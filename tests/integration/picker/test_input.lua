local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local root

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	child.start_config()
	child.wait_very_lazy()
	child.lua([[
		_G.input_submissions = {}
		_G.input_submit_state = {}
		_G.open_input = function(opts)
			vim.schedule(function()
				require("gleb.picker.input").open(vim.tbl_extend("force", {
					title = "New File or Directory",
					hint = "Create ↩",
					preview = function(query)
						return { text = "internal/billing/" .. query }
					end,
					on_submit = function(query)
						table.insert(_G.input_submissions, query)
					end,
				}, opts or {}))
			end)
		end
	]])
end

local function open_project_tree()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "README.md")))
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]]), "Project tree did not open")
end

local function open_input(opts)
	child.lua("_G.open_input(...)", { opts or {} })
	assert(child.wait("MiniPick.is_picker_active()"), "Input picker did not open")
end

local function picker_line()
	return child.lua_get([[
		vim.api.nvim_buf_get_lines(MiniPick.get_picker_state().buffers.main, 0, 1, false)[1]
	]])
end

local T = H.child_set(child, start)

T["picker: Input prompt submits its query"] = function()
	open_input()
	child.type_keys("fee.go", "<CR>")

	assert(child.wait("not MiniPick.is_picker_active()"), "Input picker did not close")
	assert(child.wait("#_G.input_submissions == 1"), "Input submission did not run")
	eq(child.lua_get("_G.input_submissions"), { "fee.go" })
end

T["picker: Input prompt starts with its default and previews it"] = function()
	open_input({ default = "invoice.go" })

	eq(child.lua_get("table.concat(MiniPick.get_picker_query())"), "invoice.go")
	eq(picker_line(), " internal/billing/invoice.go")
	child.type_keys("x")
	assert(
		child.wait(
			[[vim.api.nvim_buf_get_lines(MiniPick.get_picker_state().buffers.main, 0, 1, false)[1] == " internal/billing/invoice.gox"]]
		),
		"Preview did not update"
	)
end

T["picker: Input prompt cancels with Esc"] = function()
	open_input()
	child.type_keys("fee.go", "<Esc>")

	assert(child.wait("not MiniPick.is_picker_active()"), "Input picker did not close")
	eq(child.lua_get("_G.input_submissions"), {})
end

T["picker: Input prompt ignores a blank query"] = function()
	open_input()
	child.type_keys("  ", "<CR>")

	eq(child.lua_get("MiniPick.is_picker_active()"), true)
	eq(child.lua_get("_G.input_submissions"), {})
end

T["picker: Input prompt Esc restores tree focus and cursor state"] = function()
	open_project_tree()
	local tree_win = child.api.nvim_get_current_win()
	local tree_guicursor = child.o.guicursor
	child.lua([[
		local view = require("gleb.file_tree.view")
		local editor_win = assert(view.state.last_editor_by_tab[vim.api.nvim_get_current_tabpage()])
		vim.api.nvim_create_autocmd("User", {
			pattern = "MiniPickStop",
			once = true,
			callback = function()
				vim.schedule(function()
					vim.api.nvim_set_current_win(editor_win)
					vim.o.guicursor = "n:block"
					_G.input_teardown_finished = true
				end)
			end,
		})
	]])

	open_input()
	child.type_keys("<Esc>")

	assert(
		child.wait("not MiniPick.is_picker_active() and _G.input_teardown_finished"),
		"Input picker teardown did not finish"
	)
	eq(child.api.nvim_get_current_win(), tree_win)
	eq(child.o.guicursor, tree_guicursor)
end

T["picker: Input prompt submits after the picker closes"] = function()
	open_project_tree()
	child.lua([[
		_G.open_input({
			on_submit = function(query)
				table.insert(_G.input_submit_state, {
					query = query,
					picker_active = MiniPick.is_picker_active(),
				})
			end,
		})
	]])
	assert(child.wait("MiniPick.is_picker_active()"), "Input picker did not open")
	child.type_keys("fee.go", "<CR>")

	assert(child.wait("#_G.input_submit_state == 1"), "Input submission did not run")
	eq(child.lua_get("_G.input_submit_state"), {
		{ query = "fee.go", picker_active = false },
	})
end

return T
