local function lsp_highlight_document(client)
  -- Set autocommands conditional on server_capabilities

  -- end
end

return function(client, buffer)
  -- vim.notify(client.name .. " starting...")
  lsp_highlight_document(client)
end
