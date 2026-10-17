-- Classify write targets from source text when a supported Treesitter parser is available.
local M = {}

---@type table<string, string>
local WRITE_QUERIES = {
	go = [[
		(short_var_declaration left: (expression_list (identifier) @write))
		(assignment_statement left: (expression_list (identifier) @write))
		(var_spec name: (identifier) @write)
		(const_spec name: (identifier) @write)
		(inc_statement (identifier) @write)
	]],
	lua = [[
		(assignment_statement (variable_list (identifier) @write))
		(variable_declaration (variable_list (identifier) @write))
	]],
	bash = [[
		(variable_assignment name: (variable_name) @write)
	]],
}

---@class ReferencesSourcePosition
---@field line integer Zero-based row
---@field character integer Zero-based byte column

---@param source string
---@param language string
---@return vim.treesitter.Query?, TSTree?
local function parse(source, language)
	local query_text = WRITE_QUERIES[language]
	if not query_text or not pcall(vim.treesitter.language.add, language) then
		return nil, nil
	end

	local query_ok, query = pcall(vim.treesitter.query.parse, language, query_text)
	local parser_ok, parser = pcall(vim.treesitter.get_string_parser, source, language)
	if not query_ok or not parser_ok then
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
---@param language string
---@param positions ReferencesSourcePosition[]
---@return ("write"|"read"|"other")[]
function M.classify(source, language, positions)
	local kinds = {}
	local by_position = {}
	for index, position in ipairs(positions) do
		kinds[index] = "other"
		by_position[position.line .. ":" .. position.character] = index
	end

	local query, tree = parse(source, language)
	if not query or not tree then
		return kinds
	end
	for index in ipairs(positions) do
		kinds[index] = "read"
	end

	for capture, node in query:iter_captures(tree:root(), source, 0, -1) do
		if query.captures[capture] == "write" then
			local row, column = node:range()
			local index = by_position[row .. ":" .. column]
			if index then
				kinds[index] = "write"
			end
		end
	end
	return kinds
end

return M
