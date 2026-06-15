local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local key = require("gleb.session.key")

local T = new_set()

T["slugify replaces path separators"] = function()
	expect.equality(key.slugify("/Users/me/.config/nvim"), "%Users%me%.config%nvim")
end

T["session_name combines zellij session, pane and cwd"] = function()
	vim.env.ZELLIJ_SESSION_NAME = "blossom"
	vim.env.ZELLIJ_PANE_ID = "5"
	local cwd_slug = key.slugify(vim.fn.getcwd())

	expect.equality(key.session_name(), "blossom-5-" .. cwd_slug)
end

T["session_name degrades gracefully outside zellij"] = function()
	vim.env.ZELLIJ_SESSION_NAME = nil
	vim.env.ZELLIJ_PANE_ID = nil
	local cwd_slug = key.slugify(vim.fn.getcwd())

	expect.equality(key.session_name(), "no-zellij-0-" .. cwd_slug)
end

T["resolve prefers the exact pane key"] = function()
	local cwd_slug = key.slugify(vim.fn.getcwd())
	local exact = "blossom-5-" .. cwd_slug
	local other = "blossom-9-" .. cwd_slug

	expect.equality(key.resolve(exact, { other, exact }), exact)
end

T["resolve falls back to any session for this cwd"] = function()
	-- Pane id changed (e.g. zellij resurrection): exact key is absent.
	local cwd_slug = key.slugify(vim.fn.getcwd())
	local stale = "blossom-9-" .. cwd_slug

	expect.equality(key.resolve("blossom-5-" .. cwd_slug, { stale }), stale)
end

T["resolve returns nil when no session matches the cwd"] = function()
	local name = "blossom-5-" .. key.slugify(vim.fn.getcwd())

	expect.equality(key.resolve(name, { "blossom-5-%some%other%dir" }), nil)
end

return T
