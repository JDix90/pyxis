# Horizon 14 — THE MIDDLE (research pass)

Opened 2026-08-22, on the owner's commission after a play session:

> *"The regions between 1000u and 5000u all seem kind of… boring. Things change
> and the threat heightens, but once I'm out there my only motivation is to go
> further."*

**Nothing here is built.** This is the research pass. Two decisions were taken
at the fork before it was written: **all three directions are researched as one
horizon**, and **`RICHER OUTWARD` is never broken** — deeper stays better
per-unit at everything, and the middle has to earn its place some other way.

---

## 1. The measurement: every reward curve is monotone in depth

Every per-band table in `deep_space.gd`, `commodity_db.gd` and the loot
multipliers, read together. There is not one exception:

| | b3 REACHES 440–1100 | b4 QUIET 1100–2600 | b5 FATHOMS 2600–5200 | b6 UNSOUNDED 5200+ |
|---|---|---|---|---|
| station chance | 0.075 | 0.095 | 0.115 | 0.135 |
| hulk chance | 0.19 | 0.24 | 0.28 | 0.32 |
| hulk loot multiplier | ×2.2 | ×2.9 | ×3.7 | ×4.6 |
| salvage grade base | 230 | 340 | 480 | 620 |
| chart data base | 210 | 300 | 410 | 540 |
| seam chance / units | 0.38 / 4 | 0.45 / 5 | 0.51 / 6 | 0.56 / 6 |
| debris | 0.58 | 0.66 | 0.72 | 0.78 |
| pack chance / HP | 0.42 / ×2.4 | 0.50 / ×3.2 | 0.56 / ×4.0 | 0.60 / ×4.9 |
| trap chance | 0.38 | 0.50 | 0.60 | 0.68 |

**"My only motivation is to go further" is the correct reading of this table.**
The middle is never optimal for anything; it is a place a pilot outgrows.

**And no new noun appears between band 2 and band 6.** Stations, rocks, seams,
hulks, packs, traps, guards, landmarks, convoys — the same list at every depth,
with only the numbers moving.

## 2. Where every phenomenon lives

`Storm.band_floor()` returns `BAND_EDGES[-1]` — **5,200u** — and `spawn_storm`
refuses shallower. The file's own header is *"WEATHER IN THE UNSOUNDED"*.

So the one environmental system in the game, and its own description of itself
as *"the only thing in this game that will kill you without shooting at you"*,
**begins exactly where the boring stretch ends.** Between 1,100u and 5,200u
nothing happens to a pilot that is not a fight.

## 3. What dies before anything is proposed

**The Rival is not the cause.** The obvious theory — the middle feels
picked-over because somebody else already filed it — is refuted by its own
arithmetic. `arrival_seconds = 1800 + depth × 60 × jitter[1,3]`, so the
*earliest* claim at the band-4 floor is **~18.8 hours of play**. Its own comment
says the shallows go in single sessions and the deep belongs to whoever flies
there. The middle is never claimed in a real run.

**Landmarks must not start paying out.** `landmarks.gd` refuses it in writing,
and the reason is right: *"an object that pays out stops being a landmark and
becomes another errand."* `TASTE` under §131, and this pass does not ask to
amend it — §5 below finds a use for landmarks that keeps them scenery.

Worth recording, though, that the same comment contains the complaint from the
person who built it: *"the expanse already has four things to do in it."*

## 4. The diagnosis

**The expanse is a gradient, not a geography.** A gradient has one axis and one
direction. A place is somewhere that

1. has something you cannot get elsewhere,
2. where something *happens*,
3. that accumulates over time,
4. and that rewards knowing it.

The middle has (1) as scattered points — colonies at 1,600–4,200, the Last Watch
at band 4+, the Breakwater at band 5+ where the Mk III weapons are bought — and
**nothing of (2), (3) or (4)**. Every one of those points is a destination you
fly to, use, and leave; the space between them is pure ramp.

(3) and (4) are precisely the vocabulary Horizon 12 built for colonies — works,
the Archive's file, the Light's watched ground. None of it reaches the water.

> **THE MIDDLE BANDS SHOULD BE THE REGION A PILOT KNOWS, NOT THE REGION THEY
> SURVIVE.** The deep is where you go; the middle should be where you live. That
> is achievable without touching a single yield.

## 5. Direction A — reward AREA, not depth (the sheet)

**The one reward shape that does not fight `RICHER OUTWARD`**, because it pays
for *coverage* rather than value-per-unit. And it self-balances by
survivability: a pilot can finish a block at 2,000u and would die trying at
5,000u — so the middle becomes the best place to do it **without a single number
moving in its favour.**

### The verb already exists

`survey_coverage` records cells worked (a mast planted, a deep berth charted);
`survey_filed` is the subset sold to the Authority, with a **first-filing bonus
once per cell, ever**. `SURVEY_CELL_CAP` is 400, held as a window.

### And so does the unit

