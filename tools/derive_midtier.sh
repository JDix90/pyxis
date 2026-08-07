#!/usr/bin/env bash
# Re-derives the MIDTIER bar, the way §41 re-derived PHASE INTEGRITY: gather a
# real distribution first, then make a claim the distribution supports.
#
#   tools/derive_midtier.sh          # 20 runs
#   tools/derive_midtier.sh 40       # 40 runs
#
# WHY THIS IS N STANDALONE RUNS AND NOT A LOOP INSIDE THE HARNESS.
# The obvious implementation -- sample the yields k times inside
# _run_pacing_test and average -- is wrong, and it is wrong in a way that would
# have looked right. `_pacing_derelict_yield()` is NOT IDEMPOTENT: its loop is
# `while not derelict.is_cracked()`, so a second call in the same process exits
# immediately, waits out its 10s spill timer and returns ~0. Four samples would
# be one real reading and three zeros, `per_derelict` would land at a quarter of
# its true value, MIDTIER would collapse, and the FLOOR clause at 0.60 would
# start failing for a reason that has nothing to do with the economy.
#
# That matters more than it sounds, because §51's postscript records that the
# derelict term "alone swings 4771-5339 per hull, +/-6%, which is most of the
# spread". The one term that dominates the variance is the one term that cannot
# be resampled in-process. So the sampling unit is a PROCESS, which is also
# exactly what §41 did -- "five standalone runs on a pristine worktree, 30 fresh
# samples, pooled".
#
# WHAT TO DO WITH THE OUTPUT. The report ends with the k this run's spread
# implies. Then, deliberately, decide -- do not paste a number without reading
# §41's rule: "No sample count fixes a bar placed on the statistic's own center
# -- the statistic has to move." MIDTIER is NOT that case (2.91 against 3.00 is
# ~1.8 sd out, not 0), which is why averaging legitimately helps here and did
# not there. If this run says otherwise -- if the mean has drifted up against
# the bar -- then the honest fix is content, not statistics, and that is a
# bigger job than this script.

set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${PYXIS_DERIVE_OUT:-$(mktemp -d)}"
RUNS="${1:-20}"
TIMEOUT_S="${PYXIS_HARNESS_TIMEOUT:-900}"
mkdir -p "$OUT"

# The same guard run_harness.sh carries, for the same reason: PACINGTEST calls
# reset_to_starter(), and "a harness wrote the real save" has happened once.
SAVE="$HOME/Library/Application Support/Godot/app_userdata/Pyxis/save.json"
save_md5() { [ -f "$SAVE" ] && md5 -q "$SAVE" || echo "absent"; }
BEFORE="$(save_md5)"

echo "deriving MIDTIER over $RUNS runs -> $OUT"
echo "run an IDLE machine: §65 records 2.88-3.00 under load against 2.84-2.95 quiet,"
echo "and the whole point of this pass is to separate the two."
echo

errs=0
for i in $(seq 1 "$RUNS"); do
	log="$OUT/run_$(printf '%02d' "$i").log"
	env PYXIS_PACINGTEST=1 "$GODOT" --headless --path "$ROOT" >"$log" 2>&1 &
	pid=$!
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT_S" ]; do
		sleep 1; waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null
		echo "HARNESS TIMEOUT after ${TIMEOUT_S}s" >>"$log"
	fi
	wait "$pid" 2>/dev/null
	# A crashed run prints fewer readings and no FAIL, so counting readings alone
	# would treat it as clean -- run_harness.sh's lesson, applied here.
	if grep -qE 'SCRIPT ERROR|Parse Error|HARNESS TIMEOUT' "$log"; then
		errs=$((errs + 1)); printf 'run %2d  ERROR\n' "$i"
	else
		# 'per best-case' is load-bearing: STEADY MIDTIER prints FIRST, so a bare
		# 'MIDTIER [0-9.]*' would report the steady clause every time and quietly
		# echo the wrong statistic for the whole run.
		printf 'run %2d  %s\n' "$i" \
			"$(grep -o 'MIDTIER [0-9.]* x .*per best-case' "$log" | head -1 | awk '{print $2}')"
	fi
done

AFTER="$(save_md5)"
echo
if [ "$BEFORE" != "$AFTER" ]; then
	echo "!! SAVE TOUCHED -- the real save changed during this run."
	echo "   Check for a Godot instance playing the game before blaming the harness."
fi
[ "$errs" -gt 0 ] && echo "!! $errs run(s) errored -- their readings are absent, not zero."

python3 - "$OUT" <<'PY'
import glob, os, re, statistics as st, sys, math

