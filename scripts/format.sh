#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

TARGETS=(Sources Tests)

if [[ "${1:-}" == "--lint" ]]; then
    swift format lint --strict --recursive "${TARGETS[@]}"
else
    swift format --in-place --recursive "${TARGETS[@]}"
fi
