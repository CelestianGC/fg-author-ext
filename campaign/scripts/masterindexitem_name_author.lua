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
  if LibraryData.getDisplayText(sClass) ~= "" then
    draginfo.setDescription(LibraryData.getDisplayText(sClass) .. ": " .. getValue());
  elseif LibraryData.getRecordTypeFromPath(sClass) ~= "" then
    draginfo.setDescription(StringManager.capitalize(LibraryData.getRecordTypeFromPath(sClass)) .. ": " .. getValue());
  else
    draginfo.setDescription(getValue());
  end
	return true;
end
