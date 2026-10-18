-- Pure project-tree row construction keeps filesystem and editor concerns outside the model.

local M = {}

local nesting = require("gleb.file_tree.nesting")
local ignore = require("gleb.file_tree.ignore")

---@class FileTreeNestingSettings
---@field enabled boolean
---@field rules table[]
---@field generation integer

---@class FileTreeNestCacheEntry
---@field generation integer
---@field rules table[]
---@field map table<string, string[]>
---@field matcher? FileTreeIgnoreMatcher

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

---@param strongest string?
---@param candidate string?
---@return string?
local function stronger_descendant_status(strongest, candidate)
	if not candidate or (STATUS_STRENGTH[candidate] or 0) <= (STATUS_STRENGTH[strongest] or 0) then
		return strongest
	end
	return (candidate == "renamed" or candidate == "deleted") and "modified" or candidate
end

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
---@field nest_expanded? boolean
---@field nest_parent? string

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
	local prefix = path:gsub("/+$", "") .. "/"
	for candidate, value in pairs(status) do
		if candidate == path or candidate == prefix or candidate:sub(1, #prefix) == prefix then
			strongest = stronger_descendant_status(strongest, value)
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

---@param status table<string, string>
---@param tree FileTreeSource
---@param entry FileTreeEntry
---@param child_names string[]?
---@param entries_by_name table<string, FileTreeEntry>
---@return string?
local function nest_parent_status(status, tree, entry, child_names, entries_by_name)
	local direct = path_status(status, relative_path(tree.root, entry.path), false)
	if direct or not child_names then
		return direct
	end
	local strongest
	for _, child_name in ipairs(child_names) do
		local child = entries_by_name[child_name]
		if child then
			local child_status = path_status(status, relative_path(tree.root, child.path), false)
			strongest = stronger_descendant_status(strongest, child_status)
		end
	end
	return strongest
end

---@param tree FileTreeSource
---@param path string
---@param nesting_settings? FileTreeNestingSettings
---@param matcher? FileTreeIgnoreMatcher
---@return FileTreeEntry[]
---@return table<string, string[]>
local function visible_entries(tree, path, nesting_settings, matcher)
	local scan = tree.scan(path)
	local entries = {}
	for _, entry in ipairs(scan) do
		local relative = relative_path(tree.root, entry.path)
		if
			entry.name ~= ".git"
			and (not matcher or not ignore.is_ignored({}, matcher, relative, entry.kind == "directory", false))
		then
			entries[#entries + 1] = entry
		end
	end
	local nest_map = {}
	if nesting_settings and nesting_settings.enabled then
		local cached = nest_cache[scan]
		if
			not cached
			or cached.generation ~= nesting_settings.generation
			or cached.rules ~= nesting_settings.rules
			or cached.matcher ~= matcher
		then
			cached = {
				generation = nesting_settings.generation,
				rules = nesting_settings.rules,
				matcher = matcher,
				map = nesting.nest(path, entries, nesting_settings.rules),
			}
			nest_cache[scan] = cached
		end
		nest_map = cached.map
	end
	return M.sort(entries), nest_map
end

--- Return whether a file is currently a parent in its folder's nest map.
---@param tree FileTreeSource
---@param path string
---@param nesting_settings? FileTreeNestingSettings
---@param matcher? FileTreeIgnoreMatcher
---@return boolean
function M.has_nest(tree, path, nesting_settings, matcher)
	local _, nest_map = visible_entries(tree, vim.fs.dirname(path), nesting_settings, matcher)
	local children = nest_map[basename(path)]
	return children ~= nil and #children > 0
end

--- Return the parent path when a file is nested in its folder.
---@param tree FileTreeSource
---@param path string
---@param nesting_settings? FileTreeNestingSettings
---@param matcher? FileTreeIgnoreMatcher
---@return string?
function M.nest_parent(tree, path, nesting_settings, matcher)
	local directory = vim.fs.dirname(path)
	local _, nest_map = visible_entries(tree, directory, nesting_settings, matcher)
	local name = basename(path)
	for parent, children in pairs(nest_map) do
		if vim.tbl_contains(children, name) then
			return vim.fs.joinpath(directory, parent)
		end
	end
	return nil
end

---@param tree FileTreeSource
---@param entry FileTreeEntry
---@param nesting_settings? FileTreeNestingSettings
---@param matcher? FileTreeIgnoreMatcher
---@return string label
---@return FileTreeEntry tail
---@return FileTreeEntry[] children
local function compact_directory(tree, entry, nesting_settings, matcher)
	local names = { entry.name }
	local tail = entry
	local children = visible_entries(tree, tail.path, nesting_settings, matcher)
	while #children == 1 and children[1].kind == "directory" do
		tail = children[1]
		names[#names + 1] = tail.name
		children = visible_entries(tree, tail.path, nesting_settings, matcher)
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
---@param expanded_nests? table<string, boolean>
---@param matcher? FileTreeIgnoreMatcher
local function append_children(tree, expanded, status, rows, path, depth, nesting_settings, expanded_nests, matcher)
	local entries, nest_map = visible_entries(tree, path, nesting_settings, matcher)
	local entries_by_name = {}
	local nested = {}
	for _, entry in ipairs(entries) do
		entries_by_name[entry.name] = entry
	end
	for _, child_names in pairs(nest_map) do
		for _, child_name in ipairs(child_names) do
			nested[child_name] = true
		end
	end
	for _, entry in ipairs(entries) do
		if not nested[entry.name] then
			local label = entry.name
			local tail = entry
			local children = {}
			if entry.kind == "directory" then
				label, tail, children = compact_directory(tree, entry, nesting_settings, matcher)
			end
			local relative = relative_path(tree.root, tail.path)
			local is_expanded = tail.kind == "directory" and expanded[relative] == true
			local nest_children = nest_map[entry.name]
			local nest_expanded = nest_children ~= nil and expanded_nests ~= nil and expanded_nests[relative] == true
			local row_status = tail.kind == "file"
					and nest_parent_status(status, tree, tail, nest_children, entries_by_name)
				or path_status(status, relative, tail.kind == "directory")
			rows[#rows + 1] = {
				depth = depth,
				kind = tail.kind,
				label = label,
				path = tail.path,
				expanded = is_expanded,
				empty = tail.kind == "directory" and #children == 0,
				status = row_status,
				nest_children = nest_children,
				nest_expanded = nest_expanded,
			}
			if is_expanded then
				append_children(
					tree,
					expanded,
					status,
					rows,
					tail.path,
					depth + 1,
					nesting_settings,
					expanded_nests,
					matcher
				)
			elseif nest_expanded then
				for _, child_name in ipairs(nest_children) do
					local child = entries_by_name[child_name]
					if child then
						rows[#rows + 1] = {
							depth = depth + 1,
							kind = "file",
							label = child.name,
							path = child.path,
							expanded = false,
							empty = false,
							status = path_status(status, relative_path(tree.root, child.path), false),
							nest_parent = entry.path,
						}
					end
				end
			end
		end
	end
end

--- Flatten the visible portion of a project tree into rows.
---@param tree FileTreeSource
---@param expanded table<string, boolean>
---@param status table<string, string>
---@param nesting_settings? FileTreeNestingSettings
---@param expanded_nests? table<string, boolean>
---@param matcher? FileTreeIgnoreMatcher
---@return FileTreeRow[]
function M.rows(tree, expanded, status, nesting_settings, expanded_nests, matcher)
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
	append_children(tree, expanded, status, rows, tree.root, 0, nesting_settings, expanded_nests, matcher)
	return rows
end

return M
