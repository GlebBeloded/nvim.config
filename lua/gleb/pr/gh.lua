-- GitHub review-thread transport: keeps GraphQL details and process execution out of the PR cache.
local M = {}

M.REVIEW_THREADS_QUERY =
	"query ReviewThreads($owner:String!,$name:String!,$number:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first: 100,after:$cursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated path line originalLine startLine originalStartLine diffSide subjectType resolvedBy{login} viewerCanReply viewerCanResolve viewerCanUnresolve comments(first: 100){pageInfo{hasNextPage endCursor} nodes{id author{login} body createdAt url diffHunk originalCommit{oid} replyTo{id}}}}}}}}"

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
---@return string[]
local function review_threads_argv(review)
	return {
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
end

---@param review gleb.pr.Review
---@param run? gleb.pr.Runner
---@param callback fun(threads?: table[], result?: vim.SystemCompleted)
---@return nil
function M.fetch_threads(review, run, callback)
	run = run or system_runner
	run(review_threads_argv(review), {
		text = true,
		timeout = review.timeout,
		env = {
			GH_HOST = review.host,
			GH_PROMPT_DISABLED = "1",
			GH_NO_UPDATE_NOTIFIER = "1",
			NO_COLOR = "1",
		},
	}, function(result)
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
		callback(connection.nodes or {})
	end)
end

return M
