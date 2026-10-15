-- alpha dashboard adapter: buttons and alpha's own press keys take their keys from the shortcut map.

local Context = require("gleb.actions.context")
local Registry = require("gleb.actions.registry")

local M = {}

---@class gleb.AlphaButton
---@field id string action id
---@field label string button text

---@param shortcuts gleb.ShortcutMap
---@param id string
---@return string? lhs
local function single_lhs(shortcuts, id)
	local lhs_list = shortcuts[id] or {}
	assert(#lhs_list <= 1, ("%s accepts only one shortcut"):format(id))
	return lhs_list[1]
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param dashboard table alpha.themes.dashboard
---@param item gleb.AlphaButton
---@return table element alpha button
local function button(catalog, shortcuts, dashboard, item)
	local action = assert(catalog:get(item.id), item.id .. " is not registered")
	local lhs = single_lhs(shortcuts, item.id)
	local run = Context.invoke(action)
	local element = dashboard.button(lhs or "", item.label)
	element.on_press = run
	if lhs then
		element.opts.keymap = { "n", lhs, run, { nowait = true, silent = true, desc = Registry.description(action) } }
	end
	return element
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param dashboard table alpha.themes.dashboard
---@param items gleb.AlphaButton[]
---@return table[] elements alpha buttons, each pressed by its action's shortcut or `<CR>`
function M.buttons(catalog, shortcuts, dashboard, items)
	local elements = {}
	for _, item in ipairs(items) do
		table.insert(elements, button(catalog, shortcuts, dashboard, item))
	end
	return elements
end

--- alpha's `opts.keymap`; an empty list leaves that press unmapped.
---@param shortcuts gleb.ShortcutMap
---@return { press: string[], queue_press: string[] }
function M.press_keys(shortcuts)
	return { press = shortcuts["alpha.press"] or {}, queue_press = shortcuts["alpha.queue_press"] or {} }
end

return M
