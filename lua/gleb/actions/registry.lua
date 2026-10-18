-- Pure action catalog: feature modules provide action lists, and consumers query one merged registry.

---@class gleb.ActionContext
---@field win integer
---@field buf integer
---@field cursor integer[]
---@field mode string
---@field count integer Count typed before the mapping (`v:count`), 0 when none
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
---@field run fun(ctx: gleb.ActionContext): boolean? Returns whether a plugin command handled the key
---@field mapping? fun() Direct mapping callback for actions that capture their own context
---@field plug? string `<Plug>` target mapped recursively instead of a callback
---@field commands? (string|function)[] Native plugin command list an adapter binds instead of `run`
---@field modes? string[]
---@field ft? string|string[]
---@field when? fun(ctx: gleb.ActionContext): boolean
---@field toggle? gleb.ActionToggle
---@field aliases? string[]
---@field hidden? boolean
---@field plugin? string Plugin adapter owns this action's mappings
---@field nowait? boolean Execute an exact mapping without waiting for longer mappings
---@field neo_tree_scope? "common"|"filesystem"|"git_status"
---@field diffview_scopes? string[]

---@class gleb.ActionCatalog
---@field actions gleb.Action[]
---@field by_id table<string, gleb.Action>
---@field hidden_actions? gleb.Action[]
---@field complete_commands fun(): string[]
local Catalog = {}
Catalog.__index = Catalog

---@class gleb.ActionRegistryOptions
---@field complete_commands? fun(): string[]

local M = {}

--- Mapping description `<Category>: <Title>`; a title that starts with its category does not repeat it.
---@param action gleb.Action
---@return string
function M.description(action)
	local prefix = action.category .. " "
	local title = vim.startswith(action.title, prefix) and action.title:sub(#prefix + 1) or action.title
	return action.category .. ": " .. title
end

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
	-- plugin-window actions run only from the mappings their adapter installs
	if action.plugin then
		return false
	end
	if not vim.tbl_contains(action.modes or { "n" }, mode) then
		return false
	end
	if action.ft and type(action.ft) == "string" and action.ft ~= filetype then
		return false
	end
	if type(action.ft) == "table" then
		local filetypes = action.ft
		---@cast filetypes string[]
		if not vim.tbl_contains(filetypes, filetype) then
			return false
		end
	end
	return not action.when or action.when(ctx)
end

---@param command string
---@return string
local function humanize_command(command)
	return (command:gsub("(%u)(%u%l)", "%1 %2"):gsub("(%l)(%u)", "%1 %2"))
end

---@param command string
---@return string
local function command_id(command)
	local name = humanize_command(command):lower():gsub("[^a-z0-9]+", "_"):gsub("^_", ""):gsub("_$", "")
	if not name:match("^[a-z]") then
		name = "command_" .. name
	end
	return "ex." .. name
end

---@param command string
---@param id string
---@return gleb.Action
local function hidden_command(command, id)
	return {
		id = id,
		title = humanize_command(command),
		category = "Command",
		hidden = true,
		run = function()
			vim.cmd(command)
		end,
	}
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

---@return gleb.Action[]
function Catalog:hidden()
	if self.hidden_actions then
		return self.hidden_actions
	end

	self.hidden_actions = {}
	for _, command in ipairs(self.complete_commands()) do
		local id = command_id(command)
		if not self.by_id[id] then
			local action = hidden_command(command, id)
			table.insert(self.hidden_actions, action)
			self.by_id[id] = action
		end
	end
	return self.hidden_actions
end

---@param action_lists gleb.Action[][]
---@param opts? gleb.ActionRegistryOptions
---@return gleb.ActionCatalog
function M.new(action_lists, opts)
	opts = opts or {}
	---@type gleb.ActionCatalog
	local catalog = setmetatable({
		actions = {},
		by_id = {},
		complete_commands = opts.complete_commands or function()
			return vim.fn.getcompletion("", "command")
		end,
	}, Catalog)
	for _, actions in ipairs(action_lists) do
		for _, action in ipairs(actions) do
			validate_id(action.id)
			if catalog.by_id[action.id] then
				error("duplicate action id: " .. action.id)
			end
			table.insert(catalog.actions, action)
			catalog.by_id[action.id] = action
			for _, alias in ipairs(action.aliases or {}) do
				validate_id(alias)
				if catalog.by_id[alias] then
					error("duplicate action id: " .. alias)
				end
				catalog.by_id[alias] = action
			end
		end
	end
	return catalog
end

return M
