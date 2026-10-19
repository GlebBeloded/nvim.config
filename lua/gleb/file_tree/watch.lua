-- Non-recursive libuv watches invalidate only changed scans and coalesce redraws from event bursts. Listed folders
-- beyond MAX_WATCH_HANDLES (or whose watch failed) are covered by one recursive root watch where libuv supports it,
-- else polled every FALLBACK_RESCAN_MS. Every listed folder is also polled for FALLBACK_SETTLE_PASSES after a watch
-- change, which can drop events.

local M = {}

local fs = require("gleb.workspace")
local debounce = require("gleb.util.debounce")

local WATCH_DEBOUNCE_MS = 100
local WATCH_BATCH_SIZE = 16
local FALLBACK_RESCAN_MS = 250
-- libuv rebuilds its single FSEvents stream after any watch start or stop and drops events meanwhile.
local FALLBACK_SETTLE_PASSES = 2
-- libuv implements recursive fs events only on macOS (FSEvents) and Windows.
local RECURSIVE_WATCH = vim.fn.has("mac") == 1 or vim.fn.has("win32") == 1

M.MAX_WATCH_HANDLES = 256

---@class FileTreeWatchRoot
---@field handles table<string, uv.uv_fs_event_t>
---@field timers table<string, uv.uv_timer_t>
---@field reported table<string, FileTreeEntry[]> cached scan already reported stale, per path
---@field fallback_timer? uv.uv_timer_t
---@field tree_handle? uv.uv_fs_event_t
---@field fallback_scanning boolean
---@field settle_passes integer
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

local schedule_sync
local update_coverage

