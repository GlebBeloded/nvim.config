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

local chrome_windows = {}
local hint_namespace = vim.api.nvim_create_namespace("gleb_picker_hint_band")

---@class gleb.picker.FrameOpts
---@field title string
---@field items gleb.picker.Row[]
---@field hints? gleb.picker.Hint
---@field hint_band? boolean
---@field hint_keys? string[]
---@field choose? fun(item: gleb.picker.Row)
---@field match? fun(stritems: string[], inds: integer[], query: string[]): integer[]
---@field mappings? table<string, string|table>
---@field window_config? fun(): table
---@field highlight_overrides? table<string, string>
---@field selected_category? boolean

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
	vim.api.nvim_set_hl(0, "PickerSecondary", { fg = bg.bg5 })
	vim.api.nvim_set_hl(0, "PickerCategory", { fg = bg.bg5 })
	vim.api.nvim_set_hl(0, "PickerSectionLabel", { fg = bg.bg5 })
	vim.api.nvim_set_hl(0, "PickerSectionRule", { fg = bg.bg3 })
	vim.api.nvim_set_hl(0, "PickerToggleOn", { fg = fg.green })
	vim.api.nvim_set_hl(0, "PickerToggleOff", { fg = bg.bg5 })
	vim.api.nvim_set_hl(0, "PickerHintBand", { fg = bg.bg5, bg = bg.bg1 })
	vim.api.nvim_set_hl(0, "PickerHintKey", { fg = fg.fg1, bg = bg.bg1 })
	vim.api.nvim_set_hl(0, "PickerBandBorder", { fg = bg.bg3, bg = bg.bg0 })
end

local function close_chrome_windows()
	for _, win in ipairs(chrome_windows) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	chrome_windows = {}
end

local function clear_picker_footer()
	if not MiniPick.is_picker_active() then
		return
	end
	local win = MiniPick.get_picker_state().windows.main
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_config(win, { footer = "" })
	end
end

local function schedule_clear_picker_footer()
	vim.schedule(clear_picker_footer)
end

---@param win integer
---@param overrides? table<string, string>
local function apply_highlight_overrides(win, overrides)
	for from, to in pairs(overrides or {}) do
		local entry = from .. ":" .. to
		local pattern = "(" .. vim.pesc(from) .. ":[^,]*)"
		local value, count = vim.wo[win].winhighlight:gsub(pattern, entry)
		vim.wo[win].winhighlight = count == 0 and (value .. "," .. entry) or value
	end
end

---@param hint string
---@param parent integer
local function open_hint_window(hint, parent)
	close_chrome_windows()
	local position = vim.api.nvim_win_get_position(parent)
	local width = vim.api.nvim_win_get_width(parent)
	local height = vim.api.nvim_win_get_height(parent)
	local zindex = vim.api.nvim_win_get_config(parent).zindex + 1
	local available = math.max(width - 2, 0)
	local clipped = vim.fn.strcharpart(hint, 0, available)
	local padding = math.max(available - vim.fn.strdisplaywidth(clipped), 0)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " " .. string.rep(" ", padding) .. clipped .. " " })
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = position[1] + height + 1,
		col = position[2],
		width = width,
		height = 1,
		border = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
		style = "minimal",
		focusable = false,
		zindex = zindex,
	})
	vim.wo[win].winhighlight = "Normal:PickerHint,FloatBorder:PickerBorder"
	table.insert(chrome_windows, win)
end

---@return string
local function match_counter()
	local matches = MiniPick.get_picker_matches()
	local items = MiniPick.get_picker_items()
	if not matches or not items then
		return "0/0"
	end
	local total = vim.tbl_count(vim.tbl_filter(function(item)
		return type(item) ~= "table" or not item.section
	end, items))
	local current = vim.tbl_count(vim.tbl_filter(function(index)
		local item = items[index]
		return type(item) ~= "table" or not item.section
	end, matches.all_inds))
	return string.format("%d/%d", current, total)
end

---@param buf integer
---@param group string
---@param col integer
---@param end_col integer
local function highlight_hint(buf, group, col, end_col)
	vim.api.nvim_buf_set_extmark(buf, hint_namespace, 0, col, { end_col = end_col, hl_group = group })
end

