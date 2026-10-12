// e2e key helper: real macOS key events for one Alacritty instance.
// Built by tests/e2e/build.sh into .tests/e2e/ (cached by source hash).
//   keys trusted [--prompt]        exit 0 if Accessibility is granted (prints true/false, responsible app)
//   keys launch <app.app> <args>   start a new instance without activating it, print its pid
//   keys frontmost                 pid of the frontmost app
//   keys focus <pid>               make <pid> frontmost (AX), print the previous frontmost pid
//   keys press <pid> <chord>...    post key events to <pid> (CGEventPostToPid), e.g. cmd+shift+h ctrl+return
// Chords use US ANSI key positions (virtual key codes), so the layout's own letters do not matter.
import ApplicationServices
import Cocoa

setvbuf(stdout, nil, _IOLBF, 0)

func fail(_ message: String) -> Never {
	FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
	exit(2)
}

func spin(_ seconds: Double) {
	RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

let KEYS: [String: CGKeyCode] = [
	"a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
	"w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
	"=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34,
	"p": 35, "return": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
	"n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50, "escape": 53, "f5": 96, "f6": 97,
	"f7": 98, "f3": 99, "f8": 100, "f9": 101, "f11": 103, "f10": 109, "f12": 111, "f4": 118, "f2": 120,
	"f1": 122, "left": 123, "right": 124, "down": 125, "up": 126,
]
// order of presses; release in reverse
let MODS: [(name: String, code: CGKeyCode, flag: CGEventFlags)] = [
	("ctrl", 59, .maskControl), ("opt", 58, .maskAlternate), ("shift", 56, .maskShift), ("cmd", 55, .maskCommand),
]
let ARROWS: Set<CGKeyCode> = [123, 124, 125, 126]

func post(_ pid: pid_t, _ source: CGEventSource, _ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags, modifier: Bool = false) {
	guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { fail("cannot create event") }
	if modifier { event.type = .flagsChanged } // what a real modifier key sends
	event.flags = flags
	event.postToPid(pid)
	usleep(4000)
}

func press(_ pid: pid_t, _ chord: String) {
	let parts = chord.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
	guard let keyName = parts.last, let code = KEYS[keyName] else { fail("unknown key in chord " + chord) }
	let names = Set(parts.dropLast())
	let mods = MODS.filter { names.contains($0.name) }
	if mods.count != names.count { fail("unknown modifier in chord " + chord) }
	guard let source = CGEventSource(stateID: .privateState) else { fail("cannot create event source") }
	var flags: CGEventFlags = []
	for mod in mods {
		flags.insert(mod.flag)
		post(pid, source, mod.code, true, flags, modifier: true)
	}
	var keyFlags = flags
	if ARROWS.contains(code) { keyFlags.formUnion([.maskNumericPad, .maskSecondaryFn]) }
	post(pid, source, code, true, keyFlags)
	post(pid, source, code, false, keyFlags)
	for mod in mods.reversed() {
		flags.remove(mod.flag)
		post(pid, source, mod.code, false, flags, modifier: true)
	}
}

func frontmost() -> pid_t {
	spin(0.01) // NSWorkspace updates frontmostApplication on the run loop
	return NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
}

/// App that macOS charges TCC permissions to (private libsystem call; nil if unavailable).
func responsibleApp() -> String {
	typealias Fn = @convention(c) (pid_t) -> pid_t
	guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else {
		return "the app running make"
	}
	let pid = unsafeBitCast(sym, to: Fn.self)(getpid())
	if let app = NSRunningApplication(processIdentifier: pid) {
		return (app.localizedName ?? "?") + " (" + (app.bundleURL?.path ?? "pid \(pid)") + ")"
	}
	var path = [CChar](repeating: 0, count: 4096)
	return proc_pidpath(pid, &path, 4096) > 0 ? String(cString: path) : "pid \(pid)"
}

func focus(_ pid: pid_t) -> Bool {
	let app = AXUIElementCreateApplication(pid)
	AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
	var windows: CFTypeRef?
	if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
		let first = (windows as? [AXUIElement])?.first
	{
		AXUIElementSetAttributeValue(first, kAXMainAttribute as CFString, kCFBooleanTrue)
		AXUIElementPerformAction(first, kAXRaiseAction as CFString)
	}
	let deadline = Date().addingTimeInterval(2)
	while Date() < deadline {
		if frontmost() == pid { return true }
		spin(0.02)
	}
	return false
}

var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { fail("usage: keys trusted|launch|frontmost|focus|press ...") }
let command = args.removeFirst()
switch command {
case "trusted":
	let prompt = args.first == "--prompt"
	let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
	let trusted = AXIsProcessTrustedWithOptions(options)
	print(trusted ? "true" : "false", responsibleApp())
	exit(trusted ? 0 : 1)
case "launch":
	guard args.count >= 1 else { fail("usage: keys launch <app.app> [args...]") }
	let config = NSWorkspace.OpenConfiguration()
	config.activates = false
	config.createsNewApplicationInstance = true
	config.addsToRecentItems = false
	config.arguments = Array(args.dropFirst())
	config.environment = ProcessInfo.processInfo.environment
	var pid: pid_t = 0
	var error: Error?
	var done = false
	NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: args[0]), configuration: config) { app, err in
		pid = app?.processIdentifier ?? 0
		error = err
		done = true
	}
	let deadline = Date().addingTimeInterval(10)
	while !done && Date() < deadline { spin(0.02) }
	if pid == 0 { fail("launch failed: " + (error.map { "\($0)" } ?? "timeout")) }
	print(pid)
case "frontmost":
	print(frontmost())
case "focus":
	guard let pid = args.first.flatMap({ pid_t($0) }) else { fail("usage: keys focus <pid>") }
	let previous = frontmost()
	if !focus(pid) { fail("could not make pid \(pid) frontmost (previous \(previous))") }
	print(previous)
case "press":
	guard let pid = args.first.flatMap({ pid_t($0) }) else { fail("usage: keys press <pid> <chord>...") }
	for chord in args.dropFirst() { press(pid, chord) }
default:
	fail("unknown command " + command)
}
