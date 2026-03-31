#!/bin/bash
# Gathers metadata for research documents produced by the research-codebase skill.
# Output is key=value pairs, one per line.

echo "DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "COMMIT=$(git rev-parse HEAD)"
echo "BRANCH=$(git branch --show-current)"
echo "REPO=$(basename "$(git rev-parse --show-toplevel)")"
echo "AUTHOR=$(git config user.name)"
