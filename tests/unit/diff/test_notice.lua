local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local ENGINE_DIR = "lua/gleb/diff/engine"
local FIXTURE_DIR = "tests/unit/diff/fixtures"

local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

local function lua_files(path)
	local files = {}
	for name, kind in vim.fs.dir(path) do
		local child = path .. "/" .. name
		if kind == "directory" then
			vim.list_extend(files, lua_files(child))
		elseif kind == "file" and vim.endswith(name, ".lua") then
			table.insert(files, child)
		end
	end
	table.sort(files)
	return files
end

local T = MiniTest.new_set()

T["diff: NOTICE credits VS Code"] = function()
	local notice = read(ENGINE_DIR .. "/NOTICE")
	eq(notice:find("Visual Studio Code", 1, true) ~= nil, true)
	eq(notice:find("Microsoft Corporation", 1, true) ~= nil, true)
	eq(notice:find("Permission is hereby granted, free of charge", 1, true) ~= nil, true)

	local header = table.concat(vim.fn.readfile(ENGINE_DIR .. "/moves.lua", "", 3), "\n")
	eq(header:find("computeMovedLines.ts", 1, true) ~= nil, true)
	eq(header:find("MIT", 1, true) ~= nil, true)
end

T["diff: Ported files carry their attribution"] = function()
	local notice_path = ENGINE_DIR .. "/NOTICE"
	local license_path = ENGINE_DIR .. "/LICENSE-APACHE-2.0"
	eq(vim.fn.filereadable(notice_path), 1)
	eq(vim.fn.filereadable(license_path), 1)

	local notice = read(notice_path)
	eq(notice:find("IntelliJ IDEA", 1, true) ~= nil, true)
	eq(notice:find("Copyright (C) JetBrains s.r.o.", 1, true) ~= nil, true)
	eq(notice:find("diffbandit.nvim", 1, true) ~= nil, true)
	eq(notice:find("Copyright Corey Kaylor", 1, true) ~= nil, true)
	eq(notice:find("Unicode Character Database", 1, true) ~= nil, true)
	eq(notice:find("Copyright © 1991-2024 Unicode, Inc.", 1, true) ~= nil, true)
	eq(notice:find("Unicode License v3", 1, true) ~= nil, true)
	eq(notice:find("LICENSE-APACHE-2.0", 1, true) ~= nil, true)

	local license = read(license_path)
	eq(license:find("Apache License\n                           Version 2.0, January 2004", 1, true) ~= nil, true)
	eq(license:find("END OF TERMS AND CONDITIONS", 1, true) ~= nil, true)

	local files = vim.list_extend(lua_files(ENGINE_DIR), lua_files(FIXTURE_DIR))
	for _, path in ipairs(files) do
		local header = table.concat(vim.fn.readfile(path, "", 3), "\n")
		local is_vscode = path == ENGINE_DIR .. "/moves.lua" or path:find("/vscode_moves/", 1, true) ~= nil
		local expected_license = is_vscode and "MIT" or "Apache-2.0"
		eq(header:find(expected_license, 1, true) ~= nil, true, {
			fail_reason = path .. " lacks a " .. expected_license .. " header",
		})
		eq(header:find("Modified:", 1, true) ~= nil, true, { fail_reason = path .. " lacks a modification notice" })
	end
end

return T
