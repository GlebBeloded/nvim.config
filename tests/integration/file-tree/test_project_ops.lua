local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local tree_root

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	tree_root = assert(vim.uv.fs_realpath(root))
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "README.md")))
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]]), "Project tree did not open")
end

local T = H.child_set(child, start)

---@param relative string
local function focus_tree_path(relative)
	local path = relative == "" and tree_root or vim.fs.joinpath(tree_root, relative)
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
		{ path }
	)
	assert(found, "tree path not found: " .. relative)
end

---@param relative string
local function expand(relative)
	focus_tree_path(relative)
	child.type_keys("<CR>")
end

local function open_billing()
	expand("internal")
	expand("internal/billing")
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

---@param relative string
---@return integer
local function load_buffer(relative)
	return child.lua_get(
		[[(function(path)
			local buf = vim.fn.bufadd(path)
			vim.fn.bufload(buf)
			return buf
		end)(...)]],
		{ vim.fs.joinpath(tree_root, relative) }
	)
end

local function attach_rename_recorder()
	child.lua([[
		RenameRequestCount = 0
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(require("gleb.file_tree.view").state.last_editor_by_tab[view.tab])
		vim.api.nvim_set_current_win(editor)
		local request_id = 0
		local function server()
			return {
				request = function(method, _, callback, notify_reply)
					request_id = request_id + 1
					local current_id = request_id
					local function respond(result)
						callback(nil, result, current_id)
						if notify_reply then
							notify_reply(current_id)
						end
					end
					if method == "initialize" then
						respond({ capabilities = { workspace = { fileOperations = {
							willRename = { filters = { { scheme = "file", pattern = { glob = "**/*" } } } },
						} } } })
					elseif method == "workspace/willRenameFiles" then
						RenameRequestCount = RenameRequestCount + 1
						respond(nil)
					else
						respond(nil)
					end
					return true, current_id
				end,
				notify = function() return true end,
				is_closing = function() return false end,
				terminate = function() end,
			}
		end
		vim.lsp.start({ name = "move-preflight-test", cmd = server, root_dir = view.root })
		assert(vim.wait(1000, function()
			return #vim.lsp.get_clients({ name = "move-preflight-test" }) == 1
		end), "move preflight test server did not initialize")
		vim.api.nvim_set_current_win(view.win)
	]])
end

---@param relative string
---@return boolean
local function wait_for_path(relative)
	return child.lua_get(
		[[(function(path)
			return vim.wait(1000, function()
				return vim.uv.fs_stat(path) ~= nil
			end, 20)
		end)(...)]],
		{ vim.fs.joinpath(tree_root, relative) }
	)
end

---@param relative string
---@return boolean
local function tree_has_path(relative)
	return child.lua_get(
		[[(function(path)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			return vim.iter(view.rows):any(function(row)
				return row.path == path
			end)
		end)(...)]],
		{ vim.fs.joinpath(tree_root, relative) }
	)
end

T["file-tree: Project tree a creates a file in the folder under the cursor"] = MiniTest.new_set()

T["file-tree: Project tree a creates a file in the folder under the cursor"]["drives the real mapping"] = function()
	open_billing()
	focus_tree_path("internal/billing")
	add("tax_rate.go")

	assert(wait_for_path("internal/billing/tax_rate.go"), "created file did not appear")
	eq(vim.fn.readfile(vim.fs.joinpath(root, "internal/billing/tax_rate.go")), {})
	eq(child.api.nvim_buf_get_name(0), vim.fs.joinpath(tree_root, "internal/billing/tax_rate.go"))
	eq(tree_has_path("internal/billing/tax_rate.go"), true)
end

T["file-tree: Project tree a creates a file in the folder under the cursor"]["resolves every row kind"] = function()
	local paths = require("gleb.file_tree.paths")
	local project = "/project"

	eq(paths.target_folder(project, { kind = "root", path = project }), project)
	eq(paths.target_folder(project, { kind = "directory", path = "/project/internal" }), "/project/internal")
	eq(paths.target_folder(project, { kind = "directory", path = "/project/cmd/server" }), "/project/cmd/server")
	eq(paths.target_folder(project, { kind = "file", path = "/project/internal/main.go" }), "/project/internal")
