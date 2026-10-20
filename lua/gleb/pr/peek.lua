-- Review peeks render cached threads as window-scoped virtual lines; width and expansion follow the visible editor.

local M = {}

local THREAD_ICON = "󰆈"
local RESOLVED_ICON = ""

M.namespace = vim.api.nvim_create_namespace("gleb_pr_peek")
---@class gleb.pr.PeekState
---@field generations table<integer, integer> redraw generation per buffer
---@field diff_loads table<gleb.diff.view.View, true> views that asked for missing source blobs since the threads changed
---@field diff_lines table<gleb.diff.view.View, table<integer, true>> right lines with a peek
---@field diff_expanded table<gleb.diff.view.View, integer|false> right line whose peek is expanded

---@type gleb.pr.PeekState
M.state = {
	generations = {},
	diff_loads = setmetatable({}, { __mode = "k" }),
	diff_lines = setmetatable({}, { __mode = "k" }),
	diff_expanded = setmetatable({}, { __mode = "k" }),
}

---@param text string
---@param width integer
---@return string
function M.truncate(text, width)
	if width < 1 then
		return ""
	end
	text = vim.trim(vim.split(text, "\n", { plain = true })[1] or "")
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	local kept = ""
	for index = 0, vim.fn.strchars(text) - 1 do
		local character = vim.fn.strcharpart(text, index, 1)
		if vim.fn.strdisplaywidth(kept .. character) > width - 1 then
			break
		end
		kept = kept .. character
	end
	local next_character = vim.fn.strcharpart(text, vim.fn.strchars(kept), 1)
	if next_character ~= " " and not kept:find(" ", 1, true) == false then
		local boundary = kept:match("^.*() ")
		if boundary then
			kept = kept:sub(1, boundary - 1)
		end
	end
	return vim.trim(kept) .. "…"
end

--- An editor window: not the Changes panel nor a side of a diff view, which draws its own peeks.
---@param win integer
---@return boolean
local function is_editor_window(win)
	local diff = package.loaded["gleb.diff.view"]
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	return filetype ~= "gleb-changes" and filetype ~= "gleb-diff" and not (diff and diff.state.by_win[win])
end

---@param buf integer
---@return integer?
local function editor_window(buf)
	return vim.iter(vim.fn.win_findbuf(buf)):find(is_editor_window)
end

--- Limit the peeks' namespace to editor windows, so a diff window showing the same buffer draws only its own.
---@return nil
local function scope_to_editors()
	pcall(vim.api.nvim__ns_set, M.namespace, { wins = vim.tbl_filter(is_editor_window, vim.api.nvim_list_wins()) })
end

---@param win integer
---@return integer
local function text_width(win)
	local info = vim.fn.getwininfo(win)[1]
	return vim.api.nvim_win_get_width(win) - (info and info.textoff or 0)
end

---@param buf integer
---@param line integer
---@return string
local function indent(buf, line)
	local value = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
	return value:match("^%s*") or ""
end

