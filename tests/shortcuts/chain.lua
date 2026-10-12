-- Shortcut chain model: physical shortcut -> Alacritty bytes -> zellij -> Neovim key.
-- Runs inside the test runner Neovim (no child). Config parsing is done by
-- tests/shortcuts/configs.py (TOML + KDL); this module decodes bytes and routes
-- keys through zellij the way zellij 0.45 does. Sources for every rule are in
-- docs/testing.md#shortcut-layers.

local M = {}

local bit = require("bit")

M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

local NAVIGATOR = "vim%-zellij%-navigator%.wasm$"

-- vim-zellij-navigator defaults (move_mod = Ctrl, resize_mod = Alt): bytes it
-- writes to a Neovim pane instead of acting (hiasr/vim-zellij-navigator main.rs).
local NAVIGATOR_BYTES = {
	move_focus_or_tab = { left = "\8", right = "\12", up = "\11", down = "\10" },
	move_focus = { left = "\8", right = "\12", up = "\11", down = "\10" },
	resize = { left = "\27h", right = "\27l", up = "\27k", down = "\27j" },
}

-- Kitty CSI u codes for named keys, both directions.
local KITTY_NAMED = { [13] = "enter", [9] = "tab", [27] = "esc", [127] = "backspace", [32] = "space" }
local NVIM_NAMED = { enter = "CR", tab = "Tab", esc = "Esc", backspace = "BS", space = "Space" }
local ARROWS = { A = "up", B = "down", C = "right", D = "left" }
local ALACRITTY_NAMED = { Return = 13, Tab = 9, Escape = 27, Back = 127, Space = 32 }
local ALACRITTY_ARROWS = { Up = "A", Down = "B", Right = "C", Left = "D" }

---@class shortcuts.Key
---@field zellij string canonical zellij key, e.g. "alt shift h"
---@field nvim string Neovim key notation, e.g. "<M-H>"

---@class shortcuts.Route
---@field kind "pass"|"navigator"|"zellij"
---@field action string zellij action summary ("" for pass)
---@field bytes string bytes that reach the Neovim pane ("" when consumed)

---@type table?
local cached

--- Effective Alacritty + zellij bindings (tests/shortcuts/configs.py).
---@return table
function M.configs()
	if not cached then
		local python = vim.fs.joinpath(M.root, ".tests/venv/bin/python")
		local script = vim.fs.joinpath(M.root, "tests/shortcuts/configs.py")
		local result = vim.system({ python, "-I", script }, { text = true }):wait()
		assert(result.code == 0, "configs.py failed: " .. (result.stderr or ""))
		cached = vim.json.decode(result.stdout, { luanil = { object = true, array = true } })
	end
	return cached
end

--- Normalise Neovim key notation ("<A-j>" -> "<M-j>").
---@param notation string
---@return string
function M.norm(notation)
	return vim.fn.keytrans(vim.keycode(notation))
end

---@param mods { shift?: boolean, alt?: boolean, ctrl?: boolean, super?: boolean }
---@param key string zellij key name or char
---@return shortcuts.Key
local function make_key(mods, key)
	local zmods, nprefix = {}, ""
	for _, name in ipairs({ "ctrl", "alt", "shift", "super" }) do
		if mods[name] then
			table.insert(zmods, name)
		end
	end
	for _, pair in ipairs({ { "super", "D-" }, { "ctrl", "C-" }, { "alt", "M-" }, { "shift", "S-" } }) do
		if mods[pair[1]] then
			nprefix = nprefix .. pair[2]
		end
	end
	table.insert(zmods, key)
	local is_char = vim.fn.strchars(key) == 1
	if is_char and nprefix == "" then
		return { zellij = table.concat(zmods, " "), nvim = M.norm(key) }
	end
	local name = NVIM_NAMED[key] or (is_char and (key == "<" and "lt" or key)) or (key:sub(1, 1):upper() .. key:sub(2))
	return { zellij = table.concat(zmods, " "), nvim = M.norm("<" .. nprefix .. name .. ">") }
end

---@param bits integer kitty modifier value minus one
---@return table
local function kitty_mods(bits)
	return {
		shift = bit.band(bits, 1) ~= 0,
		alt = bit.band(bits, 2) ~= 0,
		ctrl = bit.band(bits, 4) ~= 0,
		super = bit.band(bits, 8) ~= 0,
	}
end

---@param char string single (possibly multibyte) char
---@param mods table
---@return shortcuts.Key
local function char_key(char, mods)
	if char:match("^%u$") then
		mods.shift = true
		return make_key(mods, char:lower())
	end
	return make_key(mods, char)
end

