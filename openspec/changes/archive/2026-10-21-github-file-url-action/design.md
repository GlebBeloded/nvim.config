## Context

`changes.copy_commit_url` is available only on a Branch commit row, so Find Action omits it from ordinary file
buffers. The replacement operates on the file-buffer context already captured by the action system and produces a
branch URL instead of a commit permalink.

## Current render

72x18, Normal mode, tracked file buffer, Find Action queried for `file url`:

```text
one
two█
three
~
~
      ╭ Find Action › file url────────────────────────────────╮
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │ ⌥↩ · ⌘⇧A                                        0/0  │
      ╰───────────────────────────────────────────────────────╯
```

The commit-row action is unavailable in this context, so no matching action is shown.

## Proposed render

72x18, Normal mode, tracked file buffer, Find Action queried for `file url`, no assigned shortcut:

```text
one
two█
three
~
~
      ╭ Find Action › file url────────────────────────────────╮
      │ Copy File URL                                    Git  │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │                                                       │
      │ ⌥↩ · ⌘⇧A                                        1/1  │
      ╰───────────────────────────────────────────────────────╯
```

When the action has an assigned shortcut, the same row remains present and shows that shortcut between the title and
category using Find Action's existing row format.

## Decisions

- Replace the commit-row action instead of keeping two similarly named URL actions. `:Gitlink` remains the explicit
  commit-permalink command.
- Resolve `origin`, repository root, tracked path, and the attached local branch at invocation time. An upstream is not
  consulted because the requested URL names the current local branch.
- Put normalization and URL assembly in a pure `gleb.git.file_url` module. The catalog action owns editor context,
  asynchronous Git queries, clipboard mutation, and notifications.
- Preserve slashes that delimit branch and file path segments while percent-encoding unsafe bytes within them.

## Risks

- A local branch can be absent on the remote; the requested link is still copied because publishing branches is out of
  scope.
- Branch names containing slashes can look like path segments. GitHub resolves the longest matching ref; focused tests
  keep the emitted form stable.
- The editor context can disappear during asynchronous Git work; completion must validate the captured buffer and avoid
  mutating the clipboard after an invalid result.
