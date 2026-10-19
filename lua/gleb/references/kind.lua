-- Expose reference-kind classification while request orchestration stays isolated.
local M = {
	state = {
		cache = {},
	},
}

local kind_request = require("gleb.references.kind_request")
local kind_refine = require("gleb.references.kind_refine")
local kind_ts = require("gleb.references.kind_ts")
local languages = require("gleb.languages")

---@alias gleb.references.TargetKind "function"|"type"|"field"|"variable"|"unknown"

---@type table<integer, gleb.references.TargetKind>
local TARGET_KINDS = {
	[vim.lsp.protocol.SymbolKind.Function] = "function",
	[vim.lsp.protocol.SymbolKind.Method] = "function",
	[vim.lsp.protocol.SymbolKind.Constructor] = "function",
	[vim.lsp.protocol.SymbolKind.Class] = "type",
	[vim.lsp.protocol.SymbolKind.Struct] = "type",
	[vim.lsp.protocol.SymbolKind.Interface] = "type",
	[vim.lsp.protocol.SymbolKind.Enum] = "type",
	[vim.lsp.protocol.SymbolKind.TypeParameter] = "type",
	[vim.lsp.protocol.SymbolKind.Field] = "field",
	[vim.lsp.protocol.SymbolKind.Property] = "field",
	[vim.lsp.protocol.SymbolKind.EnumMember] = "field",
	[vim.lsp.protocol.SymbolKind.Variable] = "variable",
	[vim.lsp.protocol.SymbolKind.Constant] = "variable",
}

local VARIABLE_SYMBOLS = {
	[vim.lsp.protocol.SymbolKind.Variable] = true,
	[vim.lsp.protocol.SymbolKind.Constant] = true,
}

---@class gleb.references.KindUsage: gleb.references.Usage
---@field range? lsp.Range
---@field client_id? integer
---@field kind? string

---@class gleb.references.KindCacheEntry
---@field version string
---@field results table<string, table<string, "write"|"read">>

---@class gleb.references.KindState
---@field cache table<string, gleb.references.KindCacheEntry>

---@class gleb.references.KindOrigin
---@field client_id integer
---@field params lsp.TextDocumentPositionParams
---@field cwd string

---@param filetype string
---@return gleb.language.References?
local function references_config(filetype)
	local language = languages.for_filetype(filetype)
	if not language then
		return nil
	end
	local references = language.references
	if references.disabled ~= nil then
		return nil
	end
	---@cast references gleb.language.References
	return references
end

---@param symbol_kind lsp.SymbolKind
---@return string?
local function symbol_kind_name(symbol_kind)
	for name, value in pairs(vim.lsp.protocol.SymbolKind) do
		if value == symbol_kind then
			return name
		end
	end
end

---@param uri string
---@param position lsp.Position
---@param client vim.lsp.Client
---@return boolean
local function definition_name_is_type(uri, position, client)
	local filename = vim.uri_to_fname(uri)
	local source = table.concat(vim.fn.readfile(filename), "\n")
	local filetype = vim.filetype.match({ filename = filename }) or ""
	local language = vim.treesitter.language.get_lang(filetype)
	if not language then
		return false
	end
	local character = position.character
	if client.offset_encoding ~= "utf-8" then
		local line = vim.split(source, "\n", { plain = true })[position.line + 1] or ""
		local ok, byte_index = pcall(vim.str_byteindex, line, client.offset_encoding, character, false)
		if not ok then
			return false
		end
		character = byte_index
	end
	local parser_ok, parser = pcall(vim.treesitter.get_string_parser, source, language)
	if not parser_ok then
		return false
	end
	local tree_ok, tree = pcall(function()
		return parser:parse()[1]
	end)
	if not tree_ok or not tree then
		return false
	end
	local node = tree:root():named_descendant_for_range(position.line, character, position.line, character)
	return node ~= nil and node:type() == "type_identifier"
end

