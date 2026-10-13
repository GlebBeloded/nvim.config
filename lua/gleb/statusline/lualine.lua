local status_ok, lualine = pcall(require, "lualine")
if not status_ok then
	return
end

local hide_in_width = function()
	return vim.fn.winwidth(0) > 80
end

local diagnostics = {
	"diagnostics",
	sources = { "nvim_diagnostic" },
	sections = { "error", "warn" },
	symbols = { error = " ", warn = " " },
	colored = true,
	update_in_insert = false,
	always_visible = true,
}

local diff = {
	"diff",
	colored = false,
	symbols = { added = " ", modified = " ", removed = " " }, -- changes diff symbols
	cond = hide_in_width,
}

local mode = {
	"mode",
}

local branch = {
	"branch",
	icons_enabled = true,
	icon = "",
}

-- self-contained block: "<status dot> <language logo> <language>", e.g. "●  lua"
-- (dot green/red by LSP health). Owns its own background; see the module.
local lsp_status = {
	require("gleb.statusline.language").component,
	padding = 0,
	separator = { left = "", right = "" },
}

-- code context breadcrumb (e.g. "Server ▸ Handle ▸ if") from the LSP, shown on the left
local navic = {
	function()
		return require("nvim-navic").get_location()
	end,
	cond = function()
		local ok, mod = pcall(require, "nvim-navic")
		return ok and mod.is_available()
	end,
}

-- LSP progress: spinner + readable label, only for tasks running > 500ms (see module)
local lsp_progress = require("gleb.statusline.lsp_progress").progress

-- Copilot: red glyph only when Copilot is NOT working, hidden otherwise
local copilot = {
	require("gleb.statusline.copilot").component,
	color = { fg = require("gleb.statusline.palette").err },
}

lualine.setup({
	options = {
		icons_enabled = true,
		theme = require("gleb.statusline.theme"),
		component_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		disabled_filetypes = { "alpha", "dashboard", "Outline" },
		always_divide_middle = true,
	},
	sections = {
		lualine_a = { mode },
		lualine_b = { branch, diff },
		lualine_c = { navic },
		lualine_x = { lsp_progress, copilot, diagnostics, lsp_status },
		lualine_y = {},
		lualine_z = {},
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { "filename" },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
	tabline = {},
	extensions = {},
})

-- make bufferline global (same bufferline for all windows)
-- must be after lualine setup
vim.opt.laststatus = 3
