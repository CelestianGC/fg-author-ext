--
-- Export Story text as ref-manual with records
-- Contains code to manage "/author" command and "export" story entries (<encounters>) as chapter in a ref-manual
-- format. Each "category" in the <encounters> list is a chapter and the chapter contains those story entries.
--

-- pass list of nodes with a "name" record and sort by name
function sortByName(nodes)
  local aSorted = {};
  for _,node in pairs(nodes) do
    table.insert(aSorted, node);
  end        
  table.sort(aSorted, function (a, b) return DB.getValue(a,"name","") < DB.getValue(b,"name","") end);
  return aSorted;
end

-- perform the export to Ref-Manual fields.
function performExport()
  aProperties = {};
  aProperties.bStripOrderingChapter = (chapter_clean.getValue() == 1);
  aProperties.bStripOrderingSubChapter = (subchapter_clean.getValue() == 1);
  aProperties.bStripOrderingEntry = (entry_clean.getValue() == 1);
	aProperties.name = name.getValue();
	aProperties.namecompact = string.lower(string.gsub(aProperties.name, "%W", ""));
	aProperties.category = category.getValue();
	--aProperties.file = file.getValue();
	aProperties.author = author.getValue();
	--aProperties.thumbnail = thumbnail.getValue();
	if readonly.getValue() == 1 then
		aProperties.readonly = true;
	end
	aProperties.playervisible = (playervisible.getValue() == 1);

  -- pickup all stories
  local dStoryRaw = DB.getChildren("encounter");
  local dRoot = DB.createChild("_authorRefmanual_tmp");
  local dStories = DB.createChild(dRoot,"stories");
  local dStoryCategories = DB.createChild(dStories,"category");

  for _,node in pairs(dStoryRaw) do
    local sCategory = UtilityManager.getNodeCategory(node);
    -- only apply if the record is in a category
    if (sCategory ~= "") then
      -- strip out all periods because we use category name as a child/node name --DO SOMETHING ELSE
      sCategory = sCategory:gsub("%.",""); 
      local dCategory = DB.getChild(dStoryCategories,sCategory);
      if (dCategory == nil) then
        dCategory = DB.createChild(dStoryCategories,sCategory);
        DB.setValue(dCategory,"name","string",sCategory);
      end
      local nodeEntry = dCategory.createChild();
      DB.copyNode(node,nodeEntry);
      local sNodeID = node.getPath():match("(id%-%d+)$");
      if (sNodeID) then
        DB.setValue(nodeEntry,"_sourceNode","string",sNodeID);
      end
    end
  end

  -- create root "author" node to drop entries into temporarily 
  local dAuthorNode = DB.createChild("_authorRefmanual");
  
  -- library section
  local dLibrary = DB.createChild(dAuthorNode,"library");
  local nodeLibrary = DB.createChild(dLibrary,"adnd_refmanual_library");
  DB.setValue(nodeLibrary,"categoryname","string",aProperties.category);
  DB.setValue(nodeLibrary,"name","string","Name-Ref-Manual-PlaceHolder-Text");
  local nodeLibraryEntries =  DB.createChild(nodeLibrary,"entries");
  local nodeLibraryEntry =  DB.createChild(nodeLibraryEntries);
  DB.setValue(nodeLibraryEntry,"name","string",aProperties.name);
  local sLinkClass = "reference_manual";
  local sLinkRecord = "reference.refmanualindex";
  DB.setValue(nodeLibraryEntry,"librarylink","windowreference",sLinkClass,sLinkRecord);
    
	-- Loop through selected export record categories (class, race, npc, items, spells, skills/etc)
	for _, cw in ipairs(list.getWindows()) do
    local bAuthorRecord = (cw.all.getValue() == 1);
    local aExportSources = cw.getSources();
    local aExportTargets = cw.getTargets();
    if (bAuthorRecord) then
        for kSource,vSource in ipairs(aExportSources) do
          local nodeSource = DB.findNode(vSource);
          if nodeSource and nodeSource.getChildCount() > 0 then
            -- create node matching node we're copying to manual
            local dAuthorRecord = DB.createChild(dAuthorNode,vSource);  
            -- create library link to list all these items
            local nodeLibraryAdditional =  DB.createChild(nodeLibraryEntries);                    
            DB.setValue(nodeLibraryAdditional,"name","string",StringManager.capitalize(vSource));
            DB.setValue(nodeLibraryAdditional,"source","string",vSource);
            DB.setValue(nodeLibraryAdditional,"recordtype","string",vSource);
            local sClass = "reference_list";
            local sRecord = "..";
            DB.setValue(nodeLibraryAdditional,"librarylink","windowreference",sClass,sRecord);
            for _,nodeChild in pairs(nodeSource.getChildren()) do
              if nodeChild.getType() == "node" then
                -- keep same path to records so links work in stories/pages
                local sNodePath = dAuthorNode.getPath() .. "." .. nodeChild.getPath();
