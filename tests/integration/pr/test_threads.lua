local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@param with_pr boolean
---@param mutate? fun(files: table<string, string>)
---@return string root
---@return string log
---@return string gh_dir
local function billing_branch(with_pr, mutate)
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local dir = vim.fn.tempname()
	local files = pr482(manifest)
	if not with_pr then
		files["pr.json"] = nil
	end
	if mutate then
		mutate(files)
	end
	H.write_files(dir, files)
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_DIR = ...; vim.env.FAKE_GH_LOG = select(2, ...)]], { dir, log })
	child.lua(
		[[BaseDone = false
		require("gleb.git.base").resolve(..., function() BaseDone = true end)]],
		{ root }
	)
	eq(child.wait("BaseDone == true", 3000), true)
	vim.fn.writefile({}, log)
	return root, log, dir
end

---@param files table<string, string>
---@param mutate fun(nodes: table[])
---@return nil
local function mutate_threads(files, mutate)
	local response = vim.json.decode(files["ReviewThreads.json"])
	mutate(response.data.repository.pullRequest.reviewThreads.nodes)
	files["ReviewThreads.json"] = vim.json.encode(response)
end

---@param root string
---@return nil
local function refresh_and_open_invoice(root)
	child.lua(
		[[PrReady = false
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function()
			PrReady = true
		end })
		require("gleb.pr").refresh(...)]],
		{ root }
	)
	eq(child.wait("PrReady == true", 3000), true)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
end

---@return table<string, table>
local function locate_invoice()
	child.lua([[LocateDone = false
		Locations = require("gleb.pr").locate(0, function(locations)
			Locations = locations
			LocateDone = true
		end)]])
	eq(child.wait("LocateDone == true", 3000), true)
	local locations = child.lua_get("Locations")
	local by_id = {}
	for _, location in ipairs(locations) do
		by_id[location.thread.id] = location
	end
	return by_id
end

---@param root string
---@param path string
---@return table<string, table>
local function refresh_and_locate(root, path)
	child.lua(
		[[PrReady = false
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function()
			PrReady = true
		end })
		require("gleb.pr").refresh(...)]],
		{ root }
	)
	eq(child.wait("PrReady == true", 3000), true)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, path)))
	child.lua([[LocateDone = false
		Locations = require("gleb.pr").locate(0, function(locations)
			Locations = locations
			LocateDone = true
		end)]])
	eq(child.wait("LocateDone == true", 3000), true)
	local by_id = {}
	for _, location in ipairs(child.lua_get("Locations")) do
		by_id[location.thread.id] = location
	end
	return by_id
end

---@param log string
---@return integer
local function graphql_calls(log)
	return #vim.tbl_filter(function(line)
		return line:find("query ReviewThreads", 1, true) ~= nil
	end, vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {})
end

---@param root string
---@return nil
local function force_refresh(root)
	child.lua([[require("gleb.pr").refresh(..., { force = true })]], { root })
end

local function review_changes()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.review"))
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param gh_dir string
---@return nil
local function fail_review_threads(gh_dir)
	vim.fn.writefile({ "1" }, vim.fs.joinpath(gh_dir, "ReviewThreads.json.code"))
	vim.fn.writefile({ "error connecting to pgw.dev" }, vim.fs.joinpath(gh_dir, "ReviewThreads.json.stderr"))
end

---@param gh_dir string
---@return nil
local function restore_review_threads(gh_dir)
	vim.fn.delete(vim.fs.joinpath(gh_dir, "ReviewThreads.json.code"))
	vim.fn.delete(vim.fs.joinpath(gh_dir, "ReviewThreads.json.stderr"))
end

---@param expected integer
---@return nil
local function wait_for_refreshes(expected)
	eq(
		child.wait(
			("#vim.tbl_filter(function(line) return line:find('query ReviewThreads', 1, true) ~= nil end, vim.fn.readfile(vim.env.FAKE_GH_LOG)) == %d and next(require('gleb.pr').state.in_flight) == nil"):format(
				expected
			),
			3000
		),
		true
	)
end

local function toggle_changes()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
end

