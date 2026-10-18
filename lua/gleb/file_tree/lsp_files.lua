-- LSP file operations bracket project-tree moves so servers can update references safely.

local M = {}

local paths = require("gleb.file_tree.paths")

local LSP_RENAME_TIMEOUT_MS = 1000

---@class FileTreeLspRenamePair
---@field old string
---@field new string

---@param pair FileTreeLspRenamePair
---@return lsp.FileRename
local function lsp_pair(pair)
	return { oldUri = vim.uri_from_fname(pair.old), newUri = vim.uri_from_fname(pair.new) }
end

---@param move_pairs FileTreeLspRenamePair[]
---@return lsp.RenameFilesParams
local function rename_params(move_pairs)
	return { files = vim.tbl_map(lsp_pair, move_pairs) }
end

---@param filter lsp.FileOperationFilter
---@param pair FileTreeLspRenamePair
---@return boolean
local function filter_matches_pair(filter, pair)
	local stat = vim.uv.fs_stat(pair.old) or vim.uv.fs_stat(pair.new)
	if not stat then
		return false
	end
	return paths.filter_matches(filter, pair.old, stat.type) or paths.filter_matches(filter, pair.new, stat.type)
end

---@param filters lsp.FileOperationFilter[]
---@param move_pairs FileTreeLspRenamePair[]
---@return boolean
local function filters_match(filters, move_pairs)
	for _, filter in ipairs(filters) do
		for _, pair in ipairs(move_pairs) do
			if filter_matches_pair(filter, pair) then
				return true
			end
		end
	end
	return false
end

---@param client vim.lsp.Client
---@param operation "willRename"|"didRename"
---@param move_pairs FileTreeLspRenamePair[]
---@return boolean
local function client_matches(client, operation, move_pairs)
	local workspace = client.server_capabilities.workspace
	local file_operations = workspace and workspace.fileOperations
	local registration = file_operations and file_operations[operation]
	return registration ~= nil and filters_match(registration.filters or {}, move_pairs)
end

--- Ask matching language servers for edits before files move.
---@param move_pairs FileTreeLspRenamePair[]
---@return nil
function M.will_rename(move_pairs)
	local pending = 0
	local accepting = true
	local responses = {}
	local requests = {}
	local params = rename_params(move_pairs)
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client_matches(client, "willRename", move_pairs) then
			pending = pending + 1
			local accepted, request_id = client:request("workspace/willRenameFiles", params, function(error, result)
				if not accepting then
					return
				end
				pending = pending - 1
				if not error and result then
					responses[#responses + 1] = { edit = result, encoding = client.offset_encoding }
				end
			end)
			if accepted and request_id then
				requests[#requests + 1] = { client = client, id = request_id }
			elseif not accepted then
				pending = pending - 1
			end
		end
	end

	local completed = vim.wait(LSP_RENAME_TIMEOUT_MS, function()
		return pending == 0
	end, 10)
	accepting = false
	if not completed then
		for _, request in ipairs(requests) do
			request.client:cancel_request(request.id)
		end
	end
	for _, response in ipairs(responses) do
		vim.lsp.util.apply_workspace_edit(response.edit, response.encoding)
	end
end

--- Notify matching language servers after all target paths exist.
---@param move_pairs FileTreeLspRenamePair[]
---@return nil
function M.did_rename(move_pairs)
	local params = rename_params(move_pairs)
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client_matches(client, "didRename", move_pairs) then
			client:notify("workspace/didRenameFiles", params)
		end
	end
end

return M
