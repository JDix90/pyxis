# Horizon 3, part 2 — The Grand Commission (SPECCED, NOT BUILT)

Status as of the end of the 2026-07-28 session: **the captain's log shipped
(save v12), the deep-hulk money-printer fix shipped, and the Commission is fully
designed and adversarially reviewed but no code has been written for it.**

This file exists because that design cost two reconnaissance passes and a long
adversarial pass, and all of it was living in a session transcript. Everything
below is settled unless marked otherwise.

---

## 1. The names — settled with the user, do not re-litigate

The scheme is **"what the register says about you."** Four past participles:
each is something the Galactic Survey Authority already did to your record, not
something you are being asked to do.

| # | name | citation clause |
|---|---|---|
| 1 | **ON FILE** | for the first charts filed beyond the marker |
| 2 | **CORROBORATED** | for surveys the Authority could check against its own |
| 3 | **COMMENDED** | for a body of work past the last repeater |
| 4 | **COMMISSIONED** | for a frontier that is no longer blank |

Two schemes were rejected: a **class ladder** (COMMISSION, FOURTH CLASS →
FIRST) because four near-identical strings differing by one numeral are exactly
what a battle-pass tier list looks like, and **document names** (ENTERED IN THE
REGISTER, THE SURVEY OF RECORD) because the strings are too long for a 720-wide
portrait sheet.

**Why the grammar is load-bearing.** §5's tripwire is *if any stage description
needs an imperative verb, it has become a quest.* With past-participle names, an
imperative description clashes audibly with the name directly above it — the
rule enforces itself in the copy instead of relying on discipline. It also sets
up the finale: the commissioned beacon says *CHARTS ON FILE*, and "on file" was
stage one.

## 2. Thresholds

Keys used: `chart_data_sold`, `deepest_depth`, `hulks_cracked`, `posts_cleared`.

**Deliberately excluded.** `tolls_paid` — §26 killed toll-fed XP because a toll
is the losing move, and the same argument applies verbatim to a retroactive
*payout* out of every v10 ledger. `distance_flown` — farmable in circles, the
printer shape §17's leash rule was written against.

| stage | requires | pays | × lance_1 |
|---|---|---|---|
| ON FILE | 8 chart units sold, depth ≥ 1 (past the marker) | 1,800 | 0.31 |
| CORROBORATED | 30 units, 20 hulls, depth ≥ 160 (THE DRIFT) | 2,200 | 0.38 |
| COMMENDED | 60 units, 45 hulls, 8 posts, depth ≥ 440 (THE REACHES) | 2,600 | 0.45 |
| COMMISSIONED | 100 units, 80 hulls, 20 posts, depth ≥ 1100 (THE QUIET) | 2,900 | 0.50 |

### How these were derived, and the two corrections that shaped them

`PACING_LOOP` budgets `"survey": 2` per eight-minute standard loop and
`survey_mast.gd YIELD_UNITS = 2`, so **a standard loop yields 4 chart units.**
`lance_1` is 5,800 (`module_db.gd`), the unit the pacing band is denominated in.
The full catalog is 337,400 ≈ 20 loops ≈ 2.7 hours.

**Correction 1 — the first draft asked for 320 chart units.** That is 80
standard loops, ~10.7 hours, and because *every counter is run-scoped* it had to
happen inside a single survey. 100 units is ~25 loops, which puts the finale
at roughly the same length as buying the whole catalog. That is the right size
for a *Grand* Commission: it finishes when the game does.

**Correction 2 — ON FILE's fiction did not match its number.** The clause says
"beyond the marker", and the marker is the band-1 beacon, which fires at any
depth above zero. The first draft required depth 160 — two bands out — so a
player could cross the marker, file ten Shoal surveys, and be told they had not
done the thing the stage describes. ON FILE now requires depth ≥ 1 and
CORROBORATED carries the 160. "Past the last repeater" on COMMENDED is likewise
literal: `BROADCASTS[2]` is *GSA RELAY — LAST REPEATER* and fires at 160, so
COMMENDED's 440 is genuinely past it.

