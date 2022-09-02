local sign = vim.fn.sign_define

-- `DapLogPoint` for log points (default: `L`)

sign("DapBreakpoint", { text = "", texthl = "red", linehl = "", numhl = "" })
sign("DapBreakpointCondition", { text = "", texthl = "red", linehl = "", numhl = "" })
sign("DapBreakpointRejected", { text = "", texthl = "TSComment", linehl = "", numhl = "" })
sign("DapStopped", { text = "", texthl = "red", linehl = "DapStopped", numhl = "" })
