-- Reference screenshots of Find Action across its responsive and assignment states.
-- Update with `UPDATE_SCREENSHOTS=1 make test FILE=tests/screen/find-action/test_palette.lua` after an approved change.
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality

local function start()
	child.start_bare({ "gruvbox-material", "smart-splits.nvim" })
	child.cmd("colorscheme gruvbox-material")
	child.lua([[
		vim.wo.wrap = true
		vim.wo.spell = false
		local function registered(module, id)
			return assert(vim.iter(require(module)):find(function(item) return item.id == id end))
		end
		local function action(id, title, category, extra)
			return vim.tbl_extend("force", {
				id = id,
				title = title,
				category = category,
				modes = { "n", "x" },
				run = function() end,
			}, extra or {})
		end

		FixtureActions = {
			action("changes.review", "Review Changes", "View | Tool Windows", { modes = { "n" } }),
			registered("gleb.view.actions", "view.soft_wrap"),
			registered("gleb.view.actions", "view.spell_check"),
			registered("gleb.keymaps.actions", "search.live_grep"),
			registered("gleb.find_action.actions", "find_action.open"),
			action("navigate.find_file", "Find File...", "Navigate"),
			action("edit.find_buffer", "Find in Buffer", "Edit | Find"),
			action("file_tree.toggle", "Toggle File Tree", "View | Tool Windows", { modes = { "n" } }),
			action("changes.toggle", "Toggle Git Status Tree", "View | Tool Windows", { modes = { "n" } }),
			action("git.open_diffview", "Open Diffview", "Git | Diff"),
			action("git.blame_line", "Blame Line", "Git"),
			action("git.copy_permalink", "Copy Permalink", "Git"),
			action("test.unavailable", "Unavailable Action", "Test", { when = function() return false end }),
			action("test.hidden", "Hidden Action", "Test", { hidden = true }),
		}

		local Actions = require("gleb.actions")
		ShortcutPath = vim.fn.tempname()
		Actions.setup({ FixtureActions }, ShortcutPath)
		Actions.state.applicator.catalog.complete_commands = function() return { "SecretCommand" } end
		Actions.state.store:save({
			["changes.review"] = { "<M-g>" },
			["search.live_grep"] = { "<M-F>" },
			["find_action.open"] = { "<M-A>" },
			["navigate.find_file"] = { "<D-o>" },
			["edit.find_buffer"] = { "/" },
			["file_tree.toggle"] = { "<M-e>" },
			["changes.toggle"] = { "<M-G>" },
		})
		Actions.state.applicator:apply(Actions.state.store.last_good)
		local history = require("gleb.find_action.items").history()
		vim.fn.mkdir(vim.fs.dirname(history.path), "p")
		vim.fn.writefile({ vim.json.encode({
			"changes.review",
			"view.soft_wrap",
			"view.spell_check",
			"search.live_grep",
		}) }, history.path)

		vim.keymap.set("n", "<M-A>", require("gleb.find_action").open)
		vim.keymap.set("x", "<M-A>", require("gleb.find_action").open)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })
	]])
end

local T = H.child_set(child, start)

local function set_size(columns)
	child.o.lines = 30
	child.o.columns = columns
end

local function screen_text()
	return table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
end

local function wide_color_mask(content)
	return string.rep("n", 14) .. "b" .. content .. "b" .. string.rep("n", 14)
end