**Pacing.** Worst first-claim lump (a preloaded ledger claiming all four at
once) = 9,500 = 1.64 × lance_1, under the apex first-kill bonus of 15,000. The
apex bonus is excluded from `PACING_LOOP` **by omission** — `earned` at
`main.gd:6965` is a hand-written six-term sum — and a Commission claim takes the
same route. Note the loop currently measures 2.87 × lance_1 against a 3.00
ceiling: it is at 96% of its cap, so nothing may be added to `PACING_LOOP`.

**A number to fix later.** These were derived from harness output, not from
play. The phone-performance and playtest pass deferred from Horizon 1 has still
never run. Written as named constants so a playtest moves four numbers in one
place.

## 3. State — and the one open decision

- **`commission_claimed`** — int 0..4, counting stages claimed this run, resets
  with the run.
- **`commissioned`** — a separate **persistent** bool, not run state, following
  the livery/ship_name precedent: what you earned outlives the run that earned
  it. A new top-level save field, so **SAVE_VERSION 12 → 13** with a `migrate12`
  mode proving a v12 save arrives uncommissioned.

> **OPEN:** the original plan put `commission_claimed` in `DEFAULT_LEDGER` as a
> seventh key. The adversarial pass argues against it: the ledger's load merge is
> `maxi(0, int(...))` — a floor with no ceiling — so a hand-edited `99` reaches
> `STAGES[99]` and crashes *at a dock*, and the SAVETEST write leg assigns a
> literal six-key dict, so a seventh key would silently round-trip untested,
> quietly dropping §22's six-distinct-sentinels doctrine to six-of-seven.
> Two ways to resolve, both defensible:
> **(a)** keep it in the ledger as originally specced and add an explicit
> `clampi` after the merge plus a seventh sentinel in both SAVETEST dicts; or
> **(b)** make it a top-level field beside `commissioned`, cleared in
> `reset_to_starter`, loaded as `clampi(..., 0, STAGES.size())` — which is
> exactly the reasoning already written into `game_state.gd` for `captains_log`.
> **Ask the user before choosing** — (a) honours the written plan, (b) is
> consistent with what shipped last.

**Write this rule down in code:** `commissioned` is a strict monotone derivative
of "stage 4 was ever claimed". It is read **only** by the title screen, the
accent lock and the beacons. The claim counter must never read it, or stage 4
becomes unclaimable on every run after the first.

## 4. Rendering

A `"commission"` service on the Anchor, appended (**not** prepended —
`port_panel.gd:224` makes `services()[0]` the landing tab), plus one
`_build_commission()`. Three edits in `port_panel.gd`: a `TAB_LABELS` entry, a
`match _tab` arm, and the builder. **All three are mandatory** — see finding 5
below.

Not the Contracts machinery: contracts are per-system board state and would make
the citation re-roll with the board.

**No HUD tracker row, ever.** A locked stage prints its shortfall as a statement
of record ("44 OF 60 SURVEYS ON FILE"), never as an instruction — the archeology
"12 TO NEXT" posture. `hud.band_controls()` is the complete inventory of
centre-anchored plates and `BANDS CLEAR` measures against it, so a tracker row
would have to be added there — which makes the prohibition mechanically
checkable rather than a promise.

## 5. The finale — recognition, not a module

1. **Registry line on the title screen.** Follow `title_screen.gd:198`'s
   `has_save` rule, or the registry line renders above a hidden ledger line.
2. **A ninth livery accent, "REGISTRY".** `LIVERYTEST`'s 8/8/64 assertions
   become 8/9/72; `port_panel.gd:842`'s `grid.columns = 8` should become 9 or the
   accent row wraps one orphan swatch.
3. **The beacons answer back**, for bands 1–3 only. Band 4 (THE QUIET) stays
   silent because nothing out there is transmitting — `GUARD_DESIGNATION[4]` is
   already *"UNREADABLE — IT DOES NOT ANSWER"*, so the data agrees with the
   fiction.

