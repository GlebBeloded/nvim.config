local general = vim.api.nvim_create_augroup("gleb_general", { clear = true })

---@param event vim.api.keyset.create_autocmd.callback_args
local function map_q_to_close(event)
	vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = event.buf, silent = true, desc = "Window: Close" })
end

local function highlight_yank()
	vim.hl.on_yank({ higroup = "Visual", timeout = 200 })
end

-- ftplugins add c/r/o back, so strip them whenever a buffer is shown
local function drop_comment_continuation()
	vim.opt.formatoptions:remove({ "c", "r", "o" })
end

---@param event vim.api.keyset.create_autocmd.callback_args
local function unlist_buffer(event)
	vim.bo[event.buf].buflisted = false
end

---@param event vim.api.keyset.create_autocmd.callback_args
local function set_filetype_sh(event)
	vim.bo[event.buf].filetype = "sh"
end

vim.api.nvim_create_autocmd("FileType", {
	group = general,
	pattern = { "qf", "help", "man", "lspinfo" },
	callback = map_q_to_close,
})
vim.api.nvim_create_autocmd("TextYankPost", { group = general, callback = highlight_yank })
vim.api.nvim_create_autocmd("BufWinEnter", { group = general, callback = drop_comment_continuation })
vim.api.nvim_create_autocmd("FileType", { group = general, pattern = "qf", callback = unlist_buffer })
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
	group = general,
	pattern = { "~/.zshrc", "~/.zprofile" },
	callback = set_filetype_sh,
})

local function wrap_and_spell()
	vim.opt_local.wrap = true
	vim.opt_local.spell = true
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("gleb_git_commit", { clear = true }),
	pattern = "gitcommit",
	callback = wrap_and_spell,
})
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("gleb_markdown", { clear = true }),
	pattern = "markdown",
	callback = wrap_and_spell,
})

local function equalize_windows()
	vim.cmd("tabdo wincmd =")
end

vim.api.nvim_create_autocmd("VimResized", {
	group = vim.api.nvim_create_augroup("gleb_auto_resize", { clear = true }),
	callback = equalize_windows,
})

local alpha = vim.api.nvim_create_augroup("gleb_alpha", { clear = true })

local function show_tabline()
	vim.o.showtabline = 2
end

-- the dashboard hides the tabline until its buffer is unloaded
local function hide_tabline_on_dashboard()
	vim.o.showtabline = 0
	vim.api.nvim_create_autocmd("BufUnload", {
		group = alpha,
		buffer = vim.api.nvim_get_current_buf(),
		once = true,
		callback = show_tabline,
	})
end

vim.api.nvim_create_autocmd("User", {
	group = alpha,
	pattern = "AlphaReady",
	callback = hide_tabline_on_dashboard,
})

local lsp_format = vim.api.nvim_create_augroup("gleb_lsp_format", { clear = true })

---@param event vim.api.keyset.create_autocmd.callback_args
local function format_on_save(event)
	if vim.g.format_on_save_disabled then
		return
	end
	local clients = vim.lsp.get_clients({ bufnr = event.buf, method = "textDocument/formatting" })
	if #clients > 0 then
		vim.lsp.buf.format({ bufnr = event.buf })
	end
end

vim.api.nvim_create_autocmd("BufWritePre", {
	group = lsp_format,
	callback = format_on_save,
})

-- Format only on a manual :w, never on auto-save.nvim writes. auto-save runs
-- with autocmds enabled, so it would otherwise reformat mid-edit; flag its
-- write cycle so the BufWritePre format above skips it.
local autosave_format = vim.api.nvim_create_augroup("gleb_autosave_format", { clear = true })
vim.api.nvim_create_autocmd("User", {
	group = autosave_format,
	pattern = "AutoSaveWritePre",
	callback = function()
		vim.g.format_on_save_disabled = true
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = autosave_format,
	pattern = "AutoSaveWritePost",
	callback = function()
		vim.g.format_on_save_disabled = false
	end,
})

vim.cmd([[ command! Format execute 'lua vim.lsp.buf.format{async=true}' ]])

vim.cmd([[ command! Pwd execute ':cd %:p:h' ]])

local search_hlsearch = vim.api.nvim_create_augroup("gleb_search_hlsearch", { clear = true })
vim.api.nvim_create_autocmd("CmdlineEnter", {
	group = search_hlsearch,
	callback = function()
		if vim.v.event.cmdtype == "/" or vim.v.event.cmdtype == "?" then
			vim.opt.hlsearch = true
		end
	end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
	group = search_hlsearch,
	callback = function()
		if vim.v.event.cmdtype == "/" or vim.v.event.cmdtype == "?" then
			vim.opt.hlsearch = false
		end
	end,
})
