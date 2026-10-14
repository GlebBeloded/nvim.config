local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

T["folding: Split buffers use their own fold text"] = function()
	local summaries = child.lua_get([[(function()
		vim.cmd("enew")
		local lua_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(lua_buf, 0, -1, false, {
			"local function lua_fold() {",
			"return lua_value",
			"}",
		})
		vim.bo[lua_buf].filetype = "lua"
		local lua_win = vim.api.nvim_get_current_win()
		vim.wo[lua_win].foldmethod = "manual"
		vim.api.nvim_win_call(lua_win, function() vim.cmd("1,3fold") end)

		vim.cmd("vnew")
		local go_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(go_buf, 0, -1, false, {
			"func goFold() {",
			"\treturn goValue",
			"}",
		})
		vim.bo[go_buf].filetype = "go"
		local go_win = vim.api.nvim_get_current_win()
		vim.wo[go_win].foldmethod = "manual"
		vim.api.nvim_win_call(go_win, function() vim.cmd("1,3fold") end)

		vim.wo[lua_win].foldlevel = 0
		vim.wo[go_win].foldlevel = 0
		vim.api.nvim_set_current_win(go_win)

		local function fold_row(win)
			local pos = vim.fn.win_screenpos(win)
			local cells = {}
			for col = pos[2], pos[2] + vim.api.nvim_win_get_width(win) - 1 do
				table.insert(cells, vim.fn.screenstring(pos[1], col))
			end
			return table.concat(cells)
		end

		vim.wait(1000, function()
			vim.cmd("redraw")
			return fold_row(lua_win):find(" ... }", 1, true) ~= nil
				and fold_row(go_win):find("  goValue", 1, true) ~= nil
		end)

		return { fold_row(lua_win), fold_row(go_win) }
	end)()]])

	eq(summaries[1]:find(" ... }", 1, true) ~= nil, true)
	eq(summaries[2]:find("  goValue", 1, true) ~= nil, true)
end

return T
