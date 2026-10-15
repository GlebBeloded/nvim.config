-- Fold actions expose ufo and built-in fold operations without assigning keys.

local Context = require("gleb.actions.context")

---@param ctx gleb.ActionContext
local function open_one(ctx)
	vim.cmd.normal({ args = { Context.counted(ctx, "zo") }, bang = true })
end

---@param ctx gleb.ActionContext
local function close_one(ctx)
	vim.cmd.normal({ args = { Context.counted(ctx, "zc") }, bang = true })
end

---@type gleb.Action[]
local actions = {
	{ id = "fold.open_all", title = "Open all", category = "Fold", run = require("ufo").openAllFolds },
	{ id = "fold.close_all", title = "Close all", category = "Fold", run = require("ufo").closeAllFolds },
	{ id = "fold.open_one", title = "Open one", category = "Fold", run = open_one },
	{ id = "fold.close_one", title = "Close one", category = "Fold", run = close_one },
}

return actions
