-- Non-recursive libuv watches invalidate only changed scans and coalesce redraws from event bursts.

local M = {}

local fs = require("gleb.file_tree.fs")

local WATCH_DEBOUNCE_MS = 100

---@class FileTreeWatchRoot
---@field handles table<string, uv.uv_fs_event_t>
---@field timers table<string, uv.uv_timer_t>
---@field git_handle? uv.uv_fs_event_t
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
				state.redraw(path)
				state.refresh_git()
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
	vim.system({ "git", "-C", root, "rev-parse", "--absolute-git-dir" }, { text = true }, function(result)
		vim.schedule(function()
			if M.state.roots[root] ~= state or result.code ~= 0 or state.git_handle then
				return
			end
			local path = vim.trim(result.stdout or "")
			local handle = assert(vim.uv.new_fs_event())
			local ok = handle:start(path, {}, function(error)
				if not error then
					vim.schedule(state.refresh_git)
				end
			end)
			if ok then
				state.git_handle = handle
			else
				handle:close()
			end
		end)
	end)
end

--- Watch every directory scan currently feeding visible rows.
---@param root string
---@param paths table<string, boolean>
---@param redraw fun(path: string)
---@param refresh_git fun()
---@return nil
function M.sync(root, paths, redraw, refresh_git)
	local state = M.state.roots[root]
	if not state then
		state = { handles = {}, timers = {}, redraw = redraw, refresh_git = refresh_git }
		M.state.roots[root] = state
		watch_git_dir(root, state)
	else
		state.redraw = redraw
		state.refresh_git = refresh_git
	end
	for path in pairs(paths) do
		if not state.handles[path] then
			watch_folder(root, path, state)
		end
	end
end

--- Stop and remove every watch.
---@return nil
function M.reset()
	for _, state in pairs(M.state.roots) do
		for _, handle in pairs(state.handles) do
			handle:stop()
			handle:close()
		end
		for _, timer in pairs(state.timers) do
			timer:stop()
			timer:close()
		end
		if state.git_handle then
			state.git_handle:stop()
			state.git_handle:close()
		end
	end
	M.state = { roots = {} }
end

return M
