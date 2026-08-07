# Horizon 5 — The Claim

**Status: SPECCED, NOT BUILT.** When any stage of this document is adopted,
record it in `docs/STRATEGY.md` §64 in the same commit, per the house rule.
Nothing below exists in the build today.

This horizon transforms Pyxis from a single-player game about charting a dead
frontier into a game where the frontier is *contested* — where another pilot
might file the return first, and where being first is worth something. It does
this without an MMO, without touching the deterministic single-player core, and
without ever holding a pool of players' money against a chance outcome.

The one-sentence thesis: **scarcity of discovery is the retention engine;
money is a trophy, not a wage.**

---

## 0. Premise — what this horizon is, and what it is not

Deep space is already the game's best idea: it gets harder, stranger, and
better-paying the further out you fly, and nobody is watching. What it lacks is
a rival. The void does not care whether you chart it today or never. This
horizon adds the rival — asynchronously. Other pilots' names appear on your
chart; their timestamps are the thing you race; their ships never appear on
your screen.

It is explicitly **not**:

- An MMO. There is no shared simulation, no synchronous presence, no netcode
  in the flight loop. The game remains a single-player Godot client.
- A gambling product. No structure in this document takes money from players
  and pays it back out on a chance outcome. This is an invariant (I-3, I-4,
  I-5), not a preference, and the reasoning is recorded in §10 so a future
  "simplification" cannot quietly cross the line.
- A replacement for the game. Every stage below is severable. If the server
  layer were shut off tomorrow, the single-player game must still boot, play,
  and pass its sweep. That is also an invariant (I-1).

Platform: **browser first**, then mobile wrappers. Web distribution means
payments without a 30% store cut, no store review gauntlet while the economy's
shape is being proven, and instant iteration. Mobile stores are deferred until
the economy is stable and store-policy review is a bounded, one-time cost.

---

## 1. The invariants

These are the load-bearing walls. Each records *why*, because every one of
them will someday look like it is in the way of a good idea.

- **I-1 — The single-player core stays deterministic and playable offline.**
  The whole test culture (61 runs, WORLD FINGERPRINT, pinned seeds) depends on
  a client whose world is a pure function of the seed. Server features are
  additive overlays. A player with no account and no connection gets today's
  complete game.

- **I-2 — Nothing of real-world value is ever derivable from the seed.**
  Client-side determinism means anyone can run worldgen headless and enumerate
  the world offline. Therefore capsules, derby objectives, and anything with a
  prize attached are **server-placed and server-verified**, revealed to a
  client only in response to an authenticated, rate-limited query about a
  position the server believes that ship can occupy. The seed generates the
  stage; the server hides the props.

- **I-3 — Premium currency is closed-loop. Forever.** Purchasable with real
  money; spendable in game; **never redeemable, never cashed out, never
  transferable player-to-player.** This is the line between "game economy" and
  "gambling." It is also, as of 2026, the line six-plus states have drawn in
  statute while exterminating the dual-currency sweepstakes-casino model —
  those laws target currencies that *can* be exchanged back into cash or
  prizes. A redemption or transfer feature is not a feature request; it is a
  category change for the whole product.

- **I-4 — Real money is episodic, never ambient.** Real prizes exist only
  inside scheduled, named, instanced events (derbies). Daily open-world play
  never pays real money. Reasons: (a) small ambient cash rewards convert a
  hobby into a sub-minimum-wage job and displace the intrinsic motivation the
  game runs on; (b) a 24/7 open-world cash hunt is unpoliceable against bots,
  while a scheduled instanced event is; (c) sweepstakes compliance is per-event
  paperwork, which only works if events are discrete.

- **I-5 — Free entry, equal dignity, spec loadouts.** Any event with a real
  prize is free to enter for every player, subscriber or not, and nothing
  purchasable — subscription, currency, progression — may improve prize odds.
  Prize events therefore run on **standardized loadouts** in a **mirrored
  layout**: every entrant flies the same spec ship in an identical instance
  with the objective hidden in the same place. This satisfies the sweepstakes
  "no purchase necessary / equal dignity" requirements, neutralizes
  pay-to-win, and gives a casual player a real shot against a maxed grinder.

