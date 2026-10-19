local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
	child.wait_very_lazy()
end)

T["file-tree: Toggle tolerates a deleted current file"] = function()
	local dir = vim.fn.tempname()
	H.write_files(dir, { ["deleted.txt"] = "gone\n" })
	child.cmd("cd " .. vim.fn.fnameescape(dir))
	child.cmd("edit deleted.txt")
	vim.fn.delete(vim.fs.joinpath(dir, "deleted.txt"))
	child.cmd("messages clear")

	child.type_keys("<M-e>")

	assert(
		child.wait([[(function()
			local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view ~= nil and #view.rows > 0
		end)()]]),
		"project tree did not draw its rows"
	)
	eq(
		child.lua_get([[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local row = vim.api.nvim_win_get_cursor(0)[1]
			return { vim.bo.filetype, row, view.rows[row].kind }
		end)()]]),
		{ "gleb-file-tree", 1, "root" }
	)
	eq({ child.v.errmsg, child.cmd_capture("messages") }, { "", "" })
end

return T
