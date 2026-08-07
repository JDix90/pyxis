# The Tally — Horizon 5, Stage 0−

**Status: SPECCED, NOT BUILT.** Recorded in `docs/STRATEGY.md` §64. When any of
it is adopted, update §64 in the same commit, per the house rule. Nothing below
exists in the build today.

This is **smaller than Horizon 5's own first stage** and it is deliberately the
first thing built. `docs/HORIZON-5-THE-CLAIM.md` §2 proposes a registry with
accounts, etched names and season leaderboards. This proposes one number.

> **Season 1 — 2,847 of 3,9xx soundings filed.**

That is the whole feature.

---

## 0. Why this instead of Stage 0

The review (`docs/HORIZON-5-REVIEW.md`) approved Stage 0 with seven conditions.
Four of them exist because Stage 0 has **accounts and names**: age assurance
(E-3), the counsel scoping call (E-4), the automation defence on a permanent
artifact (D-1), and claim granularity (A-1). Remove accounts and names and four
of the nine blockers do not arise — there is no identity to verify, no minor to
age-gate, no user-supplied string to moderate, and nothing permanent to steal.

What survives is the part that actually recruits. A filling frontier is a reason
to **arrive**; a leaderboard is a reason to **stay**, and a game with no players
does not yet have a retention problem. The plan's own §5 says the prize budget
"is spent as [marketing]" — this is the same instinct, three stages earlier and
for no money.

**And the game already earns it.** Deep space is salted on
`(system_id, cell_x, cell_z)` and not on `run_seed` — `DeepSpace.plan_cell`
takes no seed at all. Every player's PYX-01 at supercell (37, −12) has the same
landmark, in the same place, forever. **The shared frontier is not a feature to
build; it is a fact to reveal.** The only thing missing is a number that says so.

### What this deliberately is not

- **Not accounts.** No email, no OAuth, no identity, no login, no profile.
- **Not names.** Nobody's handle appears anywhere. No user-supplied string
  crosses the wire, so there is no moderation surface and no UGC.
- **Not a leaderboard.** No ranking, no comparison, no per-player anything.
- **Not currency, capsules, prizes, or a store.**
- **Not a gate.** See §6 — this is the invariant that keeps everything above
  true.

---

## 1. The unit — a sounding

**A sounding is a landmark, filed.** The key is
`(system_id, supercell_x, supercell_z)` — three integers.

Why the landmark and not the cell, the band, or the system:

| candidate | count | why not |
|---|---|---|
| per system | 3 | `is_system_charted` is a per-system boolean over `pyx01/02/03`. Three soundings in the entire game, taken on day one |
| per band | ~18 | Same problem, one order of magnitude up |
| **per landmark** | **~4,000** | **A discrete, visible, memorable object with an authored identity, and the count is a number a person can hold** |
| per cell | ~63,000 | Nothing is *there*. "Charted an empty cell" means nothing and the counter never visibly moves |

The landmark is also the only deep-space object the fiction already treats as a
place worth returning to — §68's cairn is *"hull plate stacked by hand, made of
ship, so whoever stacked it was not leaving in that ship."* A tally of monuments
sounded is a sentence the game can already say.

**Client and server agree for free.** `DeepSpace.landmark_cell(id, sx, sz)`
(`deep_space.gd:1295-1301`) is pure, salted on `(system_id, supercell)`, and
independent of every other roll — *"adding or removing landmarks cannot move a
rock."* The server never computes a position, never simulates, and never needs
the client's seed. It stores three integers and counts them.

### The act

**Recommended: hold-to-sound at the landmark**, reusing the hold gesture the
game already speaks (`derelict.gd`'s breach, the mast's recovery in §66). Within
some range of the monument, hold; a sounding is filed; the chart annotates it.

This is a **feel decision and it is the one thing in this document I cannot
argue from the code**, because feel is measured by playing. The requirement it
must satisfy is only this: **the act must cost something a bot would also pay.**
Proximity alone is not enough — the autopilot flies there for free (review D-4).
A hold is not much, but the point of §6 is that it does not need to be much.

