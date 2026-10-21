-- Find Usages owns a joined floating frame so grouped rows and code can remain visible together.
local M = {
	state = {},
}

local format = require("gleb.references.format")
local icons = require("gleb.references.icons")
local layout = require("gleb.references.layout")
local preview = require("gleb.references.preview")
local persisted_state = require("gleb.references.state")
local tree = require("gleb.references.tree")
local tree_model = require("gleb.ui.tree.model")
local tree_view = require("gleb.ui.tree.view")

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
---@field shared_tree? gleb.ui.tree.Model
---@field visible_nodes? gleb.references.TreeNode[]
---@field origin_win? integer
---@field origin_cursor? integer[]
---@field classifying? boolean
---@field id? integer

local FRAME_HIGHLIGHT =
	"Normal:MiniPickNormal,FloatBorder:PickerBorder,FloatTitle:MiniPickBorderText,EndOfBuffer:MiniPickNormal"
local TREE_HIGHLIGHT = FRAME_HIGHLIGHT .. ",CursorLine:MiniPickMatchCurrent"
local HINT_HIGHLIGHT = FRAME_HIGHLIGHT
local next_view_id = 0

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
	if not state.tree_win or not state.shared_tree then
		return nil
	end
	local id = tree_view.selected_id(state.shared_tree)
	local node = id and state.shared_tree.nodes[id]
	return node and node.data or nil
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
	if state.tree.has_types then
		hint = string.format(
			"%s · %s Usage type %s",
			hint,
			state.options.usage_type and "●" or "○",
			shortcut("references.toggle_usage_type", "u")
		)
	end
	if wide then
		local open_key = shortcut("references.open", "<CR>")
		if open_key == "<CR>" then
			open_key = "↩"
		end
		hint = string.format("%s · Preview %s · Open %s", hint, shortcut("references.toggle_preview", "P"), open_key)
	end
	return hint
end

---@param nodes gleb.references.TreeNode[]
---@return gleb.ui.tree.Node[]
local function shared_nodes(nodes)
	local indexed = {}
	for _, node in ipairs(nodes) do
		indexed[node.id] = {
			id = node.id,
			children = {},
			foldable = node.kind ~= "usage",
			open_by_default = true,
			data = node,
		}
	end

	local roots = {}
	for _, node in ipairs(nodes) do
		local shared = indexed[node.id]
		local parent = node.parent_id and indexed[node.parent_id]
		if parent then
			parent.children[#parent.children + 1] = shared
		else
			roots[#roots + 1] = shared
		end
	end
	return roots
end

---@param width? integer text width of the tree window
---@param selected_id? string
---@return nil
local function render_tree(width, selected_id)
	tree_view.draw(M.state.shared_tree, function(buf, tree_rows)
		M.state.visible_nodes = vim.tbl_map(function(row)
			return row.node.data
		end, tree_rows)
		local rows = vim.tbl_map(function(node)
			return format.tree_segments(node, M.state.shared_tree.folds, width)
		end, M.state.visible_nodes)
		set_lines(buf, vim.tbl_map(format.text, rows))
		format.clear_highlights(buf)
		for index, segments in ipairs(rows) do
			format.highlight(buf, index - 1, segments)
		end
	end, selected_id)
end

--- The cursor moves to `selected_id` before the preview reads the usage under it.
---@param selected_id? string
---@return nil
local function apply_layout(selected_id)
	layout.apply(M.state, {
		hint = M.hint,
		render_tree = function(width)
			render_tree(width, selected_id)
		end,
		update_preview = function()
			preview.update(M.state)
		end,
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
	local selected = as_usage(preview.selected(M.state) or M.state.preview_usage)
	M.state.tree = tree.build(M.state.usages, M.state.options, selected)
	tree_model.rebuild(M.state.shared_tree, shared_nodes(M.state.tree.nodes))
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
---@param classifying? boolean
---@return integer view_id
function M.open(title, usages, classifying)
	if not _G.MiniPick then
		require("gleb.picker.frame").setup()
	end
	M.close()
	icons.setup()
	local origin_win = vim.api.nvim_get_current_win()
	local origin_cursor = vim.api.nvim_win_get_cursor(origin_win)
	local options = persisted_state.load()
	local built = tree.build(usages, options)
	local selected = selected_usage(built)
	next_view_id = next_view_id + 1
	local view_id = next_view_id

	local tree_buf = vim.api.nvim_create_buf(false, true)
	configure_buffer(tree_buf, "gleb-references")
	set_lines(
		tree_buf,
		vim.tbl_map(function(node)
			return format.text(format.tree_segments(node, {}))
		end, built.nodes)
	)
	local tree_win = open_window(tree_buf, true, {
		relative = "editor",
		row = 0,
		col = 0,
		width = 1,
		height = 1,
		border = "rounded",
		title = string.format(" Usages of %s · %d%s ", title, built.count, classifying and " · classifying" or ""),
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
		shared_tree = tree_model.new(shared_nodes(built.nodes)),
		visible_nodes = built.nodes,
		origin_win = origin_win,
		origin_cursor = origin_cursor,
		classifying = classifying == true,
		id = view_id,
	}
	tree_view.attach(tree_buf, M.state.shared_tree, { after_redraw = apply_layout })
	local group = vim.api.nvim_create_augroup("gleb_references_view", { clear = true })
	preview.follow(M.state, group)
	vim.api.nvim_create_autocmd("WinClosed", { group = group, pattern = tostring(tree_win), callback = M.close })
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			apply_layout()
		end,
	})
	apply_layout()
	return view_id
end

---Finish the current view's asynchronous usage-kind classification.
---@param view_id integer
---@param usages gleb.references.Usage[]
---@return nil
function M.finish_classification(view_id, usages)
	if M.state.id ~= view_id or not M.state.classifying then
		return
	end
	M.state.usages = usages
	M.state.classifying = false
	rebuild()
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
function M.toggle_usage_type()
	if not M.state.tree or not M.state.tree.has_types then
		return
	end
	M.state.options.usage_type = not M.state.options.usage_type
	persisted_state.save(M.state.options)
	rebuild()
end

---@return nil
function M.fold()
	require("gleb.ui.tree").toggle(M.state.shared_tree)
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
