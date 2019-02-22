-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- Export structures
local aProperties = {};
local aNodes = {};
local aTokens = {};

function addExportNode(nodeSource, sTargetPath, sExportType, sExportLabel, sExportListClass, sExportRootPath)
	-- Create reference node
	if aProperties.readonly then
		if not aNodes["reference"] then
			aNodes["reference"] = { static = true };
		end
	end
	
	-- Create node entry
	local rNodeExport = {};
	
	rNodeExport.import = nodeSource.getNodeName();
	rNodeExport.category = nodeSource.getCategory();
	
	aNodes[sTargetPath] = rNodeExport;

	if (sExportType or "") == "" then return; end
	if (sExportListClass or "") == "" then return; end
	
	-- Create library index
	local sLibraryNode = "library." .. aProperties.namecompact;
	if not aNodes[sLibraryNode] then
		local aLibraryIndex = {};
		aLibraryIndex.createstring = { name = aProperties.namecompact, categoryname = aProperties.category };
		aLibraryIndex.static = true;
		aNodes[sLibraryNode] = aLibraryIndex;
	end

	-- Create library entry
	local sLibraryEntry = sLibraryNode .. ".entries." .. sExportType;
	if not aNodes[sLibraryEntry] then
		if sExportListClass == "reference_list" then
			local aLibraryEntry = {};
			aLibraryEntry.createstring = { name = sExportLabel, recordtype = sExportType };
			aLibraryEntry.createlink = { librarylink = { class = sExportListClass, recordname = ".." } };
			
			aNodes[sLibraryEntry] = aLibraryEntry;
		else
			local aLibraryEntry = {};
			aLibraryEntry.createstring = { name = sExportLabel };
			aLibraryEntry.createlink = { librarylink = { class = sExportListClass, recordname = sExportRootPath } };
			
			aNodes[sLibraryEntry] = aLibraryEntry;
		end
	end
end

function performClear()
	file.setValue("");
	thumbnail.setValue("");
	name.setValue("");
	category.setValue("");
	author.setValue("");
	for _,cw in ipairs(list.getWindows()) do
		cw.all.setValue(0);
		cw.entries.closeAll();
	end
	tokens.closeAll();
end

function performExport()
  -- run custom pre-export functions if exist.
  AuthorManagerADND.OnExportEvent(list); 
  
	-- Reset data
	aProperties = {};
	aNodes = {};
	aTokens = {};

	-- Global properties
	aProperties.name = name.getValue();
	aProperties.namecompact = aProperties.name:gsub("%W", ""):lower();
	aProperties.category = category.getValue();
	aProperties.file = file.getValue();
	aProperties.author = author.getValue();
	aProperties.thumbnail = thumbnail.getValue();
	if readonly.getValue() == 1 then
		aProperties.readonly = true;
	end
	aProperties.playervisible = (playervisible.getValue() == 1);

	-- Pre checks
	if aProperties.name == "" then
		ChatManager.SystemMessage(Interface.getString("export_error_name"));
		name.setFocus(true);
		return;
	end
	if aProperties.file == "" then
		ChatManager.SystemMessage(Interface.getString("export_error_file"));
		file.setFocus(true);
		return;
	end
	
	-- Loop through categories
	for _, cw in ipairs(list.getWindows()) do
    local aExportSources = cw.getSources();
		local aExportTargets;
		if aProperties.readonly then
			aExportTargets = cw.getRefTargets();
		else
			aExportTargets = cw.getTargets();
		end
		if #aExportSources > 0 and #aExportSources == #aExportTargets then
			-- Construct export lists
			if cw.all.getValue() == 1 then
				-- Add all child nodes
				for kSource,vSource in ipairs(aExportSources) do
					local nodeSource = DB.findNode(vSource);
					if nodeSource then
						for _,nodeChild in pairs(nodeSource.getChildren()) do
							if nodeChild.getType() == "node" then
								local sTargetPath = nodeChild.getNodeName():gsub("^" .. vSource, aExportTargets[kSource]);
                -- Extra Author parts --celestian
                -- find the export entry if it exists
                local rExport = getExportEntry(vSource);
                local sLibraryEntry = cw.getExportListClass();
                -- if export entry has sLibraryEntry then use it
                if rExport.sLibraryEntry and rExport.sLibraryEntry ~= "" then
                  sLibraryEntry = rExport.sLibraryEntry;
                end
                --- that allows you to create a library class of reference_manual
