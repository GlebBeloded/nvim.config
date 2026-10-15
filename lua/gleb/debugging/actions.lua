-- dap-ui window actions; lua/gleb/debugging/ui.lua hands their keys to dap-ui's element and float mappings.

local replay = require("gleb.actions.adapters").replay

---@param area "dap_ui"|"dap_float"
---@param name string dap-ui mapping action
---@param title string
---@return gleb.Action
local function dap_ui_action(area, name, title)
	local id = area .. "." .. name
	return { id = id, title = title, category = "Debug", plugin = "dap-ui", run = replay(id) }
end

---@type gleb.Action[]
local actions = {
	dap_ui_action("dap_ui", "open", "Open Debug Element"),
	dap_ui_action("dap_ui", "remove", "Remove Debug Element"),
	dap_ui_action("dap_ui", "expand", "Expand Debug Element"),
	dap_ui_action("dap_ui", "repl", "Send Debug Element to REPL"),
	dap_ui_action("dap_ui", "toggle", "Toggle Debug Element"),
	dap_ui_action("dap_float", "close", "Close Debug Floating Window"),
}

return actions
