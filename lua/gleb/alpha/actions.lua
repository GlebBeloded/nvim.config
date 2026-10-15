-- Dashboard actions; lua/gleb/alpha.lua hands their keys to alpha's buttons and press keys.

local replay = require("gleb.actions.adapters").replay

---@param id string
---@param title string
---@param run fun()
---@return gleb.Action
local function dashboard_action(id, title, run)
	return { id = id, title = title, category = "Dashboard", plugin = "alpha", run = run }
end

---@param ex_command string
---@return fun()
local function command(ex_command)
	return function()
		vim.cmd(ex_command)
	end
end

---@param source "files"|"recent_files"|"grep_live"
---@return fun()
local function picker(source)
	return function()
		require("gleb.picker")[source]()
	end
end

---@type gleb.Action[]
local actions = {
	dashboard_action("alpha.find_file", "Find file", picker("files")),
	dashboard_action("alpha.new_file", "New file", command("ene | startinsert")),
	dashboard_action("alpha.recent_files", "Recently used files", picker("recent_files")),
	dashboard_action("alpha.find_text", "Find text", picker("grep_live")),
	dashboard_action("alpha.configuration", "Configuration", command("e ~/.config/nvim/init.lua")),
	dashboard_action("alpha.quit", "Quit Neovim", command("qa")),
	dashboard_action("alpha.press", "Press button", replay("alpha.press")),
	dashboard_action("alpha.queue_press", "Queue button press", replay("alpha.queue_press")),
}

return actions
