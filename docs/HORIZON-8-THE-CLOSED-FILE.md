# Horizon 8 — The Closed File

**Status: COMPLETE — all four commits BUILT (§92, §93 — no save bump; §94 —
v24; §95 — no save bump).** The read-aloud answered R1–R4 and set the register rule; the prose in
`docs/DIRECTIVE-NINE-DRAFT.md` shipped as drafted, with one design change found
during the build and recorded there (the per-system override correctly wins on
two of the four living-voice rows, because both of those overrides are
machines). When any of it is adopted,
record it in `docs/STRATEGY.md` §64 in the same commit, per the house rule.

## What this answers

Horizon 7 gave the deep an answer (§91): the frontier was surveyed, measured,
and then classified out of existence. THE LAST RETURN carries the order that did
it, and the player can now read it.

Nothing in the game has heard.

This horizon is that reveal landing, plus the two mechanical items §64 has been
holding since the nine-note playtest. The order matters: the shop feature and
the contract verb both land into a world that has just changed meaning, which is
free flavour for both and costs nothing to sequence that way.

---

## The governing finding

**The authority's voice cannot change, because it is recordings.** `BROADCASTS`
bands 1–4 are an automated beacon, a relay, a degraded relay and a carrier tone;
THE LAST RETURN's final entry already says the machines were never told. So the
chart-edge beacon keeps telling a commissioned pilot *"the bearing is yours, and
it is written down"* forever, in the warm register, and that becomes the most
frightening line in the game the moment the player has seen Directive 9.

