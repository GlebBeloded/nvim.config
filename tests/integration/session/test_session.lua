local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Longer than auto-save's debounce_delay (1000 ms); cases that expect no
--- write have to sit it out.
local AUTOSAVE_WAIT_MS = 1500

---@type string
local dir

--- RPC can be served while init.lua still runs; restore happens on VimEnter.
local function wait_vim_enter()
	assert(child.wait("vim.v.vim_did_enter == 1", 5000), "VimEnter did not fire")
end

--- Full config started bare in a fresh temp cwd (child state is sandboxed).
local function start()
	dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.start_config()
	wait_vim_enter()
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

--- Restart the full config in `dir` under zellij pane `zellij`/`pane` with
--- `files` as arguments (bare by default), keeping the child's state
--- (start_config would reset it).
---@param zellij string
---@param pane string
---@param files? string[]
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

--- Save a session holding `a.txt` from a child in pane `pane_id`, then quit.
---@param pane_id string
---@return string path of a.txt
local function save_session_in_pane(pane_id)
	child.lua("vim.env.ZELLIJ_PANE_ID = ...", { pane_id })
	local path = edit_file("a.txt")
	quit_all()
	return path
end

--- Restart in either a named zellij session/pane (three arguments) or just a pane
--- (one or two arguments), preserving both existing test call shapes.
---@param zellij_or_pane string
---@param pane_or_args? string|string[]
---@param files? string[]
local function restart_in_pane(zellij_or_pane, pane_or_args, files)
	if type(pane_or_args) == "string" then
		vim.env.ZELLIJ_SESSION_NAME, vim.env.ZELLIJ_PANE_ID = zellij_or_pane, pane_or_args
		MiniTest.finally(function()
			vim.env.ZELLIJ_SESSION_NAME, vim.env.ZELLIJ_PANE_ID = nil, nil
		end)
		local args = vim.list_extend({ "--cmd", "cd " .. dir }, H.config_args())
		child.restart(vim.list_extend(args, files or {}))
		vim.iter(H.DISABLED_PLUGINS):each(child.disable_plugin)
		return
	end

	local cd = { "--cmd", "cd " .. vim.fn.fnameescape(dir) }
	child.restart_config(vim.list_extend(cd, pane_or_args or {}), { env = { ZELLIJ_PANE_ID = zellij_or_pane } })
	wait_vim_enter()
end

---@return string[] names of the listed buffers
local function listed_buffers()
	return child.lua_get([[vim.tbl_map(vim.api.nvim_buf_get_name, vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted
	end, vim.api.nvim_list_bufs()))]])
end

local T = H.child_set(child, start)

T["session: no matching session leaves startup untouched"] = function()
	eq(child.bo.filetype, "alpha")
end

T["session: bare nvim restores the pane session"] = function()
	save_pane_session("z", "5", "a.txt")
	child.stop()

	restart_in_pane("z", "5")

	eq({ child.fn.expand("%:t"), child.bo.filetype ~= "" }, { "a.txt", true })
end

T["session: bare nvim restores a cwd session after pane id change"] = function()
	save_pane_session("z", "9", "a.txt")
	child.stop()

	restart_in_pane("z", "5")

	eq(child.fn.expand("%:t"), "a.txt")
end

T["session: nvim with a file argument does not restore"] = function()
	save_pane_session("z", "5", "a.txt")
	child.stop()
	-- Absolute: file arguments resolve against the process cwd, not `--cmd cd`.
	local b = vim.fs.joinpath(dir, "b.txt")
	vim.fn.writefile({ "b" }, b)

	restart_in_pane("z", "5", { b })

	local listed = child.lua_get(
		[[vim.tbl_map(function(b) return vim.fn.fnamemodify(b.name, ":t") end, vim.fn.getbufinfo({ buflisted = 1 }))]]
	)
	eq(listed, { "b.txt" })
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

T["session: quitting saves the session"] = function()
	edit_file("a.txt")
	local name = child.lua_get([[require("gleb.session.key").session_name()]])
	local path = vim.fs.joinpath(child.fn.stdpath("data"), "session", name .. ".json")

	child.stop()

	eq(vim.fn.filereadable(path), 1)
	eq(table.concat(vim.fn.readfile(path), "\n"):find("a.txt", 1, true) ~= nil, true)
end

T["session: nvim with a file argument does not save the session"] = function()
	local path = save_pane_session("z", "5", "a.txt")
	child.stop()
	local before = vim.fn.readfile(path)
	-- Absolute: file arguments resolve against the process cwd, not `--cmd cd`.
	local b = vim.fs.joinpath(dir, "b.txt")
	vim.fn.writefile({ "b" }, b)

	restart_in_pane("z", "5", { b })
	child.cmd("write")
	child.stop()

	eq(vim.fn.readfile(path), before)
	eq(table.concat(before, "\n"):find("a.txt", 1, true) ~= nil, true)
end

T["session: quitting without file buffers keeps the previous session"] = function()
	local path = save_pane_session("z", "5", "a.txt")
	child.stop()
	local before = vim.fn.readfile(path)

	restart_in_pane("z", "5")
	child.cmd("%bwipeout!")
	child.stop()

	eq(vim.fn.readfile(path), before)
	eq(table.concat(before, "\n"):find("a.txt", 1, true) ~= nil, true)
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

T["session: unnamed buffer is not auto-written"] = function()
	child.cmd("enew")
	child.v.errmsg = ""
	child.type_keys("i", "hello", "<Esc>")
	vim.uv.sleep(AUTOSAVE_WAIT_MS)

	eq({ child.bo.modified, child.v.errmsg:find("E32") }, { true, nil })
end

T["session: bare nvim restores the pane session"] = function()
	local path = save_session_in_pane("5")
	restart_in_pane("5")

	eq({ child.api.nvim_buf_get_name(0), child.bo.filetype ~= "" }, { vim.fn.resolve(path), true })
end

T["session: bare nvim restores a cwd session after pane id change"] = function()
	local path = save_session_in_pane("9")
	restart_in_pane("5")

	eq(listed_buffers(), { vim.fn.resolve(path) })
end

T["session: nvim with a file argument does not restore"] = function()
	save_session_in_pane("5")
	local other = vim.fs.joinpath(dir, "b.txt")
	vim.fn.writefile({ "b" }, other)
	restart_in_pane("5", { other })

	eq(listed_buffers(), { vim.fn.resolve(other) })
end

T["session: quitting saves the session"] = function()
	local path = edit_file("a.txt")
	local session_file = child.lua_get(SESSION_FILE_LUA)
	quit_all()

	eq(session_buffers(session_file), { vim.fn.resolve(path) })
end

return T
