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

--- Open a plugin surface under the process-level deadline.
---@param open string Lua statement
---@param filetype string
---@param surface? string
---@param condition? string
local function open_surface(open, filetype, surface, condition)
	H.open_surface(child, {
		open = open,
		condition = condition or ("PluginBuffer(%q) ~= nil"):format(filetype),
		surface = surface or filetype,
	})
end

local function expect_blocked_differ_diagnostic()
	local blocked = H.new_child()
	blocked.start_config()
	blocked.wait_very_lazy()
	blocked.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit sample.go")
	blocked.lua([[
		local system = vim.system
		vim.system = function(command, opts, on_exit)
			if command[1] == "git" then
				return system({ "/bin/sleep", "30" }, opts, on_exit)
			end
			return system(command, opts, on_exit)
		end
	]])

	local started = vim.uv.hrtime()
	local ok, diagnostic = pcall(H.open_surface, blocked, {
		open = [[vim.cmd("Differ")]],
		condition = [[vim.bo.filetype == "differdiff"]],
		surface = "Differ",
		timeout = 250,
	})
	local elapsed = (vim.uv.hrtime() - started) / 1000000
	pcall(blocked.stop)

	eq(ok, false)
	eq(elapsed < 10000, true)
	for _, field in ipairs({ "Differ", "phase: opening", "elapsed:", "mode:", "getchar:", "messages:", "sleep" }) do
		assert(tostring(diagnostic):find(field, 1, true), ("missing %q in %s"):format(field, diagnostic))
	end
end

---@param filetype string
---@param lhs string
---@param mode? string
---@return boolean
local function plugin_mapped(filetype, lhs, mode)
	return child.lua_get("PluginMapped(...)", { filetype, lhs, mode or "n" })
end

local function expect_audit_empty()
	eq(child.lua_get([[require("gleb.actions").audit()]]), {})
end

T["actions: Plugin-window mappings are action-owned"] = function()
	child.lua(PLUGIN_MAPPED)
	open_surface([[vim.cmd("Neotree filesystem")]], "neo-tree")
	eq(
		child.lua_get([[(function()
			local buf = assert(PluginBuffer("neo-tree"))
			vim.keymap.set("n", "z", "<Nop>", { buffer = buf })
			local report = require("gleb.actions").audit()
			vim.keymap.del("n", "z", { buffer = buf })
			return vim.tbl_contains(report, "neo-tree n z")
		end)()]]),
		true
	)
	eq(
		child.lua_get([[(function()
			local store = require("gleb.actions").state.store
			local assigned = store.last_good["neo_tree.delete"]
			store.last_good["neo_tree.delete"] = nil
			local report = require("gleb.actions").audit()
			store.last_good["neo_tree.delete"] = assigned
			return vim.tbl_contains(report, "neo-tree n d")
		end)()]]),
		true
	)
	expect_audit_empty()
	open_surface(
		[[require("lazy").load({ plugins = { "nvim-dap" } }) require("dapui.windows").layouts[1]:open()]],
		"dapui_scopes"
	)
	expect_audit_empty()
	open_surface([[vim.cmd("DiffviewOpen")]], "DiffviewFiles")
	expect_audit_empty()
	open_surface([[vim.cmd("Differ")]], "differdiff")
	expect_audit_empty()
	open_surface([[vim.cmd("CodeDiff")]], "codediff-explorer")
	expect_audit_empty()
	open_surface([[require("neotest").summary.open()]], "neotest-summary")
	expect_audit_empty()
	open_surface(
		[[require("mason.settings").current.ui.check_outdated_packages_on_open = false vim.cmd("Mason")]],
		"mason"
	)
	expect_audit_empty()
	open_surface([[require("lazy.core.config").headless = function() return false end vim.cmd("Lazy")]], "lazy")
	expect_audit_empty()
	open_surface(
		[[
		vim.api.nvim_list_uis = function()
			return { { width = vim.o.columns, height = vim.o.lines } }
		end
		require("99").open()
	]],
		"99",
		"99",
		[[vim.bo.filetype == "99" or vim.bo.filetype == "99prompt"]]
	)
	expect_audit_empty()

	eq(
		child.lua_get([[(function()
			package.loaded["copilot"] = {
				setup = function(opts) vim.g.copilot_setup_opts = opts end,
			}
			package.loaded["copilot.config.suggestion"] = {
				default = { keymap = {
					accept = "<M-l>", accept_word = false, accept_line = false,
					next = "<M-]>", prev = "<M-[>", dismiss = "<C-]>",
				} },
			}
			package.loaded["gleb.copilot"] = nil
			require("gleb.copilot")
			return vim.g.copilot_setup_opts.suggestion
		end)()]]),
		{
			auto_trigger = true,
			keymap = {
				accept = false,
				accept_word = false,
				accept_line = false,
				next = "<M-]>",
				prev = "<M-[>",
				dismiss = "<C-]>",
			},
		}
	)
	expect_blocked_differ_diagnostic()
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
	found.differ = plugin_mapped("differdiff", "dl")
	child.lua([[pcall(vim.cmd, "tabclose")]])
	open_surface([[vim.cmd("CodeDiff")]], "codediff-explorer")
	found.codediff = plugin_mapped("codediff-explorer", "<CR>")
	child.lua([[pcall(vim.cmd, "tabclose")]])
	open_surface([[require("neotest").summary.open()]], "neotest-summary")
	found.neotest = plugin_mapped("neotest-summary", "<CR>")
	open_surface([[vim.cmd("Mason")]], "mason")
	found.mason = plugin_mapped("mason", "c")
	-- lazy.nvim opens no window without a UI; the child has none
	open_surface([[require("lazy.core.config").headless = function() return false end vim.cmd("Lazy")]], "lazy")
	found.lazy = plugin_mapped("lazy", "<localleader>l")
	child.lua([[vim.cmd("enew") vim.cmd("startinsert")]])
	found.blink = child.lua_get([[vim.fn.maparg("<C-y>", "i", false, true).buffer == 1]])
	child.lua([[vim.cmd("stopinsert")]])

	eq(found, {
		blink = false,
		codediff = false,
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
