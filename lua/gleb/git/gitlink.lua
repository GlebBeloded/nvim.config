require("gitlinker").setup({
	mappings = nil,
	print_url = false,
	callbacks = {
		["pgw.dev"] = require("gitlinker.hosts").get_github_type_url,
	},
})

vim.api.nvim_create_user_command("Gitlink", function(t)
	local mode = t.range > 0 and "v" or "n"
	if t.range > 0 then
		vim.api.nvim_win_set_cursor(0, { t.line1, 0 })
		vim.cmd("normal! V")
		vim.api.nvim_win_set_cursor(0, { t.line2, 0 })
	end

	require("gitlinker").get_buf_range_url(mode, { action_callback = require("gitlinker.actions").copy_to_clipboard })
end, { range = true })
