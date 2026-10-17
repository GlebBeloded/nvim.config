-- Async Git status snapshots let filesystem events recolour project-tree rows without blocking redraws.

local M = {}

---@class FileTreeGitRoot
---@field status table<string, string>
---@field refs integer
---@field callbacks table<integer, fun()>

---@class FileTreeGitState
---@field roots table<string, FileTreeGitRoot>

---@type FileTreeGitState
M.state = { roots = {} }

---@param output string
---@return table<string, string>
local function parse_status(output)
	local status = {}
	for _, record in ipairs(vim.split(output, "\0", { plain = true, trimempty = true })) do
		local kind = record:sub(1, 1)
		if kind == "?" then
			status[record:sub(3)] = "untracked"
		elseif kind == "1" then
			local xy, path = record:match("^1 ([^ ]+) [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
			if xy and path then
				status[path] = xy:find("A", 1, true) and "added" or "modified"
			end
		end
	end
	return status
end

--- Return the latest status snapshot for a root.
---@param root string
---@return table<string, string>
function M.status(root)
	local state = M.state.roots[root]
	return state and state.status or {}
end

--- Retain one view's ownership of a root snapshot.
---@param root string
---@param owner integer
---@param callback fun()
---@return nil
function M.start_root(root, owner, callback)
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
	local state = assert(M.state.roots[root], "git root was not started")
	vim.system(
		{ "git", "--no-optional-locks", "-C", root, "status", "--porcelain=v2", "-z", "--untracked-files=normal" },
		{ text = true },
		function(result)
			vim.schedule(function()
				if M.state.roots[root] == state and result.code == 0 then
					state.status = parse_status(result.stdout or "")
					for _, callback in pairs(state.callbacks) do
						callback()
					end
				end
			end)
		end
	)
end

--- Clear Git status state.
---@return nil
function M.reset()
	M.state = { roots = {} }
end

return M
