--
--
--
aBlockFrames = {};
nAllLocked = 0;

function onInit()
--Debug.console("manager_author_adnd.lua","onInit","aStoryRecordInfo2",aStoryRecordInfo);  
	if User.isHost() then
    
    updateRecordTypeInfo();
    
    Comm.registerSlashHandler("author", processAuthorCommand);
    local sVersionRequired = "3.3.9";
    local sMajor,sMinor,sPoint = Interface.getVersion();
    local sVersion = sMajor .. "." .. sMinor .. "." .. sPoint;
    local bVersionOK = (sVersion == sVersionRequired);

    getAvaliableBlocks();

    bVersionOK = true; -- for now don't do checking just assume they know what they are doing and enable it
    if bVersionOK then
      ExportManager.registerExportNode({ name = "_refmanualindex", label = "Reference Manual", export="reference.refmanualindex", sLibraryEntry="reference_manual"});
      --ExportManager.registerExportNode({ name = "_hiddenstory", label = "Hidden Story", export="reference.refmanualindex", sLibraryEntry="reference_manual"});
      --ExportManager.registerExportNode({ name = "hiddenstory", label = "Hidden Story", export="hiddenstory", exportref="reference.hiddendata", sLibraryEntry="reference_list"});
     
      -- setup custom export process for the _refmanualindex node build
      setCustomExportProcess(performRefIndexBuild);
        
      -- option in option_header_client section, enable/disable to receive DING on private message received
      OptionsManager.registerOption2("ADND_AUTHOR_DARKTHEME", false, "option_header_client", "option_label_ADND_AUTHOR_THEME", "option_entry_cycler", 
          { labels = "AUTHOR_DARKTHEME_enabled", values = "enabled", baselabel = "AUTHOR_DARKTHEME_disabled", baseval = "disabled", default = "disabled" })

    else
      Debug.chat("AUTHOR: This version requires v" .. sVersionRequired ..". You are running v" .. sVersion     .. ". AUTHOR NOT LOADED.");
      local CoreRPG_Version_Miss_Match_For_AUTHOR = nil
      -- this will cause red-alert on console, we do this to get their attention?
      -- CoreRPG_Version_Miss_Match_For_AUTHOR.causeAlert = nVersion;
    end
  end
end

function processAuthorCommand(sCommand, sParams)
--  Debug.console("manager_author_adnd.lua","processAuthorCommand","sParams",sParams);
  local sCmd, sCmdParameter = sParams:match("^([%w]+) (.+)");
  if not sCmd then
    sCmd = sParams;
  end
  if sCmd == "stats" then
    calculateEncounters();
  elseif sCmd == "lock" then
    processRecordLock("lock",sCmdParameter);
  elseif sCmd == "unlock" then
    processRecordUnLock("unlock",sCmdParameter);
  elseif sCmd == "addtokens" then
    addMissingTokens("addtokens",sCmdParameter);
  elseif sCmd == "addnpctokens" then
    addnpctokens("addnpctokens",sCmdParameter);
  elseif sCmd == "addbattletokens" then
    addMissingBattleTokens("addbattletokens",sCmdParameter);
  else
    showCommandHelp();
  end
end

function showCommandHelp()
  ChatManager.SystemMessage("AUTHOR HELP\n\r" 
                         .. "/author unlock [all|name] - unlocks object records.\r\n"
                         .. "/author lock [all|name] - locks object records.\r\n"
                         .. "/author addtokens (force-set) - Adds Letter tokens to NPCs & Battles missing tokens.\r\n"
                         .. "/author addnpctokens (force-set) - Adds Letter tokens to NPCs missing tokens.\r\n"
                         .. "/author addbattletokens (force-set) - Adds Letter tokens to Battles missing tokens.\r\n"
                         .. "/author stats - Display simple encounter stats.\r\n"
                         .. "");
end

-- add in the button_story_bulkstubs
function updateRecordTypeInfo()
  local aStoryRecordInfo = LibraryData.getRecordTypeInfo('story');
  if aStoryRecordInfo.aGMEditButtons == nil then
    aStoryRecordInfo.aGMEditButtons = {};
  end
  table.insert(aStoryRecordInfo.aGMEditButtons,'button_story_bulkstubs');
  LibraryData.overrideRecordTypeInfo('story', aStoryRecordInfo)
  aStoryRecordInfo = LibraryData.getRecordTypeInfo('story');
end

-- run custom process function(s) at the begining of an export passing it the "list" control
local aCustomExportProcess = {};
function setCustomExportProcess(fProcess)
	table.insert(aCustomExportProcess, fProcess);
end
function OnExportEvent(list)
	if #aCustomExportProcess > 0 then
		for _,fCustomProcess in ipairs(aCustomExportProcess) do
        fCustomProcess(list);
    end
	end
end

-- build a list of all the available frame defs we can use from the referenceblock* type.
function getAvaliableBlocks()
  local aFrames = Interface.getFrames();
  for _,sFrame in pairs(aFrames) do
    local sThisFrame = sFrame:match("^referenceblock%-([%w%a]+)");
    if (sThisFrame) then
      table.insert(aBlockFrames,sThisFrame);