T["pr: PR threads are fetched with gh api graphql"] = function()
	local root, log = billing_branch(true)
	child.lua(
		[[PrEvents = {}
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", callback = function(args)
			table.insert(PrEvents, args.data.root)
		end })
		require("gleb.pr").refresh(...)]],
		{ root }
	)
	eq(child.wait("#PrEvents == 1", 3000), true)

	local review = child.lua_get([[require("gleb.pr").get(...)]], { root })
	local ids = vim.tbl_map(function(thread)
		return thread.id
	end, review.threads)
	eq(ids, { "PRRT_t1", "PRRT_t2", "PRRT_t3", "PRRT_t4" })
	local lines = vim.fn.readfile(log)
	eq(#lines, 1)
	local call = lines[1]
	eq(call:match("^([^\t]+)"), "pgw.dev")
	eq(call:find("api graphql", 1, true) ~= nil, true)
	eq(call:find("query ReviewThreads", 1, true) ~= nil, true)
	eq(call:find("-f owner=finteqhub", 1, true) ~= nil, true)
	eq(call:find("-f name=billing", 1, true) ~= nil, true)
	eq(call:find("-F number=482", 1, true) ~= nil, true)
end

T["pr: No pull request runs no GraphQL"] = function()
	local root, log = billing_branch(false)
	child.lua([[require("gleb.pr").refresh(...)]], { root })
	eq(child.lua_get([[require("gleb.pr").get(...) == nil]], { root }), true)
	local calls = vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}
	eq(
		vim.tbl_filter(function(line)
			return line:find("api graphql", 1, true) ~= nil
		end, calls),
		{}
	)
end

T["pr: PR threads map onto the working file"] = function()
	local root = billing_branch(true)
	refresh_and_open_invoice(root)

	local locations = locate_invoice()
	eq(locations.PRRT_t1.line, 22)
	eq(locations.PRRT_t2.line, 13)
	eq(locations.PRRT_t4.line, 11)
	eq(locations.PRRT_t1.reason, nil)
	eq(locations.PRRT_t2.reason, nil)
	eq(locations.PRRT_t4.reason, nil)
	eq(locations.PRRT_t3, nil)
end

T["pr: PR threads follow unsaved edits"] = function()
	local root = billing_branch(true)
	refresh_and_open_invoice(root)
	child.api.nvim_buf_set_lines(0, 0, 0, false, { "// first", "// second" })

	local locations = locate_invoice()
	eq(locations.PRRT_t1.line, 24)
	eq(locations.PRRT_t2.line, 15)
end

T["pr: A PR thread on a removed line is unmapped"] = function()
	local root = billing_branch(true)
	refresh_and_open_invoice(root)
	child.api.nvim_buf_set_lines(0, 21, 22, false, {})

	local locations = locate_invoice()
	eq(locations.PRRT_t1.line, nil)
	eq(locations.PRRT_t1.reason, "removed")
	eq(locations.PRRT_t2.line, 13)
end

T["pr: An outdated PR thread anchors at its original commit"] = function()
	local root = billing_branch(true)
	local locations = refresh_and_locate(root, "internal/billing/tax.go")

	eq(locations.PRRT_t3 and locations.PRRT_t3.line, 18)
	eq(locations.PRRT_t3 and locations.PRRT_t3.thread.outdated, true)
end

T["pr: A PR thread at a missing commit is unmapped"] = function()
	local root = billing_branch(true, function(files)
		mutate_threads(files, function(nodes)
			nodes[3].comments.nodes[1].originalCommit.oid = string.rep("f", 40)
		end)
	end)
	local notifications = H.record_notify(child)
	local locations = refresh_and_locate(root, "internal/billing/tax.go")

	eq(locations.PRRT_t3 and locations.PRRT_t3.reason, "missing commit")
	eq(notifications(), {})
end

T["pr: Left-side and file PR threads are unmapped"] = function()
	local root = billing_branch(true, function(files)
		mutate_threads(files, function(nodes)
			local left = vim.deepcopy(nodes[2])
			left.id = "PRRT_left"
			left.diffSide = "LEFT"
			table.insert(nodes, left)
			local file = vim.deepcopy(nodes[2])
			file.id = "PRRT_file"
			file.subjectType = "FILE"
			table.insert(nodes, file)
		end)
	end)
	local locations = refresh_and_locate(root, "internal/billing/invoice.go")

	eq(locations.PRRT_left and locations.PRRT_left.reason, "left side")
	eq(locations.PRRT_file and locations.PRRT_file.reason, "file")
end

