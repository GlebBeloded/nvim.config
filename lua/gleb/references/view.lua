-- Find Usages owns a joined floating frame so grouped rows and code can remain visible together.
local M = {
	state = {},
}

local icons = require("gleb.references.icons")
local preview = require("gleb.references.preview")
local persisted_state = require("gleb.references.state")
local tree = require("gleb.references.tree")

---@class gleb.references.ViewState
---@field windows integer[]
---@field buffers integer[]
---@field tree? gleb.references.Tree
---@field tree_win? integer
---@field tree_buf? integer
---@field hint_win? integer
---@field hint_buf? integer
---@field preview_win? integer
---@field preview_buf? integer
---@field preview_usage? gleb.references.TreeNode
---@field preview_visible? boolean
---@field title? string
---@field usages? gleb.references.Usage[]
---@field options? gleb.references.PersistedState
---@field folded? table<string, boolean>
---@field visible_nodes? gleb.references.TreeNode[]
---@field origin_win? integer
---@field origin_cursor? integer[]

---@class gleb.references.Segment
---@field text string
---@field group? string

local namespace = vim.api.nvim_create_namespace("gleb_references_view")
local TREE_SHARE = 0.45
local WIDE_MIN_COLUMNS = 80
local FRAME_HIGHLIGHT =
	"Normal:MiniPickNormal,FloatBorder:PickerBorder,FloatTitle:MiniPickBorderText,EndOfBuffer:MiniPickNormal"
local TREE_HIGHLIGHT = FRAME_HIGHLIGHT .. ",CursorLine:MiniPickMatchCurrent"
local PREVIEW_HIGHLIGHT = FRAME_HIGHLIGHT .. ",WinBar:MiniPickNormal,WinBarNC:MiniPickNormal"
-- The tree's status column is its left padding, coloured like the row it pads.
local TREE_PADDING = "%{%v:relnum ? '%#MiniPickNormal#' : '%#MiniPickMatchCurrent#'%} "
local HINT_HIGHLIGHT = FRAME_HIGHLIGHT
local WIDE_TREE_BORDER = { "╭", "─", "┬", "│", "┴", "─", "├", "│" }
local NARROW_TREE_BORDER = { "╭", "─", "╮", "│", "┤", "─", "├", "│" }
local PREVIEW_BORDER = { "┬", "─", "╮", "│", "┤", "─", "┴", "│" }
-- The tree and preview bottom borders draw the rule above the hints.
local HINT_BORDER = { "", "", "", "│", "╯", "─", "╰", "│" }
local TOGGLE_ON = "●"

---@param node gleb.references.TreeNode
---@return gleb.references.Segment[]
local function group_segments(node)
	local icon = icons.for_node(node)
	local folded = M.state.folded and M.state.folded[node.id]
	local indent = node.kind == "folder" and "  " or ""
	return {
		{ text = indent .. (folded and "▸" or "▾") .. " " },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = node.label, group = icon.label_group },
		{ text = "  " },
		{ text = tostring(node.count), group = "PickerSecondary" },
	}
end

---@param node gleb.references.TreeNode
---@return gleb.references.Segment[]
local function usage_segments(node)
	local icon = icons.for_node(node)
	local file, line = node.label:match("^(.*)(:%d+)$")
	return {
		{ text = node.depth == 0 and "" or string.rep(" ", node.depth * 2 + 2) },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = file or node.label, group = icon.label_group },
		{ text = line or "", group = "PickerSecondary" },
	}
end

---@param segments gleb.references.Segment[]
---@return string
local function segments_text(segments)
	return table.concat(vim.tbl_map(function(segment)
		return segment.text
	end, segments))
end

---@param segments gleb.references.Segment[]
---@param width? integer text width the test tag is right-aligned to
local function add_test_tag(segments, width)
	local icon = icons.for_node({ kind = "scope", id = "scope:test", label = "Test", depth = 0 })
	local tag_width = vim.fn.strdisplaywidth(icon.icon .. " test")
	local line_width = vim.fn.strdisplaywidth(segments_text(segments))
	vim.list_extend(segments, {
		{ text = string.rep(" ", math.max((width or 0) - line_width - tag_width, 2)) },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = "test", group = icon.label_group },
	})
end

---@param node gleb.references.TreeNode
---@param width? integer
---@return gleb.references.Segment[]
local function tree_segments(node, width)
	if node.kind ~= "usage" then
		return group_segments(node)
	end
	local segments = usage_segments(node)
	if node.test_tag then
		add_test_tag(segments, width)
	end
	return segments
end