--- Decode the bytes a terminal sends into the key zellij parses and the key
--- Neovim's TUI decodes (they agree for every sequence handled here).
---@param bytes string
---@return shortcuts.Key?
function M.decode(bytes)
	local code, bits = bytes:match("^\27%[(%d+);(%d+)u$")
	if code then
		code, bits = tonumber(code), tonumber(bits) - 1
		return make_key(kitty_mods(bits), KITTY_NAMED[code] or vim.fn.nr2char(code))
	end
	local arrow_bits, arrow = bytes:match("^\27%[1;(%d+)([ABCD])$")
	if arrow then
		return make_key(kitty_mods(tonumber(arrow_bits) - 1), ARROWS[arrow])
	end
	local alt = bytes:match("^\27(.+)$")
	if alt and vim.fn.strchars(alt) == 1 then
		return char_key(alt, { alt = true })
	end
	if #bytes == 1 then
		local byte = bytes:byte()
		if byte == 13 or byte == 9 or byte == 27 or byte == 127 then
			return make_key({}, KITTY_NAMED[byte])
		end
		if byte >= 1 and byte <= 26 then
			return make_key({ ctrl = true }, string.char(byte + 96))
		end
	end
	if vim.fn.strchars(bytes) == 1 then
		return char_key(bytes, {})
	end
	return nil
end

--- Bytes Alacritty 0.17 emits for an unbound key while zellij has pushed kitty
--- flag 1 (disambiguate): alacritty/src/input/keyboard.rs build_sequence.
---@param key string Alacritty key name ("Return", "H", "Up")
---@param mods string[] Alacritty mods ("Control", "Shift", "Option", "Command")
---@return string
function M.alacritty_kitty_bytes(key, mods)
	local value = 1
	local weights = { Shift = 1, Option = 2, Control = 4, Command = 8 }
	for _, mod in ipairs(mods) do
		value = value + weights[mod]
	end
	if ALACRITTY_ARROWS[key] then
		return string.format("\27[1;%d%s", value, ALACRITTY_ARROWS[key])
	end
	local code = ALACRITTY_NAMED[key] or key:lower():byte()
	if value == 1 and code ~= 13 and code ~= 9 and code ~= 127 then
		return string.char(code)
	end
	return string.format("\27[%d;%du", code, value)
end

---@param action table zellij action from configs.py
---@return string
local function action_summary(action)
	local args = vim.deepcopy(action.args)
	if action.name == "MessagePlugin" and action.children then
		args = { (action.children.name or {})[1], (action.children.payload or {})[1] }
	end
	return vim.trim(action.name .. " " .. table.concat(args, " "))
end

---@param action table
---@return boolean
local function is_navigator(action)
	return action.name == "MessagePlugin" and (action.args[1] or ""):match(NAVIGATOR) ~= nil
end

