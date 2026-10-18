-- Project-tree operations coordinate prompts, filesystem changes, and view updates.

local M = {}

local paths = require("gleb.file_tree.paths")

---@class FileTreeOpsState
---@field trash_path string|false|nil
---@field clipboard? FileTreeClipboard

---@class FileTreeClipboard
---@field mode "copy"|"cut"
---@field paths string[]

---@class FileTreeCopyEntry
---@field source string
---@field target string
---@field kind "directory"|"file"|"link"
---@field link_text? string

---@type FileTreeOpsState
M.state = {}

local SYSTEM_TRASH = "/usr/bin/trash"

---@param root string
---@param path string
local function notify_exists(root, path)
	local relative = path:sub(#root + 2)
	vim.notify("Already exists: " .. relative, vim.log.levels.ERROR)
end

---@param path string
---@return string[]
local function directory_names(path)
	local names = {}
	for name in vim.fs.dir(path) do
		names[#names + 1] = name
	end
	return names
end

---@param root string
---@param reason string
---@param path string
local function notify_preflight_failure(root, reason, path)
	if reason == "exists" then
		notify_exists(root, path)
		return
	end
	local relative = paths.is_inside(root, path) and path:sub(#root + 2) or "path"
	local detail = reason == "cross-device" and reason or (relative .. ": " .. reason)
	vim.notify("Rename failed: " .. detail, vim.log.levels.ERROR)
end

---@param path string
---@return string
local function temporary_sibling(path)
	local parent = vim.fs.dirname(path)
	local stem = ".gleb-rename-temporary-" .. vim.fs.basename(path)
	local candidate = vim.fs.joinpath(parent, stem)
	local ordinal = 1
	while vim.uv.fs_lstat(candidate) do
		ordinal = ordinal + 1
		candidate = vim.fs.joinpath(parent, stem .. "-" .. ordinal)
	end
	return candidate
end

---@class FileTreeOriginalBuffer
---@field name string
---@field logical_old string
---@field suffix string

---@param path string
---@return table<integer, FileTreeOriginalBuffer>
local function buffers_at(path)
	local result = {}
	local real_path = vim.uv.fs_realpath(path)
	if not real_path then
		return result
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		local real_name = name ~= "" and vim.uv.fs_realpath(name) or nil
		if real_name and (real_name == real_path or vim.startswith(real_name, real_path .. "/")) then
			local logical_old = name
			while logical_old ~= "/" and vim.uv.fs_realpath(logical_old) ~= real_path do
				logical_old = vim.fs.dirname(logical_old)
			end
			result[buf] = {
				name = name,
				logical_old = logical_old,
				suffix = real_name:sub(#real_path + 1),
			}
		end
	end
	return result
end

---@param original_buffers table<integer, FileTreeOriginalBuffer>
local function wipe_stale_buffers(original_buffers)
	local old_names = {}
	for _, original in pairs(original_buffers) do
		old_names[original.name] = true
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(buf)
			and not original_buffers[buf]
			and old_names[vim.api.nvim_buf_get_name(buf)]
		then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

---@param old string
---@param new string
---@param opts? vim.lsp.util.rename.Opts
---@return boolean
---@return string?
local function rename_once(old, new, opts)
	local original_buffers = buffers_at(old)
	local moved, move_error = pcall(vim.lsp.util.rename, old, new, opts)
	if moved and vim.uv.fs_lstat(new) then
		wipe_stale_buffers(original_buffers)
		return true
	end
	return false, tostring(move_error or "move failed")
end

---@param old string
---@param new string
---@param original_buffers table<integer, FileTreeOriginalBuffer>
---@return boolean
---@return string?
local function rename_case_only(old, new, original_buffers)
	local temporary = temporary_sibling(old)
	local staged, stage_error = vim.uv.fs_rename(old, temporary)
	if not staged then
		return false, stage_error
	end
	local moved, move_error = vim.uv.fs_rename(temporary, new)
	if not moved then
		vim.uv.fs_rename(temporary, old)
		return false, move_error
	end

	local renamed = {}
	for buf, original in pairs(original_buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			local prefix = vim.fs.joinpath(vim.fs.dirname(original.logical_old), vim.fs.basename(new))
			local ok, name_error = pcall(vim.api.nvim_buf_set_name, buf, prefix .. original.suffix)
			if not ok then
				for renamed_buf, old_name in pairs(renamed) do
					pcall(vim.api.nvim_buf_set_name, renamed_buf, old_name)
				end
				vim.uv.fs_rename(new, old)
				return false, tostring(name_error)
			end
			renamed[buf] = original.name
		end
	end
	return true
end

---@param old string
---@param new string
---@return boolean
---@return string?
local function rename_path(old, new)
	if old:lower() == new:lower() then
		return rename_case_only(old, new, buffers_at(old))
	end

	return rename_once(old, new)
end

---@param completed FileTreeMovePair[]
local function rollback_moves(completed)
	for index = #completed, 1, -1 do
		local pair = completed[index]
		rename_once(pair.new, pair.old)
	end
end

---@param move_pairs FileTreeMovePair[]
---@return boolean
local function create_move_parents(move_pairs)
	for _, pair in ipairs(move_pairs) do
		local parent = vim.fs.dirname(pair.new)
		if vim.fn.mkdir(parent, "p") == 0 and not vim.uv.fs_stat(parent) then
			return false
		end
	end
	return true
end

--- Move a batch only after every source and target passes preflight.
---@param move_pairs FileTreeMovePair[]
---@return boolean moved
function M.move(move_pairs)
	local view = require("gleb.file_tree.view")
	local root = view.selected_path()
	if not root then
		return false
	end

	local pending = vim.tbl_filter(function(pair)
		return pair.old ~= pair.new
	end, move_pairs)
	if #pending == 0 then
		return true
	end
	local ok, reason, failed_path = paths.preflight_moves(root, pending, {
		lstat = vim.uv.fs_lstat,
		stat = vim.uv.fs_stat,
		read_dir = directory_names,
	})
	if not ok then
		notify_preflight_failure(root, reason or "unknown", failed_path or root)
		return false
	end
	if not create_move_parents(pending) then
		notify_preflight_failure(root, "missing", vim.fs.dirname(pending[1].new))
		return false
	end

	local lsp_files = require("gleb.file_tree.lsp_files")
	lsp_files.will_rename(pending)
	local completed = {}
	for _, pair in ipairs(pending) do
		local moved, error = rename_path(pair.old, pair.new)
		if not moved then
			rollback_moves(completed)
			vim.notify("Rename failed: " .. tostring(error), vim.log.levels.ERROR)
			return false
		end
		completed[#completed + 1] = pair
	end
	for _, pair in ipairs(pending) do
		if not vim.uv.fs_stat(pair.new) then
			rollback_moves(completed)
			vim.notify("Rename failed: target does not exist", vim.log.levels.ERROR)
			return false
		end
	end
	view.refresh_moved(root, pending[1].new, pending)
	lsp_files.did_rename(pending)
	return true
end

---@param path string
---@return boolean
---@return string?
local function create_file(path)
	local parent = vim.fs.dirname(path)
	if vim.fn.mkdir(parent, "p") == 0 and not vim.uv.fs_stat(parent) then
		return false, "could not create parent directory"
	end
	local handle, error = vim.uv.fs_open(path, "wx", 420)
	if not handle then
		return false, error
	end
	vim.uv.fs_close(handle)
	return true
end

---@param path string
---@return boolean
---@return string?
local function create_directory(path)
	if vim.fn.mkdir(path, "p") == 0 and not vim.uv.fs_stat(path) then
		return false, "could not create directory"
	end
	return true
end

---@param source string
---@param target string
---@param entries FileTreeCopyEntry[]
---@return boolean
---@return string?
local function collect_copy_entries(source, target, entries)
	local stat, stat_error = vim.uv.fs_lstat(source)
	if not stat then
		return false, stat_error
	end
	if stat.type == "link" then
		local link_text, link_error = vim.uv.fs_readlink(source)
		if not link_text then
			return false, link_error
		end
		entries[#entries + 1] = { source = source, target = target, kind = "link", link_text = link_text }
		return true
	end
	if stat.type ~= "directory" then
		entries[#entries + 1] = { source = source, target = target, kind = "file" }
		return true
	end

	entries[#entries + 1] = { source = source, target = target, kind = "directory" }
	local handle, scan_error = vim.uv.fs_scandir(source)
	if not handle then
		return false, scan_error
	end
	while true do
		local name = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		local ok, error = collect_copy_entries(vim.fs.joinpath(source, name), vim.fs.joinpath(target, name), entries)
		if not ok then
			return false, error
		end
	end
	return true
end

---@param source string
---@param target string
---@return boolean copied
---@return string? error
---@return boolean? conflict
local function copy_path(source, target)
	local entries = {}
	local collected, collect_error = collect_copy_entries(source, target, entries)
	if not collected then
		return false, collect_error
	end
	for _, entry in ipairs(entries) do
		if vim.uv.fs_lstat(entry.target) then
			return false, "destination exists", true
		end
	end
	for _, entry in ipairs(entries) do
		local ok, error
		if entry.kind == "directory" then
			ok, error = vim.uv.fs_mkdir(entry.target, 493)
		elseif entry.kind == "link" then
			ok, error = vim.uv.fs_symlink(assert(entry.link_text, "copy link text missing"), entry.target)
		else
			ok, error = vim.uv.fs_copyfile(entry.source, entry.target, {
				excl = true,
				ficlone = false,
				ficlone_force = false,
			})
		end
		if not ok then
			return false, error
		end
	end
	return true
end

---@param source string
---@param target string
local function finish_copy(source, target)
	local copied, error = copy_path(source, target)
	if not copied then
		vim.notify("Paste failed: " .. (error or "unknown error"), vim.log.levels.ERROR)
		return
	end
	require("gleb.file_tree.view").select_created(target, false)
end

---@param folder string
---@param name string
---@param is_directory boolean
---@return string name
---@return integer number
local function available_copy_name(folder, name, is_directory)
	local number = 1
	while true do
		local candidate = paths.copy_name(name, is_directory, number)
		if not vim.uv.fs_lstat(vim.fs.joinpath(folder, candidate)) then
			return candidate, number
		end
		number = number + 1
	end
end

---@param root string
---@param source string
---@param target_folder string
local function prompt_copy(root, source, target_folder)
	local source_stat = vim.uv.fs_lstat(source)
	if not source_stat then
		vim.notify("Paste failed: " .. source .. ": ENOENT", vim.log.levels.ERROR)
		return
	end
	local name = vim.fs.basename(source)
	local is_directory = source_stat.type == "directory"
	local default = available_copy_name(target_folder, name, is_directory)
	require("gleb.picker.input").open({
		title = "Copy",
		default = default,
		hint = "Copy ↩",
		preview = function(query)
			return { text = vim.fs.joinpath(target_folder, query):sub(#root + 2) }
		end,
		on_submit = function(query)
			local target = paths.validate_submitted_name(root, target_folder, query)
			if not target then
				vim.notify("Paste failed: path must stay inside the project root", vim.log.levels.ERROR)
				return
			end
			if vim.uv.fs_lstat(target) then
				prompt_copy(root, source, target_folder)
				return
			end
			finish_copy(source, target)
		end,
	})
end

---@param root string
---@param target_folder string
---@param query string
local function create(root, target_folder, query)
	local directory = vim.endswith(query, "/")
	local name = directory and query:sub(1, -2) or query
	local target = paths.validate_submitted_name(root, target_folder, name)
	if not target then
		vim.notify("Create failed: path must stay inside the project root", vim.log.levels.ERROR)
		return
	end
	if vim.uv.fs_lstat(target) then
		notify_exists(root, target)
		return
	end

	local ok, error
	if directory then
		ok, error = create_directory(target)
	else
		ok, error = create_file(target)
	end
	if not ok then
		vim.notify("Create failed: " .. (error or "unknown error"), vim.log.levels.ERROR)
		return
	end
	require("gleb.file_tree.view").select_created(target, not directory)
end

--- Prompt for and create a file or directory below the selected project-tree row.
---@return nil
function M.add()
	local view = require("gleb.file_tree.view")
	local root, row = view.selected_path()
	if not root or not row then
		return
	end
	local target_folder = paths.target_folder(root, row)
	require("gleb.picker.input").open({
		title = "New File or Directory",
		hint = "Directory: end with / · Create ↩",
		preview = function(query)
			local directory = vim.endswith(query, "/")
			local preview = vim.fs.joinpath(target_folder, query):sub(#root + 2)
			return { text = preview, category = directory and "New directory" or "New file" }
		end,
		on_submit = function(query)
			create(root, target_folder, query)
		end,
	})
end

--- Prompt for and rename the selected project-tree entry.
---@return nil
function M.rename()
	local view = require("gleb.file_tree.view")
	local root, row = view.selected_path()
	if not root or not row or row.kind == "root" then
		return
	end
	local parent = vim.fs.dirname(row.path)
	local name = vim.fs.basename(row.path)
	require("gleb.picker.input").open({
		title = "Rename",
		default = name,
		hint = "Rename ↩",
		preview = function(query)
			local target = vim.fs.joinpath(parent, query)
			return {
				text = target:sub(#root + 2),
				secondary = target == row.path and "unchanged" or nil,
				category = row.kind == "directory" and "Folder" or "File",
			}
		end,
		on_submit = function(query)
			local target = paths.validate_submitted_name(root, parent, query)
			if not target then
				vim.notify("Rename failed: path must stay inside the project root", vim.log.levels.ERROR)
				return
			end
			M.move({ { old = row.path, new = target } })
		end,
	})
end

---@param ctx? gleb.ActionContext
---@return string? root
---@return string[] selected
local function selected_paths(ctx)
	local view_module = require("gleb.file_tree.view")
	local root, row = view_module.selected_path()
	if not root or not row then
		return nil, {}
	end
	if not ctx or not ctx.selection then
		return root, row.kind == "root" and {} or { row.path }
	end

	local view = view_module.state.by_tab[vim.api.nvim_get_current_tabpage()]
	local selected = {}
	if not view then
		return root, selected
	end
	for line = ctx.selection.start[1], ctx.selection.finish[1] do
		local selected_row = view.rows[line]
		if selected_row and selected_row.kind ~= "root" then
			selected[#selected + 1] = selected_row.path
		end
	end
	return root, paths.dedupe(selected)
end

---@param mode "copy"|"cut"
---@param ctx? gleb.ActionContext
local function set_clipboard(mode, ctx)
	local _, selected = selected_paths(ctx)
	if #selected == 0 then
		return
	end
	M.state.clipboard = { mode = mode, paths = selected }
end

--- Copy the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.copy(ctx)
	set_clipboard("copy", ctx)
end

--- Cut the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.cut(ctx)
	set_clipboard("cut", ctx)
end

---@param root string
---@param source string
---@param target_folder string
---@return boolean
local function refuses_self_paste(root, source, target_folder)
	local stat = vim.uv.fs_lstat(source)
	if stat and stat.type == "directory" and paths.is_inside(source, target_folder) then
		vim.notify("Cannot paste " .. source:sub(#root + 2) .. " into itself", vim.log.levels.ERROR)
		return true
	end
	return false
end

--- Paste copied or cut project-tree entries into the selected folder.
---@return nil
function M.paste()
	local clipboard = M.state.clipboard
	if not clipboard then
		return
	end
	local view = require("gleb.file_tree.view")
	local root, row = view.selected_path()
	if not root or not row then
		return
	end
	local target_folder = paths.target_folder(root, row)
	for _, source in ipairs(clipboard.paths) do
		if refuses_self_paste(root, source, target_folder) then
			return
		end
	end

	if clipboard.mode == "cut" then
		local move_pairs = vim.tbl_map(function(source)
			return { old = source, new = vim.fs.joinpath(target_folder, vim.fs.basename(source)) }
		end, clipboard.paths)
		if M.move(move_pairs) then
			M.state.clipboard = nil
		end
		return
	end

	for _, source in ipairs(clipboard.paths) do
		if not vim.uv.fs_lstat(source) then
			vim.notify("Paste failed: " .. source:sub(#root + 2) .. ": ENOENT", vim.log.levels.ERROR)
		else
			local target = vim.fs.joinpath(target_folder, vim.fs.basename(source))
			if vim.uv.fs_lstat(target) then
				prompt_copy(root, source, target_folder)
			else
				finish_copy(source, target)
			end
		end
	end
end

--- Rescan the current project-tree view and refresh Git status immediately.
---@return nil
function M.refresh()
	require("gleb.file_tree.view").refresh()
end

---@return string?
local function trash_path()
	if M.state.trash_path ~= nil then
		return M.state.trash_path or nil
	end
	return vim.fn.executable(SYSTEM_TRASH) == 1 and SYSTEM_TRASH or nil
end

---@param path_list string[]
---@return boolean deleted
local function delete_with_trash(path_list)
	local command = { assert(trash_path()), "-s" }
	vim.list_extend(command, path_list)
	local result = vim.system(command, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify("Delete failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
		return false
	end
	return true
end

---@param path_list string[]
---@return boolean deleted
local function delete_permanently(path_list)
	for _, path in ipairs(path_list) do
		local ok, error = pcall(vim.fs.rm, path, { recursive = true })
		if not ok then
			vim.notify("Delete failed: " .. tostring(error), vim.log.levels.ERROR)
			return false
		end
	end
	return true
end

---@param name string
---@param path string
---@return boolean
local function path_contains(name, path)
	return name == path or vim.startswith(name, path .. "/")
end

---@param path_list string[]
---@return integer[]
local function affected_buffers(path_list)
	return vim.tbl_filter(function(buf)
		if not vim.api.nvim_buf_is_loaded(buf) then
			return false
		end
		local name = vim.api.nvim_buf_get_name(buf)
		return name ~= "" and vim.iter(path_list):any(function(path)
			return path_contains(name, path)
		end)
	end, vim.api.nvim_list_bufs())
end

---@param path_list string[]
---@return integer
local function count_modified_buffers(path_list)
	local count = 0
	for _, buf in ipairs(affected_buffers(path_list)) do
		if vim.bo[buf].modified then
			count = count + 1
		end
	end
	return count
end

---@param path_list string[]
local function wipe_deleted_buffers(path_list)
	for _, buf in ipairs(affected_buffers(path_list)) do
		local name = vim.api.nvim_buf_get_name(buf)
		if not vim.bo[buf].modified and vim.uv.fs_stat(name) == nil then
			local windows = vim.tbl_filter(function(win)
				return vim.api.nvim_win_get_buf(win) == buf
			end, vim.api.nvim_list_wins())
			local fallback = #windows > 0 and vim.api.nvim_create_buf(true, false) or nil
			for _, win in ipairs(windows) do
				vim.api.nvim_win_set_buf(win, assert(fallback, "visible deleted buffer has no replacement"))
			end
			vim.api.nvim_buf_delete(buf, {})
		end
	end
end

---@param root string
---@param path_list string[]
local function delete_paths(root, path_list)
	local existing = vim.tbl_filter(function(path)
		return vim.uv.fs_lstat(path) ~= nil
	end, path_list)
	if #existing == 0 then
		require("gleb.file_tree.view").refresh_moved(root, root)
		return
	end

	local deleted
	if trash_path() then
		deleted = delete_with_trash(existing)
	else
		deleted = delete_permanently(existing)
	end
	if deleted then
		wipe_deleted_buffers(existing)
		require("gleb.file_tree.view").refresh_moved(root, root)
	end
end

--- Confirm and delete the selected project-tree entries.
---@param ctx? gleb.ActionContext
---@return nil
function M.delete(ctx)
	local root, path_list = selected_paths(ctx)
	if not root or #path_list == 0 then
		return
	end
	if ctx and ctx.selection then
		vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
	end
	local modified = count_modified_buffers(path_list)
	local choice = trash_path() and "Move to Trash" or "Delete"
	local prompt = "Delete " .. path_list[1]:sub(#root + 2) .. "?"
	if #path_list > 1 or modified > 0 then
		prompt = ("Delete %d %s (%d unsaved)?"):format(#path_list, #path_list == 1 and "item" or "items", modified)
	end
	vim.ui.select({ choice, "Cancel" }, { prompt = prompt }, function(item)
		if item == choice then
			delete_paths(root, path_list)
		end
	end)
end

--- Reset operation state owned by this module.
---@return nil
function M.reset()
	M.state = {}
end

return M
