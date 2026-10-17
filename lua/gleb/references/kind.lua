-- Resolve syntactic usage types first, then server read/write and Treesitter fallbacks.
local M = {
	state = {
		cache = {},
	},
}

local kind_ts = require("gleb.references.kind_ts")
local languages = require("gleb.languages")

local CLASSIFY_TIMEOUT_MS = 3000
local DOCUMENT_HIGHLIGHT_READ = 2
local DOCUMENT_HIGHLIGHT_WRITE = 3
local TSSERVER_COMMAND = "typescript.tsserverRequest"
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

---@param filetype string
---@return gleb.language.References?
local function references_config(filetype)
	local language = languages.for_filetype(filetype)
	local references = language and language.references
	return references and references.disabled == nil and references or nil
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

---@param range lsp.Range
---@return string
local function range_key(range)
	return table.concat({
		range.start.line,
		range.start.character,
		range["end"].line,
		range["end"].character,
	}, ":")
end

---@param uri string
---@return integer?
local function loaded_buffer(uri)
	local filename = vim.fs.normalize(vim.uri_to_fname(uri))
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)) == filename then
			return bufnr
		end
	end
end

---@param uri string
---@return string
local function version(uri)
	local bufnr = loaded_buffer(uri)
	if bufnr then
		return "buffer:" .. vim.api.nvim_buf_get_changedtick(bufnr)
	end
	local stat = vim.uv.fs_stat(vim.uri_to_fname(uri))
	if not stat then
		return "missing"
	end
	return table.concat({ "file", stat.size, stat.mtime.sec, stat.mtime.nsec }, ":")
end

---@param uri string
---@return gleb.references.KindCacheEntry
local function cache_entry(uri)
	local current_version = version(uri)
	local entry = M.state.cache[uri]
	if not entry or entry.version ~= current_version then
		entry = { version = current_version, results = {} }
		M.state.cache[uri] = entry
	end
	return entry
end

---@param client vim.lsp.Client
---@return boolean
local function has_tsserver_command(client)
	local provider = client.server_capabilities.executeCommandProvider
	return provider ~= nil and vim.list_contains(provider.commands or {}, TSSERVER_COMMAND)
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

---@param usages gleb.references.KindUsage[]
---@param kinds table<string, "write"|"read">
local function apply_kinds(usages, kinds)
	for _, usage in ipairs(usages) do
		usage.kind = kinds[range_key(usage_range(usage))] or usage.kind
	end
end

---@param key string
---@return lsp.Range
local function key_range(key)
	local values = vim.split(key, ":", { plain = true })
	return {
		start = { line = tonumber(values[1]), character = tonumber(values[2]) },
		["end"] = { line = tonumber(values[3]), character = tonumber(values[4]) },
	}
end

---@param usages gleb.references.KindUsage[]
---@param groups table<string, gleb.references.KindUsage[]>
---@param origin gleb.references.KindOrigin
---@param client vim.lsp.Client
---@param kinds table<string, "write"|"read">
local function append_origin_writes(usages, groups, origin, client, kinds)
	local uri = origin.params.textDocument.uri
	local seen = {}
	for _, usage in ipairs(usages) do
		seen[usage.uri .. ":" .. range_key(usage_range(usage))] = true
	end
	local filename = vim.uri_to_fname(uri)
	for key, kind in pairs(kinds) do
		local range = key_range(key)
		local at_origin = range.start.line == origin.params.position.line
			and range.start.character == origin.params.position.character
		if kind == "write" and not at_origin and not seen[uri .. ":" .. key] then
			local line = vim.fn.readfile(filename, "", range.start.line + 1)[range.start.line + 1] or ""
			local col = vim.str_byteindex(line, client.offset_encoding, range.start.character, false) + 1
			local usage = {
				uri = uri,
				path = vim.fs.relpath(origin.cwd, filename) or filename,
				lnum = range.start.line + 1,
				col = col,
				filetype = vim.filetype.match({ filename = filename }),
				range = range,
				client_id = client.id,
				kind = "write",
			}
			table.insert(usages, usage)
			groups[uri] = groups[uri] or {}
			table.insert(groups[uri], usage)
		end
	end
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

---@param uri string
---@param usages gleb.references.KindUsage[]
---@param client vim.lsp.Client
---@param done fun()
---@param active fun(): boolean
---@param anchor_range? lsp.Range
---@param received? fun(kinds: table<string, "write"|"read">)
local function request_highlights(uri, usages, client, done, active, anchor_range, received)
	anchor_range = anchor_range or usage_range(usages[1])
	local anchor = range_key(anchor_range)
	local cache_key = client.id .. ":" .. anchor
	local entry = cache_entry(uri)
	if entry.results[cache_key] then
		apply_kinds(usages, entry.results[cache_key])
		if received then
			received(entry.results[cache_key])
		end
		vim.schedule(done)
		return
	end

	local params = {
		textDocument = { uri = uri },
		position = anchor_range.start,
	}
	local ok = client:request("textDocument/documentHighlight", params, function(err, highlights)
		local kinds = {}
		if not err then
			for _, highlight in ipairs(highlights or {}) do
				if highlight.kind == DOCUMENT_HIGHLIGHT_WRITE then
					kinds[range_key(highlight.range)] = "write"
				elseif highlight.kind == DOCUMENT_HIGHLIGHT_READ then
					kinds[range_key(highlight.range)] = "read"
				end
			end
		end
		entry.results[cache_key] = kinds
		if active() then
			apply_kinds(usages, kinds)
			if received then
				received(kinds)
			end
		end
		done()
	end)
	if not ok then
		vim.schedule(done)
	end
