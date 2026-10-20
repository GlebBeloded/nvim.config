-- Draw merge-base-to-HEAD changes beneath gitsigns, bounded to branch-changed text files.

local base = require("gleb.git.base")
local debounce = require("gleb.util.debounce")
local map = require("gleb.git.committed_signs.map")
local palette = require("gleb.colors.gruvbox-material.palette")
local sign_text = require("gleb.git.sign_text")

local M = {
	DEBOUNCE_MS = 150,
	MAX_BYTES = 2 * 1024 * 1024,
	MAX_LINES = 20000,
	SIGN_PRIORITY = 5,
}

local namespace = vim.api.nvim_create_namespace("gleb_git_committed_signs")

---@class gleb.git.committed_signs.File
---@field base_path? string
---@field path string

---@class gleb.git.committed_signs.ListState
---@field files? table<string, gleb.git.committed_signs.File>
---@field callbacks function[]

---@class gleb.git.committed_signs.BufferState
---@field attached boolean
---@field request integer
---@field key? string
---@field root? string
---@field head_lines? string[]
---@field kinds? GlebCommittedSignKinds
---@field running boolean
---@field timer? uv.uv_timer_t

---@class gleb.git.committed_signs.State
---@field lists table<string, gleb.git.committed_signs.ListState>
---@field buffers table<integer, gleb.git.committed_signs.BufferState>

---@type gleb.git.committed_signs.State
M.state = { lists = {}, buffers = {} }

---@param root string
---@param args string[]
---@param callback fun(result: vim.SystemCompleted)
local function git(root, args, callback)
	vim.system(vim.list_extend({ "git" }, args), { cwd = root }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

---@param output string
---@return table<string, gleb.git.committed_signs.File>
local function parse_changed_files(output)
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local files = {}
	local index = 1
	while index <= #fields do
		local status = fields[index]
		index = index + 1
		if status:find("^[RC]") then
			local old_path, path = fields[index], fields[index + 1]
			files[path] = { base_path = old_path, path = path }
			index = index + 2
		else
			local path = fields[index]
			if path and status ~= "D" then
				if status == "A" then
					files[path] = { path = path }
				else
					files[path] = { base_path = path, path = path }
				end
			end
			index = index + 1
		end
	end
	return files
end

---@param info gleb.git.base.Info
---@param callback fun(files?: table<string, gleb.git.committed_signs.File>)
local function changed_files(info, callback)
	local key = info.root .. "\0" .. info.merge_base .. "\0" .. info.head
	local state = M.state.lists[key]
	if state and state.files then
		callback(state.files)
		return
	end
	if state then
		table.insert(state.callbacks, callback)
		return
	end
	state = { callbacks = { callback } }
	M.state.lists[key] = state
	git(
		info.root,
		{ "diff", "--name-status", "-z", "-M", "--no-ext-diff", info.merge_base, info.head },
		function(result)
			local files = result.code == 0 and parse_changed_files(result.stdout or "") or nil
			state.files = files
			for _, done in ipairs(state.callbacks) do
				done(files)
			end
			state.callbacks = {}
		end
	)
end

---@param value string
---@return string[]?
local function blob_lines(value)
	if #value > M.MAX_BYTES or value:sub(1, 8000):find("\0", 1, true) then
		return nil
	end
	local lines = vim.split(value, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	if #lines > M.MAX_LINES then
		return nil
	end
	return lines
end

---@param root string
---@param oid string
---@param path string
---@param callback fun(lines?: string[])
local function read_blob(root, oid, path, callback)
	git(root, { "cat-file", "blob", oid .. ":" .. path }, function(result)
		callback(result.code == 0 and blob_lines(result.stdout or "") or nil)
	end)
end

---@param buf integer
---@param kinds GlebCommittedSignKinds
local function draw(buf, kinds)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for line, kind in pairs(kinds) do
		vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
			sign_text = (kind == "delete" or kind == "topdelete") and sign_text.delete or sign_text.bar,
			sign_hl_group = "GitCommittedSign",
			priority = M.SIGN_PRIORITY,
		})
	end
end

---@param state gleb.git.committed_signs.BufferState
local function stop_timer(state)
	if state.timer then
		state.timer:stop()
		if not state.timer:is_closing() then
			state.timer:close()
		end
		state.timer = nil
	end
end

---@param buf integer
---@param clear boolean
local function teardown(buf, clear)
	local state = M.state.buffers[buf]
	if not state then
		return
	end
	stop_timer(state)
	M.state.buffers[buf] = nil
	if clear and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
