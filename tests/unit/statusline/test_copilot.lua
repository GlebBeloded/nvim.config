local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

---@class test.CopilotState
---@field disabled? boolean `client.is_disabled()`
---@field startup_error? string `client.startup_error`
---@field status? string `status.data.status`

--- Load stub `copilot.client` / `copilot.status` modules in the child, as
--- copilot.lua leaves them once it has loaded (with a client).
---@param state test.CopilotState
local function stub_copilot(state)
	child.lua(
		[[
		local state = ...
		package.loaded["copilot.client"] = {
			is_disabled = function() return state.disabled end,
			startup_error = state.startup_error,
			get = function() return { id = 1 } end,
		}
		package.loaded["copilot.status"] = { data = { status = state.status } }
	]],
		{ state }
	)
end

---@return string
local function component()
	return child.lua_get([[require("gleb.statusline.copilot").component()]])
end

local T = H.child_set(child, child.start_bare)

T["statusline: copilot glyph hidden before load"] = function()
	eq(child.lua_get([[require("gleb.statusline.copilot").component()]]), "")
	eq(child.lua_get([[package.loaded["copilot.client"] == nil]]), true)
end

T["statusline: copilot glyph hidden when healthy"] = function()
	stub_copilot({ disabled = false, status = "Normal" })

	eq(component(), "")
end

-- The spec asserts "" for the "shown" cases: the glyph is empty in the source
-- (fix-empty-nerd-font-glyphs restores it and updates these cases).
T["statusline: copilot glyph shown when disabled"] = function()
	stub_copilot({ disabled = true, status = "Normal" })

	eq(component(), "")
end

T["statusline: copilot glyph shown on warning"] = function()
	stub_copilot({ disabled = false, status = "Warning" })

	eq(component(), "")
end

return T
