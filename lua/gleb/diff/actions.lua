-- User-facing entry actions for the owned diff viewer.

local source = require("gleb.diff.view.source")

---@param ctx gleb.ActionContext
---@return gleb.diff.view.View?
local function current(ctx)
	return require("gleb.diff.view").state.by_win[ctx.win]
end

---@param ctx gleb.ActionContext
local function close(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").close(view)
	end
end

---@param ctx gleb.ActionContext
local function next_file(ctx)
	local view = current(ctx)
	if view and view.on_next_file then
		view.on_next_file()
	end
end

---@param ctx gleb.ActionContext
local function expand_fold(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").expand_fold(view, ctx.win)
	end
end

---@param ctx gleb.ActionContext
local function toggle_folds(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").toggle_folds(view, ctx.win)
	end
end

---@param ctx gleb.ActionContext
local function next_change(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").navigate(view, ctx.win, 1)
	end
end

---@param ctx gleb.ActionContext
local function previous_change(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").navigate(view, ctx.win, -1)
	end
end

---@param ctx gleb.ActionContext
local function apply(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").apply(view, ctx.win)
	end
end

---@param ctx gleb.ActionContext
local function toggle_include(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").toggle_include(view, ctx.win)
	end
end

---@param ctx gleb.ActionContext
local function open_file(ctx)
	local path = vim.api.nvim_buf_get_name(ctx.buf)
	local view = require("gleb.diff.view")
	local existing = view.state.by_path[vim.fs.normalize(path)]
	if existing and vim.api.nvim_tabpage_is_valid(existing.tab) then
		view.open({ path = path, left = {}, right = {}, labels = { left = "", right = "" } })
		return
	end
	local data, err = source.current(path, ctx.buf)
	if err == "not_repo" then
		vim.notify("Not in a git repository", vim.log.levels.WARN)
		return
	end
	assert(data, "source data missing")
	local opened = view.open({
		path = data.path,
		root = data.root,
		relpath = data.relpath,
		left = data.left,
		right = data.right,
		right_buf = ctx.buf,
		filetype = data.filetype,
		labels = { left = data.hash .. " · HEAD", right = "Your version" },
	})
	if not opened then
		vim.notify("No changes", vim.log.levels.INFO)
	end
end

---@type gleb.Action[]
local actions = {
	{
		id = "diff.open_file",
		title = "Open File Diff",
		category = "Git | Diff",
		when = function(ctx)
			return vim.bo[ctx.buf].buftype == "" and vim.api.nvim_buf_get_name(ctx.buf) ~= ""
		end,
		run = open_file,
	},
	{
		id = "diff.next_change",
		title = "Next Change",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = next_change,
	},
	{
		id = "diff.prev_change",
		title = "Previous Change",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = previous_change,
	},
	{
		id = "diff.apply",
		title = "Revert Change",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = apply,
	},
	{
		id = "diff.toggle_include",
		title = "Toggle Change Staging",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = toggle_include,
	},
	{
		id = "diff.next_file",
		title = "Next File",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = next_file,
	},
	{
		id = "diff.expand_fold",
		title = "Expand Fold",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = expand_fold,
	},
	{
		id = "diff.toggle_folds",
		title = "Toggle Folds",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = toggle_folds,
	},
	{
		id = "diff.close",
		title = "Close Diff",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = close,
	},
}

return actions
