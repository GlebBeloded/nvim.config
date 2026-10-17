local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["languages: Enabled LSP servers are unchanged"] = function()
	eq(child.lua_get([[vim.tbl_contains(require("gleb.languages").facet_names(), "lsp")]]), true)
	eq(
		child.lua_get([[vim.fn.sort(vim.iter(vim.lsp.get_configs({ enabled = true }))
		:map(function(config) return config.name end):totable())]]),
		{
			"basedpyright",
			"bashls",
			"cssls",
			"eslint",
			"gopls",
			"html",
			"jsonls",
			"lua_ls",
			"ruff",
			"terraformls",
			"vtsls",
			"yamlls",
		}
	)
end

T["languages: Installed parsers are unchanged"] = function()
	child.lua([[
		local treesitter = require("nvim-treesitter")
		local install = treesitter.install
		treesitter.install = function(parsers)
			vim.g.gleb_treesitter_install = vim.deepcopy(parsers)
		end
		local sandbox = vim.env.GLEB_TEST_SANDBOX
		vim.env.GLEB_TEST_SANDBOX = nil
		local repair = package.loaded["gleb.treesitter.repair"]
		package.loaded["gleb.treesitter.repair"] = { repair = function() end }
		package.loaded["gleb.treesitter"] = nil
		require("gleb.treesitter")
		package.loaded["gleb.treesitter.repair"] = repair
		vim.env.GLEB_TEST_SANDBOX = sandbox
		treesitter.install = install
	]])
	eq(child.lua_get([[vim.tbl_contains(require("gleb.languages").facet_names(), "treesitter")]]), true)
	eq(child.lua_get([[vim.fn.sort(vim.g.gleb_treesitter_install)]]), {
		"bash",
		"go",
		"gomod",
		"hcl",
		"javascript",
		"json",
		"lua",
		"markdown",
		"markdown_inline",
		"python",
		"rust",
		"terraform",
		"tsx",
		"typescript",
		"vim",
		"vimdoc",
		"yaml",
	})
end

T["languages: Lua settings are module-relative"] = function()
	child.lua([[
		vim.env.NVIM_APPNAME = "module-relative-settings-test"
		package.loaded["gleb.languages.lua"] = nil
		_G.lua_language_module = require("gleb.languages.lua")
	]])

	eq(child.lua_get([[_G.lua_language_module.lsp.config.settings.Lua.completion.callSnippet]]), "Replace")
end

return T
