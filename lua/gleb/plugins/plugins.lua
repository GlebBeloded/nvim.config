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

    -- cmp plugins
    "hrsh7th/nvim-cmp", -- The completion plugin
    "hrsh7th/cmp-buffer", -- Buffer completions
    "hrsh7th/cmp-path", -- Path completions
    "saadparwaiz1/cmp_luasnip", -- Snippet completions
    "hrsh7th/cmp-nvim-lsp", -- Enables LSP in cmp

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

    -- snippets
    "L3MON4D3/LuaSnip", -- Snippet engine

    -- telescope (finder UI)
    "nvim-telescope/telescope.nvim",
    "ahmedkhalf/project.nvim",

    -- file explorer
    "nvim-tree/nvim-web-devicons",
    "nvim-tree/nvim-tree.lua",

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
        "NeogitOrg/neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = true,
    },
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
    {
        "yetone/avante.nvim",
        event = "VeryLazy",
        version = false, -- Never set this value to "*"! Never!
        opts = {
            -- add any opts here
            provider = "copilot",
            providers = {
            },
        },
        -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
        build = "make BUILD_FROM_SOURCE=true",
        -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "stevearc/dressing.nvim",
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            --- The below dependencies are optional,
            "echasnovski/mini.pick", -- for file_selector provider mini.pick
            "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
            "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
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
                'MeanderingProgrammer/render-markdown.nvim',
                opts = {
                    file_types = { "markdown", "Avante" },
                },
                ft = { "markdown", "Avante" },
            },
            {
                "zbirenbaum/copilot.lua",
                cmd = "Copilot",
                event = "InsertEnter",
                config = function()
                    require("copilot").setup({ suggestion = { auto_trigger = true } })
                end,
            },
        },
    }
}

return plugins
