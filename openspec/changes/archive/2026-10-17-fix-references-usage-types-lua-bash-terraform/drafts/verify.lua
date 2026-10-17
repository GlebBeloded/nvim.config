-- Verify queries/<lang>/usages.scm against fixture expectations.
-- Run: nvim --clean --headless --cmd 'set rtp^=~/.local/share/nvim/site' --cmd 'set rtp^=<this dir>' -l verify.lua
local root_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local fixtures = root_dir .. "/fixtures"
local failures = 0

---@class UsageResult
---@field type string Usage type id of the lowest-index pattern capturing a node at this start
---@field first_seen string Usage type of the first capture yielded by iter_captures
---@field kind "write"|"read" kind_ts-compatible kind: write when any @usage.write matched

---@param source string
---@param lang string
---@return table<string, UsageResult>
local function classify(source, lang)
	local query = vim.treesitter.query.get(lang, "usages")
	assert(query, "no usages query for " .. lang)
	local tree = vim.treesitter.get_string_parser(source, lang):parse()[1]
	local results, best = {}, {}
	for id, node, _, match in query:iter_captures(tree:root(), source, 0, -1) do
		local name = query.captures[id]
		local usage = name:match("^usage%.(.+)$")
		if usage then
			local row, col = node:range()
			local key = row .. ":" .. col
			local _, pattern = match:info()
			local result = results[key]
			if not result then
				result = { type = usage, first_seen = usage, kind = "read" }
				results[key] = result
				best[key] = pattern
			elseif pattern < best[key] then
				result.type, best[key] = usage, pattern
			end
			if usage == "write" then
				result.kind = "write"
			end
		end
	end
	return results
end

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n") .. "\n"
end

---@param label string
---@param ok boolean
---@param detail string
local function report(label, ok, detail)
	if not ok then
		failures = failures + 1
	end
	print(("%s %s %s"):format(ok and "PASS" or "FAIL", label, detail))
end

