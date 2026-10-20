-- Changes Git requests run asynchronously in the panel's repository root.

local M = {}

local git_status = require("gleb.git.status")
local workspace = require("gleb.workspace")

---@class ChangesGitState
---@field last_cmd? string[]

---@type ChangesGitState
M.state = {}

---@class ChangesGitArgs: table
---@field [integer] string
---@field stdin? string

--- Run a Git command and deliver its result on Neovim's main loop.
---@param args ChangesGitArgs
---@param cwd string
---@param callback fun(result: vim.SystemCompleted)
---@param env? table<string, string>
---@return nil
local function run_git(args, cwd, callback, env)
	local command = vim.list_slice(args)
	vim.system(command, { cwd = workspace.normalize(cwd), text = true, stdin = args.stdin, env = env }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

--- Resolve the repository containing a directory.
---@param dir string
---@param callback fun(result: vim.SystemCompleted, root: string?)
---@return nil
function M.resolve_root(dir, callback)
	local command = { "git", "rev-parse", "--show-toplevel" }
	run_git(command, dir, function(result)
		local root = result.code == 0 and workspace.normalize(vim.trim(result.stdout or "")) or nil
		callback(result, root)
	end)
end

--- Refresh porcelain status and line stats for one Changes panel.
--- Stats come from plumbing `diff-index`, which never takes the index lock that a concurrent
--- stage or revert needs; they are nil when it fails, as it does on an unborn HEAD.
---@param root string
---@param callback fun(result: vim.SystemCompleted, numstat_z: string?)
---@return nil
function M.refresh(root, callback)
	local command = {
		"git",
		"--no-optional-locks",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
	}
	local numstat_command =
		{ "git", "--no-optional-locks", "--literal-pathspecs", "diff-index", "-M", "--numstat", "-z", "HEAD" }
	local cwd = workspace.normalize(root)
	local status_result
	local numstat_result

	local function finish()
		if not status_result or not numstat_result then
			return
		end
		callback(status_result, numstat_result.code == 0 and numstat_result.stdout or nil)
	end

	M.state.last_cmd = command
	local lock_free_env = { GIT_OPTIONAL_LOCKS = "0" }
	run_git(command, cwd, function(result)
		status_result = result
		finish()
	end, lock_free_env)
	run_git(numstat_command, cwd, function(result)
		numstat_result = result
		finish()
	end, lock_free_env)
end

---@param text string
---@return string[]
local function text_lines(text)
	if text == "" then
		return {}
	end
	return vim.split(text:gsub("\n$", ""), "\n", { plain = true })
end

---@param path string
---@return string[]
local function readonly_file_lines(path)
	return vim.tbl_map(function(line)
		local sanitized = line:gsub("\n", "�")
		return sanitized
	end, vim.fn.readfile(path, "b"))
end

---@param root string
---@param row ChangesRow
---@param callback fun(spec: gleb.diff.view.Spec, loaded_buf: integer?)
---@return nil
function M.load_diff(root, row, callback)
	local relpath = assert(row.path, "file row path missing")
	local path = vim.fs.joinpath(root, relpath)
	local head_path = row.orig or relpath
	local left_command = { "git", "show", "HEAD:" .. head_path }
	local hash_command = { "git", "rev-parse", "--short=7", "HEAD" }
	local numstat_command = { "git", "--literal-pathspecs", "diff", "--numstat", "HEAD", "--", relpath }
	local left_result
	local hash_result
	local numstat_result

	local function finish()
		if not left_result or not hash_result or not numstat_result then
			return
		end
		local added = row.status == "added" or row.status == "untracked"
		local deleted = row.status == "deleted"
		local binary = (numstat_result.stdout or ""):match("^%-\t%-\t") ~= nil
		local readonly = deleted or binary or row.status == "conflict"
		local right = {}
		local right_buf
		local loaded_buf
		if not deleted then
			if readonly then
				right = readonly_file_lines(path)
			else
				right_buf = vim.fn.bufnr(path, false)
				if right_buf == -1 then
					right_buf = vim.fn.bufadd(path)
				end
				if not vim.api.nvim_buf_is_loaded(right_buf) then
					loaded_buf = right_buf
				end
				vim.fn.bufload(right_buf)
				right = vim.api.nvim_buf_get_lines(right_buf, 0, -1, false)
			end
		end
		local left_text = left_result.stdout or ""
		callback({
			path = path,
			root = root,
			relpath = relpath,
			left = added and {} or text_lines(left_text),
			right = right,
			right_buf = right_buf,
			actionable = not added and not readonly,
			head_final_newline = not added and left_text:sub(-1) == "\n",
			filetype = vim.filetype.match({ filename = path }) or "",
			labels = {
				left = (hash_result.code == 0 and vim.trim(hash_result.stdout or "") or "HEAD") .. " · HEAD",
				right = "Your version",
			},
		}, loaded_buf)
	end

	run_git(left_command, root, function(result)
		left_result = result
		finish()
	end)
	run_git(hash_command, root, function(result)
		hash_result = result
		finish()
	end)
	run_git(numstat_command, root, function(result)
		numstat_result = result
		finish()
	end)
end

---@class ChangesBranchDiffContext
---@field merge_base string
---@field base_name string
---@field head string
---@field commit? string
---@field parent? string
---@field subject? string

--- Load a committed Branch-tab comparison without using a working-tree buffer.
---@param root string
---@param row ChangesRow
---@param context ChangesBranchDiffContext
---@param callback fun(spec: gleb.diff.view.Spec)
---@return nil
function M.load_branch_diff(root, row, context, callback)
	local relpath = assert(row.path, "file row path missing")
	local path = vim.fs.joinpath(root, relpath)
	local left_path = row.orig or relpath
	local left_revision = context.parent or context.merge_base
	local right_revision = context.commit or "HEAD"
	local left_result = row.status == "added" and { code = 0, stdout = "" } or nil
	local right_result = row.status == "deleted" and { code = 0, stdout = "" } or nil

	local function finish()
		if not left_result or not right_result then
			return
		end
		local left_text = left_result.stdout or ""
		local right_text = right_result.stdout or ""
		local left_label
		local right_label
		if context.commit then
			left_label = (context.parent or left_revision):sub(1, 7) .. " · parent"
			right_label = context.commit:sub(1, 7) .. " · " .. assert(context.subject, "Commit subject missing")
		else
			left_label = context.merge_base:sub(1, 7) .. " · " .. context.base_name
			right_label = context.head:sub(1, 7) .. " · HEAD"
		end
		callback({
			path = path,
			root = root,
			relpath = relpath,
			left = text_lines(left_text),
			right = text_lines(right_text),
			actionable = false,
			committed = true,
			head_final_newline = left_text:sub(-1) == "\n",
			filetype = vim.filetype.match({ filename = path }) or "",
			labels = { left = left_label, right = right_label },
		})
	end

	if not left_result then
		run_git({ "git", "show", left_revision .. ":" .. left_path }, root, function(result)
			left_result = result
			finish()
		end)
	end
	if not right_result then
		run_git({ "git", "show", right_revision .. ":" .. relpath }, root, function(result)
			right_result = result
			finish()
		end)
	end
	finish()
end

---@param records GitStatusRecord[]
---@return boolean
local function fully_staged(records)
	if #records == 0 then
		return false
	end
	for _, record in ipairs(records) do
		local xy = record.xy or ".."
		if record.kind == "?" or xy:sub(1, 1) == "." or xy:sub(2, 2) ~= "." then
			return false
		end
	end
	return true
end

---@param command ChangesGitArgs
---@param paths string[]
---@return ChangesGitArgs command
local function add_pathspec(command, paths)
	if #paths > 100 then
		vim.list_extend(command, { "--pathspec-from-file=-", "--pathspec-file-nul" })
		command.stdin = table.concat(paths, "\0") .. "\0"
	else
		command[#command + 1] = "--"
		vim.list_extend(command, paths)
	end
	return command
end

---@param records GitStatusRecord[]
---@return boolean
local function has_conflict(records)
	return vim.iter(records):any(function(record)
		return record.kind == "u"
	end)
end

---@param root string
---@param records GitStatusRecord[]
---@return string[]
local function record_paths(root, records)
	local paths = {}
	for _, record in ipairs(records) do
		paths[#paths + 1] = vim.fs.joinpath(root, record.path)
		if record.orig then
			paths[#paths + 1] = vim.fs.joinpath(root, record.orig)
		end
	end
	return paths
end

---@param root string
---@param paths string[]
---@param records GitStatusRecord[]
---@return GitStatusRecord[]
local function selected_records(root, paths, records)
	local selected = {}
	for _, path in ipairs(paths) do
		selected[path:sub(#root + 2)] = true
	end
	return vim.iter(records)
		:filter(function(record)
			return selected[record.path] == true
		end)
		:totable()
end

---@param root string
---@param paths string[]
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.toggle_stage(root, paths, callback)
	root = workspace.normalize(root)
	paths = vim.tbl_map(workspace.normalize, paths)
	local status_command = {
		"git",
		"--literal-pathspecs",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
	}
	M.state.last_cmd = status_command
	run_git(status_command, root, function(status_result)
		if status_result.code ~= 0 then
			callback(status_result)
			return
		end
		local records = selected_records(root, paths, git_status.parse_records(status_result.stdout or ""))
		if has_conflict(records) then
			callback({ code = 1, signal = 0, stdout = "", stderr = "resolve conflicts in the merge tool" })
			return
		end
		local operation = fully_staged(records) and "reset" or "add"
		local command = { "git", "--literal-pathspecs", operation }
		if operation == "reset" then
			command[#command + 1] = "-q"
		end
		command = add_pathspec(command, record_paths(root, records))
		M.state.last_cmd = vim.list_slice(command)
		run_git(command, root, callback)
	end)
end

--- Stage every change in a repository.
---@param root string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.stage_all(root, callback)
	local command = { "git", "--literal-pathspecs", "add", "-A" }
	M.state.last_cmd = command
	run_git(command, root, callback)
end

--- Commit the staged changes in one Changes panel repository.
---@param root string
---@param message string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.commit(root, message, callback)
	local command = { "git", "--literal-pathspecs", "commit", "-m", message }
	run_git(command, root, callback)
end

--- Push the current branch from one Changes panel repository.
---@param root string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.push(root, callback)
	run_git({ "git", "push" }, root, callback)
end

---@param root string
---@param row ChangesRow
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.revert(root, row, callback)
	root = workspace.normalize(root)
	local relpath = assert(row.path, "file row path missing")
	local path = vim.fs.joinpath(root, relpath)
	local command
	if row.orig then
		command = {
			"git",
			"--literal-pathspecs",
			"checkout",
			"HEAD",
			"--",
			vim.fs.joinpath(root, row.orig),
		}
	elseif row.status == "added" then
		command = { "git", "--literal-pathspecs", "rm", "--cached", "--", path }
	else
		command = { "git", "--literal-pathspecs", "checkout", "HEAD", "--", path }
	end
	M.state.last_cmd = command
	run_git(command, root, function(result)
		if result.code ~= 0 or not row.orig then
			callback(result)
			return
		end
		local remove = { "git", "--literal-pathspecs", "rm", "--cached", "--", path }
		M.state.last_cmd = remove
		run_git(remove, root, callback)
	end)
end

return M
