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

---@param relative string
local function focus_tree_path(relative)
	local found = child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.path == path then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), relative) }
	)
	assert(found, "tree path not found: " .. relative)
end

---@param name string
---@return boolean
local function wait_for_tree_row(name)
	return child.lua_get(
		[[(function(name)
			return vim.wait(1000, function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and vim.iter(view.rows):any(function(row)
					return row.label == name
				end)
			end, 20)
		end)(...)]],
		{ name }
	)
end

---@param name string
---@param group string
---@return boolean
local function wait_for_tree_highlight(name, group)
	return child.lua_get(
		[[(function(name, group)
			return vim.wait(1000, function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then
					return false
				end
				for index, row in ipairs(view.rows) do
					if row.label == name then
						local marks = vim.api.nvim_buf_get_extmarks(
							view.buf,
							require("gleb.file_tree.render").namespace,
							{ index - 1, 0 },
							{ index - 1, -1 },
							{ details = true }
						)
						return vim.iter(marks):any(function(mark)
							return mark[4].hl_group == group
						end)
					end
				end
				return false
			end, 20)
		end)(...)]],
		{ name, group }
	)
end

local function open_billing_folder()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_path("internal/billing")
	child.type_keys("<CR>")
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
	child.cmd("edit " .. vim.fn.fnameescape(outside .. "-missing"))
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

T["file-tree: A compact chain splits when a folder gains an entry"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("cmd/server"), true)

	local result = H.system(child, { "mkdir", vim.fs.joinpath(root, "cmd/worker") }, root)
	eq(result.code, 0)

	eq(wait_for_tree_row("cmd"), true)
	eq(wait_for_tree_row("server"), true)
	eq(wait_for_tree_row("worker"), true)
	eq(wait_for_tree_row("cmd/server"), false)
end

T["file-tree: Every compact chain member is watched"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("cmd/server"), true)

	local watched = child.lua_get(
		[[(function(root)
			root = require("gleb.file_tree.fs").normalize(root)
			local handles = assert(require("gleb.file_tree.watch").state.roots[root]).handles
			return { handles[root .. "/cmd"] ~= nil, handles[root .. "/cmd/server"] ~= nil }
		end)(...)]],
		{ root }
	)
	eq(watched, { true, true })

	local result = H.system(child, { "mkdir", vim.fs.joinpath(root, "cmd/worker") }, root)
	eq(result.code, 0)
	eq(wait_for_tree_row("cmd"), true)
	eq(wait_for_tree_row("server"), true)
	eq(wait_for_tree_row("worker"), true)
end

T["file-tree: Project tree shows files created outside Neovim"] = function()
	open_billing_folder()

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "internal/billing/fee.go") }, root)
	eq(result.code, 0)

	eq(wait_for_tree_highlight("fee.go", "FileTreeGitUntracked"), true)
end

T["file-tree: Project tree recolours a written file"] = function()
	open_billing_folder()
	child.cmd("wincmd l")
	edit("internal/billing/discount.go")
	child.api.nvim_buf_set_lines(0, -1, -1, false, { "// changed" })

	child.cmd("write")

	eq(wait_for_tree_highlight("discount.go", "FileTreeGitModified"), true)
end

T["file-tree: Project tree recolours after staging outside Neovim"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	eq(wait_for_tree_highlight("notes.md", "FileTreeGitUntracked"), true)

	local result = H.system(child, { "git", "add", "notes.md" }, root)
	eq(result.code, 0)

	eq(wait_for_tree_highlight("notes.md", "FileTreeGitAdded"), true)
end

T["file-tree: Project tree watchers stop when the tree closes"] = function()
	edit("README.md")
	run_action("file_tree.toggle")

	local handle_count = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		local state = assert(require("gleb.file_tree.watch").state.roots[root])
		_G.file_tree_closed_handles = vim.tbl_values(state.handles)
		return #_G.file_tree_closed_handles
	end)(...)]],
		{ root }
	)
	assert(handle_count > 0, "expected the open tree to own folder watchers")

	child.type_keys("q")
	local stopped = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		return vim.wait(1000, function()
			local watch = require("gleb.file_tree.watch")
			return watch.state.roots[root] == nil
				and vim.iter(_G.file_tree_closed_handles):all(function(handle)
					return handle:is_closing()
				end)
		end, 20)
	end)(...)]],
		{ root }
	)
	eq(stopped, true)

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "żółć.lua") }, root)
	eq(result.code, 0)
	run_action("file_tree.toggle")
	eq(wait_for_tree_row("żółć.lua"), true)
