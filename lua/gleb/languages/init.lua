local M = {}

require("gleb.languages.types")

---@class gleb.languages.State
---@field languages? gleb.Language[]
---@field by_filetype? table<string, gleb.Language>
---@field facets table<string, gleb.languages.FacetValidator>

---@type gleb.languages.State
M.state = { facets = {} }

local LANGUAGE_FIELDS = { filetypes = true, name = true }

---@return string[]
function M.facet_names()
	local names = vim.tbl_keys(M.state.facets)
	table.sort(names)
	return names
end

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

---@param name string
---@param validate gleb.languages.FacetValidator
---@return nil
function M.register_facet(name, validate)
	M.state.facets[name] = validate
end

---@param name string
---@return gleb.languages.Facet[]
function M.facet(name)
	local facets = {}
	for _, language in ipairs(M.all()) do
		local config = language[name]
		if type(config) == "table" and config.disabled == nil then
			table.insert(facets, { language = language, config = config })
		end
	end
	return facets
end

---@param language gleb.Language
---@return nil
local function validate_language(language)
	for _, name in ipairs(M.facet_names()) do
		local config = language[name]
		if config == nil then
			error(("languages: %s lacks facet %s"):format(language.name, name), 0)
		end
		if config.disabled ~= nil then
			if type(config.disabled) ~= "string" or not config.disabled:find("%S") then
				error(("languages: %s facet %s has no disabled reason"):format(language.name, name), 0)
			end
		else
			local validation_error = M.state.facets[name](config, language)
			if validation_error then
				error(validation_error, 0)
			end
		end
	end

	for key in pairs(language) do
		if not LANGUAGE_FIELDS[key] and not M.state.facets[key] then
			error(("languages: %s has unknown facet %s"):format(language.name, key), 0)
		end
	end
end

---@return nil
function M.validate()
	for _, language in ipairs(M.all()) do
		validate_language(language)
	end
end

---@return nil
function M.reset()
	M.state.languages = nil
	M.state.by_filetype = nil
	M.state.facets = {}
end

return M
