-- Reference requests fan out only to capable attached clients and merge their locations.
local M = {
	request_id = 0,
}

---@param location lsp.Location
---@param origin_uri string
---@param origin_position lsp.Position
---@return boolean
local function is_declaration(location, origin_uri, origin_position)
	if location.uri ~= origin_uri then
		return false
	end
	local range = location.range
	return range.start.line == origin_position.line
		and range.start.character <= origin_position.character
		and range["end"].character >= origin_position.character
end

---@param locations lsp.Location[]
---@param cwd string
---@param origin_uri string
---@param origin_position lsp.Position
---@return gleb.references.Usage[]
local function normalize(locations, cwd, origin_uri, origin_position)
	local usages = {}
	local seen = {}
	for _, location in ipairs(locations) do
		local range = location.range
		local key = string.format(
			"%s:%d:%d:%d:%d",
			location.uri,
			range.start.line,
			range.start.character,
			range["end"].line,
			range["end"].character
		)
		if not seen[key] and not is_declaration(location, origin_uri, origin_position) then
			seen[key] = true
			local filename = vim.uri_to_fname(location.uri)
			table.insert(usages, {
				uri = location.uri,
				path = vim.fs.relpath(cwd, filename) or filename,
				lnum = range.start.line + 1,
				col = range.start.character + 1,
				filetype = vim.filetype.match({ filename = filename }),
			})
		end
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
	local origin_uri = vim.uri_from_bufnr(bufnr)
	local position_params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
	---@type lsp.ReferenceParams
	local params = {
		textDocument = position_params.textDocument,
		position = position_params.position,
		context = { includeDeclaration = false },
	}
	local pending = #clients
	local locations = {}

	---@param result lsp.Location[]?
	local function finish(result)
		if request_id ~= M.request_id then
			return
		end
		vim.list_extend(locations, result or {})
		pending = pending - 1
		if pending > 0 then
			return
		end
		vim.schedule(function()
			if request_id ~= M.request_id then
				return
			end
			local usages = normalize(locations, cwd, origin_uri, params.position)
			if #usages == 0 then
				vim.notify("No usages found", vim.log.levels.INFO)
				return
			end
			callback(usages)
		end)
	end

	for _, client in ipairs(clients) do
		local client_params = vim.deepcopy(params)
		client_params.position = vim.lsp.util.make_position_params(0, client.offset_encoding).position
		client:request("textDocument/references", client_params, function(_, result)
			finish(result)
		end, bufnr)
	end
end

return M
