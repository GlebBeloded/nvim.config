-- Shared picker actions keep source-specific setup behind the common frame.

local M = {}

local frame = require("gleb.picker.frame")

---@return any
function M.files()
	local ok, mini_pick = pcall(require, "mini.pick")
	if not ok then
		return
	end

	return mini_pick.builtin.files({}, frame.options("Files"))
end

---@return any
function M.recent_files()
	local ok, mini_extra = pcall(require, "mini.extra")
	if not ok then
		return
	end

	return mini_extra.pickers.oldfiles({}, frame.options("Recent Files"))
end

---@return any
function M.grep_live()
	local ok, mini_pick = pcall(require, "mini.pick")
	if not ok then
		return
	end

	return mini_pick.builtin.grep_live({}, frame.options("Live Grep"))
end

return M
