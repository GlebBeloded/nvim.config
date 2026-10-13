local M = {}

---Set up 99 with the Pi provider, then the prompt and entry keymaps.
---@return nil
function M.setup()
	local nn = require("99")
	local provider = require("gleb.ai.pi_provider")
	nn.setup({ provider = provider, model = provider.MODEL })
	require("gleb.ai.prompt_keymaps").setup()
	require("gleb.ai.entry_keymaps").setup(nn)
end

return M
