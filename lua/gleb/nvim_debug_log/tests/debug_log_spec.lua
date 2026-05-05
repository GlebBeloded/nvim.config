local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local child = MiniTest.new_child_neovim()

local function read_latest_log()
	local files = vim.fn.glob("/tmp/nvim/*.txt", false, true)
	if #files == 0 then
		return ""
	end
	table.sort(files)
	return table.concat(vim.fn.readfile(files[#files]), "\n")
end

local function expect_contains(haystack, needle)
	if not haystack:find(needle, 1, true) then
		error(string.format("expected log to contain %q\n--- actual ---\n%s", needle, haystack))
	end
end

local function wait_for_log(needle, timeout_ms)
	local elapsed = 0
	while elapsed < timeout_ms do
		if read_latest_log():find(needle, 1, true) then
			return
		end
		vim.uv.sleep(200)
		elapsed = elapsed + 200
	end
	expect_contains(read_latest_log(), needle)
end

local function require_module()
	child.lua([[require("gleb.nvim_debug_log")]])
end

local T = new_set({
	hooks = {
		pre_case = function()
			vim.fn.delete("/tmp/nvim", "rf")
			vim.fn.mkdir("/tmp/nvim", "p")
			child.restart({ "-u", "NONE", "--cmd", "set rtp+=" .. vim.env.HOME .. "/.config/nvim" })
		end,
		post_once = function()
			child.stop()
		end,
	},
})

T["captures vim.notify"] = function()
	require_module()
	child.lua([[vim.notify("TEST_notify")]])
	wait_for_log("TEST_notify", 3000)
end

T["captures :echo from ex command"] = function()
	require_module()
	child.cmd('echo "TEST_echo_excmd"')
	wait_for_log("TEST_echo_excmd", 3000)
end

T["captures :echom from ex command"] = function()
	require_module()
	child.cmd('echom "TEST_echom_excmd"')
	wait_for_log("TEST_echom_excmd", 3000)
end

T["captures errors"] = function()
	require_module()
	child.lua([[vim.api.nvim_err_writeln("TEST_err_msg")]])
	wait_for_log("TEST_err_msg", 3000)
end

T["periodic flush works during session"] = function()
	require_module()
	child.cmd('echom "FLUSH_DURING_SESSION"')
	-- Read before the explicit timer interval would have fired naturally:
	-- the wait_for_log helper polls; if the timer is broken, this will time out.
	wait_for_log("FLUSH_DURING_SESSION", 3000)
end

return T
