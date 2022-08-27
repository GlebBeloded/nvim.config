local handler = { virtText = nil, lnum = nil, endLnum = nil, width = nil, truncate = nil }

function handler:getFoldText() -- returns array of lines
	return vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), self.lnum, self.endLnum, false)
end

-- returns nth word of the handler.virtText
function handler:nThWordOfLine(n)
	return self.virtText[n][n]
end

function handler:isReturnErr()
	if #self:getFoldText() == 2 then
		return self:getFoldText()[1]:find("return", 1, true) -- contains return statement
	end

	return false
end

function handler:returnArguments()
	local text = self:getFoldText()[1] -- line[2] is just "}"
	text = string.gsub(text, "\t", "") -- trim indent
	text = string.gsub(text, "return", "") -- trim indent

	return text
end

function handler:isPanic()
	if #self:getFoldText() == 2 then
		return self:getFoldText()[1]:find("panic(", 1, true) -- contains return statement
	end

	return false
end

function handler:panicArguments()
	local text = self:getFoldText()[1] -- line[2] is just "}"
	text = string.gsub(text, "\t", "") -- trim indent
	text = string.gsub(text, "panic", "") -- trim indent
	text = string.sub(text, 2, -2) -- trim braces

	return text
end

function handler:isFunction()
	return self:nThWordOfLine(1) == "func"
end

function handler:isImport()
	return self:nThWordOfLine(1) == "import"
end

function handler:isVar()
	return self:nThWordOfLine(1) == "var"
end

function handler:isConst()
	return self:nThWordOfLine(1) == "const"
end

function handler:handle(virtText, lnum, endLnum, width, truncate)
	handler.virtText = virtText
	handler.lnum = lnum
	handler.endLnum = endLnum
	handler.width = width
	handler.truncate = truncate

	if self:isReturnErr() then
		table.insert(self.virtText, { "  " }) -- return error followed by what is returned
		table.insert(self.virtText, { self:returnArguments() }) -- arguments
	elseif self:isPanic() then -- if this is a go function
		table.insert(self.virtText, { " ﮏ ", "TSKeyword" }) -- return error followed by what is returned
		table.insert(self.virtText, { self:panicArguments() }) -- arguments
	elseif handler:isImport() or handler:isVar() or handler:isConst() then
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { ")" })
	elseif self:isFunction() then -- if this is a go function
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	else
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	end

	return self.virtText
end

return handler
