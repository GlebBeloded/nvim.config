local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[
		vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
		local Context = require("gleb.actions.context")
		local RealCatalog = require("gleb.actions").state.applicator.catalog
		RealCatalogForLabels = RealCatalog
		RealShortcutsForLabels = vim.deepcopy(require("gleb.actions").state.store.last_good)
		RealActions = RealCatalog:filter("n", vim.bo.filetype, Context.capture())
		local Registry = require("gleb.actions.registry")
		local catalog = Registry.new({ {
			{
				id = "test.regular",
				title = "Regular Action",
				category = "Test",
				run = function(ctx)
					RegularRun = {
						win = vim.api.nvim_get_current_win(),
						buf = vim.api.nvim_get_current_buf(),
						cursor = vim.api.nvim_win_get_cursor(0),
						mode = vim.fn.mode(1),
						ctx = ctx,
					}
				end,
			},
			{
				id = "test.toggle_first",
				title = "Toggle First",
				category = "Test",
				modes = { "n" },
				run = function() end,
				toggle = {
					get = function() return ToggleFirst or false end,
					set = function(_, value) ToggleFirst = value end,
				},
			},
			{
				id = "test.toggle",
				title = "Toggle Wrap",
				category = "Test",
				modes = { "n" },
				run = function() end,
				toggle = {
					get = function(ctx) return vim.wo[ctx.win].wrap end,
					set = function(_, value)
						ToggleWin = vim.api.nvim_get_current_win()
						vim.wo.wrap = value
					end,
				},
			},
			{
				id = "test.visual",
				title = "Visual Action",
				category = "Test",
				modes = { "x" },
				run = function(ctx)
					VisualRun = {
						win = vim.api.nvim_get_current_win(),
						buf = vim.api.nvim_get_current_buf(),
						mode = vim.fn.mode(1),
						selection = ctx.selection,
						anchor = vim.fn.getpos("v")[2],
						cursor = vim.api.nvim_win_get_cursor(0)[1],
					}
				end,
			},
			{
				id = "lazy.close",
				title = "Close Lazy",
				category = "Lazy",
				ft = "lazy",
				run = function() LazyClose = (LazyClose or 0) + 1 end,
			},
			RealCatalog:get("find_action.open"),
		} })
		local actions = require("gleb.actions")
		actions.state.applicator.catalog = catalog
		actions.state.store.catalog = catalog
		actions.state.store.last_good = {
			["test.regular"] = { "gR" },
			["test.toggle_first"] = {},
			["test.toggle"] = {},
			["test.visual"] = { "gV" },
			["lazy.close"] = { "q" },
			["find_action.open"] = { "<M-A>" },
		}
		actions.state.applicator:apply(actions.state.store.last_good)
	]])
end

local T = H.child_set(child, start)

local function open_palette(keys)
	child.type_keys(keys or "<M-A>")
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action picker did not open")
	assert(child.wait("#MiniPick.get_picker_items() > 0", 5000), "Find Action items did not load")
end

