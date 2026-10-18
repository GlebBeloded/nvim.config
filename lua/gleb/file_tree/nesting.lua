-- File nesting compiles user patterns once and groups same-folder files without filesystem access.

local M = {}

---@class FileTreeNestingPatternRule
---@field parent string
---@field children string[]

---@class FileTreeCompiledNestingRule
---@field parent? string
---@field capture_count? integer
---@field children? string[]
---@field lua? fun(dir: string, names: string[]): table<string, string[]>
---@field rule_index? integer
---@field failed? boolean

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
		if type(rule.lua) == "function" then
			compiled[#compiled + 1] = { lua = rule.lua, rule_index = rule_index }
		elseif type(rule.lua) == "string" then
			local loaded, module = pcall(require, rule.lua)
			if not loaded then
				reason = tostring(module)
			elseif type(module) ~= "function" then
				reason = "Lua module must return a function"
			else
				compiled[#compiled + 1] = { lua = module, rule_index = rule_index }
			end
		elseif type(rule.parent) ~= "string" or type(rule.children) ~= "table" then
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

---@param rule FileTreeCompiledNestingRule
---@param dir string
---@param names string[]
---@return table<string, string[]>?
local function call_lua_rule(rule, dir, names)
	if rule.failed then
		return nil
	end
	local ok, proposed = pcall(rule.lua, dir, names)
	local reason
	if not ok then
		reason = tostring(proposed)
	elseif type(proposed) ~= "table" then
		reason = "Lua rule must return a table"
	else
		for parent, children in pairs(proposed) do
			if type(parent) ~= "string" or type(children) ~= "table" then
				reason = "Lua rule names must be strings"
				break
			end
			for _, child in ipairs(children) do
				if type(child) ~= "string" then
					reason = "Lua rule names must be strings"
					break
				end
			end
			if reason then
				break
			end
		end
	end
	if reason then
		rule.failed = true
		warn(rule.rule_index, reason)
		return nil
	end
	return proposed
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

---@param pattern string
---@return string?
local function literal_pattern(pattern)
	local literal = {}
	local index = 1
	while index <= #pattern do
		local character = pattern:sub(index, index)
		if character == "%" then
			local escaped = pattern:sub(index + 1, index + 1)
			if escaped == "" or escaped:match("%w") then
				return nil
			end
			literal[#literal + 1] = escaped
			index = index + 2
		elseif character:find("[().%[%]*+%-?^$]") then
			return nil
		else
			literal[#literal + 1] = character
			index = index + 1
		end
	end
	return table.concat(literal)
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

---@param parent_of table<string, string>
---@param parent string
---@param child string
---@return boolean
local function makes_cycle(parent_of, parent, child)
	local ancestor = parent
	while ancestor do
		if ancestor == child then
			return true
		end
		ancestor = parent_of[ancestor]
	end
	return false
end

---@param parent_of table<string, string>
---@param name string
---@return string
local function top_parent(parent_of, name)
	local parent = parent_of[name]
	while parent_of[parent] do
		parent = parent_of[parent]
	end
	return parent
end

--- Group files under parents selected by pattern rules.
---@param _dir string
---@param entries FileTreeEntry[]
---@param rules table[]
---@return table<string, string[]>
function M.nest(_dir, entries, rules)
	local names = {}
	local name_set = {}
	for _, entry in ipairs(entries) do
		if entry.kind == "file" then
			names[#names + 1] = entry.name
			name_set[entry.name] = true
		end
	end
	table.sort(names, name_before)

	local parent_of = {}
	local function claim(parent, child)
		if
			name_set[parent]
			and name_set[child]
			and not parent_of[child]
			and not makes_cycle(parent_of, parent, child)
		then
			parent_of[child] = parent
		end
	end
	for _, rule in ipairs(compile_rules(rules)) do
		if rule.lua then
			local proposed = call_lua_rule(rule, _dir, names)
			if proposed then
				local parents = vim.tbl_keys(proposed)
				table.sort(parents, name_before)
				for _, parent in ipairs(parents) do
					for _, child in ipairs(proposed[parent]) do
						claim(parent, child)
					end
				end
			end
		else
			for _, parent in ipairs(names) do
				local captures = { parent:match(rule.parent) }
				if captures[1] then
					for _, template in ipairs(rule.children) do
						local substituted = substitute(template, captures)
						local literal = literal_pattern(substituted)
						if literal then
							claim(parent, literal)
						else
							local child_pattern = whole_pattern(substituted)
							for _, child in ipairs(names) do
								if child:match(child_pattern) then
									claim(parent, child)
								end
							end
						end
					end
				end
			end
		end
	end

	local result = {}
	for child in pairs(parent_of) do
		local parent = top_parent(parent_of, child)
		result[parent] = result[parent] or {}
		result[parent][#result[parent] + 1] = child
	end
	for _, children in pairs(result) do
		table.sort(children, name_before)
	end
	return result
end

return M
