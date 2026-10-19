local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPT = vim.fs.joinpath(H.root, ".archon/scripts/plugin_update.py")
local ISOLATE = [[
import os, pathlib, runpy, sys
os.environ["INPUTS_MODE"] = ""
original_exit = sys.exit
sys.exit = lambda *args: None
module = runpy.run_path(sys.argv[1])
sys.exit = original_exit
module["isolate"].__globals__["LIVE_DATA"] = pathlib.Path(sys.argv[2])
module["isolate"](pathlib.Path(sys.argv[3]), pathlib.Path(sys.argv[4]))
]]

T["loop: Plugin update data includes Mason tools"] = function()
	local dir = H.tempdir(child)
	local live = vim.fs.joinpath(dir, "live")
	local xdg = vim.fs.joinpath(dir, "xdg")
	local config = vim.fs.joinpath(dir, "config")
	for _, path in ipairs({ "lazy/plugin", "site/parser", "mason/bin/rust-analyzer" }) do
		local file = vim.fs.joinpath(live, path)
		vim.fn.mkdir(vim.fs.dirname(file), "p")
		vim.fn.writefile({ path }, file)
	end
	vim.fn.mkdir(xdg, "p")
	vim.fn.mkdir(config, "p")

	local result = H.system(child, { "python3", "-c", ISOLATE, SCRIPT, live, xdg, config }, H.root)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	for _, path in ipairs({ "lazy/plugin", "site/parser", "mason/bin/rust-analyzer" }) do
		eq(vim.fn.filereadable(vim.fs.joinpath(xdg, "data/nvim", path)), 1, { fail_reason = path })
	end
end

T["loop: Context pack skips the update check log"] = function()
	local artifacts = H.tempdir(child)
	vim.fn.writefile({ "FAIL in tests/x.lua | x: update" }, vim.fs.joinpath(artifacts, "check-update.log"))
	vim.fn.writefile({ "FAIL in tests/y.lua | y: gate two" }, vim.fs.joinpath(artifacts, "check-2.log"))
	local code = "import sys; sys.path.insert(0, sys.argv[1]); import context_pack; print(context_pack.last_failures())"
	local result = H.system(
		child,
		{ "python3", "-c", code, vim.fs.joinpath(H.root, ".archon/scripts") },
		artifacts,
		{ ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "c" }
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(vim.trim(result.stdout), "FAIL in tests/y.lua | y: gate two")
end

return T
