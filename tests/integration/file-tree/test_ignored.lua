local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function start()
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param ignore string[]
---@return string
local function settings_file(ignore)
	local path = vim.fn.tempname() .. ".json"
	local settings =
		vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "settings", "file_tree.json")), "\n"))
	settings.ignore = ignore
	vim.fn.writefile({ vim.json.encode(settings) }, path)
	return path
end

---@param project_root string
---@param settings_path string
---@param wait_for_initial_draw? boolean
local function open_tree(project_root, settings_path, wait_for_initial_draw)
	root = project_root
	child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], { settings_path })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	local initial = vim.uv.fs_stat(vim.fs.joinpath(root, "README.md")) and "README.md" or "index.js"
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, initial)))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	if wait_for_initial_draw == false then
		return
	end
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and #view.rows > 0
			end)()]],
			3000
		),
		"file tree did not draw its initial rows"
	)
end

---@param relative string
local function focus_tree_path(relative)
	local found = child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.path == path then
					vim.api.nvim_set_current_win(view.win)
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

---@param relative string
local function expand(relative)
	focus_tree_path(relative)
	child.type_keys("<CR>")
end

---@return string[]
local function labels()
	return child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return vim.tbl_map(function(row) return row.label end, view.rows)
	end)()]])
end

---@param label string
---@return boolean
local function has_label(label)
	return vim.tbl_contains(labels(), label)
end

---@param label string
---@param present boolean
local function wait_for_label(label, present)
	assert(
		child.wait(
			([[(function(label, present)
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then return false end
				local found = vim.iter(view.rows):any(function(row) return row.label == label end)
				return found == present
			end)(%q, %s)]]):format(label, tostring(present)),
			3000
		),
		("tree label %s did not become %s"):format(label, present and "visible" or "hidden")
	)
end

local function wait_for_git()
	assert(
		child.wait(
			[[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local git = require("gleb.file_tree.git")
			local state = git.state.roots[view.root]
			return state
				and git.state.runs > 0
				and state.timer == nil
				and not state.in_flight
				and not view.dirty
				and view.dirty_timer == nil
				and not view.git_pending
		end)()]],
			math.ceil(3000 * H.load_factor())
		),
		"git status did not finish"
	)
end

---@param relative string
---@return table?
local function row_for(relative)
	return child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for _, row in ipairs(view.rows) do
				if row.path == path then return row end
			end
		end)(...)]],
		{ vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), relative) }
	)
end

---@param relative string
---@return string[]
local function row_groups(relative)
	return child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.path == path then
					return vim.tbl_map(function(mark)
						return mark[4].hl_group
					end, vim.api.nvim_buf_get_extmarks(
						view.buf,
						require("gleb.file_tree.render").namespace,
						{ index - 1, 0 },
						{ index - 1, -1 },
						{ details = true }
					))
				end
			end
			return {}
		end)(...)]],
		{ vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), relative) }
	)
end

---@return table
local function tree_state()
	return child.lua_get(
		[=[(function(timeout)
		local expanded = require("gleb.file_tree.expanded")
		expanded.flush()
		assert(vim.wait(timeout, function()
			return not expanded.state.writing and next(expanded.state.pending) == nil
		end, 20), "expanded state did not settle")
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local cursor = vim.api.nvim_win_get_cursor(view.win)
		local state_path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "expanded.json")
		local stored = vim.uv.fs_stat(state_path)
			and vim.json.decode(table.concat(vim.fn.readfile(state_path), "\n"))[view.root]
			or nil
		return {
			cursor_line = cursor[1],
			expanded = vim.deepcopy(view.expanded),
			expanded_nests = vim.deepcopy(view.expanded_nests),
			selected = view.rows[cursor[1]].path,
			stored = stored,
		}
	end)(...)]=],
		{ math.ceil(1000 * H.load_factor()) }
	)
end

---@param query string
local function add(query)
	child.type_keys("a")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Add picker did not open")
	child.type_keys(query, "<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Add picker did not close")
end

---@param query string
local function rename(query)
	child.type_keys("r")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Rename picker did not open")
	child.type_keys("<C-u>", query, "<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Rename picker did not close")
end

T["file-tree: File under hidden node_modules is not revealed"] = MiniTest.new_set()

