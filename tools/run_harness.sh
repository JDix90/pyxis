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
#   tools/run_harness.sh --counts     # the run arithmetic, no binary
#   tools/run_harness.sh --legs       # the leg arithmetic, no binary
#   tools/run_harness.sh --parse      # parse EVERY script, not just main.gd
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
# --counts and --legs never launch the binary (§113, and Horizon 11 commit 1),
# so they must not be refused by the check that exists to protect launches.
# --parse is NOT in this list: it is nothing BUT launches.
if [ "${1:-}" != "--counts" ] && [ "${1:-}" != "--legs" ] \
		&& ! [ -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
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
	STOCKTEST SKILLTEST
	INPUTTEST DOCKTEST MARKETTEST BALANCE BOSSTEST
	FEELTEST UITEST GSATEST ACCESSTEST STREAMTEST ENVTEST MINETEST MANUALTEST
	HUNTTEST FACTIONTEST BEACONTEST COLONYTEST FRONTIERTEST STORMTEST
	CONTACTTEST PLOTTEST RIVALTEST UNSOUNDTEST DIRECTIVETEST BERTHTEST
	RETURNTEST
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
# ONE LIST, AND THE FILTER BELOW REUSES IT. This was written out twice --
# here and inside the argument branch -- which is two sources of truth for one
# fact, and it collected exactly the tax that shape always collects: adding
# `migrate27` meant editing both, and editing one would have left a partial
# sweep quietly running a different set from a full one.
ALL_MODES=(write 1 migrate migrate2 migrate3 migrate5 migrate6 migrate11 migrate12 migrate13 migrate14 migrate15 migrate16 migrate17 migrate18 migrate19 migrate20 migrate21 migrate22 migrate23 migrate24 migrate25 migrate26 migrate27 future partial6)
SAVE_MODES=("${ALL_MODES[@]}")

# §113. THE COUNTS, DERIVED. `tools/run_harness.sh --counts` prints the run
# arithmetic and exits -- no Godot binary touched, so it works on any machine
# including the ones that author but cannot sweep. This is the number the
# README quotes, and the long-standing §64 debt ("derive the README's harness
# counts") paid: the README now points here instead of hand-maintaining a
# figure that has been wrong twice.
if [ "${1:-}" = "--counts" ]; then
	echo "TAGS: ${#TAGS[@]}"
	echo "SAVE_MODES: ${#SAVE_MODES[@]}"
	echo "RUNS: $((${#TAGS[@]} + ${#SAVE_MODES[@]}))  (${#TAGS[@]} tags + ${#SAVE_MODES[@]} SAVETEST modes)"
	exit 0
fi

# THE LEG ARITHMETIC, DERIVED. `--counts` answered "how many runs"; this
# answers "how many assertions should those runs print", scoped to the tags
# this script actually sweeps -- which is why it passes TAGS in rather than
# letting the tool guess: a tag that is dispatched but deliberately NOT swept
# (the capture and demo modes above) is not a gap in the gate.
#
# No Godot binary, so it runs on any machine including the ones that author
# but cannot sweep. See tools/harness_legs.py for why this is a lower bound
# and what it refuses to gate on.
if [ "${1:-}" = "--legs" ]; then
	python3 "$ROOT/tools/harness_legs.py" "${TAGS[@]}"
	exit $?
fi

# PARSE EVERY SCRIPT, NOT JUST main.gd. The pre-flight above checks main.gd,
# which parses perfectly well while a leaf class does not -- STRATEGY §111 is
# the whole story: survey_mast.gd failed to compile, deep_space, system_db,
# game_state and the audio autoload all failed behind it, the gate passed, and
# the sweep died at `SurveyMast.new()` with "Nonexistent function 'new' in base
# 'GDScript'". §111 closed that with a static rule because the static pass is
# cheaper. This is the other half, for the classes no static rule knows about:
# Godot's parser is strictly stronger than check_scripts.py and always will be.
#
# NOT part of the default sweep. Seventy binary launches is a minute or two --
# nothing against a full sweep, but everything against the ~0.6s pre-flight
# that runs unconditionally. Run it before a PR, or in CI where the import
# cache can be kept warm.
if [ "${1:-}" = "--parse" ]; then
	parse_bad=0
	parse_n=0
	while IFS= read -r f; do
		parse_n=$((parse_n + 1))
		plog="$OUT/parse_$(echo "$f" | tr '/.' '__').log"
		"$GODOT" --headless --path "$ROOT" --check-only --script "$f" \
			>"$plog" 2>&1
		if grep -qE 'Parse Error|Could not find type|Cannot infer the type' "$plog"; then
			parse_bad=$((parse_bad + 1))
			echo "PARSE: $f"
			grep -E 'Parse Error|Could not find type|Cannot infer the type' "$plog" \
				| head -3 | sed 's/^/    /'
		fi
	done < <(find "$ROOT/scripts" -name '*.gd' | sort)
	echo "---"
	echo "$parse_n script(s) parsed | $parse_bad with errors"
	[ "$parse_bad" -eq 0 ]
	exit $?
fi

if [ $# -gt 0 ]; then
	# SAVETEST names the whole stateful sequence above, never a plain tag. Left in
	# TAGS it runs as a bare read BEFORE the =write leg has laid the fixture down,
	# which fails five assertions that are actually fine.
	#
	# AND AN UNKNOWN ARGUMENT IS REFUSED RATHER THAN RUN. This branch used to
	# accept any token as a tag, and the file's own comment forty lines up says
	# what that costs: "an unrecognised PYXIS_* var is not an error -- the game
	# simply boots normally and runs forever". So a typo, or a flag this build
	# does not have, launched Godot with a variable nothing reads and sat
	# against the 1,500-second backstop. That is not hypothetical: running
	# `--legs` against a checkout from before it existed does exactly this, and
	# it is how this guard came to be written.
	#
	# Checked against the arrays themselves, so the list of legal arguments
	# cannot drift from the list of things that actually run.
	ALL_TAGS=("${TAGS[@]}")
	TAGS=()
	SAVE_MODES=()
	for t in "$@"; do
		if [ "$t" = "SAVETEST" ]; then
			SAVE_MODES=("${ALL_MODES[@]}")
			continue
		fi
		known=0
		for k in "${ALL_TAGS[@]}"; do
			if [ "$k" = "$t" ]; then
				known=1
				break
			fi
		done
		if [ "$known" -eq 0 ]; then
			echo "UNKNOWN ARGUMENT: $t" >&2
			echo "Modes:  --counts  --legs  --parse" >&2
			echo "Tags:   SAVETEST, or one of the ${#ALL_TAGS[@]} in TAGS:" >&2
			printf '%s\n' "${ALL_TAGS[@]}" | sort | paste -sd' ' - | fold -sw 76 \
				| sed 's/^/    /' >&2
			exit 2
		fi
		TAGS+=("$t")
	done
fi

# THE PER-TAG LEG GATE, cached once. `--legs` explains what this is and what it
# deliberately refuses to gate on; this is the same numbers in a form the loop
# below can grep. Built AFTER the argument filter, so a partial sweep is judged
# against the tags it actually ran.
#
# ONE PARSE, NOT FIFTY-SIX. Calling the tool per tag would re-read 28,000 lines
# of main.gd once per run to prove the same thing every time.
#
# Warn-and-continue without python3, matching the static pre-flight above. This
# is a diagnostic layered on top of the sweep, never a precondition for it: the
# PASS/FAIL arithmetic is unaffected by its absence, and a missing python3 has
# already cost the more valuable of the two checks.
GATES="$OUT/leg_gates.tsv"
: >"$GATES"
if command -v python3 >/dev/null 2>&1 && [ ${#TAGS[@]} -gt 0 ]; then
	python3 "$ROOT/tools/harness_legs.py" --gates "${TAGS[@]}" >"$GATES" 2>/dev/null || : >"$GATES"
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
# ONE DIGEST COMMAND, RESOLVED ONCE, AND IT MUST EXIST. `md5 -q` is BSD; Linux
# ships `md5sum`. This script is macOS-targeted (the GODOT default and USERDATA
# above both say so), so the gap never bit -- but it failed OPEN when it did:
# every `md5` call errored to /dev/null, the digest of nothing compared equal to
# the digest of nothing, and the sweep printed "save intact ()" having checked
# nothing at all. That is the exact shape this file's own comment refuses two
# functions down ("a guard that fails open is worse than no guard"), and it is
# live the moment any of this runs anywhere but a Mac -- which the CI work on
# the roadmap intends. Found by running --parse on Linux.
if command -v md5 >/dev/null 2>&1; then
	_digest() { md5 -q; }
elif command -v md5sum >/dev/null 2>&1; then
	_digest() { md5sum | cut -d" " -f1; }
else
	echo "NO DIGEST TOOL: neither md5 nor md5sum found." >&2
	echo "The save-untouched check cannot run, and it is the check that matters." >&2
	exit 2
fi

save_md5() {
	{
		for f in "$SAVE" "$USERDATA/profiles.json" "$USERDATA/prefs.json"; do
			[ -f "$f" ] && _digest <"$f"
		done
		if [ -d "$USERDATA/profiles" ]; then
			for p in $(ls "$USERDATA/profiles" 2>/dev/null | sort); do
				[ -f "$USERDATA/profiles/$p/save.json" ] \
					&& _digest <"$USERDATA/profiles/$p/save.json"
			done
		fi
	} 2>/dev/null | _digest
}
BEFORE="$(save_md5)"

pass=0; fail=0; errs=0; runs=0; short=0

# What an engine error looks like from outside the process. Every one of these
# ALREADY fails the sweep through `errs`, which is the whole licence for killing
# on sight: a run that has printed one has nothing left to prove.
#
# Verified before it was wired: no .gd file in this project prints any of these
# strings itself, so this pattern can only ever match Godot's own output.
FATAL_RE='SCRIPT ERROR|Parse Error|Invalid call|Cannot call method'
# Seconds to keep reading after the first one, so the log carries the stack
# trace rather than only the headline. The whole point is a legible failure.
FATAL_GRACE=3
run_one() {  # tag, env assignment
	local tag="$1" assign="$2"
	local log="$OUT/${1//[^A-Za-z0-9_]/_}.log"
	runs=$((runs + 1))
	# Backstop: a harness that never calls quit() would otherwise stall the whole
	# sweep with no output and no failure. Counted as an error, not silence.
	env "$assign" "$GODOT" --headless --path "$ROOT" >"$log" 2>&1 &
	local pid=$!
	local waited=0 fatal=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT_S" ]; do
		sleep 1; waited=$((waited + 1))
		# KILL ON THE SYMPTOM, NOT ON THE CLOCK. §111's hang printed a script
		# error and then sat here for 1,500 seconds, because a Godot runtime
		# error aborts the FUNCTION and not the process -- so quit() is never
		# reached and the backstop is the only thing left. The backstop was
		# always correct; what it cost was twenty-five minutes per occurrence.
		#
		# A per-tag quit-after-N was the obvious fix and is refused above:
		# PYXIS_BALANCE legitimately runs five to eleven minutes, so any bound
		# tight enough to be useful fails the sweep for something that is not a
		# defect, and a table of fifty-six bounds is a measurement column
		# maintained by hand (§113's own lesson). This needs no bound and no
		# table, because it waits for the run to say it has already failed.
		if [ "$fatal" -eq 0 ] && grep -qE "$FATAL_RE" "$log" 2>/dev/null; then
			fatal=1
			sleep "$FATAL_GRACE"
			break
		fi
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null
		if [ "$fatal" -eq 1 ]; then
			# Deliberately NOT matching FATAL_RE or the errs pattern: the error
			# this reports is already counted one line below, and a marker that
			# counted itself would inflate every early kill by one.
			echo "KILLED AT ${waited}s AFTER AN ENGINE ERROR (the run had already failed)" >>"$log"
		else
			echo "HARNESS TIMEOUT after ${TIMEOUT_S}s (never called quit)" >>"$log"
		fi
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
	# THE LEG GATE. A harness that returns early and quits CLEANLY prints fewer
	# verdicts with no FAIL, no script error and no timeout -- invisible to all
	# three columns above, and the shape behind "a green at 758 that was never
	# swept". Compared against the unconditional site count only, so a leg that
	# legitimately did not fire cannot redden this (see harness_legs.py).
	local verdicts=$((p + f)) gate=""
	gate=$(awk -F'\t' -v t="$tag" '$1 == t { print $2 }' "$GATES" 2>/dev/null)
	if [ -n "$gate" ] && [ "$gate" -gt 0 ] && [ "$verdicts" -lt "$gate" ]; then
		short=$((short + 1))
		printf '    SHORT: %d verdict(s), at least %d expected -- legs did not run\n' \
			"$verdicts" "$gate"
	fi
	if [ "$f" -gt 0 ]; then grep -- '-> FAIL' "$log" | sed 's/^/    /'; fi
	if [ "$e" -gt 0 ]; then grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Cannot call method' "$log" | head -3 | sed 's/^/    /'; fi
}

for tag in "${TAGS[@]+"${TAGS[@]}"}"; do run_one "$tag" "PYXIS_$tag=1"; done
for mode in "${SAVE_MODES[@]+"${SAVE_MODES[@]}"}"; do run_one "SAVETEST=$mode" "PYXIS_SAVETEST=$mode"; done

AFTER="$(save_md5)"
echo "---"
echo "$runs runs | $pass PASS | $fail FAIL | $errs script errors | $short short"
if [ "$BEFORE" != "$AFTER" ]; then
	echo "SAVE TOUCHED: $BEFORE -> $AFTER   (a harness wrote the real save)"
	exit 1
fi
echo "save intact ($BEFORE)"
echo "logs: $OUT"
[ "$fail" -eq 0 ] && [ "$errs" -eq 0 ] && [ "$short" -eq 0 ]
