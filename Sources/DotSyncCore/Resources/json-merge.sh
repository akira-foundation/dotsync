#!/usr/bin/env bash
set -euo pipefail

BASE="$1"; OURS="$2"; THEIRS="$3"

if ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

jq -s '
  def deepmerge($a; $b):
    if   ($a | type) == "object" and ($b | type) == "object"
    then reduce ((($a | keys) + ($b | keys)) | unique[]) as $k
           ({}; .[$k] = deepmerge($a[$k]; $b[$k]))
    elif ($a | type) == "array" and ($b | type) == "array"
    then ($a + $b) | unique
    elif $b == null then $a
    else $b
    end;
  deepmerge(.[0]; .[1])
' "$OURS" "$THEIRS" > "$OURS.merged" && mv "$OURS.merged" "$OURS"
