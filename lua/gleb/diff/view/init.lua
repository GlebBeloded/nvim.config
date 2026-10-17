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
---@field on_next_file? function

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
---@field on_next_file? function
---@field owns_tab boolean
---@field origin_win integer
---@field right_restore? { buf: integer, options: table<string, unknown> }
---@field mappings? table<integer, { lhs: string, previous: table }[]>
---@field closing? boolean
---@field timer? uv.uv_timer_t
---@field attached? boolean

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

---@param view gleb.diff.view.View
local function set_mappings(view)
	local actions = require("gleb.actions")
	local adapter = require("gleb.actions.adapters.gleb_diff")
	local catalog = assert(actions.state.applicator, "actions are not set up").catalog
	local shortcuts = assert(actions.state.store, "actions are not set up").last_good
	local mappings = adapter.mappings(catalog, shortcuts)
	view.mappings = {}
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		local saved = {}
		view.mappings[buf] = saved
		vim.api.nvim_buf_call(buf, function()
			for lhs, mapping in pairs(mappings) do
				local previous = vim.fn.maparg(lhs, "n", false, true)
				table.insert(saved, { lhs = lhs, previous = previous })
				vim.keymap.set("n", lhs, mapping.callback, {
					buffer = buf,
					desc = mapping.desc,
					nowait = true,
					silent = true,
				})
			end
		end)
	end
end

---@param view gleb.diff.view.View
local function register(view)
	M.state.by_path[view.path] = view
	M.state.by_win[view.left_win] = view
	M.state.by_win[view.right_win] = view
	set_mappings(view)
	render.draw(view)
end

---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
local function build(spec)
	local comparison = engine.compare_lines(spec.left, spec.right, {
		policy = "default",
		highlight = "by_word",
		limits = { timeout_ms = M.config.timeout_ms },
	})
	if #comparison.fragments == 0 then
		return nil
	end
	local path = vim.fs.normalize(spec.path)
	local model = layout.build(comparison.fragments, #spec.left, #spec.right, M.config.context)
	---@type gleb.diff.view.View
	---@diagnostic disable-next-line: missing-fields -- windows initializes the handles as one lifecycle step.
	return {
		path = path,
		relpath = spec.relpath or vim.fs.basename(path),
		left = spec.left,
		right = spec.right,
		labels = spec.labels,
		filetype = spec.filetype or "",
		right_buf = spec.right_buf or readonly_buffer(spec.right),
		on_next_file = spec.on_next_file,
		ns = vim.api.nvim_create_namespace("gleb_diff_view"),
		fragments = comparison.fragments,
		layout = model,
	}
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

	local view = build(spec)
	if not view then
		return nil
	end
	windows.open(view)
	register(view)
	local first = view.fragments[1]
	local line = math.min(first.start2 + 1, math.max(#spec.right, 1))
	vim.api.nvim_win_set_cursor(view.right_win, { line, 0 })
	return view
end

---@param win integer
---@param spec gleb.diff.view.Spec
---@return gleb.diff.view.View?
function M.show(win, spec)
	local existing = M.state.by_win[win] or M.state.by_path[vim.fs.normalize(spec.path)]
	if existing then
		M.close(existing)
	end
	local view = build(spec)
	if not view then
		return nil
	end
	windows.show(view, win)
	register(view)
	return view
end

---@param view gleb.diff.view.View
function M.close(view)
	if view.closing then
		return
	end
	view.closing = true
	M.state.by_path[view.path] = nil
	M.state.by_win[view.left_win] = nil
	M.state.by_win[view.right_win] = nil
	pcall(vim.api.nvim_del_augroup_by_id, view.augroup)

	for buf, mappings in pairs(view.mappings or {}) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_call(buf, function()
				for _, mapping in ipairs(mappings) do
					pcall(vim.keymap.del, "n", mapping.lhs, { buffer = buf })
					if next(mapping.previous) ~= nil then
						vim.fn.mapset("n", false, mapping.previous)
					end
				end
			end)
		end
	end
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, view.ns, 0, -1)
		end
	end
	pcall(vim.api.nvim__ns_set, view.ns, { wins = {} })
	if view.timer then
		view.timer:stop()
		view.timer:close()
	end
	if view.attached and vim.api.nvim_buf_is_valid(view.right_buf) then
		vim.api.nvim_buf_detach(view.right_buf)
	end

	if view.owns_tab and vim.api.nvim_tabpage_is_valid(view.tab) then
		vim.api.nvim_set_current_tabpage(view.tab)
		pcall(vim.cmd.tabclose)
	else
		if vim.api.nvim_win_is_valid(view.left_win) then
			pcall(vim.api.nvim_win_close, view.left_win, true)
		end
		windows.restore(view)
	end
	if vim.api.nvim_win_is_valid(view.origin_win) then
		vim.api.nvim_set_current_win(view.origin_win)
	end
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
