-- Reference screenshots of Find Action across its responsive and assignment states.
-- Update with `UPDATE_SCREENSHOTS=1 make test FILE=tests/screen/find-action/test_palette.lua` after an approved change.
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality

local function start()
	child.start_bare({ "gruvbox-material" })
	child.cmd("colorscheme gruvbox-material")
	child.lua([[
		ToggleState = { wrap = true, spell = false }
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
			action("git.open_differ", "Open Differ", "Git | Diff"),
			action("view.soft_wrap", "Soft Wrap", "View | Editor", {
				toggle = {
					get = function() return ToggleState.wrap end,
					set = function(_, value) ToggleState.wrap = value end,
				},
			}),
			action("view.spell_check", "Spell Check", "View | Editor", {
				toggle = {
					get = function() return ToggleState.spell end,
					set = function(_, value) ToggleState.spell = value end,
				},
			}),
			action("edit.find_files", "Find in Files...", "Edit | Find"),
			action("help.find_action", "Find Action...", "Help"),
			action("navigate.find_file", "Find File...", "Navigate"),
			action("edit.find_buffer", "Find in Buffer", "Edit | Find"),
			action("view.file_tree", "Toggle File Tree", "View | Tool Windows"),
			action("view.git_status", "Toggle Git Status Tree", "View | Tool Windows"),
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
			["git.open_differ"] = { "<M-g>" },
			["edit.find_files"] = { "<M-F>" },
			["help.find_action"] = { "<M-A>" },
			["navigate.find_file"] = { "<D-o>" },
			["edit.find_buffer"] = { "/" },
			["view.file_tree"] = { "<M-e>" },
			["view.git_status"] = { "<M-G>" },
		})
		Actions.state.applicator:apply(Actions.state.store.last_good)
		local history = require("gleb.find_action.items").history()
		vim.fn.mkdir(vim.fs.dirname(history.path), "p")
		vim.fn.writefile({ vim.json.encode({
			"git.open_differ",
			"view.soft_wrap",
			"view.spell_check",
			"edit.find_files",
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

local function open_palette(keys)
	child.type_keys(keys or "<M-A>")
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "Find Action palette did not open")
	assert(child.wait([[#require("mini.pick").get_picker_items() > 0]]), "Find Action rows did not load")
end

local function close_palette()
	child.type_keys("<Esc>")
	assert(child.wait([[not require("mini.pick").is_picker_active()]]), "Find Action palette did not close")
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
		"git.open_differ"
	)
	local text = screen_text()
	eq(text:find("recently used", 1, true) ~= nil, true)
	eq(text:find("Assign ⌥↩ · Show hidden ⌘⇧A", 1, true) ~= nil, true)
	eq(text:find("Toggle Git Status Tree ⌘⇧G", 1, true) ~= nil, true)
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("diff")
	assert(child.wait([[table.concat(require("mini.pick").get_picker_query()) == "diff"]]), "query was not rendered")
	H.expect_screenshot(child.get_screenshot())
	close_palette()

	open_palette()
	child.type_keys("spell<CR>")
	assert(child.wait([[ToggleState.spell]]), "toggle did not change")
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
end

T["find-action: Compact palette matches reference screenshot"] = function()
	set_size(60)
	open_palette()
	local text = screen_text()
	eq(text:find("recently used", 1, true) ~= nil, true)
	eq(text:find("⌥↩ · ⌘⇧A", 1, true) ~= nil, true)
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
	eq(text:find("Open Differ", 1, true) ~= nil, true)
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
