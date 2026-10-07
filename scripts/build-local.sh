#!/bin/bash
# Local installs need a persistent signing identity so TCC can recognize updates.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
identity="${LYRICSX_SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identities=()
  while IFS= read -r line; do
    if [[ "$line" =~ ([0-9A-F]{40})\ \"(Apple\ Development:|Developer\ ID\ Application:) ]]; then
      identities+=("${BASH_REMATCH[1]}")
    fi
  done < <(security find-identity -v -p codesigning)
  if [[ ${#identities[@]} -ne 1 ]]; then
    echo 'Select one existing code-signing certificate with LYRICSX_SIGN_IDENTITY; local installs do not fall back to ad-hoc signing.' >&2
    exit 1
  fi
  identity="${identities[0]}"
fi
if [[ "$identity" == '-' ]]; then
  echo 'Ad-hoc signing changes the app identity on rebuild and can invalidate audio recording permission. Use scripts/build.sh for an explicitly ad-hoc distribution build.' >&2
  exit 1
fi
export LYRICSX_SIGN_IDENTITY="$identity"
exec "$PROJECT_ROOT/scripts/build.sh" "${1:-release}"
