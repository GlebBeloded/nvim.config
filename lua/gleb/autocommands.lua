vim.cmd([[
  augroup _general_settings
    autocmd!
    autocmd FileType qf,help,man,lspinfo nnoremap <silent> <buffer> q :close<CR>
    autocmd TextYankPost * silent!lua vim.hl.on_yank({higroup = 'Visual', timeout = 200})
    autocmd BufWinEnter * :set formatoptions-=cro
    autocmd FileType qf set nobuflisted
    autocmd BufNewFile,BufRead ~/.zshrc :setl ft=sh
    autocmd BufNewFile,BufRead ~/.zprofile :setl ft=sh
  augroup end

  augroup _git
    autocmd!
    autocmd FileType gitcommit setlocal wrap
    autocmd FileType gitcommit setlocal spell
  augroup end

  augroup _markdown
    autocmd!
    autocmd FileType markdown setlocal wrap
    autocmd FileType markdown setlocal spell
  augroup end

  augroup _auto_resize
    autocmd!
    autocmd VimResized * tabdo wincmd =
  augroup end

  augroup _alpha
    autocmd!
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
  augroup end

]])

local lsp_format = vim.api.nvim_create_augroup("_lsp", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
	group = lsp_format,
	callback = function()
		if not vim.g.format_on_save_disabled then
			vim.lsp.buf.format({})
		end
	end,
})

-- Format only on a manual :w, never on auto-save.nvim writes. auto-save runs
-- with autocmds enabled, so it would otherwise reformat mid-edit; flag its
-- write cycle so the BufWritePre format above skips it.
local autosave_format = vim.api.nvim_create_augroup("_autosave_format", { clear = true })
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

-- TODO: move to separate files
vim.cmd([[ command! Format execute 'lua vim.lsp.buf.format{async=true}' ]])

vim.cmd([[ command! Pwd execute ':cd %:p:h' ]])

-- TODO: move to separate search file
vim.api.nvim_create_autocmd("CmdlineEnter", {
	callback = function()
		if vim.v.event.cmdtype == "/" or vim.v.event.cmdtype == "?" then
			vim.opt.hlsearch = true
		end
	end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
	callback = function()
		if vim.v.event.cmdtype == "/" or vim.v.event.cmdtype == "?" then
			vim.opt.hlsearch = false
		end
	end,
})