- **I-6 — Capsules are rare; rumors are common.** A capsule found daily is a
  wage, and wages are not treasure. The daily loop is carried by intel decay,
  partial coordinates, and sector whispers — anticipation is the content, the
  find is the crescendo. Tuning targets live in §4; the invariant is the
  ordering: rumor frequency ≫ capsule frequency.

- **I-7 — Server behavior gets the harness treatment.** Every server rule gets
  a contract test, red-verified, in a suite the sweep can run against a local
  server stub. The lessons already paid for apply verbatim: an observation is
  not an assertion; a green check on a world where the defect cannot express
  itself is worth nothing; a baseline is a measurement with an age on it.

- **I-8 — Counsel gates money.** No stage that moves real money ships without
  a review of the official rules and structure by a gaming/promotions
  attorney, and payouts are geo-gated to jurisdictions where the structure is
  clean. One review per structure, not per event — the point of using
  recognized legal categories is that the review is bounded.

---

## 2. Stage 0 — The Registry (the thin claims server)

**The cheapest test of the whole thesis.** Before any economy or prize work,
prove that shared stakes change how long people play.

Scope:

- Lightweight accounts (email or OAuth; no KYC yet — no money exists yet).
- A claims API: `has anyone charted <system>?` and `file my claim, timestamp
  me`. First-charted names render on every player's chart: *"First charted by
  KESTREL-9, 2026-11-02."* Permanent.
- A season leaderboard: deepest verified sounding, most first-charts, most
  distinct bands visited. Seasons reset; etched names do not.
- Basic abuse controls: rate limits per account, claim verification against a
  plausible flight envelope (a claim 4,000u out five minutes after account
  creation is a lie the server can detect from physics alone).

Client work: a claims panel, chart annotations, an online/offline indicator
that degrades gracefully (I-1: offline play never blocks on the server).

Explicitly out of scope: currency, capsules, prizes, subscriptions.

**Gate to Stage 1:** measured retention delta. Instrument D1/D7/D30 for
account-holders vs. anonymous players, and claim-engagement (% of players who
file ≥1 claim; % who return within 48h of being *beaten* to a claim — the
rivalry signal). If names-on-charts and leaderboards move nothing, real money
will not rescue the loop — money amplifies rivalry, it does not create it —
and this horizon stops here cheaply, having still shipped a good feature.

---

## 3. Stage 1 — The Rumor Economy

Server-placed capsules paying **earned-only** closed-loop currency, plus the
intel layer that makes rarity feel alive daily.

Deliberate sequencing: currency exists in this stage but **cannot yet be
purchased**. The faucet opens before the store does, so the economy's feel is
tuned while the currency is worthless in real terms — every tuning mistake in
this stage is free.

Scope:

- **Capsules.** Server-placed (I-2), band-weighted toward the deep, cracked
  via an interactive sequence (a human-paced challenge, one more bot hurdle),
  paying tiered closed-loop currency. Placement density is a server dial, not
  a client constant — rarity tuning must never require a client patch.
- **The rumor layer.** Reuse the Hunt dossier machinery — the estimator, the
  search circle that narrows and never lies, purchasable readings — pointed at
  capsules. Rumors decay; derelicts yield partial coordinates; ports sell
  stale whispers cheap and fresh ones dear. The existing `INTEL NARROWS AND
  NEVER LIES` discipline carries over as a server contract: intel may be
  vague, never false.
- **Near-miss telemetry.** Log when players search near an unfound capsule.
  This is the tuning instrument for I-6, and later the anti-bot baseline for
  what human search patterns look like.

Rarity starting posture (tune from telemetry, not argument): a mid-skill
player engaging the rumor layer should brush a capsule's search circle
weekly and find one roughly monthly; finds should be server-announced
("a capsule was cracked in THE UNSOUNDED") so everyone feels the economy
moving even in a dry month.

**Gate to Stage 2:** % of active players engaging the rumor layer weekly, and
the retention curve of players in the week after a *near miss* (the mechanism
works if near-misses retain almost as well as finds).

