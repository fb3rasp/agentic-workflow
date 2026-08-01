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

  # split name from version specifier:
  #   lodash            -> lodash          (no pin)
  #   lodash@1.2.3      -> lodash          pin 1.2.3
  #   @scope/pkg@1.2.3  -> @scope/pkg      pin 1.2.3
  if [ "${pkg:0:1}" = "@" ]; then
    rest="${pkg:1}"
    case "$rest" in
      *@*) name="@${rest%@*}"; want="${rest##*@}" ;;
      *)   name="$pkg";        want="" ;;
    esac
  else
    case "$pkg" in
      *@*) name="${pkg%@*}"; want="${pkg##*@}" ;;
      *)   name="$pkg";      want="" ;;
    esac
  fi

  # Only an exact version is a pin. Ranges and dist-tags (^1.2.3, ~1.2, latest,
  # next, *) can all resolve to something published minutes ago, so they are
  # judged by the latest version, as before.
  case "$want" in
    ''|*[!0-9.]*) want="" ;;
  esac

  # npm registry: publish time of the version that would actually be installed
  # ("/" in scoped names -> %2F).
  #
  # Checking the pinned version rather than always the latest is the point: the
  # policy is about installing freshly published code, and `pkg@1.61.1` does not
  # install anything published today just because the project shipped 1.62.1
  # this morning. Judging a pin by dist-tags.latest blocks every dependency on a
  # fortnightly release train regardless of which version is asked for.
  published=""
  checked=""
  if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    meta="$(curl -fsSL "https://registry.npmjs.org/${name/\//%2F}" 2>/dev/null)"
    if [ -n "$meta" ]; then
      if [ -n "$want" ]; then
        published="$(printf '%s' "$meta" | jq -r --arg v "$want" '.time[$v] // empty')"
        [ -n "$published" ] && checked="$want"
      fi
      # No pin, or a pin the registry does not know: fall back to latest, which
      # is the conservative reading rather than a free pass.
      if [ -z "$published" ]; then
        latest="$(printf '%s' "$meta" | jq -r '."dist-tags".latest // empty')"
        if [ -n "$latest" ]; then
          published="$(printf '%s' "$meta" | jq -r --arg v "$latest" '.time[$v] // empty')"
          checked="latest ${latest}"
        fi
      fi
    fi
  fi
  [ -z "$published" ] && continue   # can't determine age (e.g. pip) -> don't block

  pub_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%S" "${published%.*}" +%s 2>/dev/null \
            || date -d "$published" +%s 2>/dev/null || echo "")"
  [ -z "$pub_epoch" ] && continue

  age_days=$(( (now_epoch - pub_epoch) / 86400 ))
  if [ "$age_days" -lt "$MIN_AGE_DAYS" ]; then
    blocked+=("$name ($checked published ${age_days}d ago)")
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
