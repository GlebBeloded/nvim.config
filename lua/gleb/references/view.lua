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

---@param node gleb.references.TreeNode
---@return string
local function tree_line(node, width)
	local icon = icons.for_node(node).icon
	local folded = M.state.folded and M.state.folded[node.id]
	if node.kind == "scope" then
		return string.format("%s %s %s  %d", folded and "▸" or "▾", icon, node.label, node.count)
	end
	if node.kind == "folder" then
		return string.format("  %s %s %s  %d", folded and "▸" or "▾", icon, node.label, node.count)
	end
	local indent = node.depth == 0 and "" or string.rep(" ", node.depth * 2 + 2)
	local line = string.format("%s%s %s", indent, icon, node.label)
	if node.test_tag then
		local tag = icons.for_node({ kind = "scope", id = "scope:test", label = "Test", depth = 0 }).icon .. " test"
		local padding = math.max((width or vim.fn.strdisplaywidth(line) + 2) - vim.fn.strdisplaywidth(line .. tag), 2)
		line = line .. string.rep(" ", padding) .. tag
	end
	return line
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

---@param visible boolean
---@return { outer_width: integer, body_height: integer, tree_width: integer, preview_width: integer, row: integer, col: integer }
local function geometry(visible)
	local state = M.state
	local body_height
	local tree_width
	local outer_width
	if visible then
		outer_width = vim.o.columns - 4
		body_height = vim.o.lines - 6
		tree_width = math.floor((outer_width - 3) * 0.45)
	else
		local hint = M.hint(false)
		local widest = vim.fn.strdisplaywidth(hint)
		for _, line in ipairs(vim.api.nvim_buf_get_lines(state.tree_buf, 0, -1, false)) do
			widest = math.max(widest, vim.fn.strdisplaywidth(line))
		end
		tree_width = math.min(widest, vim.o.columns - 4)
		outer_width = tree_width + 2
		body_height = math.min(#state.visible_nodes, vim.o.lines - 6)
	end
	return {
		outer_width = outer_width,
		body_height = body_height,
		tree_width = tree_width,
		preview_width = outer_width - tree_width - 3,
		row = math.floor((vim.o.lines - body_height - 3) / 2),
		col = math.floor((vim.o.columns - outer_width) / 2),
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

---@param width? integer
---@return nil
local function render_tree(width)
	M.state.visible_nodes = visible_nodes()
	set_lines(
		M.state.tree_buf,
		vim.tbl_map(function(node)
			return tree_line(node, width)
		end, M.state.visible_nodes)
	)
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

---@return nil
local function apply_layout()
	local state = M.state
	render_tree()
	local visible = state.preview_visible and vim.o.columns >= 80
	local size = geometry(visible)
	vim.api.nvim_win_set_config(state.tree_win, {
		relative = "editor",
		row = size.row,
		col = size.col,
		width = size.tree_width,
		height = size.body_height,
		border = visible and { "╭", "─", "┬", "│", "┴", "─", "╰", "│" } or "rounded",
		title = string.format(" Usages of %s · %d ", state.title, state.tree.count),
		title_pos = "left",
		style = "minimal",
		zindex = 50,
	})
	render_tree(size.tree_width)

	if visible then
		if not state.preview_buf then
			state.preview_buf = vim.api.nvim_create_buf(false, true)
			configure_buffer(state.preview_buf, "gleb-references-preview")
			table.insert(state.buffers, state.preview_buf)
		end
		if not state.preview_win then
			state.preview_win = open_window(state.preview_buf, false, {
				relative = "editor",
				row = size.row,
				col = size.col + size.tree_width + 1,
				width = size.preview_width,
				height = size.body_height,
				border = { "─", "─", "╮", "│", "╯", "─", "┴", "│" },
				style = "minimal",
				focusable = false,
				zindex = 50,
			})
			table.insert(state.windows, state.preview_win)
		end
		update_preview()
	else
		close_preview()
	end

	local hint = M.hint(visible)
	set_lines(
		state.hint_buf,
		{ string.rep(" ", math.max(size.outer_width - vim.fn.strdisplaywidth(hint) - 2, 0)) .. hint }
	)
	vim.api.nvim_win_set_config(state.hint_win, {
		relative = "editor",
		row = size.row + size.body_height + 1,
		col = size.col,
		width = size.outer_width - 2,
		height = 1,
		border = visible and { "├", "─", "┤", "│", "╯", "─", "╰", "│" } or "rounded",
		style = "minimal",
		focusable = false,
		zindex = 51,
	})
end

---@param selected_id? string
---@return nil
local function place_cursor(selected_id)
	local state = M.state
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
	apply_layout()
	place_cursor(M.state.tree.selected_id)
	update_preview()
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
			return tree_line(node)
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
	})

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
	})
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
	local selected_id = node.id
	apply_layout()
	place_cursor(selected_id)
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
