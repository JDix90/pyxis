# Horizon 9 — The True Copy

**Status: COMMITS 0-2 BUILT (§96 v25, §97 no bump, §98 rides v25). Commits 3-5 specced, nothing built. Prose gated on `docs/FAR-MARKS-DRAFT.md`
(second draft; R1–R4 and S1–S3 answered).** When any of it is adopted,
record it in `docs/STRATEGY.md` §64 in the same commit, per the house rule.

Settled from the ideation rounds: filing point is **foreign beacons**; the
response is **all three payoffs**; filing **stays a donation**; the hold is
**two-stage**; the channel has **no fixed name**; the layup takes **deposits
and withdrawals**, and a deposit leaves one clause on the plate and no tally;
the Standing Order **hails before it fires**; the serpent **leaves rather than
dies**, so the mark stays live; escorts **do not survive a warp**; and the
legend set is **ten kinds**, generous and lethal in the same table.

### One sequencing decision, taken at build time

Commit 0's reply names a **bearing to a far mark**, and the marks are commit 2
— a forward dependency that would leave commit 0's best line hollow. Resolved
the way §84 resolved the same shape: **the pure generator ships first, the
nodes ship later.** `Rival` shipped as arithmetic that the world read before
anything drew it, and `far_marks(system_id, run_seed)` is the same kind of
object — pure, deterministic, world-invisible, fully testable without building
a single node. Commit 0 carries the generator and the bearing; commit 2 builds
buoys from it. Neither commit is left holding an unfinished half.

## What this answers

The founding sentence is *selling charts of places nobody has filed a return
from*. Horizon 7 made it literal, Horizon 8 let the player read the order, and
the last fragment asks for one thing: *file a return for us.* This horizon is
the player answering — and the answer is what makes the space past the archives
worth surveying.

**The two halves are one loop.** Filing with the network pays in *bearings* —
the only currency it has — and the bearings point at the network's sounding
marks. The far deep is marked; filing is what buys the literacy to read the
markings; the markings are where the legends stand. A pilot who never files
never learns to read a mark, and the far deep stays what it is today: empty.

## The two ledgers

Filing with the GSA: credits, first-filing bonus, Commission progress —
*counted, never read.* Filing with the network: give the goods, no credits, no
bonus, no registry — *read, and held.* Per batch of cells, chosen at the mast.
This is a verb, never an allegiance: no refusers faction row, no loyalty
counter, nothing tracked but the cells themselves.

**The Authority never notices, ever.** No standing shift, no Cordon reaction,
no interdiction, and the Commission's retired field never moves.
`THE MACHINES DO NOT KNOW` (§92) already polices the principle: betraying the
Authority is administratively invisible, which is the horror register keeping
its own rule.

---

## Commit order

Cheap and certain first; the expensive systems last, so the horizon can stop
after any commit and still be a whole thing.

| # | Commit | Save | Weight |
|---|---|---|---|
| 0 | THE FILED RETURN — two-stage hold on deep foreign beacons, provenance in the store, the channel's reply | **v25** | **BUILT (§96)** |
| 1 | THE TRUE CHART — held cells marked on the plot; the rival annotation re-read | none | **BUILT (§97)** |
| 2 | THE FAR MARKS — the buoys, their placement, the read/unread split | rides v25 | **BUILT (§98)** |
| 3 | LEGENDS I, the common three — VEIN, LAYUP (deposit + withdrawal), PROVING DRIFT | rides v25 | medium |
| 4 | LEGENDS II, the dangerous three — STILLNESS' GROUND, STANDING ORDER, SOUNDING SERPENT | none | large |
| 5 | LEGENDS III, the ongoing three — TALLY'S NURSERY, PATTERN FORGE, PROCESSION'S END | **v26** | largest |

**Commit 5 is the largest single mechanical addition since the horizon system**
— a capturable colony with a recapture clock, and an escort wing. It wants its
own research pass before it is specced in detail, exactly as the berths did,
and this document does not pretend to have done that yet.

---

## Commit 0 — THE FILED RETURN

**The gate** is hearing the ask, not knowing the order: `heard_the_request()`,
fragment 3 of the bearing-terminus record, one step past `knows_directive_9()`,
derived from `deep_logs` like both siblings. Zero new save for the gate.

**The verb** is R1's two-stage hold on a band-3+ foreign beacon: first
completion reads the page (`READ_TIME`, shipped), continuing past it files
(a second `FILE_TIME`, gauge relabelled to the terms). `reading()`'s
one-question pattern gains one sibling; the recovery refusal is untouched.

**What it does.** Every unfiled surveyed cell files at once — the mast's
one-gesture generosity, never a cell picker — and the chart goods equal to the
filing leave the hold. No credits, no bonus, no `chart_data_sold`. Filed cells
mark as **held**: `survey_filed`'s value goes `true` → `true | "held"`, a value
rather than a new set, so the subset invariant and the cap eviction are
untouched and the loader change is one line that preserves a value. That is the
v25 bump.

**The reply** rides the after-register's slot (read at fire time, next outward
crossing, once per batch), carries a sender picked by hash from R2's table, and
names a **bearing** (through `compass_deg`, §60) to the nearest unseen far mark
in the system — written to the captain's log so it survives the session.

**Harness (`PYXIS_RETURNTEST`):** the gate flips on fragment 3 exactly; filing
consumes goods, pays zero credits, moves no ledger term and no GSA standing;
held ⊂ filed ⊂ coverage as one chain; the cap evicts held cells like any other
(no exemption — §17's bound stands, and the wreck's log stays true); the
Commission page is byte-identical across a filing; the reply's bearing resolves
to a real mark; `migrate24` proves a v24 file loads with every filed cell
un-held and nothing else disturbed.

