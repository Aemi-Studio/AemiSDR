#!/bin/bash
# swift-ci at the commit this repository's CI pins (.github/workflows/ci.yml): a local run checks what CI checks.
#
#   .ci/swift-ci local          the checks .ci/action.json lists in localChecks (default: quality, debug tests)
#   .ci/swift-ci run quality    one check, as CI runs it
#
# Written by `swift-ci bootstrap`; `swift-ci validate` refuses a copy that differs. SWIFT_CI_SOURCE=<checkout>
# builds that swift-ci instead of the pinned one (to try a change to swift-ci itself).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
home="${SWIFT_CI_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/swift-ci}"
if [ -n "${SWIFT_CI_SOURCE:-}" ]; then
    swift build -c release --package-path "$SWIFT_CI_SOURCE" --product swift-ci >&2
    exec "$(swift build -c release --package-path "$SWIFT_CI_SOURCE" --show-bin-path)/swift-ci" "$@" --root "$root"
fi
pin="$(grep -oE 'g-cqd/swift-ci/\.github/workflows/swift-ci\.yml@[0-9a-f]{40}' "$root/.github/workflows/ci.yml" \
    | head -n 1 | cut -d@ -f2 || true)"
if [ -z "$pin" ]; then
    echo "swift-ci: no pinned commit of g-cqd/swift-ci in .github/workflows/ci.yml" >&2
    exit 2
fi
cli="$home/$pin/swift-ci"
if [ ! -x "$cli" ]; then
    work="$(mktemp -d "${TMPDIR:-/tmp}/swift-ci-build.XXXXXX")"
    if ! (
        git -C "$work" init -q &&
            git -C "$work" fetch -q --depth 1 https://github.com/g-cqd/swift-ci.git "$pin" &&
            git -C "$work" checkout -q FETCH_HEAD &&
            swift build -c release --package-path "$work" --product swift-ci > "$work/build.log" 2>&1
    ); then
        cat "$work/build.log" >&2 2> /dev/null || true
        rm -rf "$work"
        echo "swift-ci: could not build swift-ci $pin" >&2
        exit 2
    fi
    mkdir -p "$home/$pin"
    # Copied then renamed: a concurrent run never sees a partial binary.
    cp "$(swift build -c release --package-path "$work" --show-bin-path)/swift-ci" "$cli.$$"
    mv -f "$cli.$$" "$cli"
    rm -rf "$work"
fi
exec "$cli" "$@" --root "$root"
