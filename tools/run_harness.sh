#!/usr/bin/env bash
# Runs the full headless assertion sweep and prints one summary line.
#
# The sweep was a README paragraph before this: run every harness in order, then
# md5 the real save before and after to prove no harness wrote it. Both halves
# are easy to do wrong by hand, and the save check is the one that matters --
# PYXIS_TITLETEST presses NEW SURVEY, and that combination overwrote a real save
# once already. Scripting it makes the check unskippable.
#
#   tools/run_harness.sh              # every harness
#   tools/run_harness.sh DEEPTEST     # just these tags
#
# Exit status is 0 only when FAIL is 0, no script errors appeared, and the real
# save is byte-identical to how it started.

set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${PYXIS_HARNESS_OUT:-$(mktemp -d)}"
mkdir -p "$OUT"

# THE BINARY, BEFORE ANYTHING ELSE. Every run below is `env ... "$GODOT" ...`,
# and a missing binary makes each one fail instantly with no PASS lines and no
# FAIL lines -- so the sweep would print "65 runs | 0 PASS | 0 FAIL" and exit 0,
# which is the worst possible answer: a green-looking summary that measured
# nothing at all.
if ! [ -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "GODOT not found: $GODOT" >&2
	echo "Set it explicitly, e.g." >&2
	echo "  GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_harness.sh" >&2
	exit 2
fi

# THE STATIC PRE-FLIGHT, WHICH NAMES THE LINE. Godot's parser (three lines
# down) is strictly stronger than this and would catch everything it catches,
# so this is not here for coverage -- it is here for the ERROR MESSAGE. A bad
# indent inside deep_space.gd does not report as "bad indent at line 1204"; it
# reports as `Could not parse global class "DeepSpace"` followed by four
# hundred cascade lines in files nobody touched, and finding the real line in
# that is an afternoon. This prints the line. It also runs where Godot is not
# installed, which is where the defect that prompted it was written.
if command -v python3 >/dev/null 2>&1; then
	if ! python3 "$ROOT/tools/check_scripts.py"; then
		echo "STATIC CHECK FAILED: fix the lines above before sweeping." >&2
		exit 2
	fi
else
	# Not a fail-open: the Godot parse gate immediately below is a superset of
	# this check and it is about to run. Only the nicer message is lost.
	echo "note: python3 not found, skipping static pre-flight" >&2
fi

# AND THAT IT PARSES, ONCE, BEFORE SPENDING AN HOUR FINDING OUT. A main.gd that
# fails to parse does not error: the harness never dispatches, the game boots
# normally and runs forever, so every one of the 65 runs below burns the full
# TIMEOUT_S before being killed. That is most of a day of wall clock to discover
# a missing --import pass, and it has happened -- README's own note about a run
# that sat for four hours is this, found by hand.
#
# Cheap enough to be unconditional: ~0.6s against a sweep measured in tens of
# minutes. It is also the only place the check cannot lie, because the binary
# was proven to exist three lines up -- run by hand with `godot` unset, the
# usual `... 2>&1 | grep -c 'Parse Error'` counts zero matches in
# "command not found" and prints a perfectly convincing 0.
PARSE_LOG="$OUT/parse_check.log"
"$GODOT" --headless --path "$ROOT" --check-only --script "$ROOT/scripts/main.gd" \
	>"$PARSE_LOG" 2>&1
PARSE_ERRS=$(grep -cE 'Parse Error|Could not find type|Cannot infer the type' "$PARSE_LOG")
if [ "$PARSE_ERRS" -gt 0 ]; then
	echo "PARSE CHECK FAILED: $PARSE_ERRS error line(s) before the sweep started." >&2
	grep -E 'Parse Error|Could not find type|Cannot infer the type' "$PARSE_LOG" \
		| head -5 | sed 's/^/    /' >&2
	echo "If this names an unfamiliar type, a new class_name needs the import pass:" >&2
	echo "  \"$GODOT\" --headless --path . --import" >&2
	exit 2
fi

# Every harness that prints PASS/FAIL. Excluded on purpose: PYXIS_WORLDTOUR,
# DEEPSHOTS, NARROWSHOTS, PHASE2SHOTS, SHOTS, DEMO and ECONDEMO are capture and
# demo modes -- they assert nothing, and WORLDTOUR never calls quit() unless
# PYXIS_SHOTS is set, so putting it here hangs the sweep on the first tag.
TAGS=(
	COLLISIONTEST RIFTTEST SMUGTEST LOGTEST FORGETEST HOLDTEST DAMAGETEST
	CARTTEST SPILLTEST STORETEST SALVAGETEST SHIPTEST DEEPTEST APEXTEST
	LIVERYTEST STATIONTEST TORPTEST CONTRACTTEST RAIDTEST PAUSETEST
	RADARTEST MUSICTEST PACINGTEST PROFILETEST SIGTEST LAYOUTTEST TITLETEST TUTORIALTEST
	INPUTTEST DOCKTEST MARKETTEST BALANCE BOSSTEST
	FEELTEST UITEST GSATEST ACCESSTEST STREAMTEST ENVTEST MINETEST MANUALTEST
	HUNTTEST FACTIONTEST BEACONTEST COLONYTEST FRONTIERTEST STORMTEST
	CONTACTTEST PLOTTEST RIVALTEST UNSOUNDTEST DIRECTIVETEST
)

# Only list tags that main.gd actually dispatches. An unrecognised PYXIS_* var
# is not an error -- the game simply boots normally and runs forever -- so a tag
# added here ahead of its harness hangs the sweep rather than failing it. The
# timeout below is the backstop for that and for a harness that deadlocks.
#
# Generous on purpose, and then some. PYXIS_BALANCE fights the apex to a
# conclusion with three different fits, and how long that takes depends on how
# the fights actually go -- it has run anywhere from five to eleven minutes. A
# bound tight enough to be interesting would report the slowest real harness as
# a hang on a bad roll, which is worse than useless: it fails the sweep for a
# reason that is not a defect. This exists to catch "never calls quit()", not to
# police runtime, so it is set where no legitimate harness can reach it.
TIMEOUT_S="${PYXIS_HARNESS_TIMEOUT:-1500}"

# SAVETEST is stateful: =write lays down a fixture the bare read consumes, so
# the pair must stay adjacent and in this order. The migrate modes are
# self-contained and each builds its own old-version fixture.
SAVE_MODES=(write 1 migrate migrate2 migrate3 migrate5 migrate6 migrate11 migrate12 migrate13 migrate14 migrate15 migrate16 migrate17 migrate18 migrate19 migrate20 migrate21 migrate22 future partial6)

if [ $# -gt 0 ]; then
	# SAVETEST names the whole stateful sequence below, never a plain tag. Left in
	# TAGS it runs as a bare read BEFORE the =write leg has laid the fixture down,
	# which fails five assertions that are actually fine.
	TAGS=()
	SAVE_MODES=()
	for t in "$@"; do
		if [ "$t" = "SAVETEST" ]; then
			SAVE_MODES=(write 1 migrate migrate2 migrate3 migrate5 migrate6 migrate11 migrate12 migrate13 migrate14 migrate15 migrate16 migrate17 migrate18 migrate19 migrate20 migrate21 migrate22 future partial6)
		else
			TAGS+=("$t")
		fi
	done
fi

# Godot's user:// for this project, so we can prove the real save is untouched.
#
# ONE FALSE POSITIVE, and it is worth knowing before you go hunting: this compares
# the file before and after the WHOLE sweep, so it cannot tell a harness writing
# the save from the developer PLAYING THE GAME while the sweep runs. A live game
# autosaves, the md5 moves, and the sweep reports SAVE TOUCHED against perfectly
# innocent harnesses. Check for a running Godot on the project before assuming a
# harness is at fault -- and check the `version` field, since a harness on a
# branch that has bumped SAVE_VERSION would write the NEW number and a concurrent
# game on main would write the old one.
USERDATA="$HOME/Library/Application Support/Godot/app_userdata/Pyxis"
SAVE="$USERDATA/save.json"
# THE WHOLE SAVE SURFACE, not one file. Saves became per-pilot in STRATEGY §75,
# so a harness could scribble over pilot two while save.json -- which after the
# migration does not even exist -- sat there byte-identical and the sweep called
# it clean. Everything a harness must not touch is digested together: the legacy
# file if it is still there, the registry, the device prefs, and every pilot's
# save. Sorted, so the digest does not move when the filesystem changes its mind
# about order.
#
# Written as a plain loop rather than a find|xargs pipeline on purpose: under
# `set -o pipefail` a clever pipeline turns "no profiles directory yet" into a
# failed guard, and a guard that fails open is worse than no guard. With nothing
# on disk the digest is simply the hash of no input, which is stable and compares
# equal to itself -- the property the check actually needs.
save_md5() {
	{
		for f in "$SAVE" "$USERDATA/profiles.json" "$USERDATA/prefs.json"; do
			[ -f "$f" ] && md5 -q "$f"
		done
		if [ -d "$USERDATA/profiles" ]; then
			for p in $(ls "$USERDATA/profiles" 2>/dev/null | sort); do
				[ -f "$USERDATA/profiles/$p/save.json" ] \
					&& md5 -q "$USERDATA/profiles/$p/save.json"
			done
		fi
	} 2>/dev/null | md5 -q
}
BEFORE="$(save_md5)"

pass=0; fail=0; errs=0; runs=0
run_one() {  # tag, env assignment
	local tag="$1" assign="$2"
	local log="$OUT/${1//[^A-Za-z0-9_]/_}.log"
	runs=$((runs + 1))
	# Backstop: a harness that never calls quit() would otherwise stall the whole
	# sweep with no output and no failure. Counted as an error, not silence.
	env "$assign" "$GODOT" --headless --path "$ROOT" >"$log" 2>&1 &
	local pid=$!
	local waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT_S" ]; do
		sleep 1; waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null
		echo "HARNESS TIMEOUT after ${TIMEOUT_S}s (never called quit)" >>"$log"
	fi
	wait "$pid" 2>/dev/null
	local p f e
	p=$(grep -c -- '-> PASS' "$log")
	f=$(grep -c -- '-> FAIL' "$log")
	# Parse errors and stack traces are silent killers: a harness that dies
	# early prints fewer PASS lines but no FAIL, so counting PASS alone would
	# call a crashed run clean.
	e=$(grep -cE 'SCRIPT ERROR|Parse Error|Invalid call|Cannot call method|HARNESS TIMEOUT' "$log")
	pass=$((pass + p)); fail=$((fail + f)); errs=$((errs + e))
	printf '%-16s %3d pass  %d fail  %d err\n' "$tag" "$p" "$f" "$e"
	if [ "$f" -gt 0 ]; then grep -- '-> FAIL' "$log" | sed 's/^/    /'; fi
	if [ "$e" -gt 0 ]; then grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Cannot call method' "$log" | head -3 | sed 's/^/    /'; fi
}

for tag in "${TAGS[@]+"${TAGS[@]}"}"; do run_one "$tag" "PYXIS_$tag=1"; done
for mode in "${SAVE_MODES[@]+"${SAVE_MODES[@]}"}"; do run_one "SAVETEST=$mode" "PYXIS_SAVETEST=$mode"; done

AFTER="$(save_md5)"
echo "---"
echo "$runs runs | $pass PASS | $fail FAIL | $errs script errors"
if [ "$BEFORE" != "$AFTER" ]; then
	echo "SAVE TOUCHED: $BEFORE -> $AFTER   (a harness wrote the real save)"
	exit 1
fi
echo "save intact ($BEFORE)"
echo "logs: $OUT"
[ "$fail" -eq 0 ] && [ "$errs" -eq 0 ]