---

## 4. Stage 2 — The Store

Currency purchase and the sinks that keep the loop hungry.

- **Payments:** web checkout (Stripe or equivalent) on the game's own site.
  No app stores (deferred by design). Purchases are one-way (I-3).
- **Sinks, in priority order:**
  1. **Private PYX regions** — the flagship sink. Spend currency to spin up an
     invite-only region with its own seed, its own capsule seeding (in-game
     currency prizes only — a paid-entry private region with prizes is
     hosting gambling, recorded here so it is never "discovered" as a
     feature), configurable rarity, and a private leaderboard. This is the
     casual player's winnable pond and the friend-group party mode.
  2. **Liveries and cosmetics** — the accent system already in the game grows
     a premium tier. Winner-exclusive liveries exist but are never
     purchasable (status must be earned or it is not status).
  3. **Ship slots / hangar** — parallel fits without regrinding.
  4. **Convenience** — never power: chart annotations, route bookmarks,
     capsule-rumor push notifications.
- **What currency never buys:** prize-event advantage (I-5), progression
  power that gates prize-relevant content, or anything transferable.

**Gate to Stage 3:** conversion rate to first purchase, sink absorption (does
currency pool in wallets or get spent — pooling means weak sinks), and private
region creation/joins. A healthy Stage 2 funds the prize budget out of margin.

---

## 5. Stage 3 — The First Derby (run by hand)

The first real money, structured as a **free-entry sweepstakes**, operated
manually to measure demand and ops load before any automation is built.

Structure (each element is doing legal or design work; change none of them
casually):

- **Free entry for everyone** — no purchase, no subscription requirement; a
  free entry route with equal dignity is what makes this a sweepstakes and
  not a lottery (it removes "consideration").
- **Spec loadout, mirrored layout** (I-5): every entrant flies the same ship
  into an identical instance; the derby capsule is hidden in the same spot for
  all. Fastest verified crack wins. Among entrants, outcome differences are
  skill and persistence, not luck of the draw.
- **Official rules**, attorney-reviewed once (I-8): eligibility, geo-gating
  (exclude jurisdictions with sweepstakes registration regimes — e.g. Quebec;
  revisit list with counsel), prize schedule, verification, tax handling.
- **Prize seeding:** a handful of $10–$100 capsules and one $250 headline.
  Total exposure per event ≈ $400–500. At solo-dev scale this is a marketing
  budget, and it is spent as one: every winner is a story.
- **KYC at payout, not at signup.** Winners verify identity to be paid — this
  is simultaneously the tax-compliance step and the multi-account defense
  (one identity, one payout, ever, per event).
- **Winning is loud.** Winner's name broadcast on every chart, an earned
  derby livery, a permanent hall-of-fame record. The cash is the trophy's
  certificate of authenticity; the status is the prize (see §11 — at $25–250,
  the money cannot be the motivation and must not be framed as one).
- **Run it by hand:** entry via form, winner verified from server logs, paid
  by ordinary transfer, congratulated personally. No payout rails, no
  automation. Measure everything, including your own hours.

**Gate to Stage 4:** entrants per event, new-player signups attributable to
the event (the acquisition claim), repeat-entry rate (the retention claim),
ops hours per event, and zero credible cheating incidents. Three or four
hand-run derbies constitute the dataset; automation before that is premature.

---

## 6. Stage 4 — Cadence and Subscription

Only after derbies prove demand:

- **Automation** of entry, instance provisioning, verification, and the
  hall of fame. Payouts can stay manual far longer than intuition suggests —
  a monthly event with a dozen winners is an hour of admin.
- **A public cadence** — e.g. monthly derby, quarterly "expedition" with the
  scaled headline prize. A published cadence is a promise; the schedule is
  sized to what one developer proved sustainable in Stage 3, not to ambition.
- **Subscription launch:** cosmetics track, private-region allowance,
  convenience bundle, supporter badge. Never odds (I-5). The subscription
  funds the business; the prize line is a marketing expense from revenue —
  self-funding at roughly 100–150 subscribers at $5 against a $500/month
  prize budget, subsidized before that as launch marketing.
