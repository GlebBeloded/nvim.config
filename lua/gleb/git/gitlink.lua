local has_gitlinker, gitlinker = pcall(require, "gitlinker")
local has_hosts, hosts = pcall(require, "gitlinker.hosts")
if not (has_gitlinker and has_hosts) then
	return
end

gitlinker.setup({
	mappings = nil,
	print_url = false,
	callbacks = {
		["pgw.dev"] = hosts.get_github_type_url,
	},
})

vim.api.nvim_create_user_command("Gitlink", function(t)
	local mode = t.range > 0 and "v" or "n"
	local cursor
	local visual_start
	local visual_end
	if t.range > 0 then
		cursor = vim.api.nvim_win_get_cursor(0)
		visual_start = vim.api.nvim_buf_get_mark(0, "<")
		visual_end = vim.api.nvim_buf_get_mark(0, ">")
		vim.api.nvim_win_set_cursor(0, { t.line1, 0 })
		vim.cmd("normal! V")
		vim.api.nvim_win_set_cursor(0, { t.line2, 0 })
	end

	local ok, err = pcall(
		require("gitlinker").get_buf_range_url,
		mode,
		{ action_callback = require("gitlinker.actions").copy_to_clipboard }
	)
	if cursor then
		vim.cmd("normal! \27")
		vim.api.nvim_win_set_cursor(0, cursor)
		vim.api.nvim_buf_set_mark(0, "<", visual_start[1], visual_start[2], {})
		vim.api.nvim_buf_set_mark(0, ">", visual_end[1], visual_end[2], {})
	end
	if not ok then
		error(err, 0)
	end
end, { range = true })
