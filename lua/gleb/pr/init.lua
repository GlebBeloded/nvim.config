-- Pull-request review cache: coordinates base metadata, GitHub fetches, and update publication per root.
local gh = require("gleb.pr.gh")
local threads = require("gleb.pr.threads")

local BLOB_CACHE_MAX = 200

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
---@field blobs table<string, string[]>
---@field blob_order string[]

---@type gleb.pr.State
M.state = { by_root = {}, blobs = {}, blob_order = {} }

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

---@param root string
---@return nil
function M.refresh(root)
	root = vim.fs.normalize(root)
	local info = require("gleb.git.base").get(root)
	if not info or not info.pr then
		return
	end
	local host, owner, name = repository(info.pr)
	if not host or not owner or not name then
		return
	end
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
		if not fetched_threads then
			return
		end
		review.threads = fetched_threads
		review.fetched_at = M.now()
		M.state.by_root[root] = review
		vim.api.nvim_exec_autocmds("User", { pattern = "GlebPrThreads", data = { root = root } })
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
---@field oid string
---@field source_line integer
---@field key string

---@param pending gleb.pr.PendingLocation[]
---@param buffer_lines string[]
---@return gleb.pr.Location[]
local function map_locations(pending, buffer_lines)
	local locations = {}
	for _, item in ipairs(pending) do
		local source = M.state.blobs[item.key]
		if source then
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
	vim.system({ "git", "show", item.oid .. ":" .. item.thread.path }, { cwd = root, text = true }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				cache_blob(item.key, blob_lines(result.stdout or ""))
			end
			callback()
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
			local oid, source_line = threads.anchor(thread, review.head)
			if oid and source_line then
				local key = oid .. ":" .. thread.path
				local item = { thread = thread, oid = oid, source_line = source_line, key = key }
				table.insert(pending, item)
				if not M.state.blobs[key] then
					missing[key] = item
				end
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

---@return nil
function M.reset()
	M.state.by_root = {}
	M.state.blobs = {}
	M.state.blob_order = {}
end

return M
