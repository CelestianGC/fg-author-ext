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
    local nodeChapter = DB.createChild(nodeChapters);
    DB.setValue(nodeChapter,"name","string",aProperties.name);
    local nodeSubChapters = DB.createChild(nodeChapter,"subchapters");
    -- flip through all categories, create sub per category and and entries within category
    for _,nodeCategory in pairs(sortByName(dStoryCategories.getChildren())) do
        -- create subchapter node and set name
        local nodeSubChapter = DB.createChild(nodeSubChapters);
        local sChapterName = DB.getValue(nodeCategory,"name","EMPTY-CATEGORY-NAME");
        sChapterName = stripLeadingNumbers(sChapterName);
        DB.setValue(nodeSubChapter,"name","string",sChapterName);
        for _,nodeStory in pairs(sortByName(nodeCategory.getChildren())) do
            -- create refpages node and current node to work on and set name/links
            local dRefPages = DB.createChild(nodeSubChapter,"refpages");
            local sNodeName = DB.getValue(nodeStory,"name","");
            if (sNodeName ~= "") then
--Debug.console("author.lua","performExport","sNodeName",sNodeName);            
                sNodeName = stripLeadingNumbers(sNodeName);
                local nodeRefPage = DB.createChild(dRefPages);
                DB.setValue(nodeRefPage,"name","string",sNodeName);
                DB.setValue(nodeRefPage,"keywords","string",sNodeName);
                local sLinkClass = "reference_manualtextwide";
                local sLinkRecord = "..";
                DB.setValue(nodeRefPage,"listlink","windowreference",sLinkClass,sLinkRecord);
                -- create block node and set text from story
                local dBlocks = DB.createChild(nodeRefPage,"blocks");
                --local nodeBlock = DB.createChild(dBlocks,"block");
                local nodeBlock = DB.createChild(dBlocks);
                DB.setValue(nodeBlock,"text","formattedtext",DB.getValue(nodeStory,"text","EMPTY-STORY-TEXT"));
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
    if (sFile ~= nil) then 
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
    DB.deleteNode(dRoot);
    DB.deleteNode(dAuthorNode);    
    DB.deleteNode(dDefinitionNode);    
end

-- remove leading \d+ and punctuation on text and return it
function stripLeadingNumbers(sText)
    local sStripped, sTextTrimmed = sText:match("^([%d%p?%s?]+)(.*)");
    if sStripped ~= nil and sStripped ~= "" then
        sText = sTextTrimmed;
    end
    return sText;
end