-- Shared selection UI: adapt vim.ui.select items to the picker row model and completion contract.

local M = {}

local ok, MiniPick = pcall(require, "mini.pick")
if not ok then
	return M
end

local layout = require("gleb.picker.layout")
local frame = require("gleb.picker.frame")

---@class gleb.picker.SelectKeymap
---@field focus_next string[]
---@field focus_prev string[]
---@field close string[]
---@field submit string[]

---@return gleb.picker.SelectKeymap
function M.default_keymap()
	return {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	}
end

---@param items any[]
---@param opts? table
---@return table
function M.window_config(items, opts)
	opts = opts or {}
	local format_item = opts.format_item or tostring
	local width = vim.fn.strdisplaywidth(opts.prompt or opts.kind or "Select")
	for _, item in ipairs(items) do
		width = math.max(width, vim.fn.strdisplaywidth(format_item(item)))
	end

	return {
		relative = "cursor",
		anchor = "NW",
		row = 1,
		col = 0,
		width = math.max(math.min(width + 2, vim.o.columns - 4), 1),
		height = math.max(math.min(#items + 2, vim.o.lines - 4), 1),
		border = "rounded",
	}
end

---@param by integer
---@return nil
local function move_current(by)
	local matches = MiniPick.get_picker_matches()
	if not matches or not matches.current_ind or #matches.all_inds == 0 then
		return
	end

	local position = vim.fn.index(matches.all_inds, matches.current_ind) + 1
	position = ((position - 1 + by) % #matches.all_inds) + 1
	MiniPick.set_picker_match_inds({ matches.all_inds[position] }, "current")
end

local function move_next()
	move_current(1)
end

local function move_previous()
	move_current(-1)
end

---@return boolean
local function submit_current()
	local matches = MiniPick.get_picker_matches()
	if not matches or not matches.current then
		return false
	end
	MiniPick.get_picker_opts().source.choose(matches.current)
	return true
end

---@return boolean
local function stop_picker()
	return true
end

---@param keymap gleb.picker.SelectKeymap
---@return table
local function picker_mappings(keymap)
	return {
		move_down = keymap.focus_next[1],
		move_up = keymap.focus_prev[1],
		choose = keymap.submit[1],
		stop = keymap.close[1],
		toggle_preview = "<M-p>",
		toggle_info = "<M-i>",
		focus_next_down = { char = keymap.focus_next[2], func = move_next },
		focus_next_tab = { char = keymap.focus_next[3], func = move_next },
		focus_previous_up = { char = keymap.focus_prev[2], func = move_previous },
		focus_previous_tab = { char = keymap.focus_prev[3], func = move_previous },
		close_control_c = { char = keymap.close[2], func = stop_picker },
		submit_space = { char = keymap.submit[2], func = submit_current },
	}
end

---@param preview_item? fun(item: any)
---@return fun()
local function create_preview(preview_item)
	local previewed_index
	return function()
		local matches = MiniPick.get_picker_matches()
		local current = matches and matches.current
		if preview_item and current and current.index ~= previewed_index then
			previewed_index = current.index
			preview_item(current.item)
		end
	end
end

---@return string?
local function selection_hint()
	local kind = layout.current().kind
	if kind == "full" then
		return "Choose ↩ · Cancel Esc"
	end
	if kind == "compact" then
		return "↩ · Esc"
	end
end

---@param items any[]
---@param opts? table
---@param on_choice fun(item: any?, index: integer?)
---@return any
function M.select(items, opts, on_choice)
	opts = opts or {}
	local completed = false
	local function complete(item, index)
		if completed then
			return
		end
		completed = true
		on_choice(item, index)
	end

	local title = opts.prompt or opts.kind or "Select"
	local window_config = layout.window_config
	if opts.kind == "codeaction" then
		window_config = function()
			return M.window_config(items, opts)
		end
	end
	local start_opts = frame.options(title, selection_hint, window_config, create_preview(opts.preview_item))
	if opts.kind == "codeaction" then
		start_opts.mappings = picker_mappings(M.default_keymap())
	end

	return MiniPick.ui_select(items, opts, function(item, index)
		if item == nil then
			complete(nil, nil)
		else
			complete(item, index)
		end
	end, start_opts)
end

---@diagnostic disable-next-line: duplicate-set-field
vim.ui.select = M.select

return M
