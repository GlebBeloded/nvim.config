-- Shortcut assignment owns its modal key loop so the Find Action picker stays open behind it.

local Capture = require("gleb.actions.capture")
local MiniPick = require("mini.pick")

local ADAPTER_PLUGINS = {
	blink = "blink",
	codediff = "codediff",
	copilot = "copilot",
	dap_ui = "dap-ui",
	differ = "differ",
	file_tree = "neo-tree",
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
	local width = math.min(56, math.max(vim.o.columns - 4, 20))
	local height = 7
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
	})
	vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
	return { buf = buf, win = win, palette_win = palette_win }
end

---@param window gleb.FindActionAssignWindow
---@param lines string[]
local function draw(window, lines)
	if not vim.api.nvim_buf_is_valid(window.buf) then
		return
	end
	vim.bo[window.buf].modifiable = true
	vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, lines)
	vim.bo[window.buf].modifiable = false
	vim.cmd.redraw()
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
local function draw_capture(window, lhs)
	draw(window, {
		" Press keys, Enter to save, Esc to cancel",
		"",
		"  " .. lhs .. " █",
		"",
		" No conflicts",
		"",
		" [ Save ]  [ Cancel ]",
	})
end

---@param catalog gleb.ActionCatalog
---@param conflicts gleb.ShortcutConflict[]
---@return string
local function conflict_text(catalog, conflicts)
	local titles = {}
	for _, conflict in ipairs(conflicts) do
		local action = assert(catalog:get(conflict.action_id))
		table.insert(titles, action.title)
	end
	return table.concat(titles, ", ")
end

---@param window gleb.FindActionAssignWindow
---@param lhs string
---@param catalog gleb.ActionCatalog
---@param conflicts gleb.ShortcutConflict[]
---@param selected integer
local function draw_conflict(window, lhs, catalog, conflicts, selected)
	local labels = { "Remove other", "Keep both", "Cancel" }
	local buttons = {}
	for index, label in ipairs(labels) do
		local marker = index == selected and ">" or " "
		table.insert(buttons, marker .. "[ " .. label .. " ]")
	end
	draw(window, {
		" Press keys, Enter to save, Esc to cancel",
		"",
		"  " .. lhs .. " █",
		"",
		" Already assigned to:",
		" " .. conflict_text(catalog, conflicts),
		"",
		table.concat(buttons, "  "),
	})
	vim.api.nvim_win_set_config(window.win, { height = 8 })
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
	draw_capture(window, "")
	local lhs = Capture.capture(nil, function(value)
		draw_capture(window, value)
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
