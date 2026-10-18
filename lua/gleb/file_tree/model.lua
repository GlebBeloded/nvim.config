-- Pure project-tree row construction keeps filesystem and editor concerns outside the model.

local M = {}

local nesting = require("gleb.file_tree.nesting")

---@class FileTreeNestingSettings
---@field enabled boolean
---@field rules table[]
---@field generation integer

---@class FileTreeNestCacheEntry
---@field generation integer
---@field rules table[]
---@field map table<string, string[]>

---@type table<table, FileTreeNestCacheEntry>
local nest_cache = setmetatable({}, { __mode = "k" })

local STATUS_STRENGTH = {
	untracked = 1,
	added = 2,
	deleted = 3,
	renamed = 3,
	modified = 3,
	conflict = 4,
}

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
---@field nest_children? string[]

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

---@param path string
---@param prefix string
---@return string?
local function strip_prefix(path, prefix)
	prefix = prefix:gsub("/+$", "")
	if prefix == "" then
		return path
	end
	if path:sub(1, #prefix + 1) ~= prefix .. "/" then
		return nil
	end
	return path:sub(#prefix + 2)
end

---@param xy string
---@return string
local function ordinary_status(xy)
	if xy:sub(1, 1) == "A" then
		return "added"
	end
	if xy:find("D", 1, true) then
		return "deleted"
	end
	return "modified"
end

--- Parse porcelain v2 NUL-delimited status records relative to a repository prefix.
---@param porcelain_z string
---@param prefix string
---@return table<string, string>
function M.parse_status(porcelain_z, prefix)
	local status = {}
	local offset = 1
	while offset <= #porcelain_z do
		local separator = porcelain_z:find("\0", offset, true) or (#porcelain_z + 1)
		local record = porcelain_z:sub(offset, separator - 1)
		local kind = record:sub(1, 1)
		local path
		local value
		if kind == "1" then
			local xy
			xy, path = record:match("^1 ([^ ]+) [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
			if xy then
				value = ordinary_status(xy)
			end
		elseif kind == "2" then
			path = record:match("^2 [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
			value = "renamed"
		elseif kind == "u" then
			path = record:match("^u [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
			value = "conflict"
		elseif kind == "?" then
			path = record:sub(3)
			value = "untracked"
		end
		if path and value then
			local relative = strip_prefix(path, prefix)
			if relative then
				status[relative] = value
			end
		end
		offset = separator + 1
	end
	return status
end

--- Return the strongest status at or below a folder path.
---@param status table<string, string>
---@param path string
---@return string?
function M.folder_status(status, path)
	local strongest
	local strength = 0
	local prefix = path:gsub("/+$", "") .. "/"
	for candidate, value in pairs(status) do
		if candidate == path or candidate == prefix or candidate:sub(1, #prefix) == prefix then
			local candidate_strength = STATUS_STRENGTH[value] or 0
			if candidate_strength > strength then
				strength = candidate_strength
				strongest = (value == "renamed" or value == "deleted") and "modified" or value
			end
		end
	end
	return strongest
end

---@param status table<string, string>
---@param relative string
---@param directory boolean
---@return string?
local function path_status(status, relative, directory)
	local direct = status[relative] or (directory and status[relative .. "/"] or nil)
	if direct then
		return direct
	end
	local parent = relative:match("^(.*)/[^/]+$")
	while parent do
		if status[parent .. "/"] == "untracked" then
			return "untracked"
		end
		parent = parent:match("^(.*)/[^/]+$")
	end
	return nil
end

---@param tree FileTreeSource
---@param path string
---@param nesting_settings? FileTreeNestingSettings
---@return FileTreeEntry[]
---@return table<string, string[]>
local function visible_entries(tree, path, nesting_settings)
	local scan = tree.scan(path)
	local entries = {}
	for _, entry in ipairs(scan) do
		if entry.name ~= ".git" then
			entries[#entries + 1] = entry
		end
	end
	local nest_map = {}
	if nesting_settings and nesting_settings.enabled then
		local cached = nest_cache[scan]
		if not cached or cached.generation ~= nesting_settings.generation or cached.rules ~= nesting_settings.rules then
			cached = {
				generation = nesting_settings.generation,
				rules = nesting_settings.rules,
				map = nesting.nest(path, entries, nesting_settings.rules),
			}
			nest_cache[scan] = cached
		end
		nest_map = cached.map
	end
	return M.sort(entries), nest_map
end

---@param tree FileTreeSource
---@param entry FileTreeEntry
---@param nesting_settings? FileTreeNestingSettings
---@return string label
---@return FileTreeEntry tail
---@return FileTreeEntry[] children
local function compact_directory(tree, entry, nesting_settings)
	local names = { entry.name }
	local tail = entry
	local children = visible_entries(tree, tail.path, nesting_settings)
	while #children == 1 and children[1].kind == "directory" do
		tail = children[1]
		names[#names + 1] = tail.name
		children = visible_entries(tree, tail.path, nesting_settings)
	end
	return table.concat(names, "/"), tail, children
end

---@param tree FileTreeSource
---@param expanded table<string, boolean>
---@param status table<string, string>
---@param rows FileTreeRow[]
---@param path string
---@param depth integer
---@param nesting_settings? FileTreeNestingSettings
local function append_children(tree, expanded, status, rows, path, depth, nesting_settings)
	local entries, nest_map = visible_entries(tree, path, nesting_settings)
	for _, entry in ipairs(entries) do
		local label = entry.name
		local tail = entry
		local children = {}
		if entry.kind == "directory" then
			label, tail, children = compact_directory(tree, entry, nesting_settings)
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
			status = path_status(status, relative, tail.kind == "directory"),
			nest_children = nest_map[entry.name],
		}
		if is_expanded then
			append_children(tree, expanded, status, rows, tail.path, depth + 1, nesting_settings)
		end
	end
end

--- Flatten the visible portion of a project tree into rows.
---@param tree FileTreeSource
---@param expanded table<string, boolean>
---@param status table<string, string>
---@param nesting_settings? FileTreeNestingSettings
---@return FileTreeRow[]
function M.rows(tree, expanded, status, nesting_settings)
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
	append_children(tree, expanded, status, rows, tree.root, 0, nesting_settings)
	return rows
end

return M