> **Say this out loud in STRATEGY, or the next reader will "fix" it:**
> COMMISSIONED requires reaching THE QUIET, which is the one band that will
> never acknowledge it. That is the intended note the arc ends on, not an
> oversight.

## 6. The adversarial pass — findings to implement

Ranked. Each is verified against the code, not speculative.

1. ~~**Deep hulks re-crack for full loot.**~~ **FIXED AND SHIPPED** this
   session — see STRATEGY §27. It had to land first because the Commission gates
   money on `hulks_cracked`.
2. **The accent lock cannot live in `set_livery`.** `player_ship.gd:188` reads
   `Palette.livery_accent(GameState.livery_index("accent"))` directly and never
   asks `set_livery` anything; the load merge at `game_state.gd:1212-1216` is the
   only int in `load_game` with no clamp. A hand-edited save never calls
   `set_livery`. **Gate at the load path and/or a single `accent_index()`
   accessor both renderers go through.** Assert against the *ship material*
   (`LIVERYTEST` already has `_ship_hull_color`), not the stored int, with
   fixtures at `accent: 8` and `accent: 17` — `posmod` wraps, so 17 is the same
   attack.
3. **`_apply_paint` spends before it applies** (`port_panel.gd:868-886`). If
   `set_livery` gains a silent refusal, a locked swatch charges 800 and does
   nothing. §12: "a hidden bad bet is a con." Eligibility check goes **above**
   `spend_salvage`, and the swatch needs a locked style — note that
   `_swatch_grid` overrides the `disabled` stylebox with the *same* box as
   `normal`, so `b.disabled = true` is currently invisible.
4. **`DEEPTEST` §31 pins the band-1 beacon text** — `main.gd:5091-5092` requires
   the substrings `"charted space"` and `"own risk"`, and `PYXIS_DEEPSHOTS`
   captures the same plate as a golden image. The commissioned rewrite must make
   that assertion conditional and assert **both** states.
   **More important: no harness resets `commissioned`, and `GameState` boots from
   the developer's real save.** The moment the flag exists, `DEEPTEST` passes or
   fails depending on whether you finished the Commission. Every harness touching
   band text or the accent lock must pin `GameState.commissioned` explicitly.
   (`LOGTEST` already does this for `captains_log`; only `PACINGTEST` and
   `TUTORIALTEST` call `reset_to_starter`.)
5. **`_refresh`'s `match` has a catch-all that renders the outfitter**
   (`port_panel.gd:427-429`). Add `"commission"` to `TAB_LABELS` and the Anchor's
   services but forget the `match` arm, and the COMMISSION tab silently renders a
   second outfitter — reactor row plus eight buyable modules. No error, no crash,
   a plausible-looking wrong screen. The hole is load-bearing (`"outfitter"` *is*
   the default), so it cannot be replaced with a warning.
6. **`PYXIS_GSATEST` must not own the v13 round-trip.** `save_game()`
   early-returns on `not save_enabled` and `lock_saving()` is one-way, so a
   locked harness asserting a round trip measures in-memory state that never left
   the process — §18's assertion-that-cannot-fail. Put the round trip in
   `_run_save_test`'s `write`/default/`migrate12` modes (already redirected to
   `user://test_save.json`); GSATEST locks saving and stays on rule assertions.
7. **`salvage_changed` re-enters `_refresh()` from inside the claim handler**
   (`port_panel.gd:76-79`). Increment the claim counter **before** `add_salvage`,
   or the rebuild reads the pre-claim stage and redraws the button just paid for.
   `_claim(stage)` must also re-check the stage and thresholds at its own top —
   `survey_mast.gd:174-180`'s lesson, and the harness is exactly the second
   caller that comment warns about. Also: the HUD salvage readout is **not**
   wired to `salvage_changed`; every payer in `port_panel.gd` calls
   `main.hud.set_value(...)` by hand.