T["find-action: Catalog rows use standalone Title Case labels"] = function()
	child.lua([[
		local actions = require("gleb.actions")
		actions.state.applicator.catalog = RealCatalogForLabels
		actions.state.store.catalog = RealCatalogForLabels
		actions.state.store.last_good = RealShortcutsForLabels
		actions.state.applicator:apply(RealShortcutsForLabels)
	]])
	open_palette()

	local approved = {
		["ai.search"] = { "AI Search", "AI" },
		["ai.vibe"] = { "AI Vibe", "AI" },
		["buffer.close"] = { "Close Buffer", "Buffer" },
		["changes.review"] = { "Review Changes", "View | Tool Windows" },
		["changes.toggle"] = { "Toggle Changes", "View | Tool Windows" },
		["comments.toggle"] = { "Toggle Comment", "Comments" },
		["diag.next"] = { "Next Diagnostic", "Diagnostics" },
		["diag.previous"] = { "Previous Diagnostic", "Diagnostics" },
		["fold.close_all"] = { "Collapse All Folds", "Fold" },
		["fold.close_one"] = { "Collapse Fold", "Fold" },
		["fold.open_all"] = { "Expand All Folds", "Fold" },
		["fold.open_one"] = { "Expand Fold", "Fold" },
		["file_tree.toggle"] = { "Toggle Project Tree", "Project" },
		["file_tree.reveal"] = { "Reveal in Project Tree", "Project" },
		["jump.back"] = { "Navigate Back", "Jump" },
		["jump.forward"] = { "Navigate Forward", "Jump" },
		["lsp.code_action"] = { "Show Code Actions...", "LSP" },
		["lsp.go_to_declaration"] = { "Go to Declaration", "LSP" },
		["lsp.go_to_definition"] = { "Go to Definition", "LSP" },
		["lsp.go_to_implementation"] = { "Go to Implementation", "LSP" },
		["lsp.hover"] = { "Show Hover Info", "LSP" },
		["lsp.references"] = { "Find References", "LSP" },
		["lsp.rename"] = { "Rename Symbol...", "LSP" },
		["search.live_grep"] = { "Find in Files...", "Edit | Find" },
		["surround.add"] = { "Add Surrounding", "Surround" },
		["surround.add_line"] = { "Add Surrounding on Current Line", "Surround" },
		["surround.add_on_lines"] = { "Add Surrounding on Lines", "Surround" },
		["surround.add_current_on_lines"] = { "Add Surrounding on Current Lines", "Surround" },
		["surround.change"] = { "Change Surrounding...", "Surround" },
		["surround.change_on_lines"] = { "Change Surrounding on Lines...", "Surround" },
		["surround.delete"] = { "Delete Surrounding", "Surround" },
		["window.decrease_height"] = { "Decrease Window Height", "Window" },
		["window.decrease_width"] = { "Decrease Window Width", "Window" },
		["window.increase_height"] = { "Increase Window Height", "Window" },
		["window.increase_width"] = { "Increase Window Width", "Window" },
		["window.move_down"] = { "Focus Down Window", "Window" },
		["window.move_left"] = { "Focus Left Window", "Window" },
		["window.move_right"] = { "Focus Right Window", "Window" },
		["window.move_up"] = { "Focus Up Window", "Window" },
		["window.resize_down"] = { "Resize Window Down", "Window" },
		["window.resize_left"] = { "Resize Window Left", "Window" },
		["window.resize_right"] = { "Resize Window Right", "Window" },
		["window.resize_up"] = { "Resize Window Up", "Window" },
	}
	local actual = child.lua_get([[(function()
		local rows = {}
		for _, row in ipairs(MiniPick.get_picker_items()) do
			if row.action then rows[row.action.id] = { row.text, row.category } end
		end
		return rows
	end)()]])
	for id, metadata in pairs(approved) do
		eq(actual[id], metadata)
	end

	child.type_keys("<M-A>")
	assert(
		child.wait(
			[[vim.tbl_contains(vim.tbl_map(function(row) return row.text end, MiniPick.get_picker_items()), "More results")]],
			5000
		),
		"More results did not load"
	)
	local more_results = {
		["alpha.find_file"] = { "Find File", "Dashboard" },
		["alpha.new_file"] = { "Create New File", "Dashboard" },
		["alpha.recent_files"] = { "Find Recent Files", "Dashboard" },
		["alpha.find_text"] = { "Find Text", "Dashboard" },
		["alpha.configuration"] = { "Configuration", "Dashboard" },
		["alpha.quit"] = { "Quit Neovim", "Dashboard" },
		["alpha.press"] = { "Press Dashboard Button", "Dashboard" },
		["alpha.queue_press"] = { "Queue Dashboard Button Press", "Dashboard" },
		["blink.show"] = { "Show Completion Menu", "Completion" },
		["blink.select_next_or_accept_copilot"] = {
			"Select Next Completion Item or Accept Copilot Suggestion",
			"Completion",
		},
		["blink.select_prev"] = { "Select Previous Completion Item", "Completion" },
		["blink.select_next"] = { "Select Next Completion Item", "Completion" },
		["blink.accept"] = { "Accept Completion", "Completion" },
		["blink.cancel"] = { "Cancel Completion", "Completion" },
		["blink.scroll_documentation_up"] = { "Scroll Completion Documentation Up", "Completion" },
		["blink.scroll_documentation_down"] = { "Scroll Completion Documentation Down", "Completion" },
		["blink.cmdline_show_next"] = { "Show or Select Next Command-Line Completion Item", "Completion" },
		["blink.cmdline_show_prev"] = { "Show or Select Previous Command-Line Completion Item", "Completion" },
		["blink.cmdline_select_next"] = { "Select Next Command-Line Completion Item", "Completion" },
		["blink.cmdline_select_prev"] = { "Select Previous Command-Line Completion Item", "Completion" },
		["blink.cmdline_accept"] = { "Accept Command-Line Completion", "Completion" },
		["blink.cmdline_cancel"] = { "Cancel Command-Line Completion", "Completion" },
		["copilot.next"] = { "Next Copilot Suggestion", "Copilot" },
		["copilot.prev"] = { "Previous Copilot Suggestion", "Copilot" },
		["copilot.dismiss"] = { "Dismiss Copilot Suggestion", "Copilot" },
		["dap_ui.open"] = { "Open Debug Element", "Debug" },
		["dap_ui.remove"] = { "Remove Debug Element", "Debug" },
		["dap_ui.expand"] = { "Expand Debug Element", "Debug" },
		["dap_ui.repl"] = { "Send Debug Element to REPL", "Debug" },
		["dap_ui.toggle"] = { "Toggle Debug Element", "Debug" },
		["dap_float.close"] = { "Close Debug Floating Window", "Debug" },
		["diff.apply"] = { "Revert Change", "Git | Diff" },
		["diff.close"] = { "Close Diff", "Git | Diff" },
		["diff.expand_fold"] = { "Expand Fold", "Git | Diff" },
		["diff.jump_move"] = { "Jump to Other End of Move", "Git | Diff" },
		["diff.next_change"] = { "Next Change", "Git | Diff" },
		["diff.next_file"] = { "Next File", "Git | Diff" },
		["diff.prev_change"] = { "Previous Change", "Git | Diff" },
		["diff.toggle_folds"] = { "Toggle Folds", "Git | Diff" },
		["diff.toggle_include"] = { "Toggle Change Staging", "Git | Diff" },
		["git.confirm_commit_popup"] = { "Confirm Commit Message", "Git" },
		["git.discard_commit_popup"] = { "Discard Commit Message", "Git" },
		["diffview.select_next_entry"] = { "Select Next Diffview Entry", "Git | Diff" },
		["diffview.select_prev_entry"] = { "Select Previous Diffview Entry", "Git | Diff" },
		["diffview.goto_file_edit"] = { "Open Diffview File for Editing", "Git | Diff" },
		["diffview.choose_ours"] = { "Choose Conflict Ours", "Git | Diff" },
		["diffview.choose_theirs"] = { "Choose Conflict Theirs", "Git | Diff" },
		["diffview.choose_base"] = { "Choose Conflict Base", "Git | Diff" },
		["diffview.choose_all"] = { "Choose Conflict All", "Git | Diff" },
		["diffview.choose_none"] = { "Drop All Diffview Conflict Sides", "Git | Diff" },
		["diffview.select_entry"] = { "Select Diffview Entry", "Git | Diff" },
		["diffview.close_fold"] = { "Close Diffview Fold", "Git | Diff" },
		["diffview.toggle_stage_entry"] = { "Toggle Diffview Entry Staging", "Git | Diff" },
		["diffview.stage_all"] = { "Stage All Diffview Files", "Git | Diff" },
		["diffview.unstage_all"] = { "Unstage All Diffview Files", "Git | Diff" },
		["diffview.refresh_files"] = { "Refresh Diffview Files", "Git | Diff" },
		["diffview.close"] = { "Close Diffview", "Git | Diff" },
		["mason.install_package"] = { "Install Package", "Mason" },
		["neotest.run"] = { "Run Nearest Test", "Test" },
	}
	actual = child.lua_get([[(function()
		local rows = {}
		for _, row in ipairs(MiniPick.get_picker_items()) do
			if row.action and row.hidden and row.action.plugin then rows[row.action.id] = { row.text, row.category } end
		end
		return rows
	end)()]])
	eq(actual, more_results)
