-- Public API and state for the owned two-side diff view.
-- Source comparison happens before opening windows so empty/error branches leave the editor untouched.

local engine = require("gleb.diff.engine")
local layout = require("gleb.diff.view.layout")
local render = require("gleb.diff.view.render")
local windows = require("gleb.diff.view.windows")

local M = {
	config = {
		context = 4,
		debounce_ms = 150,
		timeout_ms = 1000,
	},
	state = {
		by_path = {},
		by_win = {},
	},
}

---@class gleb.diff.view.Spec
---@field path string
---@field left string[]
---@field right string[]
---@field labels { left: string, right: string }
---@field right_buf? integer
---@field relpath? string
---@field filetype? string

---@class gleb.diff.view.View
---@field path string
---@field relpath string
---@field left string[]
---@field right string[]
---@field labels { left: string, right: string }
---@field filetype string
---@field right_buf integer
---@field left_buf integer
---@field left_win integer
---@field right_win integer
---@field tab integer
---@field augroup integer
---@field ns integer
---@field fragments gleb.diff.LineFragment[]
---@field layout gleb.diff.view.Layout

---@param lines string[]
---@return integer
local function readonly_buffer(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	return buf
end

---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
function M.open(spec)
	local path = vim.fs.normalize(spec.path)
	local existing = M.state.by_path[path]
	if existing and vim.api.nvim_tabpage_is_valid(existing.tab) then
		vim.api.nvim_set_current_tabpage(existing.tab)
		vim.api.nvim_set_current_win(existing.right_win)
		return existing
	end

	local comparison = engine.compare_lines(spec.left, spec.right, {
		policy = "default",
		highlight = "by_word",
		limits = { timeout_ms = M.config.timeout_ms },
	})
	if #comparison.fragments == 0 then
		return nil
	end
	local model = layout.build(comparison.fragments, #spec.left, #spec.right, M.config.context)
	---@type gleb.diff.view.View
	---@diagnostic disable-next-line: missing-fields -- windows.open initializes the handles as one lifecycle step.
	local view = {
		path = path,
		relpath = spec.relpath or vim.fs.basename(path),
		left = spec.left,
		right = spec.right,
		labels = spec.labels,
		filetype = spec.filetype or "",
		right_buf = spec.right_buf or readonly_buffer(spec.right),
		ns = vim.api.nvim_create_namespace("gleb_diff_view"),
		fragments = comparison.fragments,
		layout = model,
	}
	windows.open(view)
	M.state.by_path[path] = view
	M.state.by_win[view.left_win] = view
	M.state.by_win[view.right_win] = view
	render.draw(view)
	local first = comparison.fragments[1]
	local line = math.min(first.start2 + 1, math.max(#spec.right, 1))
	vim.api.nvim_win_set_cursor(view.right_win, { line, 0 })
	return view
end

---@return gleb.diff.view.View?
function M.current()
	return M.state.by_win[vim.api.nvim_get_current_win()]
end

function M.reset()
	for _, view in pairs(M.state.by_path) do
		if vim.api.nvim_buf_is_valid(view.left_buf) then
			vim.api.nvim_buf_clear_namespace(view.left_buf, view.ns, 0, -1)
		end
		if vim.api.nvim_buf_is_valid(view.right_buf) then
			vim.api.nvim_buf_clear_namespace(view.right_buf, view.ns, 0, -1)
		end
	end
	M.state = { by_path = {}, by_win = {} }
end

return M
