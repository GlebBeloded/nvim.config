local BaseProvider = require("99").Providers.BaseProvider

local PiProvider = setmetatable({}, { __index = BaseProvider })

function PiProvider._build_command(_, query, context)
	return {
		"pi",
		"--no-session",
		"--model",
		context.model,
		"--thinking",
		"low",
		"--print",
		query,
	}
end

function PiProvider._get_provider_name()
	return "PiProvider"
end

function PiProvider._get_default_model()
	return "openai-codex/gpt-5.6-sol"
end

return PiProvider
