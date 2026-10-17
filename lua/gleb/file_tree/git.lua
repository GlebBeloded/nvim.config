-- Async Git status snapshots let filesystem events recolour project-tree rows without blocking redraws.

local M = {}

local fs = require("gleb.file_tree.fs")
local model = require("gleb.file_tree.model")

---@class FileTreeGitRoot
---@field status table<string, string>
---@field refs integer
---@field callbacks table<integer, fun()>

---@class FileTreeGitState
---@field roots table<string, FileTreeGitRoot>
---@field last_cmd? string[]

---@type FileTreeGitState
M.state = { roots = {} }

---@param output string
---@return table<string, string>
local function parse_status(output)
	local status = model.parse_status(output, "")
	local folders = {}
	for path in pairs(status) do
		local current = path:gsub("/+$", ""):match("^(.*)/[^/]+$")
		while current and current ~= "" do
			folders[current] = true
			current = current:match("^(.*)/[^/]+$")
		end
		if path:sub(-1) == "/" then
			folders[path:sub(1, -2)] = true
		end
	end
	for folder in pairs(folders) do
		status[folder] = model.folder_status(status, folder)
	end
	return status
end

--- Return the latest status snapshot for a root.
---@param root string
---@return table<string, string>
function M.status(root)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	return state and state.status or {}
end

--- Retain one view's ownership of a root snapshot.
---@param root string
---@param owner integer
---@param callback fun()
---@return nil
function M.start_root(root, owner, callback)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	if not state then
		state = { status = {}, refs = 0, callbacks = {} }
		M.state.roots[root] = state
	end
	if not state.callbacks[owner] then
		state.refs = state.refs + 1
	end
	state.callbacks[owner] = callback
end

--- Release one view's ownership of a root snapshot.
---@param root string
---@param owner integer
---@return nil
function M.stop_root(root, owner)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	if not state or not state.callbacks[owner] then
		return
	end
	state.callbacks[owner] = nil
	state.refs = state.refs - 1
	if state.refs == 0 then
		M.state.roots[root] = nil
	end
end

--- Refresh one root's status and redraw after the result is applied.
---@param root string
---@return nil
function M.request(root)
	root = fs.normalize(root)
	local state = assert(M.state.roots[root], "git root was not started")
	local command =
		{ "git", "--no-optional-locks", "-C", root, "status", "--porcelain=v2", "-z", "--untracked-files=normal" }
	M.state.last_cmd = command
	vim.system(command, { text = true }, function(result)
		vim.schedule(function()
			if M.state.roots[root] == state and result.code == 0 then
				state.status = parse_status(result.stdout or "")
				for _, callback in pairs(state.callbacks) do
					callback()
				end
			end
		end)
	end)
end

--- Clear Git status state.
---@return nil
function M.reset()
	M.state = { roots = {} }
end

return M
