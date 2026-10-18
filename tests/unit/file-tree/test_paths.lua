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

T["file-tree: Project tree move preflights the whole batch"] = MiniTest.new_set()

T["file-tree: Project tree move preflights the whole batch"]["deduplicates nested selections"] = function()
	eq(
		paths.dedupe({
			"/project/internal/billing/invoice.go",
			"/project/README.md",
			"/project/internal",
			"/project/internal/billing",
			"/project/README.md",
		}),
		{ "/project/README.md", "/project/internal" }
	)
end

T["file-tree: Project tree move preflights the whole batch"]["rejects the batch when a later source is missing"] = function()
	local stats = {
		["/project/one.go"] = { dev = 7 },
		["/project/archive"] = { dev = 7 },
	}
	local ok, reason, failed_path = paths.preflight_moves("/project", {
		{ old = "/project/one.go", new = "/project/archive/one.go" },
		{ old = "/project/two.go", new = "/project/archive/two.go" },
	}, {
		lstat = function(path)
			return stats[path]
		end,
		stat = function(path)
			return stats[path]
		end,
		read_dir = function()
			return {}
		end,
	})

	eq({ ok, reason, failed_path }, { nil, "missing", "/project/two.go" })
end

T["file-tree: Project tree move preflights the whole batch"]["rejects case-insensitive target conflicts"] = function()
	local ok, reason, failed_path = paths.preflight_moves("/project", {
		{ old = "/project/invoice.go", new = "/project/archive/invoice.go" },
	}, {
		lstat = function()
			return { dev = 7 }
		end,
		stat = function()
			return { dev = 7 }
		end,
		read_dir = function()
			return { "Invoice.go" }
		end,
	})

	eq({ ok, reason, failed_path }, { nil, "exists", "/project/archive/invoice.go" })
end

T["file-tree: Project tree move preflights the whole batch"]["allows a case-only rename of its source"] = function()
	local ok = paths.preflight_moves("/project", {
		{ old = "/project/Invoice.go", new = "/project/invoice.go" },
	}, {
		lstat = function()
			return { dev = 7 }
		end,
		stat = function()
			return { dev = 7 }
		end,
		read_dir = function()
			return { "Invoice.go" }
		end,
	})

	eq(ok, true)
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

return T
