#!/usr/bin/env bash
# smoke_test.sh — end-to-end proof that the jujutsu-workflow skill's instructions
# actually work against a real jj repo + Git remote. Asserts the behaviors the
# SKILL.md and references claim.
#
# Requires: jj on PATH (skips cleanly if absent), git. Uses an isolated temp dir
# and an isolated JJ_CONFIG, so it never touches your real repos or config.
#
# Exit: 0 = all assertions passed, 1 = a failure, 2 = setup error.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DET="$ROOT/skills/jujutsu-workflow/scripts/detect_jj_state.sh"
VH="$ROOT/skills/jujutsu-workflow/scripts/verify_handoff.sh"

if ! command -v jj >/dev/null 2>&1; then
  echo "SKIP: jj is not installed — install jj to run the smoke test."
  exit 0
fi
command -v git >/dev/null 2>&1 || {
  echo "setup error: git missing" >&2
  exit 2
}

pass=0
fail=0
ok() {
  echo "PASS: $1"
  pass=$((pass + 1))
}
ng() {
  echo "FAIL: $1"
  fail=$((fail + 1))
}
# check "desc" "$actual" "$expected"
check() {
  if [[ "$2" == "$3" ]]; then ok "$1 ($2)"; else ng "$1 (got '$2', want '$3')"; fi
}
# expect_exit "desc" want_code cmd...
expect_exit() {
  local desc="$1" want="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  if [[ "$got" -eq "$want" ]]; then ok "$desc (exit $got)"; else ng "$desc (exit $got, want $want)"; fi
}
# count revisions matching a revset
revcount() { jj --no-pager log --no-graph -r "$1" -T '"x\n"' 2>/dev/null | grep -c x; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export JJ_CONFIG="$TMP/jjconfig.toml"
cat >"$JJ_CONFIG" <<'EOF'
[user]
name = "Smoke Test"
email = "smoke@example.com"
[ui]
paginate = "never"
EOF

# --- set up a bare remote with a 'main' branch, then a colocated working repo ---
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/seed"
git -C "$TMP/seed" -c user.name=S -c user.email=s@e.de commit -q --allow-empty -m "chore: init"
git -C "$TMP/seed" branch -M main
git -C "$TMP/seed" push -q origin main
git clone -q "$TMP/origin.git" "$TMP/work"
cd "$TMP/work" || {
  echo "setup error: cannot cd to work" >&2
  exit 2
}
jj git init --colocate >/dev/null 2>&1 || {
  echo "setup error: jj git init failed" >&2
  exit 2
}

# --- A. detection reports colocated ---
mode="$("$DET" --json | sed -n 's/.*"mode":"\([^"]*\)".*/\1/p')"
check "detect_jj_state reports colocated" "$mode" "colocated"

# --- B. anti-absorption: describe + jj new keeps two separate commits ---
printf 'one\n' >unit1.txt
jj describe -m "feat: unit one" >/dev/null 2>&1
jj new -m "feat: unit two" >/dev/null 2>&1
printf 'two\n' >unit2.txt
jj --no-pager status >/dev/null 2>&1 # snapshot unit2 into @
check "anti-absorption: two separate described commits" "$(revcount 'description(substring:"feat: unit")')" "2"

# --- C. non-interactive split by path ---
jj new -m "wip: mixed" >/dev/null 2>&1
printf 'impl\n' >impl.txt
printf 'doc\n' >doc.txt
jj split impl.txt -m "feat: impl only" >/dev/null 2>&1
check "jj split created the split-off commit non-interactively" "$(revcount 'description(substring:"feat: impl only")')" "1"

# --- D. recovery: abandon then undo restores it ---
before="$(revcount 'all()')"
jj abandon -r 'description(substring:"feat: impl only")' >/dev/null 2>&1
mid="$(revcount 'all()')"
jj undo >/dev/null 2>&1
after="$(revcount 'all()')"
if [[ "$mid" -lt "$before" && "$after" -eq "$before" ]]; then
  ok "recovery: jj abandon then jj undo restored the commit ($before->$mid->$after)"
else
  ng "recovery: unexpected counts ($before->$mid->$after)"
fi

# --- E. handoff: create a bookmark and push it to the remote ---
jj bookmark create feat-smoke -r @- >/dev/null 2>&1
jj git push --bookmark feat-smoke >/dev/null 2>&1
if git --git-dir="$TMP/origin.git" show-ref --verify --quiet refs/heads/feat-smoke; then
  ok "handoff: bookmark pushed to remote (no --allow-new needed)"
else
  ng "handoff: feat-smoke not found on remote"
fi

# --- F. verify_handoff gate ---
expect_exit "verify_handoff: ready on a feature bookmark" 0 "$VH" --bookmark feat-smoke --require-bookmark
expect_exit "verify_handoff: FAILs when pushing a protected branch" 1 "$VH" --bookmark main --require-bookmark

# force a conflict and confirm the gate blocks it
base="$(jj --no-pager log --no-graph -r '@' -T 'change_id' 2>/dev/null)"
jj new "$base" -m sideA >/dev/null 2>&1
printf 'AAA\n' >conf.txt
sideA="$(jj --no-pager log --no-graph -r '@' -T 'change_id' 2>/dev/null)"
jj new "$base" -m sideB >/dev/null 2>&1
printf 'BBB\n' >conf.txt
jj rebase -s @ -d "$sideA" >/dev/null 2>&1
expect_exit "verify_handoff: FAILs on unresolved conflict" 1 "$VH"

# --- G. harness-shadowed git worktree is detected, and jj is NOT trusted there ---
# A git worktree inside the repo with no .jj/ of its own: jj walks up and answers
# for the parent workspace. This is what Claude Code's EnterWorktree creates.
git worktree add -q "$TMP/work/.claude/worktrees/harness" -b harness-wt 2>/dev/null
if [[ -d "$TMP/work/.claude/worktrees/harness" ]]; then
  (
    cd "$TMP/work/.claude/worktrees/harness" || exit 2
    printf 'edited in the worktree\n' >shadow.txt
  )
  smode="$(cd "$TMP/work/.claude/worktrees/harness" && "$DET" --json | sed -n 's/.*"mode":"\([^"]*\)".*/\1/p')"
  check "detect_jj_state flags a harness worktree as shadowed" "$smode" "worktree-shadowed"

  (cd "$TMP/work/.claude/worktrees/harness" && "$DET" >/dev/null 2>&1)
  dexit=$?
  check "detect_jj_state exits 3 in a shadowed worktree" "$dexit" "3"

  # The whole point: jj reports clean here while git sees a real untracked file.
  jjsees="$(cd "$TMP/work/.claude/worktrees/harness" && jj --no-pager status 2>/dev/null | grep -c 'shadow.txt')"
  gitsees="$(cd "$TMP/work/.claude/worktrees/harness" && git status --porcelain 2>/dev/null | grep -c 'shadow.txt')"
  if [[ "$jjsees" -eq 0 && "$gitsees" -ge 1 ]]; then
    ok "shadowed worktree: jj misses the file git sees (jj=$jjsees, git=$gitsees) — git is authoritative"
  else
    ng "shadowed worktree: expected jj to miss it and git to see it (jj=$jjsees, git=$gitsees)"
  fi

  # working_copy must come from git, not from the parent workspace's jj status.
  swc="$(cd "$TMP/work/.claude/worktrees/harness" && "$DET" --json | sed -n 's/.*"working_copy":"\([^"]*\)".*/\1/p')"
  check "shadowed worktree: working_copy reported dirty from git" "$swc" "dirty"

  # A normal (non-shadowed) checkout must not regress into the new mode.
  nmode="$(cd "$TMP/work" && "$DET" --json | sed -n 's/.*"mode":"\([^"]*\)".*/\1/p')"
  check "colocated root still detected as colocated" "$nmode" "colocated"
else
  ng "shadowed worktree: could not create the test worktree"
fi

echo "----------------------------------------"
echo "smoke_test: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
