-- Pull-request review cache: coordinates base metadata, GitHub fetches, and update publication per root.
local gh = require("gleb.pr.gh")

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

---@type gleb.pr.State
M.state = { by_root = {} }

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
	gh.fetch_threads(review, nil, function(threads)
		if not threads then
			return
		end
		review.threads = threads
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

---@return integer
function M.now()
	return vim.uv.now()
end

---@return nil
function M.reset()
	M.state.by_root = {}
end

return M
