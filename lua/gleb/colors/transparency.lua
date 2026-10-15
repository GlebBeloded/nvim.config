local status_ok, transparent = pcall(require, "transparent")
if not status_ok then
	return
end

transparent.setup({
	extra_groups = {
		"Folded",
		"NormalFloat",
		"FloatBorder",
	},
	exclude_groups = {
		"FindActionBody",
		"FindActionSelected",
		"FindActionPrompt",
		"FindActionBorder",
		"FindActionHint",
		"FindActionHintKey",
	},
})

-- keep lualine section backgrounds (the colored mode/position blocks);
-- clearing them makes the statusline text barely readable on a transparent bg
transparent.clear_prefix("NeoTree")
