# The defect classes

Ten shapes this project has produced more than once. Each has instances, and
each names **what stops it happening again** — a checker rule, a harness leg, or
nothing.

**The last column is the point of the document.** A class covered by a rule is
finished. A class covered by "a habit" is one tired evening from recurring, and
five of these are in that state. Read this before writing something that
resembles a row, not after.

Kept here rather than in STRATEGY because STRATEGY is 11,900 lines of what
shipped, and "which of these am I about to do" should be a two-minute question.

---

## 1. `:=` inferred off an untyped container or global

**What happens.** GDScript cannot infer a type from a Variant, so
`var x := SOME_UNTYPED_CONST[i]` is a **parse error** — not a warning. The file
fails to compile, every class that names it fails behind it, and the report is
`Could not parse global class "DeepSpace"` plus a few hundred cascade lines in
files nobody touched.

**Four forms, each found the hard way.** Bare math globals (§77), untyped
containers indexed (§106, in an autoload — loud), the same in a **leaf**
class (§111, quiet: `survey_mast.gd` took `deep_space`, `system_db`,
`game_state` and the audio autoload down behind it, the pre-flight passed
because `main.gd` parses fine alone, and the sweep died at `SurveyMast.new()`
with "Nonexistent function 'new' in base 'GDScript'"), and inference through an
untyped **node handle** (§138 — `survey_mast.gd` again, same leaf, same
cascade, one substitution along).

**The fourth form is the one that reads as typed code.**

    var main := get_tree().get_first_node_in_group("main")
    var want := main.deep_space.sheet_readings(sc.x, sc.y)

`sheet_readings()` is declared `-> int`; the call site looks fully typed. But
the lookup returns `Node`, `Node` has no `deep_space`, so `main.deep_space` is
a Variant and a call **through** a Variant has no return type at all. The
identical line inside `main.gd` compiles, because there `deep_space` is a typed
member of the class rather than a property fished off a handle — so "it works
elsewhere" is not evidence here.

**A fifth and sixth form, both in one load (§147).** §146's capture pass would
not parse, and Godot named two lines the checker had just called clean:

    var ok := rode_clock[0] > 1.0          # untyped LOCAL, not a const
    get_tree().get_first_node_in_group("hyper")[0]   # indexing ONE Node

Rule 6 collects untyped **consts** and is exact about them; a harness leg's
buckets are **locals**. And the second is one character from
`get_nodes_in_group(...)[0]` — plural — which reads as completely ordinary code.
Rules 9 and 10 cover both, red-verified against the live failure before it was
fixed and against seven legal shapes after.

> **"0 problems" MEANS "TEN KNOWN DEFECT CLASSES ARE ABSENT". IT HAS NEVER
> MEANT "IT PARSES".**

That distinction is the standing debt this class actually carries. Ten rules
have each been written *after* paying for their form, GDScript's inference has
more corners than a rule-per-incident approach will ever close, and the only
instrument that settles the question is the parser itself —
`run_harness.sh --parse`, or any run on a machine with the binary. A commit
verified only by `check_scripts.py` is a commit whose parse status is **unknown**
and should be reported that way.

**Covered by:** `check_scripts.py` rules 5 (`check_infer`), 6
(`check_container_infer`), 7 (`check_handle_infer`) and 9–10
(`check_local_infer`). Rule 6 collects every
`const NAME := [` or `{` the project declares and flags `:=` off a lookup into
one, indexing **and** `.get()` — so it is exact rather than heuristic, and a
typed `Array[String]` is never reported. Rule 7 collects locals assigned from
an **uncast** node lookup and flags `:=` off any member of one that `Node` does
not itself declare; `... as CameraRig` supplies the type and is not flagged,
which is load-bearing — without that guard the rule reported two lines in
`main.gd` that compile fine. All three forms were red-verified: rule 7 reports
exactly the two §137 lines against the broken tree and 0 against the fixed one.
Also `run_harness.sh --parse`.

**And rule 7 cried wolf three commits later, which is the other half of the same
lesson.** Its handle set was collected per FILE and never cleared, so a name
used as an untyped handle anywhere poisoned every later function that reused it,
however that one had declared it. `main.gd` declares `var rig :=
get_tree().get_first_node_in_group(...)` in five functions and `var rig:
CameraRig = ...` in FEELTEST; the rule reported 0 problems for three commits and
then flagged six perfectly legal lines the moment FEELTEST grew a `:=` off its
properly typed local. Fixed by scoping the set to the function, which
`check_shadow`'s `live` had done since the day it was written — the rule
borrowed that rule's shape and not its scoping. **A checker earns its keep in
both directions: it has to catch the real one and stay silent on the rest, and
those are two separate red-verifications.**

