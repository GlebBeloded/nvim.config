require("gitlinker").setup({
	mappings = nil,
	print_url = false,
	callbacks = {
		["pgw.dev"] = require("gitlinker.hosts").get_github_type_url,
	},
})

vim.api.nvim_create_user_command("Gitlink", function(t)
	local mode = t.range > 0 and "v" or "n"
	local cursor
	if t.range > 0 then
		cursor = vim.api.nvim_win_get_cursor(0)
		vim.api.nvim_win_set_cursor(0, { t.line1, 0 })
		vim.cmd("normal! V")
		vim.api.nvim_win_set_cursor(0, { t.line2, 0 })
	end

	require("gitlinker").get_buf_range_url(mode, { action_callback = require("gitlinker.actions").copy_to_clipboard })
	if cursor then
		vim.cmd("normal! \27")
		vim.api.nvim_win_set_cursor(0, cursor)
	end
end, { range = true })
