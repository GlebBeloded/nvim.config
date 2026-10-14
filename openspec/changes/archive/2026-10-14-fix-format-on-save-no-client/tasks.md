## 1. Guard format-on-save by buffer capability
Scenarios: `autocommands: Saving without a formatting server is silent`, `autocommands: Saving with a formatting server formats the buffer`
- [x] 1.1 Write the tests `autocommands: Saving without a formatting server is silent` and `autocommands: Saving with a formatting server formats the buffer` in tests/integration/autocommands/test_format_on_save.lua and see the no-server case fail
- [x] 1.2 Check for a document-formatting client attached to the `BufWritePre` event buffer, and pass that buffer to the formatting request
- [x] 1.3 Run `make test FILE=tests/integration/autocommands/test_format_on_save.lua CASE="Saving without a formatting server is silent"` and `make test FILE=tests/integration/autocommands/test_format_on_save.lua CASE="Saving with a formatting server formats the buffer"` and see them pass