--Debug.console("manager_author_adnd.lua","getAvaliableBlocks","Frame found:",sThisFrame);            
    end
  end -- for frames
end

-- check and see if the Hidden Story record export is enabled
function exportingHiddenStories(list)
  local bExporting = false;
  local sHidden = Interface.getString("library_recordtype_label_hiddenstory") or "";
  if sHidden ~= '' then
    for _, cw in ipairs(list.getWindows()) do
      -- see if the hiddenstory datatype is selected for export
      if cw.all.getValue() == 1 then
        if cw.label.getValue() == Interface.getString("library_recordtype_label_hiddenstory") then
          bExporting = true;
          break;
        end
      end
    end
  end
  return bExporting;
end
--=============================================================
--
-- Create _refmanualindex node with Story text to create a simple ref-manual.
-- Each "category" in the <encounters> list is a chapter and the chapter contains those story entries.
-- Story entries with checked "Sub-chapter" will be setup as a sub-chapter.
--

-- perform the export to Ref-Manual fields.
function performRefIndexBuild(list)
  local sTmpRefIndexName = '_refmanualindex';
  local sHiddenStoryName = 'hiddenstory';
  
  DB.deleteNode(sTmpRefIndexName); -- delete any previous _refmanualindex node work
  DB.deleteNode(sHiddenStoryName); -- delete any previous hiddenstory node work

  -- pickup all stories
  -- there is probably a better way to do this, table of rRecords?
  aStoryCategories = {};
  --
  
  local dStoryRaw = DB.getChildren("encounter");
  local nodeExport = DB.findNode("export");
  local sFrameGlobalDefault = DB.getValue(nodeExport,"ref_frame","text4");
  local bExportingHiddenStories = exportingHiddenStories(list);
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sFrameGlobalDefault",sFrameGlobalDefault);  
  for _,node in pairs(dStoryRaw) do
    -- put stories in a consumable array by categories
    local sCategory = UtilityManager.getNodeCategory(node);
    -- only apply if the record is in a category
    if (sCategory ~= "") then
      if aStoryCategories[sCategory] == nil then
        aStoryCategories[sCategory] = {};
      end
      aStoryCategories[sCategory][node.getPath()] = DB.getValue(node,"name","");
    end
    -- end category dealings.
    
    -- here we hide Story entries using same ID's so we can
    -- link to them in records like class/items
    if bExportingHiddenStories then
      local sNodeID = node.getPath():match("%.(id%-%d+)$");
      if sNodeID then
        local nodeHidden = DB.createNode(sHiddenStoryName .. "." .. sNodeID);
        DB.copyNode(node,nodeHidden);
        -- since this is a duplicate of stories and we just need them there we can strip the numbers
        -- used for ordering. Might need to revisit this in the future... --celestian
        local sHiddenName = DB.getValue(nodeHidden,"name","");
        DB.setValue(nodeHidden,"name","string",StringManager.trim(stripLeadingNumbers(sHiddenName)));
        DB.setValue(nodeHidden,"locked","number",1);
        --
      end
    end
    -- Done with hiddenstory
  end
  
  -- reference section
  local nodeRefIndex = DB.createNode(sTmpRefIndexName);
  local nodeChapters = DB.createChild(nodeRefIndex,"chapters");
  -- flip through all categories, create sub per category and and entries within category
  for _,sCatagoryName in pairs(sortCatagoriesByName(aStoryCategories)) do
    -- create chapter for this category
    local sChapterName = sCatagoryName;
    local nodeChapter = DB.createChild(nodeChapters);
    local sCleanChapterName = sChapterName;
    sCleanChapterName = stripLeadingNumbers(sChapterName)
    sCleanChapterName = StringManager.trim(sCleanChapterName);
    DB.setValue(nodeChapter,"name","string",sCleanChapterName);
    -- create subchapter for this category (have to have sub in every chapter)
    local nodeSubChapters = DB.createChild(nodeChapter,"subchapters");
    -- store this outside of the nodeStory function so we only have aExportSources
    -- sub-chapter per chapter unless <sub> string found in story name
    local nodeSubChapter = nil;
    for _,sSourceNode in pairs(sortStoriesByName(aStoryCategories[sCatagoryName])) do
      local nodeStory = DB.findNode(sSourceNode);
      if (nodeStory) then
        --------have a frame string from story entry, or set to text4
        local sNodeDefaultFrame = DB.getValue(nodeStory,"ref_frame",sFrameGlobalDefault);
        if sNodeDefaultFrame:len() < 1 then sNodeDefaultFrame = sFrameGlobalDefault; end;
        local sNodeName = DB.getValue(nodeStory,"name","");
        --local sNodeID = DB.getValue(nodeStory,"_sourceNode","");
        if (sNodeName ~= "") then
          -- store current subchapter node in "local" var
          -- so we can replace with new one if we get <sub>
          local nodeSubChapterSub =  nodeSubChapter;
          -- <sub> found in name string, create new sub-chapter
          local bSubchapter = (DB.getValue(nodeStory,"subchapter",0) == 1);
          if (bSubchapter) or (sNodeName:match("<sub>") ~= nil) then
            -- strip out <sub> tag
            sNodeName = StringManager.trim(sNodeName:gsub("<sub>", "")); 
            -- create new subchapter
            nodeSubChapterSub = DB.createChild(nodeSubChapters);
            local sCleanSubChapterName = sNodeName;
            sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            sCleanSubChapterName = StringManager.trim(sCleanSubChapterName);
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
            nodeSubChapter = nodeSubChapterSub;
          end
          -- this jiggery pokery is so we can have a name on the sub
          -- if it just came from having a chapter
          if nodeSubChapterSub == nil then
            local sCleanSubChapterName = sNodeName;
            
            sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            sCleanSubChapterName = StringManager.trim(sCleanSubChapterName);
            
            nodeSubChapter = DB.createChild(nodeSubChapters);
            nodeSubChapterSub = nodeSubChapter;
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
          end
          local sNoteText = DB.getValue(nodeStory,"text","");
          -- we check > 8 because FG puts "SPACE<p></p>" in every story
          --if (bSubchapter and sNoteText:len() > 8) or (not bSubchapter) then
          if (bSubchapter and not sNoteText:match("^[\r\n]+<p></p>$")) or (not bSubchapter) then
          
            -- create refpages node and current node to work on and set name/links
            local dRefPages = DB.createChild(nodeSubChapterSub,"refpages");
            local sCleanEntry = sNodeName;
            sCleanEntry = stripLeadingNumbers(sNodeName)
            local sIndentSpace = string.match(sCleanEntry,"^([_%s%t]+)"); -- grab space for count in front of the actual name after stripping numbers
            local nIndentSpace = 1;
            if sIndentSpace then 
              nIndentSpace = string.len(sIndentSpace) or 1;
            end
            sCleanEntry = StringManager.trim(sCleanEntry);  -- trim leading/ending spaces
            sCleanEntry = sCleanEntry:gsub("^[_%t]+","");   -- remove leading _'s or tabs(no they can't exist right now)
            sNodeName = sCleanEntry;
            local nodeRefPage = DB.createChild(dRefPages);
            DB.setValue(nodeRefPage,"name","string",sNodeName);
            
            -- clean up keywords for searching
            local sKeywordBody = stripFormattedText(sNoteText);
            local sKeywords = CleanUpKeywords(sKeywordBody);
            local sKeywordsFromName = CleanUpKeywords(sNodeName);
            sKeywords = removeDuplicateWords(sKeywordsFromName .. " " .. sKeywords);
            sKeywords = StringManager.trim(sKeywords);
            ---
            DB.setValue(nodeRefPage,"keywords","string",sKeywords);
            -- if indent space is more than 1 we add it (we assume we have 1 space between the leading number and the name)
            if (nIndentSpace > 1) then
              DB.setValue(nodeRefPage,"indent","number",nIndentSpace);
            end
            local sLinkClass = "reference_manualtextwide";
            local sLinkRecord = "..";
            createBlocks(nodeRefPage,nodeStory,sNodeDefaultFrame);
            DB.setValue(nodeRefPage,"listlink","windowreference",sLinkClass,sLinkRecord);
          end -- subchapter/text check
        end -- sNodeName
      end -- nodeStory
    end -- for
  end -- for

  ChatManager.SystemMessage("AUTHOR: created " .. sTmpRefIndexName .. " entries for export.");
