local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local function entries(names)
	return vim.tbl_map(function(name)
		return { name = name, path = "/project/" .. name, kind = "file" }
	end, names)
end

local function default_rules()
	local path = vim.fs.joinpath(H.root, "settings", "file_tree.json")
	local settings = require("gleb.file_tree.settings").load(path)
	return settings.nesting.rules
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

T["file-tree: Default nesting rules nest Go files"] = MiniTest.new_set()

T["file-tree: Default nesting rules nest Go files"]["groups Go companions"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest(
		"/project",
		entries({
			"invoice.go",
			"invoice_test.go",
			"invoice_mock.go",
			"invoice_string.go",
			"api.proto",
			"api.pb.go",
			"api_grpc.pb.go",
			"go.mod",
			"go.sum",
			"go.work",
			"go.work.sum",
		}),
		default_rules()
	)

	eq(result, {
		["api.proto"] = { "api.pb.go", "api_grpc.pb.go" },
		["go.mod"] = { "go.sum" },
		["go.work"] = { "go.work.sum" },
		["invoice.go"] = { "invoice_mock.go", "invoice_string.go", "invoice_test.go" },
	})
end

T["file-tree: Default nesting rules nest web files"] = MiniTest.new_set()

T["file-tree: Default nesting rules nest web files"]["groups web companions"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest(
		"/project",
		entries({
			"price.ts",
			"price.test.ts",
			"price.spec.ts",
			"price.d.ts",
			"price.js",
			"price.d.ts.map",
			"price.js.map",
			"cart.tsx",
			"cart.test.tsx",
			"cart.stories.tsx",
			"cart.module.css",
			"util.js",
			"util.min.js",
			"util.d.ts",
			"package.json",
			"package-lock.json",
			"yarn.lock",
			".npmrc",
			".nvmrc",
			"tsconfig.json",
			"tsconfig.build.json",
		}),
		default_rules()
	)

	eq(result, {
		["cart.tsx"] = { "cart.module.css", "cart.stories.tsx", "cart.test.tsx" },
		["package.json"] = { ".npmrc", ".nvmrc", "package-lock.json", "yarn.lock" },
		["price.ts"] = { "price.d.ts", "price.d.ts.map", "price.js", "price.js.map", "price.spec.ts", "price.test.ts" },
		["tsconfig.json"] = { "tsconfig.build.json" },
		["util.js"] = { "util.d.ts", "util.min.js" },
	})
end

T["file-tree: Default nesting rules nest Python and Rust files"] = MiniTest.new_set()

T["file-tree: Default nesting rules nest Python and Rust files"]["groups Python and Rust companions"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest(
		"/project",
		entries({
			"money.py",
			"money.pyi",
			"test_money.py",
			"money_test.py",
			"pyproject.toml",
			"uv.lock",
			"requirements-dev.txt",
			"setup.cfg",
			"setup.py",
			".python-version",
			"Cargo.toml",
			"Cargo.lock",
			"rust-toolchain.toml",
			"rustfmt.toml",
			".rustfmt.toml",
			"clippy.toml",
		}),
		default_rules()
	)

	eq(result, {
		["Cargo.toml"] = { ".rustfmt.toml", "Cargo.lock", "clippy.toml", "rust-toolchain.toml", "rustfmt.toml" },
		["money.py"] = { "money.pyi", "money_test.py", "test_money.py" },
		["pyproject.toml"] = { ".python-version", "requirements-dev.txt", "setup.cfg", "setup.py", "uv.lock" },
	})
end

T["file-tree: Default nesting rules nest project files"] = MiniTest.new_set()

T["file-tree: Default nesting rules nest project files"]["groups project companions"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local result = nesting.nest(
		"/project",
		entries({
			"init.lua",
			"init_spec.lua",
			".gitignore",
			".gitattributes",
			".gitmodules",
			"README.md",
			"CHANGELOG.md",
			"LICENSE",
			"Makefile",
			"rules.mk",
		}),
		default_rules()
	)

	eq(result, {
		[".gitignore"] = { ".gitattributes", ".gitmodules" },
		["init.lua"] = { "init_spec.lua" },
		Makefile = { "rules.mk" },
		["README.md"] = { "CHANGELOG.md", "LICENSE" },
	})
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

T["file-tree: Lua nesting rule nests by function"] = MiniTest.new_set()

T["file-tree: Lua nesting rule nests by function"]["passes the folder and sorted file names"] = function()
	local nesting = require("gleb.file_tree.nesting")
	local received
	package.preload.nest_sql = function()
		return function(dir, names)
			received = { dir = dir, names = names }
			return { ["schema.sql"] = { "schema_seed.sql", "missing.sql", "schema.sql" } }
		end
	end
	package.loaded.nest_sql = nil

	local result = nesting.nest("/repo/db", entries({ "schema_seed.sql", "other.sql", "schema.sql" }), {
		{ lua = "nest_sql" },
	})

	package.loaded.nest_sql = nil
	package.preload.nest_sql = nil
	eq(received, { dir = "/repo/db", names = { "other.sql", "schema.sql", "schema_seed.sql" } })
	eq(result, { ["schema.sql"] = { "schema_seed.sql" } })
end

T["file-tree: Failing Lua nesting rule is skipped"] = MiniTest.new_set()

T["file-tree: Failing Lua nesting rule is skipped"]["warns once and continues with a later rule"] = function()
	local nesting = require("gleb.file_tree.nesting")
	package.preload.nest_boom = function()
		return function()
			error("boom")
		end
	end
	package.loaded.nest_boom = nil
	local notifications = {}
	local original_notify = vim.notify
	rawset(vim, "notify", function(message, level)
		notifications[#notifications + 1] = { message = message, level = level }
	end)

	local ok, result = pcall(nesting.nest, "/repo/lua", entries({ "init_spec.lua", "init.lua" }), {
		{ lua = "nest_boom" },
		{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } },
	})

	rawset(vim, "notify", original_notify)
	package.loaded.nest_boom = nil
	package.preload.nest_boom = nil
	eq(ok, true)
	eq(result, { ["init.lua"] = { "init_spec.lua" } })
	eq(#notifications, 1)
	eq(notifications[1].level, vim.log.levels.WARN)
	eq(notifications[1].message:match("^File tree nesting rule 1 skipped"), "File tree nesting rule 1 skipped")
	eq(notifications[1].message:find("boom", 1, true) ~= nil, true)
end

return T
