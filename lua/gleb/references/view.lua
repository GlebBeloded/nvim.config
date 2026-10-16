-- Find Usages owns a joined floating frame so grouped rows and code can remain visible together.
local M = {
	state = {},
}

local icons = require("gleb.references.icons")
local tree = require("gleb.references.tree")

---@class gleb.references.ViewState
---@field windows integer[]
---@field buffers integer[]
---@field tree? gleb.references.Tree

---@param node gleb.references.TreeNode
---@return string
local function tree_line(node)
	local icon = icons.for_node(node).icon
	if node.kind == "scope" then
		return string.format("▾ %s %s  %d", icon, node.label, node.count)
	end
	if node.kind == "folder" then
		return string.format("  ▾ %s %s  %d", icon, node.label, node.count)
	end
	return string.format("      %s %s", icon, node.label)
end

---@param usage gleb.references.TreeNode
---@param height integer
---@return string[]
local function preview_lines(usage, height)
	local filename = vim.uri_to_fname(assert(usage.uri, "selected reference has no URI"))
	local source = vim.fn.readfile(filename)
	local radius = math.max(math.floor((height - 2) / 2), 1)
	local first = math.max(assert(usage.lnum, "selected reference has no line") - radius, 1)
	local last = math.min(first + height - 2, #source)
	local lines = { string.format("%s:%d", usage.path, usage.lnum) }
	for lnum = first, last do
		table.insert(lines, string.format("%4d  %s", lnum, source[lnum]))
	end
	return lines
end

---@param buf integer
---@param filetype string
local function configure_buffer(buf, filetype)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = filetype
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

---@param buf integer
---@param enter boolean
---@param config vim.api.keyset.win_config
---@return integer
local function open_window(buf, enter, config)
	local win = vim.api.nvim_open_win(buf, enter, config)
	vim.wo[win].winhighlight = "Normal:MiniPickNormal,FloatBorder:PickerBorder,CursorLine:MiniPickMatchCurrent"
	vim.wo[win].cursorline = enter
	vim.wo[win].number = false
	vim.wo[win].signcolumn = "no"
	return win
end

---@param built gleb.references.Tree
---@return gleb.references.TreeNode
local function selected_usage(built)
	for _, node in ipairs(built.nodes) do
		if node.id == built.selected_id then
			return node
		end
	end
	error("references tree has no selected usage")
end

---@param title string
---@param usages gleb.references.Usage[]
---@return nil
function M.open(title, usages)
	M.close()
	icons.setup()
	local built = tree.build(usages, { tests = "grouped", folders = true })
	local selected = selected_usage(built)
	local wide = vim.o.columns >= 80
	local outer_width = vim.o.columns - 4
	local body_height = vim.o.lines - 6
	local tree_width = wide and math.floor((outer_width - 3) * 0.45) or math.min(outer_width - 2, 46)
	local preview_width = outer_width - tree_width - 3
	local row = 1
	local col = math.floor((vim.o.columns - outer_width) / 2)

	local tree_buf = vim.api.nvim_create_buf(false, true)
	configure_buffer(tree_buf, "gleb-references")
	set_lines(tree_buf, vim.tbl_map(tree_line, built.nodes))
	local tree_win = open_window(tree_buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = tree_width,
		height = body_height,
		border = wide and { "╭", "─", "┬", "│", "┴", "─", "╰", "│" } or "rounded",
		title = string.format(" Usages of %s · %d ", title, built.count),
		title_pos = "left",
		style = "minimal",
		zindex = 50,
	})

	local windows = { tree_win }
	local buffers = { tree_buf }
	if wide then
		local preview_buf = vim.api.nvim_create_buf(false, true)
		configure_buffer(preview_buf, "gleb-references-preview")
		set_lines(preview_buf, preview_lines(selected, body_height))
		local preview_win = open_window(preview_buf, false, {
			relative = "editor",
			row = row,
			col = col + tree_width + 1,
			width = preview_width,
			height = body_height,
			border = { "─", "─", "╮", "│", "╯", "─", "┴", "│" },
			style = "minimal",
			focusable = false,
			zindex = 50,
		})
		table.insert(windows, preview_win)
		table.insert(buffers, preview_buf)
	end

	local hint = wide and "Tests: grouped t · ● Folders f · Preview P · Open ↩"
		or "Tests: grouped t · ● Folders f"
	local hint_buf = vim.api.nvim_create_buf(false, true)
	configure_buffer(hint_buf, "gleb-references-hint")
	set_lines(hint_buf, { string.rep(" ", math.max(outer_width - vim.fn.strdisplaywidth(hint) - 2, 0)) .. hint })
	local hint_win = open_window(hint_buf, false, {
		relative = "editor",
		row = row + body_height + 1,
		col = col,
		width = outer_width - 2,
		height = 1,
		border = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
		style = "minimal",
		focusable = false,
		zindex = 51,
	})
	table.insert(windows, hint_win)
	table.insert(buffers, hint_buf)

	for index, node in ipairs(built.nodes) do
		if node.id == built.selected_id then
			vim.api.nvim_win_set_cursor(tree_win, { index, 0 })
			break
		end
	end
	M.state = { windows = windows, buffers = buffers, tree = built }
end

---@return nil
function M.close()
	for _, win in ipairs(M.state.windows or {}) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	M.state = {}
end

return M