end

T["file-tree: Project tree a creates a file in the folder under the cursor"]["builds copy conflict names"] = function()
	local paths = require("gleb.file_tree.paths")

	eq(paths.copy_name("invoice.go", false, 1), "invoice_copy.go")
	eq(paths.copy_name("invoice.go", false, 2), "invoice_copy2.go")
	eq(paths.copy_name(".env", false, 1), ".env_copy")
	eq(paths.copy_name("release.v1", true, 1), "release.v1_copy")
end

T["file-tree: Project tree a on a file creates next to it"] = function()
	open_billing()
	focus_tree_path("internal/billing/invoice.go")
	add("fee.go")

	assert(wait_for_path("internal/billing/fee.go"), "sibling file did not appear")
end

T["file-tree: Project tree a with a trailing slash creates a folder"] = function()
	open_billing()
	focus_tree_path("internal/billing")
	add("rates/")

	assert(wait_for_path("internal/billing/rates"), "created folder did not appear")
	eq(vim.fn.isdirectory(vim.fs.joinpath(root, "internal/billing/rates")), 1)
	eq(child.bo.filetype, "gleb-file-tree")
	eq(
		child.lua_get(
			[=[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows[vim.api.nvim_win_get_cursor(0)[1]].path]=]
		),
		vim.fs.joinpath(tree_root, "internal/billing/rates")
	)
end

T["file-tree: Project tree a creates missing parent folders"] = function()
	focus_tree_path("")
	add("api/v1/handler.go")

	assert(wait_for_path("api/v1/handler.go"), "nested file did not appear")
	eq(tree_has_path("api/v1/handler.go"), true)
	eq(
		child.lua_get(
			[=[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].expanded["api/v1"]]=]
		),
		true
	)
end

T["file-tree: Project tree a reports an existing name"] = function()
	local notifications = H.record_notify(child)
	local tax_path = vim.fs.joinpath(root, "internal/billing/tax.go")
	local before = vim.fn.readfile(tax_path)
	open_billing()
	focus_tree_path("internal/billing")
	add("tax.go")

	eq(notifications()[#notifications()], {
		msg = "Already exists: internal/billing/tax.go",
		level = vim.log.levels.ERROR,
	})
	eq(vim.fn.readfile(tax_path), before)
end

T["file-tree: Project tree r renames a file and its buffer"] = function()
	open_billing()
	local buffer = load_buffer("internal/billing/invoice.go")
	focus_tree_path("internal/billing/invoice.go")
	rename("bill.go")

	assert(wait_for_path("internal/billing/bill.go"), "renamed file did not appear")
	eq(vim.uv.fs_stat(vim.fs.joinpath(root, "internal/billing/invoice.go")), nil)
	eq(child.api.nvim_buf_get_name(buffer), vim.fs.joinpath(tree_root, "internal/billing/bill.go"))
	child.lua(
		[[
		local buf = ...
		vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
	]],
		{ buffer }
	)
	eq(
		child.lua_get(
			[=[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows[vim.api.nvim_win_get_cursor(0)[1]].path]=]
		),
		vim.fs.joinpath(tree_root, "internal/billing/bill.go")
	)
end

T["file-tree: Project tree r renames a folder and the buffers inside"] = function()
	expand("internal")
	local buffer = load_buffer("internal/money/money.go")
	focus_tree_path("internal/money")
	rename("currency")

	assert(wait_for_path("internal/currency/money.go"), "renamed folder did not appear")
	eq(vim.uv.fs_stat(vim.fs.joinpath(root, "internal/money")), nil)
	eq(child.api.nvim_buf_get_name(buffer), vim.fs.joinpath(tree_root, "internal/currency/money.go"))
end

