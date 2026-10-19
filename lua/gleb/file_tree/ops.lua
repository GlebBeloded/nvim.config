-- Project-tree operations expose stable entry points while delegating each filesystem responsibility.

local M = {}

local clipboard = require("gleb.file_tree.ops.clipboard")
local delete = require("gleb.file_tree.ops.delete")
local move = require("gleb.file_tree.ops.move")

M.state = clipboard.state

--- Move a batch only after every source and target passes preflight.
---@param move_pairs FileTreeMovePair[]
---@return boolean moved
function M.move(move_pairs)
	return move.move(move_pairs)
end

--- Prompt for and create a file or directory below the selected project-tree row.
---@return nil
function M.add()
	clipboard.add()
end

--- Prompt for and rename the selected project-tree entry.
---@return nil
function M.rename()
	move.rename()
end

--- Copy the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.copy(ctx)
	clipboard.copy(ctx)
end

--- Cut the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.cut(ctx)
	clipboard.cut(ctx)
end

--- Paste copied or cut project-tree entries into the selected folder.
---@return nil
function M.paste()
	clipboard.paste(M.move)
end

--- Rescan the current project-tree view and refresh Git status immediately.
---@return nil
function M.refresh()
	require("gleb.file_tree.view").refresh()
end

--- Confirm and delete the selected project-tree entries.
---@param ctx? gleb.ActionContext
---@return nil
function M.delete(ctx)
	delete.delete(ctx, M.state)
end

--- Reset operation state owned by this module.
---@return nil
function M.reset()
	clipboard.state = {}
	M.state = clipboard.state
end

return M
