-- Shared selection UI: adapt vim.ui.select items to the picker row model and completion contract.

local M = {}

local ok, MiniPick = pcall(require, "mini.pick")
if not ok then
	return M
end

local layout = require("gleb.picker.layout")
local rows = require("gleb.picker.rows")

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

---@return table
local function picker_mappings()
	return {
		move_down = "j",
		move_up = "k",
		choose = "<CR>",
		stop = "<Esc>",
		toggle_preview = "<M-p>",
		toggle_info = "<M-i>",
		focus_next_tab = { char = "<Tab>", func = move_next },
		focus_previous_tab = { char = "<S-Tab>", func = move_previous },
		close_control_c = { char = "<C-c>", func = stop_picker },
		submit_space = { char = "<Space>", func = submit_current },
	}
end

---@param preview_item? fun(item: any)
---@return fun(buf: integer, items: gleb.picker.Row[], query: string[])
local function create_show(preview_item)
	local previewed_index
	return function(buf, items, query)
		rows.show(buf, items, query)
		local current = MiniPick.get_picker_matches().current
		if preview_item and current and current.index ~= previewed_index then
			previewed_index = current.index
			preview_item(current.item)
		end
	end
end

---@param items any[]
---@param opts? table
---@param on_choice fun(item: any?, index: integer?)
---@return any
function M.select(items, opts, on_choice)
	opts = opts or {}
	local format_item = opts.format_item or tostring
	local picker_items = {}
	for index, item in ipairs(items) do
		picker_items[index] = { text = format_item(item), item = item, index = index }
	end

	local completed = false
	local function complete(item, index)
		if completed then
			return
		end
		completed = true
		on_choice(item, index)
	end

	local source = {
		items = picker_items,
		name = opts.prompt or opts.kind or "Select",
		show = create_show(opts.preview_item),
		choose = function(item)
			complete(item.item, item.index)
		end,
	}
	local window_config = opts.kind == "codeaction" and function()
		return M.window_config(items, opts)
	end or layout.window_config
	local selected = MiniPick.start({
		source = source,
		mappings = picker_mappings(),
		window = { config = window_config },
	})
	if selected == nil then
		complete(nil, nil)
	end
	return selected
end

---@diagnostic disable-next-line: duplicate-set-field
vim.ui.select = M.select

return M