end

T["find-action: Empty query puts recent actions first"] = function()
	child.lua([[vim.fn.delete(require("gleb.find_action.items").history().path)]])
	child.type_keys("gR")
	assert(child.wait("RegularRun ~= nil", 5000), "Configured shortcut did not run")

	open_palette()
	child.type_keys("toggle first<CR>")
	assert(child.wait("ToggleFirst == true", 5000), "Palette action did not run")
	child.type_keys("<Esc>")
	open_palette()

	eq(
		child.lua_get([[
			vim.tbl_map(function(row)
				return row.action and row.action.id or row.text
			end, MiniPick.get_picker_items())
		]]),
		{
			"recently used",
			"find_action.open",
			"test.toggle_first",
			"test.regular",
			"other actions",
			"test.toggle",
		}
	)
end

T["find-action: Shortcut and palette use update recent actions"] = function()
	child.lua([[vim.fn.delete(require("gleb.find_action.items").history().path)]])
	child.type_keys("gR")
	assert(child.wait("RegularRun ~= nil", 5000), "Configured shortcut did not run")

	open_palette()
	child.type_keys("toggle first<CR>")
	assert(child.wait("ToggleFirst == true", 5000), "Palette action did not run")
	child.type_keys("<Esc>")
	child.cmd("setfiletype lazy")
	child.type_keys("q")
	assert(child.wait("LazyClose == 1", 5000), "lazy.nvim action did not run")
	child.lua([[vim.bo.filetype = ""]])
	eq(child.lua_get([[require("gleb.find_action.items").history():load()]]), {
		"lazy.close",
		"test.toggle_first",
		"find_action.open",
		"test.regular",
	})

	open_palette()
	eq(
		child.lua_get([[
			vim.tbl_map(function(row)
				return row.action and row.action.id or row.text
			end, MiniPick.get_picker_items())
		]]),
		{
			"recently used",
			"find_action.open",
			"test.toggle_first",
			"test.regular",
			"other actions",
			"test.toggle",
		}
	)