---

## 2. The denominator, and why the frontier needs a stated edge

The counter needs a bottom half, and it is not obvious that one exists.

`band_of` returns `i + 1` and tops out at **6 — THE UNSOUNDED, at depth ≥ 5200,
which is unbounded outward.** `landmark_at` accepts any band in 1…6. So
**landmark sites extend forever** and the true count is infinite.

**So the tally counts to where THE UNSOUNDED begins, and no further.** A site
counts when `CONTENT_MIN_DEPTH (24.0) ≤ depth < BAND_EDGES[5] (5200)`.

This is arithmetic forced by the generator, and it happens to be the best line
the design could have drawn: **the chart has an edge; the Unsounded does not.**
Filling the tally does not mean the frontier is finished — it means you have
sounded everything that has a name, and what is past 5,200u was never going to
be counted by anyone. §68's whole subject was that THE QUIET had no far edge.
This gives the *tally* one without giving the *world* one.

### Deriving the number

**It must be derived and pinned, not estimated.** The geometry gives an upper
bound of ~3,955 supercells across three systems (π·(bounds+5200)² / (4·64)²,
summed), but the real figure is lower — every supercell whose chosen cell falls
inside `CONTENT_MIN_DEPTH` carries nothing. That subtraction depends on
`landmark_cell`'s salted pick, i.e. on Godot's `hash()`, which cannot be
reproduced outside the engine.

So:

```gdscript
# Derived by PYXIS_TALLYTEST enumerating every supercell inside the counted
# range and asking the generator. Pinned because a future horizon that adds a
# band, moves BAND_EDGES, or changes SUPERCELL/CELL moves this silently -- the
# same reason WORLD_FINGERPRINT_BEFORE_SEAMS is a constant and not a computation.
const FRONTIER_SITES := 0   # TODO: run the harness, paste the number
```

with `THE FRONTIER HAS A KNOWN SIZE` re-counting from the generator every sweep
and failing on disagreement. **Do not ship a denominator nobody has counted.**

---

## 3. The wire, and the contract fixture

Two endpoints. No auth.

```
POST /soundings     {"client": "<opaque>", "sites": [["pyx01", 37, -12], ...]}
                 -> {"total": 2847, "of": 3912, "season": 1}

GET  /tally      -> {"total": 2847, "of": 3912, "season": 1}
```

**The client posts the whole set it holds, every time.** The server unions it
into the global set. This is idempotent by construction, so there is no queue,
no ordering, no retry semantics, no partial-failure state, and no reconciliation
— a dropped request costs nothing because the next one carries the same payload.
It is also why offline needs no design (§5).

`client` is a locally-generated random opaque id. It exists **only** to
rate-limit and is never stored beside a sounding. It is not an account, it is
not personal data, it survives a reinstall no better than the save does, and
nothing in the game may read it back.

### The contract fixture

`docs/contracts/tally-v1.json`, **committed**, is the wire format:

```json
{ "version": 1,
  "cell": 64.0, "supercell": 4,
  "band_edges": [0.0, 160.0, 440.0, 1100.0, 2600.0, 5200.0],
  "counted_below": 5200.0, "counted_at_or_above": 24.0,
  "systems": ["pyx01", "pyx02", "pyx03"],
  "frontier_sites": 0 }
```

The client harness asserts its own constants against this file; the server's
build asserts *its* constants against the same file. **Neither talks to the
other at test time.** A divergence is a red diff, not a flaky network call.

This is the review's C-5 recommendation and it exists because of a specific,
already-observed failure mode: `BAND_EDGES` carries the comment *"Two more
bands, and the edges are appended rather than inserted"* — it has been extended
once already, and the next extension is a silent disagreement about where the
counted frontier ends. It is also the answer to §72's rule, **"assert the seams
you did not write"**: one person writing both sides means a stub only proves the
stub agrees with itself, so the *file* is the third party.

---

## 4. Save impact — v21