--Debug.console("export_author.lua","performExport","vSource",vSource);                
--Debug.console("export_author.lua","performExport","cw",cw);      
-- Debug.console("export_author.lua","performExport","nodeChild",nodeChild);                
-- Debug.console("export_author.lua","performExport","sTargetPath",sTargetPath);            
-- Debug.console("export_author.lua","performExport","cw.getExportType()",cw.getExportType());                
-- Debug.console("export_author.lua","performExport","cw.label.getValue()",cw.label.getValue());                
-- Debug.console("export_author.lua","performExport","sLibraryEntry",sLibraryEntry);                
-- Debug.console("export_author.lua","performExport","aExportTargets[1]",aExportTargets[1]);     
--Debug.console("export_author.lua","performExport","aNodes[sTargetPath]",aNodes[sTargetPath]);   
                addExportNode(nodeChild, sTargetPath, cw.getExportType(), cw.label.getValue(), sLibraryEntry, aExportTargets[1]);
							end
						end
					end
				end
			else
				-- Loop through entries in category
				for _, ew in ipairs(cw.entries.getWindows()) do
					local node = ew.getDatabaseNode();
					local sTargetPath = node.getNodeName();
--Debug.console("export_author.lua","performExport","ew sTargetPath",sTargetPath);    
					for kSource,vSource in ipairs(aExportSources) do
						if sTargetPath:match("^" .. vSource) then
							sTargetPath = sTargetPath:gsub("^" .. vSource, aExportTargets[kSource]);
							break;
						end
					end
					addExportNode(node, sTargetPath, cw.getExportType(), cw.label.getValue(), cw.getExportListClass(), aExportTargets[1]);
				end
			end
		end
	end
	
	-- Tokens
	for _, tw in ipairs(tokens.getWindows()) do
		table.insert(aTokens, tw.token.getPrototype());
	end
	
	-- Export
	local bRet = Module.export(aProperties.name, aProperties.category, aProperties.author, aProperties.file, aProperties.thumbnail,	aNodes, aTokens, aProperties.playervisible);
	
	if bRet then
		ChatManager.SystemMessage(Interface.getString("export_message_success"));
	else
		ChatManager.SystemMessage(Interface.getString("export_message_failure"));
	end
end

-- search the ExportManager.aExport table for the node name and get the extra values we need.
--ExportManager.registerExportNode({ name = "_authorRefmanual", class = "reference_manual", label = "Reference Manual", export="reference", exportref="EXPORTREF", sLibraryEntry="someLinkTest"});
function getExportEntry(sName) 
  local rExport = {};
	for k,v in pairs(ExportManager.aExport) do
		if string.upper(v.name) == string.upper(sName) then
-- Debug.console("export_author.lua","getExportEntry","v.name",v.name);                
-- Debug.console("export_author.lua","getExportEntry","v.class",v.class);                
-- Debug.console("export_author.lua","getExportEntry","v.label",v.label);            
-- Debug.console("export_author.lua","getExportEntry","v.label",v.label);                
-- Debug.console("export_author.lua","getExportEntry","v.export",v.export);                
-- Debug.console("export_author.lua","getExportEntry","v.exportref",v.exportref);                
-- Debug.console("export_author.lua","getExportEntry","v.sLibraryEntry",v.sLibraryEntry);                
			--nIndex = k;
      rExport.name = v.name;
      rExport.class = v.class;
      rExport.label = v.label;
      rExport.export = v.export;
      rExport.exportref = v.exportref;
      rExport.sLibraryEntry = v.sLibraryEntry; -- need this
		end
	end
  return rExport;
end