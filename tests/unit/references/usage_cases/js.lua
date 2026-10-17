-- Expected usage types: { line (1-based), needle, type|false, nth=occurrence,
-- off=byte offset into needle, kind=referenced-symbol kind for caller refinement }.
-- The verifier prints the resolved 0-based column for each entry.
local CATALOGUE_IDS = {
	catch_declaration = "catch",
	local_declaration = "variable_declaration",
	type_argument = "type_instantiation",
}

local function find_column(line, needle, occurrence)
	local from = 1
	for _ = 1, occurrence do
		local start = line:find(needle, from, true)
		assert(start, ("missing case needle %q"):format(needle))
		from = start + 1
		if _ == occurrence then
			return start - 1
		end
	end
end

local function suite(filetype, filename, descriptors)
	local path = "tests/unit/references/usage_cases/js/" .. filename
	local lines = vim.fn.readfile(path)
	local cases = vim.tbl_map(function(case)
		local expected = CATALOGUE_IDS[case[3]] or case[3]
		return {
			line = case[1] - 1,
			character = find_column(lines[case[1]], case[2], case.nth or 1) + (case.off or 0),
			expected = expected or "read",
			query_expected = case.query or expected or "read",
			refined_expected = expected or false,
			kind = case.kind,
		}
	end, descriptors)
	return { filetype = filetype, source = table.concat(lines, "\n") .. "\n", cases = cases }
end

local ts = {
	{ 1, "Default", "import" },
	{ 1, "Money", "import" },
	{ 1, "Currency", "import" },
	{ 1, "Cur }", "import" },
	{ 2, "models", "import" },
	{ 3, "Money", "import" },
	{ 5, "Base", "extends" },
	{ 5, "Money", "type_argument" },
	{ 6, "Money", "field_declaration" },
	{ 7, "Money", "parameter_declaration", nth = 1 },
	{ 7, "Money", "return_type", nth = 2 },
	{ 10, "Base", "extends" },
	{ 10, "Money", "type_argument" },
	{ 10, "Priced", "extends" },
	{ 10, "Serializable", "extends" },
	{ 11, "Money", "field_declaration", nth = 1 },
	{ 11, "Money", "static_member", nth = 2, kind = "type" },
	{ 12, "Money", "field_declaration" },
	{ 13, "Money", "field_declaration" },
	{ 15, "Money", "parameter_declaration" },
	{ 17, "Money", "new" },
	{ 20, "Money", "parameter_declaration", nth = 1 },
	{ 20, "Money", "return_type", nth = 2 },
	{ 21, "Money", "static_member", kind = "type" },
	{ 21, "of", "call" },
	{ 24, "Money {", "instanceof" },
	{ 25, "Money", "instanceof" },
	{ 29, "Array", "parameter_declaration" },
	{ 29, "Money", "type_argument", nth = 1 },
	{ 29, "Money", "parameter_declaration", nth = 2 },
	{ 29, "Money", "return_type", nth = 3 },
	{ 29, "Money", "return_type", nth = 4 },
	{ 30, "Money", "local_declaration", nth = 1 },
	{ 30, "Money", "static_member", nth = 2, kind = "type" },
	{ 30, "sum(xs", "call" },
	{ 31, "Money", "cast" },
	{ 32, "Money", "cast" },
	{ 33, "Money", "cast" },
	{ 34, "Money", "new" },
	{ 36, "total", "call" },
	{ 37, "AppError", "catch_declaration" },
	{ 38, "error", "call" },
	{ 40, "Money", "parameter_declaration", nth = 1 },
	{ 40, "Money", "return_type", nth = 2 },
	{ 41, "add", "call" },
	{ 43, "fn", "call" },
	{ 48, "Default", "static_member", kind = "type" },
	{ 48, "create", "call" },
	{ 48, "Money", "type_argument" },
	{ 49, "Box", "new" },
	{ 49, "Money", "type_argument", nth = 1 },
	{ 49, "Money", "static_member", nth = 2, kind = "type" },
	{ 50, "Money", "type_argument", nth = 1 },
	{ 50, "U,", "parameter_declaration" },
	{ 50, "Money", "parameter_declaration", nth = 2 },
	{ 50, "Cur", "parameter_declaration" },
	{ 50, "Money", "return_type", nth = 3 },
	{ 50, "U]", "return_type" },
	-- negatives
	{ 10, "models", false },
	{ 21, "m.", false },
	{ 21, "amount", false },
	{ 30, "xs", false },
	{ 31, "sum", false },
	{ 34, "models", false },
	{ 38, "console", false },
	{ 41, "sum", false },
	{ 41, "maybe", false },
	{ 42, "maybe", false },
	{ 42, "sum", false },
	{ 43, "sum", false },
	{ 46, "amount", false },
	{ 47, "Money", "type_alias" },
	{ 47, "Money", false, kind = "variable", query = "type_alias" }, -- known non-type target: type position dropped
	{ 51, "u", false },
}

