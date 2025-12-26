-- AI-assisted commit message generation
local M = {}

-- Get commit context (diff + history)
local function get_commit_context()
	local diff = vim.fn.system("git diff --cached")
	local history = vim.fn.system("git log --oneline -5 2>/dev/null")

	-- Truncate diff if too long (prevents model confusion)
	local max_lines = 200
	local diff_lines = vim.split(diff, "\n")
	if #diff_lines > max_lines then
		diff = table.concat(vim.list_slice(diff_lines, 1, max_lines), "\n") .. "\n... (truncated)"
	end

	return diff, history
end

-- Build prompt for AI
local function build_prompt()
	local diff, history = get_commit_context()
	if diff == "" then return nil end

	return string.format([[You are a git commit message generator. Output ONLY a single line commit message.

Format: <type>(<scope>): <subject>
Types: feat|fix|docs|style|refactor|test|chore
Scope: optional, general area (git, ui, lsp, config), NOT filenames
Subject: present tense, lowercase, no period, max 50 chars

Example output: feat(ui): add dark mode toggle

IMPORTANT: Output ONLY the commit message. No JSON, no explanation, no markdown, no quotes.

Recent commits:
%s
Diff:
%s]], history, diff)
end

-- Call Ollama CLI directly (using stdin to avoid shell escaping issues)
local function call_ai(prompt, callback, on_error)
	local stdout_chunks = {}
	local job_id = vim.fn.jobstart({ "ollama", "run", "qwen2.5-coder:1.5b" }, {
		stdin = "pipe",
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				for _, chunk in ipairs(data) do
					if chunk ~= "" then
						table.insert(stdout_chunks, chunk)
					end
				end
			end
		end,
		on_stderr = function(_, _)
			-- Suppress stderr (spinner/progress noise). Real errors come from exit code.
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				if code ~= 0 then
					on_error("Ollama exited with code " .. code)
				else
					local response = table.concat(stdout_chunks, "")
					-- Strip markdown code blocks if present
					response = response:gsub("^%s*```[%w]*%s*", ""):gsub("%s*```%s*$", "")
					response = response:gsub("^%s+", ""):gsub("%s+$", "")
					if response ~= "" then
						callback(response)
					end
				end
			end)
		end,
	})

	-- Send prompt via stdin and close
	if job_id > 0 then
		vim.fn.chansend(job_id, prompt)
		vim.fn.chanclose(job_id, "stdin")
	end

	return job_id
end

-- Show commit popup with auto-generated AI message
function M.show_commit_input(on_commit)
	local Popup = require("nui.popup")
	local event = require("nui.utils.autocmd").event

	local popup = Popup({
		relative = "editor",
		position = "50%",
		size = { width = 60, height = 3 },
		border = {
			style = "rounded",
			text = {
				top = " 🦙 Generating... ",
				top_align = "center",
				bottom = " <CR> ✓ │ i edit │ q ✗ ",
				bottom_align = "center",
			},
		},
		enter = true,
		focusable = true,
		buf_options = {
			modifiable = true,
			filetype = "gitcommit",
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			wrap = true,
			linebreak = true,
		},
	})

	popup:mount()
	local bufnr = popup.bufnr
	local winid = popup.winid

	-- Track active job
	local active_job = nil

	-- Helper: get buffer text, strip trailing whitespace from each line
	local function get_text()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		for i, line in ipairs(lines) do
			lines[i] = line:gsub("%s+$", "")
		end
		return table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
	end

	-- Helper: close popup
	local function close()
		if active_job then
			vim.fn.jobstop(active_job)
		end
		popup:unmount()
	end

	-- Helper: update title
	local function set_title(title)
		popup.border:set_text("top", title, "center")
	end

	-- Enter in normal mode = commit
	popup:map("n", "<CR>", function()
		local text = get_text()
		if text ~= "" then
			close()
			on_commit(text)
		end
	end, { noremap = true })

	-- q in normal mode = discard
	popup:map("n", "q", close, { noremap = true })

	popup:on(event.BufLeave, close)

	-- Auto-generate commit message
	local prompt = build_prompt()
	if not prompt then
		set_title(" Commit Message ")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# No staged changes" })
		return
	end

	active_job = call_ai(prompt, function(result)
		active_job = nil
		if result and result ~= "" and vim.api.nvim_buf_is_valid(bufnr) then
			local lines = vim.split(result, "\n")
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
			set_title(" Commit Message ")
		end
	end, function(err)
		active_job = nil
		set_title(" Commit Message ")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# Error: " .. err })
	end)
end

return M
