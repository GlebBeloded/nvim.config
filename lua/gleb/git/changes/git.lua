-- Changes Git requests run asynchronously in the panel's repository root.

local M = {}

local fs = require("gleb.file_tree.fs")

---@class ChangesGitState
---@field last_cmd? string[]

---@type ChangesGitState
M.state = {}

--- Refresh porcelain status for one Changes panel.
---@param root string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.refresh(root, callback)
	local command = {
		"git",
		"--no-optional-locks",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
	}
	M.state.last_cmd = command
	vim.system(command, { cwd = fs.normalize(root), text = true }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

return M
