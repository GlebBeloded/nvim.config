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
	child.lua(
		[[
		local fs = require("gleb.file_tree.fs")
		local model = require("gleb.file_tree.model")
		local render = require("gleb.file_tree.render")
		fs.reset()
		ProjectTreeBuf = vim.api.nvim_create_buf(false, true)
		local rows = model.rows(fs.tree(...), {
			internal = true,
			["internal/billing"] = true,
		}, {})
		render.draw(ProjectTreeBuf, rows)
	]],
		{ root }
	)
end

local T = H.child_set(child, start)

---@param relative string
local function edit(relative)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, relative)))
end

---@param relative string
---@return string
local function real_path(relative)
	return vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), relative)
end

local function run_toggle()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

---@return integer[]
local function project_tree_windows()
	return child.lua_get([[(function()
		return vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-file-tree"
		end):totable()
	end)()]])
end

local function lines()
	return child.lua_get([[vim.api.nvim_buf_get_lines(ProjectTreeBuf, 0, -1, false)]])
end

---@param name string
local function focus_tree_row(name)
	local found = child.lua_get(
		[[(function(name)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(name, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
end

local function open_tree_on_makefile()
	edit("README.md")
	run_toggle()
	focus_tree_row("Makefile")
end

---@param needle string
---@return string[]
local function groups_for(needle)
	return child.lua_get(
		[[(function(needle)
		for row, line in ipairs(vim.api.nvim_buf_get_lines(ProjectTreeBuf, 0, -1, false)) do
			if line:find(needle, 1, true) then
				local groups = {}
				for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
					ProjectTreeBuf,
					-1,
					{ row - 1, 0 },
					{ row - 1, -1 },
					{ details = true }
				)) do
					groups[#groups + 1] = mark[4].hl_group
				end
				return groups
			end
		end
		return {}
	end)(...)]],
		{ needle }
	)
end

T["file-tree: Project tree root row names the project"] = function()
	local expected = "  billing  " .. vim.fn.fnamemodify(root, ":~")
	eq(lines()[1], expected)
	eq(groups_for("billing"), { "FileTreeExpander", "FileTreeFolderIcon", "FileTreeRoot", "FileTreeRootPath" })
end

T["file-tree: Project tree rows have icons and no guides"] = function()
	local rendered = lines()
	local invoice
	for _, line in ipairs(rendered) do
		if line:find("invoice.go", 1, true) then
			invoice = line
		end
		for _, guide in ipairs({ "│", "├", "└" }) do
			assert(not line:find(guide, 1, true), "project tree drew an indent guide")
		end
	end
	eq(invoice, "          invoice.go")
	eq(groups_for("invoice.go"), { "DevIconGo", "FileTreeFileName" })
end

T["file-tree: Project tree highlight colours come from the palette"] = function()
	child.api.nvim_set_hl(0, "FileTreeRoot", { fg = "#000000" })
	child.api.nvim_exec_autocmds("ColorScheme", {})

	H.expect_hl_colors(child, "FileTreeGitModified", { fg = "#7daea3" })
	H.expect_hl_colors(child, "FileTreeGitAdded", { fg = "#a9b665" })
	H.expect_hl_colors(child, "FileTreeGitUntracked", { fg = "#e78a4e" })
	H.expect_hl_colors(child, "FileTreeGitRenamed", { fg = "#89b482" })
	H.expect_hl_colors(child, "FileTreeGitConflict", { fg = "#ea6962" })
	H.expect_hl_colors(child, "FileTreeRoot", { fg = "#ddc7a1", bold = true })
	H.expect_hl_colors(child, "FileTreeRootPath", { fg = "#928374" })
	H.expect_hl_colors(child, "FileTreeCursorLine", { bg = "#32302f" })
end

T["file-tree: Project tree opens on the left at width 35"] = function()
	edit("README.md")
	run_toggle()

	local win = child.api.nvim_get_current_win()
	eq(child.bo.filetype, "gleb-file-tree")
	eq(child.lua_get([[vim.fn.win_getid(1)]]), win)
	eq(child.api.nvim_win_get_width(win), 35)
	eq(child.wo.winfixwidth, true)
	eq(#child.api.nvim_tabpage_list_wins(0), 2)
end

T["file-tree: Project tree toggle closes a focused tree"] = function()
	edit("README.md")
	run_toggle()
	run_toggle()

	eq(project_tree_windows(), {})
end

T["file-tree: Project tree toggle focuses an open tree"] = function()
	edit("README.md")
	run_toggle()
	local tree_win = child.api.nvim_get_current_win()
	child.cmd("wincmd l")
	run_toggle()

	eq(child.api.nvim_get_current_win(), tree_win)
	eq(#child.api.nvim_tabpage_list_wins(0), 2)
end

T["file-tree: Project tree toggle reveals the current file"] = function()
	edit("internal/money/money.go")
	run_toggle()

	local cursor = child.api.nvim_win_get_cursor(0)
	local line = child.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1]
	eq(line:match("[^ ]+$"), "money.go")
end

T["file-tree: Project tree actions start unbound"] = function()
	local shortcuts = child.lua_get([[require("gleb.actions").state.store.last_good]])
	eq(shortcuts["file_tree.toggle"], nil)
	eq(shortcuts["file_tree.reveal"], nil)
	eq(child.lua_get([[vim.fn.maparg("<A-e>", "n", false, true).desc]]), "View | Tool Windows: Toggle File Tree")
	eq(child.lua_get([[vim.fn.maparg("<A-G>", "n", false, true).desc]]), "View | Tool Windows: Toggle Git Status Tree")
end

T["file-tree: Project tree closes with the last window"] = function()
	edit("README.md")
	run_toggle()
	child.cmd("wincmd l")

	local job = child.job.id
	child.api_notify.nvim_command("q")
	eq(vim.fn.jobwait({ job }, 5000)[1], 0)
end

T["file-tree: Project tree closes before last editor with close"] = function()
	edit("README.md")
	child.cmd("tabnew")
	edit("Makefile")
	local closing_tab = child.api.nvim_get_current_tabpage()
	run_toggle()
	child.cmd("wincmd l")

	child.api_notify.nvim_command("close")

	assert(child.wait([[#vim.api.nvim_list_tabpages() == 1]]), "tree tab did not close")
	eq(#child.api.nvim_list_tabpages(), 1)
	assert(child.api.nvim_get_current_tabpage() ~= closing_tab, "tree tab remained open")
	eq(project_tree_windows(), {})
end

T["file-tree: Project and neo-tree close before the last editor"] = function()
	edit("README.md")
	run_toggle()
	child.cmd("wincmd l")
	child.cmd("Neotree filesystem dir=" .. vim.fn.fnameescape(assert(vim.uv.fs_realpath(root))))
	assert(
		child.wait(
			[[(function()
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
						return true
					end
				end
				return false
			end)()]],
			10000
		),
		"neo-tree did not open"
	)
	child.lua([[(function()
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "markdown" then
				vim.api.nvim_set_current_win(win)
				return
			end
		end
		error("editor window not found")
	end)()]])

	local job = child.job.id
	child.api_notify.nvim_command("q")
	eq(vim.fn.jobwait({ job }, 5000)[1], 0)
end

T["file-tree: Project tree opening skips non-editor windows"] = function()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("DiffviewOpen")
	assert(
		child.wait(
			[[vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "DiffviewFiles"
	end)]],
			10000
		),
		"Diffview did not open"
	)
	child.cmd("vnew | edit " .. vim.fn.fnameescape(real_path("README.md")))
	local editor = child.api.nvim_get_current_win()
	child.wo.number = true
	child.cmd("Neotree filesystem")
	assert(
		child.wait(
			[[vim.iter(vim.api.nvim_list_wins()):any(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
		end)]],
			10000
		),
		"neo-tree did not open"
	)
	assert(
		child.wait(
			[[vim.iter(vim.api.nvim_list_wins()):all(function(win)
			return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) ~= "diffview://null"
		end)]],
			10000
		),
		"Diffview did not finish rendering"
	)
	child.cmd("copen")
	child.cmd("botright split | terminal")
	child.lua([[(function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			row = 1,
			col = 1,
			width = 20,
			height = 2,
			style = "minimal",
		})
	end)()]])
	local skipped = child.lua_get([[(function()
		return vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
			local buf = vim.api.nvim_win_get_buf(win)
			local name = vim.api.nvim_buf_get_name(buf)
			return vim.bo[buf].filetype == "neo-tree"
				or vim.bo[buf].filetype == "DiffviewFiles"
				or vim.bo[buf].buftype == "quickfix"
				or vim.bo[buf].buftype == "terminal"
				or vim.api.nvim_win_get_config(win).relative ~= ""
				or vim.wo[win].diff
				or vim.startswith(name, "diffview://")
		end):map(function(win)
			local buf = vim.api.nvim_win_get_buf(win)
			return { win, buf, vim.bo[buf].filetype .. ":" .. vim.api.nvim_buf_get_name(buf) }
		end):totable()
	end)()]])
	run_toggle()
	focus_tree_row("Makefile")

	child.api.nvim_input(vim.keycode("<CR>"))

	assert(child.wait(("vim.api.nvim_get_current_win() == %d"):format(editor)), "editor window was not focused")
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	for _, special in ipairs(skipped) do
		assert(child.api.nvim_win_get_buf(special[1]) == special[2], "special window replaced: " .. special[3])
	end
	eq(#project_tree_windows(), 1)
end

T["file-tree: A file cannot replace the project tree buffer"] = function()
	open_tree_on_makefile()
	local tree_win = child.api.nvim_get_current_win()
	local tree_buf = child.api.nvim_get_current_buf()

	child.cmd("edit " .. vim.fn.fnameescape(real_path("Makefile")))

	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	eq(child.bo.filetype, "make")
	eq(child.api.nvim_win_get_buf(tree_win), tree_buf)
	eq(child.lua_get([[vim.bo[...].filetype]], { tree_buf }), "gleb-file-tree")
end

T["file-tree: Project tree split windows keep editor options"] = MiniTest.new_set()

for _, case in ipairs({ { key = "v", title = "vertical split" }, { key = "s", title = "horizontal split" } }) do
	T["file-tree: Project tree split windows keep editor options"][case.title] = function()
		open_tree_on_makefile()

		child.type_keys(case.key)

		eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
		eq(child.wo.number, true)
		eq(child.wo.winfixwidth, false)
	end
end

T["file-tree: Project tree tab windows keep editor options"] = function()
	open_tree_on_makefile()
	local tabs = #child.api.nvim_list_tabpages()

	child.type_keys("t")

	eq(#child.api.nvim_list_tabpages(), tabs + 1)
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	eq(child.wo.number, true)
	eq(child.wo.winfixwidth, false)
end

T["file-tree: Project tree disables editor-only window features"] = function()
	edit("README.md")
	local editor_win = child.api.nvim_get_current_win()
	local editor_buf = child.api.nvim_get_current_buf()
	child.lua(
		[[(function(buf, win)
			require("ufo").attach(buf)
			vim.wo[win].foldenable = true
			vim.wo[win].foldmethod = "manual"
			vim.wo[win].statuscolumn = "%s"
		end)(...)]],
		{ editor_buf, editor_win }
	)
	eq(child.lua_get([[require("ufo").hasAttached(...)]], { editor_buf }), true)

	run_toggle()
	local tree_win = child.api.nvim_get_current_win()
	local tree_buf = child.api.nvim_get_current_buf()

	eq({ child.wo.foldenable, child.wo.foldmethod, child.wo.statuscolumn }, { false, "manual", "" })
	eq(child.lua_get([[require("ufo").hasAttached(...) == true]], { tree_buf }), false)
	eq(
		child.lua_get([[{ vim.wo[...].foldenable, vim.wo[...].foldmethod, vim.wo[...].statuscolumn }]], {
			editor_win,
			editor_win,
			editor_win,
		}),
		{ true, "manual", "%s" }
	)
	eq(child.api.nvim_get_current_win(), tree_win)
end

T["file-tree: Project tree preserves the original cursor setting"] = function()
	local original = "n-v:block,i:ver25"
	child.o.guicursor = original
	edit("README.md")

	run_toggle()
	eq(child.o.guicursor, "a:FileTreeHiddenCursor")
	child.cmd("normal! v")
	eq(child.o.guicursor, "a:FileTreeHiddenCursor")
	child.bo.modifiable = true
	child.type_keys("<Esc>", "i")
	eq(child.o.guicursor, original)
	child.type_keys("<Esc>")
	child.bo.modifiable = false
	eq(child.o.guicursor, "a:FileTreeHiddenCursor")

	child.cmd("wincmd l")
	eq(child.o.guicursor, original)
	run_toggle()
	eq(child.o.guicursor, "a:FileTreeHiddenCursor")
	run_toggle()
	eq(child.o.guicursor, original)
end

T["file-tree: Project tree Enter toggles a folder"] = function()
	edit("README.md")
	run_toggle()
	focus_tree_row("internal")

	child.type_keys("<CR>")
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("", 1, true) ~= nil]]), true)
	focus_tree_row(" billing")
	focus_tree_row(" money")

	focus_tree_row("internal")
	child.type_keys("<CR>")
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("", 1, true) ~= nil]]), true)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_buf_get_lines(0, 1, -1, false)):any(function(line)
		return line:find("billing", 1, true) or line:find("money", 1, true)
	end)]]),
		false
	)
