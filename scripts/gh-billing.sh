#!/bin/bash
# Check GitHub Actions billing and usage (read-only)
set -e

USERNAME=$(gh api /user --jq '.login')
echo "User: $USERNAME"
echo ""

echo "=== Repo Visibility ==="
gh repo view --json visibility,name --jq '"\(.name): \(.visibility)"'

echo ""
echo "=== Actions Billing (user) ==="
gh api "/users/$USERNAME/settings/billing/actions" 2>/dev/null || echo "(not accessible — may need admin:billing scope)"

echo ""
echo "=== Actions Billing (via settings) ==="
gh api "/user/settings/billing/actions" 2>/dev/null || echo "(not accessible)"

echo ""
echo "=== Rate Limit (to check if API is working) ==="
gh api /rate_limit --jq '{rate: .rate.remaining, limit: .rate.limit}'

echo ""
echo "=== Last Successful Run ==="
gh run list --limit 20 --json conclusion,createdAt,displayTitle --jq '[.[] | select(.conclusion=="success")] | .[0] | "\(.createdAt) \(.displayTitle)"'
