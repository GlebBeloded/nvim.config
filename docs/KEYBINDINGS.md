# Keybinding Architecture: macOS → Alacritty → Zellij → Neovim

This document explains how keyboard shortcuts flow through the terminal stack and how to add/debug them.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ macOS                                                            │
│  • Cmd+H = Hide app (system-level, can disable per-app)        │
│  • Cmd+Q = Quit app (system-level)                              │
│  • Other Cmd keys can be overridden by applications             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Alacritty (Terminal Emulator)                                   │
│  • Translates Cmd+Key → Escape Sequences                        │
│  • Config: ~/.config/alacritty/keymaps_macos.toml               │
│  • Sends sequences to running program (Zellij)                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Zellij (Terminal Multiplexer)                                   │
│  • Intercepts sequences for multiplexer actions                 │
│  • vim-zellij-navigator plugin routes to Neovim if focused      │
│  • Config: ~/.config/zellij/config.kdl                          │
│  • Passes unhandled sequences to child process (Neovim/shell)   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Neovim (Text Editor)                                            │
│  • Receives escape sequences from Zellij                        │
│  • Maps sequences to Lua functions                              │
│  • Config: ~/.config/nvim/lua/gleb/keymaps.lua                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔑 Current Keybinding Mappings

### Navigation (Cmd+H/J/K/L)

| Key | Alacritty Sends | Zellij Catches | Neovim Receives | Action |
|-----|----------------|----------------|-----------------|--------|
| Cmd+H | `\u0008` (Ctrl+H) | `Ctrl h` | `<C-h>` | Move left (seamless) |
| Cmd+J | `\u001Bj` (Alt+j) | `Alt j` | `<A-j>` | Move down (seamless) |
| Cmd+K | `\u001Bk` (Alt+k) | `Alt k` | `<A-k>` | Move up (seamless) |
| Cmd+L | `\u000C` (Ctrl+L) | `Ctrl l` | `<C-l>` | Move right (seamless) |

**Flow:** vim-zellij-navigator plugin detects if Neovim is focused. If yes, forwards to Neovim. If no, navigates Zellij panes.

### Resizing (Cmd+Shift+H/J/K/L)

| Key | Alacritty Sends | Zellij Catches | Neovim Receives | Action |
|-----|----------------|----------------|-----------------|--------|
| Cmd+Shift+H | `\u001BH` (Alt+H) | `Alt H` | `<A-H>` | Resize left (seamless) |
| Cmd+Shift+J | `\u001BJ` (Alt+J) | `Alt J` | `<A-J>` | Resize down (seamless) |
| Cmd+Shift+K | `\u001BK` (Alt+K) | `Alt K` | `<A-K>` | Resize up (seamless) |
| Cmd+Shift+L | `\u001BL` (Alt+L) | `Alt L` | `<A-L>` | Resize right (seamless) |

**Flow:** Same as navigation - plugin routes to appropriate target.

### Application Commands

| Key | Alacritty Sends | Handled By | Action |
|-----|----------------|------------|--------|
| Cmd+E | `\u001Be` (Alt+e) | Neovim | Neo-tree file explorer |
| Cmd+G | `\u001Bg` (Alt+g) | Neovim | Neo-tree git status |
| Cmd+R | `\u001Br` (Alt+r) | Neovim | LSP rename |
| Cmd+W | `\u001Bw` (Alt+w) | Neovim | Next diagnostic |
| Cmd+Shift+F | `\u001BF` (Alt+F) | Neovim | Telescope live grep |
| Cmd+[ | `\u001B[` (Alt+[) | Zellij | Previous tab |
| Cmd+] | `\u001B]` (Alt+]) | Zellij | Next tab |

---

## 🛠️ How to Add a New Keybinding

### Example: Adding Cmd+D to split pane down

#### Step 1: Choose the escape sequence

**Options:**
- `Ctrl` sequences: `\u0000` to `\u001F` (limited, some are special)
- `Alt` sequences: `\u001B` + character (recommended)
  - Lowercase: `\u001Bd` = Alt+d
  - Uppercase: `\u001BD` = Alt+D (with Shift)

**Decision:** Use `\u001Bd` (Alt+d) for Cmd+D

