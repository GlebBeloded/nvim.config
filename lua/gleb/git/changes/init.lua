-- Changes coordinates repository discovery and one panel per tab.

local M = {}

local workspace = require("gleb.workspace")
local git = require("gleb.git.changes.git")
local tabs = require("gleb.git.changes.tabs")
local view = require("gleb.git.changes.view")
local sidebar = require("gleb.tree.sidebar")

---@class ChangesState
---@field by_tab table<integer, ChangesView>
---@field by_root table<string, ChangesRootState>

---@class ChangesRootState
---@field tab string
---@field commit_view boolean
---@field folds table<string, boolean>

---@type ChangesState
M.state = { by_tab = {}, by_root = {} }

---@return string path
---@return string dir
local function current_location()
	local path = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or path == "" or path:match("^[%a][%w+.-]*://") then
		return "", workspace.normalize(vim.fn.getcwd())
	end
	path = workspace.normalize(path)
	return path, vim.fs.dirname(path)
end

---@param dir string
---@param selected_path string
---@param review? boolean
---@param on_ready? fun(panel: ChangesView)
---@return nil
local function resolve_and_open(dir, selected_path, review, on_ready)
	local tab = vim.api.nvim_get_current_tabpage()
	git.resolve_root(dir, function(result, root)
		if vim.api.nvim_get_current_tabpage() ~= tab then
			return
		end
		if not root then
			vim.notify("Git root error: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		view.open(root, selected_path, review, on_ready)
	end)
end

---@param review? boolean
---@param on_ready? fun(panel: ChangesView)
---@return nil
local function replace_tree_and_open(review, on_ready)
	sidebar.close("file_tree")
	local selected_path, dir = current_location()
	resolve_and_open(dir, selected_path, review, on_ready)
end

---@param panel ChangesView
---@param saved ChangesRootState?
---@return nil
local function restore(panel, saved)
	if not saved then
		return
	end
	if saved.tab == "branch" and panel.branch_available then
		panel.tree.folds = vim.deepcopy(saved.folds)
		view.activate_tab(panel, "branch")
		if saved.commit_view then
			panel.tree.folds = vim.deepcopy(saved.folds)
			view.toggle_commits(panel)
		end
		return
	end
	panel.tree.folds = vim.deepcopy(saved.folds)
	view.activate_tab(panel, "local")
end

---@param panel ChangesView
---@return gleb.git.changes.TabCycleState
local function cycle_state(panel)
	return {
		active = panel.active_tab,
		available = view.available_tabs(panel),
		local_count = panel.local_count,
	}
end

---@param panel ChangesView
---@param id string
---@return nil
local function apply_review_tab(panel, id)
	if id == "close" then
		view.close(panel)
	else
		view.activate_tab(panel, id)
	end
end

---@param root string
---@return nil
local function notify_no_branch(root)
	local entry = require("gleb.git.base").state.roots[root]
	local branch = entry and entry.branch or "current branch"
	vim.notify("No branch changes on " .. branch, vim.log.levels.WARN)
end

---@param panel ChangesView
---@param commit_view boolean
---@return nil
local function activate_branch(panel, commit_view)
	if not panel.branch_available then
		notify_no_branch(panel.root)
		return
	end
	view.activate_tab(panel, "branch")
	if commit_view and not panel.commit_view then
		view.toggle_commits(panel)
	end
end

---@param commit_view boolean
---@return nil
local function show_branch(commit_view)
	local tab = vim.api.nvim_get_current_tabpage()
	local current = M.state.by_tab[tab]
	if current and vim.api.nvim_win_is_valid(current.win) then
		activate_branch(current, commit_view)
		return
	end
	local selected_path, dir = current_location()
	git.resolve_root(dir, function(result, root)
		if vim.api.nvim_get_current_tabpage() ~= tab then
			return
		end
		if not root then
			vim.notify("Git root error: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		require("gleb.git.base").resolve(root, function(info)
			if vim.api.nvim_get_current_tabpage() ~= tab then
				return
			end
			if not info then
				notify_no_branch(root)
				return
			end
			sidebar.close("file_tree")
			view.open(root, selected_path, false, function(panel)
				local saved = M.state.by_root[panel.root]
				restore(panel, saved)
				if panel.active_tab ~= "branch" then
					activate_branch(panel, commit_view)
				elseif commit_view and not panel.commit_view then
					view.toggle_commits(panel)
				end
			end)
		end)
	end)
end

--- Toggle the current tab's Changes panel.
---@return nil
function M.toggle()
	local tab = vim.api.nvim_get_current_tabpage()
	local current = M.state.by_tab[tab]
	if current and vim.api.nvim_win_is_valid(current.win) then
		if vim.api.nvim_get_current_win() == current.win then
			view.close(current)
		else
			vim.api.nvim_set_current_win(current.win)
		end
		return
	end
	replace_tree_and_open(false, function(panel)
		restore(panel, M.state.by_root[panel.root])
	end)
end

--- Open or focus the Changes panel for review.
---@return nil
function M.review()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current and vim.api.nvim_win_is_valid(current.win) then
		apply_review_tab(current, tabs.next(cycle_state(current)))
		return
	end
	replace_tree_and_open(false, function(panel)
		apply_review_tab(panel, tabs.first(cycle_state(panel)))
		require("gleb.pr").refresh(panel.root)
	end)
end

--- Open or focus the Local changes tab.
---@return nil
function M.show_local()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current and vim.api.nvim_win_is_valid(current.win) then
		view.activate_tab(current, "local")
		return
	end
	replace_tree_and_open(false, function(panel)
		local saved = M.state.by_root[panel.root]
		if saved then
			panel.tree.folds = vim.deepcopy(saved.folds)
		end
		view.activate_tab(panel, "local")
	end)
end

--- Open or focus the Branch changes tab.
---@return nil
function M.show_branch()
	show_branch(false)
end

--- Open or focus the Branch commit view.
---@return nil
function M.show_branch_commits()
	show_branch(true)
end

--- Open the Changes panel for a directory.
---@param opts { root: string }
---@return nil
function M.open(opts)
	resolve_and_open(opts.root, "")
end

--- Toggle the fold under the cursor in the current Changes panel.
---@return nil
function M.toggle_fold()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current then
		view.toggle_fold(current)
	end
end

--- Toggle the current Branch tab between files and commits.
---@return nil
function M.toggle_commits()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current then
		view.toggle_commits(current)
	end
end

--- Open a file row, or fold a structural row.
---@return nil
function M.open_selected()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current then
		return
	end
	local row = current.rows[vim.api.nvim_win_get_cursor(current.win)[1]]
	if row and row.kind == "file" and (current.active_tab == "branch" or not row.fold_id) then
		view.open_file(current, row)
	elseif row and row.fold_id then
		view.toggle_fold(current)
	end
end

--- Close the current tab's Changes panel.
---@return nil
function M.close()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if current then
		view.close(current)
	end
end

---@param current ChangesView
---@param row ChangesRow
---@return string[]
local function selected_paths(current, row)
	local paths = {}
	for _, candidate in ipairs(current.all_rows) do
		local selected = row.kind == "root" and candidate.root == row.root
			or row.kind == "directory" and candidate.root == row.root and candidate.path and (candidate.path == row.path or vim.startswith(
				candidate.path,
				row.path .. "/"
			))
			or row.kind == "file" and candidate == row
		if selected and candidate.kind == "file" and candidate.path then
			paths[#paths + 1] = vim.fs.joinpath(current.root, candidate.path)
		end
	end
	return paths
end

--- Toggle staging for the file row under the cursor.
---@return nil
function M.toggle_stage()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current or current.active_tab ~= "local" then
		return
	end
	local row = current.rows[vim.api.nvim_win_get_cursor(current.win)[1]]
	if not row then
		return
	end
	local paths = selected_paths(current, row)
	if #paths == 0 then
		return
	end
	git.toggle_stage(current.root, paths, function(result)
		if result.code ~= 0 then
			vim.notify("Stage failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		if M.state.by_tab[current.tab] ~= current then
			return
		end
		view.schedule_refresh(current)
		if current.diff_view then
			require("gleb.diff.view").refresh_index(current.diff_view)
		end
	end)
end

--- Stage every change in the current Changes panel.
---@return nil
function M.stage_all()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current or current.active_tab ~= "local" then
		return
	end
	git.stage_all(current.root, function(result)
		if result.code ~= 0 then
			vim.notify("Stage failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		if M.state.by_tab[current.tab] ~= current then
			return
		end
		view.schedule_refresh(current)
		if current.diff_view then
			require("gleb.diff.view").refresh_index(current.diff_view)
		end
	end)
end

---@param current ChangesView
---@param result vim.SystemCompleted
---@return nil
local function finish_revert(current, result)
	if result.code ~= 0 then
		vim.notify("Revert failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
		return
	end
	if M.state.by_tab[current.tab] ~= current then
		return
	end
	view.schedule_refresh(current)
	if current.diff_view then
		require("gleb.diff.view").refresh_index(current.diff_view)
	end
end

--- Revert the file row under the cursor after confirmation.
---@return nil
function M.revert()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current or current.active_tab ~= "local" then
		return
	end
	local row = current.rows[vim.api.nvim_win_get_cursor(current.win)[1]]
	if not row or row.kind ~= "file" or row.status == "untracked" then
		return
	end
	local prompt = ("Are you sure you want to revert %s? y/n: "):format(row.label)
	vim.ui.input({ prompt = prompt }, function(answer)
		if answer == "y" or answer == "Y" then
			git.revert(current.root, row, function(result)
				finish_revert(current, result)
			end)
		end
	end)
end

---@param current ChangesView
---@param message string
---@param result vim.SystemCompleted
---@return nil
local function finish_commit(current, message, result)
	if result.code ~= 0 then
		local stderr, stdout = vim.trim(result.stderr or ""), vim.trim(result.stdout or "")
		local reason = stderr ~= "" and stderr or stdout ~= "" and stdout or ("exit " .. result.code)
		vim.notify("Commit failed: " .. reason, vim.log.levels.ERROR)
		return
	end
	vim.notify("Committed: " .. vim.split(message, "\n")[1], vim.log.levels.INFO)
	if M.state.by_tab[current.tab] ~= current then
		return
	end
	view.schedule_refresh(current)
	if current.diff_view then
		require("gleb.diff.view").refresh_index(current.diff_view)
	end
end

--- Commit staged changes from the current Changes panel.
---@return nil
function M.commit()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current then
		return
	end
	require("gleb.git.ai_commit").show_commit_input(function(message)
		git.commit(current.root, message, function(result)
			finish_commit(current, message, result)
		end)
	end, { root = current.root })
end

--- Push the current branch from the current Changes panel repository.
---@return nil
function M.push()
	local current = M.state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not current then
		return
	end
	vim.notify("Pushing...", vim.log.levels.INFO)
	git.push(current.root, function(result)
		vim.notify(
			result.code == 0 and "Pushed successfully" or "Push failed",
			result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
		)
	end)
end

--- Clear Changes panel state for tests.
---@return nil
function M.reset()
	for _, current in pairs(M.state.by_tab) do
		view.close(current)
	end
	M.state = { by_tab = {}, by_root = {} }
end

require("gleb.git.changes.highlights").setup()

sidebar.register("changes", M.close)

return M
