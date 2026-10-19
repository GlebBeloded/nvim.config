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
	F.disable_file_tree_nesting(child)
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
		}, { status = {}, ignored = {}, ignored_generation = 0, show_ignored = false })
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
	child.type_keys("<M-e>")
	local opened =
		child.lua_get([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]])
	if opened then
		assert(
			child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]])
		)
	end
end

local function open_changes_panel()
	child.lua([[require("gleb.git.changes").open({ root = ... })]], { root })
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view ~= nil and #view.rows > 0
			end)()]],
			math.ceil(3000 * H.load_factor())
		),
		"Changes panel did not draw its initial rows"
	)
end

local function reveal_project_tree()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.reveal"), "file_tree.reveal is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

local function enable_file_tree_nesting()
	child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], {
		vim.fs.joinpath(H.root, "settings", "file_tree.json"),
	})
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

local function open_approved_tree()
	edit("internal/billing/invoice.go")
	run_toggle()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and next(require("gleb.file_tree.git").status(view.root)) ~= nil
	end)()]],
			5000
		),
		"project-tree git status did not load"
	)
	for _, name in ipairs({ "cmd/server", "web", "src" }) do
		focus_tree_row(name)
		child.type_keys("<CR>")
	end
	focus_tree_row("invoice.go")
end

