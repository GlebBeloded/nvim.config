-- Build a stable, presentation-ready usage tree independently from the references view.
local M = {}

local scope = require("gleb.references.scope")

---@class gleb.references.Usage
---@field uri string
---@field path string
---@field lnum integer
---@field col integer
---@field filetype? string
---@field range? lsp.Range
---@field client_id? integer
---@field kind? "write"|"read"|"other"

---@class gleb.references.TreeOptions
---@field tests "grouped"|"hidden"|"mixed"
---@field folders boolean
---@field read_write boolean

---@class gleb.references.TreeNode
---@field id string
---@field kind "scope"|"kind"|"folder"|"usage"
---@field label string
---@field depth integer
---@field count? integer
---@field parent_id? string
---@field uri? string
---@field path? string
---@field lnum? integer
---@field col? integer
---@field filetype? string
---@field test? boolean
---@field test_tag? boolean
---@field usage_kind? "write"|"read"|"other"
---@field kind_tag? "write"|"read"

---@class gleb.references.Tree
---@field nodes gleb.references.TreeNode[]
---@field count integer
---@field selected_id? string
---@field has_kinds boolean

---@class gleb.references.ClassifiedUsage: gleb.references.Usage
---@field test boolean
---@field usage_kind? "write"|"read"|"other"

---@param usage gleb.references.Usage
---@return string
local function usage_id(usage)
	return string.format("usage:%s:%d:%d", usage.uri, usage.lnum, usage.col)
end

---@param path string
---@return string
local function directory(path)
	return path:match("^(.*)/[^/]+$") or "."
end

---@param path string
---@return string
local function basename(path)
	return path:match("([^/]+)$") or path
end

---@param left gleb.references.ClassifiedUsage
---@param right gleb.references.ClassifiedUsage
---@return boolean
local function usage_less_than(left, right)
	if left.path ~= right.path then
		return left.path < right.path
	end
	if left.lnum ~= right.lnum then
		return left.lnum < right.lnum
	end
	if left.col ~= right.col then
		return left.col < right.col
	end
	return left.uri < right.uri
end

---@param usage gleb.references.Usage
---@return boolean
local function is_test_usage(usage)
	if scope.is_test(usage.path, usage.filetype) then
		return true
	end
	local filetype = usage.filetype or vim.filetype.match({ filename = usage.path })
	if filetype ~= "rust" then
		return false
	end

	local filename = vim.uri_to_fname(usage.uri)
	local buf = vim.fn.bufnr(filename)
	local lines
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	else
		local ok, disk_lines = pcall(vim.fn.readfile, filename)
		lines = ok and disk_lines or {}
	end
	return scope.is_test_at(usage.path, usage.lnum, table.concat(lines, "\n"))
end

---@param usages gleb.references.Usage[]
---@param tests_mode "grouped"|"hidden"|"mixed"
---@return gleb.references.ClassifiedUsage[]
local function classify(usages, tests_mode)
	local result = {}
	for _, usage in ipairs(usages) do
		local is_test = is_test_usage(usage)
		if tests_mode ~= "hidden" or not is_test then
			table.insert(result, {
				uri = usage.uri,
				path = usage.path,
				lnum = usage.lnum,
				col = usage.col,
				filetype = usage.filetype,
				test = is_test,
				usage_kind = usage.kind,
			})
		end
	end
	table.sort(result, usage_less_than)
	return result
end

---@param usage gleb.references.ClassifiedUsage
---@param depth integer
---@param parent_id string?
---@param show_path boolean
---@param mixed boolean
---@param tagged boolean
---@return gleb.references.TreeNode
local function usage_node(usage, depth, parent_id, show_path, mixed, tagged)
	local path = show_path and usage.path or basename(usage.path)
	local node = {
		id = usage_id(usage),
		kind = "usage",
		label = string.format("%s:%d", path, usage.lnum),
		depth = depth,
		parent_id = parent_id,
		uri = usage.uri,
		path = usage.path,
		lnum = usage.lnum,
		col = usage.col,
		filetype = usage.filetype,
		test = usage.test,
		usage_kind = usage.usage_kind,
	}
	if mixed then
		node.test_tag = usage.test
	end
	if tagged and (usage.usage_kind == "write" or usage.usage_kind == "read") then
		node.kind_tag = usage.usage_kind
	end
	return node
end