local tsx = {
	{ 1, "Money", "import" },
	{ 2, "React", "import" },
	{ 4, "Money", "field_declaration", nth = 1 },
	{ 4, "Money", "parameter_declaration", nth = 2 },
	{ 6, "Props", "parameter_declaration" },
	{ 6, "Element", "return_type" },
	{ 7, "Money", "local_declaration", nth = 1 },
	{ 7, "Money", "static_member", nth = 2, kind = "type" },
	{ 7, "parse(", "call" },
	{ 7, "String", "call" },
	{ 8, "Money", "cast" },
	{ 9, "Money", "instanceof" },
	{ 10, "log", "call" },
	{ 10, "Money", "new" },
	{ 12, "ReadonlyArray", "local_declaration" },
	{ 12, "Money", "type_argument" },
	{ 14, "format", "call" },
	{ 18, "toString", "call" },
	{ 21, "Money", "parameter_declaration" },
	-- negatives
	{ 6, "JSX", false },
	{ 7, "value", false, nth = 1 },
	{ 9, "parsed", false },
	{ 14, "parsed", false },
	{ 16, "span", false }, -- JSX tag: no usage type
	{ 18, "casted", false },
	{ 22, "m.", false },
}

local js = {
	{ 1, "Money", "import" },
	{ 1, "Currency", "import" },
	{ 1, "convert", "import" },
	{ 1, "conv ", "import" },
	{ 2, "utils", "import" },
	{ 3, "Money", "import" },
	{ 5, "Money", "extends" },
	{ 7, "Wallet", "new" },
	{ 7, "Money", "static_member", kind = "type" },
	{ 11, "Container", "extends" },
	{ 14, "Money", "new" },
	{ 15, "Money", "new" },
	{ 16, "Money", "instanceof" },
	{ 17, "conv", "call" },
	{ 17, "Currency", "static_member", kind = "type" },
	{ 20, "process", "call" },
	{ 22, "error", "call" },
	{ 26, "Money", "static_member", kind = "type" },
	{ 26, "sum", "call" },
	-- negatives
	{ 11, "utils", false },
	{ 15, "utils", false },
	{ 16, "input", false },
	{ 17, "input", false },
	{ 17, "EUR", false },
	{ 20, "utils", false },
	{ 20, "m)", false },
	{ 24, "total", false },
	{ 24, "m;", false },
	{ 25, "total", false },
	{ 25, "n;", false },
	{ 26, "total", false },
	{ 26, "value", false },
	{ 17, "Currency", false, kind = "variable", query = "static_member" }, -- PascalCase variable: dropped by kind
}

local typescript = suite("typescript", "usages.ts", ts)
typescript.suites = {
	typescript,
	suite("typescriptreact", "usages.tsx", tsx),
	suite("javascript", "usages.js", js),
}
return typescript
