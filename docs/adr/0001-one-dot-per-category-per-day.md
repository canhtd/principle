---
status: accepted
date: 2026-08-19
---

# One dot per category per day

The journal records quality as **one Dot per Category per day** — Danny's own judgement of
how that kind of activity went, on a height of 1 to 10 — instead of turning every ticked
task into a dot and ranking the day's dots best to worst. Reading Dalio's *Life
Principles* 5.2 and 5.3 verbatim shows his chart is one assessment per **type** of outcome
per day, with height meaning the quality of that type on that day; the earlier model in
spec #5 had confused an outcome the day produced with a judgement about the day.

## Context

Spec #5 (revisions 1–3) said: every ticked task and every logged outcome becomes a dot,
typed by its category; at the end of the day Danny drags the day's dots from best to
worst; "Close day" saves that column; no numbers anywhere, on the strength of 5.3b ("be
imprecise").

Re-reading the source changed three things:

- **5.3 (synthesize the situation over time)** describes a day of eight outcomes drawn as
  one letter per *type* of event, height = the quality of that outcome. Applied to a
  person over many days, the honest unit is one letter per type per day — otherwise the
  chart's X axis (days) and its letters (types) stop lining up, and a busy day outranks a
  good one simply by having more ticked tasks.
- **5.2e (don't squeeze the dots too hard)** warns against reading too much into any one
  data point. Ranking every task against every other task is exactly that squeezing.
- **5.3b (be imprecise)**, **5.3c (the 80/20 rule)** and **5.3d (don't be a perfectionist)**
  argue against precision, not against numbers. A 10-step height Danny picks in two
  seconds is an approximation; a full best-to-worst sort of ten tasks is the perfectionism
  those principles warn about.

The corpus says nothing about applying this to one person's own life. The only adaptation
the personal case forces is **5.3a (level and rate of change matter, and so does their
relation)**: Dalio measures level against a bar set by the organisation, so for a person
the bar has to be self-set — one sentence per Category, and optional.

## Decision

- **One Dot per Category per day.** Its height is Danny's judgement of that Category on
  that day, 1 (low) to 10 (high), with the number shown while he sets it and not treated
  as a score afterwards.
- **The bar is self-set**: one optional sentence per Category describing a good day for
  it. Empty is allowed; the height is then felt rather than measured.
- **Ticked tasks are evidence, not dots.** They are shown beside the Category while Danny
  sets its Dot, and they never produce a Dot by themselves.
- **A Category with nothing that day gets no Dot.** Blank is not a bad day.
- **No Close day and no locking.** "Review your day" saves as it goes, and any day can be
  edited later.
- **The Day note is separate** from the Dots: one free-text note for the whole day,
  written after them.

## Considered options

- **Task ranking (the old model).** Every ticked task becomes a dot, dragged best to
  worst, no numbers. Rejected: the chart then measures volume, not quality; a bad day with
  nothing done produces no dots and so disappears; and ranking ten items is the
  perfectionism 5.3d warns against.
- **A free continuous height** (drag a dot anywhere on the axis). Rejected: it looks
  precise, invites fiddling, and is harder to compare across days than a small set of
  steps.
- **Three bands** (good / ok / bad). Rejected as too coarse to show a rate of change —
  weeks of "ok" would read as flat when something is slowly improving, which is exactly
  what 5.3a asks to see.
- **Deriving the height automatically** from Must do / Like to do completion. Rejected:
  it turns the journal back into a task tracker and removes the one judgement the whole
  exercise exists to make.

## Consequences

- The end-of-day UI shrinks to one row per Category plus a note field; drag-and-drop
  ranking, the "Log an outcome" bar and the "Order the day / Close day" mode all
  disappear.
- The Chart gains a natural place for bad days: a low Dot, rather than an absent one.
- Per-task granularity is lost — the journal can no longer say *which* piece of work was
  the day's best. Ticked tasks remain in the day as evidence, so nothing is unrecoverable.
- Issues #8 and #9 are rewritten against this model; spec #5 keeps its earlier revisions
  as history, with revision 4 pointing here.
- Categories now carry an optional Bar, which the old model had put out of scope.
