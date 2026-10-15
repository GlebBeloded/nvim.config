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
			{ "neo_tree.open", "o" },
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

--- Child-side `PluginMapped(filetype, lhs, mode)`: does the loaded `filetype` buffer map `lhs` itself?
local PLUGIN_MAPPED = [[
function PluginBuffer(filetype)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == filetype then
			return buf
		end
	end
end
function PluginMapped(filetype, lhs, mode)
	return vim.api.nvim_buf_call(assert(PluginBuffer(filetype), filetype .. " window is not open"), function()
		return vim.fn.maparg(lhs, mode or "n", false, true).buffer == 1
	end)
end]]

--- Run `open` in the child and wait until a `filetype` buffer is loaded.
---@param open string Lua statement
---@param filetype string
local function open_surface(open, filetype)
	child.lua(open)
	assert(child.wait(("PluginBuffer(%q) ~= nil"):format(filetype), 10000), filetype .. " window did not open")
end

---@param filetype string
---@param lhs string
---@param mode? string
---@return boolean
local function plugin_mapped(filetype, lhs, mode)
	return child.lua_get("PluginMapped(...)", { filetype, lhs, mode or "n" })
end

T["actions: Unconfigured defaults are absent"] = function()
	child.lua(PLUGIN_MAPPED)
	local found = {}
	open_surface([[vim.cmd("Neotree filesystem")]], "neo-tree")
	found.neo_tree = plugin_mapped("neo-tree", "C")
	open_surface(
		[[require("lazy").load({ plugins = { "nvim-dap" } }) require("dapui.windows").layouts[1]:open()]],
		"dapui_scopes"
	)
	found.dap_ui = plugin_mapped("dapui_scopes", "<CR>")
	open_surface([[vim.cmd("DiffviewOpen")]], "DiffviewFiles")
	found.diffview = plugin_mapped("DiffviewFiles", "-")
	child.lua([[pcall(vim.cmd, "tabclose")]])
	open_surface([[vim.cmd("Differ")]], "differdiff")
	found.differ = plugin_mapped("differdiff", "[c")
	child.lua([[pcall(vim.cmd, "tabclose")]])
	open_surface([[vim.cmd("CodeDiff")]], "codediff-explorer")
	found.codediff = plugin_mapped("codediff-explorer", "<CR>")
	child.lua([[pcall(vim.cmd, "tabclose")]])
	open_surface([[require("neotest").summary.open()]], "neotest-summary")
	found.neotest = plugin_mapped("neotest-summary", "<CR>")
	open_surface([[vim.cmd("Mason")]], "mason")
	found.mason = plugin_mapped("mason", "<CR>")
	-- lazy.nvim opens no window without a UI; the child has none
	open_surface([[require("lazy.core.config").headless = function() return false end vim.cmd("Lazy")]], "lazy")
	found.lazy = plugin_mapped("lazy", "<localleader>l")
	child.lua([[vim.cmd("enew") vim.cmd("startinsert")]])
	found.blink = child.lua_get([[vim.fn.maparg("<C-y>", "i", false, true).buffer == 1]])
	found.copilot = child.lua_get([[next(vim.fn.maparg("<M-l>", "i", false, true)) ~= nil]])
	child.lua([[vim.cmd("stopinsert")]])

	eq(found, {
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
