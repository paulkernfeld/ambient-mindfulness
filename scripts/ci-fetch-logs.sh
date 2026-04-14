#!/bin/bash
# Download CI run logs to .ci-logs/ for local analysis (read-only)
# Usage: ci-fetch-logs.sh [run-id]
# If no run-id, uses the latest run
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$REPO_DIR/.ci-logs"

RUN_ID="${1:-$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')}"
mkdir -p "$LOG_DIR"

echo "Fetching logs for run $RUN_ID..."
gh run view "$RUN_ID" --json jobs,status,conclusion > "$LOG_DIR/summary.json" 2>&1

# Fetch logs per job via API (more reliable than --log)
for JOB_ID in $(gh run view "$RUN_ID" --json jobs --jq '.jobs[].databaseId'); do
  JOB_NAME=$(gh run view "$RUN_ID" --json jobs --jq ".jobs[] | select(.databaseId==$JOB_ID) | .name")
  gh api "repos/{owner}/{repo}/actions/jobs/$JOB_ID/logs" > "$LOG_DIR/$JOB_NAME.log" 2>&1 || true
done

echo "Logs saved to .ci-logs/"
echo "  full.log    $(wc -l < "$LOG_DIR/full.log") lines"
echo "  failed.log  $(wc -l < "$LOG_DIR/failed.log") lines"
echo "  summary.json"
