-- Find Usages grouping is persisted separately from the transient view and fold state.
local M = {}

---@class gleb.references.PersistedState: gleb.references.TreeOptions
---@field tests "grouped"|"hidden"|"mixed"
---@field folders boolean
---@field usage_type boolean

local DEFAULTS = { tests = "grouped", folders = true, usage_type = true }

---@return string
local function path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "references.json")
end

---@param value unknown
---@return boolean
local function valid(value)
	return type(value) == "table"
		and (value.tests == nil or value.tests == "grouped" or value.tests == "hidden" or value.tests == "mixed")
		and (value.folders == nil or type(value.folders) == "boolean")
		and (value.usage_type == nil or type(value.usage_type) == "boolean")
		and (value.read_write == nil or type(value.read_write) == "boolean")
end

---@return gleb.references.PersistedState
function M.load()
	local read_ok, lines = pcall(vim.fn.readfile, path())
	if not read_ok then
		return vim.deepcopy(DEFAULTS)
	end
	local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decode_ok or not valid(decoded) then
		return vim.deepcopy(DEFAULTS)
	end
	local migrated = decoded.usage_type == nil and decoded.read_write ~= nil
	local result = {
		tests = decoded.tests or DEFAULTS.tests,
		folders = decoded.folders == nil and DEFAULTS.folders or decoded.folders,
		usage_type = decoded.usage_type,
	}
	if result.usage_type == nil then
		if migrated then
			result.usage_type = decoded.read_write
		else
			result.usage_type = DEFAULTS.usage_type
		end
	end
	if migrated then
		M.save(result)
	end
	return result
end

---@param value gleb.references.PersistedState
---@return nil
function M.save(value)
	vim.fn.mkdir(vim.fs.dirname(path()), "p")
	vim.fn.writefile({ vim.json.encode(value, { sort_keys = true }) }, path())
end

return M
