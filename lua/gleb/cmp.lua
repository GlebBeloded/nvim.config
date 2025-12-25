-- Completion is now handled by blink.cmp (configured in plugins.lua)
-- This file kept for compatibility with init.lua require

-- To disable completion in comments, add this to blink.cmp opts in plugins.lua:
-- enabled = function()
--   return not require("blink.cmp.config").context_in_treesitter_capture("comment")
-- end,
