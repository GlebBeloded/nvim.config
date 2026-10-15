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
				id = "neo_tree.open",
				title = "Open",
				category = "Tree",
				plugin = "neo-tree",
				neo_tree_scope = "common",
				run = function() NeoTreeOpen = (NeoTreeOpen or 0) + 1 end,
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
			["neo_tree.open"] = { "<CR>" },
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
	child.lua([[
		local actions = require("gleb.actions")
		local mappings = require("gleb.actions.adapters.neo_tree").mappings(
			actions.state.applicator.catalog,
			actions.state.store.last_good,
			"common"
		)
		vim.keymap.set("n", "<CR>", mappings["<CR>"], { buffer = true })
	]])
	child.type_keys("<CR>")
	assert(child.wait("NeoTreeOpen == 1", 5000), "Neo-tree action did not run")
	eq(child.lua_get([[require("gleb.find_action.items").history():load()]]), {
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
			local lhs = ("<F%d>"):format(index + 20)
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
				local action = require("gleb.actions").state.applicator.catalog:get(%q)
				return require("gleb.actions.context").get_toggle(action, require("gleb.actions.context").capture())
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
				local action = require("gleb.actions").state.applicator.catalog:get(%q)
				return require("gleb.actions.context").get_toggle(action, require("gleb.actions.context").capture())
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
					local action = require("gleb.actions").state.applicator.catalog:get(%q)
					return require("gleb.actions.context").get_toggle(action, require("gleb.find_action").state.context)
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
	child.wo.wrap = false
	local editor_win = child.api.nvim_get_current_win()
	open_palette()
	child.type_keys("toggle")
	child.type_keys("<Down>")
	local selected = child.lua_get([[MiniPick.get_picker_matches().current_ind]])
	eq(child.lua_get([[MiniPick.get_picker_matches().current.action.id]]), "test.toggle")
	child.type_keys("<CR>")
	assert(child.wait("ToggleWin ~= nil", 5000), "Toggle action did not run")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
	eq(child.lua_get([[vim.wo[]] .. editor_win .. [[].wrap]]), true)
	eq(child.lua_get([[ToggleWin]]), editor_win)
	eq(child.lua_get([[MiniPick.get_picker_matches().current_ind]]), selected)
	eq(child.lua_get([[MiniPick.get_picker_matches().current.glyph]]), true)

	child.type_keys("<Esc>")
	child.wo.wrap = false
	open_palette()
	child.type_keys("<C-n>")
	local section = child.lua_get([[MiniPick.get_picker_matches().current_ind]])
	child.type_keys("<CR>")
	assert(child.wait("vim.wo[require('gleb.find_action').state.context.win].wrap", 5000), "Section toggle did not run")

	eq(child.lua_get([[MiniPick.get_picker_matches().current_ind]]), section)
	eq(child.lua_get([[MiniPick.get_picker_items()[3].text]]), "Toggle Wrap")
	eq(child.lua_get([[MiniPick.get_picker_items()[3].glyph]]), true)
	eq(child.lua_get([[MiniPick.get_picker_items()[1].glyph]]), vim.NIL)
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
