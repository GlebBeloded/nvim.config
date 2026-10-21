-- Comments-tab modeling keeps review data in the shared tree while the Changes panel owns rendering and selection.

local M = {}

local threads = require("gleb.pr.threads")

---@param thread gleb.pr.Thread
---@return integer
local function thread_line(thread)
	return thread.line or thread.original_line or 0
end

---@param thread gleb.pr.Thread
---@return string
local function first_line(thread)
	local comment = thread.comments[1]
	return comment and vim.split(comment.body, "\n", { plain = true })[1] or ""
end

---@param thread gleb.pr.Thread
---@return ChangesRow
local function thread_row(thread)
	return {
		id = "comments:thread:" .. thread.id,
		kind = "thread",
		root = "comments",
		label = first_line(thread),
		depth = 2,
		path = thread.path,
		line = thread_line(thread),
		thread = thread,
	}
end

---@param left gleb.pr.Thread
---@param right gleb.pr.Thread
---@return boolean
local function thread_before(left, right)
	if left.resolved ~= right.resolved then
		return not left.resolved
	end
	return thread_line(left) < thread_line(right)
end

---@param left string
---@param right string
---@return boolean
local function path_before(left, right)
	local left_directory, right_directory = vim.fs.dirname(left), vim.fs.dirname(right)
	if left_directory ~= right_directory then
		return left_directory < right_directory
	end
	return left < right
end

--- Sort file paths in the tab's order: by directory, then by path.
---@param paths string[]
---@return string[] paths
function M.sort_paths(paths)
	table.sort(paths, path_before)
	return paths
end

---@param review gleb.pr.Review
---@return gleb.ui.tree.Node[]
local function review_nodes(review)
	local by_directory = {}
	for _, thread in ipairs(review.threads) do
		local directory = vim.fs.dirname(thread.path)
		by_directory[directory] = by_directory[directory] or {}
		local files = by_directory[directory]
		files[thread.path] = files[thread.path] or {}
		table.insert(files[thread.path], thread)
	end

	local directories = vim.tbl_keys(by_directory)
	table.sort(directories)
	local result = {}
	for _, directory in ipairs(directories) do
		local files = by_directory[directory]
		local directory_count = 0
		local file_nodes = {}
		local paths = vim.tbl_keys(files)
		table.sort(paths)
		for _, path in ipairs(paths) do
			local file_threads = files[path]
			table.sort(file_threads, thread_before)
			local open_count = threads.open_count(file_threads)
			directory_count = directory_count + open_count
			local children = vim.tbl_map(function(thread)
				local row = thread_row(thread)
				return { id = assert(row.id, "Comments rows have ids"), data = row }
			end, file_threads)
			local row = {
				id = "comments:file:" .. path,
				kind = "comment_file",
				root = "comments",
				label = vim.fs.basename(path),
				path = path,
				depth = 1,
				count = open_count,
				committed = true,
				thread = file_threads[1],
			}
			file_nodes[#file_nodes + 1] = {
				id = assert(row.id, "Comments rows have ids"),
				children = children,
				foldable = true,
				open_by_default = true,
				data = row,
			}
		end
		local row = {
			id = "comments:dir:" .. directory,
			kind = "directory",
			root = "comments",
			label = directory,
			path = directory,
			depth = 0,
			count = directory_count,
		}
		result[#result + 1] = {
			id = assert(row.id, "Comments rows have ids"),
			children = file_nodes,
			foldable = true,
			open_by_default = true,
			data = row,
		}
	end
	return result
end