---

## Commit 1 — THE TRUE CHART

Held cells draw a second glyph on the plot — **shape, not hue** (§30) — a small
open ring meaning *a copy exists*, plus one legend row. The player's chart
becomes two documents: what the Authority counted, and what the network holds.
The rival's *somebody was first* annotation re-reads as colleagueship once any
cell is held (derived, no flag).

**Harness:** legend row present; ring on held and absent on merely-filed (both
directions, `THE CHART REMEMBERS`' discipline); annotation flips on the derived
flag and only on it.

---

## Commit 2 — THE FAR MARKS

**What they are.** Sounding buoys standing **6,500u–9,000u** out, past
everything the game has ever placed. `far_marks(system_id, run_seed)` on
`hyper_positions`' exact pattern: deterministic, independent depths, a fixed
oversample so the draw count does not depend on what it rolled, and zero draws
from any shared stream. **Five per system, fifteen in a run.**

**Kind assignment is the new part.** Ten kinds, two classes:

- **COMMON** (VEIN, LAYUP, PROVING DRIFT) may repeat.
- **SINGULAR** (the other seven) appear **at most once in an entire game**, and
  a given run does not carry all of them. Placement draws singulars first from
  a seeded shuffle across the whole run's mark set, then fills the remainder
  with commons — so meeting a serpent is an event, and a run that has no
  serpent in it is a normal run.

That "not every run has everything" is the design, not a shortfall: it is what
makes a legend something a player describes to somebody else rather than a
checklist row.

**Everyone sees a mark; only filers can read one.** An unread mark answers the
tap honestly (*the notation is not the Authority's*) — a thing you can see and
never touch is §88's monument problem, and the answer is also the teaching.
Reading a mark resolves it and is what spawns the encounter.

**Persistence: `marks_seen`,** keyed `"system:index"`, `structures_seen`'s
posture — generator-bounded at fifteen entries, validated against `far_marks`
on load, riding v25. Per-mark resolved/claimed state lives in the value.

**Own group (`"farmark"`), no scanned group, no radar tier** — the archives'
arguments, which hold harder this far out.

**Harness:** bounded and deterministic; every mark inside the authored window
and past the archives; the fingerprint pair unmoved; singular kinds never twice
in one run over a sweep of seeds; unreadable to a non-filer and resolvable by a
filer, both through the real tap.

**BUILT as §98,** with three things the spec did not anticipate. (1) A station
keep-out is needed after all: band 6 has no outer edge and `STATION_CHANCE[6]`
is 0.135, so about one mark a run would otherwise stand inside a deep station's
keep-out where the tap ladder resolves to the dock ring. The builder NUDGES
(bounded arc offsets, ≤204u ≈ 1.7° at seven thousand units) rather than
rerolling, because the channel quotes a bearing to the generator's answer.
(2) `marks_seen`' value is a validated STATE STRING from the first line rather
than a boolean, so commits 3–5 add a word to a list instead of a type to a
store — §96's loader defect paid forward. (3) Reading a mark shows its PLATE,
written in the past tense as a record of a sounding, so the same sentence is
true before and after the encounter it names exists.

---

## Commits 3–5 — the legends

Full prose in the draft. Mechanically, the set is chosen so that **nine of the
ten ride machinery that already exists** — seams, hulls, hostiles, colonies,
broadcasts, the hold gesture — and only the escort wing is genuinely new.

| kind | class | verb | rides |
|---|---|---|---|
| THE VEIN | common | mine | `MineableSeam`, band-6 parameters |
| THE LAYUP | common | crack, **and deposit** | `Derelict` + one new expressive verb |
| THE PROVING DRIFT | common | crack | `Derelict` + prototype module tier |
| THE STILLNESS' GROUND | singular | **wait** | a field effect; no combat at all |
| THE STANDING ORDER | singular | fight (hails first) | `ApexBoss`, GSA paint |
| THE SOUNDING SERPENT | singular | fight (segmented, alive) | new movement, no new AI framework |
| THE ORRERY STILL RUNNING | singular | hold | the chart-good economy, one windfall |
| THE TALLY'S NURSERY | singular | **take, then keep** | colony machinery + a recapture clock |
| THE PATTERN FORGE | singular | print escorts | **genuinely new** |
| THE PROCESSION'S END | singular | read, deposit | copy and one verb; pays nothing |

**The economy rule, stated before PACINGTEST asks:** legends are **windfalls,
never income** — the charted seams' own posture. No pacing term, no profile
entry. A network filer trades steady counter money for access to the deep's
windfalls, and that asymmetry is the answer to "worth it despite the
donation". It must never be flattened into a second salary.

**The prototype rule:** the PROVING DRIFT's modules sit above the Mk V line and
each carries a real defect. *"Nothing in the catalogue is a straight upgrade"*
is a law here, and a legendary is not an exemption from it. `ALL-BEST IS STILL
OUT OF REACH` (§94) is re-derived against the prototype tier and must still
hold — if a prototype closes the power margin, the prototype is wrong.

---

## What this horizon must not become

- **A loyalty system.** Filing is a verb per batch. No faction row, no counter.
- **A punishment for filing with the GSA.** The counter stays exactly as good.
  The network route is additive: different pay, different places.
- **An eviction exemption.** Held cells age out of the 400-cell cap like every
  other cell. The wreck's log stays true.
- **A fleet game.** The escorts take no orders and no bearings, and per S3 they
  do not survive a warp. The charted side stays exactly as hard as it is.
- **An explanation.** Not the Stillness, not the serpent, not the Tally, not
  whoever built the forge. Marks say *that*, never *why*.
- **A checklist.** Fifteen marks and ten kinds exist; the game never says so,
  and nothing anywhere counts them.
