-- Install your plugins here
local plugins = {
	-- utility plugins
	"nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
	"nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
	"MunifTanjim/nui.nvim", -- UI library for other plugins
	"ray-x/guihua.lua", -- UI library
	"lewis6991/impatient.nvim", -- Load plugins faster
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
		priorty = 1000, -- make sure to load this before all the other start plugins
	},
	"NvChad/nvim-colorizer.lua",
	{
		"xiyaowong/transparent.nvim",
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
	--   4. Copilot shows ghost text only when completion menu is hidden (see copilot.lua autocmds)
	--
	-- Keybinds:
	--   Tab / Down = Select next completion (Tab also accepts Copilot if no menu)
	--   S-Tab / Up = Select previous completion
	--   Enter      = Accept selected completion
	--   C-Space    = Manually trigger completion menu
	--   C-e        = Close menu
	--   C-b / C-f  = Scroll documentation
	---@type LazyPluginSpec
	{
		"saghen/blink.cmp",
		version = "*",
		dependencies = {
			"rafamadriz/friendly-snippets", -- snippet collection
		},
		opts = {
			-- Custom keymap: Tab is "super key" for both completions and Copilot
			keymap = {
				preset = "none", -- disable defaults, define our own
				["<C-Space>"] = { "show" },
				["<Tab>"] = {
					-- Priority: completion menu > copilot > normal tab
					function(cmp)
						if cmp.is_visible() then
							return cmp.select_next()
						elseif require("copilot.suggestion").is_visible() then
							require("copilot.suggestion").accept()
							return true -- handled, don't fallback
						end
						-- return nil = fallback to normal tab (indent)
					end,
					"fallback",
				},
				["<S-Tab>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
				["<Up>"] = { "select_prev", "fallback" },
				["<CR>"] = { "accept", "fallback" },
				["<C-e>"] = { "cancel", "fallback" },
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
			},

			appearance = {
				nerd_font_variant = "mono", -- "mono" for Nerd Font Mono, "normal" otherwise
			},

			-- Rust-based fuzzy matcher for speed (falls back to Lua if unavailable)
			fuzzy = { implementation = "prefer_rust_with_warning" },

			-- Completion sources in priority order (first = highest priority)
			sources = {
				default = { "lazydev", "lsp", "path", "snippets", "buffer" },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100, -- boost priority for Neovim Lua API completions
					},
				},
			},

			completion = {
				-- Auto-insert brackets for functions/methods
				accept = { auto_brackets = { enabled = true } },

				-- Disabled: Copilot provides ghost text instead
				ghost_text = { enabled = false },

				-- Show docs automatically when item selected
				documentation = { auto_show = true },

				trigger = {
					-- Don't auto-show on ".", ":", etc. - only on keywords
					-- Use C-Space to manually trigger after special chars
					show_on_trigger_character = false,
				},

				menu = {
					draw = {
						-- Menu columns: [icon] [label + description]
						columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
					},
				},
			},

			-- Show function signature help while typing arguments
			signature = { enabled = true },

			-- Command-line completion (:, /, ?)
			cmdline = {
				keymap = {
					preset = "none",
					["<Tab>"] = { "show", "select_next", "fallback" },
					["<S-Tab>"] = { "show", "select_prev", "fallback" },
					["<Down>"] = { "select_next", "fallback" },
					["<Up>"] = { "select_prev", "fallback" },
					["<CR>"] = { "accept", "fallback" },
					["<C-e>"] = { "cancel", "fallback" },
				},
			},
		},
		opts_extend = { "sources.default" }, -- allow other plugins to extend sources
	},

	-- yaml schema detection (kubernetes, etc.)
	"mosheavni/yaml-companion.nvim",

	-- lsp stuff
	"neovim/nvim-lspconfig", -- Enable LSP
	"williamboman/mason.nvim", -- Manage linters, LSP, formatters
	"nvimtools/none-ls.nvim", -- Formatters and linters for LSP
	"lukas-reineke/lsp-format.nvim", -- Format code on save
	"kosayoda/nvim-lightbulb", -- Show lightbulb for code actions
	"ray-x/lsp_signature.nvim", -- Fancy function completion plugin
	"yioneko/nvim-vtsls", -- vtsls commands (organize imports, rename file, etc.)
	{
		"dmmulroy/tsc.nvim", -- Project-wide TypeScript type checking
		cmd = "TSC",
		opts = {},
	},

	-- folding
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async", -- Better folding
	},
	"lewis6991/foldsigns.nvim", -- Show LSP signs on folds

	-- debugging plugins
	"mfussenegger/nvim-dap",
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" }, -- UI (splits) for DAP
	},
	"leoluz/nvim-dap-go",

	-- testing
	{
		"nvim-neotest/neotest",
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
	"L3MON4D3/LuaSnip", -- Snippet engine

	-- telescope (finder UI)
	"nvim-telescope/telescope.nvim",
	"ahmedkhalf/project.nvim",

	-- file explorer
	"nvim-tree/nvim-web-devicons",
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
	},

	-- buffer line (bottom line)
	"nvim-lualine/lualine.nvim",

	-- treesitter (rich syntax highlighting)
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main", -- required for neotest-golang v2+
		build = ":TSUpdate",
	},
	-- playground removed: use :InspectTree (built-in Neovim 0.10+)
	-- textobjects removed: incompatible with treesitter main branch

	-- git
	"lewis6991/gitsigns.nvim",
	{
		"echasnovski/mini.diff",
		version = false,
		config = function()
			require("mini.diff").setup({})
		end,
	},
	{
		"sindrets/diffview.nvim",
		dependencies = "nvim-lua/plenary.nvim",
	},
	{
		"esmuellert/vscode-diff.nvim",
		dependencies = { "MunifTanjim/nui.nvim" },
		config = function()
			require("gleb.git.vscode_diff")
		end,
	},
	{
		"ruifm/gitlinker.nvim", -- Generate links to code
		dependencies = "nvim-lua/plenary.nvim",
	},

	-- session recovery: named, zellij-aware sessions (see lua/gleb/session)
	"stevearc/resession.nvim",

	-- unsaved-buffer safety: auto-save so resession never loses live edits
	-- (resession only restores file paths/layout, not unwritten content)
	{
		"okuuva/auto-save.nvim",
		version = "^1",
		config = function()
			require("auto-save").setup({
				-- only touch real, normal files — never terminals, prompts, etc.
				condition = function(buf)
					return vim.bo[buf].buftype == ""
						and not vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[buf].filetype)
				end,
				debounce_delay = 1000, -- wait out bursts of typing before writing
			})
		end,
	},

	-- comments
	"numToStr/Comment.nvim", -- Smart comments

	-- smart splits for seamless navigation between nvim and zellij
	-- Works with vim-zellij-navigator Zellij plugin
	{
		"mrjones2014/smart-splits.nvim",
		lazy = false,
		config = function()
			require("smart-splits").setup({
				ignored_filetypes = { "nofile", "quickfix", "qf", "prompt" },
				ignored_buftypes = { "nofile" },
				-- Ensure multiplexer detection is enabled
				at_edge = "stop", -- don't wrap at edges
			})
		end,
	},

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

	-- AI: ThePrimeagen/99 — search, visual, vibe, worker via Claude Code
	{
		"ThePrimeagen/99",
		event = "VeryLazy",
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			local nn = require("99")
			nn.setup({
				provider = nn.Providers.ClaudeCodeProvider,
				model = "claude-sonnet-4-5",
			})

			local function normal_menu()
				vim.api.nvim_echo({ { "99> [s]earch [v]ibe: ", "Question" } }, false, {})
				local key = vim.fn.nr2char(vim.fn.getchar())
				vim.cmd("redraw")
				local fns = { s = nn.search, v = nn.vibe }
				if fns[key] then
					fns[key]()
				end
			end

			vim.keymap.set("n", "<A-9>", normal_menu, { desc = "99: Menu" })
			vim.keymap.set("v", "<A-9>", nn.visual, { desc = "99: Visual" })
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
		version = "^6",
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
			require("copilot").setup({
				suggestion = {
					auto_trigger = true,
					keymap = {
						accept = false,
						next = "<M-]>",
						prev = "<M-[>",
						dismiss = "<C-]>",
					},
				},
			})

			vim.api.nvim_create_autocmd("User", {
				pattern = "BlinkCmpMenuOpen",
				callback = function()
					require("copilot.suggestion").dismiss()
					vim.b.copilot_suggestion_hidden = true
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				pattern = "BlinkCmpMenuClose",
				callback = function()
					vim.b.copilot_suggestion_hidden = false
				end,
			})
		end,
	},
}

return plugins
