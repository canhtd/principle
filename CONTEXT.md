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
The last 28 days seen at once: per day, per Category, one Dot at its height, drawn in the
Category's colour and lettered with its initial. Filtering to one Category shows that
Category's Dots with a line at their average.
_Avoid_: Graph, dashboard, trend view, month chart

**Level and direction**:
The one-line reading the Chart gives per Category, in Dalio's 5.3a terms: level is this
week's average height, direction is how it moved against last week — rising, flat or
sinking.
_Avoid_: Trend, score, progress, delta, momentum

**Day / Week / Month**:
The app's time axis, one segmented control. Day is the hour grid, Week the seven days,
Month the Chart's home. There is no Year.
_Avoid_: View mode, zoom level, range, period
