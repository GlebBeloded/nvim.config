local MiniTest = require("mini.test")
local F = require("tests.fixtures")

local eq = MiniTest.expect.equality

---@param fixture string
---@param symbol string
---@param paths string[]
local function expect_fixture(fixture, symbol, paths)
	local root, manifest = F.copy(fixture, vim.fn.tempname())
	local locations = manifest.references[symbol]

	eq(
		vim.tbl_map(function(location)
			return location.path
		end, locations),
		paths
	)

	for _, location in ipairs(locations) do
		local line = vim.fn.readfile(vim.fs.joinpath(root, location.path))[location.line]
		eq(line:sub(location.col, location.col + #symbol - 1), symbol)
	end
end

local T = MiniTest.new_set()

T["references: Lua usages in production and spec files"] = function()
	expect_fixture("luaproj", "total", { "lua/shop/price.lua", "lua/shop/cart.lua", "spec/price_spec.lua" })
end

T["references: Python usages in production and test files"] = function()
	expect_fixture("pyproj", "total", { "shop/price.py", "shop/cart.py", "tests/test_price.py" })
end

T["references: TypeScript usages in production and test files"] = function()
	expect_fixture("tsproj", "total", { "src/price.ts", "src/cart.ts", "src/price.test.ts" })
end

T["references: Rust usages in production and test code"] = function()
	expect_fixture("rustproj", "total", { "src/price.rs", "src/price.rs", "src/main.rs", "tests/price.rs" })
end

T["references: Bash usages in production and test scripts"] = function()
	expect_fixture("bashproj", "total", { "lib/price.sh", "bin/run.sh", "test/price_test.sh" })
end

T["references: Terraform variable usages"] = function()
	expect_fixture("tfproj", "region", { "variables.tf", "main.tf", "outputs.tf" })
end

return T
