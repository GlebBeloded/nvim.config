-- Coordinate asynchronous reference classification requests and merge their results.
local M = {}

local CLASSIFY_TIMEOUT_MS = 3000
local DOCUMENT_HIGHLIGHT_READ = 2
local DOCUMENT_HIGHLIGHT_WRITE = 3
local TSSERVER_COMMAND = "typescript.tsserverRequest"

---@class gleb.references.KindRequestOptions
---@field references_config fun(filetype: string): gleb.language.References?
---@field target_kind fun(symbol_kind: lsp.SymbolKind?, uri: string, position: lsp.Position, client: vim.lsp.Client): gleb.references.TargetKind
---@field finalize fun(groups: table<string, gleb.references.KindUsage[]>, target: gleb.references.TargetKind)

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

---@param cache table<string, gleb.references.KindCacheEntry>
---@param uri string
---@return gleb.references.KindCacheEntry
local function cache_entry(cache, uri)
	local current_version = version(uri)
	local entry = cache[uri]
	if not entry or entry.version ~= current_version then
		entry = { version = current_version, results = {} }
		cache[uri] = entry
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
---@return table<string, boolean>
local function usage_keys(usages)
	local seen = {}
	for _, usage in ipairs(usages) do
		seen[usage.uri .. ":" .. range_key(usage_range(usage))] = true
	end
	return seen
end

---@param kind "write"|"read"
---@param range lsp.Range
---@param origin gleb.references.KindOrigin
---@return boolean
local function is_origin_write(kind, range, origin)
	return kind == "write"
		and not (
			range.start.line == origin.params.position.line
			and range.start.character == origin.params.position.character
		)
end

---@param uri string
---@param range lsp.Range
---@param origin gleb.references.KindOrigin
---@param client vim.lsp.Client
---@return gleb.references.KindUsage
local function origin_usage(uri, range, origin, client)
	local filename = vim.uri_to_fname(uri)
	local line = vim.fn.readfile(filename, "", range.start.line + 1)[range.start.line + 1] or ""
	return {
		uri = uri,
		path = vim.fs.relpath(origin.cwd, filename) or filename,
		lnum = range.start.line + 1,
		col = vim.str_byteindex(line, client.offset_encoding, range.start.character, false) + 1,
		filetype = vim.filetype.match({ filename = filename }),
		range = range,
		client_id = client.id,
		kind = "write",
	}
end

---@param usages gleb.references.KindUsage[]
---@param groups table<string, gleb.references.KindUsage[]>
---@param origin gleb.references.KindOrigin
---@param client vim.lsp.Client
---@param kinds table<string, "write"|"read">
local function append_origin_writes(usages, groups, origin, client, kinds)
	local uri = origin.params.textDocument.uri
	local seen = usage_keys(usages)
	for key, kind in pairs(kinds) do
		local range = key_range(key)
		if is_origin_write(kind, range, origin) and not seen[uri .. ":" .. key] then
			local usage = origin_usage(uri, range, origin, client)
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

---@param client vim.lsp.Client?
---@param references gleb.language.References?
---@return boolean
local function highlights_allowed(client, references)
	if not client or (references and references.write_access == false) then
		return false
	end
	return client:supports_method("textDocument/documentHighlight")
end

---@param cache table<string, gleb.references.KindCacheEntry>
---@param uri string
---@param usages gleb.references.KindUsage[]
---@param client vim.lsp.Client
---@param done fun()
---@param active fun(): boolean
---@param anchor_range? lsp.Range
---@param received? fun(kinds: table<string, "write"|"read">)
local function request_highlights(cache, uri, usages, client, done, active, anchor_range, received)
	anchor_range = anchor_range or usage_range(usages[1])
	local anchor = range_key(anchor_range)
	local cache_key = client.id .. ":" .. anchor
	local entry = cache_entry(cache, uri)
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

---@param cache table<string, gleb.references.KindCacheEntry>
---@param usages gleb.references.KindUsage[]
---@param client vim.lsp.Client
---@param done fun()
---@param active fun(): boolean
local function request_tsserver(cache, usages, client, done, active)
	local anchor = usages[1]
	local range = usage_range(anchor)
	local cache_key = client.id .. ":" .. anchor.uri .. ":" .. range_key(range)
	local all_cached = true
	for _, usage in ipairs(usages) do
		local kinds = cache_entry(cache, usage.uri).results[cache_key]
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
			cache_entry(cache, usage.uri).results[cache_key] = kinds
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

---Resolve the kind of the symbol at `origin` from its definition.
---@param origin gleb.references.KindOrigin
---@param resolve fun(symbol_kind: lsp.SymbolKind?, uri: string, position: lsp.Position, client: vim.lsp.Client): gleb.references.TargetKind
---@param done fun(kind: gleb.references.TargetKind)
local function request_target_kind(origin, resolve, done)
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
				done(resolve(symbol_kind, uri, position, client))
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

---Classify usages asynchronously in syntax, server read/write, query fallback order.
---@param cache table<string, gleb.references.KindCacheEntry>
---@param usages gleb.references.KindUsage[]
---@param callback fun(usages: gleb.references.KindUsage[])
---@param origin? gleb.references.KindOrigin
---@param options gleb.references.KindRequestOptions
---@return nil
function M.classify(cache, usages, callback, origin, options)
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
		options.finalize(groups, target)
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
		local references = options.references_config(file_usages[1].filetype or "")
		if client and references and references.write_access == "tsserver" and has_tsserver_command(client) then
			tsserver_client = client
			vim.list_extend(tsserver_usages, file_usages)
		elseif highlights_allowed(client, references) then
			---@cast client vim.lsp.Client
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
			request_highlights(cache, uri, file_usages, client, request_done, active, anchor_range, received)
		end
	end
	if origin and not origin_highlights then
		local client = vim.lsp.get_client_by_id(origin.client_id)
		local filetype = vim.filetype.match({ filename = vim.uri_to_fname(origin.params.textDocument.uri) }) or ""
		local references = options.references_config(filetype)
		if highlights_allowed(client, references) then
			---@cast client vim.lsp.Client
			pending = pending + 1
			local anchor_range = { start = origin.params.position, ["end"] = origin.params.position }
			request_highlights(
				cache,
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
		request_tsserver(cache, tsserver_usages, tsserver_client, request_done, active)
	end
	if origin then
		pending = pending + 1
		request_target_kind(origin, options.target_kind, function(resolved_target)
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

return M
