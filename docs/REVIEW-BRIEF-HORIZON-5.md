# Review Brief — Pyxis / Horizon 5 ("The Claim")

You are a panel of independent consultants engaged to review a game project
and a transformation plan **before any implementation begins**. Your client is
a solo developer. Your job is not to encourage him — it is to find what is
wrong, weak, unverified, or missing while changes are still cheap. A review
that returns only praise is a failed engagement.

## The subject

**Pyxis** is a single-player salvage-cartography game (Godot 4.6, portrait
720×1280, browser-first with mobile planned). The player flies a survey vessel
past the edge of charted space, cracks derelicts, and sells charts of places
nobody has filed a return from. The world is fully deterministic and
client-side, generated from a seed. The project has an unusually rigorous
assertion culture: ~616 headless assertions across 62 runs, every one
red-verified, with the design record kept in numbered sections of
`docs/STRATEGY.md`.

**Horizon 5** (`docs/HORIZON-5-THE-CLAIM.md`) proposes transforming Pyxis
into a shared-stakes game without an MMO: a thin claims server (first-charted
names on every player's chart), server-placed treasure capsules paying a
closed-loop premium currency, a daily rumor/intel economy, purchasable private
regions, subscriptions, and episodic real-money prize events ("derbies")
structured as free-entry sweepstakes with spec loadouts and mirrored layouts.
Real-money paid-entry skill tournaments are specced but parked as Stage 5.

## Required reading, in order

1. `README.md` — the project's shape and its testing culture.
2. `docs/STRATEGY.md` — skim the numbered record; read §64 (the only
   forward-looking inventory), §33, §38, §41, §54, §62–§71 closely.
3. `docs/HORIZON-3-COMMISSION.md` and `docs/HORIZON-4-FACTIONS.md` — to
   calibrate what a shipped horizon looks like in this repo.
4. `docs/HORIZON-5-THE-CLAIM.md` — the plan under review. Read all of it,
   including the invariants (I-1 … I-8), the compliance ledger (§10), the
   psychology ledger (§11), and the testing implications (§12).
5. `scripts/` — enough of `main.gd` and `scripts/data/` to verify that
   claims the plan makes about existing systems are true.

## Ground rules

- **Verify, don't trust.** The plan asserts things about the codebase (e.g.
  "the Hunt intel dossier machinery can be repurposed for capsule rumors,"
  "deep space persists nothing," "the save schema needs no bump for X").
  Check these against the actual code and the STRATEGY record. Every claim
  you affirm or refute must cite a file and section/line.
- **Attack the invariants.** I-1 through I-8 are presented as non-negotiable.
  For each: is it actually load-bearing, is it sufficient for what it claims
  to protect, and is it enforceable by an assertion or only by vigilance?
  Endorse or challenge with reasons. Exception: do not propose weakening the
  legal invariants (I-3, I-4, I-5, I-8) on cleverness grounds — if you think
  one is over-conservative, say so and route it to "requires counsel," don't
  redesign around it.
- **Separate fact, inference, and opinion** — label each finding accordingly.
- **This client's culture punishes vague findings.** "The economy might not
  work" is worthless. "Stage 1's weekly-brush/monthly-find rarity target
  implies N active capsules for a P-player population, and §4 never states
  how density scales with population, so the first 50 players either strip
  the map or never find anything" is a finding.
- **You are not the client's lawyer.** Sanity-check the legal reasoning's
  internal consistency and flag anything that looks wrong or missing, but
  frame legal conclusions as "verify with counsel," not as advice.

## Review dimensions — assign at least one reviewer to each

**A. Game design & player psychology.** Does the rumor economy actually
carry a daily loop when capsules are ~monthly? Is the near-miss retention
hypothesis (§3 gate) plausible and measurable? Do spec derbies undermine the
progression game they sit beside (why grind a Mk III if the prize arena
ignores it)? Does asynchronous rivalry fit a game whose stated emotional core
is solitude — "the less anyone is watching" — or does it damage the fantasy
the game rests on? Is the casual-vs-grinder analysis honest?

**B. Economy & monetization.** Stress the faucet/sink balance: Stage 1 opens
the faucet with no store; Stage 2's sink list — is it strong enough to
absorb it? Is 100–150 subscribers at $5 against ~$500/month prizes the right
break-even math, and what CAC/conversion assumptions hide inside it? Is the
private-region price point doing two jobs (sink + party mode) that want
different prices? What does this look like at 100 players? At 10,000?

**C. Server & client architecture.** The plan bolts a claims/capsule server
onto a deterministic offline client. Identify every place the two worlds must
agree (position plausibility, band boundaries, "charted" granularity, save
compatibility) and what happens when they disagree. Evaluate the offline-first
degradation story, the Godot-browser-client-to-server auth story, and whether
the proposed contract-test approach (§12) can actually run in this repo's
harness culture (headless, assertion-based, red-verifiable, no test
framework). Estimate hosting cost and single-point-of-failure exposure for a
solo operator.

**D. Security, anti-cheat, fraud.** Red-team §9. The client is a browser
game; assume hostile players with full client source, headless automation,
and 50 accounts. Can the physics-plausibility check be gamed by a bot that
simply flies plausibly? Is the interactive crack sequence actually
bot-resistant or just bot-annoying? Does KYC-at-payout deter or merely
inconvenience multi-accounting for $250? What attack does §9 not list?

**E. Legal & compliance coherence.** Check §10's reasoning for internal
consistency and completeness (not for correctness as legal advice): does the
free-entry/equal-dignity derby structure as specced actually keep purchased
advantage out of prize odds everywhere — including intel, notifications, and
private-region practice? Are there jurisdictions or mechanisms (loot-box
adjacent rules, minors, payment-processor policies, prize-notification laws)
the ledger omits? Is Stage 5's duplicate-format skill argument coherent as
described?

**F. Delivery risk & the solo developer.** The plan is five gated stages plus
live-service operations, proposed by and for one person who currently ships a
game that can sit untouched for a month. Estimate the standing weekly ops
load at each stage. Identify the earliest stage at which a two-week absence
(illness, travel) causes player-visible breakage or a broken public promise.
Are the gates real decision points with kill criteria, or ratchets that only
ever click forward? What is the minimum version of this horizon that tests
the thesis?

## Required output

Produce a single review document containing:

1. **Verdict up front** — proceed / proceed-with-changes / do-not-proceed,
   with the conditions that would change it. Take a position; a hedged
   verdict is a non-answer.
2. **Findings, ranked by severity**, each with: dimension, claim, evidence
   (file + section), severity (blocker / major / minor), and a concrete
   recommendation. Include findings where you checked the repo and the
   plan's claim held — verified-true is information.
3. **Per-stage gate assessment** — for each of Stages 0–4: is the gate
   metric the right one, is it measurable with the instrumentation the stage
   actually builds, and what number would you set as pass/kill.
4. **The five assumptions most likely to sink the horizon**, ranked, each
   with the cheapest possible test that would falsify it.
5. **What's missing** — anything the plan should specify and doesn't.
6. **What to cut** — the plan's weakest element, even if nothing is wrong
   with it, in the spirit of shipping the minimum thesis-testing version.

Do not soften findings because the plan is well-written or because previous
reviewers (including the consultant who drafted it) reached different
conclusions. The drafting consultant's conclusions are claims like any other:
several of this repo's worst shipped defects lived behind well-argued
documents and green checks, and the house rule applies to prose as much as to
assertions — **red-verify everything, and be suspicious when the setup is
elaborate.**
