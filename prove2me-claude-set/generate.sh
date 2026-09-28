#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  printf 'Usage: %s <published-claude-workload-ref> <published-prove2me-mixin-ref>\n' "$0" >&2
  exit 2
fi

for ref in "$@"; do
  if [[ ! "$ref" =~ ^[A-Za-z0-9._/@:-]+$ || "$ref" != *:* ]]; then
    printf 'Expected a published image reference, got: %s\n' "$ref" >&2
    exit 2
  fi
done

cat > "$(dirname "$0")/prove2me-claude-set.yaml" <<EOF
# syntax=docker/sandbox-kit:3
schemaVersion: "3"
kind: set
displayName: Prove2Me Claude Code
description: Claude Code with the pinned Prove2Me Lean environment
version: "0.1.1"

kits:
  - ref: $1
  - ref: $2
EOF
