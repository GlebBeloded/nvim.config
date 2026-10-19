-- The shared tree model keeps feature payloads separate from stable fold state and visible-row traversal.

local M = {}

---@class gleb.ui.tree.Node
---@field id string
---@field parent? gleb.ui.tree.Node
---@field children? gleb.ui.tree.Node[]
---@field foldable? boolean
---@field pinned? boolean
---@field open_by_default? boolean
---@field data? any

---@class gleb.ui.tree.Model
---@field roots gleb.ui.tree.Node[]
---@field nodes table<string, gleb.ui.tree.Node>
---@field parents table<string, string>
---@field folds table<string, boolean>

---@class gleb.ui.tree.Row
---@field id string
---@field depth integer
---@field node gleb.ui.tree.Node

---@param nodes gleb.ui.tree.Node[]
---@return table<string, gleb.ui.tree.Node> indexed
---@return table<string, string> parents
local function index_nodes(nodes)
	local indexed = {}
	local parents = {}

	---@param children gleb.ui.tree.Node[]
	---@param parent? gleb.ui.tree.Node
	local function visit(children, parent)
		for _, node in ipairs(children) do
			indexed[node.id] = node
			if parent then
				parents[node.id] = parent.id
			end
			visit(node.children or {}, node)
		end
	end

	visit(nodes)
	return indexed, parents
end

---@param tree gleb.ui.tree.Model
---@param nodes gleb.ui.tree.Node[]
---@return gleb.ui.tree.Model
function M.rebuild(tree, nodes)
	local indexed, parents = index_nodes(nodes)
	local folds = {}
	for id, node in pairs(indexed) do
		if node.foldable and not node.pinned then
			local existing = tree.folds[id]
			if existing ~= nil then
				folds[id] = existing
			else
				folds[id] = not node.open_by_default
			end
		end
	end

	tree.roots = nodes
	tree.nodes = indexed
	tree.parents = parents
	tree.folds = folds
	return tree
end

---@param nodes gleb.ui.tree.Node[]
---@return gleb.ui.tree.Model
function M.new(nodes)
	return M.rebuild({ roots = {}, nodes = {}, parents = {}, folds = {} }, nodes)
end

---@param tree gleb.ui.tree.Model
---@param id string
---@param open boolean
---@return boolean changed
function M.set_open(tree, id, open)
	local node = tree.nodes[id]
	if not node or not node.foldable or node.pinned then
		return false
	end

	local folded = not open
	if tree.folds[id] == folded then
		return false
	end
	tree.folds[id] = folded
	return true
end

---@param tree gleb.ui.tree.Model
---@return gleb.ui.tree.Row[]
function M.rows(tree)
	local rows = {}

	---@param nodes gleb.ui.tree.Node[]
	---@param depth integer
	local function append(nodes, depth)
		for _, node in ipairs(nodes) do
			rows[#rows + 1] = { id = node.id, depth = depth, node = node }
			if not tree.folds[node.id] then
				append(node.children or {}, depth + 1)
			end
		end
	end

	append(tree.roots, 0)
	return rows
end

return M
