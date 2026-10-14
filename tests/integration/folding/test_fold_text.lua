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

		vim.cmd("vnew")
		local go_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(go_buf, 0, -1, false, {
			"func goFold() {",
			"\treturn goValue",
			"}",
		})
		vim.bo[go_buf].filetype = "go"
		local go_win = vim.api.nvim_get_current_win()
		local handler = require("ufo.config").fold_virt_text_handler
		local truncate = function(text) return text end

		vim.api.nvim_set_current_win(go_win)
		local lua_text = handler({ { "local function lua_fold() " }, { "{" } }, 1, 3, 80, truncate, {
			bufnr = lua_buf,
		})
		vim.api.nvim_set_current_win(lua_win)
		local go_text = handler({ { "func" } }, 1, 3, 80, truncate, { bufnr = go_buf })

		return { lua_text[#lua_text][1], go_text[#go_text][1] }
	end)()]])

	eq(summaries, { "}", " goValue" })
end

return T
