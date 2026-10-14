-- Pure action catalog: feature modules provide action lists, and consumers query one merged registry.

---@class gleb.ActionContext
---@field win integer
---@field buf integer
---@field cursor integer[]
---@field mode string
---@field selection? gleb.ActionSelection

---@class gleb.ActionSelection
---@field start integer[]
---@field finish integer[]

---@class gleb.ActionToggle
---@field get fun(ctx: gleb.ActionContext): boolean
---@field set fun(ctx: gleb.ActionContext, value: boolean)

---@class gleb.Action
---@field id string
---@field title string
---@field category string
---@field run fun(ctx: gleb.ActionContext)
---@field modes? string[]
---@field ft? string
---@field when? fun(ctx: gleb.ActionContext): boolean
---@field toggle? gleb.ActionToggle
---@field aliases? string[]
---@field hidden? boolean

---@class gleb.ActionCatalog
---@field actions gleb.Action[]
---@field by_id table<string, gleb.Action>
local Catalog = {}
Catalog.__index = Catalog

local M = {}

---@param id string
local function validate_id(id)
	if not id:match("^[a-z][a-z0-9_]*%.[a-z][a-z0-9_]*$") then
		error("invalid action id: " .. id)
	end
end

---@param action gleb.Action
---@param mode string
---@param filetype string
---@param ctx gleb.ActionContext
---@return boolean
local function is_available(action, mode, filetype, ctx)
	if action.modes and not vim.tbl_contains(action.modes, mode) then
		return false
	end
	if action.ft and action.ft ~= filetype then
		return false
	end
	return not action.when or action.when(ctx)
end

---@param id string
---@return gleb.Action?
function Catalog:get(id)
	return self.by_id[id]
end

---@param mode string
---@param filetype string
---@param ctx gleb.ActionContext
---@return gleb.Action[]
function Catalog:filter(mode, filetype, ctx)
	local available = {}
	for _, action in ipairs(self.actions) do
		if is_available(action, mode, filetype, ctx) then
			table.insert(available, action)
		end
	end
	return available
end

---@param action_lists gleb.Action[][]
---@return gleb.ActionCatalog
function M.new(action_lists)
	---@type gleb.ActionCatalog
	local catalog = setmetatable({ actions = {}, by_id = {} }, Catalog)
	for _, actions in ipairs(action_lists) do
		for _, action in ipairs(actions) do
			validate_id(action.id)
			if catalog.by_id[action.id] then
				error("duplicate action id: " .. action.id)
			end
			table.insert(catalog.actions, action)
			catalog.by_id[action.id] = action
			for _, alias in ipairs(action.aliases or {}) do
				catalog.by_id[alias] = action
			end
		end
	end
	return catalog
end

return M
