local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

---@param path string
---@param content string
local function write_executable(path, content)
	child.lua("vim.fn.writefile(vim.split(..., '\\n'), select(2, ...)); vim.uv.fs_chmod(select(2, ...), 493)", {
		content,
		path,
	})
end

---@param cmd string[]
---@param cwd string
---@param env? table<string, string>
---@return { code: integer, stdout: string, stderr: string }
local function system(cmd, cwd, env)
	return child.lua_get("vim.system(..., { cwd = select(2, ...), env = select(3, ...), text = true }):wait(30000)", {
		cmd,
		cwd,
		env or vim.empty_dict(),
	})
end

---@return string
local function tempdir()
	return child.lua_get(
		"(function() local d = vim.fn.tempname(); vim.fn.mkdir(d, 'p'); return vim.uv.fs_realpath(d) end)()"
	)
end

--- Temp checkout with this repo's guest_restore.sh and a `terminal/` holding only `setup`
--- (as `terminal/macos_test.sh`), if given; returns the restore script path.
---@param setup? string
---@return string
local function make_checkout(setup)
	local root = tempdir()
	local sandbox = vim.fs.joinpath(root, "tests/sandbox")
	child.fn.mkdir(sandbox, "p")
	child.fn.mkdir(vim.fs.joinpath(root, "terminal"), "p")
	local script = vim.fs.joinpath(sandbox, "guest_restore.sh")
	child.lua("assert(vim.uv.fs_copyfile(...))", { vim.fs.joinpath(H.root, "tests/sandbox/guest_restore.sh"), script })
	if setup then
		write_executable(vim.fs.joinpath(root, "terminal/macos_test.sh"), setup)
	end
	return script
end

---@return string
local function temp_plist()
	return vim.fs.joinpath(tempdir(), "org.alacritty.plist")
end

T["shortcuts: Guest restore drops Alacritty defaults the branch does not define"] = function()
	local script = make_checkout()
	local plist = temp_plist()
	local seed = system({
		"defaults",
		"write",
		plist,
		"NSUserKeyEquivalents",
		"-dict-add",
		"Quit alacritty",
		"@~^q",
		"Hide alacritty",
		"@~^h",
	}, H.root)
	eq(seed.code, 0)

	local restore = system({ script, plist }, H.root)

	eq({ code = restore.code, stderr = restore.stderr }, { code = 0, stderr = "" })
	MiniTest.expect.no_equality(system({ "defaults", "read", plist, "NSUserKeyEquivalents" }, H.root).code, 0)
end

T["shortcuts: Guest restore applies the branch's own terminal setup"] = function()
	local script = make_checkout('#!/bin/sh\ndefaults write "$1" TestKey -string fresh')
	local plist = temp_plist()

	local restore = system({ script, plist }, H.root)

	eq({ code = restore.code, stderr = restore.stderr }, { code = 0, stderr = "" })
	local exported = system({ "sh", "-c", 'defaults export "$1" - | plutil -convert json -o - -', "sh", plist }, H.root)
	eq(exported.code, 0)
	eq(vim.json.decode(exported.stdout), { TestKey = "fresh" })
end

return T
