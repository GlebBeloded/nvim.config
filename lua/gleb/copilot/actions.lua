-- Copilot suggestion actions; lua/gleb/copilot/init.lua hands their keys to copilot.lua's suggestion keymap.

---@param id string
---@param title string
---@param command "next"|"prev"|"dismiss"
---@return gleb.Action
local function suggestion_action(id, title, command)
	return {
		id = "copilot." .. id,
		title = title,
		category = "Copilot",
		plugin = "copilot",
		modes = { "i" },
		run = function()
			require("copilot.suggestion")[command]()
		end,
	}
end

---@type gleb.Action[]
local actions = {
	suggestion_action("next", "Next Copilot Suggestion", "next"),
	suggestion_action("prev", "Previous Copilot Suggestion", "prev"),
	suggestion_action("dismiss", "Dismiss Copilot Suggestion", "dismiss"),
}

return actions
