# Usage kinds through `gr`

The existing tree and palette stay unchanged. The visible difference is that rows previously absent from
the real `gr` result, or left as unclassified usage rows, participate in the existing read/write grouping.

## Current render

`78x18`, Normal mode, temporary Lua project, `gr` on local `count`, classification finished:

```text
 ╭ Usages of count · 2 ───────────────────────────────────────────────────╮
 │ ▾ ◆ Production  2                                                     │
 │   ▾ ◎ Value read  2                                                   │
 │     ▾ □ .  2                                                          │
 │         ◆ main.lua:2                                                  │
 │         ◆ main.lua:3                                                  │
 │                                                                       │
 │                                                                       │
 │                                              ● Read/write w · Open ↩ │
 ╰───────────────────────────────────────────────────────────────────────╯
```

The assignment target at line 2 is missing because the references response omits it.

## Proposed render

`78x18`, Normal mode, same project and cursor after omitted highlights are merged:

```text
 ╭ Usages of count · 3 ───────────────────────────────────────────────────╮
 │ ▾ ◆ Production  3                                                     │
 │   ▾ ✎ Value write  1                                                  │
 │     ▾ □ .  1                                                          │
 │         ◆ main.lua:2                                                  │
 │   ▾ ◎ Value read  2                                                   │
 │     ▾ □ .  2                                                          │
 │         █ main.lua:2                                                  │
 │         ◆ main.lua:3                                                  │
 │                                              ● Read/write w · Open ↩ │
 ╰───────────────────────────────────────────────────────────────────────╯
```

The existing write/read icons, labels, ordering, colours and toggle remain authoritative; this change only
ensures the real entry point supplies the complete classified rows.
