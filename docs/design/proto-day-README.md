# Day-view prototypes — A vs B

Throwaway HTML for ticket #7 (spec #5, Revision 2). Same 3-column shell, same data, same
interactions — as first drafted they differed only in **density of the time grid**; A has since
moved on through Danny's comment rounds and is the frozen reference (see "Decisions" below).

Open with `open docs/design/proto-day-A.html` (and `-B`); self-contained, no server.
Screenshots (1440×900): `proto-day-A-v2.png` is A as it stands now, with Ask Ray floating;
`proto-day-A-v2-chat-sidebar.png` is the same screen with Ask Ray docked into column 3;
`proto-day-A-v2-chat.png` is a close-up of the chat panel and its principle card;
`proto-day-A-v2-principles.png` is the bookmark mode with the excerpt popover open;
`proto-day-A-v2-cat-menu.png` is the category context menu; `proto-day-A-1280.png`,
`-1100.png` and `-960.png` show the responsive shell; `proto-day-A.png` is the v1 it
replaced, kept for comparison; `proto-day-B.png` is B.

| | A — calendar-faithful | B — compact |
|---|---|---|
| Grid | full 00–24, 52px/hour, scrolls | 07–22 at 42px/hour; night folded into two 26px bands that open on click |
| At 1440×900 | needs scrolling | whole day fits |
| All-day strip | thin, colored chips | taller, plain text rows (checkbox + title, no color) |
| Column 3 | 320px, white cards | 272px, no card chrome, sidebar tone |
| Status | **chosen** — v2 after Danny's comments (2026-08-18), frozen as the reference | **rejected**, kept for comparison |

