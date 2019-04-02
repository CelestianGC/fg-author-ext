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

  for nChapter = nChapterStart, nChapterCount do
    local sChapterString = string.format("%02d",nChapter);
    for nStory = nStoryStart, nStoryCount do
      local nodeStory = DB.createChild('encounter');
      local sStoryString = string.format("%03d",nStory);
Debug.console("story_bulk_stubs.lua","processBulkCreations","Chapter.Story: ",sChapterString .. "." .. sStoryString);  
      DB.setValue(nodeStory,"name","string",sChapterString .. "." .. sStoryString);
      DB.setCategory(nodeStory, sChapterString);
    end
  end

  ChatManager.SystemMessage("Created " .. nChapterCount .." chapters with " .. nStoryCount .. " story entries in each.");
end