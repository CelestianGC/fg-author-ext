--
-- Contains code to manage "/author" command and "export" story entries (<encounters>) as chapter in a ref-manual
-- format. Each "category" in the <encounters> list is a chapter and the chapter contains those story entries.
--
--
function onInit()
    ChatManager.onSlashCommand = onSlashCommand;	
	if User.isHost() then
		Comm.registerSlashHandler("author", authorRefmanual);
    end
end

function authorRefmanual(sCommand, sParams)
	Interface.openWindow("author", "author");
end

function onSlashCommand(command, parameters)
	ChatManager.SystemMessage(Interface.getString("message_slashcommands"));
	ChatManager.SystemMessage("----------------");
	if User.isHost() then
		ChatManager.SystemMessage("/author");
		ChatManager.SystemMessage("/clear");
		ChatManager.SystemMessage("/console");
		ChatManager.SystemMessage("/day");
		ChatManager.SystemMessage("/die [NdN+N] <message>");
		ChatManager.SystemMessage("/emote [message]");
		ChatManager.SystemMessage("/export");
		ChatManager.SystemMessage("/exportchar");
		ChatManager.SystemMessage("/exportchar [name]");
		ChatManager.SystemMessage("/flushdb");
		ChatManager.SystemMessage("/gmid [name]");
		ChatManager.SystemMessage("/identity [name]");
		ChatManager.SystemMessage("/importchar");
		ChatManager.SystemMessage("/importnpc");
		ChatManager.SystemMessage("/lighting [RGB hex value]");
		ChatManager.SystemMessage("/mod [N] <message>");
		ChatManager.SystemMessage("/mood [mood] <message>");
		ChatManager.SystemMessage("/mood ([multiword mood]) <message>");
		ChatManager.SystemMessage("/ooc [message]");
		ChatManager.SystemMessage("/night");
		ChatManager.SystemMessage("/password <optional password>");
		ChatManager.SystemMessage("/reload");
		ChatManager.SystemMessage("/reply [message]");
		ChatManager.SystemMessage("/rollon [table name] <-c [column name]> <-d dice> <-hide>");
		ChatManager.SystemMessage("/save");
		ChatManager.SystemMessage("/scaleui [50-200]");
		ChatManager.SystemMessage("/story [message]");
		ChatManager.SystemMessage("/vote <message>");
		ChatManager.SystemMessage("/whisper [character] [message]");
	else
		ChatManager.SystemMessage("/action [message]");
		ChatManager.SystemMessage("/afk");
		ChatManager.SystemMessage("/console");
		ChatManager.SystemMessage("/die [NdN+N] <message>");
		ChatManager.SystemMessage("/emote [message]");
		ChatManager.SystemMessage("/mod [N] <message>");
		ChatManager.SystemMessage("/mood [mood] <message>");
		ChatManager.SystemMessage("/mood ([multiword mood]) <message>");
		ChatManager.SystemMessage("/ooc [message]");
		ChatManager.SystemMessage("/reply [message]");
		ChatManager.SystemMessage("/rollon [table name] <-c [column name]> <-d dice> <-hide>");
		ChatManager.SystemMessage("/save");
		ChatManager.SystemMessage("/scaleui [50-200]");
		ChatManager.SystemMessage("/vote <message>");
		ChatManager.SystemMessage("/whisper GM [message]");
		ChatManager.SystemMessage("/whisper [character] [message]");
	end
end
