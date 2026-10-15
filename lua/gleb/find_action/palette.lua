-- Find Action captures its invocation context before handing focus to the shared picker frame.

local Context = require("gleb.actions.context")
local Assign = require("gleb.find_action.assign")
local Items = require("gleb.find_action.items")
local Rows = require("gleb.find_action.rows")
local picker = require("gleb.picker")
local picker_layout = require("gleb.picker.layout")
local color_palette = require("gleb.colors.gruvbox-material.palette")
local MiniPick = require("mini.pick")

---@class gleb.FindActionState
---@field context? gleb.ActionContext
---@field query? string
---@field show_hidden? boolean
---@field rows? gleb.FindActionRow[]
---@field pending_current_ind? integer

---@class gleb.FindActionRow: gleb.picker.Row
---@field action? gleb.Action
---@field hidden? boolean

local M = {
	---@type gleb.FindActionState
	state = {},
}

local function setup_highlights()
	local colors = {
		body = "#45403d",
		selected = "#59524d",
		text = "#d9c8a5",
		prompt = "#da8f57",
		metadata = "#a59a86",
		dim = "#8f8475",
		hint = "#32302f",
	}
	vim.api.nvim_set_hl(0, "FindActionBody", { fg = colors.text, bg = colors.body })
	vim.api.nvim_set_hl(0, "FindActionSelected", { fg = colors.text, bg = colors.selected })
	vim.api.nvim_set_hl(0, "FindActionPrompt", { fg = colors.prompt, bg = colors.body })
	vim.api.nvim_set_hl(0, "FindActionCaret", { fg = color_palette.foreground.blue, bg = colors.body })
	vim.api.nvim_set_hl(0, "FindActionBorder", { fg = colors.dim, bg = colors.body })
	vim.api.nvim_set_hl(0, "FindActionMetadata", { fg = colors.metadata })
	vim.api.nvim_set_hl(0, "FindActionSeparator", { fg = colors.dim })
	vim.api.nvim_set_hl(0, "FindActionShortcut", { fg = colors.dim })
	vim.api.nvim_set_hl(0, "FindActionRule", { fg = colors.dim })
	vim.api.nvim_set_hl(0, "FindActionToggleOn", { fg = color_palette.foreground.green })
	vim.api.nvim_set_hl(0, "FindActionToggleOff", { fg = colors.metadata })
	vim.api.nvim_set_hl(0, "FindActionHint", { fg = colors.metadata, bg = colors.hint })
	vim.api.nvim_set_hl(0, "FindActionHintKey", { fg = colors.text, bg = colors.hint })
end

---@param ctx gleb.ActionContext
---@return string
local function action_mode(ctx)
	return ctx.selection and "x" or ctx.mode
end

---@param action gleb.Action
---@param hidden? boolean
---@return gleb.FindActionRow
local function action_row(action, hidden)
	local shortcuts = assert(require("gleb.actions").state.store, "actions are not set up").last_good[action.id]
	local toggle_state = Context.get_toggle(action, assert(M.state.context, "Find Action context is missing"))
	local formatted = Rows.format(action, shortcuts, toggle_state)
	---@type gleb.FindActionRow
	return {
		text = formatted.text,
		secondary = formatted.secondary,
		category = formatted.category,
		glyph = formatted.glyph,
		dim = hidden,
		action = action,
		hidden = hidden,
	}
end

---@return gleb.FindActionRow[]
local function make_rows()
	local actions = require("gleb.actions")
	local catalog = assert(actions.state.applicator, "actions are not set up").catalog
	local ctx = assert(M.state.context, "Find Action context is missing")
	local filetype = vim.bo[ctx.buf].filetype
	local available = catalog:filter(action_mode(ctx), filetype, ctx)
	local visible = vim.tbl_filter(function(action)
		return not action.hidden
	end, available)

	local ordered = Items.order(visible, Items.history():load())
	local rows = {}
	if #ordered.recent > 0 then
		table.insert(rows, { text = "recently used", section = true })
		vim.list_extend(rows, vim.tbl_map(action_row, ordered.recent))
	end
	if #ordered.curated > 0 then
		table.insert(rows, { text = "other actions", section = true })
		vim.list_extend(rows, vim.tbl_map(action_row, ordered.curated))
	end
	if not M.state.show_hidden then
		return rows
	end

	local visible_ids = {}
	for _, action in ipairs(visible) do
		visible_ids[action.id] = true
	end
	local hidden = vim.tbl_filter(function(action)
		return not visible_ids[action.id]
	end, catalog.actions)
	vim.list_extend(hidden, catalog:hidden())

	table.insert(rows, { text = "More results", section = true, hidden = true })
	for _, action in ipairs(hidden) do
		table.insert(rows, action_row(action, true))
	end
	return rows
