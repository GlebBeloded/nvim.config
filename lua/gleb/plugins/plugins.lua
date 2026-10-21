--- Only touch real, named files — never terminals, prompts, unnamed buffers, etc.
---@param buf integer
---@return boolean
local function should_autosave(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return name ~= ""
		and vim.uv.fs_stat(name) ~= nil
		and vim.bo[buf].buftype == ""
		and not vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[buf].filetype)
end

-- Install your plugins here
local plugins = {
	-- utility plugins
	"nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
	"nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
	"MunifTanjim/nui.nvim", -- UI library for other plugins
	"ray-x/guihua.lua", -- UI library
	{
		"folke/lazydev.nvim",
		ft = "lua", -- only load on lua files
		opts = {
			library = {
				-- Load luvit types when the `vim.uv` word is found
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},

	-- colors
	-- "folke/tokyonight.nvim", -- disabled because of nvim-tree transparency bug
	{
		"sainnhe/gruvbox-material",
		priority = 1000, -- make sure to load this before all the other start plugins
	},
	{
		"NvChad/nvim-colorizer.lua",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gleb.colors.colorizer")
		end,
	},
	{
		"xiyaowong/transparent.nvim",
		event = "VeryLazy",
		config = function()
			require("gleb.colors.transparency")
		end,
	},

	-- Completion: blink.cmp (modern, fast alternative to nvim-cmp)
	-- Docs: https://cmp.saghen.dev
	--
	-- How it works:
	--   1. As you type, blink.cmp gathers suggestions from multiple sources (LSP, snippets, etc.)
	--   2. Fuzzy matching ranks results by relevance, allowing typos
	--   3. Menu appears after typing keywords (letters/numbers), NOT on special chars like "."
	--   4. Copilot shows ghost text only when completion menu is hidden (see lua/gleb/copilot autocmds)
	--
	-- Configured in lua/gleb/cmp (after the action registry); keys are completion actions.
	---@type LazyPluginSpec
	{
		"saghen/blink.cmp",
		version = "*",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"rafamadriz/friendly-snippets", -- snippet collection
		},
		config = function()
			require("gleb.cmp")
		end,
	},

	-- yaml schema detection (kubernetes, etc.)
	"mosheavni/yaml-companion.nvim",

	-- lsp stuff
	{
		"neovim/nvim-lspconfig", -- Enable LSP
		event = { "BufReadPre", "BufNewFile", "VeryLazy" },
		dependencies = {
			"williamboman/mason.nvim", -- Manage linters, LSP, formatters
			"nvimtools/none-ls.nvim", -- Formatters and linters for LSP
			"lukas-reineke/lsp-format.nvim", -- Format code on save
			"kosayoda/nvim-lightbulb", -- Show lightbulb for code actions
			"ray-x/lsp_signature.nvim", -- Fancy function completion plugin
			"yioneko/nvim-vtsls", -- vtsls commands (organize imports, rename file, etc.)
		},
		config = function()
			require("gleb.lsp")
		end,
	},
	{
		"dmmulroy/tsc.nvim", -- Project-wide TypeScript type checking
		cmd = "TSC",
		opts = {},
	},

	-- folding
	{
		"kevinhwang91/nvim-ufo",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = "kevinhwang91/promise-async", -- Better folding
		config = function()
			require("gleb.folding")
		end,
	},
	{ "lewis6991/foldsigns.nvim", lazy = true }, -- Show LSP signs on folds

	-- debugging plugins: load on the first :Dap* command (or require("dap"))
	{
		"mfussenegger/nvim-dap",
		cmd = {
			"DapClearBreakpoints",
			"DapContinue",
			"DapDisconnect",
			"DapEval",
			"DapNew",
			"DapPause",
			"DapRestartFrame",
			"DapSetLogLevel",
			"DapShowLog",
			"DapStepInto",
			"DapStepOut",
			"DapStepOver",
			"DapTerminate",
			"DapToggleBreakpoint",
			"DapToggleRepl",
		},
		dependencies = {
			{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } }, -- UI (splits) for DAP
			"leoluz/nvim-dap-go",
		},
		config = function()
			require("gleb.debugging")
		end,
	},

	-- testing
	{
		"nvim-neotest/neotest",
		cmd = "Neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"fredrikaverpil/neotest-golang", -- better Go adapter with testify support
		},
		config = function()
			require("gleb.testing")
		end,
	},

	-- snippets
	{ "L3MON4D3/LuaSnip", lazy = true }, -- Snippet engine

	-- picker UI
	"nvim-mini/mini.nvim", -- Shared picker UI and list sources

	-- file explorer
	"nvim-tree/nvim-web-devicons",

	-- buffer line (bottom line)
	{ "nvim-lualine/lualine.nvim", lazy = false },

	-- statusline extras
	{
		"SmiteshP/nvim-navic", -- LSP breadcrumb / code context (left of statusline)
		event = "LspAttach",
		dependencies = "neovim/nvim-lspconfig",
		opts = {
			lsp = { auto_attach = true }, -- attach to every LSP client automatically
			highlight = true,
			depth_limit = 5,
		},
	},

	-- treesitter (rich syntax highlighting)
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main", -- required for neotest-golang v2+
		build = ":TSUpdate",
		event = { "BufReadPre", "BufNewFile", "VeryLazy" },
		init = function()
			if vim.env.GLEB_TEST_SANDBOX then
				require("gleb.treesitter")
			end
		end,
		config = function()
			require("gleb.treesitter")
		end,
	},
	-- playground removed: use :InspectTree (built-in Neovim 0.10+)
	-- textobjects removed: incompatible with treesitter main branch

	-- git
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gleb.git.gitsigns")
			require("gleb.git.committed_signs").setup()
		end,
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewClose", "DiffviewFileHistory", "DiffviewFocusFiles", "DiffviewOpen", "DiffviewRefresh" },
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			require("gleb.git.diffview")
		end,
	},
	{
		"ruifm/gitlinker.nvim", -- Generate links to code
		cmd = "Gitlink",
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			require("gleb.git.gitlink")
		end,
	},

	-- session recovery: named, zellij-aware sessions (see lua/gleb/session)
	"stevearc/resession.nvim",

	-- unsaved-buffer safety: auto-save so resession never loses live edits
	-- (resession only restores file paths/layout, not unwritten content)
	{
		"okuuva/auto-save.nvim",
		version = "^1",
		event = "InsertEnter",
		config = function()
			require("auto-save").setup({
				condition = should_autosave,
				debounce_delay = 1000, -- wait out bursts of typing before writing
			})
		end,
	},

	-- smart splits for seamless navigation between nvim and zellij
	-- Works with vim-zellij-navigator Zellij plugin
	{
		"mrjones2014/smart-splits.nvim",
		lazy = false,
		config = function()
			require("gleb.smart_splits")
		end,
	},

	-- miscellaneous stuff
	{
		"windwp/nvim-autopairs", -- Autocomplete brace pairs
		event = "InsertEnter",
		config = function()
			require("gleb.autopairs")
		end,
	},
	{
		"kylechui/nvim-surround",
		version = "*", -- Use for stability; omit to use the main branch for the latest features
		event = "VeryLazy",
		init = function()
			vim.g.nvim_surround_no_mappings = true -- keys come from surround actions
		end,
		opts = {},
	},
	{
		"windwp/nvim-ts-autotag", -- Autoclose HTML tags
		ft = { "html", "javascriptreact", "typescriptreact", "vue", "svelte" },
		opts = {},
	},
	{
		"lukas-reineke/indent-blankline.nvim", -- Lines for indenting
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("gleb.indentline")
		end,
	},
	"goolord/alpha-nvim", -- Greeting screen

	-- file tabs
	{ "akinsho/bufferline.nvim", lazy = false },
	{ "moll/vim-bbye", cmd = { "Bdelete", "Bwipeout" } },

	-- AI: ThePrimeagen/99 — search, visual, vibe, worker via Pi
	{
		"ThePrimeagen/99",
		event = "VeryLazy",
		config = function()
			require("gleb.ai").setup()
		end,
	},

	-- Markdown rendering
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = { file_types = { "markdown" } },
		ft = { "markdown" },
	},

	-- Rust: rich rust-analyzer integration (runnables, debuggables, expand macro,
	-- grouped code actions, hover actions). Replaces lspconfig's rust_analyzer.
	{
		"mrcjkb/rustaceanvim",
		version = "^9",
		lazy = false, -- plugin self-lazies via ftplugin/rust
		init = function()
			vim.g.rustaceanvim = {
				server = {
					default_settings = {
						["rust-analyzer"] = {
							check = { command = "clippy" },
							cargo = { allFeatures = true },
						},
					},
				},
			}
		end,
	},

	-- Rust: Cargo.toml dependency hints, completion, upgrade actions
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		opts = {},
	},

	-- AI Code Completion: copilot.lua (GitHub Copilot integration)
	-- Keybinds: Tab=accept, M-]=next, M-[=prev, C-]=dismiss
	{
		"GlebBeloded/copilot.lua",
		branch = "feat/syntax-highlighted-suggestions",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("gleb.copilot")
		end,
	},
}

return plugins
