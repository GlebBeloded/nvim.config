-- Cached directory scans feed the pure tree model and can be invalidated by later watcher work.

local M = {}

---@class FileTreeFsState
---@field cache table<string, FileTreeEntry[]>

---@type FileTreeFsState
M.state = { cache = {} }

--- Clear all cached scans.
---@return nil
function M.reset()
	M.state.cache = {}
end

--- Remove one directory scan from the cache.
---@param path string
---@return nil
function M.invalidate(path)
	M.state.cache[path] = nil
end

--- Scan a directory, returning an empty list when it cannot be read.
---@param path string
---@return FileTreeEntry[]
function M.scan(path)
	local cached = M.state.cache[path]
	if cached then
		return cached
	end

	local entries = {}
	local handle = vim.uv.fs_scandir(path)
	if handle then
		while true do
			local name, kind = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end
			entries[#entries + 1] = {
				name = name,
				path = vim.fs.joinpath(path, name),
				kind = kind == "directory" and "directory" or "file",
			}
		end
	end
	M.state.cache[path] = entries
	return entries
end

--- Build the filesystem-backed source consumed by the pure row model.
---@param root string
---@return FileTreeSource
function M.tree(root)
	return { root = root, scan = M.scan }
end

return M
