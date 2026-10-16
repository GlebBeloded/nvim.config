local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["references: Go test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/widget_test.go", "go")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/widget.go", "go")]]), false)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/test_widget.go", "go")]]), false)
end

T["references: TypeScript and JavaScript test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/widget.test.ts", "typescript")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/widget.spec.tsx", "typescriptreact")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/__tests__/widget.js", "javascript")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/widget.jsx", "javascriptreact")]]), false)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/testing_utils.ts", "typescript")]]), false)
end

T["references: Python test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/test_widget.py", "python")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/widget_test.py", "python")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/conftest.py", "python")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/tests/widget.py", "python")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/contest.py", "python")]]), false)
end

T["references: Lua test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("lua/widget_spec.lua", "lua")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("spec/widget.lua", "lua")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("tests/widget.lua", "lua")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("lua/gleb/widget.lua", "lua")]]), false)
end

T["references: Rust test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("crates/core/tests/api.rs", "rust")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("crates/core/src/lib.rs", "rust")]]), false)
	eq(child.lua_get([[require("gleb.references.scope").is_test("crates/core/test_utils.rs", "rust")]]), false)
end

T["references: Bash test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("scripts/check.bats", "sh")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("test/check.sh", "bash")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("scripts/tests/check.sh", "sh")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("scripts/check.sh", "sh")]]), false)
end

T["references: Terraform test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("infra/main.tftest.hcl", "terraform")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("infra/tests/main.tf", "terraform")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("infra/main.tf", "terraform")]]), false)
end

T["references: Generic and inferred test paths"] = function()
	eq(child.lua_get([[require("gleb.references.scope").is_test("app/spec/models/user.rb", "ruby")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("app/models/user.rb", "ruby")]]), false)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/widget_test.go")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/widget.spec.ts")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/test_widget.py")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("lua/widget_spec.lua")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("src/widget.ts")]]), false)
end

T["references: Project pattern extends one filetype"] = function()
	local actual = child.lua_get([[(function()
		local scope = require("gleb.references.scope")
		local previous = vim.g.gleb_test_patterns
		vim.g.gleb_test_patterns = { go = { "/e2e/" } }
		local result = {
			scope.is_test("svc/e2e/flow.go", "go"),
			scope.is_test("svc/flow_test.go", "go"),
			scope.is_test("svc/e2e/flow.py", "python"),
			scope.is_test("svc/flow.go", "go"),
		}
		vim.g.gleb_test_patterns = previous
		return result
	end)()]])

	eq(actual, { true, true, false, false })
end

T["references: Position inside Rust cfg test module"] = function()
	local actual = child.lua_get([[(function()
		local source = table.concat({
			"fn production() {}",
			"",
			"#[cfg(test)]",
			"mod tests {",
			"    fn helper() {}",
			"}",
		}, "\n")
		local original = vim.treesitter.get_string_parser
		local root = {}
		local module = { parent_node = root }
		local inside = { parent_node = module }
		local outside = { parent_node = root }
		function root:type() return "source_file" end
		function root:parent() return nil end
		function root:descendant_for_range(row) return row == 4 and inside or outside end
		function module:type() return "mod_item" end
		function module:parent() return root end
		function module:range() return 2, 0, 6, 0 end
		function inside:type() return "function_item" end
		function inside:parent() return module end
		function outside:type() return "function_item" end
		function outside:parent() return root end
		vim.treesitter.get_string_parser = function()
			return { parse = function() return { { root = function() return root end } } end }
		end
		package.loaded["gleb.references.scope"] = nil
		local scope = require("gleb.references.scope")
		local result = {
			scope.is_test_at("src/lib.rs", 5, source),
			scope.is_test_at("src/lib.rs", 1, source),
		}
		vim.treesitter.get_string_parser = original
		return result
	end)()]])

	eq(actual, { true, false })
end

T["references: Rust parser unavailable"] = function()
	local actual = child.lua_get([[(function()
		local source = "#[cfg(test)]\nmod tests {\n    fn helper() {}\n}"
		local original = vim.treesitter.get_string_parser
		vim.treesitter.get_string_parser = function() error("parser unavailable") end
		package.loaded["gleb.references.scope"] = nil
		local scope = require("gleb.references.scope")
		local ok, source_result = pcall(scope.is_test_at, "src/lib.rs", 3, source)
		local path_result = scope.is_test_at("tests/api.rs", 3, source)
		vim.treesitter.get_string_parser = original
		return { ok, source_result, path_result }
	end)()]])

	eq(actual, { true, false, true })
end

return T
