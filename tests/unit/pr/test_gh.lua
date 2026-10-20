local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local gh = require("gleb.pr.gh")

local review = {
	host = "pgw.dev",
	owner = "finteqhub",
	name = "billing",
	pr = { number = 482 },
	timeout = 20000,
}

---@param nodes table[]
---@param has_next boolean
---@param cursor? string
---@return string
local function threads_page(nodes, has_next, cursor)
	return vim.json.encode({
		data = {
			repository = {
				pullRequest = {
					reviewThreads = {
						pageInfo = { hasNextPage = has_next, endCursor = cursor },
						nodes = nodes,
					},
				},
			},
		},
	})
end

---@param nodes table[]
---@param has_next boolean
---@param cursor? string
---@return string
local function comments_page(nodes, has_next, cursor)
	return vim.json.encode({
		data = {
			node = {
				comments = {
					pageInfo = { hasNextPage = has_next, endCursor = cursor },
					nodes = nodes,
				},
			},
		},
	})
end

---@param argv string[]
---@param value string
---@return boolean
local function has_argument(argv, value)
	return vim.tbl_contains(argv, value)
end

local T = MiniTest.new_set()

T["pr: PR thread pages follow the end cursor"] = MiniTest.new_set()

T["pr: PR thread pages follow the end cursor"]["returns every thread page in order"] = function()
	local calls = {}
	local responses = {
		threads_page({ { id = "PRRT_t1" }, { id = "PRRT_t2" } }, true, "c2"),
		threads_page({ { id = "PRRT_t3" }, { id = "PRRT_t4" } }, false),
	}
	local result
	local function run(argv, _, callback)
		table.insert(calls, argv)
		callback({ code = 0, stdout = responses[#calls], stderr = "" })
	end

	gh.fetch_threads(review, run, function(threads)
		result = threads
	end)

	eq(
		vim.tbl_map(function(thread)
			return thread.id
		end, result),
		{ "PRRT_t1", "PRRT_t2", "PRRT_t3", "PRRT_t4" }
	)
	eq(#calls, 2)
	eq(has_argument(calls[1], "cursor=c2"), false)
	eq(has_argument(calls[2], "cursor=c2"), true)
end

T["pr: Long PR threads load every comment"] = MiniTest.new_set()

T["pr: Long PR threads load every comment"]["appends comment pages in order"] = function()
	local calls = {}
	local responses = {
		threads_page({
			{
				id = "PRRT_t1",
				comments = {
					pageInfo = { hasNextPage = true, endCursor = "k1" },
					nodes = { { id = "PRRRC_c1" } },
				},
			},
		}, false),
		comments_page({ { id = "PRRRC_c2" } }, false),
	}
	local result
	local function run(argv, _, callback)
		table.insert(calls, argv)
		callback({ code = 0, stdout = responses[#calls], stderr = "" })
	end

	gh.fetch_threads(review, run, function(threads)
		result = threads
	end)

	eq(
		vim.tbl_map(function(comment)
			return comment.id
		end, result[1].comments.nodes),
		{ "PRRRC_c1", "PRRRC_c2" }
	)
	eq(#calls, 2)
	eq(has_argument(calls[2], "query=" .. gh.THREAD_COMMENTS_QUERY), true)
	eq(has_argument(calls[2], "id=PRRT_t1"), true)
	eq(has_argument(calls[2], "cursor=k1"), true)
end

T["pr: PR fetch failures are classified"] = MiniTest.new_set()

T["pr: PR fetch failures are classified"]["maps process and GraphQL failures to short messages"] = function()
	eq(type(gh.failure), "function")
	local executable = vim.fn.executable
	local cases = {
		{
			executable = 0,
			result = { code = 1, stdout = "", stderr = "" },
			kind = "missing",
			message = "PR comments unavailable: gh not found",
		},
		{
			result = {
				code = 4,
				stdout = "",
				stderr = "To get started with GitHub CLI, please run:  gh auth login\n",
			},
			kind = "auth",
			message = "PR comments unavailable: gh is not authenticated for pgw.dev",
		},
		{
			result = {
				code = 1,
				stdout = "",
				stderr = "HTTP 401: Bad credentials (https://pgw.dev/api/graphql)\n",
			},
			kind = "auth",
			message = "PR comments unavailable: gh is not authenticated for pgw.dev",
		},
		{
			result = {
				code = 1,
				stdout = "",
				stderr = "error connecting to pgw.dev\nconnection refused\n",
			},
			kind = "failed",
			message = "PR comments unavailable: error connecting to pgw.dev",
		},
		{
			result = {
				code = 0,
				stdout = vim.json.encode({
					errors = { { message = "Could not resolve to a PullRequest with the number of 482." } },
				}),
				stderr = "",
			},
			kind = "graphql",
			message = "PR comments unavailable: Could not resolve to a PullRequest with the number of 482.",
		},
	}

	for _, case in ipairs(cases) do
		rawset(vim.fn, "executable", function(command)
			return command == "gh" and (case.executable or 1) or executable(command)
		end)
		local failure = gh.failure(case.result, "pgw.dev")
		eq({ failure.kind, failure.message }, { case.kind, case.message })
	end
	rawset(vim.fn, "executable", executable)
end

return T
