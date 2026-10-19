local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function create_large_tree()
	root = vim.fn.tempname() .. "/large-tree"
	vim.fn.mkdir(root, "p")
	for directory_index = 1, 1999 do
		local directory = vim.fs.joinpath(root, ("directory-%04d"):format(directory_index))
		vim.fn.mkdir(directory, "p")
		local file_count = directory_index <= 850 and 2 or 1
		for file_index = 1, file_count do
			local path = vim.fs.joinpath(directory, ("file-%03d"):format(file_index))
			local file = assert(vim.uv.fs_open(path, "w", 420))
			assert(vim.uv.fs_close(file))
		end
	end
	for file_index = 1, 50 do
		local path = vim.fs.joinpath(root, ("root-file-%03d"):format(file_index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
	local expandable = vim.fs.joinpath(root, "expand-me")
	vim.fn.mkdir(expandable, "p")
	for file_index = 1, 100 do
		local path = vim.fs.joinpath(expandable, ("file-%03d"):format(file_index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
end

local function start()
	create_large_tree()
	child.start_config()
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "root-file-001")))
	child.type_keys("<M-e>")
	assert(
		child.wait(
			[=[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and #view.rows > 0
	end)()]=],
			math.ceil(3000 * H.load_factor())
		),
		"project tree did not open"
	)
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index = 1, 1999 do
			view.expanded[("directory-%04d"):format(index)] = true
		end
		require("gleb.file_tree.view").redraw_all()
	]])
end

local T = H.child_set(child, start)

local function install_replacement_counter()
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		FileTreeOriginalSetLines = vim.api.nvim_buf_set_lines
		FileTreeReplacementCount = 0
		vim.api.nvim_buf_set_lines = function(buf, ...)
			if buf == view.buf then
				FileTreeReplacementCount = FileTreeReplacementCount + 1
			end
			return FileTreeOriginalSetLines(buf, ...)
		end
	]])
end

T["file-tree: Project tree redraw meets the large-tree bound"] = function()
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 4900)
	install_replacement_counter()

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
		local selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
		local started = vim.uv.hrtime()
		require("gleb.file_tree.view").redraw_all()
		local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			elapsed_ms = elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows_preserved = vim.deep_equal(lines, vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)),
			selection_preserved = selected == view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path,
		}
	end)()]=])

	assert(result.elapsed_ms <= 100 * H.load_factor(), ("redraw took %.2f ms"):format(result.elapsed_ms))
	eq(result.replacements, 1)
	eq(result.rows_preserved, true)
	eq(result.selection_preserved, true)
end

T["file-tree: Project tree expansion meets the large-tree bound"] = function()
	eq(child.lua_get([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows]]), 4900)
	local found = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index, row in ipairs(view.rows) do
			if row.label == "expand-me" then
				vim.api.nvim_set_current_win(view.win)
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return true
			end
		end
		return false
	end)()]=])
	eq(found, true)
	install_replacement_counter()
	child.lua([[FileTreeExpansionStarted = vim.uv.hrtime()]])

	child.type_keys("<CR>")

	local result = child.lua_get([=[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local elapsed_ms = (vim.uv.hrtime() - FileTreeExpansionStarted) / 1e6
		vim.api.nvim_buf_set_lines = FileTreeOriginalSetLines
		return {
			elapsed_ms = elapsed_ms,
			replacements = FileTreeReplacementCount,
			rows = #view.rows,
			expanded = view.expanded["expand-me"] == true,
		}
	end)()]=])

	assert(result.elapsed_ms <= 100 * H.load_factor(), ("expansion took %.2f ms"):format(result.elapsed_ms))
	eq(result.replacements, 1)
	eq(result.rows, 5000)
	eq(result.expanded, true)
end

return T
