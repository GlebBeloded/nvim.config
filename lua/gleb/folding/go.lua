-- TODO: use tree-sitter for this
local handler = { virtText = nil, lnum = nil, endLnum = nil, width = nil, truncate = nil, bufnr = nil }

function handler:get_fold_text() -- returns array of lines
	return vim.api.nvim_buf_get_lines(self.bufnr, self.lnum, self.endLnum, false)
end

-- returns nth word of the handler.virtText
function handler:nth_word_of_line(n)
	return self.virtText[n][n]
end

function handler:is_return_err()
	if #self:get_fold_text() == 2 then
		return self:get_fold_text()[1]:find("return", 1, true) -- contains return statement
	end

	return false
end

function handler:return_arguments()
	local text = self:get_fold_text()[1] -- line[2] is just "}"
	text = string.gsub(text, "\t", "") -- trim indent
	text = string.gsub(text, "return", "") -- trim indent

	return text
end

function handler:is_panic()
	if #self:get_fold_text() == 2 then
		return self:get_fold_text()[1]:find("panic(", 1, true) -- contains return statement
	end

	return false
end

function handler:panic_arguments()
	local text = self:get_fold_text()[1] -- line[2] is just "}"
	text = string.gsub(text, "\t", "") -- trim indent
	text = string.gsub(text, "panic", "") -- trim indent
	text = string.sub(text, 2, -2) -- trim braces

	return text
end

function handler:is_function()
	return self:nth_word_of_line(1) == "func"
end

function handler:is_import()
	return self:nth_word_of_line(1) == "import"
end

function handler:is_var()
	return self:nth_word_of_line(1) == "var"
end

function handler:is_const()
	return self:nth_word_of_line(1) == "const"
end

function handler:handle(virtText, lnum, endLnum, width, truncate, bufnr)
	handler.virtText = virtText
	handler.lnum = lnum
	handler.endLnum = endLnum
	handler.width = width
	handler.truncate = truncate
	handler.bufnr = bufnr

	if self:is_return_err() then
		table.insert(self.virtText, { "  " }) -- return error followed by what is returned
		table.insert(self.virtText, { self:return_arguments() }) -- arguments
	elseif self:is_panic() then -- if this is a go function
		table.insert(self.virtText, { " ﮏ ", "TSKeyword" }) -- return error followed by what is returned
		table.insert(self.virtText, { self:panic_arguments() }) -- arguments
	elseif handler:is_import() or handler:is_var() or handler:is_const() then
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { ")" })
	else -- functions and default
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	end

	return self.virtText
end

return handler
