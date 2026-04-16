#!/bin/bash
# Push to remote and wait for CI to pass or fail.
# Usage: push-deploy.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Pushing to remote..."
git push

# Brief pause for GitHub to register the run
sleep 3

RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
echo "CI run: $RUN_ID"
echo "https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$RUN_ID"
echo ""

exec "$SCRIPT_DIR/ci-wait.sh" "$RUN_ID" 15