T["file-tree: File under hidden node_modules is not revealed"]["keeps tree state while editing the hidden file"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	expand("web/src")
	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(project, "web/src/cart.tsx")))
	focus_tree_path("web/src/cart.tsx")
	local before = tree_state()
	local target = vim.fs.joinpath(project, "web/node_modules/left-pad/index.js")

	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(target))

	eq(child.api.nvim_buf_get_name(0), assert(vim.uv.fs_realpath(target)))
	eq(tree_state(), before)
end

T["file-tree: Hidden ignored file is not revealed"] = MiniTest.new_set()

T["file-tree: Hidden ignored file is not revealed"]["keeps rows and cursor while editing the hidden file"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("internal")
	expand("internal/billing")
	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(project, "internal/billing/invoice.go")))
	focus_tree_path("internal/billing/invoice.go")
	local rows_before = labels()
	local state_before = tree_state()
	local target = vim.fs.joinpath(project, ".env")

	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(target))

	eq(child.api.nvim_buf_get_name(0), assert(vim.uv.fs_realpath(target)))
	eq(labels(), rows_before)
	eq(tree_state(), state_before)
end

T["file-tree: Created or renamed ignored target is not selected"] = MiniTest.new_set()

T["file-tree: Created or renamed ignored target is not selected"]["keeps tree state after the real create action"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	focus_tree_path("web")
	local before = tree_state()
	local target = vim.fs.joinpath(project, "web/node_modules/left-pad/new.js")

	add("node_modules/left-pad/new.js")

	assert(vim.uv.fs_stat(target), "create action did not create the ignored target")
	eq(tree_state(), before)
end

T["file-tree: Created or renamed ignored target is not selected"]["keeps tree state after the real rename action"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, { ["web/pending.js"] = "pending\n" })
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	focus_tree_path("web/pending.js")
	local before = tree_state()
	local above = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local line = vim.api.nvim_win_get_cursor(view.win)[1]
		return view.rows[line - 1].path
	end)()]])
	local target = vim.fs.joinpath(project, "web/node_modules/left-pad/new.js")

	rename("node_modules/left-pad/new.js")

	assert(vim.uv.fs_stat(target), "rename action did not create the ignored target")
	local after = tree_state()
	eq(after.selected, above)
	eq(after.expanded, before.expanded)
	eq(after.expanded_nests, before.expanded_nests)
	eq(after.stored, before.stored)
	assert(after.selected ~= assert(vim.uv.fs_realpath(target)), "ignored rename target was selected")
end

T["file-tree: First paint waits for ignored status"] = MiniTest.new_set()

