local status_ok, indent_blankline = pcall(require, "ibl")
if not status_ok then
	return
end

local indent = {
	char = "▏", -- alternative chars: "▎" "│"
}

local exclude = { -- don't show indentlines for these filetypes
	filetypes = {
		"help",
		"startify",
		"dashboard",
		"packer",
		"neogitstatus",
		"NvimTree",
		"Trouble",
	},
	buftypes = { "terminal", "nofile" },
}

indent_blankline.setup({
	indent = indent,
	exclude = exclude,
})
