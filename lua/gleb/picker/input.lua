-- Shared framed text input: keep MiniPick's editing while rendering one query-derived preview row.

local M = {}

local ok, MiniPick = pcall(require, "mini.pick")
if not ok then
	return M
end

local frame = require("gleb.picker.frame")
local layout = require("gleb.picker.layout")

local statusline_namespace = vim.api.nvim_create_namespace("gleb_picker_input_statusline")

-- the hint row greys only its text (approved G1/G2 renders)
local HIGHLIGHT_OVERRIDES = { PickerHintPadding = "MiniPickNormal" }

---@class gleb.picker.InputOpts
---@field title string
---@field default? string
---@field preview fun(query: string): gleb.picker.Row
---@field hint string
---@field on_submit fun(query: string)

---@return gleb.picker.WindowConfig
local function window_config()
	local config = layout.window_config()
	config.height = 3
	config.row = config.row + 1
	return config
end

local function seed_lualine_branch()
	local branch = require("lualine.components.branch.git_branch")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if name ~= "" and vim.bo[buf].buftype == "" then
			vim.api.nvim_buf_call(buf, branch.find_git_dir)
			if branch.get_branch() ~= "" then
				return
			end
		end
	end
end

---@param buf integer
---@param origin_win integer
local function render_origin_statusline(buf, origin_win)
	seed_lualine_branch()
	local statusline = vim.api.nvim_win_call(origin_win, function()
		return require("lualine").statusline(true) or ""
	end)
	local evaluated = vim.api.nvim_eval_statusline(statusline, {
		winid = origin_win,
		maxwidth = vim.o.columns,
		highlights = true,
	})
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { evaluated.str })
	vim.api.nvim_buf_clear_namespace(buf, statusline_namespace, 0, -1)
	for index, highlight in ipairs(evaluated.highlights or {}) do
		local following = evaluated.highlights[index + 1]
		vim.api.nvim_buf_set_extmark(buf, statusline_namespace, 0, highlight.start, {
			end_col = following and following.start or #evaluated.str,
			hl_group = highlight.group,
		})
	end
end

---@param origin_win integer
---@return integer?
local function open_origin_statusline(origin_win)
	if vim.o.laststatus ~= 3 or not package.loaded.lualine or not vim.api.nvim_win_is_valid(origin_win) then
		return nil
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	render_origin_statusline(buf, origin_win)
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = vim.o.lines - 1,
		col = 0,
		width = vim.o.columns,
		height = 1,
		border = "none",
		style = "minimal",
		focusable = false,
		zindex = 1,
	})
	vim.wo[win].winhighlight = "Normal:StatusLine"
	local group = vim.api.nvim_create_augroup("gleb_picker_input_statusline_" .. win, { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_win_is_valid(origin_win) then
				return
			end
			vim.api.nvim_win_set_config(
				win,
				{ relative = "editor", row = vim.o.lines - 1, col = 0, width = vim.o.columns }
			)
			render_origin_statusline(buf, origin_win)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = tostring(win),
		once = true,
		callback = function()
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
	return win
end

---@param _stritems string[]
---@param inds integer[]
---@param _query string[]
---@return integer[]
local function keep_preview(_stritems, inds, _query)
	return inds
end

---@param query string
---@return string[]
local function query_characters(query)
	return vim.fn.split(query, "\\zs")
end

---@param win integer
---@param guicursor string
---@param on_restored fun()
local function after_teardown(win, guicursor, on_restored)
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
			vim.o.guicursor = guicursor
		end
		on_restored()
	end)
end

---@param opts gleb.picker.InputOpts
---@return nil
function M.open(opts)
	if not _G.MiniPick then
		frame.setup()
	end
	local origin_win = vim.api.nvim_get_current_win()
	local origin_guicursor = vim.o.guicursor
	local statusline_win = open_origin_statusline(origin_win)
	local submitted_query
	local picker_opts = frame.options(opts.title, opts.hint, window_config, nil, HIGHLIGHT_OVERRIDES)
	local show_frame = picker_opts.source.show

	picker_opts.source = vim.tbl_extend("force", picker_opts.source, {
		items = { { text = "" } },
		match = keep_preview,
		show = function(buf, _items, query)
			show_frame(buf, { opts.preview(table.concat(query)) }, query)
		end,
	})
	picker_opts.mappings = {
		choose = "",
		submit_input = {
			char = "<CR>",
			func = function()
				local query = vim.trim(table.concat(MiniPick.get_picker_query() or {}))
				if query == "" then
					return false
				end
				submitted_query = query
				return true
			end,
		},
	}

	if opts.default and opts.default ~= "" then
		vim.schedule(function()
			MiniPick.set_picker_query(query_characters(opts.default --[[@as string]]))
		end)
	end

	MiniPick.start(picker_opts)
	if statusline_win and vim.api.nvim_win_is_valid(statusline_win) then
		vim.api.nvim_win_close(statusline_win, true)
	end
	after_teardown(origin_win, origin_guicursor, function()
		if submitted_query then
			opts.on_submit(submitted_query --[[@as string]])
		end
	end)
end

return M