**The first draft of rule 7 could not fail, and the reason is §77's shape
exactly.** It asked whether the member was declared by some class in the
project index, reasoning that a project member off a `Node` must be Variant.
But `build_index` skips files without a `class_name`, and `main.gd` — 29,000
lines, the class every handle in the game points at — has none, so
`deep_space` was not in the index and the rule returned green against the tree
that was on fire. The fix was to invert the test: concede the short list of
members `Node` genuinely declares and report everything else. **A checker that
asks "is this known-bad?" fails open; one that asks "is this known-good?" fails
closed.** Rules 5, 6 and 7 all now ask the second question.

---

## 2. State set at a distance, and an edit in between

**What happens.** A block depends on state established somewhere else in a
sequence. It is correct when written and stays correct until somebody edits the
gap — at which point it fails for a reason that has nothing to do with what it
is testing.

**Instances, and they run in both directions.**

*Too early to read:* §112's colony-works loader sat with the other v27 stores
and validated every key against `colonies`, **which loads seventy lines later**.
On a real boot it would have validated against the previous session's colony set
(or nothing) and silently dropped every work in the save. The berths loader
documents the same shape from the other side.

*Too far back to trust:* §116's `THE TRIP IS THE COST` cleared `colony_works` to
get a clean slate, and `THE DOCK IS TIME, NOT POWER` measured that store
**eighty lines below** — so a leg that had been green for a horizon went red for
something that was not wrong with the dock. Caught by the sweep, which is the
system working, but the lesson is cheaper than the sweep.

*Five at once, in one horizon, and none of them by a sweep.* Horizon 12's
re-pricing (§126–§128) put five fixtures a re-read caught before a run did: a
purse typed beside the prices it paid; a manifest loop that assigned each work's
goods over the last instead of summing them; three refusal clauses that would
have passed off a newly-added prereq while the gate they are named for went
untested; an orphan-state clause that would have read its grant off a colony
eighty lines above; and a leg filling a bay to its cap twenty lines above the leg
that stows into that same key. **The tell in every one is the same question:
*what else could make this pass?*** Ask it of a green assertion, not only of a
red one.

**Covered by:** nothing mechanical, and the cure is the same in both directions
— **state the dependency at the site, or remove it.** A loader goes immediately
after what it validates against. A harness block claims its own ground instead
of borrowing somebody's, and a leg that needs a precondition **builds it** rather
than inheriting it from a distance. The corollary is worth its own sentence:
**a harness block that resets shared state and does not restore it is a defect
whose blast radius is whatever somebody writes after it.**

---

## 3. An assertion whose premise a feature reversed

**What happens.** A leg encodes a rule; a later commit changes the rule; the leg
is deleted or quietly edited to match, and the argument for the change never
happens in the same diff that makes it.

**Instances.** §80 reversed §22's session-only survey rule and `SESSION RESET`
forced the conversation it existed to force. §109 gave spills a clock and
`NO EXPIRY` became `A SPILL OUTLIVES THE REAPER AND DIES ON ITS OWN CLOCK`.

**Covered by:** §24, as discipline. **An assertion whose premise a feature
reverses gets REWRITTEN to state the new rule, never dropped** — so the change
has to be argued in the commit that makes it.

---

## 4. One UI channel, many unqueued writers

**What happens.** A label with no queue is written by a dozen callers, each
unconditionally. The one that matters loses to whatever the player happened to
be drifting near.

