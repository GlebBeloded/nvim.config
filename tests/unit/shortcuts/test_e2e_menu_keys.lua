local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

---@param mode "skipped"|"fatal"|"launch_failure"|"stop_failure"
---@return string[], fun(fn: fun(stack: table))
local function load_helper(mode)
	local loaded, menu_keys = pcall(require, "tests.e2e.shortcuts.menu_keys")
	eq(loaded, true)

	local calls, starts = {}, 1
	local deps = {
		preflight = function()
			if mode == "skipped" then
				return "host refused", false
			end
			if mode == "fatal" then
				return "menu keys absent", true
			end
		end,
		skip = function()
			error("SKIPPED", 0)
		end,
		stop = function()
			table.insert(calls, "stop")
		end,
		start = function()
			starts = starts + 1
			table.insert(calls, "start")
			if mode == "launch_failure" and starts == 2 then
				error("injected launch failure")
			end
			local instance = starts
			return {
				stop = function()
					table.insert(calls, "stop")
					if mode == "stop_failure" and instance == 2 then
						error("injected stop failure")
					end
				end,
			}
		end,
		run = function(argv)
			table.insert(calls, table.concat(argv, " "))
			return { code = 0, stdout = "", stderr = "" }
		end,
		root = vim.fn.getcwd(),
		set_stack = function() end,
	}
	return calls, function(fn)
		menu_keys.with_absent(deps, fn)
	end
end

T["shortcuts: Controlled no-setup regressions do not mutate when e2e cannot run"] = function()
	local E = require("tests.e2e.alacritty")
	local preflight = E.preflight
	rawset(E, "preflight", function()
		return "menu keys absent", true
	end)
	local started, reason = pcall(E.start_or_skip)
	rawset(E, "preflight", preflight)
	eq(started, false)
	eq(tostring(reason):find("menu keys absent", 1, true) ~= nil, true)

	for _, mode in ipairs({ "skipped", "fatal" }) do
		local calls, helper = load_helper(mode)

		local ok = pcall(helper, function() end)

		eq(ok, false)
		eq(calls, {})
	end
end

T["shortcuts: Controlled no-setup regressions restore menu keys after lifecycle failures"] = function()
	for _, mode in ipairs({ "launch_failure", "stop_failure" }) do
		local calls, helper = load_helper(mode)

		local ok = pcall(helper, function() end)

		eq(ok, false)
		local script = vim.fs.joinpath(vim.fn.getcwd(), "terminal", "macos_menu_keys.sh")
		local expected = mode == "launch_failure"
				and { "stop", "defaults delete org.alacritty NSUserKeyEquivalents", "start", script, "start" }
			or { "stop", "defaults delete org.alacritty NSUserKeyEquivalents", "start", "stop", script, "start" }
		eq(calls, expected)
	end
end

return T
