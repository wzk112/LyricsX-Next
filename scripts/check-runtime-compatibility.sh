#!/bin/bash
# Regression guard for #10. SDK availability annotations did not prevent this
# missing-symbol crash; inspect linked imports, including bundled helpers.
# This is a known-symbol check, not a replacement for running on macOS 26.0.
set -euo pipefail
if [[ $# -ne 1 || ! -e "$1" ]]; then
  echo "Usage: scripts/check-runtime-compatibility.sh <app-bundle-or-Mach-O>" >&2
  exit 2
fi
checked=0
failed=0
check_binary() {
  local binary="$1" description imports
  description="$(/usr/bin/file -b "$binary")"
  [[ "$description" == *Mach-O* ]] || return 0
  checked=$((checked + 1))
  if ! imports="$(/usr/bin/nm -arch all -u "$binary")"; then
    echo "Cannot inspect runtime imports: $binary" >&2
    failed=1
    return
  fi
  # Match getter/addressor variants and weak imports too. Merely guarding a
  # call with #available cannot be trusted when the SDK annotation is wrong.
  if [[ "$imports" == *'_$s2os6LoggerV8disabled'* ]]; then
    echo "Incompatible runtime import: os.Logger.disabled in $binary (issue #10, macOS 26.0)." >&2
    failed=1
  fi
}
if [[ -d "$1" ]]; then
  # Materialize the file list so enumeration failures cannot silently pass.
  listing="$(mktemp)"
  trap 'rm -f "$listing"' EXIT
  /usr/bin/find "$1" -type f -print0 > "$listing"
  while IFS= read -r -d '' binary; do
    check_binary "$binary"
  done < "$listing"
else
  check_binary "$1"
fi
if [[ "$checked" -eq 0 ]]; then
  echo "No Mach-O binaries found: $1" >&2
  exit 1
fi
[[ "$failed" -eq 0 ]] || exit 1
echo "Runtime compatibility guard passed for $checked Mach-O binaries (issue #10)."
