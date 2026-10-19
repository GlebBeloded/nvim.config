-- Pure porcelain-v2 parsing gives repository views one ordered status representation.

local M = {}

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
local function tracked_status(xy)
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

---@class GitStatusRecord
---@field kind "1"|"2"|"u"|"?"|"!"
---@field xy? string
---@field sub? string
---@field path string
---@field orig? string

--- Parse porcelain v2 NUL-delimited status records in output order.
---@param porcelain_z string
---@return GitStatusRecord[]
function M.parse_records(porcelain_z)
	local fields = {}
	local offset = 1
	while offset <= #porcelain_z do
		local separator = porcelain_z:find("\0", offset, true) or (#porcelain_z + 1)
		fields[#fields + 1] = porcelain_z:sub(offset, separator - 1)
		offset = separator + 1
	end

	local records = {}
	local index = 1
	while index <= #fields do
		local field = fields[index]
		local kind = field:sub(1, 1)
		local xy, sub, path
		if kind == "1" then
			xy, sub, path = field:match("^1 ([^ ]+) ([^ ]+) [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
		elseif kind == "2" then
			xy, sub, path = field:match("^2 ([^ ]+) ([^ ]+) [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
		elseif kind == "u" then
			xy, sub, path = field:match("^u ([^ ]+) ([^ ]+) [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ [^ ]+ (.+)$")
		elseif kind == "?" or kind == "!" then
			path = field:sub(3)
		end
		if path then
			local record = { kind = kind, xy = xy, sub = sub, path = path }
			if kind == "2" then
				index = index + 1
				record.orig = fields[index]
			end
			records[#records + 1] = record
		end
		index = index + 1
	end
	return records
end

--- Parse porcelain v2 records relative to a repository prefix.
---@param porcelain_z string
---@param prefix string
---@return table<string, string> status
---@return table<string, boolean> ignored
function M.parse(porcelain_z, prefix)
	local status = {}
	local ignored = {}
	for _, record in ipairs(M.parse_records(porcelain_z)) do
		local value
		if record.kind == "1" then
			value = tracked_status(record.xy)
		elseif record.kind == "2" then
			value = "renamed"
		elseif record.kind == "u" then
			value = "conflict"
		elseif record.kind == "?" then
			value = "untracked"
		end
		local relative = strip_prefix(record.path, prefix)
		if relative then
			if record.kind == "!" then
				ignored[relative] = true
			elseif value then
				status[relative] = value
			end
		end
	end
	return status, ignored
end

return M
