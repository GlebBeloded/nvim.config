local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		local actions = setmetatable({}, {
			__index = function(_, key)
				return setmetatable({ name = key }, { __add = function() return {} end })
			end,
		})
		package.loaded["telescope.actions"] = actions
		package.loaded.telescope = {
			setup = function(options) TelescopeOptions = options end,
		}
	]])
end

local T = H.child_set(child, start)

T["telescope: Telescope prompt maps move selection"] = function()
	child.lua([[dofile(vim.fs.joinpath(vim.fn.getcwd(), "lua/gleb/telescope.lua"))]])

	eq(child.lua_get([[TelescopeOptions.defaults.mappings.i["<C-j>"].name]]), "move_selection_next")
	eq(child.lua_get([[TelescopeOptions.defaults.mappings.i["<C-k>"].name]]), "move_selection_previous")
end

return T
