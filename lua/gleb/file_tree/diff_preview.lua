-- Diff preview module for neo-tree + vscode-diff integration
-- Manages tab state to provide seamless diff preview experience
-- Uses vscode-diff internal API for reliable diff rendering

local M = {}

-- State tracking
M.state = {
	original_tab = nil,
	diff_tab = nil, -- single diff tab (reused)
	current_file = nil,
	navigating_until = 0, -- timestamp when navigation mode expires
}

-- Debounce timer for rapid navigation
local debounce_timer = nil
local DEBOUNCE_MS = 50
local NAVIGATION_WINDOW_MS = 300 -- refocus neo-tree if diff gets focus within this window

-- Autocmd group for focus correction
local augroup = vim.api.nvim_create_augroup("DiffPreviewFocusGuard", { clear = true })

-- Check if we're in navigation mode (recently pressed j/k)
local function is_navigating()
	return vim.uv.now() < M.state.navigating_until
end

-- Internal: actually open the diff (called after debounce)
local function do_open_diff(path)
	local git = require("vscode-diff.git")
	local view = require("vscode-diff.render.view")

	-- Async chain: get_git_root -> resolve_revision -> create/update view
	git.get_git_root(path, function(err_root, git_root)
		if err_root then
			vim.schedule(function()
				vim.notify("Git root error: " .. err_root, vim.log.levels.ERROR)
			end)
			return
		end

		local relative_path = git.get_relative_path(path, git_root)

		git.resolve_revision("HEAD", git_root, function(err_resolve, commit_hash)
			if err_resolve then
				vim.schedule(function()
					vim.notify("Git resolve error: " .. err_resolve, vim.log.levels.ERROR)
				end)
				return
			end

			vim.schedule(function()
				-- Check if user navigated to different file while async was running
				if M.state.current_file ~= path then
					return
				end

				local filetype = vim.filetype.match({ filename = path }) or ""

				---@type SessionConfig
				local session_config = {
					mode = "standalone",
					git_root = git_root,
					original_path = relative_path,
					modified_path = relative_path,
					original_revision = commit_hash,
					modified_revision = "WORKING",
				}

				-- Save original tab (only first time, before any diff tab exists)
				if not M.state.original_tab then
					M.state.original_tab = vim.api.nvim_get_current_tabpage()
				end

				-- Close existing diff tab if any (switch to original first)
				if M.state.diff_tab and vim.api.nvim_tabpage_is_valid(M.state.diff_tab) then
					if M.state.original_tab and vim.api.nvim_tabpage_is_valid(M.state.original_tab) then
						vim.api.nvim_set_current_tabpage(M.state.original_tab)
					end
					local tabnr = vim.api.nvim_tabpage_get_number(M.state.diff_tab)
					pcall(vim.cmd, tabnr .. "tabclose!")
					M.state.diff_tab = nil
				end

				-- Create fresh diff tab
				view.create(session_config, filetype)
				M.state.diff_tab = vim.api.nvim_get_current_tabpage()

				-- Set up focus guard: if focus lands on diff during navigation, refocus neo-tree
				vim.api.nvim_clear_autocmds({ group = augroup })
				vim.api.nvim_create_autocmd("WinEnter", {
					group = augroup,
					callback = function()
						-- Only act if we're navigating and not already in neo-tree
						if not is_navigating() then
							return
						end
						local ft = vim.bo.filetype
						if ft ~= "neo-tree" and ft ~= "" then
							-- Focus escaped to diff window, pull it back
							vim.schedule(function()
								M.focus_neo_tree()
							end)
						end
					end,
				})

				-- Open neo-tree in the diff tab and focus it
				vim.cmd("Neotree git_status reveal_file=" .. vim.fn.fnameescape(path))
				M.focus_neo_tree()
			end)
		end)
	end)
end

-- Open diff for file using vscode-diff internal API (debounced)
function M.open_diff(path)
	if not path then
		return
	end

	-- Skip if same file already shown
	if M.state.current_file == path then
		return
	end

	-- Enter navigation mode (extends window on each keypress)
	M.state.navigating_until = vim.uv.now() + NAVIGATION_WINDOW_MS

	-- Update current file immediately (for debounce tracking)
	M.state.current_file = path

	-- Cancel pending debounce timer
	if debounce_timer then
		vim.fn.timer_stop(debounce_timer)
	end

	-- Debounce: wait for rapid navigation to settle
	debounce_timer = vim.fn.timer_start(DEBOUNCE_MS, function()
		debounce_timer = nil
		vim.schedule(function()
			do_open_diff(path)
		end)
	end)
end

-- Close the diff tab
function M.close_current_diff()
	if M.state.diff_tab and vim.api.nvim_tabpage_is_valid(M.state.diff_tab) then
		-- Return to original tab first
		if M.state.original_tab and vim.api.nvim_tabpage_is_valid(M.state.original_tab) then
			vim.api.nvim_set_current_tabpage(M.state.original_tab)
		end
		local tabnr = vim.api.nvim_tabpage_get_number(M.state.diff_tab)
		pcall(vim.cmd, tabnr .. "tabclose!")
		M.state.diff_tab = nil
	end
end

-- Focus neo-tree window in current tab
function M.focus_neo_tree()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
		if ft == "neo-tree" then
			vim.api.nvim_set_current_win(win)
			return true
		end
	end
	return false
end

-- Close diff and clear state
function M.close_all_diffs()
	M.close_current_diff()
	M.state.current_file = nil
end

-- Alias for semantic clarity (q keymap)
M.return_to_original = M.close_all_diffs

-- Reset all state (used in tests)
function M.reset()
	M.close_all_diffs()
	vim.api.nvim_clear_autocmds({ group = augroup })
	M.state = {
		original_tab = nil,
		diff_tab = nil,
		current_file = nil,
		navigating_until = 0,
	}
end

return M
