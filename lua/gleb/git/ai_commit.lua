-- AI-assisted commit message generation
local M = {}

-- Get staged diff
local function get_staged_diff()
	local diff = vim.fn.system("git diff --cached")

	-- Truncate diff if too long (prevents model confusion)
	local max_lines = 200
	local diff_lines = vim.split(diff, "\n")
	if #diff_lines > max_lines then
		diff = table.concat(vim.list_slice(diff_lines, 1, max_lines), "\n") .. "\n... (truncated)"
	end

	return diff
end

-- Build prompt for AI
local function build_prompt()
	local diff = get_staged_diff()
	if diff == "" then
		return nil
	end

	return string.format(
		[[Write a concise commit message for this diff.

Format: <type>(<scope>): <description>
Types: feat|fix|refactor|chore|docs|test
Keep it under 50 chars. No body, no explanation.

Diff:
%s]],
		diff
	)
end

-- Wrap text at specified width, preserving existing newlines
local function wrap_text(text, width)
	local result = {}
	-- Process each existing line separately
	for _, paragraph in ipairs(vim.split(text, "\n")) do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			if #line + #word + 1 > width then
				table.insert(result, line)
				line = word
			else
				line = line == "" and word or line .. " " .. word
			end
		end
		if line ~= "" then
			table.insert(result, line)
		end
	end
	return result
end

-- Format commit message: fix spacing, extract subject, wrap body
local function format_commit_message(raw)
	-- Fix missing spaces before capital letters (e.g., "fooBar" -> "foo Bar")
	local fixed = raw:gsub("([a-z])([A-Z])", "%1 %2")
	-- Fix missing spaces after periods
	fixed = fixed:gsub("%.([A-Z])", ". %1")
	-- Put bullet points on new lines (handles "text- " and "text - ")
	fixed = fixed:gsub("([^%s\n])%s*%-(%s)", "%1\n-%2")

	-- Extract subject: either "type(scope): subject" or first sentence
	local subject, body
	local type_match = fixed:match("^([%w]+%([%w%-]+%):%s*[^.!?\n]+)")
	if type_match then
		subject = type_match
		body = fixed:sub(#subject + 1)
	else
		-- Fallback: first sentence or 50 chars
		subject = fixed:match("^([^.!?\n]+)") or fixed:sub(1, 50)
		body = fixed:sub(#subject + 1)
	end

	subject = subject:gsub("^%s+", ""):gsub("%s+$", "")
	body = body:gsub("^[.!?%s]+", ""):gsub("%s+$", "")

	if body == "" then
		return subject
	end

	-- Wrap body at 72 chars
	local wrapped = wrap_text(body, 72)
	return subject .. "\n\n" .. table.concat(wrapped, "\n")
end

-- Call Ollama CLI directly (using stdin to avoid shell escaping issues)
local function call_ai(prompt, callback, on_error)
	local stdout_chunks = {}
	local job_id = vim.fn.jobstart({ "ollama", "run", "tavernari/git-commit-message:sp_commit_mini" }, {
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
						response = format_commit_message(response)
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

	-- Helper: resize popup to fit content
	local function resize_to_content()
		if not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
			return
		end
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		-- Use fixed width (72 = standard commit msg width)
		local width = 72
		local max_screen_width = math.floor(vim.o.columns * 0.8)
		width = math.min(width, max_screen_width)

		-- Calculate height accounting for wrapped lines
		local height = 0
		for _, line in ipairs(lines) do
			local line_width = vim.fn.strdisplaywidth(line)
			height = height + math.max(1, math.ceil(line_width / width))
		end
		height = math.min(height, 10) -- cap at 10 lines

		popup:update_layout({
			size = { width = width, height = height },
		})
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
			resize_to_content()
		end
	end, function(err)
		active_job = nil
		set_title(" Commit Message ")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# Error: " .. err })
		resize_to_content()
	end)
end

return M
