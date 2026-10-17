-- The project-tree view coordinates setup now and will own its per-tab windows and buffers.

local M = {}

--- Set up project-tree rendering.
---@return nil
function M.setup()
	require("gleb.file_tree.render").setup()
end

return M
