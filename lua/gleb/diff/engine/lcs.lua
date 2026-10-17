-- Integer longest-common-subsequence engine used by line comparison.
-- Myers handles ordinary inputs; unique anchors bound difficult comparisons.

local M = {}

---@alias gleb.diff.LcsStatus "ok"|"too_big"|"timed_out"

---@class gleb.diff.LcsResult
---@field matches gleb.diff.Match[]
---@field status gleb.diff.LcsStatus

local function copy_vector(vector)
	local copy = {}
	for diagonal, value in pairs(vector) do
		copy[diagonal] = value
	end
	return copy
end

local function backtrack(trace, distance, length1, length2)
	local matches = {}
	local x = length1
	local y = length2
	for d = distance, 1, -1 do
		local vector = trace[d]
		local diagonal = x - y
		local previous_diagonal
		if diagonal == -d or (diagonal ~= d and (vector[diagonal - 1] or -1) < (vector[diagonal + 1] or -1)) then
			previous_diagonal = diagonal + 1
		else
			previous_diagonal = diagonal - 1
		end
		local previous_x = vector[previous_diagonal] or 0
		local previous_y = previous_x - previous_diagonal
		while x > previous_x and y > previous_y do
			table.insert(matches, 1, { x - 1, y - 1 })
			x = x - 1
			y = y - 1
		end
		x = previous_x
		y = previous_y
	end
	while x > 0 and y > 0 do
		table.insert(matches, 1, { x - 1, y - 1 })
		x = x - 1
		y = y - 1
	end
	return matches
end

local function timed_out(context)
	return context.clock() > context.deadline
end

local function myers(values1, values2, context, bounded)
	local length1 = #values1
	local length2 = #values2
	local vector = { [1] = 0 }
	local trace = {}
	for distance = 0, length1 + length2 do
		if timed_out(context) then
			return nil, "timed_out"
		end
		if bounded and distance > context.myers_threshold then
			return nil, "too_big"
		end
		trace[distance] = copy_vector(vector)
		for diagonal = -distance, distance, 2 do
			local x
			if
				diagonal == -distance
				or (diagonal ~= distance and (vector[diagonal - 1] or -1) < (vector[diagonal + 1] or -1))
			then
				x = vector[diagonal + 1] or 0
			else
				x = (vector[diagonal - 1] or 0) + 1
			end
			local y = x - diagonal
			while x < length1 and y < length2 and values1[x + 1] == values2[y + 1] do
				x = x + 1
				y = y + 1
			end
			vector[diagonal] = x
			if x >= length1 and y >= length2 then
				return backtrack(trace, distance, length1, length2), "ok"
			end
		end
	end
	return {}, "ok"
end

