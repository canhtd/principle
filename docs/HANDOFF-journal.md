# Handoff — Daily journal (Dalio dots) in the Principle Mac app

Written 2026-08-17 by the Fable session in ~/Documents/Projects. Next session runs inside this repo.

## Where things stand

- Spec: GitHub issue **#5** (canhtd/principle). Tickets = sub-issues with native blocking:
  - **#4** shared theme package → DONE, `https://github.com/canhtd/design-system` (private, `main`, 13 tests green).
  - **#6** Journal core → DONE, merged to `main` (`fd33649`); 32 Journal tests, full suite 323 green.
  - **#7** Today with real data → BUILT on branch `feat/today-screen` (`58985fa`, `3c80cc7`), full suite 338 green, `.app` built with `apps/mac/scripts/make-app.sh` and installed at `~/Applications/Principle.app`. **NOT merged.** Danny's first reaction: "UX vẫn tệ quá" — no specifics yet. **Next step: grill Danny on exactly what feels bad (screenshots), fix on this branch, re-verify, then merge.** Do not start #8 before he is happy with Today.
  - **#8** dots / Order the day / Close day → blocked by #7.
  - **#9** Chart → blocked by #8. **#10** Backlog + Categories screens, **#11** navigation + E2E + remove old Theme → blocked by #7.
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

## Open questions for the next session

1. What exactly is bad in Today's UX (Danny's words + screenshots)? Compare against the prototype; the app may have drifted (native sidebar/toolbar chrome vs the Eden-style layout in the prototype).
2. Whether to fix on `feat/today-screen` before merge (recommended) or merge and iterate.
