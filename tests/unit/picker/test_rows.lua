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
		"Open  file.lua                Config",
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
			{ { 6, 14, "PickerSecondary" }, { 30, 36, "PickerCategory" } },
			{ { 30, 33, "PickerToggleOn" }, { 34, 38, "PickerCategory" } },
			{ { 30, 33, "PickerToggleOff" }, { 34, 38, "PickerCategory" } },
		}
	)
end

T["picker: Section header fills its row with a rule"] = function()
	child.lua([[Rows.render(RowsBuffer, { { text = "recently used", section = true } }, 24)]])

	eq(child.lua_get("vim.api.nvim_buf_get_lines(RowsBuffer, 0, -1, false)"), {
		"recently used ──────────",
	})
	eq(
		child.lua_get([[
		vim.tbl_map(function(mark)
			return { mark[3], mark[4].end_col, mark[4].hl_group }
		end, vim.api.nvim_buf_get_extmarks(RowsBuffer, -1, 0, -1, { details = true }))
	]]),
		{
			{ 0, 13, "PickerSectionLabel" },
			{ 14, 44, "PickerSectionRule" },
		}
	)
end

return T
