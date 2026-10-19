-- Project-tree folds coordinate directory expansion and file-nest visibility.

local M = {}

local fs = require("gleb.workspace")
local model = require("gleb.file_tree.model")
local settings = require("gleb.tree.settings")
local tree_model = require("gleb.ui.tree.model")

local EXPANSION_MAX_ROWS = 5000

---@param rows FileTreeRow[]
---@return gleb.ui.tree.Node[]
function M.tree_nodes(rows)
	local root_row = rows[1]
	if not root_row then
		return {}
	end
	local root = {
		id = root_row.path,
		children = {},
		foldable = true,
		pinned = true,
		open_by_default = true,
		data = root_row,
	}
	local roots = { root }
	local parents = {}
	for index = 2, #rows do
		local row = rows[index]
		local node = {
			id = row.path,
			children = {},
			foldable = (row.kind == "directory" and not row.empty) or row.nest_children ~= nil,
			open_by_default = row.expanded or row.nest_expanded or false,
			data = row,
		}
		local parent = parents[row.depth]
		if parent then
			parent.children[#parent.children + 1] = node
		else
			roots[#roots + 1] = node
		end
		parents[row.depth + 1] = node
		for depth = row.depth + 2, #parents do
			parents[depth] = nil
		end
	end
	return roots
end

---@param view FileTreeView
---@param rows FileTreeRow[]
---@return nil
function M.rebuild_tree(view, rows)
	view.tree.folds = {}
	tree_model.rebuild(view.tree, M.tree_nodes(rows))
end

---@param view FileTreeView
---@return nil
function M.sync_expansions(view)
	for id, node in pairs(view.tree.nodes) do
		local row = node.data
		if row.kind ~= "root" and node.foldable then
			local relative = id:sub(#view.root + 2)
			local open = not view.tree.folds[id]
			if row.kind == "directory" then
				view.expanded[relative] = open and true or nil
				row.expanded = open
			else
				view.expanded_nests[relative] = open and true or nil
				row.nest_expanded = open
			end
		end
	end
end

---@class FileTreeFoldHooks
---@field expand_to fun(view: FileTreeView, path: string)
---@field row_options fun(view: FileTreeView, loaded_settings: FileTreeSettings): FileTreeRowOptions
---@field prepare_draw fun(view: FileTreeView, path: string): FileTreePreparedDraw
---@field draw fun(view: FileTreeView, path: string, prepared?: FileTreePreparedDraw)

---@param view FileTreeView
---@return FileTreeRow?
local function selected_row(view)
	return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]]
end

---@param view FileTreeView
---@param row FileTreeRow
---@param warning string
---@param hooks FileTreeFoldHooks
---@return FileTreePreparedDraw?
local function expand_directory(view, row, warning, hooks)
	local relative = row.path:sub(#view.root + 2)
	view.expanded[relative] = true
	local prepared = hooks.prepare_draw(view, row.path)
	if #prepared.rows > EXPANSION_MAX_ROWS then
		view.expanded[relative] = nil
		vim.notify(warning, vim.log.levels.WARN)
		return nil
	end
	return prepared
end

--- Expand one shared project-tree node through the lazy project model.
---@param view FileTreeView
---@param node gleb.ui.tree.Node
---@param hooks FileTreeFoldHooks
---@return boolean
function M.expand_shared(view, node, hooks)
	local row = node.data
	local prepared
	if row.kind == "directory" then
		prepared = expand_directory(view, row, "Expansion stopped at 5000 rows", hooks)
	elseif row.nest_children then
		view.expanded_nests[row.path:sub(#view.root + 2)] = true
		prepared = hooks.prepare_draw(view, row.path)
	else
		return false
	end
	if not prepared then
		return false
	end
	view.tree_watched = prepared.watched
	M.rebuild_tree(view, prepared.rows)
	return true
end

--- Toggle one project-tree directory.
---@param view FileTreeView
---@param row FileTreeRow
---@param hooks FileTreeFoldHooks
---@return nil
function M.toggle_directory(view, row, hooks)
	if row.kind == "root" or row.empty then
		return
	end
	local relative = row.path:sub(#view.root + 2)
	if row.expanded then
		view.expanded[relative] = nil
		hooks.draw(view, row.path)
	else
		local prepared = expand_directory(view, row, "Expansion stopped at 5000 rows", hooks)
		if prepared then
			hooks.draw(view, row.path, prepared)
		end
	end
end

---@param view FileTreeView
---@param row FileTreeRow
---@param hooks FileTreeFoldHooks
---@return boolean
local function close_nest(view, row, hooks)
	local parent = row.nest_parent or (row.nest_expanded and row.path or nil)
	if not parent then
		return false
	end
	view.expanded_nests[parent:sub(#view.root + 2)] = nil
	hooks.draw(view, parent)
	return true
end

--- Collapse the selected directory or its displayed parent.
---@param view FileTreeView
---@param hooks FileTreeFoldHooks
---@return nil
function M.close_node(view, hooks)
	local index = vim.api.nvim_win_get_cursor(view.win)[1]
	local row = view.rows[index]
	if not row or row.kind == "root" then
		return
	end
	if close_nest(view, row, hooks) then
		return
	end
	local target = row
	if row.kind ~= "directory" or not row.expanded then
		for parent_index = index - 1, 1, -1 do
			local candidate = view.rows[parent_index]
			if candidate.depth < row.depth then
				target = candidate
				break
			end
		end
	end
	if target.kind == "root" then
		return
	end
	view.expanded[target.path:sub(#view.root + 2)] = nil
	hooks.draw(view, target.path)
end

--- Toggle the selected directory or file nest.
---@param view FileTreeView
---@param hooks FileTreeFoldHooks
---@return nil
function M.toggle(view, hooks)
	local row = selected_row(view)
	if row and row.kind == "directory" then
		M.toggle_directory(view, row, hooks)
	elseif row and row.kind == "file" and row.nest_children then
		local relative = row.path:sub(#view.root + 2)
		view.expanded_nests[relative] = not view.expanded_nests[relative] or nil
		hooks.draw(view, row.path)
	elseif row and row.kind == "file" and row.nest_parent then
		close_nest(view, row, hooks)
	elseif row and row.kind == "file" then
		M.close_node(view, hooks)
	end
end

--- Collapse every project-tree directory while keeping the root visible.
---@param view FileTreeView
---@param hooks FileTreeFoldHooks
---@return nil
function M.fold_all(view, hooks)
	local path = view.root
	for index = vim.api.nvim_win_get_cursor(view.win)[1], 2, -1 do
		local row = view.rows[index]
		if row.depth == 0 then
			path = row.path
			break
		end
	end
	view.expanded = {}
	view.expanded_nests = {}
	hooks.draw(view, path)
end

--- Expand all shared project-tree nodes up to the visible-row safety limit.
---@param view FileTreeView
---@param hooks FileTreeFoldHooks
---@return nil
function M.expand_all_shared(view, hooks)
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local tree = fs.tree(view.root)
	local discovered
	local discovered_nests
	local stopped
	discovered, discovered_nests, stopped =
		model.unfold_all(tree, hooks.row_options(view, loaded_settings), nesting_settings, EXPANSION_MAX_ROWS)
	for relative in pairs(discovered) do
		view.expanded[relative] = true
	end
	for relative in pairs(discovered_nests) do
		view.expanded_nests[relative] = true
	end
	if stopped then
		vim.notify("Unfold all stopped at 5000 rows", vim.log.levels.WARN)
	end
	local prepared = hooks.prepare_draw(view, view.root)
	view.tree_watched = prepared.watched
	M.rebuild_tree(view, prepared.rows)
end

--- Prepare a path selection, expanding its containing directory and file nest.
---@param view FileTreeView
---@param path string
---@param hooks FileTreeFoldHooks
---@return string?
function M.prepare_selection(view, path, hooks)
	local normalized = fs.normalize(path)
	local row = view.rows_by_path[normalized]
	if row then
		vim.api.nvim_win_set_cursor(view.win, { row, 0 })
		return
	end
	hooks.expand_to(view, normalized)
	local loaded_settings = settings.load()
	local nesting_settings = loaded_settings.nesting
	local parent =
		model.nest_parent(fs.tree(view.root), normalized, nesting_settings, hooks.row_options(view, loaded_settings))
	if parent then
		view.expanded_nests[parent:sub(#view.root + 2)] = true
	end
	return normalized
end

return M
