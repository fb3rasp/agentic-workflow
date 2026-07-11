#!/usr/bin/env bash
# test-hooks.sh — behavioral tests for shared/hooks/*.sh. Hermetic: a fake curl on
# PATH serves canned npm-registry responses, so no network is needed.
#
#   ./build/test-hooks.sh        # run locally (macOS/BSD or Linux/GNU) or in CI
#
# Exits non-zero if any case fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/shared/hooks"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

check() { # $1=name  $2=expected  $3=actual
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); echo "  ok:   $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected '$2', got '$3')"
  fi
}

# ISO-8601 timestamp N days ago (BSD or GNU date — same duality as the hooks).
days_ago() {
  date -u -v-"$1"d +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null \
    || date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%S.000Z
}

# --- fake curl: logs each requested URL, serves canned packuments --------------
mkdir -p "$TMP/bin"
CURL_LOG="$TMP/curl.log"
: > "$CURL_LOG"

cat > "$TMP/fresh.json" <<JSON
{ "dist-tags": { "latest": "9.9.9" }, "time": { "9.9.9": "$(days_ago 2)" } }
JSON
cat > "$TMP/old.json" <<JSON
{ "dist-tags": { "latest": "1.0.0" }, "time": { "1.0.0": "$(days_ago 100)" } }
JSON

cat > "$TMP/bin/curl" <<FAKE
#!/usr/bin/env bash
# fake curl for test-hooks.sh — the URL is the last argument
url="\${*: -1}"
echo "\$url" >> "$CURL_LOG"
case "\$url" in
  *fresh-pkg*) cat "$TMP/fresh.json" ;;
  *old-pkg*)   cat "$TMP/old.json" ;;
  *)           exit 22 ;;
esac
FAKE
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"

curl_calls() { wc -l < "$CURL_LOG" | tr -d ' '; }
reset_log()  { : > "$CURL_LOG"; }

# --- dep-age-guard --------------------------------------------------------------
G="$HOOKS/dep-age-guard.sh"
run_guard() { bash "$G" "$1" </dev/null >/dev/null 2>&1; echo $?; }

echo "== dep-age-guard"
reset_log
check "non-install command passes"           0 "$(run_guard 'git status')"
check "  no registry lookups"                0 "$(curl_calls)"

reset_log
check "chained non-package tokens pass"      0 "$(run_guard 'npm install && npm run build')"
check "  no registry lookups"                0 "$(curl_calls)"

reset_log
check "old package passes"                   0 "$(run_guard 'npm install old-pkg')"
check "  exactly one lookup"                 1 "$(curl_calls)"

reset_log
check "fresh package blocked"                2 "$(run_guard 'npm install fresh-pkg')"

reset_log
check "scoped fresh package blocked"         2 "$(run_guard 'npm install @scope/fresh-pkg')"
check "  scope slash URL-encoded"            0 "$(grep -q '@scope%2Ffresh-pkg' "$CURL_LOG"; echo $?)"

reset_log
check "pnpm add fresh package blocked"       2 "$(run_guard 'pnpm add fresh-pkg')"
check "yarn add fresh package blocked"       2 "$(run_guard 'yarn add fresh-pkg')"

reset_log
check "install segment isolated in chain"    0 "$(run_guard 'git add x && npm install old-pkg')"
check "  only the package looked up"         1 "$(curl_calls)"
check "  chain operand not looked up"        1 "$(grep -c 'old-pkg' "$CURL_LOG" | tr -d ' ')"

reset_log
printf '%s' '{"tool_input":{"command":"npm install fresh-pkg"}}' \
  | bash "$G" >/dev/null 2>&1
check "stdin JSON command blocked (jq path)" 2 "$?"

# --- run-tests --------------------------------------------------------------------
R="$HOOKS/run-tests.sh"
PROJ="$TMP/proj"
mkdir -p "$PROJ"

echo "== run-tests"
echo '{"scripts":{"test":"echo assertion-boom && exit 1"}}' > "$PROJ/package.json"
CLAUDE_PROJECT_DIR="$PROJ" bash "$R" </dev/null >/dev/null 2>"$TMP/rt.err"
check "failing suite blocks the stop"        2 "$?"
check "  failure output fed back on stderr"  0 "$(grep -q 'assertion-boom' "$TMP/rt.err"; echo $?)"

echo '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$R" >/dev/null 2>&1
check "stop_hook_active loop guard"          0 "$?"

RUN_TESTS_SKIP=1 CLAUDE_PROJECT_DIR="$PROJ" bash "$R" </dev/null >/dev/null 2>&1
check "RUN_TESTS_SKIP bypass"                0 "$?"

echo '{"scripts":{"test":"echo all-green && exit 0"}}' > "$PROJ/package.json"
CLAUDE_PROJECT_DIR="$PROJ" bash "$R" </dev/null >/dev/null 2>&1
check "passing suite allows the stop"        0 "$?"

rm "$PROJ/package.json"
CLAUDE_PROJECT_DIR="$PROJ" bash "$R" </dev/null >/dev/null 2>&1
check "no recognised test setup skips"       0 "$?"

# --- format-changed -----------------------------------------------------------------
F="$HOOKS/format-changed.sh"

echo "== format-changed"
bash "$F" </dev/null >/dev/null 2>&1
check "no file path"                         0 "$?"
bash "$F" /nonexistent/file.ts </dev/null >/dev/null 2>&1
check "nonexistent file"                     0 "$?"

# --- summary ------------------------------------------------------------------------
echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