T["file-tree: First paint waits for ignored status"]["omits ignored entries from the first frame"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	local status = vim.system({
		"git",
		"--no-optional-locks",
		"-C",
		project,
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=normal",
		"--ignored=matching",
	}, { text = true }):wait()
	eq(status.code, 0)
	child.lua([[require("gleb.file_tree.expanded").save(assert(vim.uv.fs_realpath(...)), { web = true })]], { project })
	child.lua(
		[[
		local status_output = ...
		local view = require("gleb.file_tree.view")
		view.state.initial_status_hook = function(complete)
			_G.file_tree_release_initial_status = complete
		end
		local original_system = vim.system
		vim.system = function(command, options, callback)
			if callback and command[4] == "rev-parse" and command[5] == "--show-prefix" then
				vim.schedule(function() callback({ code = 0, stdout = "", stderr = "" }) end)
				return {}
			end
			if callback and command[5] == "status" then
				vim.schedule(function() callback({ code = 0, stdout = status_output, stderr = "" }) end)
				return {}
			end
			return original_system(command, options, callback)
		end
		_G.file_tree_draw_frames = {}
		local render = require("gleb.file_tree.render")
		local original_draw = render.draw
		render.draw = function(buf, rows)
			_G.file_tree_draw_frames[#_G.file_tree_draw_frames + 1] =
				vim.tbl_map(function(row) return row.label end, rows)
			original_draw(buf, rows)
		end
	]],
		{ status.stdout }
	)
	open_tree(project, settings_file({}), false)
	assert(
		child.wait([[_G.file_tree_release_initial_status ~= nil]], math.ceil(3000 * H.load_factor())),
		"initial status completion was not held"
	)
	eq(child.lua_get([[#_G.file_tree_draw_frames]]), 0)
	child.lua([[
		local release = assert(_G.file_tree_release_initial_status)
		_G.file_tree_release_initial_status = nil
		release()
	]])
	assert(
		child.wait([[#_G.file_tree_draw_frames > 0]], math.ceil(3000 * H.load_factor())),
		"file tree did not draw after initial status completed"
	)
	wait_for_git()

	local first_frame = child.lua_get([=[_G.file_tree_draw_frames[1]]=])
	assert(first_frame, "file tree did not draw")
	eq(vim.tbl_contains(first_frame, "bin"), false)
	eq(vim.tbl_contains(first_frame, "node_modules"), false)
	eq(vim.tbl_contains(first_frame, ".env"), false)
end

T["file-tree: Ignored entries are hidden by default"] = MiniTest.new_set()

T["file-tree: Ignored entries are hidden by default"]["filters repository ignored rows without a hint"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	wait_for_label("bin", false)
	expand("web")

	eq(has_label("bin"), false)
	eq(has_label("node_modules"), false)
	eq(has_label(".env"), false)
	eq(has_label(".git"), false)
	local web_children = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local children = {}
		local web_depth
		for _, row in ipairs(view.rows) do
			if row.path == vim.fs.joinpath(view.root, "web") then
				web_depth = row.depth
			elseif web_depth and row.depth <= web_depth then
				break
			elseif web_depth and row.depth == web_depth + 1 then
				children[#children + 1] = row.label
			end
		end
		return children
	end)()]])
	eq(web_children, { "src", "package.json" })
	eq(
		vim.iter(labels()):any(function(label)
			return label:lower():find("ignored", 1, true) ~= nil
		end),
		false
	)
end

T["file-tree: Tracked files matching gitignore stay listed"] = MiniTest.new_set()

T["file-tree: Tracked files matching gitignore stay listed"]["keeps forced tracked matches and hides untracked matches"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, {
		["internal/billing/audit.log"] = "tracked\n",
		["internal/billing/debug.log"] = "ignored\n",
	})
	H.git(project, { "add", "-f", "internal/billing/audit.log" })
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("internal")
	expand("internal/billing")
	wait_for_label("debug.log", false)

	eq(has_label("audit.log"), true)
	eq(has_label("debug.log"), false)
	local audit = assert(row_for("internal/billing/audit.log"))
	eq(audit.ignored, false)
	eq(audit.status, "added")
end

T["file-tree: Editing gitignore updates ignored entries"] = MiniTest.new_set()

T["file-tree: Editing gitignore updates ignored entries"]["refreshes ignored state after writing gitignore"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	local generation = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return require("gleb.file_tree.git").ignored_generation(view.root)
	end)()]])
	local runs = child.lua_get([[require("gleb.file_tree.git").state.runs]])
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		require("gleb.file_tree.git").refresh(view.root)
	]])
	assert(child.wait(([[require("gleb.file_tree.git").state.runs > %d]]):format(runs), 3000), "refresh did not run")
	wait_for_git()
	eq(
		child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return require("gleb.file_tree.git").ignored_generation(view.root)
	end)()]]),
		generation
	)
	wait_for_label("notes.md", true)
	child.lua(
		[[
		local path = ...
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(vim.iter(vim.api.nvim_tabpage_list_wins(view.tab)):find(function(win)
			return win ~= view.win
		end))
		vim.api.nvim_win_call(editor, function()
			vim.cmd.edit(vim.fn.fnameescape(path))
			vim.api.nvim_buf_set_lines(0, -1, -1, false, { "notes.md" })
		end)
	]],
		{ vim.fs.joinpath(project, ".gitignore") }
	)
	focus_tree_path("notes.md")
	child.lua([[
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(vim.iter(vim.api.nvim_tabpage_list_wins(view.tab)):find(function(win)
			return win ~= view.win
		end))
		vim.api.nvim_win_call(editor, function() vim.cmd.write() end)
	]])
	wait_for_label("notes.md", false)
	eq(tree_state().selected, vim.fs.joinpath(assert(vim.uv.fs_realpath(project)), "Makefile"))
	eq(
		child.lua_get(
			[[(function(generation)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		return require("gleb.file_tree.git").ignored_generation(view.root) > generation
	end)(...)]],
			{ generation }
		),
		true
	)
end

T["file-tree: Nested gitignore and negation are honoured"] = MiniTest.new_set()

