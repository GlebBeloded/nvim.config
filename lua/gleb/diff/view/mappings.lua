-- Buffer-local mappings for the owned diff view.
-- Existing mappings are replayed outside the view and restored when it closes.

local M = {}

---@param lhs string
---@param previous table
local function replay(lhs, previous)
	if next(previous) == nil then
		local count = vim.v.count > 0 and tostring(vim.v.count) or ""
		vim.api.nvim_feedkeys(vim.keycode(count .. lhs), "n", false)
		return
	end
	if previous.callback then
		local result = previous.callback()
		if previous.expr == 1 and type(result) == "string" then
			vim.api.nvim_feedkeys(vim.keycode(result), previous.noremap == 1 and "n" or "m", false)
		end
		return
	end
	local count = vim.v.count > 0 and tostring(vim.v.count) or ""
	vim.api.nvim_feedkeys(vim.keycode(count .. previous.rhs), previous.noremap == 1 and "n" or "m", false)
end

--- Install diff actions in both view buffers.
---@param view gleb.diff.view.View
---@param by_win table<integer, gleb.diff.view.View>
---@return nil
function M.install(view, by_win)
	local actions = require("gleb.actions")
	local adapter = require("gleb.actions.adapters.gleb_diff")
	local catalog = assert(actions.state.applicator, "actions are not set up").catalog
	local shortcuts = assert(actions.state.store, "actions are not set up").last_good
	local action_mappings = adapter.mappings(catalog, shortcuts)
	view.mappings = {}
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		local saved = {}
		view.mappings[buf] = saved
		vim.api.nvim_buf_call(buf, function()
			for lhs, mapping in pairs(action_mappings) do
				local previous = vim.fn.maparg(lhs, "n", false, true)
				local is_leader = vim.keycode(lhs) == vim.g.mapleader
				table.insert(saved, { lhs = lhs, previous = previous })
				vim.keymap.set("n", lhs, function()
					if by_win[vim.api.nvim_get_current_win()] == view then
						mapping.callback()
					else
						replay(lhs, previous)
					end
				end, {
					buffer = buf,
					desc = mapping.desc,
					nowait = not is_leader,
					silent = true,
				})
			end
		end)
	end
end

--- Restore mappings displaced by the diff view.
---@param view gleb.diff.view.View
---@return nil
function M.restore(view)
	for buf, buffer_mappings in pairs(view.mappings or {}) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_call(buf, function()
				for _, mapping in ipairs(buffer_mappings) do
					pcall(vim.keymap.del, "n", mapping.lhs, { buffer = buf })
					if next(mapping.previous) ~= nil then
						vim.fn.mapset("n", false, mapping.previous)
					end
				end
			end)
		end
	end
end

return M
