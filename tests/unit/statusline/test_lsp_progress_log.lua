-- Each case points $NVIM_LSP_PROGRESS_LOG at its own temp file before the
-- module loads, so the shared /tmp log of parallel workers is never truncated.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local LOG_MAX_BYTES = 1024 * 1024

local function start()
	child.start_bare()
	-- isolate from lualine: the module only calls refresh() from its timer
	child.lua([[package.loaded.lualine = { refresh = function() end }]])
end

---@param path string
local function load_with_log(path)
	child.lua(
		[[
		vim.env.NVIM_LSP_PROGRESS_LOG = ...
		require("gleb.statusline.lsp_progress")
	]],
		{ path }
	)
end

---@param title string
local function fire_begin(title)
	child.lua(
		[[vim.api.nvim_exec_autocmds("LspProgress", { data = { client_id = 1, params = { token = "t1", value = { kind = "begin", title = ... } } } })]],
		{ title }
	)
end

---@return string
local function unique_title()
	return "CapTitle" .. vim.uv.hrtime()
end

---@param lines string[]
---@param title string
---@return string[]
local function lines_with(lines, title)
	return vim.tbl_filter(function(line)
		return line:find(title, 1, true) ~= nil
	end, lines)
end

--- Runs `case` with a fresh temp log path and deletes the file afterwards.
---@param case fun(path: string)
local function with_temp_log(case)
	local path = vim.fn.tempname()
	local ok, err = pcall(case, path)
	vim.fn.delete(path)
	assert(ok, err)
end

local T = H.child_set(child, start)

T["statusline: oversized progress log is truncated"] = function()
	with_temp_log(function(path)
		vim.fn.writefile({ string.rep("x", LOG_MAX_BYTES), "" }, path, "b")
		eq(vim.uv.fs_stat(path).size, LOG_MAX_BYTES + 1)
		local title = unique_title()

		load_with_log(path)
		fire_begin(title)

		eq(vim.uv.fs_stat(path).size < LOG_MAX_BYTES, true)
		eq(#lines_with(vim.fn.readfile(path), title), 1)
	end)
end

T["statusline: progress log under the cap is appended"] = function()
	with_temp_log(function(path)
		vim.fn.writefile({ "KEEP" }, path)
		local title = unique_title()

		load_with_log(path)
		fire_begin(title)

		local lines = vim.fn.readfile(path)
		eq(#lines, 2)
		eq({ lines[1], #lines_with({ lines[2] }, title) }, { "KEEP", 1 })
	end)
end

return T
