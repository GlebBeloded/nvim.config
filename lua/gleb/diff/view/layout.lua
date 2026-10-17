-- Pure row model for the aligned diff view.
-- It turns half-open engine fragments into paired screen rows, collapsed context and gutter text.

local M = {}

---@alias gleb.diff.view.ChangeKind "Add"|"Change"|"Delete"
---@alias gleb.diff.view.Kind gleb.diff.view.ChangeKind|"Moved"

---@class gleb.diff.view.Row
---@field left? integer
---@field right? integer
---@field change? integer
---@field kind? gleb.diff.view.Kind
---@field arrow_kind? gleb.diff.view.ChangeKind
---@field first? boolean
---@field checkbox? boolean|string
---@field move_marker? string
---@field fold? integer
---@field count? integer

---@class gleb.diff.view.Fold
---@field row integer
---@field start1 integer
---@field end1 integer
---@field start2 integer
---@field end2 integer
---@field count integer

---@class gleb.diff.view.Layout
---@field rows gleb.diff.view.Row[]
---@field folds gleb.diff.view.Fold[]
---@field fragments gleb.diff.LineFragment[]
---@field moves gleb.diff.Move[]
---@field line_count1 integer
---@field line_count2 integer

---@param fragment gleb.diff.LineFragment
---@return gleb.diff.view.ChangeKind
local function change_kind(fragment)
	if fragment.start1 == fragment.end1 then
		return "Add"
	end
	if fragment.start2 == fragment.end2 then
		return "Delete"
	end
	return "Change"
end

