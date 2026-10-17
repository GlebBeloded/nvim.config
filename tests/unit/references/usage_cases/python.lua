-- Python usage-query cases ported from the change's parser-verified draft.
local DESCRIPTORS = {
	{ 1, "annotations", "import" },
	{ 2, "os", "import" },
	{ 2, "path", "import" },
	{ 2, "osp", "import" },
	{ 3, "pkg", "import" },
	{ 3, "models", "import" },
	{ 4, "Thing", "import" },
	{ 4, "Base", "import" },
	{ 4, "B", "import" },
	{ 5, "errors", "import" },
	{ 5, "AppError", "import" },
	{ 7, "Alias", false },
	{ 7, "list", "type_alias" },
	{ 7, "Thing", "type_alias" },
	{ 8, "Legacy", "write" },
	{ 8, "TypeAlias", "variable_declaration" },
	{ 8, "dict", "type_alias" },
	{ 8, "Thing", "type_alias" },
	{ 9, "counter", "write" },
	{ 9, "int", "variable_declaration" },
	{ 10, "x", "write" },
	{ 11, "print", "call" },
	{ 11, "x", false },
	{ 14, "Repo", false },
	{ 14, "B", "extends" },
	{ 14, "pkg", false },
	{ 14, "models", false },
	{ 14, "Mixin", "extends" },
	{ 14, "Generic", "extends" },
	{ 14, "Thing", "extends" },
	{ 14, "metaclass", false },
	{ 14, "Meta", "extends" },
	{ 15, "items", "write" },
	{ 15, "list", "field_declaration" },
	{ 15, "Thing", "field_declaration" },
	{ 15, "field", "call" },
	{ 15, "default_factory", "keyword_argument" },
	{ 15, "list", false, nth = 2 },
	{ 16, "dict", "field_declaration" },
	{ 16, "Optional", "field_declaration" },
	{ 16, "Thing", "field_declaration" },
	{ 18, "staticmethod", "decorator" },
	{ 19, "pkg", false },
	{ 19, "cached", "decorator" },
	{ 19, "ttl", "keyword_argument" },
	{ 20, "load", false },
	{ 20, "self", false },
	{ 20, "key", false },
	{ 20, "Thing", "parameter_declaration" },
	{ 20, "Optional", "parameter_declaration" },
	{ 20, "Thing", "parameter_declaration", nth = 2 },
	{ 20, "None", false },
	{ 20, "Thing", "parameter_declaration", nth = 3 },
	{ 20, "Thing", "parameter_declaration", nth = 4 },
	{ 20, "pkg", "parameter_declaration" },
	{ 20, "Thing", "return_type", nth = 5 },
	{ 21, "local", "write" },
	{ 21, "Thing", "variable_declaration" },
	{ 21, "Thing", "call", nth = 2 },
	{ 21, "key", false },
	{ 22, "local", false },
	{ 22, "refresh", "call" },
	{ 23, "pkg", false },
	{ 23, "build", "call" },
	{ 23, "name", "keyword_argument" },
	{ 23, "key", false },
	{ 24, "isinstance", "call" },
	{ 24, "local", false },
	{ 24, "Thing", "instanceof" },
	{ 24, "issubclass", "call" },
	{ 24, "type", "call" },
	{ 24, "Thing", "instanceof", nth = 2 },
	{ 24, "Thing", "instanceof", nth = 3 },
	{ 27, "os", false },
	{ 27, "remove", "call" },
	{ 28, "AppError", "catch" },
	{ 28, "Fail", "catch" },
	{ 28, "err", false },
	{ 30, "AppError", "catch" },
	{ 32, "y", "write" },
	{ 32, "x", false },
	{ 33, "x2", "write" },
	{ 33, "local", false },
	{ 36, "dict", "return_type" },
	{ 36, "Optional", "return_type" },
	{ 36, "Thing", "return_type" },
	{ 40, "cb", false },
	{ 40, "Callable", "parameter_declaration" },
	{ 40, "Thing", "parameter_declaration" },
	{ 40, "Annotated", "parameter_declaration" },
	{ 40, "Thing", "parameter_declaration", nth = 2 },
	{ 40, "Meta", "call" },
	{ 40, "strict", "keyword_argument" },
	{ 40, "pkg", "return_type" },
	{ 40, "Thing", "return_type", nth = 3 },
	{ 41, "data", false },
	{ 42, "Thing", "pattern" },
	{ 42, "name", "pattern" },
	{ 44, "Thing", "instanceof" },
	{ 44, "data", false },
	{ 47, "a", false },
	{ 47, "int", "parameter_declaration" },
	{ 47, "DEFAULT", false },
	{ 47, "b", false },
	{ 47, "lambda", false },
	{ 47, "q", false },
	{ 47, "q", false, nth = 2 },
	{ 48, "total", "write" },
	{ 49, "total", "write" },
	{ 49, "a", false },
	{ 50, "obj", false },
	{ 50, "attr", "write" },
	{ 50, "total", false },
	{ 51, "total", false },
	{ 52, "obj", false },
	{ 52, "attr", false },
	{ 52, "v", false },
	{ 52, "a", false },
	{ 57, "slot", "write" },
	{ 57, "Thing", "field_declaration" },
	{ 58, "Local", false },
	{ 62, "first", "write" },
	{ 62, "second", "write" },
	{ 62, "pairs", false },
	{ 63, "key", "write" },
	{ 63, "value", "write" },
	{ 63, "pairs", false },
	{ 65, "n", "write" },
	{ 65, "len", "call" },
	{ 65, "pairs", false },
	{ 66, "obj", false },
	{ 66, "count", "write" },
	{ 66, "n", false },
	{ 67, "first", false },
	{ 67, "key", false },
	{ 62, "first", false, kind = "type" },
	-- target-kind refinement (kind = the searched symbol's kind)
	{ 4, "Thing", "import", kind = "function" },
	{ 11, "print", "call", kind = "function" },
	{ 14, "B", "extends", kind = "type" },
	{ 14, "B", false, kind = "variable" },
	{ 15, "field", "call", kind = "function" },
	{ 18, "staticmethod", "decorator", kind = "function" },
	{ 20, "Thing", "parameter_declaration", kind = "unknown" },
	{ 20, "Thing", false, kind = "variable" },
	{ 21, "Thing", "variable_declaration", kind = "type" },
	{ 21, "Thing", "new", nth = 2, kind = "type" },
	{ 21, "Thing", "call", nth = 2, kind = "unknown" },
	{ 22, "refresh", "call", kind = "function" },
	{ 23, "name", "keyword_argument", kind = "variable" },
	{ 24, "Thing", "instanceof", kind = "type" },
	{ 24, "Thing", false, kind = "variable" },
	{ 28, "AppError", "catch", kind = "type" },
	{ 28, "AppError", false, kind = "function" },
	{ 36, "Thing", "return_type", kind = "type" },
	{ 40, "Meta", "new", kind = "type" },
	{ 42, "Thing", "pattern", kind = "type" },
	{ 42, "name", "pattern", kind = "field" },
}

---@param line string
---@param needle string
---@param occurrence integer
---@return integer
local function find_column(line, needle, occurrence)
	local from = 1
	local seen = 0
	while true do
		local start, finish = line:find(needle, from, true)
		assert(start, ("missing case needle %q"):format(needle))
		local before = line:sub(start - 1, start - 1)
		local after = line:sub(finish + 1, finish + 1)
		if not before:match("[%w_]") and not after:match("[%w_]") then
			seen = seen + 1
			if seen == occurrence then
				return start - 1
			end
		end
		from = finish + 1
	end
end

local path = "tests/unit/references/usage_cases/python/usages.py"
local lines = vim.fn.readfile(path)
local raw_by_position = {}
for _, case in ipairs(DESCRIPTORS) do
	local key = table.concat({ case[1], case[2], case.nth or 1 }, ":")
	if case.kind == nil then
		raw_by_position[key] = case[3] or "read"
	end
end

local cases = vim.tbl_map(function(case)
	local key = table.concat({ case[1], case[2], case.nth or 1 }, ":")
	local expected = case[3] or false
	local query_expected = raw_by_position[key] or (expected == "new" and "call" or expected) or "read"
	return {
		line = case[1] - 1,
		character = find_column(lines[case[1]], case[2], case.nth or 1),
		expected = query_expected,
		query_expected = query_expected,
		refined_expected = expected,
		kind = case.kind,
	}
end, DESCRIPTORS)

return {
	filetype = "python",
	source = table.concat(lines, "\n") .. "\n",
	cases = cases,
}
