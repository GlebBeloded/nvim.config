local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local CASE = "shortcuts: Cmd+Q quits Alacritty from a real key press"

---@class MenuKeyStub
---@field calls string[]
---@field hooks table
---@field helper fun(fn: fun(stack: table))

--- Load the real e2e suite with only its external macOS/process boundaries stubbed.
---@param mode "skipped"|"launch_failure"|"stop_failure"
---@return MenuKeyStub
local function load_stubbed_suite(mode)
	local saved = {}
	local modules = {
		"mini.test",
		"tests.shortcuts.chain",
		"tests.e2e.alacritty",
		"tests.helpers",
		"tests.shortcuts.stack",
	}
	for _, name in ipairs(modules) do
		saved[name] = package.loaded[name]
	end

	local calls, hooks, starts = {}, nil, 0
	package.loaded["mini.test"] = {
		expect = { equality = function() end },
		new_set = function(opts)
			hooks = opts.hooks
			return {}
		end,
		skip = function()
			error("SKIPPED", 0)
		end,
	}
	package.loaded["tests.shortcuts.chain"] = {}
	package.loaded["tests.helpers"] = { root = vim.fn.getcwd() }
	package.loaded["tests.e2e.alacritty"] = {
		NO_HIT_MS = 300,
		preflight = function()
			if mode == "skipped" then
				return "host refused"
			end
		end,
		start = function()
			starts = starts + 1
			table.insert(calls, "start")
			if mode == "skipped" or (mode == "launch_failure" and starts == 2) then
				error("injected launch failure")
			end
			local instance = starts
			return {
				background = true,
				stop = function()
					table.insert(calls, "stop")
					if mode == "stop_failure" and instance == 2 then
						error("injected stop failure")
					end
				end,
			}
		end,
	}
	package.loaded["tests.shortcuts.stack"] = {
		run = function(argv)
			table.insert(calls, table.concat(argv, " "))
			return { code = 0, stdout = "", stderr = "" }
		end,
	}

	local suite = dofile(vim.fs.joinpath(vim.fn.getcwd(), "tests/e2e/shortcuts/test_e2e.lua"))
	for _, name in ipairs(modules) do
		package.loaded[name] = saved[name]
	end

	local helper
	for index = 1, 100 do
		local name, value = debug.getupvalue(suite[CASE], index)
		if not name then
			break
		end
		if name == "with_menu_keys_absent" then
			helper = value
			break
		end
	end
	return {
		calls = calls,
		hooks = assert(hooks, "e2e suite hooks were not captured"),
		helper = assert(helper, "with_menu_keys_absent was not found"),
	}
end

local function clear(list)
	for index = #list, 1, -1 do
		table.remove(list, index)
	end
end

T["shortcuts: Controlled no-setup regressions do not mutate when e2e cannot run"] = function()
	local stub = load_stubbed_suite("skipped")
	stub.hooks.pre_once()

	local ok = pcall(stub.helper, function() end)

	eq(ok, false)
	eq(stub.calls, {})
end

T["shortcuts: Controlled no-setup regressions restore menu keys after lifecycle failures"] = function()
	for _, mode in ipairs({ "launch_failure", "stop_failure" }) do
		local stub = load_stubbed_suite(mode)
		stub.hooks.pre_once()
		clear(stub.calls)

		local ok = pcall(stub.helper, function() end)

		eq(ok, false)
		local script = vim.fs.joinpath(vim.fn.getcwd(), "terminal", "macos_menu_keys.sh")
		local expected = mode == "launch_failure"
				and { "stop", "defaults delete org.alacritty NSUserKeyEquivalents", "start", script, "start" }
			or { "stop", "defaults delete org.alacritty NSUserKeyEquivalents", "start", "stop", script, "start" }
		eq(stub.calls, expected)
	end
end

return T
