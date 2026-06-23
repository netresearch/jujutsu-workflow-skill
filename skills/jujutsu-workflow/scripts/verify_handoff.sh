#!/usr/bin/env bash
# verify_handoff.sh — Final verification gate before an agent claims a jj change
# is ready to hand off. Prints the canonical jj + Git state and FAILS (exit 1)
# if the change is not safe to hand off.
#
# Checks (in a jj repo):
#   - unresolved conflicts present                         -> FAIL
#   - a protected/default branch is the bookmark at @      -> FAIL (no direct push)
#   - --require-bookmark set but no bookmark points at @   -> FAIL
#   - working copy still has an undescribed change         -> WARN (FAIL with --strict)
#
# Exit: 0 = ready, 1 = not ready (a check failed), 2 = bad usage.
#
# Usage:
#   verify_handoff.sh [--bookmark NAME] [--protected "main master trunk develop"]
#                     [--require-bookmark] [--strict] [--json]
#
# --bookmark NAME : check this specific bookmark (the one you intend to push).
#                   Without it, candidates are the bookmarks on `@- | @`.
set -uo pipefail

protected="main master trunk develop"
bookmark=""
require_bookmark=false
strict=false
json=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --protected)
      protected="${2:-}"
      shift 2
      ;;
    --bookmark)
      bookmark="${2:-}"
      shift 2
      ;;
    --require-bookmark)
      require_bookmark=true
      shift
      ;;
    --strict)
      strict=true
      shift
      ;;
    --json)
      json=true
      shift
      ;;
    -h | --help)
      sed -n '2,21p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

if ! have jj; then
  echo "verify_handoff: jj is not installed — nothing to verify." >&2
  exit 0
fi

jj_root="$(jj root 2>/dev/null || true)"
if [[ -z "$jj_root" ]]; then
  echo "verify_handoff: not inside a jj repository — nothing to verify." >&2
  exit 0
fi

fails=()
warns=()

# 1. Unresolved conflicts.
conflicts="$(jj --no-pager resolve --list 2>/dev/null || true)"
if [[ -n "$conflicts" ]]; then
  fails+=("unresolved conflicts: $(printf '%s\n' "$conflicts" | grep -c '.') file(s)")
fi

# Candidate bookmarks that a handoff would push: an explicit --bookmark, or the
# local bookmarks on the working change / its parent (the documented push targets).
if [[ -n "$bookmark" ]]; then
  candidates="$bookmark"
else
  candidates="$(jj --no-pager log --no-graph -r '@- | @' -T 'bookmarks ++ "\n"' 2>/dev/null |
    tr ' ' '\n' | sed 's/\*$//' | grep -v '@' | sed '/^$/d' | sort -u || true)"
fi

# 2. A protected/default branch must not be a push target.
for b in $protected; do
  if printf '%s\n' "$candidates" | grep -qx "$b"; then
    fails+=("protected branch '${b}' is a push target — do not push it directly")
  fi
done

# 3. A usable (non-protected) bookmark must exist for PR handoff (opt-in).
if $require_bookmark; then
  usable="$candidates"
  for b in $protected; do
    usable="$(printf '%s\n' "$usable" | grep -vx "$b" || true)"
  done
  if [[ -z "$(printf '%s' "$usable" | tr -d '[:space:]')" ]]; then
    fails+=("no usable bookmark for handoff — create one (jj bookmark create <name> -r @-)")
  fi
fi

# 4. Undescribed working-copy change.
desc="$(jj --no-pager log --no-graph -r '@' -T 'description' 2>/dev/null || true)"
has_changes="$(jj --no-pager status 2>/dev/null | grep -ciE 'working copy changes' || true)"
if [[ -z "${desc// /}" && "$has_changes" != "0" ]]; then
  if $strict; then
    fails+=("working copy has an undescribed change — run jj describe -m '...'")
  else
    warns+=("working copy has an undescribed change (jj describe -m '...')")
  fi
fi

ready=true
[[ ${#fails[@]} -gt 0 ]] && ready=false

if $json; then
  printf '{"ready":%s,"fails":[' "$ready"
  for i in "${!fails[@]}"; do [[ $i -gt 0 ]] && printf ','; printf '"%s"' "${fails[$i]//\"/\'}"; done
  printf '],"warns":['
  for i in "${!warns[@]}"; do [[ $i -gt 0 ]] && printf ','; printf '"%s"' "${warns[$i]//\"/\'}"; done
  printf ']}\n'
else
  echo "=== handoff verification gate ==="
  echo "--- jj status ---";              jj --no-pager status 2>&1 || true
  echo "--- jj log (recent) ---";        jj --no-pager log --limit 5 2>&1 || true
  echo "--- jj diff --stat ---";         jj --no-pager diff --stat 2>&1 || true
  echo "--- git status (verify) ---";    git status --short --branch 2>&1 || true
  echo "================================"
  for w in "${warns[@]}"; do echo "WARN: $w"; done
  for f in "${fails[@]}"; do echo "FAIL: $f"; done
  if $ready; then
    echo "RESULT: ready for handoff"
  else
    echo "RESULT: NOT ready (${#fails[@]} failing check(s))"
  fi
fi

$ready && exit 0 || exit 1
