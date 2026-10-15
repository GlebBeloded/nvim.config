-- blink.cmp setup; runs after the action registry so its keymaps come from settings/keymap.json.
local status_ok, blink = pcall(require, "blink.cmp")
if not status_ok then
	return
end

local actions = require("gleb.actions")
local adapter = require("gleb.actions.adapters.blink")
local store = assert(actions.state.store, "actions are not set up")
local catalog = assert(actions.state.applicator, "actions are not set up").catalog
local shortcuts = store:load()

-- To disable completion in comments, add to the setup table:
-- enabled = function()
--   return not require("blink.cmp.config").context_in_treesitter_capture("comment")
-- end,
blink.setup({
	keymap = vim.tbl_extend("force", { preset = "none" }, adapter.mappings(catalog, shortcuts, "i")),

	appearance = {
		nerd_font_variant = "mono", -- "mono" for Nerd Font Mono, "normal" otherwise
	},

	-- Rust-based fuzzy matcher for speed (falls back to Lua if unavailable)
	fuzzy = { implementation = "prefer_rust_with_warning" },

	-- Completion sources in priority order (first = highest priority)
	sources = {
		default = { "lazydev", "lsp", "path", "snippets", "buffer" },
		providers = {
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				score_offset = 100, -- boost priority for Neovim Lua API completions
			},
		},
	},

	completion = {
		-- Auto-insert brackets for functions/methods
		accept = { auto_brackets = { enabled = true } },

		-- Disabled: Copilot provides ghost text instead
		ghost_text = { enabled = false },

		-- Show docs automatically when item selected
		documentation = { auto_show = true },

		trigger = {
			-- Don't auto-show on ".", ":", etc. - only on keywords
			-- Use C-Space to manually trigger after special chars
			show_on_trigger_character = false,
		},

		menu = {
			draw = {
				-- Menu columns: [icon] [label + description]
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
			},
		},
	},

	-- Show function signature help while typing arguments
	signature = { enabled = true },

	-- Command-line completion (:, /, ?)
	cmdline = {
		keymap = vim.tbl_extend("force", { preset = "none" }, adapter.mappings(catalog, shortcuts, "c")),
	},
})
