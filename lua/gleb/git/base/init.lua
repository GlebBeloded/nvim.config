local rules = require("gleb.git.base.rules")

local M = {
	GH_TIMEOUT_MS = 10000,
	PR_TTL_MS = 300000,
	WATCH_DEBOUNCE_MS = 200,
}

---@class gleb.git.base.Pr
---@field number integer
---@field url string
---@field base_ref_name string
---@field base_ref_oid string
---@field head_ref_name string
---@field head_ref_oid string
---@field host? string

---@class gleb.git.base.Info
---@field root string
---@field branch string
---@field head string
---@field default_branch string
---@field base_ref string
---@field base_oid string
---@field merge_base string
---@field source "pr"|"default"
---@field pr? gleb.git.base.Pr

---@class gleb.git.base.Watch
---@field handle uv.uv_fs_event_t
---@field path string

---@class gleb.git.base.RootState
---@field info? gleb.git.base.Info
---@field resolved boolean
---@field dirty boolean
---@field running boolean
---@field pending? table
---@field callbacks function[]
---@field request integer
---@field branch? string
---@field last_pr? { branch: string, at: integer, pr?: gleb.git.base.Pr }
---@field watchers gleb.git.base.Watch[]
---@field timer? uv.uv_timer_t
---@field process? vim.SystemObj

---@class gleb.git.base.State
---@field roots table<string, gleb.git.base.RootState>
---@field root_of table<string, string|false>

---@type gleb.git.base.State
M.state = { roots = {}, root_of = {} }

local PR_ARGS = { "pr", "view", "--json", "number,url,state,baseRefName,baseRefOid,headRefName,headRefOid" }

---@param value? string
---@return string?
local function output(value)
	value = vim.trim(value or "")
	return value ~= "" and value or nil
end

---@param path string
---@return string
local function directory(path)
	path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
	local stat = vim.uv.fs_stat(path)
	return stat and stat.type == "directory" and path or vim.fs.dirname(path)
end

