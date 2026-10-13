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

---@param event vim.api.keyset.create_autocmd.callback_args
local function reload_plugins(event)
	vim.cmd.source(event.file)
	vim.cmd("Lazy sync")
end

-- Reloads neovim whenever you save the plugins.lua file
vim.api.nvim_create_autocmd("BufWritePost", {
	group = vim.api.nvim_create_augroup("gleb_plugins_reload", { clear = true }),
	pattern = "plugins.lua",
	callback = reload_plugins,
})

-- Use a protected call so we don't error out on first use
local status_ok, lazy = pcall(require, "lazy")
if not status_ok then
	return
end

local config = {
	spec = { require("gleb.plugins.plugins") },
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "gruvbox-material" } },
	-- automatically check for plugin updates
	checker = { enabled = false },
	-- no plugin needs luarocks (else :checkhealth lazy wants hererocks)
	rocks = { enabled = false },
}

-- Setup lazy.nvim
lazy.setup(config)
