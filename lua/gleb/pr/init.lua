-- Pull-request review cache: coordinates base metadata, GitHub fetches, and update publication per root.
local gh = require("gleb.pr.gh")
local threads = require("gleb.pr.threads")
local debounce = require("gleb.util.debounce")

local BLOB_CACHE_MAX = 200
local WRITE_DEBOUNCE_MS = 1000
local WRITE_MIN_INTERVAL_MS = 30000

local M = {
	GH_TIMEOUT_MS = 20000,
}

---@class gleb.pr.Review
---@field root string
---@field pr gleb.git.base.Pr
---@field host string
---@field owner string
---@field name string
---@field head string
---@field threads table[]
---@field timeout integer
---@field fetched_at? integer

---@class gleb.pr.State
---@field by_root table<string, gleb.pr.Review>
---@field generations table<string, integer>
---@field blobs table<string, string[]>
---@field blob_order string[]
---@field in_flight table<string, boolean>
---@field pending table<string, gleb.pr.RefreshOptions>
---@field last_write_fetch table<string, integer>
---@field write_timers table<string, uv.uv_timer_t>

---@type gleb.pr.State
M.state = {
	by_root = {},
	generations = {},
	blobs = {},
	blob_order = {},
	in_flight = {},
	pending = {},
	last_write_fetch = {},
	write_timers = {},
}

---@class gleb.pr.Location
---@field thread gleb.pr.Thread
---@field line? integer
---@field reason? "left side"|"file"|"missing commit"|"removed"

---@param pr gleb.git.base.Pr
---@return string? host
---@return string? owner
---@return string? name
local function repository(pr)
	local host, owner, name = pr.url:match("^https?://([^/]+)/([^/]+)/([^/]+)/pull/%d+")
	return pr.host or host, owner, name
end

---@class gleb.pr.RefreshOptions
---@field force? boolean

---@param root string
---@param opts gleb.pr.RefreshOptions
---@return nil
local function queue_refresh(root, opts)
	local pending = M.state.pending[root] or {}
	pending.force = pending.force or opts.force
	M.state.pending[root] = pending
end

---@param root string
---@return nil
local function finish_refresh(root)
	M.state.in_flight[root] = nil
	local pending = M.state.pending[root]
	M.state.pending[root] = nil
	if pending then
		M.refresh(root, pending)
	end
end

---@param root string
---@param opts? gleb.pr.RefreshOptions
---@return nil
function M.refresh(root, opts)
	opts = opts or {}
	root = vim.fs.normalize(root)
	local info = require("gleb.git.base").get(root)
	if not info or not info.pr then
		if opts.force then
			vim.notify("No pull request for " .. (info and info.branch or "current branch"), vim.log.levels.WARN)
		end
		return
	end
	if M.state.in_flight[root] then
		queue_refresh(root, opts)
		return
	end
	local host, owner, name = repository(info.pr)
	if not host or not owner or not name then
		return
	end
	M.state.in_flight[root] = true
	local generation = (M.state.generations[root] or 0) + 1
	M.state.generations[root] = generation
	---@type gleb.pr.Review
	local review = {
		root = root,
		pr = info.pr,
		host = host,
		owner = owner,
		name = name,
		head = info.pr.head_ref_oid,
		threads = {},
		timeout = M.GH_TIMEOUT_MS,
	}
	gh.fetch_threads(review, nil, function(fetched_threads)
		local current = require("gleb.git.base").get(root)
		local current_result = fetched_threads ~= nil
			and M.state.generations[root] == generation
			and current
			and current.pr
			and current.pr.number == review.pr.number
			and current.pr.head_ref_oid == review.head
		if current_result then
			review.threads = threads.parse(fetched_threads)
			review.fetched_at = M.now()
			M.state.by_root[root] = review
			vim.api.nvim_exec_autocmds("User", { pattern = "GlebPrThreads", data = { root = root } })
			if opts.force then
				vim.notify(
					("PR #%d: %d open threads"):format(review.pr.number, threads.open_count(review.threads)),
					vim.log.levels.INFO
				)
			end
		end
		finish_refresh(root)
	end)
end

---@param root string
---@return gleb.pr.Review?
function M.get(root)
	return M.state.by_root[vim.fs.normalize(root)]
end

---@param path string
---@return gleb.pr.Review?
---@return string? relative
local function review_for_path(path)
	for root, review in pairs(M.state.by_root) do
		local relative = vim.fs.relpath(root, path)
		if relative and relative ~= ".." and relative:sub(1, 3) ~= "../" then
			return review, relative
		end
	end
end

