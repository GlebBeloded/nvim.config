local palette = require("gleb.colors.gruvbox-material.palette")

-- packages
vim.api.nvim_set_hl(0, "TSNamespace", { fg = palette.background.bg5 }) -- package name

-- variables and fields
vim.api.nvim_set_hl(0, "TSParameter", { fg = palette.foreground.fg0 }) -- function args
vim.api.nvim_set_hl(0, "TSVariable", { fg = palette.foreground.fg1 }) -- variables
vim.api.nvim_set_hl(0, "TSField", { fg = palette.foreground.fg1 }) -- struct fields
vim.api.nvim_set_hl(0, "TSProperty", { fg = palette.foreground.aqua }) -- sturct.field field color

-- functions
vim.api.nvim_set_hl(0, "TSMethod", { fg = palette.foreground.blue }) -- methods
vim.api.nvim_set_hl(0, "TSMethodCall", { fg = palette.foreground.blue }) -- calling methods
vim.api.nvim_set_hl(0, "TSFuncBuiltin", { fg = palette.foreground.blue }) -- built in functions
vim.api.nvim_set_hl(0, "TSFunction", { fg = palette.foreground.blue }) -- functions

-- types
vim.api.nvim_set_hl(0, "TSType", { fg = palette.foreground.green }) -- type name
vim.api.nvim_set_hl(0, "TSTypeDefinition", { fg = palette.foreground.fg1 }) -- type name
vim.api.nvim_set_hl(0, "TSSpell", { fg = palette.foreground.fg1 }) -- type name
vim.api.nvim_set_hl(0, "TSTypeBuiltin", { fg = palette.foreground.green }) -- built in types(int,any)

-- builtins
vim.api.nvim_set_hl(0, "TSConstBuiltin", { fg = palette.foreground.orange }) -- nil, const
vim.api.nvim_set_hl(0, "TSConstant", { fg = palette.foreground.red }) -- underscore
vim.api.nvim_set_hl(0, "TSOperator", { fg = palette.foreground.red }) -- operators
vim.api.nvim_set_hl(0, "TSKeyword", { fg = palette.foreground.red }) -- keywords
vim.api.nvim_set_hl(0, "TSKeywordReturn", { fg = palette.foreground.red }) -- return keyword
vim.api.nvim_set_hl(0, "TSPunctDelimiter", { fg = palette.foreground.yellow }) -- yaml ":"
vim.api.nvim_set_hl(0, "TSWarning", { fg = palette.foreground.red }) -- this will highlight todo's in red
vim.api.nvim_set_hl(0, "TSNote", {}) -- don't change background color for notes

-- strings
vim.api.nvim_set_hl(0, "TSString", { fg = palette.foreground.bg_yellow }) -- basic strings

-- Semantic color roles (what each color means)
local semantic_colors = {
	constant = palette.foreground.orange,
	readonly = palette.foreground.orange,
	mutable_variable = palette.foreground.fg1,
	deprecated = { strikethrough = true },
	builtin = palette.foreground.blue,
}

-- Define your LSP semantic token overrides using semantic meanings
local lsp_overrides = {
	-- Types
	-- ["@lsp.type.variable"] = { fg = semantic_colors.mutable_variable },
	-- ["@lsp.type.constant"] = { fg = semantic_colors.constant },
	-- ["@lsp.type.enumMember"] = { fg = semantic_colors.constant },
	-- ["@lsp.type.parameter"] = { link = "@variable.parameter" },
	-- ["@lsp.type.function"] = { link = "@function" },
	-- ["@lsp.type.method"] = { link = "@function.method" },
	-- ["@lsp.type.class"] = { link = "@type" },
	-- ["@lsp.type.struct"] = { link = "@type" },

	-- Modifiers
	["@lsp.mod.readonly"] = { fg = semantic_colors.readonly },
	-- ["@lsp.mod.deprecated"] = semantic_colors.deprecated,
	-- ["@lsp.mod.defaultLibrary"] = { link = "@function.builtin" },

	-- Combined type+modifier for highest priority
	-- ["@lsp.typemod.variable.readonly"] = { fg = semantic_colors.constant },
}

-- Apply all overrides
for group, opts in pairs(lsp_overrides) do
	vim.api.nvim_set_hl(0, group, opts)
end
