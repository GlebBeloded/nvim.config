-- Reference requests fan out only to capable attached clients and merge their locations.
local M = {
	request_id = 0,
}

---@param location lsp.Location
---@return string
local function location_key(location)
	local range = location.range
	return table.concat({
		location.uri,
		range.start.line,
		range.start.character,
		range["end"].line,
		range["end"].character,
	}, ":")
end

---@param batches lsp.Location[][]
---@return lsp.Location[]
function M.merge(batches)
	local merged = {}
	local seen = {}
	for _, locations in ipairs(batches) do
		for _, location in ipairs(locations) do
			local key = location_key(location)
			if not seen[key] then
				seen[key] = true
				table.insert(merged, location)
			end
		end
	end
	return merged
end

---@param filename string
---@param lnum integer 0-based
---@return string
local function source_line(filename, lnum)
	local normalized = vim.fs.normalize(filename)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == normalized then
			return vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1] or ""
		end
	end
	return vim.fn.readfile(filename, "", lnum + 1)[lnum + 1] or ""
end

---@param locations lsp.Location[]
---@param cwd string
---@param offset_encoding 'utf-8'|'utf-16'|'utf-32'
---@param client_id integer
---@return gleb.references.Usage[]
local function normalize(locations, cwd, offset_encoding, client_id)
	local usages = {}
	for _, location in ipairs(locations) do
		local range = location.range
		local filename = vim.uri_to_fname(location.uri)
		local line = source_line(filename, range.start.line)
		local col = vim.str_byteindex(line, offset_encoding, range.start.character, false) + 1
		table.insert(usages, {
			uri = location.uri,
			path = vim.fs.relpath(cwd, filename) or filename,
			lnum = range.start.line + 1,
			col = col,
			filetype = vim.filetype.match({ filename = filename }),
			range = vim.deepcopy(range),
			client_id = client_id,
		})
	end
	return usages
end

---@param callback fun(usages: gleb.references.Usage[])
---@return nil
function M.start(callback)
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.tbl_filter(function(client)
		return client.server_capabilities.referencesProvider ~= nil
			and client.server_capabilities.referencesProvider ~= false
	end, vim.lsp.get_clients({ bufnr = bufnr }))
	if #clients == 0 then
		vim.notify("No LSP references support", vim.log.levels.INFO)
		return
	end

	M.request_id = M.request_id + 1
	local request_id = M.request_id
	local cwd = vim.fn.getcwd()
	local position_params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
	---@type lsp.ReferenceParams
	local params = {
		textDocument = position_params.textDocument,
		position = position_params.position,
		context = { includeDeclaration = false },
	}
	local pending = #clients
	local location_batches = {}
	local offset_encodings = {}
	local client_ids = {}

	---@param result lsp.Location[]?
	---@param offset_encoding 'utf-8'|'utf-16'|'utf-32'
	local function finish(result, offset_encoding, client_id)
		if request_id ~= M.request_id then
			return
		end
		local locations = result or {}
		for _, location in ipairs(locations) do
			offset_encodings[location_key(location)] = offset_encodings[location_key(location)] or offset_encoding
			client_ids[location_key(location)] = client_ids[location_key(location)] or client_id
		end
		table.insert(location_batches, locations)
		pending = pending - 1
		if pending > 0 then
			return
		end
		local usages = {}
		for _, location in ipairs(M.merge(location_batches)) do
			vim.list_extend(
				usages,
				normalize(
					{ location },
					cwd,
					offset_encodings[location_key(location)],
					client_ids[location_key(location)]
				)
			)
		end
		vim.schedule(function()
			if request_id ~= M.request_id then
				return
			end
			if #usages == 0 then
				vim.notify("No usages found", vim.log.levels.INFO)
				return
			end
			callback(usages)
		end)
	end

	for _, client in ipairs(clients) do
		local client_params = vim.deepcopy(params)
		local offset_encoding = client.offset_encoding
		client_params.position = vim.lsp.util.make_position_params(0, offset_encoding).position
		local sent = client:request("textDocument/references", client_params, function(_, result)
			finish(result, offset_encoding, client.id)
		end, bufnr)
		if not sent then
			finish(nil, offset_encoding, client.id)
		end
	end
end

return M
