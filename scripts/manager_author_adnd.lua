--
--
--
function onInit()
	if User.isHost() then
    local _, _, aMajor, _ = DB.getRulesetVersion();
    local sRuleset = 'CoreRPG';
    local nVersion = 4;
    local bVersionOK = false;
    local nCurrentVersion = 0;
    for a1,a2 in pairs(aMajor) do
      if (a1 == sRuleset and a2 == nVersion) then
        bVersionOK = true;
        nCurrentVersion = a2;
        break;
      elseif (a1 == sRuleset) then
        nCurrentVersion = a2;
      end
    end
    if bVersionOK then
      Comm.registerSlashHandler("author", authorRefmanual);
      ExportManager.registerExportNode({ name = "_refmanualindex", label = "Reference Manual", export="reference.refmanualindex", sLibraryEntry="reference_manual"});
      
      -- setup custom export process for the _refmanualindex node build
      setCustomExportProcess(performRefIndexBuild);
    else
      Debug.chat("AUTHOR: This version requires " .. sRuleset .. " v" .. nVersion .. ". You are running v" .. nCurrentVersion .. ". AUTHOR NOT LOADED.");
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

function authorRefmanual(sCommand, sParams)
  Interface.openWindow("export", "export");
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
          if (DB.getValue(nodeStory,"subchapter",0) == 1) or (sNodeName:match("<sub>") ~= nil) then
            -- strip out <sub> tag
            sNodeName = StringManager.trim(sNodeName:gsub("<sub>", "")); 
            -- create new subchapter
            nodeSubChapterSub = DB.createChild(nodeSubChapters);
            local sCleanSubChapterName = sNodeName;
            --if (aProperties.bStripOrderingSubChapter) then
              sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            --end
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
            nodeSubChapter = nodeSubChapterSub;
          end
          -- this jiggery pokery is so we can have a name on the sub
          -- if it just came from having a chapter
          if nodeSubChapterSub == nil then
            local sCleanSubChapterName = sNodeName;
            --if (aProperties.bStripOrderingSubChapter) then
              sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            --end
            nodeSubChapter = DB.createChild(nodeSubChapters);
            nodeSubChapterSub = nodeSubChapter;
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
          end
          -- create refpages node and current node to work on and set name/links
          local dRefPages = DB.createChild(nodeSubChapterSub,"refpages");
          local sCleanEntry = sNodeName;
          --if (aProperties.bStripOrderingEntry) then
            sCleanEntry = stripLeadingNumbers(sNodeName)
          --end
          sNodeName = sCleanEntry;
          local nodeRefPage = DB.createChild(dRefPages);
          DB.setValue(nodeRefPage,"name","string",sNodeName);
          DB.setValue(nodeRefPage,"keywords","string",sNodeName);
          local sLinkClass = "reference_manualtextwide";
          local sLinkRecord = "..";
          -- if (sNodeID and sNodeID ~= "" ) then
            -- sLinkRecord = "encounter." .. sNodeID;
          -- else
            -- create block node and set text from story
            createBlocks(nodeRefPage,nodeStory);
            -- local dBlocks = DB.createChild(nodeRefPage,"blocks");
            -- local nodeBlock = DB.createChild(dBlocks);
            -- DB.setValue(nodeBlock,"text","formattedtext",DB.getValue(nodeStory,"text","EMPTY-STORY-TEXT"));
          --end
          DB.setValue(nodeRefPage,"listlink","windowreference",sLinkClass,sLinkRecord);
        end -- sNodeName
      end -- nodeStory
    end -- for
  end -- for

  ChatManager.SystemMessage("AUTHOR: created " .. sTmpRefIndexName .. " entries for export.");
end

function createBlocks(nodeRefPage,nodeStory)
  local dBlocks = DB.createChild(nodeRefPage,"blocks");
  local sNoteText = DB.getValue(nodeStory,"text","");
  --local aTextBlocks = StringManager.split(sNoteText, '<linklist>[%W]+<link class="imagewindow" recordname="[%w%W]+">[%w%W]+</link>[%W]+</linklist>', true);
  local aTextBlocks = {};
  local bLoop = true;
  while (bLoop) do
    local nStart, nEnd = string.find(sNoteText,'<linklist>[^<]+<link class="imagewindow" recordname="[%w%-%p]+">[^<]+</link>[^<]+</linklist>',1);
-- Debug.console("manager_author_adnd.lua","createBlocks","nStart",nStart);      
-- Debug.console("manager_author_adnd.lua","createBlocks","nEnd",nEnd);
    if (nStart and nEnd) then
      local sThisBlock = string.sub(sNoteText,1,nStart-1);
--Debug.console("manager_author_adnd.lua","createBlocks","sThisBlock",sThisBlock);
      createBlockText(dBlocks,sThisBlock);
      
      local sImageBlock = string.sub(sNoteText,nStart,nEnd);
--Debug.console("manager_author_adnd.lua","createBlocks","sImageBlock",sImageBlock);
      createBlockImage(dBlocks,sImageBlock);

      -- now trim out the above text from sNoteText
      sNoteText = string.sub(sNoteText,nEnd+1);
--Debug.console("manager_author_adnd.lua","createBlocks","sNoteText",sNoteText);                        
    else
      bLoop = false;
--Debug.console("manager_author_adnd.lua","createBlocks","bLoop",bLoop);
      createBlockText(dBlocks,sNoteText);
    end
  end -- end while
  --DB.setValue(nodeBlock,"text","formattedtext",sNoteText);
end

-- add non-image block, text
function createBlockText(dBlocks,sText)
--Debug.console("manager_author_adnd.lua","createBlockText","sText",sText);
  local nodeBlock = DB.createChild(dBlocks);
  -- <blocktype type="string">singletext</blocktype>
  DB.setValue(nodeBlock,"blocktype","string","singletext");
  -- <align type="string">center</align>
  DB.setValue(nodeBlock,"align","string","center");
  DB.setValue(nodeBlock,"text","formattedtext",sText);
end
-- create a block for an inline image
function createBlockImage(dBlocks,sText)
--Debug.console("manager_author_adnd.lua","createBlockImage","sText",sText);
  local nodeBlock = DB.createChild(dBlocks);
-- <linklist>
  -- <link class="imagewindow" recordname="image.id-00001">Cavern1 room 2</link>
-- </linklist>
  local sImageNode = sText:match("recordname=\"([%w%p%-]+)\"");
  local nodeImage = DB.findNode(sImageNode);
  if (nodeImage) then
    -- <blocktype type="string">image</blocktype>
    DB.setValue(nodeBlock,"blocktype","string","image");
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
    local sCaption = DB.getValue(nodeImage,"name","");
    -- if the size changed, tag it with full size image pixels
    if (nXOriginal ~= nX or nYOriginal ~= nY) then
      sCaption = sCaption .. " (" .. nXOriginal .. "x" .. nYOriginal .. ")";
    end
    DB.setValue(nodeBlock,"caption","string",sCaption);
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
