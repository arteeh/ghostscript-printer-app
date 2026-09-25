#!/usr/bin/env bash
# A promotion preserves the source commit and its exact tree.
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 BASE_SHA SOURCE_SHA MERGE_SHA" >&2
    exit 2
fi
base=$1
source=$2
merge=$3
# Reject squash/rebase promotion histories and stable-only changes.
git merge-base --is-ancestor "$base" "$source"
git merge-base --is-ancestor "$source" "$merge"
git diff --exit-code "$source" "$merge" --
printf 'Promotion source revision: %s\n' "$(git rev-parse "$source")"
