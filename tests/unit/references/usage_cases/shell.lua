-- Bash usage-query cases ported from the change's parser-verified draft.
local ROOT = "tests/unit/references/usage_cases/shell/"

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
	return { filetype = "bash", source = source, cases = cases }
end

return {
	suites = {
		suite("deploy.sh", {
			{ 1, 0, "call", "source" },
			{ 1, 7, false, "./lib.sh" },
			{ 2, 0, "call", "." },
			{ 4, 0, "write", "region" },
			{ 5, 7, "write", "STAGE" },
			{ 6, 7, "export", "region" },
			{ 7, 8, false, "-a" },
			{ 7, 11, "write", "hosts" },
			{ 8, 9, "write", "retries" },
			{ 10, 0, "function_declaration", "deploy" },
			{ 11, 7, "write", "target" },
			{ 11, 15, false, "$1" },
			{ 11, 16, "read", "1" },
			{ 12, 7, "write", "count" },
			{ 13, 5, "write", "host" },
			{ 13, 14, false, "${hosts[@]}" },
			{ 13, 16, "read", "hosts" },
			{ 14, 2, "call", "greet" },
			{ 14, 9, false, "$host" },
			{ 14, 10, "read", "host" },
			{ 15, 2, "write", "count" },
			{ 15, 11, "read", "count" },
			{ 17, 1, "call", "read" },
			{ 17, 6, false, "-r" },
			{ 17, 9, "write", "answer" },
			{ 18, 7, false, "$target" },
			{ 18, 8, "read", "target" },
			{ 18, 15, false, "${region" },
			{ 18, 17, "read", "region" },
			{ 18, 37, "read", "answer" },
			{ 19, 7, false, "$region" },
			{ 19, 8, "read", "region" },
			{ 20, 1, "write", "hosts" },
			{ 20, 11, "read", "region" },
			{ 21, 4, "write", "count" },
			{ 22, 7, "read", "answer" },
			{ 25, 9, "function_declaration", "cleanup" },
			{ 26, 1, "call", "greet" },
			{ 26, 9, "read", "region" },
			{ 29, 0, "call", "deploy" },
			{ 29, 23, false, "log" },
			{ 30, 0, "call", "cleanup" },
		}),
		suite("lib.sh", {
			{ 1, 0, "function_declaration", "greet" },
			{ 2, 14, "read", "1" },
		}),
	},
}