-- Debug.console("author.lua","performExport","sNodePath",sNodePath);                  
-- Debug.console("author.lua","performExport","nodeChild.getPath()",nodeChild.getPath());                  
-- Debug.console("author.lua","performExport","nodeChild",nodeChild);
                DB.copyNode(nodeChild,sNodePath);
              end
            end
          end
        end
      end
    end

  -- reference section
  local dReference = DB.createChild(dAuthorNode,"reference");
  local nodeRefIndex = DB.createChild(dReference,"refmanualindex");
  local nodeChapters = DB.createChild(nodeRefIndex,"chapters");
  -- flip through all categories, create sub per category and and entries within category
  for _,nodeCategory in pairs(sortByName(dStoryCategories.getChildren())) do
    -- create chapter for this category
    local sChapterName = DB.getValue(nodeCategory,"name","EMPTY-CATEGORY-NAME");
    local nodeChapter = DB.createChild(nodeChapters);
    local sCleanChapterName = sChapterName;
    if (aProperties.bStripOrderingChapter) then
      sCleanChapterName = stripLeadingNumbers(sChapterName)
    end
    DB.setValue(nodeChapter,"name","string",sCleanChapterName);
    -- create subchapter for this category (have to have sub in every chapter)
    local nodeSubChapters = DB.createChild(nodeChapter,"subchapters");
    -- store this outside of the nodeStory function so we only have aExportSources
    -- sub-chapter per chapter unless <sub> string found in story name
    local nodeSubChapter = nil;
    for _,nodeStory in pairs(sortByName(nodeCategory.getChildren())) do
        local sNodeName = DB.getValue(nodeStory,"name","");
        local sNodeID = DB.getValue(nodeStory,"_sourceNode","");
Debug.console("author.lua","performExport","sNodeID",sNodeID);         
        if (sNodeName ~= "") then
--Debug.console("author.lua","performExport","sNodeName",sNodeName); 
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
            if (aProperties.bStripOrderingSubChapter) then
              sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            end
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
            nodeSubChapter = nodeSubChapterSub;
          end
          -- this jiggery pokery is so we can have a name on the sub
          -- if it just came from having a chapter
          if nodeSubChapterSub == nil then
            local sCleanSubChapterName = sNodeName;
            if (aProperties.bStripOrderingSubChapter) then
              sCleanSubChapterName = stripLeadingNumbers(sNodeName)
            end
            nodeSubChapter = DB.createChild(nodeSubChapters);
            nodeSubChapterSub = nodeSubChapter;
            DB.setValue(nodeSubChapterSub,"name","string",sCleanSubChapterName);
          end
          -- create refpages node and current node to work on and set name/links
          local dRefPages = DB.createChild(nodeSubChapterSub,"refpages");
          local sCleanEntry = sNodeName;
          if (aProperties.bStripOrderingEntry) then
            sCleanEntry = stripLeadingNumbers(sNodeName)
          end
          sNodeName = sCleanEntry;
          local nodeRefPage = DB.createChild(dRefPages);
          DB.setValue(nodeRefPage,"name","string",sNodeName);
          DB.setValue(nodeRefPage,"keywords","string",sNodeName);
          local sLinkClass = "reference_manualtextwide";
          local sLinkRecord = "..";
          if (sNodeID and sNodeID ~= "" ) then
            sLinkRecord = "encounter." .. sNodeID;
          else
            -- create block node and set text from story
            local dBlocks = DB.createChild(nodeRefPage,"blocks");
            local nodeBlock = DB.createChild(dBlocks);
            DB.setValue(nodeBlock,"text","formattedtext",DB.getValue(nodeStory,"text","EMPTY-STORY-TEXT"));
          end
          DB.setValue(nodeRefPage,"listlink","windowreference",sLinkClass,sLinkRecord);
      end
    end
  end

  -- create root "author" definition node to export
  local dDefinitionNode = DB.createChild("_authorDefinition");
  DB.setValue(dDefinitionNode,"name","string",aProperties.name);    
  DB.setValue(dDefinitionNode,"category","string",aProperties.category);    
  DB.setValue(dDefinitionNode,"author","string",aProperties.author);    
  DB.setValue(dDefinitionNode,"ruleset","string",User.getRulesetName());    
  
  -- prompt for filename to save client.xml to
  local sFile = Interface.dialogFileSave( );
  if (sFile ~= nil and sFile ~= "" ) then 
    local sDirectory = sFile:match("(.*[/\\])");
    -- export the client.xml data to selected file
    DB.export(sFile,dAuthorNode.getPath());	
    -- export definition file in same path/definition
    DB.export(sDirectory .. "definition.xml",dDefinitionNode.getPath());	
    
    -- show done message
    local sFormat = Interface.getString("author_completed");
    local sMsg = string.format(sFormat, aProperties.name,sFile);
    ChatManager.SystemMessage(sMsg);
    --file.setFocus(true);
  end
  -- remove temporary category sorting nodes
  DB.deleteNode(dRoot.getPath());
  DB.deleteNode(dAuthorNode.getPath());    
  DB.deleteNode(dDefinitionNode.getPath());    
end

-- remove leading \d+ and punctuation on text and return it
function stripLeadingNumbers(sText)
    local sStripped, sTextTrimmed = sText:match("^([%d%p?%s?]+)(.*)");
    if sStripped ~= nil and sStripped ~= "" then
      sText = sTextTrimmed;
    end
    return sText;
end