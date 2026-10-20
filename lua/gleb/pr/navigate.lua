-- Review-thread navigation walks the open, mapped threads of the current window's buffer; an editor window then
-- continues in the next file of the Comments tab. Resolved and outdated threads are skipped: navigation is for the
-- work still open.

local M = {}

---@param thread gleb.pr.Thread
---@return boolean
local function is_open(thread)
	return not thread.resolved and not thread.outdated
end

---@param locations gleb.pr.Location[]
---@return integer[] lines sorted and without duplicates
local function open_lines(locations)
	local seen, lines = {}, {}
	for _, location in ipairs(locations) do
		local line = location.line
		if line and is_open(location.thread) and not seen[line] then
			seen[line] = true
			lines[#lines + 1] = line
		end
	end
	table.sort(lines)
	return lines
end

---@param lines integer[] sorted
---@param cursor integer
---@param direction 1|-1
---@return integer?
local function pick(lines, cursor, direction)
	local first, last, step = 1, #lines, 1
	if direction < 0 then
		first, last, step = #lines, 1, -1
	end
	for index = first, last, step do
		if (lines[index] - cursor) * direction > 0 then
			return lines[index]
		end
	end
end

---@param win integer
---@param line integer
---@return nil
local function jump_to(win, line)
	local buf = vim.api.nvim_win_get_buf(win)
	local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
	vim.api.nvim_win_set_cursor(win, { line, math.max(0, (text:find("%S") or 1) - 1) })
end

---@param win integer
---@return boolean
local function is_editor(win)
	local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
	return filetype ~= "gleb-changes" and filetype ~= "gleb-diff" and not vim.wo[win].diff
end

---@param path string
---@return gleb.pr.Review?
---@return string? relative
local function review_for(path)
	for root, review in pairs(require("gleb.pr").state.by_root) do
		local relative = vim.fs.relpath(root, path)
		if relative then
			return review, relative
		end
	end
end

--- The next file after (or before) `path` in Comments tab order that has an open thread on the head.
---@param review gleb.pr.Review
---@param path string relative to the review's root
---@param direction 1|-1
---@return string?
local function following_file(review, path, direction)
	local open = {}
	for _, thread in ipairs(review.threads) do
		if is_open(thread) and thread.line and thread.side == "RIGHT" and thread.subject == "line" then
			open[thread.path] = true
		end
	end
	local paths = vim.tbl_keys(open)
	if not open[path] then
		paths[#paths + 1] = path
	end
	require("gleb.pr.comments_tab").sort_paths(paths)
	local index = vim.fn.index(paths, path) + 1
	return paths[index + direction]
end

--- Edit the next file with open threads in `win` and put its cursor on the first (or, going back, last) one.
---@param win integer
---@param direction 1|-1
---@return boolean moved
local function jump_to_file(win, direction)
	local review, relative = review_for(vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))))
	local file = review and relative and following_file(review, relative, direction)
	if not review or not file then
		return false
	end
	vim.api.nvim_win_call(win, function()
		vim.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(review.root, file)))
	end)
	local target = vim.api.nvim_win_get_buf(win)
	local function land(locations)
		local lines = open_lines(locations)
		local line = direction > 0 and lines[1] or lines[#lines]
		if line and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target then
			jump_to(win, line)
		end
	end
	land(require("gleb.pr").locate(target, land))
	return true
end

--- Move `win`'s cursor to the next (`direction` 1) or previous (-1) open review thread.
---@param win integer
---@param direction 1|-1
---@return nil
function M.jump(win, direction)
	local buf = vim.api.nvim_win_get_buf(win)
	local line = pick(open_lines(require("gleb.pr").locate(buf)), vim.api.nvim_win_get_cursor(win)[1], direction)
	if line then
		jump_to(win, line)
		return
	end
	if is_editor(win) and jump_to_file(win, direction) then
		return
	end
	vim.notify(direction > 0 and "No next thread" or "No previous thread", vim.log.levels.INFO)
end

return M
