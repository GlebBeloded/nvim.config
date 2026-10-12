-- Change preview: builds openspec/changes/<id>/preview.html, the page the user reads before approving
-- a change in the Archon loop (docs/loop.md). It shows the proposal, design.md, its mermaid diagrams
-- rendered, and every ```text render side by side. Renders are colored by `make colorize FILE=…` when
-- that target exists (truecolor ANSI from the real colorscheme); otherwise they stay monochrome.
-- `*.ansi` captures in the change folder (from `make render`) are shown in color as well.
-- Run: nvim --clean -l ops/preview/preview.lua openspec/changes/<id>

local MERMAID_URL = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"

---@class preview.Render
---@field caption string
---@field html string

---@class preview.Style
---@field fg? string
---@field bg? string
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean
---@field reverse? boolean

local BASIC_COLORS = {
	"#000000",
	"#cd3131",
	"#0dbc79",
	"#e5e510",
	"#2472c8",
	"#bc3fbc",
	"#11a8cd",
	"#e5e5e5",
	"#666666",
	"#f14c4c",
	"#23d18b",
	"#f5f543",
	"#3b8eea",
	"#d670d6",
	"#29b8db",
	"#ffffff",
}

---@param path string
---@return string?
local function read(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
end

---@param text string
---@return string
local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

---@param n integer 0-255 xterm color index
---@return string
local function xterm_color(n)
	if n < 16 then
		return BASIC_COLORS[n + 1]
	end
	if n >= 232 then
		local level = 8 + (n - 232) * 10
		return string.format("#%02x%02x%02x", level, level, level)
	end
	local i = n - 16
	local function level(v)
		return v == 0 and 0 or 55 + v * 40
	end
	return string.format("#%02x%02x%02x", level(math.floor(i / 36)), level(math.floor(i / 6) % 6), level(i % 6))
end

---@param codes integer[]
---@param i integer index of 38 or 48
---@return string? color
---@return integer next index
local function extended_color(codes, i)
	if codes[i + 1] == 2 then
		return string.format("#%02x%02x%02x", codes[i + 2] or 0, codes[i + 3] or 0, codes[i + 4] or 0), i + 5
	elseif codes[i + 1] == 5 then
		return xterm_color(codes[i + 2] or 0), i + 3
	end
	return nil, i + 1
end

---@param style preview.Style
---@param params string SGR parameters, e.g. "1;38;2;255;0;0"
local function apply_sgr(style, params)
	local codes = {}
	for part in (params == "" and "0" or params):gmatch("[^;:]+") do
		table.insert(codes, tonumber(part) or 0)
	end
	local i = 1
	while i <= #codes do
		local c = codes[i]
		if c == 0 then
			for k in pairs(style) do
				style[k] = nil
			end
		elseif c == 1 then
			style.bold = true
		elseif c == 3 then
			style.italic = true
		elseif c == 4 then
			style.underline = true
		elseif c == 7 then
			style.reverse = true
		elseif c == 22 then
			style.bold = nil
		elseif c == 23 then
			style.italic = nil
		elseif c == 24 then
			style.underline = nil
		elseif c == 27 then
			style.reverse = nil
		elseif c == 38 or c == 48 then
			local color, next_i = extended_color(codes, i)
			style[c == 38 and "fg" or "bg"] = color
			i = next_i - 1
		elseif c == 39 then
			style.fg = nil
		elseif c == 49 then
			style.bg = nil
		elseif c >= 30 and c <= 37 then
			style.fg = BASIC_COLORS[c - 29]
		elseif c >= 90 and c <= 97 then
			style.fg = BASIC_COLORS[c - 81]
		elseif c >= 40 and c <= 47 then
			style.bg = BASIC_COLORS[c - 39]
		elseif c >= 100 and c <= 107 then
			style.bg = BASIC_COLORS[c - 91]
		end
		i = i + 1
	end
end

---@param style preview.Style
---@return string css
local function css(style)
	local fg, bg = style.fg, style.bg
	if style.reverse then
		fg, bg = bg or "var(--bg)", fg or "var(--fg)"
	end
	local parts = {}
	if fg then
		table.insert(parts, "color:" .. fg)
	end
	if bg then
		table.insert(parts, "background:" .. bg)
	end
	if style.bold then
		table.insert(parts, "font-weight:bold")
	end
	if style.italic then
		table.insert(parts, "font-style:italic")
	end
	if style.underline then
		table.insert(parts, "text-decoration:underline")
	end
	return table.concat(parts, ";")
end

---Convert ANSI-colored text (SGR sequences) to HTML spans; other escape sequences are dropped.
---@param ansi string
---@return string
local function ansi_to_html(ansi)
	local out, style, pos = {}, {}, 1
	local function emit(text)
		if text == "" then
			return
		end
		local rule = css(style)
		table.insert(out, rule == "" and escape(text) or ('<span style="%s">%s</span>'):format(rule, escape(text)))
	end
	while true do
		local s, e, params, final = ansi:find("\27%[([%d;:?]*)([%a])", pos)
		if not s then
			emit(ansi:sub(pos))
			break
		end
		emit(ansi:sub(pos, s - 1))
		if final == "m" then
			apply_sgr(style, params)
		end
		pos = e + 1
	end
	return (table.concat(out):gsub("\27[^%[]", ""))
end

---Renders colored by `make colorize FILE=<design.md>` (the colorscheme's real colors for renders with a
---mask and legend). Its output is one dim `── <file>:<line> <caption>` header per render, then the rows.
---@param design_path string
---@return preview.Render[]? nil when the target is missing or fails
local function colorized_renders(design_path)
	local cmd = { "make", "-s", "colorize", "FILE=" .. design_path }
	local result = vim.system(cmd, { text = true }):wait()
	if result.code ~= 0 or not result.stdout:find("── ", 1, true) then
		return nil
	end
	local renders, current = {}, nil
	for _, line in ipairs(vim.split(result.stdout, "\n")) do
		local at, caption = line:gsub("\27%[[%d;]*m", ""):match("^── %S+:(%d+)%s*(.*)$")
		if at then
			current = { caption = caption ~= "" and caption or ("design.md:" .. at), rows = {} }
			table.insert(renders, current)
		elseif current then
			table.insert(current.rows, line)
		end
	end
	return vim.tbl_map(function(r)
		return { caption = r.caption, html = ansi_to_html(vim.trim(table.concat(r.rows, "\n"))) }
	end, renders)
end

---@param lines string[]
---@param from integer index of an opening fence
---@return string[] body
---@return integer close index of the closing fence
local function fence_body(lines, from)
	local body, close = {}, from + 1
	while close <= #lines and not lines[close]:match("^```%s*$") do
		table.insert(body, lines[close])
		close = close + 1
	end
	return body, close
