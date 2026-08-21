#!/usr/bin/env python3
"""Static pre-flight for every .gd file. No Godot binary required.

WHY THIS EXISTS, AND WHY IT DUPLICATES A CHECK GODOT ALREADY DOES BETTER.
`run_harness.sh` already gates the sweep on Godot's own parser, which is
strictly stronger than anything here. This runs first anyway, for two reasons
that are not about strength:

1. GODOT NAMES THE CLASS, NOT THE LINE. A bad indent inside `deep_space.gd`
   does not report as "bad indent at line 1204". It reports as
   `Could not parse global class "DeepSpace"`, followed by roughly four hundred
   `Could not resolve class "DeepSpace"` errors in files nobody touched, an
   autoload that will not compile, and a boot that fails. Finding the actual
   line in that output is an afternoon. This prints the line.

2. NOT EVERY MACHINE THAT EDITS THIS PROJECT HAS THE BINARY. The parse gate can
   only run where Godot is installed, so on any other machine a syntax error
   survives review, gets committed, and is discovered by whoever pulls next.
   That has happened (STRATEGY §77). Python 3 is everywhere Godot is not.

SIX checks, all chosen because they cause the class-registry cascade above and
none is visible when reading a diff. This line said "four" for two rules after
it was six -- rule five arrived in STRATEGY §106 and rule six in §111, and both
sections say six while this header said four. A file's own count of itself is
a measurement column maintained by hand, which is the class §113 documents;
the honest version is `main()` below, which is where the checks are actually
listed and where the number can be read rather than remembered.

    tools/check_scripts.py            # scripts/**/*.gd
    tools/check_scripts.py a.gd b.gd  # just these
"""
import glob
import os
import re
import sys

OPEN, CLOSE = "([{", ")]}"


# ----------------------------------------------------------------- lexing ---

def strip_code(line: str):
    """Drop strings and any trailing comment. Returns (code, bracket_delta).

    String-aware on purpose: a '#' inside a string is not a comment, and a
    bracket inside one is not a bracket. Getting either wrong makes the
    indentation check below hallucinate, and a checker with false positives is
    one nobody runs.
    """
    out, i, delta, n = [], 0, 0, len(line)
    while i < n:
        c = line[i]
        if c in "\"'":
            quote = c
            triple = line[i:i + 3] in ('"""', "'''")
            i += 3 if triple else 1
            while i < n:
                if line[i] == "\\":
                    i += 2
                    continue
                if triple and line[i:i + 3] == quote * 3:
                    i += 3
                    break
                if not triple and line[i] == quote:
                    i += 1
                    break
                i += 1
            out.append("STR")
            continue
        if c == "#":
            break
        if c in OPEN:
            delta += 1
        elif c in CLOSE:
            delta -= 1
        out.append(c)
        i += 1
    return "".join(out), delta


def logical_lines(src: str):
    """(lineno, indent_depth, whole_logical_line, has_space_in_indent).

    A logical line is accumulated across every physical line it spans -- both
    bracket continuations and trailing backslashes -- so a multi-line `func`
    signature ends with the ':' it really ends with, and a lambda passed as an
    argument is one line rather than a body-less block opener. Recording only
    the first physical line makes both look like defects.
    """
    raw = src.split("\n")
    res, i = [], 0
    while i < len(raw):
        line = raw[i]
        stripped = line.strip()
        if stripped == "" or stripped.startswith("#"):
            i += 1
            continue
        lead = line[:len(line) - len(line.lstrip())]
        indent, spaced, start = lead.count("\t"), " " in lead, i + 1
        acc, depth = "", 0
        while i < len(raw):
            code, delta = strip_code(raw[i])
            depth += delta
            code = code.strip()
            more = code.endswith("\\")
            acc += (code[:-1] if more else code) + " "
            i += 1
            if depth <= 0 and not more:
                break
        res.append((start, indent, acc.strip(), spaced))
    return res


# ------------------------------------------------------------ indentation ---

def check_indent(path: str):
    """A block opener whose body is not indented under it.

    THE DEFECT THIS WAS WRITTEN FOR. A COMMENT IS NOT A BODY. Every block in
    this project opens with a paragraph explaining it, so an `if` whose comment
    sits at the right depth and whose code sits one tab too far left reads
    perfectly to a human -- the explanation occupies the space the body should
    be in. GDScript sees `if:` with nothing under it.
    """
    bad, lines = [], logical_lines(open(path, encoding="utf-8").read())
    for i, (lineno, indent, code, spaced) in enumerate(lines):
        if spaced:
            bad.append((lineno, "space in indentation (this project uses tabs)",
                        code))
        opener = code.rstrip().endswith(":")
        if i + 1 >= len(lines):
            continue
        next_lineno, next_indent, next_code, _ = lines[i + 1]
        if opener and next_indent <= indent:
            bad.append((lineno, "block opener with no indented body", code))
        elif not opener and next_indent > indent:
            bad.append((next_lineno,
                        "unexpected indent (nothing above it opens a block)",
                        next_code))
    return bad


