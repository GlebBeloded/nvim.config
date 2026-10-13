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

--- Save a session for this cwd under the zellij pane `zellij`/`pane` holding
--- only `file`; returns the session file path.
---@param zellij string
---@param pane string
---@param file string
---@return string
local function save_pane_session(zellij, pane, file)
	child.cmd("%bwipeout!")
	child.lua("vim.env.ZELLIJ_SESSION_NAME, vim.env.ZELLIJ_PANE_ID = ...", { zellij, pane })
	edit_file(file)
	local name = child.lua_get([[require("gleb.session.key").session_name()]])
	child.lua([[require("resession").save(..., { notify = false })]], { name })
	return vim.fs.joinpath(child.fn.stdpath("data"), "session", name .. ".json")
end

---@param path string
---@param mtime integer seconds since the epoch
local function set_mtime(path, mtime)
	assert(vim.uv.fs_utime(path, mtime, mtime))
end

--- Restart the full config bare in `dir` under zellij pane `zellij`/`pane`,
--- keeping the child's state (start_config would reset it).
---@param zellij string
---@param pane string
local function restart_in_pane(zellij, pane)
	vim.env.ZELLIJ_SESSION_NAME, vim.env.ZELLIJ_PANE_ID = zellij, pane
	MiniTest.finally(function()
		vim.env.ZELLIJ_SESSION_NAME, vim.env.ZELLIJ_PANE_ID = nil, nil
	end)
	child.restart(vim.list_extend({ "--cmd", "cd " .. dir }, H.config_args()))
	vim.iter(H.DISABLED_PLUGINS):each(child.disable_plugin)
end

local T = H.child_set(child, start)

T["session: no matching session leaves startup untouched"] = function()
	eq(child.bo.filetype, "alpha")
end

T["session: bare nvim restores the newest cwd session"] = function()
	-- `a-8-…` wins a filename sort, so only modification time picks `b-7-…`.
	local new = save_pane_session("b", "7", "new.txt")
	local old = save_pane_session("a", "8", "old.txt")
	child.stop() -- VimLeavePre saves again; stop first so the mtimes below stick
	local now = os.time()
	set_mtime(new, now)
	set_mtime(old, now - 60)

	restart_in_pane("c", "9")

	eq(child.fn.expand("%:t"), "new.txt")
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

return T
