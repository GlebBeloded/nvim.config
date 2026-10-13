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

	require("gitlinker").get_buf_range_url(mode, { action_callback = require("gitlinker.actions").copy_to_clipboard })
end, { range = true })

-- Hello Gleb from the future, if line selection does not work, remember this:
-- you changes two lines at gitlinker/buffer.lua (18-19) to this:
-- local pos1 = vim.api.nvim_buf_get_mark(0, "<")[1]
-- local pos2 = vim.api.nvim_buf_get_mark(0, ">")[1]
