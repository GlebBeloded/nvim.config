local INDENT = "              "
local EMPTY_ROW = INDENT .. "│                                                                      │"
local QUERY_DASHES = { ["█"] = 54, ["find█"] = 50 }
local KEY_PADDING = { [" █"] = 44, ["⌘D █"] = 42 }

local function full(background, palette)
	local lines = vim.list_extend(vim.deepcopy(background), palette)
	vim.list_extend(lines, { "", "", "", "", "", "", "" })
	return table.concat(lines, "\n") .. "\n"
end

local function palette(query, rows)
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
			INDENT
				.. "├──────────────────────────────────────────────────────────────────────┤",
			INDENT .. "│                                          Assign ⌥↩ · Show hidden ⌘⇧A │",
			INDENT
				.. "╰──────────────────────────────────────────────────────────────────────╯",
		})
	)
end

local function assignment(key)
	return {
		INDENT
			.. "╭ Find Action › find█──────────────────────────────────────────────────╮",
		INDENT .. "│ Find Action... ⌘⇧A                                              Help │",
		EMPTY_ROW,
		EMPTY_ROW,
		EMPTY_ROW,
		INDENT
			.. "│       ╭─────────── Assign Shortcut · Find Action... ───────────╮     │",
		INDENT .. "│       │ Press keys, Enter to save, Esc to cancel               │     │",
		INDENT .. "│       │                                                        │     │",
		INDENT
			.. "│       │  ╭────────────────────────────────────────────────╮    │     │",
		INDENT
			.. "│       │  │ "
			.. key
			.. string.rep(" ", (assert(KEY_PADDING[key], "unknown approved key")))
			.. " │    │     │",
		INDENT
			.. "│       │  ╰────────────────────────────────────────────────╯    │     │",
		INDENT .. "│       │                                                        │     │",
		INDENT .. "│       │ No conflicts                                           │     │",
		INDENT .. "│       │                                                        │     │",
		INDENT .. "│       │ [ Save ]  [ Cancel ]                                   │     │",
		INDENT
			.. "├───────╰─────────────────────────────────── Tab next   ↩ choose ╯─────┤",
		INDENT .. "│                                          Assign ⌥↩ · Show hidden ⌘⇧A │",
		INDENT
			.. "╰──────────────────────────────────────────────────────────────────────╯",
	}
end

local empty_buffer = { "       [No Name]", "  1", "", "", "" }
local dashboard = {
	"",
	"",
	"                                                        __",
	[[                           ___     ___    ___   __  __ /\_\    ___ ___]],
	[[                          / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\]],
}
local initial = palette("█", {
	INDENT
		.. "│ other actions ────────────────────────────────────────────────────── │",
	INDENT .. "│ Find Action... ⌘⇧A                                              Help │",
	INDENT .. "│ 99 Search                                                         AI │",
	INDENT .. "│ 99 Vibe                                                           AI │",
})
local recent = palette("█", {
	INDENT
		.. "│ recently used ────────────────────────────────────────────────────── │",
	INDENT .. "│ Find Action... ⌘⇧A                                              Help │",
	INDENT
		.. "│ other actions ────────────────────────────────────────────────────── │",
	INDENT .. "│ 99 Search                                                         AI │",
	INDENT .. "│ 99 Vibe                                                           AI │",
})

return {
	["opened palette screen"] = full(empty_buffer, initial),
	["searched palette screen"] = full(
		empty_buffer,
		palette("find█", {
			INDENT .. "│ Find Action... ⌘⇧A                                              Help │",
		})
	),
	["run action screen"] = full(empty_buffer, recent),
	["shortcut capture screen"] = full(empty_buffer, assignment(" █")),
	["captured shortcut screen"] = full(empty_buffer, assignment("⌘D █")),
	["assigned shortcut screen"] = full(empty_buffer, recent),
	["persisted shortcut screen"] = full(dashboard, initial),
}
