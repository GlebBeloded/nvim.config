local function merge(...)
	local tbl = vim.tbl_deep_extend("force", ...)
	if tbl == nil then
		return {}
	end

	return tbl
end

---@type gleb.Languages
local languages = require("gleb.languages")

languages.register_facet("lsp", function(config, language)
	if not vim.islist(config.servers) or not vim.islist(config.mason) then
		return ("languages: %s has invalid lsp facet"):format(language.name)
	end
end)

local language_configs = vim.iter(languages.facet("lsp"))
	:map(function(facet)
		return facet.config
	end)
	:totable()

local actions = require("gleb.actions")
local adapters = require("gleb.actions.adapters")
local store = assert(actions.state.store, "actions are not set up")
local catalog = assert(actions.state.applicator, "actions are not set up").catalog

require("mason").setup({
	ui = {
		-- mason has no "no key" value: an unreachable <Plug> lhs drops each unassigned default
		keymaps = vim.tbl_extend(
			"force",
			adapters.cleared(require("mason.settings").current.ui.keymaps, "<Plug>(gleb-mason-unassigned)"),
			require("gleb.actions.adapters.mason").mappings(catalog, store:load())
		),
	},
})

local function update()
	-- list of binaries (dependencies) to install. Stuff like linters, lsp, formatters.
	local deps = vim.iter(language_configs)
		:map(function(c)
			return c.mason or {}
		end)
		:flatten()
		:totable()

	vim.cmd(":MasonInstall " .. table.concat(deps, " "))
end

vim.api.nvim_create_user_command("MasonSync", update, {})

local global_config = require("gleb.lsp.config.handlers")
global_config.setup()

for _, language in ipairs(language_configs) do
	local language_config = type(language.config) == "function" and language.config() or language.config
	local config = merge(global_config, language_config or {})
	for _, name in ipairs(language.servers) do
		vim.lsp.config(name, config)
		vim.lsp.enable(name)
	end
end

local null_ls = require("null-ls")

local diagnostics = { null_ls.builtins.formatting.prettier }
for _, language in ipairs(language_configs) do
	if language.null_ls then
		for _, builtin in ipairs(language.null_ls(null_ls)) do
			table.insert(diagnostics, builtin)
		end
	end
end

null_ls.setup({
	debug = false,
	update_in_insert = false,
	sources = diagnostics,
})