---@param symbol_kind lsp.SymbolKind?
---@param uri string
---@param position lsp.Position
---@param client vim.lsp.Client
---@return gleb.references.TargetKind
local function target_kind(symbol_kind, uri, position, client)
	local filetype = vim.filetype.match({ filename = vim.uri_to_fname(uri) }) or ""
	local references = references_config(filetype)
	local override = symbol_kind and references and references.target_kinds[symbol_kind_name(symbol_kind) or ""]
	if override then
		return override
	end
	if symbol_kind and VARIABLE_SYMBOLS[symbol_kind] and definition_name_is_type(uri, position, client) then
		return "type"
	end
	return TARGET_KINDS[symbol_kind] or "unknown"
end

---@param usage gleb.references.KindUsage
---@return lsp.Range
local function usage_range(usage)
	if usage.range then
		return usage.range
	end
	local start = { line = usage.lnum - 1, character = usage.col - 1 }
	return { start = start, ["end"] = vim.deepcopy(start) }
end

---@param usage gleb.references.KindUsage
---@return vim.lsp.Client?
local function usage_client(usage)
	if usage.client_id then
		return vim.lsp.get_client_by_id(usage.client_id)
	end
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client:supports_method("textDocument/documentHighlight") then
			return client
		end
	end
end

---@param usage gleb.references.KindUsage
---@param client vim.lsp.Client?
---@return ReferencesSourcePosition
local function fallback_position(usage, client)
	local range = usage_range(usage)
	local character = range.start.character
	if client and client.offset_encoding ~= "utf-8" then
		local source = vim.fn.readfile(vim.uri_to_fname(usage.uri), "", usage.lnum)[usage.lnum] or ""
		local ok, byte_index = pcall(vim.str_byteindex, source, client.offset_encoding, character, false)
		if ok then
			character = byte_index
		end
	end
	return { line = range.start.line, character = character }
end

---@param groups table<string, gleb.references.KindUsage[]>
---@param target gleb.references.TargetKind
local function apply_query_kinds(groups, target)
	for uri, usages in pairs(groups) do
		if #usages > 0 then
			local source = table.concat(vim.fn.readfile(vim.uri_to_fname(uri)), "\n")
			local client = usage_client(usages[1])
			local positions = vim.tbl_map(function(usage)
				return fallback_position(usage, client)
			end, usages)
			local filetype = usages[1].filetype or ""
			local kinds = kind_ts.classify(source, filetype, positions)
			for index, usage in ipairs(usages) do
				local query_kind = kinds[index]
				local is_syntactic = query_kind ~= "write" and query_kind ~= "read" and query_kind ~= "unclassified"
				local kind = is_syntactic and query_kind or usage.kind or query_kind
				local fallback = is_syntactic and (usage.kind or "read") or nil
				usage.kind = kind_refine.finalize(kind, target, usage.filetype or "", fallback) or "unclassified"
			end
		end
	end
end

local request_options = {
	references_config = references_config,
	target_kind = target_kind,
	finalize = apply_query_kinds,
}

---Capture the symbol under the cursor for target-kind refinement, before the view takes focus.
---@return gleb.references.KindOrigin?
function M.origin()
	local bufnr = vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })) do
		if client:supports_method("textDocument/documentSymbol", bufnr) then
			return {
				client_id = client.id,
				params = vim.lsp.util.make_position_params(0, client.offset_encoding),
				cwd = vim.fn.getcwd(),
			}
		end
	end
end

---Classify usages asynchronously in syntax, server read/write, query fallback order.
---@param usages gleb.references.KindUsage[]
---@param callback fun(usages: gleb.references.KindUsage[])
---@param origin? gleb.references.KindOrigin
---@return nil
function M.classify(usages, callback, origin)
	kind_request.classify(M.state.cache, usages, callback, origin, request_options)
end

---Clear cached classifications.
---@return nil
function M.reset()
	M.state.cache = {}
end

return M
