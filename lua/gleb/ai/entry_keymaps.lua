local M = {}

---@class gleb.ai.Actions
---@field search fun()
---@field vibe fun()
---@field visual fun()

---@type gleb.ai.Actions
local nn

---@return gleb.ai.Actions
local function actions()
	return nn or require("99")
end

---@param action fun()
local function enter_prompt(action)
	action()
	vim.schedule(vim.cmd.startinsert)
end

---Open the 99 search prompt and enter Insert mode.
---@return nil
function M.search_prompt()
	enter_prompt(actions().search)
end

---Open the 99 vibe prompt and enter Insert mode.
---@return nil
function M.vibe_prompt()
	enter_prompt(actions().vibe)
end

---Open the 99 visual prompt and enter Insert mode.
---@return nil
function M.visual_prompt()
	enter_prompt(actions().visual)
end

---Provide the loaded 99 module to action callbacks.
---@param ninety_nine gleb.ai.Actions the 99 module (or a stub with the same actions)
---@return nil
function M.setup(ninety_nine)
	nn = ninety_nine
end

return M