- **Seasons** unify the layers: leaderboards reset, a new deep-space band or
  storm pattern headlines, the season's derby calendar is published.

---

## 7. Stage 5 — Paid-entry skill tournaments (EXPLORATORY; parked)

Recorded because it is the one legitimate structure that gets closer to
"players stake money, winners take it," and because if the appetite proves
real it is the direction that does not require becoming a casino.

The established model (Skillz and similar platforms process real-money
entry-fee tournaments at scale): games of **predominant skill** with entry
fees are lawful in most US states and are geo-fenced out of the ~5–10 that
disagree. The derby format is already shaped for this argument — spec
loadouts and mirrored layouts mean every entrant faces *identical*
conditions, so chance is equalized across the field rather than argued away
(the duplicate-bridge principle). Same-conditions, compare-performance is
exactly the structure the skill-gaming industry runs on.

Parked because: it reintroduces per-state legal analysis, payment-processor
gambling scrutiny, and refund/dispute ops; and because Stages 3–4 deliver
most of the motivational payload without any of that. Unpark only if derby
demand is proven and repeat entrants are asking to stake — and then only
with counsel, geo-fencing, and probably a specialist platform partner rather
than in-house rails.

---

## 8. Parked permanently (unless the business itself changes)

- **The MMO.** The thin server delivers the rivalry; a shared simulation
  delivers mostly cost.
- **Player-pooled prize pots.** Consideration + chance + prize = lottery.
  No accounting structure launders this; "the pool is separate from the
  subscription" is a fiction regulators are specifically practiced at
  piercing.
- **Cash-out or transferable currency.** See I-3. This is the sweepstakes-
  casino model, and 2026 is the year states began banning it by name.
- **Prediction-market anything.** Their legality is not a loophole — it is a
  federal exchange license (CFTC-designated markets), currently mid-fight
  with state regulators, and structurally unavailable to a game studio
  listing outcomes of its own game.
- **App-store distribution** until the economy is proven and stable.

---

## 9. Threat model — bots, cheats, fraud

Real value attracts automation; a browser client is the easiest platform to
bot. Posture, in order of leverage:

1. **Server placement (I-2)** — the location of anything valuable simply is
   not in the client. The seed-mining attack dies here.
2. **Episodic events (I-4)** — a bounded, instanced, spec-loadout derby is a
   small arena the server fully observes, versus an open world it cannot.
3. **Physics plausibility** — the server knows the flight envelope; claims
   and search queries inconsistent with reachable positions are rejected and
   flagged. (The Stage 1 near-miss telemetry doubles as the human-behavior
   baseline.)
4. **Interactive cracking** — capsule and derby cracks are human-paced
   interactive sequences, not a stateless API call.
5. **Rate limits** per account and per IP range on every claims/intel query.
6. **KYC at payout** — the identity chokepoint. Fifty accounts can search;
   one identity gets paid.
7. **Delay-and-review** — derby results are provisional for 48h; logs are
   reviewed before money moves. At hand-run scale this is a human reading a
   log; it never needs to be faster than that.

Accepted residual risk: closed-loop currency botting in the open world. It is
deflationary damage, not theft, and it is tunable at the server dial. Do not
spend prize-grade defenses on it.

---

## 10. Compliance ledger

Recorded so the reasoning survives contact with future enthusiasm. (Design
rationale, not legal advice; I-8 puts an attorney between this document and
any shipped money structure.)

- **Why not pooled player money:** lottery (consideration, chance, prize).
- **Why not "skill makes it legal" for open-world capsule hunts:** the
  dominant-factor test asks what separates *winner from losers among
  entrants*; when the capsule's location is random and searchers are
  comparably skilled, that factor is chance. The derby's mirrored layout
  exists precisely to change this answer.
- **Why not purchased-currency entry to chance-seeded hunts:** paying for a
  randomized reward is regulated as gambling in several jurisdictions
  (Belgium, Netherlands) even closed-loop; keep purchased currency out of
  chance-gated *entry* everywhere, not just there.
