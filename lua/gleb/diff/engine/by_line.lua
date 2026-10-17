-- IntelliJ ByLine pipeline: smart anchors, chunk optimization, and exact realignment.
-- The first pass ignores whitespace so short syntax lines cannot pull matching off useful anchors.

local lcs = require("gleb.diff.engine.lcs")
local optimizer = require("gleb.diff.engine.optimizer")
local policy = require("gleb.diff.engine.policy")
local ranges = require("gleb.diff.engine.ranges")
local trim = require("gleb.diff.engine.trim")

local M = {}

local UNIMPORTANT_LINE_CHAR_COUNT = 3

---@class gleb.diff.Line
---@field content string
---@field key string
---@field ignore_key string
---@field nonspace integer

local function make_lines(raw_lines, comparison_policy)
	local lines = {}
	for index, content in ipairs(raw_lines) do
		lines[index] = {
			content = content,
			key = policy.key(content, comparison_policy),
			ignore_key = policy.ignore_key(content),
			nonspace = policy.count_nonspace_codepoints(content),
		}
	end
	return lines
end

local function line_equals(lines1, lines2, field)
	return function(index1, index2)
		return lines1[index1 + 1][field] == lines2[index2 + 1][field]
	end
end

local function sequence_changes(values1, values2, threshold)
	local result = lcs.diff(values1, values2, threshold)
	return ranges.from_matches(result.matches, #values1, #values2), result.status
end

local function new_change_builder(length1, length2, expand_equals)
	local builder = { index1 = 0, index2 = 0 }
	local changes = {}

	local function add_change(start1, start2, end1, end2)
		if expand_equals then
			local expanded = trim.expand(start1, start2, end1, end2, expand_equals)
			start1, start2 = expanded.start1, expanded.start2
			end1, end2 = expanded.end1, expanded.end2
		end
		if start1 ~= end1 or start2 ~= end2 then
			changes[#changes + 1] = { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
		end
	end

	function builder.mark_equal(start1, start2, end1, end2)
		if start1 == end1 and start2 == end2 then
			return
		end
		if builder.index1 ~= start1 or builder.index2 ~= start2 then
			add_change(builder.index1, builder.index2, start1, start2)
		end
		builder.index1 = end1
		builder.index2 = end2
	end

	function builder.finish()
		if builder.index1 ~= length1 or builder.index2 ~= length2 then
			add_change(builder.index1, builder.index2, length1, length2)
		end
		return changes
	end

	return builder
end

local function smart_line_change_corrector(lines1, lines2, big_changes, indexes1, indexes2, threshold)
	local builder = new_change_builder(#lines1, #lines2)
	local ignore_equals = line_equals(lines1, lines2, "ignore_key")
	local big_unchanged = ranges.unchanged_from_changes(big_changes, #indexes1, #indexes2)
	local status = "ok"

	local function match_gap(start1, end1, start2, end2)
		local expanded = trim.expand(start1, start2, end1, end2, ignore_equals)
		builder.mark_equal(start1, start2, expanded.start1, expanded.start2)
		local values1 = {}
		local values2 = {}
		for index = expanded.start1, expanded.end1 - 1 do
			values1[#values1 + 1] = lines1[index + 1].ignore_key
		end
		for index = expanded.start2, expanded.end2 - 1 do
			values2[#values2 + 1] = lines2[index + 1].ignore_key
		end
		local inner_changes, inner_status = sequence_changes(values1, values2, threshold)
		if inner_status ~= "ok" then
			status = inner_status
			return
		end
		for _, unchanged in ipairs(ranges.unchanged_from_changes(inner_changes, #values1, #values2)) do
			builder.mark_equal(
				expanded.start1 + unchanged.start1,
				expanded.start2 + unchanged.start2,
				expanded.start1 + unchanged.end1,
				expanded.start2 + unchanged.end2
			)
		end
		builder.mark_equal(expanded.end1, expanded.end2, end1, end2)
	end

	local last1 = 0
	local last2 = 0
	for _, unchanged in ipairs(big_unchanged) do
		for offset = 0, unchanged.end1 - unchanged.start1 - 1 do
			local index1 = indexes1[unchanged.start1 + offset + 1]
			local index2 = indexes2[unchanged.start2 + offset + 1]
			match_gap(last1, index1, last2, index2)
			if status ~= "ok" then
				return {}, status
			end
			builder.mark_equal(index1, index2, index1 + 1, index2 + 1)
			last1 = index1 + 1
			last2 = index2 + 1
		end
	end
	match_gap(last1, #lines1, last2, #lines2)
	return builder.finish(), status
end

local function compare_smart(lines1, lines2, threshold)
	local big1 = {}
	local big2 = {}
	local indexes1 = {}
	local indexes2 = {}
	for index, line in ipairs(lines1) do
		if line.nonspace > UNIMPORTANT_LINE_CHAR_COUNT then
			big1[#big1 + 1] = line.ignore_key
			indexes1[#indexes1 + 1] = index - 1
		end
	end
	for index, line in ipairs(lines2) do
		if line.nonspace > UNIMPORTANT_LINE_CHAR_COUNT then
			big2[#big2 + 1] = line.ignore_key
			indexes2[#indexes2 + 1] = index - 1
		end
	end
	local big_changes, status = sequence_changes(big1, big2, threshold)
	if status ~= "ok" then
		return {}, status
	end
	return smart_line_change_corrector(lines1, lines2, big_changes, indexes1, indexes2, threshold)
end

local function align_exact_matching(lines1, lines2, indexes1, indexes2, builder)
	local count = math.max(#indexes1, #indexes2)
	if count > 10 or #indexes1 == #indexes2 then
		for index = 1, math.min(#indexes1, #indexes2) do
			local index1 = indexes1[index]
			local index2 = indexes2[index]
			if lines1[index1 + 1].key == lines2[index2 + 1].key then
				builder.mark_equal(index1, index2, index1 + 1, index2 + 1)
			end
		end
		return
	end

	local small = indexes1
	local large = indexes2
	local small_lines = lines1
	local large_lines = lines2
	local swapped = false
	if #indexes1 > #indexes2 then
		small, large = indexes2, indexes1
		small_lines, large_lines = lines2, lines1
		swapped = true
	end

	local combination = {}
	local best = {}
	for index = 1, #small do
		best[index] = index
	end
	local best_weight = 0
	local function score_combination()
		local weight = 0
		for index = 1, #small do
			if small_lines[small[index] + 1].key == large_lines[large[combination[index]] + 1].key then
				weight = weight + 1
			end
		end
		if weight > best_weight then
			best_weight = weight
			for index = 1, #small do
				best[index] = combination[index]
			end
		end
	end
	local function combinations(start, position)
		if position > #small then
			score_combination()
			return
		end
		for index = start, #large do
			combination[position] = index
			combinations(index + 1, position + 1)
		end
	end
	combinations(1, 1)

	for index = 1, #small do
		local index1 = swapped and large[best[index]] or small[index]
		local index2 = swapped and small[index] or large[best[index]]
		if lines1[index1 + 1].key == lines2[index2 + 1].key then
			builder.mark_equal(index1, index2, index1 + 1, index2 + 1)
		end
	end
end

local function correct_changes_second_step(lines1, lines2, ignore_changes)
	local unchanged = ranges.unchanged_from_changes(ignore_changes, #lines1, #lines2)
	local builder = new_change_builder(#lines1, #lines2, line_equals(lines1, lines2, "key"))
	local sample
	local last1 = 0
	local last2 = 0

	local function flush(end1, end2)
		if sample == nil then
			return
		end
		local indexes1 = {}
		local indexes2 = {}
		for index = math.max(last1, builder.index1), end1 - 1 do
			if lines1[index + 1].ignore_key == sample then
				indexes1[#indexes1 + 1] = index
				last1 = index + 1
			end
		end
		for index = math.max(last2, builder.index2), end2 - 1 do
			if lines2[index + 1].ignore_key == sample then
				indexes2[#indexes2 + 1] = index
				last2 = index + 1
			end
		end
		align_exact_matching(lines1, lines2, indexes1, indexes2, builder)
		sample = nil
	end

	for _, range in ipairs(unchanged) do
		for offset = 0, range.end1 - range.start1 - 1 do
			local index1 = range.start1 + offset
			local index2 = range.start2 + offset
			local line1 = lines1[index1 + 1]
			local line2 = lines2[index2 + 1]
			if sample == nil or line1.ignore_key ~= sample then
				if line1.key == line2.key then
					flush(index1, index2)
					builder.mark_equal(index1, index2, index1 + 1, index2 + 1)
				else
					flush(index1, index2)
					sample = line1.ignore_key
				end
			end
		end
	end
	flush(#lines1, #lines2)
	return builder.finish()
end

local function expand_ranges(lines1, lines2, changes)
	local equals = line_equals(lines1, lines2, "key")
	local expanded = {}
	for _, change in ipairs(changes) do
		local range = trim.expand(change.start1, change.start2, change.end1, change.end2, equals)
		if range.start1 ~= range.end1 or range.start2 ~= range.end2 then
			expanded[#expanded + 1] = range
		end
	end
	return expanded
end

---@param raw1 string[]
---@param raw2 string[]
---@param comparison_policy gleb.diff.Policy
---@param threshold integer
---@return gleb.diff.LineFragment[], gleb.diff.LcsStatus
function M.compare(raw1, raw2, comparison_policy, threshold)
	local lines1 = make_lines(raw1, comparison_policy)
	local lines2 = make_lines(raw2, comparison_policy)
	local changes, status = compare_smart(lines1, lines2, threshold)
	if status ~= "ok" then
		return {}, status
	end
	local equals = line_equals(lines1, lines2, "key")
	changes = optimizer.optimize(lines1, lines2, changes, equals)
	if comparison_policy == "ignore_whitespaces" or comparison_policy == "ignore_whitespaces_chunks" then
		return expand_ranges(lines1, lines2, changes), status
	end
	return correct_changes_second_step(lines1, lines2, changes), status
end

return M
