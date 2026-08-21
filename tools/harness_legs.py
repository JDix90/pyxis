#!/usr/bin/env python3
"""Static leg counts per harness tag. No Godot binary required.

WHAT THIS IS FOR, AND WHAT IT DELIBERATELY CANNOT DO.

`run_harness.sh` counts `-> PASS` lines and reports a total. That total has
never been checkable against anything: three times in this repo's history a
figure was wrong (§73's 44-vs-61, §77's 46-vs-64, §113's "green at 758"), and
two of those were caught only because somebody happened to add them up. The
`--counts` work (§113) derived the RUN count. This derives the LEG count.

It is a LOWER BOUND, not an equality, and the reason is worth stating rather
than hiding. Of the leg print sites in `main.gd`:

  * most sit at a harness function's top level and fire exactly once per run;
  * a few sit under an `if`/`match` and legitimately may not fire;
  * a few sit under a `for`/`while` and fire zero-to-many times;
  * and `_run_save_test` is a single function with TWENTY-FOUR mutually
    exclusive `mode ==` branches, DISPATCHED TWENTY-FOUR TIMES by SAVE_MODES.
    Its static site count has no relationship at all to its contribution.

So the split is the whole design. **Unconditional sites are a gate**: a tag
that printed fewer than those has skipped work, which is the one counting
failure nothing else in the sweep can see -- a harness that returns early and
quits CLEANLY prints fewer legs with no FAIL, no script error and no timeout.
**Conditional and looping sites are reported, never gated**, because a checker
with false positives is one nobody runs (`check_scripts.py`'s own rule).

SAVETEST is excluded entirely and PRINTED as excluded. A bound that quietly
dropped its hardest case would be a measurement column claiming coverage it
does not have, which is the class this file exists to close.

AND ONE DIAGNOSTIC THAT IS NOT A GATE. The PROSE column counts print lines in
a harness that carry no verdict. Some of those are correct and wanted --
PACINGTEST's yield table REPORTS measurements and is right not to assert them
-- so this is reported and never gated, because telling a measurement line
from a check that forgot to check needs a human.

It is here because §107 records exactly this defect surviving twenty-two
versions: MARKETTEST "printed five true things and asserted NONE of them",
with the expectation written in the prose (`expect 0`) where nothing could
read it. A tag whose GATE is zero is in the sweep, burns a run, and CANNOT
FAIL. Those are named on their own line.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = os.path.join(ROOT, "scripts", "main.gd")

# The tag whose harness is dispatched once per SAVE_MODE rather than once per
# run. Named here, printed in the output, and never silently skipped.
EXCLUDED = {"SAVETEST"}

LEG = "-> %s"


def indent(line):
    return len(line) - len(line.lstrip("\t"))


def dispatch_map(src):
    """PYXIS_<TAG> -> the _run_* function that tag dispatches.

    Three shapes exist in main.gd and all three are read here rather than
    normalised in the game: `if OS.get_environment(...)`, the `elif` chain in
    the headless block, and TITLETEST's `var title_test := ...` captured
    several lines above its own branch. A shape this function cannot read is
    reported as unresolved rather than dropped -- an unmapped tag is a gap in
    the gate, and a gate with a silent gap is worse than no gate.
    """
    out = {}
    # via-variable: `var x := OS.get_environment("PYXIS_TAG") != ""` then `if x:`
    var_tag = {}
    for line in src:
        m = re.search(r'var\s+(\w+)\s*:=\s*OS\.get_environment\("PYXIS_(\w+)"\)', line)
        if m:
            var_tag[m.group(1)] = m.group(2)

    for i, line in enumerate(src):
        stripped = line.lstrip()
        tag = ""
        m = re.search(r'OS\.get_environment\("PYXIS_(\w+)"\)\s*!=\s*""', line)
        if m and stripped.startswith(("if ", "elif ")):
            tag = m.group(1)
        else:
            m2 = re.match(r"(?:el)?if\s+(\w+)\s*:", stripped)
            if m2 and m2.group(1) in var_tag:
                tag = var_tag[m2.group(1)]
        if not tag or tag in out:
            continue
        depth = indent(line)
        for j in range(i + 1, min(i + 30, len(src))):
            nxt = src[j]
            if not nxt.strip():
                continue
            if indent(nxt) <= depth:
                break
            call = re.search(r"\b(_run_\w+)\s*\(", nxt)
            if call:
                out[tag] = call.group(1)
                break
    return out


def prose_counts(src, bounds):
    """_run_* -> print lines carrying no verdict.

    Reported, never gated: see the note at the top of this file. A high count
    is a question ("does this line check what it says?"), not a failure.
    """
    out = {}
    for name, lo, hi in bounds:
        if not name.startswith("_run_"):
            continue
        out[name] = sum(1 for i in range(lo, hi)
                        if re.search(r"\bprint\(", src[i]) and LEG not in src[i])
    return out


def func_bounds(src):
    """[(name, first_line, last_line)] for every top-level func, in order."""
    out, cur, lo = [], None, 0
    for i, line in enumerate(src):
        m = re.match(r"^func (\w+)", line)
        if m:
            if cur:
                out.append((cur, lo, i))
            cur, lo = m.group(1), i
    if cur:
        out.append((cur, lo, len(src)))
    return out


def leg_sites(src):
    """_run_* -> (unconditional, conditional, looping) leg print counts."""
    out = {}
    for name, lo, hi in func_bounds(src):
        if not name.startswith("_run_"):
            continue
        plain = cond = loop = 0
        for i in range(lo, hi):
            if LEG not in src[i]:
                continue
            # Walk outward to the function header, noting every enclosing block.
            here, is_cond, is_loop = indent(src[i]), False, False
            for j in range(i - 1, lo - 1, -1):
                prev = src[j]
                if not prev.strip():
                    continue
                pi = indent(prev)
                if pi >= here:
                    continue
                s = prev.strip()
                if s.startswith(("for ", "while ")):
                    is_loop = True
                elif s.startswith(("if ", "elif ", "else", "match ")):
                    is_cond = True
                here = pi
            if is_loop:
                loop += 1
            elif is_cond:
                cond += 1
            else:
                plain += 1
        out[name] = (plain, cond, loop)
    return out


def report(tags=None):
    src = open(MAIN, encoding="utf-8").read().split("\n")
    disp = dispatch_map(src)
    sites = leg_sites(src)
    prose = prose_counts(src, func_bounds(src))

    wanted = [t for t in (tags or sorted(disp)) if t not in EXCLUDED]
    unresolved = [t for t in wanted if t not in disp]
    rows, tot_p, tot_c, tot_l, tot_pr = [], 0, 0, 0, 0
    for tag in sorted(t for t in wanted if t in disp):
        fn = disp[tag]
        p, c, l = sites.get(fn, (0, 0, 0))
        pr = prose.get(fn, 0)
        rows.append((tag, fn, p, c, l, pr))
        tot_p, tot_c, tot_l, tot_pr = tot_p + p, tot_c + c, tot_l + l, tot_pr + pr

    print("%-16s %-24s %6s %6s %6s %6s"
          % ("TAG", "HARNESS", "GATE", "COND", "LOOP", "PROSE"))
    for tag, fn, p, c, l, pr in rows:
        print("%-16s %-24s %6d %6d %6d %6d" % (tag, fn, p, c, l, pr))
    print("---")
    print("GATE  %d  (unconditional sites: a tag printing fewer has skipped work)"
          % tot_p)
    print("COND  %d  (under if/match: reported, never gated)" % tot_c)
    print("LOOP  %d  (under for/while: fire zero-to-many, reported only)" % tot_l)
    print("PROSE %d  (print lines with no verdict: a QUESTION, never a gate)"
          % tot_pr)
    for tag in sorted(EXCLUDED):
        print("EXCLUDED: %s -- one harness, %d mode branches, dispatched per mode; "
              "its static count means nothing" % (tag, 24))

    # §107's defect, found statically rather than after twenty-two versions:
    # a tag with no verdict anywhere is a run the sweep counts and cannot fail.
    mute = [(tag, fn, pr) for tag, fn, p, c, l, pr in rows
            if p + c + l == 0 and pr > 0]
    if mute:
        print("CANNOT FAIL (dispatched, prints, and carries no verdict anywhere):")
        for tag, fn, pr in mute:
            print("    %-16s %-24s %d print line(s), 0 assertions" % (tag, fn, pr))
    if unresolved:
        print("UNRESOLVED (no dispatch found -- the gate does not cover these): %s"
              % ", ".join(sorted(unresolved)))
    return 1 if unresolved else 0


def gate_for(tag):
    """The unconditional leg count for one tag, or -1 if it has no gate."""
    src = open(MAIN, encoding="utf-8").read().split("\n")
    if tag in EXCLUDED:
        return -1
    fn = dispatch_map(src).get(tag, "")
    if not fn:
        return -1
    return leg_sites(src).get(fn, (0, 0, 0))[0]


def gates(tags):
    """`TAG<TAB>N` for each tag with a gate, for the shell to cache and grep.

    One parse of main.gd for the whole sweep rather than one per tag: 56
    subprocesses each re-reading 28,000 lines is eleven seconds spent proving
    the same thing fifty-six times.
    """
    src = open(MAIN, encoding="utf-8").read().split("\n")
    disp, sites = dispatch_map(src), leg_sites(src)
    for tag in tags:
        if tag in EXCLUDED or tag not in disp:
            continue
        print("%s\t%d" % (tag, sites.get(disp[tag], (0, 0, 0))[0]))
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--gate":
        print(gate_for(args[1]) if len(args) == 2 else -1)
        sys.exit(0)
    if args and args[0] == "--gates":
        sys.exit(gates(args[1:]))
    sys.exit(report(args or None))
