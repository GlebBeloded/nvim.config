-- Lua usage-query cases ported from the change's parser-verified draft.
local ROOT = "tests/unit/references/usage_cases/lua/shop/"

---@param file string
---@param descriptors {[1]: integer, [2]: integer, [3]: string|false, [4]: string}[]
---@return table
local function suite(file, descriptors)
	local source = table.concat(vim.fn.readfile(ROOT .. file), "\n") .. "\n"
	local lines = vim.split(source, "\n", { plain = true })
	local cases = vim.tbl_map(function(case)
		local text = case[4]
		assert(
			(lines[case[1] + 1] or ""):sub(case[2] + 1, case[2] + #text) == text,
			("missing case text %q at %d:%d"):format(text, case[1], case[2])
		)
		return { line = case[1], character = case[2], expected = case[3] or "read", query_expected = case[3] }
	end, descriptors)
	return { filetype = "lua", source = source, cases = cases }
end

return {
	suites = {
		suite("cart.lua", {
			{ 0, 6, "write", "price" },
			{ 0, 14, "call", "require" },
			{ 0, 23, false, "shop.price" },
			{ 1, 6, "write", "M" },
			{ 3, 10, false, "items" },
			{ 4, 9, "read", "M" },
			{ 4, 11, "function_declaration", "total" },
			{ 4, 17, "parameter_declaration", "items" },
			{ 5, 7, "write", "sum" },
			{ 6, 5, "write", "_" },
			{ 6, 8, "write", "item" },
			{ 6, 16, "call", "ipairs" },
			{ 6, 23, "read", "items" },
			{ 7, 2, "write", "sum" },
			{ 7, 8, "read", "sum" },
			{ 7, 14, "read", "price" },
			{ 7, 20, "call", "of" },
			{ 7, 23, "read", "item" },
			{ 12, 11, "function_declaration", "apply" },
			{ 12, 17, "parameter_declaration", "discount" },
			{ 13, 1, "read", "self" },
			{ 13, 6, "write", "discount" },
			{ 13, 17, "read", "discount" },
			{ 14, 10, "call", "total" },
			{ 14, 21, "read", "items" },
			{ 17, 2, "function_declaration", "format" },
			{ 17, 11, "function_declaration", "function" },
			{ 17, 20, "parameter_declaration", "value" },
			{ 18, 15, "call", "format" },
			{ 18, 23, false, "%.2f" },
			{ 21, 6, "write", "defaults" },
			{ 22, 1, "field_initialization", "total" },
			{ 23, 1, "function_declaration", "format" },
			{ 23, 10, "function_declaration", "function" },
			{ 23, 19, "parameter_declaration", "v" },
			{ 26, 2, "read", "price" },
			{ 26, 8, "read", "key" },
			{ 27, 2, "read", "KEY" },
			{ 30, 15, "function_declaration", "report" },
			{ 30, 22, "parameter_declaration", "cart" },
			{ 31, 1, "call", "print" },
			{ 31, 9, "call", "format" },
			{ 31, 18, "call", "total" },
			{ 31, 24, "read", "cart" },
			{ 31, 29, "read", "items" },
			{ 32, 1, "call", "log" },
			{ 32, 18, "read", "defaults" },
			{ 32, 27, "read", "total" },
			{ 33, 1, "call", "emit" },
			{ 33, 8, "field_initialization", "total" },
			{ 33, 21, "read", "total" },
			{ 34, 1, "read", "cart" },
			{ 34, 6, "call", "apply" },
			{ 35, 3, "call", "notify" },
			{ 36, 3, "call", "render" },
			{ 36, 12, "read", "cart" },
			{ 39, 2, "write", "cache" },
			{ 39, 9, "write", "report_count" },
			{ 40, 6, "function_declaration", "handler" },
			{ 40, 16, "function_declaration", "function" },
			{ 41, 6, "write", "first" },
			{ 41, 13, "write", "second" },
			{ 42, 7, "read", "M" },
		}),
		suite("price.lua", {
			{ 2, 2, "write", "key" },
			{ 4, 11, "function_declaration", "of" },
			{ 4, 14, "parameter_declaration", "item" },
			{ 5, 13, "read", "price" },
		}),
	},
}
