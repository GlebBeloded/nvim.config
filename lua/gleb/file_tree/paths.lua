-- Pure path helpers centralize project-tree target and move safety rules.

local M = {}

---@class FileTreeMovePair
---@field old string
---@field new string

---@class FileTreePathRow
---@field kind "root"|"directory"|"file"
---@field path string

---@class FileTreePreflightFs
---@field lstat fun(path: string): table?
---@field stat fun(path: string): table?
---@field read_dir fun(path: string): string[]

---@param path string
---@return string
local function normalize(path)
	local absolute = path:sub(1, 1) == "/"
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
	local normalized = table.concat(parts, "/")
	if absolute then
		return "/" .. normalized
	end
	return normalized == "" and "." or normalized
end

---@param path string
---@return string
local function dirname(path)
	local normalized = normalize(path)
	if normalized == "/" then
		return "/"
	end
	return normalized:match("^(.+)/[^/]+$") or "."
end

---@param path string
---@return string
local function basename(path)
	return normalize(path):match("([^/]+)$") or "/"
end

---@param parent string
---@param child string
---@return boolean
local function is_descendant(parent, child)
	return child:sub(1, #parent + 1) == parent .. "/"
end

--- Resolve the folder used by create and paste for a project-tree row.
---@param root string
---@param row FileTreePathRow
---@return string
function M.target_folder(root, row)
	if row.kind == "root" then
		return root
	end
	if row.kind == "directory" then
		return row.path
	end
	return dirname(row.path)
end

--- Build the suggested non-overwriting name for a copy conflict.
---@param name string
---@param is_directory boolean
---@param number integer
---@return string
function M.copy_name(name, is_directory, number)
	local suffix = number == 1 and "_copy" or ("_copy%d"):format(number)
	if is_directory then
		return name .. suffix
	end
	local stem, extension = name:match("^(.+)(%.[^.]*)$")
	if not stem or stem == "" then
		return name .. suffix
	end
	return stem .. suffix .. extension
end

--- Check lexical containment after normalizing dot segments.
---@param root string
---@param path string
---@return boolean
function M.is_inside(root, path)
	root = normalize(root)
	path = normalize(path)
	return path == root or is_descendant(root, path)
end

--- Remove duplicate paths and descendants of another selected path.
---@param selected string[]
---@return string[]
function M.dedupe(selected)
	local normalized = {}
	for _, path in ipairs(selected) do
		normalized[path] = normalize(path)
	end

	local result = {}
	local emitted = {}
	for _, path in ipairs(selected) do
		local candidate = normalized[path]
		local nested = false
		for _, other in pairs(normalized) do
			if candidate ~= other and is_descendant(other, candidate) then
				nested = true
				break
			end
		end
		if not nested and not emitted[candidate] then
			result[#result + 1] = path
			emitted[candidate] = true
		end
	end
	return result
end

---@param pair FileTreeMovePair
---@param fs FileTreePreflightFs
---@return boolean
local function target_is_available(pair, fs)
	local parent = dirname(pair.new)
	local wanted = basename(pair.new):lower()
	for _, name in ipairs(fs.read_dir(parent)) do
		if name:lower() == wanted and normalize(parent .. "/" .. name) ~= normalize(pair.old) then
			return false
		end
	end
	return true
end

--- Validate every move pair without changing filesystem state.
---@param root string
---@param move_pairs FileTreeMovePair[]
---@param fs FileTreePreflightFs
---@return true? ok
---@return "root"|"outside-root"|"missing"|"exists"|"cross-device"? reason
---@return string? path
function M.preflight_moves(root, move_pairs, fs)
	root = normalize(root)
	local targets = {}
	for _, pair in ipairs(move_pairs) do
		local old = normalize(pair.old)
		local new = normalize(pair.new)
		if old == root then
			return nil, "root", old
		end
		if not M.is_inside(root, old) or not M.is_inside(root, new) then
			return nil, "outside-root", new
		end

		local source = fs.lstat(old)
		if not source then
			return nil, "missing", old
		end
		local parent = dirname(new)
		local destination = fs.stat(parent)
		if not destination then
			return nil, "missing", parent
		end
		if source.dev ~= destination.dev then
			return nil, "cross-device", new
		end
		if not target_is_available({ old = old, new = new }, fs) then
			return nil, "exists", new
		end

		local folded_target = new:lower()
		if targets[folded_target] then
			return nil, "exists", new
		end
		targets[folded_target] = true
	end
	return true
end

return M
