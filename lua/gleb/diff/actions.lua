-- User-facing entry actions for the owned diff viewer.

local source = require("gleb.diff.view.source")

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
}

return actions
