local M = {}

---@param hex string
---@return integer r Red component (0-255)
---@return integer g Green component (0-255)
---@return integer b Blue component (0-255)
function M.hex_to_rgb(hex)
	if type(hex) ~= "string" then
		error("hex must be a string, got " .. type(hex))
	end

	hex = hex:gsub("#", "")

	if not hex:match("^%x%x%x%x%x%x$") then
		error("invalid hex color format: expected 6 hex digits, got '" .. hex .. "'")
	end

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)

	return r, g, b
end

---@param r integer Red component (0-255)
---@param g integer Green component (0-255)
---@param b integer Blue component (0-255)
---@return string hex Hex color string (e.g., "#ff5733")
function M.rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

---@param r integer r Red component (0-255)
---@param g integer g Green component (0-255)
---@param b integer b Blue component (0-255)
---@return integer? h hue (0-360)
---@return integer? s saturation (0-360)
---@return integer? l lightness (360)
function M.rgb_to_hsl(r, g, b)
	r, g, b = r / 255, g / 255, b / 255

	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l = 0, 0, (max + min) / 2

	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)

		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, l
end

---@param h integer hue (0-360)
---@param s integer saturation (0-360)
---@param l integer lightness (360)
---@return integer r r Red component (0-255)
---@return integer g g Green component (0-255)
---@return integer b b Blue component (0-255)
function M.hsl_to_rgb(h, s, l)
	local function hue_to_rgb(p, q, t)
		if t < 0 then
			t = t + 1
		end
		if t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end

	local r, g, b

	if s == 0 then
		r, g, b = l, l, l
	else
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		r = hue_to_rgb(p, q, h + 1 / 3)
		g = hue_to_rgb(p, q, h)
		b = hue_to_rgb(p, q, h - 1 / 3)
	end

	return r * 255, g * 255, b * 255
end

return M
