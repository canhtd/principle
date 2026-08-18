# Handoff — Daily journal (Dalio dots) in the Principle Mac app

Written 2026-08-17 by the Fable session in ~/Documents/Projects. Next session runs inside this repo.

## Where things stand

- Spec: GitHub issue **#5** (canhtd/principle). Tickets = sub-issues with native blocking:
  - **#4** shared theme package → DONE, `https://github.com/canhtd/design-system` (private, `main`, 13 tests green).
  - **#6** Journal core → DONE, merged to `main` (`fd33649`); 32 Journal tests, full suite 323 green.
  - **#7** (list-based Today) → BUILT on `feat/today-screen` (338 tests green, `.app` installed) and **REJECTED by Danny on UX**. Grilling revealed the concept model was wrong (list vs time). Branch stays as reference; **do not merge**; the Journal core it uses is fine and stays.
  - **Spec #5 has a "Revision 2" section (2026-08-17 evening) — read it first.** New model: time axis Day/Week/Month/Year like Apple Calendar; Eden-style 3-column shell; Day = hour grid with category-colored blocks (Must strong / Nice light, all-day strip); dots unchanged (ranked, no score).
  - **#7 (retitled)** 3-column shell + Day view → NEXT. Process: HTML prototype in **2 variants** → Danny picks → Swift (Opus 5 xhigh) → Danny tries → design gauntlet (below). Core addition needed: scheduled time on Task.
  - **#8** dots / Order the day / Close day (column 3) → blocked by #7. **#9** Week/Month/Year views → blocked by #8. **#10** Inbox/Backlog + Categories (column 1) → blocked by #7. **#11** navigation/E2E/remove old Theme → mostly absorbed by #7/#12. **#12** Principles + Ask Ray pane in the new UI → blocked by #7.
  - GitHub API was returning 503 while wiring: the detailed comment on #7 did NOT post; the content is in #5 Revision 2. Re-post it if #7 still lacks it.
  - **#2** decision journal (B), **#3** GitHub tickets → backlog: deferred backlog items.
- Visual reference (approved shape): prototype HTML at
  `/private/tmp/claude-501/-Users-danny-Documents-Projects/6ad01bbe-44e8-4922-8f40-8a95b82cf505/scratchpad/proto-principle-journal.html`
  (copied to `docs/design/proto-journal.html`; real-app screenshot `docs/design/today-real-2026-08-17.png`). Screenshots of the real app: same folder, `today-*.png`.

## Decisions that must not be re-litigated (all Danny's, 2026-08-17)

- Model = Dalio *life:5.3* exactly: a **dot is one outcome**; several dots of one category per day; quality = **position in the day's best→worst order**; **no numeric score anywhere**. Danny said "thuần như Dalio". (Corpus: `.claude/skills/ask-ray/references/corpus.jsonl` line 129; the "8" there is eight outcomes, not a scale.)
- Today = one screen (a morning/evening mode was rejected). Must section on top, Nice-to below.
- Rows are **plain text + checkbox only** — no chips, badges, colors on rows; controls on hover only. Danny has ADHD + OCD; fewer elements always wins.
- Categories are user-defined; Repeat = none / every day / weekdays / once a week (task detail).
- Theme: shared `design-system` package (Eden tokens measured by VessaStudio, `VessaStudio/docs/design/eden-tokens.md`); token names/values must stay identical to those docs. Geist not bundled (open decision shared with VessaStudio).
- UI copy, code, docs: **English**. Chat with Danny: Vietnamese.
- Process: Matt Pocock skills (`/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement`, `/wait-what`); Fable delegates all code to **Opus 5 xhigh**; Danny reviews the first runnable slice; commits carry no AI attribution.

## How to run / verify

- Tests: `cd apps/mac && swift test` (expect 338 green on `feat/today-screen`).
- App: `cd apps/mac && bash scripts/make-app.sh && open ~/Applications/Principle.app`.
- Journal data lives as files under `journal/` in this repo (see `apps/mac/Sources/PrincipleCore/Journal/`).

## Design workflow decision (Danny's proposal, evaluated 2026-08-17)

Source: `~/Documents/Projects/design-workflow-proposal.md` (4 phases A–D + "gauntlet" judging loop). Verdict: adopt, trimmed for one person + subscription (no marginal compute cost; the cap is Danny's time). Settled:
- Phase A for Principle = spec #5 (rev 2) + CONTEXT.md; no separate product-model file.
- Phase B = the `design-system` package (done). Add `design-rules.md` derived from it (checkable rules) to this repo before the gauntlet runs.
- Phase C = HTML prototype in 2 variants, then Swift; Danny tries the real build FIRST and gives 2–3 sentences; his reaction becomes the first line of `refs/interaction-spec.md`.
- Phase D (gauntlet), only after that: round 1 = first-user agent + interaction agent (drive the real .app via XCUITest — Principle is SPM-only, so a harness ticket first adds a thin Xcode app target + UI-test target; AX/AppleScript only as agreed fallback), visual agent later; a "what to remove" agent after each round; a clean-context agent reconciles; hard cap 3 rounds; Danny looks after round 1 and fixes the *references* before round 2 if still wrong. Fable is also not allowed to judge its own build.
- `refs/`: Apple Calendar screenshots (structure/time navigation), eden.so (chat pane); `refs/interaction-spec.md` drafted by an agent from spec #5, then edited by Danny in a 10-minute grill.

## Open questions for the next session

1. Prototype variants: which two? (e.g., A = Calendar-faithful hour grid; B = compact grid with larger all-day strip.) Ask Danny once, with a recommendation.
2. Scheduled time on Task: minute precision or 15-min slots? Recommend 15-min.
