-- Statusline + bufferline colors, derived entirely from the gruvbox-material
-- palette via the colors-package helpers — no hardcoded hex.
--
-- The bar sits just barely above the editor background (a subtle warm lift) so
-- both lines blend in minimalistically rather than reading as separate panels.
-- Tune LIFT (distance from the editor bg) and WARM (orange tint).
local palette = require("gleb.colors.gruvbox-material.palette")
local util = require("gleb.colors.gruvbox-material.util")

local bg = palette.background
local fg = palette.foreground

local LIFT = 0.02 -- how far the bar sits above the editor background
local WARM = 0.05 -- subtle warm (orange) tint, kills any cool cast

-- a shade of the editor background, lifted/warmed by `extra` on top of LIFT
local function bar_shade(extra)
	return util.brighten(util.blend(bg.bg0, fg.orange, WARM), LIFT + (extra or 0))
end

return {
	-- shared fill for the statusline (bottom) and bufferline (top)
	bar = bar_shade(),
	bar_sel = bar_shade(0.03), -- active buffer / selected — a touch more lifted
	chip_bg = bar_shade(0.04), -- the language chip reads as a faint block

	-- text
	text = fg.fg0,
	text_hi = fg.fg1,
	muted = bg.bg5,
	dark = bg.bg0,

	-- semantic
	ok = fg.green,
	err = fg.red,

	-- mode accents (conventional mapping)
	mode = {
		normal = fg.green,
		insert = fg.blue,
		visual = fg.purple,
		replace = fg.red,
		command = fg.yellow,
		terminal = fg.aqua,
	},
}
