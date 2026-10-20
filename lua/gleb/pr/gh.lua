-- GitHub review-thread transport: keeps GraphQL details and process execution out of the PR cache.
local M = {}

M.REVIEW_THREADS_QUERY =
	"query ReviewThreads($owner:String!,$name:String!,$number:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first: 100,after:$cursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated path line originalLine startLine originalStartLine diffSide subjectType resolvedBy{login} viewerCanReply viewerCanResolve viewerCanUnresolve comments(first: 100){pageInfo{hasNextPage endCursor} nodes{id author{login} body createdAt url diffHunk originalCommit{oid} replyTo{id}}}}}}}}"
M.THREAD_COMMENTS_QUERY =
	"query ThreadComments($id:ID!,$cursor:String){node(id:$id){... on PullRequestReviewThread{comments(first: 100,after:$cursor){pageInfo{hasNextPage endCursor} nodes{id author{login} body createdAt url diffHunk originalCommit{oid} replyTo{id}}}}}}"

---@alias gleb.pr.Runner fun(argv: string[], opts: table, callback: fun(result: vim.SystemCompleted))

---@param argv string[]
---@param opts table
---@param callback fun(result: vim.SystemCompleted)
local function system_runner(argv, opts, callback)
	vim.system(argv, opts, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

---@param review gleb.pr.Review
---@param cursor? string
---@return string[]
local function review_threads_argv(review, cursor)
	local argv = {
		"gh",
		"api",
		"graphql",
		"-f",
		"query=" .. M.REVIEW_THREADS_QUERY,
		"-f",
		"owner=" .. review.owner,
		"-f",
		"name=" .. review.name,
		"-F",
		"number=" .. review.pr.number,
	}
	if cursor then
		vim.list_extend(argv, { "-f", "cursor=" .. cursor })
	end
	return argv
end

---@param id string
---@param cursor string
---@return string[]
local function thread_comments_argv(id, cursor)
	return {
		"gh",
		"api",
		"graphql",
		"-f",
		"query=" .. M.THREAD_COMMENTS_QUERY,
		"-f",
		"id=" .. id,
		"-f",
		"cursor=" .. cursor,
	}
end

---@param review gleb.pr.Review
---@return table
local function request_opts(review)
	return {
		text = true,
		timeout = review.timeout,
		env = {
			GH_HOST = review.host,
			GH_PROMPT_DISABLED = "1",
			GH_NO_UPDATE_NOTIFIER = "1",
			NO_COLOR = "1",
		},
	}
end

---@param review gleb.pr.Review
---@param run? gleb.pr.Runner
---@param callback fun(threads?: table[], result?: vim.SystemCompleted)
---@return nil
function M.fetch_threads(review, run, callback)
	run = run or system_runner
	local threads = {}

	---@param index integer
	local function fetch_thread_comments(index)
		local thread = threads[index]
		if not thread then
			callback(threads)
			return
		end
		local comments = thread.comments
		if not comments or not comments.pageInfo or not comments.pageInfo.hasNextPage then
			fetch_thread_comments(index + 1)
			return
		end

		local function fetch_comment_page()
			run(thread_comments_argv(thread.id, comments.pageInfo.endCursor), request_opts(review), function(result)
				if result.code ~= 0 then
					callback(nil, result)
					return
				end
				local ok, response = pcall(vim.json.decode, result.stdout or "")
				local page = ok and response.data and response.data.node and response.data.node.comments
				if not page then
					callback(nil, result)
					return
				end
				vim.list_extend(comments.nodes, page.nodes or {})
				comments.pageInfo = page.pageInfo
				if comments.pageInfo.hasNextPage then
					fetch_comment_page()
				else
					fetch_thread_comments(index + 1)
				end
			end)
		end

		fetch_comment_page()
	end

	---@param cursor? string
	local function fetch_thread_page(cursor)
		run(review_threads_argv(review, cursor), request_opts(review), function(result)
			if result.code ~= 0 then
				callback(nil, result)
				return
			end
			local ok, response = pcall(vim.json.decode, result.stdout or "")
			local connection = ok
				and response.data
				and response.data.repository
				and response.data.repository.pullRequest
				and response.data.repository.pullRequest.reviewThreads
			if not connection then
				callback(nil, result)
				return
			end
			vim.list_extend(threads, connection.nodes or {})
			if connection.pageInfo.hasNextPage then
				fetch_thread_page(connection.pageInfo.endCursor)
			else
				fetch_thread_comments(1)
			end
		end)
	end

	fetch_thread_page()
end

return M
