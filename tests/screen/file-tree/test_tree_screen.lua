-- Reference screenshot of the neo-tree filesystem tree (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000
local TREE_ROWS = 5 -- docs, workflow.md, empty, lua, init.lua

local function start()
	child.start_config()
	child.wait_very_lazy()
end

--- Fixture: `docs/workflow.md`, `empty/`, `lua/gleb/`, `init.lua`.
---@return string dir
local function fixture_dir()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(vim.fs.joinpath(dir, "docs"), "p")
	vim.fn.mkdir(vim.fs.joinpath(dir, "empty"), "p")
	vim.fn.mkdir(vim.fs.joinpath(dir, "lua", "gleb"), "p")
	vim.fn.writefile({ "# workflow" }, vim.fs.joinpath(dir, "docs", "workflow.md"))
	vim.fn.writefile({ "-- init" }, vim.fs.joinpath(dir, "init.lua"))
	return dir
end

--- Put the cursor on the tree row of `name` and press `<cr>`.
---@param name string
local function press_enter_on(name)
	child.lua([[vim.fn.search(" " .. ... .. "\\>", "w")]], { name })
	child.type_keys("<cr>")
end

local T = H.child_set(child, start)

T["file-tree: filesystem tree matches reference screenshot"] = function()
	child.cmd("cd " .. fixture_dir() .. " | enew | Neotree filesystem")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search(" docs\\>", "nw") > 0]], ASYNC_MS), true)
	press_enter_on("docs")
	eq(child.wait([[vim.fn.search("workflow.md", "nw") > 0]], ASYNC_MS), true)
	press_enter_on("empty")
	press_enter_on("empty")
	vim.uv.sleep(300)
	child.cmd("redraw")

	local root_row = child.fn.win_screenpos(0)[1]
	H.expect_screenshot(H.screen_rows(child, root_row + 1, root_row + TREE_ROWS))
end

return T
