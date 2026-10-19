-- Fold actions expose ufo and built-in fold operations without assigning keys.

local Context = require("gleb.actions.context")
local Tree = require("gleb.ui.tree")

---@param verb "close"|"open"|"close_all"|"open_all"
---@return boolean handled
local function run_tree(verb)
	local tree = Tree.get(0)
	if not tree then
		return false
	end
	Tree[verb](tree)
	return true
end

---@param ctx gleb.ActionContext
---@param command string
local function run_one(ctx, command)
	pcall(vim.cmd.normal, { args = { Context.counted(ctx, command) }, bang = true })
end

---@param ctx gleb.ActionContext
local function open_one(ctx)
	if run_tree("open") then
		return
	end
	run_one(ctx, "zo")
end

---@param ctx gleb.ActionContext
local function close_one(ctx)
	if run_tree("close") then
		return
	end
	run_one(ctx, "zc")
end

local function open_all()
	if run_tree("open_all") then
		return
	end
	require("ufo").openAllFolds()
end

local function close_all()
	if run_tree("close_all") then
		return
	end
	require("ufo").closeAllFolds()
end

---@type gleb.Action[]
local actions = {
	{ id = "fold.open_all", title = "Expand All Folds", category = "Fold", run = open_all },
	{ id = "fold.close_all", title = "Collapse All Folds", category = "Fold", run = close_all },
	{ id = "fold.open_one", title = "Expand Fold", category = "Fold", run = open_one },
	{ id = "fold.close_one", title = "Collapse Fold", category = "Fold", run = close_one },
}

return actions
