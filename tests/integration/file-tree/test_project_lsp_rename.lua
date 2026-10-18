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
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "cmd/server/main.go")))
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]]),
		"Project tree did not draw its initial rows"
	)
end

local T = H.child_set(child, start)

local function open_billing()
	for _, relative in ipairs({ "internal", "internal/billing" }) do
		local path = vim.fs.joinpath(tree_root, relative)
		local found = child.lua_get(
			[[(function(wanted)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			for index, row in ipairs(view.rows) do
				if row.path == wanted then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return true
				end
			end
			return false
		end)(...)]],
			{ path }
		)
		assert(found, "tree path not found: " .. relative)
		child.type_keys("<CR>")
	end
end

---@param options table
local function attach_server(options)
	options.root = tree_root
	options.main = vim.fs.joinpath(tree_root, "cmd/server/main.go")
	child.lua(
		[[
		local options = ...
		RenameLspEvents = { requests = {}, notifications = {} }
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		local editor = assert(require("gleb.file_tree.view").state.last_editor_by_tab[view.tab])
		vim.api.nvim_set_current_win(editor)
		local request_id = 0
		local function server()
			return {
				request = function(method, params, callback, notify_reply)
					request_id = request_id + 1
					local current_id = request_id
					local function respond(result)
						callback(nil, result, current_id)
						if notify_reply then
							notify_reply(current_id)
						end
					end
					if method == "initialize" then
						respond({
							capabilities = {
								workspace = { fileOperations = {
									willRename = { filters = { options.filter } },
									didRename = { filters = { options.filter } },
								} },
							},
						})
					elseif method == "workspace/willRenameFiles" then
						RenameLspEvents.requests[#RenameLspEvents.requests + 1] = {
							files = params.files,
							old_exists = vim.uv.fs_stat(vim.uri_to_fname(params.files[1].oldUri)) ~= nil,
						}
						if not options.never_reply then
							local reply = function()
								respond({ changes = {
									[vim.uri_from_fname(options.main)] = { {
										range = {
											start = { line = 0, character = 0 },
											["end"] = { line = 0, character = 0 },
										},
										newText = "// moved\n",
									} },
								} })
							end
							if options.delay_ms then
								vim.defer_fn(reply, options.delay_ms)
							else
								reply()
							end
						end
					else
						respond(nil)
					end
					return true, current_id
				end,
				notify = function(method, params)
					if method == "workspace/didRenameFiles" then
						local files = params.files
						RenameLspEvents.notifications[#RenameLspEvents.notifications + 1] = {
							files = files,
							old_exists = vim.uv.fs_stat(vim.uri_to_fname(files[1].oldUri)) ~= nil,
							new_exists = vim.uv.fs_stat(vim.uri_to_fname(files[1].newUri)) ~= nil,
						}
					end
					return true
				end,
				is_closing = function() return false end,
				terminate = function() end,
			}
		end
		vim.lsp.start({ name = "file-rename-test", cmd = server, root_dir = options.root })
		assert(vim.wait(1000, function()
			return #vim.lsp.get_clients({ name = "file-rename-test" }) == 1
		end), "rename test server did not initialize")
		vim.api.nvim_set_current_win(view.win)
	]],
		{ options }
	)
end

local function focus_invoice()
	open_billing()
	local invoice = vim.fs.joinpath(tree_root, "internal/billing/invoice.go")
	local found = child.lua_get(
		[[(function(wanted)
		local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
		for index, row in ipairs(view.rows) do
			if row.path == wanted then
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return true
			end
		end
		return false
	end)(...)]],
		{ invoice }
	)
	assert(found, "invoice.go tree row not found")
end

local function rename_invoice()
	focus_invoice()
	assert(child.fn.maparg("r", "n") ~= "", "Rename mapping is not installed")
	child.type_keys("r")
	assert(child.wait([[MiniPick.is_picker_active()]]), "Rename picker did not open")
	child.type_keys("<C-u>bill.go", "<CR>")
	assert(child.wait([[not MiniPick.is_picker_active()]]), "Rename picker did not close")
	child.lua([[RenameTarget = ...]], { vim.fs.joinpath(tree_root, "internal/billing/bill.go") })
	assert(child.wait([[vim.uv.fs_stat(RenameTarget) ~= nil]], 1600), "rename did not finish")
end

local function go_filter()
	return { scheme = "file", pattern = { glob = "**/*.go", matches = "file" } }
end

T["file-tree: Project tree rename asks language servers to update references"] = MiniTest.new_set()

T["file-tree: Project tree rename asks language servers to update references"]["applies matching server edits"] = function()
	attach_server({ filter = go_filter() })
	rename_invoice()

	local events = child.lua_get("RenameLspEvents")
	local files = {
		{
			oldUri = vim.uri_from_fname(vim.fs.joinpath(tree_root, "internal/billing/invoice.go")),
			newUri = vim.uri_from_fname(vim.fs.joinpath(tree_root, "internal/billing/bill.go")),
		},
	}
	eq(events.requests, { { files = files, old_exists = true } })
	eq(events.notifications, { { files = files, old_exists = false, new_exists = true } })
	eq(
		child.lua_get(
			[=[vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, 1, false)[1]]=],
			{ vim.fs.joinpath(tree_root, "cmd/server/main.go") }
		),
		"// moved"
	)
end

T["file-tree: Project tree rename asks language servers to update references"]["skips a non-matching server"] = function()
	attach_server({ filter = { scheme = "file", pattern = { glob = "**/*.ts", matches = "file" } } })
	rename_invoice()

	eq(child.lua_get("RenameLspEvents.requests"), {})
	eq(child.lua_get("RenameLspEvents.notifications"), {})
end

T["file-tree: Project tree rename waits for servers at most one second"] = MiniTest.new_set()

T["file-tree: Project tree rename waits for servers at most one second"]["continues after the deadline"] = function()
	attach_server({ filter = go_filter(), never_reply = true })
	local started = vim.uv.hrtime()
	rename_invoice()
	local elapsed_ms = (vim.uv.hrtime() - started) / 1e6

	assert(elapsed_ms < 1500, ("rename took %.0f ms"):format(elapsed_ms))
end

T["file-tree: Project tree rename waits for servers at most one second"]["drops a late workspace edit"] = function()
	attach_server({ filter = go_filter(), delay_ms = 1200 })
	rename_invoice()
	child.lua([[vim.wait(400)]])

	eq(
		child.lua_get(
			[=[vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, 1, false)[1]]=],
			{ vim.fs.joinpath(tree_root, "cmd/server/main.go") }
		),
		"package main"
	)
end

T["file-tree: Project tree move notifies didRename only after the target exists"] = function()
	attach_server({ filter = go_filter() })
	rename_invoice()

	eq(child.lua_get("RenameLspEvents.notifications[1].old_exists"), false)
	eq(child.lua_get("RenameLspEvents.notifications[1].new_exists"), true)
end

return T
