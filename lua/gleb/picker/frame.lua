-- Shared picker chrome: one rounded frame owns the prompt, rows and reserved hint area.
-- Sources provide structured rows; layout controls when metadata and hints are visible.

local M = {}

local ok, MiniPick = pcall(require, "mini.pick")
if not ok then
	return M
end

local layout = require("gleb.picker.layout")
local rows = require("gleb.picker.rows")
local palette = require("gleb.colors.gruvbox-material.palette")

local join_windows = {}
local namespace = vim.api.nvim_create_namespace("gleb_picker_frame")

---@class gleb.picker.FrameOpts
---@field title string
---@field items gleb.picker.Row[]
---@field hints? string
---@field choose? fun(item: gleb.picker.Row)
---@field match? fun(stritems: string[], inds: integer[], query: string[]): integer[]

local function setup_highlights()
	local bg = palette.background
	local fg = palette.foreground
	vim.api.nvim_set_hl(0, "MiniPickBorder", { fg = bg.bg3, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "MiniPickBorderText", { fg = fg.fg1, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "MiniPickNormal", { fg = fg.fg1, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "MiniPickMatchCurrent", { bg = bg.bg1 })
	vim.api.nvim_set_hl(0, "MiniPickPrompt", { fg = fg.fg1, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "MiniPickPromptCaret", { fg = fg.blue, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "MiniPickPromptPrefix", { fg = fg.fg1, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "PickerHint", { fg = bg.bg5, bg = bg.bg0 })
	vim.api.nvim_set_hl(0, "PickerBorder", { fg = bg.bg3, bg = bg.bg0 })
end

local function close_join_windows()
	for _, win in ipairs(join_windows) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	join_windows = {}
end

---@param char string
---@param row integer
---@param col integer
---@param zindex integer
local function open_join_window(char, row, col, zindex)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { char })
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = row,
		col = col,
		width = 1,
		height = 1,
		style = "minimal",
		focusable = false,
		zindex = zindex,
	})
	vim.wo[win].winhighlight = "Normal:PickerBorder"
	table.insert(join_windows, win)
end

---@param win integer
local function draw_joins(win)
	close_join_windows()
	local position = vim.api.nvim_win_get_position(win)
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)
	local zindex = vim.api.nvim_win_get_config(win).zindex + 1
	local separator_row = position[1] + height - 1
	open_join_window("├", separator_row, position[2], zindex)
	open_join_window("┤", separator_row, position[2] + width + 1, zindex)
end

---@param hints string
---@return fun(buf: integer, items: gleb.picker.Row[], query: string[])
local function create_show(hints)
	return function(buf, items, _query)
		local win = vim.fn.bufwinid(buf)
		if win == -1 then
			return
		end

		local width = vim.api.nvim_win_get_width(win)
		local height = vim.api.nvim_win_get_height(win)
		local item_count = math.max(height - 2, 0)
		local shown = vim.list_slice(items, 1, item_count)
		rows.render(buf, shown, width, vim.tbl_extend("force", layout.row_options(), { padding = 1 }))

		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		while #lines < item_count do
			table.insert(lines, "")
		end
		table.insert(lines, string.rep("─", width))
		local available = math.max(width - 2, 0)
		local clipped_hint = vim.fn.strcharpart(hints, 0, available)
		local padding = math.max(available - vim.fn.strdisplaywidth(clipped_hint), 0)
		table.insert(lines, " " .. string.rep(" ", padding) .. clipped_hint .. " ")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
		vim.api.nvim_buf_set_extmark(buf, namespace, height - 1, 0, {
			end_col = #lines[height],
			hl_group = "PickerHint",
		})
		vim.api.nvim_win_set_config(win, { footer = "" })
		draw_joins(win)
	end
end

---@return nil
function M.setup()
	MiniPick.setup({
		window = {
			config = layout.window_config,
			prompt_caret = "█",
			prompt_prefix = " ",
		},
	})
	setup_highlights()
	local group = vim.api.nvim_create_augroup("gleb_picker", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_highlights })
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "MiniPickStop", callback = close_join_windows })
end

---@param opts gleb.picker.FrameOpts
---@return any
function M.start(opts)
	local hints = opts.hints or layout.hint()
	return MiniPick.start({
		source = {
			name = opts.title,
			items = opts.items,
			match = opts.match,
			show = hints and create_show(hints) or rows.show,
			choose = opts.choose,
		},
		window = { prompt_prefix = " " .. opts.title .. " › " },
	})
end

return M