end

---@param buf integer
---@param state gleb.git.committed_signs.BufferState
local function remap(buf, state)
	if M.state.buffers[buf] ~= state or not state.head_lines or not state.kinds then
		return
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		teardown(buf, false)
		return
	end
	local buffer_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	draw(buf, map.to_buffer(state.head_lines, buffer_lines, state.kinds))
end

---@param buf integer
---@param state gleb.git.committed_signs.BufferState
local function schedule_remap(buf, state)
	state.timer = debounce.schedule(state.timer, M.DEBOUNCE_MS, function()
		remap(buf, state)
	end)
end

---@param buf integer
---@param state gleb.git.committed_signs.BufferState
local function attach(buf, state)
	if state.attached then
		return
	end
	state.attached = vim.api.nvim_buf_attach(buf, false, {
		on_lines = function()
			if M.state.buffers[buf] ~= state then
				return true
			end
			schedule_remap(buf, state)
		end,
		on_reload = function()
			if M.state.buffers[buf] == state then
				schedule_remap(buf, state)
			end
		end,
		on_detach = function()
			teardown(buf, false)
		end,
	})
end

---@param state gleb.git.committed_signs.BufferState
local function clear_state(state)
	state.key = nil
	state.head_lines = nil
	state.kinds = nil
	state.running = false
	if state.timer then
		state.timer:stop()
	end
end

---@param buf integer
---@param info gleb.git.base.Info
---@param file gleb.git.committed_signs.File
local function load_file(buf, info, file)
	local key = info.merge_base .. "\0" .. info.head .. "\0" .. (file.base_path or "") .. "\0" .. file.path
	local state = M.state.buffers[buf]
	if not state then
		return
	end
	state.root = info.root
	attach(buf, state)
	if state.key == key and state.running then
		return
	end
	if state.key == key and state.head_lines and state.kinds then
		remap(buf, state)
		return
	end
	state.key = key
	state.head_lines = nil
	state.kinds = nil
	state.running = true
	local base_lines = file.base_path and nil or {}
	local head_lines
	local base_done = not file.base_path
	local head_done = false
	local function finish()
		if not base_done or not head_done then
			return
		end
		if M.state.buffers[buf] ~= state or state.key ~= key or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		state.running = false
		if not base_lines or not head_lines then
			state.head_lines = nil
			state.kinds = nil
			draw(buf, {})
			return
		end
		state.head_lines = head_lines
		state.kinds = map.kinds(base_lines, head_lines)
		remap(buf, state)
	end
	if file.base_path then
		read_blob(info.root, info.merge_base, file.base_path, function(lines)
			base_lines = lines
			base_done = true
			finish()
		end)
	end
	read_blob(info.root, info.head, file.path, function(lines)
		head_lines = lines
		head_done = true
		finish()
	end)
end

---@param buf integer
local function refresh(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local state = M.state.buffers[buf]
	if not state then
		state = { attached = false, request = 0, running = false }
		M.state.buffers[buf] = state
	end
	state.request = state.request + 1
	local request = state.request
	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" or vim.fn.filereadable(path) ~= 1 then
		return
	end
	base.resolve(path, function(info, root)
		if M.state.buffers[buf] ~= state or state.request ~= request or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		state.root = root
		if not info then
			clear_state(state)
			draw(buf, {})
			return
		end
		local prefix = info.root .. "/"
		local normalized = vim.fs.normalize(path)
		local relative = normalized:sub(1, #prefix) == prefix and normalized:sub(#prefix + 1) or nil
		if not relative then
			draw(buf, {})
			return
		end
		changed_files(info, function(files)
			if M.state.buffers[buf] ~= state or state.request ~= request or not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local file = files and files[relative]
			if file then
				load_file(buf, info, file)
			else
				clear_state(state)
				draw(buf, {})
			end
		end)
	end)
end

local function apply_highlight()
	vim.api.nvim_set_hl(0, "GitCommittedSign", { fg = palette.foreground.purple })
end

--- Configure committed branch signs for normal file buffers.
---@return nil
function M.setup()
	apply_highlight()
	local group = vim.api.nvim_create_augroup("gleb_git_committed_signs", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_highlight })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
		group = group,
		callback = function(args)
			refresh(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "GlebGitBaseChanged",
		callback = function(args)
			local root = args.data and args.data.root
			for buf, state in pairs(M.state.buffers) do
				if state.root == root then
					refresh(buf)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			teardown(args.buf, false)
		end,
	})
end

return M
