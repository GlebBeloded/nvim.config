-- Changes Git requests run asynchronously in the panel's repository root.

local M = {}

local fs = require("gleb.file_tree.fs")
local file_tree_model = require("gleb.file_tree.model")

---@class ChangesGitState
---@field last_cmd? string[]

---@type ChangesGitState
M.state = {}

--- Resolve the repository containing a directory.
---@param dir string
---@param callback fun(result: vim.SystemCompleted, root: string?)
---@return nil
function M.resolve_root(dir, callback)
	local command = { "git", "rev-parse", "--show-toplevel" }
	vim.system(command, { cwd = fs.normalize(dir), text = true }, function(result)
		vim.schedule(function()
			local root = result.code == 0 and fs.normalize(vim.trim(result.stdout or "")) or nil
			callback(result, root)
		end)
	end)
end

--- Refresh porcelain status for one Changes panel.
---@param root string
---@param callback fun(result: vim.SystemCompleted)
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
	M.state.last_cmd = command
	vim.system(command, { cwd = fs.normalize(root), text = true }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
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
		vim.schedule(function()
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
		end)
	end

	vim.system(left_command, { cwd = root, text = true }, function(result)
		left_result = result
		finish()
	end)
	vim.system(hash_command, { cwd = root, text = true }, function(result)
		hash_result = result
		finish()
	end)
	vim.system(numstat_command, { cwd = root, text = true }, function(result)
		numstat_result = result
		finish()
	end)
end

---@param records FileTreeStatusRecord[]
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

---@param command string[]
---@param paths string[]
---@return string[] command
---@return table opts
local function add_pathspec(command, paths)
	local opts = { text = true }
	if #paths > 100 then
		vim.list_extend(command, { "--pathspec-from-file=-", "--pathspec-file-nul" })
		opts.stdin = table.concat(paths, "\0") .. "\0"
	else
		command[#command + 1] = "--"
		vim.list_extend(command, paths)
	end
	return command, opts
end

---@param records FileTreeStatusRecord[]
---@return boolean
local function has_conflict(records)
	return vim.iter(records):any(function(record)
		return record.kind == "u"
	end)
end

---@param root string
---@param records FileTreeStatusRecord[]
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
---@param records FileTreeStatusRecord[]
---@return FileTreeStatusRecord[]
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
	root = fs.normalize(root)
	paths = vim.tbl_map(fs.normalize, paths)
	local status_command = {
		"git",
		"--literal-pathspecs",
		"status",
		"--porcelain=v2",
		"-z",
		"--untracked-files=all",
	}
	M.state.last_cmd = status_command
	vim.system(status_command, { cwd = root, text = true }, function(status_result)
		vim.schedule(function()
			if status_result.code ~= 0 then
				callback(status_result)
				return
			end
			local records =
				selected_records(root, paths, file_tree_model.parse_status_records(status_result.stdout or ""))
			if has_conflict(records) then
				callback({ code = 1, signal = 0, stdout = "", stderr = "resolve conflicts in the merge tool" })
				return
			end
			local operation = fully_staged(records) and "reset" or "add"
			local command = { "git", "--literal-pathspecs", operation }
			if operation == "reset" then
				command[#command + 1] = "-q"
			end
			local command_opts
			command, command_opts = add_pathspec(command, record_paths(root, records))
			M.state.last_cmd = command
			command_opts.cwd = root
			vim.system(command, command_opts, function(result)
				vim.schedule(function()
					callback(result)
				end)
			end)
		end)
	end)
end

--- Stage every change in a repository.
---@param root string
---@param callback fun(result: vim.SystemCompleted)
---@return nil
function M.stage_all(root, callback)
	local command = { "git", "--literal-pathspecs", "add", "-A" }
	M.state.last_cmd = command
	vim.system(command, { cwd = fs.normalize(root), text = true }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

return M
