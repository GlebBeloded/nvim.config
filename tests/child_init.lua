-- Sourced via --cmd in every full-config child (before init.lua).
-- Replaces the system clipboard ('clipboard=unnamedplus' in options.lua) with
-- an in-memory one so tests never read or overwrite the user's clipboard.

---@type table<string, { [1]: string[], [2]: string }>
local registers = {}

---@param reg string
---@return fun(lines: string[], regtype: string)
local function copy(reg)
	return function(lines, regtype)
		registers[reg] = { lines, regtype }
	end
end

---@param reg string
---@return fun(): table
local function paste(reg)
	return function()
		return registers[reg] or { {}, "v" }
	end
end

vim.g.clipboard = {
	name = "test-memory",
	copy = { ["+"] = copy("+"), ["*"] = copy("*") },
	paste = { ["+"] = paste("+"), ["*"] = paste("*") },
}
