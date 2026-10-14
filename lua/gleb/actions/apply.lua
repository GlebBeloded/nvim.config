-- Applies catalog shortcuts and remembers ownership so reloads can replace them safely.

local Context = require("gleb.actions.context")

---@class gleb.AppliedBinding
---@field mode string
---@field lhs string

---@class gleb.ScopedBinding: gleb.AppliedBinding
---@field action gleb.Action

---@class gleb.ActionApplicator
---@field catalog gleb.ActionCatalog
---@field global_bindings gleb.AppliedBinding[]
---@field buffer_bindings table<integer, gleb.AppliedBinding[]>
---@field scoped_bindings gleb.ScopedBinding[]
---@field group integer
local Applicator = {}
Applicator.__index = Applicator

local M = {}

---@param action gleb.Action
---@return string[]
local function modes(action)
	return action.modes or { "n" }
end

---@param action gleb.Action
---@return string
local function description(action)
	return action.category .. ": " .. action.title
end

---@param action gleb.Action
---@return function
local function callback(action)
	return action.mapping or Context.invoke(action)
end

---@param action gleb.Action
---@param filetype string
---@return boolean
local function matches_filetype(action, filetype)
	if type(action.ft) == "table" then
		local filetypes = action.ft
		---@cast filetypes string[]
		return vim.tbl_contains(filetypes, filetype)
	end
	return action.ft == filetype
end

---@param binding gleb.AppliedBinding
local function delete_global(binding)
	pcall(vim.keymap.del, binding.mode, binding.lhs)
end

---@param buf integer
---@param binding gleb.AppliedBinding
local function delete_buffer(buf, binding)
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.keymap.del, binding.mode, binding.lhs, { buffer = buf })
	end
end

---@param self gleb.ActionApplicator
---@param buf integer
local function apply_buffer(self, buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	for _, binding in ipairs(self.buffer_bindings[buf] or {}) do
		delete_buffer(buf, binding)
	end
	self.buffer_bindings[buf] = nil

	local filetype = vim.bo[buf].filetype
	local applied = {}
	for _, binding in ipairs(self.scoped_bindings) do
		if matches_filetype(binding.action, filetype) then
			vim.keymap.set(binding.mode, binding.lhs, callback(binding.action), {
				buffer = buf,
				desc = description(binding.action),
				silent = true,
			})
			table.insert(applied, { mode = binding.mode, lhs = binding.lhs })
		end
	end
	if #applied > 0 then
		self.buffer_bindings[buf] = applied
	end
end

---@param self gleb.ActionApplicator
local function clear(self)
	for _, binding in ipairs(self.global_bindings) do
		delete_global(binding)
	end
	for buf, bindings in pairs(self.buffer_bindings) do
		for _, binding in ipairs(bindings) do
			delete_buffer(buf, binding)
		end
	end
	self.global_bindings = {}
	self.buffer_bindings = {}
	self.scoped_bindings = {}
	vim.api.nvim_clear_autocmds({ group = self.group })
end

---@param shortcuts gleb.ShortcutMap
function Applicator:apply(shortcuts)
	clear(self)
	for id, lhs_list in pairs(shortcuts) do
		local action = self.catalog:get(id)
		if action and not action.plugin then
			for _, mode in ipairs(modes(action)) do
				for _, lhs in ipairs(lhs_list) do
					if action.ft then
						table.insert(self.scoped_bindings, { action = action, mode = mode, lhs = lhs })
					else
						vim.keymap.set(mode, lhs, callback(action), { desc = description(action), silent = true })
						table.insert(self.global_bindings, { mode = mode, lhs = lhs })
					end
				end
			end
		end
	end

	if #self.scoped_bindings > 0 then
		vim.api.nvim_create_autocmd("FileType", {
			group = self.group,
			callback = function(event)
				apply_buffer(self, event.buf)
			end,
		})
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				apply_buffer(self, buf)
			end
		end
	end
end

function Applicator:clear()
	clear(self)
end

---@param catalog gleb.ActionCatalog
---@return gleb.ActionApplicator
function M.new(catalog)
	return setmetatable({
		catalog = catalog,
		global_bindings = {},
		buffer_bindings = {},
		scoped_bindings = {},
		group = vim.api.nvim_create_augroup("gleb_actions_bindings", { clear = true }),
	}, Applicator)
end

return M
