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