---@param root string
---@return gleb.ui.tree.Node[]
function M.nodes(root)
	local info = require("gleb.git.base").get(root)
	local review = require("gleb.pr").get(root)
	if not info or not info.pr then
		return {}
	end
	local base_name = info.base_ref:gsub("^origin/", "")
	local header = ("#%d %s → %s"):format(info.pr.number, info.branch, base_name)
	local fixed = {
		{ id = "comments:header", kind = "header", root = "comments", label = header, depth = 0, pr = true },
	}
	if review then
		local open = threads.open_count(review.threads)
		fixed[#fixed + 1] = {
			id = "comments:summary",
			kind = "summary",
			root = "comments",
			label = ("%d open · %d resolved"):format(open, #review.threads - open),
			depth = 0,
		}
		fixed[#fixed + 1] = { id = "comments:blank", kind = "blank", root = "comments", label = "", depth = 0 }
	else
		local failure = require("gleb.pr").state.failures[root]
		fixed[#fixed + 1] = {
			id = "comments:state",
			kind = "comment_state",
			root = "comments",
			label = failure or "Loading…",
			depth = 0,
		}
	end
	local nodes = vim.tbl_map(function(row)
		return { id = assert(row.id, "Comments rows have ids"), data = row }
	end, fixed)
	if review then
		vim.list_extend(nodes, review_nodes(review))
	end
	return nodes
end

--- Edit `path` in `win` unless it already shows it: `:edit` on the shown file re-reads it, which restarts its
--- folds and language servers and moves the view.
---@param win integer
---@param path string
---@return nil
local function show_file(win, path)
	local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
	if name ~= "" and vim.uv.fs_realpath(name) == vim.uv.fs_realpath(path) then
		return
	end
	vim.api.nvim_win_call(win, function()
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end)
end

---@param thread gleb.pr.Thread
---@param win integer
---@param focus boolean
---@return nil
local function show_hunk(thread, win, focus)
	local name = "gleb-pr://hunk/" .. thread.id
	local buf = vim.fn.bufnr(name)
	if buf == -1 then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, name)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "diff"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(thread.comments[1].diff_hunk, "\n", { plain = true }))
		vim.bo[buf].modifiable = false
	end
	vim.api.nvim_win_set_buf(win, buf)
	if focus then
		vim.api.nvim_set_current_win(win)
	end
end

---@param view ChangesView
---@param row ChangesRow
---@param focus boolean
---@param on_shown? fun(show_hunk: boolean)
---@return nil
function M.preview(view, row, focus, on_shown)
	local thread = row.thread
	if not thread then
		return
	end
	---@param used_hunk boolean
	local function finish(used_hunk)
		if on_shown then
			on_shown(used_hunk)
		end
	end
	view.selection_generation = view.selection_generation + 1
	local generation = view.selection_generation
	local editor = view.editor_win
	if not vim.api.nvim_win_is_valid(editor) then
		return
	end
	if thread.side == "LEFT" or thread.subject == "file" then
		show_hunk(thread, editor, focus)
		finish(true)
		return
	end
	show_file(editor, vim.fs.joinpath(view.root, thread.path))
	local buf = vim.api.nvim_win_get_buf(editor)
	local function show(locations)
		if generation ~= view.selection_generation or not vim.api.nvim_win_is_valid(editor) then
			return
		end
		local location = vim.iter(locations):find(function(item)
			return item.thread.id == thread.id
		end)
		if location then
			if not location.line then
				show_hunk(thread, editor, focus)
				finish(true)
				return
			end
			vim.api.nvim_win_set_cursor(editor, { location.line, 0 })
		end
		if focus then
			vim.api.nvim_set_current_win(editor)
		end
		require("gleb.pr.peek").redraw(buf)
		finish(false)
	end
	local locations, loading = require("gleb.pr").locate(buf, show)
	if not loading then
		show(locations)
	end
end

--- `<CR>` on a thread row: drop the pending debounced selection, which would show the row again after the focus
--- moved, then show the thread at once and focus the editor window.
---@param view ChangesView
---@param row ChangesRow
---@return nil
function M.open(view, row)
	view.diff_timer:stop()
	---@param use_diff_hunk boolean
	local function open_thread(use_diff_hunk)
		local review = require("gleb.pr").get(view.root)
		if review and row.thread then
			local thread = assert(row.thread, "thread row must have a thread")
			if use_diff_hunk and thread.side ~= "LEFT" and thread.subject ~= "file" then
				thread = vim.deepcopy(thread)
				thread.side = "LEFT"
			end
			require("gleb.pr.thread_window").open(review, thread)
		end
	end
	M.preview(view, row, true, open_thread)
	view.loaded_buffers[vim.api.nvim_win_get_buf(view.editor_win)] = nil
end

return M
