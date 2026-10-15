local status_ok, neo_tree = pcall(require, "neo-tree")
if not status_ok then
	return
end

local actions = require("gleb.actions")
local adapter = require("gleb.actions.adapters.neo_tree")
local store = assert(actions.state.store, "actions are not set up")
local catalog = assert(actions.state.applicator, "actions are not set up").catalog
local shortcuts = store:load()
local common_mappings = adapter.window_mappings(catalog, shortcuts, "common")
local filesystem_mappings =
	vim.tbl_extend("force", common_mappings, adapter.window_mappings(catalog, shortcuts, "filesystem"))
local git_status_mappings =
	vim.tbl_extend("force", common_mappings, adapter.window_mappings(catalog, shortcuts, "git_status"))

neo_tree.setup({
	sources = { "filesystem", "git_status" },
	use_default_mappings = false,
	-- neo-tree's health check validates buffers even when it is not in sources
	buffers = { renderers = {} },
	source_selector = {
		winbar = false,
		statusline = false,
	},
	close_if_last_window = true,
	popup_border_style = "rounded",

	default_component_configs = {
		indent = {
			indent_size = 2,
			padding = 1,
			with_markers = true,
			indent_marker = "│",
			last_indent_marker = "└",
			with_expanders = true,
			expander_collapsed = "\u{F460}",
			expander_expanded = "\u{F47C}",
		},
		icon = {
			folder_closed = "\u{E5FF}",
			folder_open = "\u{E5FE}",
			folder_empty = "\u{F0256}",
		},
		name = {
			use_git_status_colors = true, -- Color filenames by git status
		},
		git_status = {
			symbols = {
				unstaged = " ", -- empty (no indicator)
				staged = "»", -- chevron (queued/ready to commit)
				conflict = "\u{E727}",
				renamed = "➜",
				untracked = "?",
				deleted = "✗",
				ignored = "◌",
			},
		},
	},

	window = {
		position = "left",
		width = 35,
		mappings = common_mappings,
	},

	filesystem = {
		follow_current_file = { enabled = true },
		use_libuv_file_watcher = true,
		hijack_netrw_behavior = "open_current",
		filtered_items = {
			visible = true,
			hide_dotfiles = false,
			hide_gitignored = false,
		},
		window = {
			mappings = filesystem_mappings,
		},
	},

	git_status = {
		renderers = {
			file = {
				{ "indent" },
				{ "git_status", highlight = "NeoTreeGitStatusSymbol" },
				{ "icon" },
				{ "name", use_git_status_colors = true },
			},
			directory = {
				{ "indent" },
				{ "git_status", highlight = "NeoTreeGitStatusSymbol" },
				{ "icon" },
				{ "name" },
			},
		},
		window = {
			position = "left",
			width = 35,
			mappings = git_status_mappings,
		},
	},
})

-- Remove when neo-tree's porcelain v2 parser stops skipping leading unmerged (`u`) records.
require("neo-tree.git")._supported_status_porcelain_version = 1
