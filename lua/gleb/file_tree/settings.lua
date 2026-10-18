-- File-tree settings state keeps test and user configuration paths separate.

local M = {}

---@class FileTreeSettingsOptions
---@field path string

---@class FileTreeSettingsState
---@field path? string
---@field generation integer

---@type FileTreeSettingsState
M.state = { generation = 0 }

--- Select the settings file used by the file tree.
---@param opts FileTreeSettingsOptions
---@return nil
function M.setup(opts)
	M.state.path = opts.path
	M.state.generation = M.state.generation + 1
end

--- Mark cached settings as stale.
---@return nil
function M.reload()
	M.state.generation = M.state.generation + 1
end

--- Return the generation used by derived caches.
---@return integer
function M.generation()
	return M.state.generation
end

return M
