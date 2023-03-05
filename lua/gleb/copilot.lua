local function suggest()
	require("copilot.panel").open({ position = "right", ratio = 0.3 })
end

vim.api.nvim_create_user_command("CC", suggest, {})