---@param root string
---@param args string[]
---@param callback fun(result: vim.SystemCompleted)
---@param opts? table
---@return vim.SystemObj
local function git(root, args, callback, opts)
	local command = vim.list_extend({ "git" }, args)
	return vim.system(command, vim.tbl_extend("force", { cwd = root, text = true }, opts or {}), function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

---@param left? gleb.git.base.Info
---@param right? gleb.git.base.Info
---@return boolean
local function same_info(left, right)
	if left == nil or right == nil then
		return left == right
	end
	return left.branch == right.branch
		and left.head == right.head
		and left.base_ref == right.base_ref
		and left.base_oid == right.base_oid
		and left.merge_base == right.merge_base
		and (left.pr and left.pr.number or nil) == (right.pr and right.pr.number or nil)
end

---@param root string
---@param entry gleb.git.base.RootState
---@param info? gleb.git.base.Info
local function publish(root, entry, info)
	local changed = not same_info(entry.info, info)
	entry.info = info
	entry.resolved = true
	entry.dirty = false
	if changed then
		vim.api.nvim_exec_autocmds("User", { pattern = "GlebGitBaseChanged", data = { root = root } })
	end
end

---@param entry gleb.git.base.RootState
local function answer_callbacks(entry)
	local callbacks = entry.callbacks
	entry.callbacks = {}
	for _, callback in ipairs(callbacks) do
		callback(entry.info)
	end
end

local run_refresh

---@param root string
---@param entry gleb.git.base.RootState
local function finish_refresh(root, entry)
	entry.running = false
	entry.process = nil
	answer_callbacks(entry)
	local pending = entry.pending
	entry.pending = nil
	if pending then
		run_refresh(root, entry, pending)
	end
end

---@param root string
---@param entry gleb.git.base.RootState
---@param info? gleb.git.base.Info
local function complete(root, entry, info)
	publish(root, entry, info)
	finish_refresh(root, entry)
end

---@param root string
---@param entry gleb.git.base.RootState
---@param branch string
---@param head string
---@param default_branch string
---@param refs table<string, string>
---@param pr? gleb.git.base.Pr
local function resolve_base(root, entry, branch, head, default_branch, refs, pr)
	local base_ref = "origin/" .. default_branch
	local base_oid = refs[base_ref]
	local source = "default"

	local function merge_base()
		if not base_oid then
			complete(root, entry, nil)
			return
		end
		local old = entry.info
		if
			old
			and old.branch == branch
			and old.head == head
			and old.base_oid == base_oid
			and (old.pr and old.pr.number or nil) == (pr and pr.number or nil)
		then
			entry.dirty = false
			finish_refresh(root, entry)
			return
		end
		git(root, { "merge-base", base_oid, head }, function(result)
			local merge_base_oid = output(result.stdout)
			if result.code ~= 0 or not merge_base_oid then
				complete(root, entry, nil)
				return
			end
			complete(root, entry, {
				root = root,
				branch = branch,
				head = head,
				default_branch = default_branch,
				base_ref = base_ref,
				base_oid = base_oid,
				merge_base = merge_base_oid,
				source = source,
				pr = source == "pr" and pr or nil,
			})
		end)
	end

	if not pr then
		merge_base()
		return
	end
	local remote_ref = "origin/" .. pr.base_ref_name
	if refs[remote_ref] then
		base_ref = remote_ref
		base_oid = refs[remote_ref]
		source = "pr"
		merge_base()
		return
	end
	git(root, { "cat-file", "-e", pr.base_ref_oid .. "^{commit}" }, function(result)
		if result.code == 0 then
			base_ref = pr.base_ref_name
			base_oid = pr.base_ref_oid
			source = "pr"
		end
		merge_base()
	end)
end

---@param root string
---@param entry gleb.git.base.RootState
---@param branch string
---@param head string
---@param default_branch string
---@param refs table<string, string>
---@param remote_url? string
---@param opts table
local function resolve_pr(root, entry, branch, head, default_branch, refs, remote_url, opts)
	local last = entry.last_pr
	local elapsed = last and (vim.uv.now() - last.at) or math.huge
	local due = not last
		or last.branch ~= branch
		or opts.force
		or ((opts.reason == "focus" or opts.reason == "resolve") and elapsed > M.PR_TTL_MS)

	local function use(pr)
		entry.branch = branch
		resolve_base(root, entry, branch, head, default_branch, refs, pr)
	end

	if not due then
		use(last and last.pr or nil)
		return
	end
	if vim.fn.executable("gh") == 0 then
		use(last and last.branch == branch and last.pr or nil)
		return
	end

	local host = remote_url and rules.remote_host(remote_url) or nil
	local env = {
		GH_PROMPT_DISABLED = "1",
		GH_NO_UPDATE_NOTIFIER = "1",
		NO_COLOR = "1",
		GH_HOST = host,
	}
	local process
	process = vim.system(vim.list_extend({ "gh" }, PR_ARGS), {
		cwd = root,
		text = true,
		env = env,
		timeout = M.GH_TIMEOUT_MS,
	}, function(result)
		vim.schedule(function()
			if M.state.roots[root] ~= entry or entry.process ~= process then
				return
			end
			entry.process = nil
			local outcome = rules.pr_outcome(result.code, result.stdout or "", result.stderr or "")
			local pr = last and last.branch == branch and last.pr or nil
			if outcome.kind == "open" then
				pr = outcome.pr
				pr.host = host
			elseif outcome.kind == "none" then
				pr = nil
			end
			entry.last_pr = { branch = branch, at = vim.uv.now(), pr = pr }
			use(pr)
		end)
	end)
	entry.process = process
end

---@param stdout string
---@return table<string, string>
local function parse_refs(stdout)
	local refs = {}
	for line in stdout:gmatch("[^\n]+") do
		local name, oid = line:match("^([^\t]+)\t(.+)$")
		if name and oid then
			refs[name] = oid
		end
	end
	return refs
end

---@param root string
---@param entry gleb.git.base.RootState
---@param opts table
function run_refresh(root, entry, opts)
	if entry.running then
		entry.pending = {
			force = opts.force or (entry.pending and entry.pending.force),
			reason = opts.reason or (entry.pending and entry.pending.reason),
		}
		return
	end
	entry.running = true
	entry.request = entry.request + 1
	local request = entry.request
	local commands = {
		branch = { "symbolic-ref", "--quiet", "--short", "HEAD" },
		head = { "rev-parse", "--verify", "--quiet", "HEAD^{commit}" },
		origin_head = { "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" },
		refs = { "for-each-ref", "--format=%(refname:short)%09%(objectname)", "refs/remotes/origin/" },
		remote_url = { "remote", "get-url", "origin" },
	}
	local results = {}
	local remaining = 0
	for _ in pairs(commands) do
		remaining = remaining + 1
	end
	for name, args in pairs(commands) do
		git(root, args, function(result)
			if M.state.roots[root] ~= entry or entry.request ~= request then
				return
			end
			results[name] = result
			remaining = remaining - 1
			if remaining ~= 0 then
				return
			end
			local branch = results.branch.code == 0 and output(results.branch.stdout) or nil
			local head = results.head.code == 0 and output(results.head.stdout) or nil
			local refs = parse_refs(results.refs.stdout or "")
			local origin_head = results.origin_head.code == 0 and output(results.origin_head.stdout) or nil
			local default_branch = rules.default_branch(origin_head, refs)
			if rules.skip_reason(branch, head, default_branch) then
				entry.branch = branch
				complete(root, entry, nil)
				return
			end
			assert(branch and head and default_branch, "branch base state is incomplete")
			resolve_pr(
				root,
				entry,
				branch,
				head,
				default_branch,
				refs,
				results.remote_url.code == 0 and output(results.remote_url.stdout) or nil,
				opts
			)
		end)
	end
end

---@param root string
---@param entry gleb.git.base.RootState
local function mark_dirty(root, entry)
	if M.state.roots[root] ~= entry then
		return
	end
	entry.dirty = true
	if not entry.timer then
		entry.timer = vim.uv.new_timer()
	end
	entry.timer:stop()
	entry.timer:start(M.WATCH_DEBOUNCE_MS, 0, function()
		vim.schedule(function()
			if M.state.roots[root] == entry then
				M.refresh(root, { reason = "watch" })
			end
		end)
	end)
end

---@param root string
---@param entry gleb.git.base.RootState
---@param path string
local function add_watch(root, entry, path)
	local handle = vim.uv.new_fs_event()
	if handle and handle:start(path, {}, function()
		mark_dirty(root, entry)
	end) then
		table.insert(entry.watchers, { handle = handle, path = path })
	elseif handle then
		handle:close()
	end
end

---@param root string
---@param git_dir string
---@param common_dir string
---@return gleb.git.base.RootState
local function root_state(root, git_dir, common_dir)
	local entry = M.state.roots[root]
	if entry then
		return entry
	end
	entry = {
		resolved = false,
		dirty = true,
		running = false,
		callbacks = {},
		request = 0,
		watchers = {},
	}
	M.state.roots[root] = entry
	add_watch(root, entry, git_dir)
	if common_dir ~= git_dir then
		add_watch(root, entry, common_dir)
	end
	return entry
end

---@param entry gleb.git.base.RootState
local function close_entry(entry)
	if entry.process then
		entry.process:kill(15)
	end
	if entry.timer then
		entry.timer:stop()
		entry.timer:close()
	end
	for _, watch in ipairs(entry.watchers) do
		watch.handle:stop()
		watch.handle:close()
	end
end

---@param root string
local function forget(root)
	local entry = M.state.roots[root]
	if not entry then
		return
	end
	close_entry(entry)
	M.state.roots[root] = nil
	for dir, known_root in pairs(M.state.root_of) do
		if known_root == root then
			M.state.root_of[dir] = nil
		end
	end
end

---@param root string
---@return boolean
local function has_loaded_buffer(root)
	local prefix = root .. "/"
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
		if vim.api.nvim_buf_is_loaded(buf) and (name == root or name:sub(1, #prefix) == prefix) then
			return true
		end
	end
	return false
end

---@param root string
---@param opts? table
function M.refresh(root, opts)
	root = vim.fs.normalize(root)
	local entry = M.state.roots[root]
	if entry then
		run_refresh(root, entry, opts or {})
	end
end

---@param root string
---@return gleb.git.base.Info?
function M.get(root)
	local entry = M.state.roots[vim.fs.normalize(root)]
	return entry and entry.info or nil
end

---@param path string
---@param callback fun(info?: gleb.git.base.Info)
function M.resolve(path, callback)
	local dir = directory(path)
	local known = M.state.root_of[dir]
	local function use_root(root, git_dir, common_dir)
		if not root then
			vim.schedule(function()
				callback(nil)
			end)
			return
		end
		local entry = root_state(root, git_dir, common_dir)
		table.insert(entry.callbacks, callback)
		if entry.resolved and not entry.dirty then
			vim.schedule(function()
				if M.state.roots[root] == entry then
					answer_callbacks(entry)
				end
			end)
		else
			run_refresh(root, entry, { reason = "resolve" })
		end
	end

	if known == false then
		use_root(nil)
		return
	elseif known then
		local entry = M.state.roots[known]
		use_root(known, entry.watchers[1].path, entry.watchers[2] and entry.watchers[2].path or entry.watchers[1].path)
		return
	end
	git(dir, { "rev-parse", "--show-toplevel", "--absolute-git-dir", "--git-common-dir" }, function(result)
		if result.code ~= 0 then
			M.state.root_of[dir] = false
			use_root(nil)
			return
		end
		local lines = vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })
		local root = vim.fs.normalize(lines[1])
		local git_dir = vim.fs.normalize(lines[2])
		local common_dir = lines[3]
		if not vim.startswith(common_dir, "/") then
			common_dir = vim.fs.joinpath(root, common_dir)
		end
		common_dir = vim.fs.normalize(common_dir)
		M.state.root_of[dir] = root
		use_root(root, git_dir, common_dir)
	end)
end

function M.reset()
	for _, entry in pairs(M.state.roots) do
		close_entry(entry)
	end
	M.state.roots = {}
	M.state.root_of = {}
end

local group = vim.api.nvim_create_augroup("gleb_git_base", { clear = true })

vim.api.nvim_create_autocmd("FocusGained", {
	group = group,
	callback = function()
		for root in pairs(M.state.roots) do
			M.refresh(root, { reason = "focus" })
		end
	end,
})

vim.api.nvim_create_autocmd("BufUnload", {
	group = group,
	callback = function(args)
		local name = vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf))
		vim.schedule(function()
			for root in pairs(M.state.roots) do
				local prefix = root .. "/"
				if (name == root or name:sub(1, #prefix) == prefix) and not has_loaded_buffer(root) then
					forget(root)
				end
			end
		end)
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.reset })

return M
