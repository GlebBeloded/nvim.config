-- LSP progress for the statusline, built on the native `LspProgress` event.
--
-- Design goals (see config below):
--   * no flicker: a task is only rendered once it has run longer than
--     SHOW_AFTER_MS, so sub-half-second work never reaches the statusline.
--   * readable: raw server messages are mapped to short aliases via ALIASES.
--   * debuggable: every raw progress event is appended to LOG_PATH so you can
--     `grep` it and grow the alias list:  tail -f /tmp/nvim-lsp-progress.log
local M = {}

local SHOW_AFTER_MS = 500
local LOG_PATH = "/tmp/nvim-lsp-progress.log"
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- raw title/message -> readable alias. First matching Lua pattern wins.
-- Extend this after reading the log.
local ALIASES = {
	{ "[Ss]etting up workspace", "indexing workspace" },
	{ "[Ll]oading", "loading" },
	{ "[Ii]ndex", "indexing" },
	{ "[Dd]iagnos", "checking" },
	{ "[Dd]ownload", "downloading deps" },
	{ "[Bb]uild", "building" },
	{ "[Ff]ormat", "formatting" },
	{ "[Pp]rocessing", "processing" },
}

local uv = vim.uv or vim.loop

-- active[client_id .. ":" .. token] = { start_ms, title, message, pct }
local active = {}
local timer

local function now_ms()
	return uv.hrtime() / 1e6
end

local function readable(text)
	if not text or text == "" then
		return nil
	end
	for _, alias in ipairs(ALIASES) do
		if text:match(alias[1]) then
			return alias[2]
		end
	end
	return text
end

local function log(client_name, value)
	local fd = io.open(LOG_PATH, "a")
	if not fd then
		return
	end
	fd:write(string.format(
		"[%s] %-8s kind=%-6s title=%q msg=%q pct=%s\n",
		os.date("%H:%M:%S"),
		client_name,
		value.kind or "",
		value.title or "",
		value.message or "",
		tostring(value.percentage or "")
	))
	fd:close()
end

-- refresh lualine while there is work; stop the timer once everything is idle
local function ensure_timer()
	if timer then
		return
	end
	timer = uv.new_timer()
	timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			require("lualine").refresh()
			if next(active) == nil and timer then
				timer:stop()
				timer:close()
				timer = nil
			end
		end)
	)
end

local function on_progress(args)
	local client = vim.lsp.get_client_by_id(args.data.client_id)
	local value = args.data.params.value
	local key = args.data.client_id .. ":" .. tostring(args.data.params.token)

	log(client and client.name or "lsp", value)

	if value.kind == "begin" then
		active[key] = { start_ms = now_ms(), title = value.title, message = value.message, pct = value.percentage }
		ensure_timer()
	elseif value.kind == "report" and active[key] then
		active[key].message = value.message or active[key].message
		active[key].pct = value.percentage or active[key].pct
	elseif value.kind == "end" then
		active[key] = nil
	end
end

-- statusline component: spinner + readable label, only for tasks past the threshold
function M.progress()
	local parts = {}
	local elapsed_from = now_ms()
	local spinner = SPINNER[math.floor(elapsed_from / 80) % #SPINNER + 1]

	for _, item in pairs(active) do
		if elapsed_from - item.start_ms >= SHOW_AFTER_MS then
			local label = readable(item.message) or readable(item.title) or "working"
			if item.pct then
				table.insert(parts, string.format("%s %s %d%%%%", spinner, label, item.pct))
			else
				table.insert(parts, string.format("%s %s", spinner, label))
			end
		end
	end

	return table.concat(parts, "  ")
end

vim.api.nvim_create_autocmd("LspProgress", {
	group = vim.api.nvim_create_augroup("gleb_lsp_progress", { clear = true }),
	callback = on_progress,
})

return M
