local INDENT = "              "
local EMPTY_ROW = INDENT .. "│                                                                      │"
local QUERY_DASHES = { ["█"] = 54, ["find█"] = 50 }
local KEY_PADDING = { [" █"] = 44, ["⌘D █"] = 42 }
local CONTENT_WIDTH = 68

local function full(background, palette, statusline, below)
	local lines = vim.list_extend(vim.deepcopy(background), palette)
	vim.list_extend(lines, { below or "", "", "", "", "", "", "", "" })
	if statusline then
		lines[#lines] = statusline
	end
	return table.concat(lines, "\n") .. "\n"
end

local function fit(text, width)
	local characters = vim.fn.strchars(text)
	while characters > 0 and vim.fn.strdisplaywidth(text) > width do
		characters = characters - 1
		text = vim.fn.strcharpart(text, 0, characters)
	end
	return text .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(text), 0))
end

local function render_row(row)
	local text
	if row.section then
		local remaining = math.max(CONTENT_WIDTH - vim.fn.strdisplaywidth(row.text) - 1, 0)
		text = row.text .. (remaining > 0 and (" " .. string.rep("─", remaining)) or "")
	else
		local left = row.text .. (row.secondary and ("  " .. row.secondary) or "")
		local right = row.glyph ~= nil and (row.glyph and "●" or "○") or ""
		if row.category then
			right = right == "" and row.category or (right .. " " .. row.category)
		end
		local padding = right == "" and 0
			or math.max(CONTENT_WIDTH - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right), 1)
		text = left .. string.rep(" ", padding) .. right
	end
	return INDENT .. "│ " .. fit(text, CONTENT_WIDTH) .. " │"
end

local function palette(query, rows, count)
	local body = {}
	for index = 1, math.min(#rows, 14) do
		table.insert(body, render_row(rows[index]))
	end
	while #body < 14 do
		table.insert(body, EMPTY_ROW)
	end
	return vim.list_extend(
		{
			INDENT .. "╭ Find Action › " .. query .. string.rep(
				"─",
				(assert(QUERY_DASHES[query], "unknown approved query"))
			) .. "╮",
		},
		vim.list_extend(body, {
			INDENT .. "│ Assign ⌥↩ · Show hidden ⌘⇧A" .. string.rep(" ", 41 - #count) .. count .. " │",
			INDENT
				.. "╰──────────────────────────────────────────────────────────────────────╯",
		})
	)
end

local function assignment(key)
	return {
		"",
		"",
		"",
		"",
		"",
		INDENT
			.. "        ╭─────────── Assign Shortcut · Find Action... ───────────╮",
		INDENT .. "        │ Press keys, Enter to save, Esc to cancel               │",
		INDENT .. "        │                                                        │",
		INDENT
			.. "        │  ╭────────────────────────────────────────────────╮    │",
		INDENT
			.. "        │  │ "
			.. key
			.. string.rep(" ", (assert(KEY_PADDING[key], "unknown approved key")))
			.. " │    │",
		INDENT
			.. "        │  ╰────────────────────────────────────────────────╯    │",
		INDENT .. "        │                                                        │",
		INDENT .. "        │ No conflicts                                           │",
		INDENT .. "        │                                                        │",
		INDENT .. "        │ [ Save ]  [ Cancel ]                                   │",
		INDENT
			.. "        ╰─────────────────────────────────── Tab next   ↩ choose ╯",
		"",
	}
end

local empty_buffer = { "       [No Name]", "  1", "", "", "" }
local captured_buffer = { "▎      [No Name]", "  1", "", "", "" }
local statusline = " NORMAL" .. string.rep(" ", 85) .. " 0  0"
local dashboard = {
	"",
	"",
	"                                                        __",
	[[                           ___     ___    ___   __  __ /\_\    ___ ___]],
	[[                          / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\]],
}

local fixed = {
	["shortcut capture screen"] = full(empty_buffer, assignment(" █")),
	["captured shortcut screen"] = full(captured_buffer, assignment("⌘D █"), statusline),
}

local M = {}

---@param title string
---@param state? { rows: table[], count: string }
---@return string
function M.build(title, state)
	if fixed[title] then
		return fixed[title]
	end
	assert(state, "missing live palette state: " .. title)
	local query = title == "searched palette screen" and "find█" or "█"
	local background = title == "persisted shortcut screen" and dashboard or empty_buffer
	local below = title == "persisted shortcut screen" and string.rep(" ", 35) .. "https://github.com/GlebBeloded"
		or nil
	return full(background, palette(query, state.rows, state.count), nil, below)
end

return M