#### Step 2: Add to Alacritty

Edit `~/.config/alacritty/keymaps_macos.toml`:

```toml
[[keyboard.bindings]]
chars = "\u001Bd"
key = "D"
mods = "Command"
```

**⚠️ Important:** Must restart Alacritty completely (Cmd+Q, reopen) for changes to take effect.

#### Step 3: Add to Zellij

Edit `~/.config/zellij/config.kdl` in the `shared_except "locked"` section:

```kdl
bind "Alt d" {
    NewPane "Down";
    SwitchToMode "normal";
}
```

**⚠️ Note:** KDL syntax uses `Alt d` NOT `\u001Bd`. Zellij automatically translates.

**Restart Zellij:** Exit session with `exit` or `Ctrl+Q`, then restart.

#### Step 4: (Optional) Add to Neovim

If you want Cmd+D to do something IN Neovim:

Edit `~/.config/nvim/lua/gleb/keymaps.lua`:

```lua
kmap("n", "<A-d>", ":split<CR>", opts)  -- Split horizontally
```

**Note:** Neovim will only see this if Zellij doesn't intercept it first.

---

## 🔍 Debugging Keybindings

### Problem: Key doesn't work at all

#### Debug Step 1: Check if macOS is blocking it

```bash
# Outside Alacritty, check System Settings
System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts
```

- Look for conflicting shortcuts for Alacritty.app
- Disable any that match your key

**Common conflicts:**
- Cmd+H = Hide Application (must disable per-app)
- Cmd+M = Minimize Window
- Cmd+Q = Quit Application

#### Debug Step 2: Check if Alacritty receives it

```bash
alacritty --print-events 2>&1 | grep KeyboardInput
```

Then press your key. You should see:
```
KeyboardInput { physical_key: Code(KeyD), logical_key: Character("d"), ...
```

**If you see nothing:** macOS is blocking it (see Step 1)
**If you see the event:** Alacritty receives it, check binding

#### Debug Step 3: Check Alacritty binding

Outside Zellij, run:
```bash
xxd
```

Press your key. You should see the hex code:
```
00000000: 1b64                                     .d
```

This shows `1b` (ESC) + `64` ('d') = Alt+d = `\u001Bd` ✓

**If you see nothing or wrong code:**
- Check `keymaps_macos.toml` syntax
- Restart Alacritty (Cmd+Q, reopen)
- Verify import: `grep "import" ~/.config/alacritty/alacritty.toml`

#### Debug Step 4: Check if Zellij intercepts it

Inside Zellij (but NOT in Neovim), press your key.

**Does something happen?**
- **Yes:** Zellij has it bound (check `config.kdl`)
- **No:** Either not bound in Zellij, or there's an error

Check Zellij config syntax:
```bash
zellij setup --check
```

#### Debug Step 5: Check if Neovim receives it

Inside Neovim, run:
```vim
:verbose map <A-d>
```

Shows if/where `<A-d>` is mapped.

Or insert mode test:
```vim
:startinsert
# Press Ctrl+V then your key
```

Should show `^[d` (ESC + d) if working.

---

## ⚠️ Common Pitfalls

### 1. **Using Ctrl+J or Ctrl+K**

**Problem:** These are special terminal control characters:
- Ctrl+J = Newline (0x0A)
- Ctrl+K = Vertical Tab (0x0B)

Shell intercepts them before Zellij/Neovim can see them.

**Solution:** Use Alt sequences instead (`\u001Bj`, `\u001Bk`)

### 2. **Not restarting Alacritty after config changes**

Closing the window ≠ quitting the app.

**Correct way:** Cmd+Q (quit), then reopen from Applications/Spotlight

**Verify:** `ps aux | grep alacritty` should show new PID after restart

### 3. **KDL escape sequences don't work**

**Wrong:**
```kdl
bind "\u001Bd" { ... }  # ❌ KDL doesn't support \u
```

**Correct:**
```kdl
bind "Alt d" { ... }    # ✓ Use KDL's modifier syntax
```

### 4. **Zellij intercepts keys meant for Neovim**

If Zellij binds a key in `shared_except "locked"`, it ALWAYS intercepts it, even when Neovim is focused.

