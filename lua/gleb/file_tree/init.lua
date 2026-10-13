local status_ok, neo_tree = pcall(require, "neo-tree")
if not status_ok then
	return
end

local diff_preview = require("gleb.file_tree.diff_preview")

-- Navigate down, skip directories, preview file
local function git_nav_down(state)
	local last_row = vim.api.nvim_buf_line_count(0)
	repeat
		vim.cmd("normal! j")
		local cursor = vim.api.nvim_win_get_cursor(0)
		if cursor[1] >= last_row then
			break
		end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path and vim.fn.filereadable(node.path) == 1 then
		diff_preview.open_diff(node.path)
	end
end

-- Navigate up, skip directories, preview file
local function git_nav_up(state)
	repeat
		vim.cmd("normal! k")
		local cursor = vim.api.nvim_win_get_cursor(0)
		if cursor[1] <= 1 then
			break
		end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path and vim.fn.filereadable(node.path) == 1 then
		diff_preview.open_diff(node.path)
	end
end

-- Open file and switch to filesystem tree
local function git_open_file(state)
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path then
		diff_preview.close_all_diffs()
		vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(node.path) .. " filesystem")
		vim.cmd("wincmd l")
		vim.cmd("edit " .. vim.fn.fnameescape(node.path))
	end
end

-- Close diff and return to original tab
local function git_close()
	diff_preview.return_to_original()
	vim.cmd("Neotree close")
end

--- Whether `path` (file or directory) has staged changes, asked from git for that exact pathspec.
---@param path string
---@param cwd string
---@return boolean? staged nil when git failed
---@return string? stderr
local function is_staged(path, cwd)
	local result = vim.system({ "git", "diff", "--cached", "--quiet", "--", path }, { cwd = cwd, text = true }):wait()
	if result.code == 1 then
		return true
	elseif result.code == 0 then
		return false
	end
	return nil, result.stderr
end

--- Run git with an argument list; notify `failure_prefix .. stderr` at ERROR on a non-zero exit.
---@param args string[]
---@param cwd string
---@param failure_prefix string
local function run_git(args, cwd, failure_prefix)
	local result = vim.system(args, { cwd = cwd, text = true }):wait()
	if result.code ~= 0 then
		vim.notify(failure_prefix .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
	end
end

-- Git status: toggle stage/unstage file
local function git_toggle_stage(state)
	local node = state.tree:get_node()
	if not (node and node.path) then
		return
	end
	local cwd, path = state.path, node.path
	local staged, stderr = is_staged(path, cwd)
	if staged == nil then
		vim.notify("Stage failed: " .. vim.trim(stderr or ""), vim.log.levels.ERROR)
	elseif staged then
		run_git({ "git", "reset", "-q", "--", path }, cwd, "Unstage failed: ")
	else
		run_git({ "git", "add", "--", path }, cwd, "Stage failed: ")
	end
	require("neo-tree.sources.manager").refresh("git_status")
end

--- Report a finished `git commit`; refresh the tree only on success.
---@param msg string
---@param result vim.SystemCompleted
local function on_commit_exit(msg, result)
	vim.schedule(function()
		if result.code == 0 then
			require("neo-tree.sources.manager").refresh("git_status")
			vim.notify("Committed: " .. vim.split(msg, "\n")[1], vim.log.levels.INFO)
			return
		end
		local stderr, stdout = vim.trim(result.stderr or ""), vim.trim(result.stdout or "")
		local reason = stderr ~= "" and stderr or stdout ~= "" and stdout or ("exit " .. result.code)
		vim.notify("Commit failed: " .. reason, vim.log.levels.ERROR)
	end)
end

---@param msg string
local function run_commit(msg)
	vim.system({ "git", "commit", "-m", msg }, { text = true }, function(result)
		on_commit_exit(msg, result)
	end)
end

-- Git status: commit with floating input
local function git_commit()
	require("gleb.git.ai_commit").show_commit_input(run_commit)
end

-- Git status: push to remote
local function git_push()
	vim.notify("Pushing...", vim.log.levels.INFO)
	vim.fn.jobstart("git push", {
		on_exit = function(_, code)
			if code == 0 then
				vim.notify("Pushed successfully", vim.log.levels.INFO)
			else
				vim.notify("Push failed", vim.log.levels.ERROR)
			end
		end,
	})
end

neo_tree.setup({
	sources = { "filesystem", "git_status" },
	-- neo-tree's health check validates buffers even when it is not in sources
	buffers = { renderers = {} },
	source_selector = {
		winbar = false,
		statusline = false,
	},
	close_if_last_window = true,
	popup_border_style = "rounded",

	default_component_configs = {
		indent = {
			indent_size = 2,
			padding = 1,
			with_markers = true,
			indent_marker = "│",
			last_indent_marker = "└",
			with_expanders = true,
			expander_collapsed = "\u{F460}",
			expander_expanded = "\u{F47C}",
		},
		icon = {
			folder_closed = "\u{E5FF}",
			folder_open = "\u{E5FE}",
			folder_empty = "\u{F0256}",
		},
		name = {
			use_git_status_colors = true, -- Color filenames by git status
		},
		git_status = {
			symbols = {
				unstaged = " ", -- empty (no indicator)
				staged = "»", -- chevron (queued/ready to commit)
				conflict = "\u{E727}",
				renamed = "➜",
				untracked = "?",
				deleted = "✗",
				ignored = "◌",
			},
		},
	},

	window = {
		position = "left",
		width = 35,
		mappings = {
			["<cr>"] = "open",
			["o"] = "open",
			["l"] = "open",
			["h"] = "close_node",
			["<bs>"] = "close_node",
			["v"] = "open_vsplit",
			["s"] = "open_split",
			["t"] = "open_tabnew",
			["a"] = { "add", config = { show_path = "relative" } },
			["d"] = "delete",
			["r"] = "rename",
			["c"] = "copy",
			["x"] = "cut_to_clipboard",
			["p"] = "paste_from_clipboard",
			["R"] = "refresh",
			["q"] = "close_window",
			["?"] = "show_help",
			["<"] = "prev_source",
			[">"] = "next_source",
		},
	},

	filesystem = {
		follow_current_file = { enabled = true },
		use_libuv_file_watcher = true,
		hijack_netrw_behavior = "open_current",
		filtered_items = {
			visible = true,
			hide_dotfiles = false,
			hide_gitignored = false,
		},
		window = {
			mappings = {
				["H"] = "toggle_hidden",
			},
		},
	},

	git_status = {
		renderers = {
			file = {
				{ "indent" },
				{ "git_status", highlight = "NeoTreeGitStatusSymbol" },
				{ "icon" },
				{ "name", use_git_status_colors = true },
			},
			directory = {
				{ "indent" },
				{ "git_status", highlight = "NeoTreeGitStatusSymbol" },
				{ "icon" },
				{ "name" },
			},
		},
		window = {
			position = "left",
			width = 35,
			mappings = {
				["j"] = git_nav_down,
				["k"] = git_nav_up,
				["<cr>"] = git_open_file,
				["<space>"] = git_toggle_stage,
				["gc"] = { git_commit, desc = "commit (AI)" },
				["P"] = git_push,
				["A"] = "git_add_all",
				["X"] = "git_revert_file",
				["gr"] = "none",
				["q"] = git_close,
			},
		},
	},
})
