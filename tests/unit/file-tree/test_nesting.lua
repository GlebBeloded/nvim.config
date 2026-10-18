local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local function entries(names)
	return vim.tbl_map(function(name)
		return { name = name, path = "/project/" .. name, kind = "file" }
	end, names)
end

local T = MiniTest.new_set()

T["file-tree: Nesting rule nests by capture"] = MiniTest.new_set()

T["file-tree: Nesting rule nests by capture"]["groups matching siblings under each parent"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest(
		"/project",
		entries({
			"discount.go",
			"discount_test.go",
			"invoice.go",
			"invoice_test.go",
			"invoice_mock.go",
			"tax.go",
		}),
		{
			{ parent = "(.+)%.go", children = { "${capture}_test%.go", "${capture}_mock%.go" } },
		}
	)

	eq(result, {
		["discount.go"] = { "discount_test.go" },
		["invoice.go"] = { "invoice_mock.go", "invoice_test.go" },
	})
end

T["file-tree: Nesting patterns match whole names"] = MiniTest.new_set()

T["file-tree: Nesting patterns match whole names"]["does not match prefixes or suffixes"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest("/project", entries({ "go.mod", "go.sum", "go.sum.bak", "xgo.mod" }), {
		{ parent = "go%.mod", children = { "go%.sum" } },
	})

	eq(result, { ["go.mod"] = { "go.sum" } })
end

T["file-tree: Nesting captures are inserted literally"] = MiniTest.new_set()

T["file-tree: Nesting captures are inserted literally"]["escapes pattern punctuation in a capture"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest("/project", entries({ "a.b.ts", "a.b.test.ts", "aXb.test.ts" }), {
		{ parent = "(.+)%.ts", children = { "${capture}%.test%.ts" } },
	})

	eq(result, { ["a.b.ts"] = { "a.b.test.ts" } })
end

T["file-tree: Broken nesting rules are skipped"] = MiniTest.new_set()

T["file-tree: Broken nesting rules are skipped"]["warns once and continues with later rules"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local rules = {
		{ parent = "go%.mod", children = { "${capture}%.sum" } },
		{ parent = "[", children = { "x" } },
		{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } },
	}
	local notifications = {}
	local original_notify = vim.notify
	rawset(vim, "notify", function(message, level)
		notifications[#notifications + 1] = { message = message, level = level }
	end)
	local ok, result = pcall(
		nesting.nest,
		"/project",
		entries({
			"go.mod",
			"go.sum",
			"init.lua",
			"init_spec.lua",
		}),
		rules
	)
	if ok then
		nesting.nest("/project", entries({ "go.mod", "go.sum" }), rules)
	end
	rawset(vim, "notify", original_notify)

	eq(ok, true)
	eq(result, { ["init.lua"] = { "init_spec.lua" } })
	eq(#notifications, 2)
	eq(notifications[1].level, vim.log.levels.WARN)
	eq(notifications[1].message:match("^File tree nesting rule 1 skipped"), "File tree nesting rule 1 skipped")
	eq(notifications[2].level, vim.log.levels.WARN)
	eq(notifications[2].message:match("^File tree nesting rule 2 skipped"), "File tree nesting rule 2 skipped")
end

return T
