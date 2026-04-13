#!/bin/bash
# Show recent CI runs and their status (read-only)
gh run list --limit "${1:-5}"
