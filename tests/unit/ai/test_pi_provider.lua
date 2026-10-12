local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local STUB_99 = [[
	package.loaded["99"] = { Providers = { BaseProvider = { inherited = "from base" } } }
	Provider = require("gleb.ai.pi_provider")
]]

local function start()
	child.start_bare()
	child.lua(STUB_99)
end

local T = H.child_set(child, start)

T["ai: runs Pi ephemerally with low thinking"] = function()
	local command =
		child.lua_get([[Provider._build_command(nil, "test query", { model = "openai-codex/gpt-5.6-sol" })]])
	eq(command, {
		"pi",
		"--no-session",
		"--model",
		"openai-codex/gpt-5.6-sol",
		"--thinking",
		"low",
		"--print",
		"test query",
	})
end

T["ai: defaults to Codex Sol"] = function()
	eq(child.lua_get("Provider._get_default_model()"), "openai-codex/gpt-5.6-sol")
end

T["ai: Provider name"] = function()
	eq(child.lua_get("Provider._get_provider_name()"), "PiProvider")
end

T["ai: Provider inherits base provider"] = function()
	eq(child.lua_get("Provider.inherited"), "from base")
end

return T
