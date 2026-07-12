#!/usr/bin/env bash
# dep-age-guard: block installing any dependency published < MIN_AGE_DAYS ago.
#
# Wired as a PreToolUse hook on shell/Bash tool calls. Reads the proposed command
# from (in order): JSON on stdin (.tool_input.command or .command), $1, or $TOOL_COMMAND.
# Exits non-zero to block; prints the reason to stderr.
#
# Portability: Claude Code treats exit code 2 as "block". Cursor's hook protocol
# differs slightly — adjust the wiring in build/sync.sh output if needed.

set -uo pipefail

MIN_AGE_DAYS="${DEP_AGE_MIN_DAYS:-14}"

# --- resolve the command being run -------------------------------------------
CMD=""
if [ ! -t 0 ]; then
  STDIN="$(cat 2>/dev/null || true)"
  if [ -n "$STDIN" ] && command -v jq >/dev/null 2>&1; then
    CMD="$(printf '%s' "$STDIN" | jq -r '.tool_input.command // .command // empty' 2>/dev/null)"
  fi
  [ -z "$CMD" ] && CMD="$STDIN"
fi
[ -z "$CMD" ] && CMD="${1:-${TOOL_COMMAND:-}}"
[ -z "$CMD" ] && exit 0   # nothing to inspect

# --- only act on install commands --------------------------------------------
case "$CMD" in
  *"pnpm add "*|*"pnpm install "*|\
  *"npm install "*|*"npm i "*|*"npm add "*|\
  *"yarn add "*|\
  *"bun add "*|\
  *"pip install "*|*"pip3 install "*) ;;
  *) exit 0 ;;
esac

# --- extract candidate package names ------------------------------------------
# Split the command line at shell operators so tokens from other commands in a
# chain (e.g. "npm install && npm run build") are never treated as packages, and
# only collect tokens after a package manager's install/add subcommand.
PKGS=()
while IFS= read -r segment; do
  read -r -a TOKENS <<< "$segment"
  state=cmd   # cmd -> pm -> install
  for tok in "${TOKENS[@]}"; do
    case "$state" in
      cmd)
        case "$tok" in
          npm|pnpm|yarn|bun|pip|pip3) state=pm ;;
          sudo|*=*) ;;                 # env assignments / sudo prefix
          *) break ;;                  # segment isn't a package-manager command
        esac ;;
      pm)
        case "$tok" in
          install|i|add) state=install ;;
          -*) ;;                       # global flags before the subcommand
          *) break ;;                  # some other subcommand (run, test, ...)
        esac ;;
      install)
        case "$tok" in
          -*|*=*) ;;                   # flags and assignments
          *) PKGS+=("$tok") ;;
        esac ;;
    esac
  done
done < <(printf '%s\n' "$CMD" | sed -E 's/\|\||&&|;|\|/\n/g')
[ "${#PKGS[@]}" -eq 0 ] && exit 0

now_epoch="$(date +%s)"
blocked=()

for pkg in "${PKGS[@]}"; do
  case "$pkg" in ./*|/*|*://*|.) continue ;; esac   # skip local paths/urls

  # strip version specifier: lodash@1.2.3 -> lodash, @scope/pkg@1.2.3 -> @scope/pkg
  if [ "${pkg:0:1}" = "@" ]; then
    rest="${pkg:1}"
    case "$rest" in
      *@*) name="@${rest%@*}" ;;
      *)   name="$pkg" ;;
    esac
  else
    name="${pkg%@*}"
  fi

  # npm registry: publish time of the latest version ("/" in scoped names -> %2F)
  published=""
  if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    meta="$(curl -fsSL "https://registry.npmjs.org/${name/\//%2F}" 2>/dev/null)"
    if [ -n "$meta" ]; then
      latest="$(printf '%s' "$meta" | jq -r '."dist-tags".latest // empty')"
      [ -n "$latest" ] && published="$(printf '%s' "$meta" | jq -r --arg v "$latest" '.time[$v] // empty')"
    fi
  fi
  [ -z "$published" ] && continue   # can't determine age (e.g. pip) -> don't block

  pub_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%S" "${published%.*}" +%s 2>/dev/null \
            || date -d "$published" +%s 2>/dev/null || echo "")"
  [ -z "$pub_epoch" ] && continue

  age_days=$(( (now_epoch - pub_epoch) / 86400 ))
  if [ "$age_days" -lt "$MIN_AGE_DAYS" ]; then
    blocked+=("$name (latest published ${age_days}d ago)")
  fi
done

if [ "${#blocked[@]}" -gt 0 ]; then
  {
    echo "BLOCKED by dep-age-guard: package(s) younger than ${MIN_AGE_DAYS} days:"
    for b in "${blocked[@]}"; do echo "  - $b"; done
    echo "Policy: do not install dependencies published < ${MIN_AGE_DAYS} days ago (supply-chain risk)."
  } >&2
  exit 2
fi

exit 0