end

---@param usages gleb.references.KindUsage[]
---@param client vim.lsp.Client
---@param done fun()
---@param active fun(): boolean
local function request_tsserver(usages, client, done, active)
	local anchor = usages[1]
	local range = usage_range(anchor)
	local cache_key = client.id .. ":" .. anchor.uri .. ":" .. range_key(range)
	local all_cached = true
	for _, usage in ipairs(usages) do
		local kinds = cache_entry(usage.uri).results[cache_key]
		if kinds then
			usage.kind = kinds[range_key(usage_range(usage))] or usage.kind
		else
			all_cached = false
		end
	end
	if all_cached then
		vim.schedule(done)
		return
	end

	local args = {
		file = vim.uri_to_fname(anchor.uri),
		line = range.start.line + 1,
		offset = range.start.character + 1,
	}
	local ok = client:request("workspace/executeCommand", {
		command = TSSERVER_COMMAND,
		arguments = { "references", args },
	}, function(err, response)
		local by_uri = {}
		local refs = not err and response and response.body and response.body.refs or {}
		for _, ref in ipairs(refs) do
			local uri = vim.uri_from_fname(ref.file)
			by_uri[uri] = by_uri[uri] or {}
			local ref_range = {
				start = { line = ref.start.line - 1, character = ref.start.offset - 1 },
				["end"] = { line = ref["end"].line - 1, character = ref["end"].offset - 1 },
			}
			by_uri[uri][range_key(ref_range)] = ref.isWriteAccess and "write" or "read"
		end
		for _, usage in ipairs(usages) do
			local kinds = by_uri[usage.uri] or {}
			cache_entry(usage.uri).results[cache_key] = kinds
			if active() then
				usage.kind = kinds[range_key(usage_range(usage))] or usage.kind
			end
		end
		done()
	end)
	if not ok then
		vim.schedule(done)
	end
end

---@param range lsp.Range
---@param position lsp.Position
---@return boolean
local function contains(range, position)
	local start, finish = range.start, range["end"]
	local after_start = position.line > start.line
		or (position.line == start.line and position.character >= start.character)
	local before_end = position.line < finish.line
		or (position.line == finish.line and position.character <= finish.character)
	return after_start and before_end
end

--- Only hierarchical symbols carry a name range; flat `SymbolInformation` ranges span the whole body.
---@param symbols (lsp.DocumentSymbol|lsp.SymbolInformation)[]
---@param position lsp.Position
---@return lsp.SymbolKind?
local function symbol_kind_at(symbols, position)
	for _, symbol in ipairs(symbols) do
		---@type lsp.Range?
		local selection_range = rawget(symbol, "selectionRange")
		if selection_range and contains(selection_range, position) then
			return symbol.kind
		end
		---@type lsp.Location?
		local location = rawget(symbol, "location")
		local location_start = location and location.range.start
		if
			location_start
			and location_start.line == position.line
			and location_start.character == position.character
		then
			return symbol.kind
		end
		---@type lsp.DocumentSymbol[]
		local children = rawget(symbol, "children") or {}
		local child_kind = symbol_kind_at(children, position)
		if child_kind then
			return child_kind
		end
	end
end

---@param result lsp.Location|lsp.Location[]|lsp.LocationLink[]|nil
---@return string? uri, lsp.Position? position
local function definition_target(result)
	---@type (lsp.Location|lsp.LocationLink)?
	local location = result and (result.uri and result or result[1])
	if not location then
		return nil, nil
	end
	if location.targetUri then
		---@cast location lsp.LocationLink
		return location.targetUri, location.targetSelectionRange.start
	end
	---@cast location lsp.Location
	return location.uri, location.range.start
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

---Resolve the kind of the symbol at `origin` from its definition.
---@param origin gleb.references.KindOrigin
---@param done fun(kind: gleb.references.TargetKind)
local function request_target_kind(origin, done)
	local client = vim.lsp.get_client_by_id(origin.client_id)
	if not client then
		vim.schedule_wrap(done)("unknown")
		return
	end
	---@param uri string
	---@param position lsp.Position
	local function request_symbols(uri, position)
		local ok = client:request(
			"textDocument/documentSymbol",
			{ textDocument = { uri = uri } },
			function(err, symbols)
				local symbol_kind = not err and symbol_kind_at(symbols or {}, position) or nil
				done(target_kind(symbol_kind, uri, position, client))
			end
		)
		if not ok then
			done("unknown")
		end
	end
	local ok = client:request("textDocument/definition", origin.params, function(err, result)
		local uri, position = definition_target(not err and result or nil)
		request_symbols(uri or origin.params.textDocument.uri, position or origin.params.position)
	end)
	if not ok then
		vim.schedule_wrap(done)("unknown")
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

