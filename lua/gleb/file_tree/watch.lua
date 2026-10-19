-- Non-recursive libuv watches invalidate only changed scans and coalesce redraws from event bursts.

local M = {}

local fs = require("gleb.file_tree.fs")

local WATCH_DEBOUNCE_MS = 100
local WATCH_BATCH_SIZE = 16
local FALLBACK_RESCAN_MS = 250

M.MAX_WATCH_HANDLES = 256

---@class FileTreeWatchRoot
---@field handles table<string, uv.uv_fs_event_t>
---@field timers table<string, uv.uv_timer_t>
---@field fallback_timer? uv.uv_timer_t
---@field git_handle? uv.uv_fs_event_t
---@field git_dir? string
---@field toplevel? string
---@field refs integer
---@field clients table<integer, FileTreeWatchClient>
---@field wanted table<string, boolean>
---@field wanted_order string[]
---@field sync_scheduled boolean
---@field discovery_complete boolean

---@class FileTreeWatchClient
---@field paths table<string, number>
---@field redraw fun(path: string)
---@field refresh_git fun()
---@field git_ready boolean
---@field repository_ready? fun(toplevel: string?)

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

--- Watch one directory's entries.
---@param path string
---@param on_change fun()
---@return uv.uv_fs_event_t?
local function watch_path(path, on_change)
	local handle = assert(vim.uv.new_fs_event())
	local ok = handle:start(path, {}, function(error)
		if not error then
			on_change()
		end
	end)
	if ok then
		return handle
	end
	handle:close()
end

---@param root string
---@param path string
---@param state FileTreeWatchRoot
local function watch_folder(root, path, state)
	state.handles[path] = watch_path(path, function()
		queue_redraw(root, path)
	end)
	return state.handles[path] ~= nil
end

---@param root string
---@param state FileTreeWatchRoot
local function watch_git_dir(root, state)
	vim.system(
		{ "git", "-C", root, "rev-parse", "--show-toplevel", "--absolute-git-dir" },
		{ text = true },
		function(result)
			vim.schedule(function()
				if M.state.roots[root] ~= state then
					return
				end
				state.discovery_complete = true
				if result.code == 0 then
					local lines = vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })
					local path = lines[2]
					if path then
						state.toplevel = lines[1]
						state.git_dir = path
						state.git_handle = watch_path(path, function()
							vim.schedule(function()
								if M.state.roots[root] == state then
									for _, client in pairs(state.clients) do
										client.refresh_git()
									end
								end
							end)
						end)
					end
				end
				for _, client in pairs(state.clients) do
					client.git_ready = state.git_dir ~= nil
					if client.repository_ready then
						client.repository_ready(state.toplevel)
					elseif state.git_dir then
						client.refresh_git()
					end
				end
			end)
		end
	)
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
---@param repository_ready? fun(toplevel: string?)
---@return nil
function M.start_root(root, owner, repository_ready)
	local state = M.state.roots[root]
	if state then
		if not state.clients[owner] then
			state.refs = state.refs + 1
			state.clients[owner] = {
				paths = {},
				redraw = function() end,
				refresh_git = function() end,
				git_ready = false,
				repository_ready = repository_ready,
			}
		end
		local client = state.clients[owner]
		if state.discovery_complete then
			client.git_ready = state.git_dir ~= nil
			vim.schedule(function()
				if M.state.roots[root] ~= state or state.clients[owner] ~= client then
					return
				end
				if client.repository_ready then
					client.repository_ready(state.toplevel)
				elseif state.git_dir then
					client.refresh_git()
				end
			end)
		end
		return
	end
	state = {
		handles = {},
		timers = {},
		refs = 1,
		clients = {
			[owner] = {
				paths = {},
				redraw = function() end,
				refresh_git = function() end,
				git_ready = false,
				repository_ready = repository_ready,
			},
		},
		wanted = {},
		wanted_order = {},
		sync_scheduled = false,
		discovery_complete = false,
	}
	M.state.roots[root] = state
	watch_git_dir(root, state)
end

--- Return the repository top level discovered for a watched root.
---@param root string
---@return string?
function M.toplevel(root)
	local state = M.state.roots[root]
	return state and state.toplevel or nil
end