end

-- create text/image blocks
-- TODO: instead, flip through line by line and look for markup? -- celestian
function createBlocks(nodeRefPage,nodeStory,sFrameText)
  local sFrameImage = "picture";
  local dBlocks = DB.createChild(nodeRefPage,"blocks");
  local sNoteText = DB.getValue(nodeStory,"text","");
  local aTextBlocks = {};
  local bLoop = true;
  while (bLoop) do
-- <linklist>
  -- <link class="imagewindow" recordname="image.id-00003">Map7#100x100#</link>
-- </linklist>
    local nStart, nEnd = string.find(sNoteText,'<linklist>[^<]+<link class="imagewindow" recordname="[%w%-%p]+">[^<]+</link>[^<]+</linklist>',1);
-- Debug.console("manager_author_adnd.lua","createBlocks","nStart",nStart);      
-- Debug.console("manager_author_adnd.lua","createBlocks","nEnd",nEnd);
    if (nStart and nEnd) then
      local sThisBlock = string.sub(sNoteText,1,nStart-1);
      if validateStringForBlock(sThisBlock) then
        createBlockText(dBlocks,sThisBlock,sFrameText);
      end
      
      local sImageBlock = string.sub(sNoteText,nStart,nEnd);
      if validateStringForBlock(sImageBlock) then
        createBlockImage(dBlocks,sImageBlock,sFrameImage);
      end
      -- now trim out the above text from sNoteText
      sNoteText = string.sub(sNoteText,nEnd+1);
    else
      bLoop = false;
      if validateStringForBlock(sNoteText) then
        createBlockText(dBlocks,sNoteText,sFrameText);
      end
    end
  end -- end while
