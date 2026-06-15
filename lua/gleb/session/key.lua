-- Pure session-key helpers, free of any plugin dependency so they stay testable.
-- See lua/gleb/session/init.lua for how these drive resession.

local M = {}

-- Make a path safe to embed in a session filename.
function M.slugify(path)
	return (path:gsub("[/\\:]", "%%"))
end

-- Unique key per zellij pane and directory; degrades gracefully outside zellij.
function M.session_name()
	local parts = {
		vim.env.ZELLIJ_SESSION_NAME or "no-zellij",
		vim.env.ZELLIJ_PANE_ID or "0",
		M.slugify(vim.fn.getcwd()),
	}
	return table.concat(parts, "-")
end

-- Resolve which saved session to load: prefer the exact pane key, otherwise
-- reuse any session for this cwd (pane id changed, e.g. after resurrection).
function M.resolve(name, saved)
	if vim.tbl_contains(saved, name) then
		return name
	end
	local cwd_suffix = M.slugify(vim.fn.getcwd())
	for _, candidate in ipairs(saved) do
		if vim.endswith(candidate, cwd_suffix) then
			return candidate
		end
	end
	return nil
end

return M
