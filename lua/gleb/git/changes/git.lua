-- Changes Git requests run asynchronously in the panel's repository root.

local M = {}

local fs = require("gleb.file_tree.fs")
local file_tree_model = require("gleb.file_tree.model")

---@class ChangesGitState
---@field last_cmd? string[]

---@type ChangesGitState
M.state = {}

--- Resolve the repository containing a directory.
---@param dir string
---@param callback fun(result: vim.SystemCompleted, root: string?)
---@return nil
function M.resolve_root(dir, callback)
	local command = { "git", "rev-parse", "--show-toplevel" }
	vim.system(command, { cwd = fs.normalize(dir), text = true }, function(result)
		vim.schedule(function()
			local root = result.code == 0 and fs.normalize(vim.trim(result.stdout or "")) or nil
			callback(result, root)
		end)
	end)
end

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

---@param records FileTreeStatusRecord[]
---@return boolean
local function fully_staged(records)
	if #records == 0 then
		return false
	end
	for _, record in ipairs(records) do
		local xy = record.xy or ".."
		if record.kind == "?" or xy:sub(1, 1) == "." or xy:sub(2, 2) ~= "." then
			return false
		end
	end
	return true
end

---@param root string
---@param path string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.toggle_stage(root, path, callback)
	root = fs.normalize(root)
	path = fs.normalize(path)
	local status_command = {
		"git",
		"--literal-pathspecs",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
		"--",
		path,
	}
	M.state.last_cmd = status_command
	vim.system(status_command, { cwd = root, text = true }, function(status_result)
		vim.schedule(function()
			if status_result.code ~= 0 then
				callback(status_result)
				return
			end
			local operation = fully_staged(file_tree_model.parse_status_records(status_result.stdout or "")) and "reset"
				or "add"
			local command = { "git", "--literal-pathspecs", operation }
			if operation == "reset" then
				command[#command + 1] = "-q"
			end
			vim.list_extend(command, { "--", path })
			M.state.last_cmd = command
			vim.system(command, { cwd = root, text = true }, function(result)
				vim.schedule(function()
					callback(result)
				end)
			end)
		end)
	end)
end

return M