end

local function select_first_actionable_match()
	if not MiniPick.is_picker_active() then
		return
	end
	local matches = MiniPick.get_picker_matches()
	if not matches then
		return
	end
	for _, index in ipairs(matches.all_inds) do
		local row = assert(M.state.rows, "Find Action rows are missing")[index]
		if row.action then
			MiniPick.set_picker_match_inds({ index }, "current")
			return
		end
	end
end

local function schedule_first_actionable_match()
	vim.schedule(select_first_actionable_match)
end

---@param offset integer
local function move_to_actionable_match(offset)
	local matches = MiniPick.get_picker_matches()
	if not matches or not matches.current_ind or #matches.all_inds == 0 then
		return
	end
	local position = vim.fn.index(matches.all_inds, matches.current_ind) + 1
	for _ = 1, #matches.all_inds do
		position = ((position - 1 + offset) % #matches.all_inds) + 1
		local index = matches.all_inds[position]
		if assert(M.state.rows, "Find Action rows are missing")[index].action then
			MiniPick.set_picker_match_inds({ index }, "current")
			return
		end
	end
end

local function move_to_next_action()
	move_to_actionable_match(1)
end

local function move_to_previous_action()
	move_to_actionable_match(-1)
end

---@param direction integer
local function scroll_to_actionable_match(direction)
	local matches = MiniPick.get_picker_matches()
	local state = MiniPick.get_picker_state()
	if not matches or not matches.current_ind or #matches.all_inds == 0 or not state then
		return
	end
	local position = vim.fn.index(matches.all_inds, matches.current_ind) + 1
	local offset = direction * vim.api.nvim_win_get_height(state.windows.main)
	local target
	if position == 1 and offset < 0 then
		target = #matches.all_inds
	elseif position == #matches.all_inds and offset > 0 then
		target = 1
	else
		target = math.min(math.max(position + offset, 1), #matches.all_inds)
	end
	local rows = assert(M.state.rows, "Find Action rows are missing")
	for distance = 0, #matches.all_inds - 1 do
		for _, candidate in ipairs({ target + direction * distance, target - direction * distance }) do
			local index = matches.all_inds[candidate]
			if index and rows[index].action then
				MiniPick.set_picker_match_inds({ index }, "current")
				return
			end
		end
	end
end

local function scroll_down()
	scroll_to_actionable_match(1)
end

local function scroll_up()
	scroll_to_actionable_match(-1)
end

---@param inds integer[]
local function restore_pending_current(inds)
	local target = M.state.pending_current_ind
	if not target then
		return
	end
	M.state.pending_current_ind = nil
	if not vim.tbl_contains(inds, target) then
		return
	end
	vim.schedule(function()
		local matches = MiniPick.get_picker_matches()
		if matches and vim.tbl_contains(matches.all_inds, target) then
			MiniPick.set_picker_match_inds({ target }, "current")
		end
	end)
end

---@param _ string[]
---@param inds integer[]
---@param query string[]
---@return integer[]
local function match_rows(_, inds, query)
	local rows = assert(M.state.rows, "Find Action rows are missing")
	local text = table.concat(query)
	if text ~= M.state.query then
		M.state.query = text
		schedule_first_actionable_match()
	end
	if text == "" then
		restore_pending_current(inds)
		return inds
	end
	local visible_matches = {}
	local hidden_matches = {}
	local separator
	for _, index in ipairs(inds) do
		local row = rows[index]
		if row.section then
			separator = index
		elseif row.action and #Items.match({ row.action }, text) > 0 then
			table.insert(row.hidden and hidden_matches or visible_matches, index)
		end
	end
	if #hidden_matches > 0 and separator then
		table.insert(visible_matches, separator)
		vim.list_extend(visible_matches, hidden_matches)
	end
	restore_pending_current(visible_matches)
	return visible_matches
end

---@return boolean
local function show_hidden()
	M.state.show_hidden = true
	M.state.rows = make_rows()
	MiniPick.set_picker_items(M.state.rows)
	schedule_first_actionable_match()
	return false
end

---@return boolean
local function request_assignment()
	local current = MiniPick.get_picker_matches().current
	if current and current.action and current.action.hidden then
		return false
	end
	if not current or not current.action then
		return false
	end
	local selected = MiniPick.get_picker_matches().current_ind
	Assign.open(current.action)
	M.state.rows = make_rows()
	M.state.pending_current_ind = selected
	MiniPick.set_picker_items(M.state.rows)
	return false
end

---@param row gleb.FindActionRow
---@return boolean
local function choose_action(row)
	local matches = assert(MiniPick.get_picker_matches(), "Find Action matches are missing")
	local selected = matches.current_ind
	local target = selected
	local action = row.action
	if row.section then
		local rows = assert(M.state.rows, "Find Action rows are missing")
		for position, index in ipairs(matches.all_inds) do
			if index == selected then
				target = matches.all_inds[position + 1]
				break
			end
		end
		action = target and rows[target] and rows[target].action
	end
	if not action then
		return true
	end
	local ctx = assert(M.state.context, "Find Action context is missing")
	if action.toggle then
		Context.record(action)
		local rows = assert(M.state.rows, "Find Action rows are missing")
		vim.api.nvim_win_call(ctx.win, function()
			local value = not Context.get_toggle(action, ctx)
			Context.set_toggle(action, ctx, value)
		end)
		if target then
			rows[target].glyph = Context.get_toggle(action, ctx)
		end
		M.state.pending_current_ind = selected
		MiniPick.set_picker_items(rows)
		return true
	end

	vim.schedule(function()
		Context.execute(action, ctx)
	end)
	return false
end

---@return string?
local function hints()
	local kind = picker_layout.current().kind
	if kind == "full" then
		return "Assign ⌥↩ · Show hidden ⌘⇧A"
	elseif kind == "compact" then
		return "⌥↩ · ⌘⇧A"
	end
end

---@return table
local function window_config()
	local config = picker_layout.window_config()
	config.height = math.min(16, math.max(vim.o.lines - 4, 1))
	config.row = math.max(math.floor((vim.o.lines - config.height - 4) / 2), 0)
	return config
end

---@param ctx? gleb.ActionContext
---@return any
function M.open(ctx)
	setup_highlights()
	M.state.context = ctx or Context.capture()
	M.state.query = nil
	M.state.show_hidden = false
	M.state.rows = make_rows()
	return picker.start({
		title = "Find Action",
		items = M.state.rows,
		hints = hints,
		hint_band = picker_layout.current().kind ~= "narrow",
		hint_keys = { "⌥↩", "⌘⇧A" },
		window_config = window_config,
		highlight_overrides = {
			FloatBorder = "FindActionBorder",
			MiniPickBorder = "FindActionBorder",
			MiniPickNormal = "FindActionBody",
			MiniPickMatchCurrent = "FindActionSelected",
			MiniPickPrompt = "FindActionBody",
			MiniPickPromptCaret = "FindActionCaret",
			MiniPickPromptPrefix = "FindActionPrompt",
			NormalFloat = "FindActionBody",
			PickerCategory = "FindActionMetadata",
			PickerCategorySeparator = "FindActionSeparator",
			PickerBandBorder = "FindActionBorder",
			PickerHintBand = "FindActionHint",
			PickerHintKey = "FindActionHintKey",
			PickerSectionLabel = "FindActionMetadata",
			PickerSectionRule = "FindActionRule",
			PickerSecondary = "FindActionShortcut",
			PickerToggleOff = "FindActionToggleOff",
			PickerToggleOn = "FindActionToggleOn",
		},
		selected_category = true,
		match = match_rows,
		choose = choose_action,
		mappings = {
			show_hidden = { char = "<M-A>", func = show_hidden },
			assign_shortcut = { char = "<M-}>", func = request_assignment },
			move_down = "",
			move_action_down = { char = "<C-n>", func = move_to_next_action },
			move_down_arrow = { char = "<Down>", func = move_to_next_action },
			move_up = "",
			move_action_up = { char = "<C-p>", func = move_to_previous_action },
			move_up_arrow = { char = "<Up>", func = move_to_previous_action },
			move_start = "",
			move_action_start = { char = "<C-g>", func = select_first_actionable_match },
			move_start_home = { char = "<Home>", func = select_first_actionable_match },
			scroll_down = "",
			scroll_action_down = { char = "<C-f>", func = scroll_down },
			scroll_up = "",
			scroll_action_up = { char = "<C-b>", func = scroll_up },
		},
	})
end

---@return nil
function M.reset()
	M.state = {}
end

return M
