local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Longer than auto-save's debounce_delay (1000 ms); cases that expect no
--- write have to sit it out.
local AUTOSAVE_WAIT_MS = 1500

---@type string
local dir

--- Full config started bare in a fresh temp cwd (child state is sandboxed).
local function start()
	dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.start_config()
	child.cmd("cd " .. dir)
end

---@param name string
---@param lines? string[]
---@return string path
local function edit_file(name, lines)
	local path = vim.fs.joinpath(dir, name)
	vim.fn.writefile(lines or { "original" }, path)
	child.cmd("edit " .. path)
	return path
end

--- Child-side: path of the session file `key.session_name()` maps to.
local SESSION_FILE_LUA = [[require("resession.util").get_session_file(require("gleb.session.key").session_name())]]

--- `:qall` in the child, then wait until its process has exited (VimLeavePre ran).
local function quit_all()
	local job = child.job.id
	child.api_notify.nvim_command("qall")
	eq(vim.fn.jobwait({ job }, 5000)[1], 0)
end

---@param path string
---@return string[] names of the buffers stored in the session file
local function session_buffers(path)
	local session = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	return vim.tbl_map(function(buf)
		return buf.name
	end, session.buffers)
end

local T = H.child_set(child, start)

T["session: no matching session leaves startup untouched"] = function()
	eq(child.bo.filetype, "alpha")
end

T["session: writing a buffer saves the session"] = function()
	edit_file("a.txt")
	child.cmd("write")

	local saved =
		child.lua_get([[vim.list_contains(require("resession").list(), require("gleb.session.key").session_name())]])
	eq(saved, true)
end

T["session: modified file buffer is auto-written"] = function()
	local path = edit_file("a.txt", { "" })
	child.type_keys("i", "hello", "<Esc>")
	child.wait("not vim.bo.modified", AUTOSAVE_WAIT_MS * 2)

	eq({ vim.fn.readfile(path), child.bo.modified }, { { "hello" }, false })
end

T["session: gitcommit buffer is not auto-written"] = function()
	local path = edit_file("COMMIT_EDITMSG")
	child.bo.filetype = "gitcommit"
	child.type_keys("O", "hello", "<Esc>")
	vim.uv.sleep(AUTOSAVE_WAIT_MS)

	eq({ child.bo.modified, vim.fn.readfile(path) }, { true, { "original" } })
end

T["session: special buffer is not auto-written"] = function()
	local path = edit_file("scratch.txt")
	child.bo.buftype = "nofile"
	child.type_keys("O", "hello", "<Esc>")
	local modified = child.bo.modified
	vim.uv.sleep(AUTOSAVE_WAIT_MS)

	eq({ child.bo.modified, vim.fn.readfile(path) }, { modified, { "original" } })
end

T["session: quitting saves the session"] = function()
	local path = edit_file("a.txt")
	local session_file = child.lua_get(SESSION_FILE_LUA)
	quit_all()

	eq(session_buffers(session_file), { vim.fn.resolve(path) })
end

return T