**Solutions:**
- Use vim-zellij-navigator plugin (checks if Neovim focused)
- Remove binding from Zellij
- Use a different key

### 5. **Imports not loading in Alacritty**

Symptom: Bindings work in main file but not in imported file.

**Debug:**
```bash
# Check import statement exists
grep "import" ~/.config/alacritty/alacritty.toml

# Should show:
# import = [
#     "~/.config/alacritty/keymaps_macos.toml",
# ]

# Verify file exists
ls -la ~/.config/alacritty/keymaps_macos.toml
```

**Note:** Imports work, but easier to debug by testing in main file first.

### 6. **Cmd+H still hides Alacritty**

Even with binding in config, macOS system shortcuts take precedence.

**Fix:**
```
System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts
Click + button
Application: Alacritty
Menu Title: Hide Alacritty
Keyboard Shortcut: (Press something else, like Cmd+Option+H)
```

This disables system Cmd+H for Alacritty only.

---

## 📝 Keybinding Design Guidelines

### 1. **Choose modifiers wisely**

**Cmd keys** (translated to Alt/Ctrl):
- ✅ Good for: Navigation, app-level actions
- ✅ Feels "macOS native"
- ⚠️ May conflict with system shortcuts

**Ctrl keys directly:**
- ✅ Good for: Mode switching, traditional Unix actions
- ✅ No macOS conflicts
- ⚠️ Harder to reach (pinkie stretch)

**Alt/Option keys:**
- ✅ Good for: Secondary actions, quick operations
- ✅ Easy to reach (thumb)
- ⚠️ Some apps use for special characters

**Recommendation:** Use Cmd for primary actions (with Alt escape sequences), Ctrl for Zellij modes.

### 2. **Layer responsibilities**

**Alacritty:** Only translation (Cmd → escape sequences)
**Zellij:** Multiplexer actions (panes, tabs, sessions)
**Neovim:** Editor actions (text, files, LSP)

**Seamless actions** (navigation/resize): Use vim-zellij-navigator plugin

### 3. **Document everything**

When adding a key, add comments:

```toml
# Alacritty
[[keyboard.bindings]]
chars = "\u001Bd"   # Alt+d for split down
key = "D"
mods = "Command"
```

```kdl
# Zellij
bind "Alt d" {      // Cmd+D splits pane down
    NewPane "Down";
}
```

```lua
-- Neovim
kmap("n", "<A-d>", ":split<CR>", opts)  -- Cmd+D horizontal split
```

---

## 🧪 Testing Checklist

When adding a new keybinding, test:

- [ ] Outside Zellij (in shell): Does key appear in `xxd`?
- [ ] In Zellij (no Neovim): Does Zellij action trigger?
- [ ] In Neovim (within Zellij): Does correct action trigger?
- [ ] Edge case: Multiple Neovim windows - seamless navigation works?
- [ ] Edge case: Multiple Zellij panes - seamless navigation works?

---

## 🔗 Reference

### Escape Sequence Format

**Ctrl sequences:** `\u00XX` where XX is 00-1F
```
Ctrl+A = \u0001    Ctrl+N = \u000E
Ctrl+B = \u0002    Ctrl+O = \u000F
...
Ctrl+H = \u0008    Ctrl+U = \u0015
Ctrl+I = \u0009    (Tab)
Ctrl+J = \u000A    (Newline - avoid!)
Ctrl+K = \u000B    (VTab - avoid!)
Ctrl+L = \u000C
Ctrl+M = \u000D    (Enter)
```

**Alt sequences:** `\u001B` + character
```
Alt+a = \u001Ba
Alt+A = \u001BA (with Shift)
Alt+1 = \u001B1
Alt+[ = \u001B[
```

**CSI u-sequences** (Kitty protocol):
```
\u001B[<codepoint>;<modifier>u

Example: Ctrl+Shift+H
\u001B[72;6u
  72 = 'H' ASCII code
  6 = Ctrl+Shift modifier
```

### Modifier Codes (CSI u-sequences)

