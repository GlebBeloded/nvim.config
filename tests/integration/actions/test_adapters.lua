local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		Registry = require("gleb.actions.registry")
		Invoked = {}
		local function action(id)
			return {
				id = id,
				title = id,
				category = "Plugin",
				run = function() table.insert(Invoked, id) end,
			}
		end
		Catalog = Registry.new({ {
			action("dap_ui.expand"),
			action("neotest.run"),
			action("mason.install_package"),
			action("lazy.close"),
			action("blink.accept"),
			action("copilot.accept"),
			action("file_tree.open"),
		} })
		Shortcuts = {
			["dap_ui.expand"] = { "<CR>" },
			["neotest.run"] = { "r", "R" },
			["mason.install_package"] = { "i" },
			["lazy.close"] = { "q" },
			["blink.accept"] = { "<CR>" },
			["copilot.accept"] = { "<M-l>" },
			["file_tree.open"] = { "o" },
		}
		function OpenPluginWindow(adapter)
			local buf = vim.api.nvim_create_buf(false, true)
			for lhs, callback in pairs(adapter.mappings(Catalog, Shortcuts)) do
				vim.keymap.set("n", lhs, callback, { buffer = buf })
			end
			return buf
		end
	]])
end

local T = H.child_set(child, start)

T["actions: Adapter output follows current shortcuts"] = function()
	child.lua([[
		Shortcuts["dap_ui.expand"] = { "<CR>", "o" }
	]])
	eq(
		child.lua_get([[(function()
			local dap_ui = require("gleb.actions.adapters.dap_ui").mappings(Catalog, Shortcuts)
			local neotest = require("gleb.actions.adapters.neotest").mappings(Catalog, Shortcuts)
			local mason = require("gleb.actions.adapters.mason").mappings(Catalog, Shortcuts)
			local lazy = require("gleb.actions.adapters.lazy").mappings(Catalog, Shortcuts)
			local blink = require("gleb.actions.adapters.blink").mappings(Catalog, Shortcuts)
			local copilot = require("gleb.actions.adapters.copilot").mappings(Catalog, Shortcuts)

			lazy.q()
			blink["<CR>"][1]()

			Shortcuts["mason.install_package"] = { "i", "I" }
			local mason_accepts_multiple = pcall(require("gleb.actions.adapters.mason").mappings, Catalog, Shortcuts)
			Shortcuts["mason.install_package"] = { "i" }
			Shortcuts["copilot.accept"] = { "<M-l>", "<M-L>" }
			local copilot_accepts_multiple = pcall(require("gleb.actions.adapters.copilot").mappings, Catalog, Shortcuts)
			return {
				dap_ui.expand,
				neotest.run,
				mason.install_package,
				copilot.suggestion.keymap.accept,
				mason_accepts_multiple,
				copilot_accepts_multiple,
				Invoked,
			}
		end)()]]),
		{
			{ "<CR>", "o" },
			{ "r", "R" },
			"i",
			"<M-l>",
			false,
			false,
			{
				"lazy.close",
				"blink.accept",
			},
		}
	)
	eq(
		child.lua_get([[(function()
			local found = {}
			for _, name in ipairs({ "codediff", "differ", "neo_tree" }) do
				if pcall(require, "gleb.actions.adapters." .. name) then
					table.insert(found, name)
				end
			end
			return found
		end)()]]),
		{}
	)
end

T["actions: Adapter reassignment applies on reopen"] = function()
	eq(
		child.lua_get([[(function()
			local adapter = require("gleb.actions.adapters.lazy")
			local first_window = OpenPluginWindow(adapter)
			Shortcuts["lazy.close"] = { "l" }
			vim.api.nvim_buf_delete(first_window, { force = true })
			local reopened = OpenPluginWindow(adapter)
			vim.api.nvim_set_current_buf(reopened)
			local old_mapping = vim.fn.maparg("q", "n", false, true)
			local new_mapping = vim.fn.maparg("l", "n", false, true)
			new_mapping.callback()
			return {
				next(old_mapping) == nil,
				new_mapping.buffer == 1,
				Invoked,
			}
		end)()]]),
		{ true, true, { "lazy.close" } }
	)
end

return T
