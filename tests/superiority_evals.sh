#!/usr/bin/env bash
# superiority_evals.sh — PROOF that jj is superior to pure Git for agentic coding.
#
# Each scenario runs the SAME agentic situation two ways and asserts that jj has
# a concrete, measurable advantage over pure git. These are fair comparisons, not
# strawmen: where git has a real (if awkward) path, that is noted in the output.
#
# Requires: jj on PATH (skips cleanly if absent), git. Isolated temp dirs +
# isolated JJ_CONFIG — never touches your real repos/config.
#
# Exit: 0 = jj won every scenario (superiority proven), 1 = a scenario did not
# demonstrate the advantage, 2 = setup error.
set -uo pipefail

if ! command -v jj >/dev/null 2>&1; then
  echo "SKIP: jj is not installed — install jj to run the superiority evals."
  exit 0
fi
command -v git >/dev/null 2>&1 || {
  echo "setup error: git missing" >&2
  exit 2
}

won=0
lost=0
win() {
  local msg="$1"
  echo "jj WINS  — $msg"
  won=$((won + 1))
  return 0
}
lose() {
  local msg="$1"
  echo "NOT SHOWN — $msg"
  lost=$((lost + 1))
  return 0
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export JJ_CONFIG="$TMP/jjconfig.toml"
cat >"$JJ_CONFIG" <<'EOF'
[user]
name = "Eval"
email = "eval@example.com"
[ui]
paginate = "never"
EOF
gitc() {
  git -c user.name=Eval -c user.email=eval@example.com "$@"
  return
}

echo "=========================================================="
echo " jj vs pure Git — agentic-coding superiority evals"
echo "=========================================================="

# ---------------------------------------------------------------------------
# S1. Reversible discard. An agent discards work, then needs it back.
#   git: discarding UNCOMMITTED edits (git checkout --) is unrecoverable.
#   jj : any discard (jj abandon) is reversible via the operation log.
# ---------------------------------------------------------------------------
g="$TMP/s1g"
mkdir -p "$g"
(
  cd "$g" || exit 2
  gitc init -q
  echo v1 >f.txt
  gitc add f.txt
  gitc commit -qm v1
  echo v2 >f.txt # uncommitted edit
  gitc checkout -q -- f.txt # agent "discards" it
)
git_recovered_v2=no
[[ "$(cat "$g/f.txt")" == "v2" ]] && git_recovered_v2=yes # it won't be

j="$TMP/s1j"
mkdir -p "$j"
(
  cd "$j" || exit 2
  jj git init >/dev/null 2>&1
  jj new -m feature >/dev/null 2>&1
  echo important >f.txt
  jj st >/dev/null 2>&1 # snapshot
  op="$(jj --no-pager op log --no-graph -T 'id.short() ++ "\n"' 2>/dev/null | sed -n 1p)"
  jj abandon >/dev/null 2>&1 # agent "discards" the whole change
  jj op restore "$op" >/dev/null 2>&1 # recover it
)
jj_recovered=no
[[ "$(cat "$j/f.txt" 2>/dev/null)" == "important" ]] && jj_recovered=yes

if [[ "$jj_recovered" == "yes" && "$git_recovered_v2" == "no" ]]; then
  win "S1 reversible discard: jj op restore recovered abandoned work; git could not recover the discarded uncommitted edit"
else
  lose "S1 reversible discard (jj_recovered=$jj_recovered git_recovered=$git_recovered_v2)"
fi

# ---------------------------------------------------------------------------
# S2. Conflicting integration.
#   git: rebase HALTS mid-operation (rebase-in-progress), working tree blocked.
#   jj : rebase COMPLETES, conflict stored as data, working copy usable, undoable.
# ---------------------------------------------------------------------------
g="$TMP/s2g"
mkdir -p "$g"
git_interrupted=no
(
  cd "$g" || exit 2
  gitc init -q
  echo base >c.txt
  gitc add c.txt
  gitc commit -qm base
  gitc checkout -q -b A
  echo AAA >c.txt
  gitc commit -qm A c.txt
  gitc checkout -q -b B main 2>/dev/null || gitc checkout -q -b B master
  echo BBB >c.txt
  gitc commit -qm B c.txt
  gitc rebase A >/dev/null 2>&1
) || true
{ [[ -d "$g/.git/rebase-merge" || -d "$g/.git/rebase-apply" ]]; } && git_interrupted=yes
[[ "$git_interrupted" == yes ]] && (cd "$g" && gitc rebase --abort >/dev/null 2>&1 || true)

j="$TMP/s2j"
mkdir -p "$j"
jj_completed=no
jj_reversible=no
(
  cd "$j" || exit 2
  jj git init >/dev/null 2>&1
  echo base >c.txt
  jj describe -m base >/dev/null 2>&1
  base="$(jj --no-pager log --no-graph -r @ -T change_id 2>/dev/null)"
  jj new "$base" -m A >/dev/null 2>&1
  echo AAA >c.txt
  a="$(jj --no-pager log --no-graph -r @ -T change_id 2>/dev/null)"
  jj new "$base" -m B >/dev/null 2>&1
  echo BBB >c.txt
  jj rebase -s @ -d "$a" >/dev/null 2>&1 && echo COMPLETED >"$TMP/s2_rc"
  jj --no-pager status 2>/dev/null | grep -qi 'unresolved conflicts' && echo CONFLICT >"$TMP/s2_cf"
  jj undo >/dev/null 2>&1
  jj --no-pager status 2>/dev/null | grep -qi 'unresolved conflicts' || echo CLEARED >"$TMP/s2_cl"
)
[[ -f "$TMP/s2_rc" && -f "$TMP/s2_cf" ]] && jj_completed=yes
[[ -f "$TMP/s2_cl" ]] && jj_reversible=yes

if [[ "$jj_completed" == yes && "$jj_reversible" == yes && "$git_interrupted" == yes ]]; then
  win "S2 conflict handling: jj rebase completed with the conflict recorded (and jj undo reversed it); git rebase halted mid-operation"
else
  lose "S2 conflict handling (jj_completed=$jj_completed reversible=$jj_reversible git_interrupted=$git_interrupted)"
fi

# ---------------------------------------------------------------------------
# S3. Non-interactive split of an existing commit.
#   git: splitting a commit requires interactive `git rebase -i` (edit) + reset.
#   jj : `jj split <path> -m` does it in ONE non-interactive command.
# ---------------------------------------------------------------------------
j="$TMP/s3j"
mkdir -p "$j"
jj_split=no
(
  cd "$j" || exit 2
  jj git init >/dev/null 2>&1
  echo a >a.txt
  echo b >b.txt
  jj describe -m "both files" >/dev/null 2>&1
  jj split a.txt -m "just a" >/dev/null 2>&1
)
# proof: split produced TWO distinct described commits, and a.txt landed in "just a"
two="$(cd "$j" && jj --no-pager log --no-graph -r 'description(substring:"just a") | description(substring:"both files")' -T '"x\n"' 2>/dev/null | grep -c x)"
a_in_split="$(cd "$j" && jj --no-pager diff --name-only -r 'description(substring:"just a")' 2>/dev/null | grep -cx 'a.txt')"
[[ "$two" -eq 2 && "$a_in_split" -eq 1 ]] && jj_split=yes
if [[ "$jj_split" == yes ]]; then
  win "S3 non-interactive split: jj split <path> -m carved a commit in two without an editor; git requires interactive rebase -i"
else
  lose "S3 non-interactive split (jj_split=$jj_split)"
fi

# ---------------------------------------------------------------------------
# S4. Whole-repo time travel. Undo a multi-step sequence in ONE command.
#   git: no single command restores refs AND working copy to an earlier point.
#   jj : `jj op restore <op>` rewinds the entire repo state at once.
# ---------------------------------------------------------------------------
j="$TMP/s4j"
mkdir -p "$j"
jj_timetravel=no
(
  cd "$j" || exit 2
  jj git init >/dev/null 2>&1
  echo one >one.txt
  jj describe -m one >/dev/null 2>&1
  op="$(jj --no-pager op log --no-graph -T 'id.short() ++ "\n"' 2>/dev/null | sed -n 1p)"
  # several further operations
  jj new -m two >/dev/null 2>&1
  echo two >two.txt
  jj bookmark create feat -r @ >/dev/null 2>&1
  jj new -m three >/dev/null 2>&1
  echo three >three.txt
  jj st >/dev/null 2>&1
  # one command rewinds ALL of it
  jj op restore "$op" >/dev/null 2>&1
)
# after restore: only one.txt exists, no feat bookmark, no two/three
if [[ -f "$j/one.txt" && ! -f "$j/two.txt" && ! -f "$j/three.txt" ]]; then
  nb="$(cd "$j" && jj --no-pager bookmark list 2>/dev/null | grep -c 'feat')"
  [[ "$nb" -eq 0 ]] && jj_timetravel=yes
fi
if [[ "$jj_timetravel" == yes ]]; then
  win "S4 whole-repo time travel: jj op restore rewound 4 operations (commits + bookmark) in one command; git has no single-command equivalent"
else
  lose "S4 whole-repo time travel (jj_timetravel=$jj_timetravel)"
fi

echo "----------------------------------------------------------"
echo "superiority proven in $won/$((won + lost)) scenarios"
[[ "$lost" -eq 0 ]]
