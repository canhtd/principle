# Principle

Principle is a decision machine built on Ray Dalio's *Principles*: it advises on a case
from the book's own principles, and it keeps a daily journal so that each kind of
activity shows its quality over time. This glossary fixes the words the code, the specs
and the UI all use.

## Language

### The day

**Task**:
Something to do, either sitting in the Backlog or placed on a day. Ticking it means done
and nothing more — it carries no quality judgement.
_Avoid_: To-do, item, entry, habit (a repeating Task is still a Task)

**Backlog**:
The tasks that are not placed on any day yet.
_Avoid_: Inbox, someday list, queue

**Must do / Like to do**:
A Task's two priorities, and the only priority the app has (`Priority.must` / `.nice`).
_Avoid_: Nice to have, important/urgent, P1/P2, high/low

**Category**:
A kind of activity Danny defines himself — Learning, Work, Health, Family. It has a
colour, and it may carry a Bar.
_Avoid_: Type, area, tag, project, label

**Bar**:
One optional sentence per Category, written by Danny, saying what a good day for that
Category looks like; it is what a Dot's height is judged against. It may stay empty, and
then the height is simply felt — honesty beats precision.
_Avoid_: Goal, target, threshold, benchmark, standard

**Dot**:
One per Category per day: Danny's own judgement of how that Category went that day, on a
height of 1 (low) to 10 (high). A Dot is not a Task and not a count of outcomes; ticked
Tasks are only evidence shown beside it, and a Category with nothing that day gets no Dot
at all — blank is not bad.
_Avoid_: Score, rating, rank, outcome, entry

**Review your day**:
The end-of-day act, in two steps: set a Dot per Category, then write the Day note. It
saves as it goes and can be redone any day.
_Avoid_: Close day, order the day, log an outcome, end-of-day ritual, check-in

**Day note**:
One free-text note for the whole day, written after the Dots. It belongs to the day, not
to any single Dot.
_Avoid_: Journal entry, reflection, comment, summary

### Over time

**Chart**:
A reading surface inside the Review your day pane, not a segment of the time axis: a
small Today | Chart toggle in the pane swaps the day's tracks for one real calendar month
seen at once — the month being viewed, 28 to 31 days, moved a whole month at a time —
with per day, per Category, one Dot at its height, drawn in the Category's colour and
lettered with its initial. Filtering to one Category shows that Category's Dots with a
line at their average.
_Avoid_: Graph, dashboard, trend view, month chart, Chart view, the last 28 days

**Level and direction**:
The one-line reading the Chart gives per Category, in Dalio's 5.3a terms: level is this
week's average height, direction is how it moved against last week — rising, flat or
sinking.
_Avoid_: Trend, score, progress, delta, momentum

**Day / Week / Month**:
The app's time axis, one segmented control, and all three segments show Tasks: Day is the
hour grid, Week the Week view, Month the Month view. Each segment stands on a real
calendar window that ‹ › move one whole day, week or month at a time — never a rolling
count of the last so many days. There is no Year, and no segment is the Chart's home.
_Avoid_: View mode, zoom level, range, period, rolling window

**Week view**:
The Week segment: a seven-day hour grid of Tasks over one calendar week, Monday to
Sunday, in the manner of Apple Calendar. ‹ › move it a whole week at a time. It is a
calendar of Tasks and shows no Dots.
_Avoid_: 7-day chart, the last seven days, week summary, weekly review

**Month view**:
The Month segment: a month grid of Tasks over one real calendar month of 28 to 31 days,
in the manner of Apple Calendar. ‹ › move it a whole month at a time. It is a calendar of
Tasks and shows no Dots.
_Avoid_: 28-day view, the last 28 days, month chart, monthly review