end

---@param lines string[]
---@param before integer
---@return string nearest non-blank line above `before`
local function caption_above(lines, before)
	for k = before - 1, math.max(1, before - 3), -1 do
		if lines[k]:match("%S") then
			return lines[k]
		end
	end
	return ""
end

---Split design.md into monochrome ```text renders and mermaid diagrams. A ```text block right after a
---render (only blank lines between) is its color mask and is skipped.
---@param design string
---@return preview.Render[] renders
---@return string[] diagrams
local function parse_design(design)
	local renders, diagrams = {}, {}
	local lines = vim.split(design, "\n")
	local last_close = -10
	local i = 1
	while i <= #lines do
		local lang = lines[i]:match("^```(%w+)%s*$")
		if lang == "text" or lang == "mermaid" then
			local body, close = fence_body(lines, i)
			local is_mask = lang == "text"
				and last_close > 0
				and not table.concat(lines, "", last_close + 1, i - 1):match("%S")
			if lang == "mermaid" then
				table.insert(diagrams, table.concat(body, "\n"))
			elseif not is_mask then
				table.insert(renders, { caption = caption_above(lines, i), html = escape(table.concat(body, "\n")) })
			end
			last_close = lang == "text" and not is_mask and close or -10
			i = close
		end
		i = i + 1
	end
	return renders, diagrams
