-- Tree fold verbs centralize cursor movement and fold semantics while feature views keep control of rendering.

local M = {}

local model = require("gleb.ui.tree.model")

---@alias gleb.ui.tree.Expand fun(node: gleb.ui.tree.Node): boolean

---@param tree gleb.ui.tree.Model
---@param id string
---@return string?
local function foldable_ancestor(tree, id)
	local parent_id = tree.parents[id]
	while parent_id do
		local parent = tree.nodes[parent_id]
		if parent and parent.foldable and not parent.pinned then
			return parent_id
		end
		parent_id = tree.parents[parent_id]
	end
end

---@param tree gleb.ui.tree.Model
---@param node gleb.ui.tree.Node
---@param expand? gleb.ui.tree.Expand
---@return boolean
local function expand_node(tree, node, expand)
	if expand and not expand(node) then
		return false
	end
	return model.set_open(tree, node.id, true)
end

---@param tree gleb.ui.tree.Model
---@param selected_id string
---@return string selected_id
function M.close(tree, selected_id)
	local selected = tree.nodes[selected_id]
	if not selected then
		return selected_id
	end

	if selected.foldable and not selected.pinned and not tree.folds[selected_id] then
		model.set_open(tree, selected_id, false)
		return selected_id
	end

	local parent_id = foldable_ancestor(tree, selected_id)
	if parent_id then
		model.set_open(tree, parent_id, false)
		return parent_id
	end
	return selected_id
end

---@param tree gleb.ui.tree.Model
---@param selected_id string
---@param expand? gleb.ui.tree.Expand
---@return string selected_id
function M.open(tree, selected_id, expand)
	local selected = tree.nodes[selected_id]
	if not selected or not selected.foldable then
		return selected_id
	end

	if tree.folds[selected_id] then
		expand_node(tree, selected, expand)
		return selected_id
	end

	local first_child = selected.children and selected.children[1]
	return first_child and first_child.id or selected_id
end

---@param tree gleb.ui.tree.Model
---@param selected_id string
---@param expand? gleb.ui.tree.Expand
---@return string selected_id
function M.toggle(tree, selected_id, expand)
	local selected = tree.nodes[selected_id]
	if not selected or not selected.foldable then
		return M.close(tree, selected_id)
	end
	if tree.folds[selected_id] then
		expand_node(tree, selected, expand)
		return selected_id
	end
	return M.close(tree, selected_id)
end

---@param tree gleb.ui.tree.Model
---@param selected_id string
---@return string selected_id
function M.close_all(tree, selected_id)
	for id, node in pairs(tree.nodes) do
		if node.foldable and not node.pinned then
			model.set_open(tree, id, false)
		end
	end

	local top_id = selected_id
	while tree.parents[top_id] do
		top_id = tree.parents[top_id]
	end
	return top_id
end

---@param tree gleb.ui.tree.Model
---@param selected_id string
---@param expand? gleb.ui.tree.Expand
---@return string selected_id
function M.open_all(tree, selected_id, expand)
	for _, node in pairs(tree.nodes) do
		if node.foldable and tree.folds[node.id] then
			expand_node(tree, node, expand)
		end
	end
	return selected_id
end

return M
