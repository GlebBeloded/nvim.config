package.loaded["gleb.ai.pi_provider"] = nil
package.loaded["99"] = {
	Providers = {
		BaseProvider = {},
	},
}

local provider = require("gleb.ai.pi_provider")

describe("PiProvider", function()
	it("runs Pi ephemerally with low thinking", function()
		local context = { model = "openai-codex/gpt-5.6-sol" }

		assert.same({
			"pi",
			"--no-session",
			"--model",
			"openai-codex/gpt-5.6-sol",
			"--thinking",
			"low",
			"--print",
			"test query",
		}, provider._build_command(nil, "test query", context))
	end)

	it("defaults to Codex Sol", function()
		assert.equals("openai-codex/gpt-5.6-sol", provider._get_default_model())
	end)
end)