---@param needle string
---@return string[]
local function visible_groups_for(needle)
	return child.lua_get(
		[[(function(needle)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(needle, 1, true) then
					local groups = {}
					for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
						0, require("gleb.file_tree.render").namespace, { row - 1, 0 }, { row - 1, -1 }, { details = true }
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

---@param needle string
---@return boolean
local function has_tree_line(needle)
	return child.lua_get(
		[[(function(needle)
			return vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
				return line:find(needle, 1, true) ~= nil
			end)
		end)(...)]],
		{ needle }
	)
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
	local expected = "   billing  " .. vim.fn.fnamemodify(root, ":~")
	eq(lines()[1], expected)
	eq(groups_for("billing"), { "FileTreeExpander", "FileTreeFolderIcon", "FileTreeRoot", "FileTreeRootPath" })
end

T["file-tree: Project tree opens from non-project buffers"] = function()
	local outside = vim.fn.tempname()
	vim.fn.writefile({ "outside" }, outside)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(outside))

	local function expect_project_rows()
		local rows = child.lua_get([[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			return vim.iter(view.rows):map(function(row)
				return { kind = row.kind, label = row.label }
			end):totable()
		end)()]])
		eq(rows[1].kind, "root")
		eq(rows[1].label, vim.fs.basename(root))
		local labels = vim.tbl_map(function(row)
			return row.label
		end, vim.list_slice(rows, 2))
		for _, label in ipairs({ ".github/workflows", "cmd/server", "internal", "web", "go.mod", "README.md" }) do
			eq(vim.tbl_contains(labels, label), true)
		end
	end

	run_toggle()
	expect_project_rows()
	run_toggle()
	child.cmd("terminal")
	run_toggle()
	expect_project_rows()
	H.expect_no_neo_tree(child)
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
	H.expect_no_neo_tree(child)
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

T["file-tree: Project tree rows expose their highlight groups"] = function()
	open_approved_tree()

	eq(
		visible_groups_for("billing  "),
		{ "FileTreeExpander", "FileTreeFolderIcon", "FileTreeRoot", "FileTreeRootPath" }
	)
	eq(visible_groups_for(".github/workflows"), { "FileTreeExpander", "FileTreeFolderIcon", "FileTreeFolderName" })
	eq(visible_groups_for("internal"), { "FileTreeExpander", "FileTreeFolderIcon", "FileTreeGitModified" })
	eq(visible_groups_for("invoice.go"), { "DevIconGo", "FileTreeGitModified" })
	eq(visible_groups_for("tax.go"), { "DevIconGo", "FileTreeGitAdded" })
	eq(visible_groups_for("notes.md"), { "DevIconMd", "FileTreeGitUntracked" })
	eq(visible_groups_for("cart.tsx"), { "DevIconTsx", "FileTreeFileName" })
	eq(visible_groups_for("price.d.ts"), { "DevIconTypeScriptDeclaration", "FileTreeFileName" })
	eq(visible_groups_for("price.test.ts"), { "DevIconTestTs", "FileTreeFileName" })
	eq(visible_groups_for("price.ts"), { "DevIconTypeScript", "FileTreeGitModified" })
	eq(visible_groups_for("package-lock.json"), { "DevIconPackageLockJson", "FileTreeFileName" })
	eq(visible_groups_for("package.json"), { "DevIconPackageJson", "FileTreeFileName" })
	eq(visible_groups_for(".gitignore"), { "DevIconGitIgnore", "FileTreeFileName" })
	eq(visible_groups_for("go.mod"), { "DevIconGoMod", "FileTreeFileName" })
	eq(visible_groups_for("go.sum"), { "DevIconGoSum", "FileTreeFileName" })
	eq(visible_groups_for("Makefile"), { "DevIconMakefile", "FileTreeFileName" })
	eq(visible_groups_for("README.md"), { "DevIconReadme", "FileTreeFileName" })

	local colours = {
		FileTreeNormal = { fg = "#d4be98", bg = "#282828" },
		FileTreeRoot = { fg = "#ddc7a1", bold = true },
		FileTreeRootPath = { fg = "#928374" },
		FileTreeExpander = { fg = "#928374" },
		FileTreeFolderIcon = { fg = "#7daea3" },
		FileTreeFolderName = { fg = "#d4be98" },
		FileTreeFileName = { fg = "#d4be98" },
		FileTreeGitModified = { fg = "#7daea3" },
		FileTreeGitAdded = { fg = "#a9b665" },
		FileTreeGitUntracked = { fg = "#e78a4e" },
		FileTreeGitDeleted = { fg = "#928374" },
		FileTreeGitRenamed = { fg = "#89b482" },
		FileTreeGitConflict = { fg = "#ea6962" },
		FileTreeCursorLine = { bg = "#32302f" },
	}
	for group, expected in pairs(colours) do
		H.expect_hl_colors(child, group, expected)
	end
	assert(child.fn.execute("highlight FileTreeHiddenCursor"):find("blend=100", 1, true))

	local icons = {
		DevIconGo = "#00add8",
		DevIconTsx = "#1354bf",
		DevIconTypeScriptDeclaration = "#d59855",
		DevIconTestTs = "#519aba",
		DevIconTypeScript = "#519aba",
		DevIconPackageLockJson = "#7a0d21",
		DevIconPackageJson = "#e8274b",
		DevIconGitIgnore = "#f54d27",
		DevIconGoMod = "#00add8",
		DevIconGoSum = "#00add8",
		DevIconMakefile = "#6d8086",
		DevIconMd = "#dddddd",
		DevIconReadme = "#ededed",
	}
	for group, fg in pairs(icons) do
		H.expect_hl_colors(child, group, { fg = fg })
	end
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

T["file-tree: Project tree and changes panel close before the last editor"] = function()
	edit("README.md")
	run_toggle()
	child.cmd("wincmd l")
	open_changes_panel()
	eq(
		child.lua_get([[(function()
			return #vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
				local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
				return filetype == "gleb-file-tree" or filetype == "gleb-changes"
			end):totable()
		end)()]]),
		2
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
	edit("README.md")
	run_toggle()
	local tree = child.api.nvim_get_current_win()
	child.cmd("wincmd l")
	child.cmd("terminal")
	local terminal = child.api.nvim_get_current_win()
	child.api.nvim_set_current_win(tree)
	focus_tree_row("Makefile")
	child.type_keys("<CR>")

	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	assert(
		child.api.nvim_win_get_position(0)[2] > child.api.nvim_win_get_position(tree)[2],
		"editor was not created right of tree"
	)
	eq(child.bo.buftype, "")
	eq(child.api.nvim_win_is_valid(terminal), true)

	child.cmd("tabnew")
	child.cmd("tabprevious | tabclose!")
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
	open_changes_panel()
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
			return vim.bo[buf].filetype == "gleb-changes"
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
	reveal_project_tree()
	assert(child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]]))
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

	child.cmd("terminal")
	child.api.nvim_set_current_win(tree_win)
	child.cmd("edit " .. vim.fn.fnameescape(real_path("README.md")))

	eq(child.api.nvim_buf_get_name(0), real_path("README.md"))
	eq(child.api.nvim_win_get_buf(tree_win), tree_buf)
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

	child.cmd("tabnew")
	edit("Makefile")
	run_toggle()
	child.cmd("tabprevious")
	run_toggle()
	child.cmd("tabnext")
	eq(child.bo.filetype, "gleb-file-tree")
	eq(child.o.guicursor, "a:FileTreeHiddenCursor")
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