end

-- add non-image block, text
function createBlockText(dBlocks,sText,sFrame)
  -- this just makes sure the frame for single line is 
  -- text is doesn't have odd white bar in middle
  --local sFrameTitle = "sidebar"; 
--Debug.console("manager_author_adnd.lua","createBlockText","sFrame",sFrame);
--Debug.console("manager_author_adnd.lua","createBlockText","sText",sText);
  local nodeBlock = DB.createChild(dBlocks);
  -- <blocktype type="string">singletext</blocktype>
  DB.setValue(nodeBlock,"blocktype","string","singletext");
  -- <align type="string">center</align>
  DB.setValue(nodeBlock,"align","string","center");
  --<frame type="string">castle</frame>
  --if (sFrame and sFrame ~= "") and (sText:match("</p>") or sText:match("<linklist>")) and not sFrame:match("^none$") then
  if (sFrame and sFrame ~= "") and not sFrame:match("^none$") then
    DB.setValue(nodeBlock,"frame","string",sFrame);
    DB.setValue(nodeBlock,"text","formattedtext",sText);
  -- elseif (sFrame and sFrame ~= "") and not sFrame:match("^none$") then -- it must be a single like "title" style line
    -- DB.setValue(nodeBlock,"frame","string",sFrame);
    -- DB.setValue(nodeBlock,"blocktype","string","header");
    -- DB.setValue(nodeBlock,"align","string","");
    -- DB.setValue(nodeBlock,"text","string",stripFormattedText(sText));
  else
    DB.setValue(nodeBlock,"text","formattedtext",sText);
  end
end

-- create a block for an inline image
function createBlockImage(dBlocks,sText,sFrame)
--Debug.console("manager_author_adnd.lua","createBlockImage","sFrame",sFrame);
--Debug.console("manager_author_adnd.lua","createBlockImage","sText",sText);
  local nodeBlock = DB.createChild(dBlocks);
-- should we split this up by $ or \r and parse it that way for better match?
-- <linklist>
  -- <link class="imagewindow" recordname="image.id-00001">Cavern1 room 2</link>
-- </linklist>
  local sImageNode = sText:match("recordname=\"([%w%p%-]+)\"");
  local sImageCaption = sText:match("<link class=\"imagewindow\" recordname=\"[%w%p%-]+\">([%w%p%s]+)</link>");
  
  -- prototyping code that I might use later...
  -- sImageNode, sImageCaption imageBlockRecord(sText);
  
--Debug.console("manager_author_adnd.lua","createBlockImage","sImageCaption",sImageCaption);  
  local nodeImage = DB.findNode(sImageNode);
  if (nodeImage) then
    -- <blocktype type="string">image</blocktype>
    DB.setValue(nodeBlock,"blocktype","string","image");
    
    --<frame type="string">castle</frame>
    -- FRAMES DONT WORK ON IMAGES DOH!!!! --celestian
    -- if (sFrame and sFrame ~= "") then
      -- DB.setValue(nodeBlock,"frame","string",sFrame);
    -- end
    
    -- <align type="string">center</align>
    DB.setValue(nodeBlock,"align","string","center");
    local nX,nY = 400,400; 
    local nXOriginal, nYOriginal = 0,0;
    local w = Interface.openWindow("imagewindow",nodeImage);
    if w then 
      local ctrl = w.createControl("image_refblock", "image");
      --nX,nY = getWindowSizeAtSmallImageSize(w,ctrl);
      nXOriginal, nYOriginal = ctrl.getImageSize();
      nX, nY = getAdjustedImageSize(win,ctrl);
      w.close();
    end
    -- <size type="string">nX,nY</size>
    local sSize = nX .. "," .. nY;
    DB.setValue(nodeBlock,"size","string",sSize);
    -- <caption type="string" />
    if (not sImageCaption or sImageCaption == "") then
      sImageCaption = DB.getValue(nodeImage,"name","");
    end
    -- removed the size of image caption --celestian
    -- if the size changed, tag it with full size image pixels
    --if (nXOriginal ~= nX or nYOriginal ~= nY) then
      --sImageCaption = sImageCaption .. " (" .. nXOriginal .. "x" .. nYOriginal .. ")";
    --end
    DB.setValue(nodeBlock,"caption","string",sImageCaption);
    -- <image type="image">
      -- <bitmap>Cavern1 room 2.jpg</bitmap>
    -- </image>
    DB.setValue(nodeBlock,"image","image",DB.getValue(nodeImage,"image",""));
    -- <imagelink type="windowreference">
      -- <class>imagewindow</class>
      -- <recordname>image.id-00001</recordname>
    -- </imagelink>
    DB.setValue(nodeBlock,"imagelink","windowreference","imagewindow",sImageNode);
  end
end