end

T["find-action: Only executed shortcuts update recent actions"] = function()
	child.lua([[
		local Registry = require("gleb.actions.registry")
		local mapping_action = {
			id = "test.mapping",
			title = "Mapping Action",
			category = "Test",
			run = function() MappingRuns = (MappingRuns or 0) + 1 end,
			mapping = function() MappingRuns = (MappingRuns or 0) + 1 end,
		}
		local plug = "<Plug>(TestRecentPlug)"
		local plug_action = {
			id = "test.plug",
			title = "Plug Action",
			category = "Test",
			run = function() vim.api.nvim_feedkeys(vim.keycode(plug), "m", false) end,
			plug = plug,
		}
		vim.keymap.set("n", plug, function() PlugRuns = (PlugRuns or 0) + 1 end)
		local actions = require("gleb.actions")
		local catalog = Registry.new({ {
			mapping_action,
			plug_action,
			actions.state.applicator.catalog:get("find_action.open"),
		} })
		actions.state.applicator.catalog = catalog
		actions.state.store.catalog = catalog
		actions.state.store.last_good = {
			["test.mapping"] = { "<F20>", "<C-h>" },
			["test.plug"] = { "<F21>" },
			["find_action.open"] = { "<M-A>" },
		}
		actions.state.applicator:apply(actions.state.store.last_good)
		vim.fn.delete(require("gleb.find_action.items").history().path)
	]])

	child.type_keys("<F20>")
	assert(child.wait("MappingRuns == 1", 5000), "Configured mapping shortcut did not run")
	child.type_keys("<F21>")
	assert(child.wait("PlugRuns == 1", 5000), "Configured plug shortcut did not run")
	child.type_keys("d<C-h>")
	child.type_keys("f<C-h>")
	eq(child.lua_get([[MappingRuns]]), 1)

	open_palette()
	child.type_keys("<C-h>")
	eq(child.lua_get([[MappingRuns]]), 1)
	eq(child.lua_get([[require("gleb.find_action.items").history():load()]]), {
		"find_action.open",
		"test.plug",
		"test.mapping",
	})
