#!/usr/bin/env bash
# End-to-end smoke for the consult loop: one real engine turn against an isolated
# fixture repo, then one --resume follow-up. Costs exactly two haiku calls.
#
#   apps/mac/Tests/E2E/e2e-smoke.sh          # run it
#   E2E_KEEP=1 apps/mac/Tests/E2E/e2e-smoke.sh   # keep the temp repo + logs
#
# What it proves: the prompt shape the app sends reaches a real engine, the skill
# runs against a corpus, a case file gets written, the answer comes back in Ray's
# voice and ends with a trailer carrying a diagnosis and a bridge per principle —
# and the real repo's memory is never touched.
#
# The fixture repo is copied OUTSIDE this tree on purpose: run from inside the
# repo, the engine would walk up and load the real CLAUDE.md, and the isolation
# this script exists to prove would be gone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
FIXTURE="$SCRIPT_DIR/fixture-repo"
CONSULT_SWIFT="$REPO_ROOT/apps/mac/Sources/PrincipleCore/Engine/ConsultPrompt.swift"
ALLOWED_TOOLS="Read Grep Glob Write Edit Bash(grep:*)"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# --- binary, in the same order the app resolves it -----------------------------
resolve_claude() {
    local candidate
    for candidate in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude /usr/bin/claude; do
        if [ -x "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
    done
    return 1
}

# The trailer instruction lives in Swift and is read back out of it — a second
# hand-typed copy here would drift from what the app actually sends.
system_prompt() {
    awk '
        /public static let systemPrompt = """/ { inside = 1; next }
        inside && /^[[:space:]]*"""[[:space:]]*$/ { exit }
        inside { sub(/^        /, ""); print }
    ' "$CONSULT_SWIFT"
}

# Every file under the real repo's personal data, with its hash. A fresh clone
# has neither directory yet; an empty snapshot is still a valid baseline, since
# what the comparison proves is that the engine created nothing here either.
real_memory_snapshot() {
    local dirs=()
    local dir
    for dir in memory goals; do
        if [ -d "$REPO_ROOT/$dir" ]; then
            dirs+=("$dir")
        fi
    done
    if [ ${#dirs[@]} -eq 0 ]; then
        return 0
    fi
    (cd "$REPO_ROOT" && find "${dirs[@]}" -type f -exec shasum {} + | LC_ALL=C sort)
}

run_turn() {
    local out="$1" prompt_file="$2"
    shift 2
    local status=0
    (cd "$WORK" && "$CLAUDE_BIN" -p \
        --model haiku \
        --output-format stream-json --verbose \
        --permission-mode acceptEdits \
        --append-system-prompt "$SYSTEM_PROMPT" \
        "$@" \
        --disallowedTools Task Workflow \
        --allowedTools "$ALLOWED_TOOLS") <"$prompt_file" >"$out" 2>"$out.err" || status=$?
    return $status
}

# jq over one stream, tolerant of the lines this app ignores.
tool_names() { jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$1"; }
assistant_text() { jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$1"; }
result_field() { jq -r --arg f "$2" 'select(.type=="result") | .[$f] | tostring' "$1" | tail -1; }

assert_result_ok() {
    local out="$1" label="$2" is_error
    jq -e 'select(.type=="result")' "$out" >/dev/null || fail "$label: no result event"
    is_error="$(result_field "$out" is_error)"
    [ "$is_error" = "false" ] || fail "$label: result is_error=$is_error — $(result_field "$out" result | head -3)"
    note "$label result: is_error=false, subtype=$(result_field "$out" subtype)"
}

# --- setup ---------------------------------------------------------------------
command -v jq >/dev/null || fail "jq is required"
[ -d "$FIXTURE" ] || fail "fixture repo missing at $FIXTURE"
CLAUDE_BIN="$(resolve_claude)" || fail "no claude binary in the candidate list"
SYSTEM_PROMPT="$(system_prompt)"
[ -n "$SYSTEM_PROMPT" ] || fail "could not read systemPrompt out of $CONSULT_SWIFT"

TMP_ROOT="$(mktemp -d)"
WORK="$TMP_ROOT/repo"
LOGS="$TMP_ROOT/logs"
cleanup() {
    if [ "${E2E_KEEP:-0}" = "1" ]; then printf '\nkept: %s\n' "$TMP_ROOT"; else rm -rf "$TMP_ROOT"; fi
}
trap cleanup EXIT

mkdir -p "$WORK" "$LOGS"
cp -R "$FIXTURE/." "$WORK/"
# The template ships the skill under a visible name so it does not register as a
# skill of the repo it lives in; the engine needs it at the real path.
mv "$WORK/claude-template" "$WORK/.claude"

step "Setup"
note "engine:  $CLAUDE_BIN"
note "fixture: $WORK"
CORPUS="$WORK/.claude/skills/ask-ray/references/corpus.jsonl"
[ -f "$CORPUS" ] || fail "fixture corpus missing at $CORPUS"
BEFORE="$(real_memory_snapshot)"
note "real repo memory+goals: $(printf '%s\n' "$BEFORE" | wc -l | tr -d ' ') files hashed"

# --- turn 1: the shape ConsultPrompt.firstTurn builds --------------------------
cat >"$LOGS/turn1.prompt" <<'PROMPT'
/ask-ray Chủ đề: Chọn giữa hai lời mời làm việc

Tình huống:
Em nhận được hai lời mời. Nơi A trả cao hơn 30% nhưng chỉ ký hợp đồng một năm.
Nơi B lương thấp hơn, ổn định hơn, và em học được nhiều hơn. Em phải trả lời
trong ba ngày, và đang nghiêng về A chủ yếu vì tiền.
PROMPT

step "Turn 1 — consult"
run_turn "$LOGS/turn1.jsonl" "$LOGS/turn1.prompt" || note "engine exited non-zero; asserting on the stream"
[ -s "$LOGS/turn1.jsonl" ] || fail "turn 1 produced no stream — $(tail -3 "$LOGS/turn1.jsonl.err" 2>/dev/null)"

TOOLS="$(tool_names "$LOGS/turn1.jsonl" | LC_ALL=C sort -u | tr '\n' ' ')"
[ -n "${TOOLS// /}" ] || fail "turn 1: no tool_use event — the engine never opened the corpus"
note "tools: $TOOLS"
if printf '%s' "$TOOLS" | grep -qiE 'artifact|publish'; then
    fail "turn 1: artifact-like tool call in $TOOLS"
fi

TEXT="$(assistant_text "$LOGS/turn1.jsonl")"
[ -n "$TEXT" ] || fail "turn 1: no assistant text"
note "answer: $(printf '%s' "$TEXT" | tr '\n' ' ' | cut -c1-110)…"
assert_result_ok "$LOGS/turn1.jsonl" "turn 1"

# --- voice: Ray in the first person, talking to "bạn" --------------------------
step "Voice"
if printf '%s' "$TEXT" | grep -qi 'anh danny'; then
    fail "the answer greets the user as 'Anh Danny'; inside the app the voice rule is 'bạn'"
fi
if printf '%s' "$TEXT" | grep -qi 'bạn'; then
    note "addresses the reader as 'bạn'"
else
    printf '  WARNING: the answer never says "bạn" — check the voice rule reached the engine.\n'
fi

# --- trailer (KTD3) ------------------------------------------------------------
# Hard assertions: a card is diagnosis + verbatim corpus text + the model's
# bridge. Any missing piece means the app draws a card with a hole in it, which
# is exactly the bug this contract replaced.
step "Trailer"
LAST_LINE="$(result_field "$LOGS/turn1.jsonl" result | grep -v '^[[:space:]]*$' | tail -1)"
case "$LAST_LINE" in
    PRINCIPLES_JSON:*) ;;
    *) fail "no PRINCIPLES_JSON trailer on the last line — the app draws no cards. Last line: ${LAST_LINE:0:110}" ;;
esac

TRAILER="${LAST_LINE#PRINCIPLES_JSON:}"
printf '%s' "$TRAILER" | jq -e . >/dev/null 2>&1 || fail "trailer JSON does not parse: ${LAST_LINE:0:160}"

KIND="$(printf '%s' "$TRAILER" | jq -r '.diagnosis.kind // ""')"
WHY="$(printf '%s' "$TRAILER" | jq -r '.diagnosis.why // ""')"
[ -n "$KIND" ] || fail "trailer carries no diagnosis.kind: $TRAILER"
[ -n "$WHY" ] || fail "trailer carries no diagnosis.why: $TRAILER"
note "diagnosis: $KIND — $(printf '%s' "$WHY" | cut -c1-70)"

CITED="$(printf '%s' "$TRAILER" | jq -r '.principles | length')"
[ "$CITED" -ge 1 ] || fail "trailer cited no principle: $TRAILER"
[ "$CITED" -le 3 ] || fail "trailer cited $CITED principles; the contract caps it at 3"

while IFS=$'\t' read -r id apply; do
    [ -n "$id" ] && [ "$id" != "null" ] || fail "trailer has a principle with no id: $TRAILER"
    [ -n "$apply" ] && [ "$apply" != "null" ] ||
        fail "principle $id has an empty 'apply' — the bridge is the whole point of the card"
    grep -qF "\"id\":\"$id\"" "$CORPUS" ||
        fail "principle id $id is not in the corpus — the app would resolve it to no card"
    note "principle $id: $(printf '%s' "$apply" | cut -c1-64)"
done < <(printf '%s' "$TRAILER" | jq -r '.principles[] | [.id, (.apply // "")] | @tsv')

# Every principle number named in the prose must have a card. Warn rather than
# fail: a bare "5.6" in Vietnamese prose can also be a quantity or a date.
TRAILER_NUMS="$(printf '%s' "$TRAILER" | jq -r '.principles[].id | sub("^(life|work):"; "")')"
MODEL_NAMES='s/(Haiku|Sonnet|Opus|Fable|Claude)[[:space:]]+[0-9]+(\.[0-9]+)?//g'
for num in $(printf '%s' "$TEXT" | sed -E "$MODEL_NAMES" |
    grep -oE '\b[0-9]{1,2}\.[0-9]{1,2}[a-z]?\b' | LC_ALL=C sort -u); do
    printf '%s\n' "$TRAILER_NUMS" | grep -qxF "$num" ||
        printf '  WARNING: the prose mentions %s but the trailer has no card for it.\n' "$num"
done

# --- vocabulary: the book's own words, not the model's -------------------------
# A real answer once wrote "hạ nhân" for the lower-level self; the Vietnamese
# edition says "bạn ở cấp độ thấp hơn" / "bản ngã thấp hơn". A coined term reads
# exactly like the book to anyone who has not read it, which is why this fails
# rather than warns. The trailer's prose is checked too — `why` and `apply` are
# card text, so a coinage there ships to the screen just the same.
step "Vocabulary"
case "$SYSTEM_PROMPT" in
    *"Từ của sách"*) ;;
    *) fail "the extracted system prompt carries no glossary — check the awk block against $CONSULT_SWIFT" ;;
esac
VOICE_TEXT="$TEXT
$(printf '%s' "$TRAILER" | jq -r '[.diagnosis.kind, .diagnosis.why, (.principles[]?.apply)] | map(select(. != null)) | join(" ")')"
BANNED='hạ nhân|thượng nhân|bản ngã hạ đẳng|bản ngã thượng đẳng|hạ ngã|thượng ngã'
HIT="$(printf '%s' "$VOICE_TEXT" | grep -oiE "$BANNED" | LC_ALL=C sort -u | tr '\n' ' ' || true)"
if [ -n "${HIT// /}" ]; then
    fail "the answer coined vocabulary the book does not use: $HIT — the edition says \"bạn ở cấp độ thấp hơn\" / \"bản ngã thấp hơn\""
fi
note "no coined vocabulary in the answer or the trailer"

# --- the case file the memory protocol asks for --------------------------------
NEW_CASES="$(find "$WORK/memory/cases" -type f ! -name '_TEMPLATE.md' | LC_ALL=C sort)"
[ -n "$NEW_CASES" ] || fail "no case file was written under memory/cases/"
note "case files: $(printf '%s\n' "$NEW_CASES" | xargs -n1 basename | tr '\n' ' ')"

# --- turn 2: context survives --resume (AE1) -----------------------------------
SESSION_ID="$(result_field "$LOGS/turn1.jsonl" session_id)"
[ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || fail "turn 1 reported no session_id to resume"

step "Turn 2 — resume $SESSION_ID"
printf '%s\n' "Nếu hạn ba ngày đó được lùi thành ba tuần thì hướng ông vừa chốt có đổi không?" \
    >"$LOGS/turn2.prompt"
run_turn "$LOGS/turn2.jsonl" "$LOGS/turn2.prompt" --resume "$SESSION_ID" ||
    note "engine exited non-zero; asserting on the stream"
[ -s "$LOGS/turn2.jsonl" ] || fail "turn 2 produced no stream — $(tail -3 "$LOGS/turn2.jsonl.err" 2>/dev/null)"
assert_result_ok "$LOGS/turn2.jsonl" "turn 2"
note "answer: $(assistant_text "$LOGS/turn2.jsonl" | tr '\n' ' ' | cut -c1-110)…"

# One session is one case: the system prompt rides every --resume turn, so a
# follow-up that files a second case file would double the index over a consult.
CASES_AFTER_TURN2="$(find "$WORK/memory/cases" -type f ! -name '_TEMPLATE.md' | LC_ALL=C sort)"
if [ "$CASES_AFTER_TURN2" != "$NEW_CASES" ]; then
    fail "turn 2 changed the set of case files — one session must stay one case file. After: $(printf '%s\n' "$CASES_AFTER_TURN2" | xargs -n1 basename | tr '\n' ' ')"
fi
note "case files after resume: unchanged"

# --- isolation: the real repo must be untouched --------------------------------
step "Isolation"
AFTER="$(real_memory_snapshot)"
[ "$BEFORE" = "$AFTER" ] || fail "the real repo's memory/ or goals/ changed during the run"
note "real repo memory/ and goals/ unchanged"

printf '\nPASS — 2 haiku turns, consult loop end to end.\n'
