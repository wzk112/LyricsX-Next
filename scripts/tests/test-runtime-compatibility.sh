#!/bin/bash
# Exercise the guard against real Mach-O imports, not source-text fixtures.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK="$PROJECT_ROOT/scripts/check-runtime-compatibility.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Test App.app/Contents/MacOS" "$WORK/Test App.app/Contents/Frameworks"
cat > "$WORK/clean.c" <<'C'
int main(void) { return 0; }
C
cat > "$WORK/bad.c" <<'C'
extern void disabled(void) __asm__("_$s2os6LoggerV8disabledACvgZ");
void fixture(void) { disabled(); }
C
xcrun clang "$WORK/clean.c" -o "$WORK/Test App.app/Contents/MacOS/App"
xcrun clang -dynamiclib -Wl,-undefined,dynamic_lookup "$WORK/bad.c" -o "$WORK/bad.dylib"
bash "$CHECK" "$WORK/Test App.app"
bash "$CHECK" "$WORK/Test App.app/Contents/MacOS/App"
expect_rejection() {
  if bash "$CHECK" "$1" > "$WORK/rejection.log" 2>&1; then
    echo "Expected compatibility guard to reject $1" >&2
    exit 1
  fi
  /usr/bin/grep -q "$2" "$WORK/rejection.log"
}
expect_rejection "$WORK/bad.dylib" 'os.Logger.disabled'
cp "$WORK/bad.dylib" "$WORK/Test App.app/Contents/Frameworks/Nested Library.dylib"
expect_rejection "$WORK/Test App.app" 'Nested Library.dylib'
expect_rejection "$WORK/clean.c" 'No Mach-O'
expect_rejection "$WORK/missing.app" 'Usage:'
echo "Runtime compatibility guard regression tests passed (6 checks)."
