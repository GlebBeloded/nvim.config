-- File-tree perf probe: monkey-patches module fields, never edits source.
local ROOT = assert(os.getenv("FT_ROOT"))
local EDIT = assert(os.getenv("FT_EDIT")) -- relative file to open/write
local hr = vim.uv.hrtime
local function ms(ns) return ns / 1e6 end

local view = require("gleb.file_tree.view")
local render = require("gleb.file_tree.render")
local model = require("gleb.file_tree.model")
local fs = require("gleb.file_tree.fs")
local git = require("gleb.file_tree.git")
local watch = require("gleb.file_tree.watch")
local nesting = require("gleb.file_tree.nesting")
local ignore = require("gleb.file_tree.ignore")

local C = {}
local function reset() C = { n = {}, t = {}, max = {}, systems = {}, waits = 0, gaps = {} } end
reset()
local function rec(name, ns)
	C.n[name] = (C.n[name] or 0) + 1
	C.t[name] = (C.t[name] or 0) + ns
	C.max[name] = math.max(C.max[name] or 0, ns)
end
local function wrap(mod, key, name)
	local orig = mod[key]
	mod[key] = function(...)
		local s = hr()
		local r = vim.F.pack_len(orig(...))
		rec(name, hr() - s)
		return vim.F.unpack_len(r)
	end
end
wrap(render, "draw", "render.draw")
wrap(model, "rows", "model.rows")
wrap(model, "has_nest", "model.has_nest")
wrap(model, "nest_parent", "model.nest_parent")
wrap(model, "parse_status", "model.parse_status")
wrap(fs, "scan", "fs.scan")
wrap(nesting, "nest", "nesting.nest")
wrap(watch, "sync", "watch.sync")
wrap(require("gleb.file_tree.expanded"), "save", "expanded.save")
wrap(require("gleb.file_tree.expanded"), "flush", "expanded.flush")
local ok_dev, dev = pcall(require, "nvim-web-devicons")
if ok_dev then wrap(dev, "get_icon", "devicons.get_icon") end
-- ignore.is_ignored: count only (hot, tiny)
do
	local orig = ignore.is_ignored
	ignore.is_ignored = function(...) C.n["ignore.is_ignored"] = (C.n["ignore.is_ignored"] or 0) + 1 return orig(...) end
end
local orig_extmark = vim.api.nvim_buf_set_extmark
vim.api.nvim_buf_set_extmark = function(buf, ns, ...)
	if ns == render.namespace then C.n["extmark(tree)"] = (C.n["extmark(tree)"] or 0) + 1 end
	return orig_extmark(buf, ns, ...)
end
local orig_set_lines = vim.api.nvim_buf_set_lines
vim.api.nvim_buf_set_lines = function(buf, s, e, strict, lines)
	if vim.bo[buf].filetype == "gleb-file-tree" then
		C.n["set_lines(tree)"] = (C.n["set_lines(tree)"] or 0) + 1
		C.n["lines_written"] = (C.n["lines_written"] or 0) + #lines
	end
	return orig_set_lines(buf, s, e, strict, lines)
end
-- vim.system: count git calls, sync waits on main thread
local orig_system = vim.system
vim.system = function(cmd, opts, on_exit)
	local key = type(cmd) == "table" and table.concat(vim.list_slice(cmd, 1, 6), " ") or tostring(cmd)
	C.systems[key] = (C.systems[key] or 0) + 1
	local started = hr()
	local obj = orig_system(cmd, opts, on_exit)
	local orig_wait = obj.wait
	obj.wait = function(self, ...)
		local s = hr()
		local r = orig_wait(self, ...)
		C.waits = C.waits + 1
		rec("system:wait (main thread)", hr() - s)
		return r
	end
	return obj
