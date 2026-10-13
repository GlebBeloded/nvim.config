local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

---@class CopilotStub
---@field disabled? boolean
---@field startup_error? string
---@field has_client? boolean
---@field status? string

--- Fake the loaded `copilot.client` and `copilot.status` modules in the child.
---@param opts CopilotStub
local function stub_copilot(opts)
	child.lua(
		[[
		local opts = ...
		package.loaded["copilot.client"] = {
			is_disabled = function() return opts.disabled == true end,
			startup_error = opts.startup_error,
			get = function() return opts.has_client and {} or nil end,
		}
		package.loaded["copilot.status"] = { data = { status = opts.status } }
	]],
		{ opts }
	)
end

---@return string
local function component()
	return child.lua_get([[require("gleb.statusline.copilot").component()]])
end

T["statusline: copilot glyph hidden before load"] = function()
	eq(component(), "")
	eq(child.lua_get([[package.loaded["copilot.client"] == nil]]), true)
end

T["statusline: copilot glyph shown when disabled"] = function()
	stub_copilot({ disabled = true, has_client = true, status = "Normal" })

	eq(component(), "\u{F4B8}")
end

T["statusline: copilot glyph shown on warning"] = function()
	stub_copilot({ has_client = true, status = "Warning" })

	eq(component(), "\u{F4B8}")
end

T["statusline: copilot glyph hidden when healthy"] = function()
	stub_copilot({ has_client = true, status = "Normal" })

	eq(component(), "")
end

return T
