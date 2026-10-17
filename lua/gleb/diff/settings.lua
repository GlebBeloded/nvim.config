-- Diff comparison choices persist independently from open views so later views use the same IntelliJ-style policy.

local M = {}

---@class gleb.diff.Settings
---@field policy gleb.diff.Policy
---@field highlight gleb.diff.Highlight

---@type gleb.diff.Settings
local DEFAULTS = { policy = "default", highlight = "by_word" }

local POLICIES = {
	default = true,
	trim_whitespaces = true,
	ignore_whitespaces = true,
	ignore_whitespaces_chunks = true,
}

local HIGHLIGHTS = {
	by_word = true,
	by_word_split = true,
	by_char = true,
	by_line = true,
	none = true,
}

---@return string
local function path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")
end

---@param value unknown
---@return boolean
local function valid(value)
	return type(value) == "table"
		and (value.policy == nil or POLICIES[value.policy] == true)
		and (value.highlight == nil or HIGHLIGHTS[value.highlight] == true)
end

---@return gleb.diff.Settings
function M.load()
	local read_ok, lines = pcall(vim.fn.readfile, path())
	if not read_ok then
		return vim.deepcopy(DEFAULTS)
	end
	local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decode_ok or not valid(decoded) then
		return vim.deepcopy(DEFAULTS)
	end
	return {
		policy = decoded.policy or DEFAULTS.policy,
		highlight = decoded.highlight or DEFAULTS.highlight,
	}
end

---@param value gleb.diff.Settings
function M.save(value)
	vim.fn.mkdir(vim.fs.dirname(path()), "p")
	vim.fn.writefile({ vim.json.encode(value, { sort_keys = true }) }, path())
end

return M
