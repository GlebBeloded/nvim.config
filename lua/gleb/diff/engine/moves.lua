-- Lua port of microsoft/vscode src/vs/editor/common/diff/defaultLinesDiffComputer/computeMovedLines.ts
-- and LineRangeFragment in utils.ts (MIT, © Microsoft Corporation). Modified: rewritten in Lua,
-- 0-based ranges, code-point counts; see NOTICE.
-- Detects moved line ranges on top of an existing line diff while preserving VS Code's thresholds.

local lcs = require("gleb.diff.engine.lcs")

local M = {}

local MIN_MOVE_LINES = 3
local MIN_SIMILARITY = 0.90
local SIMILAR_RATIO = 0.6
local SIMILAR_MIN_CHARS = 10
local MAX_SIMILAR_LINE = 300
local JOIN_MAX_GAP = 2
local MIN_MOVE_CHARS = 15
local MIN_LINE_CHARS = 2
local MIN_LONG_LINES = 2
local DEADLINE_BATCH_SIZE = 256
local SORT_TIMED_OUT = {}

local function timed_out(context)
	return context.clock() > context.deadline
end

local function codepoints(text)
	local result = {}
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		result[#result + 1] = char
	end
	return result
end

local function trim(text)
	return (text:gsub("^[ \t\n\r\v\f]+", ""):gsub("[ \t\n\r\v\f]+$", ""))
end

local function text_length(text)
	return #codepoints(text)
end

local function range_length(range)
	return range[2] - range[1]
end

local function move(start1, end1, start2, end2)
	return { start1, end1, start2, end2 }
end

local function histogram(lines, start_line, end_line, context)
	local counts = {}
	local total = 0
	for index = start_line + 1, end_line do
		if timed_out(context) then
			return nil, 0
		end
		for _, char in ipairs(codepoints(lines[index])) do
			counts[char] = (counts[char] or 0) + 1
			total = total + 1
		end
		counts["\n"] = (counts["\n"] or 0) + 1
		total = total + 1
	end
	return counts, total
end

local function fragment(change, side, lines, id, context)
	local offset = side == 1 and 0 or 2
	local counts, total = histogram(lines, change[offset + 1], change[offset + 2], context)
	if not counts then
		return nil
	end
	return {
		start_line = change[offset + 1],
		end_line = change[offset + 2],
		counts = counts,
		total = total,
		change_id = id,
	}
end

local function similarity(left, right, context)
	local difference = 0
	local seen = {}
	local processed = 0
	for char, count in pairs(left.counts) do
		processed = processed + 1
		if processed == DEADLINE_BATCH_SIZE then
			processed = 0
			if timed_out(context) then
				return 0
			end
		end
		difference = difference + math.abs(count - (right.counts[char] or 0))
		seen[char] = true
	end
	for char, count in pairs(right.counts) do
		processed = processed + 1
		if processed == DEADLINE_BATCH_SIZE then
			processed = 0
			if timed_out(context) then
				return 0
			end
		end
		if not seen[char] then
			difference = difference + count
		end
	end
	return 1 - difference / (left.total + right.total)
end

local function moves_from_simple_changes(changes, lines1, lines2, context)
	local moves = {}
	local deletions = {}
	local insertions = {}
	for id, change in ipairs(changes) do
		if timed_out(context) then
			return {}, {}
		end
		if change[3] == change[4] and change[2] - change[1] >= MIN_MOVE_LINES then
			local deletion = fragment(change, 1, lines1, id, context)
			if not deletion then
				return {}, {}
			end
			deletions[#deletions + 1] = deletion
		end
		if change[1] == change[2] and change[4] - change[3] >= MIN_MOVE_LINES then
			local insertion = fragment(change, 2, lines2, id, context)
			if not insertion then
				return {}, {}
			end
			insertions[#insertions + 1] = insertion
		end
	end

	local excluded = {}
	for _, deletion in ipairs(deletions) do
		local highest = -1
		local best_index
		for index, insertion in ipairs(insertions) do
			if timed_out(context) then
				return moves, excluded
			end
			local score = similarity(deletion, insertion, context)
			if score > highest then
				highest = score
				best_index = index
			end
		end
		if highest > MIN_SIMILARITY and best_index then
			local insertion = table.remove(insertions, best_index)
			moves[#moves + 1] = move(deletion.start_line, deletion.end_line, insertion.start_line, insertion.end_line)
			excluded[deletion.change_id] = true
			excluded[insertion.change_id] = true
		end
		if timed_out(context) then
			return moves, excluded
		end
	end
	return moves, excluded
end

local function add_range(ranges, range)
	local start_line = range[1]
	local end_line = range[2]
	local first = 1
	while first <= #ranges and ranges[first][2] < start_line do
		first = first + 1
	end
	local after = first
	while after <= #ranges and ranges[after][1] <= end_line do
		start_line = math.min(start_line, ranges[after][1])
		end_line = math.max(end_line, ranges[after][2])
		after = after + 1
	end
	if first == after then
		table.insert(ranges, first, { start_line, end_line })
		return
	end

	ranges[first] = { start_line, end_line }
	local removed = after - first - 1
	for index = after, #ranges do
		ranges[index - removed] = ranges[index]
	end
	for index = #ranges, #ranges - removed + 1, -1 do
		ranges[index] = nil
	end
end

local function contains(ranges, value)
	for _, range in ipairs(ranges) do
		if value < range[1] then
			return false
		end
		if range[1] <= value and value < range[2] then
			return true
		end
	end
	return false
end

local function subtract(range, claimed)
	local result = {}
	local start_line = range[1]
	for _, used in ipairs(claimed) do
		if range[2] <= used[1] then
			break
		end
		if start_line < used[1] then
			result[#result + 1] = { start_line, math.min(used[1], range[2]) }
		end
		start_line = math.max(start_line, used[2])
		if range[2] <= start_line then
			break
		end
	end
	if start_line < range[2] then
		result[#result + 1] = { start_line, range[2] }
	end
	return result
end

local function intersections(left, right)
	local result = {}
	local left_index = 1
	local right_index = 1
	while left_index <= #left and right_index <= #right do
		local left_range = left[left_index]
		local right_range = right[right_index]
		local start_line = math.max(left_range[1], right_range[1])
		local end_line = math.min(left_range[2], right_range[2])
		if start_line < end_line then
			result[#result + 1] = { start_line, end_line }
		end
		if left_range[2] < right_range[2] then
			left_index = left_index + 1
		else
			right_index = right_index + 1
		end
	end
	return result
end

local function line_hashes(lines, ids, next_id, context)
	local hashes = {}
	for index, line in ipairs(lines) do
		if index % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
			return nil, next_id
		end
		local key = trim(line)
		if ids[key] == nil then
			ids[key] = next_id
			next_id = next_id + 1
		end
		hashes[index] = ids[key]
	end
	return hashes, next_id
end

local function find_last_change(changes, side, predicate)
	local offset = side == 1 and 0 or 2
	local found
	for _, entry in ipairs(changes) do
		if predicate(entry[offset + 1]) then
			found = entry
		end
	end
	return found
end

local function is_space(char)
	return char == " " or char == "\t"
end

local function similar_line_sequence(chars, line)
	local leading_whitespace = #(line:match("^[ \t\n\r\v\f]*") or "")
	local maximum = #chars - 1 - leading_whitespace
	local result = codepoints(trim(line))
	for index = #result, maximum + 1, -1 do
		result[index] = nil
	end
	return result
end

local function lines_similar(line1, line2, context)
	if timed_out(context) then
		return false
	end
	if trim(line1) == trim(line2) then
		return true
	end
	local chars1 = codepoints(line1)
	local chars2 = codepoints(line2)
	if #chars1 > MAX_SIMILAR_LINE and #chars2 > MAX_SIMILAR_LINE then
		return false
	end

	local sequence1 = similar_line_sequence(chars1, line1)
	local sequence2 = similar_line_sequence(chars2, line2)
	local values1 = {}
	local values2 = {}
	local keys = {}
	local next_key = 1
	for index, char in ipairs(sequence1) do
		if not keys[char] then
			keys[char] = next_key
			next_key = next_key + 1
		end
		values1[index] = keys[char]
	end
	for index, char in ipairs(sequence2) do
		if not keys[char] then
			keys[char] = next_key
			next_key = next_key + 1
		end
		values2[index] = keys[char]
	end
	local result = lcs.diff(values1, values2, context)
	if result.status ~= "ok" then
		return false
	end
	local matched = {}
	for _, match in ipairs(result.matches) do
		matched[match[1]] = true
	end
	local common_non_space = 0
	-- VS Code inverts the sequence diffs up to the raw line length, then reads raw line1
	-- at the trimmed sequence offsets. The tail beyond the truncated sequence is therefore common.
	for index = 0, #chars1 - 1 do
		if index % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
			return false
		end
		if (index >= #sequence1 or matched[index]) and not is_space(chars1[index + 1]) then
			common_non_space = common_non_space + 1
		end
	end

	local longer = #chars1 > #chars2 and chars1 or chars2
	local longer_length = 0
	-- VS Code's countNonWsChars intentionally iterates using line1's length for either string.
	for index = 1, #chars1 do
		if index % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
			return false
		end
		if not is_space(longer[index]) then
			longer_length = longer_length + 1
		end
	end
	return longer_length > SIMILAR_MIN_CHARS and common_non_space / longer_length > SIMILAR_RATIO
end

local function sort_candidates(candidates, context)
	local comparisons = 0
	local function comes_before(left, right)
		comparisons = comparisons + 1
		if comparisons == DEADLINE_BATCH_SIZE then
			comparisons = 0
			if timed_out(context) then
				error(SORT_TIMED_OUT, 0)
			end
		end
		local left_length = range_length(left.modified)
		local right_length = range_length(right.modified)
		return left_length == right_length and left.order < right.order or left_length > right_length
	end

	local ok, failure = pcall(table.sort, candidates, comes_before)
	if not ok then
		if failure == SORT_TIMED_OUT then
			return false
		end
		error(failure, 0)
	end
	return not timed_out(context)
end

local function unchanged_moves(changes, lines1, lines2, context)
	local ids = {}
	local hashes1, next_id = line_hashes(lines1, ids, 0, context)
	if not hashes1 then
		return {}
	end
	local hashes2 = line_hashes(lines2, ids, next_id, context)
	if not hashes2 then
		return {}
	end
	local windows = {}
	for _, change in ipairs(changes) do
		for start_line = change[1], change[2] - MIN_MOVE_LINES do
			if start_line % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
				return {}
			end
			local key = table.concat({ hashes1[start_line + 1], hashes1[start_line + 2], hashes1[start_line + 3] }, ":")
			windows[key] = windows[key] or {}
			windows[key][#windows[key] + 1] = { start_line, start_line + MIN_MOVE_LINES }
		end
	end

	local ordered_changes = vim.deepcopy(changes)
	table.sort(ordered_changes, function(a, b)
		return a[3] < b[3]
	end)
	local possible = {}
	local order = 0
	local scanned = 0
	for _, change in ipairs(ordered_changes) do
		local last_mappings = {}
		for start_line = change[3], change[4] - MIN_MOVE_LINES do
			if timed_out(context) then
				return {}
			end
			local key = table.concat({ hashes2[start_line + 1], hashes2[start_line + 2], hashes2[start_line + 3] }, ":")
			local current = { start_line, start_line + MIN_MOVE_LINES }
			local next_mappings = {}
			for _, original in ipairs(windows[key] or {}) do
				scanned = scanned + 1
				if scanned == DEADLINE_BATCH_SIZE then
					scanned = 0
					if timed_out(context) then
						return {}
					end
				end
				local previous = last_mappings[original[2] - 1]
				if previous and previous.modified[2] + 1 == current[2] then
					previous.original[2] = original[2]
					previous.modified[2] = current[2]
					next_mappings[original[2]] = previous
				else
					order = order + 1
					local mapping = { original = { original[1], original[2] }, modified = current, order = order }
					possible[#possible + 1] = mapping
					next_mappings[original[2]] = mapping
				end
			end
			last_mappings = next_mappings
		end
		if timed_out(context) then
			return {}
		end
	end

	if not sort_candidates(possible, context) then
		return {}
	end
	local claimed1 = {}
	local claimed2 = {}
	local moves = {}
	for index, mapping in ipairs(possible) do
		if index % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
			return {}
		end
		local delta = mapping.modified[1] - mapping.original[1]
		local available2 = subtract(mapping.modified, claimed2)
		local available1 = subtract(mapping.original, claimed1)
		for _, range in ipairs(available1) do
			range[1] = range[1] + delta
			range[2] = range[2] + delta
		end
		for _, section in ipairs(intersections(available2, available1)) do
			if range_length(section) >= MIN_MOVE_LINES then
				moves[#moves + 1] = move(section[1] - delta, section[2] - delta, section[1], section[2])
				add_range(claimed1, { section[1] - delta, section[2] - delta })
				add_range(claimed2, section)
			end
		end
	end

	table.sort(moves, function(a, b)
		return a[1] < b[1]
	end)
	for index, current in ipairs(moves) do
		if timed_out(context) then
			return {}
		end
		local first1 = find_last_change(ordered_changes, 1, function(start_line)
			return start_line <= current[1]
		end)
		local first2 = find_last_change(ordered_changes, 2, function(start_line)
			return start_line <= current[3]
		end)
		local last1 = find_last_change(ordered_changes, 1, function(start_line)
			return start_line < current[2]
		end)
		local last2 = find_last_change(ordered_changes, 2, function(start_line)
			return start_line < current[4]
		end)
		if first1 and first2 and last1 and last2 then
			local above = math.max(current[1] - first1[1], current[3] - first2[3])
			local below = math.max(last1[2] - current[2], last2[4] - current[4])
			local extend_top = 0
			while extend_top < above do
				local line1 = current[1] - extend_top - 1
				local line2 = current[3] - extend_top - 1
				if line1 < 0 or line2 < 0 or contains(claimed1, line1) or contains(claimed2, line2) then
					break
				end
				if not lines_similar(lines1[line1 + 1], lines2[line2 + 1], context) then
					break
				end
				extend_top = extend_top + 1
			end
			if extend_top > 0 then
				add_range(claimed1, { current[1] - extend_top, current[1] })
				add_range(claimed2, { current[3] - extend_top, current[3] })
			end
			local extend_bottom = 0
			while extend_bottom < below do
				local line1 = current[2] + extend_bottom
				local line2 = current[4] + extend_bottom
				if line1 >= #lines1 or line2 >= #lines2 or contains(claimed1, line1) or contains(claimed2, line2) then
					break
				end
				if not lines_similar(lines1[line1 + 1], lines2[line2 + 1], context) then
					break
				end
				extend_bottom = extend_bottom + 1
			end
			if extend_bottom > 0 then
				add_range(claimed1, { current[2], current[2] + extend_bottom })
				add_range(claimed2, { current[4], current[4] + extend_bottom })
			end
			if extend_top > 0 or extend_bottom > 0 then
				moves[index] = move(
					current[1] - extend_top,
					current[2] + extend_bottom,
					current[3] - extend_top,
					current[4] + extend_bottom
				)
			end
		end
	end
	return moves
end

local function join_close_moves(moves, context)
	if #moves == 0 then
		return moves
	end
	table.sort(moves, function(a, b)
		return a[1] < b[1]
	end)
	local result = { moves[1] }
	for index = 2, #moves do
		if timed_out(context) then
			return {}
		end
		local last = result[#result]
		local current = moves[index]
		local gap1 = current[1] - last[2]
		local gap2 = current[3] - last[4]
		if gap1 >= 0 and gap2 >= 0 and gap1 + gap2 <= JOIN_MAX_GAP then
			result[#result] = move(
				math.min(last[1], current[1]),
				math.max(last[2], current[2]),
				math.min(last[3], current[3]),
				math.max(last[4], current[4])
			)
		else
			result[#result + 1] = current
		end
	end
	return result
end

local function remove_moves_in_same_change(changes, moves, context)
	local result = {}
	for _, current in ipairs(moves) do
		if timed_out(context) then
			return {}
		end
		local original_id
		local modified_id
		for id, change in ipairs(changes) do
			if id % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
				return {}
			end
			if change[1] < current[2] then
				original_id = id
			end
			if change[3] < current[4] then
				modified_id = id
			end
		end
		if original_id ~= modified_id then
			result[#result + 1] = current
		end
	end
	return result
end

local function long_enough(current, lines1, context)
	local lines = {}
	local long_lines = 0
	for index = current[1] + 1, current[2] do
		if index % DEADLINE_BATCH_SIZE == 0 and timed_out(context) then
			return false
		end
		local line = trim(lines1[index])
		lines[#lines + 1] = line
		if text_length(line) >= MIN_LINE_CHARS then
			long_lines = long_lines + 1
		end
	end
	return text_length(table.concat(lines, "\n")) >= MIN_MOVE_CHARS and long_lines >= MIN_LONG_LINES
end

---@param changes integer[][] 0-based half-open line ranges: start1, end1, start2, end2
---@param lines1 string[]
---@param lines2 string[]
---@param context gleb.diff.Context
---@return integer[][]
function M.compute(changes, lines1, lines2, context)
	local moves, excluded = moves_from_simple_changes(changes, lines1, lines2, context)
	if timed_out(context) then
		return {}
	end
	local filtered = {}
	for id, change in ipairs(changes) do
		if timed_out(context) then
			return {}
		end
		if not excluded[id] then
			filtered[#filtered + 1] = change
		end
	end
	for _, current in ipairs(unchanged_moves(filtered, lines1, lines2, context)) do
		moves[#moves + 1] = current
	end
	moves = join_close_moves(moves, context)
	local kept = {}
	for _, current in ipairs(moves) do
		if timed_out(context) then
			return {}
		end
		if long_enough(current, lines1, context) then
			kept[#kept + 1] = current
		end
	end
	return remove_moves_in_same_change(changes, kept, context)
end

return M
