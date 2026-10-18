local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local function entries(names)
	return vim.tbl_map(function(name)
		return { name = name, path = "/project/" .. name, kind = "file" }
	end, names)
end

local function default_rules()
	return {
		{ parent = "(.+)%.go", children = { "${capture}_test%.go", "${capture}_mock%.go", "${capture}_string%.go" } },
		{ parent = "(.+)%.proto", children = { "${capture}%.pb%.go", "${capture}_grpc%.pb%.go" } },
		{ parent = "go%.mod", children = { "go%.sum" } },
		{ parent = "go%.work", children = { "go%.work%.sum" } },
		{
			parent = "(.+)%.ts",
			children = {
				"${capture}%.test%.ts",
				"${capture}%.spec%.ts",
				"${capture}%.d%.ts",
				"${capture}%.js",
				"${capture}%.d%.ts%.map",
			},
		},
		{
			parent = "(.+)%.tsx",
			children = { "${capture}%.test%.tsx", "${capture}%.stories%.tsx", "${capture}%.module%.css" },
		},
		{ parent = "(.+)%.js", children = { "${capture}%.js%.map", "${capture}%.min%.js", "${capture}%.d%.ts" } },
		{
			parent = "package%.json",
			children = {
				"package%-lock%.json",
				"yarn%.lock",
				"pnpm%-lock%.yaml",
				"bun%.lock",
				"bun%.lockb",
				"%.npmrc",
				"%.nvmrc",
			},
		},
		{ parent = "tsconfig%.json", children = { "tsconfig%..+%.json" } },
		{ parent = "(.+)%.py", children = { "${capture}%.pyi", "test_${capture}%.py", "${capture}_test%.py" } },
		{
			parent = "pyproject%.toml",
			children = {
				"uv%.lock",
				"poetry%.lock",
				"pdm%.lock",
				"requirements.*%.txt",
				"setup%.cfg",
				"setup%.py",
				"%.python%-version",
			},
		},
		{
			parent = "Cargo%.toml",
			children = { "Cargo%.lock", "rust%-toolchain%.toml", "rustfmt%.toml", "%.rustfmt%.toml", "clippy%.toml" },
		},
		{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } },
		{ parent = "%.gitignore", children = { "%.gitattributes", "%.gitmodules" } },
		{ parent = "README.*", children = { "CHANGELOG.*", "LICENSE.*" } },
		{ parent = "Makefile", children = { ".+%.mk" } },
	}
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

T["file-tree: Earlier nesting rule wins a shared child"] = MiniTest.new_set()

T["file-tree: Earlier nesting rule wins a shared child"]["lifts a claimed chain to its first parent"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest("/project", entries({ "price.ts", "price.js", "price.d.ts", "price.js.map" }), {
		{
			parent = "(.+)%.ts",
			children = { "${capture}%.d%.ts", "${capture}%.js", "${capture}%.d%.ts%.map" },
		},
		{
			parent = "(.+)%.js",
			children = { "${capture}%.js%.map", "${capture}%.d%.ts" },
		},
	})

	eq(result, { ["price.ts"] = { "price.d.ts", "price.js", "price.js.map" } })
end

T["file-tree: Nesting cycles keep rule order"] = MiniTest.new_set()

T["file-tree: Nesting cycles keep rule order"]["drops a claim back to an earlier parent"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest("/project", entries({ "a.ts", "a.js" }), {
		{ parent = "(.+)%.ts", children = { "${capture}%.js" } },
		{ parent = "(.+)%.js", children = { "${capture}%.ts" } },
	})

	eq(result, { ["a.ts"] = { "a.js" } })
end

T["file-tree: Folders never nest"] = MiniTest.new_set()

T["file-tree: Folders never nest"]["excludes directory children"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest("/project", {
		{ name = "invoice.go", path = "/repo/invoice.go", kind = "file" },
		{ name = "invoice_test.go", path = "/repo/invoice_test.go", kind = "directory" },
	}, {
		{ parent = "(.+)%.go", children = { "${capture}_test%.go" } },
	})

	eq(result, {})
end

T["file-tree: Default nesting rules meet the large-folder bound"] = MiniTest.new_set()

T["file-tree: Default nesting rules meet the large-folder bound"]["groups 5000 files within 50 ms"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local names = {}
	for index = 1, 2500 do
		names[#names + 1] = ("file_%04d.go"):format(index)
		names[#names + 1] = ("file_%04d_test.go"):format(index)
	end
	local folder_entries = entries(names)
	local rules = default_rules()

	nesting.nest("/project", folder_entries, rules)
	local started = vim.uv.hrtime()
	local result = nesting.nest("/project", folder_entries, rules)
	local elapsed_ms = (vim.uv.hrtime() - started) / 1000000

	eq(#vim.tbl_keys(result), 2500)
	if elapsed_ms > 50 then
		error(("expected nesting to finish within 50 ms, took %.2f ms"):format(elapsed_ms))
	end
end

T["file-tree: Git redraw reuses the nest map"] = MiniTest.new_set()

T["file-tree: Git redraw reuses the nest map"]["runs a Lua rule once for an unchanged scan"] = function()
	local model = require("gleb.file_tree.model")
	local settings = require("gleb.file_tree.settings")
	local scan = entries({ "invoice.go", "invoice_test.go" })
	local calls = 0
	local rules = {
		{
			lua = function()
				calls = calls + 1
				return { ["invoice.go"] = { "invoice_test.go" } }
			end,
		},
	}
	local tree = {
		root = "/project",
		scan = function()
			return scan
		end,
	}
	local generation = settings.generation()

	model.rows(tree, {}, {}, { enabled = true, rules = rules, generation = generation })
	model.rows(tree, {}, { ["invoice_test.go"] = "modified" }, {
		enabled = true,
		rules = rules,
		generation = generation,
	})

	eq(calls, 1)
	settings.reload()
	if settings.generation() <= generation then
		error("expected settings reload to bump the generation")
	end
end

return T
