#!/bin/bash
# Poll a CI run until completion (read-only)
# Usage: ci-wait.sh [run-id] [poll-interval-seconds]
# If no run-id, uses the latest run
set -e

RUN_ID="${1:-$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')}"
INTERVAL="${2:-15}"

echo "Watching run $RUN_ID (polling every ${INTERVAL}s)"

while true; do
  STATUS=$(gh run view "$RUN_ID" --json status,conclusion --jq '"\(.status) \(.conclusion)"')
  read -r RUN_STATUS CONCLUSION <<< "$STATUS"

  if [ "$RUN_STATUS" = "completed" ]; then
    JOBS=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[] | "  \(.name): \(.conclusion)"')
    echo ""
    echo "Run $RUN_ID: $CONCLUSION"
    echo "$JOBS"
    if [ "$CONCLUSION" = "success" ]; then
      exit 0
    else
      exit 1
    fi
  fi

  JOBS=$(gh run view "$RUN_ID" --json jobs --jq '[.jobs[] | select(.status=="in_progress") | .name] | join(", ")')
  echo "$(date +%H:%M:%S) in_progress: ${JOBS:-waiting...}"
  sleep "$INTERVAL"
done
