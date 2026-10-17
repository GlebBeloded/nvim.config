-- Classify usage positions through each parser language's runtime usages query.
local M = {}

local languages = require("gleb.languages")

---@class ReferencesSourcePosition
---@field line integer Zero-based row
---@field character integer Zero-based byte column
---@field target_kind? gleb.references.TargetKind

local TYPE_POSITION_KINDS = {
	field_declaration = true,
	parameter_declaration = true,
	return_type = true,
	receiver = true,
	variable_declaration = true,
	const_declaration = true,
	type_alias = true,
	type_assertion = true,
	type_conversion = true,
	type_instantiation = true,
	type_constraint = true,
	type_parameter_declaration = true,
	cast = true,
	instanceof = true,
	extends = true,
	impl = true,
	catch = true,
}

---@param kind string
---@param target gleb.references.TargetKind
---@param filetype string
---@return string?
local function refine(kind, target, filetype)
	if kind == "call" and target == "type" and filetype == "go" then
		return "type_conversion"
	end
	if kind == "function_argument" and target ~= "function" then
		return nil
	end
	if kind == "static_member" and target ~= "type" then
		return nil
	end
	if target ~= "unknown" and target ~= "type" and TYPE_POSITION_KINDS[kind] then
		return nil
	end
	return kind
end

---@param source string
---@param language string
---@return vim.treesitter.Query?, TSTree?
local function parse(source, language)
	local language_ok, loaded = pcall(vim.treesitter.language.add, language)
	if not language_ok or not loaded then
		return nil, nil
	end

	local query_ok, query = pcall(vim.treesitter.query.get, language, "usages")
	local parser_ok, parser = pcall(vim.treesitter.get_string_parser, source, language)
	if not query_ok or not query or not parser_ok then
		return nil, nil
	end

	local tree_ok, tree = pcall(function()
		return parser:parse()[1]
	end)
	if not tree_ok or not tree then
		return nil, nil
	end
	return query, tree
end

---@param source string
---@param filetype string
---@param positions ReferencesSourcePosition[]
---@return string[]
function M.classify(source, filetype, positions)
	local kinds = {}
	for index in ipairs(positions) do
		kinds[index] = "unclassified"
	end

	local language = languages.for_filetype(filetype)
	if not language or language.references.disabled ~= nil then
		return kinds
	end
	local parser_language = vim.treesitter.language.get_lang(filetype)
	local query, tree
	if parser_language then
		query, tree = parse(source, parser_language)
	end
	if not query and language.name ~= filetype then
		parser_language = vim.treesitter.language.get_lang(language.name)
		if parser_language then
			query, tree = parse(source, parser_language)
		end
	end
	if not query or not tree then
		return kinds
	end
	local root = tree:root()
	for index, position in ipairs(positions) do
		kinds[index] = "read"
		local best_pattern
		for pattern, match in query:iter_matches(root, source, position.line, position.line + 1) do
			for capture, nodes in pairs(match) do
				local kind = query.captures[capture]:match("^usage%.(.+)$")
				for _, node in ipairs(kind and nodes or {}) do
					local row, column = node:start()
					if
						row == position.line
						and column == position.character
						and (best_pattern == nil or pattern < best_pattern)
					then
						best_pattern = pattern
						local refined = kind
						if position.target_kind then
							refined = refine(kind, position.target_kind, filetype)
						end
						kinds[index] = refined or "read"
					end
				end
			end
		end
	end
	return kinds
end

return M
