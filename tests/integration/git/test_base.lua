local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@return string root
---@return fixtures.Manifest manifest
---@return string log
local function prbranch()
	local root, manifest = F.copy("prbranch", vim.fn.tempname() .. "/prbranch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	return root, manifest, log
end

---@param root string
---@param manifest fixtures.Manifest
---@param state? string
local function write_pr(root, manifest, state)
	local path = vim.fn.tempname()
	local head = vim.trim(H.git(root, { "rev-parse", "HEAD" }))
	vim.fn.writefile({
		vim.json.encode({
			number = 482,
			url = "https://pgw.dev/finteqhub/billing/pull/482",
			state = state or "OPEN",
			baseRefName = "release/1.4",
			baseRefOid = manifest.pr_merge_base,
			headRefName = "feat/tax",
			headRefOid = head,
		}),
	}, path)
	child.lua([[vim.env.FAKE_GH_STDOUT = ...; vim.env.FAKE_GH_CODE = "0"]], { path })
end

---@param path string
---@return table|vim.NIL
local function resolve(path)
	child.lua(
		[[BaseDone = false; BaseResult = nil
		require("gleb.git.base").resolve(..., function(info) BaseResult = info; BaseDone = true end)]],
		{ path }
	)
	eq(child.wait("BaseDone == true", 3000), true)
	return child.lua_get("BaseResult or vim.NIL")
end

local function record_events()
	child.lua([[BaseEvents = {}
		vim.api.nvim_create_autocmd("User", { pattern = "GlebGitBaseChanged", callback = function(args)
			table.insert(BaseEvents, args.data.root)
		end })]])
end

local function clear_fake_pr()
	child.lua([[vim.env.FAKE_GH_STDOUT = nil; vim.env.FAKE_GH_CODE = nil; vim.env.FAKE_GH_STDERR = nil]])
end

T["git: Branch base defaults to the remote default branch"] = function()
	local root, manifest = prbranch()
	local info = resolve(root .. "/internal/billing/invoice.go")
	eq({ info.root, info.branch, info.head:sub(1, 7), info.base_ref, info.merge_base, info.source, info.pr == nil }, {
		root,
		"feat/tax",
		manifest.head,
		"origin/main",
		manifest.merge_base,
		"default",
		true,
	})
end

T["git: Branch base follows the open pull request"] = function()
	local root, manifest = prbranch()
	write_pr(root, manifest)
	local info = resolve(root)
	eq({ info.base_ref, info.merge_base, info.source, info.pr.number, info.pr.url }, {
		"origin/release/1.4",
		manifest.pr_merge_base,
		"pr",
		482,
		"https://pgw.dev/finteqhub/billing/pull/482",
	})
end

T["git: Branch base uses the pull request base commit when its ref is missing"] = function()
	local root, manifest = prbranch()
	write_pr(root, manifest)
	H.git(root, { "update-ref", "-d", "refs/remotes/origin/release/1.4" })
	local info = resolve(root)
	eq({ info.base_ref, info.base_oid, info.merge_base }, {
		"release/1.4",
		manifest.pr_merge_base,
		manifest.pr_merge_base,
	})
end

T["git: Branch base is absent on the default branch"] = function()
	local root, _, log = prbranch()
	H.git(root, { "reset", "--hard", "-q" })
	H.git(root, { "checkout", "-q", "main" })
	eq(resolve(root), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
end

T["git: Branch base is absent on master"] = function()
	local root = H.git_repo({ ["a.txt"] = "one" })
	H.git(root, { "checkout", "-q", "-b", "master" })
	H.git(root, { "update-ref", "refs/remotes/origin/develop", "HEAD" })
	H.git(root, { "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop" })
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	eq(resolve(root), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
end

T["git: Branch base is absent on a detached HEAD"] = function()
	local root, _, log = prbranch()
	H.git(root, { "checkout", "-q", "--detach" })
	eq(resolve(root), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
end

T["git: Branch base is absent outside a repository"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	local messages = child.cmd_capture("messages")
	eq(resolve(dir .. "/a.txt"), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
	eq(child.cmd_capture("messages"), messages)
end

T["git: Branch base is absent without a remote default branch"] = function()
	local root = H.git_repo({ ["a.txt"] = "one" })
	H.git(root, { "checkout", "-q", "-b", "feat/x" })
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	eq(resolve(root), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
end

T["git: Branch base is absent for unrelated histories"] = function()
	local root = H.git_repo({ ["a.txt"] = "main" })
	H.git(root, { "update-ref", "refs/remotes/origin/main", "HEAD" })
	H.git(root, { "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main" })
	H.git(root, { "checkout", "-q", "--orphan", "feat/unrelated" })
	H.git(root, { "rm", "-q", "-rf", "." })
	H.write_files(root, { ["b.txt"] = "unrelated" })
	H.git(root, { "add", "-A" })
	H.git(root, { "commit", "-q", "-m", "unrelated" })
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	eq(resolve(root), vim.NIL)
	eq(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, {})
end

T["git: Branch base passes the remote host to gh"] = function()
	local root, _, log = prbranch()
	resolve(root)
	eq(vim.fn.readfile(log), {
		"pgw.dev\tpr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid",
	})
end

T["git: Branch base ignores a merged pull request"] = function()
	local root, manifest = prbranch()
	write_pr(root, manifest, "MERGED")
	local info = resolve(root)
	eq({ info.base_ref, info.source, info.pr == nil }, { "origin/main", "default", true })
end

T["git: Branch base falls back when gh fails"] = function()
	local root = prbranch()
	child.lua([[vim.env.FAKE_GH_STDERR = "error connecting to pgw.dev"; vim.env.FAKE_GH_CODE = "1"]])
	local messages = child.cmd_capture("messages")
	eq(resolve(root).base_ref, "origin/main")
	eq(child.cmd_capture("messages"), messages)
end

T["git: Branch base works without gh"] = function()
	local root = prbranch()
	local bin = vim.fn.tempname()
	vim.fn.mkdir(bin, "p")
	vim.uv.fs_symlink(vim.fn.exepath("git"), bin .. "/git")
	child.lua([[vim.env.PATH = ...]], { bin })
	eq(resolve(root).base_ref, "origin/main")
end

T["git: Branch base gives up on a slow gh"] = function()
	local root, _, log = prbranch()
	child.lua([[vim.env.FAKE_GH_SLEEP = "30.4817"
		require("gleb.git.base").GH_TIMEOUT_MS = 200]])
	local before = vim.uv.hrtime()
	eq(resolve(root).base_ref, "origin/main")
	eq((vim.uv.hrtime() - before) / 1e9 < 2, true)
	eq(child.lua_get([[require("gleb.git.base").state.roots[...].process == nil]], { root }), true)
	eq(vim.fn.readfile(log), {
		"pgw.dev\tpr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid",
	})
	eq(vim.system({ "pgrep", "-f", "sleep 30[.]4817$" }):wait().code ~= 0, true)
end

T["git: Branch base keeps the last pull request when gh fails"] = function()
	local root, manifest, log = prbranch()
	write_pr(root, manifest)
	eq(resolve(root).pr.number, 482)
	clear_fake_pr()
	child.lua(
		[[vim.env.FAKE_GH_STDERR = "error connecting to pgw.dev"; vim.env.FAKE_GH_CODE = "1"
		require("gleb.git.base").refresh(..., { force = true })]],
		{ root }
	)
	eq(
		vim.wait(3000, function()
			return #vim.fn.readfile(log) == 2
		end, 20),
		true
	)
	eq(child.wait(([[not require("gleb.git.base").state.roots[%q].running]]):format(root), 3000), true)
	local info = child.lua_get([[require("gleb.git.base").get(...)]], { root })
	eq({ info.pr.number, info.base_ref }, { 482, "origin/release/1.4" })
end

T["git: Branch base clears the pull request when none is found"] = function()
	local root, manifest = prbranch()
	write_pr(root, manifest)
	eq(resolve(root).pr.number, 482)
	record_events()
	clear_fake_pr()
	child.lua([[require("gleb.git.base").refresh(..., { force = true })]], { root })
	eq(child.wait([[#BaseEvents == 1]], 3000), true)
	local info = child.lua_get([[require("gleb.git.base").get(...)]], { root })
	eq({ info.base_ref, info.pr == nil, child.lua_get("BaseEvents") }, { "origin/main", true, { root } })
end

T["git: Branch base is cached"] = function()
	local root, _, log = prbranch()
	record_events()
	local first = resolve(root)
	local second = resolve(root .. "/internal/billing/invoice.go")
	child.api.nvim_exec_autocmds("FocusGained", {})
	vim.wait(100, function()
		return false
	end)
	eq(first, second)
	eq(#vim.fn.readfile(log), 1)
	eq(child.lua_get("#BaseEvents"), 1)
end

T["git: Branch base refreshes after a commit"] = function()
	local root, manifest, log = prbranch()
	record_events()
	resolve(root)
	child.lua([[BaseEvents = {}]])
	H.write_files(root, { ["new.txt"] = "new" })
	H.git(root, { "add", "new.txt" })
	H.git(root, { "commit", "-q", "-m", "new" })
	local head = vim.trim(H.git(root, { "rev-parse", "HEAD" }))
	child.lua([[BaseRoot, BaseHead = ...]], { root, head })
	eq(child.wait([[#BaseEvents > 0 and require("gleb.git.base").get(BaseRoot).head == BaseHead]], 2000), true)
	local info = child.lua_get([[require("gleb.git.base").get(...)]], { root })
	eq({ info.head, info.merge_base, #vim.fn.readfile(log) }, { head, manifest.merge_base, 1 })
end

T["git: Branch base refreshes after a checkout"] = function()
	local root = prbranch()
	H.git(root, { "reset", "--hard", "-q" })
	record_events()
	resolve(root)
	child.lua([[BaseEvents = {}]])
	H.git(root, { "checkout", "-q", "main" })
	child.lua([[BaseRoot = ...]], { root })
	eq(child.wait([[#BaseEvents > 0 and require("gleb.git.base").get(BaseRoot) == nil]], 2000), true)
end

T["git: Branch base asks gh again after the TTL on focus"] = function()
	local root, _, log = prbranch()
	resolve(root)
	child.lua([[require("gleb.git.base").PR_TTL_MS = 0]])
	child.api.nvim_exec_autocmds("FocusGained", {})
	eq(
		vim.wait(3000, function()
			return #vim.fn.readfile(log) == 2
		end, 20),
		true
	)
end

T["git: Branch base stops watching on reset"] = function()
	local root = prbranch()
	resolve(root)
	eq(
		child.lua(
			[[local base = require("gleb.git.base")
		local handles = vim.tbl_map(function(watch) return watch.handle end, base.state.roots[...].watchers)
		base.reset()
		local active = vim.iter(handles):any(function(handle) return handle:is_active() end)
		return { vim.tbl_isempty(base.state.roots), active }]],
			{ root }
		),
		{ true, false }
	)
end

T["git: Branch base discards stale asynchronous results"] = function()
	local function check(stage, with_pr)
		local root, manifest = prbranch()
		if with_pr then
			write_pr(root, manifest)
			H.git(root, { "update-ref", "-d", "refs/remotes/origin/release/1.4" })
		end
		record_events()
		child.lua(
			[[local stage, root = ...
			local original = vim.system
			local merge_base_calls = 0
			StaleGitCallback = nil
			BaseDone = false
			vim.system = function(command, opts, callback)
				if command[1] == "git" and command[2] == "merge-base" then
					merge_base_calls = merge_base_calls + 1
				end
				local hold = command[1] == "git" and command[2] == stage
					and (command[2] ~= "merge-base" or merge_base_calls == 2)
				if hold then
					return original(command, opts, function(result)
						StaleGitCallback = function() callback(result) end
					end)
				end
				return original(command, opts, callback)
			end
			OriginalSystem = original
			require("gleb.git.base").resolve(root, function() BaseDone = true end)]],
			{ stage, root }
		)
		eq(child.wait("StaleGitCallback ~= nil", 3000), true)
		child.lua([[require("gleb.git.base").reset(); StaleGitCallback(); vim.system = OriginalSystem
			vim.wait(100, function() return false end)]])
		eq(child.lua_get([[{ BaseDone, #BaseEvents, vim.tbl_isempty(require("gleb.git.base").state.roots) }]]), {
			false,
			0,
			true,
		})
	end

	check("cat-file", true)
	check("merge-base", false)
end

return T
