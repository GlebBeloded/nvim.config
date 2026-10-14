local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		MiniPick = require("mini.pick")
		MiniPick.setup()
		Select = require("gleb.picker.select")
	]])
end

local T = H.child_set(child, start)

T["select: Code action menu receives picker mappings"] = function()
	child.lua_notify([[Select.select({ "Fix" }, { kind = "codeaction" }, function() end)]])
	assert(child.wait("MiniPick.is_picker_active()"), "shared picker did not open")
	local mappings = child.lua_get([[(function()
		local map = MiniPick.get_picker_opts().mappings
		return {
			map.move_down,
			map.focus_next_down.char,
			map.focus_next_tab.char,
			map.move_up,
			map.focus_previous_up.char,
			map.focus_previous_tab.char,
			map.stop,
			map.close_control_c.char,
			map.choose,
			map.submit_space.char,
		}
	end)()]])

	eq(mappings, { "j", "<Down>", "<Tab>", "k", "<Up>", "<S-Tab>", "<Esc>", "<C-c>", "<CR>", "<Space>" })
	child.type_keys("<Esc>")
end

T["select: Code action popup fits editor width"] = function()
	local widths = child.lua_get([[
		(function()
			vim.o.columns = 80
			local function width(items, prompt)
				return Select.window_config(items, {
					prompt = prompt,
					format_item = function(item) return item.label end,
				}).width
			end
			return {
				short = width({ { label = "Fix" } }, "Actions"),
				long = width({ { label = string.rep("x", 100) } }, "Actions"),
			}
		end)()
	]])

	eq(widths, { short = 9, long = 76 })
end

T["select: Cancelling a code action completes selection"] = function()
	child.lua_notify([[
		cancel_result = { calls = 0, item_is_nil = false, index_is_nil = false }
		Select.select({ "Fix" }, { kind = "codeaction", prompt = "Actions" }, function(item, index)
			cancel_result.calls = cancel_result.calls + 1
			cancel_result.item_is_nil = item == nil
			cancel_result.index_is_nil = index == nil
		end)
	]])
	assert(child.wait("MiniPick.is_picker_active()"), "shared picker did not open")
	child.type_keys("<Esc>")
	assert(child.wait("cancel_result.calls == 1"), "selection callback did not complete")
	local result = child.lua_get([[cancel_result]])

	eq(result, { calls = 1, item_is_nil = true, index_is_nil = true })
end

return T
