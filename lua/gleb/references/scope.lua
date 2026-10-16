-- Classify reference paths consistently so consumers can separate production and test usages.
local M = {}

---@type table<string, string[]>
local PATTERNS = {
	go = { "_test%.go$" },
	typescript = { "%.test%.[^/]+$", "%.spec%.[^/]+$", "/__tests__/" },
	typescriptreact = { "%.test%.[^/]+$", "%.spec%.[^/]+$", "/__tests__/" },
	javascript = { "%.test%.[^/]+$", "%.spec%.[^/]+$", "/__tests__/" },
	javascriptreact = { "%.test%.[^/]+$", "%.spec%.[^/]+$", "/__tests__/" },
	python = { "/test_[^/]*%.py$", "/[^/]*_test%.py$", "/conftest%.py$", "/tests/" },
	lua = { "_spec%.lua$", "/spec/", "/tests/" },
	rust = { "/tests/" },
	sh = { "%.bats$", "/test/", "/tests/" },
	bash = { "%.bats$", "/test/", "/tests/" },
	terraform = { "%.tftest%.hcl$", "/tests/" },
}

---@type table<string, boolean>
local GENERIC_SEGMENTS = {
	test = true,
	tests = true,
	spec = true,
	__tests__ = true,
}

---@param path string
---@param patterns string[]?
---@return boolean
local function matches_any(path, patterns)
	for _, pattern in ipairs(patterns or {}) do
		if path:find(pattern) then
			return true
		end
	end
	return false
end

---@param path string
---@return boolean
local function has_generic_segment(path)
	for segment in path:gmatch("[^/]+") do
		if GENERIC_SEGMENTS[segment] then
			return true
		end
	end
	return false
end

---@param path string
---@param filetype string?
---@return boolean
function M.is_test(path, filetype)
	local normalized = "/" .. path:gsub("\\", "/")
	local resolved_filetype = filetype or vim.filetype.match({ filename = path })
	if matches_any(normalized, PATTERNS[resolved_filetype or ""]) then
		return true
	end

	local extensions = vim.g.gleb_test_patterns
	if type(extensions) == "table" and matches_any(normalized, extensions[resolved_filetype or ""]) then
		return true
	end

	return has_generic_segment(normalized)
end

---@param node TSNode
---@param text string
---@return boolean
local function is_cfg_test_module(node, text)
	local start_row, _, end_row, end_col = node:range()
	local lines = vim.split(text, "\n", { plain = true })
	local fragments = {}
	local last_line = end_row + (end_col > 0 and 1 or 0)
	for index = start_row + 1, last_line do
		table.insert(fragments, lines[index])
	end
	local module_text = table.concat(fragments, "\n")
	return module_text:find("^%s*#%s*%[%s*cfg%s*%(%s*test%s*%)%s*%]") ~= nil
end

---@param text string
---@param lnum integer
---@return boolean
local function is_rust_inline_test(text, lnum)
	local ok, result = pcall(function()
		local parser = vim.treesitter.get_string_parser(text, "rust")
		local tree = parser:parse()[1]
		local node = tree:root():descendant_for_range(lnum - 1, 0, lnum - 1, 0)
		while node do
			if node:type() == "mod_item" and is_cfg_test_module(node, text) then
				return true
			end
			node = node:parent()
		end
		return false
	end)
	return ok and result == true
end

---@param path string
---@param lnum integer
---@param text string
---@return boolean
function M.is_test_at(path, lnum, text)
	if M.is_test(path) then
		return true
	end
	if vim.filetype.match({ filename = path }) ~= "rust" then
		return false
	end
	return is_rust_inline_test(text, lnum)
end

return M
