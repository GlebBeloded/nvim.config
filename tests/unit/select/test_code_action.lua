local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare({ "nui.nvim" })
	child.lua([[CodeAction = require("gleb.select.code_action")]])
end

local T = H.child_set(child, start)

T["select: Code action menu receives picker mappings"] = function()
	local keymap = child.lua_get([[CodeAction:new({}, { prompt = "Actions" }, function() end):menu().keymap]])

	eq(keymap, {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	})
end

T["select: Code action popup fits editor width"] = function()
	local widths = child.lua_get([[
		(function()
			vim.o.columns = 80
			local function width(items, prompt)
				return CodeAction:new(items, {
					prompt = prompt,
					format_item = function(item) return item.label end,
				}, function() end):popup_under_cursor_options().size.width
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
	child.lua([[
		cancel_result = { calls = 0, item_is_nil = false, index_is_nil = false }
		CodeAction:new({}, { prompt = "Actions" }, function(item, index)
			cancel_result.calls = cancel_result.calls + 1
			cancel_result.item_is_nil = item == nil
			cancel_result.index_is_nil = index == nil
		end):select()
	]])
	child.type_keys("<Esc>")
	local result = child.lua_get([[cancel_result]])

	eq(result, { calls = 1, item_is_nil = true, index_is_nil = true })
end

return T
