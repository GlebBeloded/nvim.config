local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		Rows = require("gleb.picker.rows")
		RowsBuffer = vim.api.nvim_create_buf(false, true)
	]])
end

local T = H.child_set(child, start)

T["picker: Rows expose primary secondary and category text"] = function()
	child.lua([[
		Rows.render(RowsBuffer, {
			{ text = "Open", secondary = "file.lua", category = "Config" },
			{ text = "Enabled", category = "Flag", glyph = true },
			{ text = "Disabled", category = "Flag", glyph = false },
		}, 36)
	]])

	eq(child.lua_get("vim.api.nvim_buf_get_lines(RowsBuffer, 0, -1, false)"), {
		"Open file.lua                 Config",
		"Enabled                       ● Flag",
		"Disabled                      ○ Flag",
	})
	eq(
		child.lua_get([[
		(function()
			local result = { {}, {}, {} }
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(RowsBuffer, -1, 0, -1, { details = true })) do
				local row, col, details = mark[2], mark[3], mark[4]
				table.insert(result[row + 1], { col, details.end_col, details.hl_group })
			end
			return result
		end)()
	]]),
		{
			{ { 5, 13, "Comment" }, { 30, 36, "PmenuExtra" } },
			{ { 30, 33, "PmenuKind" }, { 34, 38, "PmenuExtra" } },
			{ { 30, 33, "PmenuExtra" }, { 34, 38, "PmenuExtra" } },
		}
	)
end

T["picker: Section header fills its row with a rule"] = function()
	child.lua([[Rows.render(RowsBuffer, { { text = "recently used", section = true } }, 24)]])

	eq(child.lua_get("vim.api.nvim_buf_get_lines(RowsBuffer, 0, -1, false)"), {
		"recently used ──────────",
	})
end

return T
