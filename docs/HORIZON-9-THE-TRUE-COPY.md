# Horizon 9 — The True Copy

**Status: SPECCED, nothing built. Commits 0–1's prose is gated on the
read-aloud (`docs/FAR-MARKS-DRAFT.md`, decisions R1–R4).** When any of it is
adopted, record it in `docs/STRATEGY.md` §64 in the same commit, per the house
rule.

Three decisions arrived answered from the ideation round and are settled here:
the filing point is **foreign beacons** (the write-mirror of the page read);
the response is **all three payoffs** (the plate answers, provenance on the
chart, the rival re-read); and filing **stays a donation** — the goods are the
price and the response is the pay.

## What this answers

The game's founding sentence is *selling charts of places nobody has filed a
return from*. Horizon 7 made that sentence literal — the returns were refused,
not lost — and Horizon 8 let the player read the order that did it. The last
fragment of THE LAST RETURN asks for one thing: *"file a return for us."*

This horizon is the player answering. And it answers the standing playtest
demand with the same stroke: **what makes the space past the archives worth
surveying**, especially for a pilot giving up counter money to do it.

The two halves are one design. Filing with the network is what buys the
ability to *read the deep's own markings* — and the far deep is marked. The
reward for refusing the Authority's ledger is literacy in the only chart out
there that is true.

## The two ledgers

What filing means today: sell charts at a counter → credits + first-filing
bonus + Commission progress → counted, never read. What filing with the
refusers means: give the chart goods away at a deep foreign beacon → no
credits, no bonus, no Commission movement → **read, and held**. The Authority
counts; the network remembers. The player chooses per batch of cells — this is
a verb, not an allegiance, and nothing anywhere tracks a "loyalty".

**The Authority never notices, ever.** No GSA standing shift, no Cordon
reaction, no interdiction, and the Commission's retired field never moves.
`THE MACHINES DO NOT KNOW` already polices the principle; betraying the
Authority is administratively invisible, which is the horror register keeping
its own rule.

---

## Commit order

| # | Commit | Save | What it is |
|---|---|---|---|
| 0 | THE FILED RETURN — the write verb on deep foreign beacons, provenance in the store, the plate's answer | **v25** | The verb the last fragment asks for |
| 1 | THE TRUE CHART — held cells marked on the chart plot; the rival annotation re-read | none | The two remaining payoffs, both copy and drawing |
| 2 | THE FAR MARKS — the network's sounding marks past the archives, visible to everyone, readable only by filers | **v25 rides commit 0's bump** (`marks_seen`, generator-bounded) | The discovery layer |
| 3 | THE LEGENDS — what stands at a mark: four authored encounter kinds, two generous, one dread, one fight | none beyond commit 2's store | The payoff layer |

Commits 0–1 are small. Commits 2–3 are the horizon's weight and want their own
adversarial pass before the user sweeps — they touch generation, and
generation is where this project's worst bugs have lived.

---

## Commit 0 — THE FILED RETURN

**The verb.** A deep foreign beacon (band 3+, the ones that carry pages) gains
a third answer: with unfiled surveyed cells in the log AND the request heard,
the hold offers to file. The read verb and the recovery refusal are untouched;
`reading()`'s one-question pattern grows one sibling.

**The gate is hearing the ask**, not knowing the order:

```gdscript
func heard_the_request() -> bool:
    # Fragment 3 of the bearing-terminus record -- "file a return for us."
    # One step past knows_directive_9 (stage 2). Derived from deep_logs like
    # its two siblings; zero new save for the gate itself.
```

**What it does.** Every unfiled surveyed cell files at once — the mast's
one-gesture generosity, not a cell picker — and the chart goods equal to the
filing leave the hold. No credits, no bonus, no `chart_data_sold`. The cells
mark as **held** rather than merely filed: `survey_filed`'s value goes from
`true` to `true | "held"` — a value, not a new set, so the subset invariant
and the cap eviction are untouched and the loader change is one line
preserving the value. That is the save bump (v25).

**The plate answers** on the next outward band crossing — the same
read-at-fire-time slot the after-register uses, one broadcast, once per filing
batch. And the answer carries **a bearing** (through `compass_deg`, §60's
rule) to the nearest unseen far mark in the system, written into the captain's
log so it survives the session. That is the discovery loop: file a return, and
the network tells you where it has sounded. The network pays in bearings — the
only currency it has.

