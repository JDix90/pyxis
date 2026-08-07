# Horizon 5 ("The Claim") — Independent Review

Subject: `docs/HORIZON-5-THE-CLAIM.md` (435 lines), per the engagement in
`docs/REVIEW-BRIEF-HORIZON-5.md`.

Reviewed against `766c5fe` (main). Date: 2026-08-07.

> **Note on this document's history.** A first pass was written and committed
> before the plan reached this container — it could review only the thesis as
> the brief summarised it, and said so. This replaces it entirely. Where that
> pass reached a conclusion the actual document refutes, the retraction is
> recorded in §7 rather than quietly dropped, because a reviewer who silently
> revises is no better than a baseline with an age on it.

---

## 1. Verdict

# PROCEED TO STAGE 0 — WITH CHANGES. DO NOT PRE-APPROVE ANYTHING PAST IT.

That is a position, not a hedge, and it splits deliberately at the plan's own
first gate.

**Why proceed.** This is a good document. It is not merely well-written — it is
*correct about the hard part*, and the hard part is the one most plans of this
kind get wrong. **I-2** identifies, unprompted, that a client-side deterministic
world means anyone can enumerate it headless, and concludes that anything with
value attached must be server-placed. I verified that reasoning against the
generator and it is not just true, it is *more* true than the plan knows
(**C-1**). §8 parks pooled pots, cash-out currency and prediction markets
permanently, with reasons. §11 cites the overjustification effect against its own
monetisation. §12 applies the `TUTORIALTEST sentries=0` lesson to telemetry
before anyone had to point it out. A plan that argues *against itself* this
competently has earned a real review rather than a reflexive no.

**And Stage 0 is the right first move.** It is severable, cheap, takes no money,
creates no legal exposure, degrades to today's game when the server is off, and
tests the only hypothesis that matters. An earlier pass of this review
independently recommended almost exactly Stage 0 as "the minimum thesis-testing
version" before the plan was available. The plan got there first.

**Why with changes, and why the line is drawn at Stage 0's gate.** Stage 0 as
written **cannot produce the number its own gate is defined on**, and it ships a
permanent artifact on a resource I measured at roughly 4,000 items and 30–50
player-hours (**A-1**, **A-2**). Those are cheap to fix now and unfixable after
launch, because the claims are specced as permanent. Past Stage 0, three of the
plan's load-bearing technical claims are wrong (**C-1**, **C-2**, **C-3**) and
the economy section never once mentions the pacing band that governs it
(**B-1**) — none fatal, all needing rework before those stages mean anything.

**Why not "proceed" outright.** Because the gates are only real if something can
fail them, and Stage 0's gate currently cannot be computed. Fix that and the
gate becomes the decision point the plan intends.

### Conditions — all seven before Stage 0 ships

Every one is cheap now and expensive-to-impossible once players exist, which is
why they gate Stage 0 rather than the stage they nominally belong to.

1. **Decide claim granularity.** §13 lists it as an open question; §2's gate
   metric is undefined without it. Recommendation: **per landmark** (≤3,955
   sites). §2's own worked example is per-system, which is **3 claims globally,
   ever**. See **A-1**.
2. **Answer what happens when the frontier is fully claimed** (**A-2**) before
   shipping a permanence promise you cannot withdraw. Recommendation: seasonal
   claims, permanent *record*.
3. **Defend Stage 0, or don't make it permanent.** It is the only stage §9's
   defences explicitly skip, and it is the stage that mints the permanent
   artifact — six accounts can claim the enumerable frontier in a day.
   **Ship a retraction path.** See **D-1**.
4. **A counsel *scoping* call before Stage 0, not Stage 3** (**E-4**). §13's own
   first open question proves Stage 0's account model is already constrained by
   Stage 3's KYC requirement. One conversation, costing the same order as one
   derby's prize budget, that can invalidate three stages.
5. **Decide age assurance** (**E-3**). Zero words in the plan, zero mechanism in
   the code, browser-first with no store gate. It is a Stage 0 account-model
   decision and cannot be retrofitted without re-consenting everyone.
6. **Correct I-1's "61 runs"** and re-verify the baseline: 63 runs, and STRATEGY
   §72 says 634 assertions where the README said 616. An invariant resting on a
   stale count is the plan's own `TUTORIALTEST` lesson, on page one.
7. **Record the §5:72 / §2:25 amendment in `STRATEGY.md`** (**F-2**). The plan
   confronts the MMO exclusion by name and well; it never mentions "timer or
   energy monetization", "alliance/social systems", or §2:25's headcount
   rationale.

### To proceed past Stage 0's gate, additionally

8. **Answer the oracle question before building the rumor layer** (**D-3**). If
   hints compose, the intel system is a convergent estimator and rate limits do
   not bound it. Adopt per-(capsule, account) nonces and server-side
   intersection, or accept that capsule locations are findable by anyone patient.
9. **State the reveal radius** (**D-2**) — it is the single parameter that
   decides whether 50 accounts strip a system in an evening.
10. **Settle §13's intel-pricing question as a security decision, not only an
    economic one** (**D-9**): salvage is minted by editing one integer in a
    plaintext JSON file.
11. Rewrite §3's dossier-reuse claim (**C-1**), §4's private-region seed
    mechanism (**C-2**), and §12's derby mirroring assertion (**C-3**).
12. Put a credit number on intel and reconcile it with §51:4484 (**B-1**).
13. Produce a web export and run the game in a browser (**F-1**).
14. **Resolve I-5 against §4 sink 1 and §6** (**E-2**) — counsel picks which of
    the two consistent readings applies; do not let it stay contradictory.

---

## 2. Findings index

**Blockers**

| # | dim | finding |
|---|---|---|
| **A-1** | A | Stage 0's gate metric is uncomputable until §13's open question is closed; §2's own example yields **3 claims globally, ever** |
| **A-2** | A | The claimable frontier is ≤3,955 sites / ~30–50 player-hours, permanent and non-renewing while everything around it resets |
| **D-1** | D | Stage 0 mints the permanent artifact in the one stage §9's defences explicitly do not cover — the invariant ordering is inverted |
| **D-2** | D | I-2's reveal query is a **coverage oracle**; §9 item 1 mistakes "not in the client" for "not derivable" |
| **D-3** | D | "Vague, never false" makes intel a **convergent estimator** — error shrinks as `4e/(K+1)` in the number of readings |
| **E-1** | E | §10's dominant-factor argument does not follow, and §7 concedes the opposite in its own words. Stage 5 has nothing else holding it up |
| **E-2** | E | I-5 as written is contradicted by §4 sink 1 and §6 — the plan states the prohibition and sells the violation four bullets apart |
| **E-3** | E | Minors and age assurance: **zero words** in the plan, zero mechanism in the code, and the decision point is upstream of I-8's gate |
| **E-4** | E | I-8 fires at Stage 3; §13's own first open question proves Stage 0 is already constrained by it |

**Majors**

| # | dim | finding |
|---|---|---|
| **C-1** | C | I-2 and §3 contradict: server-placed capsules cannot use hint builders that derive from client-side truth |
| **C-2** | C | Private regions — "its own seed" is the wrong knob; verified, a new seed changes almost nothing |
| **C-3** | C | §12's derby mirroring assertion measures what cannot vary and cannot see what can — violates the plan's own I-7 |
| **B-1** | B | The plan never mentions the pacing band; intel is priced in salvage credits with no number |
| **B-2** | B | Private regions with purchaser-set rarity are an undeclared faucet in the one unobserved arena |
| **A-4** | A | §11's casual-vs-grinder mitigations cover the derby and skip the claims layer, which ships first and skews hardest |
| **D-4** | D | §9 item 3's "human-behaviour baseline" has almost no entropy, and the instrument it cites is the wrong shape and forbidden to be read |
| **D-5** | D | Interactive cracking is a 3-second timer; §12 asserts the one property a `sleep()` satisfies for free |
| **D-6** | D | KYC defends the payout, not the odds — and the mirroring that makes the derby legally clean is what makes 50 entries maximally valuable |
| **D-7** | D | All three Stage 0 leaderboard axes are monotone in machine-hours, poisoning the dataset that gates the whole horizon |
| **D-8** | D | Free entry + per-entrant instances = an unauthenticated compute faucet; §9 has **zero** availability items |
| **D-9** | D | The plaintext save is the trust boundary, and §13's "salvage credits, hard" makes the D-3 oracle free |
| **E-5** | E | §6 supplies, as a subscriber-to-prize ratio, the exact sentence §8 says regulators are practiced at piercing |
| **E-6** | E | §10 bullet 3's stated *rule* is narrower than the *risk* named in its own sentence |
| **E-7** | E | Private-region seeding is a purchased randomized reward, and §10 has no loot-box bullet |
| **E-8** | E | The derby is drafted in sweepstakes vocabulary and structured as a skill contest; §5 sends counsel one document that is both |
| **E-9** | E | I-4's protection rests entirely on the word "instanced," which §6's seasons never repeat |
| **F-1** | F | Browser-first is unbuilt and uncosted — no `export_presets.cfg` exists |
| **F-2** | F | The §5:72 / §2:25 reversal is unrecorded; five gated stages with no rollbacks |

**Minors, and one live defect**

| # | dim | finding |
|---|---|---|
| **D-10** | D | **Live defect, shipped today:** the intel hint's dedup key and its RNG seed key disagree |
| **A-3** | A | The plan leans on "nobody is watching" — a property never written down as a pillar |
| **C-4** | C | I-1 cites "61 runs"; it is 63, and §72 says 634 assertions where the README said 616 |
| **C-5** | C | §12's `PYXIS_CLAIMTEST` stub tests agreement with a mirror of its own author |
| **C-6** | C | Prize floor stated as both $10 and $25; "invite-only" access grant unaddressed by I-3 |
| **E-10** | E | Twelve further compliance omissions, tabulated in §3 |
| **V-1…V-10** | — | Claims that held — verified-true is information |

---

## 3. Findings

Labels: **fact** (measured or quoted), **inference**, **opinion**.

---

### D-2 — I-2's reveal query is a coverage oracle. §9 item 1 mistakes "not in the client" for "not derivable". `[fact + inference]`

**Severity: blocker.** Dimension D.

**I-2's diagnosis is right and its remedy is incomplete.** §9 item 1: *"the
location of anything valuable simply is not in the client. **The seed-mining
attack dies here.**"* It does. A **coverage** attack replaces it, and the
coverage attack is cheaper.

I-2 specifies capsules are *"revealed to a client only in response to an
authenticated, rate-limited query about a position the server believes that ship
can occupy."* **Any positional reveal with radius `r` is a spatial membership
oracle**, and sweeping it is a covering problem of path length ≈ `A / 2r`.

Deep content sits between band 3 (depth 1100) and the band-6 edge (5200) —
`deep_space.gd:33` — an annulus of area ≈ 8.2 × 10⁷ u². Sustained speed ≈ 8 u/s
(hull `max_speed` 5.75, `module_db.gd:99`, plus the best drive at `:660`):

