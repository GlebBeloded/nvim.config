-- Zellij-aware session recovery, layered on stevearc/resession.nvim.
--
-- A session is keyed by (zellij session, pane id, cwd) so every nvim pane gets
-- its own restore point. Pane ids are NOT stable across zellij resurrection, so
-- restore falls back to the most recent session for the same cwd when the exact
-- key is missing (newest first via `load_order` in resession.setup below).
--
-- Only a bare-started nvim (`nvim`, no file arguments) restores or saves, and a
-- save with no listed file buffer is skipped so it never clobbers a good session.
--
-- resession only persists file paths / layout — never unsaved content — so
-- okuuva/auto-save.nvim (see plugins.lua) keeps buffers flushed to disk.

local status_ok, resession = pcall(require, "resession")
if not status_ok then
	return
end

local key = require("gleb.session.key")
local session_name, session_slug = key.session_name()

-- Read once at load: a later `:argadd` must not change how nvim was started.
local started_bare = vim.fn.argc(-1) == 0

---@return boolean
local function has_file_buffer()
	return vim.iter(vim.fn.getbufinfo({ buflisted = 1 })):any(function(info)
		return info.name ~= "" and vim.bo[info.bufnr].buftype == ""
	end)
end

---@return boolean
local function should_save()
	return started_bare and has_file_buffer()
end

local function save()
	if not should_save() then
		return
	end
	resession.save(session_name, { notify = false })
end

local function restore()
	-- Only when launched bare (`nvim`), never `nvim file` or piped input.
	if not started_bare then
		return
	end
	local name = key.resolve(session_name, resession.list(), session_slug)
	if name then
		resession.load(name, { silence_errors = true })
	end
end

resession.setup({
	autosave = { enabled = false }, -- saves are driven by the autocmds below
	load_order = "modification_time", -- list() newest first: the cwd fallback picks the latest
})

local group = vim.api.nvim_create_augroup("gleb_session", { clear = true })

-- Registered before gleb.alpha's VimEnter so a restored buffer makes the
-- dashboard self-skip. `nested` lets FileType/LSP fire for restored buffers.
vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	nested = true,
	callback = restore,
})

vim.api.nvim_create_autocmd({ "BufWritePost", "VimLeavePre" }, {
	group = group,
	callback = save,
})
