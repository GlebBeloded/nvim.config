-- Reference row formatting keeps tree labels, tags, truncation, and highlights consistent.
local M = {}

local icons = require("gleb.references.icons")
local usage_types = require("gleb.references.usage_types")

local namespace = vim.api.nvim_create_namespace("gleb_references_view")

---@class gleb.references.Segment
---@field text string
---@field group? string

---@param node gleb.references.TreeNode
---@param folded table<string, boolean>
---@return gleb.references.Segment[]
local function group_segments(node, folded)
	local icon = icons.for_node(node)
	local indent = string.rep(" ", math.max(node.depth, node.kind == "folder" and 1 or 0) * 2)
	return {
		{ text = indent .. (folded[node.id] and "▸" or "▾") .. " " },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = node.label, group = icon.label_group },
		{ text = "  " },
		{ text = tostring(node.count), group = "PickerSecondary" },
	}
end

---@param node gleb.references.TreeNode
---@return gleb.references.Segment[]
local function usage_segments(node)
	local icon = icons.for_node(node)
	local file, line = node.label:match("^(.*)(:%d+)$")
	local indent = node.flat_path and node.depth * 2 or node.depth * 2 + 2
	return {
		{ text = node.depth == 0 and "" or string.rep(" ", indent) },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = file or node.label, group = icon.label_group },
		{ text = line or "", group = "PickerSecondary" },
	}
end

---@param segments gleb.references.Segment[]
---@return string
function M.text(segments)
	return table.concat(vim.tbl_map(function(segment)
		return segment.text
	end, segments))
end

---@param text string
---@param width integer
---@return string
local function shorten_left(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	if width <= 1 then
		return "…"
	end
	local suffix = text
	while suffix ~= "" and vim.fn.strdisplaywidth("…" .. suffix) > width do
		suffix = vim.fn.strcharpart(suffix, 1)
	end
	return "…" .. suffix
end

---@param segments gleb.references.Segment[]
---@param width? integer text width the test tag is right-aligned to
local function add_test_tag(segments, width)
	local icon = icons.for_node({ kind = "scope", id = "scope:test", label = "Test", depth = 0 })
	local tag_width = vim.fn.strdisplaywidth(icon.icon .. " test")
	if width then
		local fixed_width = vim.fn.strdisplaywidth(M.text(segments)) - vim.fn.strdisplaywidth(segments[4].text)
		segments[4].text = shorten_left(segments[4].text, math.max(width - fixed_width - tag_width - 1, 1))
	end
	local line_width = vim.fn.strdisplaywidth(M.text(segments))
	vim.list_extend(segments, {
		{ text = string.rep(" ", math.max((width or 0) - line_width - tag_width, 1)) },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = "test", group = icon.label_group },
	})
end

---@param segments gleb.references.Segment[]
---@param type_id string
---@param width? integer
local function add_type_tag(segments, type_id, width)
	local entry = assert(usage_types[type_id], "unknown reference usage type")
	local icon = icons.for_node({
		kind = "type",
		id = "type:tag:" .. type_id,
		label = entry.label,
		depth = 0,
		usage_type = type_id,
	})
	local tag_width = vim.fn.strdisplaywidth(icon.icon .. " " .. entry.tag)
	if width then
		local fixed_width = vim.fn.strdisplaywidth(M.text(segments)) - vim.fn.strdisplaywidth(segments[4].text)
		segments[4].text = shorten_left(segments[4].text, math.max(width - fixed_width - tag_width - 2, 1))
	end
	local line_width = vim.fn.strdisplaywidth(M.text(segments))
	vim.list_extend(segments, {
		{ text = string.rep(" ", math.max((width or 0) - line_width - tag_width, 2)) },
		{ text = icon.icon, group = icon.icon_group },
		{ text = " " },
		{ text = entry.tag, group = icon.label_group },
	})
end

---@param node gleb.references.TreeNode
---@param folded table<string, boolean>
---@param width? integer
---@return gleb.references.Segment[]
function M.tree_segments(node, folded, width)
	if node.kind ~= "usage" then
		return group_segments(node, folded)
	end
	local segments = usage_segments(node)
	if node.test_tag then
		add_test_tag(segments, width)
	end
	if node.type_tag then
		add_type_tag(segments, node.type_tag, width)
	end
	return segments
end

---@param buf integer
---@param row integer 0-based
---@param segments gleb.references.Segment[]
---@return nil
function M.highlight(buf, row, segments)
	local col = 0
	for _, segment in ipairs(segments) do
		if segment.group and segment.text ~= "" then
			vim.api.nvim_buf_set_extmark(
				buf,
				namespace,
				row,
				col,
				{ end_col = col + #segment.text, hl_group = segment.group }
			)
		end
		col = col + #segment.text
	end
end

---@param buf integer
---@return nil
function M.clear_highlights(buf)
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
end

return M
