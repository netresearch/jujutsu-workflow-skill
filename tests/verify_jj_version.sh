#!/usr/bin/env bash
# verify_jj_version.sh — Re-check every jj command, flag and revset this skill
# claims against the jj on PATH. Run it when bumping the `compatibility` field in
# SKILL.md, or when a new jj release lands.
#
# It is a compatibility PROBE, not a CI gate: it answers "do our documented
# commands still exist and still behave as written on this jj?".
# tests/smoke_test.sh remains the behavioral gate.
#
# Exit: 0 = every claim holds, 1 = at least one drifted, 2 = setup error.
set -uo pipefail

if ! command -v jj >/dev/null 2>&1; then
  echo "SKIP: jj is not installed."
  exit 0
fi
command -v git >/dev/null 2>&1 || {
  echo "setup error: git missing" >&2
  exit 2
}

ok=0
drift=0
OK() {
  printf 'OK     %s\n' "$1"
  ok=$((ok + 1))
}
DRIFT() {
  printf 'DRIFT  %s\n' "$1"
  drift=$((drift + 1))
}

# claim <ok-msg> <drift-msg> <cmd...> — the command's exit status decides.
claim() {
  local okmsg="$1" drmsg="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then OK "$okmsg"; else DRIFT "$drmsg"; fi
}

# claim_bool <ok-msg> <drift-msg> <true|false> — for conditions evaluated inline.
claim_bool() {
  if [[ "$3" == "true" ]]; then OK "$1"; else DRIFT "$2"; fi
}

# hasflag <subcommand words...> -- <flag> — e.g. hasflag git init -- --colocate
# `--help` exits 0, so the pipeline status is grep's.
hasflag() {
  local args=()
  while [[ "$1" != "--" ]]; do
    args+=("$1")
    shift
  done
  shift
  jj "${args[@]}" --help 2>&1 | grep -q -- "$1"
}
yn() { if "$@"; then echo true; else echo false; fi; }

echo "jj: $(jj --version)"
echo "=================================================="

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export JJ_CONFIG="$T/cfg.toml"
cat >"$JJ_CONFIG" <<'EOF'
[user]
name = "Compat Probe"
email = "probe@example.com"
[ui]
paginate = "never"
EOF

# ---------- init / colocation (git-interop.md) ----------
mkdir -p "$T/initdefault"
(cd "$T/initdefault" && jj git init >/dev/null 2>&1)
claim_bool "jj git init is colocated by default" \
  "jj git init is no longer colocated by default" \
  "$(yn test -d "$T/initdefault/.git")"
for f in --colocate --no-colocate --git-repo; do
  claim_bool "jj git init $f exists" "jj git init $f is GONE" "$(yn hasflag git init -- "$f")"
done
claim "jj git colocation exists" "jj git colocation is GONE (git-interop.md cites it)" \
  jj git colocation --help

# Colocated init must still refuse inside a git worktree.
git init -q "$T/wt"
(cd "$T/wt" && git -c user.name=P -c user.email=p@e.co commit -q --allow-empty -m i)
git -C "$T/wt" worktree add -q "$T/wt/.claude/worktrees/probe" -b probe 2>/dev/null
# Capture first: `jj git init` exits non-zero here, and `pipefail` would make a
# `| grep -q` pipeline report that failure instead of the match.
wt_out="$(cd "$T/wt/.claude/worktrees/probe" && jj git init --colocate 2>&1)"
claim_bool "colocated init still refuses inside a git worktree" \
  "colocated init inside a git worktree no longer refuses" \
  "$(printf '%s' "$wt_out" | grep -qi 'inside a Git worktree' && echo true || echo false)"

# ---------- main probe repo ----------
R="$T/work"
git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$R" 2>/dev/null
cd "$R" || exit 2
git -c user.name=P -c user.email=p@e.co commit -q --allow-empty -m init
git branch -M main
git push -q origin main
jj git init --colocate >/dev/null 2>&1 || {
  echo "setup error: jj git init failed" >&2
  exit 2
}
# `jj git init` leaves an empty, undescribed working-copy change behind. Describe
# it: an undescribed ancestor blocks every push — the rule this script asserts.
jj describe -m "chore: probe base" >/dev/null 2>&1

# ---------- core verbs (command-map.md) ----------
printf 'a\n' >a.txt
claim "jj describe -m" "jj describe -m FAILED" jj describe -m "feat: alpha"
claim "jj new -m" "jj new -m FAILED" jj new -m "feat: beta"
printf 'b\n' >b.txt
claim "jj status" "jj status FAILED" jj --no-pager status
claim "jj log --limit" "jj log --limit FAILED" jj --no-pager log --limit 3
claim "jj diff --stat" "jj diff --stat FAILED" jj --no-pager diff --stat
claim "jj diff --git" "jj diff --git FAILED" jj --no-pager diff --git
claim "jj file list" "jj file list FAILED" jj --no-pager file list
claim_bool "jj squash --from/--into" "jj squash --from/--into GONE" \
  "$(hasflag squash -- "--from" && hasflag squash -- "--into" && echo true || echo false)"
