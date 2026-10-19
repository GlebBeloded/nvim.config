-- Changes rows turn ordered porcelain records into the panel's compact directory tree.

local M = {}

local git_status = require("gleb.git.status")
local nesting = require("gleb.tree.nesting")

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
---@field added? integer
---@field removed? integer

---@class ChangesNumstat
---@field added integer
---@field removed integer
---@field orig? string

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

---@param record GitStatusRecord
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

---@param record GitStatusRecord
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

---@param numstat_z? string
---@return table<string, ChangesNumstat>
local function parse_numstat(numstat_z)
	local stats = {}
	if not numstat_z then
		return stats
	end

	local fields = vim.split(numstat_z, "\0", { plain = true })
	local index = 1
	while index <= #fields do
		local added, removed, path = fields[index]:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		local orig
		if path == "" then
			orig = fields[index + 1]
			path = fields[index + 2]
			index = index + 2
		end
		local added_number = tonumber(added)
		local removed_number = tonumber(removed)
		if path and added_number and removed_number then
			stats[path] = { added = added_number, removed = removed_number, orig = orig }
		end
		index = index + 1
	end
	return stats
end

---@param root ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@param record GitStatusRecord
---@param stats table<string, ChangesNumstat>
---@return nil
local function insert_record(root, root_name, record, stats)
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
	local stat = record.kind ~= "?" and stats[record.path] or nil
	if stat and stat.orig and stat.orig ~= record.orig then
		stat = nil
	end
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
		added = stat and stat.added or nil,
		removed = stat and stat.removed or nil,
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
---@param files ChangesRow[]
---@param directory string
---@param root_name "changes"|"unversioned"
---@param depth integer
---@param nesting_rules table[]
---@return boolean complete
local function append_files(rows, files, directory, root_name, depth, nesting_rules)
	table.sort(files, named_before)
	local entries = {}
	local files_by_name = {}
	for _, file in ipairs(files) do
		entries[#entries + 1] = { kind = "file", name = file.label, path = file.path }
		files_by_name[file.label] = file
	end
	local nests = nesting.nest(directory, entries, nesting_rules)
	local nested = {}
	for _, children in pairs(nests) do
		for _, child_name in ipairs(children) do
			nested[child_name] = true
		end
	end

	local function append_file(file, file_depth)
		if #rows >= MAX_ROWS then
			return false
		end
		file.depth = file_depth
		rows[#rows + 1] = file
		return true
	end

	for _, file in ipairs(files) do
		if not nested[file.label] then
			local children = nests[file.label]
			if children then
				file.expanded = true
				file.fold_id = root_name .. ":" .. file.path
			end
			if not append_file(file, depth) then
				return false
			end
			for _, child_name in ipairs(children or {}) do
				if not append_file(files_by_name[child_name], depth + 1) then
					return false
				end
			end
		end
	end
	return true
end

---@param rows ChangesRow[]
---@param node ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@param depth integer
---@param nesting_rules table[]
---@return boolean complete
local function append_directory(rows, node, root_name, depth, nesting_rules)
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
		if not append_directory(rows, directory, root_name, depth + 1, nesting_rules) then
			return false
		end
	end
	return append_files(rows, tail.files, tail.path, root_name, depth + 1, nesting_rules)
end

---@param rows ChangesRow[]
---@param root ChangesTreeNode
---@param root_name "changes"|"unversioned"
---@param nesting_rules table[]
---@return boolean complete
local function append_root(rows, root, root_name, nesting_rules)
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
		if not append_directory(rows, directory, root_name, 1, nesting_rules) then
			return false
		end
	end
	return append_files(rows, root.files, "", root_name, 1, nesting_rules)
end

--- Build compact Changes panel rows from porcelain-v2 output.
---@param porcelain_z string
---@param nesting_rules table[]
---@param numstat_z? string Output is absent when HEAD is unborn.
---@return ChangesRow[] rows
---@return boolean capped
function M.rows(porcelain_z, nesting_rules, numstat_z)
	local roots = {
		changes = tree_node("", ""),
		unversioned = tree_node("", ""),
	}
	local stats = parse_numstat(numstat_z)
	for _, record in ipairs(git_status.parse_records(porcelain_z)) do
		if record.kind ~= "!" then
			local root_name = record.kind == "?" and "unversioned" or "changes"
			insert_record(roots[root_name], root_name, record, stats)
		end
	end

	local rows = {}
	local complete = append_root(rows, roots.changes, "changes", nesting_rules)
	if complete then
		complete = append_root(rows, roots.unversioned, "unversioned", nesting_rules)
	end
	return rows, not complete
end

return M
