-- Branch file URLs normalize Git remotes and encode ref and path bytes while preserving their segment separators.

local M = {}

---@param value string
---@return string
local function encode_segments(value)
	return (value:gsub("[^%w%-%._~/]", function(byte)
		return ("%%%02X"):format(string.byte(byte))
	end))
end

---@param remote string
---@return string?
local function repository_url(remote)
	local host, path = remote:match("^https?://([^/]+)/(.+)$")
	if not host then
		host, path = remote:match("^ssh://[^@/]+@([^/:]+):?%d*/(.+)$")
	end
	if not host then
		host, path = remote:match("^ssh://([^/:]+):?%d*/(.+)$")
	end
	if not host then
		host, path = remote:match("^[^@:/]+@([^:]+):(.+)$")
	end
	if not host or not path then
		return nil
	end
	path = path:gsub("%.git/?$", ""):gsub("/+$", "")
	return ("https://%s/%s"):format(host, encode_segments(path))
end

---@param remote string
---@param ref string
---@param path string
---@param first_line integer
---@param last_line integer
---@return string?
function M.build(remote, ref, path, first_line, last_line)
	local repository = repository_url(remote)
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
