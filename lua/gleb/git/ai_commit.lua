-- AI-assisted commit message generation
local M = {}

-- Get commit context (diff + history)
local function get_commit_context()
	local diff = vim.fn.system("git diff --cached")
	local history = vim.fn.system("git log --oneline -5 2>/dev/null")
	return diff, history
end

-- Build prompt for AI
local function build_prompt(user_hint)
	local diff, history = get_commit_context()
	if diff == "" then return nil end

	local hint_section = ""
	if user_hint and user_hint ~= "" then
		hint_section = string.format("\nUser's hint (HIGH PRIORITY - incorporate this): %s\n", user_hint)
	end

	return string.format([[Generate a semantic commit message for these staged changes.
Format: <type>(<scope>): <subject>
Types: feat, fix, docs, style, refactor, test, chore
Scope: general area like "git", "ui", "lsp", "config" - NOT filenames. Omit if unclear.
Subject: present tense, lowercase, no period, max 50 chars.
Return ONLY the commit message, no quotes, no explanation, no markdown.
%s
Recent commits for style reference:
%s
Staged diff:
%s]], hint_section, history, diff)
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

-- Show commit input with AI hint (multiline popup)
function M.show_commit_input(on_commit)
	local Popup = require("nui.popup")
	local event = require("nui.utils.autocmd").event

	local popup = Popup({
		relative = "editor",
		position = "50%",
		size = { width = 50, height = 5 },
		border = {
			style = "rounded",
			text = {
				top = " Commit Message ",
				top_align = "center",
				bottom = " <A-c> 🦙 │ <S-CR> ✓ │ <S-Esc> ✗ ",
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
	vim.cmd("startinsert")

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

	-- Shift+Enter = commit
	popup:map("i", "<S-CR>", function()
		local text = get_text()
		if text ~= "" then
			close()
			on_commit(text)
		end
	end, { noremap = true })

	popup:map("n", "<CR>", function()
		local text = get_text()
		if text ~= "" then
			close()
			on_commit(text)
		end
	end, { noremap = true })

	-- AI generate (Alt+C)
	popup:map("i", "<A-c>", function()
		local current_text = get_text()
		local prompt = build_prompt(current_text)
		if not prompt then
			vim.notify("No staged changes", vim.log.levels.WARN)
			return
		end

		vim.notify("🦙 Generating...", vim.log.levels.INFO)

		active_job = call_ai(prompt, function(result)
			active_job = nil
			if result and result ~= "" and vim.api.nvim_buf_is_valid(bufnr) then
				local lines = vim.split(result, "\n")
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
				-- Move cursor to end
				local win = vim.fn.bufwinid(bufnr)
				if win ~= -1 then
					local last_line = #lines
					vim.api.nvim_win_set_cursor(win, { last_line, #lines[last_line] })
				end
				vim.notify("🦙 Done", vim.log.levels.INFO)
			end
		end, function(err)
			active_job = nil
			vim.notify("🦙 " .. err, vim.log.levels.ERROR)
		end)
	end, { noremap = true })

	-- Escape = normal mode (default), Shift+Escape = discard
	popup:map("i", "<S-Esc>", close, { noremap = true })
	popup:map("n", "<S-Esc>", close, { noremap = true })
	popup:map("n", "q", close, { noremap = true })

	popup:on(event.BufLeave, close)
end

return M