A new store, `soundings`, keyed by system id:

```gdscript
# v21. Filed soundings, keyed by system id, each entry a supercell [sx, sz].
# Deep-space PLAYER state -- the beacons/colonies side of the line, not the
# generated-content side (see §64's correction). Persisted because a sounding
# the player made and the server has must not be re-flown after a reinstall.
var soundings := {}
```

Following the `beacons` precedent exactly (§66): validated entry by entry on
load, non-integer and out-of-range entries dropped in file order so which
survive a corrupt file is deterministic.

**The grandfather, stated in §44's idiom — which way do we choose to be wrong.**
A v20 save has no `soundings` and arrives empty, so a player who has already
flown past forty monuments starts the tally at zero. That takes something away.
It is the right way to be wrong anyway: nothing was ever recorded, so there is
no *record* being destroyed, and the alternative — inferring soundings from
`ledger.deepest_depth` or from `breached` — would credit sites the player never
visited and put fabricated numbers into a shared count. **Prefer under-crediting
a real player over inventing a sounding.**

**And `soundings` is derived-not-stored where it can be.** The count shown to
the player is `soundings` summed across systems, never a stored integer, for the
reason §66:6264 gives about beacon stock: *"a hand-edited save cannot carry
'stock: 9' beside eight standing beacons."*

---

## 5. Offline — I-1, and it costs nothing

No connection: the tally line is absent, the game is otherwise **bit-identical**
to today. Soundings accumulate in the save and post whenever a connection next
exists. Nothing blocks, nothing spins, nothing retries in the flight loop, and
nothing about the world, the sweep or the save depends on the server having
answered.

If the server is switched off **forever**, the game loses one line of UI. That
is the whole cost, and it is the strongest property this design has: I-1 is not
a promise here, it is a consequence of the client posting a set it already owns.

---

## 6. The tally is a mood, never a gate

**This is the load-bearing invariant of the whole document, and everything cheap
about this design depends on it.**

Nothing in the game may read the tally to decide what a player gets. No unlock,
no reward, no rarity change, no achievement, no season transition that grants
anything. The number is atmosphere: it tells you the frontier is occupied.

**Why this is an invariant and not a preference.** The moment the number gates
something, it becomes worth attacking — and this design has *no* defence against
attack, deliberately. The world is enumerable offline, so a headless client can
post every site in the game in an afternoon (review D-1). There is no account to
ban, no identity to verify, no physics envelope worth checking (the autopilot
generates the trajectory, review D-4). **A soft number that can be inflated
costs nothing when it is inflated. A number that grants something costs
everything.**

So the honest posture, recorded so a future reader does not "fix" it:

- The tally is approximate and we know it.
- It may be inflated by a bot and the damage is that a number is wrong.
- Rate-limit posts and cap new sites per post, to keep it *roughly* honest.
- **Do not spend anti-cheat effort here.** Spend it if and when Stage 0's names
  arrive, which is the point at which there is something to steal.

`THE TALLY NEVER GATES` (§7) is a source-reading assertion for exactly this
reason: it is the kind of invariant a well-meaning feature violates in a dead
path first, which is the argument the plan itself makes for `ATTRIBUTION IS
EXPLICIT`-style checks.

---

## 7. Assertions — `PYXIS_TALLYTEST`

Red-verify every one by breaking its actual mechanism, never by inverting a
comparison.

- **`THE FRONTIER HAS A KNOWN SIZE`** — enumerate every supercell in the counted
  range, ask the generator, compare to `FRONTIER_SITES`. Fails when a band is
  added, `SUPERCELL`/`CELL` moves, or a system is added. *Red-verify: bump
  `BAND_EDGES`' last entry.*
- **`THE CONTRACT FIXTURE MATCHES THE CONSTANTS`** — read
  `docs/contracts/tally-v1.json` as text and compare every field against the
  live constants. *Red-verify: edit one number in the file.*
- **`A SOUNDING IS IDEMPOTENT`** — filing the same site twice leaves the local
  set and the derived count unchanged. *Red-verify: append without the
  membership check.*