end

T["file-tree: Project tree Enter opens a file in the editor window"] = function()
	edit("go.mod")
	run_toggle()
	local tree_win = child.api.nvim_get_current_win()
	local editor_win = child.lua_get([[vim.fn.win_getid(2)]])
	focus_tree_row("Makefile")

	child.type_keys("<CR>")

	eq(child.api.nvim_get_current_win(), editor_win)
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	eq(child.api.nvim_win_get_width(tree_win), 35)
	eq(#project_tree_windows(), 1)
end

T["file-tree: Project tree h on a file collapses its folder"] = function()
	edit("README.md")
	run_toggle()
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_row(" billing")
	child.type_keys("<CR>")
	focus_tree_row("invoice.go")

	child.type_keys("h")

	eq(child.lua_get([[vim.api.nvim_get_current_line():find("billing", 1, true) ~= nil]]), true)
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("", 1, true) ~= nil]]), true)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
		return line:find("invoice.go", 1, true)
	end)]]),
		false
	)
end

T["file-tree: Project tree q closes the tree"] = function()
	edit("README.md")
	local editor_win = child.api.nvim_get_current_win()
	run_toggle()

	child.type_keys("q")

	eq(project_tree_windows(), {})
	eq(child.api.nvim_get_current_win(), editor_win)
end

return T
