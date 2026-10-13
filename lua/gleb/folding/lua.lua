local handler = { virtText = nil, lnum = nil, endLnum = nil, width = nil, truncate = nil }

function handler:get_fold_text() -- returns array of lines
	return vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), self.lnum, self.endLnum, false)
end

-- returns nth word of the handler.virtText
function handler:nth_word_of_line(n)
	return self.virtText[n][n]
end

-- returns nth word of the handler.virtText
function handler:last_word_of_line(_)
	return self.virtText[#self.virtText][1]
end

function handler:handle(virtText, lnum, endLnum, width, truncate)
	handler.virtText = virtText
	handler.lnum = lnum
	handler.endLnum = endLnum
	handler.width = width
	handler.truncate = truncate

	if handler:last_word_of_line(1) == "{" then
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	else
		table.insert(virtText, { " ... " })
	end

	return self.virtText
end

return handler
