local status_ok, transparent = pcall(require, "transparent")
if not status_ok then
	return
end

transparent.setup({
	extra_groups = {
		'Folded',
		'NormalFloat',
		'FloatBorder',
	},
})

transparent.clear_prefix('lualine')
transparent.clear_prefix('NeoTree')
