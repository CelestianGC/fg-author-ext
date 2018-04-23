--
-- Contains code to manage "/author" command and "export" story entries (<encounters>) as chapter in a ref-manual
-- format. Each "category" in the <encounters> list is a chapter and the chapter contains those story entries.
--
--
function onInit()
	if User.isHost() then
		Comm.registerSlashHandler("author", authorRefmanual);
  end
end

function authorRefmanual(sCommand, sParams)
	Interface.openWindow("author", "author");
end