---@param rows gleb.diff.view.Row[]
---@param folds gleb.diff.view.Fold[]
---@param start1 integer 0-based, inclusive
---@param end1 integer 0-based, exclusive
---@param start2 integer 0-based, inclusive
---@param context integer
---@param has_change_before boolean
---@param has_change_after boolean
local function add_unchanged(rows, folds, start1, end1, start2, context, has_change_before, has_change_after)
	local count = end1 - start1
	local keep_before = has_change_before and math.min(context, count) or 0
	local keep_after = has_change_after and math.min(context, count - keep_before) or 0
	local hidden = count - keep_before - keep_after

	if hidden < 2 then
		keep_before = count
		hidden = 0
		keep_after = 0
	end

	for offset = 0, keep_before - 1 do
		rows[#rows + 1] = { left = start1 + offset + 1, right = start2 + offset + 1 }
	end
	if hidden > 0 then
		local fold_index = #folds + 1
		local left_start = start1 + keep_before + 1
		local right_start = start2 + keep_before + 1
		rows[#rows + 1] = { fold = fold_index, left = left_start, right = right_start, count = hidden }
		folds[fold_index] = {
			row = #rows,
			start1 = left_start,
			end1 = left_start + hidden - 1,
			start2 = right_start,
			end2 = right_start + hidden - 1,
			count = hidden,
		}
	end
	for offset = count - keep_after, count - 1 do
		rows[#rows + 1] = { left = start1 + offset + 1, right = start2 + offset + 1 }
	end
end

---@param rows gleb.diff.view.Row[]
---@param fragment gleb.diff.LineFragment
---@param index integer
---@param checkbox boolean|string
local function add_change(rows, fragment, index, checkbox)
	local count1 = fragment.end1 - fragment.start1
	local count2 = fragment.end2 - fragment.start2
	local count = math.max(count1, count2)
	local kind = change_kind(fragment)
	for offset = 0, count - 1 do
		---@type gleb.diff.view.Row
		local row = { change = index, kind = kind }
		if offset < count1 then
			row.left = fragment.start1 + offset + 1
		end
		if offset < count2 then
			row.right = fragment.start2 + offset + 1
		end
		if offset == 0 then
			row.first = true
			row.checkbox = checkbox
		end
		rows[#rows + 1] = row
	end
end

---@param text string
---@return string
local function move_marker(text)
	text = vim.fn.strcharpart(text, 0, 5)
	return text .. string.rep(" ", math.max(5 - vim.fn.strdisplaywidth(text), 0))
end

--- Tints a changed row as moved while its arrow keeps the original change colour.
---@param row gleb.diff.view.Row
local function mark_moved(row)
	if row.kind ~= "Moved" then
		row.arrow_kind = row.kind --[[@as gleb.diff.view.ChangeKind?]]
		row.kind = "Moved"
	end
end

---@param rows gleb.diff.view.Row[]
---@param moves gleb.diff.Move[]
local function mark_moves(rows, moves)
	for _, move in ipairs(moves) do
		for _, row in ipairs(rows) do
			local left = row.left and row.left - 1 or nil
			local right = row.right and row.right - 1 or nil
			if left and left >= move.start1 and left < move.end1 then
				mark_moved(row)
				if left == move.start1 then
					row.move_marker = move_marker("→" .. (move.start2 + 1))
				end
			elseif right and right >= move.start2 and right < move.end2 then
				mark_moved(row)
				if right == move.start2 then
					row.move_marker = move_marker("←" .. (move.start1 + 1))
				end
			end
		end
	end
end

---@param fragments gleb.diff.LineFragment[] ordered, non-overlapping half-open ranges
---@param line_count1 integer
---@param line_count2 integer
---@param context integer
---@param states? string[]
---@param moves? gleb.diff.Move[]
---@return gleb.diff.view.Layout
function M.build(fragments, line_count1, line_count2, context, states, moves)
	local rows = {}
	local folds = {}
	if #fragments == 0 then
		for line = 1, math.max(line_count1, line_count2) do
			rows[#rows + 1] = {
				left = line <= line_count1 and line or nil,
				right = line <= line_count2 and line or nil,
			}
		end
		return {
			rows = rows,
			folds = folds,
			fragments = fragments,
			moves = moves or {},
			line_count1 = line_count1,
			line_count2 = line_count2,
		}
	end
	local previous1, previous2 = 0, 0
	for index, fragment in ipairs(fragments) do
		add_unchanged(rows, folds, previous1, fragment.start1, previous2, context, index > 1, true)
		add_change(rows, fragment, index, line_count1 > 0 and (states and states[index] or true))
		previous1, previous2 = fragment.end1, fragment.end2
	end
	add_unchanged(rows, folds, previous1, line_count1, previous2, context, #fragments > 0, false)
	mark_moves(rows, moves or {})
	return {
		rows = rows,
		folds = folds,
		fragments = fragments,
		moves = moves or {},
		line_count1 = line_count1,
		line_count2 = line_count2,
	}
end

---@param layout gleb.diff.view.Layout
---@param side "left"|"right"
---@param line integer 1-based line
---@return integer? change 1-based fragment index
function M.change_at_line(layout, side, line)
	local start_key = side == "left" and "start1" or "start2"
	local end_key = side == "left" and "end1" or "end2"
	for index, fragment in ipairs(layout.fragments) do
		local start_line = fragment[start_key]
		local end_line = fragment[end_key]
		if (start_line == end_line and line == start_line + 1) or (line > start_line and line <= end_line) then
			return index
		end
	end
end

---@param model gleb.diff.view.Layout
---@param side "left"|"right"
---@param line integer 1-based line
---@return integer? change 1-based fragment index
function M.change_at(model, side, line)
	return M.change_at_line(model, side, line)
end

---@param layout gleb.diff.view.Layout
---@param side "left"|"right"
---@param line integer 1-based line
---@return integer 1-based line on the other side
function M.transfer_line(layout, side, line)
	local source_start = side == "left" and "start1" or "start2"
	local source_end = side == "left" and "end1" or "end2"
	local target_start = side == "left" and "start2" or "start1"
	local target_end = side == "left" and "end2" or "end1"
	local delta = 0
	for _, fragment in ipairs(layout.fragments) do
		local source_count = fragment[source_end] - fragment[source_start]
		local target_count = fragment[target_end] - fragment[target_start]
		if line <= fragment[source_start] then
			return line + delta
		end
		if line <= fragment[source_end] then
			if target_count == 0 then
				return fragment[target_start] + 1
			end
			local offset = math.min(line - fragment[source_start] - 1, target_count - 1)
			return fragment[target_start] + offset + 1
		end
		delta = delta + target_count - source_count
	end
	return line + delta
end

---@param row gleb.diff.view.Row
---@return string
function M.gutter(row)
	if row.fold then
		return string.rep("~", 16)
	end
	local arrow = row.first and "»" or " "
	local left = row.left and string.format("%3d ", row.left) or "╱╱╱╱"
	local right = row.right and string.format("%3d ", row.right) or "╱╱╱╱"
	local checkbox = row.first and row.checkbox and (type(row.checkbox) == "string" and row.checkbox or "󰄱") or " "
	return arrow .. left .. (row.move_marker or "     ") .. right .. checkbox .. " "
end

return M