| reveal radius `r` | sweep path, one system | 1 account | **50 accounts** |
|---|---|---|---|
| 250 u (the Hunt's search-circle scale) | 164,000 u | 5.7 h | **~7 min each** |
| 64 u (one cell, `deep_space.gd:53`) | 642,000 u | 22 h | **~27 min each** |
| 20 u | 2.06 × 10⁶ u | 71 h | **~1.4 h each** |

**The finding is robust across three orders of magnitude of `r`: there is no
reveal radius at which 50 accounts cannot strip a system inside one evening.**
Multiply by three for the whole game.

**What §9 item 5 buys: nothing on the binding axis.** The constraint is
*flight-time*, which parallelises perfectly and linearly across accounts. A
per-account limit tight enough to matter (one reveal per 30 s) still permits
2,880 reveals/day/account — more than the entire sweep needs at r = 250. Per-IP
limits fail against residential proxies by construction; that is what they are
sold for.

**And §9 item 3 has no teleport model, while the game has three.** All verified:

| teleport | where | gate |
|---|---|---|
| `recall_to_system()` | `main.gd:1508` | free, instant, to spawn |
| `colony_jump_to()` | `main.gd:1585` | 500 salvage + 300 s cooldown (`main.gd:281`) measured against `GameState.played_seconds` (`main.gd:1570-1571`) |
| `_emergency_warp` | `player_ship.gd` | death → spawn after 1.4 s. **A bot can use dying as fast travel** |

The one teleport that goes somewhere the *attacker chooses* is gated by
`played_seconds` and `salvage` — **both of which come out of the plaintext save**
(**D-9**). An envelope check that models colony jump is trusting the save; one
that does not will reject honest players who used it.

**Recommendation.** Treat sweep economics, not query authentication, as the
capsule's actual defence: make the expected cost of sweeping exceed a capsule's
value, and tune it on the server dial §3 already specifies. State the reveal
radius in the plan — it is the single parameter that decides this — and add the
three teleports to §9 item 3 explicitly.

---

### D-3 — "Vague, never false" makes the intel layer a convergent estimator. N accounts triangulate without flying; one account converges by walking. `[fact + inference]`

**Severity: blocker.** Dimension D. This is the deepest finding in the review.

**The honesty guarantee is what makes the attack work.** §3 promises the
`INTEL NARROWS AND NEVER LIES` discipline carries over: *"intel may be vague,
never false."* Guaranteed containment is precisely the property that makes
intersection sound.

**Two independent attacks.**

**(a) Cross-account triangulation.** A bearing hint is a cone from a stated
origin — `{kind, ox, oz, bearing, err}` (`hunt.gd:263-269`) — and
`Hunt.estimate` is a **pure static function the attacker has the source to**
(`hunt.gd:173-223`), doing a 7-pass polar intersection of arbitrarily many cones.
50 accounts each buy the cheapest reading from a different position; export the
hints (plaintext, `apex_intel` in the save); intersect offline with no cap.
`HINT_CAP := 8` is a per-save display cap enforced in `add_apex_hint` — **it is
not a security control**, because the attacker computes offline.

**(b) Same-account stacking, and this one is arithmetic.** Verified at
`hunt.gd:258-259`:

```gdscript
rng.seed = hash("%s|hint|%s|%d|%d|%d" % [
    system_id, kind, run_seed, int(round(from.x)), int(round(from.z))])
```

**The observer position is rounded to integers.** Moving **1.0 unit** re-seeds
the RNG and yields a *fresh, independent* uniform draw of the same true bearing.
For K iid samples `bᵢ = θ + Uᵢ` with `Uᵢ ~ U(−e, e)`, guaranteed containment gives
`[max(bᵢ) − e, min(bᵢ) + e]`, of expected width **`4e/(K+1)`**:

| readings K | effective error, from `e = 8°` |
|---|---|
| 1 | ±8.0° |
| 4 | ±3.2° |
| 19 | ±0.8° |
| 79 | ±0.2° |

**Nineteen units of flying buys a 10× precision improvement, with no new
information — only more samples.** Rate limits scale K linearly with time; they
do not bound it.

**Is any formulation of the rumor layer *not* an oracle?** You can keep two of
{honest, cheap, composable}. The three non-oracle shapes: **(1)** a single fixed
nonce per (capsule, account), so every reading that account buys is a
deterministic refinement of *one* draw rather than an independent sample;
**(2)** the server returns an already-intersected `{center, radius}` for that
account, never cone parameters, with a floored radius — pooling 50 circles is far
weaker than pooling 400 cones; **(3)** warmer/colder only on positions the ship
has physically occupied, which collapses back to **D-2**'s sweep economics.

**Recommendation.** Adopt (1)+(2). And state plainly in §9 what §3 currently
implies otherwise: **the rumor layer is a pacing device and cannot be
load-bearing anti-cheat.**

---

### D-1 — Stage 0 mints the permanent artifact in the one stage §9's defences do not cover. `[fact + inference]`

**Severity: blocker.** Dimension D, converging with **A-1** and **A-2** from a
different direction.

§2's abuse controls are exactly two: rate limits per account, and a plausible
flight envelope. §9's other defences all presuppose money or events that do not
exist yet — §2 says *"no KYC yet — no money exists yet."* Meanwhile §2 creates
**permanent** etched names, and §2 states *"Seasons reset; **etched names do
not**."*

**The attack.** Enumerate the world offline (`plan_cell`, `deep_space.gd:826` —
no seed, so every account's world is identical). Precompute a serpentine route.
Run headless clients at real speed — **the physics envelope is fully satisfied,
because the bot actually flies.** Combat is auto-resolved; movement is one
`command_move` per waypoint; death costs 1.4 s.

64 u cell at 8 u/s ≈ 8 s → ~10,800 cells/account/day against ~63,000 cells for
all three systems. **Six accounts finish the enumerable frontier in a day. Fifty
finish in under three hours.** Cost: ~$5 of proxy and 50 free email addresses.
Gain: permanent ownership of every first-charted name in the game, acquired
*before* the names are worth anything and held until they are.

**§9's own logic argues against §2.** Item 2's leverage is that *"a bounded,
instanced, spec-loadout derby is a small arena the server fully observes, versus
an open world it cannot."* An unbounded, permanent, open-world registry is by
that reasoning the **least** defensible object in the design — and it is the
first thing built.

**Recommendation** (none of which touches I-3/I-4/I-5/I-8):
1. **Make Stage 0 claims season-scoped**, which **A-2** independently recommends
   for pacing reasons. Permanence becomes a reward for a defended stage.
2. **Make permanence non-parallelisable** — one etched name per account per
   season.
3. **Ship a retraction path in Stage 0.** §2 has none and §12 asserts none. If a
   name cannot be un-etched, the first confirmed farm is a permanent scar on
   every player's chart.

---

### E-1 — §10's dominant-factor argument does not follow, and §7 concedes the opposite in its own words. `[inference — verify with counsel]`

**Severity: blocker.** Dimension E.

§10 bullet 2: *"the dominant-factor test asks what separates winner from losers
among entrants; when the capsule's location is random and searchers are
comparably skilled, that factor is chance. **The derby's mirrored layout exists
precisely to change this answer.**"*
§7: mirroring means *"chance is **equalized across the field rather than argued
away**."*

**These are different claims and the second undercuts the first.** Mirroring
converts *independent* draws into a *common* draw. That equalises the
distribution facing each entrant **ex ante**. It does not remove chance from the
**realization that separates them**: two entrants of identical skill, facing the
identical hidden capsule in the identical instance, are still separated by which
direction each searched first. §7 states this correctly and §10 then asserts the
stronger proposition without argument. **The more honest sentence falsifies the
more load-bearing one.**

**Why blocker rather than curiosity.** Stages 3–4 do not need the skill argument
— they have free entry, which removes consideration, and the analysis ends there.
**Stage 5 has nothing else**, and §7's whole premise is *"the derby format is
already shaped for this argument."* It is shaped for *fairness*, which is a
different property from *skill predominance*.

**The word doing the damage is "hidden"** (§5: *"the derby capsule is hidden in
the same spot for all"*). Three restructurings the spec can accommodate: a
**known objective on a hazardous route** (a race — nothing is guessed); a
**solvable search** where identical intel makes the location derivable
(inference, not a guess); or **multi-leg** aggregate scoring.

**And the duplicate-bridge analogy drops the part that does the work.** Duplicate
bridge neutralises the deal by playing the same deal at every table, scoring
comparatively, **and playing many boards** — because a single board has variance
large enough to rank pairs unreliably even when identical. The derby has the
first two. It is one capsule, one location, one crack: **a one-board duplicate.**
Cheapest fix, and a good game-design change anyway: make a derby three legs.

**Recommendation.** Rewrite §10 bullet 2 to claim only what mirroring delivers —
it removes *differential* chance between entrants, and it removes seed-mining and
gear advantage. Mark skill-predominance **unproven** and make it an explicit
precondition on any Stage 5 unpark, not a property Stage 3 already has. Verify
with counsel.

---

### E-2 — I-5 as written is contradicted by §4 sink 1 and §6. The plan states the prohibition and sells the violation four bullets apart. `[fact + inference — verify with counsel]`

**Severity: blocker.** Dimension E. This is the brief's sharpest question and the
answer is not the comfortable one.

I-5: *"nothing purchasable — subscription, currency, progression — **may improve
prize odds**."* §4: *"What currency never buys: prize-event advantage (I-5)."*
§4 sink 1, four bullets earlier: private regions with *"its own capsule seeding
… **configurable rarity** … the casual player's winnable pond."* §6: the
subscription includes a *"**private-region allowance**."*

§5's win condition is *"fastest verified crack wins."* §3 describes capsules as
*"cracked via an interactive sequence."* §9 item 4 uses the same words for both.
**A purchased private region with rarity dialled up is a practice range for the
exact interactive sequence the derby scores** — purchasable with real money and
available on recurring subscription. The derby is a rank-order contest with a
fixed prize schedule, so it is zero-sum: anything raising one entrant's expected
performance lowers everyone else's probability of winning. **Under I-5's literal
text this is a violation, and I-5 names "subscription" by name.**

**I will not resolve this in the client's favour.** Two internally consistent
resolutions exist:

1. **Re-scope I-5 to what does the legal work** — structural equality of the
   prize event: nothing purchasable may alter the instance, the entry mechanism,
   the number of entries, objective placement, prize schedule, or verification;
   entry is free to all. Under this reading sink 1 is fine, because there is no
   paid entry route for a purchase to advantage.
2. **Keep I-5 as written**, in which case sink 1 and the subscription's
   private-region allowance must go — i.e. the flagship sink dies.

Per the engagement's ground rules I am **not** recommending (1) on cleverness
grounds. **Counsel picks**, and the question to put is narrow: *does a paid
practice environment for a free-entry, no-paid-route prize promotion create
consideration or "purchase improves chance" exposure?* My reading of §10's own
logic suggests no — but I-5 is currently a statement the plan's own Stage 2
falsifies, and that is exactly the quiet drift §0 says the ledger exists to
prevent.

**Related and unresolved either way:** if the crack has a hard human-paced floor
(§12 asserts it does), practice compresses the field toward that floor and
**ties become the normal outcome** — and §5 specifies no tie rule (**E-10**).

---

### E-3 — Minors and age assurance: zero words in the plan, zero mechanism in the code, and the decision point is upstream of I-8's gate. `[fact + inference — verify with counsel]`

**Severity: blocker.** Dimension E.

**Fact (plan).** In `docs/HORIZON-5-THE-CLAIM.md` these terms occur **zero**
times: *minor, child, COPPA, parental, 18, privacy, GDPR, CCPA, consent,
disclosure, insider, bond, withholding, loot*. The only occurrence of "age" is
line 101 — *"a baseline is a measurement with an age on it"*, in the testing
section.

**Fact (repo).** No age gate exists. `DEFAULT_SETTINGS` (`game_state.gd:42-64`)
is exactly `music_vol, sfx_vol, shake, ui_scale, haptics, reduce_motion,
telemetry, colorblind, bindings`. Nothing age-, birthdate- or consent-related
anywhere in `scripts/`.

**Fact (structure).** §0 chooses browser-first explicitly to avoid store review —
so there is no platform age gate either. §8 parks app stores. §2's accounts are
*"email or OAuth; no KYC yet."* §4 sells currency to anyone with a card. §5 pays
cash and lists *"eligibility"* as a rules element without stating an age floor.

**The asymmetry is the finding.** The plan is meticulous about money-**out** —
KYC at payout, geo-gating, 1099 — and has **no chokepoint whatever on
money-in**. Four surfaces, each needing counsel scoping: a prize-eligibility
floor; COPPA/GDPR-K **at account creation, which is Stage 0 — three stages
before I-8 fires**; age-appropriate-design regimes that attach to services likely
to be accessed by children regardless of whether money exists; and parental
chargebacks on Stage 2 purchases.

**Recommendation.** Add a minors bullet to §10 and an eligibility floor to §5.
Structurally more important: **age assurance is a Stage 0 account-model
decision** and cannot be retrofitted without re-consenting an existing user base.
This is the strongest single argument for **E-4**.

---

### E-4 — I-8 fires at Stage 3, and §13's own first open question proves Stage 0 is already constrained by it. `[fact + inference]`

**Severity: blocker.** Dimension E.

I-8: *"No stage that moves real money ships without a review… One review per
structure, not per event."* §5 calls Stage 3 *"the first real money."*

**§13's first open question is:** *"Account identity for a browser game: how
little can Stage 0 ask for and still support KYC-at-payout later **without a
migration**?"* **The document identifies that Stage 0's identity design is
constrained by a Stage 3 compliance requirement, and then places the review at
Stage 3.** That is gating on the wrong side of a dependency the author already
found.

Frozen in Stages 0–2, expensive or impossible to change once players exist:

| fixed at | what Stage 3 depends on |
|---|---|
| Stage 0 (§2) | identity fields, **age assurance** (**E-3**), country determination, name-matching for later KYC |
| Stage 0 (§2) | privacy notice, lawful basis, retention, deletion tooling, and the **permanence-vs-erasure** decision |
| Stage 1 (§3) | the near-miss behavioural log later used to **deny payouts** |
| Stage 2 (§4) | wallet/ledger shape, transferability, expiry, merchant category, refund posture |

**Three further defects in I-8 as drafted.** *(a)* **"Moves real money" has three
different answers in this document** — §4 takes cards, §5 calls Stage 3 the
first real money, §7 places processor scrutiny at Stage 5. A maintainer cannot
tell which stage trips it. *(b)* **"One review per structure, not per event" has
no re-trigger list**, so it currently tells a maintainer that *scaling the prize*
needs no new review — and §6 does exactly that (**E-10**). *(c)* Minor
circularity: I-8 geo-gates *"to jurisdictions where the structure is clean"*, but
the review that determines which those are is the one being gated.

**Recommendation.** Move a **scoping** consultation to **before Stage 0** — one
conversation: what must the account model capture now; what is the age floor; is
the derby a contest or a sweepstakes (**E-10**); does the free-entry structure
work as described. §5's own budget is $400–500 *per derby*; a scoping call is the
same order and can invalidate three stages. Then convert I-8 from a stage gate
into a **change-trigger list**: prize magnitude, jurisdiction set, entry
mechanism (free→paid), any transferability or redeemability, any new purchasable
touching a prize event, and an annual re-check.

---

### A-1 — Stage 0's gate metric cannot be computed until §13's open question is closed, and one of the candidate answers makes it permanently zero. `[fact]`

**Severity: blocker.** Dimension A (design), with C consequences.

**The contradiction is internal to the plan.** §2 defines Stage 0's gate as:

> claim-engagement (% of players who file ≥1 claim; **% who return within 48h of
> being *beaten* to a claim — the rivalry signal**).

§13 then lists as an open question:

> Where does the claims server draw the "charted" boundary — per system, per
> band, per structure?

**The gate metric is a function of the undecided variable.** "% beaten to a
claim" has no value until you know what a claim *is*, and the candidate answers
differ by four orders of magnitude. Measured against the actual generator:

| granularity | claims that exist, globally, forever | source |
|---|---|---|
| **per system** | **3** | `SystemDB` has pyx01/02/03; `is_system_charted` is a per-system boolean (`game_state.gd:849`) |
| **per band** | **15** | `BAND_EDGES` = 5 deep bands × 3 systems (`deep_space.gd:33`) |
| **per landmark** | **≤ 3,955** | one landmark per supercell; `SUPERCELL := 4` cells of `CELL := 64.0` (`deep_space.gd:1261`, `:53`) |
| **per cell** | **63,276** | π·(bounds+5200)² / 64² summed over three systems |

*(3,955 is an upper bound: `landmark_at` returns `{}` for band 0
(`deep_space.gd:1305`) and for cells inside `CONTENT_MIN_DEPTH := 24.0`
(`:1314`, `:60`), so the innermost supercells carry nothing. The order of
magnitude is what matters here — thousands, not millions.)*

**§2's own worked example is the per-system case.** It specifies the API as
*"has anyone charted `<system>`?"* and renders *"First charted by KESTREL-9,
2026-11-02."* At that granularity **the entire game contains three first-charts,
they are taken on day one, and the rivalry signal reads zero for every player
who arrives afterwards — permanently.** The gate cannot fail informatively; it
can only read zero, which the plan would have to interpret as "shared stakes
don't work" when it actually means "there was nothing left to race for."

That is this repo's signature defect, in a design document: *a green check on a
world where the defect cannot express itself* (§54:4767). The plan cites that
exact lesson in I-7 and §12 and then builds a gate that has it.

**Per-cell is the opposite failure.** 63,276 sites across three systems means two
players essentially never collide, so "% beaten to a claim" is ~0 for a different
reason and equally uninformative.

**Recommendation — decide it now, and the answer is per-landmark.** It is the
only granularity that produces a measurable rivalry signal, and it is the cheapest
to build:

- Landmark positions are a pure function of `(system_id, supercell)` —
  `landmark_cell(id, sx, sz)` at `deep_space.gd:1295-1301` — so **client and
  server agree with no synchronisation, no replication, and no shared code**.
  A claim key is `(system_id, sx, sz)`: three integers.
- Landmarks are the only deep-space object with authored identity —
  `LANDMARK_KINDS` = pylon, frame, monolith, marker, gate, cairn
  (`deep_space.gd:1265`) — and the fiction already supports naming them
  (§68:6533: *"a cairn — hull plate stacked by hand, made of ship, so whoever
  stacked it was not leaving in that ship"*). A cairn somebody named is a better
  artifact than a system somebody named.
- It requires **no** identity layer to be invented. Note what `landmark_at`
  returns today — `{kind, pos, rot_y, band}`, no id (`deep_space.gd:1329-1334`) —
  but the *position* is deterministic, so the supercell coordinate is the id.

Move this out of §13 and into §2 before Stage 0 is built.

---

### A-2 — The claimable frontier is finite, small, and exhausted in roughly 30–50 player-hours — and the plan makes claims permanent. `[fact + inference]`

**Severity: blocker.** Dimension A, with B consequences.

Taking the recommended per-landmark granularity — the *most* generous tractable
answer — the total resource is **3,955 sites** across all three systems, forever.

Sustained cruise on the starter hull is `max_speed` **5.75 u/s**
(`module_db.gd:99`; the 1.9× at `player_ship.gd:871` is the *surge ability*, not
cruise, so it is not sustainable). Landmark sites sit one per supercell, 256u
apart (`deep_space.gd:1261` × `:53`).

| assumption | sites/hour | player-hours to claim **all 3,955** |
|---|---|---|
| 5.75 u/s sustained, optimal routing | 81 | **≈ 49** |
| 10.9 u/s (surge sustained — not achievable) | 154 | ≈ 26 |

Call it **30–50 player-hours for the entire frontier**, and that is transit time
with no combat, no storms, no docking. Distributed across a playerbase:

| players | wall-clock to exhaust every claim in the game |
|---|---|
| 10 | ~3–5 hours each |
| 50 | ~35–60 minutes each |
| 200 | ~10–15 minutes each |

**The plan makes this permanent.** §2: *"Permanent."* and *"Seasons reset; etched
names do not."* So Stage 0 ships a **strictly finite, non-renewing, rapidly
exhausted** resource as the foundation of a retention system whose every other
layer (leaderboards, seasons, derbies) is explicitly designed to reset and
renew.

**What this does to the thesis.** The plan's one-sentence thesis is *"scarcity of
discovery is the retention engine."* Correct — and scarcity has two failure
modes, not one. The plan guards against the resource being too *common* (I-6:
"a capsule found daily is a wage"). It does not guard against the resource being
**used up**. Month one, first-charting is the best feature in the game. Month
four, every landmark within reasonable range carries a name from month one, and
a new player's entire experience of the headline feature is reading other
people's names. The rivalry the plan wants — *"another pilot might file the
return first"* — requires unclaimed frontier to exist, and the plan never asks
how much there is.

**This is not the deep frontier being big.** The world reaches 5,240u and feels
limitless in play. The *claimable* set is 3,955 items, and that is a different
quantity, which is exactly why it needed measuring rather than assuming.

**Recommendation — pick one, in the plan, before Stage 0:**

1. **Seasonal claims** (my recommendation): first-charts reset with the season,
   the hall-of-fame record does not. This aligns the claim layer with every
   other layer's renewal, keeps late arrivals in the game, and costs nothing —
   §2 already ships seasons. Permanence moves to the *record* ("KESTREL-9 held
   47 first-charts in Season 3"), which is a better trophy than an annotation
   nobody revisits.
2. **Expand the claimable set** to per-cell (63,276) and accept a weaker
   rivalry signal.
3. **Keep permanence and state the intended lifetime.** If "the frontier fills
   up in year one and that's the story," say so — but then the retention thesis
   has a stated expiry date and Stage 0's gate should measure against it.

Whichever is chosen, **state the exhaustion arithmetic in the plan.** The
brief's own example of a good finding is a density calculation; this is that
calculation, and the plan owes its own.

---

### C-1 — I-2 and §3 contradict each other. Server-placed capsules cannot use hint builders that derive from client-side truth. `[fact]`

**Severity: major.** Dimension C.

**I-2 is right, and §3 was written as if it isn't.**

I-2 (line 57-63): *"capsules, derby objectives, and anything with a prize
attached are **server-placed and server-verified** … The seed generates the
stage; the server hides the props."*

§3 (line 158-161): *"**Reuse the Hunt dossier machinery** — the estimator, the
search circle that narrows and never lies, purchasable readings — pointed at
capsules."*

**These cannot both hold**, because the dossier's correctness argument depends
on the client knowing the answer. `Hunt.bearing_hint` (`scripts/hunt.gd:242-269`):

```gdscript
var truth := SystemDB.lair_pos(system_id, run_seed)
var true_deg := fposmod(rad_to_deg(atan2(to_truth.z, to_truth.x)), 360.0)
rng.seed = hash("%s|hint|%s|%d|%d|%d" % [system_id, kind, run_seed, ...])
var offset := rng.randf_range(-err_deg, err_deg)
```

It takes ground truth and adds a *deterministic* error — deliberately, so a
player cannot save-scum a tighter cone (`hunt.gd:248-253`). Under server
authority there is nothing to re-roll and nothing client-side to derive from.

**What survives, precisely.** ~110 of ~800 lines: `Hunt._scan` and
`Hunt._satisfies` (`hunt.gd:75-170`, `:226-239`) take an opaque hint array plus a
polar window and return a centroid, radius and agreement count, reading only
hint fields — no globals, no `SystemDB`. Genuinely reusable. So is the chart cone
renderer (`chart_panel.gd:252-293`) and the widest-first eviction *policy*
(`game_state.gd:1983-2002`).

**What does not, and why each is structural:**

| piece | obstacle |
|---|---|
| `bearing_hint` / `ring_hint` (`hunt.gd:242-282`) | take `run_seed`, derive truth internally |
| `Hunt.estimate` (`hunt.gd:173-223`) | its search domain **is** the lair's authored annulus (`hunt.gd:184-197`: *"The hints choose WHERE in the annulus; they never get to choose the annulus"*). A server-placed capsule has no annulus, so the polar grid has no domain |
| storage (`game_state.gd:276`) | `{system → [hints]}`; N targets needs `{system → {target → [hints]}}` — six accessors and a save migration |
| **expiry** | **does not exist.** No timestamp on a hint, no sweep, no clock. A dossier entry ends exactly one way: the boss dies (`game_state.gd:1029`, `:1048`, `:1960`). §3's *"Rumors decay"* is a from-scratch subsystem |
| load validation (`game_state.gd:1329-1332`) | deliberately refuses to cross-check hints against truth — *"Contradiction is a legal state of a dossier."* Server authority needs the inverse |
| `file_apex_intel` (`main.gd:3680`) | no target parameter; hard-coded to the current system's engine |
| ~19 `HUNTTEST` assertions (`main.gd:18855`–`19372`) | all anchored on `main.gd:18845`'s client-computed `truth` |

**One correction the plan can safely keep.** §3 says the `INTEL NARROWS AND NEVER
LIES` discipline *"carries over as a server contract: intel may be vague, never
false."* **That part is right and is the best sentence in §3** — it is a
statement about the server's obligation, not about reused code, and it survives
the inversion intact.

**Recommendation.** Rewrite §3 to claim what is true: *the estimator and the
chart rendering are reusable; the hint builders, the storage shape, the search
domain and expiry are new work.* Re-cost accordingly — calibrated against §42
(the original dossier: 14 assertions, one save bump, one stage), this is
**larger than the original**, because it adds authority and expiry, which the
original did not have.

---

### C-2 — Private regions: "its own seed" is the wrong knob. A new seed changes almost nothing. `[fact]`

**Severity: major.** Dimension C. This one is verified and constructive.

§4, sink 1 — the **flagship** sink: *"Spend currency to spin up an invite-only
region with **its own seed**, its own capsule seeding …, configurable rarity, and
a private leaderboard."*

**Measured: `run_seed` does not generate the world.** `DeepSpace.plan_cell(cx, cz)`
(`deep_space.gd:826`) takes **no seed**. Its ten salted streams are all
`hash("%s|%d|%d|<tag>")` where `%s` is `_id` — the **system id**, set in
`_load_system` (`deep_space.gd:480`, `:639`):

```
:852  hash("%s|%d|%d"          :1214 hash("%s|%d|%d|seam"
:942  hash("%s|%d|%d|guard"    :1299 hash("%s|%d|%d|landmark"
:1030 hash("%s|%d|%d|convoy"   :1311 hash("%s|%d|%d|landmark_at"
:1078 hash("%s|%d|%d|hulk2"    :1326 hash("%s|%d|%d|landmark_kind"
:1721 hash("%s|%d|%d|pack"     :1798 hash("%s|%d|%d|convoyspring"
```

`grep -c run_seed scripts/deep_space.gd` → **2**, both the lair. Only
`SystemDB.lair_pos` and `hyper_positions` (`system_db.gd:706`, `:773`) consume
`run_seed`.

**So a private region "with its own seed" is the same rocks, the same hulks, the
same seams, the same landmarks, the same stations, the same convoy springs as
the public world — with the apex boss and the hyper-structures moved.** The
flagship sink, the "casual player's winnable pond" and the "friend-group party
mode", as specced produces a world indistinguishable from the one everyone
already flies.

**The fix is cheaper than the thing that doesn't work.** Give a private region
its own **system id**, not its own seed. Every one of the ten streams keys off
`_id`, so a synthetic id (`"priv:<uuid>"`) yields a completely fresh world **for
free** — no generator change, no new parameter threaded through, and critically
**no disturbance to `WORLD FINGERPRINT`**, which exists precisely to prove that
nothing moves a rock (`main.gd:15536-15546`).

The one real cost: `SystemDB.get_system(id)` must return a definition — bounds,
`apex.lair.depth`, the `deep` block, `station_weights`, `landmark_weights`. So a
private region needs a *synthesised SystemDB row*, which is a small, bounded,
data-shaped task. That is a completely different piece of work from "its own
seed," and it is the one worth specifying.

**Do not instead make the world generator take `run_seed`.** That would move
every rock, hulk, nest and station in the game — the exact defect
`_world_fingerprint()` was written to catch, and the reason the guard and
landmark rolls take their own salted streams (`main.gd:15536-15541`).

---

### C-3 — §12's derby mirroring assertion measures the one thing that cannot vary, and cannot see the one thing that can. `[fact]`

**Severity: major.** Dimension C. The plan violates its own I-7 here.

§12: *"`PYXIS_DERBYTEST`: … **mirrored instances are bit-identical across
entrants (WORLD FINGERPRINT, repointed)**."*

`_world_fingerprint()` (`main.gd:15536-15563`) hashes `deep_space.plan_cell(cx,cz)`
over cells (−5..5, −5..5) — rocks, hulk, pack, station. Per **C-2**, `plan_cell`
depends only on `(system_id, cx, cz)`. **It does not depend on the player, the
account, the save, or the seed.**

Therefore *"mirrored instances are bit-identical across entrants"* is **true by
construction, for every pair of players, in the shipped game today, with no derby
code written.** Repointing the fingerprint asserts a tautology.

**And it cannot see the thing that matters.** The derby capsule is server-placed
(I-2) and therefore, by definition, outside `plan_cell` and outside the
fingerprint. The single quantity that could differ between two entrants —
*where the server hid the objective* — is the one this assertion structurally
cannot observe.

I-7 promises: *"a green check on a world where the defect cannot express itself
is worth nothing."* §12 then specifies one. This is the fourth-plus instance of
the pattern in this repo's record (§41's vacuous `RETURN`, §54's `AMBIENT COMBAT
DEPLETES NOTHING`, §67's `board_clean = board_clean`, §71's *"Fourth vacuity this
horizon"*), and the first to appear in a document that cites the lesson.

**Recommendation.** Assert the server's instance description, not the client's
terrain: **two entrants' derby manifests hash identically, and the objective
coordinate is byte-equal across entrant records**, checked against a recorded
fixture rather than a live server. Keep `WORLD FINGERPRINT` where it is, doing
the job it already does.

---

### B-1 — The plan never mentions the pacing band. §13 makes the right call for the wrong reason and puts no number on it. `[fact + inference]`

**Severity: major.** Dimension B.

**Searched the whole plan for `MIDTIER`, `PACING_LOOP`, `PACING`, `ceiling`,
§41, §51: no substantive match.** The one hit is §13's *"a pacing decision as
much as a technical one"*, about claim density.

**First, the good news, and it is real: the currency design is safe for
`MIDTIER`.** Capsules pay *closed-loop currency* (§3), not salvage credits.
`MIDTIER` is income-only — README:219, *"a sink cannot touch it"* — so a premium
faucet cannot move it. **The blocker an earlier pass of this review recorded on
these grounds is retracted** (§7). I-3's closed loop, which exists for legal
reasons, has an economic dividend the plan never claims: it firewalls the entire
horizon from the binding economy assertion.

**Now the problem.** §13:

> What does the rumor economy price intel in — salvage credits (binds it to the
> existing economy) or premium currency (stronger sink, but flirts with
> paying-for-chance; see §10)? **Leaning salvage credits, hard.**

The lean is correct — and the *only* reason offered is §10's paying-for-chance
concern. The pacing consequence is not considered, and it is the larger one:

- The bar is `PACING_MAX_MODULES := 3.00` (`main.gd:168`) against `lance_1` at
  **5,800 cr** (`module_db.gd:152`) over an 8-minute loop (`main.gd:154`).
- STRATEGY §51:4484-4486, under *"Write the spread down, because the ceiling is
  close"*: *"`MIDTIER` is 2.91 ± 0.05 against a hard 3.00, so a good roll reads
  2.95 and **real headroom is about 0.04. Anyone adding income needs four
  samples, not one.**"*
- 0.04 modules × 5,800 = **≈ 232 credits per 8-minute loop**.

Pricing intel in salvage credits does not *break* that bar — a sink cannot. But
it makes the rumor economy a **direct competitor with the module ladder for the
same currency**, and the ladder it competes with is the newest content in the
game: the Mk III line is the entire payload of frontier stage 2 (§69), ten
modules topping out at **90,000 cr** — about **43 minutes of optimal play per
module** at the measured earn rate.

**The plan owes a number.** "Ports sell stale whispers cheap and fresh ones
dear" (§3) is a design sentence, not a price. If a fresh reading costs 2,000 cr
and the loop earns ~16,900, the rumor layer taxes ~12% of progression; at
8,000 cr it taxes half. Those are different games and the plan does not say
which one it is.

**Recommendation.**
1. State intel prices in credits, and state the resulting % of an 8-minute
   loop's earnings, in the plan.
2. Cite §51:4484 and take **four samples, not one**, when Stage 1 lands.
3. Do the §41 `MIDTIER` re-derivation — owed since §65, *"now due"* per §64,
   re-stated in §72:7201 — **before** Stage 1, not because Horizon 5 breaks the
   bar but because a bar that can read 3.00 on unchanged code under load
   (README:213-218) cannot tell you whether Stage 1 broke anything.
4. Add the closed-loop firewall to the plan as a stated *economic* property, not
   only a legal one. It is a strength and I-3 currently under-sells itself.

---

### B-2 — Private regions with purchaser-configurable rarity are an undeclared faucet, and the plan never says what they pay in. `[inference]`

**Severity: major.** Dimension B/D.

§4, sink 1: private regions have *"its own capsule seeding (in-game currency
prizes only …), **configurable rarity**"*.

The parenthetical closes the legal hole (no real prizes in a paid region — good,
and explicitly recorded so it is never "discovered" as a feature). It does not
close the **economic** one:

1. **Rarity is a purchaser-set dial on a currency faucet.** §3 says placement
   density is *"a server dial, not a client constant"* — correct, and centrally
   controlled. §4 then hands a version of that dial to whoever paid. Buy a
   region, set rarity high, farm closed-loop currency. §9's *"accepted residual
   risk: closed-loop currency botting in the open world"* reasons about the
   **open world**; a purchased private region with a rarity slider is a
   different object and is not covered.
2. **The plan never says whether a private region's ordinary deep-space content
   pays salvage credits.** It is a PYX region, so presumably it streams hulks,
   packs and seams — all of which pay. If so, a purchased private region is a
   **real-money-purchasable salvage faucet**, which lands squarely on `MIDTIER`
   (**B-1**) and, worse, makes progression speed purchasable — which I-5's
   spirit and §4's own *"What currency never buys: … progression power"*
   forbid.
3. **The price is doing two jobs** (the brief's question, and it is a good one).
   As a *sink* it wants to be expensive enough to absorb the wallet. As a *party
   mode* it wants to be cheap enough that a group of five actually buys one.
   Those pull opposite ways, and the plan sets no price. Recommendation: split
   them — a cheap, short-lived, **rarity-locked** party region, and an expensive
   persistent one. Only the second is a sink; only the first is a party.

**Recommendation.** State explicitly: private regions seed **closed-loop currency
only, at server-fixed rarity**, and grant **no salvage income** — or if they do,
price and cap it and re-measure `MIDTIER` against it.

---

### F-1 — Browser-first is a plan decision, not an existing capability, and it is uncosted. `[fact]`

**Severity: major.** Dimension F/C.

§0: *"Platform: **browser first**, then mobile wrappers."* The reasons given are
good ones — no 30% store cut, no review gauntlet while the economy's shape is
unproven, instant iteration.

**The repo disagrees in every place it says anything**, and this is a real gap
rather than a documentation quibble:

- STRATEGY §1:10 — *"An original **single-player mobile-portrait** space game"*
- STRATEGY §2:24 — Platform: *"Mobile portrait (720×1280 base)"*
- README:3-5 — *"A single-player **mobile** game … for portrait phones"*
- `project.godot:107` — `renderer/rendering_method="mobile"`; `:25` —
  `window/handheld/orientation=1`
- **`export_presets.cfg` does not exist.** No web preset, no Android, no iOS.
  **The project has never been exported to anything.**

Every dimension-D argument in the brief and in §9 rests on "the client is a
browser game" — a correct threat model *for a web build that does not yet
exist*. Specific unknowns for this project: Godot 4 web export needs
cross-origin-isolation headers; the audio system is generated WAVs through an
import cache whose web behaviour is untested (README:99-104); and
`STREAMTEST`'s `worst` clause already fails at 40ms on desktop
(README:224-231) with no browser measurement at all.

**Recommendation.** A web export and one played session on a mid-range phone
browser is **Stage 0's real prerequisite** — one day of work, and the cheapest
possible way to discover that the platform premise needs revisiting. See the
gate table in §4.

---

### F-2 — The plan confronts one founding exclusion by name and silently crosses two others; and its five gates have no rollbacks. `[fact + opinion]`

**Severity: major.** Dimension F.

**Credit first, because it is deserved.** §0 states *"It is explicitly **not**: An
MMO"* and §8 parks the MMO permanently with a reason. That directly and honestly
engages STRATEGY §5:72's first exclusion. Most plans of this kind would not.

**But §5:72 lists five things**, and the plan addresses one:

> Real-time MMO backend; **alliance/social systems**; **timer or energy
> monetization**; officer/crew collection; a three-tier map hierarchy

- **"alliance/social systems"** — Stage 0's claims, leaderboards and seasons are
  a social system. Not alliances, and defensibly outside the letter; unmentioned.
- **"timer or energy monetization"** — I-6's daily loop is carried by *"intel
  decay"* and §3's *"Rumors decay"*. Decay is a clock. §5's base-building
  amendment (§5:89-94), the most recent statement of this boundary, is explicit:
  *"no clocks, no queues … and **nothing that rewards logging in rather than
  flying**."* Unmentioned.
- **§2:25's rationale** — *"MMO/live-ops scope is a 50-person operation. **Ours
  is not.**"* The plan takes on live-ops without engaging the sentence that
  says why the project declined to. Unmentioned.

**A related fact worth knowing: the game has no wall clock.**
`grep -rn "get_unix_time\|get_date_dict\|get_time_dict" scripts/` returns
**zero**. Every time reference is `Time.get_ticks_msec()` — monotonic since
process start. Pyxis has never asked what day it is. Once a server exists, server
time supplies this and the classic device-clock exploit is closed *by
architecture* — so the plan is fine on the security half without saying so. The
design-boundary half is untouched.

**On the gates — opinion, labelled.** §5's base-building amendment is the model
for how this project does a reversal: state what is lifted, record the owner's
reason as given, and write down **the boundary that survives**, in the same edit.
The plan should do that for §5:72 and §2:25 rather than route around them.

**And the gates need rollbacks, not just holds.** Every gate in the plan reads
"proceed to stage N+1 if…". None says what is *withdrawn* if the answer is no.
Stage 1 opens a currency faucet before Stage 2 builds sinks (deliberately, and
the reasoning — tune while the currency is worthless — is good). But if Stage 2
never ships, Stage 1 does not un-ship. **The gate that matters is not "should we
build Stage 2" but "should Stage 1 still exist."** Anything that has taken money
cannot be rolled back, which makes **Stage 2 the true point of no return** — one
stage earlier than the plan's own framing (Stage 3, first real money) implies.

---

### A-3 — The plan leans on "nobody is watching", which was never written down as a pillar. `[fact + opinion]`

**Severity: minor**, but it is the cheapest fix in this document.

§0 opens: *"Deep space is already the game's best idea: it gets harder,
stranger, and better-paying the further out you fly, **and nobody is watching**."*

That is correct, it is the right thing to build on — and **it is not a stated
pillar of this project.** The word "solitude" appears exactly once in
`STRATEGY.md`'s 7,261 lines, at §49:4341, where it means elbow room for a ship
AI. The six experience pillars (§3:34-47) are living star chart, reward
spectacle, quiet HUD, frictionless command, scale contrast, cohesion. None is
about aloneness.

What exists is the *mechanic*, stated twice and never promoted:

- §17:623-625 — *"there is no range at which a full hold is safe, only ranges at
  which it is unlikely to be noticed. **This is the trade the expanse rests
  on.**"*
- §18:794-795 — *"raiders thin out with distance because **nobody is watching**"*

**Why it matters here specifically.** Isolation is the *economic* structure of
the game — a term in the payout gradient — and §7:216-217 names *"the pillar
list"* as **"the contract for saying no."** Solitude is not on the pillar list.
So the property Horizon 5 both builds on and puts most at risk is the one
load-bearing design value with no written defence. Horizon 5 does not endanger it
carelessly — asynchronous rivalry with *"their ships never appear on your
screen"* (§0) is about as gentle a version as exists, and I endorse it — but the
argument cannot be *had* while one side is unwritten.

**Recommendation.** Add the seventh pillar to §3, in §17:624's own language,
before Stage 0. One paragraph. Then every subsequent element of this horizon —
notifications, leaderboards, derby spectacle — has something to be measured
against.

---

### D-4 — §9 item 3's "human-behaviour baseline" has almost no entropy, and the instrument it cites is the wrong shape and forbidden to be read. `[fact + inference]`

**Severity: major.** Dimension D. This answers the brief's question directly:
**yes, a bot that simply flies plausibly defeats it — because the game flies the
ship.**

**The autopilot generates the trajectory, deterministically.** `command_move(pos)`
sets a goal (`player_ship.gd:721`); `_physics_process` integrates it via
`Obstacles.steer` + `velocity.move_toward(desired, accel*delta)`
(`player_ship.gd:874-912`). **Given the same tap, a bot and a human produce a
bit-identical trajectory.** There is nothing in the path to classify. STRATEGY
§3:42 is literal: *"tap to designate; the ship handles the rest."*

**And the server never sees taps.** It sees claims and reveal queries — a feature
vector of `(position, timestamp)` at query granularity, which is exactly what an
attacker synthesises, because **the bot's positions are genuine**. The attacker
gets unlimited labelled training data by playing legitimately. This is a
classifier the defender must win every time and the attacker must beat once.

**The cited instrument does not exist and cannot be repointed.**
`scripts/telemetry.gd` is one JSON row **per session** (`:19-23`), local-only and
opt-in, and its header states *"there is no network code here and there will not
be"* and *"**NOTHING IN THE GAME MAY READ IT**"* (`:13-17`). §3's near-miss
telemetry is a *server query log* — it records where searches happened, not how
the ship got there. There is nothing to repoint and the plan does not budget
building it.

**What item 3 actually buys, and it is worth keeping:** a hard upper bound on
claim rate, `distance / max_speed`. Genuine and cheap. But it is **a schedule,
not an identity** — it limits humans and bots identically, and the bot runs 24/7
while the human runs 90 minutes. §2's own example ("4,000 u out five minutes
after account creation") is a 7–12 minute flight at real speeds, so the
envelope's whole yield against a patient attacker is seven minutes per claim.

**Recommendation.** Rename item 3 to what it is — **an anti-teleport check** —
and delete the human-behaviour-baseline parenthetical until an instrument exists.
§12's own rule applies verbatim: *"anything that matters gets promoted to an
assertion somewhere, or it will be printed and ignored for four stages."*

---

### D-5 — Interactive cracking is a timer. §12 asserts the one property a `sleep()` satisfies for free. `[fact]`

**Severity: major.** Dimension D. The brief asks whether it is bot-resistant or
bot-annoying; measured, it is **neither — it is a 1:1 tax**.

**The existing precedent is a timer.** `Derelict.hold_begin()` → `hold_tick(delta)`
accumulating until `_progress >= 1.0` (`derelict.gd:299-352`), with
`crack_time = 1.8 + 0.2 * band` (`deep_space.gd:910`) → **1.8 to 3.0 seconds**.
Leaving range auto-issues a fresh approach and resumes (`derelict.gd:323-326`);
`_approach()` even parks the ship for you (`derelict.gd:294`).

**The bot:** `on_tapped()` → wait for range → `hold_begin()` → `sleep(3.1)` →
done. Zero decisions, zero variance, and the game auto-navigates *and* auto-fights
around it.

**§12 certifies the wrong property.** It asserts the crack *"cannot complete in
fewer than its designed human-paced steps"* — a **lower bound on elapsed time**,
which is precisely what a `sleep()` satisfies. A green check there is worth
nothing against a bot, which is the failure mode I-7 names. It costs the attacker
3 seconds per capsule and an honest player 3 seconds per capsule: **a 1:1 tax is
the definition of a non-defence.**

**For an interactive sequence to be bot-resistant it needs** server-chosen
per-attempt variance the client cannot precompute; a **cost of failure**, because
a free-retry challenge is brute-forced regardless of difficulty; and
response-latency measurement, which lands back in **D-4**'s entropy problem. §9
item 4 and §12 specify none of the three.

**An I-5 tension worth pinning separately:** the crack rate is
`1 + GameState.stats["breach_speed"]` (`derelict.gd:332`) — **a fitted module
stat** (`module_db.gd:476`, Breaching Torch, `+50%`). In a *"fastest verified
crack wins"* derby that single stat is a direct prize-odds multiplier. §12's
general "pin the spec fit to named constants" is good, but the derby's winning
condition is now one stat away from an I-5 violation and deserves its own named
assertion.

---

### D-6 — KYC defends the payout, not the odds — and the mirroring that makes the derby legally clean is what makes 50 entries maximally valuable. `[inference]`

**Severity: major.** Dimension D, answering the brief's KYC question.

§9 item 6: *"Fifty accounts can search; one identity gets paid."* **The reasoning
is correct and insufficient.** It defends the *cash line*, not the *competition*,
because the attacker needs only **one** winning account — and that account KYCs
cleanly.

**What 50 accounts actually buy.** I-5 mandates a mirrored layout, and §13 leans
toward a 24-hour window with fastest-completion scoring. So 50 entries = **50
independent attempts at the same course, of which you submit the best.** The
attacker's score is the maximum order statistic of 50 samples; an honest player's
is a single sample. Against a field of ~200 honest single-entry players that is
close to decisive — **and it is worse under mirroring than under randomised
layouts, because 50 runs at the same course also let the attacker learn the
course. The property that makes the event legally clean is the property that
makes multi-accounting maximally profitable.**

**Cost asymmetry ≈ zero.** Attacker: 50 free emails, ~$5 of proxy, one real
identity they already have. Legitimate winner: one KYC step. **KYC taxes winners
and does not bar attackers.**

**What is missing is an entry-time uniqueness signal** — and I-5's equal-dignity
free-entry requirement constrains what may be demanded at entry, so this is
**counsel's call under I-8**, not a design fix. Flagging, not solving.

**And the 48-hour provisional window has no written standard.** §5's rules list is
*"eligibility, geo-gating, prize schedule, verification, tax handling"* —
**no disqualification clause, no appeal, no evidentiary standard, no runner-up
policy.** The first contested result is then a public dispute between an
anonymous accused and a solo operator with no policy, which is the reputational
failure mode that kills small prize programs well before fraud losses do.

**Ops arithmetic, while we are here:** §13's 24-hour window plus §9's 48-hour
review is a **72-hour operator clock per event**, against §6's assumption that
*"a monthly event with a dozen winners is an hour of admin."*

---

### D-7 — All three Stage 0 leaderboard axes are monotone in machine-hours, which poisons the dataset that gates the whole horizon. `[fact + inference]`

**Severity: major.** Dimension D, compounding **A-4**.

§2's axes: *"deepest verified sounding, most first-charts, most distinct bands
visited."*

**There is no endurance constraint in the game.** `cell_fuel` exists as a
tradeable commodity (`commodity_db.gd:173`) but **there is no fuel consumption,
no tank and no refuelling gate anywhere**; `band_of` returns the top band for
anything past 5,200 (`deep_space.gd:564-570`), so there is no hard outer edge;
and death is a 1.4 s teleport to spawn. Therefore *deepest sounding* ≈
`hours_flown × max_speed` — an endurance race won by whoever leaves a process
running longest. *Most distinct bands* saturates at 6 for any account that flies
outward for an hour, so it ranks nobody. *Most first-charts* is **D-1**'s sweep.
**Not one of the three measures a decision.**

**The compounding harm is the real finding.** The Stage 0 leaderboard exists to
produce the retention dataset that gates Stage 1 and thereby the horizon.
**A botted leaderboard does not merely award the wrong names — it inflates
D1/D7/D30 and claim-engagement for exactly the accounts that are not people.**
§2's rivalry signal, *"% who return within 48h of being beaten to a claim"*, is
the metric most easily manufactured, and the one most likely to be manufactured
*accidentally* by a farm that keeps beating everyone.

§12 explicitly declines to guard this — *"the sweep's PASS/FAIL never depends on
live-service data"* — which is correct for the sweep and means **no assertion
anywhere protects the numbers the go/no-go decision reads.**

**Recommendation.** Add at least one non-volume axis (see **A-4**), and treat the
Stage 0 dataset as requiring bot-filtering *before* it is read as evidence — which
is another argument for **D-1**'s season-scoping.

---

### D-8 — Free entry plus per-entrant instances is an unauthenticated compute faucet, and §9 has zero availability items. `[inference]`

**Severity: major.** Dimension D.

I-5 mandates free entry for everyone and a mirrored instance per entrant. §6
automates *"instance provisioning."* §5's total prize exposure is $400–500 per
event.

**Attack:** register 5,000 free accounts, enter all of them, play none. Each
provisions an instance. Cost to the attacker: one email each. Cost to the
operator: per-instance compute — so **the infrastructure bill can exceed the
prize bill by an order of magnitude**, charged to a solo dev's card. §6's "an
hour of admin" assumes entrants ≈ winners × a small constant; a griefing entrant
costs exactly what a real one costs.

**§9's seven items are all integrity items. There is no availability item at all**
— no per-account instance quota, no cost ceiling, no circuit breaker. The plan's
closing note defers *"stack, hosting, cost ceiling"* to a companion document, so
the ceiling is acknowledged as an artifact and simply absent from the threat
model.

**One place the plan is genuinely strong and does not claim it:** I-1 is a real
availability control. An offline-capable client means a registry outage degrades
to today's complete game, and §12 asserts it. **Say that in §9** — it is free DoS
resilience the plan earned. **The exception is claims:** first-write-wins and
permanent, so an outage — or one timed to a season opening — **permanently
mis-assigns names**, with no retraction path (**D-1**).

---

### D-9 — The plaintext save is the trust boundary, and §13's "salvage credits, hard" makes the D-3 oracle free. `[fact + inference]`

**Severity: major.** Dimension D. **This is the cheapest finding in the review to
act on.**

No signature, no HMAC: `JSON.stringify` out (`game_state.gd:2507`),
`JSON.parse_string` in (`:2521`), and the loaders coerce and accept —
`salvage = int(data.get("salvage", 0))`,
`played_seconds = float(data.get("played_seconds", 0.0))`.

**§9 never states which client-reported values the server may accept.** Three
matter:

1. **`played_seconds`** — the colony-jump cooldown clock (`main.gd:1570-1571`),
   the gate on the one player-chosen-destination teleport (**D-2**). Editable.
2. **`salvage`** — **and this collides head-on with §13.** §13 leans *"salvage
   credits, hard"* for intel pricing. **Salvage is minted by editing one integer
   in a JSON file. If intel is priced in salvage, the D-3 oracle becomes free**,
   and every price-based scarcity control in §3 evaporates. §13 does not mention
   this; §9 does not mention this. **The pricing decision in §13 is a security
   decision, and the two sections are currently deciding it independently.**
3. **The ledger** — the Stage 0 leaderboard inputs (**D-7**).

**Recommendation.** One sentence the plan does not have: **the server treats
nothing in `save.json` as evidence.** Everything a claim or reveal depends on
must be server-side state derived from server-observed queries. That sentence
also answers §13's first open question about what Stage 0's account record must
hold. **And the project already owns the technique** — §66:6264 makes beacon
stock *derived, never stored*, *"so a hand-edited save cannot carry 'stock: 9'
beside eight standing beacons."*

---

### D-10 — LIVE DEFECT, shipped today: the intel hint's dedup key and its RNG seed key disagree. `[fact]`

**Severity: minor for Horizon 5, but it is a present-tense bug in `main`.**

Verified in both directions:

- **Seed** (`hunt.gd:258-259`): `int(round(from.x)), int(round(from.z))` —
  integers.
- **Dedup** (`game_state.gd:1992-1993`):
  `is_equal_approx(float(h.get("ox")), float(hint.get("ox")))` — exact floats.

They disagree both ways:

| move | dedup says | seed says | result |
|---|---|---|---|
| **1.0 u** | new hint | new seed | **fresh independent draw** — the stacking channel in **D-3**; the *"precision is bought"* rule at `game_state.gd:1980-1983` does not hold |
| **0.3 u** | new hint | same seed | **bit-identical bearing filed twice** |

The second case is the shipped bug: a duplicate hint is counted twice in
`score`/`strength` by `Hunt._scan` (`hunt.gd:104-106`), and `strength` gates the
radar ghost at `hud.gd:221` (`>= HUNT_MIN_STRENGTH`). **So walking 0.3 u and
re-buying inflates the agreement count without adding information, and can
surface the ghost early.**

**Recommendation.** One line: dedup on the same rounded key the seed uses. **Not
applied in this commit** — it is a behavioural change and there is no Godot
binary in this container to red-verify it. It wants an assertion that a
sub-unit reposition yields the same hint and does not increase `strength`.

---

### A-4 — The casual-vs-grinder analysis is honest about the derby and silent about the claims layer, which is the part that ships first. `[inference]`

**Severity: major.** Dimension A. Two of the brief's questions, answered
together.

**"Why grind a Mk III if the prize arena ignores it?" — the plan has a good
answer and never states it.** I-5's spec loadouts are legally load-bearing
(equal dignity) and §11 correctly lists them as a churn mitigation: *"spec
derbies where gear cannot bury a newcomer."* The tension the brief names is real
— the Mk III line is the newest content in the game (frontier stage 2, §69: ten
modules; catalog tops out at **90,000 cr**, ≈43 minutes of optimal play per
module at the measured earn rate) and the only competitive surface ignores it.

But the ladder and the derby are aimed at **different activities**, and that
resolves it: the ladder buys **depth**, not competition. THE BREAKWATER and THE
FAR LANTERN (§70) exist precisely as the band-5/6 ports that sell what the chart
cannot; the Mk III line is what survives THE UNSOUNDED's storms (§71). *"Why
grind a Mk III"* has the answer *"to go further out than the derby will ever take
you"* — which is the game's own thesis. **Say it in §5.** It is the first question
a player will ask, it has a good answer, and an unstated good answer reads as no
answer.

**The casual-vs-grinder analysis is honest exactly where §11 looks, and §11 does
not look at Stage 0.** §11's mitigations — *"tiered prize distribution, seasonal
resets, private regions as winnable ponds, and spec derbies"* — address the
derby (I-5) and the store (§4 sink 1). They do not address the **claims layer**,
which is the first thing that ships and the only thing Stage 0 contains.

And the claims layer is the most grinder-favouring mechanic in the whole horizon:

- First-charts go to whoever flies the most, with no skill component and no
  diminishing return. Per **A-2**, ~3,955 sites at ~5.75 u/s means the resource
  is allocated almost purely by hours flown.
- §2's leaderboard axes — *"deepest verified sounding, most first-charts, most
  distinct bands visited"* — are **all three volume metrics.** There is no axis a
  casual player can win.
- And unlike every other layer, the claims are **permanent** (§2), so early
  volume compounds forever while seasons reset around it.

So the horizon's stated casual-friendliness is concentrated in Stage 3, and its
most grinder-skewed mechanic is Stage 0 — which means the *first* experience of
the horizon, for everyone who arrives after week one, is reading a map covered in
somebody else's name with no way to compete for what is left.

**Recommendation.** §11's mitigation list must cover the claims layer, and the
cheapest fix is the same one **A-2** recommends for a different reason:
**make first-charts seasonal.** That single change converts the most
grinder-skewed mechanic into a renewing one, gives late arrivals a real
frontier, and preserves the trophy as a *record* rather than an annotation. Add
at least one non-volume leaderboard axis — first-charts *per hour played*, or a
"deepest single sounding" that a good run can win without a long one.

---

### C-4 — I-1 rests on a stale measurement. `[fact]`

**Severity: minor.** I-1: *"The whole test culture (**61 runs**, WORLD
FINGERPRINT, pinned seeds)…"*

Counted from `tools/run_harness.sh`: `TAGS` = 46, `SAVE_MODES` = 17 → **63 runs**.
Separately, STRATEGY §72:7206 says **634** assertions where README:119 said 616 —
616/62 was correct as of §71 and never updated when §72 added `PYXIS_CONTACTTEST`
(19 assertions, one tag). *(Both README figures were corrected in the previous
commit on this branch.)*

Minor in itself; noted because I-1 is an *invariant*, and the plan's own §12
closes with the `TUTORIALTEST sentries=0` lesson about numbers that get printed
and not read. README:163: *"a baseline is a measurement with an age on it."*

---

### C-5 — §12's contract-test approach tests agreement with a mirror of its own author. `[inference]`

**Severity: minor** as specced, **major** if it is the only defence.

§12: *"**`PYXIS_CLAIMTEST`** against a local server stub"* and *"Server contract
suite (runs in the server repo, **mirrored as a stub locally**)."*

The word "mirrored" is the failure mode. One person writes the client, the
server, the stub, and the assertions; the stub agrees with the server because the
same belief produced both. STRATEGY §72:7209-7212, on four defects an adversarial
review found that 634 green assertions did not:

> **Every one of them lives at a seam between the new code and a rule written
> down somewhere else — which is precisely where a harness written by the author
> of the change does not look, because the author is asserting the thing they
> just built.**

The rule §72 draws is **"assert the seams you did not write"** (§72:7254). A
client/server boundary is *entirely* seam.

**Recommendation, and it is cheap.** A **checked-in contract fixture**: one
committed JSON file that *is* the wire format — band edges, cell size, supercell
size, claim key shape, version. The client harness asserts its constants against
the fixture; the server's build asserts its constants against the same file.
Neither talks to the other at test time, and a divergence is a red diff rather
than a flaky network call. In this repo's idiom that is `ATTRIBUTION IS EXPLICIT`
(`main.gd:15790`) — an assertion that reads a file as text because a call site
that is never exercised cannot be caught any other way.

**The constant that will break first:** `deep_space.gd:33` —
`BAND_EDGES := [0.0, 160.0, 440.0, 1100.0, 2600.0, 5200.0]`, with the comment at
`:22` noting the edges are *appended* rather than inserted. It has already been
extended once (frontier stage 1). The next extension is a silent client/server
disagreement about where THE QUIET ends.

**And budget for the adversarial reader.** §70:6750-6753 records the practice
that actually works here: *"Four adversarial readers went at the two archetypes
as a **specification** — no file written… **Two of what they found would have
shipped.**"* Do that to the wire contract before it is implemented. It is the
highest-yield process this project has, and the only one that addresses
author-asserts-own-work.

---

### E-5 … E-9 — Five further compliance-coherence findings. `[inference — verify with counsel]`

**Severity: major.** Dimension E.

**E-5 — §6 supplies the exact sentence §8 warns about.** §8: pooled pots are out
because *"'the pool is separate from the subscription' is a fiction regulators are
specifically practiced at piercing."* §6: *"the prize line is a marketing expense
from revenue — **self-funding at roughly 100–150 subscribers at $5 against a
$500/month prize budget**."* The substance is almost certainly fine and
materially different from a pool — entry is free, no subscription is required to
enter or win, prizes come from general revenue. But §6 states, as a
subscriber-count-to-prize ratio, the framing §8 says gets pierced, and that
sentence is the one most likely to migrate into marketing copy or an upsell
screen. **Recommendation:** a framing rule, not a structure change — the prize
budget is committed and announced *before* the period whose revenue would fund
it, is paid regardless of subscriber count, and is never described to players as
subscriber-funded.

**E-6 — §10 bullet 3's rule is narrower than the risk in its own sentence.** It
names the risk as *"paying for a randomized reward"* and then states the rule as
*"keep purchased currency out of chance-gated **entry**."* Intel falls in the
gap: buying a reading is not entry, it is a mid-hunt purchase resolving a
chance-seeded outcome. §13's *"salvage credits, hard"* closes the **direct** hop
only; two indirect paths survive — §4 sink 3 sells *"ship slots … without
regrinding"* (money → saved grind → credits → intel), and §6's **undefined**
*"convenience bundle"* reopens it on a recurring charge if it ever accelerates
income. **Recommendation:** widen the rule to match the stated risk — *nothing
purchased with real money, directly or through any conversion, may resolve by
chance, anywhere in the product.* Then §13's lean becomes a consequence of the
rule rather than a preference.

**E-7 — Private-region seeding is a purchased randomized reward, and §10 has no
loot-box bullet.** Open-world capsules are clean: free to find, so not purchased,
and the skill-gated crack strengthens it. **This is the plan's strongest
structural choice.** Private-region capsules are not obviously clean — real money
→ a randomized distribution of **fungible** currency — and which side of §10's own
Belgium/Netherlands bullet they land on turns entirely on what *"configurable
rarity"* means: *"I specify N capsules of tier T at density D"* is deterministic
and the question disappears; *"I set a dial and the server rolls"* is the exact
shape that bullet names. **The document does not say which.** **Recommendation:**
specify seeding as fully deterministic and buyer-specified — it costs nothing and
removes the question — and add a loot-box bullet to §10 recording the reasoning.

**E-8 — The derby is drafted in sweepstakes vocabulary and structured as a skill
contest.** §5 says *"a **free entry route with equal dignity** is what makes this
a sweepstakes"* — but **there is no free entry *route*, because there is no paid
route.** "Equal dignity" and AMOE are terms of art about an *alternate* method
alongside a purchase path; this promotion has one path and it is free. Harmless
today; the risk is that it lets a future maintainer conclude *"we have an AMOE, so
we can add a paid entry route"* — the drift §0 says the ledger exists to prevent.
And sweepstakes and skill contests carry **different disclosure sets** (odds of
winning vs judging criteria and basis of determination). *"Fastest verified crack
wins"* is a contest rule; the consideration analysis around it is sweepstakes
framing. **§5 currently sends counsel one rules draft described in both idioms.**
**Recommendation:** decide which promotion this is — my reading of what §5
describes is a free-entry **contest of skill** — and let the disclosures,
registration analysis and rules structure follow from that one choice.

**E-9 — I-4's protection rests entirely on the word "instanced," which §6's
seasons never repeat.** I-4 holds as literally written across all six stages —
verified stage by stage, and recorded as **V-9**. The one exposure is §6:
*"Seasons unify the layers: leaderboards reset…"*. Season leaderboards are fed by
**daily open-world play**, and I-4 excludes them only because they are not
*instanced* — one word, never repeated in §6, carrying the whole load.
**"Season champion gets $250" is the single most obvious thing a future
maintainer would add**, and it would simultaneously route purchased advantage into
a real-money prize through all three channels this review traced: private-region
practice (**E-2**), push notifications, and intel (**E-6**).

**On push notifications specifically** (§4 sink 4, *"convenience — never
power"*): they are a **latency advantage in a first-come race** — §0's own thesis
is *"their timestamps are the thing you race"* — so calling them "never power" is
wrong on the design merits. But they do **not** currently touch prize odds,
because open-world capsules pay closed-loop currency and derbies are scheduled.
**Notifications are fine today and become an I-5 violation the moment a
leaderboard carries cash.** **Recommendation:** state in §6 that *season
leaderboards never carry a real-money prize.* One sentence retires the entire
notification/intel/practice question for the open world permanently.

---

### E-10 — Twelve further omissions and inconsistencies. `[fact — verify with counsel]`

**Severity: minor individually; the pattern is worth the table.**

| # | issue |
|---|---|
| Tie rule | §5's *"fastest verified crack wins"* has **no tiebreak, no timing source, no latency policy**. With a hard human-paced floor and a practised field (**E-2**), ties at the floor become the expected outcome — and a random or arrival-order tiebreak re-introduces chance at exactly the point §10 bullet 2 claims mirroring removed it. Specify a **skill-based** tiebreak |
| Geo-gating | I-8 gates **payouts**; §5 gates **entry**. Different promises — payout-gating lets a player enter, invest hours, win, and be told they cannot be paid. How geography is determined (declared / IP / payment instrument / KYC document — all of which disagree) is unstated, as is VPN handling |
| Prize magnitude | §5's $250 headline is likely comfortable *because* it sits below common registration/bonding thresholds — **the plan never says that is why**. §6 then proposes a *"scaled headline prize"* and I-8 tells the maintainer no re-review is needed (**E-4b**) |
| Disclosure | §5's rules list omits the "no purchase necessary" **disclosure** obligation itself and where it must appear, plus abbreviated-rules content (sponsor, dates, eligibility, odds-or-judging-basis, prize value) |
| Insider eligibility | I-2 makes the **operator** hold every objective by design. §5's rules list has no sponsor/employee/tester/family exclusion, and §9 lists no insider vector — in an architecture whose whole premise is that the server is trusted |
| Data protection | No controller/processor posture, lawful basis, notice, retention or deletion, for a Stage 0 that creates accounts before I-8 fires |
| Consent drift | The shipped posture is opt-in, local-only, never-networked (`telemetry.gd:13`, `game_state.gd:60`: *"a recorder running because the player never found the switch is not a recorder they consented to"*). Stage 1's near-miss logging is a **posture change**, not an extension, and the plan should say it is deliberately departing |
| Permanence vs erasure | *"Permanent"* is promised three times and is in tension with deletion rights. The obvious reconciliation — etch the **handle**, sever the account link — is never mentioned and is a **Stage 0 schema decision** |
| Processor & refunds | *refund* and *dispute* each occur **once**, both in §7's parked-Stage-5 list. Selling virtual currency (Stage 2) and running prize promotions (Stage 3) are commonly restricted categories on their own. §9 has zero words on chargebacks |
| Non-monetary consideration | §10's consideration analysis is entirely monetary; several regimes reach substantial time, effort or data. The finding is the omission, not the treatment |
| Tax periodicity | Three periodicities asserted about one surface: I-4 says *"per-event paperwork"*, §10 says *"≥$600/**year** to one winner"* (per-payer aggregate), I-8 says *"per structure"*. With §6's monthly cadence a repeat winner crosses the annual aggregate quickly. §10 is also **US-only** for an internationally geo-gated promotion |
| Housekeeping | No record-retention rule; no winner **publicity release** despite §5's *"every winner is a story"*; no right to void/modify/substitute reserved against §6's published cadence; §5's *"one identity, one payout, ever, per event"* is ambiguous between "once per event" and "once, ever" — and it is the plan's stated multi-account defence, whose strength differs by an order of magnitude between readings |

---

### C-6 — Two small internal inconsistencies. `[fact]`

**Severity: minor.** Recorded because this client's culture notices them and
because both sit in the sections that will be read by an attorney.

1. **The prize floor is stated twice, differently.** §5:226 — *"a handful of
   **$10**–$100 capsules and one $250 headline"*. §5:234-235 — *"at **$25**–250,
   the money cannot be the motivation"*. The psychology argument in §11 and the
   §5 prize schedule should quote the same number, and the official rules will
   quote whichever is written down.
2. **"Invite-only region" is an access grant, not a currency transfer.** I-3
   holds literally — no currency moves — but §4 sink 1 lets a purchaser give
   others access to a purchased good, which is the nearest thing to a transfer
   in the document. Worth one sentence in §4 stating that access is not
   transferable value and that invitees gain no currency, so a later reader does
   not have to re-derive that it is fine.

---

### Verified true — claims that held

The brief asks for these explicitly, and they mark ground that needs no
re-argument.

| # | claim | verdict | evidence |
|---|---|---|---|
| **V-1** | **I-2's core reasoning**: client determinism ⇒ the world is enumerable offline ⇒ valuables must be server-placed | **TRUE, and stronger than stated** | `plan_cell(cx,cz)` (`deep_space.gd:826`) takes no seed at all. Ten salted streams on `(system_id, cell)`. Every player's world is identical *and* enumerable without even knowing a seed. I-2 is the most important sentence in the document |
| **V-2** | A server port was anticipated at founding | **TRUE** | §2:26 — State: *"Local save, explicitly serialized"*, rationale *"**Keeps a server port possible without building one now.**"* |
| **V-3** | Every repo artefact §12 cites exists | **TRUE, 5/5** | `MINING COSTS A MOUNT`, `ATTRIBUTION IS EXPLICIT`, `INTEL NARROWS AND NEVER LIES`, `WORLD FINGERPRINT`, `THE PINNING LIST IS COMPLETE` — all present in `main.gd`. The `MINING COSTS A MOUNT` citation is apt: it read `REACTOR_TIERS.size()-1` into a var named `mk3` and silently changed meaning when a tier was added (README:333-341), which is exactly the spec-loadout pinning hazard §12 invokes it for |
| **V-4** | §12's *"telemetry is observation, not assertion"* | **CORRECT, and well-applied** | The `TUTORIALTEST sentries=0` lesson (§54:4806-4838) is precisely the right citation, and pre-empting it is the kind of thing this project's record says nobody does until it has cost them |
| **V-5** | I-1's offline severability is achievable | **TRUE** | Zero networking exists today (`grep HTTPRequest\|HTTPClient\|multiplayer\|WebSocket scripts/` → 0), so "additive overlay" is the actual current state, not an aspiration |
| **V-6** | *"Deep space persists nothing"* (as inherited from §64) | **FALSE as stated — but the plan never relies on it** | `beacons`, `colonies`, `last_colony_jump` are all saved (`game_state.gd:2478-2480`); `beacons` cost save v20. The distinction is generated content vs player state, and a claim is player state. *(§64 was corrected in the previous commit on this branch.)* The plan is silent on save impact — see §6 |
| **V-7** | Stage 0 is the right minimum thesis test | **TRUE** | Severable, no money, no legal exposure, degrades cleanly, tests the only load-bearing hypothesis. An earlier pass of this review recommended almost exactly this shape independently |
| **V-8** | §8's permanent-parks are correctly reasoned | **TRUE / internally coherent** | Pooled pots (consideration+chance+prize), cash-out currency (I-3), prediction markets (CFTC designation, not a loophole). The prediction-market entry in particular is a trap the plan spotted before walking into it |
| **V-9** | **I-4 holds across all six stages** as literally written | **TRUE** | Checked stage by stage. Stage 0 no money; Stage 1 closed-loop only; Stage 2 store only; Stage 3 scheduled and instanced; Stage 5 instanced. The single exposure is definitional, not a violation — §6's seasons, see **E-9** |
| **V-10** | **The shipped intel code already exceeds §10's standard**, and §13's lean is grounded in the shipped economy | **TRUE, and this is the best news in the review** | `hunt.gd:248`: *"THE ERROR IS SEEDED, NOT ROLLED. `randf()` here would mean a player who saves, buys a reading, reloads and buys it again gets a different cone each time — the hunt would become a slot machine that pays out to whoever reloads most."* **A purchased reading today is deterministic**, which is exactly the property that stops a paid intel purchase being a paid random draw — reached for anti-save-scum reasons years before the compliance question existed. And intel *is* priced in salvage today: `hunt_price: 500` (`system_db.gd:170`), `900` (`deep_port_db.gd:179`). **The gap:** §12's server contract suite lists *"vague-never-false"* and **omits seeded-not-rolled entirely** — the compliance-relevant half of the invariant is the half that did not make the crossing. Adding *"the same reading, purchased twice from the same position by the same account, returns bit-identical output"* is the single cheapest item in this review |
| **V-11** | §4 sink 2 gets the purchased-advantage line exactly right | **TRUE** | *"Winner-exclusive liveries exist but are never purchasable (status must be earned or it is not status)."* The one purchasable in the document with no I-5 exposure of any kind, and the reasoning is stated |

---

## 4. Per-stage gate assessment

For each: is the metric right, is it measurable with what the stage actually
builds, and what number is pass/kill.

**A gate is real only if all four hold:** the metric exists *before* the stage
ships (not built by it); the number is decided in advance; there is a **kill**
criterion (what gets torn out), not just a hold; and a date and owner are set,
because the failure mode of a solo gate is that nobody calls it.

---

### Gate −1 (new, before Stage 0) — the platform gate

**Not in the plan. Add it.** §0 commits to browser-first; nothing has ever been
exported (**F-1**).

- **Metric:** a web export completing one 8-minute loop on a mid-range phone
  browser.
- **Measurable?** Yes, today, with no new instrumentation.
- **Pass:** ≥30fps sustained, worst frame under 60ms, audio intact.
- **Kill:** if a web build cannot be produced in **five working days**, the
  browser-first premise is unfounded and §0, §9's threat model and the
  distribution plan all need rewriting before anything else proceeds.

---

### Stage 0 — The Registry

**Plan's gate:** *"measured retention delta. D1/D7/D30 for account-holders vs.
anonymous players, and claim-engagement (% who file ≥1 claim; % who return
within 48h of being beaten to a claim)."*

- **Right metric?** **Yes — the best gate in the document.** "% who return within
  48h of being beaten" is a direct operationalisation of the thesis, not a proxy.
  It deserves the credit.
- **Measurable with what the stage builds?** **No, not as written** — and this is
  blocker **A-1**. The metric is a function of claim granularity, which §13 defers.
  At the per-system granularity §2's own example implies, the denominator is 3
  and reads zero forever.
- **Second problem:** the account-holder vs anonymous comparison is
  **self-selecting**. Players who create accounts are already more engaged;
  a D7 delta between them measures the selection, not the feature. This needs a
  randomised holdout (claims visible vs hidden for a fraction of
  account-holders) or the number is not evidence.
- **Numbers I would set** — after fixing granularity to per-landmark:
  - **Pass:** ≥25% of active players file ≥1 claim in their first week, **and**
    the beaten-to-a-claim 48h return rate is ≥1.3× the same players' baseline
    48h return.
  - **Kill:** <10% file any claim, **or** beaten-players return at ≤1.0× baseline
    (rivalry is inert, or actively discouraging). **Kill means the claims layer
    ships as a solo-player cartography feature and the horizon ends here** — as
    §2 already says, "having still shipped a good feature."

---

### Stage 1 — The Rumor Economy

**Plan's gate:** *"% of active players engaging the rumor layer weekly, and the
retention curve of players in the week after a near miss."*

- **Right metric?** Yes for the second half. The near-miss hypothesis (§11:
  *"near-misses do the daily retention work"*) is the load-bearing psychological
  claim of the whole horizon, and §3 correctly builds the instrument
  (near-miss telemetry) to test it.
- **Measurable?** Yes — §3 explicitly ships the logging. **This is the plan's
  best instrumentation decision** and it satisfies the "metric exists" test
  because the telemetry is stage scope, not gate scope.
- **Gap:** the gate has no **rarity-calibration** criterion, though §3 states the
  target (*"brush weekly, find monthly"*). Add it: if measured find-rate is
  outside 0.5×–2× the target after tuning, the server dial is not sufficient and
  the density model is wrong.
- **Numbers:**
  - **Pass:** ≥40% of weekly-active players buy ≥1 reading per week, **and**
    near-miss players' 7-day return is ≥80% of finders' (that is the actual
    claim — near-misses retain *almost* as well).
  - **Kill:** near-miss return <60% of finders'. That falsifies §11's
    anticipation-is-the-content thesis, and with it the case for a rumor economy
    at all — at which point capsules are just rare loot and the store should be
    reconsidered from scratch.

---

### Stage 2 — The Store

**Plan's gate:** *"conversion rate to first purchase, sink absorption (does
currency pool in wallets or get spent — pooling means weak sinks), and private
region creation/joins."*

- **Right metric?** Sink absorption is exactly right and well-posed.
- **Measurable?** Yes.
- **What's missing:** no **revenue** number, which is odd for the stage that
  introduces revenue. §6 asserts self-funding at 100–150 subscribers × $5 vs
  $500/month prizes — but that is *contribution margin* with **no acquisition
  cost and no churn in it**. At 5% monthly churn, a 125-subscriber stock needs
  ~6 net new subscribers *every month, forever*, from an unreleased browser game
  with no marketing budget. State the assumed install→account and
  account→subscriber rates; those two numbers decide whether the business exists.
- **Also missing:** a price for private regions, which per **B-2** is doing two
  incompatible jobs.
- **Numbers:**
  - **Pass:** ≥2% of account-holders make a first purchase within 30 days, **and**
    ≥60% of issued currency is spent within 30 days (absorption).
  - **Kill:** <0.5% conversion, **or** >70% of currency pooling unspent — the
    sinks are decorative and Stage 3's prize budget has no funding model.
- **Flag:** this is the **true point of no return** (**F-2**), not Stage 3. Money
  taken cannot be un-taken. Put the counsel review before this stage, not after
  it (**E-1**).

---

### Stage 3 — The First Derby

**Plan's gate:** *"entrants per event, new-player signups attributable to the
event, repeat-entry rate, ops hours per event, and zero credible cheating
incidents."*

- **Right metric?** **Yes, and "ops hours per event" is the single best line in
  the plan's gate design** — it is the only gate in the document that measures
  the *developer* rather than the players, and dimension F says that is the
  binding constraint. §5's *"Measure everything, including your own hours"* and
  its insistence on running by hand first is genuinely strong practice.
- **Measurable?** Yes — hand-run by design, so everything is observable.
- **Problem with "zero credible cheating incidents":** it is unfalsifiable as
  stated. Absence of *detected* cheating in a hand-run event with a human reading
  logs is weak evidence, and it is exactly the *"AMBIENT COMBAT DEPLETES
  NOTHING"* shape — satisfied perfectly by a world where nobody looked. **Make
  it adversarial:** commission one person to *try* to cheat a derby, and gate on
  whether the log review caught them.
- **Numbers:**
  - **Pass:** ≥30 entrants by event 3, repeat-entry ≥40%, **ops ≤6 hours per
    event**, and the commissioned cheat attempt was detected.
  - **Kill:** **ops >15 hours per event** at any point. That is the number that
    ends the horizon regardless of how good the other metrics look, because §6's
    automation is specced to be sized *"to what one developer proved sustainable
    in Stage 3"* — and 15 hours a month of unautomatable admin is not
    sustainable alongside building the game.

---

### Stage 4 — Cadence and Subscription

**Plan's gate:** none stated. §6 lists what ships and gates only on *"after
derbies prove demand."*

- **This is the ratchet** (**F-2**). Stage 4 is where a **public cadence** is
  published — *"A published cadence is a promise"*, §6, correctly — and where the
  subscription creates recurring obligations. It is the stage with the most
  externally-visible commitments and the only one with no gate.
- **Add one. Metrics:** subscriber count and churn against the prize line;
  consecutive months of the published cadence met without slippage.
- **Numbers:**
  - **Pass:** ≥100 subscribers with <7% monthly churn, **and** three consecutive
    published events delivered on the announced date.
  - **Kill:** any **missed published date** in the first six months. Not because
    one slip is fatal, but because the cadence is the promise, and a solo
    operator who cannot hold it for six months should find that out while the
    audience is small enough to apologise to individually.
- **This is also the answer to the brief's question about a two-week absence.**
  See §6.

---

## 5. The five assumptions most likely to sink the horizon

Ranked by (probability wrong) × (cost if wrong), each with the *cheapest*
falsifying test.

> **Two of these are no longer assumptions.** This review measured them, and both
> came back against the plan. They are kept in the list because they are the two
> most likely to sink the horizon and the plan still rests on them — but the
> "cheapest test" for #2 and #5 is not an experiment to run, it is a redesign to
> decide. Read them as findings with a residual verification step, not as open
> questions.

---

**1. "There is enough frontier to race over."**
*Why first:* it is already measured and already looks wrong. 3,955 claimable
sites, ~30–50 player-hours to exhaust, permanence promised (**A-2**). Every
downstream stage assumes an unclaimed frontier exists to create rivalry.
**Cheapest falsifying test — one afternoon, no server, no code:** take the
arithmetic in **A-2**, pick your granularity, and compute the fill curve for
100/1,000/10,000 players against your expected session length. If the frontier
is full inside two seasons, Stage 0's permanence clause is wrong and it is a
one-line fix *now* versus a broken promise later. This is a spreadsheet, not an
experiment.

---

**2. "Shared stakes make solitude stickier rather than spoiling it."**
*Why second:* it is the thesis, and nobody has any evidence.
**Cheapest falsifying test — ~one day, still no server:** a **ghost chart**.
Ship a static data file of the developer's own past surveys as
`(system, supercell, name, date)` rows, render them on the chart panel — which
already draws hint cones and beacon dots (`chart_panel.gd:179-293`) — labelled
honestly as prior surveys. Play for a week and answer: does finding a name out at
3,000u make the place feel *more* like somewhere, or *less* like yours? Do **not**
fabricate other players; a deception is not a test result, and the honest version
measures the same thing.

---

**3. "A solo developer can carry standing live-service ops."**
*Why third:* highest cost if wrong, and untested in either direction. The git
record shows commits on **11 of the 11 days** this project has existed
(2026-07-28 → 2026-08-07), including **six shipped stages in ~36 hours** across
08-04/05. That is extraordinary *feature* velocity on a deterministic offline
codebase — and live-ops is measured in **response latency to incidents you did
not schedule**, which nothing in the record demonstrates. The brief describes a
game "that can sit untouched for a month": true of the *artifact*, because it has
no server; Horizon 5 removes exactly that property.
**Cheapest falsifying test — $5 and three weeks of doing nothing:** deploy the
do-nothing claims server and leave it running, no players, no traffic, no
features. Log every time it needs attention — a certificate, a bill, a host
migration, a dependency advisory, an unexplained restart. If it is more than zero
on an *empty* server, it is much more than zero on a populated one. Runs
concurrently with everything else.

---

**4. ~~"The rumor layer can be an information channel without being an oracle."~~ — FALSIFIED**
*Not an assumption any more.* **D-3** did the arithmetic. The honesty guarantee
that makes intel trustworthy — *"vague, never false"* — is exactly what makes it
composable, and composable bounded-honest samples converge: K readings shrink the
containment interval to **`4e/(K+1)`**, so 19 readings turn an 8° cone into 0.8°
**with no new information, only more samples**. The hint seed rounds observer
position to integers (`hunt.gd:258-259`), so **one unit of walking buys a fresh
independent draw**; and `Hunt.estimate` is a pure static function the attacker
compiles from your own source. Rate limits scale K linearly with time and do not
bound it.
**Residual step — a design decision, not a test:** pick one of the three
non-oracle formulations in **D-3** (per-(capsule, account) nonce; server-side
intersection returning a floored `{center, radius}` instead of cone parameters;
or warmer/colder on occupied positions only) **before Stage 1 is built**, and
settle §13's intel-pricing question as a security decision at the same time
(**D-9**).

---

**5. ~~"Physics plausibility distinguishes a player from a bot."~~ — FALSIFIED**
*Not an assumption any more.* **D-4**: movement is tap-to-command autopilot
(`player_ship.gd:721`, `:874-912`) and combat is auto-resolved, so **the game's
own shipped pathing generates the bot's trajectory** — a bot and a human produce
bit-identical paths from the same tap. The server sees only
`(position, timestamp)`, which is what an attacker synthesises with *genuine*
positions. And the instrument §9 cites does not exist in usable form:
`telemetry.gd` is session-shaped, local-only, and states *"NOTHING IN THE GAME
MAY READ IT"* (`:13-17`).
**Residual step, half a day:** write the bot anyway and run §9's check against
the trace, so the rejection carries a measurement rather than an argument. Then
rename item 3 to what it is — an **anti-teleport check**, which is real and worth
keeping — and move the anti-bot weight onto scarcity, identity, and **D-2**'s
sweep economics.

---

**The one that replaced them, and it is now the highest-value untested claim:**

**6. "The derby is a contest of predominant skill."**
Stages 3–4 do not need it — free entry carries them — but **Stage 5 rests on
nothing else**, and §10 asserts it while §7 concedes the opposite in the same
document (**E-1**). If it is false, the parked stage is unparkable and the
account/wallet/KYC plumbing built toward it was built for nothing.
**Cheapest falsifying test — no lawyers, one hand-run event:** run derby 1 with
identical spec entrants who all know the objective's rough band, and measure the
spread in completion time. If the spread is dominated by *who searched the right
quadrant first* rather than by execution, the mirrored layout is equalising the
stage and not the outcome — exactly as §7 says and §10 denies. Take **that
measurement** to counsel rather than the argument; a number about your own event
is worth more than an analogy to bridge.

---

## 6. What's missing

Things the plan should specify and does not. Ordered by when they become
expensive.

**Before Stage 0**

- **Claim granularity** (**A-1**) — currently in §13; belongs in §2.
- **Frontier exhaustion behaviour** (**A-2**) — what happens when it fills.
- **Save impact.** The plan says nothing about the save schema. A claims layer is
  deep-space *player state*, which is the `beacons`/`colonies` side of the line
  (**V-6**) and cost save v20. Expect a bump. It is mechanically cheap —
  §36:2557 records *"there is still **no `migrate_*()` function anywhere**"*,
  field-defaulting since v1 — but §38:2752 and §44:3690 record the one expensive
  case: **a default that takes something away.** A default that silently drops a
  first-charted name is that case, and worse than the `lanes_open` precedent
  because the name may have been re-filed by someone else meanwhile. State the
  grandfather rule in §44's idiom: *which way do we choose to be wrong.*
- **The auth story.** The brief names it; the plan defers it to §13's open
  question about identity. "Email or OAuth" (§2) is not a design. For a Godot web
  export specifically: where does the token live, what happens on refresh, and
  what does the client do with a 401 mid-session?
- **The offline degradation contract, feature by feature.** I-1 states the
  principle well. Nothing states what a player with no connection *sees* — do
  claim annotations vanish, grey out, or show stale? A claim filed offline: lost,
  queued, or refused? "Degrades gracefully" is a posture, not a spec.

**Before Stage 1**

- **Capsule density as a function of population.** §3 correctly makes density a
  server dial rather than a client constant — the *mechanism* is right — but
  never states the *function*. "Brush weekly, find monthly" is a per-player rate;
  per-player rates require density to scale with population. State it at 100 and
  at 10,000 players.
- **Intel prices, in credits, as a % of an 8-minute loop** (**B-1**).
- **The oracle question** (assumption 4).

**Before Stage 2**

- **Private-region pricing, and whether they pay salvage** (**B-2**).
- **CAC and churn** (§4 gate assessment). The break-even is contribution margin
  only.
- **Age assurance.** Browser-first, no app-store gate, real money. Nothing in
  §10 addresses minors, and the codebase has no age-gate mechanism — the only
  settings are audio, colour-vision and UI scale.

**Before Stage 3**

- **What happens when the server is down during a derby.** This is the first
  breakable public promise and it needs an answer *before* the first derby is
  announced.
- **Hosting cost and single-point-of-failure exposure**, with numbers.
  **The plan defers this explicitly and legitimately** — the closing note commits
  to *"a server architecture note (stack, hosting, cost ceiling)"* as a companion
  document, and it is right that it does not belong in the design record. Two
  qualifications: **(a)** the companion note is needed before **Stage 0**, not
  Stage 3, because Stage 0 already runs a server; **(b)** when it is written, the
  thin-registry number must not be allowed to stand in for the wallet number —
  a claims registry is a $5–20/month VPS, and a wallet with a transaction log,
  idempotent writes and payout reconciliation is a different object with a
  different cost and a different failure blast radius.

**Process, throughout**

- **A rollback per stage** (**F-2**), including what the save does with orphaned
  state.
- **Which STRATEGY sections this horizon amends**, edited in the same commit —
  §5:72 and §2:25 at minimum, plus the §3 pillar (**A-3**).
- **The two-week absence answer, stated in the plan.** The brief asks for the
  earliest stage where a two-week absence causes player-visible breakage. It is
  **Stage 4**, unambiguously: Stage 0–2 degrade to a working single-player game
  (I-1) and a store that can 503 without anyone being owed anything; Stage 3 is
  hand-run and can simply not be scheduled. Stage 4 publishes a **cadence** and
  charges a **subscription** — a missed date is a broken promise to people who
  paid. Everything before Stage 4 is absence-tolerant by construction, and that
  is a genuine strength of the staging that the plan should claim out loud.

---

## 7. What to cut — and one retraction

### Cut: Stage 5, from the document

§7 (paid-entry skill tournaments) is well-reasoned and correctly parked. **Cut it
anyway**, to its own file.

Not because it is wrong — because a parked stage inside the plan does load-bearing
damage to the plan's own gating. Its presence means Stages 0–4 get read, built and
costed as *foundations for Stage 5*: the account model, the wallet, the
eligibility ledger and the KYC plumbing all look cheaper if something downstream
justifies them. That is how a five-stage gated plan becomes a ratchet. If Stages
0–4 stand alone — and the plan argues convincingly that they do, *"Stages 3–4
deliver most of the motivational payload without any of that"* — then §7 is
doing no work here and should be recorded elsewhere, to be retrieved only if
Stage 4's gate produces the demand evidence it names.

**Second cut, smaller: the daily cadence of the rumor layer** (**F-2**). Keep
rumors; make them **event-driven** — you get a rumor when you *do* something —
rather than date-driven. That removes the clock the game does not have, the §5:72
"timer monetization" collision, and the punish-you-for-being-away dynamic, at the
cost of only the login habit, which is the thing this game should least want. §3's
*"ports sell stale whispers cheap and fresh ones dear"* survives intact: staleness
can be measured in *your* elapsed play, which `played_seconds`
(`game_state.gd:187`) already tracks.

### Retraction

An earlier pass of this review, written when the plan was unavailable, recorded a
**blocker** that Horizon 5 opens a credit faucet against `MIDTIER`'s ~232-credit
headroom. **That was wrong.** Capsules pay closed-loop currency, not salvage
credits (§3), and `MIDTIER` is income-only, so the plan's currency design cannot
move the bar. I-3's closed loop — written for legal reasons — firewalls the
horizon from the binding economy assertion as a side effect. The surviving
economy findings are narrower and are recorded as **B-1** (no number on intel;
the pacing band is never mentioned) and **B-2** (private regions as an undeclared
faucet).

That pass also recommended "cut to a minimum thesis-testing version: a read-only
claims server, no currency, no prizes." **The plan already contains that, as
Stage 0.** The recommendation stands as an endorsement rather than a change.

---

## Appendix — verification log

Every measurement, so it can be re-checked or refuted.

```
CLAIM DENSITY
  SystemDB systems ..................... 3 (pyx01/02/03)
  is_system_charted .................... per-system boolean, game_state.gd:849
  BAND_EDGES ........................... [0,160,440,1100,2600,5200] deep_space.gd:33
  CELL / SUPERCELL ..................... 64.0 / 4 -> 256u  deep_space.gd:53,:1261
  claimable sites: per system 3 | per band 15 | per landmark 3,955 | per cell 63,276

FRONTIER EXHAUSTION
  starter max_speed .................... 5.75 u/s  module_db.gd:99
  (1.9x at player_ship.gd:871 is the SURGE ability, not cruise)
  all 3,955 landmark sites ............. ~49 player-hours @5.75 u/s sustained
                                          ~26 player-hours @10.9 u/s (unachievable)

WORLD GENERATION
  plan_cell(cx,cz) ..................... takes NO seed  deep_space.gd:826
  salted streams ....................... 10, all hash("%s|%d|%d|tag") on system_id
  grep -c run_seed deep_space.gd ....... 2, both the lair
  run_seed consumers ................... lair_pos, hyper_positions  system_db.gd:706,:773
  _world_fingerprint() ................. hashes plan_cell over 121 cells  main.gd:15536

ECONOMY
  PACING_MAX_MODULES ................... 3.00        main.gd:168
  PACING_MIDTIER / price ............... lance_1 / 5,800 cr  main.gd:169, module_db.gd:152
  PACING_MINUTES ....................... 8.0         main.gd:154
  real headroom ........................ 0.04 modules ~= 232 cr/loop  STRATEGY §51:4484
  catalog .............................. 51 modules, 0-90,000 cr
  plan mentions MIDTIER/PACING/§41/§51 . none

PLAN'S REPO CITATIONS
  MINING COSTS A MOUNT ................. exists
  ATTRIBUTION IS EXPLICIT .............. exists, main.gd:15790
  INTEL NARROWS AND NEVER LIES ......... exists
  WORLD FINGERPRINT .................... exists
  THE PINNING LIST IS COMPLETE ......... exists
  I-1's "61 runs" ...................... stale; TAGS=46 + SAVE_MODES=17 = 63

CLIENT SURFACE
  networking (HTTPRequest/HTTPClient/
    multiplayer/WebSocket) ............. 0 matches in scripts/
  wall clock (get_unix_time/
    get_date_dict/get_time_dict) ....... 0 matches in scripts/
  export_presets.cfg ................... does not exist
  save ................................. plaintext JSON, no integrity check
                                          store: game_state.gd:2507
                                          load:  game_state.gd:2521
  deep-space player state in save ...... beacons, colonies, last_colony_jump
                                          game_state.gd:2478-2480

SECURITY SURFACE (dimension D)
  hint RNG seed ........................ int(round(from.x/z))  hunt.gd:258-259
  hint dedup ........................... is_equal_approx(ox/oz) game_state.gd:1992
  ^ THESE DISAGREE — live defect, see D-10
  HINT_CAP ............................. 8, display cap in add_apex_hint only
  Hunt.estimate ........................ pure static fn, hunt.gd:173-223
  teleports ............................ recall_to_system main.gd:1508
                                          colony_jump_to  main.gd:1585
                                          COLONY_JUMP_COOLDOWN 300s main.gd:281
                                          gated on played_seconds main.gd:1570-71
  breach_speed ......................... fitted stat feeding crack rate
                                          derelict.gd:332, module_db.gd:476 (+50%)
  crack_time ........................... 1.8 + 0.2*band = 1.8..3.0s deep_space.gd:910
  telemetry.gd ......................... session-shaped, local-only, opt-in;
                                          ":13-17 NOTHING IN THE GAME MAY READ IT"
  fuel ................................. cell_fuel is a COMMODITY
                                          (commodity_db.gd:173). No consumption,
                                          no tank, no refuelling gate anywhere.
  DEFAULT_SETTINGS ..................... no age/birthdate/consent field
                                          game_state.gd:42-64

COMPLIANCE SURFACE (dimension E)
  intel priced in salvage today ........ hunt_price 500  system_db.gd:170
                                          hunt_price 900  deep_port_db.gd:179
  "THE ERROR IS SEEDED, NOT ROLLED" .... hunt.gd:248 — readings are deterministic
  age/minor/COPPA/GDPR/privacy/
    consent/disclosure/insider/loot
    in HORIZON-5-THE-CLAIM.md .......... 0 occurrences each
                                          (the one "age" hit is line 101,
                                           "a measurement with an age on it")
  refund / dispute in the plan ......... 1 each, both in §7's parked Stage 5
  plan mentions save schema ............ none (only §13, on account identity)

STRATEGY
  "solitude" in STRATEGY.md ............ 1 hit, §49:4341, means elbow room
  §5:72 exclusions ..................... MMO backend; alliance/social; timer or
                                          energy monetization; crew collection;
                                          three-tier map
  §2:25 ................................ "MMO/live-ops scope is a 50-person
                                          operation. Ours is not."
  git log --date=short | sort -u ....... 11 distinct days, 2026-07-28..2026-08-07

NOT VERIFIED
  The 634 PASS / 0 FAIL baseline. No Godot binary in this container, so
  tools/run_harness.sh could not be run and --check-only could not be run.
  Treat every citation of the baseline as a citation of a document.
```
