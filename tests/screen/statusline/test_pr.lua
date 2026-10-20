local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local child = H.new_child()

local function start()
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(manifest))
	child.start_config()
	child.wait_very_lazy()
	child.o.columns = 100
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua(
		[[
		local root = ...
		Ready = false
		require("gleb.git.base").resolve(root, function()
			vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function() Ready = true end })
			require("gleb.pr").refresh(root)
		end)
	]],
		{ root }
	)
	assert(child.wait("Ready == true", math.floor(5000 * H.load_factor())))
	child.cmd("redrawstatus")
end

local T = H.child_set(child, start)

T["statusline: Statusline with a pull request matches the approved render"] = function()
	MiniTest.expect.equality(
		table.concat(H.screen_rows(child, -1).text[1]),
		" NORMAL  ⎇ feat/tax   #482  󰂈 3                                                     0  0 ●  go "
	)
	H.expect_screen_colors(child, -1, {
		"aaaaaaaabbbbbbbbbbbbbccccccbbdddbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbeeeeeffffghihhhhj",
	}, {
		a = "lualine_a_normal",
		b = "lualine_b_normal",
		c = "PrStatuslineNumber",
		d = "PrStatuslineThreads",
		e = "lualine_x_diagnostics_error_normal",
		f = "lualine_x_diagnostics_warn_normal",
		g = "StatuslineLangCapOk",
		h = "StatuslineLangText",
		i = "StatuslineLang_go",
		j = "StatuslineLangEdge",
	})
end

return T