---@param root string
---@param state FileTreeWatchRoot
local function wanted_paths(root, state)
	local priorities = {}
	for _, client in pairs(state.clients) do
		for path, priority in pairs(client.paths) do
			priorities[path] = math.min(priorities[path] or math.huge, priority)
		end
	end

	local ordered = vim.tbl_keys(priorities)
	table.sort(ordered, function(left, right)
		if left == root then
			return true
		end
		if right == root then
			return false
		end
		if priorities[left] ~= priorities[right] then
			return priorities[left] < priorities[right]
		end
		return left < right
	end)
	local wanted = {}
	for index = 1, math.min(#ordered, M.MAX_WATCH_HANDLES) do
		wanted[ordered[index]] = true
	end
	return wanted, vim.list_slice(ordered, 1, math.min(#ordered, M.MAX_WATCH_HANDLES))
end

---@param root string
---@param state FileTreeWatchRoot
---@param limit integer
---@return boolean pending
local function reconcile(root, state, limit)
	local changed = 0
	for path in pairs(state.handles) do
		if not state.wanted[path] then
			close_folder(state, path)
			changed = changed + 1
			if changed == limit then
				return true
			end
		end
	end
	for _, path in ipairs(state.wanted_order) do
		if not state.handles[path] and watch_folder(root, path, state) then
			changed = changed + 1
			if changed == limit then
				return true
			end
		end
	end
	return false
end

---@param root string
---@param state FileTreeWatchRoot
local function schedule_sync(root, state)
	if state.sync_scheduled then
		return
	end
	state.sync_scheduled = true
	vim.schedule(function()
		if M.state.roots[root] ~= state then
			state.sync_scheduled = false
			return
		end
		state.sync_scheduled = false
		if reconcile(root, state, WATCH_BATCH_SIZE) then
			schedule_sync(root, state)
		end
	end)
end

---@param root string
---@param state FileTreeWatchRoot
local function ensure_fallback_timer(root, state)
	if state.fallback_timer then
		return
	end
	local timer = assert(vim.uv.new_timer())
	state.fallback_timer = timer
	timer:start(
		FALLBACK_RESCAN_MS,
		FALLBACK_RESCAN_MS,
		vim.schedule_wrap(function()
			if M.state.roots[root] ~= state then
				return
			end
			state.wanted, state.wanted_order = wanted_paths(root, state)
			schedule_sync(root, state)
			local changed = {}
			for _, client in pairs(state.clients) do
				for path in pairs(client.paths) do
					if not state.handles[path] and changed[path] == nil then
						local before = fs.state.cache[path]
						fs.invalidate(path)
						changed[path] = before ~= nil and not vim.deep_equal(before, fs.scan(path))
					end
				end
			end
			for _, client in pairs(state.clients) do
				local refresh_git = false
				for path in pairs(client.paths) do
					if changed[path] then
						client.redraw(path)
						refresh_git = true
					end
				end
				if refresh_git then
					client.refresh_git()
				end
			end
		end)
	)
end

--- Watch every directory scan currently feeding one view's visible rows.
---@param root string
---@param owner integer
---@param paths table<string, number>
---@param redraw fun(path: string)
---@param refresh_git fun()
---@return nil
function M.sync(root, owner, paths, redraw, refresh_git)
	local state = assert(M.state.roots[root], "watch root was not started")
	local client = assert(state.clients[owner], "watch root owner was not started")
	client.paths = paths
	client.redraw = redraw
	client.refresh_git = refresh_git
	if state.git_dir and not client.git_ready then
		client.git_ready = true
		refresh_git()
	end
	state.wanted, state.wanted_order = wanted_paths(root, state)
	if next(client.paths) ~= nil and next(state.handles) == nil then
		reconcile(root, state, WATCH_BATCH_SIZE)
	end
	schedule_sync(root, state)
	ensure_fallback_timer(root, state)
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
		state.wanted, state.wanted_order = wanted_paths(root, state)
		schedule_sync(root, state)
		return
	end
	if state.fallback_timer then
		state.fallback_timer:stop()
		state.fallback_timer:close()
		state.fallback_timer = nil
	end
	if state.git_handle then
		state.git_handle:stop()
		state.git_handle:close()
	end
	M.state.roots[root] = nil
	fs.invalidate_root(root)
	local function close_batch()
		local closed = 0
		for path in pairs(state.handles) do
			close_folder(state, path)
			closed = closed + 1
			if closed == WATCH_BATCH_SIZE then
				vim.schedule(close_batch)
				return
			end
		end
	end
	vim.schedule(close_batch)
end

--- Stop every active filesystem handle while retaining registered views.
---@return nil
function M.stop_all()
	for _, state in pairs(M.state.roots) do
		if state.fallback_timer then
			state.fallback_timer:stop()
			state.fallback_timer:close()
			state.fallback_timer = nil
		end
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
