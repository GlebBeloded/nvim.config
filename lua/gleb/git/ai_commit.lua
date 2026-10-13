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

-- Call Ollama CLI directly (using stdin to avoid shell escaping issues)
local function call_ai(prompt, callback, on_error)
	local stdout = ""
	local job_id = vim.fn.jobstart({ "ollama", "run", "tavernari/git-commit-message:sp_commit_mini" }, {
		stdin = "pipe",
		stdout_buffered = true,
		on_stdout = function(_, data)
			stdout = table.concat(data, "\n")
		end,
		on_stderr = function(_, _)
			-- Suppress stderr (spinner/progress noise). Real errors come from exit code.
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				if code ~= 0 then
					on_error("Ollama exited with code " .. code)
				else
					local response = stdout
					-- Strip markdown code blocks if present
					response = response:gsub("^%s*```[%w]*%s*", ""):gsub("%s*```%s*$", "")
					response = response:gsub("^%s+", ""):gsub("%s+$", "")
					if response ~= "" then
						callback(response)
					else
						on_error("Ollama returned an empty message")
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

--- Buffer text without `#` comment lines, each line right-trimmed, the whole text trimmed.
---@param bufnr integer
---@return string
local function get_text(bufnr)
	local lines = vim.iter(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
		:filter(function(line)
			return not vim.startswith(line, "#")
		end)
		:map(function(line)
			return (line:gsub("%s+$", ""))
		end)
		:totable()
	return vim.trim(table.concat(lines, "\n"))
end

--- Show commit popup with auto-generated AI message.
---@param on_commit fun(message: string) called with the confirmed message
---@return nil
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

	-- Helper: popup still mounted (a wipe of bufnr can be aborted by autocmds, so check the window)
	local function is_open()
		return popup.winid ~= nil and vim.api.nvim_win_is_valid(popup.winid)
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
		local text = get_text(bufnr)
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
		if result and result ~= "" and is_open() then
			local lines = vim.split(result, "\n")
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
			set_title(" Commit Message ")
			resize_to_content()
		end
	end, function(err)
		active_job = nil
		if not is_open() then
			return
		end
		set_title(" Commit Message ")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# Error: " .. err })
		resize_to_content()
	end)
end

return M