T["pr: PR threads are cached per head"] = function()
	local root, log = billing_branch(true)
	refresh_and_open_invoice(root)
	child.lua([[RealSystem = vim.system
		GitShowCalls = 0
		vim.system = function(cmd, ...)
			if cmd[1] == "git" and cmd[2] == "show" then
				GitShowCalls = GitShowCalls + 1
			end
			return RealSystem(cmd, ...)
		end]])

	child.lua_get([[require("gleb.pr").get(...)]], { root })
	child.lua_get([[require("gleb.pr").get(...)]], { root })
	locate_invoice()
	child.lua([[Locations = require("gleb.pr").locate(0)]])

	eq(child.lua_get("GitShowCalls"), 1)
	eq(#vim.fn.readfile(log), 1)
end

T["pr: A new PR head fetches the threads again"] = function()
	local root, log, gh_dir = billing_branch(true)
	refresh_and_open_invoice(root)
	local pr_file = vim.fs.joinpath(gh_dir, "pr.json")
	local response = vim.json.decode(table.concat(vim.fn.readfile(pr_file), "\n"))
	local new_head = string.rep("a", 40)
	response.headRefOid = new_head
	vim.fn.writefile({ vim.json.encode(response) }, pr_file)

	child.lua(
		[[ExpectedRoot, ExpectedHead = ...
		require("gleb.git.base").refresh(ExpectedRoot, { force = true })]],
		{ root, new_head }
	)
	eq(child.wait([[require("gleb.git.base").get(ExpectedRoot).pr.head_ref_oid == ExpectedHead]], 3000), true)
	eq(
		child.wait(
			[[#vim.tbl_filter(function(line) return line:find("query ReviewThreads", 1, true) ~= nil end, vim.fn.readfile(vim.env.FAKE_GH_LOG)) == 2]],
			3000
		),
		true
	)
	eq(
		child.wait(
			[[require("gleb.pr").get(ExpectedRoot) ~= nil and require("gleb.pr").get(ExpectedRoot).head == ExpectedHead]],
			3000
		),
		true
	)
	eq(#vim.tbl_filter(function(line)
		return line:find("query ReviewThreads", 1, true) ~= nil
	end, vim.fn.readfile(log)), 2)
end

T["pr: PR thread updates fire an event"] = function()
	local root = billing_branch(true)
	child.lua(
		[[PrEvents = {}
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", callback = function(args)
			table.insert(PrEvents, args.data.root)
		end })
		require("gleb.pr").refresh(...)]],
		{ root }
	)
	eq(child.wait("#PrEvents == 1", 3000), true)
	eq(child.lua_get("PrEvents"), { root })
end

T["pr: pr.refresh fetches the threads again"] = function()
	local root, log = billing_branch(true)
	local notifications = H.record_notify(child)
	child.lua([[PrEvents = 0
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", callback = function()
			PrEvents = PrEvents + 1
		end })]])

	force_refresh(root)
	eq(child.wait("PrEvents == 1", 3000), true)
	force_refresh(root)
	eq(child.wait("PrEvents == 2", 3000), true)

	eq(graphql_calls(log), 2)
	eq(notifications(), {
		{ msg = "PR #482: 3 open threads", level = vim.log.levels.INFO },
		{ msg = "PR #482: 3 open threads", level = vim.log.levels.INFO },
	})
end

T["pr: Opening the review panel fetches the threads"] = function()
	local root, log = billing_branch(true)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))

	review_changes()
	eq(
		child.wait(
			[[#vim.tbl_filter(function(line)
		return line:find("query ReviewThreads", 1, true) ~= nil
	end, vim.fn.readfile(vim.env.FAKE_GH_LOG)) == 1]],
			3000
		),
		true
	)
	review_changes()
	eq(child.lua_get([[vim.wait(500, function() return false end)]]), false)

	eq(graphql_calls(log), 1)
end

T["pr: Writing a file fetches the threads once"] = function()
	local root, log = billing_branch(true)
	refresh_and_open_invoice(root)
	child.lua([[WriteStart = vim.uv.now()]])

	child.cmd("write")
	eq(
		child.wait(
			[[#vim.tbl_filter(function(line)
		return line:find("query ReviewThreads", 1, true) ~= nil
	end, vim.fn.readfile(vim.env.FAKE_GH_LOG)) == 2]],
			3000
		),
		true
	)
	eq(child.wait("vim.uv.now() - WriteStart >= 1500", 2000), true)
	child.cmd("write")
	eq(child.lua_get([[vim.wait(1500, function() return false end)]]), false)

	eq(graphql_calls(log), 2)
end

T["pr: Writing a file fetches threads before any manual refresh"] = function()
	local root, log = billing_branch(true)
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))

	child.cmd("write")
	eq(child.wait("#vim.fn.readfile(vim.env.FAKE_GH_LOG) == 1", 3000), true)

	eq(graphql_calls(log), 1)
end

T["pr: A trigger during a fetch queues one more"] = function()
	local root, log = billing_branch(true)
	child.lua([[vim.env.FAKE_GH_SLEEP = "1"; PrEvents = 0
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", callback = function()
			PrEvents = PrEvents + 1
		end })]])

	child.lua(
		[[local root = ...
		local pr = require("gleb.pr")
		pr.refresh(root)
		pr.refresh(root)
		pr.refresh(root)]],
		{ root }
	)
	eq(child.wait("PrEvents == 2", 5000), true)
	eq(child.lua_get([[vim.wait(1200, function() return false end)]]), false)

	eq(graphql_calls(log), 2)
