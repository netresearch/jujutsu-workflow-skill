#!/usr/bin/env bash
# detect_jj_state.sh — Report the version-control state of the current directory
# so an agent can pick the right workflow (jj vs Git, colocated or not).
#
# Exit status: 0 on success (including "no VCS here"); 2 on a real error (bad
# arguments); 3 when the working directory is a git worktree shadowed by a jj repo
# above it (see worktree-shadowed below) -- a hazard, not an error, but loud on
# purpose. Missing tools or missing repos are reported, never fatal.
#
# Usage: detect_jj_state.sh [--json]
#
# MODE is one of: colocated | jj-only | git-only | worktree-shadowed | none
#   colocated        : .jj/ and a working .git/ at the same root -> mutate with jj, read with git
#   jj-only          : .jj/ present, git backend lives inside .jj/ -> use jj; raw git will not see state
#   git-only         : a Git repo, no .jj/ -> use Git; do not introduce jj unless asked
#   worktree-shadowed: a git worktree with no .jj/ of its own, under a jj repo -> jj answers
#                      for the PARENT repo, not for this directory. Do not run jj here.
#   none             : neither -> do not invent a VCS workflow
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
shadowed=false
default_branch=""
jj_version=""
paginate=""
wc_state="unknown"
warning=""

# Resolve a possibly-relative git path to a physical absolute path.
abspath() { (cd "$1" 2>/dev/null && pwd -P) || true; }

# Escape a value for embedding in a JSON string. Paths may legally contain a
# double quote or a backslash, which would otherwise emit unparseable --json.
json_escape() {
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

git_wt_dir=""
git_common_dir=""
in_git_worktree=false
if have git; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  git_wt_dir="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
  git_common_dir="$(abspath "$(git rev-parse --git-common-dir 2>/dev/null || echo .)")"
  # A linked git worktree has its own gitdir under <common>/worktrees/<name>;
  # in a normal checkout the two paths are identical.
  if [[ -n "$git_wt_dir" && -n "$git_common_dir" && "$git_wt_dir" != "$git_common_dir" ]]; then
    in_git_worktree=true
  fi
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
#
# Checked FIRST: a git worktree with no .jj/ of its own, sitting under a jj repo.
# jj walks up, finds the parent's .jj/ and answers for the PARENT workspace --
# reads describe files this directory does not contain, and writes commit the
# parent checkout's uncommitted work. Harnesses create exactly this shape (Claude
# Code puts worktrees in .claude/worktrees/<name> inside the repo), so it is
# detected by structure, not by path.
if [[ -n "$jj_root" ]] && $in_git_worktree && [[ -n "$git_root" && "$jj_root" != "$git_root" ]]; then
  mode="worktree-shadowed"
  shadowed=true
  warning="jj answers for $jj_root, NOT for this worktree ($git_root). Do not run jj here — git is authoritative."
elif [[ -n "$jj_root" ]]; then
  if [[ -d "$jj_root/.git" || -f "$jj_root/.git" ]]; then
    mode="colocated"
    colocated=true
  else
    mode="jj-only"
  fi
elif [[ -n "$git_root" ]]; then
  mode="git-only"
fi

# Best-effort default branch (the PR/rebase target). When shadowed, ask git — jj
# would answer for the parent repo.
if [[ "$mode" == "git-only" || "$mode" == "worktree-shadowed" ]]; then
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
elif [[ -n "$jj_root" ]]; then
  default_branch="$(jj bookmark list --all-remotes 2>/dev/null | sed -n 's/^\(main\|master\|trunk\)[@:].*/\1/p' | head -1 || true)"
fi
[[ -z "$default_branch" ]] && default_branch="unknown"

# Working-copy state: clean / dirty / conflicted.
if $shadowed; then
  # Deliberately NOT `jj status` — it answers for the parent workspace and lists
  # files this directory does not contain. git is the only truthful source here.
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    wc_state="dirty"
  else
    wc_state="clean"
  fi
elif [[ -n "$jj_root" ]]; then
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
  printf '"mode":"%s",' "$(json_escape "$mode")"
  printf '"colocated":%s,' "$colocated"
  printf '"shadowed":%s,' "$shadowed"
  printf '"git_root":"%s",' "$(json_escape "$git_root")"
  printf '"jj_root":"%s",' "$(json_escape "$jj_root")"
  printf '"git_dir":"%s",' "$(json_escape "$git_dir")"
  printf '"git_worktree":%s,' "$in_git_worktree"
  printf '"jj_version":"%s",' "$(json_escape "$jj_version")"
  printf '"ui_paginate":"%s",' "$(json_escape "$paginate")"
  printf '"default_branch":"%s",' "$(json_escape "$default_branch")"
  printf '"working_copy":"%s",' "$(json_escape "$wc_state")"
  printf '"warning":"%s"' "$(json_escape "$warning")"
  printf '}\n'
else
  if $shadowed; then
    echo "WARNING: $warning"
    echo
  fi
  echo "mode:            $mode"
  echo "colocated:       $colocated"
  echo "shadowed:        $shadowed"
  echo "git_root:        ${git_root:-<none>}"
  echo "jj_root:         ${jj_root:-<none>}"
  echo "git_dir:         ${git_dir:-<none>}"
  echo "git_worktree:    $in_git_worktree"
  echo "jj_version:      ${jj_version:-<jj not installed>}"
  echo "ui.paginate:     ${paginate:-<unset — set 'never' for agents>}"
  echo "default_branch:  $default_branch"
  if $shadowed; then
    echo "working_copy:    $wc_state (per git — jj's answer would be the parent's)"
  else
    echo "working_copy:    $wc_state"
  fi
fi

$shadowed && exit 3
exit 0
