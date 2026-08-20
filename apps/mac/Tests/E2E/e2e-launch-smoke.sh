#!/usr/bin/env bash
# End-to-end smoke for the launch itself (#11): the app is built into a bundle,
# opened against an isolated fixture repo, and has to come up showing the Day —
# not a blank window, not a crash three seconds in.
#
#   apps/mac/Tests/E2E/e2e-launch-smoke.sh              # run it
#   E2E_KEEP=1 apps/mac/Tests/E2E/e2e-launch-smoke.sh   # keep the bundle, repo and shot
#   E2E_SHOT=/path/shot.png apps/mac/Tests/E2E/e2e-launch-smoke.sh
#
# It costs no engine call: nothing here asks a question, so no `claude` process
# is ever spawned. What it proves, in the order it proves it:
#
#   1. `scripts/make-app.sh` still assembles a bundle that launches at all.
#   2. It owns a window at the size `PRINCIPLE_WINDOW` asked for.
#   3. The process is still alive with that window 5 s later — a SwiftUI crash
#      on first layout dies well inside that.
#   4. That window's accessibility tree carries `day-header-title` (set in
#      ``DayHeader``) and its value is today's date. This is the actual claim:
#      the app opens on the Day, showing today. Everything above it only says
#      that something opened.
#   5. It quits on SIGTERM and leaves the real repo's memory/, goals/ and
#      journal/ untouched.
#
# It needs a Mac with somebody logged in and the screen unlocked, and it says so
# rather than timing out: a locked screen hands out no windows at all — neither
# `CGWindowListCopyWindowInfo` nor the accessibility tree — so there is nothing
# to assert on. Step 4 additionally needs Accessibility permission for whatever
# runs this, which cannot be granted unattended; without it that step says so
# and steps aside, and 1–3 and 5 stay hard.
#
# The fixture repo is copied OUTSIDE this tree, exactly as `e2e-smoke.sh` does
# it: the app writes its journal into whatever repo it is pointed at, and the
# one thing this must not do is write into Danny's real memory/ or journal/.
#
# It takes the screen for a few seconds — the app activates itself, as any app
# does when it opens. That is the cost of testing a launch for real.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PACKAGE_DIR="$REPO_ROOT/apps/mac"
FIXTURE="$SCRIPT_DIR/fixture-repo"
HEADER_SWIFT="$PACKAGE_DIR/Sources/Principle/UI/Day/DayHeader.swift"
# Origin and size in points, the way ``LaunchHooks`` reads it. A frame that was
# asked for is a frame that can be asserted on; whatever macOS restores is not.
WINDOW_FRAME="40,60,1400,860"
WINDOW_SIZE="1400,860"
# Long enough for a release build to get through first layout on a cold start.
WINDOW_TIMEOUT=40
ALIVE_SECONDS=5

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
warn() { printf '  WARNING: %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

[ -d "$FIXTURE" ] || fail "fixture repo missing at $FIXTURE"
command -v swiftc >/dev/null || fail "swiftc is required"

TMP_ROOT="$(mktemp -d)"
WORK="$TMP_ROOT/repo"
APP_DIR="$TMP_ROOT/app"
APP="$APP_DIR/Principle.app"
BINARY="$APP/Contents/MacOS/Principle"
SHOT="${E2E_SHOT:-$TMP_ROOT/launch.png}"
APP_PID=""

cleanup() {
    if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$APP_PID" 2>/dev/null || true
    fi
    if [ "${E2E_KEEP:-0}" = "1" ]; then printf '\nkept: %s\n' "$TMP_ROOT"; else rm -rf "$TMP_ROOT"; fi
}
trap cleanup EXIT

# --- the two things AppKit will not tell a shell -------------------------------
# `windows lock` answers whether the login screen is up; `windows <pid>` lists
# that process's windows as `id<TAB>width,height`. Owner pid and bounds are
# readable without any permission — `kCGWindowName` would need Screen Recording,
# which is why the window is identified by its owner and its size.
#
# The list is `.optionAll`, not `.optionOnScreenOnly`, because what is asserted
# is that the window EXISTS. An on-screen-only list leaves out every window that
# is not on the Space in front right now, so somebody working on another Space
# while this runs would read as "no window opened", or as "the window is gone",
# on an app that is perfectly healthy.
cat >"$TMP_ROOT/windows.swift" <<'SWIFT'
import CoreGraphics
import Foundation

let argument = CommandLine.arguments.dropFirst().first ?? ""
if argument == "lock" {
    let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
    print(session["CGSSessionScreenIsLocked"] as? Int == 1 ? "locked" : "unlocked")
    exit(0)
}

let pid = Int(argument) ?? -1
let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
for info in list {
    guard info[kCGWindowOwnerPID as String] as? Int == pid,
        let id = info[kCGWindowNumber as String] as? Int,
        let bounds = info[kCGWindowBounds as String] as? [String: Any],
        let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double
    else { continue }
    print("\(id)\t\(Int(width)),\(Int(height))")
}
SWIFT

# The value of the element carrying a given AXIdentifier, anywhere under an
# app's windows. Exit 2 means "no Accessibility permission", which the caller
# treats as skipped rather than failed; 1 means the tree really has no such
# element, which is a failure.
cat >"$TMP_ROOT/axvalue.swift" <<'SWIFT'
import ApplicationServices
import Foundation

let pid = pid_t(CommandLine.arguments[1]) ?? -1
let wanted = CommandLine.arguments[2]

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("not trusted for accessibility\n".utf8))
    exit(2)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

