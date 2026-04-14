#!/bin/bash
# Show detailed run info including annotations (read-only)
# Usage: ci-run-detail.sh [run-id]
set -e
RUN_ID="${1:-$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')}"
echo "=== Run $RUN_ID ==="
gh run view "$RUN_ID" --json status,conclusion,event,headSha,createdAt,updatedAt --jq '.'
echo ""
echo "=== Jobs ==="
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | "\(.name): \(.conclusion) (\(.startedAt) → \(.completedAt)) steps=\(.steps | length)"'
echo ""
echo "=== Annotations ==="
gh api "repos/{owner}/{repo}/check-runs?check_suite_id=$(gh api repos/{owner}/{repo}/actions/runs/$RUN_ID --jq '.check_suite_id')" --jq '.check_runs[].output | select(.annotations_count > 0) | .annotations[]' 2>/dev/null || echo "(none)"