local function unique_anchors(values1, values2, start1, end1, start2, end2)
	local counts1 = {}
	local counts2 = {}
	local positions2 = {}
	for index = start1, end1 do
		local value = values1[index]
		counts1[value] = (counts1[value] or 0) + 1
	end
	for index = start2, end2 do
		local value = values2[index]
		counts2[value] = (counts2[value] or 0) + 1
		positions2[value] = index
	end

	local candidates = {}
	for index = start1, end1 do
		local value = values1[index]
		if counts1[value] == 1 and counts2[value] == 1 then
			table.insert(candidates, { index, positions2[value] })
		end
	end

	local tails = {}
	local previous = {}
	for candidate_index, candidate in ipairs(candidates) do
		local low = 1
		local high = #tails
		while low <= high do
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

	local anchors = {}
	local cursor = tails[#tails]
	while cursor do
		table.insert(anchors, 1, candidates[cursor])
		cursor = previous[cursor]
	end
	return anchors
end

local function append_offset(matches, additions, offset1, offset2)
	for _, match in ipairs(additions) do
		table.insert(matches, { match[1] + offset1, match[2] + offset2 })
	end
end

local function patience_region(values1, values2, start1, end1, start2, end2, may_fail, context)
	if timed_out(context) then
		return {}, false, "timed_out"
	end
	local matches = {}
	while start1 <= end1 and start2 <= end2 and values1[start1] == values2[start2] do
		table.insert(matches, { start1 - 1, start2 - 1 })
		start1 = start1 + 1
		start2 = start2 + 1
	end
	local suffix = {}
	while start1 <= end1 and start2 <= end2 and values1[end1] == values2[end2] do
		table.insert(suffix, 1, { end1 - 1, end2 - 1 })
		end1 = end1 - 1
		end2 = end2 - 1
	end
	if start1 > end1 or start2 > end2 then
		vim.list_extend(matches, suffix)
		return matches, true, "ok"
	end

	local anchors = unique_anchors(values1, values2, start1, end1, start2, end2)
	if #anchors == 0 then
		if may_fail then
			return {}, false, "too_big"
		end
		local left = {}
		local right = {}
		for index = start1, end1 do
			table.insert(left, values1[index])
		end
		for index = start2, end2 do
			table.insert(right, values2[index])
		end
		local additions, status = myers(left, right, context, false)
		if status ~= "ok" then
			return {}, false, status
		end
		append_offset(matches, additions, start1 - 1, start2 - 1)
		vim.list_extend(matches, suffix)
		return matches, true, "ok"
	end

	local next1 = start1
	local next2 = start2
	for _, anchor in ipairs(anchors) do
		local gap1 = anchor[1] - next1
		local gap2 = anchor[2] - next2
		local reduced = gap1 * 2 < (end1 - start1 + 1) or gap2 * 2 < (end2 - start2 + 1)
		local inner, ok, status = patience_region(
			values1,
			values2,
			next1,
			anchor[1] - 1,
			next2,
			anchor[2] - 1,
			may_fail and not reduced,
			context
		)
		if not ok then
			return {}, false, status
		end
		vim.list_extend(matches, inner)
		table.insert(matches, { anchor[1] - 1, anchor[2] - 1 })
		next1 = anchor[1] + 1
		next2 = anchor[2] + 1
	end
	local tail, ok, status = patience_region(values1, values2, next1, end1, next2, end2, false, context)
	if not ok then
		return {}, false, status
	end
	vim.list_extend(matches, tail)
	vim.list_extend(matches, suffix)
	return matches, true, "ok"
end

local function discard_unique(values1, values2)
	local counts1 = {}
	local counts2 = {}
	for _, value in ipairs(values1) do
		counts1[value] = (counts1[value] or 0) + 1
	end
	for _, value in ipairs(values2) do
		counts2[value] = (counts2[value] or 0) + 1
	end
	local reduced1 = {}
	local reduced2 = {}
	local indexes1 = {}
	local indexes2 = {}
	for index, value in ipairs(values1) do
		if counts2[value] then
			table.insert(reduced1, value)
			table.insert(indexes1, index - 1)
		end
	end
	for index, value in ipairs(values2) do
		if counts1[value] then
			table.insert(reduced2, value)
			table.insert(indexes2, index - 1)
		end
	end
	return reduced1, reduced2, indexes1, indexes2
end

---@param values1 integer[]
---@param values2 integer[]
---@param context gleb.diff.Context
---@return gleb.diff.LcsResult
function M.diff(values1, values2, context)
	local prefix = 0
	while prefix < math.min(#values1, #values2) and values1[prefix + 1] == values2[prefix + 1] do
		prefix = prefix + 1
	end
	local suffix = 0
	local remaining = math.min(#values1, #values2) - prefix
	while suffix < remaining and values1[#values1 - suffix] == values2[#values2 - suffix] do
		suffix = suffix + 1
	end

	local middle1 = {}
	local middle2 = {}
	for index = prefix + 1, #values1 - suffix do
		middle1[#middle1 + 1] = values1[index]
	end
	for index = prefix + 1, #values2 - suffix do
		middle2[#middle2 + 1] = values2[index]
	end

	local reduced1, reduced2, indexes1, indexes2 = discard_unique(middle1, middle2)
	local matches, status = myers(reduced1, reduced2, context, true)
	if status == "timed_out" then
		return { matches = {}, status = status }
	end
	if status == "too_big" then
		local ok
		matches, ok, status = patience_region(reduced1, reduced2, 1, #reduced1, 1, #reduced2, true, context)
		if not ok then
			return { matches = {}, status = status }
		end
	end
	assert(matches, "successful LCS has matches")
	for _, match in ipairs(matches) do
		match[1] = indexes1[match[1] + 1] + prefix
		match[2] = indexes2[match[2] + 1] + prefix
	end
	for index = prefix - 1, 0, -1 do
		table.insert(matches, 1, { index, index })
	end
	for offset = suffix - 1, 0, -1 do
		table.insert(matches, {
			#values1 - offset - 1,
			#values2 - offset - 1,
		})
	end
	return { matches = matches, status = "ok" }
end

return M
