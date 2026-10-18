-- Non-recursive libuv watches invalidate only changed scans and coalesce redraws from event bursts.

local M = {}

local fs = require("gleb.file_tree.fs")

local WATCH_DEBOUNCE_MS = 100

M.MAX_WATCH_HANDLES = 256

---@class FileTreeWatchRoot
---@field handles table<string, uv.uv_fs_event_t>
---@field timers table<string, uv.uv_timer_t>
---@field git_handle? uv.uv_fs_event_t
---@field git_dir? string
---@field toplevel? string
---@field refs integer
---@field clients table<integer, FileTreeWatchClient>

---@class FileTreeWatchClient
---@field paths table<string, boolean>
---@field redraw fun(path: string)
---@field refresh_git fun()

---@class FileTreeWatchState
---@field roots table<string, FileTreeWatchRoot>

---@type FileTreeWatchState
M.state = { roots = {} }

---@param root string
---@param path string
local function queue_redraw(root, path)
	local state = M.state.roots[root]
	if not state then
		return
	end
	local timer = state.timers[path]
	if not timer then
		timer = assert(vim.uv.new_timer())
		state.timers[path] = timer
	end
	timer:stop()
	timer:start(
		WATCH_DEBOUNCE_MS,
		0,
		vim.schedule_wrap(function()
			if M.state.roots[root] == state then
				fs.invalidate(path)
				if not vim.uv.fs_stat(path) then
					fs.invalidate(vim.fs.dirname(path))
				end
				local refresh_git
				for _, client in pairs(state.clients) do
					client.redraw(path)
					refresh_git = refresh_git or client.refresh_git
				end
				if refresh_git then
					refresh_git()
				end
			end
		end)
	)
end

---@param root string
---@param path string
---@param state FileTreeWatchRoot
local function watch_folder(root, path, state)
	local handle = assert(vim.uv.new_fs_event())
	local ok = handle:start(path, {}, function(error)
		if not error then
			queue_redraw(root, path)
		end
	end)
	if ok then
		state.handles[path] = handle
	else
		handle:close()
	end
end

---@param root string
---@param state FileTreeWatchRoot
local function watch_git_dir(root, state)
	local result = vim.system(
		{ "git", "-C", root, "rev-parse", "--show-toplevel", "--absolute-git-dir" },
		{ text = true }
	)
		:wait()
	if result.code ~= 0 then
		return
	end
	local lines = vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })
	local path = lines[2]
	if not path then
		return
	end
	state.toplevel = lines[1]
	state.git_dir = path
	local handle = assert(vim.uv.new_fs_event())
	local ok = handle:start(path, {}, function(error)
		if not error then
			vim.schedule(function()
				local _, client = next(state.clients)
				if client then
					client.refresh_git()
				end
			end)
		end
	end)
	if ok then
		state.git_handle = handle
	else
		handle:close()
	end
end

---@param state FileTreeWatchRoot
---@param path string
local function close_folder(state, path)
	local handle = state.handles[path]
	if handle then
		handle:stop()
		handle:close()
		state.handles[path] = nil
	end
	local timer = state.timers[path]
	if timer then
		timer:stop()
		timer:close()
		state.timers[path] = nil
	end
end

---@param root string
---@param owner integer
---@return nil
function M.start_root(root, owner)
	local state = M.state.roots[root]
	if state then
		if not state.clients[owner] then
			state.refs = state.refs + 1
			state.clients[owner] = { paths = {}, redraw = function() end, refresh_git = function() end }
		end
		return
	end
	state = {
		handles = {},
		timers = {},
		refs = 1,
		clients = { [owner] = { paths = {}, redraw = function() end, refresh_git = function() end } },
	}
	M.state.roots[root] = state
	watch_git_dir(root, state)
end

---@param root string
---@param state FileTreeWatchRoot
local function sync_handles(root, state)
	local paths = {}
	for _, client in pairs(state.clients) do
		for path in pairs(client.paths) do
			paths[path] = true
		end
	end

	local ordered = vim.tbl_keys(paths)
	table.sort(ordered, function(left, right)
		if left == root then
			return true
		end
		if right == root then
			return false
		end
		return left < right
	end)
	local wanted = {}
	for index = 1, math.min(#ordered, M.MAX_WATCH_HANDLES) do
		wanted[ordered[index]] = true
	end
	for path in pairs(state.handles) do
		if not wanted[path] then
			close_folder(state, path)
		end
	end
	for path in pairs(wanted) do
		if not state.handles[path] then
			watch_folder(root, path, state)
		end
	end
end

--- Watch every directory scan currently feeding one view's visible rows.
---@param root string
---@param owner integer
---@param paths table<string, boolean>
---@param redraw fun(path: string)
---@param refresh_git fun()
---@return nil
function M.sync(root, owner, paths, redraw, refresh_git)
	local state = assert(M.state.roots[root], "watch root was not started")
	local client = assert(state.clients[owner], "watch root owner was not started")
	client.paths = paths
	client.redraw = redraw
	client.refresh_git = refresh_git
	sync_handles(root, state)
end

--- Release one tree's ownership of a normalized root.
---@param root string
---@param owner integer
---@return nil
function M.stop_root(root, owner)
	local state = M.state.roots[root]
	if not state or not state.clients[owner] then
		return
	end
	state.clients[owner] = nil
	state.refs = state.refs - 1
	if state.refs > 0 then
		sync_handles(root, state)
		return
	end
	for path in pairs(state.handles) do
		close_folder(state, path)
	end
	if state.git_handle then
		state.git_handle:stop()
		state.git_handle:close()
	end
	M.state.roots[root] = nil
	fs.invalidate_root(root)
end

--- Stop every active filesystem handle while retaining registered views.
---@return nil
function M.stop_all()
	for _, state in pairs(M.state.roots) do
		for path in pairs(state.handles) do
			close_folder(state, path)
		end
		if state.git_handle then
			state.git_handle:stop()
			state.git_handle:close()
			state.git_handle = nil
		end
	end
end

--- Stop and remove every watch.
---@return nil
function M.reset()
	for root, state in pairs(M.state.roots) do
		for owner in pairs(state.clients) do
			M.stop_root(root, owner)
		end
	end
	M.state = { roots = {} }
end

return M
