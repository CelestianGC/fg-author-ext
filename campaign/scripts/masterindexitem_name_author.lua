-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

sDefaultColor = "000000";
sHightlightColor = "6715B0";
function onInit()
local node = getDatabaseNode();
  --sDefaultColor = getColor();
--Debug.console("masterindexitem_name.lua","onInit","self",self);
--Debug.console("masterindexitem_name.lua","onInit","sDefaultColor",sDefaultColor);
--Debug.console("masterindexitem_name.lua","onInit","node",node);
  if (node.getPath():match("^encounter%.")) then
    updateColorsForTheme();
    local nodeStory = node.getParent();
    DB.addHandler(DB.getPath(nodeStory, "subchapter"), "onUpdate", onSubchapterChanged);
    DB.addHandler("options.ADND_AUTHOR_DARKTHEME", "onUpdate", updateColorsForTheme);
    onSubchapterChanged();
  end
end

function updateColorsForTheme()
  local node = getDatabaseNode();
 if OptionsManager.isOption("ADND_AUTHOR_DARKTHEME", "enabled") then
  sDefaultColor = "EEEEEE";
  sHightlightColor = "EFA177";
 else
  sDefaultColor = "000000";
  sHightlightColor = "6715B0";
  end
  onSubchapterChanged();
end

function onClose()
  local node = getDatabaseNode();
  if (node.getPath():match("^encounter%.")) then
    local nodeStory = node.getParent();
    DB.removeHandler(DB.getPath(nodeStory, "subchapter"), "onUpdate", onSubchapterChanged);
    DB.removeHandler("options.ADND_AUTHOR_DARKTHEME", "onUpdate", updateColorsForTheme);
  end
end
function onSubchapterChanged()
  local node = getDatabaseNode();
  if (node.getPath():match("^encounter%.")) then
    local nodeStory = node.getParent();
    local bSubChapter = (DB.getValue(nodeStory,"subchapter",0) == 1);
    if bSubChapter then -- change to purple
      setColor(sHightlightColor);
    else
      setColor(sDefaultColor); -- otherwise set black
    end
  end
end

function onHover(bHover)
	setUnderline(bHover, -1);
end

function onClickDown(button, x, y)
	return true;
end

function onClickRelease(button, x, y)
	window.link.activate();
	return true;
end

function onDragStart(button, x, y, draginfo)
	draginfo.setType("shortcut");
	draginfo.setIcon("button_link");
	local sClass, sRecord = window.link.getValue();
	draginfo.setShortcutData(sClass, sRecord);
Debug.console("masterindexitem_name.lua","onDragStart","sClass",sClass);  
  if LibraryData.getRecordTypeFromPath(sClass) ~= "" then
    draginfo.setDescription(StringManager.capitalize(LibraryData.getRecordTypeFromPath(sClass)) .. ": " .. getValue());
  elseif LibraryData.getDisplayText(sClass) ~= "" then
    draginfo.setDescription(LibraryData.getDisplayText(sClass) .. ": " .. getValue());
  elseif getRecordTypeFromDisplayClass(sClass) ~= "" then
    draginfo.setDescription(StringManager.capitalize(getRecordTypeFromDisplayClass(sClass)) .. ": " .. getValue());
  elseif getRecordTypeFromDataMap(sClass) ~= "" then
    draginfo.setDescription(StringManager.capitalize(getRecordTypeFromDataMap(sClass)) .. ": " .. getValue());
  else
    draginfo.setDescription(getValue());
  end
	return true;
end

-- various utility functions to get readable/useful tags for dragged links.
function getRecordTypeFromDisplayClass(sDisplayClass)
  for kRecordType,vRecord in pairs(LibraryData.aRecords) do
    if vRecord.sRecordDisplayClass and vRecord.sRecordDisplayClass == sDisplayClass then
      return kRecordType;
    end
  end
  return "";
end
function getRecordTypeFromDataMap(sDataMap)
	for kRecordType,vRecord in pairs(aRecords) do
		if vRecord.aDataMap then
      for i=1,#vRecord.aDataMap do 
        if vRecord.aDataMap[i] == sDataMap then
          return kRecordType;
        end
      end
		end
	end
	return "";
end