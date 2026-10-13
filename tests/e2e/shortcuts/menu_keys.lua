local M = {}

---@class MenuKeyLifecycleDeps
---@field preflight fun(): string?, boolean?
---@field skip fun(reason: string)
---@field stop fun()
---@field start fun(): table
---@field run fun(argv: string[]): { code: integer, stdout: string, stderr: string }
---@field root string
---@field set_stack fun(stack: table)

---@param deps MenuKeyLifecycleDeps
---@return boolean
local function ready(deps)
	local reason, fatal = deps.preflight()
	if fatal then
		error("e2e: " .. reason, 0)
	end
	if reason then
		deps.skip(reason)
		return false
	end
	return true
end

--- Run a regression without app-menu overrides, then restore a provisioned stack.
---@param deps MenuKeyLifecycleDeps
---@param fn fun(stack: table)
function M.with_absent(deps, fn)
	if not ready(deps) then
		return
	end
	deps.stop()
	local fresh
	local action_ok, action_err = xpcall(function()
		local removed = deps.run({ "defaults", "delete", "org.alacritty", "NSUserKeyEquivalents" })
		assert(removed.code == 0, removed.stderr)
		fresh = deps.start()
		fn(fresh)
	end, debug.traceback)
	local stop_ok, stop_err = true, nil
	if fresh then
		stop_ok, stop_err = xpcall(function()
			fresh:stop()
		end, debug.traceback)
	end

	local cleanup_ok, cleanup_err = xpcall(function()
		local script = vim.fs.joinpath(deps.root, "terminal", "macos_menu_keys.sh")
		local restored = deps.run({ script })
		assert(restored.code == 0, restored.stderr)
		local reason, fatal = deps.preflight()
		assert(not fatal and not reason, reason)
		deps.set_stack(deps.start())
	end, debug.traceback)
	if not cleanup_ok then
		error("failed to restore menu keys after controlled regression: " .. tostring(cleanup_err), 0)
	end
	if not stop_ok then
		error(stop_err, 0)
	end
	if not action_ok then
		error(action_err, 0)
	end
end

return M