T["file-tree: Project tree r reports an existing name"] = function()
	local notifications = H.record_notify(child)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	local tax = vim.fs.joinpath(root, "internal/billing/tax.go")
	local invoice_before = vim.fn.readfile(invoice)
	local tax_before = vim.fn.readfile(tax)
	open_billing()
	focus_tree_path("internal/billing/invoice.go")
	rename("tax.go")
	assert(child.wait([[#Notifications > 0]]), "rename conflict was not reported")

	eq(notifications()[#notifications()], {
		msg = "Already exists: internal/billing/tax.go",
		level = vim.log.levels.ERROR,
	})
	eq(vim.fn.readfile(invoice), invoice_before)
	eq(vim.fn.readfile(tax), tax_before)
end

T["file-tree: Project tree rename refuses a vanished row"] = function()
	local notifications = H.record_notify(child)
	open_billing()
	focus_tree_path("internal/billing/invoice.go")
	attach_rename_recorder()
	vim.fn.delete(vim.fs.joinpath(root, "internal/billing/invoice.go"))
	rename("bill.go")
	assert(child.wait([[#Notifications > 0]]), "vanished rename was not reported")

	eq(vim.uv.fs_stat(vim.fs.joinpath(root, "internal/billing/bill.go")), nil)
	eq(child.lua_get("RenameRequestCount"), 0)
	local notification = notifications()[#notifications()]
	assert(notification.msg:find("Rename failed:", 1, true) == 1, "vanished source failure was not reported")
	eq(notification.level, vim.log.levels.ERROR)
end

T["file-tree: Project tree move preflights the whole batch"] = MiniTest.new_set()

T["file-tree: Project tree move preflights the whole batch"]["rejects a vanished later source before moving"] = function()
	H.record_notify(child)
	open_billing()
	attach_rename_recorder()
	local invoice = vim.fs.joinpath(tree_root, "internal/billing/invoice.go")
	local tax = vim.fs.joinpath(tree_root, "internal/billing/tax.go")
	local invoice_target = vim.fs.joinpath(tree_root, "internal/money/invoice.go")
	local tax_target = vim.fs.joinpath(tree_root, "internal/money/tax.go")
	eq(child.lua_get([[vim.uv.fs_unlink(...)]], { tax }), true)
	eq(child.lua_get([[vim.uv.fs_lstat(...) == nil]], { tax }), true)

	local outcome = child.lua_get(
		[[(function(move_pairs)
			local move = require("gleb.file_tree.ops").move
			if type(move) ~= "function" then
				return { api = false }
			end
			return { api = true, moved = move(move_pairs), notifications = Notifications }
		end)(...)]],
		{ { { old = invoice, new = invoice_target }, { old = tax, new = tax_target } } }
	)
	eq(outcome.api, true)
	eq(outcome.moved, false)

	eq(vim.uv.fs_stat(invoice) ~= nil, true)
	eq(vim.uv.fs_stat(invoice_target), nil)
	eq(vim.uv.fs_stat(tax_target), nil)
	eq(child.lua_get("RenameRequestCount"), 0)
	local notification = outcome.notifications[#outcome.notifications]
	assert(notification.msg:find("Rename failed:", 1, true) == 1, "batch failure was not reported")
	eq(notification.level, vim.log.levels.ERROR)
end

T["file-tree: Project tree move preflights the whole batch"]["deduplicates nested selections"] = function()
	local path_helpers = require("gleb.file_tree.paths")
	eq(
		path_helpers.dedupe({
			"/project/internal/billing/invoice.go",
			"/project/README.md",
			"/project/internal",
			"/project/internal/billing",
			"/project/README.md",
		}),
		{ "/project/README.md", "/project/internal" }
	)
end

T["file-tree: Project tree move preflights the whole batch"]["rejects the batch when a later source is missing"] = function()
	local path_helpers = require("gleb.file_tree.paths")
	local stats = {
		["/project/one.go"] = { dev = 7 },
		["/project/archive"] = { dev = 7 },
	}
	local ok, reason, failed_path = path_helpers.preflight_moves("/project", {
		{ old = "/project/one.go", new = "/project/archive/one.go" },
		{ old = "/project/two.go", new = "/project/archive/two.go" },
	}, {
		lstat = function(path)
			return stats[path]
		end,
		stat = function(path)
			return stats[path]
		end,
		read_dir = function()
			return {}
		end,
	})

	eq({ ok, reason, failed_path }, { nil, "missing", "/project/two.go" })
end

T["file-tree: Project tree move preflights the whole batch"]["rejects case-insensitive target conflicts"] = function()
	local path_helpers = require("gleb.file_tree.paths")
	local ok, reason, failed_path = path_helpers.preflight_moves("/project", {
		{ old = "/project/invoice.go", new = "/project/archive/invoice.go" },
	}, {
		lstat = function()
			return { dev = 7 }
		end,
		stat = function()
			return { dev = 7 }
		end,
		read_dir = function()
			return { "Invoice.go" }
		end,
	})

	eq({ ok, reason, failed_path }, { nil, "exists", "/project/archive/invoice.go" })
end

T["file-tree: Project tree move preflights the whole batch"]["allows a case-only rename of its source"] = function()
	local path_helpers = require("gleb.file_tree.paths")
	local ok = path_helpers.preflight_moves("/project", {
		{ old = "/project/Invoice.go", new = "/project/invoice.go" },
	}, {
		lstat = function()
			return { dev = 7 }
		end,
		stat = function()
			return { dev = 7 }
		end,
		read_dir = function()
			return { "Invoice.go" }
		end,
	})

	eq(ok, true)
end

T["file-tree: Project tree create reports a read-only destination"] = MiniTest.new_set()

T["file-tree: Project tree create reports a read-only destination"]["reports the filesystem error"] = function()
	local notifications = H.record_notify(child)
	focus_tree_path("")
	child.lua([[vim.uv.fs_chmod(..., 365)]], { tree_root })
	add("blocked.go")

	eq(vim.uv.fs_stat(vim.fs.joinpath(root, "blocked.go")), nil)
	local notification = notifications()[#notifications()]
	assert(notification.msg:find("Create failed:", 1, true) == 1, "create failure was not reported")
	eq(notification.level, vim.log.levels.ERROR)
end

T["file-tree: Project tree create reports a read-only destination"]["rejects a destination outside the root"] = function()
	local notifications = H.record_notify(child)
	local outside = vim.fs.joinpath(vim.fs.dirname(tree_root), "outside")
	focus_tree_path("")
	add("../outside")

	eq(vim.uv.fs_stat(outside), nil)
	local notification = notifications()[#notifications()]
	assert(notification.msg:find("Create failed:", 1, true) == 1, "unsafe destination was not reported")
	eq(notification.level, vim.log.levels.ERROR)
end

T["file-tree: Project tree operation keys come from the keymap file"] = function()
	local actual = child.lua_get([[
(function()
	local result = { n = {}, x = {}, actions = {} }
	for _, mode in ipairs({ "n", "x" }) do
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
			result[mode][map.lhs] = map.desc
		end
	end
	local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
		vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
	local catalog = require("gleb.actions").state.applicator.catalog
	for _, name in ipairs({ "add", "rename", "delete", "copy", "cut", "paste", "refresh" }) do
		local id = "file_tree." .. name
		local action = assert(catalog:get(id), id .. " is not registered")
		result.actions[id] = { keys = shortcuts[id], plugin = action.plugin }
	end
	return result
end)()
]])
	local expected = {
		add = { keys = { "a" }, title = "New File or Directory" },
		rename = { keys = { "r" }, title = "Rename" },
		delete = { keys = { "d" }, title = "Delete", visual = true },
		copy = { keys = { "c" }, title = "Copy", visual = true },
		cut = { keys = { "x" }, title = "Cut", visual = true },
		paste = { keys = { "p" }, title = "Paste" },
		refresh = { keys = { "R" }, title = "Refresh" },
	}
	for name, operation in pairs(expected) do
		local id = "file_tree." .. name
		eq(actual.actions[id], { keys = operation.keys })
		for _, lhs in ipairs(operation.keys) do
			eq(actual.n[lhs], "Project: " .. operation.title)
			if operation.visual then
				eq(actual.x[lhs], "Project: " .. operation.title)
			end
		end
	end
end

return T
