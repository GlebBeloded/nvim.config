-- Project-tree lifecycle keeps editor windows, directory buffers, and view teardown coordinated.

local M = {}

local editor = require("gleb.file_tree.editor")
local expanded = require("gleb.file_tree.expanded")
local fs = require("gleb.workspace")
local git = require("gleb.file_tree.git")
local watch = require("gleb.tree.watch")

---@class FileTreeLifecycleHooks
---@field get_state fun(): FileTreeViewState
---@field open_view fun(path: string, requested_root?: string): FileTreeView
---@field reroot fun(view: FileTreeView, root: string)
---@field request_git fun(view: FileTreeView)

---@class FileTreeViewLifecycleHooks
---@field get_state fun(): FileTreeViewState
---@field is_hidden fun(view: FileTreeView, path: string): boolean
---@field reveal_path fun(view: FileTreeView, path: string, focus: boolean)

local view_group
local original_guicursor

local function update_cursor()
	local current = vim.api.nvim_get_current_win()
	local tree_focused = vim.api.nvim_win_is_valid(current)
		and vim.bo[vim.api.nvim_win_get_buf(current)].filetype == "gleb-file-tree"
	local mode = vim.api.nvim_get_mode().mode
	local hidden = tree_focused and (mode == "n" or mode == "v" or mode == "V" or mode == "\22")
	if hidden then
		original_guicursor = original_guicursor or vim.o.guicursor
		vim.o.guicursor = "a:FileTreeHiddenCursor"
	elseif original_guicursor then
		vim.o.guicursor = original_guicursor
	end
end

---@param win integer
---@return boolean
local function is_sidebar_window(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	return filetype == "gleb-file-tree" or filetype == "gleb-changes"
end

---@param view FileTreeView
---@param state FileTreeViewState
local function forget(view, state)
	if state.by_tab[view.tab] == view then
		state.by_tab[view.tab] = nil
	end
	if view.watching then
		view.watching = false
		expanded.save(view.root, view.expanded)
		expanded.flush()
		watch.stop_root(view.root, view.tab)
		git.stop_root(view.root, view.tab)
	end
	if view.initial_draw_timer then
		view.initial_draw_timer:stop()
		view.initial_draw_timer:close()
		view.initial_draw_timer = nil
	end
	if view.dirty_timer then
		view.dirty_timer:stop()
		view.dirty_timer:close()
		view.dirty_timer = nil
	end
	for _, autocmd in ipairs(view.autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	view.autocmds = {}
end

--- Close and forget one project-tree view.
---@param view FileTreeView
---@param state FileTreeViewState
---@return nil
function M.close(view, state)
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.bo[view.buf].bufhidden = "wipe"
	end
	forget(view, state)
	if vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	end
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.api.nvim_buf_delete(view.buf, { force = true })
	end
	update_cursor()
end

---@param view FileTreeView
local function protect_tree_buffer(view)
	if not vim.api.nvim_win_is_valid(view.win) or vim.api.nvim_get_current_win() ~= view.win then
		return
	end
	local replacement = vim.api.nvim_win_get_buf(view.win)
	if replacement == view.buf then
		return
	end
	local target = editor.select(view)
	vim.api.nvim_win_set_buf(view.win, view.buf)
	vim.bo[view.buf].bufhidden = "wipe"
	vim.api.nvim_win_set_buf(target, replacement)
	vim.api.nvim_set_current_win(target)
end

---@param view FileTreeView
local function keep_tree_buffer(view)
	if
		vim.api.nvim_win_is_valid(view.win)
		and vim.api.nvim_get_current_win() == view.win
		and vim.api.nvim_win_get_buf(view.win) == view.buf
	then
		vim.bo[view.buf].bufhidden = "hide"
	end
end

---@param view FileTreeView
---@param buf integer
---@param hooks FileTreeViewLifecycleHooks
local function follow_buffer(view, buf, hooks)
	if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_tabpage() ~= view.tab or buf == view.buf then
		return
	end
	if view.skip_follow_buf == buf then
		view.skip_follow_buf = nil
		return
	end
	local win = vim.api.nvim_get_current_win()
	local path = vim.api.nvim_buf_get_name(buf)
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	if stat and stat.type == "directory" then
		view.directory_hijacks[win] = true
		return
	end
	if view.directory_hijacks[win] then
		view.directory_hijacks[win] = nil
		return
	end
	if vim.bo[buf].buftype == "" and not hooks.is_hidden(view, path) then
		hooks.reveal_path(view, path, false)
	end
end

--- Attach teardown and buffer-protection autocmds to a view.
---@param view FileTreeView
---@param hooks FileTreeViewLifecycleHooks
---@return nil
function M.attach(view, hooks)
	view.autocmds = {
		vim.api.nvim_create_autocmd("BufLeave", {
			group = view_group,
			buffer = view.buf,
			callback = function()
				view.buffer_leave_cursor = vim.api.nvim_win_get_cursor(view.win)
				vim.bo[view.buf].bufhidden = "hide"
			end,
		}),
		vim.api.nvim_create_autocmd("WinLeave", {
			group = view_group,
			pattern = tostring(view.win),
			callback = function()
				update_cursor()
				if vim.api.nvim_buf_is_valid(view.buf) then
					vim.bo[view.buf].bufhidden = "wipe"
				end
			end,
		}),
		vim.api.nvim_create_autocmd({ "WinEnter", "ModeChanged" }, {
			group = view_group,
			callback = function()
				keep_tree_buffer(view)
				update_cursor()
			end,
		}),
		vim.api.nvim_create_autocmd("BufEnter", {
			group = view_group,
			callback = function(args)
				protect_tree_buffer(view)
				keep_tree_buffer(view)
				follow_buffer(view, args.buf, hooks)
			end,
		}),
		vim.api.nvim_create_autocmd("WinClosed", {
			group = view_group,
			pattern = tostring(view.win),
			callback = function()
				forget(view, hooks.get_state())
			end,
		}),
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = view_group,
			buffer = view.buf,
			callback = function()
				forget(view, hooks.get_state())
			end,
		}),
	}
