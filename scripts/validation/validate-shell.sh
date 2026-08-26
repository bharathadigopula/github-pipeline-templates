#!/usr/bin/env bash

#==============================================================================
# SHELL SCRIPT VALIDATION
#==============================================================================

set -euo pipefail

: "${SEARCH_PATH:?SEARCH_PATH is required}"

if [[ ! -d "$SEARCH_PATH" ]]; then
  printf 'Shell script directory does not exist: %s\n' "$SEARCH_PATH" >&2
  exit 1
fi

script_count=0
while IFS= read -r -d '' script_file; do
  bash -n "$script_file"
  shellcheck "$script_file"
  script_count=$((script_count + 1))
done < <(find "$SEARCH_PATH" -type f -name '*.sh' -print0)

if (( script_count == 0 )); then
  printf 'No shell scripts found under %s.\n' "$SEARCH_PATH" >&2
  exit 1
fi