8. **Put the commissioned beacon text inside `BROADCASTS`**, as optional
   `"from_commissioned"` / `"body_commissioned"` keys with
   `broadcast_for(band, commissioned)` falling back when absent. A parallel
   three-entry array creates a second bounds contract that disagrees with the
   first, and "band 4 unchanged" becomes a size mismatch instead of a stated
   property. `_tick_broadcast` reads at fire time and caches nothing, so a newly
   commissioned player hears the answer on their next trip out — the right beat.
9. **`main.add_salvage()` also calls `contracts.on_salvage()`**, so a claim ticks
   any active "earn N salvage" contract. The apex bonus goes through the same
   path, so there is precedent either way — match the apex and say so, rather
   than letting it be accidental.

### Assertions to write (`PYXIS_GSATEST` unless noted)

- `EVERY SERVICE HAS A BUILDER` — every `TAB_LABELS` key and every key in every
  chart and deep port's `services` renders a body distinguishable from the
  outfitter's. Closes finding 5, which is otherwise invisible.
- `LOAD CLAMPS` — `commission_claimed: 99` arrives at 4, `-5` arrives at 0.
  (`LOGTEST`'s `LOAD COERCES` is the template.)
- `ACCENT LOCKED AT THE LOAD PATH` — fixtures at `accent: 8` and `17`, asserted
  against the ship material, uncommissioned.
- `REFUSAL IS FREE` — tapping the locked swatch leaves `salvage` unchanged.
- `CLAIM GUARDS ITSELF` — call `_claim(0)` twice directly, not through a button.
- `CLAIM IS ORDERED` — stage 3 refused at `commission_claimed == 1` even with
  every threshold met.
- `STATE BEFORE MONEY` — a one-shot on `salvage_changed` sees the counter already
  incremented.
- `STAGE COUNT` — `STAGES.size() == 4`, and every clamp uses `STAGES.size()`
  rather than a literal 4.
- `NO IMPERATIVE` — every stage description fails a verb list, **as data**. The
  structural rule is worth nothing unless something checks it.
- `BEACON PARITY` — `BROADCASTS.size() == 5`; band 4 carries no commissioned key;
  bands 1–3 do; and `broadcast_for(band, false)` is string-identical to today for
  all five. That last clause is what stops the rewrite quietly editing the
  uncommissioned text.
- `NOT A TALLY` — `commission_claimed` never appears in `title_summary()`.
- `CLAIM ONCE`, `RETROACTIVE CLAIM PRINTED`, `RESET WITH RUN`, `PACING STACK`,
  `BEACON ANSWERS` — from the original plan.
- `[save] v13` round-trip + `migrate12` — in SAVETEST, per finding 6.

## 7. Facts checked so you do not have to re-check them

- **Depth 1100 is reachable.** No positional clamp (`DEEPTEST` flies to radius
  2404 and asserts none); the despawn leash is 140 so packs give up on a straight
  dash. Bands 3–4 guards beat a 100-shield ship, but that constrains *cracking
  guarded hulks out there*, not *getting there*.
- **Chart data cannot be lost to bad luck.** `spill_unread` filters on
  `is_salvage()` and chart goods carry `chart_band`, not `band`, so deep death
  spills nothing chart-shaped. `strip_hottest` sorts by weight × price, where
  charts are 40–150 against contraband's 2,450, so raiders take them last;
  `jettison_to_fit` dumps ore, alloys and charted salvage first. The only real
  loss path is paying a toll from a hold that is *only* charts.
- **The Anchor's seventh tab is fine.** `_tab_row` is an `HFlowContainer` chosen
  for exactly this, and Forgeline Depot already ships seven services. No harness
  asserts any port's service list as a whole.
- **Two of my own cited numbers were wrong** and are corrected here: `DEEPTEST`
  sweeps 4,225 cells (not 1,089), and posts sit on 80% of qualifying hulks (not
  82%) — `GUARD_WEIGHTS[0]` is 0.20.
