-- Shared framed text input: keep MiniPick's editing while rendering one query-derived preview row.

local M = {}

local ok, MiniPick = pcall(require, "mini.pick")
if not ok then
	return M
end

local frame = require("gleb.picker.frame")
local layout = require("gleb.picker.layout")

---@class gleb.picker.InputOpts
---@field title string
---@field default? string
---@field preview fun(query: string): gleb.picker.Row
---@field hint string
---@field on_submit fun(query: string)

---@return gleb.picker.WindowConfig
local function window_config()
	local config = layout.window_config()
	config.height = 3
	return config
end

---@param _stritems string[]
---@param inds integer[]
---@param _query string[]
---@return integer[]
local function keep_preview(_stritems, inds, _query)
	return inds
end

---@param query string
---@return string[]
local function query_characters(query)
	return vim.fn.split(query, "\\zs")
end

---@param win integer
---@param guicursor string
---@param on_restored fun()
local function after_teardown(win, guicursor, on_restored)
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
			vim.o.guicursor = guicursor
		end
		on_restored()
	end)
end

---@param opts gleb.picker.InputOpts
---@return nil
function M.open(opts)
	local origin_win = vim.api.nvim_get_current_win()
	local origin_guicursor = vim.o.guicursor
	local submitted_query
	local picker_opts = frame.options(opts.title, opts.hint, window_config)
	local show_frame = picker_opts.source.show

	picker_opts.source = vim.tbl_extend("force", picker_opts.source, {
		items = { { text = "" } },
		match = keep_preview,
		show = function(buf, _items, query)
			show_frame(buf, { opts.preview(table.concat(query)) }, query)
		end,
	})
	picker_opts.mappings = {
		submit_input = {
			char = "<CR>",
			func = function()
				local query = vim.trim(table.concat(MiniPick.get_picker_query() or {}))
				if query == "" then
					return false
				end
				submitted_query = query
				return true
			end,
		},
	}

	if opts.default and opts.default ~= "" then
		vim.schedule(function()
			MiniPick.set_picker_query(query_characters(opts.default --[[@as string]]))
		end)
	end

	MiniPick.start(picker_opts)
	after_teardown(origin_win, origin_guicursor, function()
		if submitted_query then
			opts.on_submit(submitted_query --[[@as string]])
		end
	end)
end

return M