What changes is what is alive: bands 5 and 6 (the only broadcasts that were
never the GSA's), the player's own file, and the player's own ship.

The pass therefore has a rule it can be held to, and an assertion that holds it:
**if a recording changed its words, the pass is wrong.**

---

## Commit order

| # | Commit | Save | Why here |
|---|---|---|---|
| 0 | The second register, staged — the private beat at the read, the two living voices at the whole record | **none** | **BUILT (§92)** — the reveal itself. Data and copy; both flags derived from v23 `deep_logs` |
| 1 | The refusers' network — Directive 9 pages on band-3+ foreign beacons | **none** | **BUILT (§93)** — the mid-game hint channel. Built second, but in play it is met FIRST — the pages foreshadow the archive, not the other way round |
| 2 | The berths — a slot AND the power to use it, paid for in permanent mass | **v24** | **BUILT (§94)** — the research below killed the slots-only version; the penalty axis was decided as mass |
| 3 | Commissions — work a faction posts for a pilot it already trusts | **none** | **BUILT (§95)** — standing and contract state both already persist, so the whole commit is behaviour over two existing stores |

Commits 0 and 1 are small, save-free and independently shippable. Commit 2 is
the largest single mechanical change since the horizon system itself; its
research pass is below, and it found that the obvious version of the feature
does not work.

**Deferred on purpose, and now claimed:** filing returns with the refusers is
Horizon 9's spine (`docs/HORIZON-9-THE-TRUE-COPY.md`). The deferral did its
job — the revelation shipped a horizon before the choice it creates.

---

## Commit 0 — the second register, staged

R1's answer is structure, not copy: the reveal lands in three beats that the
geography already orders — pages as mid-game hints (commit 1), the private
realization at the archive, and the world's answer only once the whole record
is held. Commit 0 builds the last two, as **two derived flags**:

```gdscript
func knows_directive_9() -> bool:
    # Any system's bearing-terminus record at fragment 2 or past it. Gates
    # only what is PRIVATE: the bark, the log line, the Commission field.

func holds_whole_record() -> bool:
    # meridian, glass and return all read to stage 3. Gates the two living
    # voices — the world speaks differently only to someone who knows
    # everything, and to no one else.
```

Both in `GameState`, beside the v23 store they read, derived from the data
rather than hardcoded to systems. Zero new save; a pilot who already read the
fragments is already carrying both flags.

**Where the words live.** `broadcast_for` already resolves optional keys with a
fallback — *"a second array would be a second bounds contract that could
disagree with the first"* — so bands 5 and 6 gain `from_after` / `body_after`
and inherit that whole argument. The commissioned overlay and the per-system
override keep their precedence; the after-register only ever applies to rows
that authored one, which is two rows in the whole table.

**The private half is one field, one bark, one log line.** Per R4 the
Commission field is **absent until the order is read** — before, the page is
byte-identical to today's; after, `RETURNS LOGGED FROM THE RECLASSIFIED
VOLUME: —` appears with its plain one-line explanation, corroborating what the
player now knows instead of teasing what they do not.

**Harness — new tag `PYXIS_DIRECTIVETEST`:**

- `THE MACHINES DO NOT KNOW` — bands 1–4 resolve byte-identical under every
  combination of the two flags, in every system, commissioned and not. The
  load-bearing one: it is the design rule as an assertion, and it goes red the
  moment somebody "finishes" the table. Red-verify by authoring a `body_after`
  on band 1.
- `THE WORLD WAITS FOR THE WHOLE RECORD` — bands 5 and 6 are unchanged at
  `knows_directive_9` alone (two archives done, one partial), change only at
  3/3/3, and both halves of each changed row are non-empty. This is the staged
  reveal as an assertion: a wiring mistake that flipped the world on the first
  fragment would land the twist exactly as early as R1 feared.
- `THE GATE IS THE ORDER` — `knows_directive_9` flips exactly on `return`
  stage 2: false at 1, true at 2 and 3. Driven through `note_deep_log`, not by
  writing the store.
- `THE FIELD ARRIVES WITH THE ORDER` — the Commission page carries no trace of
  the field before the flag (the R4 decision as a check), renders it after,
  and the field never changes thereafter — it is a statement, not a counter.
- `NOTHING NEW IS STORED` — the save dict is byte-identical before and after
  reading the order, beyond the `deep_logs` entries §91 already asserts. The
  whole claim of this commit is "no save", and a claim like that wants a
  check.

---

## Commit 1 — the refusers' network, band 3 and deeper

Foreign beacons (§84) gain a second verb. The recovery refusal stays exactly
as it is — *"NOT YOUR ANCHOR CODE — THIS BEACON ANSWERS TO SOMEBODY ELSE"* —
and the read is a separate, shorter hold that costs nothing and pays nothing.

**Only beacons at band 3 or deeper carry a page**, and this gate is R1's other
half. Foreign beacons spawn wherever the rival has filed, from
`CONTENT_MIN_DEPTH` (24u) outward — the shallows go to the rival within single
sessions, so ungated pages would put the order's text at the chart edge inside
the first hours. Band 3 (1,100u+) is where the shipped broadcast arc already
turns strange, so the hints arrive exactly when the game has said things are
no longer fine — and the fiction agrees: you do not leave contraband where the
authority still sweeps. A shallow foreign beacon stays what it is today:
somebody else's furniture, refusal and all.

**Which page a beacon carries is a pure function of its cell key.** The
rival's covenant, unchanged: zero bytes of save, no store, no completion
tracker. The Authority's records persist; the refusers leave nothing behind.
A player who wants the whole order flies until they have seen six different
deep beacons, and the game never tells them how many they are missing.

**Harness legs:** `EVERY PAGE IS REACHABLE` (the pure function covers all six
across a sweep of band-3+ cell keys, and the distribution is not degenerate),
`THE PAGES KEEP TO THE DEEP` (a band-1/2 foreign beacon offers no read — the
pacing gate as an assertion, red-verified by dropping the band check),
`THE PAGES LEAVE NOTHING BEHIND` (reading is save-neutral), and
`A REFUSAL IS STILL A REFUSAL` (the recovery hold still refuses, with its
existing copy, on a beacon that has just been read).

---

## What this horizon must not become

- **A faction to join.** The moment there is a side, this is a space shooter
  with lore, and the thing that makes it frightening — that the horror is
  administrative, finished, and unopposed — is gone.
- **An explanation.** No surface states that the GSA lied. The register changes
  a word; the player does the rest. Every line in the draft that explains was
  cut or flagged (R2).
- **A tracker.** No "pages 3/6" counter, no HUD element, no Commission stage for
  the order. The Commission's statement-of-record posture (§90) holds.
- **A completed table.** Bands 1–4 stay silent for the same reason band 4 has no
  commissioned line: *"Do not 'finish' this entry."*


---

## Commit 2 — the berths (research pass, 2026-08-19)

### The finding: the top of the game already has a slot it cannot fill

Power is the binding constraint on fitting, and it is protected by a live
assertion. `ALL-BEST IS STILL OUT OF REACH` measures greedy best-per-slot at
**32 power against the Mk V reactor's 24** — a margin of 8, green on every
sweep, computed from the live catalog rather than from a constant.

`module_db.gd` spells out the top-end product in its own words: two Mk III
mounts (6 + 7), a Vector Mk II (4) and an Aegis (4) is 21, plus exactly one
3-power tool makes 24 — *"and the second utility bay still empty. That is the
entire product."*

So a pilot at the top of the game **already owns a slot the reactor cannot
feed**. Selling them a Utility III for ninety thousand credits would be selling
a bay that stays empty: the players most likely to buy the upgrade are exactly
the players it does nothing for. The obvious version of this feature is a
confusing purchase, not a powerful one.

That is not an argument against the playtest note. It is the note's real
content. What was asked for underneath *"purchasable extra slots"* is **more
ship** — slots are simply how the refit console renders that idea.

### Three shapes, and what each actually sells

| | what it sells | verdict |
|---|---|---|
| **A. Berths** — a slot AND power together, paid for with a permanent penalty in another axis | more ship, at a stated cost | **recommended** — real at every tier, and the penalty is what keeps all-best out of reach |
| **B. Slots only** | flexibility the reactor cannot power | rejected — dead exactly where it is most expensive |
| **C. Power only, no new slots** | fills the bay that is already there | answers the constraint but leaves the note unanswered and adds no decision |

Under A, `ALL-BEST IS STILL OUT OF REACH` stays the governing invariant: every
berth raises the cap by less than the best module that could occupy its slot,
so the margin narrows and never closes. The assertion is re-derived across all
berths bought rather than re-pinned to a new constant.

### What the code says about the change (findings, not plans)

- **`compute_stats` hardcodes two slot lists** (`[WEAPON_A, WEAPON_B]` and
  `[DRIVE, UTILITY, UTILITY_B, CORE]`). A new slot added to the enum and
  forgotten here would be purchasable, equippable, powered — and contribute
  **nothing**, silently. Both lists should be derived from `SLOT_CATEGORY` in
  the same commit, with an assertion that every slot reaches the stats.
- **`power_draw` iterates `fit`** and is slot-agnostic. Nothing to change.
- **Sections govern SYSTEMS, not slots** (`dps`, `speed`, `shield`, `core`), so
  section damage needs no new rows for new slots.
- **`refit_panel` builds chips from `SLOT_NAMES` into an HFlow**, which its own
  comment says was chosen because *"six chips no longer fit an HBox"* — more
  chips wrap without layout work.
- **The count 6 is pinned in three places**: `SECOND SLOT` asserts
  `SLOT_NAMES.size() == 6`, the manual prints the count, and a UITEST leg
  checks the refit sheet mentions it. All three want to become "the number of
  slots this pilot has", not a literal.
- **Save (v24)**: which berths are bought. The loader must also refuse a fit
  that names a slot the pilot has not bought — otherwise a hand-edited save
  grants free slots, and `can_equip` is not the only door into `fit`.

### The decision this needs before it is built

**What the berth costs.** The credit price is the easy half; the permanent
penalty is the design. Candidates, all of which the existing floors machinery
(`enforce_floors`) already supports:

1. **Mass** — each berth costs max speed. Reads as a heavier ship, hits the
   axis the deep punishes most (a slow ship in band 5 is a dead ship), and is
   legible on the refit sheet's own delta rows.
2. **Hold** — each berth costs cargo space. Hits the income loop directly, so
   it trades combat capability against how much a run pays.
3. **Integrity** — each berth costs hull. Simple, but it makes the upgrade read
   as a downgrade in the one number a new player watches.

Recommendation: **mass**. It is the axis the frontier already tests, it makes
the fully-berthed ship a deliberate choice rather than a strict upgrade, and it
cannot be bought back — which is what makes it a trade rather than a tax.

**DECIDED: berths, paid for in mass** (2026-08-19). Shipped as §94; the table
of prices, power and speed costs lives there and in `ModuleDB.BERTHS`.
