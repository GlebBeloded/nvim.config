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
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.lua([[require("gleb.file_tree.fs").reset()]])
end

local T = H.child_set(child, start)

---@param relative string
local function edit(relative)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, relative)))
end

---@param id string
local function run_action(id)
	child.lua(
		[[(function(id)
			local catalog = require("gleb.actions").state.applicator.catalog
			local action = assert(catalog:get(id), id .. " is not registered")
			action.run(require("gleb.actions.context").capture())
		end)(...)]],
		{ id }
	)
end

---@return integer[]
local function tree_position()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { view.win, vim.api.nvim_win_get_cursor(view.win)[1] }
	end)()]])
end

---@return string
local function selected_tree_line()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local row = vim.api.nvim_win_get_cursor(view.win)[1]
		return vim.api.nvim_buf_get_lines(view.buf, row - 1, row, false)[1]
	end)()]])
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

T["file-tree: Project tree follows the current file"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	local editor = child.api.nvim_get_current_win()

	edit("internal/money/money.go")

	eq(child.api.nvim_get_current_win(), editor)
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
	local money_line = child.lua_get([[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.iter(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)):find(function(line)
			return line:find("money", 1, true) ~= nil and line:find("money.go", 1, true) == nil
		end)
	end)()]])
	assert(money_line:find("", 1, true), "money row is not expanded")
end

T["file-tree: Project tree ignores files outside the root"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	focus_tree_row("go.mod")
	local outside = vim.fn.tempname()
	vim.fn.writefile({ "outside" }, outside)

	child.cmd("edit " .. vim.fn.fnameescape(outside))

	eq(selected_tree_line():match("[^ ]+$"), "go.mod")
end

T["file-tree: Project tree reveal focuses the current file"] = function()
	edit("internal/money/money.go")

	run_action("file_tree.reveal")

	local position = tree_position()
	eq(child.api.nvim_get_current_win(), position[1])
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
end

T["file-tree: Project tree reveal tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	run_action("file_tree.reveal")

	local position = tree_position()
	eq(child.api.nvim_get_current_win(), position[1])
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree follow tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	local deleted_buf = child.api.nvim_get_current_buf()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("go.mod")
	child.cmd("wincmd l")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	child.api.nvim_set_current_buf(deleted_buf)

	local position = tree_position()
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree toggle tolerates a deleted file"] = function()
	edit("internal/money/money.go")
	child.fn.delete(vim.fs.joinpath(root, "internal/money/money.go"))
	local notifications = H.record_notify(child)

	run_action("file_tree.toggle")

	local position = tree_position()
	eq(position[2], 1)
	eq(notifications(), {})
end

T["file-tree: Project tree does not follow a directory buffer"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("wincmd l")
	focus_tree_row("go.mod")
	local notifications = H.record_notify(child)

	child.lua(
		[[(function(path)
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(buf, path)
			vim.api.nvim_set_current_buf(buf)
		end)(...)]],
		{ vim.fs.joinpath(root, "internal") }
	)

	eq(selected_tree_line():match("[^ ]+$"), "go.mod")
	eq(notifications(), {})
end

T["file-tree: Project tree normalizes a symlinked root"] = function()
	local linked_home = vim.fn.tempname()
	child.lua([[assert(vim.uv.fs_symlink(...))]], { vim.fs.dirname(root), linked_home })
	child.lua([[vim.env.HOME = ...]], { linked_home })
	local linked_root = vim.fs.joinpath(linked_home, vim.fs.basename(root))
	child.cmd("cd " .. vim.fn.fnameescape(linked_root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(linked_root, "internal/money/money.go")))
	local notifications = H.record_notify(child)

	run_action("file_tree.toggle")

	local actual = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return {
			root = view.root,
			root_line = vim.api.nvim_buf_get_lines(view.buf, 0, 1, false)[1],
		}
	end)()]])
	eq(actual.root, assert(vim.uv.fs_realpath(root)))
	eq(actual.root_line:sub(-#("~/" .. vim.fs.basename(root))), "~/" .. vim.fs.basename(root))
	eq(selected_tree_line():match("[^ ]+$"), "money.go")
	eq(notifications(), {})
end

T["file-tree: Project tree cuts a symlink loop"] = function()
	child.lua([[assert(vim.uv.fs_symlink(".", ...))]], { vim.fs.joinpath(root, "loop") })
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_action("file_tree.toggle")

	child.type_keys("zR")

	local loop_rows = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return vim.iter(view.rows):filter(function(row)
			return row.label == "loop"
		end):totable()
	end)()]])
	eq(#loop_rows, 1)
	eq(loop_rows[1].kind, "directory")
	eq(loop_rows[1].empty, true)
	eq(notifications(), {})
end

T["file-tree: Project tree tolerates an unreadable folder"] = function()
	local locked = vim.fs.joinpath(root, "locked")
	vim.fn.mkdir(locked, "p")
	vim.fn.writefile({ "secret" }, vim.fs.joinpath(locked, "secret.txt"))
	assert(vim.uv.fs_chmod(locked, 0))
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_action("file_tree.toggle")

	focus_tree_row("locked")
	child.type_keys("<CR>")

	local locked_rows = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return vim.iter(view.rows):filter(function(row)
			return row.path:find("/locked", 1, true) ~= nil
		end):totable()
	end)()]])
	eq(#locked_rows, 1)
	eq(locked_rows[1].kind, "directory")
	eq(locked_rows[1].empty, true)
	eq(notifications(), {})
	assert(vim.uv.fs_chmod(locked, 448))
end

return T
