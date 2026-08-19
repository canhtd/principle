# "Review your day" prototypes — A vs B

Throwaway HTML for #8 on the frozen Day-view shell (`proto-day-A.html` v4, untouched). Open with
`open docs/design/proto-review-B.html` (and `-A`) — self-contained, no server. **C** starts commenting,
**Shift+C** opens the list, **Copy as Markdown** is what to paste back.

**The model, identical in both:** one dot per **category** per day; its height is Danny's own judgement of how that
category went, on a 10-step track (1 low … 10 high). A category may carry a **bar** — one sentence on what a good day
looks like there (Work and Health have one; Learning and Family don't). Today's ticked tasks sit under it as
**evidence** only: nothing is scored from them, and ticking one never moves a dot. A category with nothing to say stays
**blank** — blank is not a bad day. Everything autosaves: no Close day, no Order the day, no Log an outcome, not even a
"Saved" flicker. Then one free-text **Day note** for the whole day. Older days open from the mini month, still editable.

| | A — rows | **B — chosen**, v2 after round 1 |
|---|---|---|
| Set a dot | a horizontal track per row, number at the right edge | a vertical track per category, dot dragged up and down, number floating beside it |
| Unset category | an empty track, no dot | **(round 1)** the dot rests at the midpoint in grey, no colour and no number — visibly unset, never a 5. The first click or drag makes it real; clicking a dot on its own step clears it back to that resting look |
| Bar / evidence | under every row, always | tooltip on the track; in full under the chart, for the picked track only |
| Reads as | four judgements, one per line | today as one small chart — the shape Dalio draws |

**Entry point (both):** a quiet **Review** button in column 3's header, in the free cell left of ‹ Today ›.
Always there, on every day — not time-gated: an older day is reviewed from the same spot, and a control that
only appears at 17:00 is one Danny has to re-find. It reads **Backlog** and is also the way back.

**Screenshots (1440×900):** `proto-review-{A,B}.png` pane open · `-setting.png` a dot mid-set, number visible · `-note.png` the day note typed · `-older.png` 16 Aug, still editable · `proto-review-B-unset.png` Family resting unset beside three set dots · `proto-review-A-evidence.png` a tick adds a line and moves no dot. **Faked:** only 17 Aug has tasks; reviews seeded 14–17 Aug; "now" pinned to 10:24; nothing persists (reload = reset); no principle text is stored anywhere.
