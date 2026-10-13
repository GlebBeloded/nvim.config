# Design

## Context

The `gr` mapping passes Telescope's `lsp_references` function directly. Telescope defaults
`include_current_line` to `false` and filters every reference whose file and line match the cursor,
after requesting declarations from gopls. On the `Format` declaration this removes the declaration
from the five-location reply, leaving four picker entries.

## Current render

82x10, Insert mode, empty Telescope references prompt opened on the `Format` declaration:

```text
╭────────────────────────────────────────────────────────────────────────────────╮
│ References                                                                     │
│ billing/invoice.go:17:15          return money.Format(total)                   │
│ billing/invoice.go:24:31          append(lines, money.Format(cents))            │
│ internal/money/money_test.go:6:12 if got := Format(1999)                       │
│ report/summary.go:7:28            "total: " + money.Format(total)              │
│                                                                                │
│ > █                                                                            │
╰────────────────────────────────────────────────────────────────────────────────╯
```

The declaration on the cursor's line is absent, so the picker reports 4 of 5 locations.

## Proposed render

82x11, Insert mode, empty Telescope references prompt opened on the `Format` declaration:

```text
╭────────────────────────────────────────────────────────────────────────────────╮
│ References                                                                     │
│ billing/invoice.go:17:15          return money.Format(total)                   │
│ billing/invoice.go:24:31          append(lines, money.Format(cents))            │
│ internal/money/money.go:6:6       func Format(cents int) string                │
│ internal/money/money_test.go:6:12 if got := Format(1999)                       │
│ report/summary.go:7:28            "total: " + money.Format(total)              │
│                                                                                │
│ > █                                                                            │
╰────────────────────────────────────────────────────────────────────────────────╯
```

The picker reports all 5 manifest locations, including the declaration under the cursor. Layout,
sorting and selection behavior stay unchanged.

## Decision

Wrap the Telescope call in a small named `lsp_references` function that passes
`{ include_current_line = true }`, and keep `gr` mapped to that function. No plugin configuration or
load order changes are needed.
