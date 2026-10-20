local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

local T = H.child_set(child, child.start_config)

---@return string root
---@return fixtures.Manifest manifest
local function prbranch()
	local root, manifest = F.copy("prbranch", vim.fn.tempname() .. "/prbranch")
	return vim.fs.normalize(vim.fn.resolve(root)), manifest
end

---@param root string
---@param path string
local function edit(root, path)
	child.cmd("edit " .. vim.fs.joinpath(root, path))
end

local function install_sign_reader()
	child.lua([[
		function CommittedSigns()
			local ns = vim.api.nvim_get_namespaces().gleb_git_committed_signs
			if not ns then return {} end
			local signs = {}
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
				local details = mark[4]
				local text = vim.trim(details.sign_text or "")
				signs[tostring(mark[2] + 1)] = {
					kind = text == "┃" and "bar" or "delete",
					text = text,
					hl = details.sign_hl_group,
					priority = details.priority,
				}
			end
			return signs
		end
		function GitsignsSignAt(target)
			for name, ns in pairs(vim.api.nvim_get_namespaces()) do
				if name:find("^gitsigns_signs_") then
					local marks = vim.api.nvim_buf_get_extmarks(0, ns, { target - 1, 0 }, { target - 1, -1 }, {})
					if #marks > 0 then return true end
				end
			end
			return false
		end
	]])
end

---@param expected table<string, table>
local function wait_for_signs(expected)
	child.lua([[ExpectedCommittedSigns = ...]], { expected })
	local ready = child.wait("vim.deep_equal(CommittedSigns(), ExpectedCommittedSigns)", ASYNC_MS)
	if not ready then
		eq(child.lua_get("CommittedSigns()"), expected)
	end
end

---@param committed { add: integer[], change: integer[], delete: integer[] }
---@return table<string, table>
local function expected_bars(committed)
	local result = {}
	for _, lines in ipairs({ committed.add, committed.change }) do
		for _, line in ipairs(lines) do
			result[tostring(line)] = { kind = "bar", text = "┃", hl = "GitCommittedSign", priority = 5 }
		end
	end
	return result
end

---@param files table<string, string>
---@return string
local function branch_repo(files)
	local root = H.git_repo(files)
	H.git(root, { "update-ref", "refs/remotes/origin/main", "HEAD" })
	H.git(root, { "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main" })
	H.git(root, { "checkout", "-q", "-b", "feat/x" })
	return root
end

T["git: Committed signs mark the branch's lines"] = function()
	local root, manifest = prbranch()
	install_sign_reader()
	edit(root, "internal/billing/invoice.go")
	local expected = expected_bars(manifest.committed["internal/billing/invoice.go"])
	wait_for_signs(expected)
	eq(expected[tostring(manifest.hunks["internal/billing/invoice.go"][1])], nil)
end

T["git: Committed signs mark every line of a file added on the branch"] = function()
	local root, manifest = prbranch()
	install_sign_reader()
	edit(root, "internal/billing/tax.go")
	wait_for_signs(expected_bars(manifest.committed["internal/billing/tax.go"]))
end

T["git: Committed signs mark deleted lines"] = function()
	local root = branch_repo({
		["lib/util.lua"] = "local M = {}\nM.a = 1\nM.b = 2\nM.c = 3\nreturn M",
	})
	H.write_files(root, { ["lib/util.lua"] = "local M = {}\nM.a = 1\nreturn M" })
	H.git(root, { "add", "-A" })
	H.git(root, { "commit", "-q", "-m", "delete fields" })
	install_sign_reader()
	edit(root, "lib/util.lua")
	wait_for_signs({
		["2"] = { kind = "delete", text = "", hl = "GitCommittedSign", priority = 5 },
	})
end

T["git: Committed signs colour is gruvbox purple"] = function()
	H.expect_hl_colors(child, "GitCommittedSign", { fg = "#d3869b" })
	child.cmd("colorscheme gruvbox-material")
	H.expect_hl_colors(child, "GitCommittedSign", { fg = "#d3869b" })
end

T["git: Committed signs are absent without a base"] = function()
	local root = prbranch()
	H.git(root, { "stash", "-q" })
	H.git(root, { "checkout", "-q", "main" })
	install_sign_reader()
	edit(root, "internal/billing/invoice.go")
	child.lua([[vim.wait(1000, function() return false end)]])
	eq(child.lua_get("CommittedSigns()"), {})
