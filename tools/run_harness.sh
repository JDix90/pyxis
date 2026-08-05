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

# Every harness that prints PASS/FAIL. Excluded on purpose: PYXIS_WORLDTOUR,
# DEEPSHOTS, NARROWSHOTS, PHASE2SHOTS, SHOTS, DEMO and ECONDEMO are capture and
# demo modes -- they assert nothing, and WORLDTOUR never calls quit() unless
# PYXIS_SHOTS is set, so putting it here hangs the sweep on the first tag.
TAGS=(
	COLLISIONTEST RIFTTEST SMUGTEST LOGTEST FORGETEST HOLDTEST DAMAGETEST
	CARTTEST SPILLTEST STORETEST SALVAGETEST SHIPTEST DEEPTEST APEXTEST
	LIVERYTEST STATIONTEST TORPTEST CONTRACTTEST RAIDTEST PAUSETEST
	RADARTEST MUSICTEST PACINGTEST LAYOUTTEST TITLETEST TUTORIALTEST
	INPUTTEST DOCKTEST MARKETTEST BALANCE BOSSTEST
	FEELTEST UITEST GSATEST ACCESSTEST STREAMTEST ENVTEST MINETEST MANUALTEST
	HUNTTEST FACTIONTEST BEACONTEST COLONYTEST FRONTIERTEST
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
SAVE_MODES=(write 1 migrate migrate2 migrate3 migrate5 migrate6 migrate11 migrate12 migrate13 migrate14 migrate15 migrate16 migrate17 migrate18 migrate19 partial6)

if [ $# -gt 0 ]; then
	# SAVETEST names the whole stateful sequence below, never a plain tag. Left in
	# TAGS it runs as a bare read BEFORE the =write leg has laid the fixture down,
	# which fails five assertions that are actually fine.
	TAGS=()
	SAVE_MODES=()
	for t in "$@"; do
		if [ "$t" = "SAVETEST" ]; then
			SAVE_MODES=(write 1 migrate migrate2 migrate3 migrate5 migrate6 migrate11 migrate12 migrate13 migrate14 migrate15 migrate16 migrate17 migrate18 migrate19 partial6)
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
SAVE="$HOME/Library/Application Support/Godot/app_userdata/Pyxis/save.json"
save_md5() { [ -f "$SAVE" ] && md5 -q "$SAVE" || echo "absent"; }
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
