-- Changes rows turn ordered porcelain records into the panel's compact directory tree.

local M = {}

local file_tree_model = require("gleb.file_tree.model")

local MAX_ROWS = 5000
local CHECKBOX_EMPTY = "󰄱"
local CHECKBOX_CHECKED = "󰄲"
local CHECKBOX_MIXED = "󰡖"

---@class ChangesTreeNode
---@field name string
---@field path string
---@field count integer
---@field staged boolean
---@field unstaged boolean
---@field directories table<string, ChangesTreeNode>
---@field files ChangesRow[]

---@class ChangesRow
---@field kind "root"|"directory"|"file"
---@field root "changes"|"unversioned"
---@field label string
---@field depth integer
---@field path? string
---@field count? integer
---@field fold_id? string
---@field expanded? boolean
---@field status? string
---@field xy? string
---@field orig? string
---@field submodule? boolean
---@field directory_record? boolean
---@field diffable? boolean
---@field checkbox? string

local ROOTS = {
	changes = { label = "Changes" },
	unversioned = { label = "Unversioned Files" },
}

---@param name string
---@param path string
---@return ChangesTreeNode
local function tree_node(name, path)
	return { name = name, path = path, count = 0, staged = false, unstaged = false, directories = {}, files = {} }
end

---@param staged boolean
---@param unstaged boolean
---@return string
local function checkbox(staged, unstaged)
	if staged and unstaged then
		return CHECKBOX_MIXED
	end
	if staged then
		return CHECKBOX_CHECKED
	end
	return CHECKBOX_EMPTY
end

---@param record FileTreeStatusRecord
---@return boolean staged
---@return boolean unstaged
local function record_index_state(record)
	if record.kind == "?" then
		return false, true
	end
	local xy = record.xy or ".."
	return xy:sub(1, 1) ~= ".", xy:sub(2, 2) ~= "."
end

---@param left { name?: string, label?: string }
---@param right { name?: string, label?: string }
---@return boolean
local function named_before(left, right)
	local left_name = left.name or left.label or ""
	local right_name = right.name or right.label or ""
	local left_folded = left_name:lower()
	local right_folded = right_name:lower()
	if left_folded ~= right_folded then
		return left_folded < right_folded
	end
	return left_name < right_name
end

---@param record FileTreeStatusRecord
---@return string
local function record_status(record)
	if record.kind == "?" then
		return "untracked"
	end
	if record.kind == "u" then
		return "conflict"
	end
	if record.kind == "2" then
		return "renamed"
	end
	local xy = record.xy or ""
	if xy:find("A", 1, true) then
		return "added"
	end
	if xy:find("D", 1, true) then
		return "deleted"
	end
	if xy:find("R", 1, true) or xy:find("C", 1, true) then
		return "renamed"
	end
	return "modified"
end

---@param root ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@param record FileTreeStatusRecord
---@return nil
local function insert_record(root, root_name, record)
	local staged, unstaged = record_index_state(record)
	local display_path = record.path:gsub("/+$", "")
	local parts = vim.split(display_path, "/", { plain = true, trimempty = true })
	local node = root
	node.count = node.count + 1
	node.staged = node.staged or staged
	node.unstaged = node.unstaged or unstaged
	for index = 1, #parts - 1 do
		local name = parts[index]
		local child = node.directories[name]
		if not child then
			local path = node.path == "" and name or node.path .. "/" .. name
			child = tree_node(name, path)
			node.directories[name] = child
		end
		child.count = child.count + 1
		node = child
	end

	local directory_record = record.kind == "?" and record.path:sub(-1) == "/"
	local submodule = record.sub ~= nil and record.sub:sub(1, 1) == "S"
	node.files[#node.files + 1] = {
		kind = "file",
		root = root_name,
		label = parts[#parts] or display_path,
		depth = 0,
		path = record.path,
		status = record_status(record),
		xy = record.xy,
		orig = record.orig,
		submodule = submodule,
		directory_record = directory_record,
		diffable = not directory_record and not submodule,
		checkbox = checkbox(staged, unstaged),
	}
end

---@param directories table<string, ChangesTreeNode>
---@return ChangesTreeNode[]
local function sorted_directories(directories)
	local result = {}
	for _, directory in pairs(directories) do
		result[#result + 1] = directory
	end
	table.sort(result, named_before)
	return result
end

---@param node ChangesTreeNode
---@return ChangesTreeNode?
local function only_directory(node)
	local child
	for _, directory in pairs(node.directories) do
		if child then
			return nil
		end
		child = directory
	end
	return child
end

---@param rows ChangesRow[]
---@param node ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@param depth integer
---@return boolean complete
local function append_directory(rows, node, root_name, depth)
	local labels = { node.name }
	local tail = node
	local child = #tail.files == 0 and only_directory(tail) or nil
	while child do
		labels[#labels + 1] = child.name
		tail = child
		child = #tail.files == 0 and only_directory(tail) or nil
	end
	if #rows >= MAX_ROWS then
		return false
	end
	rows[#rows + 1] = {
		kind = "directory",
		root = root_name,
		label = table.concat(labels, "/"),
		depth = depth,
		path = tail.path,
		count = tail.count,
		fold_id = root_name .. ":" .. tail.path,
		expanded = true,
	}

	for _, directory in ipairs(sorted_directories(tail.directories)) do
		if not append_directory(rows, directory, root_name, depth + 1) then
			return false
		end
	end
	table.sort(tail.files, named_before)
	for _, file in ipairs(tail.files) do
		if #rows >= MAX_ROWS then
			return false
		end
		file.depth = depth + 1
		rows[#rows + 1] = file
	end
	return true
end

---@param rows ChangesRow[]
---@param root ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@return boolean complete
local function append_root(rows, root, root_name)
	if root.count == 0 then
		return true
	end
	if #rows >= MAX_ROWS then
		return false
	end
	rows[#rows + 1] = {
		kind = "root",
		root = root_name,
		label = ROOTS[root_name].label,
		depth = 0,
		count = root.count,
		fold_id = root_name,
		expanded = true,
		checkbox = checkbox(root.staged, root.unstaged),
	}
	for _, directory in ipairs(sorted_directories(root.directories)) do
		if not append_directory(rows, directory, root_name, 1) then
			return false
		end
	end
	table.sort(root.files, named_before)
	for _, file in ipairs(root.files) do
		if #rows >= MAX_ROWS then
			return false
		end
		file.depth = 1
		rows[#rows + 1] = file
	end
	return true
end

--- Build compact Changes panel rows from porcelain-v2 output.
---@param porcelain_z string
---@param _nesting_rules table[]
---@return ChangesRow[] rows
---@return boolean capped
function M.rows(porcelain_z, _nesting_rules)
	local roots = {
		changes = tree_node("", ""),
		unversioned = tree_node("", ""),
	}
	for _, record in ipairs(file_tree_model.parse_status_records(porcelain_z)) do
		if record.kind ~= "!" then
			local root_name = record.kind == "?" and "unversioned" or "changes"
			insert_record(roots[root_name], root_name, record)
		end
	end

	local rows = {}
	local complete = append_root(rows, roots.changes, "changes")
	if complete then
		complete = append_root(rows, roots.unversioned, "unversioned")
	end
	return rows, not complete
end

return M
