-- Project-tree operations coordinate prompts, filesystem changes, and view updates.

local M = {}

local paths = require("gleb.file_tree.paths")

---@class FileTreeOpsState
---@field trash_path string|false|nil

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
	local detail = reason == "cross-device" and reason or (path .. ": " .. reason)
	vim.notify("Rename failed: " .. detail, vim.log.levels.ERROR)
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

	local lsp_files = require("gleb.file_tree.lsp_files")
	lsp_files.will_rename(pending)
	for _, pair in ipairs(pending) do
		local moved, error = pcall(vim.lsp.util.rename, pair.old, pair.new)
		if not moved then
			vim.notify("Rename failed: " .. tostring(error), vim.log.levels.ERROR)
			return false
		end
	end
	for _, pair in ipairs(pending) do
		if not vim.uv.fs_stat(pair.new) then
			vim.notify("Rename failed: target does not exist", vim.log.levels.ERROR)
			return false
		end
	end
	lsp_files.did_rename(pending)
	view.refresh_moved(root, pending[1].new)
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

---@param root string
---@param target_folder string
---@param query string
local function create(root, target_folder, query)
	local directory = vim.endswith(query, "/")
	local name = directory and query:sub(1, -2) or query
	local target = vim.fs.joinpath(target_folder, name)
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
			M.move({ { old = row.path, new = vim.fs.joinpath(parent, query) } })
		end,
	})
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
			local fallback = vim.api.nvim_create_buf(true, false)
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					vim.api.nvim_win_set_buf(win, fallback)
				end
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

--- Confirm and delete the selected project-tree entry.
---@return nil
function M.delete()
	local view = require("gleb.file_tree.view")
	local root, row = view.selected_path()
	if not root or not row or row.kind == "root" then
		return
	end
	local path_list = { row.path }
	local modified = count_modified_buffers(path_list)
	local choice = trash_path() and "Move to Trash" or "Delete"
	local prompt = "Delete " .. row.path:sub(#root + 2) .. "?"
	if modified > 0 then
		prompt = ("Delete 1 item (%d unsaved)?"):format(modified)
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