T["file-tree: Project tree zo and zc fold without an error"] = function()
	edit("README.md")
	run_toggle()
	focus_tree_row("internal")
	if has_tree_line(" billing") then
		child.type_keys("<CR>")
		focus_tree_row("internal")
	end
	child.lua([[vim.v.errmsg = ""]])

	local open_ok = pcall(child.type_keys, "zo")
	local after_open = { has_tree_line(" billing"), open_ok, child.lua_get([[vim.v.errmsg]]) }
	local close_ok = pcall(child.type_keys, "zc")
	local after_close = { has_tree_line(" billing"), close_ok, child.lua_get([[vim.v.errmsg]]) }

	eq({ after_open, after_close }, {
		{ true, true, "" },
		{ false, true, "" },
	})
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

	run_toggle()
	local tree_win = child.api.nvim_get_current_win()
	child.cmd("wincmd l | terminal")
	local terminal_win = child.api.nvim_get_current_win()
	child.api.nvim_set_current_win(tree_win)
	child.type_keys("q")

	eq(project_tree_windows(), {})
	eq(child.bo.buftype, "")
	eq(child.api.nvim_win_is_valid(terminal_win), true)
end

local function assert_registered_action(id)
	eq(child.lua_get([[require("gleb.actions").state.applicator.catalog:get(...) ~= nil]], { id }), true)
end

T["file-tree: Project tree v opens a vertical split"] = function()
	open_tree_on_makefile()
	local editor_win = child.lua_get([[vim.fn.win_getid(2)]])
	local editor_position = child.api.nvim_win_get_position(editor_win)

	child.type_keys("v")

	local opened_position = child.api.nvim_win_get_position(0)
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	eq(opened_position[1], editor_position[1])
	assert(opened_position[2] ~= editor_position[2], "file was not opened in a vertical split")
	assert_registered_action("file_tree.open_vsplit")
end

T["file-tree: Project tree s opens a horizontal split"] = function()
	open_tree_on_makefile()
	local editor_win = child.lua_get([[vim.fn.win_getid(2)]])
	local editor_position = child.api.nvim_win_get_position(editor_win)

	child.type_keys("s")

	local opened_position = child.api.nvim_win_get_position(0)
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	eq(opened_position[2], editor_position[2])
	assert(opened_position[1] ~= editor_position[1], "file was not opened in a horizontal split")
	assert_registered_action("file_tree.open_split")
end

T["file-tree: Project tree t opens a new tab"] = function()
	open_tree_on_makefile()
	local tabs = #child.api.nvim_list_tabpages()

	child.type_keys("t")

	eq(#child.api.nvim_list_tabpages(), tabs + 1)
	eq(child.api.nvim_buf_get_name(0), real_path("Makefile"))
	assert_registered_action("file_tree.open_tab")
end

T["file-tree: Project tree keys come from the keymap file"] = function()
	edit("README.md")
	run_toggle()
	local actual = child.lua_get([[
(function()
	local maps = {}
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
		maps[map.lhs] = map.desc
	end
	local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
		vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
	return { maps = maps, keys = shortcuts["file_tree.open"] }
end)()
]])
	eq(actual.keys, { "<CR>", "o", "l" })
	for _, lhs in ipairs(actual.keys) do
		eq(actual.maps[lhs] or actual.maps[vim.keycode(lhs)], "Project: Open")
	end
	H.expect_no_neo_tree(child)

	child.type_keys("<M-A>")
	assert(
		child.wait(
			[[MiniPick.is_picker_active() and vim.api.nvim_get_current_win() == MiniPick.get_picker_state().windows.main]],
			5000
		),
		"Find Action picker did not open"
	)
	child.type_keys("project open")
	assert(child.wait([[table.concat(MiniPick.get_picker_query()) == "project open"]], 5000), "query was not processed")
	assert(
		child.wait(
			[[
(function()
	local matches = MiniPick.get_picker_matches()
	local row = matches and require("gleb.find_action.palette").state.rows[matches.current_ind]
	return row and row.action and row.action.id == "file_tree.open"
end)()
]],
			5000
		),
		"Project Open action did not match"
	)
	child.lua([[
		local actions = require("gleb.actions")
		local shortcut_path = vim.fn.tempname()
		vim.fn.writefile({ vim.json.encode(actions.state.store.last_good) }, shortcut_path)
		actions.state.store.path = shortcut_path
		vim.schedule(function()
			vim.api.nvim_feedkeys(vim.keycode("<F23><CR>"), "t", false)
		end)
		local catalog = actions.state.applicator.catalog
		require("gleb.find_action.assign").open(assert(catalog:get("file_tree.open")))
	]])
	assert(
		child.wait([[require("gleb.actions").state.store.last_good["file_tree.open"][4] == "<F23>"]], 5000),
		"Project Open shortcut was not saved"
	)
	child.type_keys("<Esc>")

	eq(child.lua_get([[vim.fn.maparg("<F23>", "n", false, true).desc]]), "Project: Open")
	focus_tree_row("internal")
	child.type_keys("<F23>")
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("", 1, true) ~= nil]]), true)
end

