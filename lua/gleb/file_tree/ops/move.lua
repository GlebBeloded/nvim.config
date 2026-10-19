-- Project-tree moves preserve editor buffers and coordinate filesystem and LSP rename events.

local M = {}

local paths = require("gleb.file_tree.paths")

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

---@param path string
---@return table<integer, FileTreeOriginalBuffer>
local function buffers_at_logical_path(path)
	local result = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if name == path or vim.startswith(name, path .. "/") then
			result[buf] = {
				name = name,
				logical_old = path,
				suffix = name:sub(#path + 1),
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
	local renamed = {}
	for buf, original in pairs(original_buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			local prefix = vim.fs.joinpath(vim.fs.dirname(original.logical_old), vim.fs.basename(new))
			local ok, name_error = pcall(vim.api.nvim_buf_set_name, buf, prefix .. original.suffix)
			if not ok then
				for renamed_buf, old_name in pairs(renamed) do
					pcall(vim.api.nvim_buf_set_name, renamed_buf, old_name)
				end
				vim.uv.fs_rename(temporary, old)
				return false, tostring(name_error)
			end
			renamed[buf] = original.name
		end
	end

	local moved, move_error = vim.uv.fs_rename(temporary, new)
	if not moved then
		for renamed_buf, old_name in pairs(renamed) do
			pcall(vim.api.nvim_buf_set_name, renamed_buf, old_name)
		end
		vim.uv.fs_rename(temporary, old)
		return false, move_error
	end
	return true
end

---@param old string
---@param new string
---@return boolean
---@return string?
local function rename_symlink(old, new)
	local original_buffers = buffers_at_logical_path(old)
	local moved, move_error = vim.uv.fs_rename(old, new)
	if not moved then
		return false, move_error
	end

	local renamed = {}
	for buf, original in pairs(original_buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			local ok, name_error = pcall(vim.api.nvim_buf_set_name, buf, new .. original.suffix)
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
	local stat = vim.uv.fs_lstat(old)
	if stat and stat.type == "link" then
		if old:lower() == new:lower() then
			return rename_case_only(old, new, buffers_at_logical_path(old))
		end
		return rename_symlink(old, new)
	end
	if old:lower() == new:lower() then
		return rename_case_only(old, new, buffers_at(old))
	end

	return rename_once(old, new)
end

---@param completed FileTreeMovePair[]
local function rollback_moves(completed)
	for index = #completed, 1, -1 do
		local pair = completed[index]
		rename_path(pair.new, pair.old)
	end
end

---@param move_pairs FileTreeMovePair[]
---@return FileTreeMovePair[]
local function reverse_moves(move_pairs)
	return vim.tbl_map(function(pair)
		return { old = pair.new, new = pair.old }
	end, move_pairs)
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
	view.migrate_moved(root, pending)
	local completed = {}
	for _, pair in ipairs(pending) do
		local moved, error = rename_path(pair.old, pair.new)
		if not moved then
			rollback_moves(completed)
			view.migrate_moved(root, reverse_moves(pending))
			vim.notify("Rename failed: " .. tostring(error), vim.log.levels.ERROR)
			return false
		end
		completed[#completed + 1] = pair
	end
	for _, pair in ipairs(pending) do
		if not vim.uv.fs_stat(pair.new) then
			rollback_moves(completed)
			view.migrate_moved(root, reverse_moves(pending))
			vim.notify("Rename failed: target does not exist", vim.log.levels.ERROR)
			return false
		end
	end
	view.refresh_moved(root, pending[1].new, pending)
	lsp_files.did_rename(pending)
	return true
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

return M
