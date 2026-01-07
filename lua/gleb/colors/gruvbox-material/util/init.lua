local conversions = require("gleb.colors.gruvbox-material.util.convert")

local M = {}

M.hex_to_rgb = conversions.hex_to_rgb
M.rgb_to_hex = conversions.rgb_to_hex
M.rgb_to_hsl = conversions.rgb_to_hsl
M.hsl_to_rgb = conversions.hsl_to_rgb

-- Brighten a color by adjusting lightness in HSL space
-- amount: 0.0 to 1.0 (0.1 = 10% brighter)
function M.brighten(hex_color, amount)
	local h, s, l = M.rgb_to_hsl(M.hex_to_rgb(hex_color))

	l = math.min(1, l + amount)

	return M.rgb_to_hex(M.hsl_to_rgb(h, s, l))
end

-- Darken a color by adjusting lightness in HSL space
-- amount: 0.0 to 1.0 (0.1 = 10% darker)
function M.darken(hex_color, amount)
	return M.brighten(hex_color, -amount)
end

-- Blend two colors
-- ratio: 0.0 to 1.0 (0.5 = 50/50 blend)
function M.blend(hex_color1, hex_color2, ratio)
	local r1, g1, b1 = M.hex_to_rgb(hex_color1)
	local r2, g2, b2 = M.hex_to_rgb(hex_color2)

	local r = r1 * (1 - ratio) + r2 * ratio
	local g = g1 * (1 - ratio) + g2 * ratio
	local b = b1 * (1 - ratio) + b2 * ratio

	return M.rgb_to_hex(r, g, b)
end

return M
