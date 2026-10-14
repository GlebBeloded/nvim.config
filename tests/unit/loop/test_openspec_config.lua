local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

-- Ruby's stdlib YAML (Psych) ships with macOS; like openspec's parser it reads `- Key: text` as a mapping.
local LOAD = 'puts JSON.generate(YAML.safe_load(File.read(ARGV[0]))["rules"])'

--- `rules.<section>[<index>]` of every entry that is not a plain string.
---@param rules table<string, any[]>
---@return string[]
local function non_strings(rules)
	local bad = {}
	for section, entries in pairs(rules) do
		for index, entry in ipairs(entries) do
			if type(entry) ~= "string" then
				table.insert(bad, ("rules.%s[%d]: %s"):format(section, index, vim.inspect(entry)))
			end
		end
	end
	return bad
end

T["loop: OpenSpec config rules are plain strings"] = function()
	local config = vim.fs.joinpath(H.root, "openspec/config.yaml")
	local result = H.system(child, { "ruby", "-ryaml", "-rjson", "-e", LOAD, config }, H.root)
	eq(result.code, 0, { fail_reason = result.stderr })
	local rules = vim.json.decode(result.stdout)
	eq(vim.tbl_count(rules) > 0, true)
	eq(non_strings(rules), {})
end

return T
