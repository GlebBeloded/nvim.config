-- Terraform usage-query cases ported from the change's parser-verified draft.
local ROOT = "tests/unit/references/usage_cases/terraform/"

---@param file string
---@param filetype string
---@param descriptors {[1]: integer, [2]: integer, [3]: string|false, [4]: string}[]
---@return table
local function suite(file, filetype, descriptors)
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
	return { filetype = filetype, source = source, cases = cases }
end

local main_cases = {
	{ 0, 9, false, '"region"' },
	{ 0, 10, "write", "region" },
	{ 1, 2, "read", "type" },
	{ 1, 9, "read", "string" },
	{ 4, 10, "write", "tags" },
	{ 9, 2, "variable_declaration", "name" },
	{ 9, 18, "read", "var" },
	{ 9, 22, "read", "region" },
	{ 10, 2, "variable_declaration", "common" },
	{ 10, 11, "read", "merge" },
	{ 10, 17, "read", "var" },
	{ 10, 21, "read", "tags" },
	{ 10, 29, "read", "region" },
	{ 10, 38, "read", "var" },
	{ 10, 42, "read", "region" },
	{ 13, 8, false, "net" },
	{ 14, 2, "read", "source" },
	{ 15, 2, "attribute_assignment", "cidr" },
	{ 15, 11, "read", "var" },
	{ 15, 15, "read", "region" },
	{ 18, 10, false, "aws_s3_bucket" },
	{ 18, 26, false, "logs" },
	{ 19, 2, "read", "bucket" },
	{ 19, 11, "local_reference", "local" },
	{ 19, 17, "local_reference", "name" },
	{ 20, 17, "local_reference", "common" },
	{ 22, 16, "depends_on", "module" },
	{ 22, 23, "depends_on", "net" },
	{ 22, 28, "depends_on", "data" },
	{ 22, 33, "depends_on", "aws_ami" },
	{ 22, 41, "depends_on", "base" },
	{ 25, 16, false, "base" },
	{ 26, 12, "read", "var" },
	{ 26, 16, "read", "region" },
	{ 30, 14, "data_reference", "data" },
	{ 30, 19, "data_reference", "aws_ami" },
	{ 30, 27, "data_reference", "base" },
	{ 30, 32, "read", "id" },
	{ 31, 14, "module_reference", "module" },
	{ 31, 21, "module_reference", "net" },
	{ 31, 25, "module_reference", "vpc_id" },
	{ 32, 16, "read", "bucket" },
	{ 32, 25, "resource_reference", "aws_s3_bucket" },
	{ 32, 39, "resource_reference", "logs" },
	{ 32, 44, "read", "arn" },
	{ 32, 55, "read", "var" },
	{ 32, 59, "read", "tags" },
	{ 35, 8, false, "bucket_arn" },
	{ 36, 16, "output", "aws_s3_bucket" },
	{ 36, 30, "output", "logs" },
	{ 37, 26, "read", "var" },
	{ 37, 30, "read", "region" },
	{ 41, 12, "read", "name" },
	{ 41, 19, "output", "local" },
	{ 41, 25, "output", "name" },
	{ 41, 37, "output", "module" },
	{ 41, 44, "output", "net" },
	{ 41, 48, "output", "vpc_id" },
	{ 45, 21, "resource_reference", "aws_s3_bucket" },
	{ 45, 35, "resource_reference", "logs" },
}

local module_cases = {
	{ 0, 10, "write", "cidr" },
	{ 4, 8, false, "vpc_id" },
	{ 5, 17, "read", "var" },
	{ 5, 21, "read", "cidr" },
}

return {
	suites = {
		suite("main.tf", "hcl", main_cases),
		suite("net/main.tf", "hcl", module_cases),
		suite("main.tf", "terraform", main_cases),
		suite("net/main.tf", "terraform", module_cases),
	},
}
