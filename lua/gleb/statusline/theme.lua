-- lualine theme built from the derived statusline palette (see palette.lua).
-- All colors come from the colors package; nothing is hardcoded here.
local c = require("gleb.statusline.palette")

local function mode(accent)
	return { a = { fg = c.dark, bg = accent, gui = "bold" } }
end

return {
	normal = {
		a = { fg = c.dark, bg = c.mode.normal, gui = "bold" },
		b = { fg = c.text, bg = c.bar },
		c = { fg = c.text, bg = c.bar },
	},
	insert = mode(c.mode.insert),
	visual = mode(c.mode.visual),
	replace = mode(c.mode.replace),
	command = mode(c.mode.command),
	terminal = mode(c.mode.terminal),
	inactive = {
		a = { fg = c.muted, bg = c.bar },
		b = { fg = c.muted, bg = c.bar },
		c = { fg = c.muted, bg = c.bar },
	},
}
