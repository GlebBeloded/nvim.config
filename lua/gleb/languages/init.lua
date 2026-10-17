local M = {}

require("gleb.languages.types")

---@class gleb.languages.State
---@field languages? gleb.Language[]
---@field by_filetype? table<string, gleb.Language>

---@type gleb.languages.State
M.state = {}

---@return string[]
local function language_names()
	local names = {}
	local seen = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/gleb/languages/*/init.lua", true)) do
		local name = path:match("/languages/([^/]+)/init%.lua$")
		if name and not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function discover()
	---@type gleb.Language[]
	local languages = {}
	---@type table<string, gleb.Language>
	local by_filetype = {}
	for _, name in ipairs(language_names()) do
		---@type gleb.Language
		local language = require("gleb.languages." .. name)
		table.insert(languages, language)
		for _, filetype in ipairs(language.filetypes) do
			by_filetype[filetype] = language
		end
	end
	M.state.languages = languages
	M.state.by_filetype = by_filetype
end

---@return gleb.Language[]
function M.all()
	if not M.state.languages then
		discover()
	end
	return M.state.languages or {}
end

---@param filetype string
---@return gleb.Language?
function M.for_filetype(filetype)
	if not M.state.by_filetype then
		discover()
	end
	return M.state.by_filetype and M.state.by_filetype[filetype] or nil
end

---@return nil
function M.reset()
	M.state.languages = nil
	M.state.by_filetype = nil
end

return M
