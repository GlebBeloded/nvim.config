local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_bare()
end)

T["diff: Diff settings validate diff.json"] = MiniTest.new_set()

T["diff: Diff settings validate diff.json"]["defaults missing and malformed state"] = function()
	eq(child.lua_get([[require("gleb.diff.settings").load()]]), { policy = "default", highlight = "by_word" })
	child.lua([[
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile({ "not json" }, path)
	]])
	eq(child.lua_get([[require("gleb.diff.settings").load()]]), { policy = "default", highlight = "by_word" })
end

T["diff: Diff settings validate diff.json"]["accepts known values and rejects unknown ones"] = function()
	child.lua([[
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile({ '{"policy":"ignore_whitespaces_chunks","highlight":"by_char"}' }, path)
	]])
	eq(child.lua_get([[require("gleb.diff.settings").load()]]), {
		policy = "ignore_whitespaces_chunks",
		highlight = "by_char",
	})

	child.lua([[
		local path = vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")
		vim.fn.writefile({ '{"policy":"unknown","highlight":"by_char"}' }, path)
	]])
	eq(child.lua_get([[require("gleb.diff.settings").load()]]), { policy = "default", highlight = "by_word" })
end

T["diff: Diff settings validate diff.json"]["saves both choices"] = function()
	local saved = child.lua_get([[(function()
		local settings = require("gleb.diff.settings")
		settings.save({ policy = "trim_whitespaces", highlight = "by_line" })
		return vim.json.decode(table.concat(vim.fn.readfile(
			vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")
		), "\n"))
	end)()]])
	eq(saved, { policy = "trim_whitespaces", highlight = "by_line" })
end

return T
