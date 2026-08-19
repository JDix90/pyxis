# Horizon 8 — The Closed File

**Status: SPECCED, nothing built. Commit 0 is gated on the prose read-aloud
(`docs/DIRECTIVE-NINE-DRAFT.md`, decisions R1–R4).** When any of it is adopted,
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
| 0 | The second register — bands 5/6 after-lines, the Commission's unset field, one bark, one log line | **none** | The reveal itself. Data and copy; derived entirely from v23 `deep_logs` |
| 1 | The refusers' network — Directive 9 pages on foreign beacons | **none** | Needs the register to exist so the pages are corroboration rather than exposition |
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

## Commit 0 — the second register

**The gate, derived rather than hardcoded:**

```gdscript
func knows_directive_9() -> bool:
    # Any system's bearing-terminus record, held to fragment 2 or past it.
    # Derived from the data so a future system authoring the "return" datum
    # is covered without a second place to edit.
```

`GameState`, beside the v23 store it reads. Zero new save, and a pilot who
already read the fragment is already carrying the flag.

**Where the words live.** `broadcast_for` already resolves optional keys with a
fallback — *"a second array would be a second bounds contract that could
disagree with the first"* — so bands 5 and 6 gain `from_after` / `body_after`
and inherit that whole argument. The commissioned overlay and the per-system
override both keep their current precedence; the after-register only ever
applies to rows that authored one, which is two rows in the whole table.

**Everything else is one label and two strings:** the Commission page's unset
`RETURNS LOGGED` field (see R4 — I recommend always visible), one `Barks` key,
one `note_log` line at the moment the fragment is read.

**Harness — new tag `PYXIS_DIRECTIVETEST`:**

- `THE MACHINES DO NOT KNOW` — bands 1–4 resolve byte-identical before and
  after the gate, in every system, commissioned and not. The load-bearing one:
  it is the design rule as an assertion, and it goes red the moment somebody
  "finishes" the table. Red-verify by authoring a `body_after` on band 1.
- `THE LIVING VOICES ANSWER` — bands 5 and 6 differ across the gate, and both
  halves are non-empty (an after-line that is accidentally empty would pass a
  one-sided "they differ" check).
- `THE GATE IS THE ORDER` — flips exactly on `return` stage 2: false at stage 1,
  true at 2 and 3, and true for a record read in any system that authors the
  datum. Driven through `note_deep_log`, not by writing the store.
- `THE REGISTRY NEVER ADDS UP` — the Commission page renders the unset field,
  and it is still unset after selling charts (whatever the pilot files, that
  field does not move — it is not a counter).
- `NOTHING NEW IS STORED` — the save dict is byte-identical before and after
  reading the order, beyond the `deep_logs` entry §91 already asserts. The whole
  claim of this commit is "no save", and a claim like that wants a check.

---

## Commit 1 — the refusers' network

Foreign beacons (§84) gain a second verb. The recovery refusal stays exactly as
it is — *"NOT YOUR ANCHOR CODE — THIS BEACON ANSWERS TO SOMEBODY ELSE"* — and
the read is a separate, shorter hold that costs nothing and pays nothing.

**Which page a beacon carries is a pure function of its cell key.** The rival's
covenant, unchanged: zero bytes of save, no store, no completion tracker. The
Authority's records persist; the refusers leave nothing behind. A player who
wants the whole order flies until they have seen six different beacons, and the
game never tells them how many they are missing.

**Harness legs:** `EVERY PAGE IS REACHABLE` (the pure function covers all six
across a sweep of cell keys, and the distribution is not degenerate),
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
