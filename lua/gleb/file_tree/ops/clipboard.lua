-- Project-tree creation and clipboard operations coordinate filesystem changes with view updates.

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

---@param root string
---@param path string
local function notify_exists(root, path)
	local relative = path:sub(#root + 2)
	vim.notify("Already exists: " .. relative, vim.log.levels.ERROR)
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

---@param ctx? gleb.ActionContext
---@return string? root
---@return string[] selected
function M.selected_paths(ctx)
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
	local _, selected = M.selected_paths(ctx)
	if #selected == 0 then
		return
	end
	M.state.clipboard = { mode = mode, paths = selected }
	if ctx and ctx.selection then
		vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
	end
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
---@param move fun(move_pairs: FileTreeMovePair[]): boolean
---@return nil
function M.paste(move)
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
		if move(move_pairs) then
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

return M
