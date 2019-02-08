--
--
--
aBlockFrames = {};

function onInit()
	if User.isHost() then
    local sVersionRequired = "3.3.6";
    local sMajor,sMinor,sPoint = Interface.getVersion();
    local sVersion = sMajor .. "." .. sMinor .. "." .. sPoint;
    local bVersionOK = (sVersion == sVersionRequired);

    getAvaliableBlocks();

    bVersionOK = true; -- for now don't do checking just assume they know what they are doing and enable it
    if bVersionOK then
      Comm.registerSlashHandler("author", authorRefmanual);
      ExportManager.registerExportNode({ name = "_refmanualindex", label = "Reference Manual", export="reference.refmanualindex", sLibraryEntry="reference_manual"});
      
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

-- run custom process function(s) at the begining of an export
local aCustomExportProcess = {};
function setCustomExportProcess(fProcess)
	table.insert(aCustomExportProcess, fProcess);
end
function OnExportEvent()
	if #aCustomExportProcess > 0 then
		for _,fCustomProcess in ipairs(aCustomExportProcess) do
        fCustomProcess();
    end
	end
end

-- slash command /author /export
function authorRefmanual(sCommand, sParams)
  Interface.openWindow("export", "export");
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

--=============================================================
--
-- Create _refmanualindex node with Story text to create a simple ref-manual.
-- Each "category" in the <encounters> list is a chapter and the chapter contains those story entries.
-- Story entries with <sub> will be setup as a sub-chapter.
--

-- perform the export to Ref-Manual fields.
function performRefIndexBuild()
--Debug.console("author.lua","performRefIndexBuild","",nil);
  local sTmpRefIndexName = '_refmanualindex';
  
  DB.deleteNode(sTmpRefIndexName); -- delete any previous _refmanualindex node work

  -- pickup all stories
  -- there is probably a better way to do this, table of rRecords?
  aStoryCategories = {};
  --
  local dStoryRaw = DB.getChildren("encounter");
  -- local dRoot = DB.createChild("_authorRefmanual_tmp");
  -- local dStories = DB.createChild(dRoot,"stories");
  -- local dStoryCategories = DB.createChild(dStories,"category");

  for _,node in pairs(dStoryRaw) do
    local sCategory = UtilityManager.getNodeCategory(node);
    -- only apply if the record is in a category
    if (sCategory ~= "") then
      -- -- strip out all periods because we use category name as a child/node name --DO SOMETHING ELSE
      -- sCategory = sCategory:gsub("%.",""); 
      --
      if aStoryCategories[sCategory] == nil then
        aStoryCategories[sCategory] = {};
      end
      aStoryCategories[sCategory][node.getPath()] = DB.getValue(node,"name","");
      -- local sNodeID = node.getPath():match("(id%-%d+)$");
      -- if (sNodeID) then
        -- DB.setValue(nodeEntry,"_sourceNode","string",sNodeID);
      -- end
    end
  end
  -- reference section
  local nodeRefIndex = DB.createNode(sTmpRefIndexName);
  local nodeChapters = DB.createChild(nodeRefIndex,"chapters");
  -- flip through all categories, create sub per category and and entries within category
  for _,sCatagoryName in pairs(sortCatagoriesByName(aStoryCategories)) do
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sCatagoryName",sCatagoryName);    
    -- create chapter for this category
    local sChapterName = sCatagoryName;
    local nodeChapter = DB.createChild(nodeChapters);
    local sCleanChapterName = sChapterName;
    sCleanChapterName = stripLeadingNumbers(sChapterName)
    sCleanChapterName = StringManager.trim(sCleanChapterName);
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sCleanChapterName",sCleanChapterName);    
    DB.setValue(nodeChapter,"name","string",sCleanChapterName);
    -- create subchapter for this category (have to have sub in every chapter)
    local nodeSubChapters = DB.createChild(nodeChapter,"subchapters");
    -- store this outside of the nodeStory function so we only have aExportSources
    -- sub-chapter per chapter unless <sub> string found in story name
    local nodeSubChapter = nil;
    for _,sSourceNode in pairs(sortStoriesByName(aStoryCategories[sCatagoryName])) do
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sSourceNode",sSourceNode);    
      local nodeStory = DB.findNode(sSourceNode);
      if (nodeStory) then
        --------have a frame string from story entry, or set to text4
        local sNodeDefaultFrame = DB.getValue(nodeStory,"ref_frame","text4");
        
        local sNodeName = DB.getValue(nodeStory,"name","");
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sNodeName1",sNodeName);    
        --local sNodeID = DB.getValue(nodeStory,"_sourceNode","");
--Debug.console("author.lua","performExport","sNodeID",sNodeID);         
        if (sNodeName ~= "") then
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sNodeName2",sNodeName); 
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
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","bSubchapter",bSubchapter);                     
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sNoteText",sNoteText);           
          -- we check > 8 because FG puts "SPACE<p></p>" in every story
          if (bSubchapter and sNoteText:len() > 8) or (not bSubchapter) then
            -- create refpages node and current node to work on and set name/links
            local dRefPages = DB.createChild(nodeSubChapterSub,"refpages");
            local sCleanEntry = sNodeName;
