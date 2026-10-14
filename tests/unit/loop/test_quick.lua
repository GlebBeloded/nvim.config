local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["loop: Literal quick routes exist"] = function()
	local quick = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "tests/quick.sh")), "\n") .. "\n"
	local routes = {}
	for route in quick:gmatch("[^%s|%)]+") do
		if route == "init.lua" or route:match("^lua/[%w_./-]+%.lua$") then
			routes[route] = true
		end
	end

	assert(next(routes), "tests/quick.sh has no literal Lua routes")
	for route in pairs(routes) do
		eq(vim.fn.filereadable(vim.fs.joinpath(H.root, route)), 1)
	end
end

return T