---@param root string
---@param path string
local function queue_redraw(root, path)
	local state = M.state.roots[root]
	if not state then
		return
	end
	state.reported[path] = fs.state.cache[path]
	state.timers[path] = debounce.schedule(state.timers[path], WATCH_DEBOUNCE_MS, function()
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
end

--- Watch one directory's entries, or its whole subtree when `flags.recursive` is set.
---@param path string
---@param on_change fun(filename?: string)
---@param flags? uv.fs_event_start.flags
---@return uv.uv_fs_event_t?
local function watch_path(path, on_change, flags)
	local handle = assert(vim.uv.new_fs_event())
	local ok = handle:start(path, flags or {}, function(error, filename)
		if not error then
			on_change(filename)
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
	if state.handles[path] then
		state.settle_passes = FALLBACK_SETTLE_PASSES
	end
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
						state.settle_passes = FALLBACK_SETTLE_PASSES
						schedule_sync(root, state)
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
		state.settle_passes = FALLBACK_SETTLE_PASSES
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
		reported = {},
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
		fallback_scanning = false,
		settle_passes = 0,
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
		-- Keep live handles while their folder stays listed: on macOS each fs_event stop blocks the main loop.
		local left_live, right_live = state.handles[left] ~= nil, state.handles[right] ~= nil
		if left_live ~= right_live then
			return left_live
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
schedule_sync = function(root, state)
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
		else
			update_coverage(root, state)
		end
	end)
end

---@param state FileTreeWatchRoot
---@return boolean
local function has_unwatched(state)
	for _, client in pairs(state.clients) do
		for path in pairs(client.paths) do
			if not state.handles[path] then
				return true
			end
		end
	end
	return false
end

---@param root string
---@param state FileTreeWatchRoot
---@param filename string
local function redraw_unwatched_parent(root, state, filename)
	local path = vim.fs.dirname(vim.fs.joinpath(root, filename))
	if state.handles[path] then
		return
	end
	for _, client in pairs(state.clients) do
		if client.paths[path] then
			queue_redraw(root, path)
			return
		end
	end
end

---@param root string
---@param state FileTreeWatchRoot
---@return uv.uv_fs_event_t?
local function watch_tree(root, state)
	return watch_path(root, function(filename)
		if filename then
			redraw_unwatched_parent(root, state, filename)
		end
	end, { recursive = true })
end

---@param state FileTreeWatchRoot
local function stop_fallback_timer(state)
	if state.fallback_timer then
		state.fallback_timer:stop()
		state.fallback_timer:close()
		state.fallback_timer = nil
	end
end

---@param state FileTreeWatchRoot
local function stop_tree_watch(state)
	if state.tree_handle then
		state.tree_handle:stop()
		state.tree_handle:close()
		state.tree_handle = nil
	end
end

---@param state FileTreeWatchRoot
local function stop_coverage(state)
	stop_tree_watch(state)
	stop_fallback_timer(state)
	for path, timer in pairs(state.timers) do
		if not state.handles[path] then
			timer:stop()
			timer:close()
			state.timers[path] = nil
		end
	end
end

---@param root string
---@param state FileTreeWatchRoot
---@param before table<string, FileTreeEntry[]>
---@param scans table<string, FileTreeEntry[]>
---@param stamps table<string, string|false>
local function apply_fallback_scans(root, state, before, scans, stamps)
	if M.state.roots[root] ~= state then
		return
	end
	state.fallback_scanning = false
	for path, entries in pairs(scans) do
		local previous = before[path]
		if previous and fs.state.cache[path] == previous and state.reported[path] ~= previous then
			if vim.deep_equal(previous, entries) then
				fs.remember_scan_stamp(path, stamps[path])
			else
				-- Shares the watch event's debounce, so a change seen by both redraws once.
				queue_redraw(root, path)
				fs.invalidate(path)
			end
		end
	end
end

---@param root string
---@param state FileTreeWatchRoot
---@param before table<string, FileTreeEntry[]>
local function scan_fallback_paths(root, state, before)
	local paths = vim.tbl_keys(before)
	if #paths == 0 then
		return
	end
	state.fallback_scanning = true
	local pending = #paths
	local scans = {}
	local stamps = {}
	local function complete(path, entries, stamp)
		if entries then
			scans[path] = entries
			stamps[path] = stamp
		end
		pending = pending - 1
		if pending == 0 then
			vim.schedule(function()
				apply_fallback_scans(root, state, before, scans, stamps)
			end)
		end
	end
	for _, path in ipairs(paths) do
		fs.scan_stamp_async(path, function(stamp)
			if fs.state.scan_stamps[path] == stamp then
				complete(path)
				return
			end
			fs.scan_async(path, function(entries)
				complete(path, entries, stamp)
			end)
		end)
	end
end

---@param root string
---@param state FileTreeWatchRoot
local function poll_folders(root, state)
	if M.state.roots[root] ~= state or state.fallback_scanning then
		return
	end
	local settling = state.settle_passes > 0
	if settling then
		state.settle_passes = state.settle_passes - 1
	end
	local before = {}
	for _, client in pairs(state.clients) do
		for path in pairs(client.paths) do
			if settling or not state.handles[path] then
				before[path] = fs.state.cache[path]
			end
		end
	end
	scan_fallback_paths(root, state, before)
	state.wanted, state.wanted_order = wanted_paths(root, state)
	schedule_sync(root, state)
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
			poll_folders(root, state)
		end)
	)
end

--- Cover listed folders left without a handle once a reconcile pass completes.
---@param root string
---@param state FileTreeWatchRoot
update_coverage = function(root, state)
	local unwatched = has_unwatched(state)
	if unwatched and RECURSIVE_WATCH and not state.tree_handle then
		state.tree_handle = watch_tree(root, state)
		if state.tree_handle then
			state.settle_passes = FALLBACK_SETTLE_PASSES
		end
	elseif not unwatched then
		stop_tree_watch(state)
	end
	if state.settle_passes > 0 or (unwatched and not state.tree_handle) then
		ensure_fallback_timer(root, state)
	else
		stop_fallback_timer(state)
	end
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
	stop_coverage(state)
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
		stop_coverage(state)
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
