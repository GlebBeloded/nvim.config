-- File-tree settings state keeps test and user configuration paths separate.

local M = {}

---@class FileTreeSettingsOptions
---@field path string

---@class FileTreeSettingsState
---@field path? string

---@type FileTreeSettingsState
M.state = {}

--- Select the settings file used by the file tree.
---@param opts FileTreeSettingsOptions
---@return nil
function M.setup(opts)
	M.state.path = opts.path
end

return M