/// Depth-limited: a SwiftUI window is a deep tree, and a stray cycle in it
/// would hang the run rather than fail it.
func find(_ element: AXUIElement, depth: Int) -> String? {
    if depth > 40 { return nil }
    if let id = attribute(element, kAXIdentifierAttribute as String) as? String, id == wanted {
        return attribute(element, kAXValueAttribute as String) as? String
            ?? attribute(element, kAXTitleAttribute as String) as? String
            ?? attribute(element, kAXDescriptionAttribute as String) as? String
            ?? ""
    }
    for child in attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? [] {
        if let hit = find(child, depth: depth + 1) { return hit }
    }
    return nil
}

let app = AXUIElementCreateApplication(pid)

/// `AXWindows` comes back empty for an app whose windows all sit on some other
/// Space: the tree is still there, it is that one list that is filtered. So the
/// main and focused window are searched too, and the header is readable
/// whichever Space is in front while this runs.
var roots = attribute(app, kAXWindowsAttribute as String) as? [AXUIElement] ?? []
for name in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
    guard let window = attribute(app, name as String),
        CFGetTypeID(window) == AXUIElementGetTypeID()
    else { continue }
    roots.append(window as! AXUIElement)
}

for window in roots {
    if let hit = find(window, depth: 0) {
        print(hit)
        exit(0)
    }
}
exit(1)
SWIFT

# Compiled once rather than run through `swift` on every poll: the window check
# runs up to WINDOW_TIMEOUT times, and a fresh compile each time is most of the
# wall clock.
for helper in windows axvalue; do
    swiftc -o "$TMP_ROOT/$helper" "$TMP_ROOT/$helper.swift" 2>"$TMP_ROOT/$helper.build" ||
        fail "could not compile the $helper helper — $(tail -3 "$TMP_ROOT/$helper.build")"
done

# --- setup ---------------------------------------------------------------------
step "Setup"
# Checked before the build, which is the expensive part: a locked screen cannot
# be worked around, only waited out.
[ "$("$TMP_ROOT/windows" lock)" = "unlocked" ] ||
    fail "the screen is locked. macOS hands out no window while it is — neither CGWindowList nor the accessibility tree — so there is nothing here to assert on. Unlock the Mac and run this again."

