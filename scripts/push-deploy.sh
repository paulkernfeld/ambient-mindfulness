#!/bin/bash
# Push to remote and wait for CI to pass or fail.
# Tracks by commit SHA to avoid race conditions.
# Usage: push-deploy.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHA=$(git rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

echo "Pushing $SHA to remote..."
git push

echo "Waiting for CI run for $SHA..."
RUN_ID=""
for i in $(seq 1 40); do
  RUN_ID=$(gh run list --json databaseId,headSha --limit 5 -q ".[] | select(.headSha==\"$SHA\") | .databaseId")
  if [ -n "$RUN_ID" ]; then
    break
  fi
  sleep 3
done

if [ -z "$RUN_ID" ]; then
  echo "ERROR: No CI run found for $SHA after 2 minutes"
  exit 1
fi

echo "CI run: $RUN_ID"
echo "https://github.com/$REPO/actions/runs/$RUN_ID"
echo ""

exec "$SCRIPT_DIR/ci-wait.sh" "$RUN_ID" 15
