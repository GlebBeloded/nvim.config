local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	assert(child.wait("vim.v.vim_did_enter == 1", 5000), "VimEnter did not fire")
end

local T = H.child_set(child, start)

T["picker: Dashboard opens shared list pickers"] = function()
	child.type_keys("<CR>")
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Files picker did not open on Enter")
	eq(child.lua_get("MiniPick.get_picker_opts().source.name"), "Files")
	child.lua("MiniPick.stop()")

	local actions = {
		{ key = "f", title = "Files" },
		{ key = "r", title = "Recent Files" },
		{ key = "t", title = "Live Grep" },
	}

	for _, action in ipairs(actions) do
		child.type_keys(action.key)
		assert(child.wait("MiniPick.is_picker_active()", 5000), action.title .. " picker did not open")
		eq(child.lua_get("MiniPick.get_picker_opts().source.name"), action.title)
		child.lua("MiniPick.stop()")
	end
end

return T
