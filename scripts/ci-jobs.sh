#!/bin/bash
# Show job results for a CI run (read-only)
# Usage: ci-jobs.sh <run-id>
# If no run-id, uses the latest run
RUN_ID="${1:-$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')}"
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | {name: .name, conclusion: .conclusion}'