# -------------------------------------------------------------- duplicates ---

def check_duplicates(path: str):
    """Two declarations of the same name at file scope.

    THE THIRD RULE, added after the second time a scripted edit inserted a
    function the file already had (STRATEGY §88). GDScript rejects the file
    outright, which means the class never registers, which means the §77
    cascade: four hundred "could not resolve class" lines in files nobody
    touched, and the actual duplicate named nowhere in them.

    FILE SCOPE ONLY -- indent 0. An inner `class Foo:` may legitimately declare
    a `_ready` that the outer class also declares, and its members are indented
    by construction, so restricting to column zero excludes them without
    needing to model scope at all.
    """
    bad, seen = [], {}
    decl = re.compile(r'^(func|const|var|signal|enum|class)\s+([A-Za-z_]\w*)')
    for n, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        m = decl.match(line)
        if not m:
            continue
        kind, name = m.group(1), m.group(2)
        if name in seen:
            bad.append((n, "%s %s is already declared at line %d (file scope)"
                        % (kind, name, seen[name]), line.strip()))
        else:
            seen[name] = n
    return bad


# ----------------------------------------------------------------- shadow ---

LOOP = re.compile(r'^(\t*)for\s+([A-Za-z_]\w*)\s+in\b')
LOCAL = re.compile(r'^(\t*)(?:var|const)\s+([A-Za-z_]\w*)')
FUNC = re.compile(r'^(?:static\s+)?func\s')


UNTYPED_GLOBALS = (
    "floor", "ceil", "round", "abs", "sign", "min", "max", "clamp", "lerp",
    "wrap", "snapped", "posmod", "step_decimals", "inverse_lerp", "remap",
)


def check_infer(path: str):
    """`var x := <untyped global>(...)` -- the type cannot be inferred.

    THE FIFTH RULE, and it cost a whole harness run to learn. GDScript's bare
    math globals (floor, abs, min, clamp...) are Variant-in/Variant-out, so
    `var strided := floor(a / b)` fails to compile with "Cannot infer the type
    of ... because the value doesn't have a set type". The typed variants --
    floorf/floori, absf/absi, minf/mini, clampf/clampi -- are what this
    codebase uses everywhere, and mixing one bare call in is a PARSE error:
    it took down game_state.gd, which is an autoload, which took down every
    script that depends on it and every harness with it.

    Nothing else catches this. It is not an indent, not a duplicate, not a
    shadow and not an unresolved reference, and it reads as completely
    ordinary code -- which is why it survived a written file, a re-read and a
    static check before Godot saw it.

    Only `:=` is flagged. `var x: float = floor(...)` is explicit and legal,
    and so is `int(floor(...))`, because the conversion supplies the type.
    """
    out = []
    # THE UNTYPED CALL MUST BE OUTERMOST. The first version of this pattern
    # allowed wrapper calls in front of it, which contradicted this rule's own
    # docstring and reported 13 collisions against a tree that parses -- every
    # one of them an `int(ceil(...))` that is legal precisely because the
    # conversion supplies the type. The shadow rule learned the same lesson
    # from 28 of them: a checker that cries wolf is a checker nobody runs.
    pat = re.compile(
        r"^\s*var\s+[A-Za-z_]\w*\s*:=\s*(" +
        "|".join(UNTYPED_GLOBALS) + r")\s*\(")
    for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
        code = line.split("#", 1)[0]
        m = pat.match(code)
        if not m:
            continue
        # A typed sibling on the same line (floorf, absi) is the fix, not the
        # defect -- the pattern above already requires an exact name match, but
        # the guard is stated so the next reader does not have to derive it.
        out.append((lineno, "`:=` cannot infer from the untyped global "
                    "`%s()` -- use %sf()/%si()" % (m.group(1), m.group(1),
                                                   m.group(1)),
                    line.rstrip()))
    return out


# --------------------------------------------------------- untyped containers ---

UNTYPED_CONST = re.compile(
    r'^\s*const\s+([A-Z][A-Z0-9_]*)\s*:=\s*[\[{]')


def untyped_consts(paths):
    """class_name -> const names declared as an untyped Array or Dictionary.

    `const BAND_NAMES := [...]` has no element type, so BAND_NAMES[i] is a
    Variant. Collected per class so the rule below can be exact about which
    lookups cannot be inferred from, instead of guessing at every `[`.
    """
    out = {}
    for path in paths:
        src = open(path, encoding="utf-8").read()
        m = CLASSNAME.search(src)
        if not m:
            continue
        names = set()
        for line in src.split("\n"):
            d = UNTYPED_CONST.match(line)
            if d:
                names.add(d.group(1))
        if names:
            out[m.group(1)] = names
    return out


