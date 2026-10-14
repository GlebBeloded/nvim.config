local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local repo

local function start()
	repo = H.git_repo({
		["sample.go"] = "package sample\n\nfunc Value() int { return 1 }\n",
		["sample_test.go"] = 'package sample\n\nimport "testing"\n\nfunc TestValue(t *testing.T) { if Value() != 1 { t.Fail() } }\n',
	})
	H.write_files(repo, { ["sample.go"] = "package sample\n\nfunc Value() int { return 2 }\n" })
	child.start_config()
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit sample.go")
end

local T = H.child_set(child, start)

T["actions: Plugin-window mappings are action-owned"] = function()
	local ownership = child.lua_get([[(function()
		local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
		local catalog = require("gleb.actions").state.applicator.catalog
		local expected = {
			{ "file_tree.open", "o" },
			{ "dap_ui.expand", "e" },
			{ "diffview.select_next_entry", "<Tab>" },
			{ "differ.next_hunk", "]c" },
			{ "codediff.next_hunk", "]c" },
			{ "neotest.run", "r" },
			{ "mason.install_package", "i" },
			{ "lazy.close", "q" },
			{ "blink.accept", "<CR>" },
			{ "copilot.next", "<M-]>" },
		}
		local missing = {}
		for _, item in ipairs(expected) do
			local id, lhs = item[1], item[2]
			if not catalog:get(id) or not vim.tbl_contains(shortcuts[id] or {}, lhs) then
				table.insert(missing, id)
			end
		end
		return missing
	end)()]])

	eq(ownership, {})
end

T["actions: Unconfigured defaults are absent"] = function()
	local defaults = child.lua_get([[(function()
		local found = {}
		local function mapped(lhs, mode)
			return next(vim.fn.maparg(lhs, mode or "n", false, true)) ~= nil
		end
		vim.cmd("Neotree filesystem")
		found.neo_tree = mapped("<CR>")
		require("lazy").load({ plugins = { "nvim-dap" } })
		require("dapui.windows").layouts[1]:open()
		found.dap_ui = mapped("o")
		vim.cmd("DiffviewOpen")
		found.diffview = mapped("dx")
		pcall(vim.cmd, "tabclose")
		vim.cmd("Differ")
		found.differ = mapped("[c")
		pcall(vim.cmd, "tabclose")
		vim.cmd("CodeDiff")
		found.codediff = mapped("[c")
		pcall(vim.cmd, "tabclose")
		require("neotest").summary.open()
		found.neotest = mapped("<CR>")
		vim.cmd("Mason")
		found.mason = mapped("<CR>")
		vim.cmd("Lazy")
		found.lazy = mapped("K")
		vim.cmd("enew")
		found.blink = mapped("<C-Space>", "i")
		found.copilot = mapped("<M-[>", "i")
		return found
	end)()]])

	eq(defaults, {
		blink = false,
		codediff = false,
		copilot = false,
		dap_ui = false,
		differ = false,
		diffview = false,
		lazy = false,
		mason = false,
		neo_tree = false,
		neotest = false,
	})
end

T["actions: Lazy specs define no shortcut keys"] = function()
	local offenders = child.lua_get([[(function()
		local found = {}
		for _, spec in ipairs(require("gleb.plugins.plugins")) do
			if type(spec) == "table" and spec.keys ~= nil then
				table.insert(found, spec[1])
			end
		end
		table.sort(found)
		return found
	end)()]])

	eq(offenders, {})
end

return T