end

T["git: Committed signs skip files the branch did not change"] = function()
	local root = prbranch()
	H.write_files(root, { ["notes.md"] = "notes" })
	child.lua([[
		GitCatFileCalls = {}
		local original_system = vim.system
		vim.system = function(command, opts, callback)
			if command[1] == "git" and command[2] == "cat-file" and command[3] == "blob" then
				table.insert(GitCatFileCalls, vim.deepcopy(command))
			end
			return original_system(command, opts, callback)
		end
	]])
	install_sign_reader()
	for _, path in ipairs({ "internal/money/money.go", "notes.md" }) do
		edit(root, path)
		child.lua([[vim.wait(1000, function() return false end)]])
		eq(child.lua_get("CommittedSigns()"), {})
	end
	eq(child.lua_get("GitCatFileCalls"), {})
end

T["git: Committed signs compare a renamed file with its old path"] = function()
	local root = branch_repo({
		["lib/util.lua"] = "local M = {}\nM.a = 1\nreturn M",
	})
	H.git(root, { "mv", "lib/util.lua", "lib/helpers.lua" })
	H.write_files(root, { ["lib/helpers.lua"] = "local M = {}\nM.a = 10\nreturn M" })
	H.git(root, { "add", "-A" })
	H.git(root, { "commit", "-q", "-m", "rename util" })
	install_sign_reader()
	edit(root, "lib/helpers.lua")
	wait_for_signs({
		["2"] = { kind = "bar", text = "┃", hl = "GitCommittedSign", priority = 5 },
	})
end

T["git: Committed signs skip a file over the line limit"] = function()
	local root = prbranch()
	child.lua([[require("gleb.git.committed_signs").MAX_LINES = 10]])
	install_sign_reader()
	edit(root, "internal/billing/tax.go")
	child.lua([[vim.wait(1000, function() return false end)]])
	eq(child.lua_get("CommittedSigns()"), {})
end

T["git: Committed signs move with unsaved edits"] = function()
	local root, manifest = prbranch()
	install_sign_reader()
	edit(root, "internal/billing/invoice.go")
	wait_for_signs(expected_bars(manifest.committed["internal/billing/invoice.go"]))

	child.type_keys("gg", "O", "// one", "<Esc>", "o", "// two", "<Esc>")
	local expected = {}
	for line, sign in pairs(expected_bars(manifest.committed["internal/billing/invoice.go"])) do
		expected[tostring(tonumber(line) + 2)] = sign
	end
	wait_for_signs(expected)
	eq(child.bo.modified, true)
end

T["git: Committed signs yield to a local change on the same line"] = function()
	local root, manifest = prbranch()
	local path = "internal/billing/invoice.go"
	local line = manifest.committed[path].change[1]
	install_sign_reader()
	edit(root, path)
	local expected = expected_bars(manifest.committed[path])
	wait_for_signs(expected)

	child.type_keys(tostring(line) .. "G", "cc", "\tTax   Rate // per invoice", "<Esc>")
	expected[tostring(line)] = nil
	wait_for_signs(expected)
	eq(child.bo.modified, true)
	child.lua([[TargetLine = ...]], { line })
	eq(child.wait("GitsignsSignAt(TargetLine)", ASYNC_MS), true)
end

T["git: Committed signs refresh after a commit"] = function()
	local root, manifest = prbranch()
	local path = "internal/billing/invoice.go"
	install_sign_reader()
	edit(root, path)
	wait_for_signs(expected_bars(manifest.committed[path]))

	H.git(root, { "commit", "-qam", "wip" })
	local line = manifest.hunks[path][1]
	child.lua([[TargetLine = ...]], { line })
	eq(child.wait("CommittedSigns()[tostring(TargetLine)] ~= nil", ASYNC_MS), true)
end

T["git: Committed signs clear when HEAD is detached"] = function()
	local root, manifest = prbranch()
	local path = "internal/billing/invoice.go"
	install_sign_reader()
	edit(root, path)
	wait_for_signs(expected_bars(manifest.committed[path]))

	H.git(root, { "checkout", "-q", "--detach" })
	wait_for_signs({})
end

return T
