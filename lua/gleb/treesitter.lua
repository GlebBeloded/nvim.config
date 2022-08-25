local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
	return
end

configs.setup({
	ensure_installed = "all", -- one of "all" or a list of languages
	ignore_install = { "phpdoc" }, -- List of parsers to ignore installing
	highlight = {
		enable = true, -- false will disable the whole extension
		disable = {}, -- list of language that will be disabled
		additional_vim_regex_highlighting = false, -- disable vim built-in highlighting
	},
	autopairs = {
		enable = true,
	},
	indent = { enable = true, disable = {} },
	playground = {
		enable = true,
	},
})

vim.cmd([[ set foldlevel=20 ]])
vim.cmd([[ set foldmethod=expr ]])
vim.cmd([[ set foldexpr=nvim_treesitter#foldexpr() ]])