-- prototyping code that I might use later...
-- <link class="imagewindow" recordname="image.id-00003">Map7#100x100#</link>
function imageBlockRecord(sText)
  local sImageNode, sImageCaption = sText:match('<link class="imagewindow" recordname="(.-)">(.-)</link>');
  return sImageNode, sImageCaption;
end


-- this will make sure the image is no bigger than 500x500 and try to keep
-- the scale/size portions correct
function getAdjustedImageSize(win,image)
  local SMALL_WIDTH = 500;
  local SMALL_HEIGHT = 500;
  local nX,nY = image.getImageSize();
  if (nX > SMALL_WIDTH or nY > SMALL_HEIGHT) then
    local nNewScale = math.min(SMALL_WIDTH/nX,SMALL_HEIGHT/nY);
    nX = math.floor(nX * nNewScale);
    nY = math.floor(nY * nNewScale);
  end
  return nX,nY;
end

-- this checks to see if the string is valid to be written to refmanual-block. Sometimes get get a black line or empty cause of
-- users....
function validateStringForBlock(sBlockText)
 local bValid = false;
  
  if (sBlockText:len() > 0) and (sBlockText:match("^[\r\n]$") == nil) and (sBlockText:match("^[\r\n]?<p></p>[\r\n]?$") == nil) then
    bValid = true;
  end
  
  return bValid;
end

-- strip out formattedtext from a string
function stripFormattedText(sText)
  local sTextOnly = sText;
  --sTextOnly = sTextOnly:gsub("</p>","\n");
  sTextOnly = sTextOnly:gsub("<.?[ubiphUBIPH]>","");
  sTextOnly = sTextOnly:gsub("<.?table>","");
  sTextOnly = sTextOnly:gsub("<.?frame>","");
  sTextOnly = sTextOnly:gsub("<.?t.?>","");
  sTextOnly = sTextOnly:gsub("<.?list>","");
  sTextOnly = sTextOnly:gsub("<.?li>","");
  return sTextOnly;  
end

-- generate ignore case patterns from string passed
function nocase(pattern)
  -- find an optional '%' (group 1) followed by any character (group 2)
  local p = pattern:gsub("(%%?)(.)", function(percent, letter)
    if percent ~= "" or not letter:match("%a") then
      -- if the '%' matched, or `letter` is not a letter, return "as is"
      return percent .. letter
    else
      -- else, return a case-insensitive character class of the matched letter
      return string.format("[%s%s]", letter:lower(), letter:upper())
    end

  end)
  return p
end

-- this removes a lot of the meaningless words from keywords search strings 
-- so that the search works a little better
function CleanUpKeywords(sText)
  local sCleanedText = sText;
  if sCleanedText then 
    local textMatches = {
      'and',
      'does',
      'more',
      'must',
      'mine',
      'the',
      'then',
      'that',
      'are',
      'was',
      'were',
      'well',
      'what',
      'where',
      'this',
      'that',
      'other',
      'left',
      'right',
      'but',
      'old',
      'td',
      'or',
      'of',
      'no',
      'its',
      'new',
      'not',
      'most',
      'has',
      'been',
      'well',
      'good',
      'bad',
      'thier',
      'their',
      'fore',
      'from',
      'for',
      'another',
    };
    for _, sFind in ipairs(textMatches) do
      sCleanedText = sCleanedText:gsub("^" .. nocase(sFind) .. " ","");      -- remove and replace if start of text with nothing
      sCleanedText = sCleanedText:gsub("[%s]+" .. nocase(sFind) .. " "," "); -- remove and replace with a space
    end
    sCleanedText = sCleanedText:gsub("linklist","");                   -- remove special strings related to FG
    sCleanedText = sCleanedText:gsub("imagewindow","");                -- remove special strings related to FG
    sCleanedText = sCleanedText:gsub("recordname","");                 -- remove special strings related to FG
    sCleanedText = sCleanedText:gsub("[%p%(%)%.%%%*%?%[%^%$%]]"," ");  -- remove punctuation/magic characters
    sCleanedText = sCleanedText:gsub(" [a-zA-Z] "," ");                -- remove single letters surrounded by space
    sCleanedText = sCleanedText:gsub(" [a-zA-Z][a-zA-Z] "," ");        -- remove 2 letters surrounded by space
    sCleanedText = sCleanedText:gsub("%s%s+"," ");                     -- remove double+ spacing if it's there
    sCleanedText = StringManager.trim(sCleanedText);                   -- clean up ends
    sCleanedText = string.lower(sCleanedText);
  end
  return sCleanedText;
end

-- remove repeating words in a block of text
function removeDuplicateWords(sText)
  local out = " ";
  for s in sText:gmatch("%w+") do
    if not out:find(s) then out = out .. " " .. s end
  end
  return out;
end

-- remove leading \d+ and punctuation on text and return it
function stripLeadingNumbers(sText)
    local sStripped, sTextTrimmed = sText:match("^([%d%p]+)(.*)");
    if sStripped ~= nil and sStripped ~= "" then
      sText = sTextTrimmed;
    end
    return sText;