**Instances.** The parley demand, wiped by ambient range prompts (v18 — fixed
with `_prompt_held`, a lock, and the comment refuses a priority number by name).
The broadcast plate, where a second sentence *erases* rather than stacks (§96 —
`broadcast_busy`, ask-first, which is what enforces the procession's "read them
slowly"). And §113's red: `far_mark_locked` fired one line after
`hud.prompt(CANNOT_READ)` and replaced the refusal on the first-ever tap, for
the pilot least able to guess.

**Covered by:** four devices — `_prompt_held`, `clear_prompt_if(text)`,
`prompt_text()`, and `broadcast_busy()`/`toast_busy()` — plus §113's posture:
**arm on the refusal, fire at range-exit, stand down unspent if anything else
wrote first.** No leg covers the *class*; each instance is caught by reading.

---

## 5. A measurement column maintained by hand

**What happens.** A number describing the code is typed into prose. The code
moves. The number does not. The fix — retype it — is the fix that expires.

**Instances.** §73 found the README claiming 44 and 61 in two places that
disagreed with each other. §77 found 46 and 64 against a `TAGS` array holding 48
and a sweep of 66. §113 found "green at 758" for a sweep that was never run. And
`check_scripts.py`'s own header said "four checks" for two rules after it was
six — while §111 and §113 both said six.

**And a fourth instance, from the other end: a measurement that does not say
what it measured.** Three times in one horizon a sweep's counts looked plausible
and were correct for a tree nobody had checked — twice an old checkout, once
`main` while the work sat on a branch. The numbers were never wrong; they were
unattributed, which in a repo with two live trees is the same failure wearing a
different coat. `--counts`, `--legs` and the sweep summary now all print
`branch @ sha`.

**And a fifth, the worst of them: an ESTIMATE wearing a measurement's
clothes.** §114 published a table of sinks whose `credits` column was derived
from live constants and whose `loops` column was that column divided by a steady
loop somebody had guessed. The two columns looked identical. The guess was
~34,000; `PACINGTEST` prints 11,236, and it had been printing it on every sweep
for a week. The figure travelled through four documents and became the premise
of a whole horizon's commission before §123 converted one sentence of it into an
assertion and the leg went red on its first run (§124). Three companion figures
travelled with it, each one line of arithmetic away from being right.

**And a sixth, which is the fifth's mirror: the LEG was the wrong one.** Two
figures for the module catalogue — 1,106,200 in the docs, 846,200 from
`_pacing_catalog_cost` — coexisted for a week and were never compared, because
nothing is built to compare a number to another statement of itself. The leg was
missing `ModuleDB.BERTHS`, 23% of everything a run can buy, and it *could not*
go red over it: the catalogue is the denominator of both assertions that use it,
so under-counting makes each one stricter and still passing. An error that only
ever tightens a green test is invisible by construction. **Two numbers for the
same thing are a defect even while both are green.**

**And a seventh, the one that closed Horizon 12: a sweep total recorded from a
RED tree.** §122 wrote down "824 across 82" as the horizon's figure. It was
measured at `2f309ed`, which printed **one FAIL**, and nobody re-recorded it
after the fixes made it green. Seven sections later §129 built its own expected
total on it and was off by eight. The rule: **a measured figure carries the tree
that produced it, or it is an estimate with a decimal point** — and a sweep with
a FAIL in it produces no total worth keeping.

**And a sixth, from Horizon 12: a fixture holding a number typed beside the
thing it pays for.** `WORKS ARE A SINK` set `salvage = 30000` against a colony
ladder that totalled 28,000. Re-pricing it to 101,000 would have reddened the
leg with *"a work refused"* — a **pricing change reported as a mechanism
failure**, which is worse than a plain red because it sends the next reader to
the wrong file entirely. Every fixture purse in that test is now derived from
the prices it pays (§126).

**And a sixth, in the horizon that quotes this rule (§144).** §139 shipped
"+15% on the fastest legal fit" for the tide's flat 0.9 u/s, in three documents.
`compute_stats` is additive and `enforce_floors` sets no ceiling, so the fastest
legal fit is at minimum 5.75 + 5.00 = **10.75 u/s** before a rig — the true
figure is **+8.4%**, falling to +5.7% fully rigged. Wrong by roughly a factor of
two, written in the section that cites §124, by the author of §124.

**The defect is not the arithmetic.** The +56% on the 1.6 floor, derived from a
constant, was right. The other half was *estimated from a recollection of the
drive ladder and never derived from it* — and then repeated twice more, because
a figure in prose is copied, not recomputed.

> **A NUMBER YOU DID NOT DERIVE IS A NUMBER YOU GUESSED, HOWEVER CONFIDENT THE
> SENTENCE AROUND IT SOUNDS.**

The same failure ran on the sweep totals in the same week: 866 quoted as 864,
off a chain of hand-tracked deltas. §144's footer bound is the fix for that half
— the sweep now prints what the tree itself says to expect, so no human,
including this one, tracks it by hand again.

**Covered by:** `run_harness.sh --counts` (runs) and `--legs` (assertions), both
derived, neither needing the Godot binary; `tree_id` on every mode so a figure
carries its provenance; and `THE DEATH PRICE SITS IN ITS BAND`, which is what
turning a prose figure into an assertion buys. **If a number describes the code,
derive it or do not write it — say which code, and say whether it was measured,
derived or estimated.** A table that mixes the three without labels is drift with
a plausible surface.

---

## 2b. Two systems writing the same property

**What happens.** Two mechanisms both own one value. Neither is wrong on its
own; the one that writes more often wins, and it wins *silently* because
nothing anywhere compares them.

**Instance.** `UIKit.reveal_list` tweens a `Control`'s `position` to slide it
in. Both call sites put their labels in a `VBoxContainer` — which owns its
children's positions — and call the helper in the same frame the labels are
added, before the container has sorted. So `from` reads `(0, 0)`, the tween
drives every label **to** `(0, 0)`, and the tween beats the layout because a
tween writes every frame and a container sorts only when asked. A column of
copy collapses onto one corner. Live in `CAPTAIN'S LOG` since §118 and shipped
in the induction (§136).

**The standing instance to watch for.** `PlayerShip._tether_vel` is the game's
one shared write channel: `apply_tether` re-clamps it to the **last** caller's
cap, so any two mechanisms driving it in one frame settle the question by node
order. §139 is the first time two could — the tide stands down inside a storm's
pull radius for exactly this reason, and standing down is a *cease to drive*
rather than a `clear_tether()`, because zeroing a shared channel on the way out
is the same defect pointed the other way. **Anything new that calls
`apply_tether` owes this list an answer about who yields.**

A quieter form of the same shape is two readers of one fact, each carrying its
own copy of the rule. §139 refused an obvious early-out for that reason: the
band gate is inside `Tide.set_at` and nowhere else, because a second gate on the
hull's depth would have had a different edge from the one on the block's radius,
and the chart would have drawn arrows for water the hull is not pushed in.

**Why it hides.** Each half is individually correct and individually testable.
The container lays out properly; the tween tweens properly. **No instrument in
this repo watches one system fight another**, and both screenshots that found
it came from a person looking at a screen.

**The rule.** **Name the owner of every property that two things can write.**
A container owns `position`; animate something else, or animate outside the
container. And when an assertion covers an animated value, it must **say when
it looks** — §136's leg sampled two frames in against a reveal that runs a
third of a second, and would have passed on the broken build.

---

## 5b. A validity rule strict enough to be wrong

**What happens.** A loader validates a key against one format, a second format
arrives later, and the loader silently deletes the data rather than crashing on
it. A crash would have been found in a day.

**Instance.** `_bay_key_is_real` split a bay key on `:` and demanded **three**
parts, because a deep bay is a cell `system:x:y`. The BONDED ANNEX (§112) stores
under a colony key — `system:index`, **two** parts. Every annex bay was dropped
on every load for two horizons, and everything a pilot stowed in one vanished.
§16's *"nothing may vanish"*, broken by a function whose own comment calls the
warehouse *"the one save field that arrives with no structure guaranteeing
itself."*

Nothing could catch it. The loader is *supposed* to drop keys that fail
validation — that is its job — so the deletion looked exactly like the feature
working. It was found by §127 asking whether it was safe to double that bay.

**The rule.** **A validity test deletes; write the weakest one that is still
true.** The fix asks only that the colony exists, not that it has an annex: a
work cannot be un-built, so a bay without one is unreachable rather than
illegal. And **a loader that discards should say how much** — a silent drop and
a correct load are the same shape from outside.

**Covered by:** `THE VAULT SURVIVES ITS OWN LOADER` (COLONYTEST), which stows a
full bay and reloads it.

---

## 6. `String(x)` on a store that holds more than one type

**What happens.** `String(true)` is not a constructor GDScript has. The call
errors at runtime **and returns false anyway**, so surrounding assertions pass
while the log carries a script error: a green leg standing on a broken call.

**Instances.** `survey_filed` began holding `true` and `HELD` in §96. The bare
`String()` read errored on every counter-filed cell. Then — **in the same file,
minutes after the rule was recorded** — `files_with_the_network`'s first draft
wrote `String(survey_filed[k_v]) == HELD` and did it again.

**Covered by:** **one accessor per multi-typed store, and every other reader
calls it** (`is_survey_held`). That is the durable fix; "remember to use
`typeof`" demonstrably is not — it failed inside one file inside one hour.

---

## 7. Copy derived from a table under a false assumption about it

**What happens.** A hint line is derived from real data, which makes it feel
checked. The derivation assumes a property the data does not have.

**Instance.** §110's forge hint printed `SINK FALLS FROM READING BAND 2+
SALVAGE`. `READS_AS` is **not monotone in band** and never was, so a pilot
following the game's own printed instruction could read the Quiet forever and
never see four of the eight forge inputs. Worse: that line was itself a v22
*fix* for an earlier report of the same symptom — a fix restating the bug it
fixed.

**Covered by:** `THE HINT WOULD HAVE LIED`, which asserts **both halves** — that
at least one component breaks a `BAND n+` claim (or the copy change was
unnecessary and the leg measures nothing) and that the derived list is exactly
the yielding set. **Derive the list itself, never a claim about its shape.**

---

## 8. A leg that can pass by never reaching its case

**What happens.** The assertion is true and tests nothing, because the state it
describes was never entered.

**Instances.** §88's `THE MONUMENT ANSWERS A TAP` took whatever
`get_nodes_in_group("hyper")` returned first and demanded the unclaimed wording
— and first-in-tree was a *claimed* monument answering its claimed branch
perfectly. §108's `NO COUNTER CLOSES AT HOSTILE` needed a clause asserting at
least one fence actually closed, so it could not pass by never reaching HOSTILE.
`ONLY THE SHELF MOVES WITH STANDING` needed "and something rose" beside "nothing
fell."

**Covered by:** **the both-halves habit** — assert the change *and* that the
change happened. Pick by STATE, never by tree order.

---

## 9. A wired verb with no affordance

**What happens.** The feature is built, correct, and shipped. Nothing invites
the player to use it, so it does not exist.

**Instance.** §88's playtest: of nine notes, **six were systems working as built
that the game never introduced.** The claim hold had been wired since hyper
structures shipped; the select ladder just never picked `hyper`.

**And the same object again, two horizons later (§141).** A playtest reported
"completely unable to interact" with a hyper structure — the ladder from §88
working perfectly, `on_tapped` answering every branch, and the tap still unable
to land. `CameraRig._pick` was a **60-pixel test around a single anchor point**,
applied to every object in the game. That is correct for a hulk, a seam, a
beacon or a mark, all a few units across. It is exactly wrong for a 140-unit
object whose centre is off frame at claim range.

> **A VERB CAN HAVE AN AFFORDANCE AND STILL BE UNREACHABLE. THE RUNG IS NOT THE
> REACH.**

**Why the leg did not catch it.** COLONYTEST's `THE MONUMENT ANSWERS A TAP` was
written for §88 and stayed green throughout, because it calls `on_tapped()`
**directly**. It tested the verb; nothing tested whether a finger could get
there. A leg that drives a verb through its own function measures the function.
`AND THE TAP CAN REACH IT` (§141) is the missing clause: it projects the object,
taps 0.7 of its half-span off centre, and asserts the pick lands.

**Covered by:** §88 as a rule, and `EVERY RUNG SAYS WHAT IT BOUGHT` for skill
tiers specifically (a rung with no perk string fails). §111 killed two rungs
against it before they shipped. §141 adds `AND THE TAP CAN REACH IT` plus `AND
NOTHING ELSE WIDENED`, which asserts that `hyper` is the only group claiming a
world pick radius — the ladder's near-last ordering is what makes a wide radius
safe, and that argument holds only while it is the only one. **No mechanical
check exists for the general case** — it is caught by reading, and by tapping,
the surface a player actually touches.

---

## 9b. A system with no tell

**What happens.** The mechanism is correct, asserted, and shipping. Its only
way of announcing itself to the player cannot render. Class 9's sibling: there
the verb has no affordance, here the *system* has no evidence.

**Instance (§143).** A playtester found a tide, read the cockpit line, and
reported *"could not determine any effect ... no visual feedback related to the
tide that I could identify."* There was none to identify. The tide's entire
visual tell was a `CPUParticles3D` with **no mesh and no material** — a null
mesh renders nothing, and `color` only tints a material that is not there.
Three independent reasons it was invisible, any one of them sufficient:

| | |
|---|---|
| no mesh, no material | draws nothing at all |
| `amount 70 / lifetime 26.7s` | **2.6 particles a second** |
| a 240u emission box | the lens sees ~21u; ~99% off screen |

**It had already shipped once.** `storm.gd` built the eye's motes the same way
in v20 and went unnoticed for four horizons, because a storm also has an eye,
arms, a ring and a shockwave to be seen by. The tide had only the motes, which
is why the tide is what reported it.

**Why the legs were green.** TIDETEST was **10 for 10**. Every leg measured the
derivation (purity, density, the tangential bound) or the physics (the three-way
riding/athwart/against measurement). **No instrument in this repo can see a
renderer** — §129's observation, arriving somewhere new.

**And a second, quieter half of the same report.** *"it quickly disappeared from
my sensors."* It had not. The cockpit suffix only lit while `_riding`, which
requires the hull to be under way and aligned — so finishing a move order made
the line vanish. The readout conflated *there is water here* with *it is
carrying me*, and the player correctly read the result as the tide going away.

**Covered by:** `check_scripts.py` rule 8 (`check_particles`) — every
`CPUParticles3D.new()` must be given a `.mesh` in the same function, red-verified
against both shipped forms. Plus `AND THE WATER CAN BE SEEN` in TIDETEST, which
asserts the mesh, the material and the emission **rate**, since 2.6 a second
needed no renderer to be wrong. Rule 8 is the first rule in that file that is
not a parse error, and the footer had to be corrected to stop calling it one.

> **A HARNESS THAT MEASURES THE MECHANISM WILL GO GREEN ON A FEATURE NOBODY CAN
> SEE. ASSERT THE TELL, NOT ONLY THE RULE.**

**And the standing rule this class finally earned (§146).** Every defect that
has ever reached a player in this project — six of them — was found by an eye:
§88 and §141 by playtest, §134 and §136 by screenshots, §143 by a playtest
against a harness that was 10 for 10 at the time. **Zero by an assertion**,
against 866 legs and an instrument four times the size of the game.

So:

> **NO COMMIT TOUCHING A DRAWN SURFACE SHIPS WITHOUT A FRAME.**

`PYXIS_SURFACES` is what makes that cheap rather than a chore — one run, ~40
PNGs, every panel and every cockpit state. It carries **no verdicts** and joins
the cannot-fail family deliberately: this harness cannot tell a good frame from
a bad one, and a PASS line on it would be the "green that measured nothing" §77
names. The verdict is a human's; the frames are how they reach it.

---

## 10. A wrong arity, invisible without the binary

**What happens.** There is no Godot binary in the authoring environment. A
changed function signature is a parse error `check_scripts.py` cannot see, and
`check_refs` does not catch a bogus cross-class constant either — red-verified:
`PortPanel.PAINT_PRICE_TYPO` passes the static checker clean.

**Instance (a near-miss).** §108 needed `unit_price`, `buy_price`, `sell_price`
and `trend` to learn about a counter key. A fourth positional argument would
have touched ~21 harness call sites with no node in scope to read a cell from.

**Covered by:** **append with a default** — `port_key := ""` — so every existing
call site stays byte-identical and only the sites that need the new fact change.
Plus `run_harness.sh --parse`, which runs Godot's own parser over all 70 scripts
and is strictly stronger than anything static.

---

## Standing debts this document names

- ~~**`TITLETEST` cannot fail.**~~ **PAID (§120).** It was in `TAGS`, burned a
  run every sweep, and carried four print lines with their expectations in prose
  (`expect 0`, `expect false`, `expect ~0`) and no verdict anywhere — §107's
  MARKETTEST defect still live in a second tag, found by `--legs` on its first
  execution. Four assertions written; the sweep's CANNOT FAIL list is now empty.
  **The reusable part is the tell: a print that states what it expects is an
  assertion somebody stopped one line short of writing.**
- **`run_harness.sh` is macOS-targeted** and its save-untouched guard failed
  open anywhere else until Horizon 11 commit 1: `md5 -q` is BSD-only, so off a
  Mac every digest errored to `/dev/null` and the sweep printed
  `save intact ()` having compared nothing to nothing. Now resolved to `md5` or
  `md5sum`, and it exits rather than continuing without one. **Class 5 again**,
  and worth remembering when CI work starts: the sweep assumes a Mac in more
  places than the digest.

---

## The rule this document is really about

Of the fifteen ideas in Horizon 11's research pass, **five died against a
comment sitting exactly where the bad idea would have been typed** — the prompt
queue against `hud.gd`'s "A LOCK RATHER THAN A PRIORITY NUMBER", the harness
watchdog against `run_harness.sh`'s note about `PYXIS_BALANCE`, a colony work
taking stored alloys against `can_store`'s bonded-rule argument, a band-shifted
pressure front against `plan_cell`'s purity.

And exactly one refusal was **forgotten**: "operating costs", refused by §5 in
2026-08-04, scoped as a feature anyway on 2026-08-21, and never built, deferred
or mentioned again. The difference is not that it was written down. It was
written down. The difference is **where**.

> **Write the refusal where somebody would type the mistake.**
