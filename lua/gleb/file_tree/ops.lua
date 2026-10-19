-- Project-tree operations expose stable entry points while delegating each filesystem responsibility.

local M = {}

local clipboard = require("gleb.file_tree.ops.clipboard")
local move = require("gleb.file_tree.ops.move")

local SYSTEM_TRASH = "/usr/bin/trash"

M.state = clipboard.state

--- Move a batch only after every source and target passes preflight.
---@param move_pairs FileTreeMovePair[]
---@return boolean moved
function M.move(move_pairs)
	return move.move(move_pairs)
end

--- Prompt for and create a file or directory below the selected project-tree row.
---@return nil
function M.add()
	clipboard.add()
end

--- Prompt for and rename the selected project-tree entry.
---@return nil
function M.rename()
	move.rename()
end

--- Copy the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.copy(ctx)
	clipboard.copy(ctx)
end

--- Cut the selected project-tree entries into the tree clipboard.
---@param ctx? gleb.ActionContext
---@return nil
function M.cut(ctx)
	clipboard.cut(ctx)
end

--- Paste copied or cut project-tree entries into the selected folder.
---@return nil
function M.paste()
	clipboard.paste(M.move)
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
				assert(fallback, "visible deleted buffer has no replacement")
				vim.api.nvim_win_set_buf(win, fallback)
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
	local root, path_list = clipboard.selected_paths(ctx)
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
	clipboard.state = {}
	M.state = clipboard.state
end

return M
