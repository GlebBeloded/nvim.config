-- Decoration providers let other features add virtual lines under a diff view's right lines; the renderer pairs
-- each with as many blank rows on the left so both sides stay aligned.

local M = {}

---@alias gleb.diff.view.VirtLine [string, string][]

---@class gleb.diff.view.Decorations
---@field right table<integer, gleb.diff.view.VirtLine[]> virtual lines under a 1-based right line

---@alias gleb.diff.view.Provider fun(view: gleb.diff.view.View): gleb.diff.view.Decorations?

---@type gleb.diff.view.Provider[]
M.list = {}

--- Register a provider, called on every render of every diff view.
---@param provider gleb.diff.view.Provider
---@return nil
function M.add(provider)
	table.insert(M.list, provider)
end

--- The providers' virtual lines of `view` by right line, in registration order.
---@param view gleb.diff.view.View
---@return table<integer, gleb.diff.view.VirtLine[]>
function M.collect(view)
	local by_line = {}
	for _, provider in ipairs(M.list) do
		local decorations = provider(view)
		for line, virt_lines in pairs(decorations and decorations.right or {}) do
			by_line[line] = vim.list_extend(by_line[line] or {}, virt_lines)
		end
	end
	return by_line
end

return M
