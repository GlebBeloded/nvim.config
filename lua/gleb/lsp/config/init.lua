local function merge(...)
	local tbl = vim.tbl_deep_extend("force", ...)
	if tbl == nil then
		return {}
	end

	return tbl
end

local langauge_configs = {
	require("gleb/lsp/config/go"), -- golang
	require("gleb/lsp/config/lua"), -- lua
	require("gleb/lsp/config/html"), -- html
	require("gleb/lsp/config/css"), -- css
	require("gleb/lsp/config/js"), -- javascript
	require("gleb/lsp/config/json"), -- json
	require("gleb/lsp/config/yaml"), -- yaml
	require("gleb/lsp/config/shell"), -- sh,bash,zsh
	require("gleb/lsp/config/terraform"), -- hashicorp yucky
	require("gleb/lsp/config/rust"), -- rust
}

require("mason").setup()

local function update()
	-- list of binaries (dependencies) to install. Stuff like linters, lsp, formatters.
	local deps = vim.iter(langauge_configs)
		:map(function(c)
			return c.mason or {}
		end)
		:flatten()
		:totable()

	vim.cmd(":MasonInstall " .. table.concat(deps, " "))
end

vim.api.nvim_create_user_command("MasonSync", update, {})

local global_config = require("gleb/lsp/config/handlers")
global_config.setup()

for _, language in ipairs(langauge_configs) do
	if language.lsp_name then
		local config = merge(global_config, language.lsp_config)
		vim.lsp.config(language.lsp_name, config)
		vim.lsp.enable(language.lsp_name)
	end
end

local null_ls = require("null-ls")

local diagnostics = { null_ls.builtins.formatting.prettier }
for _, language in ipairs(langauge_configs) do
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
