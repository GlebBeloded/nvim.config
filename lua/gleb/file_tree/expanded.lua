-- Expanded project-tree folders persist per normalized root through atomic state-file replacement.

local M = {}

local SAVE_DEBOUNCE_MS = 500

---@class FileTreeExpandedState
---@field pending table<string, string[]>
---@field timer? uv.uv_timer_t
---@field sequence integer
---@field writing boolean
---@field stored? table<string, string[]>
---@field loading boolean
---@field waiters function[]

---@type FileTreeExpandedState
M.state = { pending = {}, sequence = 0, writing = false, loading = false, waiters = {} }

---@return string
local function state_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
end

---@param callback fun(stored: table<string, string[]>)
local function read_state(callback)
	local path = state_path()
	vim.uv.fs_open(path, "r", 420, function(open_error, file)
		if open_error or not file then
			vim.schedule(function()
				callback({})
			end)
			return
		end
		vim.uv.fs_fstat(file, function(stat_error, stat)
			if stat_error or not stat then
				vim.uv.fs_close(file, function()
					vim.schedule(function()
						callback({})
					end)
				end)
				return
			end
			vim.uv.fs_read(file, stat.size, 0, function(read_error, content)
				vim.uv.fs_close(file, function()
					vim.schedule(function()
						local ok, decoded = pcall(vim.json.decode, read_error and "" or content or "")
						callback(ok and type(decoded) == "table" and decoded or {})
					end)
				end)
			end)
		end)
	end)
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

---@param path string
---@param content string
---@param callback fun(ok: boolean)
local function replace_file(path, content, callback)
	local directory = vim.fs.dirname(path)
	local temporary = ("%s.%d.%d.tmp"):format(path, vim.fn.getpid(), M.state.sequence)
	vim.uv.fs_mkdir(directory, 493, function()
		vim.uv.fs_open(temporary, "w", 420, function(open_error, file)
			if open_error or not file then
				vim.schedule(function()
					callback(false)
				end)
				return
			end
			vim.uv.fs_write(file, content, 0, function(write_error)
				vim.uv.fs_close(file, function(close_error)
					if write_error or close_error then
						vim.uv.fs_unlink(temporary)
						vim.schedule(function()
							callback(false)
						end)
						return
					end
					vim.uv.fs_rename(temporary, path, function(rename_error)
						vim.schedule(function()
							callback(not rename_error)
						end)
					end)
				end)
			end)
		end)
	end)
end

local function write_pending()
	local state = M.state
	if state.writing or next(state.pending) == nil then
		return
	end
	state.writing = true
	state.sequence = state.sequence + 1
	local sequence = state.sequence
	local snapshot = vim.deepcopy(state.pending)
	read_state(function(stored)
		if M.state ~= state then
			return
		end
		for root, paths in pairs(snapshot) do
			stored[root] = paths
		end
		replace_file(state_path(), vim.json.encode(stored), function(ok)
			if M.state ~= state or sequence ~= state.sequence then
				return
			end
			state.writing = false
			if ok then
				state.stored = stored
				for root, paths in pairs(snapshot) do
					if vim.deep_equal(state.pending[root], paths) then
						state.pending[root] = nil
					end
				end
			end
			if ok and next(state.pending) ~= nil then
				write_pending()
			end
		end)
	end)
end

--- Write all queued roots while preserving roots most recently written by another view.
---@return nil
function M.flush()
	stop_timer()
	write_pending()
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
---@param paths string[]
---@return table<string, boolean>
local function valid_paths(root, paths)
	local loaded = {}
	for _, relative in ipairs(paths) do
		local stat = vim.uv.fs_stat(vim.fs.joinpath(root, relative))
		if stat and stat.type == "directory" then
			loaded[relative] = true
		end
	end
	return loaded
end

---@param root string
---@param callback? fun(expanded: table<string, boolean>)
---@return table<string, boolean>
function M.load(root, callback)
	local paths = M.state.pending[root] or (M.state.stored and M.state.stored[root])
	if paths then
		local loaded = valid_paths(root, paths)
		if callback then
			vim.schedule(function()
				callback(loaded)
			end)
		end
		return loaded
	end
	if callback then
		M.state.waiters[#M.state.waiters + 1] = function(stored)
			callback(valid_paths(root, stored[root] or {}))
		end
	end
	if not M.state.loading then
		local state = M.state
		state.loading = true
		read_state(function(stored)
			if M.state ~= state then
				return
			end
			state.loading = false
			state.stored = stored
			local waiters = state.waiters
			state.waiters = {}
			for _, waiter in ipairs(waiters) do
				waiter(stored)
			end
		end)
	end
	return {}
end

--- Flush pending state and release the debounce timer.
---@return nil
function M.reset()
	M.flush()
	M.state = { pending = {}, sequence = 0, writing = false, loading = false, waiters = {} }
end

return M