local function open_palette(keys)
	child.type_keys(keys or "<M-A>")
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "Find Action palette did not open")
	assert(child.wait([[#require("mini.pick").get_picker_items() > 0]]), "Find Action rows did not load")
end

local function close_palette()
	child.type_keys("<Esc>")
	assert(child.wait([[not require("mini.pick").is_picker_active()]]), "Find Action palette did not close")
end

local function selected_screen_row()
	return child.lua_get([[(function()
		local pick = require("mini.pick")
		local state = pick.get_picker_state()
		local cursor_row = vim.api.nvim_win_get_cursor(state.windows.main)[1]
		return vim.fn.screenpos(state.windows.main, cursor_row, 1).row
	end)()]])
end

local function selected_category_screen_rows()
	local selected_row = selected_screen_row()
	local screen = child.get_screenshot()
	local selected_category_attr = screen.attr[selected_row][72]
	local bounds = child.lua_get([[(function()
		local win = require("mini.pick").get_picker_state().windows.main
		local position = vim.api.nvim_win_get_position(win)
		return { position[1] + 1, position[2] + 1, vim.api.nvim_win_get_height(win), vim.api.nvim_win_get_width(win) }
	end)()]])
	local rows = {}
	for row = bounds[1], bounds[1] + bounds[3] - 1 do
		for col = bounds[2], bounds[2] + bounds[4] - 1 do
			if screen.attr[row][col] == selected_category_attr then
				table.insert(rows, row)
				break
			end
		end
	end
	return rows
end

local function expect_assignment_box(label)
	local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
	eq(lines[3]:find("╭", 1, true) ~= nil, true)
	eq(lines[4]:find(label, 1, true) ~= nil, true)
	eq(lines[5]:find("╰", 1, true) ~= nil, true)
end

T["find-action: Wide palette matches reference screenshots"] = function()
	set_size(100)
	open_palette()
	eq(
		child.lua_get([[(function()
			local current = require("mini.pick").get_picker_matches().current
			return current.action and current.action.id or vim.NIL
		end)()]]),
		"changes.review"
	)
	local text = screen_text()
	eq(text:find("recently used", 1, true) ~= nil, true)
	eq(text:find("Assign ⌥↩ · Show hidden ⌘⇧A", 1, true) ~= nil, true)
	eq(text:find("12/12", 1, true) ~= nil, true)
	eq(text:find("Remove", 1, true), nil)
	eq(text:find("Review Changes  ⌘G", 1, true) ~= nil, true)
	eq(text:find("Toggle Git Status Tree  ⌘⇧G", 1, true) ~= nil, true)
	H.expect_hl_colors(child, "FindActionBody", { fg = "#d9c8a5", bg = "#45403d" })
	H.expect_hl_colors(child, "FindActionSelected", { bg = "#59524d" })
	H.expect_hl_colors(child, "FindActionPrompt", { fg = "#da8f57", bg = "#45403d" })
	H.expect_hl_colors(child, "FindActionMetadata", { fg = "#a59a86" })
	H.expect_hl_colors(child, "FindActionSeparator", { fg = "#8f8475" })
	H.expect_hl_colors(child, "FindActionShortcut", { fg = "#8f8475" })
	H.expect_hl_colors(child, "FindActionRule", { fg = "#8f8475" })
	H.expect_hl_colors(child, "FindActionHint", { fg = "#a59a86", bg = "#32302f" })
	H.expect_hl_colors(child, "FindActionHintKey", { fg = "#d9c8a5", bg = "#32302f" })
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("diff")
	assert(child.wait([[table.concat(require("mini.pick").get_picker_query()) == "diff"]]), "query was not rendered")
	H.expect_screenshot(child.get_screenshot())
	close_palette()

	child.o.lines = 14
	open_palette()
	for _ = 1, 4 do
		child.type_keys("<C-n>")
	end
	eq(selected_category_screen_rows(), { selected_screen_row() })
	close_palette()
	child.o.lines = 30

	open_palette()
	child.type_keys("spell<CR>")
	assert(child.wait([[vim.wo[require("gleb.find_action").state.context.win].spell]]), "toggle did not change")
	H.expect_screenshot(child.get_screenshot())
	close_palette()

	open_palette()
	child.type_keys("secret<M-A>")
	assert(
		child.wait(
			[[vim.tbl_contains(vim.tbl_map(function(row) return row.text end, require("mini.pick").get_picker_items()), "More results")]]
		),
		"hidden tier did not open"
	)
	assert(
		child.wait(
			[[table.concat(vim.api.nvim_buf_get_lines(require("mini.pick").get_picker_state().buffers.main, 0, -1, false), "\n"):find("More results", 1, true) ~= nil]]
		),
		"hidden tier was not rendered"
	)
	H.expect_screenshot(child.get_screenshot())
	close_palette()

	child.type_keys("vjj<M-A>")
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "visual Find Action palette did not open")
	eq(child.lua_get([[require("gleb.find_action").state.context.selection ~= nil]]), true)
	H.expect_screenshot(child.get_screenshot())
	close_palette()

	child.lua(
		[[vim.fn.writefile({ vim.json.encode({ "changes.review", "view.soft_wrap", "view.spell_check", "search.live_grep" }) }, require("gleb.find_action.items").history().path)]]
	)
	open_palette()
	H.expect_screen_colors(child, 6, {
		wide_color_mask(string.rep("p", 15) .. "c" .. string.rep("b", 54)),
	}, { n = "EndOfBuffer", b = "FindActionBorder", p = "FindActionPrompt", c = "FindActionCaret" })
	H.expect_screen_colors(child, 7, {
		wide_color_mask("B" .. string.rep("a", 13) .. "B" .. string.rep("r", 54) .. "B"),
	}, {
		n = "EndOfBuffer",
		b = "FindActionBorder",
		B = "FindActionBody",
		a = "FindActionMetadata",
		r = "FindActionRule",
	})
	H.expect_screen_colors(child, 8, {
		wide_color_mask(
			string.rep("S", 17)
				.. string.rep("d", 2)
				.. string.rep("S", 31)
				.. string.rep("a", 4)
				.. string.rep("d", 3)
				.. string.rep("a", 12)
				.. "S"
		),
	}, {
		n = "EndOfBuffer",
		b = "FindActionBorder",
		S = "FindActionSelected",
		q = "FindActionShortcut",
		a = "FindActionMetadata",
		d = "FindActionSeparator",
	})
	H.expect_screen_colors(child, 11, {
		wide_color_mask(
			string.rep("B", 19)
				.. string.rep("q", 3)
				.. string.rep("B", 36)
				.. string.rep("a", 4)
				.. string.rep("d", 3)
				.. string.rep("a", 4)
				.. "B"
		),
	}, {
		n = "EndOfBuffer",
		b = "FindActionBorder",
		B = "FindActionBody",
		q = "FindActionShortcut",
		a = "FindActionMetadata",
		d = "FindActionSeparator",
	})
	H.expect_screen_colors(
		child,
		20,
		{ wide_color_mask(string.rep("B", 66) .. string.rep("a", 3) .. "B") },
		{ n = "EndOfBuffer", b = "FindActionBorder", B = "FindActionBody", a = "FindActionMetadata" }
	)
	H.expect_screen_colors(child, 21, {
		wide_color_mask(
			string.rep("H", 8) .. string.rep("K", 2) .. string.rep("H", 15) .. string.rep("K", 3) .. string.rep("H", 42)
		),
	}, { n = "EndOfBuffer", b = "FindActionBorder", H = "FindActionHint", K = "FindActionHintKey" })
	child.type_keys("diff")
	assert(child.wait([[table.concat(require("mini.pick").get_picker_query()) == "diff"]]), "query was not rendered")
	H.expect_screen_colors(child, 7, {
		wide_color_mask(
			string.rep("S", 17)
				.. "d"
				.. string.rep("S", 40)
				.. string.rep("a", 4)
				.. string.rep("d", 3)
				.. string.rep("a", 4)
				.. "S"
		),
	}, {
		n = "EndOfBuffer",
		b = "FindActionBorder",
		S = "FindActionSelected",
		q = "FindActionShortcut",
		a = "FindActionMetadata",
		d = "FindActionSeparator",
	})
	close_palette()

	child.o.lines = 14
	open_palette()
	for _ = 1, 4 do
		child.type_keys("<C-n>")
	end
	H.expect_screen_colors(child, selected_screen_row(), {
		wide_color_mask(string.rep("S", 17) .. string.rep("q", 3) .. string.rep("S", 45) .. string.rep("a", 4) .. "S"),
	}, {
		n = "EndOfBuffer",
		b = "FindActionBorder",
		S = "FindActionSelected",
		q = "FindActionShortcut",
		a = "FindActionMetadata",
	})
	close_palette()
end

T["find-action: Compact palette matches reference screenshot"] = function()
	set_size(60)
	open_palette()
	local text = screen_text()
	eq(text:find("recently used", 1, true) ~= nil, true)
	eq(text:find("⌥↩ · ⌘⇧A", 1, true) ~= nil, true)
	eq(text:find("12/12", 1, true) ~= nil, true)
	eq(text:find("Git | Diff", 1, true), nil)
	H.expect_screenshot(child.get_screenshot())
end

T["find-action: Narrow palette matches reference screenshot"] = function()
	set_size(40)
	open_palette()
	local text = screen_text()
	eq(text:find("recently used", 1, true) ~= nil, true)
	eq(text:find("⌘G", 1, true), nil)
	eq(text:find("Git | Diff", 1, true), nil)
	eq(text:find("⌥↩", 1, true), nil)
	eq(text:find("39/39", 1, true), nil)
	H.expect_screenshot(child.get_screenshot())
end

T["find-action: Conflict assignment matches reference screenshot"] = function()
	set_size(100)
	open_palette()
	child.type_keys("diffview")
	assert(
		child.wait([[require("mini.pick").get_picker_matches().current.action.id == "git.open_diffview"]]),
		"Open Diffview did not match"
	)
	child.type_keys("<M-}><M-g>")
	assert(
		child.wait([[vim.api.nvim_get_current_win() ~= require("mini.pick").get_picker_state().windows.main]]),
		"conflict float did not open"
	)
	assert(
		child.wait(
			[[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("Already assigned", 1, true) ~= nil]]
		),
		"conflict details were not drawn"
	)
	expect_assignment_box("⌘G █")
	local text = screen_text()
	eq(text:find("Review Changes", 1, true) ~= nil, true)
	eq(text:find("[ Remove other ]", 1, true) ~= nil, true)
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("<CR><Tab><Tab>")
	eq(
		child.lua_get([[
			(function()
				local namespace = vim.api.nvim_get_namespaces().gleb_find_action_assign
				local mark = vim.iter(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true }))
					:find(function(item) return item[4].hl_group == "PmenuSel" end)
				return { mark[2], mark[3], mark[4].end_col }
			end)()
		]]),
		{ 9, 34, 44 }
	)
	child.type_keys("<CR>")
	assert(
		child.wait([[vim.api.nvim_get_current_win() == require("mini.pick").get_picker_state().windows.main]]),
		"Cancel did not return to the palette"
	)
end

T["find-action: Free assignment matches reference screenshot"] = function()
	set_size(100)
	open_palette()
	child.type_keys("diffview")
	assert(
		child.wait([[require("mini.pick").get_picker_matches().current.action.id == "git.open_diffview"]]),
		"Open Diffview did not match"
	)
	child.type_keys("<M-}><M-D>")
	assert(
		child.wait([[vim.api.nvim_get_current_win() ~= require("mini.pick").get_picker_state().windows.main]]),
		"assignment float did not open"
	)
	assert(
		child.wait([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("⌘⇧D", 1, true) ~= nil]]),
		"free shortcut was not drawn"
	)
	expect_assignment_box("⌘⇧D █")
	eq(screen_text():find("No conflicts", 1, true) ~= nil, true)
	H.expect_screenshot(child.get_screenshot())
end

return T
