-- Lua port of intellij-community Diff.kt, MyersLCS.kt, Reindexer.kt, PatienceIntLCS.kt, and UniqueLCS.kt
-- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/myers_lcs.lua
-- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
-- Integer longest-common-subsequence engine used by line comparison.
-- Myers handles ordinary inputs; unique anchors bound difficult comparisons.

local M = {}

---@alias gleb.diff.LcsStatus "ok"|"too_big"|"timed_out"

---@class gleb.diff.LcsResult
---@field matches gleb.diff.Match[]
---@field status gleb.diff.LcsStatus

local function timed_out(context)
	return context.clock() > context.deadline
end

local function myers(values1, values2, context, bounded, exact)
	local length1 = #values1
	local length2 = #values2
	local forward = {}
	local backward = {}
	local matches = {}

	local function vector_get(vector, index)
		return vector[index] or 0
	end

	local function common_forward(index1, index2, max_length)
		local count = 0
		while count < max_length and values1[index1 + count + 1] == values2[index2 + count + 1] do
			if timed_out(context) then
				return nil, "timed_out"
			end
			count = count + 1
		end
		return count, "ok"
	end

	local function common_backward(index1, index2, max_length)
		local count = 0
		while count < max_length and values1[index1 - count + 1] == values2[index2 - count + 1] do
			if timed_out(context) then
				return nil, "timed_out"
			end
			count = count + 1
		end
		return count, "ok"
	end

	local execute
	execute = function(old_start, old_end, new_start, new_end, difference_estimate, throw_on_limit)
		if timed_out(context) then
			return "timed_out"
		end
		if old_start >= old_end or new_start >= new_end then
			return "ok"
		end

		local old_length = old_end - old_start
		local new_length = new_end - new_start
		forward[new_length + 1] = 0
		backward[new_length + 1] = 0
		local half_distance = math.floor((difference_estimate + 1) / 2)
		local split_x = -1
		local split_diagonal = -1
		local total_distance = -1

		for distance = 0, half_distance do
			if timed_out(context) then
				return "timed_out"
			end
			local parity1 = (distance + new_length) % 2
			local parity2 = (distance + old_length) % 2
			local left = new_length + math.max(-distance, -new_length + parity1)
			local right = new_length + math.min(distance, old_length - parity2)

			local diagonal = left
			while diagonal <= right do
				if timed_out(context) then
					return "timed_out"
				end
				local x
				if
					diagonal == left
					or (diagonal ~= right and vector_get(forward, diagonal - 1) < vector_get(forward, diagonal + 1))
				then
					x = vector_get(forward, diagonal + 1)
				else
					x = vector_get(forward, diagonal - 1) + 1
				end
				local y = x - diagonal + new_length
				local common, status =
					common_forward(old_start + x, new_start + y, math.min(old_length - x, new_length - y))
				if status ~= "ok" then
					return status
				end
				x = x + common
				forward[diagonal] = x
				diagonal = diagonal + 2
			end

			if (old_length - new_length) % 2 ~= 0 then
				diagonal = left
				while diagonal <= right do
					if timed_out(context) then
						return "timed_out"
					end
					if
						old_length - (distance - 1) <= diagonal
						and diagonal <= old_length + (distance - 1)
						and vector_get(forward, diagonal)
								+ vector_get(backward, new_length + old_length - diagonal)
							>= old_length
					then
						split_x = vector_get(forward, diagonal)
						split_diagonal = diagonal
						total_distance = 2 * distance - 1
						break
					end
					diagonal = diagonal + 2
				end
			end
			if total_distance >= 0 then
				break
			end

			diagonal = left
			while diagonal <= right do
				if timed_out(context) then
					return "timed_out"
				end
				local x
				if
					diagonal == left
					or (diagonal ~= right and vector_get(backward, diagonal - 1) < vector_get(backward, diagonal + 1))
				then
					x = vector_get(backward, diagonal + 1)
				else
					x = vector_get(backward, diagonal - 1) + 1
				end
				local y = x - diagonal + new_length
				local common, status =
					common_backward(old_end - 1 - x, new_end - 1 - y, math.min(old_length - x, new_length - y))
				if status ~= "ok" then
					return status
				end
				x = x + common
				backward[diagonal] = x
				diagonal = diagonal + 2
			end

			if (old_length - new_length) % 2 == 0 then
				diagonal = left
				while diagonal <= right do
					if timed_out(context) then
						return "timed_out"
					end
					if
						old_length - distance <= diagonal
						and diagonal <= old_length + distance
						and vector_get(forward, old_length + new_length - diagonal)
								+ vector_get(backward, diagonal)
							>= old_length
					then
						split_x = old_length - vector_get(backward, diagonal)
						split_diagonal = old_length + new_length - diagonal
						total_distance = 2 * distance
						break
					end
					diagonal = diagonal + 2
				end
			end
			if total_distance >= 0 then
				break
			end
		end

		if total_distance > 1 then
			local split_y = split_x - split_diagonal + new_length
			local old_distance = math.floor((total_distance + 1) / 2)
			if split_x > 0 and split_y > 0 then
				local status = execute(
					old_start,
					old_start + split_x,
					new_start,
					new_start + split_y,
					old_distance,
					throw_on_limit
				)
				if status ~= "ok" then
					return status
				end
			end
			if old_start + split_x < old_end and new_start + split_y < new_end then
				return execute(
					old_start + split_x,
					old_end,
					new_start + split_y,
					new_end,
					total_distance - old_distance,
					throw_on_limit
				)
			end
		elseif total_distance >= 0 then
			local x = old_start
			local y = new_start
			while x < old_end and y < new_end do
				if timed_out(context) then
					return "timed_out"
				end
				local common, status = common_forward(x, y, math.min(old_end - x, new_end - y))
				if status ~= "ok" then
					return status
				end
				if common > 0 then
					for offset = 0, common - 1 do
						if timed_out(context) then
							return "timed_out"
						end
						matches[#matches + 1] = { x + offset, y + offset }
					end
					x = x + common
					y = y + common
				elseif old_length > new_length then
					x = x + 1
				else
					y = y + 1
				end
			end
		elseif throw_on_limit then
			return "too_big"
		end
		return "ok"
	end

	if length1 == 0 or length2 == 0 then
		return {}, "ok"
	end
	local estimate
	if bounded then
		estimate = math.min(context.myers_threshold, length1 + length2)
	elseif exact then
		estimate = length1 + length2
	else
		estimate = math.min(20000 + 10 * math.floor(math.sqrt(length1 + length2)), length1 + length2)
	end
	local status = execute(0, length1, 0, length2, estimate, bounded)
	if status ~= "ok" then
		return nil, status
	end
	return matches, "ok"
end

---@param values1 integer[]
---@param values2 integer[]
---@param context gleb.diff.Context
---@return gleb.diff.LcsResult
function M.diff_exact(values1, values2, context)
	local matches, status = myers(values1, values2, context, false, true)
	return { matches = matches or {}, status = status }
end

local function unique_anchors(values1, values2, start1, end1, start2, end2, context)
	local counts1 = {}
	local counts2 = {}
	local positions2 = {}
	for index = start1, end1 do
		if timed_out(context) then
			return nil, "timed_out"
		end
		local value = values1[index]
		counts1[value] = (counts1[value] or 0) + 1
	end
	for index = start2, end2 do
		if timed_out(context) then
			return nil, "timed_out"
		end
		local value = values2[index]
		counts2[value] = (counts2[value] or 0) + 1
		positions2[value] = index
	end

	local candidates = {}
	for index = start1, end1 do
		if timed_out(context) then
			return nil, "timed_out"
		end
		local value = values1[index]
		if counts1[value] == 1 and counts2[value] == 1 then
			candidates[#candidates + 1] = { index, positions2[value] }
		end
	end

	local tails = {}
	local previous = {}
	for candidate_index, candidate in ipairs(candidates) do
		if timed_out(context) then
			return nil, "timed_out"
		end
		local low = 1
		local high = #tails
		while low <= high do
			if timed_out(context) then
				return nil, "timed_out"
			end
			local middle = math.floor((low + high) / 2)
			if candidates[tails[middle]][2] < candidate[2] then
				low = middle + 1
			else
				high = middle - 1
			end
		end
		previous[candidate_index] = low > 1 and tails[low - 1] or nil
		tails[low] = candidate_index
	end

	local reversed = {}
	local cursor = tails[#tails]
	while cursor do
		if timed_out(context) then
			return nil, "timed_out"
		end
		reversed[#reversed + 1] = candidates[cursor]
		cursor = previous[cursor]
	end
	local anchors = {}
	for index = #reversed, 1, -1 do
		if timed_out(context) then
			return nil, "timed_out"
		end
		anchors[#anchors + 1] = reversed[index]
	end
	return anchors, "ok"
end

local function append_matches(matches, additions, offset1, offset2, context)
	for _, match in ipairs(additions) do
		if timed_out(context) then
			return "timed_out"
		end
		matches[#matches + 1] = { match[1] + offset1, match[2] + offset2 }
	end
	return "ok"
end

local function reduction_is_small(count1, count2, original_count1, original_count2)
	return count1 * 2 < original_count1 or count2 * 2 < original_count2
end

local function patience_region(
	values1,
	values2,
	start1,
	end1,
	start2,
	end2,
	threshold_counter,
	original_count1,
	original_count2,
	context
)
	if timed_out(context) then
		return {}, false, "timed_out"
	end
	local matches = {}
	if start1 > end1 or start2 > end2 then
		return matches, true, "ok"
	end

	while start1 <= end1 and start2 <= end2 and values1[start1] == values2[start2] do
		if timed_out(context) then
			return {}, false, "timed_out"
		end
		matches[#matches + 1] = { start1 - 1, start2 - 1 }
		start1 = start1 + 1
		start2 = start2 + 1
	end
	local suffix_count = 0
	while start1 <= end1 and start2 <= end2 and values1[end1] == values2[end2] do
		if timed_out(context) then
			return {}, false, "timed_out"
		end
		suffix_count = suffix_count + 1
		end1 = end1 - 1
		end2 = end2 - 1
	end

	local function append_suffix()
		for offset = 0, suffix_count - 1 do
			if timed_out(context) then
				return "timed_out"
			end
			matches[#matches + 1] = { end1 + offset, end2 + offset }
		end
		return "ok"
	end

	if start1 > end1 or start2 > end2 then
		local status = append_suffix()
		return matches, status == "ok", status
	end

	local count1 = end1 - start1 + 1
	local count2 = end2 - start2 + 1
	if threshold_counter == 0 and not reduction_is_small(count1, count2, original_count1, original_count2) then
		return {}, false, "too_big"
	end
	threshold_counter = math.max(-1, threshold_counter - 1)

	local anchors, status = unique_anchors(values1, values2, start1, end1, start2, end2, context)
	if status ~= "ok" then
		return {}, false, status
	end
	assert(anchors, "successful unique LCS has anchors")
	if #anchors == 0 then
		if threshold_counter >= 0 and not reduction_is_small(count1, count2, original_count1, original_count2) then
			return {}, false, "too_big"
		end
		local left = {}
		local right = {}
		for index = start1, end1 do
			if timed_out(context) then
				return {}, false, "timed_out"
			end
			left[#left + 1] = values1[index]
		end
		for index = start2, end2 do
			if timed_out(context) then
				return {}, false, "timed_out"
			end
			right[#right + 1] = values2[index]
		end
		local additions
		additions, status = myers(left, right, context, false)
		if status ~= "ok" then
			return {}, false, status
		end
		status = append_matches(matches, additions, start1 - 1, start2 - 1, context)
		if status ~= "ok" then
			return {}, false, status
		end
		status = append_suffix()
		return matches, status == "ok", status
	end

	local next1 = start1
	local next2 = start2
	for _, anchor in ipairs(anchors) do
		if timed_out(context) then
			return {}, false, "timed_out"
		end
		local inner, ok
		inner, ok, status = patience_region(
			values1,
			values2,
			next1,
			anchor[1] - 1,
			next2,
			anchor[2] - 1,
			threshold_counter,
			original_count1,
			original_count2,
			context
		)
		if not ok then
			return {}, false, status
		end
		status = append_matches(matches, inner, 0, 0, context)
		if status ~= "ok" then
			return {}, false, status
		end
		matches[#matches + 1] = { anchor[1] - 1, anchor[2] - 1 }
		next1 = anchor[1] + 1
		next2 = anchor[2] + 1
	end
	local tail, ok
	tail, ok, status = patience_region(
		values1,
		values2,
		next1,
		end1,
		next2,
		end2,
		threshold_counter,
		original_count1,
		original_count2,
		context
	)
	if not ok then
		return {}, false, status
	end
	status = append_matches(matches, tail, 0, 0, context)
	if status ~= "ok" then
		return {}, false, status
	end
	status = append_suffix()
	return matches, status == "ok", status
end

local function discard_unique(values1, values2, context)
	local counts1 = {}
	local counts2 = {}
	for _, value in ipairs(values1) do
		if timed_out(context) then
			return nil, nil, nil, nil, "timed_out"
		end
		counts1[value] = (counts1[value] or 0) + 1
	end
	for _, value in ipairs(values2) do
		if timed_out(context) then
			return nil, nil, nil, nil, "timed_out"
		end
		counts2[value] = (counts2[value] or 0) + 1
	end
	local reduced1 = {}
	local reduced2 = {}
	local indexes1 = {}
	local indexes2 = {}
	for index, value in ipairs(values1) do
		if timed_out(context) then
			return nil, nil, nil, nil, "timed_out"
		end
		if counts2[value] then
			reduced1[#reduced1 + 1] = value
			indexes1[#indexes1 + 1] = index - 1
		end
	end
	for index, value in ipairs(values2) do
		if timed_out(context) then
			return nil, nil, nil, nil, "timed_out"
		end
		if counts1[value] then
			reduced2[#reduced2 + 1] = value
			indexes2[#indexes2 + 1] = index - 1
		end
	end
	return reduced1, reduced2, indexes1, indexes2, "ok"
end

---@param values1 integer[]
---@param values2 integer[]
---@param context gleb.diff.Context
---@return gleb.diff.LcsResult
function M.diff(values1, values2, context)
	local prefix = 0
	while prefix < math.min(#values1, #values2) and values1[prefix + 1] == values2[prefix + 1] do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		prefix = prefix + 1
	end
	local suffix = 0
	local remaining = math.min(#values1, #values2) - prefix
	while suffix < remaining and values1[#values1 - suffix] == values2[#values2 - suffix] do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		suffix = suffix + 1
	end

	local middle1 = {}
	local middle2 = {}
	for index = prefix + 1, #values1 - suffix do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		middle1[#middle1 + 1] = values1[index]
	end
	for index = prefix + 1, #values2 - suffix do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		middle2[#middle2 + 1] = values2[index]
	end

	local reduced1, reduced2, indexes1, indexes2, status = discard_unique(middle1, middle2, context)
	if status ~= "ok" then
		return { matches = {}, status = status }
	end
	assert(reduced1 and reduced2 and indexes1 and indexes2, "successful discard has reduced sequences")
	local matches
	matches, status = myers(reduced1, reduced2, context, true)
	if status == "timed_out" then
		return { matches = {}, status = status }
	end
	if status == "too_big" then
		local ok
		matches, ok, status =
			patience_region(reduced1, reduced2, 1, #reduced1, 1, #reduced2, 2, #reduced1, #reduced2, context)
		if not ok then
			return { matches = {}, status = status }
		end
	end
	assert(matches, "successful LCS has matches")

	local ordered = {}
	for index = 0, prefix - 1 do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		ordered[#ordered + 1] = { index, index }
	end
	for _, match in ipairs(matches) do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		local index1 = assert(indexes1[match[1] + 1], "match has a first-side index")
		local index2 = assert(indexes2[match[2] + 1], "match has a second-side index")
		ordered[#ordered + 1] = {
			index1 + prefix,
			index2 + prefix,
		}
	end
	for offset = suffix - 1, 0, -1 do
		if timed_out(context) then
			return { matches = {}, status = "timed_out" }
		end
		ordered[#ordered + 1] = {
			#values1 - offset - 1,
			#values2 - offset - 1,
		}
	end
	return { matches = ordered, status = "ok" }
end

return M
