local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local manifest

local function start()
	root, manifest = F.copy("diffgo", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param path string
local function edit(path)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
end

local function open_diff()
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
end

local function open_controller()
	edit(manifest.controller)
	open_diff()
end

T["diff: Diff view q closes the tab page"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.type_keys("q")

	eq(#child.api.nvim_list_tabpages(), 1)
	eq(child.api.nvim_get_current_buf(), view.right_buf)
	eq(next(child.fn.maparg("q", "n", false, true)), nil)
	eq(child.api.nvim_buf_get_extmarks(view.right_buf, view.ns, 0, -1, {}), {})
end

local closes_scenario = "diff: Diff view closes with either window"
T[closes_scenario] = MiniTest.new_set()

T[closes_scenario]["closes the peer after the left window quits"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.left_win)
	child.cmd("quit")

	eq(#child.api.nvim_list_tabpages(), 1)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):any(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
		end)]]),
		false
	)
end

T[closes_scenario]["closes the peer after the right window quits"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.right_win)
	child.cmd("quit")

	eq(#child.api.nvim_list_tabpages(), 1)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):any(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
		end)]]),
		false
	)
end

T["diff: Diff view restores a shadowed buffer mapping"] = function()
	edit(manifest.controller)
	child.lua([[vim.keymap.set("n", "q", function() vim.g.shadowed_q = true end, {
		buffer = true, desc = "Original q",
	})]])
	open_diff()
	child.type_keys("q")

	eq(child.lua_get([[vim.fn.maparg("q", "n", false, true).desc]]), "Original q")
	child.type_keys("q")
	eq(child.g.shadowed_q, true)
end

T["diff: Diff view shows in a given window without focus"] = function()
	child.cmd("edit a.txt | rightbelow vnew")
	local target = child.api.nvim_get_current_win()
	child.cmd("wincmd p")
	local current = child.api.nvim_get_current_win()
	local tabs = #child.api.nvim_list_tabpages()

	local view = child.lua_get(
		[[(function(win)
		return require("gleb.diff.view").show(win, {
			path = "b.txt",
			left = { "a", "b" },
			right = { "a", "c" },
			labels = { left = "HEAD", right = "Working tree" },
		})
	end)(...)]],
		{ target }
	)

	eq(#child.api.nvim_list_tabpages(), tabs)
	eq(child.api.nvim_get_current_win(), current)
	eq(child.api.nvim_buf_get_lines(view.left_buf, 0, -1, false), { "a", "b" })
	eq(child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false), { "a", "c" })
	eq(child.lua_get("vim.wo[...].winbar", { view.left_win }), "HEAD")
end

T["diff: Diff view ]f calls the next-file hook"] = function()
	child.cmd("vnew")
	local target = child.api.nvim_get_current_win()
	child.lua(
		[[
		vim.g.next_file_calls = 0
		require("gleb.diff.view").show(..., {
			path = "b.txt",
			left = { "a" },
			right = { "b" },
			labels = { left = "HEAD", right = "Working tree" },
			on_next_file = function() vim.g.next_file_calls = vim.g.next_file_calls + 1 end,
		})
	]],
		{ target }
	)
	local right_win = child.lua_get([=[require("gleb.diff.view").state.by_path[vim.fs.normalize("b.txt")].right_win]=])
	child.api.nvim_set_current_win(right_win)
	child.type_keys("]f")

	eq(child.g.next_file_calls, 1)
end

T["diff: Diff view ]f without a list keeps the view"] = function()
	open_controller()
	local before = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		return {
			view = view,
			buffers = { vim.api.nvim_win_get_buf(view.left_win), vim.api.nvim_win_get_buf(view.right_win) },
			cursor = vim.api.nvim_win_get_cursor(view.right_win),
		}
	end)()]])
	child.type_keys("]f")
	local after = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		return {
			view = view,
			buffers = { vim.api.nvim_win_get_buf(view.left_win), vim.api.nvim_win_get_buf(view.right_win) },
			cursor = vim.api.nvim_win_get_cursor(view.right_win),
		}
	end)()]])

	eq(after, before)
end

T["diff: Diff view mappings come from diff actions"] = function()
	open_controller()
	local failures = child.lua_get([[(function()
		local actions = require("gleb.actions")
		local catalog = actions.state.applicator.catalog
		local shortcuts = actions.state.store.last_good
		local view = require("gleb.diff.view").current()
		local failures = {}
		for _, id in ipairs({ "diff.close", "diff.next_file" }) do
			local action = catalog:get(id)
			if not action or action.plugin ~= "gleb-diff" then
				table.insert(failures, id .. "=<action>")
			end
			for _, lhs in ipairs(shortcuts[id] or {}) do
				for _, buf in ipairs({ view.left_buf, view.right_buf }) do
					local map = vim.api.nvim_buf_call(buf, function()
						return vim.fn.maparg(lhs, "n", false, true)
					end)
					if not map.callback or map.nowait ~= 1 or map.desc ~= "Git | Diff: " .. action.title then
						table.insert(failures, id .. "=" .. lhs)
					end
				end
			end
		end
		if shortcuts["diff.open_file"] ~= nil then
			table.insert(failures, "diff.open_file=<assigned>")
		end
		return failures
	end)()]])

	eq(failures, {})
end

T["diff: Diff view uses a reassigned key on reopen"] = function()
	open_controller()
	child.lua([[
		local actions = require("gleb.actions")
		actions.state.store.last_good["diff.close"] = { "Q" }
	]])
	child.type_keys("q")
	open_diff()
	local mappings = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local result = {}
		for _, buf in ipairs({ view.left_buf, view.right_buf }) do
			result[#result + 1] = vim.api.nvim_buf_call(buf, function()
				return {
					next(vim.fn.maparg("q", "n", false, true)) ~= nil,
					next(vim.fn.maparg("Q", "n", false, true)) ~= nil,
				}
			end)
		end
		return result
	end)()]])
	eq(mappings, { { false, true }, { false, true } })
	child.type_keys("Q")
	eq(#child.api.nvim_list_tabpages(), 1)
end

return T
