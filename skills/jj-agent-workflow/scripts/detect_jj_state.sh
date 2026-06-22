#!/usr/bin/env bash
# detect_jj_state.sh — Report the version-control state of the current directory
# so an agent can pick the right workflow (jj vs Git, colocated or not).
#
# Exit status: 0 on success (including "no VCS here"); 2 only on a real error
# (bad arguments). Missing tools or missing repos are reported, never fatal.
#
# Usage: detect_jj_state.sh [--json]
#
# MODE is one of: colocated | jj-only | git-only | none
#   colocated : .jj/ and a working .git/ at the same root -> mutate with jj, read with git
#   jj-only   : .jj/ present, git backend lives inside .jj/ -> use jj; raw git will not see state
#   git-only  : a Git repo, no .jj/ -> use Git; do not introduce jj unless asked
#   none      : neither -> do not invent a VCS workflow
set -uo pipefail

json=false
case "${1:-}" in
  --json) json=true ;;
  "") ;;
  -h | --help)
    sed -n '2,16p' "$0"
    exit 0
    ;;
  *)
    echo "error: unknown argument: $1" >&2
    exit 2
    ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

git_root=""
jj_root=""
git_dir=""
mode="none"
colocated=false
default_branch=""
jj_version=""
paginate=""
wc_state="unknown"

if have git; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if have jj; then
  jj_version="$(jj --version 2>/dev/null | awk '{print $2}')"
  jj_root="$(jj root 2>/dev/null || true)"
  if [[ -n "$jj_root" ]]; then
    git_dir="$(jj git root 2>/dev/null || true)"
    paginate="$(jj config get ui.paginate 2>/dev/null || true)"
  fi
fi

# Mode + colocation. A colocated repo has a real .git/ at the workspace root;
# a non-colocated jj repo keeps its Git backend inside .jj/.
if [[ -n "$jj_root" ]]; then
  if [[ -d "$jj_root/.git" || -f "$jj_root/.git" ]]; then
    mode="colocated"
    colocated=true
  else
    mode="jj-only"
  fi
elif [[ -n "$git_root" ]]; then
  mode="git-only"
fi

# Best-effort default branch (the PR/rebase target).
if [[ "$mode" == "git-only" ]]; then
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
elif [[ -n "$jj_root" ]]; then
  default_branch="$(jj bookmark list --all-remotes 2>/dev/null | sed -n 's/^\(main\|master\|trunk\)[@:].*/\1/p' | head -1 || true)"
fi
[[ -z "$default_branch" ]] && default_branch="unknown"

# Working-copy state (jj repos only): clean / dirty / conflicted.
if [[ -n "$jj_root" ]]; then
  st="$(jj --no-pager status 2>/dev/null || true)"
  if printf '%s' "$st" | grep -qi 'unresolved conflicts'; then
    wc_state="conflicted"
  elif printf '%s' "$st" | grep -qiE 'working copy changes|^[AM] '; then
    wc_state="dirty"
  else
    wc_state="clean"
  fi
fi

if $json; then
  printf '{'
  printf '"mode":"%s",' "$mode"
  printf '"colocated":%s,' "$colocated"
  printf '"git_root":"%s",' "$git_root"
  printf '"jj_root":"%s",' "$jj_root"
  printf '"git_dir":"%s",' "$git_dir"
  printf '"jj_version":"%s",' "$jj_version"
  printf '"ui_paginate":"%s",' "$paginate"
  printf '"default_branch":"%s",' "$default_branch"
  printf '"working_copy":"%s"' "$wc_state"
  printf '}\n'
else
  echo "mode:            $mode"
  echo "colocated:       $colocated"
  echo "git_root:        ${git_root:-<none>}"
  echo "jj_root:         ${jj_root:-<none>}"
  echo "git_dir:         ${git_dir:-<none>}"
  echo "jj_version:      ${jj_version:-<jj not installed>}"
  echo "ui.paginate:     ${paginate:-<unset — set 'never' for agents>}"
  echo "default_branch:  $default_branch"
  echo "working_copy:    $wc_state"
fi

exit 0
