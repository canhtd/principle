# STATE — milestone progress log

The resume pointer for any new session: where we are, what is done, the next
step. Position only — decisions live in `CONTEXT.md`, `docs/adr/` and GitHub
Issues.

Append entries at the bottom; newest last. Never rewrite an old entry — a wrong
past position is corrected by the next entry, not by editing history.

Per item, state the verification level explicitly: "done, ran for real" versus
"green report, NOT run: <gap>".

---

## 2026-08-20 — Review your day + time-axis re-grill (spec #14)

**Landed on main.** `main = c76d1b7`, pushed (`origin/main` matches).

- #8 (Review your day: set/clear one dot per category) — done, ran for real.
  Merged `f8a3161`; evidence on the issue, 404 tests re-run by the CTO.
- #15 + #17 (the Bar, the evidence list, the Day note; a browsed past day stays
  put) — done, ran for real. Merged `5ea0274`; 422 tests / 51 suites re-run by
  the CTO, runtime click-through by the worker, screenshots on record.
- Launch-smoke Space flake (smoke asserts window existence, not
  on-screen-ness) — done, merged `c6c887e`.
- App rebuilt in `~/Applications/Principle.app`. NOT yet: Danny's own hands-on
  pass of the #15 UI.

**The time axis, re-grilled 2026-08-20.**

- Week and Month are Apple-Calendar-style task calendars standing on real
  calendar windows — never a rolling count of the last so many days.
- The Chart lives inside the Review pane behind a `Today | Chart` toggle, over
  one real calendar month.
- Recorded in `CONTEXT.md` and in the "Revision 5" comment on #14.
- #9 and #16 are open and unlabelled, ON HOLD until the prototype freezes — do
  not start work from their current bodies.

**Proto-loop round 1 — OPEN, waiting on Danny.**

