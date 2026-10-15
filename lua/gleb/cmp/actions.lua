-- Completion actions: blink.cmp command lists for insert and command-line keys (lua/gleb/cmp/init.lua binds them).

---@alias gleb.BlinkCommand string|fun(cmp: table): boolean?

--- Tab is the "super key": completion menu, then a visible Copilot suggestion, then a plain Tab.
---@param cmp table blink.cmp
---@return boolean?
local function select_next_or_accept_copilot(cmp)
	if cmp.is_visible() then
		return cmp.select_next()
	elseif require("copilot.suggestion").is_visible() then
		require("copilot.suggestion").accept()
		return true
	end
end

--- Run the commands in order until one handles the key; a palette run has no key to fall back to.
---@param commands gleb.BlinkCommand[]
local function run_commands(commands)
	local cmp = require("blink.cmp")
	for _, command in ipairs(commands) do
		if type(command) == "function" then
			if command(cmp) then
				return
			end
		elseif command ~= "fallback" and cmp[command]() then
			return
		end
	end
end

---@param id string
---@param title string
---@param mode "i"|"c"
---@param commands gleb.BlinkCommand[]
---@return gleb.Action
local function blink_action(id, title, mode, commands)
	return {
		id = "blink." .. id,
		title = title,
		category = "Completion",
		plugin = "blink",
		modes = { mode },
		commands = commands,
		run = function()
			run_commands(commands)
		end,
	}
end

---@type gleb.Action[]
local actions = {
	blink_action("show", "Show menu", "i", { "show" }),
	blink_action("select_next_or_accept_copilot", "Next item or accept Copilot", "i", {
		select_next_or_accept_copilot,
		"fallback",
	}),
	blink_action("select_prev", "Previous item", "i", { "select_prev", "fallback" }),
	blink_action("select_next", "Next item", "i", { "select_next", "fallback" }),
	blink_action("accept", "Accept", "i", { "accept", "fallback" }),
	blink_action("cancel", "Cancel", "i", { "cancel", "fallback" }),
	blink_action("scroll_documentation_up", "Scroll documentation up", "i", { "scroll_documentation_up", "fallback" }),
	blink_action(
		"scroll_documentation_down",
		"Scroll documentation down",
		"i",
		{ "scroll_documentation_down", "fallback" }
	),
	blink_action("cmdline_show_next", "Command line: show or next item", "c", { "show", "select_next", "fallback" }),
	blink_action(
		"cmdline_show_prev",
		"Command line: show or previous item",
		"c",
		{ "show", "select_prev", "fallback" }
	),
	blink_action("cmdline_select_next", "Command line: next item", "c", { "select_next", "fallback" }),
	blink_action("cmdline_select_prev", "Command line: previous item", "c", { "select_prev", "fallback" }),
	blink_action("cmdline_accept", "Command line: accept", "c", { "accept", "fallback" }),
	blink_action("cmdline_cancel", "Command line: cancel", "c", { "cancel", "fallback" }),
}

return actions
