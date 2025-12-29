local handler = { virtText = nil, lnum = nil, endLnum = nil, width = nil, truncate = nil }

function handler:getFoldText() -- returns array of lines
	return vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), self.lnum, self.endLnum, false)
end

-- returns nth word of the handler.virtText
function handler:nThWordOfLine(n)
	return self.virtText[n][n]
end

-- returns nth word of the handler.virtText
function handler:lastWordOfLine(_)
	return self.virtText[#self.virtText][1]
end

function handler:handle(virtText, lnum, endLnum, width, truncate)
	handler.virtText = virtText
	handler.lnum = lnum
	handler.endLnum = endLnum
	handler.width = width
	handler.truncate = truncate

	if handler:lastWordOfLine(1) == "{" then
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	else
		table.insert(virtText, { " ... " })
	end

	return self.virtText
end

return handler