end

---@param dir string change folder
---@return preview.Render[]
local function ansi_captures(dir)
	local renders = {}
	for _, path in ipairs(vim.fn.globpath(dir, "**/*.ansi", false, true)) do
		table.insert(renders, { caption = vim.fs.basename(path), html = ansi_to_html(read(path) or "") })
	end
	return renders
end

---@param renders preview.Render[]
---@return string
local function render_grid(renders)
	local cells = {}
	for _, r in ipairs(renders) do
		table.insert(
			cells,
			("<figure><figcaption>%s</figcaption><pre class=screen>%s</pre></figure>"):format(escape(r.caption), r.html)
		)
	end
	return #cells == 0 and "<p>No renders.</p>" or '<div class="grid">' .. table.concat(cells) .. "</div>"
end

---@param id string
---@param sections { title: string, html: string }[]
---@return string
local function page(id, sections)
	local body = {}
	for _, s in ipairs(sections) do
		table.insert(body, ("<section><h2>%s</h2>%s</section>"):format(s.title, s.html))
	end
	return table.concat({
		"<!doctype html><html><head><meta charset=utf-8>",
		'<meta name=viewport content="width=device-width,initial-scale=1">',
		"<title>Preview " .. escape(id) .. "</title><style>",
		":root{--bg:#fbf1c7;--fg:#3c3836;--line:#d5c4a1}",
		"@media (prefers-color-scheme:dark){:root{--bg:#1d2021;--fg:#d4be98;--line:#504945}}",
		"body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui;margin:0 auto;max-width:1600px;padding:16px}",
		"pre{white-space:pre-wrap;border:1px solid var(--line);padding:12px;overflow-x:auto}",
		"pre.screen{white-space:pre;font:11px/1.25 ui-monospace,Menlo,monospace;background:#282828;color:#d4be98}",
		".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,680px),1fr));gap:16px}",
		"figure{margin:0}figcaption{font-weight:600;margin-bottom:4px}",
		"</style></head><body><h1>" .. escape(id) .. "</h1>",
		table.concat(body),
		'<script src="' .. MERMAID_URL .. '"></script>',
		"<script>window.mermaid&&mermaid.initialize({startOnLoad:true,theme:",
		"matchMedia('(prefers-color-scheme: dark)').matches?'dark':'default'})</script>",
		"</body></html>",
	}, "\n")
end

---@param dir string
---@return string out path
local function build(dir)
	dir = vim.fs.normalize(dir):gsub("/$", "")
	local id = vim.fs.basename(dir)
	local proposal = read(dir .. "/proposal.md") or "(no proposal.md)"
	local design = read(dir .. "/design.md") or ""
	local plain, diagrams = parse_design(design)
	local colored = design ~= "" and colorized_renders(dir .. "/design.md") or nil
	local color = colored ~= nil
	local renders = colored or plain
	vim.list_extend(renders, ansi_captures(dir))
	local mermaid = {}
	for _, d in ipairs(diagrams) do
		table.insert(mermaid, '<pre class="mermaid">' .. escape(d) .. "</pre>")
	end
	local out = dir .. "/preview.html"
	local html = page(id, {
		{
			title = "Renders" .. (color and "" or " (monochrome: make colorize not available)"),
			html = render_grid(renders),
		},
		{ title = "Diagrams", html = #mermaid == 0 and "<p>No diagrams.</p>" or table.concat(mermaid) },
		{ title = "Proposal", html = "<pre>" .. escape(proposal) .. "</pre>" },
		{ title = "Design", html = "<pre>" .. escape(design == "" and "(no design.md)" or design) .. "</pre>" },
	})
	vim.fn.writefile(vim.split(html, "\n"), out)
	return out
end

local dir = (_G.arg or {})[1]
if not dir or vim.fn.isdirectory(dir) == 0 then
	vim.api.nvim_echo(
		{ { "usage: nvim --clean -l ops/preview/preview.lua openspec/changes/<id>" } },
		false,
		{ err = true }
	)
	os.exit(2)
end
print(build(dir))