---@param hint string
---@param hint_keys? string[]
---@param parent integer
---@param highlight_overrides? table<string, string>
local function open_hint_band(hint, hint_keys, parent, highlight_overrides)
	close_chrome_windows()
	local position = vim.api.nvim_win_get_position(parent)
	local width = vim.api.nvim_win_get_width(parent)
	local height = vim.api.nvim_win_get_height(parent)
	local counter = match_counter()
	local available = math.max(width - vim.fn.strdisplaywidth(counter) - 3, 0)
	local clipped = vim.fn.strcharpart(hint, 0, available)
	local left = " " .. clipped
	local padding = math.max(width - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(counter) - 1, 0)
	local line = "│" .. left .. string.rep(" ", padding) .. counter .. " " .. "│"
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
	local band_group = highlight_overrides and highlight_overrides.PickerHintBand or "PickerHintBand"
	highlight_hint(buf, band_group, 0, #line)
	highlight_hint(buf, "PickerBandBorder", 0, #"│")
	highlight_hint(buf, "PickerBandBorder", #line - #"│", #line)
	for _, key in ipairs(hint_keys or {}) do
		local start_col = line:find(key, 1, true)
		if start_col then
			highlight_hint(buf, "PickerHintKey", start_col - 1, start_col - 1 + #key)
		end
	end
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = position[1] + height,
		col = position[2],
		width = width + 2,
		height = 1,
		border = "none",
		style = "minimal",
		focusable = false,
		zindex = vim.api.nvim_win_get_config(parent).zindex + 1,
	})
	vim.wo[win].winhighlight = "Normal:" .. band_group
	apply_highlight_overrides(win, highlight_overrides)
	table.insert(chrome_windows, win)
end

---@alias gleb.picker.Hint string|fun(): string?

---@param hints? gleb.picker.Hint
---@return string?
local function current_hint(hints)
	if type(hints) == "function" then
		return hints()
	end
	if hints then
		return layout.current().kind == "narrow" and nil or hints
	end
	return layout.hint()
end

---@return integer?
local function selected_match_position()
	local matches = MiniPick.get_picker_matches()
	if not matches then
		return nil
	end
	for position, index in ipairs(matches.shown_inds) do
		if index == matches.current_ind then
			return position
		end
	end
end

---@param hints? gleb.picker.Hint
---@param on_show? fun(items: any[])
---@param highlight_overrides? table<string, string>
---@param selected_category? boolean
---@return fun(buf: integer, items: any[], query: string[])
local function create_show(hints, on_show, highlight_overrides, selected_category, hint_band, hint_keys)
	return function(buf, items, query)
		local picker_win = MiniPick.get_picker_state().windows.main
		apply_highlight_overrides(picker_win, highlight_overrides)
		vim.api.nvim_win_set_config(picker_win, { footer = "" })
		local hint = current_hint(hints)
		if hint and hint_band then
			open_hint_band(hint, hint_keys, picker_win, highlight_overrides)
			vim.wo[picker_win].scrolloff = 1
		elseif hint then
			open_hint_window(hint, picker_win)
		else
			close_chrome_windows()
		end

		local render_win = vim.fn.bufwinid(buf)
		if render_win == -1 then
			return
		end

		if type(items[1]) == "table" then
			local width = vim.api.nvim_win_get_width(render_win)
			local row_opts = vim.tbl_extend("force", layout.row_options(), { padding = 1 })
			if selected_category then
				row_opts.selected = selected_match_position()
				row_opts.selected_metadata = true
			end
			rows.render(buf, items, width, row_opts)
		else
			MiniPick.default_show(buf, items, query)
		end

		if on_show then
			on_show(items)
		end
	end
end

---@param title string
---@param hints? gleb.picker.Hint
---@param window_config? fun(): table
---@param on_show? fun(items: gleb.picker.Row[])
---@param highlight_overrides? table<string, string>
---@param selected_category? boolean
---@return table
function M.options(title, hints, window_config, on_show, highlight_overrides, selected_category, hint_band, hint_keys)
	local base_window_config = window_config or layout.window_config
	return {
		source = {
			name = title,
			show = create_show(hints, on_show, highlight_overrides, selected_category, hint_band, hint_keys),
		},
		window = {
			prompt_prefix = " " .. title .. " › ",
			config = function()
				local config = vim.deepcopy(base_window_config())
				if current_hint(hints) then
					config.height = math.max(config.height - (hint_band and 1 or 2), 1)
				end
				return config
			end,
		},
	}
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
	vim.api.nvim_create_autocmd("BufWinEnter", { group = group, callback = schedule_clear_picker_footer })
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "MiniPickStart", callback = clear_picker_footer })
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "MiniPickStop", callback = close_chrome_windows })
end

---@param opts gleb.picker.FrameOpts
---@return any
function M.start(opts)
	local picker_opts = M.options(
		opts.title,
		opts.hints,
		opts.window_config,
		nil,
		opts.highlight_overrides,
		opts.selected_category,
		opts.hint_band,
		opts.hint_keys
	)
	picker_opts.source = vim.tbl_extend("force", picker_opts.source, {
		name = opts.title,
		items = opts.items,
		match = opts.match,
		choose = opts.choose,
	})
	picker_opts.mappings = opts.mappings
	return MiniPick.start(picker_opts)
end

return M