--- What zellij does with a key in `mode` while the focused pane runs Neovim
--- (assumed to have enabled kitty keys, so unbound bytes pass unchanged).
---@param zkey string? canonical zellij key
---@param bytes string bytes that were sent (written through when unbound)
---@param mode? string zellij input mode (default: the config's default_mode)
---@return shortcuts.Route
function M.route_key(zkey, bytes, mode)
	local zellij = M.configs().zellij
	mode = mode or zellij.default_mode
	local bind = zkey and zellij.modes[mode][zkey]
	if not bind then
		local writes = mode == "locked" or mode == zellij.default_mode
		return { kind = writes and "pass" or "zellij", action = writes and "" or "NoOp", bytes = writes and bytes or "" }
	end
	local first = bind.actions[1]
	if #bind.actions == 1 and is_navigator(first) then
		local name, payload = first.children.name[1], first.children.payload[1]
		return { kind = "navigator", action = action_summary(first), bytes = NAVIGATOR_BYTES[name][payload] }
	end
	local summary = table.concat(vim.tbl_map(action_summary, bind.actions), "; ")
	return { kind = "zellij", action = summary, bytes = "" }
end

--- What zellij does with `bytes` in `mode` (see M.route_key).
---@param bytes string
---@param mode? string
---@return shortcuts.Route
function M.route(bytes, mode)
	local key = M.decode(bytes)
	return M.route_key(key and key.zellij, bytes, mode)
end

--- Printable form of a byte string: "\eg", "\x08".
---@param bytes string
---@return string
function M.escape(bytes)
	return (
		bytes:gsub("[%z\1-\31\127]", function(c)
			return c == "\27" and "\\e" or string.format("\\x%02x", c:byte())
		end)
	)
end

--- Physical shortcut name: "Cmd+Shift+H".
---@param key string
---@param mods string[]
---@return string
function M.physical(key, mods)
	local names = { Command = "Cmd", Control = "Ctrl", Option = "Option", Shift = "Shift" }
	local order = { "Control", "Option", "Command", "Shift" }
	local parts = {}
	for _, mod in ipairs(order) do
		if vim.list_contains(mods, mod) then
			table.insert(parts, names[mod])
		end
	end
	local key_names = { LBracket = "[", RBracket = "]", Slash = "/", Minus = "-", Equals = "=" }
	table.insert(parts, key_names[key] or key:gsub("^Key(%d)$", "%1"))
	return table.concat(parts, "+")
end

---@class shortcuts.Shortcut
---@field physical string
---@field bytes string what Alacritty sends
---@field source "chars"|"kitty" explicit `chars` binding, or Alacritty's own encoding

--- Every Alacritty `chars` binding outside Vi mode, by physical name.
---@return table<string, shortcuts.Shortcut>
function M.alacritty_chars()
	local shortcuts = {}
	for _, binding in ipairs(M.configs().alacritty.bindings) do
		if binding.chars and binding.mode == "" then
			local physical = M.physical(binding.key, binding.mods)
			shortcuts[physical] = { physical = physical, bytes = binding.chars, source = "chars" }
		end
	end
	return shortcuts
end

--- Bytes for a physical shortcut: its `chars` binding, else Alacritty's kitty
--- flag-1 encoding (what it emits under zellij).
---@param physical string e.g. "Ctrl+Return"
---@return shortcuts.Shortcut
function M.shortcut(physical)
	local bound = M.alacritty_chars()[physical]
	if bound then
		return bound
	end
	local parts = vim.split(physical, "+", { plain = true })
	local key = table.remove(parts)
	local names = { Cmd = "Command", Ctrl = "Control", Option = "Option", Shift = "Shift" }
	local mods = vim.tbl_map(function(name)
		return names[name]
	end, parts)
	return { physical = physical, bytes = M.alacritty_kitty_bytes(key, mods), source = "kitty" }
end

--- Zellij bindings in `mode` that consume the key (not navigator pass-through).
---@param mode? string
---@return { key: string, action: string }[]
function M.consumed(mode)
	local zellij = M.configs().zellij
	local result = {}
	for key, bind in pairs(zellij.modes[mode or zellij.default_mode]) do
		if not (#bind.actions == 1 and is_navigator(bind.actions[1])) then
			table.insert(result, { key = key, action = table.concat(vim.tbl_map(action_summary, bind.actions), "; ") })
		end
	end
	table.sort(result, function(a, b)
		return a.key < b.key
	end)
	return result
end

--- Neovim key notation of a canonical zellij key ("ctrl q" -> "<C-q>").
---@param zkey string
---@return string
function M.zellij_to_nvim(zkey)
	local parts = vim.split(zkey, " ")
	local key = table.remove(parts)
	local mods = {}
	for _, mod in ipairs(parts) do
		mods[mod] = true
	end
	return make_key(mods, key).nvim
end

--- Render rows as an aligned text table.
---@param header string[]
---@param rows string[][]
---@return string
function M.format_table(header, rows)
	local widths = {}
	for _, row in ipairs(vim.list_extend({ header }, rows)) do
		for i, cell in ipairs(row) do
			widths[i] = math.max(widths[i] or 0, vim.fn.strdisplaywidth(cell))
		end
	end
	local lines = {}
	for _, row in ipairs(vim.list_extend({ header }, rows)) do
		local cells = {}
		for i, cell in ipairs(row) do
			cells[i] = cell .. string.rep(" ", widths[i] - vim.fn.strdisplaywidth(cell))
		end
		table.insert(lines, vim.trim(table.concat(cells, "  ")))
	end
	return table.concat(lines, "\n")
end

--- Inverse of M.escape.
---@param text string
---@return string
function M.unescape(text)
	return (text:gsub("\\x(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end):gsub("\\e", "\27"))
end

---@param line string markdown table row
---@return string[]
local function cells(line)
	local result = {}
	for cell in line:gmatch("|([^|]*)") do
		table.insert(result, vim.trim(cell))
	end
	table.remove(result) -- after the last |
	return result
end

---@param cell string
---@return string
local function code(cell)
	return cell:match("^`(.*)`$") or cell
end

--- Rows of the markdown table under `## <heading>` in the shortcuts spec.
---@param heading string
---@return string[][]
function M.spec_table(heading)
	local path = vim.fs.joinpath(M.root, "openspec/specs/shortcuts/spec.md")
	local rows, inside = {}, false
	for _, line in ipairs(vim.fn.readfile(path)) do
		if line:match("^## ") then
			inside = line == "## " .. heading
		elseif inside and line:match("^|") and not line:match("^|%-") then
			table.insert(rows, cells(line))
		end
	end
	table.remove(rows, 1) -- header
	return rows
end

---@class shortcuts.Row
---@field shortcut string
---@field source "chars"|"kitty"
---@field bytes string
---@field zellij string
---@field receives string? normalised Neovim key, nil for "—"
---@field mapping string

--- The shortcut table of the spec.
---@return shortcuts.Row[]
function M.shortcut_rows()
	return vim.tbl_map(function(row)
		local receives = code(row[5])
		return {
			shortcut = row[1],
			source = row[2],
			bytes = M.unescape(code(row[3])),
			zellij = row[4],
			receives = receives ~= "—" and M.norm(receives) or nil,
			mapping = row[6],
		}
	end, M.spec_table("Shortcut table"))
end

--- The collision table of the spec as "key | action | nvim key | modes" strings.
---@return string[]
function M.collision_rows()
	return vim.tbl_map(function(row)
		return table.concat({ row[1], row[2], M.norm(code(row[3])), row[4] }, " | ")
	end, M.spec_table("Collision table"))
end

--- Route summary in the notation of the spec's *zellij* column.
---@param route shortcuts.Route
---@return string
function M.route_text(route)
	if route.kind == "pass" then
		return "pass"
	elseif route.kind == "navigator" then
		return (route.action:gsub("^MessagePlugin", "navigator"))
	end
	return route.action
end

return M
