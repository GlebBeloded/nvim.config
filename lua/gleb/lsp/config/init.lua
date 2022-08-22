local function merge(...)
	local tbl = vim.tbl_deep_extend("force", ...)
	if tbl == nil then
		return {}
	end

	return tbl
end

-- fieldToList accepts a list of objects and returns field fieldName from those objects
local function fieldToList(fieldName, ...)
	local fields = {}
	for _, value in ipairs(...) do
		if value[fieldName] then
			table.insert(fields, value[fieldName])
		end
	end

	return fields
end

local langauge_configs = {
	require("gleb/lsp/config/go"), -- golang
	require("gleb/lsp/config/lua"), -- lua
}

require("mason").setup()

local function update()
	vim.cmd(":MasonInstall " .. table.concat(merge(unpack(fieldToList("mason", langauge_configs))), " "))
end

vim.api.nvim_create_user_command("MasonSync", update, {})

local lsp = require("lspconfig")
local global_config = require("gleb/lsp/config/handlers")

for _, language in ipairs(langauge_configs) do
	if language.lsp_name then
		lsp[language.lsp_name].setup(merge(global_config, language.lsp_config))
	end
end

local null_ls = require("null-ls")

local diagnostics = {}
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

-- OLD CODE

-- null_ls.setup({
--   debug = false,
--   update_in_insert = false,

--   sources = { null_ls.builtins.diagnostics.zsh, null_ls.builtins.formatting.beautysh,
--     null_ls.builtins.formatting.prettier },
-- })
--
-- require("gleb/lsp/config/json")
--
-- require("lspconfig").yamlls.setup({
--   settings = {
--     yaml = {
--       schemas = {
--         ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json?inline=false"] = "*/.gitlab-ci.yaml",
--       }
--     }
--   }
-- })
--
-- require("lspconfig").jsonls.setup(merge(global_config, require("gleb.lsp.config.json")))