---@param value string
---@return string[]
local function blob_lines(value)
	local lines = vim.split(value, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	return lines
end

---@param key string
---@param lines string[]
---@return nil
local function cache_blob(key, lines)
	if M.state.blobs[key] then
		return
	end
	M.state.blobs[key] = lines
	table.insert(M.state.blob_order, key)
	if #M.state.blob_order > BLOB_CACHE_MAX then
		M.state.blobs[table.remove(M.state.blob_order, 1)] = nil
	end
end

---@class gleb.pr.PendingLocation
---@field thread gleb.pr.Thread
---@field oid? string
---@field source_line? integer
---@field key? string
---@field reason? "left side"|"file"
---@field missing_commit? boolean

---@param pending gleb.pr.PendingLocation[]
---@param buffer_lines string[]
---@return gleb.pr.Location[]
local function map_locations(pending, buffer_lines)
	local locations = {}
	for _, item in ipairs(pending) do
		local source = item.key and M.state.blobs[item.key] or nil
		if item.reason then
			table.insert(locations, { thread = item.thread, reason = item.reason })
		elseif item.missing_commit then
			table.insert(locations, { thread = item.thread, reason = "missing commit" })
		elseif source and item.source_line then
			local line = threads.map_line(source, buffer_lines, item.source_line)
			local location = { thread = item.thread, line = line }
			if not line then
				location.reason = "removed"
			end
			table.insert(locations, location)
		end
	end
	return locations
end

---@param root string
---@param item gleb.pr.PendingLocation
---@param callback fun()
---@return nil
local function load_blob(root, item, callback)
	assert(item.oid and item.key, "pending PR location requires an anchor")
	vim.system({ "git", "show", item.oid .. ":" .. item.thread.path }, { cwd = root, text = true }, function(result)
		if result.code == 0 then
			vim.schedule(function()
				cache_blob(item.key, blob_lines(result.stdout or ""))
				callback()
			end)
			return
		end
		vim.system({ "git", "cat-file", "-e", item.oid .. "^{commit}" }, { cwd = root }, function(commit_result)
			vim.schedule(function()
				item.missing_commit = commit_result.code ~= 0
				callback()
			end)
		end)
	end)
end

---@param buf integer
---@param callback? fun(locations: gleb.pr.Location[])
---@return gleb.pr.Location[]
function M.locate(buf, callback)
	buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
	local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
	local review, relative = review_for_path(path)
	if not review or not relative then
		return {}
	end
	local pending = {}
	local missing = {}
	for _, thread in ipairs(review.threads) do
		if thread.path == relative then
			local oid, source_line, reason = threads.anchor(thread, review.head)
			if oid and source_line then
				local key = oid .. ":" .. thread.path
				local item = { thread = thread, oid = oid, source_line = source_line, key = key }
				table.insert(pending, item)
				if not M.state.blobs[key] then
					missing[key] = item
				end
			elseif reason then
				table.insert(pending, { thread = thread, reason = reason })
			end
		end
	end
	local buffer_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local locations = map_locations(pending, buffer_lines)
	local remaining = vim.tbl_count(missing)
	if remaining == 0 then
		return locations
	end
	for _, item in pairs(missing) do
		load_blob(review.root, item, function()
			remaining = remaining - 1
			if remaining == 0 and callback then
				callback(map_locations(pending, buffer_lines))
			end
		end)
	end
	return locations
end

---@return integer
function M.now()
	return vim.uv.now()
end

---@param args table
---@return nil
local function base_changed(args)
	local root = args.data and args.data.root
	if not root then
		return
	end
	root = vim.fs.normalize(root)
	local info = require("gleb.git.base").get(root)
	local review = M.state.by_root[root]
	if info and info.pr and review and review.pr.number == info.pr.number and review.head == info.pr.head_ref_oid then
		return
	end
	M.state.generations[root] = (M.state.generations[root] or 0) + 1
	M.state.by_root[root] = nil
	if info and info.pr then
		M.refresh(root)
	end
end

---@param root string
---@return nil
local function schedule_write_refresh(root)
	M.state.write_timers[root] = debounce.schedule(M.state.write_timers[root], WRITE_DEBOUNCE_MS, function()
		local info = require("gleb.git.base").get(root)
		if not info or not info.pr then
			return
		end
		local now = M.now()
		local last = M.state.last_write_fetch[root]
		if last and now - last < WRITE_MIN_INTERVAL_MS then
			return
		end
		M.state.last_write_fetch[root] = now
		M.refresh(root)
	end)
end

---@param args table
---@return nil
local function written(args)
	if vim.bo[args.buf].buftype ~= "" then
		return
	end
	local path = vim.api.nvim_buf_get_name(args.buf)
	if path == "" then
		return
	end
	require("gleb.git.base").resolve(path, function(info, root)
		if info and info.pr and root then
			schedule_write_refresh(vim.fs.normalize(root))
		end
	end)
end

local group = vim.api.nvim_create_augroup("gleb_pr", { clear = true })
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "GlebGitBaseChanged",
	callback = base_changed,
})
vim.api.nvim_create_autocmd("BufWritePost", {
	group = group,
	callback = written,
})

---@return nil
function M.reset()
	for _, timer in pairs(M.state.write_timers) do
		timer:stop()
		if not timer:is_closing() then
			timer:close()
		end
	end
	M.state.by_root = {}
	M.state.generations = {}
	M.state.blobs = {}
	M.state.blob_order = {}
	M.state.in_flight = {}
	M.state.pending = {}
	M.state.last_write_fetch = {}
	M.state.write_timers = {}
end

return M
