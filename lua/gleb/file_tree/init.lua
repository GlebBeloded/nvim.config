local status_ok, neo_tree = pcall(require, "neo-tree")
if not status_ok then
	return
end

-- Track state for auto-preview
local last_previewed_file = nil

-- Track which buffers have overlay enabled
local overlay_enabled_bufs = {}

-- Preview file with mini.diff overlay (shows deleted lines as virtual text)
local function preview_git_diff(path)
	if not path or last_previewed_file == path then
		return
	end
	last_previewed_file = path

	local neo_tree_win = vim.api.nvim_get_current_win()

	-- Find or create preview window
	local preview_win = nil
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ft = vim.api.nvim_get_option_value("filetype", { buf = vim.api.nvim_win_get_buf(win) })
		if ft ~= "neo-tree" and win ~= neo_tree_win then
			preview_win = win
			break
		end
	end

	if not preview_win then
		vim.cmd("belowright vsplit")
		preview_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(neo_tree_win)
	end

	-- Check if file exists (not deleted)
	local file_exists = vim.fn.filereadable(path) == 1

	if not file_exists then
		-- File was deleted - show git HEAD version in red
		local relative_path = vim.fn.fnamemodify(path, ":.")
		local content = vim.fn.system("git show HEAD:" .. vim.fn.shellescape(relative_path))

		-- Create scratch buffer for deleted file
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
		vim.api.nvim_win_set_buf(preview_win, buf)

		-- Detect filetype from extension and highlight in red
		local ext = vim.fn.fnamemodify(path, ":e")
		if ext and ext ~= "" then
			vim.api.nvim_set_option_value("filetype", ext, { buf = buf })
		end

		-- Highlight entire buffer in red (full line background)
		local ns = vim.api.nvim_create_namespace("deleted_file_hl")
		for i = 0, vim.api.nvim_buf_line_count(buf) - 1 do
			vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
				line_hl_group = "DiffDelete",
				priority = 1000,
			})
		end
		return
	end

	-- Check if buffer already exists
	local buf = vim.fn.bufnr(path, false)
	if buf ~= -1 then
		-- Buffer exists, just switch to it (fast)
		vim.api.nvim_win_set_buf(preview_win, buf)
	else
		-- Load new buffer, then detect filetype for syntax highlighting
		vim.api.nvim_win_call(preview_win, function()
			vim.cmd("noautocmd edit " .. vim.fn.fnameescape(path))
			vim.cmd("filetype detect")
		end)
		buf = vim.fn.bufnr(path, false)
	end

	-- Enable mini.diff overlay for inline diff view
	vim.defer_fn(function()
		if vim.api.nvim_buf_is_valid(buf) and not overlay_enabled_bufs[buf] then
			local md_ok, mini_diff = pcall(require, "mini.diff")
			if md_ok then
				-- Enable mini.diff on buffer first (needed since we use noautocmd)
				mini_diff.enable(buf)
				-- Small delay for diff to compute, then toggle overlay
				vim.defer_fn(function()
					if vim.api.nvim_buf_is_valid(buf) then
						pcall(mini_diff.toggle_overlay, buf)
						overlay_enabled_bufs[buf] = true
					end
				end, 100)
			end
		end
	end, 50)
end

-- Disable overlay on all tracked buffers
local function disable_all_overlays()
	local md_ok, mini_diff = pcall(require, "mini.diff")
	if md_ok then
		for buf, _ in pairs(overlay_enabled_bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				pcall(mini_diff.toggle_overlay, buf)
			end
		end
	end
	overlay_enabled_bufs = {}
end

-- Git status keymap: navigate down, skip directories, preview file
local function git_nav_down(state)
	local last_row = vim.api.nvim_buf_line_count(0)
	repeat
		vim.cmd("normal! j")
		local cursor = vim.api.nvim_win_get_cursor(0)
		if cursor[1] >= last_row then break end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path then
		preview_git_diff(node.path)
	end
end

-- Git status keymap: navigate up, skip directories, preview file
local function git_nav_up(state)
	repeat
		vim.cmd("normal! k")
		local cursor = vim.api.nvim_win_get_cursor(0)
		if cursor[1] <= 1 then break end
	until state.tree:get_node().type == "file"
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path then
		preview_git_diff(node.path)
	end
end

-- Git status keymap: open file in preview window, keep tree open
local function git_open_file(state)
	local node = state.tree:get_node()
	if node and node.type == "file" and node.path then
		disable_all_overlays()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
			if ft ~= "neo-tree" then
				vim.api.nvim_set_current_win(win)
				vim.cmd("edit " .. vim.fn.fnameescape(node.path))
				return
			end
		end
		vim.cmd("wincmd l")
		vim.cmd("edit " .. vim.fn.fnameescape(node.path))
	end
end

-- Git status keymap: close tree and disable overlays
local function git_close_tree()
	disable_all_overlays()
	vim.cmd("Neotree close")
end

-- Git status keymap: toggle stage/unstage file
local function git_toggle_stage(state)
	local node = state.tree:get_node()
	if node and node.path then
		local handle = io.popen("git diff --cached --name-only")
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

-- Git status keymap: commit with message prompt
local function git_commit()
	local msg = vim.fn.input("Commit message: ")
	if msg and msg ~= "" then
		vim.fn.system("git commit -m " .. vim.fn.shellescape(msg))
		require("neo-tree.sources.manager").refresh("git_status")
	end
end

-- Git status keymap: push to remote
local function git_push()
	vim.cmd("!git push")
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
				unstaged = " ",    -- empty (no indicator)
				staged = "»",      -- chevron (queued/ready to commit)
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
		-- Put git_status (checkbox) before filename
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
				["q"] = git_close_tree,
				["<space>"] = git_toggle_stage,
				["c"] = git_commit,
				["P"] = git_push,
				["A"] = "git_add_all",
				["gr"] = "git_revert_file",
			},
		},
	},
})

-- Custom git status colors for filenames (gruvbox-material palette)
vim.api.nvim_set_hl(0, "NeoTreeGitAdded", { fg = "#a9b665" })       -- green for new files
vim.api.nvim_set_hl(0, "NeoTreeGitModified", { fg = "#7daea3" })    -- blue for modified
vim.api.nvim_set_hl(0, "NeoTreeGitDeleted", { fg = "#ea6962" })     -- red for deleted
vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#928374" })   -- gray for untracked
vim.api.nvim_set_hl(0, "NeoTreeGitConflict", { fg = "#d8a657" })    -- yellow for conflicts
vim.api.nvim_set_hl(0, "NeoTreeGitStaged", { fg = "#a9b665" })      -- green for staged

-- Reset state when neo-tree window is closed
vim.api.nvim_create_autocmd("WinClosed", {
	callback = function()
		vim.schedule(function()
			local has_neotree = false
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
				if ft == "neo-tree" then
					has_neotree = true
					break
				end
			end
			if not has_neotree then
				last_previewed_file = nil
				overlay_enabled_bufs = {}
			end
		end)
	end,
})

