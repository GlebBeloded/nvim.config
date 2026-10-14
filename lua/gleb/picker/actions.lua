-- Shared picker actions keep source-specific setup behind the common frame.

local M = {}

local frame = require("gleb.picker.frame")

---@return any
function M.grep_live()
	local ok, mini_pick = pcall(require, "mini.pick")
	if not ok then
		return
	end

	return mini_pick.builtin.grep_live({}, frame.options("Live Grep"))
end

---@return nil
function M.lsp_references()
	local ok, mini_extra = pcall(require, "mini.extra")
	if not ok then
		return
	end

	return mini_extra.pickers.lsp({ scope = "references" }, frame.options("References"))
end

return M
