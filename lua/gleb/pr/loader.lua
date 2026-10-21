-- File reads and writes are pull-request entry points (thread peeks, write-triggered fetches), so load the deferred
-- implementation on the first one; its own BufWinEnter and BufWritePost handlers then see that buffer's events.

local group = vim.api.nvim_create_augroup("gleb_pr_loader", { clear = true })

local function load_pull_requests()
	vim.api.nvim_del_augroup_by_id(group)
	require("gleb.pr")
end

vim.api.nvim_create_autocmd(
	{ "BufReadPre", "BufNewFile", "BufWritePre" },
	{ group = group, callback = load_pull_requests }
)
