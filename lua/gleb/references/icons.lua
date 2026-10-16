-- Find Usages icons pair semantic glyph colours with softer labels derived from the active palette.
local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")
local color = require("gleb.colors.gruvbox-material.util")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local LABEL_PALENESS = 0.7
local PRODUCTION_ICON = ""
local TEST_ICON = ""
local FOLDER_ICON = "󰉖"

---@class gleb.references.Icon
---@field icon string
---@field icon_group string
---@field label_group string

---@type table<string, true>
local file_icons = {}

---@param icon_color string
---@param foreground string
---@return string
function M.label_color(icon_color, foreground)
	return color.blend(icon_color, foreground, LABEL_PALENESS)
end

---@param icon_group string
---@return string
local function file_label_group(icon_group)
	return "ReferencesFileLabel" .. icon_group:gsub("[^%w_]", "_")
end

local function setup_highlights()
	local foreground = palette.foreground
	local background = palette.background
	local groups = {
		ReferencesProduction = foreground.aqua,
		ReferencesTest = foreground.yellow,
		ReferencesFolder = background.bg5,
	}

	for group, icon_color in pairs(groups) do
		vim.api.nvim_set_hl(0, group, { fg = icon_color })
		vim.api.nvim_set_hl(0, group .. "Label", { fg = M.label_color(icon_color, foreground.fg1) })
	end

	for group in pairs(file_icons) do
		local icon_color = string.format("#%06x", vim.api.nvim_get_hl(0, { name = group }).fg)
		vim.api.nvim_set_hl(0, file_label_group(group), { fg = M.label_color(icon_color, foreground.fg1) })
	end
end

---@param path string
---@return gleb.references.Icon
local function usage_icon(path)
	local name = vim.fs.basename(path)
	local extension = name:match("%.([^.]*)$")
	local icon, icon_group = devicons.get_icon(name, extension, { default = true })
	local _, icon_color = devicons.get_icon_color(name, extension, { default = true })
	file_icons[icon_group] = true
	local label_group = file_label_group(icon_group)
	vim.api.nvim_set_hl(0, label_group, { fg = M.label_color(icon_color, palette.foreground.fg1) })
	return { icon = icon, icon_group = icon_group, label_group = label_group }
end

---@param node gleb.references.TreeNode
---@return gleb.references.Icon
function M.for_node(node)
	if node.kind == "scope" and node.label == "Production" then
		return {
			icon = PRODUCTION_ICON,
			icon_group = "ReferencesProduction",
			label_group = "ReferencesProductionLabel",
		}
	end
	if node.kind == "scope" then
		return { icon = TEST_ICON, icon_group = "ReferencesTest", label_group = "ReferencesTestLabel" }
	end
	if node.kind == "folder" then
		return { icon = FOLDER_ICON, icon_group = "ReferencesFolder", label_group = "ReferencesFolderLabel" }
	end
	assert(has_devicons, "nvim-web-devicons is required for reference usage icons")
	return usage_icon(node.path or node.label)
end

---@return nil
function M.setup()
	setup_highlights()
	local group = vim.api.nvim_create_augroup("gleb_references_icons", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_highlights })
end

return M
