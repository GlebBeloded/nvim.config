-- LSP progress for the statusline, built on the native `LspProgress` event.
--
-- Design goals (see config below):
--   * no flicker: a task is only rendered once it has run longer than
--     SHOW_AFTER_MS, so sub-half-second work never reaches the statusline.
--   * never stuck: a task with no begin/report for STALE_AFTER_MS is dropped,
--     so a server that never sends `end` cannot spin forever; raise it if a
--     slow server goes quiet longer than that mid-task.
--   * readable: raw server messages are mapped to short aliases via ALIASES.
--   * debuggable: every raw progress event is appended to LOG_PATH so you can
--     `grep` it and grow the alias list:  tail -f /tmp/nvim-lsp-progress.log
--     $NVIM_LSP_PROGRESS_LOG overrides the path; the log is emptied before an
--     append once it exceeds LOG_MAX_BYTES.
local M = {}

local SHOW_AFTER_MS = 500
local STALE_AFTER_MS = 60000
local LOG_PATH = vim.env.NVIM_LSP_PROGRESS_LOG or ""
if LOG_PATH == "" then
	LOG_PATH = "/tmp/nvim-lsp-progress.log"
end
local LOG_MAX_BYTES = 1024 * 1024
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

---@class gleb.lsp_progress.Task
---@field start_ms number when `begin` arrived; drives the SHOW_AFTER_MS delay
---@field seen_ms number last `begin`/`report`; drives the STALE_AFTER_MS timeout
---@field title? string
---@field message? string
---@field pct? number

---@type table<string, gleb.lsp_progress.Task> keyed by client_id .. ":" .. token
local active = {}
---@type uv.uv_timer_t?
local timer

local function now_ms()
	return uv.hrtime() / 1e6
end

local function prune_stale()
	local now = now_ms()
	for key, task in pairs(active) do
		if now - task.seen_ms > STALE_AFTER_MS then
			active[key] = nil
		end
	end
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

--- "w" empties an oversized log before writing, "a" appends.
---@return "a"|"w"
local function log_mode()
	local stat = uv.fs_stat(LOG_PATH)
	return stat and stat.size > LOG_MAX_BYTES and "w" or "a"
end

local function log(client_name, value)
	local fd = io.open(LOG_PATH, log_mode())
	if not fd then
		return
	end
	fd:write(
		string.format(
			"[%s] %-8s kind=%-6s title=%q msg=%q pct=%s\n",
			os.date("%H:%M:%S"),
			client_name,
			value.kind or "",
			value.title or "",
			value.message or "",
			tostring(value.percentage or "")
		)
	)
	fd:close()
end

local function stop_timer()
	if not timer then
		return
	end
	timer:stop()
	timer:close()
	timer = nil
end

-- refresh lualine while there is work; stop the timer once everything is idle
local function tick()
	prune_stale()
	require("lualine").refresh()
	if next(active) == nil then
		stop_timer()
	end
end

local function ensure_timer()
	if timer then
		return
	end
	local t = assert(uv.new_timer())
	t:start(0, 100, vim.schedule_wrap(tick))
	timer = t
end

local function on_progress(args)
	local client = vim.lsp.get_client_by_id(args.data.client_id)
	local value = args.data.params.value
	local key = args.data.client_id .. ":" .. tostring(args.data.params.token)

	log(client and client.name or "lsp", value)

	if value.kind == "begin" then
		local now = now_ms()
		active[key] =
			{ start_ms = now, seen_ms = now, title = value.title, message = value.message, pct = value.percentage }
		ensure_timer()
	elseif value.kind == "report" and active[key] then
		active[key].message = value.message or active[key].message
		active[key].pct = value.percentage or active[key].pct
		active[key].seen_ms = now_ms()
	elseif value.kind == "end" then
		active[key] = nil
	end
end

---@param client_id integer
local function drop_client(client_id)
	local prefix = client_id .. ":"
	for key in pairs(active) do
		if vim.startswith(key, prefix) then
			active[key] = nil
		end
	end
end

-- `LspDetach` also fires per buffer on unload; a client still attached elsewhere keeps its tasks
---@param client? vim.lsp.Client
---@param buf integer
---@return boolean
local function client_leaving(client, buf)
	if client == nil or client:is_stopped() then
		return true
	end
	local first = next(client.attached_buffers)
	return first == buf and next(client.attached_buffers, first) == nil
end

local function on_detach(args)
	local client_id = args.data.client_id
	if client_leaving(vim.lsp.get_client_by_id(client_id), args.buf) then
		drop_client(client_id)
	end
end

--- Statusline component: spinner + readable label, only for tasks past the threshold.
---@return string
function M.progress()
	prune_stale()
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

local group = vim.api.nvim_create_augroup("gleb_lsp_progress", { clear = true })
vim.api.nvim_create_autocmd("LspProgress", { group = group, callback = on_progress })
vim.api.nvim_create_autocmd("LspDetach", { group = group, callback = on_detach })
vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = stop_timer })

return M
