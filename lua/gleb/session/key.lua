-- Pure session-key helpers, free of any plugin dependency so they stay testable.
-- See lua/gleb/session/init.lua for how these drive resession.

local M = {}

--- Make a path safe to embed in a session filename.
---@param path string
---@return string
function M.slugify(path)
	return (path:gsub("[/\\:]", "%%"))
end

--- Unique key per zellij pane and directory; degrades gracefully outside zellij.
---@return string name
---@return string slug
function M.session_name()
	local slug = M.slugify(vim.fn.getcwd())
	local parts = {
		vim.env.ZELLIJ_SESSION_NAME or "no-zellij",
		vim.env.ZELLIJ_PANE_ID or "0",
		slug,
	}
	return table.concat(parts, "-"), slug
end

-- Whether `candidate` parses as `<zellij session>-<pane id>-<slug>` with the
-- whole slug as its tail. A zellij session name never holds `%`, so names of
-- deeper paths that merely end with the slug (`x-9-%baz-<slug>`) are rejected.
---@param candidate string
---@param slug string
---@return boolean
local function is_cwd_session(candidate, slug)
	if not vim.endswith(candidate, "-" .. slug) then
		return false
	end
	local head = candidate:sub(1, -#slug - 2)
	return head:match("^[^%%]+%-%d+$") ~= nil
end

-- Resolve which saved session to load: prefer the exact pane key, otherwise
-- reuse the first session for this cwd (pane id changed, e.g. after
-- resurrection); `saved` is newest first (see lua/gleb/session/init.lua).
---@param name string
---@param saved string[]
---@param slug string
---@return string?
function M.resolve(name, saved, slug)
	if vim.tbl_contains(saved, name) then
		return name
	end
	for _, candidate in ipairs(saved) do
		if is_cwd_session(candidate, slug) then
			return candidate
		end
	end
	return nil
end

return M
