-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
local node = getDatabaseNode();
--Debug.console("masterindexitem_name.lua","onInit","node",node);
  if (node.getPath():match("^encounter%.")) then
    local nodeStory = node.getParent();
    DB.addHandler(DB.getPath(nodeStory, "subchapter"), "onUpdate", onSubchapterChanged);
    onSubchapterChanged();
  end
end

function onClose()
  local node = getDatabaseNode();
  if (node.getPath():match("^encounter%.")) then
    local nodeStory = node.getParent();
    DB.removeHandler(DB.getPath(nodeStory, "subchapter"), "onUpdate", onSubchapterChanged);
  end
end
function onSubchapterChanged()
  local node = getDatabaseNode();
  local nodeStory = node.getParent();
  local bSubChapter = (DB.getValue(nodeStory,"subchapter",0) == 1);
  if bSubChapter then -- change to purple
    setColor("6715B0");
  else
    setColor("000000"); -- otherwise set black
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
	draginfo.setDescription(getValue());
	return true;
end