**A v2 — the shell is Eden.** Canvas `#fafaf8` with columns 1 and 3 floating on it as Eden
panels at an 8px inset: 260px wide (content 234), `#f4f3ee`, r=12, 1px black/6%,
`shadow-sm` — every number from `VessaStudio/docs/design/eden-components.md` §1 and
`eden-tokens.md`. Column 2 is the bare canvas. Column 1 holds the Eden sidebar rhythm:
Calendar/Principles as 36×36 r=12 icon buttons (calendar + bookmark) at the panel's right, a “Categories” section
header at h26/13.5px neutral-500 (mt-3 mb-1, pl-2 pr-1) whose disclosure chevron fades in
on hover and collapses the list, and rows at h30 / r=12 / pl-2 pr-3 / gap-8 / 14px
neutral-600 in a gap-0.5 group, hover `black/4%` + neutral-900. Each row is a colored tick
square + name that filters the day (blocks, all-day chips and dots all follow); right-click
gives Rename…, Change color ▸ swatches, Show only <name>, Delete Category, dismissed by
Escape or a click outside. The mini month sits at the bottom of the same panel. The habit
sub-rows are gone. Day/Week/Month/Year sits at the centre of the column-2
toolbar with the date title at its left, and ‹ Today › moved to the top of column 3
(spec #5 rev 2: column 3 carries the date navigation); the dots are a
plain ranked column of circles (“Order the day” turns them into draggable rows, then
“Close day”). The bookmark mode is **Principles**, not a backlog: the
“Principle of the day” card on top, then the favourited principles grouped under
“Life principles” / “Work principles” — the same section-label style as “Principle of the
day”, sentence case, no small caps. The card carries a 3px accent stroke inside its
radius, an uppercase “LIFE PRINCIPLE 5.6” label in place of the id chip, the title, and a
bookmark toggle. Clicking any card or favourite row opens a short **book excerpt** in a
**popover beside the thing you clicked** — 360px, Eden card tokens, an arrow on the row's
centre line, holding the label, title, the excerpt as a quote, the source line, a Favorite
toggle and **Open in Books** (which opens Apple Books at that page in the real app; inert
here). It closes on Escape, on a click outside, and re-anchors when you click another row;
column 3 is left on the day pane throughout. Ask Ray's inline card is the same component
and opens the same popover, flipped to the card's left where the window runs out. If the
chat is docked as a sidebar when something needs column 3, the chat floats itself out of
the way rather than blocking the pane. Ask Ray is a bubble on the window's right margin (right/bottom 20px) instead
of a header icon, and the chat it opens has two modes like Notion AI — floating panel, or
docked as a sidebar in place of column 3. The header's dock icon switches between them
(“Open as sidebar” / “Float”), the X closes, and the mode you last used is the one the
bubble reopens for the rest of the session.

**Responsive:** the shell is fluid — only the side panels carry a width (260 / 320), column
2 takes whatever is left and the hour grid scrolls inside it, and the app always fills
100vh. Under **1200px** the header switches to the short date (“Mon 17 Aug”) and drops the
task-count subtitle. Under **1100px** column 3 slides out behind a toggle in the day header; under
**900px** column 1 does too. An open panel is an overlay and closes on Escape or a click
off it; widen the window and it docks itself again. The floating chat clamps to the
window (`min(380px, 100vw-40)` × `min(520px, 100vh-40)`, 420px tall on short windows).

## Decisions from the comment rounds

Every change Danny asked for across the review rounds, and how A v2 stands today. This list is
the frozen reference the Swift build is measured against.

1. **View switch** — Day / Week / Month / Year is one segmented control centred in column 2's
   toolbar, with the date title at its left. It is not a sidebar item and not a menu.
2. **Column 1** — an Eden floating panel (8px inset, 260px, `#f4f3ee`, r=12, 1px black/6%,
   `shadow-sm`). No app name and no title bar in it. A Calendar / Principles icon pair sits at the
   panel's top right as 36×36 r=12 Eden icon buttons (calendar, bookmark).
3. **Categories are a filter**, like Apple Calendar's calendar list: each row is a colored tick
   square + name, ticked by default; unticking hides that category's blocks, all-day chips and
   dots from the day. Habit sub-rows were removed — a habit is just a task on the grid. Right-click
   opens a native-style context menu: Rename…, Change color ▸ swatches, Show only <name>,
   Delete Category.
4. **Principles mode** (the bookmark icon) is not an inbox or a backlog: the "Principle of the day"
   card on top, then the favourited principles grouped under "Life principles" / "Work principles" —
   one section-label style for all three, sentence case. Backlog appears only as "Suggested from
   backlog" in column 3.
5. **Clicking a principle opens a popover beside it**, not a pane on the other side of the screen:
   360px, arrow on the clicked row's centre line, holding the label, title, the excerpt as a quote,
   the source line, a **Favorite** toggle and **Open in Books**. Escape / click-away closes it,
   another row re-anchors it, and column 3 is left alone.
6. **‹ Today ›** date navigation lives at the top of column 3, not in column 2's header
   (spec #5 rev 2: column 3 carries the date navigation).
7. **The dots column is static** — a plain ranked column of circles. Ranking is a mode you enter:
   "Order the day" turns them into draggable rows, "Close day" ends it.
8. **Ask Ray is a floating bubble** on the window's right margin, not a header icon. The chat it
   opens has two modes like Notion AI — a floating panel, or docked as a sidebar in place of
   column 3 — the header's dock icon switches between them and the last mode is remembered. When
   something needs column 3, a sidebar-docked chat floats itself out of the way.
9. **Warning copy is short** — one line under the date ("7 tasks — more than usual."), no
   paragraph, no banner.
10. **The shell is fluid**, with breakpoints at 1199px (short date, subtitle hidden), 1099px
    (column 3 becomes a drawer) and 899px (column 1 too). No fixed-width wrapper anywhere.
11. **Everything on the grid snaps to 15 minutes** — moving, resizing, creating by drag, and
    dropping an all-day item onto the grid.
12. **The chat has one vertical rhythm** — 14px between every item (day divider, user bubble,
    principle card, Ray's prose, paragraphs, composer), identical floating and docked.

**Working interactions:** untick a category to filter it off the day · right-click one
to rename, recolor, isolate or delete it · dock or float the Ask Ray chat · drag a block
to move · drag its bottom edge to resize · drag on empty grid to create (all snapped to
15 min) · drag an all-day item onto the grid to give it a time · click a block → task
detail in column 3 · tick a checkbox → done · click a suggestion → lands in the all-day
strip · drag the dots to rank best→worst · Close day · mini calendar picks a day ·
Day/Week/Month/Year switch.

## Commenting

Press **C** to start commenting, then click anything — the element under the cursor is
outlined, and clicking holds that outline and names the element in the popover header
("block · Decide M4 scope for VessaStudio"), so you always see what the comment is
attached to; a numbered pin drops where you clicked. Type and press Enter. **Shift+C**
opens the list; pins can be replied to, resolved or deleted. **Copy as Markdown** in the
list is what to paste back to me (Export/Import JSON also work). Comments live in
localStorage per prototype file, so a reload keeps them. The pill sits bottom-**centre** so
it never covers a prototype's own corners. New prototype? Add one line
before `</body>`: `<script src="./proto-comments.js"></script>`. `?selftest` seeds two
demo pins in memory without touching your saved ones — see `proto-day-A-comments.png`.

**Faked:** principle titles and excerpts are placeholders; only 17 Aug 2026 has data, every other day is deliberately empty; "now" is
pinned to 10:24; nothing persists (reload = reset); Week/Month/Year are empty states; the
Ask Ray exchange is a fixed sample. **No principle text is stored in these files** — the
"Principle of the day" card and the Ask Ray card carry only a corpus id (`life:5.3`,
`life:5.6`) plus placeholder copy; the real text is read from the local corpus at runtime,
because the translation is copyrighted and must never be committed. Geist is not installed
locally, so type falls back to the system sans.
