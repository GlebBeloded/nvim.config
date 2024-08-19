local colorscheme = "gruvbox-material"
local initialized = false

if not initialized then
	require("gleb.colors.colorizer")

	require("gleb.colors." .. colorscheme)

	initialized = true
end

require("gleb.colors." .. "transparency")

return require("gleb.colors." .. colorscheme .. ".palette")