end

---@param args { buf: integer }
---@param hooks FileTreeLifecycleHooks
local function hijack_directory(args, hooks)
	if not vim.api.nvim_buf_is_valid(args.buf) then
		return
	end
	local directory = vim.api.nvim_buf_get_name(args.buf)
	local stat = directory ~= "" and vim.uv.fs_stat(directory) or nil
	if vim.bo[args.buf].buftype ~= "" or not stat or stat.type ~= "directory" then
		return
	end

	local view = hooks.get_state().by_tab[vim.api.nvim_get_current_tabpage()]
	if view and vim.api.nvim_win_is_valid(view.win) then
		if vim.api.nvim_get_current_win() == view.win then
			vim.api.nvim_win_set_buf(view.win, view.buf)
			if view.buffer_leave_cursor then
				vim.api.nvim_win_set_cursor(view.win, view.buffer_leave_cursor)
				view.buffer_leave_cursor = nil
			end
		else
			vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))
		end
		vim.api.nvim_set_current_win(view.win)
	else
		vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))
		hooks.open_view(directory, directory)
	end
	if vim.api.nvim_buf_is_valid(args.buf) then
		vim.api.nvim_buf_delete(args.buf, { force = true })
	end
end

---@param tab integer
---@param hooks FileTreeLifecycleHooks
local function close_tree_windows(tab, hooks)
	local state = hooks.get_state()
	local view = state.by_tab[tab]
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if is_sidebar_window(win) and (not view or win ~= view.win) and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	if view then
		M.close(view, state)
	end
end

---@param hooks FileTreeLifecycleHooks
local function on_quit_pre(hooks)
	local tab = vim.api.nvim_get_current_tabpage()
	if
		hooks.get_state().by_tab[tab]
		and editor.is_eligible(vim.api.nvim_get_current_win())
		and editor.count(tab) == 1
	then
		close_tree_windows(tab, hooks)
	end
end

---@param tab integer
---@param hooks FileTreeLifecycleHooks
local function close_trees_if_orphaned(tab, hooks)
	if vim.api.nvim_tabpage_is_valid(tab) and hooks.get_state().by_tab[tab] and editor.count(tab) == 0 then
		close_tree_windows(tab, hooks)
	end
end

---@param hooks FileTreeLifecycleHooks
local function close_trees_without_an_editor(hooks)
	for tab in pairs(hooks.get_state().by_tab) do
		local pending_tab = tab
		vim.schedule(function()
			close_trees_if_orphaned(pending_tab, hooks)
		end)
	end
end

--- Install project-tree lifecycle hooks.
---@param hooks FileTreeLifecycleHooks
---@return nil
function M.setup(hooks)
	view_group = vim.api.nvim_create_augroup("gleb_file_tree_view", { clear = true })
	local hijack_group = vim.api.nvim_create_augroup("gleb_file_tree_hijack", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = hijack_group,
		callback = function(args)
			hijack_directory(args, hooks)
		end,
	})
	editor.remember()
	vim.api.nvim_create_autocmd("WinEnter", { group = view_group, callback = editor.remember })
	vim.api.nvim_create_autocmd("QuitPre", {
		group = view_group,
		callback = function()
			on_quit_pre(hooks)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = view_group,
		callback = function()
			close_trees_without_an_editor(hooks)
		end,
	})
	vim.api.nvim_create_autocmd("DirChanged", {
		group = view_group,
		pattern = "global",
		callback = function()
			local view = hooks.get_state().by_tab[vim.api.nvim_get_current_tabpage()]
			if view then
				hooks.reroot(view, fs.normalize(vim.fn.getcwd()))
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", { group = view_group, callback = expanded.flush_sync })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = view_group,
		callback = function()
			local path = fs.normalize(vim.api.nvim_buf_get_name(0))
			for _, view in pairs(hooks.get_state().by_tab) do
				if vim.startswith(path, view.root .. "/") then
					hooks.request_git(view)
				end
			end
		end,
	})
end

--- Update cursor visibility after opening or closing a tree.
---@return nil
function M.update_cursor()
	update_cursor()
end

return M
