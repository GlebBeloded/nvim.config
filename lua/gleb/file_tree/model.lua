-- Pure project-tree row construction keeps filesystem and editor concerns outside the model.

local M = {}

---@class FileTreeEntry
---@field name string
---@field path string
---@field kind "directory"|"file"

---@class FileTreeSource
---@field root string
---@field scan fun(path: string): FileTreeEntry[]

---@class FileTreeRow
---@field depth integer
---@field kind "root"|"directory"|"file"
---@field label string
---@field path string
---@field expanded boolean
---@field empty boolean
---@field status string?

---@param path string
---@return string
local function basename(path)
	return path:match("([^/]+)/*$") or path
end

---@param root string
---@param path string
---@return string
local function relative_path(root, path)
	return path:sub(#root + 2)
end

---@param left FileTreeEntry
---@param right FileTreeEntry
---@return boolean
local function entry_before(left, right)
	if left.kind ~= right.kind then
		return left.kind == "directory"
	end
	local left_folded = left.name:lower()
	local right_folded = right.name:lower()
	if left_folded ~= right_folded then
		return left_folded < right_folded
	end
	return left.name < right.name
end

--- Sort entries in project-tree display order.
---@param entries FileTreeEntry[]
---@return FileTreeEntry[] entries
function M.sort(entries)
	table.sort(entries, entry_before)
	return entries
end

---@param tree FileTreeSource
---@param path string
---@return FileTreeEntry[]
local function visible_entries(tree, path)
	local entries = {}
	for _, entry in ipairs(tree.scan(path)) do
		if entry.name ~= ".git" then
			entries[#entries + 1] = entry
		end
	end
	return M.sort(entries)
end

---@param tree FileTreeSource
---@param entry FileTreeEntry
---@return string label
---@return FileTreeEntry tail
---@return FileTreeEntry[] children
local function compact_directory(tree, entry)
	local names = { entry.name }
	local tail = entry
	local children = visible_entries(tree, tail.path)
	while #children == 1 and children[1].kind == "directory" do
		tail = children[1]
		names[#names + 1] = tail.name
		children = visible_entries(tree, tail.path)
	end
	return table.concat(names, "/"), tail, children
end

---@param tree FileTreeSource
---@param expanded table<string, boolean>
---@param status table<string, string>
---@param rows FileTreeRow[]
---@param path string
---@param depth integer
local function append_children(tree, expanded, status, rows, path, depth)
	for _, entry in ipairs(visible_entries(tree, path)) do
		local label = entry.name
		local tail = entry
		local children = {}
		if entry.kind == "directory" then
			label, tail, children = compact_directory(tree, entry)
		end
		local relative = relative_path(tree.root, tail.path)
		local is_expanded = tail.kind == "directory" and expanded[relative] == true
		rows[#rows + 1] = {
			depth = depth,
			kind = tail.kind,
			label = label,
			path = tail.path,
			expanded = is_expanded,
			empty = tail.kind == "directory" and #children == 0,
			status = status[relative],
		}
		if is_expanded then
			append_children(tree, expanded, status, rows, tail.path, depth + 1)
		end
	end
end

--- Flatten the visible portion of a project tree into rows.
---@param tree FileTreeSource
---@param expanded table<string, boolean>
---@param status table<string, string>
---@return FileTreeRow[]
function M.rows(tree, expanded, status)
	local rows = {
		{
			depth = 0,
			kind = "root",
			label = basename(tree.root),
			path = tree.root,
			expanded = true,
			empty = false,
		},
	}
	append_children(tree, expanded, status, rows, tree.root, 0)
	return rows
end

return M
