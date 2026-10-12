local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 5000
--- current_line_blame_opts.delay of the config (the spec's 300 ms).
local BLAME_DELAY_MS = 300

---@type string
local repo

local function start()
	child.start_config()
end

--- Fresh temp git repo with `files` committed, as the child's cwd.
---@param files table<string, string>
---@param opts? test.GitRepoOpts
---@return string repo path
local function use_repo(files, opts)
	repo = H.git_repo(files, opts)
	child.cmd("cd " .. repo)
	return repo
end

--- Edit `name` of the current repo in the child.
---@param name string
local function edit(name)
	child.cmd("edit " .. vim.fs.joinpath(repo, name))
end

--- Child-side: true once gitsigns has attached to the current buffer.
local GITSIGNS_ATTACHED = "vim.b.gitsigns_status_dict ~= nil"

--- Child-side: define `GitsignsSigns()`, the sign texts gitsigns placed in the
--- current buffer keyed by 1-based line (as strings, so the table survives RPC).
local GITSIGNS_SIGNS_LUA = [[
function GitsignsSigns()
	local signs = {}
	for name, ns in pairs(vim.api.nvim_get_namespaces()) do
		if name:find("^gitsigns_signs") then
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true, type = "sign" })) do
				signs[tostring(mark[2] + 1)] = vim.trim(mark[4].sign_text or "")
			end
		end
	end
	return signs
end]]

--- Child-side: end-of-line virtual texts in the current buffer, all namespaces.
local EOL_VIRT_TEXT_LUA = [[
local texts = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
	if mark[4].virt_text and mark[4].virt_text_pos == "eol" then
		table.insert(texts, mark[4].virt_text)
	end
end
return texts]]

local T = H.child_set(child, start)

T["git: Git commands are available after startup"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	local commands = { "Gitsigns", "Differ", "DiffviewOpen", "Gitlink" }
	local exists = vim.tbl_map(function(cmd)
		return child.fn.exists(":" .. cmd)
	end, commands)
	eq(exists, { 2, 2, 2, 2 })
end

T["git: vscode-diff setup runs on plugin load"] = function()
	child.lua([[require("lazy").load({ plugins = { "vscode-diff.nvim" } })]])

	eq(child.lua_get([[package.loaded["gleb.git.vscode_diff"] ~= nil]]), true)
	-- the plugin defaults are width 40 and a list view, so these come from the config's setup
	local explorer = child.lua_get([[require("codediff.config").options.explorer]])
	eq({ explorer.position, explorer.width, explorer.view_mode }, { "left", 35, "tree" })
end

T["git: Added line shows bar sign"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	edit("a.txt")
	eq(child.wait(GITSIGNS_ATTACHED, ASYNC_MS), true)
	child.lua(GITSIGNS_SIGNS_LUA)
	child.api.nvim_buf_set_lines(0, 1, 1, false, { "added" })

	eq(child.wait("GitsignsSigns()['2'] ~= nil", ASYNC_MS), true)
	eq(child.lua_get("GitsignsSigns()['2']"), "┃")
end

T["git: Blame is off by default"] = function()
	use_repo({ ["a.txt"] = "a\nb\n" })
	edit("a.txt")
	eq(child.wait(GITSIGNS_ATTACHED, ASYNC_MS), true)
	child.type_keys("j")
	vim.uv.sleep(BLAME_DELAY_MS + 200)

	eq(child.lua(EOL_VIRT_TEXT_LUA), {})
end

return T
