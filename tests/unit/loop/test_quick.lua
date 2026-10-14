local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["loop: Literal quick routes exist"] = function()
	local quick = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "tests/quick.sh")), "\n") .. "\n"
	local repo = H.git_repo({
		["lua/gleb/lualine.lua"] = "return {}\n",
		["tests/check.sh"] = "#!/bin/sh\nprintf '%s\\n' \"$*\"\n",
		["tests/quick.sh"] = quick,
		["tests/unit/statusline/test_placeholder.lua"] = "return {}\n",
	})
	for _, script in ipairs({ "tests/check.sh", "tests/quick.sh" }) do
		assert(vim.uv.fs_chmod(vim.fs.joinpath(repo, script), 493))
	end
	H.git(repo, { "add", "-A" })
	H.git(repo, { "commit", "-q", "--amend", "--no-edit" })
	H.git(repo, { "branch", "auto" })
	H.git(repo, { "switch", "-q", "-c", "work" })
	vim.fn.delete(vim.fs.joinpath(repo, "lua/gleb/lualine.lua"))
	H.git(repo, { "add", "-A" })
	H.git(repo, { "commit", "-q", "-m", "delete lualine" })

	local result = vim.system({ "sh", "tests/quick.sh" }, { cwd = repo, text = true }):wait()
	eq({ result.code, result.stdout }, { 0, "quick vs auto: lint trace types test\nlint trace types test\n" })
end

return T
