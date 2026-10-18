local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local default_settings =
	vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "settings", "file_tree.json")), "\n"))

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], {
		vim.fs.joinpath(H.root, "settings", "file_tree.json"),
	})
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

local T = H.child_set(child, start)

---@param name string
---@return string?
local function tree_line(name)
	return child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for _, line in ipairs(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)) do
				if line:find(name, 1, true) then
					return line
				end
			end
		end)(...)]],
		{ name }
	)
end

---@param name string
---@return boolean
local function has_tree_line(name)
	return child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			return vim.iter(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)):any(function(line)
				return line:find(name, 1, true) ~= nil
			end)
		end)(...)]],
		{ name }
	)
end

---@param name string
local function focus_tree_row(name)
	local found = child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			vim.api.nvim_set_current_win(view.win)
			for index, row in ipairs(view.rows) do
				if row.label == name then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
end

---@param relative string
local function focus_tree_path(relative)
	local found = child.lua_get(
		[[(function(root, relative)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local path = vim.fs.joinpath(require("gleb.file_tree.fs").normalize(root), relative)
			vim.api.nvim_set_current_win(view.win)
			for index, row in ipairs(view.rows) do
				if row.path == path then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ root, relative }
	)
	assert(found, "tree path not found: " .. relative)
end

---@param name string
local function rename(name)
	child.type_keys("r")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Rename picker did not open")
	child.type_keys("<C-u>", name, "<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Rename picker did not close")
end

---@param id string
local function run_action(id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

---@param relative string
local function expect_selected(relative)
	local selected = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local cursor = vim.api.nvim_win_get_cursor(view.win)
		return view.rows[cursor[1]].path
	end)()]=])
	local expected = child.lua_get([[require("gleb.file_tree.fs").normalize(...)]], {
		vim.fs.joinpath(root, relative),
	})
	eq(selected, expected)
end

---@param query string
local function add(query)
	child.type_keys("a")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Add picker did not open")
	child.type_keys(query, "<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Add picker did not close")
end

---@param visual? boolean
local function confirm_delete(visual)
	if visual then
		assert(
			child.wait([[MiniPick.is_picker_active() and (MiniPick.get_picker_matches() or {}).current ~= nil]]),
			"Delete confirmation did not open"
		)
	else
		assert(vim.wait(1000, child.is_blocked, 10), "Delete confirmation did not block")
		child.type_keys("<Down>")
	end
	child.type_keys("<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Delete confirmation did not close")
end

local function nest_is_expanded()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return view.expanded_nests["internal/billing/invoice.go"] == true
	end)()]])
end

---@param enabled boolean
---@param include_go_rule boolean
---@return string
local function settings_json(enabled, include_go_rule)
	local value = vim.deepcopy(default_settings)
	value.nesting.enabled = enabled
	if not include_go_rule then
		table.remove(value.nesting.rules, 1)
	end
	return vim.json.encode(value)
end