- **Why not the dual-currency sweeps model:** redeemable currency is the
  defining feature of the sweepstakes-casino category that states banned
  throughout 2025–26 (Indiana, Iowa, Louisiana, Maine, Oklahoma, Tennessee
  in 2026 alone). Pyxis currency is not redeemable (I-3), which keeps the
  product outside those statutes' definitions — and must stay so.
- **Why free-entry sweepstakes work:** removing consideration removes the
  lottery structure; equal-dignity free entry is the load-bearing element,
  which is why I-5 is an invariant and not a preference.
- **Winners' tax paperwork** (US: 1099-MISC territory at ≥$600/year to one
  winner) and geo-gating live in the official rules; revisit annually.

---

## 11. The psychology ledger

Also recorded so it is not re-litigated by intuition later:

- **$10–$250 is a trophy, not income.** Any player who computes $/hour on a
  capsule hunt sees a bad job. The design therefore never advertises expected
  value; it advertises *stories* — named winners, etched charts, screenshots.
- **Small extrinsic rewards can displace intrinsic motivation** (the
  overjustification effect). Confining cash to episodic celebration events
  (I-4) is the mitigation, and it is load-bearing.
- **Winner-take-all with an invisible field churns casuals.** Mitigations:
  tiered prize distribution (many small, few large), seasonal resets,
  private regions as winnable ponds, and spec derbies where gear cannot bury
  a newcomer.
- **Near-misses do the daily retention work** — the rumor economy is the
  product; the capsule is the punctuation.

---

## 12. Testing implications

The house rules extend to the new surface:

- **`PYXIS_CLAIMTEST`** against a local server stub: claims are first-write-
  wins; a beaten claim reports the earlier timestamp; offline play never
  blocks on the registry; the chart annotation renders the server's answer
  and never a cached lie.
- **Server contract suite** (runs in the server repo, mirrored as a stub
  locally): capsule reveals require plausible position; rate limits actually
  limit (red-verify by exceeding them); intel is vague-never-false — the
  server-side descendant of `INTEL NARROWS AND NEVER LIES`; a rejected claim
  cannot mutate state.
- **`PYXIS_DERBYTEST`**: spec loadout is actually pinned (assert the fit
  cannot drift from the spec — the `MINING COSTS A MOUNT` stale-name lesson
  applies: pin to named constants, not list-ends); mirrored instances are
  bit-identical across entrants (WORLD FINGERPRINT, repointed); the crack
  sequence cannot complete in fewer than its designed human-paced steps.
- **Economy assertions**: no code path grants transferable or redeemable
  premium currency — an `ATTRIBUTION IS EXPLICIT`-style source-reading
  assertion is appropriate here, because a call site that is never exercised
  cannot be caught any other way, and I-3 is exactly the kind of invariant a
  well-meaning feature would violate in a dead path first.
- **Telemetry is observation, not assertion** — the near-miss logs inform
  tuning but the sweep's PASS/FAIL never depends on live-service data. The
  `TUTORIALTEST sentries=0` lesson: anything that matters gets promoted to an
  assertion somewhere, or it will be printed and ignored for four stages.

---

## 13. Open questions

- Account identity for a browser game: how little can Stage 0 ask for and
  still support KYC-at-payout later without a migration?
- Where does the claims server draw the "charted" boundary — per system, per
  band, per structure? (Density determines how fast the frontier's names fill
  in, which is a pacing decision as much as a technical one.)
- Does the derby run synchronously (everyone at 20:00 UTC, strongest event
  feel, worst for time zones) or as a 24h window with fastest-completion
  scoring (fairer, weaker spectacle)? Leaning window-first for a solo dev.
- What does the rumor economy price intel in — salvage credits (binds it to
  the existing economy) or premium currency (stronger sink, but flirts with
  paying-for-chance; see §10)? Leaning salvage credits, hard.
- Season length: 8 weeks vs. quarterly. Shorter seasons suit a small early
  playerbase (more restarts, more winnable moments).

---

*Companion documents when work begins: a server architecture note (stack,
hosting, cost ceiling) and the derby official rules draft for counsel review.
Neither belongs in this file; this file is the design record.*