mkdir -p "$WORK" "$APP_DIR"
cp -R "$FIXTURE/." "$WORK/"
# Same move `e2e-smoke.sh` makes: the template ships the skill under a visible
# name so it does not register as a skill of the repo it lives in.
mv "$WORK/claude-template" "$WORK/.claude"

# The identifier is read out of Swift rather than typed twice — a second copy
# here would drift from the one the view actually sets.
MARKER="$(sed -n 's/.*static let titleIdentifier = "\([^"]*\)".*/\1/p' "$HEADER_SWIFT" | head -1)"
[ -n "$MARKER" ] || fail "could not read titleIdentifier out of $HEADER_SWIFT"
# ``JournalModel.dayTitle`` formats today as `EEEE, d MMMM` in en_US_POSIX, so
# the expected string is a fixed pattern here too, not the shell's locale.
EXPECTED_TITLE="$(LC_ALL=C date +'%A, %-d %B')"

note "package: $PACKAGE_DIR"
note "fixture: $WORK"
note "marker:  $MARKER = \"$EXPECTED_TITLE\""

# Danny's real memory, goals and journal live in the main checkout — a worktree
# has none of them, and checking the worktree would prove nothing while looking
# like it had. `--git-common-dir` is what points back at the checkout the
# worktree belongs to; in a plain clone it is that clone's own `.git`.
DATA_ROOT="$REPO_ROOT"
if COMMON_DIR="$(cd "$REPO_ROOT" && git rev-parse --git-common-dir 2>/dev/null)"; then
    DATA_ROOT="$(dirname "$(cd "$REPO_ROOT" && cd "$COMMON_DIR" && pwd)")"
fi

# Every file under that personal data, with its hash — the baseline the
# isolation check at the end compares against. A fresh clone has none of the
# directories yet; an empty snapshot is still a valid baseline, since what the
# comparison proves is that the app created nothing here either.
real_memory_snapshot() {
    local dirs=() dir
    for dir in memory goals journal; do
        [ -d "$DATA_ROOT/$dir" ] && dirs+=("$dir")
    done
    [ ${#dirs[@]} -eq 0 ] && return 0
    (cd "$DATA_ROOT" && find "${dirs[@]}" -type f -exec shasum {} + | LC_ALL=C sort)
}
BEFORE="$(real_memory_snapshot)"
note "personal data: $DATA_ROOT — $(printf '%s' "$BEFORE" | grep -c . || true) files hashed"

# --- build ---------------------------------------------------------------------
step "Build"
# Into the temp dir, never ~/Applications: this must not replace the app Danny
# has open.
(cd "$PACKAGE_DIR" && INSTALL_DIR="$APP_DIR" bash scripts/make-app.sh) >"$TMP_ROOT/build.log" 2>&1 ||
    fail "make-app.sh failed — $(tail -5 "$TMP_ROOT/build.log")"
[ -x "$BINARY" ] || fail "no executable at $BINARY after make-app.sh"
note "bundle: $APP"

# --- launch --------------------------------------------------------------------
step "Launch"
# `-repoPath` lands in the argument domain, which outranks every stored default
# and is thrown away when the process exits — so the fixture is used without the
# real repo path ever being written over.
PRINCIPLE_WINDOW="$WINDOW_FRAME" "$BINARY" -repoPath "$WORK" >"$TMP_ROOT/app.log" 2>&1 &
APP_PID=$!
# Off the job table, so bash does not print its own "Terminated: 15" notice
# across the Quit step below. It is still a child, so it is still reaped and
# `kill -0` still answers honestly.
disown "$APP_PID" 2>/dev/null || true
note "pid $APP_PID, repo $WORK"

WINDOW_ID=""
for _ in $(seq 1 "$WINDOW_TIMEOUT"); do
    kill -0 "$APP_PID" 2>/dev/null ||
        fail "the app exited before a window opened — $(tail -5 "$TMP_ROOT/app.log")"
    while IFS=$'\t' read -r id size; do
        # The day's window, not a tooltip or a menu shadow: it is the one at the
        # size that was asked for.
        [ "$size" = "$WINDOW_SIZE" ] && WINDOW_ID="$id"
    done < <("$TMP_ROOT/windows" "$APP_PID")
    [ -n "$WINDOW_ID" ] && break
    sleep 1
done
[ -n "$WINDOW_ID" ] ||
    fail "no ${WINDOW_SIZE//,/×} window from pid $APP_PID within ${WINDOW_TIMEOUT}s — $(tail -5 "$TMP_ROOT/app.log")"
note "window $WINDOW_ID at ${WINDOW_SIZE//,/×}"

# --- still there ---------------------------------------------------------------
step "Alive"
sleep "$ALIVE_SECONDS"
kill -0 "$APP_PID" 2>/dev/null ||
    fail "the app died within ${ALIVE_SECONDS}s of opening its window — $(tail -20 "$TMP_ROOT/app.log")"
"$TMP_ROOT/windows" "$APP_PID" | grep -q "^$WINDOW_ID	" ||
    fail "window $WINDOW_ID is gone ${ALIVE_SECONDS}s after it opened"
note "alive with its window ${ALIVE_SECONDS}s on"

# --- the screen it came up on --------------------------------------------------
step "Showing the day"
AX_STATUS=0
AX_VALUE="$("$TMP_ROOT/axvalue" "$APP_PID" "$MARKER" 2>"$TMP_ROOT/ax.err")" || AX_STATUS=$?
case "$AX_STATUS" in
    0)
        [ "$AX_VALUE" = "$EXPECTED_TITLE" ] ||
            fail "the day header reads \"$AX_VALUE\"; today is \"$EXPECTED_TITLE\""
        note "day header: \"$AX_VALUE\""
        ;;
    2)
        warn "no Accessibility permission for this shell, so the day header could not be read."
        warn "Grant it under System Settings → Privacy & Security → Accessibility to make this step assert."
        ;;
    *)
        fail "the accessibility tree carries no \"$MARKER\" — the app opened on something other than the day. $(cat "$TMP_ROOT/ax.err")"
        ;;
esac

# --- the picture for the human -------------------------------------------------
# Best effort: capturing one window needs Screen Recording permission, and a
# missing screenshot is not a broken app.
step "Screenshot"
if screencapture -x -o -l"$WINDOW_ID" "$SHOT" 2>"$TMP_ROOT/shot.err" && [ -s "$SHOT" ]; then
    note "saved: $SHOT"
    if [ "${E2E_KEEP:-0}" != "1" ] && [ -z "${E2E_SHOT:-}" ]; then
        note "(inside the temp dir — pass E2E_SHOT=/some/path.png or E2E_KEEP=1 to keep it)"
    fi
else
    warn "screencapture produced nothing — $(tail -1 "$TMP_ROOT/shot.err" 2>/dev/null)"
    warn "It needs Screen Recording permission; the assertions above do not."
fi

# --- quit ----------------------------------------------------------------------
step "Quit"
kill "$APP_PID"
for _ in $(seq 1 10); do
    kill -0 "$APP_PID" 2>/dev/null || break
    sleep 1
done
if kill -0 "$APP_PID" 2>/dev/null; then
    kill -9 "$APP_PID" 2>/dev/null || true
    fail "the app ignored SIGTERM and had to be killed"
fi
APP_PID=""
note "exited on SIGTERM"

# --- isolation -----------------------------------------------------------------
step "Isolation"
AFTER="$(real_memory_snapshot)"
[ "$BEFORE" = "$AFTER" ] || fail "memory/, goals/ or journal/ under $DATA_ROOT changed during the run"
note "$DATA_ROOT: memory/, goals/ and journal/ unchanged"

printf '\nPASS — the app builds, launches and comes up on the day. No engine call.\n'
