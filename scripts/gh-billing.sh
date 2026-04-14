#!/bin/bash
# Check GitHub Actions billing/quota (read-only)
set -e
echo "=== Actions Billing ==="
gh api /repos/{owner}/{repo}/actions/cache/usage --jq '.' 2>/dev/null || true
echo ""
echo "=== Actions Minutes (user level) ==="
gh api /user --jq '{plan: .plan.name, collaborators: .plan.collaborators}' 2>/dev/null || true
echo ""
echo "=== Recent run durations ==="
gh run list --limit 10 --json databaseId,conclusion,createdAt,displayTitle --jq '.[] | "\(.conclusion)\t\(.createdAt)\t\(.displayTitle)"'