T["file-tree: Project tree za on a file collapses its folder"] = function()
	enable_file_tree_nesting()
	edit("README.md")
	run_toggle()
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_row(" billing")
	child.type_keys("<CR>")
	focus_tree_row("tax.go")

	child.type_keys("za")

	eq(child.lua_get([[vim.api.nvim_get_current_line():find("tax.go", 1, true) ~= nil]]), true)
	eq(has_tree_line("tax_test.go"), true)
end

T["file-tree: Project tree zM collapses every folder"] = function()
	enable_file_tree_nesting()
	edit("README.md")
	run_toggle()
	focus_tree_row("cmd/server")
	child.type_keys("<CR>")
	focus_tree_row("internal")
	child.type_keys("<CR>")
	focus_tree_row(" billing")
	child.type_keys("<CR>")
	focus_tree_row("web")
	child.type_keys("<CR>")
	focus_tree_row("invoice.go")
	child.type_keys("za")
	eq(has_tree_line("invoice_test.go"), true)
	focus_tree_row("invoice.go")

	child.type_keys("zM")

	eq(has_tree_line("invoice.go"), false)
	eq(has_tree_line("invoice_test.go"), false)
	eq(has_tree_line(" billing"), false)
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("internal", 1, true) ~= nil]]), true)
	eq(
		child.lua_get([[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
			if not lines[1]:find("", 1, true) then
				return false
			end
			return vim.iter(view.rows):enumerate():all(function(index, row)
				return row.kind ~= "directory" or lines[index]:find("", 1, true) ~= nil
			end)
		end)()]]),
		true
	)
end

T["file-tree: Project tree has no trailing blank row"] = function()
	edit("README.md")
	run_toggle()
	local line_count = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return { vim.api.nvim_buf_line_count(view.buf), #view.rows }
	end)()]])

	child.type_keys("G")
	child.type_keys("zM")

	eq(line_count[1], line_count[2])
end

T["file-tree: Project tree zR expands every folder"] = function()
	enable_file_tree_nesting()
	edit("README.md")
	run_toggle()

	child.type_keys("zR")

	eq(has_tree_line("invoice.go"), true)
	eq(has_tree_line("invoice_test.go"), true)
	eq(has_tree_line("money.go"), true)
	eq(has_tree_line("money_test.go"), true)
	eq(has_tree_line("cart.tsx"), true)
	eq(has_tree_line("price.test.ts"), true)
	eq(
		child.lua_get([[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
			return vim.iter(view.rows):enumerate():all(function(index, row)
				return row.kind ~= "directory" or lines[index]:find("", 1, true) ~= nil
			end)
		end)()]]),
		true
	)
end

T["file-tree: Project tree unfold all stops at the row limit"] = function()
	enable_file_tree_nesting()
	local oversized = vim.fs.joinpath(root, "oversized")
	for folder_index = 1, 60 do
		local folder = ("folder-%02d"):format(folder_index)
		local directory = vim.fs.joinpath(oversized, folder)
		vim.fn.mkdir(directory, "p")
		for index = 1, 100 do
			local file = assert(vim.uv.fs_open(vim.fs.joinpath(directory, ("file-%04d"):format(index)), "w", 420))
			assert(vim.uv.fs_close(file))
		end
	end
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_toggle()

	child.type_keys("zR")

	assert(#child.api.nvim_buf_get_lines(0, 0, -1, false) <= 5000, "unfold all exceeded the row limit")
	eq(notifications(), {
		{ msg = "Unfold all stopped at 5000 rows", level = vim.log.levels.WARN },
	})
	local expanded =
		child.lua_get([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded]])
	eq(expanded.oversized, true)
	eq(expanded["oversized/folder-01"], true)
	eq(expanded["oversized/folder-60"], nil)
end

T["file-tree: Project tree manual expansion stops at the row limit"] = function()
	local oversized = vim.fs.joinpath(root, "oversized")
	vim.fn.mkdir(oversized, "p")
	for index = 1, 5000 do
		local file = assert(vim.uv.fs_open(vim.fs.joinpath(oversized, ("file-%04d"):format(index)), "w", 420))
		assert(vim.uv.fs_close(file))
	end
	child.lua([[require("gleb.file_tree.fs").reset()]])
	local notifications = H.record_notify(child)
	edit("README.md")
	run_toggle()
	focus_tree_row("oversized")

	child.type_keys("<CR>")

	assert(#child.api.nvim_buf_get_lines(0, 0, -1, false) <= 5001, "manual expansion exceeded the row limit")
	eq(notifications(), {
		{ msg = "Expansion stopped at 5000 rows", level = vim.log.levels.WARN },
	})
	local expanded =
		child.lua_get([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded]])
	eq(expanded.oversized, nil)
end

return T
