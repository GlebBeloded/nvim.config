local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[Key = require("gleb.session.key")]])
end

---@return string
local function cwd_slug()
	return child.lua_get("Key.slugify(vim.fn.getcwd())")
end

---@param name string
---@param available string[]
---@return string?
local function resolve(name, available)
	return child.lua_get("Key.resolve(...)", { name, available })
end

local T = H.child_set(child, start)

T["session: slugify replaces path separators"] = function()
	eq(child.lua_get([[Key.slugify("/Users/me/.config/nvim")]]), "%Users%me%.config%nvim")
end

T["session: session_name combines zellij session, pane and cwd"] = function()
	child.lua([[vim.env.ZELLIJ_SESSION_NAME = "blossom"; vim.env.ZELLIJ_PANE_ID = "5"]])

	eq(child.lua_get("Key.session_name()"), "blossom-5-" .. cwd_slug())
end

T["session: session_name degrades gracefully outside zellij"] = function()
	child.lua("vim.env.ZELLIJ_SESSION_NAME = nil; vim.env.ZELLIJ_PANE_ID = nil")

	eq(child.lua_get("Key.session_name()"), "no-zellij-0-" .. cwd_slug())
end

T["session: resolve prefers the exact pane key"] = function()
	local exact = "blossom-5-" .. cwd_slug()
	local other = "blossom-9-" .. cwd_slug()

	eq(resolve(exact, { other, exact }), exact)
end

T["session: resolve falls back to any session for this cwd"] = function()
	-- Pane id changed (e.g. zellij resurrection): exact key is absent.
	local stale = "blossom-9-" .. cwd_slug()

	eq(resolve("blossom-5-" .. cwd_slug(), { stale }), stale)
end

T["session: resolve returns nil when no session matches the cwd"] = function()
	eq(resolve("blossom-5-" .. cwd_slug(), { "blossom-5-%some%other%dir" }), vim.NIL)
end

return T