end

function sortCatagoriesByName(aCatagory)
  local aSorted = {};
  for sCatagoryName,aStoryEntries in pairs(aCatagory) do
    table.insert(aSorted, sCatagoryName);
  end        
  table.sort(aSorted);
  return aSorted;
end
function sortStoriesByName(aStories)
  local aSorted = {};
  for sStorySource,sStoryName in pairs(aStories) do
    table.insert(aSorted, sStorySource);
  end
  table.sort(aSorted, function(a, b) return aStories[a] < aStories[b] end);
  return aSorted;
end


-- -- default record list for "all" lock/unlock
-- local aDefaultLockAll = {
  -- "background",
  -- "battle",
  -- "battlerandom",
  -- "class",
  -- "effects",
  -- "encounter",
  -- "feat",
  -- "image",
  -- "item",
  -- "modifiers",
  -- "notes",
  -- "npc",
  -- "quest",
  -- "race",
  -- "skill",
  -- "spell",
  -- "story",
  -- "storytemplate",
  -- "tables",
  -- "treasureparcels",
-- };
-- process unlocks
function processRecordUnLock(sCommand, sParams)
  nAllLocked = 0;
  processRecordLocking(sParams:lower(),0);
  ChatManager.SystemMessage("AUTHOR: unlocked " .. nAllLocked .. " records.");  
end
-- Search through param passed record and set it locked.
function processRecordLock(sCommand, sParams)
  nAllLocked = 0;
  processRecordLocking(sParams:lower(),1);
  ChatManager.SystemMessage("AUTHOR: locked " .. nAllLocked .. " records.");  
end
-- general locking function, take name and whether should lock or not
function processRecordLocking(sParams,nLock)
  local sRecordName = sParams:lower();
  if sRecordName == "all" then
    local aDefaultLockAll = {};
--Debug.console("manager_author_adnd.lua","processRecordLocking","Locking1: ",sRecordName);
    local aRecords = LibraryData.getRecordTypes();
    
    for _, sRecord in pairs(aRecords) do
      local sInfo = LibraryData.getRecordTypeInfo(sRecord);
      table.insert(aDefaultLockAll,sInfo.aDataMap[1]);
    end
    --for _, sRecord in pairs(aRecords) do
    for _, sRecord in pairs(aDefaultLockAll) do
      editLockRecords(sRecord,nLock);
    end
  elseif DB.getChildCount(sRecordName) > 0 then
--Debug.console("manager_author_adnd.lua","processRecordLocking","Locking2: ",sRecordName);
    editLockRecords(sRecordName,nLock);
  end -- valid record
end
-- pass name to lock records for this type
function editLockRecords(sRecord,nLock)
  local sRulesetName = User.getRulesetName();
  local nLockCount = 0;
  for _,nodeLock in pairs(DB.getChildren(sRecord)) do
    nLockCount = nLockCount + 1;
    DB.setValue(nodeLock,"locked","number",nLock);
Debug.console("manager_author_adnd.lua","lockRecord","Locked node:",nodeLock);
    -- 2E only processes
    if sRulesetName == "2E" then
      -- lock npc weapon quicknote for 2E npcs
      if sRecord == "npc" then
        editLockRecords(nodeLock.getPath() .. "." .. "powers",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "abilitynoteslist",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "weaponlist",nLock);
      elseif (sRecord:match('weaponlist')) then -- lock weapon quicknotes
        local sClass, _ = DB.getValue(nodeLock,"shortcut","","");
        if (sClass == "quicknote") then
          DB.setValue(nodeLock,"itemnote.locked","number",nLock);
        end
        local sQuickNoteName = DB.getValue(nodeLock,"itemnote.name");
        if (sQuickNoteName) then
          DB.setValue(nodeLock,"itemnote.locked","number",nLock);
        end
      elseif (sRecord == 'item') then
        editLockRecords(nodeLock.getPath() .. "." .. "weaponlist",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "powers",nLock);
      elseif (sRecord == "race") then
        editLockRecords(nodeLock.getPath() .. "." .. "features",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "nonweaponprof",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "proficiencies",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "traits",nLock);
      elseif (sRecord == "class") then
        -- use this instead?
        editLockRecords(nodeLock.getPath() .. "." .. "advancement",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "features",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "nonweaponprof",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "proficiencies",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "abilities",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "powers",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "skill",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "weaponlist",nLock);
      elseif (sRecord == "treasureparcels") then
        editLockRecords(nodeLock.getPath() .. "." .. "itemlist",nLock);
      elseif (sRecord == "background") then
        editLockRecords(nodeLock.getPath() .. "." .. "features",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "nonweaponprof",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "proficiencies",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "powers",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "skill",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "weaponlist",nLock);
      end -- class
    
    -- 5e
    elseif sRulesetName == "5E" then
      if (sRecord == "class") then
        editLockRecords(nodeLock.getPath() .. "." .. "features",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "abilities",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "multiclassfeatures",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "multiclassproficiencies",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "proficiencies",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "abilities",nLock);
        editLockRecords(nodeLock.getPath() .. "." .. "abilities",nLock);
      elseif (sRecord == "treasureparcels") then
        editLockRecords(nodeLock.getPath() .. "." .. "itemlist",nLock);
      elseif (sRecord == "background") then
        editLockRecords(nodeLock.getPath() .. "." .. "features",nLock);
      end -- 
    end
    
    --Debug.console("manager_author_adnd.lua","lockRecord","Locked node:",nodeLock);
  end -- record for
  local sLockedText = "locked";
  if nLock == 0 then sLockedText = "unlocked"; end;
  local sRecordDisplayName = LibraryData.getDisplayText(sRecord)
  if (not sRecordDisplayName or sRecordDisplayName == "") then
    sRecordDisplayName = sRecord;
  end
  nAllLocked = nLockCount + nAllLocked;
