local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local paths = require("gleb.file_tree.paths")

local T = MiniTest.new_set()

T["file-tree: Project tree refuses operations on the root row"] = MiniTest.new_set()

T["file-tree: Project tree refuses operations on the root row"]["rejects the root during move preflight"] = function()
	local ok, reason = paths.preflight_moves("/project", {
		{ old = "/project", new = "/project-renamed" },
	}, {
		lstat = function()
			return { dev = 1 }
		end,
		stat = function()
			return { dev = 1 }
		end,
		read_dir = function()
			return {}
		end,
	})

	eq({ ok, reason }, { nil, "root" })
end

T["file-tree: Project tree refuses a path that escapes the root"] = MiniTest.new_set()

T["file-tree: Project tree refuses a path that escapes the root"]["uses normalized path boundaries"] = function()
	eq(paths.is_inside("/project", "/project/internal/../README.md"), true)
	eq(paths.is_inside("/project", "/project/../../outside"), false)
	eq(paths.is_inside("/project", "/project-other/file"), false)
end

T["file-tree: Project tree refuses a cross-device move"] = MiniTest.new_set()

T["file-tree: Project tree refuses a cross-device move"]["compares the source and destination parent devices"] = function()
	local ok, reason = paths.preflight_moves("/project", {
		{ old = "/project/invoice.go", new = "/project/mount/invoice.go" },
	}, {
		lstat = function()
			return { dev = 1 }
		end,
		stat = function()
			return { dev = 2 }
		end,
		read_dir = function()
			return {}
		end,
	})

	eq({ ok, reason }, { nil, "cross-device" })
end

T["file-tree: Project tree rename skips servers whose filters do not match"] = MiniTest.new_set()

T["file-tree: Project tree rename skips servers whose filters do not match"]["matches recursive extension globs"] = function()
	eq(paths.filter_matches({ scheme = "file", pattern = { glob = "**/*.go" } }, "/project/main.go", "file"), true)
	eq(paths.filter_matches({ scheme = "file", pattern = { glob = "**/*.go" } }, "/project/main.ts", "file"), false)
	eq(paths.filter_matches({ scheme = "untitled", pattern = { glob = "**/*.go" } }, "/project/main.go", "file"), false)
end

T["file-tree: Project tree rename skips servers whose filters do not match"]["matches brace extension globs"] = function()
	eq(paths.filter_matches({ pattern = { glob = "**/*.{ts,tsx}" } }, "/project/web/app.ts", "file"), true)
	eq(paths.filter_matches({ pattern = { glob = "**/*.{ts,tsx}" } }, "/project/web/app.tsx", "file"), true)
	eq(paths.filter_matches({ pattern = { glob = "**/*.{ts,tsx}" } }, "/project/web/app.js", "file"), false)
end

T["file-tree: Project tree rename skips servers whose filters do not match"]["honours case-insensitive patterns"] = function()
	local filter = { pattern = { glob = "**/*.TS", options = { ignoreCase = true } } }
	eq(paths.filter_matches(filter, "/project/web/app.ts", "file"), true)
	eq(paths.filter_matches(filter, "/project/web/app.Ts", "file"), true)
end

T["file-tree: Project tree rename skips servers whose filters do not match"]["distinguishes folders from files"] = function()
	local folder = { pattern = { glob = "**/billing", matches = "folder" } }
	eq(paths.filter_matches(folder, "/project/internal/billing", "directory"), true)
	eq(paths.filter_matches(folder, "/project/internal/billing", "file"), false)
end

return T
