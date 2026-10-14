local M = {}

---Set up 99 with the Pi provider, then provide it to entry actions.
---@return nil
function M.setup()
	local ok, nn = pcall(require, "99")
	if not ok then
		return
	end
	local provider = require("gleb.ai.pi_provider")
	nn.setup({
		provider = provider,
		model = provider.MODEL,
		completion = { source = "native" },
	})
	require("gleb.ai.entry_keymaps").setup(nn)
end

return M
