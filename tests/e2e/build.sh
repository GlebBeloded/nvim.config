#!/usr/bin/env sh
# Build the e2e key helper (tests/e2e/keys.swift) into .tests/e2e/keys, cached by
# the source hash (swiftc takes ~15 s). Prints the binary path.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
src="$root/tests/e2e/keys.swift"
out="$root/.tests/e2e"
hash=$(shasum "$src" | cut -c1-12)
bin="$out/keys-$hash"
if [ ! -x "$bin" ]; then
	mkdir -p "$out"
	rm -f "$out"/keys-*
	swiftc -O -o "$bin.tmp" "$src" >&2
	mv "$bin.tmp" "$bin"
fi
ln -sf "keys-$hash" "$out/keys"
echo "$out/keys"
