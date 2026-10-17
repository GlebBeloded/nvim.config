-- User-facing entry actions for the owned diff viewer.

local source = require("gleb.diff.view.source")

---@param ctx gleb.ActionContext
---@return boolean
local function view_in_tab(ctx)
	local tab = vim.api.nvim_win_get_tabpage(ctx.win)
	for _, view in pairs(require("gleb.diff.view").state.by_path) do
		if view.tab == tab then
			return true
		end
	end
	return false
end

---@param key "policy"|"highlight"
---@param value string
local function set_setting(key, value)
	local view = require("gleb.diff.view")
	view.config[key] = value
	require("gleb.diff.settings").save({
		policy = view.config.policy,
		highlight = view.config.highlight,
	})
	view.recompare_all()
end

---@param id string
---@param title string
---@param key "policy"|"highlight"
---@param value string
---@return gleb.Action
local function setting_action(id, title, key, value)
	local function apply_setting()
		set_setting(key, value)
	end
	return {
		id = id,
		title = title,
		category = "Git | Diff",
		when = view_in_tab,
		run = apply_setting,
		toggle = {
			get = function()
				return require("gleb.diff.view").config[key] == value
			end,
			set = function(_, enabled)
				if enabled then
					apply_setting()
				end
			end,
		},
	}
end

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
local function jump_move(ctx)
	local view = current(ctx)
	if view then
		require("gleb.diff.view").jump_move(view, ctx.win)
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
		id = "diff.jump_move",
		title = "Jump to Other End of Move",
		category = "Git | Diff",
		plugin = "gleb-diff",
		run = jump_move,
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
	setting_action("diff.ignore_none", "Do Not Ignore", "policy", "default"),
	setting_action("diff.ignore_trim", "Trim Whitespaces", "policy", "trim_whitespaces"),
	setting_action("diff.ignore_whitespaces", "Ignore Whitespaces", "policy", "ignore_whitespaces"),
	setting_action(
		"diff.ignore_whitespaces_chunks",
		"Ignore Whitespaces and Empty Lines",
		"policy",
		"ignore_whitespaces_chunks"
	),
	setting_action("diff.highlight_words", "Highlight Words", "highlight", "by_word"),
	setting_action("diff.highlight_split", "Highlight Split Changes", "highlight", "by_word_split"),
	setting_action("diff.highlight_chars", "Highlight Symbols", "highlight", "by_char"),
	setting_action("diff.highlight_lines", "Highlight Lines", "highlight", "by_line"),
	setting_action("diff.highlight_none", "Do Not Highlight", "highlight", "none"),
}

return actions
