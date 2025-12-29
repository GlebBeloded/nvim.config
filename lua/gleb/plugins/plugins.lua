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
			"Kaiser-Yang/blink-cmp-avante", -- avante.nvim @ mentions/commands
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
				default = { "lazydev", "lsp", "path", "snippets", "buffer", "avante" },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100, -- boost priority for Neovim Lua API completions
					},
					avante = {
						module = "blink-cmp-avante",
						name = "Avante", -- enables @mentions and /commands in avante.nvim
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

	-- lsp stuff
	"neovim/nvim-lspconfig", -- Enable LSP
	"williamboman/mason.nvim", -- Manage linters, LSP, formatters
	"nvimtools/none-ls.nvim", -- Formatters and linters for LSP
	"lukas-reineke/lsp-format.nvim", -- Format code on save
	"kosayoda/nvim-lightbulb", -- Show lightbulb for code actions
	"ray-x/lsp_signature.nvim", -- Fancy function completion plugin

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
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false, -- Never set this value to "*"! Never!
		opts = {
			-- add any opts here
			provider = "copilot",
			providers = {},
		},
		-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
		build = "make BUILD_FROM_SOURCE=true",
		-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			{
				"stevearc/dressing.nvim",
				opts = {
					input = {
						relative = "editor", -- center in editor, not current window
						prefer_width = 60,
						min_width = 40,
					},
				},
			},
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			--- The below dependencies are optional,
			"echasnovski/mini.pick", -- for file_selector provider mini.pick
			"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
			-- blink.cmp is used for autocompletion (configured separately)
			"ibhagwan/fzf-lua", -- for file_selector provider fzf
			"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
			{
				-- support for image pasting
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					-- recommended settings
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- required for Windows users
						use_absolute_path = true,
					},
				},
			},
			{
				-- Make sure to set this up properly if you have lazy=true
				"MeanderingProgrammer/render-markdown.nvim",
				opts = {
					file_types = { "markdown", "Avante" },
				},
				ft = { "markdown", "Avante" },
			},
			-- AI Code Completion: copilot.lua (GitHub Copilot integration)
			-- Docs: https://github.com/zbirenbaum/copilot.lua
			--
			-- How it integrates with blink.cmp:
			--   1. Copilot shows ghost text suggestions when you pause typing
			--   2. When blink.cmp menu opens, Copilot hides (via BlinkCmpMenuOpen autocmd)
			--   3. When blink.cmp menu closes, Copilot can show again
			--   4. Tab accepts Copilot when no completion menu is visible (see blink.cmp keymap)
			--
			-- Keybinds:
			--   Tab      = Accept suggestion (when no completion menu)
			--   M-]      = Next suggestion
			--   M-[      = Previous suggestion
			--   C-]      = Dismiss suggestion
			---@type LazyPluginSpec
			{
				"GlebBeloded/copilot.lua",
				branch = "feat/syntax-highlighted-suggestions",
				cmd = "Copilot",
				event = "InsertEnter",
				config = function()
					require("copilot").setup({
						suggestion = {
							auto_trigger = true, -- show suggestions automatically
							keymap = {
								-- Accept is handled by Tab in blink.cmp (see keymap above)
								accept = false,
								next = "<M-]>",
								prev = "<M-[>",
								dismiss = "<C-]>",
							},
						},
					})

					-- Autocmds to hide Copilot when blink.cmp menu is open
					-- This prevents both showing suggestions at the same time
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
		},
	},
}

return plugins
