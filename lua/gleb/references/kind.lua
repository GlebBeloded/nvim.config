-- Resolve usage kinds from language servers first, then fill unsupported ranges with Treesitter.
local M = {
	state = {
		cache = {},
	},
}

local kind_ts = require("gleb.references.kind_ts")

local CLASSIFY_TIMEOUT_MS = 3000
local DOCUMENT_HIGHLIGHT_READ = 2
local DOCUMENT_HIGHLIGHT_WRITE = 3
local TSSERVER_COMMAND = "typescript.tsserverRequest"
local CALLABLE_SYMBOLS = {
	[vim.lsp.protocol.SymbolKind.Function] = true,
	[vim.lsp.protocol.SymbolKind.Method] = true,
	[vim.lsp.protocol.SymbolKind.Constructor] = true,
}

---@class gleb.references.KindUsage: gleb.references.Usage
---@field range? lsp.Range
---@field client_id? integer
---@field kind? "write"|"read"|"other"

---@class gleb.references.KindCacheEntry
---@field version string
---@field results table<string, table<string, "write"|"read">>

---@class gleb.references.KindState
---@field cache table<string, gleb.references.KindCacheEntry>

---@class gleb.references.KindOrigin
---@field client_id integer
---@field params lsp.TextDocumentPositionParams

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
local function request_highlights(uri, usages, client, done)
	local anchor = range_key(usage_range(usages[1]))
	local cache_key = client.id .. ":" .. anchor
	local entry = cache_entry(uri)
	if entry.results[cache_key] then
		apply_kinds(usages, entry.results[cache_key])
		vim.schedule(done)
		return
	end

	local params = {
		textDocument = { uri = uri },
		position = usage_range(usages[1]).start,
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
		apply_kinds(usages, kinds)
		done()
	end)
	if not ok then
		vim.schedule(done)
	end
end

---@param usages gleb.references.KindUsage[]
---@param client vim.lsp.Client
---@param done fun()
local function request_tsserver(usages, client, done)
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
			usage.kind = kinds[range_key(usage_range(usage))] or usage.kind
		end
		done()
	end)
	if not ok then
		done()
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
---@param symbols lsp.DocumentSymbol[]
---@param position lsp.Position
---@return lsp.SymbolKind?
local function symbol_kind_at(symbols, position)
	for _, symbol in ipairs(symbols) do
		if symbol.selectionRange and contains(symbol.selectionRange, position) then
			return symbol.kind
		end
		local child_kind = symbol_kind_at(symbol.children or {}, position)
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

--- Whether the symbol at `origin` is defined as a function, method or constructor.
---@param origin gleb.references.KindOrigin
---@param done fun(callable: boolean)
local function request_callable(origin, done)
	local client = vim.lsp.get_client_by_id(origin.client_id)
	if not client then
		vim.schedule_wrap(done)(false)
		return
	end
	---@param uri string
	---@param position lsp.Position
	local function request_symbols(uri, position)
		local ok = client:request(
			"textDocument/documentSymbol",
			{ textDocument = { uri = uri } },
			function(err, symbols)
				done(not err and CALLABLE_SYMBOLS[symbol_kind_at(symbols or {}, position)] == true)
			end
		)
		if not ok then
			done(false)
		end
	end
	local ok = client:request("textDocument/definition", origin.params, function(err, result)
		local uri, position = definition_target(not err and result or nil)
		if uri and position then
			request_symbols(uri, position)
		else
			done(false)
		end
	end)
	if not ok then
		vim.schedule_wrap(done)(false)
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
local function fill_fallbacks(groups)
	for uri, usages in pairs(groups) do
		local unresolved = vim.tbl_filter(function(usage)
			return usage.kind == nil
		end, usages)
		if #unresolved > 0 then
			local source = table.concat(vim.fn.readfile(vim.uri_to_fname(uri)), "\n")
			local client = usage_client(unresolved[1])
			local positions = vim.tbl_map(function(usage)
				return fallback_position(usage, client)
			end, unresolved)
			local language = vim.treesitter.language.get_lang(unresolved[1].filetype or "") or ""
			local kinds = kind_ts.classify(source, language, positions)
			for index, usage in ipairs(unresolved) do
				usage.kind = kinds[index]
			end
		end
	end
end

---@param usages gleb.references.KindUsage[]
local function mark_other(usages)
	for _, usage in ipairs(usages) do
		usage.kind = "other"
	end
end

---Capture the symbol under the cursor for the callable check, before the view takes focus.
---@return gleb.references.KindOrigin?
function M.origin()
	local bufnr = vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })) do
		if client:supports_method("textDocument/documentSymbol", bufnr) then
			return { client_id = client.id, params = vim.lsp.util.make_position_params(0, client.offset_encoding) }
		end
	end
end

---Classify usages asynchronously, preferring server-provided kinds over syntax fallback.
---Usages of a function, method or constructor at `origin` are only calls, so they stay `other`.
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
	local callable = false
	local function finish()
		if finished then
			return
		end
		finished = true
		fill_fallbacks(groups)
		if callable then
			mark_other(classified)
		end
		callback(classified)
	end
	local function request_done()
		pending = pending - 1
		if pending == 0 then
			finish()
		end
	end

	local tsserver_usages = {}
	local tsserver_client
	for uri, file_usages in pairs(groups) do
		local client = usage_client(file_usages[1])
		if client and client.name == "vtsls" and has_tsserver_command(client) then
			tsserver_client = client
			vim.list_extend(tsserver_usages, file_usages)
		elseif client and client:supports_method("textDocument/documentHighlight") then
			pending = pending + 1
			request_highlights(uri, file_usages, client, request_done)
		end
	end
	if tsserver_client and #tsserver_usages > 0 then
		pending = pending + 1
		request_tsserver(tsserver_usages, tsserver_client, request_done)
	end
	if origin then
		pending = pending + 1
		request_callable(origin, function(is_callable)
			callable = is_callable
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
