local MiniTest = require("mini.test")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality

local threads = require("gleb.pr.threads")

local manifest = {
	head = "e325463",
	merge_base = "4ccefde",
	commits = { "e325463", "07cb52e", "b5435c5" },
}

---@return table[] nodes
local function pr482_nodes()
	local response = vim.json.decode(pr482(manifest)["ReviewThreads.json"])
	return response.data.repository.pullRequest.reviewThreads.nodes
end

local T = MiniTest.new_set()

T["pr: PR thread model keeps the GraphQL fields"] = MiniTest.new_set()

T["pr: PR thread model keeps the GraphQL fields"]["normalizes threads and comments"] = function()
	local nodes = pr482_nodes()
	local parsed = threads.parse(nodes)

	eq(parsed[1], {
		id = "PRRT_t1",
		path = "internal/billing/invoice.go",
		side = "RIGHT",
		line = 22,
		original_line = 22,
		original_commit = "e325463",
		resolved = false,
		outdated = false,
		subject = "line",
		can_reply = true,
		can_resolve = true,
		can_unresolve = false,
		comments = {
			{
				id = "PRRRC_c1",
				author = "maria.k",
				body = "Should a nil rate mean no tax at all?\nA missing config would silently drop tax.",
				created_at = "2026-01-01T23:00:00Z",
				url = "https://pgw.dev/finteqhub/billing/pull/482#discussion_r1",
				diff_hunk = nodes[1].comments.nodes[1].diffHunk,
			},
			{
				id = "PRRRC_c2",
				author = "gleb-beloded",
				body = "Good catch, defaulting to Rate(0) and\nlogging a warning.",
				created_at = "2026-01-02T00:00:00Z",
				url = "https://pgw.dev/finteqhub/billing/pull/482#discussion_r2",
				diff_hunk = nodes[1].comments.nodes[2].diffHunk,
				reply_to = "PRRRC_c1",
			},
		},
	})
	eq({
		parsed[3].line,
		parsed[3].original_line,
		parsed[3].original_commit,
		parsed[3].outdated,
	}, { nil, 18, "b5435c5", true })
	eq({ parsed[4].resolved, parsed[4].resolved_by }, { true, "gleb-beloded" })
end

T["pr: PR thread author falls back to ghost"] = MiniTest.new_set()

T["pr: PR thread author falls back to ghost"]["normalizes a deleted account"] = function()
	local nodes = pr482_nodes()
	nodes[1].comments.nodes[1].author = vim.NIL

	eq(threads.parse(nodes)[1].comments[1].author, "ghost")
end

T["pr: Open PR threads are counted"] = MiniTest.new_set()

T["pr: Open PR threads are counted"]["excludes resolved threads"] = function()
	eq(threads.open_count(threads.parse(pr482_nodes())), 3)
end

T["pr: Thread line shifts below inserted lines"] = MiniTest.new_set()

T["pr: Thread line shifts below inserted lines"]["maps every source line"] = function()
	local cases = {
		{ line = 1, want = 1 },
		{ line = 2, want = 4 },
		{ line = 3, want = 5 },
		{ line = 4, want = 6 },
	}
	for _, case in ipairs(cases) do
		eq(threads.map_line({ "a", "b", "c", "d" }, { "a", "x", "y", "b", "c", "d" }, case.line), case.want)
	end
end

T["pr: Thread line inside a replaced block keeps its offset"] = MiniTest.new_set()

T["pr: Thread line inside a replaced block keeps its offset"]["caps the replaced offset at the last new line"] = function()
	local cases = {
		{ line = 1, want = 1 },
		{ line = 2, want = 2 },
		{ line = 3, want = 3 },
		{ line = 4, want = 3 },
		{ line = 5, want = 4 },
	}
	for _, case in ipairs(cases) do
		eq(threads.map_line({ "a", "b", "c", "d", "e" }, { "a", "B", "C", "e" }, case.line), case.want)
	end
end

T["pr: Thread line on a removed line is unmapped"] = MiniTest.new_set()

T["pr: Thread line on a removed line is unmapped"]["returns nil only for the deleted line"] = function()
	local cases = {
		{ line = 1, want = 1 },
		{ line = 2 },
		{ line = 3, want = 2 },
	}
	for _, case in ipairs(cases) do
		eq(threads.map_line({ "a", "b", "c" }, { "a", "c" }, case.line), case.want)
	end
end

return T
