-- Branch file URLs normalize Git remotes and encode ref and path bytes while preserving their segment separators.

local rules = require("gleb.git.base.rules")

local M = {}

---@param value string
---@return string
local function encode_segments(value)
	return (value:gsub("[^%w%-%._~/]", function(byte)
		return ("%%%02X"):format(string.byte(byte))
	end))
end

---@param remote string
---@param ref string
---@param path string
---@param first_line integer
---@param last_line integer
---@return string?
function M.build(remote, ref, path, first_line, last_line)
	local repository = rules.remote_web_base(remote)
	if not repository then
		return nil
	end
	local fragment = ("#L%d"):format(first_line)
	if last_line ~= first_line then
		fragment = ("%s-L%d"):format(fragment, last_line)
	end
	return ("%s/blob/%s/%s%s"):format(repository, encode_segments(ref), encode_segments(path), fragment)
end

return M
