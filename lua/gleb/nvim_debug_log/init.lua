vim.fn.mkdir("/tmp/nvim", "p")

local path = string.format("/tmp/nvim/%d_%d.txt", os.time(), vim.fn.getpid())
local flush_interval_ms = 2000

vim.cmd("redir >> " .. path)

local function flush()
	vim.cmd("redir END")
	vim.cmd("redir >> " .. path)
end

local timer = vim.fn.timer_start(flush_interval_ms, function()
	flush()
end, { ["repeat"] = -1 })

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		vim.fn.timer_stop(timer)
		vim.cmd("redir END")
	end,
})