def check_container_infer(path: str, consts):
    """`var x := Class.UNTYPED_CONST[...]` / `.get(...)` -- same parse error.

    THE SIXTH RULE, and the THIRD form of one defect. check_infer catches the
    untyped math globals; this catches untyped CONTAINERS, which fail for the
    identical reason and produce the identical message:

        var band_name := DeepSpace.BAND_NAMES[i]
        Cannot infer the type of "band_name" because the value doesn't have a
        set type.

    It cost a run to learn, and it was worse than the fifth rule's parse error
    in one specific way: that one was in an autoload, so everything died at
    once and loudly. THIS one was in a LEAF class, and the pre-flight only
    parse-checks main.gd -- which parses perfectly well on its own. So the
    gate passed, the sweep started, survey_mast.gd failed to compile at load,
    and deep_space, system_db, game_state and the audio autoload went down
    behind it while the harness printed three cheerful PASS lines first.

    Exact rather than heuristic: only lookups into a const this project
    actually declares untyped are flagged, so a typed Array[String] or a local
    dictionary is never reported. `.get()` is included because it returns
    Variant no matter what the container holds.
    """
    out = []
    pat = re.compile(
        r"^\s*var\s+[A-Za-z_]\w*\s*:=\s*([A-Z]\w*)\.([A-Z][A-Z0-9_]*)"
        r"\s*(\[|\.get\()")
    for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
        code = line.split("#", 1)[0]
        m = pat.match(code)
        if not m:
            continue
        cls, const = m.group(1), m.group(2)
        if const not in consts.get(cls, ()):  # typed, or not a const we know
            continue
        out.append((lineno, "`:=` cannot infer from `%s.%s`, an untyped "
                    "const %s -- wrap it (String(...), int(...)) or declare "
                    "the local's type" % (cls, const,
                                          "dictionary" if m.group(3) != "["
                                          else "array"),
                    line.rstrip()))
    return out


def check_shadow(path: str):
    """A `for` variable OR a `var` colliding with a local that is still in scope.

    THE FOURTH RULE, and the second one a scripted edit produced. GDScript
    rejects `for b in 40` outright when a `var b` earlier in the same function
    is still live -- "There is already a variable named b in this scope" -- and
    that is a parse error, so it takes the class registry down with it exactly
    the way a bad indent does. It also survives review perfectly: the loop and
    the declaration were two hundred lines apart, both correct on their own,
    and the diff showed only the new one.

    SCOPE IS TRACKED BY INDENTATION, which is what makes this quiet enough to
    keep. A `var` inside an `if` body dies with the block, so a later loop at
    lower indent may legitimately reuse the name -- the naive version of this
    check reported 28 collisions against a tree that parses, which is a checker
    nobody would run twice.
    """
    bad, live = [], []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.strip() == "" or line.lstrip().startswith("#"):
            continue
        if FUNC.match(line):
            live = []
            continue
        indent = len(line) - len(line.lstrip("\t"))
        # Everything declared deeper than this line has gone out of scope.
        live = [e for e in live if e[0] <= indent]
        m = LOOP.match(line)
        if m:
            depth, name = len(m.group(1)), m.group(2)
            hit = [e for e in live if e[1] == name and e[0] <= depth]
            if hit:
                bad.append((n, "for variable %s is already a live local from "
                            "line %d" % (name, hit[-1][2]), line.strip()))
            # The loop variable itself scopes to the body.
            live.append((depth + 1, name, n))
            continue
        m = LOCAL.match(line)
        if m:
            depth, name = len(m.group(1)), m.group(2)
            # THE SAME RULE, THE OTHER DIRECTION -- and the one that cost a
            # sweep. `var` against a live `var` is the identical parse error as
            # `for` against a live `var`, and the tracking above already knew
            # about it; the check simply was not asked. A scripted insert put a
            # second `var rec2` a hundred lines below the first, inside a
            # 27,000-line file, and the static pass reported zero problems while
            # the harness could not boot at all.
            hit = [e for e in live if e[1] == name and e[0] <= depth]
            if hit:
                bad.append((n, "var %s is already a live local from line %d"
                            % (name, hit[-1][2]), line.strip()))
            live.append((depth, name, n))
    return bad


# -------------------------------------------------------------- reference ---

# Reachable through any class name without being declared anywhere in this
# project. Keep this list SHORT and only add to it with a real call site --
# every entry is a place this check has agreed to stop looking.
ENGINE_STATICS = {"new"}