out = sys.argv[1]
# Both MIDTIER clauses, the ceiling, and every per-term yield -- the point of
# parsing the yields too is to find WHICH term drives the spread, rather than
# assuming §51's answer is still current.
pats = {
    "MIDTIER (best case)": re.compile(r"MIDTIER ([0-9.]+) x .* per best-case loop"),
    "STEADY MIDTIER":      re.compile(r"STEADY MIDTIER ([0-9.]+) x"),
    "PROSPECT MIDTIER":    re.compile(r"PROSPECT MIDTIER ([0-9.]+) x"),
    "CEILING ratio":       re.compile(r"CEILING ratio ([0-9.]+)"),
}
yield_re = re.compile(
    r"YIELD\s+swarm ([0-9.]+)/kill\s+sentry ([0-9.]+)/kill\s+derelict ([0-9.]+)/hull"
    r"\s+trade ([0-9.]+)/run\s+contract ([0-9.]+)/each\s+survey ([0-9.]+)\s+seam ([0-9.]+)/cut")
yield_names = ["swarm", "sentry", "derelict", "trade", "contract", "survey", "seam"]

series = {k: [] for k in pats}
yields = {n: [] for n in yield_names}
for path in sorted(glob.glob(os.path.join(out, "run_*.log"))):
    text = open(path, errors="replace").read()
    for name, pat in pats.items():
        m = pat.search(text)
        if m:
            series[name].append(float(m.group(1)))
    m = yield_re.search(text)
    if m:
        for n, v in zip(yield_names, m.groups()):
            yields[n].append(float(v))

def describe(vals):
    n = len(vals)
    if n < 2:
        return None
    m, sd = st.mean(vals), st.stdev(vals)
    return n, m, sd, min(vals), max(vals)

BARS = {  # (floor, ceiling) as the code states them today
    "MIDTIER (best case)": (0.60, 3.00),
    "STEADY MIDTIER":      (0.60, 3.00),
    "PROSPECT MIDTIER":    (0.60, 3.00),
    "CEILING ratio":       (None, 0.15),
}

print("\n=== the distribution ===")
print(f"{'statistic':22} {'n':>3} {'mean':>7} {'sd':>7} {'min':>7} {'max':>7} "
      f"{'bar':>6} {'margin':>8} {'obs>=bar':>9}")
main = None
for name, vals in series.items():
    d = describe(vals)
    if not d:
        print(f"{name:22}   -- no readings parsed --"); continue
    n, m, sd, lo, hi = d
    _, ceil = BARS[name]
    sigma = (ceil - m) / sd if sd > 0 else float("inf")
    over = sum(1 for v in vals if v >= ceil)
    print(f"{name:22} {n:>3} {m:>7.3f} {sd:>7.3f} {lo:>7.2f} {hi:>7.2f} "
          f"{ceil:>6.2f} {sigma:>7.2f}s {over:>4}/{n:<4}")
    if name == "MIDTIER (best case)":
        main = (n, m, sd, ceil)

print("\n=== where the spread comes from ===")
print("(coefficient of variation per measured term; §51 recorded the derelict")
print(" term as most of it -- check whether that is still true)")
for n_ in yield_names:
    d = describe(yields[n_])
    if not d:
        continue
    cnt, m, sd, lo, hi = d
    cv = (sd / m * 100.0) if m else 0.0
    print(f"  {n_:9} n={cnt:<3} mean {m:>8.0f}  sd {sd:>7.1f}  cv {cv:>5.2f}%"
          + ("   <-- dominant" if cv > 3.0 else ""))

if main:
    n, m, sd, ceil = main
    print("\n=== what this implies ===")
    print(f"single draw: {(ceil - m) / sd:.2f} sd below the bar"
          f"  ->  ~{100 * (1 - 0.5 * (1 + math.erf(((ceil - m) / sd) / math.sqrt(2)))):.2f}% of runs fail")
    print("mean of k samples (sd shrinks as sd/sqrt(k)):")
    for k in (1, 2, 3, 4, 5, 8):
        s = sd / math.sqrt(k)
        z = (ceil - m) / s if s > 0 else float("inf")
        p = 100 * (1 - 0.5 * (1 + math.erf(z / math.sqrt(2))))
        note = "  <-- §51's 'four samples, not one'" if k == 4 else ""
        print(f"    k={k}: sd {s:.4f}  {z:5.2f} sd out  ~{p:8.4f}% fail{note}")
    print("\nPick the smallest k whose failure rate you would accept as noise, then")
    print("REMEMBER THE COST: k samples means k x the fight time in PACINGTEST, and")
    print("the derelict cannot be resampled in-process (see this file's header).")
    print("Paste the measured spread into STRATEGY as a §41-style postscript --")
    print("'write the spread down, because the ceiling is close' (§51).")
PY
