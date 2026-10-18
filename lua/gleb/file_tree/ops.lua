-- Project-tree operations coordinate prompts, filesystem changes, and view updates.

local M = {}

local paths = require("gleb.file_tree.paths")

---@param old_path string
---@param new_path string
local function rename_path(old_path, new_path)
	local pair = { old = old_path, new = new_path }
	local lsp_files = require("gleb.file_tree.lsp_files")
	lsp_files.will_rename({ pair })
	local ok, error = pcall(vim.lsp.util.rename, old_path, new_path)
	if not ok then
		vim.notify("Rename failed: " .. tostring(error), vim.log.levels.ERROR)
		return
	end
	if not vim.uv.fs_stat(new_path) then
		vim.notify("Rename failed: target does not exist", vim.log.levels.ERROR)
		return
	end
	lsp_files.did_rename({ pair })
	require("gleb.file_tree.view").select_created(new_path, false)
end

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
			rename_path(row.path, vim.fs.joinpath(parent, query))
		end,
	})
end

return M
