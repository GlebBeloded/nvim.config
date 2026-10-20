## Why

Kind: feature
Depends: pr-comments-view, pr-thread-mutations

`pr-comments-view` shows review threads in the Comments tab and as peeks in the code, but they can only be
read there. The user wants to act on them in the editor: "I want Open thread action to read/reply in a
thread. Or to resolve thread. With hints on which button does what. Also that should have confirmation".

## What Changes

- **Thread window** (design.md, Decisions 1–3). `pr.open_thread` (Find Action, no key) opens the thread on
  the cursor line in a centred float, and Enter on a Comments tab thread now opens it too.
  - The float is 72 columns wide on a 100-column screen, above the statusline.
  - Its title is in the top border: " invoice.go:22 · PR #482 · open ".
  - Inside it: the commented line (or the `diffHunk` for a thread that no longer maps), every comment with
    author, age and body, a `Reply` rule, a multi-line reply area (Markdown, Insert mode), and the hint row
    under a joined rule: "Reply ↩ · Resolve R · Open on web gx · Close q" (rule 8.9).
- **Keys** (`gleb-pr-thread`, from `settings/keymap.json`):
  - Enter in Normal mode starts a reply, or asks to send one;
  - R asks to resolve, or to unresolve a resolved thread;
  - gx opens the thread on the web;
  - q closes and keeps the draft.
- **Confirmation in the hint row** (design.md, Decision 4). Nothing is written without it.
  - Sending: "Send this reply to maria.k on pgw.dev?  Send y · Keep editing n".
  - Resolving: "Resolve this thread?  Resolve y · Cancel n".
  - The row is yellow (`PrConfirm`, `PrConfirmHint`), and only y, n and Esc act (`gleb-pr-confirm`).
  - y runs the mutation, refreshes the threads and notifies. n goes back to editing.
  - A failure is notified at ERROR and the draft is kept.
- **Mutations** (design.md, Decision 5): `addPullRequestReviewThreadReply`, `resolveReviewThread` and
  `unresolveReviewThread` through `gh api graphql`, as argument lists, with the PR host. They are the only
  writes this config makes to GitHub.
  The requests themselves (`gh.reply`, `gh.set_resolved`) ship first in `pr-thread-mutations` (split out,
  user 2026-10-20); this change calls them.
- **Highlight groups**: `PrConfirm`, `PrConfirmHint`, `PrReplyPlaceholder`. The frame reuses `FloatBorder`,
  `FloatTitle` and `PickerHint`.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `pr`:
  - Added: "Thread window", "Thread window keys", "Reply confirmation", "Resolve confirmation", "Thread
    mutations", "Thread window colours".
  - Modified: "Comments tab Enter" (from `pr-comments-view`; Enter now also opens the thread window, which
    takes focus). It is copied whole, with its one scenario restated.

## Impact

- Code:
  - New: `lua/gleb/pr/thread_window.lua`.
  - Changed:
    - `lua/gleb/pr/{actions,comments_tab,highlights}.lua` (the window and confirm actions, Enter, colours);
    - `settings/keymap.json`: `pr.thread_send` Enter, `pr.thread_resolve` R, `pr.thread_open_web` gx,
      `pr.thread_close` q, `pr.confirm_yes` y, and `pr.confirm_no` n and Esc, all view-scoped.
- Tests:
  - integration `tests/integration/pr/test_thread_window.lua`;
  - changed integration cases in `tests/integration/pr/test_comments_tab.lua`;
  - screen `tests/screen/pr/test_thread_window.lua`;
- Plugins: none added, removed or upgraded. octo.nvim, gh-review.nvim and snacks.nvim's `gh` all reply and
  resolve from their own buffers, with no confirmation step; the user chose our own build (R2.7).
- Core keymaps: none. The new keys are local to the thread window (`gleb-pr-thread`, `gleb-pr-confirm`), and
  `pr.open_thread` is unbound.
- Unchanged scenarios:
  - `git: Changes panel mappings come from the shortcut file` still holds: the new keys are scoped to the thread window's filetypes, not `gleb-changes`.
  - `git: Changes panel Enter opens the file` still holds: Enter on Local and Branch rows is unchanged; only Comments thread rows open the thread window.
  - `actions: Every configured mapping is action-owned` still holds: every thread-window key is a `pr.*` action in `settings/keymap.json`.
  - `actions: Exact and prefix overlaps conflict in one scope` still holds: `gx`, `q`, `R` and Enter are unique within `gleb-pr-thread`, and `y`, `n` and Esc within `gleb-pr-confirm`.
  - `picker: Input prompt cancels with Esc` and `picker: Input prompt Esc restores tree focus and cursor state` still hold: Esc is mapped only in the `gleb-pr-confirm` buffer, never in the picker.
  - `git: Enter confirms message` and `git: q discards popup` still hold: the AI commit popup keeps its own filetype and keys.
  - `git: Requirement: Branch tab hint row` still holds: the thread window reuses `PickerHint` without changing the Branch tab's hint text, keys, rule or scrolling.
- Out of scope:
  - Starting a new thread, editing or deleting a comment, suggestions, reactions, pending reviews and review
    submission.
  - Rendering Markdown in the window: bodies are plain text.
  - Reply drafts that survive a restart: they live for the session.

## Decision (user, 2026-10-19)

- R2.4: "I want Open thread action to read/reply in a thread. Or to resolve thread. With hints on which button
  does what. Also that should have confirmation".
- R3.1 thread window: centred (approved mock `r3_thread_center`).
- R3.2 confirmation: the hint row becomes the question (approved mock `r3_confirm_footer`).
- R3.3 send: Enter in Normal mode, then `y`.
- Latest: the thread actions are Find Action entries without a shortcut.

## Agent decisions

- **Enter on an empty reply starts Insert mode.** The hint `Reply ↩` then means the same key from the first
  press: write, then send.
- **The confirm state has its own filetype** (`gleb-pr-confirm` on the reply buffer, read-only), so `y` and
  `n` are action-owned keys only while the question shows. In the normal state `y` keeps yanking text out of
  a comment.
- **The question names the first comment's author**: replies go to the thread, and its author is the person
  the user answers.
- **Focus leaving the window closes it**, as the AI commit popup does. The draft is kept per thread for the
  session, so nothing typed is lost.
- **The `Reply` label sits on an inner joined rule**, as in the approved mock. Rule 8.9 keeps text off the
  outer border (title only), and this is a section rule inside the frame, like the picker's section rows.
- **No separate dialog**: the user picked the hint-row question over the `r3_confirm_dialog` mock.
- **Draft text is plain `Normal`**: no group is needed for it.

## Decision (user, 2026-10-20)

- Don't guess the GitHub API: the agent may call the real API on this repo's own PRs (GlebBeloded/nvim.config, through
  `gh`) to learn the exact request and response shapes, then record those responses as fixtures and test against the
  mocked responses. Tests never call the network.
