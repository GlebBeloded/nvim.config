-- Find Action captures its invocation context before handing focus to the shared picker frame.

local Context = require("gleb.actions.context")
local Assign = require("gleb.find_action.assign")
local Items = require("gleb.find_action.items")
local Rows = require("gleb.find_action.rows")
local picker = require("gleb.picker")
local picker_layout = require("gleb.picker.layout")
local MiniPick = require("mini.pick")

---@class gleb.FindActionState
---@field context? gleb.ActionContext
---@field show_hidden? boolean
---@field rows? gleb.FindActionRow[]

---@class gleb.FindActionRow: gleb.picker.Row
---@field action? gleb.Action
---@field hidden? boolean

local M = {
	---@type gleb.FindActionState
	state = {},
}

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

---@param _ string[]
---@param inds integer[]
---@param query string[]
---@return integer[]
local function match_rows(_, inds, query)
	local rows = assert(M.state.rows, "Find Action rows are missing")
	local text = table.concat(query)
	if text == "" then
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
	return visible_matches
end

---@return boolean
local function show_hidden()
	M.state.show_hidden = true
	M.state.rows = make_rows()
	MiniPick.set_picker_items(M.state.rows)
	return false
end

---@return boolean
local function request_assignment()
	local current = MiniPick.get_picker_matches().current
	if current and current.hidden then
		return false
	end
	if not current or not current.action then
		return false
	end
	local selected = MiniPick.get_picker_matches().current_ind
	Assign.open(current.action)
	M.state.rows = make_rows()
	MiniPick.set_picker_items(M.state.rows)
	if selected then
		MiniPick.set_picker_match_inds({ selected }, "current")
	end
	return false
end

---@param row gleb.FindActionRow
---@return boolean
local function choose_action(row)
	local action = row.action
	if row.section then
		local current_ind = MiniPick.get_picker_matches().current_ind
		local rows = assert(M.state.rows, "Find Action rows are missing")
		action = current_ind and rows[current_ind + 1] and rows[current_ind + 1].action
	end
	if not action then
		return true
	end
	local ctx = assert(M.state.context, "Find Action context is missing")
	Items.history():record(action.id)
	if action.toggle then
		local selected = MiniPick.get_picker_matches().current_ind
		local rows = assert(M.state.rows, "Find Action rows are missing")
		vim.api.nvim_win_call(ctx.win, function()
			local value = not Context.get_toggle(action, ctx)
			Context.set_toggle(action, ctx, value)
		end)
		if selected then
			rows[selected].glyph = Context.get_toggle(action, ctx)
		end
		MiniPick.set_picker_items(rows)
		if selected then
			MiniPick.set_picker_match_inds({ selected }, "current")
		end
		return true
	end

	vim.schedule(function()
		Context.run(action, ctx)
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
	M.state.context = ctx or Context.capture()
	M.state.show_hidden = false
	M.state.rows = make_rows()
	return picker.start({
		title = "Find Action",
		items = M.state.rows,
		hints = hints,
		window_config = window_config,
		match = match_rows,
		choose = choose_action,
		mappings = {
			show_hidden = { char = "<M-A>", func = show_hidden },
			assign_shortcut = { char = "<M-}>", func = request_assignment },
		},
	})
end

---@return nil
function M.reset()
	M.state = {}
end

return M
