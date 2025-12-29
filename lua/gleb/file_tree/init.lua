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
	if node and node.type == "file" and node.path then
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
	if node and node.type == "file" and node.path then
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

-- Git status: toggle stage/unstage file
local function git_toggle_stage(state)
	local node = state.tree:get_node()
	if node and node.path then
		local handle = io.popen("git diff --cached --name-only")
		if not handle then
			return
		end
		local staged_files = handle:read("*a")
		handle:close()

		local relative_path = vim.fn.fnamemodify(node.path, ":.")
		local is_staged = staged_files:find(relative_path, 1, true) ~= nil

		if is_staged then
			vim.fn.system("git reset -- " .. vim.fn.shellescape(node.path))
		else
			vim.fn.system("git add " .. vim.fn.shellescape(node.path))
		end
		require("neo-tree.sources.manager").refresh("git_status")
	end
end

-- Git status: commit with floating input (Alt+C for AI)
local function git_commit()
	require("gleb.git.ai_commit").show_commit_input(function(msg)
		vim.fn.system("git commit -m " .. vim.fn.shellescape(msg))
		require("neo-tree.sources.manager").refresh("git_status")
		local subject = vim.split(msg, "\n")[1]
		vim.notify("Committed: " .. subject, vim.log.levels.INFO)
	end)
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
			expander_collapsed = "",
			expander_expanded = "",
		},
		icon = {
			folder_closed = "",
			folder_open = "",
			folder_empty = "",
		},
		name = {
			use_git_status_colors = true, -- Color filenames by git status
		},
		git_status = {
			symbols = {
				unstaged = " ", -- empty (no indicator)
				staged = "»", -- chevron (queued/ready to commit)
				unmerged = "",
				renamed = "➜",
				untracked = "?",
				deleted = "✗",
				ignored = "◌",
			},
		},
		diagnostics = {
			symbols = {
				hint = "",
				info = "",
				warn = "",
				error = "",
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
				["c"] = git_commit,
				["P"] = git_push,
				["A"] = "git_add_all",
				["gr"] = "git_revert_file",
				["q"] = git_close,
			},
		},
	},
})

-- Custom git status colors for filenames (gruvbox-material palette)
vim.api.nvim_set_hl(0, "NeoTreeGitAdded", { fg = "#a9b665" }) -- green for new files
vim.api.nvim_set_hl(0, "NeoTreeGitModified", { fg = "#7daea3" }) -- blue for modified
vim.api.nvim_set_hl(0, "NeoTreeGitDeleted", { fg = "#ea6962" }) -- red for deleted
vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#928374" }) -- gray for untracked
vim.api.nvim_set_hl(0, "NeoTreeGitConflict", { fg = "#d8a657" }) -- yellow for conflicts
vim.api.nvim_set_hl(0, "NeoTreeGitStaged", { fg = "#a9b665" }) -- green for staged
