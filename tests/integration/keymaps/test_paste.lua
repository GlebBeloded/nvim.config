local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local project

local function start()
	project = H.git_repo({ ["README.md"] = "project\n" })
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start, { reuse = true })

local function open_project_tree()
	child.cmd("cd " .. vim.fn.fnameescape(project))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(project, "README.md")))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		child.wait([[(function()
			local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view and #view.rows > 0
		end)()]]),
		"Project tree did not draw its initial rows"
	)
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		vim.api.nvim_set_current_win(view.win)
	]])
end

T["keymaps: Terminal paste ignores a read-only project tree"] = function()
	open_project_tree()
	local before = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])

	local result = child.lua_get([[{ pcall(vim.paste, { "probe" }, -1) }]])

	eq(result[1], true)
	eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), before)
end

T["keymaps: Terminal paste edits a normal buffer"] = function()
	child.cmd("enew")

	local result = child.lua_get([[{ pcall(vim.paste, { "probe" }, -1) }]])

	eq(result[1], true)
	eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), { "probe" })
end

T["keymaps: Terminal paste writes to a terminal buffer"] = function()
	child.cmd("terminal cat")

	local result = child.lua_get([[{ pcall(vim.paste, { "probe" }, -1) }]])

	eq(result, { true, true })
	assert(child.wait([[vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "probe"]]), "Terminal did not receive paste")
end

T["keymaps: Terminal paste edits the command line from a read-only project tree"] = function()
	open_project_tree()
	child.type_keys(":")

	local result = child.lua_get([[{ pcall(vim.paste, { "probe" }, -1) }]])

	eq(result, { true, true })
	eq(child.lua_get([[vim.fn.getcmdline()]]), "probe")
	child.type_keys("<Esc>")
end

return T
