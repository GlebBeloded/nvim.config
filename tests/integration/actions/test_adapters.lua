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
			action("differ.next_hunk"),
			action("codediff.next_hunk"),
			action("dap_ui.expand"),
			action("neotest.run"),
			action("mason.install_package"),
			action("lazy.close"),
			action("blink.accept"),
			action("copilot.accept"),
			action("file_tree.open"),
		} })
		Shortcuts = {
			["differ.next_hunk"] = { "]c" },
			["codediff.next_hunk"] = { "]d" },
			["dap_ui.expand"] = { "<CR>" },
			["neotest.run"] = { "r" },
			["mason.install_package"] = { "i" },
			["lazy.close"] = { "q" },
			["blink.accept"] = { "<CR>" },
			["copilot.accept"] = { "<M-l>" },
			["file_tree.open"] = { "o" },
		}
		function InvokeNamedMapping(mappings, area, lhs)
			local callbacks = {}
			for name, native_lhs in pairs(mappings) do
				local lhs_list = type(native_lhs) == "table" and native_lhs or { native_lhs }
				for _, mapped_lhs in ipairs(lhs_list) do
					local action = assert(Catalog:get(area .. "." .. name))
					callbacks[mapped_lhs] = require("gleb.actions.context").invoke(action)
				end
			end
			assert(callbacks[lhs], "missing native mapping for " .. lhs)()
		end
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
			local differ = require("gleb.actions.adapters.differ").mappings(Catalog, Shortcuts)
			local codediff = require("gleb.actions.adapters.codediff").mappings(Catalog, Shortcuts)
			local dap_ui = require("gleb.actions.adapters.dap_ui").mappings(Catalog, Shortcuts)
			local neotest = require("gleb.actions.adapters.neotest").mappings(Catalog, Shortcuts)
			local mason = require("gleb.actions.adapters.mason").mappings(Catalog, Shortcuts)
			local lazy = require("gleb.actions.adapters.lazy").mappings(Catalog, Shortcuts)
			local blink = require("gleb.actions.adapters.blink").mappings(Catalog, Shortcuts)
			local copilot = require("gleb.actions.adapters.copilot").mappings(Catalog, Shortcuts)
			local neo_tree = require("gleb.actions.adapters.neo_tree").mappings(Catalog, Shortcuts)

			InvokeNamedMapping(differ, "differ", "]c")
			InvokeNamedMapping(codediff.keymaps.view, "codediff", "]d")
			InvokeNamedMapping(dap_ui, "dap_ui", "<CR>")
			InvokeNamedMapping(dap_ui, "dap_ui", "o")
			InvokeNamedMapping(neotest, "neotest", "r")
			InvokeNamedMapping(mason, "mason", "i")
			InvokeNamedMapping(copilot.suggestion.keymap, "copilot", "<M-l>")
			lazy.q()
			blink["<CR>"][1]()
			neo_tree.o()

			Shortcuts["mason.install_package"] = { "i", "I" }
			local mason_accepts_multiple = pcall(require("gleb.actions.adapters.mason").mappings, Catalog, Shortcuts)
			Shortcuts["mason.install_package"] = { "i" }
			Shortcuts["copilot.accept"] = { "<M-l>", "<M-L>" }
			local copilot_accepts_multiple = pcall(require("gleb.actions.adapters.copilot").mappings, Catalog, Shortcuts)
			return {
				differ.next_hunk,
				codediff.keymaps.view.next_hunk,
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
			"]c",
			"]d",
			{ "<CR>", "o" },
			"r",
			"i",
			"<M-l>",
			false,
			false,
			{
				"differ.next_hunk",
				"codediff.next_hunk",
				"dap_ui.expand",
				"dap_ui.expand",
				"neotest.run",
				"mason.install_package",
				"copilot.accept",
				"lazy.close",
				"blink.accept",
				"file_tree.open",
			},
		}
	)
end

T["actions: Adapter reassignment applies on reopen"] = function()
	eq(
		child.lua_get([[(function()
			local adapter = require("gleb.actions.adapters.neo_tree")
			local first_window = OpenPluginWindow(adapter)
			Shortcuts["file_tree.open"] = { "l" }
			vim.api.nvim_buf_delete(first_window, { force = true })
			local reopened = OpenPluginWindow(adapter)
			vim.api.nvim_set_current_buf(reopened)
			local old_mapping = vim.fn.maparg("o", "n", false, true)
			local new_mapping = vim.fn.maparg("l", "n", false, true)
			new_mapping.callback()
			return {
				next(old_mapping) == nil,
				new_mapping.buffer == 1,
				Invoked,
			}
		end)()]]),
		{ true, true, { "file_tree.open" } }
	)
end

return T
