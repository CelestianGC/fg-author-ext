---
---
---
---

-- This creates Chapter.Story entry blank stubs in bulk
function processBulkCreations()
  local nChapterCount = chaptercount.getValue() or 0;
  local nStoryCount = storycount.getValue() or 0;
  local nChapterStart = chapterstart.getValue() or 0;
  local nStoryStart = storystart.getValue() or 0;
  local bIncludeChapter = (storyincludechapter.getValue() == 0)

  for nChapter = nChapterStart, nChapterStart+nChapterCount-1 do
    local sChapterID = string.format("%02d",nChapter);
    for nStory = nStoryStart, nStoryStart+nStoryCount-1 do
      local nodeStory = DB.createChild('encounter');
      local sStoryID = string.format("%03d",nStory);
      local sStoryString = sChapterID .. "." .. sStoryID;
      if not bIncludeChapter then
        sStoryString = sStoryID;
      end
Debug.console("story_bulk_stubs.lua","processBulkCreations","Chapter.Story: ",sChapterID .. "." .. sStoryString);  
      DB.setValue(nodeStory,"name","string",sStoryString);
      DB.setCategory(nodeStory, sChapterID);
    end
  end

  ChatManager.SystemMessage("Created " .. nChapterCount .." chapters with " .. nStoryCount .. " story entries in each.");
end