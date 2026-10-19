-- File-tree actions own the project-tree entry points and local behavior.

local function project_open()
	require("gleb.file_tree.view").open()
end

local function project_close_node()
	require("gleb.file_tree.view").close_node()
end

local function project_close()
	require("gleb.file_tree.view").close()
end

local function project_open_vsplit()
	require("gleb.file_tree.view").open_vsplit()
end

local function project_open_split()
	require("gleb.file_tree.view").open_split()
end

local function project_open_tab()
	require("gleb.file_tree.view").open_tab()
end

local function project_toggle_fold()
	require("gleb.file_tree.view").toggle_fold()
end

local function project_fold_all()
	require("gleb.file_tree.view").fold_all()
end

local function project_unfold_all()
	require("gleb.file_tree.view").unfold_all()
end

local function project_add()
	require("gleb.file_tree.ops").add()
end

local function project_rename()
	require("gleb.file_tree.ops").rename()
end

---@param ctx gleb.ActionContext
local function project_delete(ctx)
	require("gleb.file_tree.ops").delete(ctx)
end

---@param ctx gleb.ActionContext
local function project_copy(ctx)
	require("gleb.file_tree.ops").copy(ctx)
end

---@param ctx gleb.ActionContext
local function project_cut(ctx)
	require("gleb.file_tree.ops").cut(ctx)
end

local function project_paste()
	require("gleb.file_tree.ops").paste()
end

local function project_refresh()
	require("gleb.file_tree.ops").refresh()
end

---@return boolean
local function show_ignored()
	return require("gleb.file_tree.state").show_ignored()
end

---@param _ gleb.ActionContext
---@param value boolean
local function set_show_ignored(_, value)
	require("gleb.file_tree.state").set_show_ignored(value)
	require("gleb.file_tree.view").redraw_all()
end

---@param ctx gleb.ActionContext
local function toggle_show_ignored(ctx)
	set_show_ignored(ctx, not show_ignored())
end

---@type gleb.Action[]
local actions = {
	{
		id = "file_tree.toggle",
		title = "Toggle Project Tree",
		category = "Project",
		run = function()
			require("gleb.file_tree.view").toggle()
		end,
	},
	{
		id = "file_tree.show_ignored",
		title = "Show Ignored",
		category = "Project",
		ft = "gleb-file-tree",
		run = toggle_show_ignored,
		toggle = {
			get = show_ignored,
			set = set_show_ignored,
		},
	},
	{
		id = "file_tree.reveal",
		title = "Reveal in Project Tree",
		category = "Project",
		run = function()
			require("gleb.file_tree.view").reveal()
		end,
	},
	{
		id = "file_tree.add",
		title = "New File or Directory",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_add,
	},
	{
		id = "file_tree.rename",
		title = "Rename",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_rename,
	},
	{
		id = "file_tree.delete",
		title = "Delete",
		category = "Project",
		ft = "gleb-file-tree",
		modes = { "n", "x" },
		run = project_delete,
	},
	{
		id = "file_tree.copy",
		title = "Copy",
		category = "Project",
		ft = "gleb-file-tree",
		modes = { "n", "x" },
		run = project_copy,
	},
	{
		id = "file_tree.cut",
		title = "Cut",
		category = "Project",
		ft = "gleb-file-tree",
		modes = { "n", "x" },
		run = project_cut,
	},
	{
		id = "file_tree.paste",
		title = "Paste",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_paste,
	},
	{
		id = "file_tree.refresh",
		title = "Refresh",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_refresh,
	},
	{
		id = "file_tree.open",
		title = "Open",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open,
	},
	{
		id = "file_tree.close_node",
		title = "Close Node",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_close_node,
	},
	{
		id = "file_tree.close",
		title = "Close",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_close,
	},
	{
		id = "file_tree.open_vsplit",
		title = "Open in Vertical Split",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_vsplit,
	},
	{
		id = "file_tree.open_split",
		title = "Open in Horizontal Split",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_split,
	},
	{
		id = "file_tree.open_tab",
		title = "Open in New Tab",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_open_tab,
	},
	{
		id = "file_tree.toggle_fold",
		title = "Toggle Fold",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_toggle_fold,
	},
	{
		id = "file_tree.fold_all",
		title = "Fold All",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_fold_all,
	},
	{
		id = "file_tree.unfold_all",
		title = "Unfold All",
		category = "Project",
		ft = "gleb-file-tree",
		run = project_unfold_all,
	},
}

return actions