claim_bool "jj rebase -d" "jj rebase -d GONE" "$(yn hasflag rebase -- "-d")"
claim_bool "jj rebase --onto/-o alias present" \
  "jj rebase --onto/-o GONE (command-map claims both work)" \
  "$(jj rebase --help 2>&1 | grep -qE '\-\-onto|\-o,' && echo true || echo false)"
claim "jj split <path> -m (non-interactive)" "jj split <path> -m FAILED" \
  jj split a.txt -m "feat: split off"
claim "jj edit <rev>" "jj edit FAILED" jj edit @-
jj new >/dev/null 2>&1
claim "jj abandon -r <revset>" "jj abandon -r FAILED" \
  jj abandon -r 'description(substring:"feat: split off")'
claim "jj undo" "jj undo FAILED" jj undo
claim "jj redo" "jj redo GONE" jj redo
jj undo >/dev/null 2>&1

# ---------- editor/TUI forms must still hang an agent (agent-safety.md §2) ----------
# Runs in a throwaway repo: these probes leave undescribed/rewritten changes
# behind, which would break the push checks further down.
cat >"$T/fake-editor" <<EOF
#!/usr/bin/env bash
echo invoked >>"$T/edmark"
exit 0
EOF
chmod +x "$T/fake-editor"
edprobe() {
  local label="$1"
  shift
  : >"$T/edmark"
  "$@" >/dev/null 2>&1
  claim_bool "$label still opens an editor (agent-safety forbids it)" \
    "$label no longer opens an editor — agent-safety.md §2 may be stale" \
    "$(yn test -s "$T/edmark")"
}
mkdir -p "$T/edrepo"
cd "$T/edrepo" || exit 2
jj git init >/dev/null 2>&1
jj config set --repo ui.diff-editor "$T/fake-editor" >/dev/null 2>&1
export JJ_EDITOR="$T/fake-editor"
printf 'p\n' >p.txt
jj describe -m "editor probe parent" >/dev/null 2>&1
jj new -m "editor probe child" >/dev/null 2>&1
printf 'q\n' >q.txt
jj --no-pager status >/dev/null 2>&1
edprobe "bare jj describe" jj describe
edprobe "bare jj split" jj split
edprobe "jj squash -i" jj squash -i
edprobe "jj diffedit" jj diffedit
unset JJ_EDITOR
cd "$R" || exit 2

# ---------- op log / recovery (recovery-playbook.md) ----------
claim "jj op log --limit" "jj op log --limit FAILED" jj --no-pager op log --limit 3
opid="$(jj --no-pager op log --no-graph -T 'id.short() ++ "\n"' 2>/dev/null | sed -n 2p)"
if [[ -n "$opid" ]]; then
  claim "jj op restore <id>" "jj op restore FAILED" jj op restore "$opid"
else
  DRIFT "jj op log produced no operation id to restore"
fi
claim "jj op revert" "jj op revert GONE" jj op revert --help
claim "jj workspace update-stale" "jj workspace update-stale GONE" jj workspace update-stale --help

# ---------- bookmarks / remote (pr-handoff.md) ----------
# Own clone: the recovery section above runs `jj op restore`, which rewinds the
# whole repo and would leave undescribed ancestors that block every push here.
P="$T/pushwork"
git clone -q "$T/origin.git" "$P" 2>/dev/null
cd "$P" || exit 2
jj git init --colocate >/dev/null 2>&1
jj describe -m "chore: push-probe base" >/dev/null 2>&1
printf 'h\n' >h.txt
jj describe -m "feat: handoff work" >/dev/null 2>&1
jj new -m "next" >/dev/null 2>&1
claim "jj bookmark create -r" "jj bookmark create -r FAILED" jj bookmark create feat-probe -r @-
claim "jj bookmark list --all-remotes" "bookmark list --all-remotes FAILED" \
  jj --no-pager bookmark list --all-remotes
jj git push --bookmark feat-probe >/dev/null 2>&1
claim_bool "jj git push --bookmark pushes a NEW bookmark directly" \
  "pushing a new bookmark FAILED" \
  "$(yn git --git-dir="$T/origin.git" show-ref --verify --quiet refs/heads/feat-probe)"
claim_bool "jj git push still has no --allow-new" \
  "jj git push --allow-new IS BACK (command-map says removed)" \
  "$(jj git push --help 2>&1 | grep -q -- "--allow-new" && echo false || echo true)"

# Push must still reject an undescribed commit anywhere in the pushed range.
jj new >/dev/null 2>&1
jj new >/dev/null 2>&1
jj bookmark create feat-nodesc -r @- >/dev/null 2>&1
nodesc_out="$(jj git push --bookmark feat-nodesc 2>&1)"
claim_bool "jj git push still rejects an undescribed commit in the pushed range" \
  "push no longer rejects undescribed commits — pr-handoff.md note is stale" \
  "$(printf '%s' "$nodesc_out" | grep -qi 'no description' && echo true || echo false)"