---@param path string
---@param text string
local function write_settings_buffer(path, text)
	child.lua([[
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-file-tree" then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	]])
	child.cmd("edit " .. vim.fn.fnameescape(path))
	child.api.nvim_buf_set_lines(0, 0, -1, false, { text })
	child.cmd("write")
end

---@param text string
---@return string
local function use_temporary_settings(text)
	local path = child.lua_get([[vim.fn.tempname() .. ".json"]])
	write_settings_buffer(path, text)
	child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], { path })
	child.lua([[require("gleb.file_tree.view").refresh()]])
	return path
end

---@return table[]
local function billing_file_rows()
	local directory = child.lua_get([[require("gleb.file_tree.fs").normalize(...)]], {
		vim.fs.joinpath(root, "internal", "billing"),
	})
	return child.lua_get(
		[[(function(directory)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local rows = {}
			for _, row in ipairs(view.rows) do
				if row.kind == "file" and vim.fs.dirname(row.path) == directory then
					rows[#rows + 1] = { row.label, row.nest_children ~= nil }
				end
			end
			return rows
		end)(...)]],
		{ directory }
	)
end

local sibling_rows = {
	{ "discount.go", false },
	{ "discount_test.go", false },
	{ "invoice.go", false },
	{ "invoice_test.go", false },
	{ "tax.go", false },
	{ "tax_test.go", false },
}

T["file-tree: Nests start collapsed under a chevron"] = function()
	local invoice = assert(tree_line("invoice.go"))
	eq(invoice:find("", 1, true) ~= nil, true)
	eq(has_tree_line("invoice_test.go"), false)
	eq(nest_is_expanded(), false)
end

T["file-tree: Nest children are indented under the parent"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")

	local invoice = assert(tree_line("invoice.go"))
	local invoice_test = assert(tree_line("invoice_test.go"))
	eq(invoice:sub(1, 10), "       ")
	eq(invoice_test:match("^ *"), string.rep(" ", 11))
	eq(nest_is_expanded(), true)
end

T["file-tree: Nest state survives a refresh"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	child.type_keys("R")

	eq(nest_is_expanded(), true)
	eq(has_tree_line("invoice_test.go"), true)
end

T["file-tree: Nest state is isolated between tabs"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	local first_tab = child.api.nvim_get_current_tabpage()

	child.cmd("tabnew")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	eq(nest_is_expanded(), false)
	eq(has_tree_line("invoice_test.go"), false)

	child.api.nvim_set_current_tabpage(first_tab)
	eq(nest_is_expanded(), true)
	eq(has_tree_line("invoice_test.go"), true)
end

T["file-tree: Drawing prunes stale nest state"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	eq(vim.fn.delete(vim.fs.joinpath(root, "internal/billing/invoice_test.go")), 0)
	child.type_keys("R")

	local invoice = assert(tree_line("invoice.go"))
	eq(nest_is_expanded(), false)
	eq(invoice:find("", 1, true), nil)
	eq(invoice:find("", 1, true), nil)
end

T["file-tree: Invalid settings file disables nesting"] = function()
	local notifications = H.record_notify(child)
	use_temporary_settings('{ "nesting": ')

	eq(vim.inspect(billing_file_rows()), vim.inspect(sibling_rows))
	local notice = notifications()[1]
	eq(notice.level, vim.log.levels.ERROR)
	eq(vim.startswith(notice.msg, "File tree settings invalid"), true)
end

T["file-tree: Nesting can be turned off"] = function()
	use_temporary_settings(settings_json(false, true))

	eq(vim.inspect(billing_file_rows()), vim.inspect(sibling_rows))
end

T["file-tree: Writing the settings file reloads nesting"] = function()
	local path = use_temporary_settings(settings_json(true, true))
	eq(assert(tree_line("invoice.go")):find("", 1, true) ~= nil, true)

	write_settings_buffer(path, settings_json(true, false))
	assert(child.wait([[require("gleb.file_tree.settings").generation() > 2]], 1000), "settings did not reload")

	eq(vim.inspect(billing_file_rows()), vim.inspect(sibling_rows))
end

T["file-tree: Writing settings through a normalized path reloads nesting"] = function()
	local path = use_temporary_settings(settings_json(true, true))
	local normalized = child.lua_get([[require("gleb.file_tree.fs").normalize(...)]], { path })
	eq(vim.startswith(path, "/var/"), true)
	eq(vim.startswith(normalized, "/private/var/"), true)

	write_settings_buffer(normalized, settings_json(true, false))
	assert(child.wait([[require("gleb.file_tree.settings").generation() > 2]], 1000), "settings did not reload")

	eq(vim.inspect(billing_file_rows()), vim.inspect(sibling_rows))
end

T["file-tree: Fold all and reroot clear nest state"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	child.type_keys("zM")
	eq(nest_is_expanded(), false)
	eq(child.lua_get([=[require("gleb.file_tree.expanded").state.pending[...] == nil]=], { root }), true)

	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		view.expanded_nests["internal/billing/invoice.go"] = true
	]])
	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	child.cmd("cd " .. vim.fn.fnameescape(other))
	assert(
		child.wait([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and view.root == require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
	end)()]]),
		"tree did not reroot"
	)
	eq(
		child.lua_get(
			[[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded_nests]]
		),
		{}
	)
end

T["file-tree: Renaming a nest parent migrates its state"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	assert(
		vim.uv.fs_copyfile(
			vim.fs.joinpath(root, "internal/billing/invoice_test.go"),
			vim.fs.joinpath(root, "internal/billing/bill_test.go")
		)
	)
	rename("bill.go")
	assert(
		child.wait(
			[[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return view.expanded_nests["internal/billing/bill.go"] == true
			and vim.iter(view.rows):any(function(row) return row.label == "bill_test.go" end)
	end)()]],
			1600
		),
		"rename did not migrate nest state"
	)

	local state = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			old = view.expanded_nests["internal/billing/invoice.go"],
			new = view.expanded_nests["internal/billing/bill.go"],
			child = vim.iter(view.rows):any(function(row) return row.label == "bill_test.go" end),
		}
	end)()]])
	eq(state, { new = true, child = true })
