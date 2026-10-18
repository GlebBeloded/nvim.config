-- Async Git status snapshots let filesystem events recolour project-tree rows without blocking redraws.

local M = {}

local fs = require("gleb.file_tree.fs")
local model = require("gleb.file_tree.model")

local GIT_DEBOUNCE_MS = 150

---@class FileTreeGitRoot
---@field status table<string, string>
---@field ignored table<string, boolean>
---@field ignored_generation integer
---@field refs integer
---@field callbacks table<integer, fun()>
---@field generation integer
---@field in_flight boolean
---@field dirty boolean
---@field timer? uv.uv_timer_t

---@class FileTreeGitState
---@field roots table<string, FileTreeGitRoot>
---@field last_cmd? string[]
---@field runs integer

---@type FileTreeGitState
M.state = { roots = {}, runs = 0 }

---@param output string
---@param prefix string
---@return table<string, string> status
---@return table<string, boolean> ignored
local function parse_status(output, prefix)
	return model.parse_status(output, prefix)
end

---@param left table<string, boolean>
---@param right table<string, boolean>
---@return boolean
local function equal_sets(left, right)
	for path in pairs(left) do
		if not right[path] then
			return false
		end
	end
	for path in pairs(right) do
		if not left[path] then
			return false
		end
	end
	return true
end

--- Return the latest status snapshot for a root.
---@param root string
---@return table<string, string>
function M.status(root)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	return state and state.status or {}
end

--- Return the latest ignored snapshot for a root.
---@param root string
---@return table<string, boolean>
function M.ignored(root)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	return state and state.ignored or {}
end

--- Return the ignored snapshot generation for a root.
---@param root string
---@return integer
function M.ignored_generation(root)
	root = fs.normalize(root)
	local state = M.state.roots[root]
	return state and state.ignored_generation or 0
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
		state = {
			status = {},
			ignored = {},
			ignored_generation = 0,
			refs = 0,
			callbacks = {},
			generation = 0,
			in_flight = false,
			dirty = false,
		}
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
		if state.timer then
			state.timer:stop()
			state.timer:close()
		end
		M.state.roots[root] = nil
	end
end

---@param root string
---@param state FileTreeGitRoot
local function run(root, state)
	state.timer = nil
	state.in_flight = true
	local generation = state.generation
	local command = {
		"git",
		"--no-optional-locks",
		"-C",
		root,
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=normal",
		"--ignored=matching",
	}
	M.state.last_cmd = command
	M.state.runs = M.state.runs + 1
	vim.system({ "git", "-C", root, "rev-parse", "--show-prefix" }, { text = true }, function(prefix_result)
		local prefix = vim.trim(prefix_result.stdout or "")
		vim.system(command, { text = true }, function(result)
			vim.schedule(function()
				if M.state.roots[root] ~= state then
					return
				end
				state.in_flight = false
				if prefix_result.code == 0 and result.code == 0 and generation == state.generation then
					local status, ignored = parse_status(result.stdout or "", prefix)
					state.status = status
					if not equal_sets(state.ignored, ignored) then
						state.ignored = ignored
						state.ignored_generation = state.ignored_generation + 1
					end
					for _, callback in pairs(state.callbacks) do
						callback()
					end
				end
				if state.dirty then
					state.dirty = false
					run(root, state)
				end
			end)
		end)
	end)
end

--- Refresh one root's status and redraw after the result is applied.
---@param root string
---@return nil
function M.request(root)
	root = fs.normalize(root)
	local state = assert(M.state.roots[root], "git root was not started")
	state.generation = state.generation + 1
	if state.in_flight then
		state.dirty = true
		return
	end
	if not state.timer then
		state.timer = assert(vim.uv.new_timer())
	end
	state.timer:stop()
	local generation = state.generation
	state.timer:start(
		GIT_DEBOUNCE_MS,
		0,
		vim.schedule_wrap(function()
			if M.state.roots[root] ~= state or generation ~= state.generation or not state.timer then
				return
			end
			state.timer:stop()
			state.timer:close()
			run(root, state)
		end)
	)
end

--- Start one root's status refresh without the watcher debounce.
---@param root string
---@return nil
function M.refresh(root)
	root = fs.normalize(root)
	local state = assert(M.state.roots[root], "git root was not started")
	state.generation = state.generation + 1
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end
	if state.in_flight then
		state.dirty = true
		return
	end
	run(root, state)
end

--- Clear Git status state.
---@return nil
function M.reset()
	for _, state in pairs(M.state.roots) do
		if state.timer then
			state.timer:stop()
			state.timer:close()
		end
	end
	M.state = { roots = {}, runs = 0 }
end

return M
