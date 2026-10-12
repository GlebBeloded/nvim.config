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

--- Start the config again in `dir` on the kept data/state, in pane `pane_id`.
---@param pane_id string
---@param args? string[] extra Neovim args (file arguments)
local function restart_in_pane(pane_id, args)
	local cd = { "--cmd", "cd " .. vim.fn.fnameescape(dir) }
	child.restart_config(vim.list_extend(cd, args or {}), { env = { ZELLIJ_PANE_ID = pane_id } })
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