jj bookmark delete feat-nodesc >/dev/null 2>&1
jj edit 'description(substring:"feat: handoff work")' >/dev/null 2>&1

claim "jj bookmark move --to" "jj bookmark move --to FAILED" jj bookmark move feat-probe --to @
jj git push --change @ >/dev/null 2>&1
claim_bool "jj git push --change @ creates push-<changeid>" \
  "jj git push --change @ did not create a push-* branch" \
  "$(git --git-dir="$T/origin.git" for-each-ref --format='%(refname:short)' |
    grep -q '^push-' && echo true || echo false)"
claim "jj bookmark delete" "jj bookmark delete FAILED" jj bookmark delete feat-probe
claim "jj git fetch" "jj git fetch FAILED" jj git fetch
claim_bool "jj describe still has no --signoff" \
  "jj describe NOW HAS --signoff (pr-handoff.md says it does not)" \
  "$(hasflag describe -- "--signoff" && echo false || echo true)"
cd "$R" || exit 2 # back to the main probe repo

# ---------- identity: config affects future commits only (agent-safety.md §6) ----------
I="$T/ident"
mkdir -p "$I"
ident_probe() (
  cd "$I" || return 1
  jj git init >/dev/null 2>&1
  printf 'x\n' >f.txt
  jj describe -m "under old identity" >/dev/null 2>&1
  jj config set --repo user.name "New Name" >/dev/null 2>&1
  jj config set --repo user.email "new@example.com" >/dev/null 2>&1
  local before after
  before="$(jj --no-pager log --no-graph -r @ -T 'author.email()' 2>/dev/null)"
  jj metaedit --update-author >/dev/null 2>&1
  after="$(jj --no-pager log --no-graph -r @ -T 'author.email()' 2>/dev/null)"
  [[ "$before" != "new@example.com" && "$after" == "new@example.com" ]]
)
claim_bool "config change alone keeps the old author; jj metaedit --update-author fixes it" \
  "identity/metaedit behaviour differs from agent-safety.md §6" \
  "$(yn ident_probe)"

# ---------- revsets (command-map.md) ----------
rc() { jj --no-pager log --no-graph -r "$1" -T '"x\n"' 2>/dev/null | grep -c x; }
claim_bool "revset mine()" "revset mine() returned nothing" "$(yn test "$(rc 'mine()')" -ge 1)"
for rs in 'trunk()' 'conflicts()' '@ | @-' '::@'; do
  claim "revset $rs" "revset $rs FAILED" jj --no-pager log --no-graph -r "$rs" -T '"x\n"'
done
claim_bool 'revset description(substring:"…")' 'description(substring:) matched nothing' \
  "$(yn test "$(rc 'description(substring:"feat: alpha")')" -ge 1)"
claim_bool 'bare description("…") is still glob-matched (does not match a full message)' \
  'bare description("…") NOW MATCHES — command-map.md revset note is stale' \
  "$(yn test "$(rc 'description("feat: alpha")')" -eq 0)"

# ---------- conflicts (recovery-playbook.md) ----------
base="$(jj --no-pager log --no-graph -r '@' -T 'change_id' 2>/dev/null)"
jj new "$base" -m sideA >/dev/null 2>&1
printf 'AAA\n' >conf.txt
sideA="$(jj --no-pager log --no-graph -r '@' -T 'change_id' 2>/dev/null)"
jj new "$base" -m sideB >/dev/null 2>&1
printf 'BBB\n' >conf.txt
jj rebase -s @ -d "$sideA" >/dev/null 2>&1
claim_bool "jj status flags unresolved conflicts" "jj status did NOT flag the conflict" \
  "$(jj --no-pager status 2>/dev/null | grep -qi 'conflict' && echo true || echo false)"
claim "jj resolve --list" "jj resolve --list FAILED" jj --no-pager resolve --list
claim_bool "conflict markers still use the %%%%%%% / +++++++ form" \
  "conflict marker format CHANGED — recovery-playbook.md shows %%%%%%% / +++++++" \
  "$(grep -q '%%%%%%%' conf.txt 2>/dev/null && grep -q '+++++++' conf.txt 2>/dev/null &&
    echo true || echo false)"

# ---------- workspaces (parallel-agents.md) ----------
claim "jj workspace add" "jj workspace add FAILED" jj workspace add "$T/ws2"
claim "jj workspace list" "jj workspace list FAILED" jj --no-pager workspace list
claim "jj workspace forget" "jj workspace forget FAILED" jj workspace forget ws2

echo "=================================================="
echo "verify_jj_version: $ok claims hold, $drift drifted"
[[ "$drift" -eq 0 ]]
