-- Shortcut assignment owns its modal key loop so the Find Action picker stays open behind it.

local Capture = require("gleb.actions.capture")
local Rows = require("gleb.find_action.rows")
local MiniPick = require("mini.pick")

local KEY_BOX_WIDTH = 48
local HIGHLIGHT_NAMESPACE = vim.api.nvim_create_namespace("gleb_find_action_assign")

local ADAPTER_PLUGINS = {
	blink = "blink",
	codediff = "codediff",
	copilot = "copilot",
	dap_ui = "dap-ui",
	differ = "differ",
	lazy = "lazy",
	mason = "mason",
	neo_tree = "neo-tree",
	neotest = "neotest",
}

---@class gleb.FindActionAssignWindow
---@field buf integer
---@field win integer
---@field palette_win integer

local M = {}

---@param action gleb.Action
---@return string?
local function adapter_plugin(action)
	return ADAPTER_PLUGINS[action.id:match("^([^.]+)%.")]
end

---@param title string
---@return gleb.FindActionAssignWindow
local function open_window(title)
	local palette_win = MiniPick.get_picker_state().windows.main
	local zindex = vim.api.nvim_win_get_config(palette_win).zindex + 1
	local width = math.min(56, math.max(vim.o.columns - 4, 20))
	local height = 9
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(math.floor((vim.o.lines - height) / 2), 0),
		col = math.max(math.floor((vim.o.columns - width) / 2), 0),
		width = width,
		height = height,
		border = "rounded",
		style = "minimal",
		title = " Assign Shortcut · " .. title .. " ",
		title_pos = "center",
		footer = " Tab next   ↩ choose ",
		footer_pos = "right",
		zindex = zindex,
	})
	vim.wo[win].winhighlight =
		"Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle,FloatFooter:FloatFooter"
	return { buf = buf, win = win, palette_win = palette_win }
end

---@param window gleb.FindActionAssignWindow
---@param lines string[]
---@param highlights? table[]
local function draw(window, lines, highlights)
	if not vim.api.nvim_buf_is_valid(window.buf) then
		return
	end
	vim.bo[window.buf].modifiable = true
	vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(window.buf, HIGHLIGHT_NAMESPACE, 0, -1)
	for _, highlight in ipairs(highlights or {}) do
		local end_col = highlight.end_col == -1 and #lines[highlight.line + 1] or highlight.end_col
		vim.api.nvim_buf_set_extmark(
			window.buf,
			HIGHLIGHT_NAMESPACE,
			highlight.line,
			highlight.col,
			{ end_col = end_col, hl_group = highlight.group }
		)
	end
	vim.bo[window.buf].modifiable = false
	vim.cmd.redraw()
end

