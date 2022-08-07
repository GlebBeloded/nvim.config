local fn = vim.fn

local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system {
    "git",
    "clone",
    "--depth",
    "1", "https://github.com/wbthomason/packer.nvim", install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

-- Install your plugins here
return packer.startup(function(use)
  -- My plugins here
  use "wbthomason/packer.nvim" -- Have packer manage itself
  use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
  use "nvim-lua/plenary.nvim" -- Useful lua functions used ny lots of plugins
  use "MunifTanjim/nui.nvim" -- ui library for other plugins
	use "lewis6991/impatient.nvim" -- load plugins faster
  use "folke/lua-dev.nvim" -- autocomplete for nvim development
  use "antoinemadec/FixCursorHold.nvim" -- fix hold cursor bugs
  use "nathom/filetype.nvim" -- allows to override file type

  -- colorschemes
  use 'folke/tokyonight.nvim'

  -- cmp plugins
  use "hrsh7th/nvim-cmp" -- The completion plugin
  use "hrsh7th/cmp-buffer" -- buffer completions
  use "hrsh7th/cmp-path" -- path completions
  use "hrsh7th/cmp-cmdline" -- cmdline completions
  use "saadparwaiz1/cmp_luasnip" -- snippet completions
  use "hrsh7th/cmp-nvim-lsp" -- enables lsp in cmp
  use "hrsh7th/cmp-nvim-lua" -- adds autocomplete for nvim lua api

  -- lsp stuff
  use "neovim/nvim-lspconfig" -- enable LSP
  use "williamboman/mason.nvim" -- stuff for managins linters, lsp, formatters, example: MasonInstall golint, :Mason will show all installed linetrs and lsps
  use "williamboman/mason-lspconfig.nvim" -- bridge between lspconfig and mason
  use "jose-elias-alvarez/null-ls.nvim" -- formatters and linters for lsp
  use "lukas-reineke/lsp-format.nvim" -- format code on save
  use "https://git.sr.ht/~whynothugo/lsp_lines.nvim" -- pretty diagnostics rendering
  use "kosayoda/nvim-lightbulb" -- show lightbulb for code actions

  -- snippets
  use "L3MON4D3/LuaSnip" --snippet engine

  -- telescope (finder ui)
  use "nvim-telescope/telescope.nvim"
	use "ahmedkhalf/project.nvim"
	use("folke/which-key.nvim")

  -- file explorer
  use "kyazdani42/nvim-web-devicons"
  use "kyazdani42/nvim-tree.lua"

  -- bufer line (bottom line)
	use "nvim-lualine/lualine.nvim"

  -- treesitter (rich syntax highlighting)
  use { "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" }

  -- git
  use "lewis6991/gitsigns.nvim"

  -- miscalenious stuff
  use "windwp/nvim-autopairs" -- autocomplete braces pairs
  use "numToStr/Comment.nvim" -- smart comments
  use "JoosepAlviste/nvim-ts-context-commentstring" -- even smarter comments for files with multiple languages in them (like react)
	use "lukas-reineke/indent-blankline.nvim" -- lines for indenting
	use "goolord/alpha-nvim" -- greeting screen

  -- file tabs 
  use "akinsho/bufferline.nvim"
  use "moll/vim-bbye"

  -- terminal stuff
  use "akinsho/toggleterm.nvim" -- togglable terminal (like in IDE)

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
