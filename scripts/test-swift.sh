#!/bin/bash
# Run AdaptiveRate tests locally by compiling production code + test file together.
# No Xcode/XCTest needed — just swiftc.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TMPBIN=$(mktemp)
trap "rm -f $TMPBIN" EXIT

TMPDIR_BUILD=$(mktemp -d)
trap "rm -rf $TMPBIN $TMPDIR_BUILD" EXIT

# swiftc needs the main file to be literally named "main.swift"
cp "$SCRIPT_DIR/test-adaptive-rate.swift" "$TMPDIR_BUILD/main.swift"
swiftc -o "$TMPBIN" \
    "$REPO_DIR/Shared/AdaptiveRate.swift" \
    "$TMPDIR_BUILD/main.swift"
"$TMPBIN"
