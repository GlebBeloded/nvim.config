---@param manifest fixtures.Manifest
---@return table<string, string>
return function(manifest)
	local invoice_hunk_lines = {
		"@@ -1,28 +1,37 @@",
		" package billing",
		" ",
		" import (",
		' \t"fmt"',
		" ",
		' \t"example.com/billing/internal/money"',
		" )",
		" ",
		"-// Invoice is a list of line amounts in cents.",
		"+// Invoice is a list of line amounts in cents, with a tax rate.",
		" type Invoice struct {",
		" \tID    string",
		" \tLines []int",
		"+\tTax   Rate",
		" }",
		" ",
		" // Total sums the lines and applies the tax rate.",
		" func (i Invoice) Total() int {",
		"-\ttotal := 0",
		"+\tvar total int",
		" \tfor _, cents := range i.Lines {",
		" \t\ttotal += cents",
		" \t}",
		"+\tif i.Tax == nil {",
	}
	local tax_hunk = table.concat({
		"@@ -0,0 +1,41 @@",
		"+package billing",
		"+",
		"+// Rate applies a tax to an amount in cents.",
		"+type Rate interface {",
		"+\tApply(cents int) int",
		"+}",
		"+",
		"+// Flat is a Flat tax rate.",
		"+type Flat struct {",
		"+\tValue int",
		"+}",
		"+",
		"+// Apply implements Rate.",
		"+func (r Flat) Apply(cents int) int {",
		"+\treturn cents + r.Value",
		"+}",
		"+",
		"+// Percent is a Percent tax rate.",
	}, "\n")

	local function comment(id, author, body, created_at, path, line, reply_to, original_commit)
		return {
			id = id,
			author = { login = author },
			body = body,
			createdAt = created_at,
			url = "https://pgw.dev/finteqhub/billing/pull/482#discussion_r" .. id:match("%d+$"),
			diffHunk = path:match("tax%.go$") and tax_hunk or table.concat(
				vim.list_slice(invoice_hunk_lines, 1, ({ [11] = 13, [13] = 15, [22] = 25 })[line]),
				"\n"
			),
			originalCommit = { oid = original_commit or manifest.head },
			replyTo = reply_to and { id = reply_to } or vim.NIL,
		}
	end

	local function thread(id, path, line, opts)
		opts = opts or {}
		return {
			id = id,
			isResolved = opts.resolved or false,
			isOutdated = opts.outdated or false,
			path = path,
			line = line or vim.NIL,
			originalLine = opts.original_line or line,
			startLine = vim.NIL,
			originalStartLine = vim.NIL,
			diffSide = "RIGHT",
			subjectType = "LINE",
			resolvedBy = opts.resolved and { login = "gleb-beloded" } or vim.NIL,
			viewerCanReply = true,
			viewerCanResolve = true,
			viewerCanUnresolve = opts.resolved or false,
			comments = {
				pageInfo = { hasNextPage = false, endCursor = vim.NIL },
				nodes = opts.comments,
			},
		}
	end

	local invoice = "internal/billing/invoice.go"
	local tax = "internal/billing/tax.go"
	local c1 = comment(
		"PRRRC_c1",
		"maria.k",
		"Should a nil rate mean no tax at all?\nA missing config would silently drop tax.",
		"2026-01-01T23:00:00Z",
		invoice,
		22
	)
	local nodes = {
		thread("PRRT_t1", invoice, 22, {
			comments = {
				c1,
				comment(
					"PRRRC_c2",
					"gleb-beloded",
					"Good catch, defaulting to Rate(0) and\nlogging a warning.",
					"2026-01-02T00:00:00Z",
					invoice,
					22,
					c1.id
				),
			},
		}),
		thread("PRRT_t2", invoice, 13, {
			comments = { comment("PRRRC_c3", "ivan.p", "Rate or *Rate here?", "2026-01-01T21:00:00Z", invoice, 13) },
		}),
		thread("PRRT_t3", tax, nil, {
			outdated = true,
			original_line = 18,
			comments = {
				comment(
					"PRRRC_c4",
					"maria.k",
					"Round half-even?",
					"2026-01-01T02:00:00Z",
					tax,
					18,
					nil,
					manifest.commits[3]
				),
			},
		}),
		thread("PRRT_t4", invoice, 11, {
			resolved = true,
			comments = {
				comment(
					"PRRRC_c5",
					"ivan.p",
					"Should ID stay a string? The ledger numbers invoices with integers, so a string lets a malformed ID reach the export unchecked.\nIf we keep it, validate it in New.",
					"2026-01-01T21:00:00Z",
					invoice,
					11
				),
			},
		}),
	}

	return {
		["pr.json"] = vim.json.encode({
			number = 482,
			url = "https://pgw.dev/finteqhub/billing/pull/482",
			state = "OPEN",
			baseRefName = "main",
			baseRefOid = manifest.merge_base,
			headRefName = "feat/tax",
			headRefOid = manifest.head,
		}),
		["ReviewThreads.json"] = vim.json.encode({
			data = {
				repository = {
					pullRequest = {
						reviewThreads = {
							pageInfo = { hasNextPage = false, endCursor = vim.NIL },
							nodes = nodes,
						},
					},
				},
			},
		}),
	}
end
