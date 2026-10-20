local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@param with_pr boolean
---@return string root
---@return string log
local function billing_branch(with_pr)
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local dir = vim.fn.tempname()
	local files = pr482(manifest)
	if not with_pr then
		files["pr.json"] = nil
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
	return root, log
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

return T
