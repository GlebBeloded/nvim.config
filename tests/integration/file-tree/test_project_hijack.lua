local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/treeproj")
	vim.fn.mkdir(vim.fs.joinpath(root, "docs"), "p")
	vim.fn.writefile({ "# Workflow" }, vim.fs.joinpath(root, "docs", "workflow.md"))
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
end

local T = H.child_set(child, start)

local function run_tree_toggle()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(child.wait([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and #view.rows > 0 and view.initial_draw_timer == nil
	end)()]]))
end

---@param name string
local function focus_tree_row(name)
	local found = child.lua_get(
		[[(function(name)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for row, line in ipairs(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)) do
				if line:find(name, 1, true) then
					vim.api.nvim_win_set_cursor(view.win, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
end

T["file-tree: Directory argument opens the project tree"] = function()
	local directory = vim.fs.joinpath(root, "docs")
	child.cmd("edit " .. vim.fn.fnameescape(directory))
	assert(child.wait([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and #view.rows > 1
	end)()]]))

	local actual = child.lua_get(
		[[(function(directory)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			filetype = vim.bo.filetype,
			root = view.root,
			labels = vim.tbl_map(function(row) return row.label end, view.rows),
			directory_windows = vim.iter(vim.api.nvim_list_wins()):fold(0, function(count, win)
				return count + (vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == directory and 1 or 0)
			end),
			directory_buffers = vim.iter(vim.api.nvim_list_bufs()):fold(0, function(count, buf)
				return count + (vim.api.nvim_buf_get_name(buf) == directory and 1 or 0)
			end),
			netrw_buffers = vim.iter(vim.api.nvim_list_bufs()):fold(0, function(count, buf)
				return count + (vim.bo[buf].filetype == "netrw" and 1 or 0)
			end),
		}
	end)(...)]],
		{ directory }
	)

	eq(actual.filetype, "gleb-file-tree")
	eq(actual.root, vim.uv.fs_realpath(directory))
	eq(actual.labels, { "docs", "workflow.md" })
	eq(actual.directory_windows, 0)
	eq(actual.directory_buffers, 0)
	eq(actual.netrw_buffers, 0)
end

T["file-tree: netrw is not loaded"] = function()
	local actual = child.lua_get([[(function()
		local disabled = require("lazy.core.config").options.performance.rtp.disabled_plugins
		return { explore = vim.fn.exists(":Explore"), disabled = vim.tbl_contains(disabled, "netrwPlugin") }
	end)()]])

	eq(actual, { explore = 0, disabled = true })
end

T["file-tree: Directory buffer focuses an open project tree"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit README.md")
	run_tree_toggle()
	child.cmd("wincmd l")
	focus_tree_row("go.mod")
	local directory = vim.fs.joinpath(root, "internal")

	child.cmd("edit " .. vim.fn.fnameescape(directory))
	assert(child.wait([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and vim.api.nvim_get_current_win() == view.win
	end)()]]))

	local actual = child.lua_get(
		[[(function(directory)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			root = view.root,
			line = vim.api.nvim_buf_get_lines(view.buf, vim.api.nvim_win_get_cursor(view.win)[1] - 1,
				vim.api.nvim_win_get_cursor(view.win)[1], false)[1],
			directory_buffers = vim.iter(vim.api.nvim_list_bufs()):fold(0, function(count, buf)
				return count + (vim.api.nvim_buf_get_name(buf) == directory and 1 or 0)
			end),
		}
	end)(...)]],
		{ directory }
	)

	eq(actual.root, vim.uv.fs_realpath(root))
	assert(actual.line:find("go.mod", 1, true), "tree cursor moved from go.mod")
	eq(actual.directory_buffers, 0)
end

T["file-tree: Directory buffer entered from project tree focuses it"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit README.md")
	run_tree_toggle()
	focus_tree_row("go.mod")
	local directory = vim.fs.joinpath(root, "internal")

	child.cmd("edit " .. vim.fn.fnameescape(directory))
	assert(child.wait([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and vim.api.nvim_get_current_win() == view.win
	end)()]]))

	local actual = child.lua_get(
		[[(function(directory)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local editor = assert(require("gleb.file_tree.view").state.last_editor_by_tab[view.tab])
			return {
				root = view.root,
				line = vim.api.nvim_buf_get_lines(view.buf, vim.api.nvim_win_get_cursor(view.win)[1] - 1,
					vim.api.nvim_win_get_cursor(view.win)[1], false)[1],
				editor_name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(editor)),
				directory_buffers = vim.iter(vim.api.nvim_list_bufs()):fold(0, function(count, buf)
					return count + (vim.api.nvim_buf_get_name(buf) == directory and 1 or 0)
				end),
			}
		end)(...)]],
		{ directory }
	)

	eq(actual.root, vim.uv.fs_realpath(root))
	assert(actual.line:find("go.mod", 1, true), "tree cursor moved from go.mod")
	eq(actual.editor_name, vim.uv.fs_realpath(vim.fs.joinpath(root, "README.md")))
	eq(actual.directory_buffers, 0)
end

return T