---@param lhs string
---@return string[], table[]
local function key_box(lhs)
	local label = Rows.physical_label(lhs) .. " █"
	local padding = math.max(KEY_BOX_WIDTH - vim.fn.strdisplaywidth(label) - 2, 0)
	local lines = {
		"  ╭" .. string.rep("─", KEY_BOX_WIDTH) .. "╮",
		"  │ " .. label .. string.rep(" ", padding) .. " │",
		"  ╰" .. string.rep("─", KEY_BOX_WIDTH) .. "╯",
	}
	return lines,
		{
			{ line = 0, col = 2, end_col = -1, group = "FloatBorder" },
			{ line = 1, col = 2, end_col = 5, group = "FloatBorder" },
			{ line = 1, col = 6, end_col = 6 + #Rows.physical_label(lhs), group = "Search" },
			{ line = 1, col = #lines[2] - 3, end_col = -1, group = "FloatBorder" },
			{ line = 2, col = 2, end_col = -1, group = "FloatBorder" },
		}
end

---@param highlights table[]
local function offset_key_box(highlights)
	for _, highlight in ipairs(highlights) do
		highlight.line = highlight.line + 2
	end
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
local function draw_capture(window, lhs)
	local box, highlights = key_box(lhs)
	offset_key_box(highlights)
	local lines = {
		" Press keys, Enter to save, Esc to cancel",
		"",
		box[1],
		box[2],
		box[3],
		"",
		" No conflicts",
		"",
		" [ Save ]  [ Cancel ]",
	}
	draw(
		window,
		lines,
		vim.list_extend(highlights, {
			{ line = 6, col = 1, end_col = -1, group = "DiffAdd" },
			{ line = 8, col = 1, end_col = 9, group = "PmenuSel" },
			{ line = 8, col = 11, end_col = -1, group = "TabLine" },
		})
	)
	vim.api.nvim_win_set_config(window.win, { height = #lines })
end

---@param catalog gleb.ActionCatalog
---@param conflict gleb.ShortcutConflict
---@return string
local function conflict_text(catalog, conflict)
	local action = assert(catalog:get(conflict.action_id))
	local padding = math.max(54 - vim.fn.strdisplaywidth(action.title) - vim.fn.strdisplaywidth(action.category), 1)
	return " " .. action.title .. string.rep(" ", padding) .. action.category
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
---@param catalog gleb.ActionCatalog
---@param conflicts gleb.ShortcutConflict[]
---@param selected integer
local function draw_conflict(window, lhs, catalog, conflicts, selected)
	local labels = { "Remove other", "Keep both", "Cancel" }
	local buttons = {}
	local button_cols = {}
	local next_col = 1
	for _, label in ipairs(labels) do
		local button = "[ " .. label .. " ]"
		table.insert(buttons, button)
		table.insert(button_cols, next_col)
		next_col = next_col + #button + 2
	end
	local box, highlights = key_box(lhs)
	offset_key_box(highlights)
	local button_line = " " .. table.concat(buttons, "  ")
	local button_col = button_cols[selected]
	local lines = {
		" Press keys, Enter to save, Esc to cancel",
		"",
		box[1],
		box[2],
		box[3],
		"",
		" Already assigned to:",
	}
	for _, conflict in ipairs(conflicts) do
		table.insert(lines, conflict_text(catalog, conflict))
		table.insert(highlights, { line = #lines - 1, col = 1, end_col = -1, group = "NormalFloat" })
	end
	table.insert(lines, "")
	table.insert(lines, button_line)
	local button_row = #lines - 1
	table.insert(lines, "")
	vim.list_extend(highlights, {
		{ line = 6, col = 1, end_col = -1, group = "PmenuExtra" },
		{ line = button_row, col = 1, end_col = -1, group = "TabLine" },
		{ line = button_row, col = button_col, end_col = button_col + #buttons[selected], group = "PmenuSel" },
	})
	draw(window, lines, highlights)
	vim.api.nvim_win_set_config(window.win, { height = #lines })
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param action_id string
local function draw_capture_state(window, lhs, catalog, shortcuts, action_id)
	local conflicts = lhs == "" and {} or Capture.conflicts(catalog, shortcuts, action_id, lhs)
	if #conflicts > 0 then
		draw_conflict(window, lhs, catalog, conflicts, 1)
	else
		draw_capture(window, lhs)
	end
end

---@param window gleb.FindActionAssignWindow
local function close_window(window)
	if vim.api.nvim_win_is_valid(window.palette_win) then
		vim.api.nvim_set_current_win(window.palette_win)
	end
	if vim.api.nvim_win_is_valid(window.win) then
		vim.api.nvim_win_close(window.win, true)
	end
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
---@param catalog gleb.ActionCatalog
---@param conflicts gleb.ShortcutConflict[]
---@return "remove"|"keep"|"cancel"
local function choose_conflict(window, lhs, catalog, conflicts)
	local selected = 1
	while true do
		draw_conflict(window, lhs, catalog, conflicts, selected)
		local key = vim.fn.keytrans(vim.fn.getcharstr())
		if key == "r" or key == "R" then
			return "remove"
		elseif key == "k" or key == "K" then
			return "keep"
		elseif key == "c" or key == "C" or key == "<Esc>" then
			return "cancel"
		elseif key == "<Tab>" or key == "<Right>" then
			selected = selected % 3 + 1
		elseif key == "<Left>" then
			selected = (selected + 1) % 3 + 1
		elseif key == "<CR>" then
			return ({ "remove", "keep", "cancel" })[selected]
		end
	end
end

---@param shortcuts gleb.ShortcutMap
---@param catalog gleb.ActionCatalog
---@param conflicts gleb.ShortcutConflict[]
local function remove_conflicts(shortcuts, catalog, conflicts)
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		local removed = false
		local kept = vim.tbl_filter(function(lhs)
			for _, conflict in ipairs(conflicts) do
				if action and action.id == conflict.action_id and lhs == conflict.lhs then
					removed = true
					return false
				end
			end
			return true
		end, lhs_list)
		if removed then
			shortcuts[id] = #kept > 0 and kept or nil
		end
	end
end

---@param shortcuts gleb.ShortcutMap
---@param action_id string
---@param lhs string
local function add_shortcut(shortcuts, action_id, lhs)
	shortcuts[action_id] = shortcuts[action_id] or {}
	if not vim.tbl_contains(shortcuts[action_id], lhs) then
		table.insert(shortcuts[action_id], lhs)
	end
end

---@param action gleb.Action
---@return boolean
function M.open(action)
	local actions = require("gleb.actions")
	local store = assert(actions.state.store, "actions are not set up")
	local catalog = assert(actions.state.applicator, "actions are not set up").catalog
	local window = open_window(action.title)
	draw_capture_state(window, "", catalog, store.last_good, action.id)
	local lhs = Capture.capture(nil, function(value)
		draw_capture_state(window, value, catalog, store.last_good, action.id)
	end)
	if not lhs or lhs == "" then
		close_window(window)
		return false
	end

	local conflicts = Capture.conflicts(catalog, store.last_good, action.id, lhs)
	local choice = #conflicts == 0 and "keep" or choose_conflict(window, lhs, catalog, conflicts)
	if choice == "cancel" then
		close_window(window)
		return false
	end

	local shortcuts = vim.deepcopy(store.last_good)
	if choice == "remove" then
		remove_conflicts(shortcuts, catalog, conflicts)
	end
	add_shortcut(shortcuts, action.id, lhs)
	if store:save(shortcuts) then
		local plugin = adapter_plugin(action)
		if plugin then
			vim.notify("Shortcut saved; applies when " .. plugin .. " reopens", vim.log.levels.INFO)
		else
			actions.apply()
		end
	end
	close_window(window)
	return false
end

return M
