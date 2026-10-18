# Shared by the test scripts (source it): PASS / FAIL / SKIP lines and a count of failures.
# shellcheck shell=bash
failures=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*"
  failures=$((failures + 1))
}
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$*"; }
# check "description" command...   passes when the command succeeds
check() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}
# expect "description" "actual" "wanted"
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: got [$2], wanted [$3]"; fi
}