end

T["file-tree: Renaming a folder migrates nest state in every view"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	local first_tab = child.api.nvim_get_current_tabpage()

	child.cmd("tabnew")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	focus_tree_row("invoice.go")
	child.type_keys("za")
	focus_tree_path("internal/billing")
	rename("accounts")
	assert(
		child.wait(
			([[(function(first_tab)
			for _, tab in ipairs({ first_tab, vim.api.nvim_get_current_tabpage() }) do
				local view = assert(require("gleb.file_tree.view").state.by_tab[tab])
				if view.expanded_nests["internal/accounts/invoice.go"] ~= true then
					return false
				end
			end
			return true
		end)(%d)]]):format(first_tab),
			1600
		),
		"rename did not migrate every view"
	)

	local states = child.lua_get(
		[[(function(first_tab)
			local result = {}
			for _, tab in ipairs({ first_tab, vim.api.nvim_get_current_tabpage() }) do
				local view = assert(require("gleb.file_tree.view").state.by_tab[tab])
				result[#result + 1] = {
					old = view.expanded_nests["internal/billing/invoice.go"],
					new = view.expanded_nests["internal/accounts/invoice.go"],
					child = vim.iter(view.rows):any(function(row) return row.label == "invoice_test.go" end),
				}
			end
			return result
		end)(...)]],
		{ first_tab }
	)
	eq(states, { { new = true, child = true }, { new = true, child = true } })
end

T["file-tree: za toggles a nest"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	eq(has_tree_line("invoice_test.go"), true)

	child.type_keys("za")
	eq(has_tree_line("invoice_test.go"), false)
end

T["file-tree: h on a nested file closes its nest"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	focus_tree_row("invoice_test.go")

	child.type_keys("h")

	eq(has_tree_line("invoice_test.go"), false)
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("invoice.go", 1, true) ~= nil]]), true)
end

T["file-tree: Enter on a nest parent opens the file"] = function()
	focus_tree_row("invoice.go")

	child.type_keys("<CR>")

	eq(
		child.lua_get([[require("gleb.file_tree.fs").normalize(vim.api.nvim_buf_get_name(0))]]),
		child.lua_get([[require("gleb.file_tree.fs").normalize(...)]], {
			vim.fs.joinpath(root, "internal/billing/invoice.go"),
		})
	)
	eq(nest_is_expanded(), false)
	eq(has_tree_line("invoice_test.go"), false)
end

T["file-tree: Fold all and unfold all include nests"] = function()
	child.type_keys("zR")
	for _, name in ipairs({
		"discount_test.go",
		"invoice_test.go",
		"tax_test.go",
		"money_test.go",
		"price.test.ts",
		"price.d.ts",
		"package-lock.json",
		"go.sum",
	}) do
		eq(has_tree_line(name), true)
	end

	child.type_keys("zM")
	for _, name in ipairs({
		"discount_test.go",
		"invoice_test.go",
		"tax_test.go",
		"money_test.go",
		"price.test.ts",
		"price.d.ts",
		"package-lock.json",
		"go.sum",
	}) do
		eq(has_tree_line(name), false)
	end
end

