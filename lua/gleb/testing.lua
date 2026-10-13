local has_neotest, neotest = pcall(require, "neotest")
local has_golang, neotest_golang = pcall(require, "neotest-golang")
if not (has_neotest and has_golang) then
	return
end

neotest.setup({
	adapters = {
		neotest_golang({
			testify_enabled = true,
		}),
	},
})
