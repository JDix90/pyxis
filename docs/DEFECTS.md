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

**Three forms, each found the hard way.** Bare math globals (§77), untyped
containers indexed (§106, in an autoload — loud), and the same in a **leaf**
class (§111, quiet: `survey_mast.gd` took `deep_space`, `system_db`,
`game_state` and the audio autoload down behind it, the pre-flight passed
because `main.gd` parses fine alone, and the sweep died at `SurveyMast.new()`
with "Nonexistent function 'new' in base 'GDScript'").

**Covered by:** `check_scripts.py` rules 4 (`check_infer`) and 6
(`check_container_infer`). Rule 6 collects every `const NAME := [` or `{` the
project declares and flags `:=` off a lookup into one, indexing **and** `.get()`
— so it is exact rather than heuristic, and a typed `Array[String]` is never
reported. Both forms were red-verified. Also `run_harness.sh --parse`.

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

**Covered by:** `run_harness.sh --counts` (runs) and `--legs` (assertions), both
derived, neither needing the Godot binary; and `tree_id` on every mode so a
figure carries its provenance. **If a number describes the code, derive it or do
not write it — and say which code.**

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

**Covered by:** §88 as a rule, and `EVERY RUNG SAYS WHAT IT BOUGHT` for skill
tiers specifically (a rung with no perk string fails). §111 killed two rungs
against it before they shipped. **No mechanical check exists for the general
case** — it is caught by reading the surface a player actually touches.

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
