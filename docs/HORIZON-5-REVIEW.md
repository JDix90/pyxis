# Horizon 5 ("The Claim") — Independent Review

Engagement: review `docs/HORIZON-5-THE-CLAIM.md` and the transformation it
proposes, before implementation.

Reviewed against: `317327d` (main, merge of PR #40), working tree clean.
Date of review: 2026-08-07.

---

## 0. What this review could and could not examine

**`docs/HORIZON-5-THE-CLAIM.md` does not exist.** Not in the working tree, not
in `main`, not in any of the six remote branches, not in any commit reachable
from any ref, and not anywhere else on this machine.

The searches, so they can be repeated:

| check | result |
|---|---|
| `ls docs/` | `HORIZON-3-COMMISSION.md`, `HORIZON-4-FACTIONS.md`, `STRATEGY.md`. Nothing else. |
| `git log --all --diff-filter=A --name-only -- '*HORIZON-5*' '*CLAIM*'` | empty |
| `git log --all --pretty=format: --name-only --diff-filter=A \| sort -u \| grep -i horizon` | `docs/HORIZON-3-COMMISSION.md`, `docs/HORIZON-4-FACTIONS.md` — the complete set of horizon documents that have ever existed in this repo |
| `git branch -r` after `git fetch --all` | 6 branches, none named for horizon 5 except this review's own branch |
| all 40 pull requests, `state: all` | none mentions horizon 5, claims, capsules or derbies |
| `grep -rIl "capsule\|derby\|sweepstake\|claims server\|premium currency" /` | no matches anywhere on the filesystem |
| `~/.claude/plans/` — where §64:6016 and §64:6042 record that this project's specs actually live | directory does not exist in this container |

The last row is the likely explanation rather than a mystery. STRATEGY §64:6042
records the established pattern in this project: *"The horizon is specced in full
in `~/.claude/plans/i-have-indeed-tested-fuzzy-parnas.md` — **outside the repo,
which is most of why these went unnoticed**."* Horizon 5 has almost certainly
been written; it has not been committed. That is finding **F-1** below, and it
is not a clerical complaint — §64 exists *because* out-of-repo plans caused this
project's two longest-lived documentation defects.

### What follows, and what it is worth

I did not review the document. I cannot, and I will not simulate having done so.
Specifically, **the following were requested and are not delivered, because
delivering them would mean inventing the text they assess**:

- the attack on invariants **I-1 … I-8** (I do not know what they say);
- the red-team of **§9** (anti-cheat) — I do not know what attacks it lists, so I
  cannot report "what §9 does not list";
- the coherence check of **§10** (compliance ledger) and **§11** (psychology
  ledger);
- the feasibility check of **§12**'s contract-test approach *as written*;
- the per-stage gate assessment for **Stages 0–4** as the plan defines them,
  including its stated gate metrics.

Two things I *can* do, and have:

1. **Verify every claim the brief attributes to the plan against the code and
   the STRATEGY record.** The brief quotes three directly — "the Hunt intel
   dossier machinery can be repurposed for capsule rumors", "deep space persists
   nothing", "the save schema needs no bump" — and asserts a dozen more as
   background fact. These are checkable without the document, and checking them
   turned out to be the most productive part of the engagement: **two of the
   three named claims are false** (**C-1**, **C-3**), one of them in a way that
   has already shipped as a defect in a code comment (**C-2**), **and three of
   the brief's own background premises are wrong** — the platform (**F-3**), the
   assertion baseline (**F-4**), and the existence of a stated emotional core
   (**A-2**).

2. **Assess the thesis as the brief describes it.** The brief is a substantial
   summary — thin claims server, server-placed capsules, closed-loop premium
   currency, daily rumor economy, purchasable private regions, subscriptions,
   free-entry sweepstakes derbies, Stage 5 paid tournaments parked. That is
   enough to test the thesis against the project's founding decisions and its
   measured economy, which is where the blocking problems are.

Every finding below cites a file and a line. Where I am reasoning rather than
measuring, it says so.

**One thing I could not do at all:** there is no Godot binary in this container,
so I could not run `tools/run_harness.sh`. The 616 PASS / 0 FAIL baseline is
unverified by me. Given this project's own repeated lesson that *"a baseline is a
measurement with an age on it"* (README:163), treat my citations of it as
citations of the README, not as measurements.

### A note on the brief itself

The brief closes by quoting this repo's house rule — *"red-verify everything, and
be suspicious when the setup is elaborate"* (README:267). The rule applies to
the brief. It is an elaborate setup: eight numbered invariants, four numbered
ledger sections, five gated stages, a specific assertion count, a specific run
count. Three of its factual premises about the project are wrong (**F-3**,
**F-4**, **A-2**), which is roughly the error rate you would expect from a
document written *about* a codebase rather than *against* one. That is the same
failure mode §64 was created to fix, and it is why every number in this review is
followed by the command that produced it.

---

## 1. Verdict

# DO NOT PROCEED.

Not "proceed with changes." Two independent grounds, either one sufficient on
its own, and neither is about the quality of the plan's argument — which I
haven't read and which is, by all accounts, good. Well-argued is the warning
sign here, not the reassurance: *"several of this repo's worst shipped defects
lived behind well-argued documents and green checks."*

**Ground 1 — process.** A five-stage transformation carrying real-money prize
events, a premium currency, subscriptions, KYC and multi-jurisdiction sweepstakes
exposure cannot be approved on a summary. The artifact is not in the repo. There
is no version of this review that ends "approved" while the thing being approved
is unreadable by anyone but its author.

**Ground 2 — substance, on the thesis as described.** Three founding decisions
are reversed without the reversal being on the record, and the binding economy
assertion is overdue for the re-derivation this project's own written rule
requires before any income-adding work:

- STRATEGY §5:72 lists, under **"What we deliberately do not build"**: *"Real-time
  MMO backend; alliance/social systems; **timer or energy monetization**"*. The
  described horizon proposes a server, a shared social layer, and a daily loop.
- STRATEGY §2:25 sets Scope as *"Single-player, offline-capable"*, rationale
  *"MMO/live-ops scope is a 50-person operation. **Ours is not.**"*
- STRATEGY §5:106-110 sets the precedent for exactly this situation, on base
  building: *"`PACING_LOOP` sits at ~97% of its ceiling with `MIDTIER` at 2.90
  against a hard 3.00 … **A base-building horizon starts by re-deriving the
  pacing band, not by authoring a build tree.**"* Horizon 5 authors a build tree.

None of that makes the horizon wrong. §5's base-building exclusion was lifted on
2026-08-04 by explicit owner decision, and the way it was lifted is the model:
the reversal was stated, the reasoning was recorded as given, and the boundary
that survived the reversal was written down in the same edit (§5:78-116). **The
objection is not that Horizon 5 breaks §5. It is that, on the evidence available,
it does so without saying that it does.** A plan whose one-line self-description
is "a shared-stakes game without an MMO" is arguing with §5's letter. §5's letter
is not what is load-bearing; §2:25's rationale is, and that sentence is about
headcount.

### What would change the verdict

To **proceed-with-changes**, all four:

1. **Commit the document.** `docs/HORIZON-5-THE-CLAIM.md`, in the repo, in a
   commit that also adds Horizon 5 to §64's Outstanding list. Then this review
   can be done.
2. **Put the §5/§2 reversal on the record** in `STRATEGY.md`, in the shape §5's
   base-building amendment already models: what is lifted, the owner's reason as
   given, and — the part that matters — **the boundary that survives**. My
   proposed boundary is in §6 below.
3. **Pay the §41 debt first.** Re-derive the `MIDTIER` bar before authoring any
   faucet. This is already owed (§64:6029-6033, *"now due"*, outstanding since
   §65) and is a hard prerequisite of a horizon that mints currency. It is also
   the cheapest of the five assumption-tests in §4.
4. **Cut to the minimum thesis test** (§6). Five stages is not a plan, it is a
   ratchet; see **F-2**.
5. **Write the seventh pillar down** (**A-2**). One paragraph in §3 naming
   isolation as a pillar rather than an emergent property. This costs an hour and
   it is the only thing that makes the central design question arguable instead
   of merely felt — and it should happen whatever the verdict, because right now
   the game's load-bearing emotional property is the only one with no entry in
   *"the contract for saying no"* (§7:216-217).

To **proceed** outright: additionally, counsel sign-off on the derby structure
*before* Stage 0, not before Stage 3. See **E-1**.

---

## 1a. Findings index

| # | dim | severity | finding |
|---|---|---|---|
| **F-1** | F | blocker | The document under review is not in the repository |
| **B-1** | B | blocker | ~232 cr/loop of headroom; bar flaky at its failing value; re-derivation overdue |
| **D-1** | D | blocker | Plaintext save, no integrity checking — any client-held currency is forged |
| **A-1** | A/D | blocker | No wall clock anywhere; §5 excludes clocks; device-clock dailies are exploitable |
| **C-1** | C | blocker | The dossier cannot be repurposed — it is a veil over a client-known secret |
| **C-2** | C/D | blocker | `game_state.gd:268` claims the save can't leak the answer. It can, in four lines |
| **F-2** | F | major | §64 is self-contradictory today; five gated stages with no rollbacks |
| **C-3** | C | major | "Deep space persists nothing" false since §66 (`beacons`, `colonies`) |
| **D-2** | D | major | NEW SURVEY is a free, unlimited re-roll; multi-resetting beats multi-accounting |
| **C-4** | C | major | Deep space is already identical for every player — the foundation, and the problem |
| **C-5** | C | major | No location identity layer; the only UGC sanitizer is trim-and-truncate |
| **F-3** | F/C | major | Nothing is browser-first; `export_presets.cfg` does not exist |
| **F-4** | F | major | README baseline one horizon stale; STRATEGY says 634, README says 616 |
| **A-2** | A | major | Solitude is never *stated* — the property most at risk has no written defence |
| **A-3** | A | major | Spec derbies and the progression ladder are in structural competition |
| **C-6** | C | major | Contract tests hit this harness's documented blind spot: seams the author wrote |
| **E-1** | E | major | Counsel gate is at Stage 5; minors/age assurance absent from the codebase |
| **D-3** | D | major | Plausibility checking fails: the autopilot generates the bot's trajectory |
| **C-7** | C | minor | "The Claim" collides with shipped `claim_colony` / `commission_claimed` |
| **A-4** | A | minor | "A new survey is a new frontier" is already only a quarter true |
| **V-1…V-7** | — | verified | Claims that held — see the table at the end of §2 |

---

## 2. Findings, ranked by severity

Severity is blocker / major / minor. Each finding is labelled **fact**
(measured or quoted), **inference** (reasoning from facts), or **opinion**
(judgement). Dimension letters follow the brief: A game design, B economy,
C architecture, D security, E legal, F delivery.

---

### BLOCKERS

---

#### F-1 — The document under review is not in the repository. `[fact]`

**Dimension:** F (delivery) · **Severity:** blocker

**Evidence:** the seven searches in §0. `docs/` contains three files;
`HORIZON-3-COMMISSION.md` and `HORIZON-4-FACTIONS.md` are the only horizon
documents that have ever existed in this repo's history.

**Why it is a blocker and not an inconvenience.** STRATEGY §64 exists solely
because of this failure mode. §64:5976-5982 records that the repo was *"wrong in
both directions at once"* — `HORIZON-3-COMMISSION.md` was marked "not built"
eight months after shipping, while the Hunt's stages 4–6 were specced in a file
outside the repo and were silently skipped for a whole horizon. §64:6042 names
the cause: *"outside the repo, which is most of why these went unnoticed."*
§64:5984 calls the inventory *"the only forward-looking list in the repo, and it
is load-bearing."*

Horizon 5 is currently in exactly the state the Hunt's back half was in when it
got lost — specced somewhere else, invisible to the inventory, and about to be
reasoned about from memory. The difference is that losing track of the Hunt's
stage 5 cost some beacons. Losing track of a stage of this horizon costs a public
promise to paying customers.

**Recommendation.** `git add docs/HORIZON-5-THE-CLAIM.md` in a commit that also
adds a Horizon 5 row to §64's **Outstanding** section. Then re-open this
engagement. The reviewers' time is cheap; the ordering is not.

---

#### B-1 — The economy has ~232 credits of headroom per loop by the project's own measurement, the bar is flaky at exactly its failing value, and its re-derivation is already overdue. `[fact + inference]`

**Dimension:** B (economy) · **Severity:** blocker

This is the finding I would keep if I could keep only one.

**The measurements, all from the repo:**

| quantity | value | source |
|---|---|---|
| `PACING_MAX_MODULES` (hard bar) | `3.00` | `scripts/main.gd:168` |
| `PACING_MIDTIER` reference module | `lance_1` | `scripts/main.gd:169` |
| `lance_1` price | `5,800` cr | `scripts/data/module_db.gd:152` |
| `PACING_MINUTES` (the loop) | `8.0` | `scripts/main.gd:154` |
| current `MIDTIER` reading | 2.91 ± 0.05 | STRATEGY §51:4484 |

So an eight-minute loop earns ≈ 2.91 × 5,800 ≈ **16,878 credits**, against a hard
ceiling of 3.00 × 5,800 = **17,400** — about **520 credits** of headroom at the
mean.

**But the mean is the wrong number, and this project already wrote down the right
one.** STRATEGY §51:4484-4486, under the heading *"Write the spread down, because
the ceiling is close"*:

> `MIDTIER` is 2.91 ± 0.05 against a hard 3.00, so a good roll reads 2.95 and
> **real headroom is about 0.04. Anyone adding income needs four samples, not
> one.**

0.04 modules × 5,800 = **232 credits per eight-minute loop.** That is 29 credits
a minute, and it is the project's own figure, published under an instruction
addressed to exactly the person proposing this horizon. **The cheapest priced
module in the catalog is more than two hours of that headroom.**

The code already knows this and says so twice, unprompted:

- `scripts/main.gd:2557-2559` — *"`PACING_LOOP` budgets five sentry kills for a
  whole eight-minute loop and `MIDTIER` sits at 2.91 against a hard 3.00, so a
  sentry respawn would bolt an income source onto a loop **already at 97% of its
  ceiling**."* A *respawning sentry* was rejected as too expensive against this
  budget.
- `scripts/main.gd:2844` — *"and `PACING_LOOP` is at 97% of its ceiling."*

**Now the two things that make it a blocker rather than a tuning note.**

**(a) The bar is not currently trustworthy.** README:213-218 records that
`MIDTIER` *"can read 3.00 — a FAIL — on an unchanged catalog under machine
load"*, measured on a control run of an unmodified commit (§65). Quiet-machine
range 2.84–2.95; under load 2.86–3.00. `main.gd:11239-11245` records the same
event from the other side: the reading was diagnosed as a rift-clock leak, the
rift clock was pinned, the readings did not move, and *"a control run on the
unmodified parent commit read 2.88-3.00 INCLUDING A 3.00 FAIL, exonerating both
the rift and the stage."* **The binding economy assertion in this project cannot
currently distinguish "you broke the economy" from "the machine was busy."**

**(b) The fix is already owed, and its owner already wrote down that it blocks
this exact class of work.** §64:6029-6033: *"One piece of debt is now due… §41's
re-derivation of the `MIDTIER` bar has been outstanding since §65, and stage 4 is
the first frontier work that would add INCOME… **Stages 1-3 could be measured
against a bar nobody had re-derived because none of them could move it; stage 4
cannot.**"* And §5:109-110, on base building: *"A base-building horizon starts by
re-deriving the pacing band, not by authoring a build tree."*

**Anticipating the plan's defence.** README:219 records that `MIDTIER` is
income-only — *"so a sink cannot touch it"* — and the brief describes the premium
currency as **closed-loop**. If the loop is genuinely closed (premium buys only
private regions and cosmetics; capsules pay only premium; nothing converts to
credits in either direction) then `MIDTIER` is untouched and this finding
downgrades to major. **That is a very large "if", and it is the single highest-
value thing for the plan to state explicitly and for an assertion to enforce.**
Note that a *closed* loop is also a loop with no faucet pressure and no sink
pressure on the real economy — which is to say, a second currency that the actual
game does not feel. Whether players will chase a currency that cannot buy a Lance
is a design question the plan should answer; see **A-2**.

**Recommendation.**
1. Do the §41 re-derivation **first**, as its own PR, before any Horizon 5 code.
   Re-derive the bar from the distribution the way `PHASE INTEGRITY` was
   re-derived in §41 (README:453-479) — a bar the distribution supports, not a
   nudged threshold. Until `MIDTIER` can go red for a reason, no economy change
   in this horizon is measurable.
2. Add an assertion that names the closed loop as an invariant: **no path
   converts premium currency to `salvage` or vice versa.** In this repo's idiom
   that is a rule-not-rendering assertion and it is cheap. Without it, "closed
   loop" is prose, and this project's record on prose-only guarantees is in §54.
3. State the per-loop credit cost of every Horizon 5 faucet in the plan, in
   credits, against the **232-credit** budget — and take four samples, not one,
   per §51:4486.

---

#### D-1 — The save is plaintext JSON with no integrity checking, so any currency it holds is forged in under a minute. `[fact]`

**Dimension:** D (security) · **Severity:** blocker

**Evidence.** `scripts/game_state.gd:35` — `const SAVE_PATH := "user://save.json"`.
Written with `JSON`/`FileAccess` at `:2489`, read at `:2500`. The balance is
loaded at `:2519`:

```gdscript
salvage = int(data.get("salvage", 0))
```

No signature, no HMAC, no checksum, no obfuscation, no server echo. The
validation that *does* exist — and there is a lot of it, `:2513`–`:2560` and the
ten-filter `_load_apex_intel` at `:1323-1379` — is **referential**: does this
module id exist, is this system real, is this float finite. It is excellent, and
it is aimed at corruption and hand-edits that would *crash* the game
(`game_state.gd:363-365` is explicit: a hand-edited 99 would *"reach STAGES[99]
and crash AT A DOCK"*). It is not aimed at fraud, because until now there was no
fraud to aim at. In a single-player game, editing your own save is not cheating;
it is playing with your own toy.

On web this is worse, not better: the save lives in IndexedDB, editable from the
devtools console of the page the game is served from.

**Consequence for the horizon.** Anything of real-money value — the premium
currency, capsule credit, derby eligibility, subscription entitlement — must be
**server-held and server-authoritative**, with the client save holding at most a
cached display copy that the server overwrites. That is not a small addition: it
means the server needs an account model, a wallet, an idempotent transaction log
and a reconciliation story, which is a materially larger thing than the "thin
claims server" the brief describes.

**The project already owns the right technique, and the plan should name it.**
§66:6264-6266, on beacon stock:

> The stock is **derived** — `BEACON_STOCK` minus every entry across every system
> — never stored, so **a hand-edited save cannot carry "stock: 9" beside eight
> standing beacons.**

That is exactly the discipline a currency needs, applied to a quantity nobody was
attacking. The loaders show the same posture: §66:6318-6324 treats the file *"as
**input rather than truth**"*, dropping malformed entries in file order so which
survive is deterministic; §67:6398-6403 feeds seven broken colony shapes and
asserts exactly the one valid entry survives. **This codebase is already
adversarial toward its own save file.** What it does not have — and cannot have
locally — is a way to make a *balance* unforgeable, because a balance has no
derivation. That is the whole argument for server authority, and it is one
sentence long.

**Recommendation.** State explicitly in the plan which values are server-held and
which are client-held, as a table, and make the rule mechanical: *anything that
can be exchanged for money, or for a thing bought with money, is server-held.*
Then the client save schema question (**C-3**) mostly answers itself: the client
stores nothing of value, so it needs no new integrity machinery — and it keeps
the §66 rule for everything else, which is that a quantity you can derive, you
never store.

---

#### A-1 — The game has no wall clock anywhere, and §5 excludes clocks by name. A daily loop is both new machinery and a boundary violation. `[fact + inference]`

**Dimension:** A (design) / D (security) · **Severity:** blocker

**The fact, first, because it is stronger than I expected.**
`grep -rn "get_unix_time\|get_date_dict\|get_time_dict\|OS.get_system_time" scripts/`
returns **zero matches**. Every time reference in the codebase is
`Time.get_ticks_msec()` — monotonic milliseconds since process start — used for
animation phase and input hold detection (`camera_rig.gd:204`, `hostile.gd:379`,
`derelict.gd:210`, and ~7 others). `GameState.played_seconds` accumulates in-game
time and is saved, but it is a duration, not a date.

**Pyxis has never asked what day it is.** That is not an oversight; it is the
shape of the design.

**The boundary.** STRATEGY §5:72 excludes *"timer or energy monetization"* by
name. The base-building amendment, which is the most recent statement of what
this project will and will not do (§5:89-94), draws the line explicitly:

> A place in the world the player owns and changes, in a single-player game with
> **no clocks, no queues**, no currency sink pretending to be a decision, and
> **nothing that rewards logging in rather than flying**. If a structure takes
> time to become something, the time is *spent flying to it with what it needs* —
> the trip is the cost… **Nothing may be built by waiting.**

A **daily** rumor economy is a clock, and its entire retention mechanism is
rewarding logging in rather than flying. It is the specific thing this paragraph
was written to forbid, written three days ago, in the amendment that was
*granting* a scope expansion.

**And the security half.** Device-clock dailies are the oldest exploit in the
free-to-play catalogue: set the clock forward, collect tomorrow's rumor, repeat.
The only fix is server time, which means the daily loop cannot degrade offline —
so the offline-first story (**C-1**) breaks precisely at the feature that carries
the daily retention.

**Recommendation.** If the daily loop survives, three things must be true and
stated: (1) the reset is **server** time, never device time; (2) §5 is amended
in the same commit to record that the no-clocks boundary has been narrowed and
to what; (3) the plan states what a player who is offline for a week sees — and
"you lost six rumors" is a punishment for not logging in, which is the thing §5
forbids by a different route.

**Opinion, offered because the brief asked for a position:** the daily rumor is
the weakest load-bearing element in the described design. The game's own answer
to "what brings you back" is already written and already shipped — you come back
because there is somewhere you have not flown. Bolting on a login reward does not
strengthen that; it competes with it, and it converts a game that is safe to
leave alone into one that punishes you for it. See **F-2** and §6.

---

#### C-1 — "The Hunt intel dossier machinery can be repurposed for capsule rumors" is false, and false in the load-bearing direction. `[fact]`

**Dimension:** C (architecture) · **Severity:** blocker

The dossier is **a client-side progressive-disclosure UI over a number the client
already holds.** It is not an information channel. Repurposing it for
server-authoritative secrets inverts it.

**The proof is four lines.** `scripts/data/system_db.gd:706-728`:

```gdscript
static func lair_pos(id: String, run_seed: int) -> Vector3:
	...
	rng.seed = hash("%s|lair|%d" % [id, run_seed])
	var bearing := rng.randf_range(0.0, TAU)
	var depth := rng.randf_range(float(band[0]), float(band[1]))
	return Vector3(cos(bearing) * radius, 0.0, sin(bearing) * radius)
```

A pure function of `(system_id, run_seed)` over static authored data. And
`run_seed` is client-owned end to end: rolled locally from the system clock at
`game_state.gd:791-793`, **written into the save** at `game_state.gd:2458`
(`"run_seed": run_seed,`), read back at `:2607`.

`Hunt.bearing_hint` (`scripts/hunt.gd:242-269`) computes the true bearing and
adds a *deterministic* error seeded on `(system, kind, run_seed, rounded observer
position)` — deliberately, so a player cannot save-scum a tighter cone
(`hunt.gd:248-253`). Every guarantee the dossier makes is a guarantee about *how
much of the truth to show a client that has all of it*.

**Under server authority every one of those guarantees becomes either trivial or
unenforceable.** There is nothing to re-roll (the server sends a cone), and the
client cannot verify that a cone contains a truth it does not know.

**What is actually reusable:** `Hunt._scan` and `Hunt._satisfies`
(`hunt.gd:75-170`, `:226-239`) — about 110 lines of opaque-hint polar
point-location, no globals, no `SystemDB` — plus the chart cone renderer
(`chart_panel.gd:252-293`) and the widest-first eviction *policy*
(`game_state.gd:1983-2002`). Call it 110 of ~800 lines.

**What must be rewritten**, each with a reason that is structural rather than
cosmetic:

| piece | why it cannot carry over |
|---|---|
| `bearing_hint` / `ring_hint` (`hunt.gd:242-282`) | take `run_seed`, derive truth internally |
| `Hunt.estimate` (`hunt.gd:173-223`) | its search domain **is** the lair's authored annulus (`hunt.gd:184-197`, *"The hints choose WHERE in the annulus; they never get to choose the annulus"*). A server-placed capsule has no annulus, so the polar grid has no domain |
| storage (`game_state.gd:276`) | `{system → [hints]}`. N targets needs `{system → {target → [hints]}}` — rewrites six accessors and forces a save migration |
| expiry | **does not exist.** No timestamp on a hint, no sweep, no clock (see **A-1**). A dossier entry ends exactly one way: the boss dies (`game_state.gd:1029`, `:1048`, `:1960`) |
| load validation (`game_state.gd:1329-1332`) | deliberately refuses to cross-check hints against ground truth — *"Contradiction is a legal state of a dossier."* Server authority needs the exact inverse |
| `file_apex_intel` (`main.gd:3680-3721`) | takes no target parameter; hard-coded to the current system's engine (`main.gd:3687-3690`) |
| all consumers | one ghost (`hud.gd:224`, literal `"id": 1`), one plot circle (`chart_panel.gd:186`), one desk row (`port_panel.gd:1295-1358`), single-entry estimate cache (`main.gd:3667-3676`) |
| ~19 `HUNTTEST` assertions (`main.gd:18855`–`19372`) | all anchored on `main.gd:18845`'s client-computed `truth` |

**One factual correction to the existing record, found on the way.**
`main.gd:3681-3685` says *"Six things can teach you where the engine hides."*
There are **eight** distinct `kind` strings reaching `file_apex_intel`: `hull`
(`derelict.gd:393`), `mast` (`survey_mast.gd:263`), `rift` (`rift.gd:155`),
`convoy` (`deep_space.gd:1994`), `guard` (`deep_space.gd:2055`), `relic`
(`game_state.gd:2120`), `watch` and `rumor` (`port_panel.gd:1373`,
`main.gd:626`). The comment is stale by two, and §64:6092 and §67 repeat the
six. Worth a one-line fix independent of this horizon.

**Recommendation.** Delete the reuse claim from the plan and re-cost the rumor
system as new work: a multi-target, server-issued, time-expiring hint store with
its own save migration and its own harness tag. My estimate, calibrated against
§42 (the dossier itself: 14 assertions, one save bump, one stage): **larger than
the original dossier**, because it adds authority and expiry, which the original
did not have.

---

#### C-2 — `game_state.gd:268-270` claims the save cannot leak the answer. It can, in four lines. `[fact]`

**Dimension:** C (architecture) / D (security) · **Severity:** blocker
*(as a live defect in shipped reasoning; the horizon then inherits it)*

This is a finding about the existing codebase, surfaced by asking a Horizon 5
question of it. `scripts/game_state.gd:268-270`:

> NOTHING here is ground truth. `SystemDB.lair_pos` is, and it is never written
> down: every hint is derived from it at the moment it is earned and then stands
> on its own, **so a save file cannot leak the answer** and a contradictory
> dossier stays contradictory.

The first clause is true: `apex_intel` holds no coordinates. The conclusion does
not follow. `scripts/game_state.gd:2458` writes `"run_seed": run_seed` into the
same file, and `system_db.gd:706-728` turns `(system_id, run_seed)` into the lair
position with no hidden state. **The save leaks the answer transitively, and the
comment's own next sentence names the function that does it.**

This is precisely the shape README:266-267 warns about — a guarantee whose setup
is elaborate enough that nobody checked the last step — and it is not covered by
an assertion, because the 19 dossier assertions all *start* from
`SystemDB.lair_pos(isys, GameState.run_seed)` as their ground truth
(`main.gd:18845`). They verify the veil; nothing verifies the claim that the veil
is the only path.

**Why it blocks Horizon 5 rather than merely embarrassing §42.** The plan's
premise — that a treasure location can be hidden from a client that has the game
— is falsified by the strongest existing attempt to do so in this codebase. The
horizon must be designed on the assumption that **the client knows everything the
client can compute**, and therefore that capsule positions are either (a) server-
held and revealed only on approach, at the cost of a round trip in the hot path,
or (b) computable, and therefore not a secret at all.

**Recommendation.** Two separate actions. (1) Independently of this horizon, fix
the comment — it is a false statement in a load-bearing explanation, which this
project treats as a defect (§54, §72). (2) In the plan, replace any "the client
cannot know X" reasoning with an explicit threat model that assumes it can.

---

### MAJOR

---

#### F-2 — Five gated stages, proposed for a project whose only forward-looking list drifted within two days of its last edit. `[fact + opinion]`

**Dimension:** F (delivery) · **Severity:** major

**The fact.** §64 is currently self-contradictory, today, about work that shipped
two days ago:

- §64:6010 (prose): *"**Nothing outstanding from the frontier.** Stages 1–4
  shipped as §68–§70 plus stage 4's own commit."*
- §64:6023 (the table, four lines below): stage 4 → status **"not built"**.
- README:29: *"§64 is the inventory: today it holds the frontier's stage 4
  (optional polish)"* — i.e. the README reads the table, not the prose.
- `git log`: `5bbf69c "Deep weather (frontier stage 4) — grave-fields, a longer
  reach, six landmark kinds"`, merged in PR #37 on 2026-08-05.

Stage 4 is built. The inventory says both. The README believes the wrong half.
§64:5985-5986 states the discipline it depends on — *"if you build or defer
something, update it in the same commit"* — and §64:6105-6117 explains, well,
why this is a discipline rather than an assertion. The discipline held for
roughly 48 hours.

**Why this matters more for Horizon 5 than for the frontier.** A stale row in a
single-player inventory costs a confused reader. The described horizon has five
stages, a compliance ledger, live prize events with published dates, and a
subscription with a renewal cycle. Every one of those is a promise with an
external party on the other side of it. The mechanism this project uses to track
promises is a hand-maintained markdown table that is wrong right now.

**On the gates specifically — opinion, clearly labelled.** I cannot assess the
plan's gates (**F-1**), but I can assess the *structure*. A five-stage gated plan
where each gate's failure mode is "do not proceed to the next stage" is a ratchet
unless each gate has a **kill** criterion — a number that, if missed, means the
already-built stage is *withdrawn*, not merely un-extended. Stage 1 opens a
faucet with no store (per the brief); if Stage 2's sink never ships, Stage 1's
faucet does not un-ship. That is the ratchet. The gate that matters is not
"should we build Stage 2" but "should Stage 1 still exist."

**Recommendation.** For each stage, the plan must state a **rollback**, not just
a gate: what is torn out, what players are told, and what the save does with
orphaned state. If a stage cannot be rolled back — and anything that has taken
money cannot be — say so, and treat that stage as the true point of no return.
Then move every reversible decision before it.

---

#### C-3 — "Deep space persists nothing" has been false since §66. Any "no save bump needed" claim inherits the error. `[fact]`

**Dimension:** C (architecture) · **Severity:** major

**The claim's source.** §64:6033-6035: *"**No save bump is expected anywhere in
this horizon**: deep space persists nothing, and module and commodity ids flow
through the existing generic `owned`/`fit`/cargo paths."* README:120-122 repeats
it. In the frontier's context the claim is true and load-bearing — deep-space
*generated content* (rocks, hulks, seams, stations, landmarks) is regenerated per
cell and never written down.

**But as stated it is false, and has been since Hunt stage 5.**
`scripts/game_state.gd:2478-2480` writes three deep-space keys:

```gdscript
"beacons": beacons,
"colonies": colonies,
"last_colony_jump": last_colony_jump,
```

`beacons` are dropped *at depth* (`game_state.gd:1182`, `drop_beacon(system_id,
x, z, depth)`) and were the reason for save **v20** (§66). `colonies` are claimed
*past 1600u* (§67) and are persisted deliberately as *"a dict per instance rather
than a set of keys"* so a later horizon can add fields without a migration
(§5:112-116).

So the correct statement is: **deep-space *generated content* persists nothing;
deep-space *player state* has persisted since v20, and adding it cost a save
version.** The distinction is exactly the one Horizon 5 lands on. A first-charted
claim is deep-space player state. A held capsule is deep-space player state. Both
are on the `beacons`/`colonies` side of the line, not the terrain side.

**On what a bump actually costs — and this cuts in the plan's favour, so it is
worth stating precisely.** Mechanically it is nearly free: §36:2557-2563 records
that `load_game()` *"has been field-defaulting since v1 and there is still **no
`migrate_*()` function anywhere**"*, so the work is a version constant, a
save/load pair, a `SAVETEST=migrateN` fixture leg, and adding the mode to
`SAVE_MODES` in `tools/run_harness.sh`. Three stages in a row needed no bump at
all (§70:6807).

**The recorded expense is narrow and specific: a bump is expensive exactly when a
default could *take something away*.** §38:2752-2763 — *"a plain `lanes_open =
[]` default would wake them up locked out… the pilot standing in PYX-01 wondering
how they got there."* §44:3690-3707 — choosing which way to be wrong, where
over-counting *"would delete a wreck worth up to 32,000 credits that they can
still see on the radar."*

**A claim is precisely that kind of value.** A default that silently drops a
first-charted name is the `lanes_open` failure with a stranger's feelings
attached, and it is unrecoverable in a way a wreck is not, because the name may
have been re-filed by someone else in the meantime.

**Recommendation.** Correct §64:6034 to name the generated-content /
player-state distinction. In the plan, replace any blanket "no bump" claim with a
per-store table, expect at least one bump, and — the part that matters — state
the grandfather rule for claims explicitly, in the §44 idiom: **which way do we
choose to be wrong**, and why.

---

#### D-2 — Reset is free, unlimited, and rolls a new world. Multi-accounting is not the interesting attack; multi-*resetting* is. `[fact + inference]`

**Dimension:** D (security) · **Severity:** major

**Evidence.** `GameState.reset_to_starter()` (`game_state.gd:~780-840`):

```gdscript
# A NEW SURVEY is a new frontier. This is the one place the run's salt is
# rolled, and it is rolled from the system clock rather than the seeded
# global stream — every other roll in this game is deterministic by design,
# and this is the single number that must not be.
var seed_rng := RandomNumberGenerator.new()
seed_rng.randomize()
run_seed = seed_rng.randi()
```

and it clears `apex_intel`, `beacons`, `colonies`, `faction_deltas`, `salvage`,
`owned`, `breached`, the ledger and the log. It survives: `commissioned`,
`livery`, `ship_name`, `audio_muted` (`game_state.gd:822`, `:829-833`).

**The attack the brief's framing misses.** The brief red-teams "50 accounts."
Fifty accounts costs fifty email addresses and fifty KYC evasions. **NEW SURVEY
costs one tap and there is no limit on it.** Whatever the client reports about
its world — its seed, its position, its charting progress, its capsule finds —
can be re-rolled arbitrarily many times per minute from a single install, with no
account creation, no device fingerprint change, and nothing for KYC-at-payout to
attach to.

**And the deeper structural point (see C-4).** Deep-space content is *not*
seeded on `run_seed` at all — so a reset does not even change the map. It changes
only the lair and the hyper-structures. A capsule placed at a fixed
`(system, cell)` is in the same place before and after a reset, which means reset
is a free re-roll of *state* against an *unchanged* world.

**Recommendation.** The server must key entitlement on something a reset cannot
change, and the save cannot be that thing. Also: state in the plan what NEW
SURVEY *means* once claims exist — do a player's first-charted names survive their
own reset? Both answers have costs, and it is a question the plan must answer
before Stage 1, because it is visible to players on day one.

---

#### C-4 — Deep space is already identical for every player. This is the horizon's strongest existing foundation and it also removes the secrets the design needs. `[fact]`

**Dimension:** C (architecture) · **Severity:** major (as an unexploited fact and an unaddressed constraint)

**The measurement.** Every deep-space generator is salted on
`(system_id, cell_x, cell_z)` and **not** on `run_seed`. The ten salted streams
in `scripts/deep_space.gd`:

```
:852  hash("%s|%d|%d"                :1214 hash("%s|%d|%d|seam"
:942  hash("%s|%d|%d|guard"          :1299 hash("%s|%d|%d|landmark"
:1030 hash("%s|%d|%d|convoy"         :1311 hash("%s|%d|%d|landmark_at"
:1078 hash("%s|%d|%d|hulk2"          :1326 hash("%s|%d|%d|landmark_kind"
:1721 hash("%s|%d|%d|pack"           :1798 hash("%s|%d|%d|convoyspring"
```

`grep -c run_seed scripts/deep_space.gd` → **2**, and both are the lair
(`:492`, `:644`). Only `SystemDB.lair_pos` and `SystemDB.hyper_positions`
(`system_db.gd:706`, `:773`) take `run_seed`.

**The good news, and the plan should be built on it.** Every player's PYX-01 at
cell (37, −12) has the same wreck, the same seam, the same landmark, the same
guard post, forever. **The shared world Horizon 5 needs already exists and is
free.** A claims server can address locations as `(system_id, cx, cz)` — a
16-byte key — and every client will independently agree on what is there. No
position sync, no world-state replication, no seed negotiation. This is a
genuinely strong position that a plan framing the world as "generated from a
seed" (per the brief) may not realise it is in.

**The bad news, and it is the same fact.** Because content is a pure function of
public inputs, **there is nothing hidden in deep space.** A player with the source
— which every browser player has — can enumerate every landmark in every band in
milliseconds, without flying. So a server-placed capsule is the only object in
the world that is *not* derivable, which makes it trivially distinguishable from
scenery by a bot that simply asks "what is here that the generator does not
predict?" The anti-cheat problem is not "detect an implausible flight path"; it
is that **the capsule is a needle that announces itself as not-hay.**

**Recommendation.** Build the claims layer on `(system_id, cx, cz)` — cheap,
correct, and already true. And drop any design element that depends on capsule
*locations* being secret; secrecy is not available. If capsules must be
findable-but-not-enumerable, the secret has to be *when* they exist, not *where*,
and that is a different mechanic.

---

#### C-5 — There is no location identity layer. "First-charted" has nothing to attach to. `[fact]`

**Dimension:** C (architecture) · **Severity:** major

"Charted" in this codebase means exactly one thing: `is_system_charted(id)`
(`game_state.gd:849`), backed by the `breached` array — a **per-system boolean**,
across **three** systems. That is the entire granularity of charting.

Deep-space landmarks — the obvious candidate for "a place somebody was first to
file" — have no identity. `DeepSpace.landmark_at` (`deep_space.gd:1304-1334`)
returns:

```gdscript
return {"kind": kind, "pos": at, "rot_y": rng.randf_range(0.0, 360.0), "band": band}
```

No id, no name, no persistence. Nothing anywhere in `scripts/` assigns a stable
handle to a place in deep space. Their *positions* are stable (**C-4**), so
`(system_id, cx, cz)` can serve as a synthetic key — but that key does not exist
today, nothing renders it, and nothing in the save references it.

**The second half of this is UGC.** The only user-supplied string in the game is
`ship_name`, and its sanitizer is `game_state.gd:2134-2138` in full:

```gdscript
func _sanitize_ship_name(raw: String) -> String:
	var clean := raw.strip_edges()
	if clean.length() > SHIP_NAME_MAX:
		clean = clean.substr(0, SHIP_NAME_MAX)
	return clean if clean != "" else DEFAULT_SHIP_NAME
```

Trim and truncate. No profanity filter, no Unicode normalisation, no homoglyph
folding, no rate limit — correctly, because today that string is displayed to
exactly one person: the person who typed it.

**"First-charted names on every player's chart" converts that function into a
content-moderation surface with zero protection**, in a game that (per the brief)
plans to be browser-first, which means minors, which means the moderation
question is not optional. This is also the cheapest possible way for the project
to end up in a headline.

**Recommendation.** The plan must specify: the identity scheme (I recommend
`(system_id, cx, cz)`), what granularity a "claim" has, and the **moderation
model** — pre-moderation, post-moderation with reports, or a curated name
vocabulary. My recommendation is the third: let players compose a name from an
authored word list. It removes the entire moderation surface, it fits the
cartographic fiction better than free text, and it costs a data table instead of
an ops function.

---

#### F-3 — The platform premise is wrong: nothing in this repo is browser-first, and no export target is configured at all. `[fact]`

**Dimension:** F (delivery) / C · **Severity:** major

The brief describes Pyxis as *"browser-first with mobile planned."* The repo says
the opposite, in every place it says anything:

- STRATEGY §1:10 — *"An original **single-player mobile-portrait** space game"*
- STRATEGY §2:24 — Platform: *"Mobile portrait (720×1280 base)"*, rationale
  *"Where the reference's audience lives."*
- README:3-5 — *"A single-player **mobile** game… built in Godot 4.6 for portrait
  phones"*
- `project.godot:107` — `renderer/rendering_method="mobile"`
- `project.godot:25` — `window/handheld/orientation=1`

And decisively: **`export_presets.cfg` does not exist.** There is no web export
preset, no Android preset, no iOS preset. The project has never been exported to
anything. Nothing has been run outside the editor and headless CI.

**Why this is major rather than pedantic.** Every dimension-D argument in the
brief rests on "the client is a browser game" — full client source, headless
automation, devtools. That is a correct threat model *for a web build*, but the
web build does not exist, and standing it up is unestimated work with real
unknowns for this specific project: Godot 4 web export requires
cross-origin-isolation headers, the audio system is generated WAVs loaded through
an import cache (README:99-104) whose behaviour under web export is untested, and
`PYXIS_BALANCE` runtimes of 5–20 minutes (README:481-486) say nothing about
browser frame budgets. `STREAMTEST`'s `worst` clause already fails at 40ms on
desktop (README:224-231).

**Recommendation.** Before Stage 0, spend a day producing a web export and
running one session in a browser on a mid-range phone. If Horizon 5 is
browser-first, that build *is* Stage 0's real prerequisite, and it is the single
cheapest way to discover that the horizon's platform assumption is unfounded.

---

#### F-4 — The README's baseline is exactly one horizon stale, and the two canonical documents now disagree by 18 assertions. `[fact]`

**Dimension:** F · **Severity:** major *(as a culture finding; minor as arithmetic)*

Counted from `tools/run_harness.sh`: `TAGS` has **46** entries; `SAVE_MODES` has
**17**. **Total runs = 63.**

The recorded numbers, and they are three different answers:

| source | assertions | runs |
|---|---|---|
| README:47-49 | — | *"44 suites make **61 runs**"* (tag count also wrong: 46) |
| README:119 | **616** | **62** |
| STRATEGY §72:7206 | **634** | — |
| measured, this review | (could not run) | **63** |

**The story is clean once you line it up against the sweep totals STRATEGY
records per section** (§68:6634 → 61 runs/588; §69:6726 → 61/592; §70:6807 →
61/598; §71:6975 → 62 runs/612, *"the instruments add four more clauses"* = 616).

**README:119's "616 PASS across 62 runs" was correct as of §71 and is stale by
exactly one horizon.** §72 then shipped `PYXIS_CONTACTTEST` — 19 assertions, one
new tag, one new run — which is 634 and 63. §72:7206 states the 634 in its own
heading. Nobody updated the README.

The brief cites *"~616 headless assertions across 62 runs"* as a fact about the
project, so it inherits the stale figure — the exact behaviour README:163 warns
against: *"**A baseline is a measurement with an age on it.**"*

**A second gap, found the same way and worth more than the arithmetic.** §63
records 550 PASS; §68 records 588. The **+38 assertions and +4 runs across §65,
§66 and §67** — three shipped stages, one of them a save bump to v20 — have **no
recorded sweep line anywhere.** Every other stage in the file has one. Three
stages shipped without the measurement that every other stage published, and
because the next section's total absorbed them, nothing looked missing.

I could not run the sweep (no Godot binary here), so I cannot confirm 634. I can
confirm that 62 is not the run count, that 616 and 634 both appear as current in
documents dated the same week, and that three stages went unmeasured in public.

**Why it belongs above "minor."** This project's central claim about itself is
measurement discipline, and the brief leans on that claim to establish that the
plan deserves trust. The load-bearing number in that claim has drifted twice in
the ten days the project has existed. The discipline is real — 616 red-verified
assertions is genuinely unusual — but the *prose about* the discipline is not
under the discipline, which is the same gap as **F-2** and §54.

**Recommendation.** Derive the counts. `tools/run_harness.sh` already computes
PASS/FAIL and run totals; have it print a line the README can be pasted from, and
stop hand-maintaining three numbers in two files.

---

#### A-2 — The "stated emotional core" the brief asks me to protect is not stated anywhere, which is worse than it sounds. `[fact + opinion]`

**Dimension:** A (design) · **Severity:** major

The brief asks whether rivalry fits *"a game whose stated emotional core is
solitude — 'the less anyone is watching'."* The answer turned out to be more
interesting than yes or no, and it cuts against the brief's premise before it
cuts against the horizon.

**Solitude is not a stated core. It is not stated anywhere.** The word
"solitude" appears exactly once in `STRATEGY.md`'s 7,261 lines, at §49:4341, and
it is about how much clearance a ship AI needs: *"it needs elbow room, **not
solitude**."* The six experience pillars (§3:34-47) are living star chart,
reward spectacle, quiet HUD, frictionless command, scale contrast, cohesion —
**none is social, and none is about aloneness either.** The quoted phrase *"the
less anyone is watching"* is from **README:10**, not from the design record.

**What does exist is the mechanic, stated twice, without ever being promoted to a
principle.** STRATEGY §17:623-625:

> Never zero: **there is no range at which a full hold is safe, only ranges at
> which it is unlikely to be noticed. This is the trade the expanse rests on.**

and §18:794-795, written as a spawn-rate justification:

> **raiders thin out with distance because nobody is watching**, and saying so
> out loud is what turns a number into a place.

**This is the finding, and it is worse for the horizon than a stated pillar would
have been.** Isolation is the *economic* structure of this game — it is literally
the term in the payout gradient — and it has no protection, because §7:216-217
names *"the pillar list"* as **"the contract for saying no"** and solitude is not
on the pillar list. So the thing Horizon 5 most endangers is the one load-bearing
property of the design with no written defence, which is precisely how it gets
traded away without anyone noticing they traded it. That is the §54 pattern
applied to a design value instead of an assertion.

**The sharper point, and it cuts both ways.** §7:210-213 pre-registers the risk
Horizon 5 is arguably answering:

> **Auto-combat flatness.** The reference's moment-to-moment play is shallow and
> carried by meta pressure and **social stakes we won't have**. Our answer is
> fitting decisions plus an active ability; if that doesn't land, the design
> needs a bigger swing (**positioning, targeting choices**).

So the project *did* anticipate needing more pressure, and it *did* write down
its remedy — and the remedy is **mechanical**, not social. Horizon 5 substitutes
the social answer for the mechanical one. That may be right. But it is a
substitution the plan should argue explicitly against §7's recorded alternative,
and "we chose the swing the risk register ruled out" is a sentence that needs to
appear somewhere.

**On "first-charted" specifically.** A name on a place *strengthens* the
cartographic fantasy — filing a return is what the game is about, and a chart
nobody else has filed is a better prize when "nobody else" is verifiable. **I
endorse the claims layer on design grounds.** It is the one element of the
described horizon that makes the existing fiction more true rather than less.

**What subtracts** is everything that makes another player a *rival in the
present tense*: a race for a capsule, a leaderboard, a prize arena, a
notification that someone beat you there. That converts "the less anyone is
watching" into "somebody is always watching", which is the inverse of the
sentence the game rests on.

**Recommendation, and the first item is the cheap one that should happen whatever
the verdict.**

1. **Write the pillar down before deciding anything else.** Add a seventh pillar
   to §3, in the language §17:624 already uses, so that "the less anyone is
   watching" becomes part of the contract for saying no instead of an emergent
   property nobody promised. This costs one paragraph and it is the only way the
   rest of this argument can be *had* rather than merely felt. If the owner
   writes it down and *then* decides Horizon 5 is worth it, that is a decision.
   Trading it away without writing it down is not.
2. **Keep first-charted claims.** They make the fiction more true.
3. Treat every synchronous or quasi-synchronous rivalry element (capsule races,
   derbies, notifications) as carrying a design cost that must be argued against
   the new pillar, not assumed. Note the asymmetry: a claim is *permanent and
   asynchronous* — you find a name from six weeks ago, which reads as
   archaeology, and archaeology is this game's genre. A capsule race is
   *transient and contested*, which is a different game.

---

#### A-3 — Spec derbies and the progression game are in direct competition, and the brief's own framing concedes it. `[inference]`

**Dimension:** A · **Severity:** major

The brief asks: "why grind a Mk III if the prize arena ignores it?" That is the
right question and it has a measurable edge in this repo.

The Mk III line is **the entire content of frontier stage 2** (§69): four Mk III
weapons, three Mk III utilities, Breaching Torch, Surge Capacitors, Expedition
Frame, Reactor Mk V — *"ten modules stocked nowhere until stage 3 authors the
counters"* (README:126-129). The top of the catalog costs **90,000 credits**
(`module_db.gd`, max price), which at the measured earn rate of ~16,820 credits
per 8-minute loop is **~43 minutes of optimal play for one module**, and the
catalog has 51 of them.

A spec-loadout arena declares that ~43 minutes × N of progression is irrelevant
to the only competitive surface in the game. That is not automatically fatal —
it is the standard fair-competition answer, and the equal-dignity requirement
(per the brief) may make it legally necessary. But it is a real cost, and it
lands on the newest content in the game.

**The tension is structural, not tunable.** Fair prize competition requires
equalised loadouts. A progression game requires loadouts to matter. Those cannot
both be maximised, and the brief's mitigation ("mirrored layouts") addresses map
fairness, not loadout relevance.

**Recommendation.** State the trade explicitly and pick a side. If prize events
are spec-only, say in the plan that the progression ladder is deliberately
excluded from competition and explain what the ladder is *for* instead (the
answer is available and good: it is for going *further out*, which is the actual
game). If that answer is unsatisfying, the derby is testing the wrong thing —
see §6.

---

#### C-6 — A contract test against a server cannot run in this harness culture without breaking the property that makes the harness trustworthy. `[inference]`

**Dimension:** C · **Severity:** major

**The constraints, measured:**

- There is **no test framework**. Every check is an assertion inside
  `scripts/main.gd`, gated behind a `PYXIS_*` environment variable
  (README:40-42). `main.gd` is **21,888 lines**.
- There is **no networking code of any kind**:
  `grep -rn "HTTPRequest\|HTTPClient\|multiplayer\|WebSocket" scripts/` → **0**.
- The sweep's correctness rests on determinism — `WORLD FINGERPRINT`
  (`main.gd:15522`) — and on the guarantee that no harness touches external state
  (`tools/run_harness.sh` md5s the real save before and after specifically to
  prove this).

A contract test has exactly two shapes and both have a problem here:

1. **In-process fake server.** Deterministic, runs in the sweep, red-verifiable —
   and tests only that the client agrees with a fake the same author wrote. It
   cannot catch the failure this horizon actually has to survive, which is the
   server and client disagreeing about band edges, cell coordinates, or what
   "charted" means. This project has a name for that shape: an assertion that
   *"measured a world where the defect cannot express itself"* (README:259-267).
2. **Live call to a real server.** Catches real drift — and introduces network
   non-determinism into a sweep whose exit status is *"0 only if all three checks
   pass"*, makes the sweep require connectivity, and makes a red run ambiguous
   between "regression" and "the server was down." This project already has three
   load-sensitive flaky assertions (`MIDTIER`, `STREAMTEST worst`,
   `PHASE INTEGRITY`) and README:213-231 shows what they cost.

**And there is a third problem, which is the one I would actually worry about.**
A client/server boundary is *entirely* seam, and this project has just finished
writing down, in its most recent section, that seams are exactly where its
harness does not look. STRATEGY §72:7209-7212, on four defects an adversarial
review found that 634 green assertions did not:

> **Every one of them lives at a seam between the new code and a rule written
> down somewhere else — which is precisely where a harness written by the author
> of the change does not look, because the author is asserting the thing they
> just built.**

The rule §72 draws from it is **"assert the seams you did not write"**
(§72:7254). In Horizon 5 there is no seam the author did not write: one person
writes the client, the server, the contract and the assertions. The method that
found those four defects was *a different reader*, not a better assertion.

The supporting rate is not reassuring either. Sections §62–§71 record **eighteen**
assertions that were green while measuring nothing, four of them in a single
horizon (§71:6960 calls storms' the *"Fourth vacuity this horizon"*), including
`board_clean = board_clean` written into the check whose job was proving an
absence (§67:6394-6397), a clause defeated by a header comment (§71:6907-6909),
and one that was *"asserting that two opposed unit vectors sum to zero"*
(§71:6914-6920). Plus a separate class: three assertions this horizon that
**failed by crashing rather than printing FAIL**, which a sweep reports as
*"fewer passes"* rather than as a failure (§71:6922-6945).

This is not a criticism of the harness — a project that finds and *records*
eighteen of its own vacuities is doing something almost nobody does. It is a
statement about what that harness can be asked to guarantee. **It reliably
catches arithmetic, prices, layout, save round-trips and positions. Its recorded
blind spots are: whether a mechanic fires at all (§54:4767-4776), the path a real
player takes rather than the function it wraps (§54:4723), its own vacuity, and
seams with rules written elsewhere (§72:7209).** A client/server contract is the
fourth category, tested by the author of both sides.

**The one shape that works**, and I recommend it: **a checked-in contract
fixture.** A single JSON file, committed, that is the literal wire format —
band edges, cell size, key format, version. The client harness asserts its own
constants against the fixture; the server's own build asserts *its* constants
against the same file. Neither talks to the other at test time; the file is the
contract, and a divergence is a red diff rather than a red network call. In this
repo's idiom that is `ATTRIBUTION IS EXPLICIT` (README:327-330) — an assertion
that reads a source file as text because *"a call site that is never exercised
cannot be caught any other way."*

**And budget for the adversarial reader.** §70:6750-6753 records the practice
that actually works here: *"Four adversarial readers went at the two archetypes
as a **specification** — no file written… **Two of what they found would have
shipped.**"* Do that to the wire contract before it is implemented, not after.
It is the highest-yield process this project has, and it is the only one that
addresses the author-asserts-their-own-work problem.

**And the specific constant that will break first.**
`scripts/deep_space.gd:33`:

```gdscript
const BAND_EDGES := [0.0, 160.0, 440.0, 1100.0, 2600.0, 5200.0]
```

with the comment at `:22`: *"Two more bands, and the edges are **appended** rather
than inserted."* This array has already been extended once (frontier stage 1,
bands 5 and 6). Any server that reasons about bands duplicates it. The next
extension is a silent client/server disagreement about where THE QUIET ends, and
the fixture above is what catches it.

---

#### E-1 — The compliance ledger's gate is in the wrong place, and one omission is visible from outside the document. `[inference — verify with counsel]`

**Dimension:** E (legal) · **Severity:** major

I cannot review §10 (**F-1**). Two things are assessable from the brief's summary
of it, and both are process rather than law.

**(a) The gate ordering is wrong.** The brief says paid-entry skill tournaments
are "specced but parked as Stage 5." If Stage 5's legality is what makes the
Stage 1–4 architecture worth building — a wallet, KYC hooks, an account model,
an eligibility ledger — then a counsel opinion at Stage 5 is an opinion delivered
after the money is spent. Conversely, if Stages 1–4 stand alone without Stage 5,
then Stage 5's spec is doing no work in this document and should be deleted
(§6). **Either way, "specced but parked" is the wrong state for the riskiest
element in the plan.** Route the derby structure to counsel *before Stage 0* —
the question "does this free-entry structure work as described" costs one
consultation and can invalidate three stages.

**(b) An omission visible without reading §10: minors.** The brief lists
loot-box-adjacent rules, minors, payment-processor policy and prize-notification
law as things to check for. Whether §10 covers them I cannot say. But the
project-side fact is checkable and is not in the plan's favour: a browser game
(**F-3**) has no app-store age gate, and the described feature set —
purchasable currency, subscriptions, prize events with cash payouts — is the
exact combination that attracts COPPA/GDPR-K attention and payment-processor
scrutiny. There is no age-gate mechanism anywhere in the codebase; the only
settings that exist are audio, colour-vision and UI scale.

**Recommendation.** Move counsel to before Stage 0. Add an explicit
minors/age-assurance section to the ledger. Frame both as *verify with counsel*;
I am not the client's lawyer and none of the above is advice.

---

#### D-3 — Physics-plausibility checking is defeated by the cheapest possible bot, because the client's own autopilot already flies plausibly. `[inference]`

**Dimension:** D · **Severity:** major

I cannot red-team §9 (**F-1**), but the brief's question — "can the
physics-plausibility check be gamed by a bot that simply flies plausibly?" — has
an answer specific to this codebase, and it is worse than the generic answer.

**The player does not fly the ship. The autopilot does.** Pillar 4 (§3:42-43) is
*"Frictionless command interaction — **tap to designate; the ship handles the
rest**."* Movement is a tap-to-command autopilot with obstacle steering
(`scripts/obstacles.gd`, `steer`). Combat is auto-resolved; §4:61-62 records the
design as *"player skill lives in fleet/loadout choice, not aiming."*

So a bot does not need to *simulate* plausible flight. It issues the same
designate-command a human issues, and **the game's own shipped autopilot produces
a perfectly plausible trajectory**, because it is the identical code path. There
is no distribution of "human input" to compare against: the input is one tap
every several seconds, and its plausibility is indistinguishable by construction.

**The interactive crack sequence is the same story.** Breaching is *hold-to-
breach* (§6:120-122, `derelict.gd`). A hold is one boolean over time. Adding
timing jitter to a synthetic hold is a five-line change.

**Recommendation.** Do not build behavioural anti-cheat for this game; it cannot
work against this input model and it will produce false positives on legitimate
players. If capsule payouts must be defended, defend them with *scarcity and
identity* (rate limits per verified identity, payout thresholds that make
farming uneconomic) rather than with *detection*. And state in the plan that
behavioural detection was considered and rejected, with this reason — a rejected
approach on the record is worth more than an unexamined one.

---

### MINOR

---

#### C-7 — "The Claim" collides with a shipped v20 feature that already owns the word. `[fact]`

`GameState.claim_colony()` and `is_colony_claimed()` (`game_state.gd:1262`,
`:1266`) shipped in §67. `commission_claimed` (`game_state.gd:367`) is a
different claim again, with a written rule about what may read it
(`game_state.gd:371-375`). A third "claim" concept in the same save and the same
UI vocabulary will produce exactly the kind of same-name-different-thing defect
§64:6051-6056 records for save version v18, which *"pointed at two different
features depending on which document you were holding."*

**Recommendation.** Rename the horizon's concept — "the filing", "the return",
"first return" all fit the fiction better and none is taken. `breached`/`filed`
is already the game's vocabulary for this act (`main.gd:19086`).

---

#### A-4 — "A new survey is a new frontier" is already only a quarter true, which the claims layer will expose. `[fact]`

`reset_to_starter` comments *"A NEW SURVEY is a new frontier"*
(`game_state.gd:~788`). Per **C-4**, a new `run_seed` moves the lair
(`system_db.gd:706`) and the hyper-structures (`:773`) and **nothing else** — all
ten deep-space content streams are salted on `(system, cell)` only. The frontier
is the same frontier.

This is invisible today because nobody replays and compares. It becomes visible
the moment a claims layer draws other people's names on a map that is provably
identical across every run of every player — which is the first time anyone will
notice that their "new frontier" has the same cairn in the same place.

**Recommendation.** Not a defect, but the plan should decide whether it is a
feature (a shared, stable, knowable world — which is what makes claims work at
all) and if so, say it in the fiction. "The chart is the chart; only the engines
move" is a better line than the one the code currently implies.

---

### VERIFIED TRUE — claims that held

The brief asked for these explicitly, and they are the most useful part of the
report for the plan's author, because they mark the ground that does not need
re-argument.

| # | claim | verdict | evidence |
|---|---|---|---|
| V-1 | A server port was anticipated at founding | **TRUE** | §2:26 — State: *"Local save, explicitly serialized"*, rationale *"**Keeps a server port possible without building one now.**"* This is the plan's single strongest citation and it is real. |
| V-2 | The world is fully deterministic and client-side, generated from a seed | **TRUE** | `run_seed` (`game_state.gd:2458`) is the only non-deterministic value in the game, rolled once from the system clock (`:791-793`) with the comment *"every other roll in this game is deterministic by design, and this is the single number that must not be."* `WORLD FINGERPRINT` (`main.gd:15522`) enforces it. |
| V-3 | Godot 4.6, portrait 720×1280 | **TRUE** | `project.godot:8`, `:18-19`, `:25`. |
| V-4 | Save format v20 | **TRUE** | `game_state.gd:36` — `const SAVE_VERSION := 20`. |
| V-5 | Deep-space *generated content* persists nothing | **TRUE** (as narrowed) | No terrain/content keys in the save block at `game_state.gd:2445-2487`. False as stated for player state — see **C-3**. |
| V-6 | The project has an unusually rigorous assertion culture | **TRUE**, and stronger than the brief conveys | 46 harness tags + 17 save-migration modes; `ATTRIBUTION IS EXPLICIT` reads source as text (README:327-330); `THE PINNING LIST IS COMPLETE` asserts two lists agree (README:450-451); the §41 `PHASE INTEGRITY` re-derivation changed the *statistic* rather than loosening the bound (README:453-479). This culture is the project's real asset and it is why the economy findings above are actionable rather than speculative. |
| V-7 | The dossier's design is careful and its assertions are real | **TRUE** | ~19 assertions, `main.gd:18855`–`19372`, including two (`INTEL NARROWS AND NEVER LIES`, `BUYING INTEL NEVER WIDENS THE SEARCH`) that caught defects in the estimator itself (§42). The machinery is good. It is simply not reusable for the stated purpose — **C-1**. |

---

## 3. Per-stage gate assessment

**Not deliverable as briefed** — the plan defines Stages 0–4 and their gate
metrics, and I cannot read them (**F-1**). Inventing five stages and grading them
would be the worst thing this document could contain.

What I can offer is the standard I would hold each gate to when the document
arrives, plus the two gates I can specify now because they follow from measured
facts rather than from the plan's text.

**The standard.** A gate is real if and only if it has all four:

1. **A metric that exists before the stage ships** — not one the stage builds. A
   gate measured by instrumentation the gated stage introduces cannot fail,
   which is this repo's own most-repeated defect (§54: *"`AMBIENT COMBAT DEPLETES
   NOTHING` is satisfied perfectly by a world where nobody fires"*).
2. **A number, decided in advance, written down.** Not "if retention improves."
3. **A kill criterion, not just a hold criterion** — what gets *torn out*, not
   what fails to get built (**F-2**).
4. **A named owner of the decision and a date it is taken.** With one person,
   this means a calendar entry, because the failure mode of a solo gate is that
   nobody ever calls it.

Grade every gate in the document against those four. My prediction, offered as
opinion so it can be checked: most will fail (1) and (3).

**Two gates I can specify now.**

**Gate −1 (before Stage 0) — the economy gate.** Metric: `MIDTIER`, re-derived
per §41 (**B-1**). Pass: the re-derived bar leaves ≥ 0.25 modules (≈ 1,450 cr per
loop) of headroom above a *good roll*, not above the mean — §51:4486's rule —
*and* a false-failure rate below 1% across ≥ 20 samples on an idle machine.
Kill: if headroom against a good roll is under 0.10 modules, **no faucet ships
this horizon at all** and the horizon becomes claims-only (§6).

**Stated plainly, because a gate whose answer is already known should say so: on
today's numbers this gate kills.** §51:4484 puts real headroom at 0.04 modules,
which is under half the kill threshold. The re-derivation might move it — that is
exactly why it must happen first, and why it is assumption 1 in §4 — but a plan
that assumes it moves *favourably* is assuming its way past the one measurement
this project has already taken. This gate is measurable today with
instrumentation that already exists, which is what makes it the right first gate.

**Gate 0 (Stage 0 exit) — the platform gate.** Metric: a web export running one
complete 8-minute loop on a mid-range phone browser at ≥ 30fps sustained, with
`STREAMTEST`-equivalent `worst` frame time under 60ms. Pass: it runs. Kill: if a
web build cannot be produced in five working days, the browser-first premise
(**F-3**) is unfounded and the whole horizon's threat model, audience model and
distribution model need rewriting before anything else proceeds.

---

## 4. The five assumptions most likely to sink this horizon

Ranked by (probability wrong) × (cost if wrong). Each with the cheapest test that
would falsify it — cheapest, not best.

---

**1. "The economy can absorb a new faucet."**
*Why it's first:* it is the only one that is already measurably in trouble
(**B-1**: 232 credits of headroom by the project's own reckoning, a bar flaky at
exactly its failing value, re-derivation overdue since §65).
**Cheapest falsifying test:** do the §41 re-derivation. Twenty `PYXIS_PACINGTEST`
runs on an idle machine, plot the distribution, re-derive the bar from it. Cost:
one session, no new code, and **it is already owed** — so its true marginal cost
is zero. Falsified if the honest bar leaves under 0.10 modules above a good roll
— and note that §51:4484 has already measured 0.04 — in which case no Horizon 5
faucet fits and the horizon must be claims-only.

---

**2. "Shared stakes make solitude stickier rather than spoiling it."**
*Why it's second:* it is the whole thesis, and it is the one nobody has any
evidence about. Every other finding is downstream of this being true.
**Cheapest falsifying test:** a **ghost chart**, single-player, no server, no
account, ~one day of work. Record the developer's own past surveys as a static
data file of `(system, cx, cz, name, date)` rows shipped with the build. Draw
them on the chart panel — which already draws hint cones and beacon dots
(`chart_panel.gd:179-293`) — labelled honestly as prior surveys, not as other
players. Then play it for a week and answer one question: **does finding a name
out at 3,000u make the place feel more like somewhere, or less like yours?**
That is the entire thesis, tested for one day's work with no server, no legal
exposure and no promise to anyone. Do not fake other players; a deception is not
a test result, and the honest version measures the same thing.

---

**3. "A solo developer can carry standing live-service ops."**
*Why it's third:* highest cost if wrong, and **currently untested in either
direction.** The git record shows commits on **11 of the 11 days** this project
has existed (2026-07-28 → 2026-08-07, `git log --format=%ad --date=short | sort -u`),
and the cadence inside those days is extraordinary: **six shipped stages in about
36 hours** across 2026-08-04/05 — the Hunt's stages 4–6 including a save bump to
v20 on the 4th (§64:6037), then the frontier's stages 1–3 on the 5th, *"the
commissioned loop"* opened and closed the same day it was commissioned
(§64:6014, §64:6025).

**That velocity is real and it is also the trap.** It is *feature* velocity on a
deterministic offline codebase with an excellent harness, and it is measurably
sensitive to tooling rather than to effort: §69:6731-6734 records a round
dropping to *"4 minutes against the previous round's 37"* purely from knowing
about the import pass and `--check-only`, against *"three silent hangs this
horizon, one of four hours"* (§69:6735). Live-service ops is not measured in
features per day; it is measured in **response latency to an incident you did not
schedule**, and nothing in this record demonstrates that quantity in either
direction.

The brief describes a game "that can sit untouched for a month" — true of the
*artifact*, because a deterministic offline client has no ops surface at all, and
unevidenced of the *developer*, who has shipped on every day of the project's
existence. **Horizon 5 removes exactly the property that makes the current game
safe to leave: the absence of a server.**
**Cheapest falsifying test:** deploy the do-nothing claims server (§6) and leave
it running for **three weeks while touching nothing** — no players, no traffic,
no features. Note every time it needs attention: a certificate, a bill, a host
migration, a dependency advisory, an unexplained restart. If the answer is more
than zero on an *empty* server, it is much more than zero on a populated one.
Cost: a $5/month VPS and three weeks of not doing anything, which can run
concurrently with everything else.

---

**4. "Anti-cheat can distinguish a player from a bot."**
*Why it's fourth:* it is load-bearing for every real-money element, and I believe
it is already false (**D-3**) — the autopilot means a bot's trajectory is
generated by the game's own shipped pathing code.
**Cheapest falsifying test:** write the bot. Half a day. Godot exposes input
synthesis; the client source is yours. Drive one complete survey-and-breach loop
with synthetic taps and hold-to-breach, then run whatever plausibility check §9
proposes against the trace. If it passes — and I expect it to pass trivially —
the anti-cheat section needs replacing with a scarcity-and-identity model before
any money is attached.

---

**5. "The rumor economy carries a daily loop when capsules are ~monthly."**
*Why it's fifth:* it is genuinely uncertain, and unlike the others it is testable
against machinery that already exists.
**Cheapest falsifying test:** instrument the **existing** intel dossier. It
already has eight channels, a paid desk row (`port_panel.gd:1295-1358`), a
narrowing estimate and a payoff. Add local-only telemetry — sessions played,
readings bought, whether the apex was found — and answer: **do players who buy
intel come back more days than players who do not?** If the answer is no for a
hunt whose payoff is a boss fight and a wreck, it will not be yes for a rumor
whose payoff is a capsule you may not reach. Cost: a counters dict and a debug
readout. Zero new systems, zero server.

---

## 5. What's missing

Things the plan should specify. Some may be in the document; I cannot check
(**F-1**). All of them are things I could not answer from the brief, and every
one is cheaper to answer now than after Stage 1.

**Architecture and data**
- **The identity scheme for a claimed place.** Nothing in the game has one
  (**C-5**). I recommend `(system_id, cx, cz)`.
- **A server-held vs client-held table** for every value (**D-1**), with the
  mechanical rule: anything convertible to money is server-held.
- **What NEW SURVEY does to claims** (**D-2**). Player-visible on day one.
- **The offline degradation contract**, feature by feature: what a player with no
  connection sees, for how long, and what happens to a claim filed offline.
  "Offline-first" is a posture, not a spec.
- **The auth story.** The brief names it as a dimension; I could not find a
  single line of auth-adjacent code (`grep` for HTTP/crypto → 0). Device UUID?
  Account? Third-party identity? Each has a different KYC and minors story.
- **The wire contract as a checked-in fixture** (**C-6**), with `BAND_EDGES`
  (`deep_space.gd:33`) as its first entry.
- **Capsule density as a function of population.** The brief's own example of a
  good finding, and it is right: a rarity target of "weekly brush / monthly find"
  is a *per-player* rate, and per-player rates require density to scale with
  population. State the function. At 100 players and at 10,000.

**Operations and money**
- **Hosting cost and single-point-of-failure exposure**, with numbers. A thin
  claims server is a $5–20/month VPS; a wallet with a transaction log and payout
  reconciliation is not, and the plan should not let the first number stand in
  for the second.
- **What happens when the server is down during a derby.** This is the first
  broken public promise and it needs an answer before the first derby is
  announced, not after.
- **CAC.** The brief's break-even (100–150 subscribers at $5 vs ~$500/month
  prizes) is a *contribution-margin* calculation with no acquisition cost in it.
  A subscription business with zero marketing budget acquires subscribers at
  whatever rate organic discovery provides, which for an unreleased browser game
  with no web build (**F-3**) is not yet a measurable number. State the assumed
  conversion rate from installs, and the assumed installs.
- **Churn.** 100–150 *subscribers* is a stock, and prizes are a monthly flow. At
  5% monthly churn that stock needs 5–8 replacements a month forever, which is
  the number that actually determines whether this is sustainable.

**Design and content**
- **The moderation model for player-supplied names** (**C-5**). My
  recommendation: an authored word vocabulary, not free text.
- **Age assurance** (**E-1**).
- **What the progression ladder is for, if the competitive surface ignores it**
  (**A-3**).

**Process**
- **A rollback per stage** (**F-2**), including what the save does with orphaned
  state.
- **Which STRATEGY sections this horizon amends**, edited in the same commit —
  §5:72 at minimum, and §2:25 if live-ops is really being taken on.

---

## 6. What to cut

**Cut the derbies. All of them — Stage 5's paid tournaments and the free-entry
sweepstakes both.**

They are not the weakest *idea* in the plan. They are the element with the worst
ratio of thesis-information to cost, and by a wide margin:

- They carry **essentially all** of the legal exposure (**E-1**): sweepstakes
  registration and bonding in some US states, prize-notification law,
  payment-processor policy, KYC, minors, and multi-jurisdiction variation.
- They carry **essentially all** of the standing ops load: scheduled events with
  published times, live prize disbursement, dispute handling, and an uptime
  promise on a specific date — the first thing on this list that a two-week
  absence visibly breaks (**assumption 3**).
- They carry the **$500/month cash burn** that generates the entire subscription
  break-even problem. Remove them and the subscription no longer needs to fund
  anything, so the 100–150-subscriber target and its hidden CAC assumptions stop
  being load-bearing.
- They put a **spec-loadout arena** in tension with the newest content in the
  game (**A-3**).
- And they **test the least interesting hypothesis.** Prize competitions are
  known to attract players; that is not in doubt and does not need testing. What
  is in doubt is whether *this* game — whose stated trade is that the less anyone
  is watching, the better it pays — survives anyone watching. A derby answers a
  question nobody asked.

Second cut, smaller: **the daily rumor cadence** (**A-1**). Keep rumors if they
earn their place; make them event-driven — you get a rumor when you *do*
something — rather than date-driven. That removes the wall clock the game does
not have, the device-clock exploit, the §5 boundary violation, and the
punish-you-for-being-away dynamic, all at once, and costs only the login habit,
which is the thing this game should least want.

### The minimum thesis-testing version

One stage. No currency, no capsules, no store, no subscription, no prizes, no
accounts.

- A read-only claims server. Two endpoints: `POST /claim {system, cx, cz, name}`
  and `GET /claims?system&cx&cz&r`. Identity is a device UUID. No wallet, no
  auth beyond a rate limit.
- Names come from an **authored vocabulary**, not free text (**C-5**) — no
  moderation surface.
- Places are `(system_id, cx, cz)` (**C-4**) — the shared world is already there
  and already free.
- Fully degradable: no connection means no names, the game is otherwise
  identical, and nothing is lost. Every existing assertion stays green because
  nothing existing changed.
- Save impact: one new store, one version bump, following the `beacons`
  precedent exactly (**C-3**).

That is a week or two of work, it violates no founding decision that a one-line
§5 amendment cannot honestly cover, it takes no money from anyone, it creates no
legal exposure, it can be switched off without breaking a promise, and **it tests
the actual thesis**: does a name on a place, out where nobody is watching, make
this game stickier or spoil it?

If the answer is no, nothing downstream was worth building. If the answer is
yes — then come back with the document, the re-derived `MIDTIER` bar, and a
counsel opinion, and the rest of this horizon deserves the serious review it
could not get today.

---

## Appendix — verification log

Every command run against `317327d`, so the findings can be re-checked or
refuted.

```
docs/HORIZON-5-THE-CLAIM.md .......... absent: working tree, all 6 remote
                                       branches, full history, all 40 PRs,
                                       whole filesystem
networking (HTTPRequest/HTTPClient/
  multiplayer/WebSocket) ............. 0 matches in scripts/
wall clock (get_unix_time/
  get_date_dict/get_time_dict) ....... 0 matches in scripts/
export_presets.cfg ................... does not exist
tools/run_harness.sh ................. TAGS=46, SAVE_MODES=17 -> 63 runs
                                       (README said 62 at :119 and 61 at :49
                                        when measured; both corrected below)
scripts/main.gd ...................... 21,888 lines
scripts/data/module_db.gd ............ 51 modules, 0-90,000 cr, mean 16,592
scripts/main.gd:168 .................. PACING_MAX_MODULES := 3.00
scripts/main.gd:169 .................. PACING_MIDTIER := "lance_1"
scripts/data/module_db.gd:152 ........ lance_1 price 5,800
scripts/main.gd:154 .................. PACING_MINUTES := 8.0
scripts/main.gd:2558, :2844 .......... "97% of its ceiling", in code comments
scripts/game_state.gd:36 ............. SAVE_VERSION := 20
scripts/game_state.gd:2478-2480 ...... beacons, colonies, last_colony_jump saved
scripts/game_state.gd:2458 ........... run_seed saved
scripts/game_state.gd:268-270 ........ "a save file cannot leak the answer"
scripts/data/system_db.gd:706-728 .... lair_pos(id, run_seed), pure
scripts/deep_space.gd:33 ............. BAND_EDGES, client-side const
scripts/deep_space.gd .. run_seed ..... 2 matches, both the lair
scripts/deep_space.gd .. salted streams  10, all on (system_id, cx, cz)
scripts/game_state.gd:2134-2138 ...... _sanitize_ship_name: trim + truncate
scripts/game_state.gd:849 ............ is_system_charted -> per-system boolean
scripts/deep_space.gd:1304-1334 ...... landmark_at -> {kind,pos,rot_y,band}, no id
git log --format=%ad --date=short
  | sort -u .......................... 11 distinct days, 2026-07-28..2026-08-07
docs/STRATEGY.md:6010 vs :6023 ....... frontier stage 4: "shipped" vs "not built"
docs/STRATEGY.md:7206 vs README:119 .. 634 assertions vs 616 — one horizon apart
docs/STRATEGY.md:51:4484-4486 ........ "real headroom is about 0.04. Anyone
                                        adding income needs four samples, not one"
docs/STRATEGY.md .. "solitude" ....... 1 hit, §49:4341, and it means elbow room
docs/STRATEGY.md .. "multiplayer" .... 0 · "server" 1 (§2:26) · "subscription" 0
                                        · "revenue" 0 · "prize" 0 · "leaderboard" 0
                                        · "network" 0 · "online" 0 · "latency" 0
sweep totals recorded per section .... §68:6634 61/588 · §69:6726 61/592
                                        · §70:6807 61/598 · §71:6975 62/612
                                        (§65, §66, §67 record none)

NOT verified: the 616 / 634 PASS baseline. No Godot binary in this container,
so tools/run_harness.sh could not be run. Treat every citation of either
number as a citation of a document, not as a measurement — which is the
point of F-4.

NOT verified: that the project still parses. `--check-only --script
scripts/main.gd` needs a Godot binary and there is none here. The two
GDScript edits below are comment-only -- `git diff` over `scripts/` returns
no changed line that is not a comment or blank, and the main.gd block is
tab-indented inside its function (checked with `cat -A`) -- so parse risk is
as close to zero as an unrun check gets. RUN IT ANYWAY BEFORE THE NEXT
SWEEP. This file's own §0 says a document written about a codebase has an
error rate; so does one written against a codebase it cannot execute.
```

---

## What this engagement changed in the repo

The review is the deliverable. But four of its findings were live defects in the
repo rather than opinions about a plan, and this project's rule is that the
inventory is part of the commit that changes it — so they are fixed here rather
than filed as recommendations.

| file | change | finding |
|---|---|---|
| `docs/STRATEGY.md` §64 | Horizon 5 added to **Outstanding**, with the verdict and the three repo-level debts | **F-1** |
| `docs/STRATEGY.md` §64 | frontier stage 4's row corrected `not built` → **BUILT** (`5bbf69c`, PR #37), and the 48-hour drift recorded rather than quietly patched | **F-2** |
| `docs/STRATEGY.md` §64 | "deep space persists nothing" narrowed to *generated content*; the `beacons`/`colonies` player-state line drawn | **C-3** |
| `README.md` | baseline `616 / 62 runs` → `634 / 63 runs`, with how each was derived and why the old one was stale | **F-4** |
| `README.md` | tag count `44 → 46`, run arithmetic `61 → 63`, and the §64 pointer corrected | **F-4**, **F-2** |
| `scripts/game_state.gd:268` | the false *"a save file cannot leak the answer"* replaced with what is actually true, and why 19 assertions cannot see it | **C-2** |
| `scripts/main.gd:3681` | *"Six things can teach you"* → the eight channels, listed rather than counted | **C-1** |

Nothing else was touched. No behaviour changed; both GDScript edits are comments.
The remaining findings are recommendations, not repairs, because they are
decisions for the owner rather than facts that are wrong.