CLASSNAME = re.compile(r'^class_name\s+([A-Za-z_]\w*)', re.M)
EXTENDS = re.compile(r'^extends\s+([A-Za-z_]\w*)', re.M)
DECL = re.compile(r'^\t*(?:static\s+)?(?:func|const|var|signal|enum|class)\s+'
                  r'([A-Za-z_]\w*)')
EXPORT = re.compile(r'^\t*@export[^\n]*\s+var\s+([A-Za-z_]\w*)')


def build_index(paths):
    """class_name -> declared members, plus the extends chain between them."""
    members, parent, home = {}, {}, {}
    for path in paths:
        src = open(path, encoding="utf-8").read()
        m = CLASSNAME.search(src)
        if not m:
            continue
        cls = m.group(1)
        home[cls] = path
        e = EXTENDS.search(src)
        if e:
            parent[cls] = e.group(1)
        names = set()
        for line in src.split("\n"):
            for pattern in (DECL, EXPORT):
                d = pattern.match(line)
                if d:
                    names.add(d.group(1))
        # Enum members are referenced as Class.MEMBER too, and are declared
        # inside braces rather than by a keyword, so they need their own sweep.
        for body in re.findall(r'enum\s+\w*\s*\{([^}]*)\}', src, re.S):
            names.update(re.findall(r'\b([A-Z][A-Z0-9_]*)\b', body))
        members[cls] = names
    return members, parent, home


def check_refs(path, members, parent, home):
    """`SomeClass.member` naming something that class does not declare.

    Godot reports this as a parse error, so it takes the whole class registry
    down exactly the way a bad indent does.

    THE FIRST VERSION OF THIS COULD NOT FAIL, and it is worth saying why in
    full, because the shape recurs (STRATEGY §77). It walked `extends` and
    returned "fine" on reaching a class it did not know, reasoning that an
    engine base has members it cannot enumerate. But EVERY class here bottoms
    out at Node3D, Control or RefCounted, so every lookup reached that bail and
    every reference resolved. Run against a deliberate `DeepSpace.compass_deg`
    typo it reported zero problems -- a green that measured nothing.

    What makes the narrow rule correct: `ClassName.member` is a STATIC access.
    Godot resolves it against static functions, consts, enums and inner classes
    only -- an inherited *instance* member is not reachable through the class
    name, so an engine base contributes almost nothing here and running out of
    the project chain is a real answer rather than a missing one.
    """
    bad = []
    src = open(path, encoding="utf-8").read()
    own = CLASSNAME.search(src)
    own = own.group(1) if own else None

    def resolves(cls, name, depth=0):
        if depth > 8:
            return True
        if cls in members and name in members[cls]:
            return True
        if cls in parent:
            return resolves(parent[cls], name, depth + 1)
        # Out of the project chain, so what is left is what the ENGINE offers
        # through a class name. That set is small: the constructor, and the
        # SCREAMING_CASE notification and enum constants every Object carries
        # (NOTIFICATION_READY, PROCESS_MODE_ALWAYS). Conceding those two shapes
        # is what keeps this quiet enough to be worth running -- `.new()` alone
        # is 186 call sites here, and a checker that cries about all of them is
        # a checker nobody reads.
        return name in ENGINE_STATICS or name.isupper()

    for n, line in enumerate(src.split("\n"), 1):
        code, _ = strip_code(line)
        for cls, name in re.findall(r'\b([A-Z]\w+)\.([A-Za-z_]\w*)', code):
            # `cls == own` is skipped: a class may name itself before the
            # member is declared further down the file, which is legal.
            if cls not in members or cls == own:
                continue
            if not resolves(cls, name):
                bad.append((n, "%s.%s is not declared in %s"
                            % (cls, name, os.path.basename(home[cls])),
                            line.strip()))
    return bad


# ------------------------------------------------------------------- main ---

def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    every = sorted(glob.glob(os.path.join(root, "scripts", "**", "*.gd"),
                             recursive=True))
    targets = argv[1:] or every
    # The reference index is always built from EVERY script, even when only a
    # few files are being checked -- a class declared in a file not on the
    # command line is still a class, and indexing only the targets would report
    # every reference into it as unresolved.
    members, parent, home = build_index(every)
    consts = untyped_consts(every)

    found = 0
    for path in targets:
        for lineno, why, text in check_indent(path) + check_duplicates(path) + \
                check_shadow(path) + check_infer(path) + \
                check_container_infer(path, consts) + \
                check_refs(path, members, parent, home):
            rel = os.path.relpath(path, root)
            print("%s:%d: %s\n    %s" % (rel, lineno, why, text[:88]))
            found += 1

    print("--- %d file(s) checked, %d problem(s)" % (len(targets), found))
    if found:
        print("Each of these is a parse error. Godot reports them as "
              "'Could not parse global class' plus a few hundred lines of "
              "cascade, so fix them here.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