T["file-tree: Nested gitignore and negation are honoured"]["keeps the negated nested path"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, {
		["web/.gitignore"] = "generated/*\n!generated/keep.ts\n",
		["web/generated/drop.ts"] = "drop\n",
		["web/generated/keep.ts"] = "keep\n",
	})
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	wait_for_label("generated", true)
	expand("web/generated")
	wait_for_label("drop.ts", false)

	eq(has_label("keep.ts"), true)
	eq(has_label("drop.ts"), false)
end

T["file-tree: Tree root inside an ignored folder stays visible"] = MiniTest.new_set()

T["file-tree: Tree root inside an ignored folder stays visible"]["does not inherit ignore state from ancestors above the root"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	local nested_root = vim.fs.joinpath(project, "web/node_modules/left-pad")
	open_tree(nested_root, settings_file({}))
	wait_for_git()
	wait_for_label("index.js", true)

	eq(labels(), { "left-pad", "index.js" })
	eq(assert(row_for("index.js")).ignored, false)
	eq(
		child.lua_get(
			[[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows[1].ignored]]
		),
		false
	)
end

T["file-tree: Folder with only ignored content stays listed"] = MiniTest.new_set()

T["file-tree: Folder with only ignored content stays listed"]["keeps the empty visible folder"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, { ["generated/debug.log"] = "ignored\n" })
	open_tree(project, settings_file({}))
	wait_for_git()
	wait_for_label("generated", true)

	local generated = assert(row_for("generated"))
	eq(generated.empty, true)
	eq(generated.ignored, false)
	focus_tree_path("generated")
	child.type_keys("<CR>")
	eq(has_label("debug.log"), false)
end

T["file-tree: Ignored sets follow normalized roots across tabs"] = MiniTest.new_set()

T["file-tree: Ignored sets follow normalized roots across tabs"]["maps snapshots for repository and subdirectory roots"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	local normalized = assert(vim.uv.fs_realpath(project))
	assert(project:match("^/var/"), "fixture path is not under /var: " .. project)
	assert(normalized:match("^/private/var/"), "fixture path was not normalized through /private/var: " .. normalized)
	local settings_path = settings_file({})
	open_tree(project, settings_path)
	wait_for_git()
	wait_for_label("bin", false)
	expand("web")
	eq(has_label("node_modules"), false)

	child.cmd("tabnew")
	open_tree(vim.fs.joinpath(project, "web"), settings_path)
	wait_for_git()
	wait_for_label("node_modules", false)
	eq(has_label("package.json"), true)
	eq(has_label("node_modules"), false)
end

T["file-tree: Settings ignore patterns hide entries"] = MiniTest.new_set()

T["file-tree: Settings ignore patterns hide entries"]["filters names and root-relative paths before nesting"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, {
		["notes.md.swp"] = "swap\n",
		["cmd/server/main.go.swp"] = "swap\n",
	})
	open_tree(project, settings_file({ "*.swp", "web/src/*.d.ts" }))
	expand("cmd/server")
	expand("web")
	expand("web/src")
	focus_tree_path("web/src/price.ts")
	child.type_keys("za")

	eq(has_label("notes.md.swp"), false)
	eq(has_label("main.go.swp"), false)
	eq(has_label("price.d.ts"), false)
	eq(has_label("price.test.ts"), true)
end

T["file-tree: Ignored nest children leave no chevron"] = MiniTest.new_set()

T["file-tree: Ignored nest children leave no chevron"]["removes the ignored child before building its nest"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({ "package-lock.json" }))
	expand("web")

	local package = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for _, row in ipairs(view.rows) do
			if row.label == "package.json" then return { row.label, row.nest_children } end
		end
	end)()]])
	eq(package, { "package.json" })
	eq(has_label("package-lock.json"), false)
end

T["file-tree: Ignore patterns apply outside a git repository"] = MiniTest.new_set()

T["file-tree: Ignore patterns apply outside a git repository"]["filters without requesting git status"] = function()
	local project = vim.fn.tempname()
	vim.fn.mkdir(project, "p")
	H.write_files(project, {
		["README.md"] = "# scratch\n",
		["main.go"] = "package main\n",
		["scratch.swp"] = "swap\n",
	})
	local notifications = H.record_notify(child)
	open_tree(project, settings_file({ "*.swp" }))

	eq(has_label("main.go"), true)
	eq(has_label("scratch.swp"), false)
	eq(child.lua_get([[require("gleb.file_tree.git").state.last_cmd]]), vim.NIL)
	eq(notifications(), {})
end

