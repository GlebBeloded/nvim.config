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
local function open_tree(project_root, settings_path)
	root = project_root
	child.lua([[require("gleb.file_tree.settings").setup({ path = ... })]], { settings_path })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "README.md")))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
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

return T