end
-- main-thread stall monitor
local phase = "init"
local last = hr()
local mon = vim.uv.new_timer()
mon:start(2, 2, function()
	local now = hr()
	local gap = now - last
	last = now
	if gap > 16e6 then C.gaps[#C.gaps + 1] = string.format("%.1f", ms(gap)) end
end)

local out = {}
local function report(label, extra)
	local parts = { ("== %s %s"):format(label, extra or "") }
	local names = vim.tbl_keys(C.n)
	table.sort(names)
	for _, k in ipairs(names) do
		if C.t[k] then
			parts[#parts + 1] = ("  %-28s n=%-6d total=%8.2fms max=%7.2fms"):format(k, C.n[k], ms(C.t[k]), ms(C.max[k]))
		else
			parts[#parts + 1] = ("  %-28s n=%d"):format(k, C.n[k])
		end
	end
	for k, v in pairs(C.systems) do parts[#parts + 1] = ("  system[%s] x%d"):format(k, v) end
	if #C.gaps > 0 then parts[#parts + 1] = "  loop stalls>16ms: " .. table.concat(C.gaps, ",") end
	out[#out + 1] = table.concat(parts, "\n")
end
local function settle(t) vim.wait(t or 800, function() return false end, 5) end
local function V() return view.state.by_tab[vim.api.nvim_get_current_tabpage()] end
local function timed(label, fn, settle_ms)
	reset(); last = hr()
	local s = hr()
	fn()
	local sync = ms(hr() - s)
	settle(settle_ms)
	report(label, ("sync=%.2fms rows=%d"):format(sync, V() and #V().rows or -1))
end

-- 1. open
vim.cmd.cd(ROOT)
vim.cmd.edit(vim.fn.fnameescape(ROOT .. "/" .. EDIT))
settle(500)
reset(); last = hr()
local s = hr()
view.toggle()
local sync_open = ms(hr() - s)
vim.wait(5000, function() return V() and #V().rows > 0 end, 1)
local first_paint = ms(hr() - s)
settle(1500)
report("open", ("toggle sync=%.2fms first_paint=%.2fms rows=%d"):format(sync_open, first_paint, #V().rows))
local v = V()
vim.api.nvim_set_current_win(v.win)

-- wrap the git callback and watcher redraw to time timer-driven draws
local groot = git.state.roots[v.root]
for owner, cb in pairs(groot.callbacks) do
	groot.callbacks[owner] = function() local t = hr() cb() rec("git-callback draw", hr() - t) end
end
local orig_sync = watch.sync
watch.sync = function(root, owner, paths, redraw, refresh_git)
	return orig_sync(root, owner, paths, function(p) local t = hr() redraw(p) rec("watch redraw", hr() - t) end, function()
		C.n["watch->git.request"] = (C.n["watch->git.request"] or 0) + 1
		refresh_git()
	end)
end

-- 2. idle 3s (storms?)
timed("idle 3s", function() end, 3000)

-- 3. expand/collapse each top-level dir
local function find_row(pred)
	for i, r in ipairs(V().rows) do if pred(r) then return i, r end end
end
local dirs = {}
for i, r in ipairs(V().rows) do if r.kind == "directory" and r.depth == 0 and not r.ignored and not r.empty and not r.expanded then dirs[#dirs + 1] = r.path end end
for i = 1, math.min(4, #dirs) do
	local idx = find_row(function(r) return r.kind ~= "root" and r.path == dirs[i] end)
	vim.api.nvim_win_set_cursor(v.win, { idx, 0 })
	timed("expand " .. vim.fs.basename(dirs[i]), function() view.open() end, 300)
end
local idx = find_row(function(r) return r.kind ~= "root" and r.path == dirs[1] end)
vim.api.nvim_win_set_cursor(v.win, { idx, 0 })
timed("collapse " .. vim.fs.basename(dirs[1]), function() view.close_node() end, 300)

-- 4. j/k and scroll (keys through typeahead, autocmds fire)
vim.api.nvim_win_set_cursor(v.win, { 1, 0 })
local cm = vim.api.nvim_get_autocmds({ event = { "CursorMoved" } })
timed("50x j", function() for _ = 1, 50 do vim.api.nvim_feedkeys("j", "xt", false) end end, 200)
timed("50x k", function() for _ = 1, 50 do vim.api.nvim_feedkeys("k", "xt", false) end end, 200)
do -- explicit CursorMoved autocmd cost in tree window
	reset()
	local t = hr()
	for _ = 1, 50 do vim.api.nvim_exec_autocmds("CursorMoved", { buffer = v.buf }) end
	out[#out + 1] = ("== CursorMoved autocmds=%d, 50x exec=%.2fms"):format(#cm, ms(hr() - t))
end
timed("10x <C-d>", function() for _ = 1, 10 do vim.api.nvim_feedkeys(vim.keycode("<C-d>"), "xt", false) end end, 200)

-- 5. unfold all (worst-case rows)
if os.getenv("FT_UNFOLD") then timed("unfold_all", function() view.unfold_all() end, 800) else
  -- expand every directory directly (no O(n^2) unfold), capped
  local all = {}
  local function walk(d, rel, depth)
    if depth > 6 then return end
    for name, t in vim.fs.dir(d) do
      if t == "directory" and name ~= ".git" and name ~= "node_modules" and name ~= ".tests" then
        local r = rel == "" and name or rel .. "/" .. name
        all[#all+1] = r; walk(d .. "/" .. name, r, depth + 1)
      end
    end
  end
  walk(V().root, "", 0)
  table.sort(all)
  local cap = tonumber(os.getenv("FT_CAP") or "400")
  for i = 1, math.min(cap, #all) do V().expanded[all[i]] = true end
  timed("redraw with expanded set (" .. math.min(cap,#all) .. " dirs)", function() view.redraw_all() end, 800)
end
vim.api.nvim_win_set_cursor(v.win, { 1, 0 })
timed("50x j (big)", function() for _ = 1, 50 do vim.api.nvim_feedkeys("j", "xt", false) end end, 200)
do
	local d
	for _, r in ipairs(V().rows) do if r.kind == "directory" and r.expanded and r.depth >= 1 then d = r end end
	if d then
		local i = find_row(function(r) return r == d end)
		vim.api.nvim_win_set_cursor(v.win, { i, 0 })
		timed("collapse one (big)", function() view.toggle_fold() end, 300)
		timed("expand one (big)", function() view.toggle_fold() end, 300)
	end
end
local big_rows = #V().rows
do
  local prof = require("jit.profile")
  local leaf, stack = {}, {}
  prof.start("li1", function(th, samples)
    local l = prof.dumpstack(th, "pl", 1)
    leaf[l] = (leaf[l] or 0) + samples
    local st = prof.dumpstack(th, "pF;", -12)
    for fr in st:gmatch("[^;]+") do if fr:find("file_tree") then stack[fr] = (stack[fr] or 0) + samples end end
  end)
  for _ = 1, 3 do view.redraw_all() end
  prof.stop()
  local function top(t, n, label)
    local ks = vim.tbl_keys(t); table.sort(ks, function(a, b) return t[a] > t[b] end)
    local lines = { "== profile " .. label }
    for i = 1, math.min(n, #ks) do lines[#lines+1] = ("  %5d %s"):format(t[ks[i]], ks[i]) end
    out[#out+1] = table.concat(lines, "\n")
  end
  top(leaf, 15, "leaf lines (3 redraws, 1ms samples)")
  top(stack, 15, "inclusive file_tree funcs")
end

-- 6. file write in editor (repo is a scratch copy)
local editor = view.eligible_editor(v)
vim.api.nvim_set_current_win(editor)
vim.cmd.edit(vim.fn.fnameescape(ROOT .. "/" .. EDIT))
settle(300)
timed("write (BufWritePost+watch+git)", function()
	vim.api.nvim_buf_set_lines(0, 0, 0, false, { "// probe " .. hr() })
	vim.cmd("silent write")
end, 1500)
-- 7. BufEnter follow: switch to another file
local other = vim.fs.find(function(n) return n:match("%.lua$") or n:match("%.go$") end, { path = ROOT .. "/" .. vim.fs.dirname(EDIT), type = "file", limit = 2 })
if other[2] then timed("edit other file (follow)", function() vim.cmd.edit(vim.fn.fnameescape(other[2])) end, 600) end
-- 8. git refresh only
timed("git.refresh", function() git.refresh(v.root) end, 800)
-- 9. watcher storm: 200 files in the edited file's directory
local dir = ROOT .. "/" .. vim.fs.dirname(EDIT)
timed("storm 200 files", function()
	for i = 1, 200 do
		local f = io.open(("%s/zz_probe_%03d.tmp"):format(dir, i), "w"); f:write("x"); f:close()
		if i % 20 == 0 then vim.wait(20, function() return false end, 1) end
	end
end, 1500)
timed("storm delete 200", function()
	for i = 1, 200 do os.remove(("%s/zz_probe_%03d.tmp"):format(dir, i)) if i % 20 == 0 then vim.wait(20, function() return false end, 1) end end
end, 1500)
mon:stop()
print(("ROOT=%s big_rows=%d"):format(ROOT, big_rows))
print(table.concat(out, "\n"))
