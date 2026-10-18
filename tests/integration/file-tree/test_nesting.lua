local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

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

local function nest_is_expanded()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return view.expanded_nests["internal/billing/invoice.go"] == true
	end)()]])
end

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

return T
