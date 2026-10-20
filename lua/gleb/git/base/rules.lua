local M = {}

---@param origin_head? string
---@param refs table<string, string>
---@return string?
function M.default_branch(origin_head, refs)
	if origin_head then
		return origin_head:match("^origin/(.+)$")
	end
	if refs["origin/main"] then
		return "main"
	end
	if refs["origin/master"] then
		return "master"
	end
end

---@param url string
---@return string?
function M.remote_host(url)
	local scp_host = url:match("^[^/@]+@([^:/]+):")
	if scp_host then
		return scp_host
	end
	local scheme, authority = url:match("^(%a[%w+.-]*)://([^/]*)")
	if not scheme or scheme == "file" or authority == "" then
		return nil
	end
	authority = authority:gsub("^.*@", "")
	return authority:match("^([^:]+)")
end

---@param branch? string
---@param head? string
---@param default? string
---@return string?
function M.skip_reason(branch, head, default)
	if not branch then
		return "detached"
	end
	if not head then
		return "unborn"
	end
	if not default then
		return "no default"
	end
	if branch == default or branch == "main" or branch == "master" then
		return "default branch"
	end
end

---@class gleb.git.base.PrOutcome
---@field kind "open"|"none"|"failed"
---@field pr? gleb.git.base.Pr

---@param code integer
---@param stdout string
---@param stderr string
---@return gleb.git.base.PrOutcome
function M.pr_outcome(code, stdout, stderr)
	if code ~= 0 then
		if stderr:lower():find("no pull requests found", 1, true) then
			return { kind = "none" }
		end
		return { kind = "failed" }
	end
	local ok, value = pcall(vim.json.decode, stdout)
	if not ok or type(value) ~= "table" or value.state ~= "OPEN" or not value.number or not value.baseRefName then
		return { kind = "none" }
	end
	return {
		kind = "open",
		pr = {
			number = value.number,
			url = value.url,
			base_ref_name = value.baseRefName,
			base_ref_oid = value.baseRefOid,
			head_ref_name = value.headRefName,
			head_ref_oid = value.headRefOid,
		},
	}
end

return M
