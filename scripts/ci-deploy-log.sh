#!/bin/bash
# Show deploy job logs for a CI run (read-only)
# Usage: ci-deploy-log.sh [run-id] [grep-pattern]
# If no run-id, uses the latest run
RUN_ID="${1:-$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')}"
DEPLOY_JOB_ID=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[] | select(.name=="deploy") | .databaseId')
if [ -z "$DEPLOY_JOB_ID" ]; then
  echo "No deploy job found in run $RUN_ID"
  exit 1
fi
if [ -n "$2" ]; then
  gh api "repos/{owner}/{repo}/actions/jobs/$DEPLOY_JOB_ID/logs" 2>&1 | grep -iE "$2"
else
  gh api "repos/{owner}/{repo}/actions/jobs/$DEPLOY_JOB_ID/logs" 2>&1 | tail -40
fi
