-- `make render CASE=<name> [ATTR=1] [LINES=24] [COLUMNS=80]`
-- Prints the screen of a full-config child Neovim after running the setup
-- tests/render/<name>.lua (a module returning `fun(child: test.Child)`).
-- Without CASE, lists the available setups.

local H = require("tests.helpers")

local M = {}

local SETUP_DIR = vim.fs.joinpath(H.root, "tests/render")

---@return string[]
local function setups()
	local names = {}
	for name, kind in vim.fs.dir(SETUP_DIR) do
		if kind == "file" and name ~= "init.lua" and name:match("%.lua$") then
			table.insert(names, (name:gsub("%.lua$", "")))
		end
	end
	table.sort(names)
	return names
end

---@param text string
local function out(text)
	io.write(text .. "\n")
end

---@param name string
local function render(name)
	local setup = dofile(vim.fs.joinpath(SETUP_DIR, name .. ".lua")) --[[@as fun(child: test.Child)]]
	local child = H.new_child()
	child.start_config()
	child.o.lines = tonumber(vim.env.LINES) or 24
	child.o.columns = tonumber(vim.env.COLUMNS) or 80
	child.wait_very_lazy()
	setup(child)
	vim.uv.sleep(300) -- let timers (lualine, bufferline) redraw
	local screenshot = child.get_screenshot()
	child.stop()

	local text = tostring(screenshot)
	out(vim.env.ATTR == "1" and text or vim.split(text, "\n\n", { plain = true })[1])
end

function M.run()
	local name = vim.env.CASE
	local ok, err = true, nil
	if not name or name == "" then
		out(
			"Usage: make render CASE=<name> [ATTR=1] [LINES=..] [COLUMNS=..]\nAvailable: "
				.. table.concat(setups(), ", ")
		)
	elseif not vim.list_contains(setups(), name) then
		ok, err = false, "Unknown CASE " .. name .. ". Available: " .. table.concat(setups(), ", ")
	else
		ok, err = pcall(render, name)
	end
	if not ok then
		io.write(tostring(err) .. "\n")
	end
	vim.cmd(ok and "qall!" or "cquit 1")
end

return M