--Debug.console("manager_author_adnd.lua","lockRecord","sRecordDisplayName",sRecordDisplayName);  
  if (not sRecord:match("%.id%-%d+")) then
    ChatManager.SystemMessage("AUTHOR: " .. sLockedText .. " " .. nLockCount .. " entries for ".. sRecordDisplayName .. " (type: " .. sRecord .. ")" .. ".");  
  end
  
  Debug.console("manager_author_adnd.lua","editLockRecords():","AUTHOR: " .. sLockedText .. " " .. nLockCount .. " entries for ".. sRecordDisplayName .. " (type: " .. sRecord .. ")" .. ".");
end

-- add missing tokens to npcs and battle/encounters
function addMissingTokens(sCommand, sParams)
  local bForceSet = false;
  if sParams then
    bForceSet = (sParams:lower() == "force-set");
  end
Debug.console("manager_author_adnd.lua","addMissingTokens","Is ForceSet?",bForceSet);     
  addTokensIfMissing(bForceSet);
  addTokensIfMissingFromEncounters(bForceSet);
end
-- add missing tokens to npcs 
function addMissingNPCTokens(sCommand, sParams)
  local bForceSet = false;
  if sParams then
    bForceSet = (sParams:lower() == "force-set");
  end
  addTokensIfMissing(bForceSet)
end
-- add missing tokens to battle/encounters
function addMissingBattleTokens(sCommand, sParams)
  local bForceSet = false;
  if sParams then
    bForceSet = (sParams:lower() == "force-set");
  end
  addTokensIfMissingFromEncounters(bForceSet)
end

-- add letter tokens to npcs if they are missing one
function addTokensIfMissing(bForceSet)
  local nCount = 0;
--<token type="token">tokens/Medium/a.png@Letter Tokens</token>
  for _,nodeNPC in pairs(DB.getChildren("npc")) do
    local sName = DB.getValue(nodeNPC,"name","");
    local tToken = DB.getValue(nodeNPC,"token","");
--Debug.console("manager_author_adnd.lua","addTokensIfMissing","sName",sName);      
--Debug.console("manager_author_adnd.lua","addTokensIfMissing","tToken",tToken);      
    local sToken = nil;
    if (not tToken or tToken == "" or bForceSet) then
      nCount = nCount + 1;
      local sFirstLetter = StringManager.trim(sName):match("^([a-zA-Z])");
      if sFirstLetter then
        sToken = "tokens/Medium/" .. sFirstLetter:lower() .. ".png@Letter Tokens";
      else
        sToken = "tokens/Medium/z.png@Letter Tokens";
      end
      Debug.console("manager_author_adnd.lua","addNPCTokens","Adding Token:",sToken);       
      DB.setValue(nodeNPC, "token", "token", sToken);
    end
  end
  ChatManager.SystemMessage("AUTHOR: Added letter token to " .. nCount .. " npcs.");  
end

-- add letter tokens to encounters if they are missing one
function addTokensIfMissingFromEncounters(bForceSet)
  local nCount = 0;
  for _,nodeBattle in pairs(DB.getChildren("battle")) do
    for _,nodeEncounterNPC in pairs(DB.getChildren(nodeBattle,"npclist")) do
      local _, sRecord = DB.getValue(nodeEncounterNPC,"link","","");
      local nodeSource = DB.findNode(sRecord);
      local sNameOriginal = DB.getValue(nodeSource,"name","");
      local sName = DB.getValue(nodeEncounterNPC,"name","");
      local tToken = DB.getValue(nodeEncounterNPC,"token","");

      if (sName == "") then -- if they did not rename the creature
        sName = sNameOriginal;
      end
      
      local sToken = nil;
      if (not tToken or tToken == "" or bForceSet) then
        nCount = nCount + 1;
        local sFirstLetter = StringManager.trim(sName):match("^([a-zA-Z])");
        if sFirstLetter then
          sToken = "tokens/Medium/" .. sFirstLetter:lower() .. ".png@Letter Tokens";
        else
          sToken = "tokens/Medium/z.png@Letter Tokens";
        end
        Debug.console("manager_author_adnd.lua","addBattleTokens","Adding Token:",sToken);           
        DB.setValue(nodeEncounterNPC, "token", "token", sToken);
      end
      
    end -- end list of nodeEncounterNPC
  end -- end list of nodeBattle
  ChatManager.SystemMessage("AUTHOR: Added letter token to " .. nCount .. " battle/encounters.");  