end

T["file-tree: Project tree prunes a deleted expanded folder"] = function()
	open_billing_folder()
	focus_tree_path("internal/billing/invoice_test.go")
	child.lua(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		_G.file_tree_deleted_handle = assert(
			require("gleb.file_tree.watch").state.roots[root].handles[root .. "/internal/billing"]
		)
	end)(...)]],
		{ root }
	)

	local result = H.system(child, { "rm", "-r", vim.fs.joinpath(root, "internal/billing") }, root)
	eq(result.code, 0)

	local pruned = child.lua_get([[(function()
		return vim.wait(1000, function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local cursor = vim.api.nvim_win_get_cursor(view.win)[1]
			return view.expanded["internal/billing"] == nil
				and vim.iter(view.rows):all(function(row)
					return not row.path:find("/internal/billing", 1, true)
				end)
				and cursor <= #view.rows
				and _G.file_tree_deleted_handle:is_closing()
		end, 20)
	end)()]])
	eq(pruned, true)
end

T["file-tree: Project tree caps watched folders"] = function()
	child.lua([[require("gleb.file_tree.watch").MAX_WATCH_HANDLES = 2]])
	edit("README.md")
	run_action("file_tree.toggle")

	local watched = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local handles = assert(require("gleb.file_tree.watch").state.roots[root]).handles
		return {
			handle_count = vim.tbl_count(handles),
			has_compact_row = vim.iter(view.rows):any(function(row)
				return row.label == "cmd/server"
			end),
			has_unwatched_row = vim.iter(view.rows):any(function(row)
				return row.label == "internal"
			end),
		}
	end)(...)]],
		{ root }
	)
	eq(watched, { handle_count = 2, has_compact_row = true, has_unwatched_row = true })
end

T["file-tree: Project tree shares root work across tabs"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(root, "go.mod")))
	run_action("file_tree.toggle")

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "shared.lua") }, root)
	eq(result.code, 0)
	local shared = child.lua_get(
		[[(function(root)
		root = require("gleb.file_tree.fs").normalize(root)
		return vim.wait(1000, function()
			local views = vim.tbl_values(require("gleb.file_tree.view").state.by_tab)
			return #views == 2 and vim.iter(views):all(function(view)
				return vim.iter(view.rows):any(function(row)
					return row.label == "shared.lua"
				end)
			end)
		end, 20) and {
			git_refs = require("gleb.file_tree.git").state.roots[root].refs,
			watch_refs = require("gleb.file_tree.watch").state.roots[root].refs,
		}
	end)(...)]],
		{ root }
	)
	eq(shared, { git_refs = 2, watch_refs = 2 })
end

T["file-tree: Project tree isolates tabpage state"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local first_tab = child.api.nvim_get_current_tabpage()
	focus_tree_row("internal")

	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(root, "go.mod")))
	run_action("file_tree.toggle")
	local second_tab = child.api.nvim_get_current_tabpage()
	focus_tree_row("go.mod")
	local second = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { buf = view.buf, cursor = vim.api.nvim_win_get_cursor(view.win), autocmds = vim.deepcopy(view.autocmds) }
	end)()]])

	child.cmd("tabprevious")
	child.type_keys("<CR>")
	child.cmd("tabclose")
	eq(child.api.nvim_get_current_tabpage(), second_tab)

	local result = H.system(child, { "touch", vim.fs.joinpath(root, "isolated.lua") }, root)
	eq(result.code, 0)
	local isolated = child.lua_get(
		[[(function(first_tab, expected, root)
		root = require("gleb.file_tree.fs").normalize(root)
		local ready = vim.wait(1000, function()
			local state = require("gleb.file_tree.view").state
			local view = state.by_tab[vim.api.nvim_get_current_tabpage()]
			return state.by_tab[first_tab] == nil
				and view ~= nil
				and view.buf == expected.buf
				and vim.deep_equal(vim.api.nvim_win_get_cursor(view.win), expected.cursor)
				and vim.deep_equal(view.autocmds, expected.autocmds)
				and vim.iter(view.rows):any(function(row)
					return row.label == "isolated.lua"
				end)
		end, 20)
		return ready and {
			git_refs = require("gleb.file_tree.git").state.roots[root].refs,
			watch_refs = require("gleb.file_tree.watch").state.roots[root].refs,
		} or false
	end)(...)]],
		{ first_tab, second, root }
	)
	eq(isolated, { git_refs = 1, watch_refs = 1 })