---@param buf integer
---@param row integer 0-based
---@param segments gleb.references.Segment[]
local function highlight_segments(buf, row, segments)
	local col = 0
	for _, segment in ipairs(segments) do
		if segment.group and segment.text ~= "" then
			vim.api.nvim_buf_set_extmark(
				buf,
				namespace,
				row,
				col,
				{ end_col = col + #segment.text, hl_group = segment.group }
			)
		end
		col = col + #segment.text
	end
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
---@param winhighlight string
---@return integer
local function open_window(buf, enter, config, winhighlight)
	local win = vim.api.nvim_open_win(buf, enter, config)
	vim.wo[win].winhighlight = winhighlight
	vim.wo[win].cursorline = enter
	vim.wo[win].number = false
	vim.wo[win].signcolumn = "no"
	return win
end

---@return gleb.references.TreeNode?
local function node_under_cursor()
	local state = M.state
	if not state.tree_win or not state.visible_nodes then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(state.tree_win)[1]
	return state.visible_nodes[row]
end

---@return gleb.references.TreeNode?
local function usage_under_cursor()
	local node = node_under_cursor()
	return node and node.kind == "usage" and node or nil
end

---@return nil
local function update_preview()
	local state = M.state
	local usage = usage_under_cursor()
	if not usage then
		state.preview_usage = nil
		state.tree.selected_id = nil
		if state.preview_buf then
			preview.clear(state.preview_buf, state.preview_win)
		end
		return
	end
	state.preview_usage = usage
	state.tree.selected_id = usage.id
	if not state.preview_buf or not state.preview_win then
		return
	end
	preview.render(state.preview_buf, usage, state.usages, state.title)
	preview.center(state.preview_win, usage)
end

---@class gleb.references.Geometry
---@field inner_width integer
---@field body_height integer
---@field tree_width integer
---@field preview_width integer
---@field row integer
---@field col integer

--- Without the preview the frame fits the widest row or hint plus one padding cell per side.
---@return integer
local function fitted_width()
	local widest = vim.fn.strdisplaywidth(M.hint(false))
	for _, line in ipairs(vim.api.nvim_buf_get_lines(M.state.tree_buf, 0, -1, false)) do
		widest = math.max(widest, vim.fn.strdisplaywidth(line))
	end
	return widest + 2
end

---@param visible boolean
---@return gleb.references.Geometry
local function geometry(visible)
	local columns, lines = vim.o.columns, vim.o.lines
	local inner_width, body_height, tree_width
	if visible then
		inner_width = columns - 6
		body_height = lines - 6
		tree_width = math.floor(inner_width * TREE_SHARE)
	else
		inner_width = math.min(fitted_width(), columns - 6)
		body_height = math.max(1, math.min(#M.state.visible_nodes, lines - 6))
		tree_width = inner_width
	end
	return {
		inner_width = inner_width,
		body_height = body_height,
		tree_width = tree_width,
		preview_width = inner_width - tree_width - 1,
		row = math.floor((lines - body_height - 4) / 2),
		col = math.floor((columns - inner_width - 2) / 2),
	}
end

---@param id string
---@param fallback string
---@return string
local function shortcut(id, fallback)
	local actions = require("gleb.actions")
	local store = actions.state.store
	local keys = store and store.last_good[id]
	return (keys and keys[1]) or fallback
end

---@param wide boolean
---@return string
function M.hint(wide)
	local state = M.state
	local tests_key = shortcut("references.cycle_tests", "t")
	local folders_key = shortcut("references.toggle_folders", "f")
	local hint = string.format(
		"Tests: %s %s · %s Folders %s",
		state.options.tests,
		tests_key,
		state.options.folders and "●" or "○",
		folders_key
	)
	if wide then
		local open_key = shortcut("references.open", "<CR>")
		if open_key == "<CR>" then
			open_key = "↩"
		end
		hint = string.format("%s · Preview %s · Open %s", hint, shortcut("references.toggle_preview", "P"), open_key)
	end
	return hint
end

---@return gleb.references.TreeNode[]
local function visible_nodes()
	local result = {}
	local hidden_depth
	for _, node in ipairs(M.state.tree.nodes) do
		if not hidden_depth or node.depth <= hidden_depth then
			hidden_depth = nil
			table.insert(result, node)
			if node.kind ~= "usage" and M.state.folded[node.id] then
				hidden_depth = node.depth
			end
		end
	end
	return result
end

---@param width? integer text width of the tree window
---@return nil
local function render_tree(width)
	local buf = M.state.tree_buf
	M.state.visible_nodes = visible_nodes()
	local rows = vim.tbl_map(function(node)
		return tree_segments(node, width)
	end, M.state.visible_nodes)
	set_lines(buf, vim.tbl_map(segments_text, rows))
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for index, segments in ipairs(rows) do
		highlight_segments(buf, index - 1, segments)
	end
end

---@param size gleb.references.Geometry
---@param visible boolean
local function render_hint(size, visible)
	local buf = M.state.hint_buf
	local hint = M.hint(visible)
	local padding = string.rep(" ", math.max(size.inner_width - vim.fn.strdisplaywidth(hint) - 1, 1))
	local line = padding .. hint .. " "
	set_lines(buf, { line })
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	vim.api.nvim_buf_set_extmark(
		buf,
		namespace,
		0,
		#padding,
		{ end_col = #line, hl_group = "PickerHint", priority = vim.hl.priorities.syntax }
	)
	local toggle = hint:find(TOGGLE_ON, 1, true)
	if toggle then
		local col = #padding + toggle - 1
		vim.api.nvim_buf_set_extmark(
			buf,
			namespace,
			0,
			col,
			{ end_col = col + #TOGGLE_ON, hl_group = "PickerToggleOn", priority = vim.hl.priorities.user }
		)
	end
end

---@return nil
local function close_preview()
	local state = M.state
	if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
		vim.api.nvim_win_close(state.preview_win, true)
	end
	state.preview_win = nil
	state.preview_buf = nil
end

---@param selected_id? string
---@return nil
local function place_cursor(selected_id)
	local state = M.state
	if #state.visible_nodes == 0 then
		vim.api.nvim_win_set_cursor(state.tree_win, { 1, 0 })
		return
	end
	for index, node in ipairs(state.visible_nodes) do
		if node.id == selected_id then
			vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
			return
		end
	end
	vim.api.nvim_win_set_cursor(
		state.tree_win,
		{ math.min(vim.api.nvim_win_get_cursor(state.tree_win)[1], #state.visible_nodes), 0 }
	)
end

---@param size gleb.references.Geometry
local function show_preview(size)
	local state = M.state
	if not state.preview_buf then
		state.preview_buf = vim.api.nvim_create_buf(false, true)
		configure_buffer(state.preview_buf, "gleb-references-preview")
		table.insert(state.buffers, state.preview_buf)
	end
	---@type vim.api.keyset.win_config
	local config = {
		relative = "editor",
		row = size.row,
		col = size.col + size.tree_width + 1,
		width = size.preview_width,
		height = size.body_height,
		border = PREVIEW_BORDER,
		style = "minimal",
		focusable = false,
		zindex = 50,
	}
	if state.preview_win then
		vim.api.nvim_win_set_config(state.preview_win, config)
	else
		state.preview_win = open_window(state.preview_buf, false, config, PREVIEW_HIGHLIGHT)
		table.insert(state.windows, state.preview_win)
	end
end

--- The cursor moves to `selected_id` before the preview reads the usage under it.
---@param selected_id? string
---@return nil
local function apply_layout(selected_id)
	local state = M.state
	render_tree()
	local visible = state.preview_visible and vim.o.columns >= WIDE_MIN_COLUMNS
	local size = geometry(visible)
	vim.api.nvim_win_set_config(state.tree_win, {
		relative = "editor",
		row = size.row,
		col = size.col,
		width = size.tree_width,
		height = size.body_height,
		border = visible and WIDE_TREE_BORDER or NARROW_TREE_BORDER,
		title = string.format(" Usages of %s · %d ", state.title, state.tree.count),
		title_pos = "left",
		style = "minimal",
		zindex = 50,
	})
	vim.wo[state.tree_win].statuscolumn = TREE_PADDING
	render_tree(size.tree_width - 2)
	if selected_id then
		place_cursor(selected_id)
	end

	if visible then
		show_preview(size)
	else
		close_preview()
	end
	update_preview()

	render_hint(size, visible)
	vim.api.nvim_win_set_config(state.hint_win, {
		relative = "editor",
		row = size.row + size.body_height + 2,
		col = size.col,
		width = size.inner_width,
		height = 1,
		border = HINT_BORDER,
		style = "minimal",
		focusable = false,
		zindex = 51,
	})
end

---@param node gleb.references.TreeNode?
---@return gleb.references.Usage?
local function as_usage(node)
	if not node or node.kind ~= "usage" then
		return nil
	end
	return {
		uri = assert(node.uri, "usage has no uri"),
		path = assert(node.path, "usage has no path"),
		lnum = assert(node.lnum, "usage has no line"),
		col = assert(node.col, "usage has no column"),
		filetype = node.filetype,
	}
end

---@return nil
local function rebuild()
	local selected = as_usage(usage_under_cursor() or M.state.preview_usage)
	M.state.tree = tree.build(M.state.usages, M.state.options, selected)
	apply_layout(M.state.tree.selected_id)
end

---@param built gleb.references.Tree
---@return gleb.references.TreeNode?
local function selected_usage(built)
	for _, node in ipairs(built.nodes) do
		if node.id == built.selected_id then
			return node
		end
	end
end

---@param title string
---@param usages gleb.references.Usage[]
---@return nil
function M.open(title, usages)
	M.close()
	icons.setup()
	local origin_win = vim.api.nvim_get_current_win()
	local origin_cursor = vim.api.nvim_win_get_cursor(origin_win)
	local options = persisted_state.load()
	local built = tree.build(usages, options)
	local selected = selected_usage(built)

	local tree_buf = vim.api.nvim_create_buf(false, true)
	configure_buffer(tree_buf, "gleb-references")
	set_lines(
		tree_buf,
		vim.tbl_map(function(node)
			return segments_text(tree_segments(node))
		end, built.nodes)
	)
	local tree_win = open_window(tree_buf, true, {
		relative = "editor",
		row = 0,
		col = 0,
		width = 1,
		height = 1,
		border = "rounded",
		title = string.format(" Usages of %s · %d ", title, built.count),
		title_pos = "left",
		style = "minimal",
		zindex = 50,
	}, TREE_HIGHLIGHT)

	local hint_buf = vim.api.nvim_create_buf(false, true)
	configure_buffer(hint_buf, "gleb-references-hint")
	set_lines(hint_buf, { "" })
	local hint_win = open_window(hint_buf, false, {
		relative = "editor",
		row = 2,
		col = 0,
		width = 1,
		height = 1,
		border = "rounded",
		style = "minimal",
		focusable = false,
		zindex = 51,
	}, HINT_HIGHLIGHT)
	for index, node in ipairs(built.nodes) do
		if node.id == built.selected_id then
			vim.api.nvim_win_set_cursor(tree_win, { index, 0 })
			break
		end
	end
	M.state = {
		windows = { tree_win, hint_win },
		buffers = { tree_buf, hint_buf },
		tree = built,
		tree_win = tree_win,
		tree_buf = tree_buf,
		hint_win = hint_win,
		hint_buf = hint_buf,
		preview_usage = selected,
		preview_visible = true,
		title = title,
		usages = usages,
		options = options,
		folded = {},
		visible_nodes = built.nodes,
		origin_win = origin_win,
		origin_cursor = origin_cursor,
	}
	local group = vim.api.nvim_create_augroup("gleb_references_view", { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", { group = group, buffer = tree_buf, callback = update_preview })
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			apply_layout()
		end,
	})
	apply_layout()
end

---@return nil
function M.cycle_tests()
	local next_mode = { grouped = "hidden", hidden = "mixed", mixed = "grouped" }
	M.state.options.tests = next_mode[M.state.options.tests]
	persisted_state.save(M.state.options)
	rebuild()
end

---@return nil
function M.toggle_folders()
	M.state.options.folders = not M.state.options.folders
	persisted_state.save(M.state.options)
	rebuild()
end

---@return nil
function M.fold()
	local node = node_under_cursor()
	if not node or node.kind == "usage" then
		return
	end
	M.state.folded[node.id] = not M.state.folded[node.id]
	apply_layout(node.id)
end

---@return nil
function M.open_selected()
	local node = node_under_cursor()
	if not node then
		return
	end
	if node.kind ~= "usage" then
		M.fold()
		return
	end
	local filename = vim.uri_to_fname(node.uri)
	local line, col = node.lnum, node.col
	M.close()
	vim.cmd.edit(vim.fn.fnameescape(filename))
	vim.api.nvim_win_set_cursor(0, { line, col - 1 })
end

---@return nil
function M.toggle_preview()
	if not M.state.tree_win then
		return
	end
	M.state.preview_visible = not M.state.preview_visible
	apply_layout()
end

---@return nil
function M.close()
	pcall(vim.api.nvim_del_augroup_by_name, "gleb_references_view")
	local origin_win = M.state.origin_win
	local origin_cursor = M.state.origin_cursor
	for _, win in ipairs(M.state.windows or {}) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	M.state = {}
	if origin_win and vim.api.nvim_win_is_valid(origin_win) then
		vim.api.nvim_set_current_win(origin_win)
		vim.api.nvim_win_set_cursor(origin_win, origin_cursor)
	end
end

return M