--Debug.console("manager_author_adnd.lua","performRefIndexBuild","sCleanEntry",sCleanEntry);                     
            sCleanEntry = stripLeadingNumbers(sNodeName)
            local sIndentSpace = string.match(sCleanEntry,"^([%s%t]+)"); -- grab space for count in front of the actual name after stripping numbers
            local nIndentSpace = 1;
            if sIndentSpace then 
              nIndentSpace = string.len(sIndentSpace) or 1;
            end
            sCleanEntry = StringManager.trim(sCleanEntry);
            sNodeName = sCleanEntry;
            local nodeRefPage = DB.createChild(dRefPages);
            DB.setValue(nodeRefPage,"name","string",sNodeName);
            DB.setValue(nodeRefPage,"keywords","string",CleanUpKeywords(sNodeName));
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

function createBlocks(nodeRefPage,nodeStory,sNodeDefaultFrame)
  local sFrameText = sNodeDefaultFrame;
  if sFrameText:len() < 1 then sFrameText = "text3"; end;
  local sFrameImage = "picture";
  local dBlocks = DB.createChild(nodeRefPage,"blocks");
  local sNoteText = DB.getValue(nodeStory,"text","");
  local sFrame = sNoteText:match("#frame=([%w%p%-]+)#");
  if (sFrame) then
    sNoteText = sNoteText:gsub("#frame=([%w%p%-]+)#","");
  else
    sFrame = sFrameText;
  end
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
--Debug.console("manager_author_adnd.lua","createBlocks","sThisBlock",sThisBlock);
        createBlockText(dBlocks,sThisBlock,sFrame);
      end
      
      local sImageBlock = string.sub(sNoteText,nStart,nEnd);
      if validateStringForBlock(sImageBlock) then
--Debug.console("manager_author_adnd.lua","createBlocks","sImageBlock",sImageBlock);
        createBlockImage(dBlocks,sImageBlock,sFrameImage);
      end
      -- now trim out the above text from sNoteText
      sNoteText = string.sub(sNoteText,nEnd+1);
--Debug.console("manager_author_adnd.lua","createBlocks","sNoteText",sNoteText);                        
    else
      bLoop = false;
--Debug.console("manager_author_adnd.lua","createBlocks","bLoop",bLoop);
      if validateStringForBlock(sNoteText) then
--Debug.console("manager_author_adnd.lua","createBlocks","sNoteText2",sNoteText);
        createBlockText(dBlocks,sNoteText,sFrame);
      end
    end
  end -- end while
  --DB.setValue(nodeBlock,"text","formattedtext",sNoteText);
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
  if (sFrame and sFrame ~= "") and sText:match("</p>") then
    DB.setValue(nodeBlock,"frame","string",sFrame);
    DB.setValue(nodeBlock,"text","formattedtext",sText);
  elseif (sFrame and sFrame ~= "") then -- it must be a single like "title" style line
    DB.setValue(nodeBlock,"frame","string",sFrame);
    DB.setValue(nodeBlock,"blocktype","string","header");
    DB.setValue(nodeBlock,"align","string","");
    DB.setValue(nodeBlock,"text","string",stripFormattedText(sText));
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
--Debug.console("manager_author_adnd.lua","createBlockImage","sSize",sSize);    
    DB.setValue(nodeBlock,"size","string",sSize);
    -- <caption type="string" />
    if (not sImageCaption or sImageCaption == "") then
      sImageCaption = DB.getValue(nodeImage,"name","");
    end
    -- if the size changed, tag it with full size image pixels
    if (nXOriginal ~= nX or nYOriginal ~= nY) then
      sImageCaption = sImageCaption .. " (" .. nXOriginal .. "x" .. nYOriginal .. ")";
    end
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
  sTextOnly = sTextOnly:gsub("</p>","\n");
  sTextOnly = sTextOnly:gsub("<.?[ubiphUBIPH]>","");
  sTextOnly = sTextOnly:gsub("<.?table>","");
  sTextOnly = sTextOnly:gsub("<.?frame>","");
  sTextOnly = sTextOnly:gsub("<.?t.?>","");
  sTextOnly = sTextOnly:gsub("<.?list>","");
  sTextOnly = sTextOnly:gsub("<.?li>","");
  return sTextOnly;  
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
  local textMatches = {
    'a',
    'and',
    'or',
    'the',
    'then',
    'that',
    'am',
    'is',
    'are',
    'was',
    'were',
    'at',
    'it',
    'thier',
    'their',
    'for',
    'of',
    '',
    '',
    '',
  };
  for _, sFind in ipairs(textMatches) do
    sCleanedText = sCleanedText:gsub("^" .. nocase(sFind) .. " ","");      -- remove and replace if start of text with nothing
    sCleanedText = sCleanedText:gsub("[%s]+" .. nocase(sFind) .. " "," "); -- remove and replace with a space
  end
  sCleanedText = sCleanedText:gsub("[%p%(%)%.%%%*%?%[%^%$%]]"," ");  -- remove punctuation/magic characters
  sCleanedText = sCleanedText:gsub(" [a-zA-Z] ","");  -- remove single letters surrounded by space
  sCleanedText = sCleanedText:gsub("%s%s+"," ");         -- remove double+ spacing if it's there
  sCleanedText = StringManager.trim(sCleanedText);    -- clean up ends
  sCleanedText = string.lower(sCleanedText);
  return sCleanedText;
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
