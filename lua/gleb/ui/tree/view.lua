-- Tree views preserve selection by stable node id while feature renderers retain control of row presentation.

local M = {}

local model = require("gleb.ui.tree.model")

---@alias gleb.ui.tree.Render fun(buf: integer, rows: gleb.ui.tree.Row[])
---@alias gleb.ui.tree.Fallback fun(buf: integer, rows: gleb.ui.tree.Row[])

---@class gleb.ui.tree.ViewOptions
---@field expand? gleb.ui.tree.Expand
---@field fallback? gleb.ui.tree.Fallback

---@class gleb.ui.tree.View
---@field buf integer
---@field tree gleb.ui.tree.Model
---@field rows gleb.ui.tree.Row[]
---@field render? gleb.ui.tree.Render
---@field options gleb.ui.tree.ViewOptions

---@class gleb.ui.tree.ViewState
---@field by_buf table<integer, gleb.ui.tree.View>
---@field by_tree table<gleb.ui.tree.Model, gleb.ui.tree.View>
M.state = { by_buf = {}, by_tree = setmetatable({}, { __mode = "k" }) }

local augroup = vim.api.nvim_create_augroup("gleb_ui_tree", { clear = false })

---@param buf integer
---@return integer
local function resolve_buf(buf)
	return buf == 0 and vim.api.nvim_get_current_buf() or buf
end

---@param view gleb.ui.tree.View
---@return integer?
local function window_for(view)
	local win = vim.fn.bufwinid(view.buf)
	return win ~= -1 and win or nil
end

---@param view gleb.ui.tree.View
---@return string?
local function cursor_id(view)
	local win = window_for(view)
	if not win then
		return nil
	end
	local row = view.rows[vim.api.nvim_win_get_cursor(win)[1]]
	return row and row.id or nil
end

---@param tree gleb.ui.tree.Model
---@param visible table<string, integer>
---@param selected_id string
---@return integer?
local function selected_row(tree, visible, selected_id)
	local id = selected_id
	while id do
		if visible[id] then
			return visible[id]
		end
		id = tree.parents[id]
	end
end

---@param buf integer
---@param tree gleb.ui.tree.Model
---@param options? gleb.ui.tree.ViewOptions
---@return gleb.ui.tree.Model tree
function M.attach(buf, tree, options)
	buf = resolve_buf(buf)
	local previous = M.state.by_buf[buf]
	if previous then
		M.state.by_tree[previous.tree] = nil
	end

	local view = { buf = buf, tree = tree, rows = {}, options = options or {} }
	M.state.by_buf[buf] = view
	M.state.by_tree[tree] = view
	if not previous then
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = augroup,
			buffer = buf,
			once = true,
			callback = function()
				local attached = M.state.by_buf[buf]
				if attached then
					M.state.by_tree[attached.tree] = nil
					M.state.by_buf[buf] = nil
				end
			end,
		})
	end
	return tree
end

---@param buf integer
---@return gleb.ui.tree.Model?
function M.get(buf)
	local view = M.state.by_buf[resolve_buf(buf)]
	return view and view.tree or nil
end

---@param tree gleb.ui.tree.Model
---@return string?
function M.selected_id(tree)
	local view = M.state.by_tree[tree]
	return view and cursor_id(view) or nil
end

---@param tree gleb.ui.tree.Model
---@return gleb.ui.tree.ViewOptions?
function M.options(tree)
	local view = M.state.by_tree[tree]
	return view and view.options or nil
end

---@param tree gleb.ui.tree.Model
---@param render_rows gleb.ui.tree.Render
---@param selected_id? string
---@return gleb.ui.tree.Row[] rows
function M.draw(tree, render_rows, selected_id)
	local view = assert(M.state.by_tree[tree], "tree is not attached")
	selected_id = selected_id or cursor_id(view)
	local rows = model.rows(tree)
	local visible = {}
	for index, row in ipairs(rows) do
		visible[row.id] = index
	end

	render_rows(view.buf, rows)
	view.rows = rows
	view.render = render_rows

	local win = window_for(view)
	local row = selected_id and selected_row(tree, visible, selected_id) or nil
	if win and row then
		vim.api.nvim_win_set_cursor(win, { row, 0 })
	elseif selected_id and view.options.fallback then
		view.options.fallback(view.buf, rows)
	end
	return rows
end

---@param tree gleb.ui.tree.Model
---@param selected_id? string
---@return gleb.ui.tree.Row[] rows
function M.redraw(tree, selected_id)
	local view = assert(M.state.by_tree[tree], "tree is not attached")
	return M.draw(tree, assert(view.render, "tree has not been drawn"), selected_id)
end

return M
