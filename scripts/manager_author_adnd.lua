--
--
--
function onInit()
	if User.isHost() then
		Comm.registerSlashHandler("author", authorRefmanual);
    ExportManager.registerExportNode({ name = "_refmanualindex", label = "Reference Manual", export="reference.refmanualindex", sLibraryEntry="reference_manual"});
    
    -- setup custom export process for the _refmanualindex node build
    setCustomExportProcess(performRefIndexBuild);
  end
end

-- run a custom process function(s) at the begining of an export
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
  DB.deleteNode('_authorRefmanual_tmp');


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
          if (sNodeName:match("<sub>") ~= nil) then
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
            local dBlocks = DB.createChild(nodeRefPage,"blocks");
            local nodeBlock = DB.createChild(dBlocks);
            DB.setValue(nodeBlock,"text","formattedtext",DB.getValue(nodeStory,"text","EMPTY-STORY-TEXT"));
          --end
          DB.setValue(nodeRefPage,"listlink","windowreference",sLinkClass,sLinkRecord);
        end -- sNodeName
      end -- nodeStory
    end -- for
  end -- for

  ChatManager.SystemMessage("AUTHOR: created " .. sTmpRefIndexName .. " entries for export.");
end

-- remove leading \d+ and punctuation on text and return it
function stripLeadingNumbers(sText)
    local sStripped, sTextTrimmed = sText:match("^([%d%p?%s?]+)(.*)");
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
