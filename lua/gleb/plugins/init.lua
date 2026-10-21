-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Use a protected call so we don't error out on first use
local status_ok, lazy = pcall(require, "lazy")
if not status_ok then
	return
end

--- lazy.nvim's default custom keys, off: lazy window keys come from settings/keymap.json.
---@return table<string, false>
local function disabled_custom_keys()
	local keys = {}
	for lhs in pairs(require("lazy.core.config").defaults.ui.custom_keys) do
		keys[lhs] = false
	end
	return keys
end

local config = {
	spec = { require("gleb.plugins.plugins") },
	defaults = { lazy = true },
	ui = { custom_keys = disabled_custom_keys() },
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "gruvbox-material" } },
	-- automatically check for plugin updates
	checker = { enabled = false },
	-- no plugin needs luarocks (else :checkhealth lazy wants hererocks)
	rocks = { enabled = false },
	performance = { rtp = { disabled_plugins = { "netrwPlugin" } } },
}

-- Setup lazy.nvim
lazy.setup(config)
