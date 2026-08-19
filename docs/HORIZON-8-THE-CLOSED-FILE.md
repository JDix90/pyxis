# Horizon 8 — The Closed File

**Status: COMMITS 0 AND 1 BUILT (§92, §93 — no save bump in either). Commits
2–3 specced, nothing built.** The read-aloud answered R1–R4 and set the register rule; the prose in
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
| 2 | Purchasable slot expansion (Utility III, Drive II, Weapon III) | likely **v24** | §64's headline. Touches the fit dict, refit UI, section damage, every BALANCE and PACING assertion |
| 3 | Faction contracts offered on hail | TBD | §64's second act; the offer verb is the one new piece, riding existing contract + faction machinery |

Commits 0 and 1 are small, save-free and independently shippable. Commit 2 is
the largest single mechanical change since the horizon system itself and wants
its own research pass before it is specced in detail — this document does not
pretend to have done that yet.

**Deferred on purpose:** filing returns with the refusers instead of the
Authority. It is the verb the last fragment asks for (*"file a return for us"*),
it rides existing fence machinery, and it must not ship in the same horizon as
the revelation. A discovery that immediately becomes a menu option was never a
discovery.

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
