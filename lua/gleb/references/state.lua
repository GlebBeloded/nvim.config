-- Find Usages grouping is persisted separately from the transient view and fold state.
local M = {}

---@class gleb.references.PersistedState: gleb.references.TreeOptions
---@field tests "grouped"|"hidden"|"mixed"
---@field folders boolean
---@field read_write boolean

local DEFAULTS = { tests = "grouped", folders = true, read_write = true }

---@return string
local function path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "references.json")
end

---@param value unknown
---@return boolean
local function valid(value)
	return type(value) == "table"
		and (value.tests == "grouped" or value.tests == "hidden" or value.tests == "mixed")
		and type(value.folders) == "boolean"
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
	decoded.read_write = decoded.read_write ~= false
	return decoded
end

---@param value gleb.references.PersistedState
---@return nil
function M.save(value)
	vim.fn.mkdir(vim.fs.dirname(path()), "p")
	vim.fn.writefile({ vim.json.encode(value, { sort_keys = true }) }, path())
end

return M
