local status_ok, alpha = pcall(require, "alpha")
if not status_ok then
	return
end

local dashboard = require("alpha.themes.dashboard")
local actions = require("gleb.actions")
local adapter = require("gleb.actions.adapters.alpha")
local shortcuts = assert(actions.state.store, "actions are not set up"):load()
local catalog = assert(actions.state.applicator, "actions are not set up").catalog

dashboard.section.header.val = {
	[[                               __                ]],
	[[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
	[[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
	[[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
	[[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
	[[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
}
dashboard.section.buttons.val = adapter.buttons(catalog, shortcuts, dashboard, {
	{ id = "alpha.find_file", label = "  Find file" },
	{ id = "alpha.new_file", label = "  New file" },
	{ id = "alpha.recent_files", label = "  Recently used files" },
	{ id = "alpha.find_text", label = "  Find text" },
	{ id = "alpha.configuration", label = "  Configuration" },
	{ id = "alpha.quit", label = "  Quit Neovim" },
})

local function footer()
	-- NOTE: requires the fortune-mod package to work
	-- local handle = io.popen("fortune")
	-- local fortune = handle:read("*a")
	-- handle:close()
	-- return fortune
	return "https://github.com/GlebBeloded"
end

dashboard.section.footer.val = footer()

dashboard.section.footer.opts.hl = "Type"
dashboard.section.header.opts.hl = "Include"
dashboard.section.buttons.opts.hl = "Keyword"

dashboard.opts.opts.noautocmd = true
dashboard.opts.opts.keymap = adapter.press_keys(shortcuts)
alpha.setup(dashboard.opts)
