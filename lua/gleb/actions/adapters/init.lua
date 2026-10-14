-- Plugin adapters translate the current shortcut map without retaining state between window opens.

local Context = require("gleb.actions.context")

local M = {}

---@param id string
---@return string
local function action_name(id)
	return assert(id:match("^[^.]+%.(.+)$"))
end

---@param areas string[]
---@param id string
---@return boolean
local function belongs_to(areas, id)
	local area = id:match("^([^.]+)%.")
	return vim.tbl_contains(areas, area)
end

---@param id string
---@param lhs_list string[]
---@param supports_multiple boolean
---@return string|string[]
local function native_lhs(id, lhs_list, supports_multiple)
	if #lhs_list == 1 then
		return lhs_list[1]
	end
	assert(supports_multiple, ("%s accepts only one shortcut"):format(id))
	return lhs_list
end

---@param areas string[]
---@param opts? { supports_multiple: boolean? }
---@return table
function M.by_action(areas, opts)
	opts = opts or {}
	local adapter = {}

	---@param catalog gleb.ActionCatalog
	---@param shortcuts gleb.ShortcutMap
	---@return table<string, string>
	function adapter.mappings(catalog, shortcuts)
		local mappings = {}
		for id, lhs_list in pairs(shortcuts) do
			if belongs_to(areas, id) and catalog:get(id) then
				mappings[action_name(id)] = native_lhs(id, lhs_list, opts.supports_multiple == true)
			end
		end
		return mappings
	end

	return adapter
end

---@param areas string[]
---@param wrap fun(run: fun(ctx: gleb.ActionContext)): unknown
---@return table
function M.by_lhs(areas, wrap)
	local adapter = {}

	---@param catalog gleb.ActionCatalog
	---@param shortcuts gleb.ShortcutMap
	---@return table<string, unknown>
	function adapter.mappings(catalog, shortcuts)
		local mappings = {}
		for id, lhs_list in pairs(shortcuts) do
			local action = belongs_to(areas, id) and catalog:get(id) or nil
			if action then
				for _, lhs in ipairs(lhs_list) do
					mappings[lhs] = wrap(Context.invoke(action))
				end
			end
		end
		return mappings
	end

	return adapter
end

--- Run a plugin-window action by replaying its first assigned key, which the plugin itself maps.
---@param id string
---@return fun()
function M.replay(id)
	return function()
		local store = assert(require("gleb.actions").state.store, "actions are not set up")
		local lhs = assert(store.last_good[id], "shortcut is not configured")[1]
		vim.api.nvim_feedkeys(vim.keycode(lhs), "m", false)
	end
end

--- Native defaults with every key cleared, ready to receive the adapter's keys.
---@param defaults table<string, unknown> plugin action name → default key(s)
---@param cleared unknown value the plugin reads as "no key"
---@return table<string, unknown>
function M.cleared(defaults, cleared)
	local keys = {}
	for name in pairs(defaults) do
		keys[name] = cleared
	end
	return keys
end

---@param run fun(ctx: gleb.ActionContext)
---@return fun(ctx: gleb.ActionContext)
function M.callback(run)
	return run
end

---@param run fun(ctx: gleb.ActionContext)
---@return function[]
function M.command_list(run)
	return { run }
end

return M