---@param kind string
---@param target gleb.references.TargetKind
---@param filetype string
---@return string?
local function refine_query_kind(kind, target, filetype)
	if kind == "call" and target == "type" and filetype == "go" then
		return "type_conversion"
	end
	local drops_function_argument = kind == "function_argument" and target ~= "function"
	local drops_static_member = kind == "static_member" and target ~= "type"
	local drops_type_position = target ~= "unknown" and target ~= "type" and TYPE_POSITION_KINDS[kind]
	if drops_function_argument or drops_static_member or drops_type_position then
		return nil
	end
	return kind
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
				if is_syntactic then
					usage.kind = refine_query_kind(query_kind, target, usage.filetype or "") or usage.kind or "read"
				elseif usage.kind == nil then
					usage.kind = query_kind
				end
			end
		end
	end
end

---@param usages gleb.references.KindUsage[]
---@param target gleb.references.TargetKind
local function refine_target_kinds(usages, target)
	for _, usage in ipairs(usages) do
		local kind = usage.kind
		local drops_read_write = (target == "function" or target == "type") and (kind == "write" or kind == "read")
		local drops_function_argument = kind == "function_argument" and target ~= "function"
		local drops_static_member = kind == "static_member" and target ~= "type"
		local drops_type_position = target ~= "unknown" and target ~= "type" and TYPE_POSITION_KINDS[kind]
		if kind == "call" and target == "type" and usage.filetype == "go" then
			usage.kind = "type_conversion"
		elseif drops_read_write or drops_function_argument or drops_static_member or drops_type_position then
			usage.kind = "unclassified"
		end
	end
end

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
	local classified = vim.deepcopy(usages)
	local groups = {}
	for _, usage in ipairs(classified) do
		groups[usage.uri] = groups[usage.uri] or {}
		table.insert(groups[usage.uri], usage)
	end

	local pending = 0
	local finished = false
	local target = "unknown"
	local function finish()
		if finished then
			return
		end
		finished = true
		apply_query_kinds(groups, target)
		refine_target_kinds(classified, target)
		callback(classified)
	end
	local function request_done()
		pending = pending - 1
		if pending == 0 then
			finish()
		end
	end
	local function active()
		return not finished
	end

	local tsserver_usages = {}
	local tsserver_client
	local origin_highlights = false
	for uri, file_usages in pairs(groups) do
		local client = usage_client(file_usages[1])
		local references = references_config(file_usages[1].filetype or "")
		if client and references and references.write_access == "tsserver" and has_tsserver_command(client) then
			tsserver_client = client
			vim.list_extend(tsserver_usages, file_usages)
		elseif
			client
			and references
			and references.write_access == "documentHighlight"
			and client:supports_method("textDocument/documentHighlight")
		then
			pending = pending + 1
			local anchor_range
			local received
			if origin and client.id == origin.client_id and uri == origin.params.textDocument.uri then
				local matched_origin = origin
				origin_highlights = true
				anchor_range = { start = matched_origin.params.position, ["end"] = matched_origin.params.position }
				received = function(kinds)
					append_origin_writes(classified, groups, matched_origin, client, kinds)
				end
			end
			request_highlights(uri, file_usages, client, request_done, active, anchor_range, received)
		end
	end
	if origin and not origin_highlights then
		local client = vim.lsp.get_client_by_id(origin.client_id)
		local filetype = vim.filetype.match({ filename = vim.uri_to_fname(origin.params.textDocument.uri) }) or ""
		local references = references_config(filetype)
		if
			client
			and references
			and references.write_access == "documentHighlight"
			and client:supports_method("textDocument/documentHighlight")
		then
			pending = pending + 1
			local anchor_range = { start = origin.params.position, ["end"] = origin.params.position }
			request_highlights(
				origin.params.textDocument.uri,
				{},
				client,
				request_done,
				active,
				anchor_range,
				function(kinds)
					append_origin_writes(classified, groups, origin, client, kinds)
				end
			)
		end
	end
	if tsserver_client and #tsserver_usages > 0 then
		pending = pending + 1
		request_tsserver(tsserver_usages, tsserver_client, request_done, active)
	end
	if origin then
		pending = pending + 1
		request_target_kind(origin, function(resolved_target)
			target = resolved_target
			request_done()
		end)
	end

	if pending == 0 then
		vim.schedule(finish)
	else
		vim.defer_fn(finish, CLASSIFY_TIMEOUT_MS)
	end
end

---Clear cached classifications.
---@return nil
function M.reset()
	M.state.cache = {}
end

return M
