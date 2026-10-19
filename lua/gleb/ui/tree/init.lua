-- The shared tree facade joins the pure fold verbs to attached buffers without owning feature rendering.

local M = {}

local fold = require("gleb.ui.tree.fold")
local view = require("gleb.ui.tree.view")

---@param verb "close"|"open"|"toggle"|"close_all"|"open_all"
---@param tree? gleb.ui.tree.Model
---@return boolean handled
local function apply(verb, tree)
	tree = tree or view.get(0)
	if not tree then
		return false
	end
	local selected_id = view.selected_id(tree)
	if not selected_id then
		return false
	end
	local options = view.options(tree) or {}
	local next_id = fold[verb](tree, selected_id, options.expand, options.expand_all)
	view.redraw(tree, next_id)
	return true
end

M.attach = view.attach
M.draw = view.draw
M.get = view.get

---@param tree? gleb.ui.tree.Model
---@return boolean handled
function M.close(tree)
	return apply("close", tree)
end

---@param tree? gleb.ui.tree.Model
---@return boolean handled
function M.open(tree)
	return apply("open", tree)
end

---@param tree? gleb.ui.tree.Model
---@return boolean handled
function M.toggle(tree)
	return apply("toggle", tree)
end

---@param tree? gleb.ui.tree.Model
---@return boolean handled
function M.close_all(tree)
	return apply("close_all", tree)
end

---@param tree? gleb.ui.tree.Model
---@return boolean handled
function M.open_all(tree)
	return apply("open_all", tree)
end

return M