end

T["file-tree: Project tree re-roots on a cwd change"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	H.write_files(other, { ["other-root.txt"] = "other\n" })

	child.cmd("cd " .. vim.fn.fnameescape(other))
	local actual = child.lua_get(
		[[(function(old_root)
		return vim.wait(1000, function()
			local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view
				and view.root == require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
				and vim.iter(view.rows):any(function(row)
					return row.label == "other-root.txt"
				end)
		end, 20) and {
			root = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].root,
			old_watch = require("gleb.file_tree.watch").state.roots[require("gleb.file_tree.fs").normalize(old_root)] ~= nil,
		}
	end)(...)]],
		{ root }
	)
	eq(actual, { root = assert(vim.uv.fs_realpath(other)), old_watch = false })
end

T["file-tree: Project tree expanded folders persist per root"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	run_action("file_tree.close")

	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	child.cmd("cd " .. vim.fn.fnameescape(other))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(other, "README.md")))
	run_action("file_tree.toggle")
	focus_tree_row("web")
	child.type_keys("<CR>")
	run_action("file_tree.close")

	child.cmd("cd " .. vim.fn.fnameescape(root))
	run_action("file_tree.toggle")
	local first = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	run_action("file_tree.close")
	child.cmd("cd " .. vim.fn.fnameescape(other))
	run_action("file_tree.toggle")
	local second = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	eq(first, { internal = true })
	eq(second, { web = true })
end

T["file-tree: Project tree drops a stored folder that is gone"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	run_action("file_tree.close")
	eq(H.system(child, { "rm", "-r", vim.fs.joinpath(root, "internal") }, root).code, 0)

	run_action("file_tree.toggle")
	local expanded = child.lua_get(
		[[vim.deepcopy(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded)]]
	)
	run_action("file_tree.close")
	local stored = child.lua_get(
		[[(function(root)
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))[root]
	end)(...)]],
		{ assert(vim.uv.fs_realpath(root)) }
	)
	eq(expanded, {})
	eq(stored, {})
end

T["file-tree: Project tree atomically merges expansion state"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	focus_tree_row("internal")
	child.type_keys("<CR>")

	local other = F.copy("treeproj", vim.fn.tempname() .. "/other")
	child.cmd("tabnew " .. vim.fn.fnameescape(vim.fs.joinpath(other, "README.md")))
	child.cmd("cd " .. vim.fn.fnameescape(other))
	run_action("file_tree.toggle")
	focus_tree_row("web")
	child.type_keys("<CR>")
	child.cmd("tabclose")
	run_action("file_tree.close")

	local stored = child.lua_get([[(function()
		local directory = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree")
		local path = vim.fs.joinpath(directory, "expanded.json")
		return {
			value = vim.json.decode(table.concat(vim.fn.readfile(path), "\n")),
			temporary = vim.fn.globpath(directory, "expanded.json.*", false, true),
		}
	end)()]])
	eq(stored, {
		value = {
			[assert(vim.uv.fs_realpath(root))] = { "internal" },
			[assert(vim.uv.fs_realpath(other))] = { "web" },
		},
		temporary = {},
	})
end

T["file-tree: Project tree re-roots across git worktrees"] = function()
	edit("README.md")
	run_action("file_tree.toggle")
	local linked = vim.fn.tempname() .. "/linked"
	eq(H.system(child, { "git", "worktree", "add", "-q", "-b", "linked-test", linked }, root).code, 0)
	local expected_top = vim.trim(H.system(child, { "git", "-C", linked, "rev-parse", "--show-toplevel" }, root).stdout)
	local expected_git =
		vim.trim(H.system(child, { "git", "-C", linked, "rev-parse", "--absolute-git-dir" }, root).stdout)

	child.cmd("cd " .. vim.fn.fnameescape(linked))
	local actual = child.lua_get([[(function()
		return vim.wait(1000, function()
			local root = require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
			local state = require("gleb.file_tree.watch").state.roots[root]
			return state and state.toplevel and state.git_dir
		end, 20) and (function()
			local root = require("gleb.file_tree.fs").normalize(vim.fn.getcwd())
			local state = require("gleb.file_tree.watch").state.roots[root]
			return { root = root, toplevel = state.toplevel, git_dir = state.git_dir }
		end)()
	end)()]])
	eq(actual, { root = assert(vim.uv.fs_realpath(linked)), toplevel = expected_top, git_dir = expected_git })
end

return T