---@param file string
---@param lang string
---@param expected {[1]: integer, [2]: integer, [3]: string|false, [4]: string}[] row, col (0-based), type (false = unclassified), text at position
local function check(file, lang, expected)
	local source = read(fixtures .. "/" .. file)
	local lines = vim.split(source, "\n", { plain = true })
	local results = classify(source, lang)
	for _, case in ipairs(expected) do
		local row, col, want, text = case[1], case[2], case[3], case[4]
		local at = (lines[row + 1] or ""):sub(col + 1, col + #text)
		local result = results[row .. ":" .. col]
		local got = result and result.type or false
		local precedence_ok = not result or result.first_seen == result.type
		local label = ("%s[%s] %d:%d %-12q"):format(file, lang, row, col, text)
		local detail = ("want=%s got=%s"):format(tostring(want), tostring(got))
		if at ~= text then
			detail = detail .. (" TEXT MISMATCH (found %q)"):format(at)
		end
		if not precedence_ok then
			detail = detail .. (" ORDER first_seen=%s"):format(result.first_seen)
		end
		report(label, at == text and got == want and precedence_ok, detail)
	end
end

-- kind_ts parity: every named leaf start must keep kind_ts's write/read, except listed extensions.
---@param file string
---@param lang string
---@param ts_lang string kind_ts language key
---@param extensions table<string, boolean> "row:col" positions intentionally promoted to write
local function parity(file, lang, ts_lang, extensions)
	local kind_ts = dofile(vim.fn.expand("~/.config/nvim/lua/gleb/references/kind_ts.lua"))
	local source = read(fixtures .. "/" .. file)
	local tree = vim.treesitter.get_string_parser(source, lang):parse()[1]
	local positions, seen = {}, {}
	local function collect(node)
		if node:named_child_count() == 0 and node:named() then
			local row, col = node:range()
			local key = row .. ":" .. col
			if not seen[key] then
				seen[key] = true
				table.insert(positions, { line = row, character = col })
			end
		end
		for child in node:iter_children() do
			collect(child)
		end
	end
	collect(tree:root())
	local old = kind_ts.classify(source, ts_lang, positions)
	local new = classify(source, lang)
	local diffs, unexpected = {}, 0
	for index, position in ipairs(positions) do
		local key = position.line .. ":" .. position.character
		local new_kind = new[key] and new[key].kind or "read"
		if old[index] ~= new_kind then
			local allowed = extensions[key] and old[index] == "read" and new_kind == "write"
			if not allowed then
				unexpected = unexpected + 1
			end
			table.insert(diffs, ("%s %s->%s%s"):format(key, old[index], new_kind, allowed and "" or " UNEXPECTED"))
		end
	end
	report(
		("parity %s[%s]"):format(file, lang),
		unexpected == 0,
		("%d leaves, diffs: %s"):format(#positions, #diffs == 0 and "none" or table.concat(diffs, ", "))
	)
end

---@param keys string[]
---@return table<string, boolean>
local function set(keys)
	local result = {}
	for _, key in ipairs(keys) do
		result[key] = true
	end
	return result
end

check("lua/shop/cart.lua", "lua", {
	{ 0, 6, "write", "price" },
	{ 0, 14, "call", "require" },
	{ 0, 23, false, "shop.price" }, -- lua_ls returns no references inside require strings
	{ 1, 6, "write", "M" },
	{ 3, 10, false, "items" }, -- LuaCATS ---@param name: comment is one leaf
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
	{ 17, 11, "function_declaration", "function" }, -- lua_ls also reports the function value
	{ 17, 20, "parameter_declaration", "value" },
	{ 18, 15, "call", "format" },
	{ 18, 23, false, "%.2f" }, -- plain string, not require
	{ 21, 6, "write", "defaults" },
	{ 22, 1, "field_initialization", "total" },
	{ 23, 1, "function_declaration", "format" },
	{ 23, 10, "function_declaration", "function" },
	{ 23, 19, "parameter_declaration", "v" },
	{ 26, 2, "read", "price" },
	{ 26, 8, "read", "key" },
	{ 27, 2, "read", "KEY" }, -- computed key [KEY] is not a field initialisation
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
	{ 36, 12, "read", "cart" }, -- positional table item is not a field initialisation
	{ 39, 2, "write", "cache" },
	{ 39, 9, "write", "report_count" },
	{ 40, 6, "function_declaration", "handler" },
	{ 40, 16, "function_declaration", "function" },
	{ 41, 6, "write", "first" },
	{ 41, 13, "write", "second" },
	{ 42, 7, "read", "M" },
})
check("lua/shop/price.lua", "lua", {
	{ 2, 2, "write", "key" },
	{ 4, 11, "function_declaration", "of" },
	{ 4, 14, "parameter_declaration", "item" },
	{ 5, 13, "read", "price" },
})
parity("lua/shop/cart.lua", "lua", "lua", set({ "6:5", "6:8", "13:6", "17:2", "39:2" }))
parity("lua/shop/price.lua", "lua", "lua", set({ "2:2" }))

check("bash/deploy.sh", "bash", {
	{ 1, 0, "call", "source" },
	{ 1, 7, false, "./lib.sh" }, -- bashls returns no references on source paths
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
	{ 13, 14, false, "${hosts[@]}" }, -- bashls ranges start at the name
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
	{ 22, 7, "read", "answer" }, -- unset: no dedicated type
	{ 25, 9, "function_declaration", "cleanup" },
	{ 26, 1, "call", "greet" },
	{ 26, 9, "read", "region" },
	{ 29, 0, "call", "deploy" },
	{ 29, 23, false, "log" }, -- plain argument word
	{ 30, 0, "call", "cleanup" },
})
check("bash/lib.sh", "bash", {
	{ 1, 0, "function_declaration", "greet" },
	{ 2, 14, "read", "1" },
})
parity("bash/deploy.sh", "bash", "bash", set({ "7:11", "13:5", "17:9", "20:1", "21:4" }))

---@param lang string
local function check_terraform(lang)
	check("tf/main.tf", lang, {
		{ 0, 9, "variable_declaration", '"region"' },
		{ 0, 10, "variable_declaration", "region" },
		{ 1, 2, "read", "type" },
		{ 1, 9, "read", "string" },
		{ 4, 10, "variable_declaration", "tags" },
		{ 9, 2, "local_declaration", "name" },
		{ 9, 18, "read", "var" },
		{ 9, 22, "read", "region" },
		{ 10, 2, "local_declaration", "common" },
		{ 10, 11, "read", "merge" },
		{ 10, 17, "read", "var" },
		{ 10, 21, "read", "tags" },
		{ 10, 29, "read", "region" }, -- object key, not a reference
		{ 10, 38, "read", "var" },
		{ 10, 42, "read", "region" },
		{ 13, 8, "module_declaration", "net" },
		{ 14, 2, "read", "source" }, -- module meta-argument
		{ 15, 2, "attribute_assignment", "cidr" },
		{ 15, 11, "read", "var" },
		{ 15, 15, "read", "region" },
		{ 18, 10, false, "aws_s3_bucket" }, -- resource type label
		{ 18, 26, "resource_declaration", "logs" },
		{ 19, 2, "read", "bucket" },
		{ 19, 11, "local_reference", "local" },
		{ 19, 17, "local_reference", "name" },
		{ 20, 17, "local_reference", "common" },
		{ 22, 16, "depends_on", "module" },
		{ 22, 23, "depends_on", "net" },
		{ 22, 28, "depends_on", "data" },
		{ 22, 33, "depends_on", "aws_ami" },
		{ 22, 41, "depends_on", "base" },
		{ 25, 16, "data_declaration", "base" },
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
		{ 35, 8, "output_declaration", "bucket_arn" },
		{ 36, 16, "output", "aws_s3_bucket" },
		{ 36, 30, "output", "logs" },
		{ 37, 26, "read", "var" }, -- output description, not value
		{ 37, 30, "read", "region" },
		{ 41, 12, "read", "name" }, -- object key
		{ 41, 19, "output", "local" },
		{ 41, 25, "output", "name" },
		{ 41, 37, "output", "module" },
		{ 41, 44, "output", "net" },
		{ 41, 48, "output", "vpc_id" },
		{ 45, 21, "resource_reference", "aws_s3_bucket" }, -- two levels deep: falls back
		{ 45, 35, "resource_reference", "logs" },
	})
	check("tf/net/main.tf", lang, {
		{ 0, 10, "variable_declaration", "cidr" },
		{ 4, 8, "output_declaration", "vpc_id" },
		{ 5, 17, "read", "var" }, -- input variable in an output value stays a read
		{ 5, 21, "read", "cidr" },
	})
	parity("tf/main.tf", lang, "hcl", {})
	parity("tf/net/main.tf", lang, "hcl", {})
end
check_terraform("hcl")
check_terraform("terraform")

print(failures == 0 and "ALL PASS" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
