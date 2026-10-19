-- Sidebar coordination lets tree features replace one another without importing each other's internals.

local M = {}

---@class TreeSidebarState
---@field closers table<string, fun()>

---@type TreeSidebarState
M.state = { closers = {} }

--- Register the close action for a tree sidebar.
---@param name string
---@param closer fun()
---@return nil
function M.register(name, closer)
	M.state.closers[name] = closer
end

--- Close a loaded tree sidebar by name.
---@param name string
---@return nil
function M.close(name)
	local closer = M.state.closers[name]
	if closer then
		closer()
	end
end

return M
