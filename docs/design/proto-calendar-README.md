# Week / Month / Trends prototype

**A chosen — v4 frozen 2026-08-20 after Danny's comment rounds 1–4 (10 comments).** This file is the visual
spec for #14; treat it as read-only from here. Open with `open docs/design/proto-calendar-A.html`. **C** starts
commenting, **Shift+C** opens the list, **Copy as Markdown** is what to paste back. Add `#week`, `#month`,
`#chart`, `#d28` or `#filter` to the URL to open on that state (they combine: `#d28,filter`).

**The frozen form.**

1. Day / Week / Month are Task calendars over real windows — Monday–Sunday hour grid, true 28–31 day chip
   grid — and ‹ › move one whole day, week or month; month grids use Apple Calendar's colours (selected =
   filled accent circle, white numeral; today unselected = accent numeral, no fill).
2. The Review pane carries a **Today | Trends** toggle. Trends is the Dalio record of the Dots: a rolling
   **Last 7 days** or **Last 28 days**, one window at a time behind a quiet sub-toggle, 7 days by default and
   drawn with book-sized circles; GOOD at the top of the left edge, BAD at the floor.
3. A day is a **ranked stack** — circles sorted by score, best on top, category colour and initial, and no
   numerals anywhere; the slot is rank, never value. A deleted Category stays muted.
4. One line of **category chips** under the field is the only legend and the filter: click one and just that
   Category remains, each circle taking its **height from its own score**; click again to clear.
5. Column 3 reads **Principle of the day → the pane (Review your day or Trends) → Day note (Today mode) →
   Bookmarks**; the sidebar keeps only the Categories and the month, and there is no Backlog surface here.
6. Both dividers drag — sidebar 196–420px, pane 300–720px — invisible until the cursor crosses them.

**Faked.** "Now" pinned to Mon 17 Aug 2026 10:24; reviews seeded 21 Jul – 17 Aug with real gaps (nothing on 24
and 29 Jul or 3 and 8 Aug, Categories missing on many days) so the 28-day window is full; *Side project* is a
deleted Category — its dots stay, muted, and stop after 10 Aug. Nothing persists (reload = reset). No Dalio
text anywhere, only placeholder ids, and the principle card and bookmark rows do not open an excerpt. Dates on
the chart are on hover only. Cut for size, already frozen in `proto-day-A.html`: the task inspector (a block
only selects), Ask Ray's chat, the Category context menu, grid drag-to-move/resize/create. Overlapping blocks
are not split into columns — the seed avoids overlaps.

**Screenshots (1600×1000):** `proto-calendar-A.png` Day + Today · `-A-chart.png` Trends, 7 days ·
`-A-chart-28.png` Trends, 28 days · `-A-filter.png` filtered to Health · `-A-week.png` · `-A-month.png`.
