local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(manifest))
	child.start_config()
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua(
		[[
		local root = ...
		Ready = false
		require("gleb.git.base").resolve(root, function()
			vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function()
				Ready = true
			end })
			require("gleb.pr").refresh(root)
		end)
	]],
		{ root }
	)
	assert(child.wait("Ready == true", math.floor(5000 * H.load_factor())), "PR peeks did not load")
	child.lua([[require("gleb.pr").now = function() return os.time({ year = 2026, month = 1, day = 2, hour = 1 }) end]])
	child.lua([[vim.api.nvim_win_set_cursor(0, { 18, 0 })]])
	assert(
		child.wait(
			[[(function()
		local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
		return ns and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0
	end)()]],
			math.floor(5000 * H.load_factor())
		),
		"PR peek extmarks did not draw"
	)
	return root, gh_dir
end

local T = H.child_set(child, start)

---@param line integer
---@return table[]
local function virt_lines(line)
	return child.lua_get(
		[[(function(line)
		local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
		if not ns then return {} end
		local marks = vim.api.nvim_buf_get_extmarks(0, ns, { line - 1, 0 }, { line - 1, -1 }, { details = true })
		return marks[1] and marks[1][4].virt_lines or {}
	end)(...)]],
		{ line }
	)
end

local function virt_text(line)
	return vim.tbl_map(function(segments)
		return vim.trim(vim.iter(segments):fold("", function(text, segment)
			return text .. segment[1]
		end))
	end, virt_lines(line))
end

T["pr: Open threads peek as one line"] = function()
	eq(virt_text(22), { "╰─ 󰂈 maria.k Should a nil rate mean no tax at all? +1 reply" })
	eq(virt_text(13), { "╰─ 󰂈 ivan.p Rate or *Rate here?" })
	local groups = vim.tbl_map(function(segment)
		return segment[2]
	end, virt_lines(22)[1])
	eq(vim.list_slice(groups, 2), { "PrPeekMeta", "PrPeekIcon", "PrPeekAuthor", "PrPeek", "PrPeekMeta" })
end

T["pr: Peek expands at the cursor line"] = function()
	child.lua([[vim.api.nvim_win_set_cursor(0, { 22, 0 })]])
	assert(
		child.wait(
			"#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().gleb_pr_peek, {21, 0}, {21, -1}, {details=true}) > 0",
			1000
		)
	)
	local expanded = virt_text(22)
	eq(#expanded, 8)
	eq(expanded[1]:find("PR #482 · 2 comments", 1, true) ~= nil, true)
	eq(expanded[2]:find("maria.k · 2h", 1, true) ~= nil, true)
	eq(expanded[5]:find("gleb-beloded · 1h", 1, true) ~= nil, true)
	child.lua([[vim.api.nvim_win_set_cursor(0, { 23, 0 })]])
	eq(#virt_lines(22), 1)
end

T["pr: Resolved threads fold to one grey line"] = function()
	child.lua([[vim.api.nvim_win_set_cursor(0, { 11, 0 })]])
	local lines = virt_lines(11)
	eq(#lines, 1)
	eq(virt_text(11)[1]:find("╰─  Resolved · ivan.p: Should ID stay a string?", 1, true) ~= nil, true)
	for _, segment in ipairs(vim.list_slice(lines[1], 2)) do
		eq(segment[2], "PrThreadResolved")
	end
end

T["pr: Outdated threads are hidden in code"] = function()
	child.cmd("edit internal/billing/tax.go")
	eq(child.lua_get([[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().gleb_pr_peek, 0, -1, {})]]), 0)
end

T["pr: Peeks follow the threads"] = function()
	child.lua(
		[[
		local review = require("gleb.pr").get((...))
		review.threads = vim.tbl_filter(function(thread) return thread.id ~= "PRRT_t2" end, review.threads)
		vim.api.nvim_exec_autocmds("User", { pattern = "GlebPrThreads", data = { root = review.root } })
	]],
		{ child.lua_get([[require("gleb.pr").get(vim.fn.getcwd()).root]]) }
	)
	eq(#virt_lines(13), 0)
	eq(#virt_lines(22), 1)
end

return T
