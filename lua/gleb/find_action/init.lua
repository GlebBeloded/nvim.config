-- Find Action captures its invocation context before handing focus to the shared picker frame.

local Context = require("gleb.actions.context")
local picker = require("gleb.picker")

---@class gleb.FindActionState
---@field context? gleb.ActionContext

local M = {
	---@type gleb.FindActionState
	state = {},
}

---@param ctx? gleb.ActionContext
---@return any
function M.open(ctx)
	M.state.context = ctx or Context.capture()
	return picker.start({
		title = "Find Action",
		items = {},
	})
end

---@return nil
function M.reset()
	M.state = {}
end

return M
