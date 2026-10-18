-- File nesting compiles user patterns once and groups same-folder files without filesystem access.

local M = {}

---@class FileTreeNestingPatternRule
---@field parent string
---@field children string[]

---@class FileTreeCompiledNestingRule
---@field parent string
---@field capture_count integer
---@field children string[]

---@type table<table, FileTreeCompiledNestingRule[]>
local compiled_rule_sets = setmetatable({}, { __mode = "k" })

---@param pattern string
---@return string
local function whole_pattern(pattern)
	pattern = pattern:gsub("%^", "", 1)
	local percent_count = 0
	local index = #pattern - 1
	while index > 0 and pattern:sub(index, index) == "%" do
		percent_count = percent_count + 1
		index = index - 1
	end
	if pattern:sub(-1) == "$" and percent_count % 2 == 0 then
		pattern = pattern:sub(1, -2)
	end
	return "^" .. pattern .. "$"
end

---@param pattern string
---@return integer
local function capture_count(pattern)
	local count = 0
	local in_class = false
	local index = 1
	while index <= #pattern do
		local character = pattern:sub(index, index)
		if character == "%" then
			index = index + 2
		elseif character == "[" then
			in_class = true
			index = index + 1
		elseif character == "]" and in_class then
			in_class = false
			index = index + 1
		else
			if character == "(" and not in_class then
				count = count + 1
			end
			index = index + 1
		end
	end
	return count
end

---@param rule_index integer
---@param reason string
---@return nil
local function warn(rule_index, reason)
	vim.notify(("File tree nesting rule %d skipped: %s"):format(rule_index, reason), vim.log.levels.WARN)
end

---@param template string
---@return integer
local function highest_capture(template)
	local highest = template:find("${capture}", 1, true) and 1 or 0
	for capture in template:gmatch("${([1-9])}") do
		highest = math.max(highest, tonumber(capture) or 0)
	end
	return highest
end

---@param rules table[]
---@return FileTreeCompiledNestingRule[]
local function compile_rules(rules)
	local cached = compiled_rule_sets[rules]
	if cached then
		return cached
	end

	local compiled = {}
	for rule_index, rule in ipairs(rules) do
		local reason
		if type(rule.parent) ~= "string" or type(rule.children) ~= "table" then
			reason = "parent and children are required"
		else
			local parent = whole_pattern(rule.parent)
			if not pcall(string.find, "", parent) then
				reason = "malformed parent pattern"
			else
				local captures = capture_count(rule.parent)
				local children = {}
				for _, child in ipairs(rule.children) do
					if type(child) ~= "string" then
						reason = "children must be strings"
						break
					elseif highest_capture(child) > captures then
						reason = "child references a missing capture"
						break
					elseif not pcall(string.find, "", whole_pattern(child)) then
						reason = "malformed child pattern"
						break
					end
					children[#children + 1] = child
				end
				if not reason then
					compiled[#compiled + 1] = { parent = parent, capture_count = captures, children = children }
				end
			end
		end
		if reason then
			warn(rule_index, reason)
		end
	end
	compiled_rule_sets[rules] = compiled
	return compiled
end

---@param template string
---@param captures string[]
---@return string
local function substitute(template, captures)
	template = template:gsub("${capture}", function()
		return vim.pesc(tostring(captures[1]))
	end)
	local substituted = template:gsub("${([1-9])}", function(index)
		return vim.pesc(tostring(captures[tonumber(index)]))
	end)
	return substituted
end

---@param left string
---@param right string
---@return boolean
local function name_before(left, right)
	local left_folded = left:lower()
	local right_folded = right:lower()
	if left_folded ~= right_folded then
		return left_folded < right_folded
	end
	return left < right
end

--- Group files under parents selected by pattern rules.
---@param _dir string
---@param entries FileTreeEntry[]
---@param rules table[]
---@return table<string, string[]>
function M.nest(_dir, entries, rules)
	local names = {}
	for _, entry in ipairs(entries) do
		if entry.kind == "file" then
			names[#names + 1] = entry.name
		end
	end

	local result = {}
	for _, rule in ipairs(compile_rules(rules)) do
		for _, parent in ipairs(names) do
			local captures = { parent:match(rule.parent) }
			if captures[1] then
				local children = result[parent] or {}
				local included = {}
				for _, child in ipairs(children) do
					included[child] = true
				end
				for _, template in ipairs(rule.children) do
					local child_pattern = whole_pattern(substitute(template, captures))
					for _, child in ipairs(names) do
						if child ~= parent and not included[child] and child:match(child_pattern) then
							children[#children + 1] = child
							included[child] = true
						end
					end
				end
				if #children > 0 then
					table.sort(children, name_before)
					result[parent] = children
				end
			end
		end
	end
	return result
end

return M
