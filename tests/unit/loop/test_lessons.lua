local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param text string
---@param needle string
---@return integer
local function position(text, needle)
	local start = text:find(needle, 1, true)
	eq(start ~= nil, true, { fail_reason = ("missing %q"):format(needle) })
	return start --[[@as integer]]
end

---@param prompt string
---@param task_context string
local function expect_lesson_order(prompt, task_context)
	local skills = position(prompt, "naming it.")
	local lessons = position(prompt, "## Loop lessons")
	local context = position(prompt, task_context)
	eq(skills < lessons and lessons < context, true)
end

T["loop: Fix and implement prompts read loop lessons"] = function()
	local workflow = read("docs/workflow.md")
	local explore = read(".archon/commands/explore-bug.md")
	local implement = read(".archon/commands/implement.md")

	position(workflow, "## Loop lessons")
	expect_lesson_order(explore, "Bug: $ARGUMENTS")
	expect_lesson_order(implement, "Change: openspec/changes/$INPUTS.change/")
	position(implement, "$ARTIFACTS_DIR/lesson-candidates.txt")
	position(implement, "failure from the previous pass")
	position(implement, "directly verified")
end

return T