`DeepSpace.SUPERCELL := 4` — a **4×4 block of 64u cells, 256u square, sixteen
cells** — already exists, and **landmarks are placed one per supercell.**

That is the whole shape of the proposal:

> **A COMPLETED SHEET ALWAYS CONTAINS EXACTLY ONE LANDMARK.** The landmark
> becomes the *name* of the region a pilot finished — and stays scenery, paying
> nothing, exactly as its refusal requires. It is "somewhere to be" and the
> sheet is "somewhere you finished", and the first gives the second a name.

| | |
|---|---|
| sheet | 16 cells, 256u × 256u |
| THE QUIET | 5.9 sheets deep |
| THE FATHOMS | 10.2 sheets deep |
| `SURVEY_CELL_CAP` 400 | exactly 25 full sheets |

That last row is a finding rather than a coincidence to lean on: the cap is a
*window*, so a completed sheet must record its completion as a **fact about the
sheet**, never as a set of cells that can age out from under it.

### Open questions for the spec
- **Is 256u the right grain?** It is quick to sweep. A sheet that takes ninety
  seconds is a chore; one that takes ten minutes is a project. Measure before
  choosing, §114's posture.
- **What does a sheet pay?** It must not be credits scaled by band — that
  re-introduces the gradient. §26's currencies are the candidates, and *access*
  or *information* fit best.
- **§11**: a sheet bonus is once-ever per sheet like the first-filing bonus, or
  it is a printer with geometry.

## 6. Direction B — weather in the middle

The Unsounded has storms. The Quiet and the Fathoms have nothing. The strongest
single argument in this whole pass is §2: **the only environmental system in the
game starts at exactly the depth the complaint stops at.**

The shape that fits the laws: **a phenomenon that is not a hazard, and pays in
time.** Storms take; this would give — a drift or current that carries a hull
along a bearing. §26's currency, unable to be a money printer, and it makes
*route knowledge* into something a pilot owns.

- `Storm` already proves the mechanism: it moves a ship through
  `apply_tether`, which re-clamps whatever is passed to it, so *no constant
  below can build a cage.* A current would use the same door in the other
  direction.
- The band names are already written for it: **THE QUIET**, **THE STILL WATER**
  (pyx03), **THE LAPSED** (pyx01). The fiction is waiting.
- Cost is real: storms took a commit of their own, and this is the most
  expensive of the three.

### Open questions
- Does a current show on the chart, or is it learned? Learned is stronger and
  fits "rewards knowing it"; shown is kinder.
- Does it interact with the sheet? A sheet you finished could remember the
  currents through it — which is (3) and (4) at once.

## 7. Direction C — home waters

Colonies sit at 1,600–4,200 — **inside the complaint's range** — and Horizon 12
made them the largest sink in the game. But every work faces the deep or the
colony itself: the relay and repeater carry *market weather*, the Archive files
*deep counters*, the vault and yard serve the *hull*. The **Light** (§128) is
the only work that reaches into the surrounding water at all, and its reach is
350u.

So the weakest direction alone — colonies are already there and it is still
boring — and the most continuous with what just shipped. Its real value is as
the place the other two are *spent*: a work that reaches into the band around it
turns a colony from a destination into a centre.

`work_aura_at(x, z, work, radius)` (§127/§128) is already general over radius,
so the mechanism costs nothing.

### Open questions
- What may a work grant across a band without breaking §51 (*only the player
  depletes the world*) or minting survey coverage for free?
- Does a colony know its own sheet? That is the braid, and it is the most
  interesting single question in this document.

## 8. How the three braid

They are complementary rather than parallel, and the braid is the argument for
taking all three:

- **A gives a reason to stay** — an area worth finishing.
- **B gives something to happen** while you are staying.
- **C gives somewhere for it to accumulate** — the colony that already sits in
  the middle becomes the centre of the water around it.

Each is weaker alone. A without B is a chore with no texture; B without A is
weather nobody is out in; C without either is what shipped in Horizon 12 and is
the thing the owner is describing.

## 9. What must not happen

- **`RICHER OUTWARD` holds** (owner's decision, taken at the fork). Both legs
  stay green; no seam, salvage grade or chart good is re-priced.
- **No landmark pays out.** §5 uses them as names, never as errands.
- **No new roll anywhere but the end of `plan_cell`, on its own salted stream.**
  `landmark`, `seams` and `convoy` were all added exactly that way and the
  file's comments explain why twice; the world fingerprint is the check.
- **No per-cell save.** §17's *"revisiting a sector costs zero bytes"* — a sheet
  records the sheet, never its cells, and the `SURVEY_CELL_CAP` window is the
  reason that is a requirement rather than a preference.
- **Nothing that makes the middle richer than the deep.** The middle earns its
  place through coverage, knowledge and presence. If it ever pays better per
  unit, this pass failed.

## 10. Next steps

1. Owner reads this and picks the grain question in §5 (or defers it to a
   measurement).
2. Spec doc, then commits — most likely A first (cheapest, law-safe, and the
   other two attach to it), B second, C as the braid.
