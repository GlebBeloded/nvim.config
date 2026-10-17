-- Cached directory scans feed the pure tree model and can be invalidated by later watcher work.

local M = {}

---@class FileTreeFsState
---@field cache table<string, FileTreeEntry[]>

---@type FileTreeFsState
M.state = { cache = {} }

--- Resolve a path through its nearest existing parent.
---@param path string
---@return string
function M.normalize(path)
	local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
	local resolved = vim.uv.fs_realpath(absolute)
	if resolved then
		return vim.fs.normalize(resolved)
	end

	local missing = {}
	local parent = absolute
	while parent do
		local next_parent = vim.fs.dirname(parent)
		if not next_parent or next_parent == parent then
			break
		end
		table.insert(missing, 1, vim.fs.basename(parent))
		parent = next_parent
		resolved = vim.uv.fs_realpath(parent)
		if resolved then
			return vim.fs.normalize(vim.fs.joinpath(resolved, unpack(missing)))
		end
	end
	return absolute
end

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
			local entry_path = vim.fs.joinpath(path, name)
			local target = kind == "link" and vim.uv.fs_stat(entry_path) or nil
			entries[#entries + 1] = {
				name = name,
				path = entry_path,
				kind = (kind == "directory" or (target and target.type == "directory")) and "directory" or "file",
			}
		end
	end
	M.state.cache[path] = entries
	return entries
end

--- Build the filesystem-backed source consumed by the pure row model.
---@param root string
---@param on_scan? fun(path: string)
---@return FileTreeSource
function M.tree(root, on_scan)
	local realpaths = { [vim.uv.fs_realpath(root) or root] = root }
	return {
		root = root,
		scan = function(path)
			if on_scan then
				on_scan(path)
			end
			local realpath = vim.uv.fs_realpath(path)
			local first_path = realpath and realpaths[realpath] or nil
			if first_path and first_path ~= path then
				return {}
			end
			if realpath then
				realpaths[realpath] = path
			end
			return M.scan(path)
		end,
	}
end

return M