end

-- count up all the encounters, cr and experience totals for a report.
function calculateEncounters()
  local nTotalEXP = 0;
  local nTotalCR = 0;
  local fAverageCR = 0;
  local nTotalEncounters = 0;
  for _,nodeEnc in pairs(DB.getChildren("battle")) do
    nTotalEncounters = nTotalEncounters + 1;
    nTotalEXP = nTotalEXP + DB.getValue(nodeEnc,"exp",0);
    local sCR = DB.getValue(nodeEnc, "cr", "");
    nTotalCR = nTotalCR + tonumber(sCR:match("^%d+$") or 0);
  end
  if nTotalCR ~= 0 and nTotalEncounters ~= 0 then
    fAverageCR = nTotalCR/nTotalEncounters;
  end
  local sRulesetName = User.getRulesetName();
  if sRulesetName == "2E" then
    ChatManager.SystemMessage("AUTHOR: Encounter Totals\r\nCount: " .. nTotalEncounters .. "\r\nEXP: " .. nTotalEXP .."\r\n");  
    Debug.console("manager_author_adnd","calculateEncounters","AUTHOR: Encounter Totals\r\nCount: " .. nTotalEncounters .. "\r\EXP: " .. nTotalEXP .."\r\n");  
  else
    ChatManager.SystemMessage("AUTHOR: Encounter Totals\r\nCount: " .. nTotalEncounters .. "\r\nEXP: " .. nTotalEXP.. "\r\nAverage CR: " .. string.format("%.2f",fAverageCR) .."\r\n");  
    Debug.console("manager_author_adnd","calculateEncounters","AUTHOR: Encounter Totals\r\nCount: " .. nTotalEncounters .. "\r\nEXP: " .. nTotalEXP.. "\r\nAverage CR: " .. string.format("%.2f",fAverageCR) .."\r\n");  
  end
  local sMessage = "";
  for sName,nCount in pairs(calculateTreasureCoins()) do
    if sName ~= "" then
      sMessage = sMessage .. sName .. " : " .. nCount .. "\r\n";
    end
  end
  ChatManager.SystemMessage("AUTHOR: Treasure Coin Totals\r\n" .. sMessage);
  Debug.console("manager_author_adnd","calculateEncounters","AUTHOR: Treasure Coin Totals\r\n" .. sMessage);
  sMessage = "";
  for sName,nCount in pairs(calculateTreasureItems()) do
    if sName ~= "" then
      sMessage = sMessage .. sName .. " : " .. nCount .. "\r\n";
    end
  end
  ChatManager.SystemMessage("AUTHOR: Treasure Item Value Totals\r\n" .. sMessage);
  Debug.console("manager_author_adnd","calculateEncounters","AUTHOR: Treasure Item Value Totals\r\n" .. sMessage);
end

function calculateTreasureCoins()
  local aCoins ={};
  for _,nodeParcel in pairs(DB.getChildren("treasureparcels")) do
      local sNameParcel = DB.getValue(nodeParcel, "name", "");    
    for _,nodeCoin in pairs(DB.getChildren(nodeParcel, "coinlist")) do
      local sCurrency = DB.getValue(nodeCoin, "description", "");
      sCurrency = sCurrency:upper();
      local nCurrency = DB.getValue(nodeCoin, "amount", 0);
      if aCoins[sCurrency] then
        aCoins[sCurrency] = aCoins[sCurrency] + nCurrency;
      else
        aCoins[sCurrency] = nCurrency;
      end
    end
  end
  return aCoins;
end

function calculateTreasureItems()
  local aCoins ={};
  local sRulesetName = User.getRulesetName();
  for _,nodeParcel in pairs(DB.getChildren("treasureparcels")) do
    local sNameParcel = DB.getValue(nodeParcel, "name", "");    
    for _,nodeItem in pairs(DB.getChildren(nodeParcel, "itemlist")) do
      local sNameItem = DB.getValue(nodeItem, "name", "");    
      local sCost = DB.getValue(nodeItem, "cost", "");
      if sCost ~= "" then
        local sCoins,sCurrency = sCost:match("(%d+) (%w+)");
        if not sCurrency then
Debug.console("manager_author_adnd","calculateTreasure","sNameParcel",sNameParcel);   
Debug.console("manager_author_adnd","calculateTreasure","sNameItem",sNameItem);   
Debug.console("manager_author_adnd","calculateTreasure","sCost",sCost);   
        else
          sCurrency = sCurrency:upper();
          local nCurrency = tonumber(sCoins) or 0;
          if aCoins[sCurrency] then
            aCoins[sCurrency] = aCoins[sCurrency] + nCurrency;
          else
            aCoins[sCurrency] = nCurrency;
          end
        end
      end
    end
  end
  return aCoins;
end