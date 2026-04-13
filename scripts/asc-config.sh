#!/bin/bash
# Shared ASC config — sourced by all asc-*.sh scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

ASC_KEY_ID="V92Q946H8M"
ASC_ISSUER_ID="$(cat "$REPO_DIR/apple-issuer-id.txt")"
ASC_KEY_FILE="$REPO_DIR/AuthKey_${ASC_KEY_ID}.p8"

if [ ! -f "$ASC_KEY_FILE" ]; then
  echo "API key not found: $ASC_KEY_FILE" >&2
  exit 1
fi
