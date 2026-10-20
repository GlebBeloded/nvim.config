-- Pull-request thread model: normalizes GraphQL names and nulls for UI-independent consumers.
local M = {}

---@class gleb.pr.Comment
---@field id string
---@field author string
---@field body string
---@field created_at string
---@field url string
---@field diff_hunk string
---@field reply_to? string

---@class gleb.pr.Thread
---@field id string
---@field path string
---@field side "RIGHT"|"LEFT"
---@field line? integer
---@field start_line? integer
---@field original_line? integer
---@field original_commit? string
---@field resolved boolean
---@field outdated boolean
---@field subject "line"|"file"
---@field resolved_by? string
---@field can_reply boolean
---@field can_resolve boolean
---@field can_unresolve boolean
---@field comments gleb.pr.Comment[]

---@generic T
---@param value T
---@return T?
local function nullable(value)
	if value == vim.NIL then
		return nil
	end
	return value
end

---@param node table
---@return gleb.pr.Comment
local function parse_comment(node)
	local author = nullable(node.author)
	local reply_to = nullable(node.replyTo)
	return {
		id = node.id,
		author = author and author.login or "ghost",
		body = node.body,
		created_at = node.createdAt,
		url = node.url,
		diff_hunk = node.diffHunk,
		reply_to = reply_to and reply_to.id or nil,
	}
end

---@param node table
---@return gleb.pr.Thread
local function parse_thread(node)
	local comments = vim.tbl_map(parse_comment, node.comments.nodes)
	local first_comment = comments[1] and node.comments.nodes[1] or nil
	local original_commit = first_comment and nullable(first_comment.originalCommit) or nil
	local resolved_by = nullable(node.resolvedBy)
	return {
		id = node.id,
		path = node.path,
		side = node.diffSide,
		line = nullable(node.line),
		start_line = nullable(node.startLine),
		original_line = nullable(node.originalLine),
		original_commit = original_commit and original_commit.oid or nil,
		resolved = node.isResolved,
		outdated = node.isOutdated,
		subject = node.subjectType == "FILE" and "file" or "line",
		resolved_by = resolved_by and resolved_by.login or nil,
		can_reply = node.viewerCanReply,
		can_resolve = node.viewerCanResolve,
		can_unresolve = node.viewerCanUnresolve,
		comments = comments,
	}
end

---@param nodes table[]
---@return gleb.pr.Thread[]
function M.parse(nodes)
	return vim.tbl_map(parse_thread, nodes)
end

---@param threads gleb.pr.Thread[]
---@return integer
function M.open_count(threads)
	local count = 0
	for _, thread in ipairs(threads) do
		if not thread.resolved then
			count = count + 1
		end
	end
	return count
end

return M