- `docs/design/proto-calendar-A.html` (the chart as one shared Dalio field)
  versus `docs/design/proto-calendar-B.html` (small multiples; column 3 placed
  after Apple Calendar's right column), plus `proto-calendar-README.md` and 8
  PNGs.
- All of it is UNCOMMITTED in the main checkout, awaiting Danny's on-page
  comments.
- Persistent worker: `w-proto2` (this session).
- Open questions: A versus B, and the duplicated mini month in B.

**Parked.**

- Stopped #9 WIP in worktree `.claude/worktrees/agent-a0d650685afc5161d`
  (branch `feat/chart-columns`, tip at `f8a3161`, changes uncommitted). The dot
  queries there may be salvageable.
- `/design-gauntlet` for #7: evenings only, still pending.

**Next.** Danny comments on the prototypes → the comments are translated into
rounds for `w-proto2` (cap 5) → freeze the winner as the visual spec → re-cut
#9 and #16 against it → hand to code workers.

---

## 2026-08-20 — Proto freeze + re-cut (spec #14 Rev 6)

**Proto-loop closed.** Four comment rounds, ten comments; Danny chose variant A
and froze it as v4. B was deleted in round 2.

- Frozen visual spec: `docs/design/proto-calendar-A.html` v4 +
  `proto-calendar-A{,-chart,-chart-28,-filter,-week,-month}.png` +
  `proto-calendar-README.md`. All of it is still UNCOMMITTED in the main
  checkout — the CTO commits after review.
- Final form: Week and Month are Apple-style task calendars over real windows;
  the Chart is renamed **Trends** and lives in the Review pane behind
  `Today | Trends`, standing on a rolling Last 7 days or Last 28 days, one
  window at a time; a day is a ranked stack of lettered circles with no
  numerals; category chips are the only legend and filter, and a filtered
  Category is placed by score; column 3 reads Principle of the day → pane →
  Day note → Bookmarks; both dividers drag.
- `CONTEXT.md` updated (Chart → Trends, Level and direction, Day / Week /
  Month); #14 carries **Revision 6**, which supersedes Revision 5's chart shape
  only. #14 itself is untouched and open.

**Tickets re-cut**, all labelled `ready-for-agent`, block chain in the bodies:

- #18 Column 3 restructure + draggable dividers — blocked by none.
- #9 Trends mode: the Dalio record of the Dots — rewritten, blocked by #18.
- #16 Trends filter: category chips + score scatter — rewritten, blocked by #9.
- #19 Week view: real-week task calendar — blocked by none.
- #20 Month view: real-month task grid — blocked by #19.

**Verification.** Prototype behaviour ran for real in a browser (zoom toggle,
chip filter and clear, both windows measured). Everything else this entry
records is document work, not code — no app build was made.

**Next.** Code workers one ticket at a time from the frontier (#18 and #19 are
unblocked; #18 first), and STOP at the first ticket that runs so Danny can try
it. Still parked: the old #9 WIP in worktree `agent-a0d650685afc5161d`, and
`/design-gauntlet` for #7 (evenings only).

## 2026-08-20 evening — #18 mid review-fix loop (checkpoint at usage limit)

**Proto freeze + recut landed earlier today** (`main = 1511282`, entry above).

**#18 (column 3 + dividers) — NOT merged, NOT pushed.**

- Build 1: branch `feat/column3-shell`, commit `5ca1d74`, in worktree
  `.claude/worktrees/agent-a9d722f974c6cbd23`. Worker evidence: 432 tests /
  52 suites green, launch smoke PASS, runtime screenshots in the session
  scratchpad `t18/` (green report; CTO viewed the default-widths shot only —
  CTO has NOT re-run the suite himself).
- Review verdict: REQUEST-CHANGES. Blocking: (1) divider drag starts from the
  STORED width while drawn at the FITTED width — dead zone up to 233 pt on
  narrow windows, and a plain click persists the fitted width, destroying a
  stored 620; (2) docked Ask Ray drops the principle card + bookmarks
  ("every mode" broken). Plus 6 minor findings.
- Fixer `w-t18b` was spawned into the same worktree with the full findings
  list and was RUNNING at checkpoint time. To resume: `git log` on
  `feat/column3-shell` — a `fix(mac):` commit after `5ca1d74` means it
  finished; then re-review the fix diff, merge, and the CTO re-runs
  `swift test` + `scripts/make-app.sh` before Danny tries it. If no new
  commit, re-send the findings (they are in this repo's issue #18 review
  context and reproducible from the list above).

**Open decision for Danny.** The app still shows a Backlog section in column 3;
the frozen prototype removed it and no ticket covers the removal. Proposed:
a small unblocked ticket "Remove the Backlog surface from column 3".

**Next.** Finish #18 loop → Danny tries it (STOP point) → #19 Week view next
(#9 needs #18 merged first). `/design-gauntlet` for #7: evenings.

## 2026-08-20 night — fixer stopped mid-work to save usage

- w-t18b (fix pass for the #18 review findings) was STOPPED before committing.
  Its half-done work sits UNCOMMITTED in worktree
  `.claude/worktrees/agent-a9d722f974c6cbd23` (branch `feat/column3-shell`,
  tip still `5ca1d74`): 11 modified files + 3 new ones (`PanelLayout.swift`,
  `PanelLayoutTests.swift`, `AskRayColumn.swift`) — aimed at the two blocking
  findings (divider drag math, docked Ask Ray keeping card + bookmarks).
- To resume: spawn a FRESH fixer into that same worktree; brief = the findings
  list in the "2026-08-20 evening" entry above + "uncommitted work in the tree
  is a half-done fix pass — inspect it, keep what is right, finish, commit as
  fix(mac)". Do not reset the tree before reading it.
- Everything else in the evening entry stands (re-review → merge → CTO re-runs
  tests + make-app.sh → Danny tries #18; Backlog-removal ticket still open).

## 2026-08-21 — #18 merged; STOP point for Danny

- #18 (column 3 restructure + draggable dividers) — MERGED to main `f5eca28`
  (branch commits 5ca1d74 → 2c704b5 → d4aa468 → 35def5b). Review loop: build 1
  REQUEST-CHANGES (8 findings) → fix pass → re-review found a new blocking
  divider-ratchet bug (clamp ceiling fed back per frame) → fixed as a frozen
  `PanelLayout.Drag` value type + replay tests → APPROVE → 3 nits applied.
- done, ran for real: `swift test` on merged main = 446 tests / 54 suites
  passed, and `apps/mac/scripts/make-app.sh` rebuilt
  `~/Applications/Principle.app` — both re-run by the CTO. Runtime behaviour
  (drag out-and-back keeps stored widths, docked Ask Ray keeps card+bookmarks,
  520pt short column) verified by the worker with screenshots, NOT re-run by
  the CTO.
- **STOP point: Danny tries #18 before any next ticket.**
- Follow-ups parked: docked Ask Ray has no date navigation (known out of
  scope); onEnd guard lacks the edge check its onDrag twin got (pathological
  only); Backlog-removal ticket still awaiting Danny's yes; #19 Week view is
  the next unblocked ticket, #9 now unblocked by this merge.
