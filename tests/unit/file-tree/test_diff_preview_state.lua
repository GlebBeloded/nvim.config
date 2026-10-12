local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[DiffPreview = require("gleb.file_tree.diff_preview")]])
end

---@return { original_tab: integer?, diff_tab: integer?, current_file: string?, navigating_until: number }
local function state()
	return child.lua_get("DiffPreview.state")
end

---@return integer
local function tab_count()
	return #child.api.nvim_list_tabpages()
end

local EMPTY_STATE = { navigating_until = 0 }

local T = H.child_set(child, start)

T["file-tree: State starts empty"] = function()
	child.lua("DiffPreview.reset()")

	eq(state(), EMPTY_STATE)
end

T["file-tree: Reset clears populated state"] = function()
	child.lua([[
		DiffPreview.state.current_file = "/some/path"
		DiffPreview.state.original_tab = vim.api.nvim_get_current_tabpage()
		DiffPreview.state.diff_tab = 1
		DiffPreview.state.navigating_until = 999999
		DiffPreview.reset()
	]])

	eq(state(), EMPTY_STATE)
end

T["file-tree: Nil path is ignored"] = function()
	local before = tab_count()
	child.lua("DiffPreview.open_diff(nil)")

	eq(state().current_file, nil)
	eq(tab_count(), before)
end

T["file-tree: Same file is ignored"] = function()
	child.lua([[DiffPreview.state.current_file = "/test/file.lua"]])
	local before = tab_count()
	child.lua([[DiffPreview.open_diff("/test/file.lua")]])
	vim.uv.sleep(100)

	eq(tab_count(), before)
end

T["file-tree: Focus returns false without neo-tree"] = function()
	eq(child.lua_get("DiffPreview.focus_neo_tree()"), false)
end

T["file-tree: Return to original tab"] = function()
	local original = child.api.nvim_get_current_tabpage()
	child.lua([[
		DiffPreview.state.original_tab = vim.api.nvim_get_current_tabpage()
		vim.cmd("tabnew")
		DiffPreview.state.diff_tab = vim.api.nvim_get_current_tabpage()
		DiffPreview.return_to_original()
	]])

	eq(child.api.nvim_get_current_tabpage(), original)
end

T["file-tree: Return clears current file"] = function()
	child.lua([[DiffPreview.state.current_file = "/some/file"; DiffPreview.return_to_original()]])

	eq(state().current_file, nil)
end

return T