T["file-tree: I toggles ignored entries"] = MiniTest.new_set()

T["file-tree: I toggles ignored entries"]["shows and hides ignored rows through the tree mapping"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")

	child.type_keys("I")
	wait_for_label("bin", true)
	eq(has_label("node_modules"), true)
	eq(has_label(".env"), true)
	local shown = labels()
	eq(vim.fn.index(shown, "bin") + 1, vim.fn.index(shown, ".github/workflows") + 2)
	eq(vim.fn.index(shown, "node_modules") + 1, vim.fn.index(shown, "src") + 0)
	eq(vim.fn.index(shown, ".env") + 1, vim.fn.index(shown, ".gitignore") + 0)

	child.type_keys("I")
	wait_for_label("bin", false)
	eq(has_label("node_modules"), false)
	eq(has_label(".env"), false)
end

T["file-tree: I toggles ignored entries"]["expands a settings-ignored nest child through the tree mapping"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({ "package-lock.json" }))
	expand("web")
	focus_tree_path("web/package.json")

	child.type_keys("I")
	child.type_keys("za")

	eq(has_label("package-lock.json"), true)
end

T["file-tree: I toggles ignored entries"]["reveals a settings-ignored nest child from the editor"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({ "package-lock.json" }))
	expand("web")
	child.type_keys("I")

	child.cmd("wincmd l")
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(project, "web/package-lock.json")))

	wait_for_label("package-lock.json", true)
	eq(has_label("package-lock.json"), true)
	eq(
		child.lua_get([[(function()
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			local index = vim.api.nvim_win_get_cursor(view.win)[1]
			return view.rows[index].label
		end)()]]),
		"package-lock.json"
	)
end

T["file-tree: Show Ignored is a Find Action toggle"] = MiniTest.new_set()

T["file-tree: Show Ignored is a Find Action toggle"]["toggles in place through the real picker"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")

	child.type_keys("<M-A>")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Find Action did not open")
	child.type_keys("show ignored")
	assert(
		child.wait([[(MiniPick.get_picker_matches().current or {}).action.id == "file_tree.show_ignored"]]),
		"Show Ignored did not match"
	)
	child.type_keys("<CR>")
	assert(child.wait([[MiniPick.is_picker_active()]]), "toggle closed Find Action")
	eq(child.lua_get([[MiniPick.get_picker_matches().current.glyph]]), true)
	eq(
		child.lua_get([[(function()
			local state = MiniPick.get_picker_state()
			local line = vim.api.nvim_buf_get_lines(state.buffers.main, 0, 1, false)[1]
			return line:find("●", 1, true) ~= nil
		end)()]]),
		true
	)
	child.type_keys("<Esc>")
	wait_for_label("bin", true)
	eq(has_label("node_modules"), true)
	eq(has_label(".env"), true)
end

T["file-tree: Show Ignored persists"] = MiniTest.new_set()

T["file-tree: Show Ignored persists"]["saves and survives closing the tree"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()

	child.type_keys("I")
	wait_for_label("bin", true)
	child.type_keys("q")
	assert(child.wait([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]]))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	wait_for_label("bin", true)
	eq(
		child.lua_get([[(function()
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "view.json")
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	end)()]]),
		{ show_ignored = true }
	)
end

T["file-tree: Saved Show Ignored state is restored"] = MiniTest.new_set()

T["file-tree: Saved Show Ignored state is restored"]["loads the saved value on first open"] = function()
	child.lua([[
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "view.json")
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile({ '{"show_ignored":true}' }, path)
	]])
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	wait_for_label("bin", true)

	eq(has_label("bin"), true)
	eq(has_label(".env"), true)
end

T["file-tree: Hiding the selected ignored row moves upward"] = MiniTest.new_set()

T["file-tree: Hiding the selected ignored row moves upward"]["selects the nearest listed row above"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	child.type_keys("I")
	wait_for_label("node_modules", true)
	focus_tree_path("web/node_modules")
	local above = child.lua_get([[(function()
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local line = vim.api.nvim_win_get_cursor(view.win)[1]
		return view.rows[line - 1].path
	end)()]])

	child.type_keys("I")
	wait_for_label("node_modules", false)
	eq(tree_state().selected, above)
end

T["file-tree: Ignored rows are grey italic"] = MiniTest.new_set()

T["file-tree: Ignored rows are grey italic"]["uses the ignored group for names and icons"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	expand("web")
	child.type_keys("I")
	wait_for_label("node_modules", true)

	eq(row_groups("bin"), { "FileTreeExpander", "FileTreeIgnored", "FileTreeIgnored" })
	eq(row_groups("web/node_modules"), { "FileTreeExpander", "FileTreeIgnored", "FileTreeIgnored" })
	eq(row_groups(".env"), { "FileTreeIgnored", "FileTreeIgnored" })
	H.expect_hl_colors(child, "FileTreeIgnored", { fg = "#7c6f64" })
	eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = "FileTreeIgnored", link = false }).italic]]), true)
