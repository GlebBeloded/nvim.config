---@class gleb.folding.LuaHandler
---@field virtText table[]?
---@field lnum integer?
---@field endLnum integer?
---@field width integer?
---@field truncate (fun(text: string, width: integer): string)?
---@field bufnr integer?
local handler = { virtText = nil, lnum = nil, endLnum = nil, width = nil, truncate = nil, bufnr = nil }

---@return string[]
function handler:get_fold_text() -- returns array of lines
	return vim.api.nvim_buf_get_lines(self.bufnr, self.lnum, self.endLnum, false)
end

-- returns nth word of the handler.virtText
---@param n integer
---@return string
function handler:nth_word_of_line(n)
	return self.virtText[n][n]
end

-- returns nth word of the handler.virtText
---@param _ integer
---@return string
function handler:last_word_of_line(_)
	return self.virtText[#self.virtText][1]
end

---@param virtText table[]
---@param lnum integer
---@param endLnum integer
---@param width integer
---@param truncate fun(text: string, width: integer): string
---@param bufnr integer
---@return table[]
function handler:handle(virtText, lnum, endLnum, width, truncate, bufnr)
	handler.virtText = virtText
	handler.lnum = lnum
	handler.endLnum = endLnum
	handler.width = width
	handler.truncate = truncate
	handler.bufnr = bufnr

	if handler:last_word_of_line(1) == "{" then
		table.insert(virtText, { " ... " })
		table.insert(self.virtText, { "}" })
	else
		table.insert(virtText, { " ... " })
	end

	return self.virtText
end

return handler
