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

**Trends**:
A reading surface inside the Review your day pane, not a segment of the time axis: a small
Today | Trends toggle in the pane swaps the day's tracks for the Dalio reading of the
Dots. It stands on a rolling window ending on the day the pane is on — the **Last 7 days**
or the **Last 28 days**, one window at a time behind a quiet sub-toggle, 7 days by
default. Each day is a ranked stack of that day's Dots: a circle per Category in the
Category's colour, lettered with its initial, sorted best outcome on top, with no numbers
anywhere — the slot is rank, not height. Days without Dots are empty columns and a deleted
Category's Dots stay, muted. Filtering to one Category shows only its Dots, each placed
vertically by its own height, so the trend reads as a scatter.
_Avoid_: Chart, graph, dashboard, trend view, month chart, Trends view

**Level and direction**:
The reading Trends is there to give per Category, in Dalio's 5.3a terms: level is the last
7 days' average height, direction is how it moved against the 7 before — rising, flat or
sinking. The app draws the Dots and lets Danny read it; it prints no per-Category
sentence.
_Avoid_: Trend, score, progress, delta, momentum

**Day / Week / Month**:
The app's time axis, one segmented control, and all three segments show Tasks: Day is the
hour grid, Week the Week view, Month the Month view. Each segment stands on a real
calendar window that ‹ › move one whole day, week or month at a time — never a rolling
count of the last so many days. There is no Year, and no segment is where Trends lives.
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
