local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.cmd("edit " .. vim.fn.fnameescape(vim.fn.tempname() .. ".txt"))
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["autocommands: q closes special buffers through an action"] = function()
	for _, filetype in ipairs({ "qf", "help", "man", "lspinfo" }) do
		child.cmd("new")
		child.lua("vim.bo.filetype = ...", { filetype })
		local special_window = child.api.nvim_get_current_win()
		local window_count = #child.api.nvim_list_wins()

		local mapping = child.lua_get([[(function()
			local map = vim.fn.maparg("q", "n", false, true)
			return { buffer = map.buffer, desc = map.desc, callback = type(map.callback) }
		end)()]])
		eq(mapping, { buffer = 1, desc = "Window: Close Window", callback = "function" })
		child.type_keys("q")

		eq(#child.api.nvim_list_wins(), window_count - 1)
		eq(child.api.nvim_win_is_valid(special_window), false)
	end
end

return T