end

T["find-action: Regular action runs like its shortcut"] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
	child.api.nvim_win_set_cursor(0, { 2, 1 })
	child.type_keys("gR")
	local shortcut_run = child.lua_get([[RegularRun]])

	child.lua([[RegularRun = nil]])
	open_palette()
	child.type_keys("regular")
	child.type_keys("<CR>")
	assert(child.wait("RegularRun ~= nil", 5000), "Regular action did not run")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), false)
	eq(child.lua_get([[RegularRun]]), shortcut_run)

	child.lua([[
		local Actions = require("gleb.actions")
		RegisteredOpen = require("gleb.find_action").open
		RegisteredRuns = {}
		RegisteredActions = RealActions
		local shortcuts = {}
		for index, action in ipairs(RegisteredActions) do
			local lhs = ("gz%d;"):format(index)
			shortcuts[action.id] = { lhs }
			if not action.toggle then
				local id = action.id
				local function record()
					table.insert(RegisteredRuns, id)
				end
				action.run = record
				action.mapping = record
			end
		end
		Actions.setup({ RegisteredActions }, vim.fn.tempname())
		Actions.state.store:save(shortcuts)
		Actions.state.applicator:apply(Actions.state.store.last_good)
	]])
	child.lua([[vim.schedule(RegisteredOpen)]])
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Registered-action palette did not open")
	eq(
		child.lua_get([[
			vim.iter(MiniPick.get_picker_items()):filter(function(row)
				return row.action ~= nil
			end):map(function(row)
				return { row.action.id, row.text, row.category, row.secondary, row.glyph }
			end):totable()
		]]),
		child.lua_get([[
			vim.tbl_map(function(action)
				local lhs = require("gleb.actions").state.store.last_good[action.id][1]
				return {
					action.id,
					action.title,
					action.category,
					require("gleb.find_action.rows").physical_label(lhs),
					require("gleb.actions.context").get_toggle(action, require("gleb.find_action").state.context),
				}
			end, RegisteredActions)
		]])
	)
	child.type_keys("<Esc>")

	local actions = child.lua_get([[
		vim.tbl_map(function(action)
			return { id = action.id, title = action.title, lhs = require("gleb.actions").state.store.last_good[action.id][1], toggle = action.toggle ~= nil }
		end, RegisteredActions)
	]])
	local run_count = 0
	for _, action in ipairs(actions) do
		local initial_toggle
		local shortcut_toggle
		if action.toggle then
			initial_toggle = child.lua_get(([[
				require("gleb.actions.context").get_toggle(
					require("gleb.actions").state.applicator.catalog:get(%q),
					require("gleb.actions.context").capture()
				)
			]]):format(action.id))
		else
			child.type_keys(action.lhs)
			run_count = run_count + 1
			assert(child.wait(("#RegisteredRuns == %d"):format(run_count), 5000), action.id .. " shortcut did not run")
			eq(child.lua_get([=[RegisteredRuns[#RegisteredRuns]]=]), action.id)
		end
		if action.toggle then
			child.type_keys(action.lhs)
			shortcut_toggle = child.lua_get(([[
				require("gleb.actions.context").get_toggle(
					require("gleb.actions").state.applicator.catalog:get(%q),
					require("gleb.actions.context").capture()
				)
			]]):format(action.id))
			child.lua(
				([[
				local action = require("gleb.actions").state.applicator.catalog:get(%q)
				require("gleb.actions.context").set_toggle(action, require("gleb.actions.context").capture(), ...)
			]]):format(action.id),
				{ initial_toggle }
			)
		end

		child.lua([[vim.schedule(RegisteredOpen)]])
		assert(child.wait("MiniPick.is_picker_active()", 5000), action.id .. " palette did not open")
		child.type_keys(action.title:gsub("%.+$", ""):lower())
		assert(
			child.wait(([[MiniPick.get_picker_matches().current.action.id == %q]]):format(action.id), 5000),
			action.id .. " did not match"
		)
		child.type_keys("<CR>")
		if action.toggle then
			eq(
				child.lua_get(([[
					require("gleb.actions.context").get_toggle(
						require("gleb.actions").state.applicator.catalog:get(%q),
						require("gleb.find_action").state.context
					)
				]]):format(action.id)),
				shortcut_toggle
			)
			child.type_keys("<Esc>")
		else
			run_count = run_count + 1
			assert(
				child.wait(("#RegisteredRuns == %d"):format(run_count), 5000),
				action.id .. " palette action did not run"
			)
			eq(child.lua_get([=[RegisteredRuns[#RegisteredRuns]]=]), action.id)
		end
	end
end

T["find-action: Toggle changes without closing the palette"] = function()
	child.lua([[
		local actions = require("gleb.actions")
		actions.state.applicator.catalog = RealCatalogForLabels
		actions.state.store.catalog = RealCatalogForLabels
		actions.state.store.last_good = vim.deepcopy(RealShortcutsForLabels)
		actions.state.applicator:apply(actions.state.store.last_good)

		vim.cmd.vsplit()
		OtherEditorWin = vim.api.nvim_get_current_win()
		vim.wo[OtherEditorWin].wrap = false
		vim.wo[OtherEditorWin].spell = true
		vim.cmd.wincmd("p")
		EditorWin = vim.api.nvim_get_current_win()
		vim.wo[EditorWin].wrap = true
		vim.wo[EditorWin].spell = false
	]])

	local cases = {
		{ query = "soft wrap", id = "view.soft_wrap", option = "wrap", before = true, after = false },
		{ query = "spell check", id = "view.spell_check", option = "spell", before = false, after = true },
	}
	for _, case in ipairs(cases) do
		open_palette()
		child.type_keys(case.query)
		assert(
			child.wait(
				([[(MiniPick.get_picker_matches().current or {}).action
					and MiniPick.get_picker_matches().current.action.id == %q]]):format(case.id),
				5000
			),
			case.id .. " did not match"
		)
		local selected = child.lua_get([[MiniPick.get_picker_matches().current_ind]])
		eq(child.lua_get(([[vim.wo[EditorWin].%s]]):format(case.option)), case.before)
		eq(child.lua_get(([[vim.wo[OtherEditorWin].%s]]):format(case.option)), case.after)

		child.type_keys("<CR>")
		assert(
			child.wait(([[vim.wo[EditorWin].%s == %s]]):format(case.option, tostring(case.after)), 5000),
			case.id .. " did not toggle"
		)

		eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
		eq(child.lua_get(([[vim.wo[OtherEditorWin].%s]]):format(case.option)), case.after)
		eq(child.lua_get([[MiniPick.get_picker_matches().current_ind]]), selected)
		eq(child.lua_get([[MiniPick.get_picker_matches().current.glyph]]), case.after)
		child.type_keys("<Esc>")
	end
end

T["find-action: Visual palette preserves the selection"] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	local editor_win = child.api.nvim_get_current_win()
	local editor_buf = child.api.nvim_get_current_buf()
	open_palette("Vj<M-A>")

	eq(
		child.lua_get([[
		vim.tbl_map(function(item) return item.text end, MiniPick.get_picker_items())
		]]),
		{ "recently used", "Find Action...", "other actions", "Visual Action" }
	)
	child.type_keys("visual")
	child.type_keys("<CR>")
	assert(child.wait("VisualRun ~= nil", 5000), "Visual action did not run")

	eq(child.lua_get([[VisualRun]]), {
		win = editor_win,
		buf = editor_buf,
		mode = "V",
		selection = { start = { 2, 0 }, finish = { 3, 0 } },
		anchor = 2,
		cursor = 3,
	})
end

return T