**Harness (`PYXIS_RETURNTEST`):** the gate flips on fragment 3 exactly; filing
consumes goods and pays zero credits and moves no ledger term; held is a
subset of filed is a subset of coverage (three stores, one chain); the cap
evicts held cells like any others (no exemption — §17's bound stands); the
Commission page and GSA standing are byte-identical across a filing;
`migrate24` proves a v24 file loads with every filed cell un-held and nothing
else disturbed.

---

## Commit 1 — THE TRUE CHART

**Provenance on the plot.** Held cells draw with their own mark — shape, not
hue (§30): filed cells today are one glyph, held cells gain a second, a small
open ring ("a copy exists"). The chart legend gains one row. The player's
chart visibly becomes two documents: what the Authority counted, and what the
network holds.

**The rival re-read.** Once the pilot has ever filed with the network (any
held cell — derived, no flag), the "somebody was first" annotations change
register: from sting to colleagueship. The wreck's log already told them the
truth of it; this is the surfaces catching up. Copy only, in the places that
already render the annotation.

**Harness:** legend row present; ring drawn for held and not for merely-filed
(both directions, the CHART REMEMBERS discipline); annotation text flips on
the derived flag and only on it.

---

## Commit 2 — THE FAR MARKS

**What they are.** The network's sounding marks: buoys standing past the
archives, **6,500u–9,000u**, further than anything the game has ever placed.
Bounded by construction on `hyper_positions`' exact pattern:
`far_marks(system_id, run_seed) -> [{pos, kind}]`, at most **FAR_MARKS_MAX
(4)** per system, deterministic, independent depths, zero draws from any
shared stream. Twelve marks in the whole game, findable only by flying
further out than the archives — which answers "what makes it worth going
beyond there" with geography, the way this game answers everything.

**Everyone sees them; only filers can read them.** A mark builds for every
pilot (a thing you can see but never touch is the monument problem, §88 —
so the unqualified tap gets a real answer: *the notation is not the
Authority's, and you cannot read it*). For a pilot who has filed with the
network, the same tap resolves the mark: names it, says what the network
sounded here, and states the terms — because the network's marks are honest
with their own people. Reading a mark is what spawns its encounter.

**Persistence: `marks_seen`,** keyed `"system:index"`, `structures_seen`'s
exact posture — generator-bounded at 12 entries, validated against
`far_marks` on load, riding commit 0's v25 bump. Claimed/resolved state per
mark lives in the same store as a value.

**Own group (`"farmark"`), no scanned group, no radar tier** — the archives'
own arguments, all of which hold harder out here.

**Harness:** bounded and deterministic (same seed twice, identical); every
mark past the archives' depth and inside the authored window; no draw moved
(the fingerprint pair, run against a probe at these depths); unreadable to a
non-filer and resolvable by a filer, both through the real tap.

---

## Commit 3 — THE LEGENDS

Four kinds at launch, authored in the mark table, seeded per mark — a given
mark is always the same legend, §17's determinism. Two generous, one dread,
one fight, per the ideation decision: *good and bad, rewarding or dangerous —
the great unknown.* Full prose in the draft doc; mechanics here.

| kind | what stands there | the shape of it |
|---|---|---|
| **THE VEIN** | a seam field richer than anything charted — band-6 ore at multiples of the best charted yield | pure windfall, in weather. Mining machinery exists (`MineableSeam`); this is parameters, not a class |
| **THE LAYUP** | a refusers' cache: a hulk-shaped store of goods and salvage, unrigged, enormous | the crack machinery exists (`Derelict`); one-time, `marks_seen` remembers |
| **THE STILLNESS' GROUND** | the mark warns: *it passes here*. Enter and the drives go quiet — a becalming, not damage — and something crosses the field while you drift. Survive the stillness (it ends), and the mark's far side holds the reading | the dread one. Names one of the three unknowns the survey register only ever described. No new combat: the encounter is waiting, which is this game's oldest verb |
| **THE STANDING ORDER** | a GSA heavy asset, still in service, past the terminus where no order ever reached it. It does not know the survey ended. It will not be told | the fight. The most dangerous thing in the great unknown is the Authority's own machinery — Directive 9 page 4, met in person. First-kill bonus at apex scale |

**Economy note, stated for PACINGTEST before it is asked:** legends are
windfalls, not income — the charted seams' own posture ("a windfall rather
than an income"). No pacing term. A network filer trades steady counter
income for access to the deep's windfalls; that asymmetry is the answer to
"worth it despite the donation", and it must never be flattened into a second
salary.

**The unknowns stay unexplained.** THE STILLNESS' GROUND shows an effect and
a crossing shadow, never an anatomy. The rule that the deep's nature is never
mechanized survives contact with an encounter named after it — the mark warns
*that* it passes, and nothing anywhere says what it is.

---

## What this horizon must not become

- **A loyalty system.** Filing is a verb per batch, not an allegiance. No
  refusers faction row, no counter, no "network standing".
- **A punishment for filing with the GSA.** The counter stays exactly as good
  as it is. The network route is additive: different pay, different places.
- **An eviction exemption.** Held cells age out of the 400-cell cap like
  everything else. The wreck's log stays true.
- **An explanation.** Neither the Stillness nor the deep gets an anatomy. The
  marks say *that*, never *why*.
- **A quest log.** No mark counter, no legend checklist. Twelve marks exist;
  the game never says so.