- **`ONLY THE COUNTED RANGE COUNTS`** — a site inside `CONTENT_MIN_DEPTH` and a
  site past 5,200u are both refused. *Red-verify: drop either bound. Note the
  §71 lesson — a one-sided bound passes harder when the constants are zeroed, so
  **assert both ends and assert that something is countable at all**.*
- **`OFFLINE NEVER BLOCKS`** — with no transport, a full loop runs, the save
  round-trips, and no frame budget moves. *Red-verify: make the post synchronous.*
- **`THE TALLY NEVER GATES`** — read `scripts/` as text; assert no gameplay path
  reads the tally value. *Red-verify: add a line that grants salvage above a
  threshold.*
- **`A V20 SAVE ARRIVES WITH AN EMPTY LOG`** — `SAVETEST=migrate20`, plus a
  rubbish pass feeding malformed shapes and keeping exactly the valid ones.
  *Red-verify: default the key to a fabricated set.*
- **`THE COUNT IS DERIVED`** — a hand-edited save cannot carry a total that
  disagrees with its own entries. *Red-verify: store the integer.*

Eight assertions, one new tag, one new `SAVE_MODES` entry: the sweep goes from
**63 runs to 65** (a tag plus a migrate leg). Update the README's baseline in
the same commit — it was one horizon stale until 2026-08-07 and that is a
recurring defect, not an accident.

---

## 8. Hosting, and what breaks when it breaks

One process, one table (`system_id, sx, sz` with a unique index), two endpoints,
no session state, no user data, no scheduled work. A $5/month VPS with a nightly
`pg_dump`, or a serverless function against any managed store.

**Failure modes, all of them:** the server is down (the tally line is absent);
the disk is lost (the total resets, players re-post from their saves, and the
number rebuilds itself — because the client holds the truth and the server holds
only a union). There is no state on the server that cannot be reconstructed from
the clients. **This is the only piece of Horizon 5 with that property, and it is
why it is the one to build first.**

For §64's cadence question — the review's assumption 3 — this is also the cheapest
possible rehearsal of the thing nobody has tested: deploy it, leave it alone for
three weeks, and count how many times it wanted attention with nobody using it.

---

## 9. What this does NOT authorise

It is a lifted exclusion, not a queued feature — the §5 base-building formula,
applied to itself.

- **No accounts.** The moment identity exists, E-3 (minors), E-4 (counsel) and
  D-1 (a permanent artifact worth stealing) all arrive together.
- **No names.** UGC on a shared surface is a moderation function, and
  `_sanitize_ship_name` trims and truncates and does nothing else.
- **No leaderboard.** Ranking needs identity.
- **No money of any kind**, in either direction.
- **No second server feature** without re-reading §5's narrowed exclusion and
  amending it again, deliberately.

If the tally works — if people arrive because the frontier is filling, and stay
long enough to fill it — **that is the evidence Stage 0 was asking for**, and
Stage 0 becomes a decision with data behind it instead of a hypothesis with a
gate metric that cannot be computed.

---

## 10. Open questions

- **What is the act?** Hold-to-sound is the recommendation; it is a feel
  question and wants ten minutes of play, not an argument.
- **Season length.** The tally implies a reset. 8 weeks suits a small early
  playerbase; quarterly suits a frontier that fills slowly. **Measure the fill
  rate for two weeks before choosing** — the whole point of the counter is that
  it tells you this.
- **What happens at 100%?** A new season is the obvious answer, but "the
  frontier was fully sounded on 4 March and here is who was flying" is a better
  story than a reset, and the two are not exclusive.
- **Does the client show its own count beside the global one?** Probably yes; it
  is the closest thing to a personal stake that does not need an account.
- **Per-system tallies as well as global?** Three numbers is more texture; it
  also makes the emptiest system visible, which may be good or may just be sad.

---

*Companion when work begins: the server is small enough that its architecture
note is this document's §3 and §8. If it grows past that, it has stopped being
this feature.*
