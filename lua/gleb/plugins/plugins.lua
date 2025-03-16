-- Install your plugins here
local plugins = {
	-- utility plugins
	"nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
	"nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
	"MunifTanjim/nui.nvim", -- UI library for other plugins
	"ray-x/guihua.lua", -- UI library
	"lewis6991/impatient.nvim", -- Load plugins faster
	"folke/neodev.nvim", -- Autocomplete for nvim development

	-- colors
	-- "folke/tokyonight.nvim", -- disabled because of nvim-tree transparency bug
	{
		"sainnhe/gruvbox-material",
		priorty = 1000, -- make sure to load this before all the other start plugins
	},
	"NvChad/nvim-colorizer.lua",

	-- cmp plugins
	"hrsh7th/nvim-cmp", -- The completion plugin
	"hrsh7th/cmp-buffer", -- Buffer completions
	"hrsh7th/cmp-path", -- Path completions
	"saadparwaiz1/cmp_luasnip", -- Snippet completions
	"hrsh7th/cmp-nvim-lsp", -- Enables LSP in cmp
	"hrsh7th/cmp-nvim-lua", -- Adds autocomplete for nvim lua API

	-- lsp stuff
	"neovim/nvim-lspconfig", -- Enable LSP
	"williamboman/mason.nvim", -- Manage linters, LSP, formatters
	"jose-elias-alvarez/null-ls.nvim", -- Formatters and linters for LSP
	"lukas-reineke/lsp-format.nvim", -- Format code on save
	"kosayoda/nvim-lightbulb", -- Show lightbulb for code actions
	"ray-x/lsp_signature.nvim", -- Fancy function completion plugin

	-- folding
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async", -- Better folding
	},
	"lewis6991/foldsigns.nvim", -- Show LSP signs on folds

	-- copilot
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({ suggestion = { auto_trigger = true } })
		end,
	},

	-- debugging plugins
	"mfussenegger/nvim-dap",
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" }, -- UI (splits) for DAP
	},
	"leoluz/nvim-dap-go",

	-- snippets
	"L3MON4D3/LuaSnip", -- Snippet engine

	-- telescope (finder UI)
	"nvim-telescope/telescope.nvim",
	"ahmedkhalf/project.nvim",

	-- file explorer
	"kyazdani42/nvim-web-devicons",
	"kyazdani42/nvim-tree.lua",

	-- buffer line (bottom line)
	"nvim-lualine/lualine.nvim",

	-- treesitter (rich syntax highlighting)
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
	},
	"nvim-treesitter/playground",
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		dependencies = "nvim-treesitter/nvim-treesitter",
	},

	-- git
	"lewis6991/gitsigns.nvim",
	{
		"sindrets/diffview.nvim",
		dependencies = "nvim-lua/plenary.nvim",
	},
	{
		"ruifm/gitlinker.nvim", -- Generate links to code
		dependencies = "nvim-lua/plenary.nvim",
	},

	-- comments
	"numToStr/Comment.nvim", -- Smart comments

	-- miscellaneous stuff
	"windwp/nvim-autopairs", -- Autocomplete brace pairs
	{
		"kylechui/nvim-surround",
		version = "*", -- Use for stability; omit to use the main branch for the latest features
		config = function()
			require("nvim-surround").setup({})
		end,
	},
	"windwp/nvim-ts-autotag", -- Autoclose HTML tags
	"JoosepAlviste/nvim-ts-context-commentstring", -- Smarter comments for files with multiple languages
	"lukas-reineke/indent-blankline.nvim", -- Lines for indenting
	"goolord/alpha-nvim", -- Greeting screen

	-- file tabs
	"akinsho/bufferline.nvim",
	"moll/vim-bbye",

	-- leetcode
	{
		"kawre/leetcode.nvim",
		build = ":TSUpdate html",
		dependencies = {
			"nvim-telescope/telescope.nvim",
			"nvim-lua/plenary.nvim", -- required by telescope
			"MunifTanjim/nui.nvim",

			-- optional
			"nvim-treesitter/nvim-treesitter",
			-- "rcarriga/nvim-notify",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			lang = "golang",
			injector = {
				["golang"] = {
					before = "package leet",
				},
			},
		},
	},
}

return plugins
