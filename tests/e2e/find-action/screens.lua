local INDENT = "              "
local EMPTY_ROW = INDENT .. "│                                                                      │"
local QUERY_DASHES = { ["█"] = 54, ["find█"] = 50 }
local KEY_PADDING = { [" █"] = 44, ["⌘D █"] = 42 }

local function full(background, palette, statusline, below)
	local lines = vim.list_extend(vim.deepcopy(background), palette)
	vim.list_extend(lines, { below or "", "", "", "", "", "", "", "" })
	if statusline then
		lines[#lines] = statusline
	end
	return table.concat(lines, "\n") .. "\n"
end

local function palette(query, rows, count)
	local body = vim.deepcopy(rows)
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
local recent = palette("█", {
	INDENT
		.. "│ recently used ────────────────────────────────────────────────────── │",
	INDENT .. "│ Find Action...  ⌘⇧A                                             Help │",
	INDENT
		.. "│ other actions ────────────────────────────────────────────────────── │",
	INDENT .. "│ Focus Left Window  ⌘H                                         Window │",
	INDENT .. "│ Focus Down Window  ⌘⇧J                                        Window │",
	INDENT .. "│ Focus Up Window  ⌘⇧K                                          Window │",
	INDENT .. "│ Focus Right Window  ⌘L                                        Window │",
	INDENT .. "│ Navigate Back  gb                                               Jump │",
	INDENT .. "│ Navigate Forward  gB                                            Jump │",
	INDENT .. "│ Increase Window Height  ⌃↑                                    Window │",
	INDENT .. "│ Decrease Window Height  ⌃↓                                    Window │",
	INDENT .. "│ Decrease Window Width  ⌃←                                     Window │",
	INDENT .. "│ Increase Window Width  ⌃→                                     Window │",
	INDENT .. "│ Resize Window Left  ⌘⇧H                                       Window │",
}, "43/43")

return {
	["opened palette screen"] = full(empty_buffer, recent),
	["searched palette screen"] = full(
		empty_buffer,
		palette("find█", {
			INDENT .. "│ Find Action...  ⌘⇧A                                             Help │",
			INDENT .. "│ Focus Left Window  ⌘H                                         Window │",
			INDENT .. "│ Focus Down Window  ⌘⇧J                                        Window │",
			INDENT .. "│ Focus Up Window  ⌘⇧K                                          Window │",
			INDENT .. "│ Focus Right Window  ⌘L                                        Window │",
			INDENT .. "│ Find in Files...  ⌘⇧F                                    Edit | Find │",
			INDENT .. "│ Find References  gr                                              LSP │",
		}, "7/43")
	),
	["run action screen"] = full(empty_buffer, recent),
	["shortcut capture screen"] = full(empty_buffer, assignment(" █")),
	["captured shortcut screen"] = full(captured_buffer, assignment("⌘D █"), statusline),
	["assigned shortcut screen"] = full(empty_buffer, recent),
	["persisted shortcut screen"] = full(
		dashboard,
		recent,
		nil,
		string.rep(" ", 35) .. "https://github.com/GlebBeloded"
	),
}
