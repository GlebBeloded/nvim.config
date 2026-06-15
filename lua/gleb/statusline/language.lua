-- Statusline LSP/language block, rendered on its own background so it reads as a
-- distinct chip. Contents: a health dot (green = an LSP is attached & running,
-- red = none), the language logo (Nerd Font glyph in its brand color), and the
-- language name. Pick the layout with STYLE below.
local M = {}

local devicons = require("nvim-web-devicons")
local c = require("gleb.statusline.palette")

-- ── appearance ──────────────────────────────────────────────────────────────
-- STYLE = chip body. Health is shown by the LEFT cap color (green/red), so the
-- body usually omits the dot. Options: logo_name | dot_logo_name | dot_logo |
-- dot_name | logo_dot_name | dot
local STYLE = "logo_name"
local BLOCK_BG = c.chip_bg -- warm-tinted statusline grey
local TEXT_FG = c.text_hi -- language name + padding
local OK_FG = c.ok -- green: LSP healthy
local ERR_FG = c.err -- red: LSP broken

local logo_defined = {}

-- rounded end-caps: half-circle glyphs drawn in the block color on a
-- transparent background, so the chip reads as a rounded pill
local CAP_LEFT = ""
local CAP_RIGHT = ""

local function define_highlights()
	vim.api.nvim_set_hl(0, "StatuslineLangText", { fg = TEXT_FG, bg = BLOCK_BG })
	vim.api.nvim_set_hl(0, "StatuslineLspOk", { fg = OK_FG, bg = BLOCK_BG })
	vim.api.nvim_set_hl(0, "StatuslineLspError", { fg = ERR_FG, bg = BLOCK_BG })
	vim.api.nvim_set_hl(0, "StatuslineLangEdge", { fg = BLOCK_BG }) -- neutral cap, transparent bg
	vim.api.nvim_set_hl(0, "StatuslineLangCapOk", { fg = OK_FG }) -- left cap when LSP healthy
	vim.api.nvim_set_hl(0, "StatuslineLangCapError", { fg = ERR_FG }) -- left cap when broken
end

define_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		logo_defined = {}
		define_highlights()
	end,
})

-- ── pieces ──────────────────────────────────────────────────────────────────
local function hl(group, text)
	return "%#" .. group .. "#" .. text
end

local function has_running_client()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	local running = vim.tbl_filter(function(client)
		return not client:is_stopped()
	end, clients)
	return not vim.tbl_isempty(running)
end

local function dot()
	return hl(has_running_client() and "StatuslineLspOk" or "StatuslineLspError", "●")
end

local function logo(filetype)
	local glyph, color = devicons.get_icon_color_by_filetype(filetype, { default = true })
	if not glyph then
		return ""
	end
	local group = "StatuslineLang_" .. filetype
	if not logo_defined[filetype] then
		vim.api.nvim_set_hl(0, group, { fg = color, bg = BLOCK_BG })
		logo_defined[filetype] = true
	end
	return hl(group, glyph)
end

-- ── assembly ─────────────────────────────────────────────────────────────────
local function pieces_for(filetype)
	local d, l = dot(), logo(filetype)
	return {
		dot_logo_name = { d, l, filetype },
		dot_logo = { d, l },
		dot_name = { d, filetype },
		logo_name = { l, filetype },
		dot = { d },
		logo_dot_name = { l, d, filetype },
	}
end

function M.component()
	local filetype = vim.bo.filetype
	if filetype == "" then
		return ""
	end

	local parts = pieces_for(filetype)[STYLE]
	local sep = hl("StatuslineLangText", " ") -- a space on the block background
	local body = sep .. table.concat(parts, sep) .. sep
	local left_cap = has_running_client() and "StatuslineLangCapOk" or "StatuslineLangCapError"
	return hl(left_cap, CAP_LEFT) .. body .. hl("StatuslineLangEdge", CAP_RIGHT)
end

return M
