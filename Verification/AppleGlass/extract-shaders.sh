#!/bin/bash
# Reverse engineering aid (ADR-0007): reads Apple's Core Animation shader library from the installed iOS simulator
# runtime and writes readable LLVM IR, one file per shader, so the native glass can be studied and measured.
#
#   Verification/AppleGlass/extract-shaders.sh [OUTPUT_DIR]      (default: ./.glass-ir, git-ignored)
#
# Nothing is copied into the repository: the output is a local working directory. Needs Xcode's Metal toolchain
# (air-nm, air-objdump). Prints the glass-related entry points and the struct offsets of their uniforms.
set -euo pipefail
unset DEVELOPER_DIR
out="${1:-.glass-ir}"

runtime_root="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
roots = [r["runtimeRoot"] for r in json.load(sys.stdin)["runtimes"] if r["name"].startswith("iOS")]
print(roots[-1] if roots else "")')"
[ -n "$runtime_root" ] || { echo "no iOS simulator runtime installed" >&2; exit 1; }
library="$runtime_root/System/Library/Frameworks/QuartzCore.framework/default.metallib"
[ -f "$library" ] || { echo "not found: $library" >&2; exit 1; }

bin="$(ls -d "$HOME"/Library/Developer/MetalToolchains/*/Metal.xctoolchain/usr/metal/current/bin 2>/dev/null | tail -1)"
[ -n "$bin" ] || bin="$(dirname "$(xcrun -f air-objdump)")"

mkdir -p "$out/ir"
cp "$library" "$out/QuartzCore.metallib"
"$bin/air-objdump" -d "$out/QuartzCore.metallib" > "$out/all.ll"
python3 - "$out" <<'PY'
import re, sys
out = sys.argv[1]
text = open(f"{out}/all.ll", errors="replace").read()
count = 0
for part in re.split(r"\n(?=0x[0-9a-f]+ -- )", text)[1:]:
    match = re.match(r"0x[0-9a-f]+ -- (\S+):", part)
    if match:
        open(f"{out}/ir/{match.group(1)}.ll", "w").write(part)
        count += 1
print(f"{count} shaders written to {out}/ir")
PY
echo "glass-related entry points:"
"$bin/air-nm" "$out/QuartzCore.metallib" | awk '{print $NF}' | grep -E 'glass|brim|rim_|sdf_|backdrop' | grep -E '_lpf$' | sed 's/_lpf$//' | tr '\n' ' '
echo
