-- Zellij-aware session recovery, layered on stevearc/resession.nvim.
--
-- A session is keyed by (zellij session, pane id, cwd) so every nvim pane gets
-- its own restore point. Pane ids are NOT stable across zellij resurrection, so
-- restore falls back to the most recent session for the same cwd when the exact
-- key is missing.
--
-- resession only persists file paths / layout — never unsaved content — so
-- okuuva/auto-save.nvim (see plugins.lua) keeps buffers flushed to disk.

local status_ok, resession = pcall(require, "resession")
if not status_ok then
	return {}
end

local key = require("gleb.session.key")

local function save()
	resession.save(key.session_name(), { notify = false })
end

local function restore()
	-- Only when launched bare (`nvim`), never `nvim file` or piped input.
	if vim.fn.argc(-1) ~= 0 then
		return
	end
	local name = key.resolve(key.session_name(), resession.list())
	if name then
		resession.load(name, { silence_errors = true })
	end
end

resession.setup({
	autosave = { enabled = false }, -- saves are driven by the autocmds below
})

local group = vim.api.nvim_create_augroup("gleb_session", { clear = true })

-- Registered before alpha-nvim's VimEnter so a restored buffer makes the
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

return {}
