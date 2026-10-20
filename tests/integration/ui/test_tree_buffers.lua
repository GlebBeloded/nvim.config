local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local root
local manifest

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	child.cmd("cd " .. vim.fn.fnameescape(root))
end

local T = H.child_set(child, start)

---@return { registered: boolean, rows: integer, lines: integer }
local function tree_state()
	return child.lua_get([[
(function()
	local tree = require("gleb.ui.tree").get(0)
	return {
		registered = tree ~= nil,
		rows = tree and #require("gleb.ui.tree.model").rows(tree) or 0,
		lines = vim.api.nvim_buf_line_count(0),
	}
end)()
]])
end

local function run_action(id)
	child.lua(
		[[(function(id)
			local catalog = require("gleb.actions").state.applicator.catalog
			assert(catalog:get(id), id .. " is not registered").run(require("gleb.actions.context").capture())
		end)(...)]],
		{ id }
	)
end

local function expect_shared_tree()
	local state = tree_state()
	eq(state.registered, true)
	eq(state.rows, state.lines)
end

T["ui: Every tree buffer is a shared tree"] = function()
	local declaration = manifest.references.Format[1]
	child.cmd("edit " .. vim.fn.fnameescape(declaration.path))
	eq(tree_state().registered, false)

	child.type_keys("<M-e>")
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]]), "Project tree did not open")
	assert(
		child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]]),
		"Project tree did not draw its initial rows"
	)
	expect_shared_tree()
	child.type_keys("<M-e>")

	vim.fn.writefile({ "package dirty" }, root .. "/dirty.go")
	run_action("changes.toggle")
	assert(
		child.wait([[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view ~= nil and #view.rows > 0
		end)()]]),
		"Changes panel did not draw its initial rows"
	)
	expect_shared_tree()
	run_action("changes.toggle")

	child.cmd("edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], H.lsp_timeout(10000)), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)), true)
	expect_shared_tree()
end

return T
