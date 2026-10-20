local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["loop: Check prunes stale Neovim temp dirs"] = function()
	local root = vim.fs.joinpath(vim.fn.tempname(), "nvim.prunetest")
	for _, name in ipairs({ "OldGone", "Young", "OldLive" }) do
		vim.fn.mkdir(vim.fs.joinpath(root, name, "data"), "p")
	end
	eq(H.system(child, { "chmod", "a-w", vim.fs.joinpath(root, "OldGone", "data") }, root).code, 0) -- a read-only fixture
	-- a dir a permission test left write-only (d-w-------: the billing fixture's `locked`), its entry unreadable
	vim.fn.mkdir(vim.fs.joinpath(root, "OldGone", "locked", "inner"), "p")
	eq(H.system(child, { "chmod", "200", vim.fs.joinpath(root, "OldGone", "locked") }, root).code, 0)
	for _, name in ipairs({ "OldGone", "OldLive" }) do
		eq(H.system(child, { "touch", "-t", "202001010000", vim.fs.joinpath(root, name) }, root).code, 0)
	end
	local live = vim.system({ "sh", "-c", "sleep 30; :", vim.fs.joinpath(root, "OldLive", "socket") })
	local result = H.system(child, { vim.fs.joinpath(H.root, "tests/prune_tmp.sh"), root }, root)
	live:kill(9)
	eq({ result.code, result.stderr }, { 0, "" }, { fail_reason = result.stdout .. result.stderr })
	eq({
		vim.fn.isdirectory(vim.fs.joinpath(root, "OldGone")),
		vim.fn.isdirectory(vim.fs.joinpath(root, "Young")),
		vim.fn.isdirectory(vim.fs.joinpath(root, "OldLive")),
	}, { 0, 1, 1 })
	eq(result.stdout:find("removed 1 stale Neovim temp dirs", 1, true) ~= nil, true, { fail_reason = result.stdout })
end

T["loop: Check stops orphaned test processes"] = function()
	local root = vim.fs.joinpath(vim.fn.tempname(), "nvim.orphantest")
	vim.fn.mkdir(vim.fs.joinpath(root, "Live", "data"), "p")
	-- a language server whose test child died: its shell exits, so it is reparented to launchd
	local env = { XDG_DATA_HOME = vim.fs.joinpath(root, "Live", "data") }
	local pid_file = vim.fs.joinpath(root, "pid")
	-- a Neovim, not /bin/sleep: macOS hides a system binary's env from `ps eww`
	local server = ("%q --clean --headless -c 'sleep 300' </dev/null >/dev/null 2>&1 &"):format(vim.v.progpath)
	H.system(child, { "sh", "-c", server .. (" echo $! > %q"):format(pid_file) }, root, env)
	local pid = tonumber(vim.fn.readfile(pid_file)[1])
	local other = vim.system({ "sleep", "300" }) -- this process's own child: not an orphan, not under root
	local result = H.system(child, { vim.fs.joinpath(H.root, "tests/prune_tmp.sh"), root .. "/" }, root)
	eq({ result.code, result.stderr }, { 0, "" }, { fail_reason = result.stdout .. result.stderr })
	eq(result.stdout:find("stopped 1 orphaned test processes", 1, true) ~= nil, true, { fail_reason = result.stdout })
	eq(
		vim.wait(5000, function()
			return vim.uv.kill(pid, 0) ~= 0
		end, 50),
		true
	)
	eq(vim.uv.kill(other.pid, 0), 0)
	other:kill(9)
end

return T
