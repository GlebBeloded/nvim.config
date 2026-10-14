local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		package.loaded["nui.menu"] = {
			item = function(text, options) return { text = text, options = options } end,
		}
		CodeAction = require("gleb.select.code_action")
	]])
end

local T = H.child_set(child, start)

T["select: Code action menu receives picker mappings"] = function()
	local keymap = child.lua_get([[CodeAction:new({}, { prompt = "Actions" }, function() end):menu().keymap]])

	eq(keymap, {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	})
end

return T
