-- `make render CASE=<name> [COLUMNS=80] [LINES=24] [OUT=path] [MONO=1 [ATTR=1]]`
-- Renders the real config for a case of tests/render/cases.lua.
--   default  colored: tmux capture with truecolor escapes, written to
--            renders/<case>.ansi (or OUT) and printed
--   MONO=1   plain text from a mini.test child screenshot (ATTR=1 adds the
--            attribute block), printed (and written to OUT when given)
-- Without CASE, lists the cases.

local H = require("tests.helpers")
local cases = require("tests.render.cases")

local M = {}

---@param text string
local function out(text)
	io.write(text .. "\n")
end

---@return string
local function usage()
	local lines = { "Usage: make render CASE=<name> [COLUMNS=80] [LINES=24] [OUT=path] [MONO=1 [ATTR=1]]", "Cases:" }
	local names = vim.tbl_keys(cases)
	table.sort(names)
	for _, name in ipairs(names) do
		table.insert(lines, ("  %-10s %s"):format(name, cases[name].description))
	end
	return table.concat(lines, "\n")
end

---@return render.Size
local function screen_size()
	return { columns = tonumber(vim.env.COLUMNS) or 80, lines = tonumber(vim.env.LINES) or 24 }
end

---@param case render.Case
---@param size render.Size
---@return string
local function mono(case, size)
	local child = H.new_child()
	child.start_config()
	child.o.lines, child.o.columns = size.lines, size.columns
	child.wait_very_lazy()
	case.setup(child)
	vim.uv.sleep(300) -- let timers (lualine, bufferline) redraw
	local text = tostring(child.get_screenshot())
	child.stop()
	return vim.env.ATTR == "1" and text or vim.split(text, "\n\n", { plain = true })[1]
end

---@param path string
---@param text string
local function write(path, text)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end

---@param name string
local function render(name)
	local case, size = cases[name], screen_size()
	local target = vim.env.OUT ~= "" and vim.env.OUT or nil
	local text
	if vim.env.MONO == "1" then
		text = mono(case, size)
	else
		text = require("tests.render.tmux").capture(case, size)
		target = target or vim.fs.joinpath(H.root, "renders", name .. ".ansi")
	end
	out(text)
	if target then
		write(target, text)
		vim.uv.fs_write(2, "render: wrote " .. target .. "\n")
	end
end

function M.run()
	local name = vim.env.CASE
	local ok, err = true, nil
	if not name or name == "" then
		out(usage())
	elseif not cases[name] then
		ok, err = false, "Unknown CASE " .. name .. "\n" .. usage()
	else
		ok, err = pcall(render, name)
	end
	if not ok then
		io.write(tostring(err) .. "\n")
	end
	vim.cmd(ok and "qall!" or "cquit 1")
end

return M
