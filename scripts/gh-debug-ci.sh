#!/bin/bash
# Debug CI allocation failures — gather all available diagnostic info (read-only)
set -e

echo "=== Token Scopes ==="
gh auth status 2>&1 | head -10

echo ""
echo "=== Repo ==="
gh repo view --json visibility,name,owner --jq '{name: .name, visibility: .visibility, owner: .owner.login}'

echo ""
echo "=== Actions Permissions ==="
gh api "repos/{owner}/{repo}/actions/permissions" --jq '.' 2>/dev/null || echo "(not accessible)"

echo ""
echo "=== Billing (user) ==="
gh api "/users/$(gh api /user --jq '.login')/settings/billing/actions" 2>/dev/null || echo "(not accessible — need admin:billing scope)"

echo ""
echo "=== Latest Failed Run Detail ==="
LATEST=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh api "repos/{owner}/{repo}/actions/runs/$LATEST" --jq '{
  id: .id,
  status: .status,
  conclusion: .conclusion,
  created_at: .created_at,
  updated_at: .updated_at,
  run_started_at: .run_started_at,
  triggering_actor: .triggering_actor.login,
  head_sha: .head_sha,
  run_attempt: .run_attempt,
  workflow_id: .workflow_id
}' 2>/dev/null || echo "(not accessible)"

echo ""
echo "=== Latest Failed Job Detail ==="
JOB_ID=$(gh run view "$LATEST" --json jobs --jq '.jobs[0].databaseId')
gh api "repos/{owner}/{repo}/actions/jobs/$JOB_ID" --jq '{
  id: .id,
  status: .status,
  conclusion: .conclusion,
  started_at: .started_at,
  completed_at: .completed_at,
  runner_name: .runner_name,
  runner_id: .runner_id,
  runner_group_name: .runner_group_name,
  labels: .labels
}' 2>/dev/null || echo "(not accessible)"
