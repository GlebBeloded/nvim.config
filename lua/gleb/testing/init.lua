local has_neotest, neotest = pcall(require, "neotest")
local has_golang, neotest_golang = pcall(require, "neotest-golang")
if not (has_neotest and has_golang) then
	return
end

local actions = require("gleb.actions")
local adapters = require("gleb.actions.adapters")
local store = assert(actions.state.store, "actions are not set up")
local catalog = assert(actions.state.applicator, "actions are not set up").catalog

neotest.setup({
	adapters = {
		neotest_golang({
			testify_enabled = true,
		}),
	},
	summary = {
		mappings = vim.tbl_extend(
			"force",
			adapters.cleared(require("neotest.config").summary.mappings, {}),
			require("gleb.actions.adapters.neotest").mappings(catalog, store:load())
		),
	},
})
