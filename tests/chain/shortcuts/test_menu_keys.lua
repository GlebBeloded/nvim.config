-- Chain layer: terminal/macos_menu_keys.sh against a temp defaults plist (never the user's own domain).
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local SCRIPT = vim.fs.joinpath(H.root, "terminal", "macos_menu_keys.sh")

local T = MiniTest.new_set()

---@param cmd string[]
---@return vim.SystemCompleted
local function run(cmd)
	return vim.system(cmd, { text = true }):wait(10000)
end

--- Run the setup step against `plist` as its defaults domain.
---@param plist string
---@return vim.SystemCompleted
local function run_setup(plist)
	return run({ "bash", SCRIPT, plist })
end

---@param plist string
---@return table<string, string>
local function read_equivalents(plist)
	local result = run({ "plutil", "-convert", "json", "-o", "-", plist })
	assert(result.code == 0, result.stderr)
	return vim.json.decode(result.stdout).NSUserKeyEquivalents
end

---@return string
local function temp_plist()
	return vim.fn.tempname() .. ".plist"
end

T["shortcuts: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H"] = function()
	local plist = temp_plist()
	local result = run_setup(plist)
	MiniTest.expect.equality(result.code, 0, result.stderr)
	MiniTest.expect.equality(read_equivalents(plist), {
		["Quit alacritty"] = "@~^q",
		["Hide alacritty"] = "@~^h",
	})
end

T["shortcuts: Menu key setup is idempotent and keeps other entries"] = function()
	local plist = temp_plist()
	local seed = run({
		"defaults",
		"write",
		plist,
		"NSUserKeyEquivalents",
		"-dict",
		"Hide alacritty",
		"@" .. vim.fn.nr2char(0xf70f),
		"Minimize",
		"@m",
	})
	assert(seed.code == 0, seed.stderr)
	run_setup(plist)
	local second = run_setup(plist)
	MiniTest.expect.equality(second.code, 0, second.stderr)
	MiniTest.expect.equality(read_equivalents(plist), {
		["Quit alacritty"] = "@~^q",
		["Hide alacritty"] = "@~^h",
		["Minimize"] = "@m",
	})
end

return T
