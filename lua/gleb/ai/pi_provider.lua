---Looks up members PiProvider does not override on 99's base provider, once 99 is loaded.
---@param _ table
---@param key string
---@return any
local function inherit_base(_, key)
	return require("99").Providers.BaseProvider[key]
end

local PiProvider = setmetatable({}, { __index = inherit_base })

PiProvider.MODEL = "openai-codex/gpt-5.6-sol"

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
	return PiProvider.MODEL
end

return PiProvider