end

T["file-tree: Settings-ignored entries do not tint folders or nests"] = MiniTest.new_set()

T["file-tree: Settings-ignored entries do not tint folders or nests"]["keeps ignored descendants out of aggregate colours"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	H.write_files(project, {
		["cmd/server/main.go.swp"] = "swap\n",
		["cmd/server/main_mock.go"] = "package main\n",
	})
	open_tree(project, settings_file({ "*.swp", "main_mock.go" }))
	wait_for_git()
	expand("cmd/server")

	eq(vim.tbl_contains(row_groups("cmd/server"), "FileTreeGitUntracked"), false)
	child.type_keys("I")
	eq(vim.tbl_contains(row_groups("cmd/server"), "FileTreeGitUntracked"), false)
	eq(vim.tbl_contains(row_groups("cmd/server/main.go"), "FileTreeGitUntracked"), false)
end

T["file-tree: Unfold all leaves ignored folders collapsed"] = MiniTest.new_set()

T["file-tree: Unfold all leaves ignored folders collapsed"]["does not descend into ignored directories"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	child.type_keys("I")
	wait_for_label("bin", true)

	child.type_keys("zR")

	local bin = assert(row_for("bin"))
	local node_modules = assert(row_for("web/node_modules"))
	eq({ bin.expanded, bin.empty }, { false, false })
	eq({ node_modules.expanded, node_modules.empty }, { false, false })
	eq(has_label("server"), false)
	eq(has_label("left-pad"), false)
end

T["file-tree: Project tree unfold all preserves skipped expansion state"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	child.type_keys("I")
	wait_for_label("bin", true)
	expand("web")
	expand("web/node_modules")
	eq(has_label("left-pad"), true)

	child.type_keys("zR")

	local node_modules = assert(row_for("web/node_modules"))
	eq(node_modules.expanded, true)
	eq(has_label("left-pad"), true)
end

T["file-tree: Expanded ignored folder lists ignored children"] = MiniTest.new_set()

T["file-tree: Expanded ignored folder lists ignored children"]["inherits ignored state without another git call"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	open_tree(project, settings_file({}))
	wait_for_git()
	child.type_keys("I")
	wait_for_label("bin", true)
	child.lua([[
		_G.file_tree_system_calls = {}
		local original_system = vim.system
		vim.system = function(command, options, callback)
			_G.file_tree_system_calls[#_G.file_tree_system_calls + 1] = command
			return original_system(command, options, callback)
		end
	]])

	focus_tree_path("bin")
	child.type_keys("za")

	eq(has_label("server"), true)
	eq(row_groups("bin/server"), { "FileTreeIgnored", "FileTreeIgnored" })
	eq(
		child.lua_get([[vim.iter(_G.file_tree_system_calls):any(function(command) return command[1] == "git" end)]]),
		false
	)
end

T["file-tree: Ignored folders do not compact or consume unfold budget"] = MiniTest.new_set()

T["file-tree: Ignored folders do not compact or consume unfold budget"]["counts only listed rows near the cap"] = function()
	local project = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	for index = 1, 4870 do
		local path = vim.fs.joinpath(project, ("budget-%04d.txt"):format(index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
	for index = 1, 150 do
		local path = vim.fs.joinpath(project, "bin", ("ignored-%04d.txt"):format(index))
		local file = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_close(file))
	end
	open_tree(project, settings_file({}))
	wait_for_git()
	child.type_keys("I")
	wait_for_label("bin", true)
	local notifications = H.record_notify(child)

	child.type_keys("zR")

	local node_modules = assert(row_for("web/node_modules"))
	eq(node_modules.label, "node_modules")
	eq({ node_modules.expanded, node_modules.empty }, { false, false })
	eq(has_label("cart.tsx"), true)
	eq(notifications(), {})
end

return T
