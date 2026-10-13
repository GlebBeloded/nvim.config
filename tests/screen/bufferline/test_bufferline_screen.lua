-- Reference screenshots of the bufferline tabline row (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local TAB = "[No Name]"
local TAB_INSET = 8 -- indicator, padding, icon and space before the label in the fixed-width (tab_size) tab
local TREE_COLUMNS = 36 -- neo-tree width 35 plus the window separator

--- An empty buffer in a fresh temp dir on a 100x12 screen.
local function start()
	child.start_config()
	child.wait_very_lazy()
	child.o.lines, child.o.columns = 12, 100
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.cmd("cd " .. dir .. " | enew")
end

local function open_tree()
	child.cmd("Neotree filesystem")
	assert(child.wait([[vim.bo.filetype == "neo-tree"]], 3000), "neo-tree window did not open")
end

---@return string[] cells of row 1 of the screen, one per display column
local function tabline_cells()
	return H.screen_rows(child, 1).text[1]
end

--- Display column where `text` starts in `cells` (cells may hold multibyte glyphs).
---@param cells string[]
---@param text string
---@return integer?
local function cell_column(cells, text)
	for col = 1, #cells - #text + 1 do
		if table.concat(cells, "", col, col + #text - 1) == text then
			return col
		end
	end
end

--- Display column where the `[No Name]` tab (not its centred label) starts in the tabline row.
---@return integer?
local function tab_column()
	local label = cell_column(tabline_cells(), TAB)
	return label and label - TAB_INSET
end

--- Wait until bufferline (redrawn asynchronously) draws the tab at `col`.
---@param col integer
local function wait_for_tab(col)
	local ok = vim.wait(2000, function()
		return tab_column() == col
	end, 20)
	assert(ok, ("%s at column %s, expected %d"):format(TAB, tostring(tab_column()), col))
end

local T = H.child_set(child, start)

T["bufferline: tabs start after the open tree"] = function()
	open_tree()
	vim.wait(2000, function()
		return tab_column() == TREE_COLUMNS + 1
	end, 20)
	eq(table.concat(tabline_cells(), "", 1, TREE_COLUMNS), (" "):rep(TREE_COLUMNS))
	eq(tab_column(), TREE_COLUMNS + 1)
end

T["bufferline: tabline with tree open matches reference screenshot"] = function()
	open_tree()
	wait_for_tab(TREE_COLUMNS + 1)
	H.expect_screenshot(H.screen_rows(child, 1, 1))
end

T["bufferline: tabline without tree matches reference screenshot"] = function()
	open_tree()
	child.cmd("Neotree close")
	wait_for_tab(1)
	H.expect_screenshot(H.screen_rows(child, 1, 1))
end

return T
