#!/bin/bash
# Show repo info including visibility (read-only)
set -e
gh repo view --json visibility,name,owner --jq '.'