```
1 = Shift
2 = Alt
3 = Alt+Shift
4 = Ctrl
5 = Ctrl+Shift
6 = Ctrl+Alt
7 = Ctrl+Alt+Shift
8 = Meta
```

### Neovim Key Notation

```
<C-h>    = Ctrl+h
<A-h>    = Alt+h
<M-h>    = Meta+h (same as Alt on most systems)
<S-h>    = Shift+h (uppercase H)
<A-H>    = Alt+Shift+h
<leader> = Leader key (default \)
<CR>     = Enter/Return
<Esc>    = Escape
```

### Config File Locations

```
Alacritty:  ~/.config/alacritty/alacritty.toml
            ~/.config/alacritty/keymaps_macos.toml

Zellij:     ~/.config/zellij/config.kdl

Neovim:     ~/.config/nvim/lua/gleb/keymaps.lua
```

---

## 💡 Advanced: Seamless Navigation Setup

The vim-zellij-navigator plugin enables seamless navigation between Neovim windows and Zellij panes using the same keybindings.

**How it works:**

1. Alacritty sends escape sequence (e.g., `\u0008` for Cmd+H)
2. Zellij's `MessagePlugin` binding catches it
3. Plugin checks: Is Neovim running in current pane?
   - **Yes:** Sends sequence to Neovim
   - **No:** Moves between Zellij panes
4. Neovim's smart-splits receives sequence and navigates windows

**Setup requirements:**

1. Plugin installed: `~/.config/zellij/plugins/vim-zellij-navigator.wasm`
2. Zellij binds to MessagePlugin with `move_focus_or_tab` or `resize`
3. Neovim maps same sequences to smart-splits functions
4. smart-splits.nvim plugin installed in Neovim

**Example config:**

```kdl
# Zellij
bind "Ctrl h" {
    MessagePlugin "file:/path/to/vim-zellij-navigator.wasm" {
        name "move_focus_or_tab";
        payload "left";
    };
}
```

```lua
-- Neovim
kmap("n", "<C-h>", require("smart-splits").move_cursor_left, opts)
```

**Key insight:** Both Zellij and Neovim must bind the SAME sequence (e.g., `<C-h>`) so the plugin can forward it correctly.

---

## 🆘 Emergency Debugging

### Nuclear option: Bypass everything

Test if base Alacritty → Neovim works without Zellij:

```bash
# Quit Alacritty, reopen, skip Zellij
nvim /tmp/test.txt

# In insert mode, press Ctrl+V then your key
# Should show raw escape sequence
```

### Check what Zellij sees

Add this to Zellij config temporarily:

```kdl
bind "Alt x" {
    Run "notify-send" "Caught Alt+x!";
}
```

Restart Zellij, press Cmd+X. If notification appears, binding works.

### Verify plugin is loaded

In Zellij:
```bash
ls ~/.config/zellij/plugins/vim-zellij-navigator.wasm
# Should exist and be ~1.1MB
```

Check Zellij logs:
```bash
tail -f /tmp/zellij-*/zellij-log-*.log
```

Press navigation keys, look for plugin errors.

---

## 📚 Further Reading

- [Alacritty Keyboard Mappings Wiki](https://github.com/alacritty/alacritty/wiki/Keyboard-mappings)
- [Zellij Keybindings Docs](https://zellij.dev/documentation/keybindings.html)
- [vim-zellij-navigator GitHub](https://github.com/hiasr/vim-zellij-navigator)
- [smart-splits.nvim GitHub](https://github.com/mrjones2014/smart-splits.nvim)
- [Neovim Key Notation Help](https://neovim.io/doc/user/intro.html#key-notation)

---

## ✅ Summary

**The key to successful keybinding setup:**

1. **Understand the flow:** macOS → Alacritty → Zellij → Neovim
2. **Choose sequences wisely:** Avoid Ctrl+J/K, prefer Alt sequences
3. **Test each layer:** Use `--print-events`, `xxd`, and `:verbose map`
4. **Restart after changes:** Alacritty especially needs full restart
5. **Document your choices:** Future you will thank you
6. **Use plugins for seamless actions:** vim-zellij-navigator + smart-splits

**When in doubt:** Test at each layer from the bottom up (Alacritty → Zellij → Neovim) to isolate the problem.
