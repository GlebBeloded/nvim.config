-- `make colorize FILE=<markdown> [CASE=lua-file]`
-- Prints every ```text render of a design doc. A render followed by a mask
-- block and a `Legend:` line (docs/workflow.md, "Design renders") is printed
-- in truecolor: each mask letter is resolved to the fg/bg/bold/italic of its
-- highlight group in the real colorscheme, queried from a headless full-config
-- child after the render case CASE has run (groups created on first draw, like
-- StatuslineLang_lua, then exist). Other renders print plain.

local H = require("tests.helpers")
local cases = require("tests.render.cases")

local M = {}

local RESET = "\27[0m"
local DIM = "\27[2m"

---@class colorize.Fence
---@field info string info string after the backticks
---@field first integer line number of the opening fence
---@field last integer line number of the closing fence
---@field rows string[]

---@class colorize.Render
---@field line integer
---@field caption? string
---@field rows string[]
---@field mask? string[]
---@field legend? table<string, string> mask letter -> highlight group

---@alias colorize.Hl vim.api.keyset.get_hl_info

---@param message string
local function warn(message)
	vim.uv.fs_write(2, "colorize: " .. message .. "\n")
end

-- ── markdown ────────────────────────────────────────────────────────────────

--- Top-level fenced blocks (CommonMark backtick fences, so a ```text inside a
--- ````markdown example is content, not a render).
---@param lines string[]
---@return colorize.Fence[]
local function fences(lines)
	local found, open = {}, nil
	for number, line in ipairs(lines) do
		local ticks, info = line:match("^(```+)%s*(.-)%s*$")
		if open and ticks and #ticks >= open.ticks and info == "" then
			table.insert(found, { info = open.info, first = open.first, last = number, rows = open.rows })
			open = nil
		elseif open then
			table.insert(open.rows, line)
		elseif ticks then
			open = { ticks = #ticks, info = info, first = number, rows = {} }
		end
	end
	return found
end

---@param lines string[]
---@param from integer
---@param to integer
---@return boolean
local function blank_between(lines, from, to)
	for number = from, to do
		if vim.trim(lines[number]) ~= "" then
			return false
		end
	end
	return true
end

---@param lines string[]
---@param from integer
---@return integer? first non-blank line at or after `from`
local function next_text(lines, from)
	for number = from, #lines do
		if vim.trim(lines[number]) ~= "" then
			return number
		end
	end
end

--- Legend paragraph starting at `first`: "Legend: `a` [Group] · `b` [Other]".
---@param lines string[]
---@param first? integer
---@return table<string, string>?
local function legend_at(lines, first)
	if not first or not lines[first]:match("^Legend:") then
		return nil
	end
	local legend = {}
	for number = first, #lines do
		if vim.trim(lines[number]) == "" then
			break
		end
		for letter, group in lines[number]:gmatch("`(.)`%s*%[([^%]]+)%]") do
			legend[letter] = group
		end
	end
	return legend
end

---@param lines string[]
---@param fence colorize.Fence
---@return string?
local function caption_of(lines, fence)
	local number = fence.first - 1
	while number > 0 and vim.trim(lines[number]) == "" do
		number = number - 1
	end
	local line = lines[number]
	return line and line:match("^%*%*") and line or nil
end

--- `fence` is the mask of `render` when it directly follows it, has as many
--- rows and is followed by a Legend line.
---@param lines string[]
---@param render colorize.Fence
---@param fence? colorize.Fence
---@return table<string, string>? legend
local function mask_legend(lines, render, fence)
	if not fence or fence.info ~= "text" or #fence.rows ~= #render.rows then
		return nil
	end
	if not blank_between(lines, render.last + 1, fence.first - 1) then
		return nil
	end
	return legend_at(lines, next_text(lines, fence.last + 1))
end

--- Renders of a markdown document with their masks and legends.
---@param lines string[]
---@return colorize.Render[]
function M.parse(lines)
	local renders, all = {}, fences(lines)
	local index = 1
	while index <= #all do
		local fence = all[index]
		if fence.info == "text" then
			local render = { line = fence.first, caption = caption_of(lines, fence), rows = fence.rows }
			local legend = mask_legend(lines, fence, all[index + 1])
			if legend then
				render.mask, render.legend = all[index + 1].rows, legend
				index = index + 1
			end
			table.insert(renders, render)
		end
		index = index + 1
	end
	return renders
end

-- ── colors ──────────────────────────────────────────────────────────────────

---@param renders colorize.Render[]
---@return string[]
local function legend_groups(renders)
	local groups = { [H.DEFAULT_GROUP] = true }
	for _, render in ipairs(renders) do
		for _, group in pairs(render.legend or {}) do
			groups[group] = true
		end
	end
	return vim.tbl_keys(groups)
end

--- Resolved highlights from the real config (nil for undefined groups).
---@param groups string[]
---@return table<string, colorize.Hl|vim.NIL>
local function resolve(groups)
	local child = H.new_child()
	child.start_config()
	child.wait_very_lazy()
	local case = vim.env.CASE
	cases[(case and case ~= "") and case or "lua-file"].setup(child)
	child.cmd("redraw!")
	local hls = child.lua(
		[[local hls = {}
		for _, name in ipairs(...) do
			hls[name] = vim.fn.hlexists(name) == 1 and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.NIL
		end
		return hls]],
		{ groups }
	)
	child.stop()
	return hls
end

---@param color integer
---@return string
local function rgb(color)
	return ("%d;%d;%d"):format(math.floor(color / 0x10000), math.floor(color / 0x100) % 0x100, color % 0x100)
end

local SGR_FLAGS = { bold = "1", italic = "3", underline = "4", undercurl = "4:3", strikethrough = "9", reverse = "7" }

--- Truecolor SGR escape for a highlight, missing colors taken from `base`.
---@param hl colorize.Hl
---@param base colorize.Hl
---@return string
local function sgr(hl, base)
	local params = { "0" }
	local fg, bg = hl.fg or base.fg, hl.bg or base.bg
	if fg then
		table.insert(params, "38;2;" .. rgb(fg))
	end
	if bg then
		table.insert(params, "48;2;" .. rgb(bg))
	end
	for flag, code in pairs(SGR_FLAGS) do
		if hl[flag] then
			table.insert(params, code)
		end
	end
	return "\27[" .. table.concat(params, ";") .. "m"
end

-- ── output ──────────────────────────────────────────────────────────────────

--- The highlight of `group`, or nil when the group does not exist.
---@param hls table<string, colorize.Hl|vim.NIL>
---@param group string
---@return colorize.Hl?
local function hl_of(hls, group)
	local hl = hls[group]
	if hl == vim.NIL then
		return nil
	end
	-- LuaLS does not narrow on `== vim.NIL`
	return hl --[[@as colorize.Hl]]
end

---@param render colorize.Render
---@param hls table<string, colorize.Hl|vim.NIL>
---@return table<string, string> mask letter -> escape
local function letter_escapes(render, hls)
	local base = hl_of(hls, H.DEFAULT_GROUP) or {}
	local escapes = {}
	for letter, group in pairs(render.legend) do
		local hl = hl_of(hls, group)
		if not hl then
			warn(("line %d: unknown highlight group [%s], shown as %s"):format(render.line, group, H.DEFAULT_GROUP))
			hl = base
		end
		escapes[letter] = sgr(hl, base)
	end
	escapes[""] = sgr(base, base)
	return escapes
end

---@param row string
---@param mask string
---@param escapes table<string, string>
---@return string
local function color_row(row, mask, escapes)
	local cells, letters, out, current = vim.fn.split(row, [[\zs]]), vim.fn.split(mask, [[\zs]]), {}, nil
	for col, cell in ipairs(cells) do
		local letter = letters[col] or ""
		local escape = (H.UNMASKED[letter] or not escapes[letter]) and escapes[""] or escapes[letter]
		if escape ~= current then
			table.insert(out, escape)
			current = escape
		end
		table.insert(out, cell)
	end
	return table.concat(out) .. RESET
end

---@param render colorize.Render
---@param hls table<string, colorize.Hl|vim.NIL>
---@return string[]
local function colored_rows(render, hls)
	local escapes = letter_escapes(render, hls)
	local rows = {}
	for index, row in ipairs(render.rows) do
		if vim.fn.strchars(render.mask[index]) ~= vim.fn.strchars(row) then
			warn(("line %d: mask row %d width differs from the render"):format(render.line, index))
		end
		table.insert(rows, color_row(row, render.mask[index], escapes))
	end
	return rows
end

---@param file string
---@param render colorize.Render
---@param hls? table<string, colorize.Hl|vim.NIL>
local function print_render(file, render, hls)
	local header = ("── %s:%d %s"):format(file, render.line, render.caption or "")
	io.write(DIM .. header .. RESET .. "\n")
	local rows = (render.mask and hls) and colored_rows(render, hls) or render.rows
	io.write(table.concat(rows, "\n") .. "\n\n")
end

---@param file string
local function colorize(file)
	local renders = M.parse(vim.fn.readfile(file))
	local masked = vim.tbl_filter(function(render)
		return render.mask ~= nil
	end, renders)
	local hls = #masked > 0 and resolve(legend_groups(masked)) or nil
	for _, render in ipairs(renders) do
		print_render(file, render, hls)
	end
end

function M.run()
	local file = vim.env.FILE
	local ok, err = true, nil
	if not file or file == "" or vim.fn.filereadable(file) == 0 then
		ok, err = false, "Usage: make colorize FILE=<markdown file> [CASE=<render case priming highlights>]"
	else
		ok, err = pcall(colorize, file)
	end
	if not ok then
		io.write(tostring(err) .. "\n")
	end
	vim.cmd(ok and "qall!" or "cquit 1")
end

return M