---@param text string
---@param width integer
---@return string[]
local function wrap(text, width)
	local lines = {}
	for _, source in ipairs(vim.split(text, "\n", { plain = true })) do
		local rest = vim.trim(source)
		while vim.fn.strdisplaywidth(rest) > width do
			local part = M.truncate(rest, width + 1):sub(1, -4)
			if part == "" then
				part = vim.fn.strcharpart(rest, 0, 1)
			end
			lines[#lines + 1] = part
			rest = vim.trim(rest:sub(#part + 1))
		end
		lines[#lines + 1] = rest
	end
	return lines
end

---@return integer
local function wall_time()
	local now = require("gleb.pr").now()
	return now > 1000000000 and now or os.time()
end

---@param value string
---@return string
local function age(value)
	local created = vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", value)
	return require("gleb.git.changes.branch").age(math.max(0, wall_time() - created))
end

---@param thread gleb.pr.Thread
---@param available integer
---@return table[]
local function collapsed(thread, available)
	local comment = thread.comments[1]
	local author = comment and comment.author or "ghost"
	if thread.resolved then
		local prefix = "╰─ " .. RESOLVED_ICON .. " Resolved · " .. author .. ":"
		local text = M.truncate(comment and comment.body or "", available - vim.fn.strdisplaywidth(prefix) - 1)
		return { { prefix .. (text ~= "" and " " .. text or ""), "PrThreadResolved" } }
	end
	local replies = #thread.comments - 1
	local suffix = replies > 0 and (" +%d %s"):format(replies, replies == 1 and "reply" or "replies") or ""
	local prefix = "╰─ "
	local fixed = vim.fn.strdisplaywidth(prefix .. THREAD_ICON .. " " .. author .. " " .. suffix)
	local text = M.truncate(comment and comment.body or "", available - fixed)
	local segments = {
		{ prefix, "PrPeekMeta" },
		{ THREAD_ICON .. " ", "PrPeekIcon" },
		{ author, "PrPeekAuthor" },
	}
	if text ~= "" then
		segments[#segments + 1] = { " " .. text, "PrPeek" }
	end
	if suffix ~= "" then
		segments[#segments + 1] = { suffix, "PrPeekMeta" }
	end
	return segments
end

--- Blank cells that pad a box row to its inner width: plain Normal, so only text and borders carry colour.
---@param inner integer
---@param content string
---@return string
local function box_padding(inner, content)
	return string.rep(" ", math.max(0, inner - vim.fn.strdisplaywidth(content)))
end

---@param thread gleb.pr.Thread
---@param review gleb.pr.Review
---@param available integer
---@return table[]
local function expanded(thread, review, available)
	local inner = math.max(1, available - 4)
	local title = (" %s PR #%d · %d comments "):format(THREAD_ICON, review.pr.number, #thread.comments)
	local top_fill = math.max(0, available - vim.fn.strdisplaywidth("╭─" .. title .. "╮"))
	local lines = {
		{ { "╭─", "PrPeekMeta" }, { title, "PrPeekIcon" }, { string.rep("─", top_fill) .. "╮", "PrPeekMeta" } },
	}
	for _, comment in ipairs(thread.comments) do
		local meta = " · " .. age(comment.created_at)
		lines[#lines + 1] = {
			{ "│ ", "PrPeekMeta" },
			{ comment.author, "PrPeekAuthor" },
			{ meta, "PrPeekMeta" },
			{ box_padding(inner, comment.author .. meta), "Normal" },
			{ " │", "PrPeekMeta" },
		}
		for _, body in ipairs(wrap(comment.body, inner)) do
			lines[#lines + 1] = {
				{ "│ ", "PrPeekMeta" },
				{ body, "PrPeek" },
				{ box_padding(inner, body), "Normal" },
				{ " │", "PrPeekMeta" },
			}
		end
	end
	lines[#lines + 1] = { { "╰" .. string.rep("─", math.max(0, available - 2)) .. "╯", "PrPeekMeta" } }
	return lines
end

---@param thread gleb.pr.Thread
---@return boolean
local function selected_in_comments(thread)
	local changes = package.loaded["gleb.git.changes"]
	if not changes then
		return false
	end
	local panel = changes.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not panel or panel.active_tab ~= "comments" or vim.api.nvim_get_current_win() ~= panel.win then
		return false
	end
	local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
	return row and row.thread and row.thread.id == thread.id
end

--- The virtual lines of one peek, starting at the commented line's indent.
---@param thread gleb.pr.Thread
---@param review gleb.pr.Review
---@param padding string
---@param width integer the window's text width
---@param expand boolean
---@return table[]
local function peek_lines(thread, review, padding, width, expand)
	local available = width - vim.fn.strdisplaywidth(padding)
	local lines = not thread.resolved and expand and expanded(thread, review, available)
		or { collapsed(thread, available) }
	for _, line in ipairs(lines) do
		table.insert(line, 1, { padding, "Normal" })
	end
	return lines
end

---@param buf integer
---@param review gleb.pr.Review
---@param locations gleb.pr.Location[]
---@return nil
local function draw(buf, review, locations)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
	scope_to_editors()
	local win = editor_window(buf)
	if not win then
		return
	end
	for _, location in ipairs(locations) do
		local thread = location.thread
		if location.line and not thread.outdated then
			local is_cursor = vim.api.nvim_get_current_win() == win
				and vim.api.nvim_win_get_cursor(win)[1] == location.line
			local lines = peek_lines(
				thread,
				review,
				indent(buf, location.line),
				text_width(win),
				is_cursor or selected_in_comments(thread)
			)
			vim.api.nvim_buf_set_extmark(buf, M.namespace, location.line - 1, 0, { virt_lines = lines })
		end
	end
end

--- The line whose peek a diff view expands: the right window's cursor line while it is current and has a thread.
---@param view gleb.diff.view.View
---@return integer|false
local function diff_expanded_line(view)
	local lines = M.state.diff_lines[view] or {}
	local win = view.right_win
	local cursor = vim.api.nvim_get_current_win() == win and vim.api.nvim_win_get_cursor(win)[1]
	return cursor and lines[cursor] and cursor or false
end

--- The peeks of a diff view whose right side is a file of a root with a review, mapped from the PR head onto the
--- right side's lines (the buffer for the Local tab, the `HEAD:<path>` text for the Branch tab).
---@param view gleb.diff.view.View
---@return gleb.diff.view.Decorations?
local function diff_peeks(view)
	scope_to_editors()
	local review = view.root and require("gleb.pr").get(view.root)
	if not review or not vim.api.nvim_win_is_valid(view.right_win) then
		return nil
	end
	local function reload()
		require("gleb.diff.view").redecorate(view)
	end
	local first_load = not M.state.diff_loads[view]
	M.state.diff_loads[view] = true
	local locations = require("gleb.pr").locate_lines(view.path, view.right, first_load and reload or nil)
	local lines = {}
	for _, location in ipairs(locations) do
		if location.line and not location.thread.outdated then
			lines[location.line] = true
		end
	end
	M.state.diff_lines[view] = lines
	local expanded_line = diff_expanded_line(view)
	M.state.diff_expanded[view] = expanded_line
	local right = {}
	for _, location in ipairs(locations) do
		local line = location.line
		if line and not location.thread.outdated then
			local padding = (view.right[line] or ""):match("^%s*") or ""
			local width = text_width(view.right_win)
			right[line] = vim.list_extend(
				right[line] or {},
				peek_lines(location.thread, review, padding, width, expanded_line == line)
			)
		end
	end
	return { right = right }
end

--- Draw the diff views again whose expanded peek changed, or all of them when the threads did.
---@param all boolean
---@return nil
local function redecorate_diffs(all)
	local diff = package.loaded["gleb.diff.view"]
	if not diff then
		return
	end
	if all then
		M.state.diff_loads = setmetatable({}, { __mode = "k" })
	end
	for _, view in pairs(diff.state.by_path) do
		if all or diff_expanded_line(view) ~= M.state.diff_expanded[view] then
			diff.redecorate(view)
		end
	end
end

---@param buf? integer
---@return nil
function M.redraw(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	M.state.generations[buf] = (M.state.generations[buf] or 0) + 1
	local generation = M.state.generations[buf]
	local function finish(locations)
		if M.state.generations[buf] ~= generation then
			return
		end
		local path = vim.api.nvim_buf_get_name(buf)
		local review
		for root, candidate in pairs(require("gleb.pr").state.by_root) do
			if vim.fs.relpath(root, path) then
				review = candidate
				break
			end
		end
		if review then
			draw(buf, review, locations)
		end
	end
	local locations = require("gleb.pr").locate(buf, finish)
	finish(locations)
end

local function redraw_visible()
	local seen = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if not seen[buf] then
			seen[buf] = true
			M.redraw(buf)
		end
	end
end

local function follow_cursor()
	redraw_visible()
	redecorate_diffs(false)
end

local function threads_changed()
	redraw_visible()
	redecorate_diffs(true)
end

require("gleb.diff.view").add_provider(diff_peeks)

local group = vim.api.nvim_create_augroup("gleb_pr_peek", { clear = true })
vim.api.nvim_create_autocmd({ "CursorMoved", "WinEnter" }, { group = group, callback = follow_cursor })
vim.api.nvim_create_autocmd(
	{ "BufWinEnter", "BufWritePost", "WinClosed" },
	{ group = group, callback = redraw_visible }
)
vim.api.nvim_create_autocmd("User", { group = group, pattern = "GlebPrThreads", callback = threads_changed })

return M
