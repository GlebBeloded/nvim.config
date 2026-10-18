-- Expanded project-tree folders persist per normalized root through atomic state-file replacement.

local M = {}

local SAVE_DEBOUNCE_MS = 500

---@class FileTreeExpandedState
---@field pending table<string, string[]>
---@field timer? uv.uv_timer_t
---@field sequence integer

---@type FileTreeExpandedState
M.state = { pending = {}, sequence = 0 }

---@return string
local function state_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
end

---@return table<string, string[]>
local function read_state()
	local path = state_path()
	local file = io.open(path, "r")
	if not file then
		return {}
	end
	local content = file:read("*a")
	file:close()
	local ok, decoded = pcall(vim.json.decode, content)
	return ok and type(decoded) == "table" and decoded or {}
end

---@param expanded table<string, boolean>
---@return string[]
local function sorted_paths(expanded)
	local paths = vim.tbl_keys(expanded)
	table.sort(paths)
	return paths
end

local function stop_timer()
	if M.state.timer then
		M.state.timer:stop()
		M.state.timer:close()
		M.state.timer = nil
	end
end

--- Write all queued roots while preserving roots most recently written by another view.
---@return nil
function M.flush()
	stop_timer()
	if next(M.state.pending) == nil then
		return
	end
	local stored = read_state()
	for root, paths in pairs(M.state.pending) do
		stored[root] = paths
	end
	local path = state_path()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	M.state.sequence = M.state.sequence + 1
	local temporary = ("%s.%d.%d.tmp"):format(path, vim.fn.getpid(), M.state.sequence)
	local ok = pcall(vim.fn.writefile, { vim.json.encode(stored) }, temporary, "b")
	if ok then
		ok = vim.uv.fs_rename(temporary, path) ~= nil
	end
	if ok then
		M.state.pending = {}
	else
		vim.uv.fs_unlink(temporary)
	end
end

---@param root string
---@param expanded table<string, boolean>
---@return nil
function M.save(root, expanded)
	M.state.pending[root] = sorted_paths(expanded)
	if not M.state.timer then
		M.state.timer = assert(vim.uv.new_timer())
	end
	M.state.timer:stop()
	M.state.timer:start(SAVE_DEBOUNCE_MS, 0, vim.schedule_wrap(M.flush))
end

--- Load one root's expansion set, omitting folders that no longer exist.
---@param root string
---@return table<string, boolean>
function M.load(root)
	local paths = M.state.pending[root] or read_state()[root] or {}
	local loaded = {}
	for _, relative in ipairs(paths) do
		local stat = vim.uv.fs_stat(vim.fs.joinpath(root, relative))
		if stat and stat.type == "directory" then
			loaded[relative] = true
		end
	end
	return loaded
end

--- Flush pending state and release the debounce timer.
---@return nil
function M.reset()
	M.flush()
	M.state = { pending = {}, sequence = 0 }
end

return M