---@param nodes gleb.references.TreeNode[]
---@param usages gleb.references.ClassifiedUsage[]
---@param scope_name string
---@param depth integer
---@param parent_id string?
---@param mixed boolean
---@param tagged boolean
local function append_folders(nodes, usages, scope_name, depth, parent_id, mixed, tagged)
	local index = 1
	while index <= #usages do
		local folder = directory(usages[index].path)
		local last = index
		while last < #usages and directory(usages[last + 1].path) == folder do
			last = last + 1
		end

		local folder_id = string.format("folder:%s:%s", scope_name, folder)
		table.insert(nodes, {
			id = folder_id,
			kind = "folder",
			label = folder,
			count = last - index + 1,
			depth = depth,
			parent_id = parent_id,
		})
		for usage_index = index, last do
			table.insert(nodes, usage_node(usages[usage_index], depth + 1, folder_id, false, mixed, tagged))
		end
		index = last + 1
	end
end

---@param nodes gleb.references.TreeNode[]
---@param usages gleb.references.ClassifiedUsage[]
---@param scope_name string
---@param depth integer
---@param parent_id string?
---@param options gleb.references.TreeOptions
---@param tagged boolean
local function append_flat_usages(nodes, usages, scope_name, depth, parent_id, options, tagged)
	if options.folders then
		append_folders(nodes, usages, scope_name, depth, parent_id, options.tests == "mixed", tagged)
		return
	end
	for _, usage in ipairs(usages) do
		table.insert(nodes, usage_node(usage, depth, parent_id, true, options.tests == "mixed", tagged))
	end
end

local KIND_GROUPS = {
	{ kind = "write", label = "Value write" },
	{ kind = "read", label = "Value read" },
	{ kind = "other", label = "Usage" },
}

---@param nodes gleb.references.TreeNode[]
---@param usages gleb.references.ClassifiedUsage[]
---@param scope_name string
---@param depth integer
---@param parent_id string?
---@param options gleb.references.TreeOptions
---@param has_kinds boolean
local function append_usages(nodes, usages, scope_name, depth, parent_id, options, has_kinds)
	if not has_kinds or not options.read_write then
		append_flat_usages(nodes, usages, scope_name, depth, parent_id, options, has_kinds)
		return
	end
	for _, group in ipairs(KIND_GROUPS) do
		local grouped = vim.tbl_filter(function(usage)
			return (usage.usage_kind or "other") == group.kind
		end, usages)
		if #grouped > 0 then
			local id = string.format("kind:%s:%s", scope_name, group.kind)
			table.insert(nodes, {
				id = id,
				kind = "kind",
				label = group.label,
				count = #grouped,
				depth = depth,
				parent_id = parent_id,
				usage_kind = group.kind,
			})
			append_flat_usages(nodes, grouped, scope_name .. ":" .. group.kind, depth + 1, id, options, false)
		end
	end
end

---@param nodes gleb.references.TreeNode[]
---@param usages gleb.references.ClassifiedUsage[]
---@param is_test boolean
---@param options gleb.references.TreeOptions
---@param has_kinds boolean
local function append_scope(nodes, usages, is_test, options, has_kinds)
	local scoped = {}
	for _, usage in ipairs(usages) do
		if usage.test == is_test then
			table.insert(scoped, usage)
		end
	end
	if #scoped == 0 then
		return
	end

	local name = is_test and "test" or "production"
	local id = "scope:" .. name
	table.insert(nodes, {
		id = id,
		kind = "scope",
		label = is_test and "Test" or "Production",
		count = #scoped,
		depth = 0,
	})
	append_usages(nodes, scoped, name, 1, id, options, has_kinds)
end

---@param nodes gleb.references.TreeNode[]
---@param selected gleb.references.Usage?
---@return string?
local function selected_id(nodes, selected)
	local first_usage
	for _, node in ipairs(nodes) do
		if node.kind == "usage" then
			first_usage = first_usage or node.id
			if selected and node.uri == selected.uri and node.lnum == selected.lnum and node.col == selected.col then
				return node.id
			end
		end
	end
	return first_usage
end

---@param usages gleb.references.Usage[]
---@param options gleb.references.TreeOptions
---@param selected? gleb.references.Usage
---@return gleb.references.Tree
function M.build(usages, options, selected)
	local classified = classify(usages, options.tests)
	local has_kinds = vim.iter(classified):any(function(usage)
		return usage.usage_kind == "write" or usage.usage_kind == "read"
	end)
	local nodes = {}
	if options.tests == "mixed" then
		append_usages(nodes, classified, "all", 0, nil, options, has_kinds)
	else
		append_scope(nodes, classified, false, options, has_kinds)
		append_scope(nodes, classified, true, options, has_kinds)
	end

	return {
		nodes = nodes,
		count = #classified,
		selected_id = selected_id(nodes, selected),
		has_kinds = has_kinds,
	}
end

return M
