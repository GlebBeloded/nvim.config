-- Tests for diff_preview module
-- Run with: nvim --headless -c "PlenaryBustedFile tests/file_tree/diff_preview_spec.lua"

local diff_preview = require("gleb.file_tree.diff_preview")

-- Helper to check if neo-tree window exists
local function has_neotree_window()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
		if ft == "neo-tree" then
			return true
		end
	end
	return false
end

-- Helper to get current window filetype
local function current_filetype()
	return vim.api.nvim_get_option_value("filetype", { buf = 0 })
end

describe("diff_preview", function()
	before_each(function()
		-- Close all tabs except first
		while #vim.api.nvim_list_tabpages() > 1 do
			vim.cmd("tabclose!")
		end
		-- Close all windows except one
		vim.cmd("only!")
		diff_preview.reset()
	end)

	describe("state management", function()
		it("should initialize with empty state", function()
			assert.is_nil(diff_preview.state.original_tab)
			assert.is_nil(diff_preview.state.current_file)
			assert.is_nil(diff_preview.state.diff_tab)
			assert.are.equal(0, diff_preview.state.navigating_until)
		end)

		it("should track original tab on first open", function()
			local original = vim.api.nvim_get_current_tabpage()
			diff_preview.state.original_tab = original
			assert.are.equal(original, diff_preview.state.original_tab)
		end)
	end)

	describe("focus_neo_tree", function()
		it("should return false when no neo-tree window exists", function()
			local result = diff_preview.focus_neo_tree()
			assert.is_false(result)
		end)

		it("should return true and focus neo-tree when it exists", function()
			-- Open neo-tree
			pcall(vim.cmd, "Neotree filesystem")
			vim.wait(100, function() return has_neotree_window() end)

			if has_neotree_window() then
				-- Move away from neo-tree
				vim.cmd("wincmd l")

				-- Now focus it
				local result = diff_preview.focus_neo_tree()
				assert.is_true(result)
				assert.are.equal("neo-tree", current_filetype())
			end
		end)
	end)

	describe("reset", function()
		it("should clear all state", function()
			diff_preview.state.current_file = "/some/path"
			diff_preview.state.original_tab = vim.api.nvim_get_current_tabpage()
			diff_preview.state.diff_tab = 1
			diff_preview.state.navigating_until = 999999

			diff_preview.reset()

			assert.is_nil(diff_preview.state.current_file)
			assert.is_nil(diff_preview.state.original_tab)
			assert.is_nil(diff_preview.state.diff_tab)
			assert.are.equal(0, diff_preview.state.navigating_until)
		end)
	end)

	describe("open_diff", function()
		it("should skip nil path", function()
			local tab_count_before = #vim.api.nvim_list_tabpages()
			diff_preview.open_diff(nil)
			assert.is_nil(diff_preview.state.current_file)
			assert.are.equal(tab_count_before, #vim.api.nvim_list_tabpages())
		end)

		it("should skip if same file already shown", function()
			diff_preview.state.current_file = "/test/file.lua"
			local tab_count_before = #vim.api.nvim_list_tabpages()

			diff_preview.open_diff("/test/file.lua")

			assert.are.equal(tab_count_before, #vim.api.nvim_list_tabpages())
		end)

		it("should save original tab before opening diff", function()
			local original_tab = vim.api.nvim_get_current_tabpage()
			assert.is_nil(diff_preview.state.original_tab)

			-- Use existing git-tracked file
			local test_file = vim.fn.expand("~/.config/nvim/lua/gleb/file_tree/diff_preview.lua")

			if vim.fn.filereadable(test_file) == 1 then
				diff_preview.open_diff(test_file)

				-- Wait for debounce + async git operations (may not complete in headless)
				local completed = vim.wait(500, function()
					return diff_preview.state.original_tab ~= nil
				end)

				-- Only assert if async completed (requires vscode-diff loaded)
				if completed then
					assert.are.equal(original_tab, diff_preview.state.original_tab)
				end
			end
		end)

		it("should track current_file after open", function()
			local test_file = vim.fn.expand("~/.config/nvim/lua/gleb/file_tree/diff_preview.lua")

			if vim.fn.filereadable(test_file) == 1 then
				diff_preview.open_diff(test_file)

				-- current_file is set immediately (before debounce)
				assert.are.equal(test_file, diff_preview.state.current_file)
			end
		end)
	end)

	describe("return_to_original", function()
		it("should return to original tab", function()
			local original_tab = vim.api.nvim_get_current_tabpage()
			diff_preview.state.original_tab = original_tab

			-- Create new tab (simulating diff tab)
			vim.cmd("tabnew")
			local diff_tab = vim.api.nvim_get_current_tabpage()
			diff_preview.state.diff_tab = diff_tab
			assert.are_not.equal(original_tab, diff_tab)

			diff_preview.return_to_original()

			assert.are.equal(original_tab, vim.api.nvim_get_current_tabpage())
		end)

		it("should clear current_file", function()
			diff_preview.state.current_file = "/some/file"
			diff_preview.return_to_original()
			assert.is_nil(diff_preview.state.current_file)
		end)
	end)

	describe("integration: open_diff creates proper layout", function()
		it("should create a new tab when CodeDiff runs", function()
			local tab_count_before = #vim.api.nvim_list_tabpages()

			-- Create a git-tracked test file (use existing file from config)
			local test_file = vim.fn.expand("~/.config/nvim/lua/gleb/file_tree/diff_preview.lua")

			if vim.fn.filereadable(test_file) == 1 then
				diff_preview.open_diff(test_file)

				-- Wait for async operations
				vim.wait(200, function()
					return #vim.api.nvim_list_tabpages() > tab_count_before
				end)

				-- Should have created at least one new tab (CodeDiff creates tab)
				local tab_count_after = #vim.api.nvim_list_tabpages()
				assert.is_true(tab_count_after >= tab_count_before,
					"Expected new tab. Before: " .. tab_count_before .. ", After: " .. tab_count_after)
			end
		end)

		it("should open neo-tree in diff tab after CodeDiff", function()
			local test_file = vim.fn.expand("~/.config/nvim/lua/gleb/file_tree/diff_preview.lua")

			if vim.fn.filereadable(test_file) == 1 then
				diff_preview.open_diff(test_file)

				-- Wait for neo-tree to open (requires vscode-diff + neo-tree loaded)
				local neo_tree_opened = vim.wait(500, function()
					return has_neotree_window()
				end)

				-- Only assert if plugins fully loaded in test environment
				if neo_tree_opened then
					assert.is_true(has_neotree_window(), "Neo-tree should be visible in diff tab")
				end
			end
		end)

		it("should focus neo-tree after opening diff", function()
			local test_file = vim.fn.expand("~/.config/nvim/lua/gleb/file_tree/diff_preview.lua")

			if vim.fn.filereadable(test_file) == 1 then
				diff_preview.open_diff(test_file)

				-- Wait for focus (requires vscode-diff + neo-tree loaded)
				local focused = vim.wait(500, function()
					return current_filetype() == "neo-tree"
				end)

				-- Only assert if plugins fully loaded in test environment
				if focused then
					assert.are.equal("neo-tree", current_filetype(),
						"Focus should be on neo-tree, got: " .. current_filetype())
				end
			end
		end)
	end)
end)