end

T["pr: pr.refresh without a pull request"] = function()
	local root, log = billing_branch(false)
	local notifications = H.record_notify(child)

	force_refresh(root)

	eq(notifications(), { { msg = "No pull request for feat/tax", level = vim.log.levels.WARN } })
	eq(graphql_calls(log), 0)
end

T["pr: A missing gh fetch warns and clears in-flight refresh"] = function()
	local root = billing_branch(true)
	local notifications = H.record_notify(child)
	refresh_and_open_invoice(root)
	local path = child.lua_get("vim.env.PATH")

	child.lua([[vim.env.PATH = ""; require("gleb.pr").refresh(...)]], { root })
	eq(child.wait("next(require('gleb.pr').state.in_flight) == nil", 3000), true)
	eq(notifications(), {
		{ msg = "PR comments unavailable: gh not found", level = vim.log.levels.WARN },
	})

	child.lua([[vim.env.PATH = select(2, ...); require("gleb.pr").refresh(...)]], { root, path })
	wait_for_refreshes(2)
	eq(#child.lua_get([[require("gleb.pr").get(...).threads]], { root }), 4)
end

T["pr: A failed PR fetch warns once and keeps the threads"] = MiniTest.new_set()

T["pr: A failed PR fetch warns once and keeps the threads"]["retains cached threads and the changes panel"] = function()
	local root, log, gh_dir = billing_branch(true)
	local notifications = H.record_notify(child)
	refresh_and_open_invoice(root)
	fail_review_threads(gh_dir)

	child.lua([[require("gleb.pr").refresh(...)]], { root })
	wait_for_refreshes(2)
	child.lua([[require("gleb.pr").refresh(...)]], { root })
	wait_for_refreshes(3)
	toggle_changes()
	eq(
		child.wait(
			[[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return panel and vim.api.nvim_buf_get_lines(panel.buf, 0, 1, false)[1]:find("Changes 2 files", 1, true) ~= nil
		end)()]],
			3000
		),
		true
	)

	eq(graphql_calls(log), 3)
	eq(#child.lua_get([[require("gleb.pr").get(...).threads]], { root }), 4)
	eq(notifications(), {
		{ msg = "PR comments unavailable: error connecting to pgw.dev", level = vim.log.levels.WARN },
	})
end

T["pr: A failed PR fetch warns once and keeps the threads"]["a success resets failure suppression"] = function()
	local root, _, gh_dir = billing_branch(true)
	local notifications = H.record_notify(child)
	refresh_and_open_invoice(root)
	fail_review_threads(gh_dir)

	child.lua([[require("gleb.pr").refresh(...)]], { root })
	wait_for_refreshes(2)
	restore_review_threads(gh_dir)
	child.lua([[require("gleb.pr").refresh(...)]], { root })
	wait_for_refreshes(3)
	fail_review_threads(gh_dir)
	child.lua([[require("gleb.pr").refresh(...)]], { root })
	wait_for_refreshes(4)

	eq(notifications(), {
		{ msg = "PR comments unavailable: error connecting to pgw.dev", level = vim.log.levels.WARN },
		{ msg = "PR comments unavailable: error connecting to pgw.dev", level = vim.log.levels.WARN },
	})
end

T["pr: pr.refresh always reports a failure"] = MiniTest.new_set()

T["pr: pr.refresh always reports a failure"]["forced refreshes each notify"] = function()
	local root, _, gh_dir = billing_branch(true)
	local notifications = H.record_notify(child)
	fail_review_threads(gh_dir)

	force_refresh(root)
	wait_for_refreshes(1)
	force_refresh(root)
	wait_for_refreshes(2)

	eq(notifications(), {
		{ msg = "PR comments unavailable: error connecting to pgw.dev", level = vim.log.levels.WARN },
		{ msg = "PR comments unavailable: error connecting to pgw.dev", level = vim.log.levels.WARN },
	})
end

T["pr: pr.refresh is an unbound Find Action entry"] = function()
	local entry = child.lua_get([[(function()
		local action = require("gleb.actions").state.applicator.catalog:get("pr.refresh")
		local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
			vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")
		), "\n"))
		return {
			id = action and action.id,
			title = action and action.title,
			category = action and action.category,
			shortcut = shortcuts["pr.refresh"],
		}
	end)()]])

	eq(entry, {
		id = "pr.refresh",
		title = "Refresh Pull Request Comments",
		category = "Git | Pull Request",
	})
end

return T