T["file-tree: Unfold all counts nested children toward the row limit"] = function()
	local oversized = vim.fs.joinpath(root, "oversized")
	vim.fn.mkdir(oversized, "p")
	for index = 1, 2500 do
		for _, suffix in ipairs({ ".go", "_test.go" }) do
			local path = vim.fs.joinpath(oversized, ("file-%04d%s"):format(index, suffix))
			local file = assert(vim.uv.fs_open(path, "w", 420))
			assert(vim.uv.fs_close(file))
		end
	end
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)

	child.type_keys("zR")

	local row_count = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return #view.rows
	end)()]])
	assert(row_count <= 5001, "unfold all exceeded the row limit")
	eq(notifications(), {
		{ msg = "Unfold all stopped at 5000 rows", level = vim.log.levels.WARN },
	})
end

T["file-tree: Followed nested file expands its nest"] = function()
	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice_test.go")))

	eq(has_tree_line("invoice_test.go"), true)
	expect_selected("internal/billing/invoice_test.go")
end

T["file-tree: Added nested file is revealed in its nest"] = function()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	focus_tree_row("invoice_test.go")
	add("invoice_mock.go")

	eq(has_tree_line("invoice_mock.go"), true)
	expect_selected("internal/billing/invoice_mock.go")
end

T["file-tree: Renamed file is revealed in a collapsed nest"] = function()
	vim.fn.writefile({ "package billing" }, vim.fs.joinpath(root, "internal/billing/pending.go"))
	child.type_keys("R")
	focus_tree_row("pending.go")

	rename("invoice_mock.go")

	eq(has_tree_line("invoice_mock.go"), true)
	expect_selected("internal/billing/invoice_mock.go")
end

T["file-tree: Pasted file is revealed in a collapsed nest"] = function()
	vim.fn.writefile({ "package billing" }, vim.fs.joinpath(root, "invoice_mock.go"))
	child.type_keys("R")
	focus_tree_path("invoice_mock.go")
	child.type_keys("c", "<Esc>")
	focus_tree_path("internal/billing/invoice.go")

	child.type_keys("p")

	assert(vim.uv.fs_stat(vim.fs.joinpath(root, "internal/billing/invoice_mock.go")), "pasted file did not appear")
	eq(has_tree_line("invoice_mock.go"), true)
	expect_selected("internal/billing/invoice_mock.go")
end

T["file-tree: Following under a symlinked root expands the nest"] = function()
	local logical_root = vim.fs.joinpath(vim.fn.tempname(), "linked-billing")
	vim.fn.mkdir(vim.fs.dirname(logical_root), "p")
	assert(vim.uv.fs_symlink(root, logical_root, { dir = true }))
	run_action("file_tree.toggle")
	child.cmd("cd " .. vim.fn.fnameescape(logical_root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(logical_root, "internal/billing/invoice_test.go")))
	run_action("file_tree.reveal")

	eq(has_tree_line("invoice_test.go"), true)
	expect_selected("internal/billing/invoice_test.go")
end

T["file-tree: Deleting a nest parent keeps its children"] = function()
	focus_tree_path("internal/billing/discount.go")
	child.type_keys("d")
	confirm_delete()

	local parent = vim.fs.joinpath(root, "internal/billing/discount.go")
	local nested_child = vim.fs.joinpath(root, "internal/billing/discount_test.go")
	assert(
		vim.wait(1000, function()
			return vim.uv.fs_lstat(parent) == nil
		end),
		"nest parent was not deleted"
	)
	eq(vim.uv.fs_lstat(nested_child) ~= nil, true)
	eq(has_tree_line("discount_test.go"), true)
	local child_line = assert(tree_line("discount_test.go"))
	eq(child_line:find("", 1, true), nil)
	eq(child_line:find("", 1, true), nil)
end

T["file-tree: Visual delete on a collapsed parent deletes only the parent"] = function()
	focus_tree_path("internal/billing/discount.go")
	child.type_keys("V")
	eq(child.fn.mode(1), "V")
	child.type_keys("d")
	confirm_delete(true)

	local parent = vim.fs.joinpath(root, "internal/billing/discount.go")
	local nested_child = vim.fs.joinpath(root, "internal/billing/discount_test.go")
	assert(
		vim.wait(1000, function()
			return vim.uv.fs_lstat(parent) == nil
		end),
		"nest parent was not deleted"
	)
	eq(vim.uv.fs_lstat(nested_child) ~= nil, true)
	eq(has_tree_line("discount_test.go"), true)
end

return T
