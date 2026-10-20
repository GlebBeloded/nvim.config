-- Branch-change helpers turn Git's NUL-delimited output into stable model inputs.

local M = {}

local changes_model = require("gleb.git.changes.model")
local settings = require("gleb.tree.settings")

---@class ChangesBranchFile
---@field status "added"|"modified"|"deleted"|"renamed"
---@field path string
---@field orig? string

---@class ChangesBranchCommit
---@field hash string
---@field parents string[]
---@field timestamp integer
---@field subject string

local STATUS_NAMES = {
	A = "added",
	D = "deleted",
	M = "modified",
}

---@param count integer
---@param merge_base string
---@return string
function M.summary(count, merge_base)
	local noun = count == 1 and "commit" or "commits"
	return string.format("%d %s · merge-base %s", count, noun, merge_base:sub(1, 7))
end

---@param seconds integer
---@return string
function M.age(seconds)
	if seconds < 60 then
		return "now"
	elseif seconds < 60 * 60 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 24 * 60 * 60 then
		return math.floor(seconds / (60 * 60)) .. "h"
	elseif seconds < 14 * 24 * 60 * 60 then
		return math.floor(seconds / (24 * 60 * 60)) .. "d"
	elseif seconds < 60 * 24 * 60 * 60 then
		return math.floor(seconds / (7 * 24 * 60 * 60)) .. "w"
	elseif seconds < 365 * 24 * 60 * 60 then
		return math.floor(seconds / (30 * 24 * 60 * 60)) .. "mo"
	end
	return math.floor(seconds / (365 * 24 * 60 * 60)) .. "y"
end

---@return integer
function M.now()
	return os.time()
end

---@param output string
---@return ChangesBranchCommit[]
function M.parse_commits(output)
	local commits = {}
	local records = vim.split(output, "\0\0", { plain = true, trimempty = true })
	for _, record in ipairs(records) do
		local fields = vim.split(record, "\0", { plain = true })
		table.insert(commits, {
			hash = fields[1],
			parents = vim.split(fields[2], " ", { plain = true, trimempty = true }),
			timestamp = assert(tonumber(fields[3]), "invalid commit timestamp"),
			subject = fields[4],
		})
	end
	return commits
end

---@param output string
---@return ChangesBranchFile[]
function M.parse_name_status(output)
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local files = {}
	local index = 1
	while index <= #fields do
		local code = fields[index]
		local kind = code:sub(1, 1)
		if kind == "R" or kind == "C" then
			table.insert(files, { status = "renamed", orig = fields[index + 1], path = fields[index + 2] })
			index = index + 3
		else
			table.insert(files, { status = STATUS_NAMES[kind] or "modified", path = fields[index + 1] })
			index = index + 2
		end
	end
	return files
end

---@param output string
---@return table<string, { added: integer, removed: integer }>
local function parse_numstat(output)
	local stats = {}
	local fields = vim.split(output, "\0", { plain = true })
	local index = 1
	while index <= #fields do
		local added, removed, path = fields[index]:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		if path == "" then
			path = fields[index + 2]
			index = index + 2
		end
		if path and tonumber(added) and tonumber(removed) then
			stats[path] = { added = assert(tonumber(added)), removed = assert(tonumber(removed)) }
		end
		index = index + 1
	end
	return stats
end

---@param rows ChangesRow[]
---@return gleb.ui.tree.Node[]
local function file_nodes(rows)
	local roots = {}
	local parents = {}
	for _, row in ipairs(rows) do
		local path = assert(row.path, "branch row has no path")
		row.id = row.kind == "file" and "branch:file:" .. path or "branch:directory:" .. path
		row.checkbox = nil
		local node = {
			id = row.id,
			children = {},
			foldable = row.kind == "directory" or row.fold_id ~= nil,
			open_by_default = true,
			data = row,
		}
		local parent = parents[row.depth - 1]
		if parent then
			parent.children[#parent.children + 1] = node
		else
			roots[#roots + 1] = node
		end
		parents[row.depth] = node
	end
	return roots
end

---@param info gleb.git.base.Info
---@param name_status string
---@param numstat string
---@param commit_count integer
---@return gleb.ui.tree.Node[]
local function nodes(info, name_status, numstat, commit_count)
	local stats = parse_numstat(numstat)
	local files = vim.iter(M.parse_name_status(name_status))
		:map(function(file)
			local stat = stats[file.path]
			---@type ChangesRow
			return {
				kind = "file",
				root = "branch",
				label = vim.fs.basename(file.path),
				depth = 0,
				path = file.path,
				orig = file.orig,
				status = file.status,
				diffable = true,
				added = stat and stat.added or nil,
				removed = stat and stat.removed or nil,
				committed = true,
			}
		end)
		:totable()
	local rows = changes_model.group_files(files, settings.load().nesting.rules, "branch")
	local base_name = info.base_ref:gsub("^origin/", "")
	local header = info.pr and ("#%d %s → %s"):format(info.pr.number, info.branch, base_name)
		or ("%s → %s"):format(info.branch, base_name)
	---@type ChangesRow[]
	local fixed = {
		{ id = "branch:header", kind = "header", root = "branch", label = header, depth = 0, pr = info.pr ~= nil },
		{
			id = "branch:summary",
			kind = "summary",
			root = "branch",
			label = M.summary(commit_count, info.merge_base),
			depth = 0,
		},
		{ id = "branch:blank", kind = "blank", root = "branch", label = "", depth = 0 },
	}
	local result = {}
	for _, row in ipairs(fixed) do
		result[#result + 1] = { id = assert(row.id, "branch fixed row has no id"), data = row }
	end
	vim.list_extend(result, file_nodes(rows))
	return result
end

--- Load branch files and return them only while the caller's generation is current.
---@param root string
---@param info gleb.git.base.Info
---@param generation integer
---@param is_current fun(generation: integer): boolean
---@param callback fun(nodes: gleb.ui.tree.Node[])
---@return nil
function M.load_files(root, info, generation, is_current, callback)
	local pending = 3
	local name_status
	local numstat
	local commit_count
	local failed = false

	---@param key "name_status"|"numstat"|"commit_count"
	---@param result vim.SystemCompleted
	local function complete(key, result)
		vim.schedule(function()
			if not is_current(generation) then
				return
			end
			failed = failed or result.code ~= 0
			if key == "name_status" then
				name_status = result.stdout or ""
			elseif key == "numstat" then
				numstat = result.stdout or ""
			else
				commit_count = tonumber(vim.trim(result.stdout or ""))
			end
			pending = pending - 1
			if pending == 0 and not failed and commit_count then
				callback(nodes(info, name_status or "", numstat or "", commit_count))
			end
		end)
	end

	local range = info.merge_base .. "..HEAD"
	vim.system({ "git", "diff", "--name-status", "-z", "-M", info.merge_base, "HEAD" }, {
		cwd = root,
		text = true,
	}, function(result)
		complete("name_status", result)
	end)
	vim.system({ "git", "diff", "--numstat", "-z", "-M", info.merge_base, "HEAD" }, {
		cwd = root,
		text = true,
	}, function(result)
		complete("numstat", result)
	end)
	vim.system({ "git", "rev-list", "--count", range }, { cwd = root, text = true }, function(result)
		complete("commit_count", result)
	end)
end

return M
