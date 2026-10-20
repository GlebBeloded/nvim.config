local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function setup(with_pr, with_threads)
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	local files = pr482(manifest)
	if not with_pr then
		files["pr.json"] = nil
	end
	H.write_files(gh_dir, files)
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua([[Done = false; require("gleb.git.base").resolve(..., function() Done = true end)]], { root })
	assert(child.wait("Done == true", math.floor(5000 * H.load_factor())))
	if with_pr and with_threads then
		child.lua(
			[[
			ThreadsDone = false
			vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function() ThreadsDone = true end })
			require("gleb.pr").refresh(...)
		]],
			{ root }
		)
		assert(child.wait("ThreadsDone == true", math.floor(5000 * H.load_factor())))
	end
	return root
end

local T = H.child_set(child, child.start_config)

T["statusline: Statusline shows the pull request and its open threads"] = function()
	setup(true, true)
	eq(require("tests.helpers") ~= nil, true)
	eq(
		child.lua_get([[require("gleb.pr.statusline").component()]]),
		"%#lualine_b_normal# %#PrStatuslineNumber# #482%#lualine_b_normal#  %#PrStatuslineThreads#󰂈 3"
	)
end

T["statusline: Statusline shows the number before the threads load"] = function()
	setup(true, false)
	eq(
		child.lua_get([[require("gleb.pr.statusline").component()]]),
		"%#lualine_b_normal# %#PrStatuslineNumber# #482"
	)
end

T["statusline: Statusline hides the pull request component without a PR"] = function()
	setup(false, false)
	eq(child.lua_get([[require("gleb.pr.statusline").cond()]]), false)
	eq(child.lua_get([[require("gleb.pr.statusline").component()]]), "")
end

T["statusline: Statusline pull request component runs nothing on redraw"] = function()
	setup(true, true)
	child.lua([[
		SystemCalls = 0
		local system = vim.system
		vim.system = function(...) SystemCalls = SystemCalls + 1; return system(...) end
		for _ = 1, 10 do vim.cmd.redrawstatus() end
	]])
	eq(child.lua_get([[SystemCalls]]), 0)
end

T["statusline: Statusline pull request colours"] = function()
	setup(true, true)
	child.cmd("colorscheme gruvbox-material")
	local expected = child.lua_get([[(function()
		local p = require("gleb.colors.gruvbox-material.palette")
		local bg = vim.api.nvim_get_hl(0, { name = "lualine_b_normal" }).bg
		return { number = { fg = tonumber(p.foreground.purple:sub(2), 16), bg = bg }, threads = { fg = tonumber(p.foreground.yellow:sub(2), 16), bg = bg } }
	end)()]])
	for group, colors in pairs({ PrStatuslineNumber = expected.number, PrStatuslineThreads = expected.threads }) do
		local actual = child.lua_get([[vim.api.nvim_get_hl(0, { name = ... })]], { group })
		eq({ actual.fg, actual.bg }, { colors.fg, colors.bg })
	end
end

return T
