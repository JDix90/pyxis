#!/usr/bin/env python3
"""Read the local play recorder that telemetry.gd writes.

WHY THIS EXISTS. `telemetry.gd` has been built, documented and switchable since
Horizon 3, and had never been read once by Horizon 14 -- its own header still
says "the phone-performance and playtest pass deferred from Horizon 1 has still
never run". An instrument nobody reads is an instrument nobody has, and the
friction was never the recording: it was that reading meant finding Godot's
user:// directory by hand and squinting at JSON lines.

WHAT IT REFUSES TO DO. It does not judge, threshold or grade. §144's whole
lesson is that a number wearing a verdict it never earned is worse than no
number, and every question a playtest asks of these rows ("is that enough
minutes?", "is one sheet a lot?") is a design question the reader answers, not
this file.

Rows are cumulative PER RUN, not per sitting -- `minutes` is `played_seconds` at
quit, so successive rows for one pilot show that run's progression rather than
independent samples. Averaging them is almost always wrong; the columns are
printed per row for exactly that reason.
"""
import glob
import json
import os
import sys

# Godot's user:// for this project, on each platform it might be read from.
CANDIDATES = [
    "~/Library/Application Support/Godot/app_userdata/*/telemetry/sessions.jsonl",
    "~/.local/share/godot/app_userdata/*/telemetry/sessions.jsonl",
    "~/AppData/Roaming/Godot/app_userdata/*/telemetry/sessions.jsonl",
]

COLUMNS = [
    ("pilot", "PILOT", "%-10s"),
    ("minutes", "MIN", "%7.1f"),
    ("deepest_depth", "DEEPEST", "%8d"),
    ("sheets_filed", "SHEETS", "%7d"),
    ("tide_seconds", "TIDE s", "%7d"),
    ("hulks_cracked", "HULKS", "%6d"),
    ("chart_data_sold", "CHART", "%6d"),
    ("posts_cleared", "POSTS", "%6d"),
    ("salvage", "SALVAGE", "%9d"),
    ("modules_owned", "MODS", "%5d"),
]

# From DeepSpace.BAND_EDGES. Named here rather than parsed out of the game
# because this tool must run with no project beside it -- and it is a LABEL on
# a depth the row already carries, never a judgement about it.
BANDS = [(5200, "UNSOUNDED"), (2600, "FATHOMS"), (1100, "QUIET"),
         (440, "REACHES"), (160, "DRIFT"), (0, "SHOALS")]


def band_of(depth):
    for floor, name in BANDS:
        if depth >= floor:
            return name
    return "CHARTED"


def find_file(argv):
    if len(argv) > 1:
        return argv[1]
    for pattern in CANDIDATES:
        hits = sorted(glob.glob(os.path.expanduser(pattern)))
        if hits:
            return hits[-1]
    return ""


def main(argv):
    path = find_file(argv)
    if not path or not os.path.exists(path):
        print("No telemetry file found. Looked in:")
        for c in CANDIDATES:
            print("   ", os.path.expanduser(c))
        print("\nTurn it on in-game: PAUSE -> SETTINGS -> SHARE PLAY DATA.")
        print("A row is written at QUIT, and only for sessions over 60s.")
        print("Pass a path explicitly to read one from somewhere else.")
        return 1

    rows = []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            # Reported, never dropped silently: a row this cannot parse is a
            # row the game wrote in a shape this has not been taught, which is
            # worth knowing about rather than rounding away.
            print("  (line %d is not readable JSON, skipped)" % n)

    if not rows:
        print("%s exists but holds no rows yet." % path)
        return 0

    print(path)
    print()
    # Header widths derived from the value formats, so a column added below
    # cannot drift out of alignment with its own heading.
    def head(fmt):
        # The dot is kept through the extraction and dropped by the split --
        # stripping it first turns "%7.1f" into width 71 and shoves the whole
        # header sideways, which is how the first version of this printed.
        width = "".join(c for c in fmt if c.isdigit() or c in "-.")
        return "%" + (width.split(".")[0] or "") + "s"

    print("  ".join(head(fmt) % lbl for _k, lbl, fmt in COLUMNS))
    for r in rows:
        cells = []
        for key, _lbl, fmt in COLUMNS:
            v = r.get(key, 0)
            cells.append(fmt % (str(v) if fmt.endswith("s") else v))
        print("  ".join(cells))

    print()
    print("--- %d row(s), %d pilot(s)"
          % (len(rows), len({r.get("pilot") for r in rows})))
    deepest = max((int(r.get("deepest_depth", 0)) for r in rows), default=0)
    print("deepest reached: %du (%s)" % (deepest, band_of(deepest)))
    print("rows that filed a sheet: %d of %d"
          % (sum(1 for r in rows if int(r.get("sheets_filed", 0)) > 0), len(rows)))
    print("rows that rode a tide:   %d of %d"
          % (sum(1 for r in rows if int(r.get("tide_seconds", 0)) > 0), len(rows)))
    print()
    print("Cumulative per RUN, not per sitting -- successive rows for one pilot")
    print("are that run's progression. No thresholds are applied here (§144).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
