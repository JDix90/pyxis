extends Node
# Autoloaded as `GameState`. Owns persistent player state and is the only
# thing that writes the save file. Serialization is explicit (never
# store-the-whole-object) so this layer can move behind a server later.

signal fit_changed(stats: Dictionary)
signal salvage_changed(total: int)
# v16. THE HOLD CHANGED, whoever changed it. Cargo is the one piece of state the
# WORLD mutates while a screen is looking at it -- loot picked up, a toll taken,
# a delivery settled on docking, salvage spilled on death -- so the nineteen
# hand-written hud.refresh_cargo() calls were a rule enforced by memory, and two
# sites had already forgotten: spill_unread and Contracts.on_docked both unload
# and neither refreshes. Emitted from load_cargo and unload_cargo, which grep
# confirms are the only two functions in the game that write `cargo` outside of
# a reset or a save load.
signal cargo_changed
signal system_unlocked(id: String)
# v15. The lane to `id` is now flyable — its jamming engine is dead. Deliberately
# a second signal rather than a flag on the first: charting and opening happen at
# different places, for different reasons, and a listener usually wants one.
signal lane_opened(id: String)
# A standing shift the PLAYER is party to. Emitted from the ONE mutator, so
# every mover that exists now and every mover added later is covered by
# construction rather than by somebody remembering to announce it.
#
# DELIBERATELY NOT GATED ON `quiet`. That flag governs the LOGBOOK -- ten slots,
# and a redundant line there took LOGTEST's FIVE SITES WIRED red once already
# (see shift_faction's note). A toast is not a slot. The three POSITIVE movers
# all pass quiet=true and all three had nothing on screen at all, which is the
# half of finding A10 the dock-sheet row never covered: a consequence you can
# only discover by docking somewhere and reading a line is not feedback for an
# act you committed four hundred units away.
signal standing_shifted(other: String, delta: int, band: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 27
const SAVE_DEBOUNCE := 1.0

# v6 defaults. Kept as one dictionary each so a migration only has to merge
# missing keys rather than know the whole shape — adding a fifth setting later
# costs a line here and nothing in load_game().
const DEFAULT_SETTINGS := {
	"music_vol": 0.75,
	"sfx_vol": 0.90,
	"shake": true,
	"ui_scale": 1.0,
	# On by default: this is a phone game whose loudest moments (a hull giving
	# way, a claim at a dock) are otherwise carried by colour and a camera lurch,
	# both of which someone may have turned off or be unable to use.
	"haptics": true,
	# Separate from "shake" on purpose. Shake predates this and some players turn
	# it off because they dislike shake specifically, not because they want every
	# transition in the game to stop moving. Merging the two would silently
	# reinterpret a preference they already expressed.
	"reduce_motion": false,
	# OFF by default, and it stays off unless someone deliberately turns it on.
	# The file never leaves the device and nothing in the game reads it -- see
	# scripts/telemetry.gd -- but a recorder running because the player never
	# found the switch is not a recorder they consented to.
	"telemetry": false,
	# Palette.Vision: 0 normal, 1 deutan, 2 protan, 3 tritan. Materials are baked
	# at node construction, so changing this rebuilds the world through the
	# existing build paths rather than retinting in place -- see main.rebuild_visuals.
	"colorblind": 0,
	# Rebindable actions, as {action: [physical keycodes]}. Empty means "whatever
	# project.godot says", so a save written before this existed keeps the
	# defaults instead of arriving with no controls at all.
	"bindings": {},
}
const DEFAULT_LIVERY := {
	"hull": 0,
	"accent": 0,
}

# v10. The logbook: what this run has DONE, as opposed to what it owns. Same
# shape as settings and livery — a defaults dict merged key by key on load — so
# a key added later arrives at 0 on an older save rather than missing entirely.
const DEFAULT_LEDGER := {
	"deepest_depth": 0,
	"distance_flown": 0,
	"hulks_cracked": 0,
	"posts_cleared": 0,
	"chart_data_sold": 0,
	"tolls_paid": 0,
	# v22. Cells filed first. The count behind the first-filing bonus, and the
	# ledger's version of "places I put on the map" -- chart_data_sold measures
	# volume, this measures FIRSTS. A new key in this dict needs no save bump:
	# the load-side merge is defaults-based.
	"cells_filed": 0,
}
const SHIP_NAME_MAX := 24
const DEFAULT_SHIP_NAME := "SURVEYOR"

# v12. The captain's log: the ledger counts, this one remembers. Ten lines, and
# deliberately NOT a seventh DEFAULT_LEDGER key — that dict's load-side merge is
# `maxi(0, int(...))`, an int contract that would turn an array into 0. It gets
# its own field and its own sanitizer, the shape market_events already uses.
#
# Bounded because an unbounded one is a visited-cells array by another name (17):
# it would grow every minute the player flies. Ten is what fits the pause sheet
# without scrolling and what a player can read at a glance.
const LOG_MAX := 10
const LOG_LINE_MAX := 48

var salvage := 0
var owned: Array[String] = []
var fit := {}
var reactor_tier := 0
# v24 (§94). WHICH BERTHS ARE BOUGHT — ids into ModuleDB.BERTHS. An Array
# rather than a dictionary because a berth is owned or it is not, and because
# `owned` next door has taught the loader's shape already: validate against the
# catalog, drop what is not in it. Bounded by the table at three entries.
#
# One way only, and the loader enforces the consequence rather than trusting
# it: a fit naming a slot no berth has opened is dropped on load, so a
# hand-edited save cannot hand a pilot a free hardpoint.
var berths: Array = []
var stats := {}

# Live power diversions: burned-out section id -> the section carrying its power.
#
# DELIBERATELY NOT SAVED, and that is the design rather than an omission. A
# diversion is a wound you are still carrying, and it lasts exactly until you
# reach a dock (clear_diverts, called from the dock completion). Writing it to
# the save would mean a pilot who quit mid-fight loads back into a burned-out
# mount with no memory of trading it away -- punishment for closing the game.
# Everything else about this mechanic is derived from live integrity, so an
# empty dictionary at load is the correct and complete state.
var diverts := {}

# v2 fields — travel, progression, and first-run state.
var current_system := ""
var breached: Array[String] = []
var contract_state := {}
var barks_seen: Array[String] = []

# v3: systems whose apex engine has been put down at least once (first-kill
# bonus is one-time). A DAMAGED engine is still never persisted — retreat from a
# fight and it is whole again, because failure costs tempo and never salvage.
# What IS persisted, since v17, is the kill itself: see apex_down.
var apex_killed: Array[String] = []

# v15. THE HUNT — progression is now TWO tiers, and this is the second.
#
#   breached   -> the next system is CHARTED. It appears on the map, named,
#                 with its lane jammed by the engine still transmitting.
#   lanes_open -> the lane is OPEN. Travel is permitted.
#
# Before v15 the breach did both and `apex_killed` gated nothing whatsoever —
# the engine was an optional windfall parked at 60% of the charted radius, in
# plain sight, and the frontier opened twenty minutes into a run. Splitting the
# two is what makes the hunt the spine instead of a side errand.
#
# Kept SEPARATE from apex_killed rather than derived from it, because the two
# answer different questions: apex_killed is "has this engine ever paid its
# first-kill bonus", lanes_open is "may this lane be flown". A save written
# before v15 has the second without the first (see _load_lanes_open) and must
# not be charged a bonus it already collected, nor refused a lane it already had.
var lanes_open: Array[String] = []

# v17. THE ENGINE STAYS DOWN. Systems whose apex engine has been DESTROYED.
#
# There are three states, and before v17 only two of them had somewhere to live,
# which is why a cleared system rebuilt a full-strength engine the moment you
# warped out and back — SystemBuilder had nothing to ask:
#
#   neither flag  -> the engine is alive. Build it.
#   apex_down     -> killed, wreck not yet cracked. Build the WRECK.
#   + apex_killed -> killed and cracked. Build nothing.
#
# Kept SEPARATE from both neighbours above, and neither of them could stand in:
#
#   apex_killed is "has the first-kill bonus been paid", which is only true once
#   the WRECK is cracked — a second trip the player may not survive. Gating the
#   build on it would leave exactly the window this field exists to close.
#
#   lanes_open is "may this lane be flown", which is not the same question: the
#   pre-v15 grandfather seeds it from `breached`, so a save from before the split
#   would mark living engines dead and silently delete their bonus.
#
# Written by Main.on_apex_defeated — deliberately NOT by open_lane(), which is
# also called to grant passage without anything having died.
var apex_down: Array[String] = []

# v15. The run's own salt, and the only source of per-playthrough hiding.
#
# Everything the hunt conceals derives from this and nothing else, which buys
# both halves of what a hunt needs: DETERMINISM WITHIN A RUN — fly away and come
# back and the lair has not moved, so a bearing you were told an hour ago is
# still true — and a FRESH HUNT ACROSS RUNS, so a second playthrough is not a
# walk to a remembered coordinate.
#
# Rolled exactly once, at reset_to_starter. Never re-rolled mid-run: re-rolling
# would silently invalidate every hint the player has paid for and flown for.
# Harnesses PIN it (Main.RUN_SEED_PINNED) — a harness whose world moved on every
# run would be measuring the dice.
var run_seed := 0

# v4: the economy.
var cargo := {}                # good id -> units held
var played_seconds := 0.0      # drives market drift; never wall-clock
var docked_at := ""            # port id, so a reload resumes docked
var market_pressure := {}      # "port|good" -> -0.25..0.25
# v27. THE SHELF. "<counter>|good" -> {d: units the player has taken, t: the
# played-clock stamp it was taken at}. Only the hole is stored; the full shelf is
# derived from the port's bias table by Market.stock_cap, and an entry is ERASED
# the moment it replenishes, so a counter at rest costs the save nothing.
#
# The counter, NOT the port id: a charted port keys on its own id, a deep station
# on its CELL, because port_id out past the chart is the archetype and buying out
# one Shoal Relay must say nothing about the Relay three systems over. The bonded
# bay learned this first -- NO WORMHOLE -- and the shelf keys the same way,
# through the same PortPanel._bay_key().
var market_stock := {}
# v27 (§110). THE ORDER BOOK. [{good, port, at}] -- what was ordered, from which
# counter, on which tick of the played clock. Paid in full when placed, so an
# order is a receipt rather than a debt and abandoning one costs the player
# exactly what they already spent.
#
# Bounded by REQ_MAX_OPEN on the way in, and re-bounded in the loader, because a
# hand-edited file is input and not truth.
var requisition_orders: Array = []
# Which components this pilot has ever read out of a crate. The order desk will
# only source something you have SEEN -- "bring me one you have held" -- which is
# what stops requisitions being a way to skip ARCHEOLOGY rather than a way to
# stop hunting for the eighth unit of something you already understand.
var reads_done := {}
# v27 (§111). skill id -> xp. The TIER is never stored; skill_tier derives it.
var skills := {}

# v27 (§111). THE LADDER. Four skills shipped one at a time over twenty
# versions, each with its own var, its own xp var, its own tier constant and its
# own line function -- which was fine at four and is not fine at eleven. These
# are a DICT and a table, and the tier is DERIVED from the xp rather than stored
# beside it, so unlike the legacy four there is no second number that can
# disagree with the first.
#
# THE LAW THEY ALL KEEP (§19, §26, §36): a tier buys TIME, a CHOICE, ACCESS or
# INFORMATION. Never credits, never a stat, never a price. And every feed is a
# DIFFERENT VERB -- an hour surveying is an hour not cracking hulks -- because
# skills all fed by "playing the game" rise together and become a clock rather
# than a decision. FEEDS COMPETE asserts that as data.
const SKILL_TIERS := {
	# Masts worked. The one verb in the game that fed nothing at all: survey
	# coverage has counted it persistently and bounded since v21, and no ladder
	# has ever read the count.
	"surveying": [0, 6, 16, 34, 60],
	# Returns filed with the refusers' network, and far marks read for the first
	# time. Deliberately the two halves of one act -- filing is what buys the
	# literacy, and a mark is what the literacy is FOR (§98).
	"filing": [0, 3, 8],
}
const SKILL_LABELS := {
	"surveying": "SURVEYING",
	"filing": "FILING",
}
# What to do if you want the first tier. §58's rule: a refusal names the act.
const SKILL_VERBS := {
	"surveying": "WORK A SURVEY MAST OUT PAST THE CHART",
	"filing": "FILE A RETURN AT A FOREIGN MAST",
}
# Index by tier, so index 0 is the unearned rung and reads as "".
const SKILL_PERKS := {
	"surveying": ["", "THE READING IS NAMED", "MAST TEMPO",
		"THE RIVAL SHOWS EARLY", "THE LONG ARM"],
	# NOT "the marks name themselves". That was the plan and sounding_mark.gd
	# refuses it in writing: "an unread mark is A SOUNDING MARK to everybody,
	# because the kind is precisely what the notation tells you", and a harness
	# pins NAMES to FarMarks.kinds() rather than trusting the comment. A tier
	# that revealed the kind at range would delete the one thing reading a mark
	# is FOR. Both of these buy the same reading, sooner and from further out.
	"filing": ["", "A QUICKER HAND", "ALONGSIDE FROM FURTHER"],
}

# The tiers, named where the world reads them so a call site says what it means.
const SURVEY_NAMED_TIER := 1
const SURVEY_TEMPO_TIER := 2
const SURVEY_TEMPO_BONUS := 0.25    # a quarter off the hold
const SURVEY_RIVAL_TIER := 3
const SURVEY_REACH_TIER := 4
const SURVEY_REACH_MULT := 1.5      # far enough to work a guarded hull's mast
const FILING_QUICK_TIER := 1
const FILING_QUICK_BONUS := 0.25    # a quarter off the hold
const FILING_REACH_TIER := 2
const FILING_REACH_MULT := 1.5      # come alongside from further out

const REQ_MAX_OPEN := 3
# Five played minutes. Long enough that ordering is a decision made on the way
# out rather than a vending machine at the counter you are standing at, short
# enough that it lands inside the same session it was placed in.
const REQ_DELAY := 300.0
# v8. How much salvage this pilot can read. Not a power stat and deliberately not
# spendable: it is a record of what you have actually done that opens doors, the
# same shape as `breached`. See identify() for the one rule it drives.
var archeology := 0
var archeology_xp := 0
# v11. SMUGGLING. Fed by ONE thing — contraband and stolen goods sold at a fence
# — and the two feeds that were cut are worth recording, because both were
# arithmetic rather than taste:
#
#   XP for TOLLS PAID rewards the losing move. Fighting a raid nets about +700
#   in drops, running costs nothing, and paying costs 400 or more; a skill that
#   levelled on tolls would pay a player for choosing worst. It also grants
#   retroactive XP out of every v10 ledger, which already counts tolls.
#
#   XP for ESCAPING is a free ninety-second loop between two systems, which is
#   the exact printer shape the leash rule was written against.
#
# What is left competes honestly with ARCHEOLOGY: the good-sets are disjoint,
# and the Void-to-Cantina run is a different flight plan from cracking hulks —
# different bands, different hold, different exposure. 19's warning is that
# skills all fed by "playing the game" rise together and become a clock.
var smuggling := 0
var smuggling_xp := 0

# v14. MINING. Fed by SEAMS CUT, weighted by band — never by ore SOLD, which a
# smuggler's dock visit would also trigger and which would make the three feeds
# rise together (19's clock warning, and FEEDS COMPETE asserts the good-sets are
# disjoint). Ore carries neither `band` nor `parent`, so it belongs to neither
# ARCHEOLOGY's salvage set nor SMUGGLING's, and the three stay honest rivals.
var mining := 0
var mining_xp := 0

# v19. PERSUASION. Fed by ONE thing — a parley you TALKED your way out of — and
# the two feeds that were cut here are the same two SMUGGLING cut above, for the
# same arithmetic. A skill must never pay for paying and must never pay for
# running, so a toll settled moves this ladder by exactly nothing.
#
# WHAT MADE IT POSSIBLE AT ALL is that a talk-down now carries a stake. A bluff
# has always burned a Forged Manifest whether it worked or not, precisely so it
# could not strictly dominate paying; a talk-down needs no manifest, so without
# a cost of its own it would be a free roll on every demand and levelling on it
# would be levelling on showing up. Failing one costs a step of Tithe standing —
# they remember being lied to — which is the mirror of the step paying earns.
#
# It competes honestly with the other three by EVENT rather than by good-set:
# reading salvage, fencing contraband and cutting seams are three flight plans,
# and this one is not a flight plan at all. It is the thing you do when a fourth
# party interrupts one.
var persuasion := 0
var persuasion_xp := 0

# v14. Charted seams already cut, keyed "system:asteroid_index" ("pyx01:2").
#
# PERSISTENT, unlike the expanse's session-only `_mined`, and the split is the
# whole design. There are eleven finite authored rocks in the game; respawning
# them on every warp is the deep-hulk farm bug that DeepSpace._build_post's
# comment already records once. The expanse can reset safely because its defence
# is the band gradient (see WARP FARM); eleven fixed rocks have no such defence.
#
# It cannot grow without bound the way 17's rejected visited-cells array would:
# it is capped at the number of authored asteroids in the game, which is 11.
# The KEY is the system id and the asteroid's ARRAY INDEX, so reordering an
# `asteroids` array in system_db.gd silently rekeys a player's cut seams.
var seams_cut := {}
# v21. WORKED SURVEY CELLS, persistent. Keyed "system:cx:cz" -- DeepSpace's own
# cell_key shape, the one warehouse already uses -- because a bare Vector2i is
# the same key in every Pyx and the whole point of qualifying is that pyx01's
# (7,-3) and pyx02's (7,-3) are different places.
#
# THIS REVERSES 17's SESSION-ONLY RULE, and the reversal is answered rather
# than waved at: 17 refused a VISITED-cells array, which grows every minute the
# player flies. This records only cells where a mast was WORKED -- earned, not
# travelled -- and it is capped per system with oldest-first eviction, the
# intel dossier's own posture, enforced on write and re-enforced by the loader.
# Bounded by construction, not by hope. See 80.
var survey_coverage := {}
# v22. WHICH OF THOSE HAVE BEEN SOLD. A SEPARATE SET rather than a `filed` flag
# on the value above, and the reason is the migration: leaving survey_coverage
# as key->true means a v21 file loads through the SAME loader it always did,
# byte for byte, and an absent survey_filed is simply "nothing has been filed
# yet" -- which is exactly true of every v21 pilot. Defaults-not-branches with
# no branch at all, against a store that already holds the player's real work.
#
# INVARIANT: filed is a SUBSET of coverage, and the cap evicts them together.
# A filed key surviving its coverage key would grow without a bound of its own,
# which is the thing 17 refuses and 80 answered by construction.
var survey_filed := {}
# v22. HYPER STRUCTURES THE PLAYER HAS SEEN, keyed "system:index" -- the SAME
# shape `colonies` uses, because it is the same thing at an earlier stage.
#
# The silhouette design (hyper_structure.gd) is deliberate: 3-5 per system, no
# radar tier, visible at ~1000u, so finding one is a ~54-minute sweep rather
# than a lottery. That stands. What did not stand is losing the result: fly
# past one, get driven off by its wardens, and there was nowhere for "it is
# THERE" to live. The search stays hard; the answer stops evaporating.
#
# NEEDS NO CAP, and that is a property of the generator rather than a hope --
# hyper_positions returns at most HYPER_MAX per system, so this is bounded at
# 15 entries across the whole game. Asserted against the generator.
var structures_seen := {}
# v23. DEEP LOGS READ, keyed "system:kind" -> highest fragment stage reached
# (1..3). The unsounded structures out past band 6 each carry a short written
# record; this remembers how much of each the pilot has stood still long enough
# to pull. An int rather than the structures_seen booleans because the record
# is SEQUENTIAL -- fragment two only makes sense after fragment one, and the
# structure refuses to skip ahead.
#
# NEEDS NO CAP, generator-bounded like structures_seen: SystemDB authors one
# unsounded kind per system plus a single wreck, so this tops out at four
# entries across the whole game. The kind list is duplicated here as a const
# rather than read off UnsoundedSite -- this autoload references no world
# class, deep_space.gd's rule (§39), and four strings are a cheaper price
# than a class-list edge.
var deep_logs := {}
# v25 (§98). SOUNDING MARKS THIS PILOT HAS RESOLVED, keyed "system:index" --
# structures_seen's shape one shelf further out, because it is the same kind of
# fact: a place you found, remembered because finding it was the work.
#
# RIDES v25 WITH NO BUMP. Defaults-not-branches: a file from either earlier v25
# commit has no key, gets {}, and loads as a pilot who has read no marks --
# true of every pilot before buoys existed.
#
# THE VALUE IS A STATE, NOT A BOOLEAN, and it is one from the first line rather
# than a bool that grows a vocabulary later. That growth is precisely what cost
# a version bump and a silent loader defect in 96: survey_filed held `true` for
# two versions, the loader wrote the literal back, and the day a second value
# appeared every network filing quietly reverted on load. The legends (commits
# 3-5) need per-mark state -- a layup that has been deposited into, a nursery
# that is held -- so the store carries a validated string today and gains a
# member of MARK_STATES then, with no shape change and nothing to migrate.
#
# NEEDS NO CAP, generator-bounded like structures_seen: FarMarks returns at
# most PER_SYSTEM per system, so this is bounded at fifteen entries across the
# whole game. Asserted against the generator rather than hoped.
var marks_seen := {}
# v26 (§106). THE NURSERY, HELD. Keyed by MARK key ("system:index") and kept in
# its OWN store rather than in `colonies`, which the research pass found is not
# a choice but a requirement:
#
#   colony_key(sid, i) and mark_key(sid, i) are the SAME FORMAT -- "%s:%d" --
#   so a nursery filed under `colonies` at FarMarks index 3 would collide with
#   hyper-structure index 3's colony. Claiming one would make the other read as
#   claimed, suppress its chart diamond and mislabel its jump row. And a
#   prefixed key does not escape it: _load_colonies REQUIRES a two-part key and
#   silently drops anything else. There is no key shape that both survives that
#   loader and avoids the collision.
#
# Value: {"x": float, "z": float, "taken_at": float, "waves": int}. `taken_at`
# is the recapture clock's anchor and `waves` is what the pilot has actually
# turned back -- the ONE thing the derivation cannot reconstruct, because it is
# a fact about them rather than about the clock. Everything else (which wave is
# due, how many hulls it brings) is DERIVED from taken_at against
# played_seconds, the rival's rule: nothing to keep in step, nothing that can
# disagree with itself.
#
# NEEDS NO CAP, generator-bounded like its neighbours: FarMarks deals at most
# one nursery in an entire run, so this store holds at most one entry, ever.
var nursery := {}
# What each nursery key has survived, kept across a LOSS so retaking does not
# reset the record (S5). Session-only and deliberately so: it is a courtesy to
# a pilot inside one sitting, not a fact the save owes anyone.
var _nursery_waves_memory := {}

# v16. THE INTEL DOSSIER. Keyed by system id; each value is an Array of hint
# dictionaries the player has PAID FOR or EARNED, and together they are the only
# thing standing between "somewhere past the chart edge" and a bearing to fly.
#
# Two shapes, and the difference is what each channel can honestly claim:
#
#   {"kind": <channel>, "ox": float, "oz": float, "bearing": float, "err": float}
#       A bearing taken FROM somewhere. `ox`/`oz` is where the instrument stood
#       — stored, never recomputed, because a cone drawn from the wrong origin
#       is worse than no cone — and `err` is the half-angle it can promise.
#   {"kind": "ring", "band": int, "quadrant": String}
#       A rumour. No origin and no bearing: an annulus and a compass sector.
#
# NOTHING here is ground truth. `SystemDB.lair_pos` is, and it is never written
# down: every hint is derived from it at the moment it is earned and then stands
# on its own, so a save file cannot leak the answer and a contradictory dossier
# stays contradictory. `Hunt.estimate` does the intersecting, live, from these.
#
# The entry is DELETED on the kill (mark_apex_killed): the hunt is over, the
# hints are worthless, and a dossier that outlives its quarry is just clutter
# that would redraw a survey plot for a system with nothing left to find.
var apex_intel := {}

# v20 HUNT STAGE 5. Dropped waypoint beacons, keyed by system id, each entry
# {"x": float, "z": float}. The STOCK is derived, never stored — BEACON_STOCK
# minus every entry across every system (§59's derived-not-tracked rule, so the
# save cannot disagree with itself about how many beacons exist). Validated on
# load by _load_beacons, entry by entry, the apex_intel loader's shape.
var beacons := {}

# v20 HUNT STAGE 6. Founded colonies, keyed "system:index" — the seams_cut key
# shape, with a sharper hazard: seams_cut's index names an AUTHORED array, and
# reordering it rekeys a player's cuts. A colony's index names a SEED-DERIVED
# position, which is strictly weaker — so the value carries the POSITION rather
# than a bare flag, and the jump reads the stored coordinates. A change to the
# seed policy, the depth band or the candidate count can then never strand a
# founded colony or point a jump row at empty space.
#
# A DICT PER INSTANCE rather than a set of keys, deliberately: §5's base-building
# exclusion was lifted this horizon, and a claimed colony is exactly where a
# construction layer would hang. Fields cost nothing to add to a dict and a save
# migration to add to a set.
var colonies := {}
# When the last colony jump was taken, on played_seconds. ONE stamp for all of
# them — never one per colony — so founding five never multiplies how often the
# player can be outbound. THE COOLDOWN IS THE MECHANISM here, not the fee: see
# Main.COLONY_JUMP_COOLDOWN.
# v21. RENAMED FROM last_colony_jump, because it stopped being about colonies.
# The beacon jump shares this one stamp for the reason the colony jump's own
# comment gives -- founding five colonies must not multiply how often you can
# leave -- and a field still called "colony" would have been a name that lied
# about half of what it governs.
var last_outbound_jump := -1.0e9
# Eight is where the plot stops teaching. Past it the cones overlap so heavily
# that another one moves the estimate by less than the marker is wide, and the
# widest-error hint is dropped first — buying a ±5° reading should never be
# spent evicting itself in favour of a ±15° one already on file.
const HINT_CAP := 8
# Bumped whenever the dossier changes, so a renderer can cache an estimate
# without recomputing a 120x24 grid every frame. Deliberately NOT saved: it
# numbers edits within a session, not the dossier's contents.
var intel_version := 0

# v9. Bonded stores, keyed by PLACE.
#
#   chart station   the port id      ("anchor")
#   deep station    the CELL         ("pyx01:3:-7")
#
# The cell, emphatically not the archetype id. Every deep station carries its
# archetype as `port_id` (deep_space.gd sets it from the def), so every Shoal
# Relay in every system is "deep_relay" — a bay keyed on that would be ONE bay
# shared across an infinite map, and stashing 200u out of PYX-01 to withdraw
# 200u out of PYX-03 would teleport a hold between systems.
#
# This does not make the expanse saved state in 17's sense. That section
# refuses a visited-cells array because it "would grow every minute the player
# flies" — passive growth proportional to distance travelled. A bay grows only
# when you deliberately put something down. Generation stays a pure function of
# hash(system|cx|cz), and BECAUSE it does, every key here can be re-derived and
# validated against the generator on load rather than trusted.
var warehouse := {}

# One number, printed on the tab, identical at every station. Never a port-def
# key: a cap that VARIES turns storage capacity into a thing you shop for and
# compare across stations, which is a second budget with its own shopping trip —
# and 9 rule 1 allows exactly one.
const WAREHOUSE_SPACE := 60
var market_events: Array = []  # [{kind, port, good, mult, remaining}]

# v5: front door and first run.
var audio_muted := false
var tutorial_step := -1        # -1 = complete or never started

# v6: device preferences and ship identity. Both are deliberately NOT reset by
# reset_to_starter — how loud you like the music and what colour you painted the
# hull are yours, not the run's.
var settings := {}
var livery := {}
# The logbook is RUN state — a new survey is a new logbook, so reset_to_starter
# clears it. The ship's NAME is not: like the paint, what you called your ship is
# yours and outlives the run that named it.
var ledger := {}
var ship_name := DEFAULT_SHIP_NAME
# Run state too, cleared beside the ledger. Typed Array[String] on purpose: it is
# what forces the str() coercion on load that makes a hand-edited save safe, the
# same reason `owned`, `breached`, `barks_seen` and `apex_killed` carry the type.
var captains_log: Array[String] = []

# v13. The Grand Commission.
#
# `commission_claimed` is RUN state: how many stages this survey has claimed,
# cleared by reset_to_starter beside the ledger it reads from. Top-level rather
# than a seventh DEFAULT_LEDGER key, which was the other candidate: that dict's
# load merge is `maxi(0, int(...))`, a floor with no ceiling, so a hand-edited 99
# would reach STAGES[99] and crash AT A DOCK -- and the SAVETEST write leg
# assigns a literal six-key dict, so a seventh key would round-trip untested.
# This is the shape captains_log already shipped as, for the same reasons.
var commission_claimed := 0
# PERSISTENT, and the only thing here that is. What you earned outlives the run
# that earned it -- the livery and ship_name precedent.
#
# THE RULE, written down so the next reader does not "fix" it: `commissioned` is
# a strict monotone derivative of "stage 4 was ever claimed", and it is read by
# exactly three things -- the title screen's registry line, the accent lock, and
# the beacons. THE CLAIM COUNTER MUST NEVER READ IT, or stage 4 becomes
# unclaimable on every run after the first.
var commissioned := false

# v18. THE FACTION MATRIX — Horizon 4 stage 1 (docs/HORIZON-4-FACTIONS.md §4).
#
# Player-caused deltas over FactionDB.BASELINE, keyed by FactionDB.pair_key
# (canonical "a|b", a <= b), value clamped to ±FactionDB.DELTA_SPAN. SPARSE BY
# INVARIANT: a delta that returns to 0 is erased rather than stored, so "the
# player has changed nothing" and "the dict is empty" are the same statement —
# which is what lets NO INPUT, NO DRIFT assert on emptiness instead of on a
# tour of every pair.
#
# The baseline lives in FactionDB and the arithmetic lives HERE, not there:
# FactionDB is a pure leaf outside the class_name registry's reach (§39's
# cycle), and an autoload is the one place that can read both the table and
# the save without joining that graph.
var faction_deltas := {}
# Bumped whenever any attitude may have changed (shift, load, reset), so a
# hostile can cache its enemy list against a version instead of recomputing
# per frame — the apex_intel/intel_version pattern.
var faction_version := 0

# Overridable so scripted demos and tests never touch the player's real save.
var save_path := SAVE_PATH
# Guarded by _save_locked below: a harness that has said "never write" cannot be
# talked back into writing by any code path it later runs through.
var save_enabled := true:
	set(v):
		save_enabled = v and not _save_locked

var _save_locked := false
var _save_timer: SceneTreeTimer = null

# Set by load_game when it finds a save written by a NEWER build. Read by the
# title screen, which must not offer CONTINUE for a run it could not read.
var newer_save_refused := false

# --- device preferences, which are not run state ----------------------------
# Everything here belongs to the DEVICE and is shared by every pilot: the keys
# they rebound, the volume they set, the colour mode they need. It used to ride
# inside the save, which was correct while there was exactly one save -- and
# became wrong the moment there were five, because switching pilots would have
# silently rebound the player's keyboard and changed their colour-vision mode.
#
# `tutorial_seen` is the one field here that is not a preference. It is a device
# fact: this machine has been through onboarding once. tutorial_step stays in the
# SAVE, because a pilot halfway through step three is run state and sharing that
# between pilots would be its own bug; what is shared is only whether a NEW pilot
# starts at -1 instead of 0.
var prefs_path := "user://prefs.json"
var tutorial_seen := false
# True once prefs.json has been read from disk. Until then the legacy save is
# allowed to seed these fields, which is how an upgrading player keeps the
# bindings and volumes they already had.
var _prefs_loaded := false

# The pilot this save belongs to, "" when running on the legacy single-save path
# (which is every harness, and any boot before the migration has run). Written
# into the registry on every save so the title screen's rows stay current.
var active_profile := ""


func lock_saving() -> void:
	# One-way. Harnesses used to just assign `save_enabled = false`, but
	# start_new_game() assigns it back to true — and PYXIS_TITLETEST's entire job
	# is to press NEW SURVEY. The result was a headless test run silently
	# overwriting the player's actual save with a fresh starter run. A flag that
	# only travels in one direction is the fix; nothing may opt back in.
	_save_locked = true
	save_enabled = false


func saving_locked() -> bool:
	return _save_locked


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = DEFAULT_SETTINGS.duplicate()
	livery = DEFAULT_LIVERY.duplicate()
	ledger = DEFAULT_LEDGER.duplicate()
	if _headless():
		# PREFS ARE OFF UNDER A HARNESS, and the empty path is the switch.
		#
		# _save_prefs is reached from set_setting, set_audio_muted and
		# set_tutorial_step(-1), and forty-odd suites call those constantly --
		# ACCESSTEST alone rebinds keys a dozen times. Every one of them would
		# have been writing the player's real preferences, which is the rule this
		# repo enforces with an md5 in the sweep. Locking saving is not the
		# answer either: SAVETEST, LIVERYTEST and HUNTTEST deliberately do not
		# lock, because the file layer is what they are testing.
		#
		# Off, rather than pointed at a scratch file, because a shared scratch
		# file is cross-run coupling by another name: one suite's leftover
		# volume would arrive as another suite's starting state. With prefs
		# disabled, `_prefs_loaded` stays false, load_game seeds settings from
		# the save exactly as it did before this commit, and every existing
		# assertion keeps the meaning it was written with.
		#
		# A suite that actually wants the layer -- SAVETEST and PROFILETEST --
		# assigns its own path and calls reload_prefs(), which turns it back on
		# for that run only. Same seam as save_path, same reason.
		prefs_path = ""
	_load_prefs()
	# THE PROFILE IS RESOLVED HERE, not by Main, because this is an autoload and
	# its _ready runs BEFORE the main scene exists -- so anything that waited for
	# Main to point save_path at a pilot would already have loaded the wrong file.
	# It is also why the harness check below cannot call Main.harness_running().
	if not _headless():
		if Profiles.needs_migration():
			Profiles.migrate_legacy(Time.get_unix_time_from_system())
		var id := Profiles.active_id()
		# A FRESH INSTALL MUST STILL HAVE A PILOT. With no legacy save there is
		# nothing to migrate, so the registry is written empty and active_id is
		# "" -- which left save_path on the old single-save path. The player then
		# pressed NEW SURVEY, played a whole run into user://save.json, and the
		# first time they opened PILOTS and made one, switch_profile moved the
		# path to the new folder with `active_profile` still empty, so the
		# outgoing save was skipped and the entire run was stranded in a file
		# nothing would ever read again. The migration cannot rescue it either:
		# it is keyed on the registry's absence, and the registry now exists.
		#
		# So a player always has a pilot from the first boot, and every run is
		# written inside one from the start.
		if id == "":
			id = Profiles.create("", Time.get_unix_time_from_system())
		if id != "":
			active_profile = id
			save_path = Profiles.save_path_for(id)
	if not load_game():
		reset_to_starter()
	# Seeded, not merged: an upgrading player's bindings and volumes lived in the
	# save until this build, so the first boot after the split lifts them out of
	# whatever load_game just read and writes them where they now belong. After
	# that prefs.json exists and always wins.
	if not _prefs_loaded:
		# AND THE ONE FIELD THE SAVE CANNOT SEED BY ITSELF. tutorial_seen has no
		# home in the old format, so an upgrading player who finished onboarding
		# months ago would be stamped as never having seen it -- and it cannot
		# self-correct, because the only writer is set_tutorial_step(-1) and
		# load_game assigns tutorial_step directly rather than through the
		# setter, so the step is already -1 and the setter early-returns. Their
		# second pilot would then be walked through six steps of a tutorial they
		# finished before this build existed. A save that arrives finished IS the
		# device having seen it.
		if tutorial_step == -1:
			tutorial_seen = true
		_save_prefs()
	_recompute()
	apply_settings()


func _headless() -> bool:
	# THE HARNESS TEST THIS LAYER IS ALLOWED TO MAKE. Main owns HARNESS_VARS and
	# harness_running(), and neither is reachable from here: main.gd is 21k lines
	# and a compile-time dependency from an autoload into it is the shape §39
	# records closing a class-list cycle -- forty parse errors in untouched files
	# and a boot that hung rather than failed.
	#
	# So the question is asked of the display server instead, and it is the right
	# question rather than a cheap proxy: run_harness.sh runs every suite with
	# --headless, and the thing being prevented is a HEADLESS run moving the
	# player's real save into a pilot folder. A player's game is never headless.
	# Harnesses that want the migration call Profiles directly with redirected
	# paths, which is how PROFILETEST exercises it.
	return DisplayServer.get_name() == "headless"


# --- device preferences -----------------------------------------------------

func reload_prefs() -> void:
	# Re-reads prefs_path after a caller has MOVED it. _ready is the only other
	# reader, and it has already run by the time a harness redirects, so without
	# this the redirect would take effect for writes and not for reads.
	#
	# It resets first, so an absent file returns this layer to the state a fresh
	# install is in -- prefs off, the save allowed to seed. That is what lets one
	# SAVETEST mode consume what another wrote while the migrate modes each start
	# from nothing.
	settings = DEFAULT_SETTINGS.duplicate()
	audio_muted = false
	tutorial_seen = false
	_prefs_loaded = false
	_load_prefs()
	apply_settings()


func _load_prefs() -> void:
	# An empty path means the layer is off -- see _ready's headless clause.
	if prefs_path == "" or not FileAccess.file_exists(prefs_path):
		return
	var f := FileAccess.open(prefs_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pyxis: prefs.json unreadable, using defaults")
		return
	var data: Dictionary = parsed
	# Key-by-key onto the defaults, the same merge load_game does, so a prefs
	# file written before a later setting existed still gets that default.
	# UNTYPED FIRST, THEN CHECKED. `var saved: Dictionary = data.get(...)` looks
	# like it is guarded by the `is Dictionary` under it and is not: the typed
	# declaration converts on assignment, so a prefs.json whose "settings" key
	# is a number or a string raises a runtime error ON THAT LINE and the guard
	# below it never runs. This file is hand-editable by definition, and the
	# whole read would abort -- taking audio_muted and tutorial_seen with it, and
	# then letting _ready overwrite the file with defaults. profiles.gd already
	# does this in the right order; so does this now.
	var saved_v: Variant = data.get("settings", {})
	if saved_v is Dictionary:
		var saved: Dictionary = saved_v
		for key in DEFAULT_SETTINGS:
			if saved.has(key):
				settings[key] = saved[key]
	_clamp_settings()
	audio_muted = bool(data.get("audio_muted", false))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	_prefs_loaded = true


func _save_prefs() -> void:
	# The empty path is the off switch, and it is checked BEFORE save_enabled on
	# purpose: the suites that must not write prefs are exactly the ones that
	# deliberately leave saving enabled.
	if prefs_path == "" or not save_enabled:
		return
	var f := FileAccess.open(prefs_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"settings": settings,
		"audio_muted": audio_muted,
		"tutorial_seen": tutorial_seen,
	}, "\t"))
	f.close()
	_prefs_loaded = true


func _clamp_settings() -> void:
	# Every bound the settings dict has, in one place, because two readers now
	# fill it: prefs.json and (on the first boot after the split) an old save.
	settings["music_vol"] = clampf(float(settings["music_vol"]), 0.0, 1.0)
	settings["sfx_vol"] = clampf(float(settings["sfx_vol"]), 0.0, 1.0)
	settings["shake"] = bool(settings["shake"])
	settings["ui_scale"] = clampf(float(settings["ui_scale"]), 0.7, 1.6)
	settings["colorblind"] = clampi(int(settings["colorblind"]), 0, Palette.Vision.size() - 1)
	if not (settings["bindings"] is Dictionary):
		settings["bindings"] = {}


func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	_save_prefs()


# --- v6 settings ------------------------------------------------------------

func setting(key: String) -> Variant:
	# Always answers, even for a key a v5 save never had.
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_warning("Pyxis: unknown setting '%s'" % key)
		return
	# Unchanged is not a write. apply_settings runs on every step of a volume
	# slider, and prefs.json is now a real file on the other side of it -- so
	# without this, dragging one slider is a few hundred synchronous writes.
	if settings.has(key) and settings[key] == value:
		return
	settings[key] = value
	apply_settings()
	# TO PREFS, NOT TO THE SAVE. A setting belongs to the device, so it is
	# written immediately and to its own file -- which also means changing the
	# volume no longer dirties the run, and a player who changes a setting on the
	# title screen before picking a pilot still keeps it.
	_save_prefs()


func apply_settings() -> void:
	# One place that pushes preferences at the systems that own them, called on
	# load and on every change, so there is no path where the save and the running
	# game disagree about the volume.
	Sfx.set_bus_volume(Sfx.BUS_MUSIC, float(setting("music_vol")))
	Sfx.set_bus_volume(Sfx.BUS_SFX, float(setting("sfx_vol")))
	UILayout.user_scale = clampf(float(setting("ui_scale")), 0.7, 1.6)
	var want_vision := clampi(int(setting("colorblind")), 0, Palette.Vision.size() - 1)
	var vision_changed: bool = want_vision != Palette.vision
	Palette.vision = want_vision
	apply_bindings()
	var tree := get_tree()
	if tree != null:
		var win := tree.root.get_window()
		if win != null:
			UILayout.apply_scale(win)
		if vision_changed:
			# Only on an actual CHANGE: apply_settings runs on every slider drag,
			# and rebuilding the world on each frame of a volume tweak would be a
			# hitch with no cause the player could see.
			var main := tree.get_first_node_in_group("main")
			if main != null and main.has_method("rebuild_visuals"):
				main.rebuild_visuals()


# --- v13 the Grand Commission ------------------------------------------------

# Index of the earned accent in Palette.LIVERY_ACCENTS. Named rather than a
# literal 8 because two files gate on it and a ninth bought accent added later
# must not silently become the earned one.
const REGISTRY_ACCENT := 8


func commission_stage() -> int:
	# Which stage is up for claiming. Equals STAGES.size() when all four are in.
	return clampi(commission_claimed, 0, CommissionDB.count())


func commission_complete() -> bool:
	return commission_claimed >= CommissionDB.count()


func commission_ready() -> bool:
	# Deliberately does NOT read `commissioned`: that flag is persistent, and a
	# claim counter that consulted it would find stage 4 already done and make it
	# unclaimable on every run after the first.
	if commission_complete():
		return false
	return CommissionDB.met(commission_stage(), ledger)


func claim_commission() -> Dictionary:
	# Re-checks stage AND thresholds at its own top rather than trusting the
	# caller -- survey_mast.gd's lesson, and the harness is exactly the second
	# caller that comment warns about. Returns {} on refusal so a caller cannot
	# mistake "nothing happened" for a payout.
	if not commission_ready():
		return {}
	var stage := commission_stage()
	var paid := int(CommissionDB.stage(stage).get("pays", 0))

	# STATE BEFORE MONEY. add_salvage emits salvage_changed, and PortPanel
	# re-enters _refresh() from that signal -- so incrementing after the payout
	# would rebuild the sheet reading the pre-claim stage and redraw the button
	# that was just paid for.
	commission_claimed = stage + 1
	if commission_claimed >= CommissionDB.count():
		commissioned = true
	add_salvage(paid)
	note_log("%s — GSA REGISTRY" % String(CommissionDB.stage(stage).get("name", "")))
	_queue_save()
	return {"stage": stage, "name": String(CommissionDB.stage(stage).get("name", "")), "pays": paid}


func accent_unlocked(index: int) -> bool:
	# The single question both renderers ask. The lock lives here and at the load
	# path, never in set_livery -- set_livery is also how a save restores a
	# colour, so a refusal there would rewrite a legitimately earned livery.
	return index < REGISTRY_ACCENT or commissioned


# --- the faction matrix (v18, Horizon 4 stage 1) -----------------------------

func faction_attitude(a: String, b: String) -> int:
	# How a feels about b: authored baseline plus the symmetric player-caused
	# delta, clamped at READ time — clamping the read rather than the pieces is
	# what keeps an asymmetric baseline plus a symmetric delta from pushing one
	# direction of a pair out of range while the other stays in.
	var att := clampi(FactionDB.baseline_attitude(a, b)
		+ int(faction_deltas.get(FactionDB.pair_key(a, b), 0)),
		FactionDB.ATTITUDE_MIN, FactionDB.ATTITUDE_MAX)
	# The one authored floor (HORIZON-4 §2): the Authority never reaches the
	# band where the Cordon would fire on the surveyor. Applied to both
	# directions of the pair — a player hostile to a power that is merely wary
	# of them would have pickets returning fire "in defence", which is the same
	# broken world by a side door.
	if (a == FactionDB.SURVEYOR and b == "gsa") or (a == "gsa" and b == FactionDB.SURVEYOR):
		att = maxi(att, FactionDB.GSA_SURVEYOR_FLOOR)
	return att


func faction_band(a: String, b: String) -> int:
	return FactionDB.band_of(faction_attitude(a, b))


func enemies_of(faction: String) -> Array:
	# Every faction id `faction` would fire on unprovoked. Callers cache the
	# result against faction_version rather than calling per frame — this walks
	# the whole roster and is priced for "attitudes changed", not "every tick".
	var out: Array = []
	for other_v in FactionDB.ids():
		var other := String(other_v)
		if other == faction:
			continue
		if faction_band(faction, other) == FactionDB.Band.HOSTILE:
			out.append(other)
	return out


func has_ring_hint(system_id: String) -> bool:
	# Whether the dossier already holds a band-and-quarter reading for this
	# system. The free relay files one the moment the lane closes, so a desk
	# selling the same thing needs to know not to offer it twice.
	for h_v in apex_hints(system_id):
		if String((h_v as Dictionary).get("kind", "")) == "ring":
			return true
	return false


func hostile_to_player(node) -> bool:
	# The one dispatcher every consumer asks, so "is this thing my enemy" has a
	# single answer instead of four that agree by luck.
	#
	# UNTYPED, for _auto_targetable's reason: a typed parameter is checked
	# before the call, and freed nodes arrive here routinely from group walks.
	#
	# NO METHOD MEANS HOSTILE. ApexBoss is in "hostiles" and carries no faction
	# at all -- it IS the fight -- and a default that spared it would make the
	# engine untappable and silent. Anything else unflagged is hostile by
	# construction too, which is the shipped world exactly.
	if not is_instance_valid(node):
		return false
	if not (node as Node).has_method("fights_the_player"):
		return true
	return bool(node.fights_the_player())


func shift_faction(a: String, b: String, amount: int, quiet := false) -> void:
	# THE ONLY MUTATOR, and it moves both directions of one pair at once —
	# deltas are symmetric by design (HORIZON-4 §2), so there is nothing else a
	# caller could mean. Player actions are the only legitimate callers; nothing
	# in the game may call this from a timer, a spawn, or another faction's
	# fortunes. NO INPUT, NO DRIFT is asserted against exactly this property.
	if amount == 0 or not FactionDB.is_faction(a) or not FactionDB.is_faction(b) or a == b:
		return
	var key := FactionDB.pair_key(a, b)
	var cur := int(faction_deltas.get(key, 0))
	var nxt := clampi(cur + amount, -FactionDB.DELTA_SPAN, FactionDB.DELTA_SPAN)
	if nxt == cur:
		return
	# Sparse by invariant: zero is absence, never a stored value.
	if nxt == 0:
		faction_deltas.erase(key)
	else:
		faction_deltas[key] = nxt
	faction_version += 1
	# The A10 line: politics the player changed and cannot see is not politics,
	# it is a haunting. One log line, only for shifts the player is party to —
	# third-party shifts get their line from the contract copy that caused them.
	# `quiet` is for callers that have ALREADY narrated the cause. A toll writes
	# "TOLL PAID — 400 IN CARGO" and a held muster writes "THE LINE HELD"; a
	# second entry stating the obvious consequence burns another of only ten
	# logbook slots on one moment, and LOGTEST's FIVE SITES WIRED went red
	# proving it. Finding A10 — politics you cannot see is a haunting — is
	# satisfied without the line now: stage 5 put a permanent STANDING row on
	# every dock sheet. Callers with no other record stay loud.
	if not quiet and (a == FactionDB.SURVEYOR or b == FactionDB.SURVEYOR):
		var other := b if a == FactionDB.SURVEYOR else a
		note_log("%s — STANDING %s" % [FactionDB.display_name(other),
			"RISES" if amount > 0 else "FALLS"])
	# The on-screen channel, for every mover regardless of `quiet`. The early
	# returns above mean a no-op never reaches here, and the SURVEYOR test means
	# a third-party shift never does either -- both are asserted.
	if a == FactionDB.SURVEYOR or b == FactionDB.SURVEYOR:
		var moved := b if a == FactionDB.SURVEYOR else a
		standing_shifted.emit(moved, amount,
			FactionDB.band_of(faction_attitude(FactionDB.SURVEYOR, moved)))
	_queue_save()


func _load_faction_deltas(saved: Variant) -> void:
	# Rebuilt entry by entry — the seams_cut/warehouse posture. A key must name
	# two real factions in canonical order, a value arrives clamped, and a zero
	# is dropped rather than stored so the sparse invariant survives a
	# hand-edited file. Anything else is rejected by name, not tolerated.
	faction_deltas = {}
	faction_version += 1
	if not (saved is Dictionary):
		return
	for k_v in (saved as Dictionary):
		var key := String(k_v)
		var parts := key.split("|")
		if parts.size() != 2:
			continue
		if not FactionDB.is_faction(parts[0]) or not FactionDB.is_faction(parts[1]):
			continue
		# A faction's relationship with ITSELF is a constant, not state. Rejected
		# explicitly because pair_key("gsa", "gsa") is legitimately "gsa|gsa", so
		# the canonical-ordering check below waves a self-pair straight through —
		# and a stored self-delta would be the one entry faction_attitude can
		# never read back, since it short-circuits on a == b.
		if parts[0] == parts[1]:
			continue
		if FactionDB.pair_key(parts[0], parts[1]) != key:
			continue  # non-canonical ordering: the same pair under a second name
		var val := clampi(int((saved as Dictionary)[k_v]),
			-FactionDB.DELTA_SPAN, FactionDB.DELTA_SPAN)
		if val != 0:
			faction_deltas[key] = val


func shake_enabled() -> bool:
	# Reduced motion subsumes shake: someone who asked for less movement is not
	# asking to keep the camera lurching. The reverse is not true.
	return bool(setting("shake")) and not reduce_motion()


# Actions a player may rebind. Deliberately not every action in the InputMap:
# `cancel` is the escape hatch out of every console and the pause menu, and a
# player who binds it to a key they cannot reach has no way back to the settings
# page that would let them fix it. It stays on Escape.
#
# `toggle_hold` IS IN THIS LIST AND HAS TO BE. The list drives two things that
# look unrelated: the settings rows, and rebind()'s conflict-stealing loop
# below. An action outside it is INVISIBLE to that loop, so a player could bind
# move_up to I and end up with two live actions on one key -- which is exactly
# what NO SHARED KEY forbids, arriving through the one door that assertion
# cannot see.
#
# The same reasoning is why `chart`, `drop_beacon` and `pause` join it the day
# they enter the InputMap rather than later: each is a real key a player may
# want moved, and each is a key another action could otherwise be stacked on
# top of. ACCESSTEST asserts this list plus `cancel` IS the InputMap, so the
# omission cannot survive a sweep either -- but the conflict loop is the reason
# that assertion is worth having.
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right",
	"ability", "cycle_target", "toggle_hold", "chart", "drop_beacon", "pause"]


func _live_keys(action: String) -> Array:
	# Every physical keycode currently on an action, read from the InputMap so
	# defaults and overrides answer alike. rebind's conflict loop and
	# binding_name are the two callers, and both used to have their own idea of
	# where the truth was.
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null:
			out.append(int(k.physical_keycode))
	return out


func binding_name(action: String) -> String:
	# What key is on this action RIGHT NOW, for anything that prints a key to the
	# player. It reads the live InputMap rather than the saved dict on purpose:
	# an action still on its project.godot default has no entry in `settings`
	# (apply_bindings skips it, and that is what leaves the default in place), so
	# the dict would answer "—" for six of the ten actions on a fresh install.
	#
	# It lives here rather than on PauseMenu, where it was written, because the
	# manual prints keys too and had been printing them as HAND-TYPED LITERALS
	# since it shipped -- "W A S D", "SPACE", "I" -- which were simply false for
	# any player who had used the rebinding page the settings screen advertises.
	# One reader, one answer.
	# UPPER-CASED, because every surface that prints a key is all-caps and Godot
	# is not: get_keycode_string answers "Space", "Tab", "Escape". Left alone,
	# the manual's control column read "CLICK / Tab" beside "DROP BEACON" and
	# the settings rows read "ABILITY   Space".
	for code in _live_keys(action):
		return OS.get_keycode_string(
			DisplayServer.keyboard_get_keycode_from_physical(int(code))).to_upper()
	return "—"


func apply_bindings() -> void:
	# Rebuilt from the saved dict on every settings change and on load, so the
	# InputMap and the save can never disagree. An action missing from the dict
	# keeps whatever project.godot gave it.
	var saved: Dictionary = setting("bindings")
	if not (saved is Dictionary):
		return
	for action in REBINDABLE:
		if not saved.has(action) or not InputMap.has_action(action):
			continue
		var codes: Array = saved[action]
		if not (codes is Array) or codes.is_empty():
			continue
		InputMap.action_erase_events(action)
		for code in codes:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(code)
			InputMap.action_add_event(action, ev)


func rebind(action: String, physical_keycode: int) -> bool:
	# One key per action, replacing whatever was there. Returns false rather than
	# silently doing nothing so the UI can say why.
	if not REBINDABLE.has(action) or physical_keycode == 0:
		return false
	# ESCAPE IS RESERVED, not merely immovable. `cancel` is kept out of
	# REBINDABLE so it can never be moved OFF Escape -- but nothing stopped an
	# action being moved ONTO it, and `cancel` is invisible to the loop below
	# because that loop walks REBINDABLE. The result was never a shared key the
	# player could use: CameraRig tests `cancel` before every hotkey branch, so
	# a chart or beacon action bound to Escape was simply DEAD, and a `pause`
	# action bound to Escape was worse -- PauseMenu tests pause first, so Escape
	# stopped backing out one step and started resuming from any page, which is
	# the manual's numbered ladder made false from the settings screen.
	#
	# Refusing is the only coherent answer, because the other repair -- taking
	# Escape away from `cancel` -- is the thing REBINDABLE's exclusion exists to
	# prevent.
	if physical_keycode == KEY_ESCAPE:
		return false
	# A key already spoken for is TAKEN AWAY from its old owner rather than
	# shared. Two actions on one key is not a binding, it is a bug the player
	# discovers mid-flight.
	var binds: Dictionary = (setting("bindings") as Dictionary).duplicate(true)
	for other in REBINDABLE:
		if other == action:
			continue
		# THE LIVE MAP, NOT THE SAVED DICT, and the difference was a real hole.
		# This used to read `binds`, which holds only actions a player has
		# ALREADY moved -- an action still on its project.godot default has no
		# entry there at all (apply_bindings skips it, and that is exactly what
		# leaves the default in place). So on a fresh install every default was
		# invisible to this loop: binding move_up to C returned true, wrote the
		# override, and left `chart` sitting on C as well. Two live actions on
		# one key, reachable in four taps, by the function written to prevent it.
		#
		# InputMap is authoritative because set_setting -> apply_settings ->
		# apply_bindings runs on every change, so it already reflects both the
		# saved overrides and the untouched defaults. Same source binding_name
		# reads, for the same reason.
		var current: Array = _live_keys(String(other))
		if not current.has(physical_keycode):
			continue
		var kept: Array = []
		for c in current:
			if int(c) != physical_keycode:
				kept.append(int(c))
		# Never leave an action with nothing bound: an unreachable action is
		# worse than a shared key, because there is no way to notice it until
		# the moment it is needed.
		if kept.is_empty():
			return false
		binds[other] = kept
	binds[action] = [physical_keycode]
	set_setting("bindings", binds)
	return true


func reset_bindings() -> void:
	set_setting("bindings", {})
	# Erasing the overrides is not enough -- InputMap still holds whatever was
	# applied. load_from_project_settings puts every action back to project.godot.
	InputMap.load_from_project_settings()


func haptics_enabled() -> bool:
	return bool(setting("haptics"))


func reduce_motion() -> bool:
	return bool(setting("reduce_motion"))


# --- v6 livery --------------------------------------------------------------

func livery_index(part: String) -> int:
	return int(livery.get(part, DEFAULT_LIVERY.get(part, 0)))


func set_livery(hull: int, accent: int) -> void:
	livery["hull"] = hull
	livery["accent"] = accent
	_queue_save()
	# The hull is rebuilt from the fit, so re-emitting is what repaints the ship.
	fit_changed.emit(stats)


func reset_to_starter() -> void:
	# DIVERSIONS DIE WITH THE RUN, and missing this made "not saved" a false
	# comfort. `diverts` is only ever emptied by docking, so ABANDON TO TITLE
	# followed by NEW SURVEY carried a burned-out mount into a brand-new ship:
	# this function ends in _recompute(), which folds the stale dictionary
	# straight back in, and the new pilot flies at half DPS with no way to see
	# why -- the damage panel refuses to open during the tutorial.
	diverts = {}
	salvage = 0
	owned = []
	for id in ModuleDB.STARTER_OWNED:
		owned.append(id)
	fit = ModuleDB.STARTER_FIT.duplicate()
	reactor_tier = 0
	berths = []
	current_system = SystemDB.START_SYSTEM
	breached = []
	lanes_open = []
	# A NEW SURVEY is a new frontier. This is the one place the run's salt is
	# rolled, and it is rolled from the system clock rather than the seeded
	# global stream — every other roll in this game is deterministic by design,
	# and this is the single number that must not be.
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.randomize()
	run_seed = seed_rng.randi()
	contract_state = {}
	barks_seen = []
	apex_killed = []
	apex_down = []
	cargo = {}
	played_seconds = 0.0
	docked_at = ""
	market_pressure = {}
	market_stock = {}
	requisition_orders = []
	reads_done = {}
	skills = {}
	market_events = []
	archeology = 0
	archeology_xp = 0
	smuggling = 0
	smuggling_xp = 0
	mining = 0
	mining_xp = 0
	persuasion = 0
	persuasion_xp = 0
	seams_cut = {}
	survey_coverage = {}
	survey_filed = {}
	structures_seen = {}
	deep_logs = {}
	marks_seen = {}
	nursery = {}
	apex_intel = {}
	beacons = {}
	colonies = {}
	last_outbound_jump = -1.0e9
	intel_version += 1
	# A new survey is a new political slate: the deltas are RUN STATE, cleared
	# with the ledger. The baseline needs no reset — it is a const table.
	faction_deltas = {}
	faction_version += 1
	warehouse = {}
	# A new survey is a new logbook. ship_name is deliberately NOT reset — see the
	# field comment: what you called your ship outlives the run that named it.
	ledger = DEFAULT_LEDGER.duplicate()
	captains_log = []
	# Run state, cleared with the ledger it reads from. `commissioned` is NOT
	# cleared: it is the one thing here that outlives the run, same as the paint
	# and the ship's name.
	commission_claimed = 0
	tutorial_step = 0          # a fresh survey starts at step one
	# audio_muted is a device preference, not run state: deliberately preserved
	# across a new game.
	# Derived stats must be rebuilt here, not left to the next equip: starting a
	# new game from a save with (say) a Cargo Bay fitted otherwise kept the old
	# hold size and the old hull mesh until the player happened to refit, because
	# nothing else emits fit_changed.
	_recompute()


# --- travel & progression ---------------------------------------------------

func set_current_system(id: String) -> void:
	if current_system == id:
		return
	current_system = id
	_queue_save()


func is_system_charted(id: String) -> bool:
	# On the map and named. Breaching the previous system's derelict does this,
	# exactly as it always has — the tutorial's finale still opens the world.
	var req := String(SystemDB.get_system(id).get("unlocked_by", ""))
	return req == "" or breached.has(req)


func is_lane_open(id: String) -> bool:
	# Flyable. Requires the previous system's engine to be dead.
	var req := String(SystemDB.get_system(id).get("unlocked_by", ""))
	return req == "" or lanes_open.has(req)


func is_system_unlocked(id: String) -> bool:
	# Kept as the TRAVEL question, which is what every caller of the old name
	# actually meant, so a missed call site fails closed (refuses a lane) rather
	# than open (grants one). New code should say which tier it means.
	return is_lane_open(id)


func mark_breached(id: String) -> Array[String]:
	# Returns systems this breach newly charted, so callers can announce them.
	if breached.has(id):
		return []
	breached.append(id)
	var newly: Array[String] = []
	for other in SystemDB.ids():
		if String(SystemDB.get_system(other).get("unlocked_by", "")) == id:
			newly.append(other)
			system_unlocked.emit(other)
	_queue_save()
	return newly


# --- cargo hold -------------------------------------------------------------

func cargo_capacity() -> int:
	return int(stats.get("cargo_space", ModuleDB.BASE.get("cargo_space", 24)))


func cargo_used() -> int:
	var used := 0
	for good in cargo:
		used += int(cargo[good]) * CommodityDB.space_of(String(good))
	return used


func cargo_free() -> int:
	return maxi(0, cargo_capacity() - cargo_used())


func cargo_count(good: String) -> int:
	return int(cargo.get(good, 0))


func cargo_over() -> int:
	# How much is aboard BEYOND capacity. cargo_free() clamps at zero and so
	# cannot express this state at all, and cargo_overflow() answers a different
	# question -- what a PROSPECTIVE swap would leave over -- and needs a slot to
	# do it. A screen that is not a fitting screen has no slot to give it.
	return maxi(0, cargo_used() - cargo_capacity())


func hold_value(weighted := false) -> int:
	# Base-price valuation of the hold. `weighted` applies each good's
	# interdiction weight, which is what the raider roll reads: a hold of
	# contraband is worth stopping for three times as badly as its sticker price.
	var total := 0.0
	for good in cargo:
		var id := String(good)
		var v := float(CommodityDB.base_price(id)) * float(cargo[good])
		total += v * (CommodityDB.interdiction_weight(id) if weighted else 1.0)
	return int(total)


func can_load(good: String, units: int) -> bool:
	return cargo_free() >= CommodityDB.space_of(good) * units


func load_cargo(good: String, units: int) -> int:
	# Loads as many units as fit and returns how many were actually taken, so
	# callers can decide what to do with the remainder rather than silently
	# dropping it.
	if units <= 0 or not CommodityDB.exists(good):
		return 0
	var per := maxi(1, CommodityDB.space_of(good))
	var room := cargo_free() / per
	var taken := mini(units, room)
	if taken > 0:
		cargo[good] = cargo_count(good) + taken
		_queue_save()
		cargo_changed.emit()
	return taken


func unload_cargo(good: String, units: int) -> int:
	# Returns how many were actually removed.
	var have := cargo_count(good)
	var removed := mini(units, have)
	if removed <= 0:
		return 0
	if have - removed <= 0:
		cargo.erase(good)
	else:
		cargo[good] = have - removed
	_queue_save()
	cargo_changed.emit()
	return removed


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func set_tutorial_step(step: int) -> void:
	if tutorial_step == step:
		return
	tutorial_step = step
	# -1 is the sentinel for "finished or never started", and reaching it is what
	# tells the DEVICE it has been through onboarding once. A second pilot then
	# starts at -1 rather than at step one, because somebody testing a fourth fit
	# does not want six steps of it again. The step itself stays in the save.
	if step == -1:
		mark_tutorial_seen()
	_queue_save()


func set_audio_muted(v: bool) -> void:
	audio_muted = v
	Sfx.set_muted(v)
	# A device preference, and its own comment in reset_to_starter has said so
	# since long before there were pilots to share it between. It goes to prefs.
	_save_prefs()


func advance_clock(delta: float) -> void:
	played_seconds += delta


func set_docked(port_id: String) -> void:
	if docked_at == port_id:
		return
	docked_at = port_id
	_queue_save()


func has_killed_apex(id: String) -> bool:
	return apex_killed.has(id)


func open_lane(id: String) -> Array[String]:
	# The engine has stopped transmitting. Returns the lanes this newly opened,
	# the same shape mark_breached returns for charting — the two are halves of
	# one progression and should read alike.
	#
	# DELIBERATELY SEPARATE from mark_apex_killed, and the separation is
	# load-bearing rather than tidiness. The lane opens when the engine DIES;
	# the first-kill bonus is paid when its WRECK IS BREACHED, which is a second
	# trip the player may not survive. Folding them together would mean the
	# bonus guard (`has_killed_apex`) was already true by the time the wreck was
	# cracked, and the bonus would never pay at all.
	#
	# It also opens on a repeat kill whose bonus is long spent: a player who has
	# put the engine down twice should never be held behind that door.
	var newly: Array[String] = []
	if lanes_open.has(id):
		return newly
	lanes_open.append(id)
	for other in SystemDB.ids():
		if String(SystemDB.get_system(other).get("unlocked_by", "")) == id:
			newly.append(other)
			lane_opened.emit(other)
	_queue_save()
	return newly


func mark_apex_killed(id: String) -> void:
	# Records that this system's first-kill bonus has been collected. The LANE is
	# open_lane's business — see the note there.
	if apex_killed.has(id):
		return
	apex_killed.append(id)
	# The hunt is over, so the dossier goes with it. Kept here rather than in
	# open_lane because the intel is about the ENGINE, not about the lane. Since
	# v17 mark_apex_down is the earlier and more literal "the engine is dead", and
	# it clears the dossier too — by the time the wreck is cracked there is
	# normally nothing left to clear. This stays as the backstop for the one order
	# that skips it: a save grandfathered from v16, where the kill was inferred.
	clear_apex_intel(id)
	_queue_save()


func has_apex_down(id: String) -> bool:
	return apex_down.has(id)


func mark_apex_down(id: String) -> void:
	# The engine is DESTROYED, and unlike its hit points that outlives the system
	# teardown: SystemBuilder asks this before it builds anything at the lair.
	#
	# Separate from mark_apex_killed on purpose — see apex_down's declaration. The
	# bonus is still owed at this point, and the wreck carrying it is rebuilt on
	# re-entry until somebody cracks it.
	if apex_down.has(id):
		return
	apex_down.append(id)
	# Nothing left to hunt, so the dossier goes now rather than at the wreck.
	clear_apex_intel(id)
	_queue_save()


func has_seen_bark(key: String) -> bool:
	return barks_seen.has(key)


func mark_bark(key: String) -> void:
	if barks_seen.has(key):
		return
	barks_seen.append(key)
	_queue_save()


func set_contract_state(state: Dictionary) -> void:
	contract_state = state
	_queue_save()


# --- salvage ---------------------------------------------------------------

func add_salvage(amount: int) -> void:
	salvage += amount
	salvage_changed.emit(salvage)
	_queue_save()


func spend_salvage(amount: int) -> bool:
	if salvage < amount:
		return false
	salvage -= amount
	salvage_changed.emit(salvage)
	_queue_save()
	return true


# --- fitting ---------------------------------------------------------------

func power_cap() -> int:
	# v24 (§94). The reactor, plus whatever the bought berths brought with them.
	# A berth is a slot AND the power to use it -- see ModuleDB.BERTHS for why
	# the slot alone was not a product worth selling.
	return ModuleDB.reactor_power(reactor_tier) + ModuleDB.berth_power(berths)


func slot_unlocked(slot: int) -> bool:
	# Every shipped slot is always open; a berth slot opens when it is bought.
	# Asked of the BERTH TABLE rather than of a list of unlocked slots, so the
	# two can never disagree about which slot a berth opens.
	for id_v in ModuleDB.BERTHS:
		if int((ModuleDB.BERTHS[id_v] as Dictionary).get("slot", -1)) == slot:
			return berths.has(String(id_v))
	return true


func open_slots() -> Array:
	# The slots this pilot actually has, in enum order. Every surface that draws
	# or counts slots reads this rather than SLOT_NAMES -- the refit chips, the
	# manual's fitting page, and the assertions that count them.
	var out: Array = []
	for slot_v in ModuleDB.SLOT_NAMES:
		if slot_unlocked(int(slot_v)):
			out.append(slot_v)
	return out


func berth_price(id: String) -> int:
	return int((ModuleDB.BERTHS.get(id, {}) as Dictionary).get("price", 0))


func can_buy_berth(id: String) -> bool:
	return ModuleDB.BERTHS.has(id) and not berths.has(id) \
		and salvage >= berth_price(id)


func buy_berth(id: String) -> bool:
	# ONE WAY, and that is the design rather than a missing feature. The mass is
	# what makes a berth a trade instead of a strict upgrade, and a berth that
	# could be sold back would make it a rental -- buy it for the fight, refund
	# it for the flight home.
	if not can_buy_berth(id):
		return false
	salvage -= berth_price(id)
	berths.append(id)
	salvage_changed.emit(salvage)
	_recompute()
	_queue_save()
	return true


func power_draw() -> int:
	return ModuleDB.power_draw(fit)


func owns(id: String) -> bool:
	return owned.has(id)


func cargo_after(slot: int, id: String) -> int:
	# Hold size the ship WOULD have with this swap applied.
	var probe := fit.duplicate()
	probe[slot] = id
	return int(ModuleDB.compute_stats(probe).get("cargo_space",
		ModuleDB.BASE.get("cargo_space", 24)))


func cargo_overflow(slot: int, id: String) -> int:
	# How much cargo would not fit. Zero means the swap is safe.
	return maxi(0, cargo_used() - cargo_after(slot, id))


func can_equip(slot: int, id: String) -> bool:
	if id == "":
		# Not a blanket allow any more: pulling a Cargo Bay out from under a
		# loaded hold used to leave cargo_used above cargo_capacity, which every
		# other system then had to tolerate as a silently invalid state. The
		# refit console offers to jettison down to the threshold instead.
		return cargo_overflow(slot, id) == 0
	if not slot_unlocked(slot):
		return false
	if not ModuleDB.exists(id) or not owns(id):
		return false
	if ModuleDB.SLOT_CATEGORY.get(slot, "") != ModuleDB.get_module(id)["category"]:
		return false
	if cargo_overflow(slot, id) > 0:
		return false
	var probe := fit.duplicate()
	probe[slot] = id
	return ModuleDB.power_draw(probe) <= power_cap()


func _load_seams_cut(saved: Dictionary) -> void:
	# Validated against the GENERATOR, exactly as _load_warehouse validates bay
	# keys against the places that actually exist. A raw dictionary keyed by
	# strings the player never types is still a raw dictionary: a hand-edited save
	# — or an `asteroids` array that lost an entry between builds — must not leave
	# this holding a rock that is not there any more.
	seams_cut = {}
	for key_v in saved:
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 2:
			continue                       # 1. shape
		var sid := String(bits[0])
		if not SystemDB.exists(sid):
			continue                       # 2. the system must still exist.
			                               #    REDUNDANT today and kept anyway: the
			                               #    red pass showed filter 4 already
			                               #    rejects an unknown system, because
			                               #    get_system() returns {} and an empty
			                               #    asteroids array fails the bounds
			                               #    check. That is an implementation
			                               #    detail of SystemDB, not a promise,
			                               #    so the explicit test stays.
		if not String(bits[1]).is_valid_int():
			continue                       # 3. the index must be a number
		var idx := int(bits[1])
		var rocks: Array = SystemDB.get_system(sid).get("asteroids", [])
		if idx < 0 or idx >= rocks.size():
			continue                       # 4. and must still name a real rock
		if bool(saved[key_v]):
			seams_cut[key] = true          # 5. falsey values dropped, not kept


# --- survey coverage (v21) ----------------------------------------------------

# Generous against real play -- masts ride deep hulks, so a long session works
# a few dozen cells -- and small against the file: 400 short strings. What it
# buys is the property 17 demanded: the store cannot grow without bound, so
# "the save grows every minute the player flies" stays refused even though the
# session-only rule is gone.
const SURVEY_CELL_CAP := 400


func note_survey_worked(key: String) -> bool:
	# Returns whether this was NEW coverage, so a caller that pays for a first
	# reading can refuse to pay for a repeat. Insertion order is eviction order:
	# GDScript dictionaries keep it, which is the same property the eviction in
	# _enforce_survey_cap and the loader both lean on.
	if survey_coverage.has(key):
		return false
	survey_coverage[key] = true
	_enforce_survey_cap(String(key.split(":")[0]))
	_queue_save()
	return true


func is_survey_worked(key: String) -> bool:
	return survey_coverage.has(key)


func _enforce_survey_cap(system_id: String) -> void:
	# Oldest first, and only within the one system that grew: coverage in pyx02
	# must never be what pyx01's four-hundred-and-first mast evicts.
	var prefix := system_id + ":"
	var mine: Array = []
	for k_v in survey_coverage:
		if String(k_v).begins_with(prefix):
			mine.append(String(k_v))
	for i in range(0, mine.size() - SURVEY_CELL_CAP):
		survey_coverage.erase(mine[i])
		# v22. AND ITS FILED FLAG, or the subset invariant breaks and the filed
		# set becomes a second store growing with no bound of its own. A cell
		# that has fallen out of a four-hundred-cell window is one the pilot has
		# surveyed four hundred others since; treating it as fresh on a return
		# is the generous reading and, more importantly, the bounded one.
		survey_filed.erase(mine[i])


func note_survey_filed(key: String) -> bool:
	# Returns whether this cell had NOT been filed before -- the caller pays a
	# first-filing bonus on true and nothing on false. Refuses to file a cell
	# that is not in coverage at all, which is what keeps filed a subset rather
	# than a parallel store that could disagree with it.
	if not survey_coverage.has(key) or survey_filed.has(key):
		return false
	survey_filed[key] = true
	_queue_save()
	return true


func is_survey_filed(key: String) -> bool:
	return survey_filed.has(key)


# v25 (§96). THE VALUE OF A FILED CELL, and until this horizon there was not
# one -- every write was the literal `true`. A cell filed with the refusers'
# network instead of an Authority counter carries HELD instead, so the store
# says WHERE the return went rather than only that it went.
#
# A VALUE, NOT A SECOND SET. A parallel `survey_held` dictionary would be a
# second store needing its own bound, its own loader and its own eviction, and
# §17 refuses exactly that; as a value it inherits the subset invariant and the
# cap for free -- a held cell is evicted with its coverage key like any other,
# and the wreck's four-hundred-cell log stays true.
const HELD := "held"


func is_survey_held(key: String) -> bool:
	# The accessor that did not exist before this horizon: every reader of this
	# store asked `.has()` and nothing anywhere looked at a value.
	#
	# TYPE FIRST, and this is not defensive style -- it is required. The store
	# now holds TWO types: `true` for a counter filing and HELD for a network
	# one, and `String(true)` is not a constructor GDScript has. Written as a
	# bare String() this errored on every counter-filed cell it was asked about
	# and then returned false anyway, so the assertions around it PASSED while
	# the run logged a script error: a green leg standing on a broken call.
	var v = survey_filed.get(key, false)
	return typeof(v) == TYPE_STRING and String(v) == HELD


func note_survey_held(key: String) -> bool:
	# THE SIBLING MUTATOR, and it exists because note_survey_filed CANNOT do
	# this. That function's first line refuses a key already in the store --
	# correctly, for its own job, since filing twice at a counter must not pay
	# twice -- so promoting a cell the pilot already sold at a port is a no-op
	# through it. This one upgrades.
	#
	# Still refuses a cell that is not in coverage, which is where the subset
	# invariant is actually enforced, and still queues the save: a held mark
	# that only reached disk on the next ambient write would be lost to a crash
	# in exactly the session the player flew six thousand units for it.
	if not survey_coverage.has(key) or is_survey_held(key):
		return false
	survey_filed[key] = HELD
	_queue_save()
	return true


func files_with_the_network() -> bool:
	# v25 (§97). Whether this pilot has ever clipped a return to somebody else's
	# mast. DERIVED from the store rather than flagged, the horizon's own rule:
	# a held cell IS the evidence, so there is nothing to keep in step and
	# nothing that can disagree with the chart the player is looking at.
	#
	# What it gates is a REGISTER, never a mechanic: the rival's annotations stop
	# reading as a loss and start reading as a colleague's mark. Nothing about
	# the rival changes -- they still get there first exactly as often, and they
	# still take nothing the player had.
	# THROUGH is_survey_held, NOT by re-reading the value. The first draft of
	# this function was `String(survey_filed[k_v]) == HELD` -- the identical
	# invalid-constructor defect fixed two commits ago, written again in the same
	# file minutes after the rule was recorded. The store holds two types and
	# there is exactly ONE function that knows how to ask; every other reader
	# calls it. That is the durable fix, where "remember to use typeof" is not.
	for k_v in survey_filed:
		if is_survey_held(String(k_v)):
			return true
	return false


func held_cells(system_id := "") -> Array:
	# Coverage that went to the network, optionally for one system. unfiled_cells'
	# shape and unfiled_cells' reason: a UI that wants to say "eleven held"
	# should not be walking the store itself.
	var prefix := system_id + ":"
	var out: Array = []
	for k_v in survey_coverage:
		var k := String(k_v)
		if system_id != "" and not k.begins_with(prefix):
			continue
		if is_survey_held(k):
			out.append(k)
	return out


func unfiled_cells(system_id := "") -> Array:
	# Coverage minus filed, optionally for one system. The pricing half of this
	# lands in the next commit; the accessor is here because the store is here,
	# and because a UI that wants to say "eleven unfiled" should not be walking
	# two dictionaries itself.
	var prefix := system_id + ":"
	var out: Array = []
	for k_v in survey_coverage:
		var k := String(k_v)
		if system_id != "" and not k.begins_with(prefix):
			continue
		if not survey_filed.has(k):
			out.append(k)
	return out


func note_structure_seen(key: String) -> bool:
	# Returns whether this is the FIRST sighting, so the caller can toast once
	# rather than every frame the silhouette is in range.
	if structures_seen.has(key):
		return false
	structures_seen[key] = true
	_queue_save()
	return true


func is_structure_seen(key: String) -> bool:
	return structures_seen.has(key)


func structures_seen_in(system_id: String) -> Array:
	# [{key, index}] for one system, in index order so a UI built from it is
	# stable between frames -- colonies_in's shape and colonies_in's reason.
	# Position is deliberately NOT stored: hyper_positions is a pure function of
	# (system, run_seed) and the chart already calls it, so storing coordinates
	# would be a second copy that could disagree with the generator.
	var out: Array = []
	var prefix := system_id + ":"
	var keys: Array = structures_seen.keys()
	keys.sort()
	for k_v in keys:
		var k := String(k_v)
		if not k.begins_with(prefix):
			continue
		var bits := k.split(":")
		if bits.size() != 2:
			continue
		out.append({"key": k, "index": int(bits[1])})
	return out


# THE ONLY STATE A MARK CAN BE IN TODAY, and the list is the validator: the
# loader accepts a value only if it is in here, so a hand-edited save cannot
# invent a fourth kind of mark and the legends can add theirs by appending one
# string. HELD's neighbour in every respect except that this one was written
# knowing what it was for.
const MARK_READ := "read"
# v25 (§99). AND THE STATE THE STORE WAS SHAPED FOR. A drift whose workshop has
# been cracked is still a read mark -- is_mark_read asks whether the value is a
# legal STATE, not whether it is the first one -- so the channel still skips it
# and the plate still reads. What changes is that the legend does not come back.
#
# This is the whole argument for shipping a validated string one commit early
# rather than a boolean: the store did not change shape, the loader did not
# change, and nothing had to be migrated. One word was added to one list.
const MARK_SPENT := "spent"
# v25 (§101). THE LAYUP'S TWO FACTS, and the ladder becomes a small lattice:
# a cache can be withdrawn from (spent) and deposited into (given), and a pilot
# can have done either, or both (closed), in either order. Four words cover
# every reachable combination, the accessors below own the transitions, and the
# loader still validates by membership with no other change -- the third time
# this store has grown by a word and nothing else.
const MARK_GIVEN := "given"
const MARK_CLOSED := "closed"
const MARK_STATES := ["read", "spent", "given", "closed"]


func mark_key(system_id: String, index: int) -> String:
	return "%s:%d" % [system_id, index]


func is_mark_read(key: String) -> bool:
	# TYPE FIRST, for the reason is_survey_held carries the same guard: the store
	# holds strings, `String(true)` is not a constructor GDScript has, and a bare
	# String() over a rubbish value is a script error inside a call whose
	# assertions would still print PASS. ANY recorded state means resolved --
	# a mark that has been claimed has necessarily been read.
	var v = marks_seen.get(key, "")
	return typeof(v) == TYPE_STRING and MARK_STATES.has(String(v))


func note_mark_read(key: String) -> bool:
	# Returns whether this is the FIRST reading, so the caller can write the log
	# line once rather than on every re-read. Queues the save immediately: a mark
	# read six thousand units out and lost to a crash is a lost expedition.
	if is_mark_read(key):
		return false
	marks_seen[key] = MARK_READ
	_queue_save()
	return true


func note_mark_spent(key: String) -> bool:
	# The legend at this mark has been taken. Refuses a mark that was never read
	# -- you cannot spend what you could not find -- so the two states stay
	# ordered by construction rather than by the caller remembering. A mark
	# already GIVEN closes instead, preserving the deposit fact (§101): spending
	# must never erase that the pilot once left something here.
	if not is_mark_read(key) or is_mark_spent(key):
		return false
	marks_seen[key] = MARK_CLOSED if is_mark_given(key) else MARK_SPENT
	_queue_save()
	return true


func is_mark_spent(key: String) -> bool:
	var v = marks_seen.get(key, "")
	return typeof(v) == TYPE_STRING \
		and (String(v) == MARK_SPENT or String(v) == MARK_CLOSED)


func note_mark_given(key: String) -> bool:
	# §101. Something was left at this mark's cache. Returns whether it is the
	# FIRST deposit -- the plate's clause and the log line fire once -- while
	# the act itself stays repeatable at the node: the arrangement keeps no
	# books, so there is nothing here to count, only the one fact.
	if not is_mark_read(key) or is_mark_given(key):
		return false
	marks_seen[key] = MARK_CLOSED if is_mark_spent(key) else MARK_GIVEN
	_queue_save()
	return true


func is_mark_given(key: String) -> bool:
	var v = marks_seen.get(key, "")
	return typeof(v) == TYPE_STRING \
		and (String(v) == MARK_GIVEN or String(v) == MARK_CLOSED)


func marks_read() -> Dictionary:
	# key -> true for every resolved mark, which is exactly the shape
	# FarMarks.nearest_unseen reads. Built rather than handing the store over
	# directly: the generator asks bool() of what it is given, the store holds
	# STATE STRINGS, and the day a state is added that should not hide a mark
	# from the channel this is the one place that decides. One reader that knows
	# how to ask, per 97's own lesson.
	var out := {}
	for k_v in marks_seen:
		var k := String(k_v)
		if is_mark_read(k):
			out[k] = true
	return out


func _load_survey_filed(saved: Dictionary) -> void:
	# Filtered against COVERAGE rather than against a shape, which is the
	# stronger test and the one the invariant actually needs: a filed key naming
	# a cell this pilot has not surveyed is meaningless whatever it looks like.
	# _load_warehouse validates bay keys against the places that exist, for the
	# same reason.
	survey_filed = {}
	for key_v in saved:
		var key := String(key_v)
		if not survey_coverage.has(key):
			continue
		# v25 (§96). THE VALUE IS PRESERVED, and it was not before -- this line
		# wrote the literal `true` and dropped whatever the file held, which was
		# harmless for two versions because the only value that ever existed WAS
		# true. The moment a cell can be HELD, that same line silently converts
		# every network filing back into a counter filing on the next load: the
		# store would be right all session and wrong forever after, with nothing
		# dropped and no error anywhere.
		#
		# Validated by TYPE rather than by bool() coercion, _load_deep_logs'
		# posture for a store whose value means something. Exactly two values are
		# legal; anything else -- a number, a dictionary, "nonsense" -- is not a
		# third state to be tolerated, it is a corrupt entry to drop. `false`
		# drops here as it always did, which keeps migrate21's rubbish pass true.
		var raw = saved[key_v]
		if typeof(raw) == TYPE_STRING and String(raw) == HELD:
			survey_filed[key] = HELD
		elif typeof(raw) == TYPE_BOOL and bool(raw):
			survey_filed[key] = true


func _load_structures_seen(saved: Dictionary) -> void:
	# Validated against the GENERATOR, the seams_cut posture: the index must
	# still name a structure hyper_positions actually returns. A run_seed change
	# or a retune of HYPER_MIN/MAX must not leave this pointing at a sighting of
	# something that is no longer there.
	structures_seen = {}
	for key_v in saved:
		if not bool(saved[key_v]):
			continue
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 2:
			continue
		var sid := String(bits[0])
		if not SystemDB.exists(sid):
			continue
		if not String(bits[1]).is_valid_int():
			continue
		var idx := int(bits[1])
		if idx < 0 or idx >= SystemDB.hyper_positions(sid, run_seed).size():
			continue
		structures_seen[key] = true


# §106. THE RECAPTURE CLOCK, and it costs zero new mechanism. The wave index is
# DERIVED from a persisted anchor exactly the way ContractDB.board_bucket
# derives a board from played_seconds, and quantised the way Rival quantises
# its strides -- so two world rebuilds seconds apart can never disagree about
# which wave is due, and closing the game for a month does not return the pilot
# to a nursery under its hundredth assault. It races the player's own clock.
const NURSERY_PERIOD := 900.0
# The stride the anchor is rounded to before any comparison. Rival's rule: a
# clock read twice inside one stride answers the same both times.
const NURSERY_STRIDE := 60.0
# What the first wave brings, and what each one after it adds. "In increasing
# numbers, forever" is the index feeding this, capped so forever stays playable
# -- the muster releases six at a time and that is the pacing precedent.
const NURSERY_WAVE_BASE := 3
const NURSERY_WAVE_STEP := 1
const NURSERY_WAVE_MAX := 8


func nursery_key() -> String:
	return String(nursery.get("key", ""))


func holds_nursery() -> bool:
	return not nursery.is_empty()


func take_nursery(key: String, x: float, z: float) -> bool:
	# Taking the ground. Refuses a second claim outright -- there is at most one
	# nursery in a run, and a re-take must go through release_nursery first so
	# the clock restarts from the moment it was actually retaken.
	if holds_nursery():
		return false
	nursery = {"key": key, "x": x, "z": z, "taken_at": played_seconds,
		"waves": int(_nursery_waves_memory.get(key, 0))}
	note_log("TOOK THE TALLY'S GROUND")
	_queue_save()
	return true


func release_nursery() -> void:
	# THEY TOOK IT BACK. The count of waves turned back is remembered against
	# the key rather than reset -- S5: the clock restarts, the record does not.
	# A pilot who held it through nine assaults and lost the tenth has still
	# held it through nine, and retaking it does not make them a novice.
	if not holds_nursery():
		return
	_nursery_waves_memory[String(nursery.get("key", ""))] = int(nursery.get("waves", 0))
	nursery = {}
	note_log("THE TALLY TOOK IT BACK")
	_queue_save()


func nursery_wave_index() -> int:
	# Which assault is due, derived. Quantised to the stride BEFORE the divide,
	# so a rebuild mid-stride cannot advance it.
	if not holds_nursery():
		return 0
	var since := played_seconds - float(nursery.get("taken_at", played_seconds))
	if since <= 0.0:
		return 0
	# floorf, NOT floor: the bare global is untyped, so `:=` cannot infer from
	# it and the whole autoload fails to compile -- which takes every script
	# that depends on it down with it. The typed float variants (floorf, absf,
	# maxf, clampf...) are what this codebase uses everywhere else for exactly
	# this reason.
	var strided := floorf(since / NURSERY_STRIDE) * NURSERY_STRIDE
	return int(floorf(strided / NURSERY_PERIOD))


func nursery_wave_size(index: int) -> int:
	return clampi(NURSERY_WAVE_BASE + NURSERY_WAVE_STEP * maxi(index, 0),
		NURSERY_WAVE_BASE, NURSERY_WAVE_MAX)


func nursery_waves_turned() -> int:
	return int(nursery.get("waves", 0))


func note_nursery_wave_turned() -> void:
	if not holds_nursery():
		return
	nursery["waves"] = int(nursery.get("waves", 0)) + 1
	# THE CLOCK RESTARTS FROM THE VICTORY, not from the founding. Without this
	# the derived index would run away while the pilot was busy winning, and the
	# next assault would arrive already overdue -- several at once, forever.
	nursery["taken_at"] = played_seconds
	_queue_save()


func _load_nursery(saved: Dictionary) -> void:
	# _load_colonies' posture with the generator check its sibling deliberately
	# omits: a colony's stored position IS the colony, but a nursery is pinned
	# to a MARK, so an index FarMarks no longer deals is a nursery standing at
	# nothing. Validated the way marks_seen is.
	nursery = {}
	if saved.is_empty():
		return
	var key := String(saved.get("key", ""))
	var bits := key.split(":")
	if bits.size() != 2:
		return
	var sid := String(bits[0])
	if not SystemDB.exists(sid) or not String(bits[1]).is_valid_int():
		return
	var idx := int(bits[1])
	if idx < 0 or idx >= FarMarks.positions(sid, run_seed).size():
		return
	var x = saved.get("x", null)
	var z = saved.get("z", null)
	if typeof(x) not in [TYPE_FLOAT, TYPE_INT] or typeof(z) not in [TYPE_FLOAT, TYPE_INT]:
		return
	if not is_finite(float(x)) or not is_finite(float(z)):
		return
	# taken_at is clamped to NOW at the top: a hand-edited stamp in the future
	# would make `since` negative forever and freeze the clock, and one absurdly
	# far in the past would land the pilot mid-siege on load.
	var stamp := clampf(float(saved.get("taken_at", played_seconds)),
		0.0, played_seconds)
	nursery = {"key": key, "x": float(x), "z": float(z), "taken_at": stamp,
		"waves": maxi(int(saved.get("waves", 0)), 0)}


func _load_marks_seen(saved: Dictionary) -> void:
	# _load_structures_seen's posture, against the mark generator instead of the
	# instrument one: the index must still name a buoy FarMarks actually returns,
	# so a retune of the depth window or the per-system count cannot leave this
	# pointing at a reading of something that is no longer there.
	#
	# AND THE VALUE IS VALIDATED, NEVER COERCED. `if bool(saved[key_v])` -- the
	# line its sibling above uses correctly, because that store's value carries
	# no information -- would accept 7, "nonsense" and {} here and write them
	# straight back into a store whose value is read as a state. Checked by type
	# and by membership, then PRESERVED: writing the literal MARK_READ instead
	# would throw away exactly what 96 learned the hard way.
	#
	# FarMarks IS A LEAF, so calling it from the autoload closes no class-list
	# cycle: it is a RefCounted of static functions that references SystemDB and
	# nothing else, which is the same edge _load_structures_seen already has one
	# line up. 39's rule is about WORLD classes -- this file still references no
	# node, and SoundingMark is not named anywhere in it.
	marks_seen = {}
	for key_v in saved:
		var raw = saved[key_v]
		if typeof(raw) != TYPE_STRING or not MARK_STATES.has(String(raw)):
			continue
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 2:
			continue
		var sid := String(bits[0])
		if not SystemDB.exists(sid):
			continue
		if not String(bits[1]).is_valid_int():
			continue
		var idx := int(bits[1])
		if idx < 0 or idx >= FarMarks.positions(sid, run_seed).size():
			continue
		marks_seen[key] = String(raw)


func _load_survey(saved: Dictionary) -> void:
	# _load_seams_cut's posture: reset, then filter, dropping rather than
	# crashing. Entries are INSERTED THROUGH THE SAME CAP the write path uses,
	# in file order -- so an over-cap file loads as its newest CAP entries, the
	# same set the write path would have left, and the two enforcement points
	# cannot disagree.
	survey_coverage = {}
	for key_v in saved:
		if not bool(saved[key_v]):
			continue                        # 1. falsey values dropped, not kept
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 3:
			continue                        # 2. shape is system:cx:cz
		if not SystemDB.exists(String(bits[0])):
			continue                        # 3. the system must still exist
		if not String(bits[1]).is_valid_int() or not String(bits[2]).is_valid_int():
			continue                        # 4. both coordinates are integers
		if absi(int(bits[1])) > 1 << 20 or absi(int(bits[2])) > 1 << 20:
			continue                        # 5. and name a cell that can exist --
			                                #    the rift sentinel is 0x7ffffff,
			                                #    and a chart scale fed that cell
			                                #    would span 8.6e9 units
		survey_coverage[key] = true
		_enforce_survey_cap(String(bits[0]))


# --- deep logs (v23, THE UNSOUNDED) ------------------------------------------

# The four records the generator can place. Mirrors UnsoundedSite's kind set by
# hand -- see the deep_logs declaration for why this file will not read it off
# the class -- and the harness pins the two lists against each other so they
# cannot drift apart silently.
const DEEP_LOG_KINDS := ["meridian", "glass", "return", "wreck"]
# The longest record is three fragments; the wreck is one. The loader clamps
# against this rather than trusting the file.
const DEEP_LOG_STAGE_MAX := 3


func deep_log_stage(key: String) -> int:
	# 0 means "never read", which is not a stored state -- absence is the
	# default, the same rule as every other store here.
	return int(deep_logs.get(key, 0))


func note_deep_log(key: String, stages_total: int) -> int:
	# Advance the record by ONE fragment, never further. The fourteen-second
	# hold in unsounded_site.gd is what makes each advance cost standing still
	# in band-6 weather; this function's own contract is narrower -- no single
	# call grants more than one stage, and none past the record's total.
	# Returns the stage now held, unchanged when the record is already complete
	# -- the caller reads "no advance" off equality, not off a second flag.
	var cur := deep_log_stage(key)
	var cap := clampi(stages_total, 1, DEEP_LOG_STAGE_MAX)
	if cur >= cap:
		return cur
	deep_logs[key] = cur + 1
	_queue_save()
	return cur + 1


# §92. WHICH FRAGMENT IS THE ORDER. Directive 9 is fragment 2 of the
# bearing-terminus record, and the two flags below are the whole reveal's
# gating — derived from the store above, so this horizon costs zero bytes and a
# pilot who read the fragments last week is already carrying both.
const DIRECTIVE_STAGE := 2
# The three ARCHIVES, which is DEEP_LOG_KINDS minus the wreck: the wreck is the
# other cartographer's own log, not one of the authority's datums, and holding
# it says nothing about how much of the record the pilot has.
const ARCHIVE_KINDS := ["meridian", "glass", "return"]


func knows_directive_9() -> bool:
	# The PRIVATE beat: the pilot has read the order itself. Gates the ship's
	# line, the log entry and the Commission field — things that belong to the
	# player. The world does not react to this, deliberately (§92): you know,
	# and nothing else does.
	#
	# Derived by SCANNING for any bearing-terminus record rather than asking
	# pyx03 by name, so a future system authoring the `return` datum is covered
	# without a second place to edit — the same reason unsounded_kind_of is data.
	for key_v in deep_logs:
		if String(key_v).ends_with(":return") \
				and int(deep_logs[key_v]) >= DIRECTIVE_STAGE:
			return true
	return false


func heard_the_request() -> bool:
	# v25 (§96). THE THIRD RUNG, and the last one the record has. Fragment 3 of
	# the bearing-terminus archive is the ASK -- "file a return for us" -- and
	# this gates the verb that answers it. One step past knows_directive_9,
	# which gates only knowing the order was given.
	#
	# Scanned for a suffix rather than asked of pyx03 by name, its two siblings'
	# rule: a future system authoring the `return` datum is covered with no
	# second place to edit.
	for key_v in deep_logs:
		if String(key_v).ends_with(":return") \
				and int(deep_logs[key_v]) >= DEEP_LOG_STAGE_MAX:
			return true
	return false


func holds_whole_record() -> bool:
	# The AFTERMATH beat: every archive read to its end. Gates the two voices
	# out past the Quiet that were never the authority's — the deep speaks
	# differently to somebody who knows all of it, and to nobody else.
	#
	# Stage-max rather than a per-kind length, because this file must not reach
	# for UnsoundedSite (§39: the autoload never references a world class). The
	# harness pins the two against each other so an archive that grew a fourth
	# fragment cannot make this flag silently unreachable.
	for kind_v in ARCHIVE_KINDS:
		var suffix := ":" + String(kind_v)
		var held := false
		for key_v in deep_logs:
			if String(key_v).ends_with(suffix) \
					and int(deep_logs[key_v]) >= DEEP_LOG_STAGE_MAX:
				held = true
				break
		if not held:
			return false
	return true


func _load_deep_logs(saved: Dictionary) -> void:
	# _load_structures_seen's posture, validated against what CAN exist: the
	# system must still be authored, the kind must be one the generator places,
	# and the stage must be a real fragment number. Anything else is dropped,
	# not kept and not crashed on.
	deep_logs = {}
	for key_v in saved:
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 2:
			continue
		if not SystemDB.exists(String(bits[0])):
			continue
		if not DEEP_LOG_KINDS.has(String(bits[1])):
			continue
		# THE VALUE'S TYPE, BEFORE ITS RANGE. JSON hands back whatever was in
		# the file, and int() on a dictionary or an array is a conversion this
		# loader should never be asked to make -- a hand-edited save must be
		# dropped here, not turned into a plausible-looking stage number.
		var raw_v = saved[key_v]
		if typeof(raw_v) != TYPE_INT and typeof(raw_v) != TYPE_FLOAT:
			continue
		var stage := int(raw_v)
		if stage < 1 or stage > DEEP_LOG_STAGE_MAX:
			continue
		deep_logs[key] = stage


# --- waypoint beacons (v20, Hunt stage 5) ------------------------------------

# v22: THREE, down from eight — §79's re-derivation, decided from live play
# (§87). Eight was tuned when a beacon was a passive bookmark; navigation made
# each one a free course destination and a jump target, so the stock stopped
# being "enough to thread a route" and became the size of a fast-travel
# network. At three, placing one is a real commitment again, and the recover
# verb — which an eight-stock player never needed — is back in the loop.
const BEACON_STOCK := 3
# The largest stock EVER shipped. The loader bounds a corrupt file against
# this, never against BEACON_STOCK, because a retune must not delete a beacon
# somebody placed: a v21 pilot with five standing beacons keeps all five and
# simply cannot drop new ones until recovery brings them under the new stock.
const BEACON_LEGACY_CAP := 8


func beacon_stock_left() -> int:
	# DERIVED. The stock minus every dropped entry across every system — the one
	# arithmetic, computed where it is asked, so a save edited by hand cannot
	# carry "stock: 9" beside a field of standing beacons.
	#
	# CLAMPED AT ZERO, and only because of the retune: a grandfathered save can
	# legitimately stand more beacons than today's stock, and "-2 IN STOCK" in a
	# toast would be the arithmetic showing through the fiction. Zero reads as
	# what it is — recover before you drop.
	var dropped := 0
	for sid_v in beacons:
		dropped += (beacons[sid_v] as Array).size()
	return maxi(0, BEACON_STOCK - dropped)


func beacons_in(system_id: String) -> Array:
	return beacons.get(system_id, [])


func beacon_rows(system_id: String) -> Array:
	# [{x, z, depth, label}] for one system, nearest first, as a COPY.
	#
	# beacons_in hands out the LIVE array by reference. Every existing caller
	# only reads it, but a UI that sorted it for display would be sorting the
	# save -- which is colonies_in's stated reason for copying, and the drop
	# order is not something a chart layout gets to renumber on disk.
	#
	# THE LABEL IS SYNTHESIZED AT READ TIME, from sorted position, and is
	# deliberately not stored. A designation in the save would be a new field to
	# migrate, a new thing to keep unique, and a new way for the file to
	# disagree with the screen -- for a string the player never types and cannot
	# choose. Nearest-first because that is the order the chart's colony rows
	# already use, for the same reason: the near one is the one you are deciding
	# about.
	var bounds := SystemDB.bounds_of(system_id)
	var out: Array = []
	for e_v in beacons.get(system_id, []):
		var e: Dictionary = e_v
		var x := float(e["x"])
		var z := float(e["z"])
		out.append({"x": x, "z": z,
			"depth": maxf(Vector2(x, z).length() - bounds, 0.0)})
	# Depth first, then the coordinates, so two beacons at the same depth still
	# order deterministically rather than by whatever the save happened to hold.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["depth"]), float(b["depth"])):
			return float(a["depth"]) < float(b["depth"])
		if not is_equal_approx(float(a["x"]), float(b["x"])):
			return float(a["x"]) < float(b["x"])
		return float(a["z"]) < float(b["z"]))
	for i in out.size():
		(out[i] as Dictionary)["label"] = "BEACON %d" % (i + 1)
	return out


func drop_beacon(system_id: String, x: float, z: float, depth: float) -> bool:
	# THE RULE LIVES HERE, not in the button that calls it — §59's lesson about
	# rules that live in a disabled flag. Depth is an ARGUMENT for the same
	# reason integrity is one in divert_power: GameState cannot read the world,
	# and a rule it cannot be handed is a rule it cannot enforce.
	#
	# Refused inside the chart because the chart already remembers every place
	# in it — a beacon there would be a second bookmark on a page that has one.
	if depth <= 0.0:
		return false
	if beacon_stock_left() <= 0:
		return false
	if not SystemDB.exists(system_id):
		return false
	var row: Array = beacons.get(system_id, [])
	row.append({"x": x, "z": z})
	beacons[system_id] = row
	note_log("BEACON DROPPED — %d IN STOCK" % beacon_stock_left())
	_queue_save()
	return true


func recover_beacon(system_id: String, x: float, z: float) -> bool:
	# Keyed by POSITION, never by index: an index held on a live node goes stale
	# the moment a sibling is recovered first, and a position cannot. 0.5u of
	# tolerance is generous against float drift and far under the 34u any two
	# beacons the drop verb places can plausibly sit apart.
	var row: Array = beacons.get(system_id, [])
	for i in range(row.size()):
		var e: Dictionary = row[i]
		if absf(float(e["x"]) - x) < 0.5 and absf(float(e["z"]) - z) < 0.5:
			row.remove_at(i)
			if row.is_empty():
				beacons.erase(system_id)   # sparse, the faction-delta rule
			else:
				beacons[system_id] = row
			_queue_save()
			return true
	return false


func _load_beacons(saved: Dictionary) -> void:
	# Entry-by-entry validation, the apex_intel loader's shape: a file is input,
	# not truth. Unknown systems are dropped, malformed entries are dropped,
	# non-finite coordinates are dropped, and anything past BEACON_LEGACY_CAP in
	# total is dropped — in file order, so which entries survive a corrupt file
	# is deterministic rather than dictionary-order luck. THE LEGACY CAP, not
	# the stock: the bound exists to refuse a corrupt file, and a stock retune
	# must never delete a beacon somebody placed (§87).
	beacons = {}
	var kept := 0
	for sid_v in saved:
		var sid := String(sid_v)
		if not SystemDB.exists(sid):
			continue
		if not (saved[sid_v] is Array):
			continue
		var row: Array = []
		for e_v in saved[sid_v]:
			if kept >= BEACON_LEGACY_CAP:
				break
			if not (e_v is Dictionary):
				continue
			var e: Dictionary = e_v
			if not e.has("x") or not e.has("z"):
				continue
			var ex := float(e["x"])
			var ez := float(e["z"])
			if not (is_finite(ex) and is_finite(ez)):
				continue
			row.append({"x": ex, "z": ez})
			kept += 1
		if not row.is_empty():
			beacons[sid] = row


# --- colonies (v20, Hunt stage 6) --------------------------------------------

func colony_key(system_id: String, index: int) -> String:
	return "%s:%d" % [system_id, index]


func is_colony_claimed(key: String) -> bool:
	return colonies.has(key)


func claim_colony(key: String, x: float, z: float) -> bool:
	if colonies.has(key):
		return false
	colonies[key] = {"x": x, "z": z, "founded_at": played_seconds}
	note_log("COLONY FOUNDED — %s" % key)
	_queue_save()
	return true


func colonies_in(system_id: String) -> Array:
	# [{key, x, z}] for one system, in key order so a UI built from it is
	# stable between frames.
	var out: Array = []
	var prefix := system_id + ":"
	var keys: Array = colonies.keys()
	keys.sort()
	for k_v in keys:
		var k := String(k_v)
		if not k.begins_with(prefix):
			continue
		var e: Dictionary = colonies[k]
		out.append({"key": k, "x": float(e["x"]), "z": float(e["z"])})
	return out


func _load_colonies(saved: Dictionary) -> void:
	# A file is input, not truth. Key shape, system existence, a non-negative
	# index and finite coordinates — each checked, each failure dropping only
	# its own entry.
	#
	# THERE IS DELIBERATELY NO "DOES THIS AGREE WITH run_seed" FILTER. The
	# stored position IS the colony; recomputing hyper_positions and discarding
	# disagreements would delete a founded colony the day the depth band was
	# retuned. _load_apex_intel makes the same choice for the same reason.
	colonies = {}
	for k_v in saved:
		var k := String(k_v)
		var parts := k.split(":")
		if parts.size() != 2:
			continue
		if not SystemDB.exists(String(parts[0])):
			continue
		if not String(parts[1]).is_valid_int() or int(String(parts[1])) < 0:
			continue
		if not (saved[k_v] is Dictionary):
			continue
		var e: Dictionary = saved[k_v]
		if not e.has("x") or not e.has("z"):
			continue
		var ex := float(e["x"])
		var ez := float(e["z"])
		if not (is_finite(ex) and is_finite(ez)):
			continue
		colonies[k] = {"x": ex, "z": ez,
			"founded_at": float(e.get("founded_at", 0.0))}


func _load_apex_intel(saved: Dictionary) -> void:
	# Validated the way _load_seams_cut is, and for a sharper reason: every value
	# here is a NUMBER THE RENDERER TRUSTS. A bearing of NaN or an error of -40
	# does not fail loudly — it silently poisons the estimate, and the survey
	# plot draws a confident cone pointing at nothing.
	#
	# There is deliberately no filter for "does this hint agree with the current
	# run_seed's lair". Contradiction is a legal state of a dossier: a stale
	# rumour and a fresh mast reading disagreeing is the mechanic working, and a
	# loader that quietly discarded the losing hint would be answering the hunt.
	apex_intel = {}
	for sid_v in saved:
		var sid := String(sid_v)
		if not SystemDB.exists(sid):
			continue                       # 1. the system must still exist
		if not (saved[sid_v] is Array):
			continue                       # 2. shape
		var kept: Array = []
		for h_v in (saved[sid_v] as Array):
			if not (h_v is Dictionary):
				continue                   # 3. every entry is a hint dict
			var h: Dictionary = h_v
			# Values, not keys: JSON can hand back a number here, and String()
			# has no constructor for one. Normalised through str(), which
			# accepts anything and lets the checks below reject it on its
			# merits -- the same outcome, without a thrown call. No shipped
			# fixture reaches this today; the berths loader's did.
			var kind := str(h.get("kind", ""))
			if kind == "":
				continue                   # 4. an unattributed hint is unplottable
			if kind == "ring":
				var band := int(h.get("band", -1))
				if band < 0 or band >= DeepSpace.BAND_NAMES.size():
					continue               # 5. must name a band that exists
				if not DeepSpace.QUADRANTS.has(str(h.get("quadrant", ""))):
					continue               # 6. and a real compass sector
				kept.append({"kind": "ring", "band": band,
					"quadrant": str(h.get("quadrant", ""))})
				continue
			# Bearing hints: every number finite, the error a sane half-angle.
			var ox := float(h.get("ox", 0.0))
			var oz := float(h.get("oz", 0.0))
			var bearing := float(h.get("bearing", 0.0))
			var err := float(h.get("err", 0.0))
			if not (is_finite(ox) and is_finite(oz) and is_finite(bearing) and is_finite(err)):
				continue                   # 7. NaN/inf poisons the estimate silently
			if err <= 0.0 or err > 90.0:
				continue                   # 8. a cone with no width, or wider than
				                           #    the rumour that costs a tenth as much
			kept.append({"kind": kind, "ox": ox, "oz": oz,
				"bearing": fposmod(bearing, 360.0), "err": err})
		# 9. Trim to the cap on the way in as well as on the way out: a
		#    hand-edited save must not hand anyone a nine-cone dossier.
		while kept.size() > HINT_CAP:
			var widest := 0
			for i in range(kept.size()):
				if hint_error(kept[i]) > hint_error(kept[widest]):
					widest = i
			kept.remove_at(widest)
		if not kept.is_empty():
			apex_intel[sid] = kept         # 10. empty arrays dropped, not kept
	intel_version += 1


# --- bonded stores ----------------------------------------------------------

func _load_warehouse(saved: Dictionary) -> void:
	# Four filters, every one with precedent above. A raw dictionary is the one
	# save field that arrives with no structure guaranteeing itself, so it gets
	# validated rather than trusted.
	warehouse = {}
	for key_v in saved:
		var key := String(key_v)
		if not _bay_key_is_real(key):
			continue           # 1. the place must exist, and for a deep bay that
			                   #    means the generator must still put a station
			                   #    with a bay in that cell
		var bay := {}
		var contents: Dictionary = saved[key_v]
		for good_v in contents:
			var good := String(good_v)
			if not CommodityDB.exists(good):
				continue       # 2. same filter cargo gets
			if not can_store(good):
				continue       # 3. the bonded rule holds on LOAD too, not only on
				               #    deposit — a good that stops being no_retail in
				               #    some later build must not leave illegal stock
				               #    sitting in bays
			var n := int(contents[good_v])
			if n > 0:
				bay[good] = n  # 4. non-positive counts dropped, not kept at zero
		if not bay.is_empty():
			warehouse[key] = bay
	# Over-capacity bays shed cheapest-first, so a reload is idempotent. Same
	# posture as a fit over its power budget falling back to STARTER_FIT: 16
	# refuses an invalid state rather than tolerating it.
	for key in warehouse.keys():
		for g_v in _stashable_order():
			var g := String(g_v)
			while warehouse_used(String(key)) > WAREHOUSE_SPACE \
					and warehouse_count(String(key), g) > 0:
				var bay2: Dictionary = warehouse[key]
				bay2[g] = int(bay2[g]) - 1
				if int(bay2[g]) <= 0:
					bay2.erase(g)
				warehouse[key] = bay2


func _bay_key_is_real(key: String) -> bool:
	# A chart bay is a port id that declares storage. A deep bay is a cell, and
	# it is checked by RE-DERIVING it: ask the generator what is in that cell and
	# keep the key only if the answer is a station with a bay.
	#
	# This is only possible because the expanse is a pure function (17). A save
	# that has been edited, or written by a build with different station odds,
	# self-corrects instead of carrying phantom bays forever.
	if not key.contains(":"):
		var pdef := SystemDB.port_def_by_id(key)
		return not pdef.is_empty() and port_has_bay(pdef)
	var parts := key.split(":")
	if parts.size() != 3:
		return false
	if not SystemDB.exists(parts[0]):
		return false
	if not parts[1].lstrip("-").is_valid_int() or not parts[2].lstrip("-").is_valid_int():
		return false
	# The live DeepSpace, because re-derivation needs the system that is loaded.
	# A key for a system other than the current one cannot be checked, so it is
	# KEPT — dropping it would silently delete a bay in PYX-02 every time the
	# player saved while standing in PYX-01.
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if main == null or main.deep_space == null:
		return true
	if String(parts[0]) != String(main.system_id):
		return true
	return main.deep_space.cell_has_bay(String(parts[0]), int(parts[1]), int(parts[2]))


func can_store(good: String) -> bool:
	# THE BONDED RULE, and it is one line on purpose.
	#
	# A bay accepts only what the game will never sell you. That closes a money
	# printer no shipped assertion can see: market events last 240-360s, so with
	# an open bay you buy alloys under a 0.55x glut, put them down, wait for the
	# event to lapse, and sell at the SAME counter for 1.61x — no travel, no raid
	# exposure, and the Cantina's rumour tab sells you the event locations.
	# NO ROUND-TRIP PROFIT cannot catch it: it prices both legs in one loop
	# iteration, at one instant, under one market_events array.
	#
	# Closed at the source rather than by capping anything, which is 11's own
	# fix pattern ("a fence buys and does not sell"). No buy leg exists for a
	# no_retail good at any counter, so there is no round trip left to price.
	#
	# It also earns its keep as design rather than as a guard: at Archeology 2 a
	# hold of Reaches and Quiet Salvage is unreadable everywhere and is dead
	# weight. A bay is where you put it down and come back for it at tier 3.
	return CommodityDB.no_retail(good)


func port_has_bay(port_def: Dictionary) -> bool:
	return (port_def.get("services", []) as Array).has("storage")


func warehouse_of(key: String) -> Dictionary:
	return warehouse.get(key, {})


func warehouse_used(key: String) -> int:
	# Measured in SPACE, like the hold, so a bay and a hold are the same currency.
	var used := 0
	for good in warehouse_of(key):
		used += int(warehouse_of(key)[good]) * CommodityDB.space_of(String(good))
	return used


func warehouse_free(key: String) -> int:
	return maxi(0, WAREHOUSE_SPACE - warehouse_used(key))


func warehouse_count(key: String, good: String) -> int:
	return int(warehouse_of(key).get(good, 0))


func store_cargo(key: String, good: String, units: int) -> int:
	# Returns how many units actually moved, like load_cargo.
	if key == "" or units <= 0 or not can_store(good):
		return 0
	var held := cargo_count(good)
	if held <= 0:
		return 0
	var per := maxi(1, CommodityDB.space_of(good))
	var room := warehouse_free(key) / per
	var moved := mini(mini(units, held), room)
	if moved <= 0:
		return 0
	# Out of the hold FIRST, so a failure can never duplicate cargo.
	unload_cargo(good, moved)
	var bay: Dictionary = warehouse.get(key, {})
	bay[good] = int(bay.get(good, 0)) + moved
	warehouse[key] = bay
	_queue_save()
	return moved


func withdraw_cargo(key: String, good: String, units: int) -> int:
	if key == "" or units <= 0:
		return 0
	var stored := warehouse_count(key, good)
	if stored <= 0:
		return 0
	var want := mini(units, stored)
	# load_cargo reports what it actually took; only remove that much from the
	# bay. Nothing may vanish — the same discipline identify() carries.
	var taken := load_cargo(good, want)
	if taken <= 0:
		return 0
	var bay: Dictionary = warehouse[key]
	bay[good] = stored - taken
	if int(bay[good]) <= 0:
		bay.erase(good)
	if bay.is_empty():
		warehouse.erase(key)
	else:
		warehouse[key] = bay
	_queue_save()
	return taken


func _stashable_order() -> Array:
	# Cheapest-first, and for a DIFFERENT reason than jettison_to_fit's.
	#
	# Jettison dumps the cheapest because the player should lose the least. A
	# stash loses nothing, so that argument does not apply and reusing that
	# function would leave a comment that lies. The reason here is that what
	# stays in the hold is what you fly away with — and what you fly away with is
	# what you sell and what draws raiders. So the dense valuable cargo stays
	# aboard deliberately.
	var goods := CommodityDB.ids().filter(func(g) -> bool: return can_store(String(g)))
	goods.sort_custom(func(a, b) -> bool:
		return CommodityDB.base_price(String(a)) < CommodityDB.base_price(String(b)))
	return goods


func stash_would_fit(slot: int, id: String, key: String) -> bool:
	# Can the bay absorb the WHOLE overflow? Asked before anything moves.
	var over := cargo_overflow(slot, id)
	if over <= 0:
		return true
	var room := warehouse_free(key)
	var freed := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		var per := maxi(1, CommodityDB.space_of(g))
		var movable := mini(cargo_count(g), room / per) if per > 0 else 0
		freed += movable * per
		room -= movable * per
		if freed >= over:
			return true
	return false


func stash_to_fit(slot: int, id: String, key: String) -> int:
	# ALL OR NOTHING. A stash that half-fills the bay, still fails the equip and
	# leaves the player over-full with a partly-emptied hold is the worst failure
	# available here — it is READ REFUSED's lesson exactly: nothing may be
	# consumed by an operation that does not complete.
	if not stash_would_fit(slot, id, key):
		return 0
	var moved := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		while cargo_overflow(slot, id) > 0 and cargo_count(g) > 0:
			if store_cargo(key, g, 1) <= 0:
				break
			moved += 1
	return moved


func stash_would_fit_now(key: String) -> bool:
	# The slot-free twin of stash_would_fit, for a console that has no fitting
	# slot to name. The originals take a PROSPECTIVE swap (slot, id) and ask what
	# it would leave over; here the hold is ALREADY over capacity and the
	# question is only whether the bay can take the difference. Passing an
	# arbitrary slot to get at the same answer would be a lie in the code even
	# where the arithmetic happened to come out right.
	var over := cargo_over()
	if over <= 0:
		return true
	var room := warehouse_free(key)
	var freed := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		var per := maxi(1, CommodityDB.space_of(g))
		var movable := mini(cargo_count(g), room / per) if per > 0 else 0
		freed += movable * per
		room -= movable * per
		if freed >= over:
			return true
	return freed >= over


func stash_to_fit_now(key: String) -> int:
	# ALL OR NOTHING, exactly as stash_to_fit is. A stash that half-fills the bay
	# and leaves the player still over-full with a partly-emptied hold is the
	# worst outcome available here.
	if not stash_would_fit_now(key):
		return 0
	var moved := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		while cargo_over() > 0 and cargo_count(g) > 0:
			if store_cargo(key, g, 1) <= 0:
				break
			moved += 1
	return moved


# --- reading salvage --------------------------------------------------------
# ARCHEOLOGY. One skill, three tiers past the start, and it gates INFORMATION
# rather than power — which is what keeps it out of 9's "linear upgrade
# ladder" objection. A higher tier does not make you stronger; it makes a thing
# you were already carrying legible.
#
# One rule covers where you can read:
#
#     in the field   band <= archeology
#     at a lab       band <= archeology + 1
#
# so the lab is always exactly one band ahead of you. There is always a reason to
# carry something home, and always a reason to raise the skill, at every tier.
# v20 THE FRONTIER: two more rungs, because the frontier's salvage grades are
# band 5 and band 6 and the rule above is `band <= archeology (+1 at a lab)`.
# Without them Fathom Salvage is unreadable forever by anybody and the deepest
# loot in the game is a crate you can only sell.
#
# 108 AND 140 ARE A BUDGET, NOT A CURVE. The first draft read 150 and 260,
# extrapolating the ~1.9x/2.3x ratios above, and TIERS caught it: a standard loop
# cracks one hull and reads a hold, which is ARCHEOLOGY_PER_BREACH 4 + 8 reads =
# 12 xp, so a 260 cap is 21.7 loops against a stated ceiling of 12. The rule that
# ceiling protects is "a tier needing fifteen derelicts is content you can see
# and never use" — and the failure it describes is exactly the one these two
# rungs exist to PREVENT, so shipping them out of reach would have made the
# deepest loot in the game a crate you can only sell for hours of play.
#
# So the cap is 144 (12 loops) and the ladder finishes at 140 = 11.7. The
# increments dip from +44 to +30/+32 as a consequence; that is what a fixed
# budget spent over six rungs instead of four looks like, and it is preferable to
# a curve nobody can climb. Raising ARCHEOLOGY_PER_READ to fit was considered and
# refused: it pulls tiers 1-3 in as well and brings forward reading the Quiet's
# salvage, which is an income change against a loop at 97% of its ceiling.
#
# THE UNSOUNDED STAYS LAB-ONLY FOREVER, which is not an oversight: tier 5 is the
# last rung, so band 6 is only ever readable at `archeology + 1`. That is exactly
# the note band 4 used to end on, moved outward — there is still always a reason
# to carry something home.
const ARCHEOLOGY_TIERS := [0, 12, 34, 78, 108, 140]
const ARCHEOLOGY_PER_READ := 1
const ARCHEOLOGY_PER_BREACH := 4

# Set by identify(): true when THAT read crossed a tier threshold. Session-only —
# it is a notification, not state.
var last_read_tiered := false


const SMUGGLING_TIERS := [0, 14, 38, 84]
# What the lanes do for you, tier by tier. NOT credits, and that exclusion is the
# design: a toll discount is a stat denominated in salvage, and a fence premium
# would move _pacing_trade_yield's best legal route and drag the pacing band with
# it. These buy TIME, a CHOICE, and ACCESS — 19's "gates how the world treats
# you, never what your ship can do".
const SMUGGLING_STANDOFF_BONUS := 3.0   # t1: three more seconds to read a demand
const SMUGGLING_BLUFF_TIER := 2         # t2: the bluff button appears
const SMUGGLING_BLUFF_BASE := 0.40      # printed on the button, never hidden
const SMUGGLING_BLUFF_PER_TIER := 0.10
const SMUGGLING_ACCESS_TIER := 3        # t3: deep fences deal in more of it
# Which goods pay. Deliberately a small explicit set rather than "anything a
# fence takes": components are fenced too, and letting them count would level
# smuggling off the same salvage run that levels archeology.
const SMUGGLING_GOODS := ["contraband", "stolen"]


func smuggling_next_at() -> int:
	var next := smuggling + 1
	return SMUGGLING_TIERS[next] if next < SMUGGLING_TIERS.size() else -1


func mark_smuggling(units: int) -> bool:
	if units <= 0 or smuggling >= SMUGGLING_TIERS.size() - 1:
		return false
	smuggling_xp += units
	var gained := false
	while smuggling < SMUGGLING_TIERS.size() - 1 \
			and smuggling_xp >= SMUGGLING_TIERS[smuggling + 1]:
		smuggling += 1
		gained = true
	# ONE line naming the tier the player LANDED on, not one per tier crossed.
	# The loop can cross two at once on a big sale, and the toast the player
	# actually saw announces only the final tier — a log that disagreed with the
	# announcement would be a log describing a different evening.
	if gained:
		note_log("SMUGGLING %d — THE LANES KNOW YOU" % smuggling)
	_queue_save()
	return gained


# --- PERSUASION (v19) --------------------------------------------------------
# Counted in PARLEYS TALKED DOWN, not in units of anything — which is why the
# numbers are small next to the other three ladders. A raid needs RAID_MIN_HOLD
# aboard and clears a cooldown before it can roll at all, so nine successes is a
# long acquaintance with the Tithe rather than an afternoon.
const PERSUASION_TIERS := [0, 2, 5, 9]
# WHAT A TIER BUYS: better odds on the same conversation, and nothing else. Never
# credits and never a cheaper toll — a toll discount is a stat denominated in
# salvage, which is the exclusion SMUGGLING_TIERS states above and the reason
# NO PRICE TIERS exists.
#
# THE BASE IS NON-ZERO AT TIER 0, deliberately, and it is also the fix for what
# the playtest actually hit. bluff_odds returned 0.0 below smuggling 2, and the
# plate was gated a second time on holding a Forged Manifest, so a new pilot met
# a demand that named three answers with one button on the screen. Everybody can
# try talking; being good at it is what is earned.
const PERSUASION_BLUFF_BASE := 0.15
const PERSUASION_BLUFF_PER_TIER := 0.10
# What a failed talk-down costs the Tithe's opinion of you. The mirror of the +1
# pay_toll books, and the stake without which this would be a free roll.
const PERSUASION_FAILURE_COST := -1
# Both ladders can raise the same plate, so their sum needs a ceiling. 0.80 keeps
# the top of the game an honest bet rather than a formality — 12's standard is an
# honest bad bet you can SEE, and a 100% "gamble" is a button, not a wager.
const BLUFF_ODDS_CAP := 0.80


func persuasion_next_at() -> int:
	var next := persuasion + 1
	return PERSUASION_TIERS[next] if next < PERSUASION_TIERS.size() else -1


func mark_persuasion(wins: int) -> bool:
	if wins <= 0 or persuasion >= PERSUASION_TIERS.size() - 1:
		return false
	persuasion_xp += wins
	var gained := false
	while persuasion < PERSUASION_TIERS.size() - 1 \
			and persuasion_xp >= PERSUASION_TIERS[persuasion + 1]:
		persuasion += 1
		gained = true
	# ONE line naming the tier the player LANDED on, like the other three.
	if gained:
		note_log("PERSUASION %d — THEY LISTEN TO YOU" % persuasion)
	_queue_save()
	return gained


func persuasion_line() -> String:
	var next_at := persuasion_next_at()
	var tail := ("%d TO NEXT" % (next_at - persuasion_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	if persuasion < 1:
		return "PERSUASION 0 — TALK A RAIDER PACK DOWN INSTEAD OF PAYING · %d%% · %s" % [
			int(persuasion_odds() * 100.0), tail]
	return "PERSUASION %d — TALK A PACK DOWN · %d%% · %s" % [
		persuasion, int(persuasion_odds() * 100.0), tail]


func persuasion_odds() -> float:
	return PERSUASION_BLUFF_BASE + PERSUASION_BLUFF_PER_TIER * float(persuasion)


func manifest_odds() -> float:
	# SMUGGLING's half, unchanged in value and now named for what it is. It was
	# always the social mechanic in this game in everything but title; what moved
	# is only that it is no longer the ONLY way to raise the plate.
	if smuggling < SMUGGLING_BLUFF_TIER:
		return 0.0
	return SMUGGLING_BLUFF_BASE + SMUGGLING_BLUFF_PER_TIER \
		* float(smuggling - SMUGGLING_BLUFF_TIER)


func bluff_odds() -> float:
	# TWO LADDERS, SUMMED, CAPPED. A pilot who has never talked to anybody but
	# carries a manifest at smuggling 2 reads exactly 40% — the number that
	# shipped — so nothing is taken away from a save that already earned it. The
	# manifest half is only counted when the manifest is actually aboard, because
	# it is the stake being wagered rather than a stat.
	var odds := persuasion_odds()
	if hold_has("manifest_forged"):
		odds += manifest_odds()
	return minf(odds, BLUFF_ODDS_CAP)


func smuggling_line() -> String:
	var next_at := smuggling_next_at()
	var tail := ("%d TO NEXT" % (next_at - smuggling_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# TIER 0 NAMES THE VERB AND THE DESK, per §58's copy rule. "THE LANES DO NOT
	# KNOW YOU YET" states an absence, and this ladder needs the opposite more
	# than any other: XP comes ONLY from a FENCE sale (Market.fences), and in
	# charted space exactly two counters qualify. THE GRINNING VOID is the trap —
	# it sells contraband, calls itself the smuggler's den and has a fence tab,
	# but contraband is absent from its fence_goods, so selling it back there
	# completes, pays credits, and moves the ladder by nothing. A playtester
	# reached 68 minutes at smuggling 0 while carrying stolen goods.
	var perk := "FENCE CONTRABAND OR STOLEN — THE CANTINA TAKES BOTH"
	if smuggling >= SMUGGLING_ACCESS_TIER:
		perk = "DEEP FENCES DEAL IN ANYTHING YOU CARRY"
	elif smuggling >= SMUGGLING_BLUFF_TIER:
		# NAMES ITS OWN CONTRIBUTION, not the total. Since v19 two ladders raise
		# the bluff plate, and printing the sum here would have SMUGGLING taking
		# credit for what PERSUASION earned — the A10 complaint (a number moved
		# and nothing said which of the last ten seconds moved it) reproduced in
		# a skill readout.
		perk = "A FORGED MANIFEST BUYS YOU +%d%% ON A BLUFF" % int(manifest_odds() * 100.0)
	elif smuggling >= 1:
		perk = "THE LANES WARN YOU EARLY"
	return "SMUGGLING %d — %s · %s" % [smuggling, perk, tail]


# v14. MINING. Tops out higher than the other two ladders (78 and 84), and that
# is not an inconsistency: the three are earned in DIFFERENT UNITS, so comparing
# their top values is a category error. What matters is sessions-to-max, and the
# weighting is what sets it — a seam pays XP equal to its BAND, so 110 is about
# fourteen sessions of working the Shoals and three and a half of working the
# Quiet. The shallow grind being genuinely slow is the same anti-farm gradient
# the ore prices encode, said again in the skill.
const MINING_TIERS := [0, 18, 50, 110]
# What the tiers buy: INFORMATION, a CHOICE, and ACCESS. Never credits, never a
# yield — util_assay already owns the yield axis, and a tier that paid would put
# a second earner under a loop already at 97% of its ceiling. TIERS BUY NO
# CREDITS asserts it rather than trusting the comment.
const MINING_READ_TIER := 1     # t1: the radar marker takes the ore's colour
# ACCESS BEFORE CONVENIENCE, and these two were the other way round until the
# playtest. MINING_DEEP_TIER was 3 — which is MINING_TIERS' MAX index — so
# band-4 access, the only 4-XP rung on the board, unlocked exactly when there was
# nothing left to earn with it. The perk bought nothing, and the tuning note
# above (which prices the whole ladder as "three and a half sessions of working
# the Quiet") described a rate no live ladder could ever reach: the constant and
# the comment contradicted each other, and the comment was the honest one.
#
# Swapped rather than lowered, so every tier still buys something. Access is what
# a climbing skill needs; taking a core sample and moving on is a convenience,
# which is the right shape for the top of a ladder.
const MINING_DEEP_TIER := 2     # t2: band-4 seams can be worked at all
const MINING_SAMPLE_TIER := 3   # t3: release past halfway and keep half the cut
const MINING_SAMPLE_FRACTION := 0.5


func mining_next_at() -> int:
	var next := mining + 1
	return MINING_TIERS[next] if next < MINING_TIERS.size() else -1


func mark_mining(band: int) -> bool:
	# Weighted by BAND, and fed by the CUT rather than the SALE. Selling ore is a
	# dock visit, which a smuggler makes anyway; cutting rock is the verb this
	# skill is about. MINING PAYS ON SEAMS, NOT SALES asserts the distinction.
	var xp := maxi(band, 1)
	if mining >= MINING_TIERS.size() - 1:
		return false
	mining_xp += xp
	var gained := false
	while mining < MINING_TIERS.size() - 1 and mining_xp >= MINING_TIERS[mining + 1]:
		mining += 1
		gained = true
	# One line naming the tier LANDED on, matching mark_smuggling: a big band-4
	# cut can cross two at once, and the log must not disagree with the toast.
	if gained:
		note_log("MINING %d — THE ROCK READS DIFFERENTLY NOW" % mining)
	_queue_save()
	return gained


func can_work_band(band: int) -> bool:
	# t3 is ACCESS: the deepest seams are refused until the skill is there. A
	# locked seam stays visible and says why -- a thing you can see and cannot
	# have is a goal, and a thing that is simply absent is nothing at all.
	return band < 4 or mining >= MINING_DEEP_TIER


func mining_line() -> String:
	var next_at := mining_next_at()
	var tail := ("%d TO NEXT" % (next_at - mining_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# HIGHEST TIER FIRST, and the order follows the CONSTANTS rather than the
	# names — the sample and the deep perk swapped tiers, and a chain that still
	# tested DEEP first would report the tier-2 perk to a tier-3 pilot.
	var perk := "ORE READS AS GREY ROCK"
	if mining >= MINING_SAMPLE_TIER:
		perk = "YOU CAN TAKE A CORE SAMPLE AND MOVE ON"
	elif mining >= MINING_DEEP_TIER:
		perk = "THE QUIET'S SEAMS WILL OPEN FOR YOU"
	elif mining >= MINING_READ_TIER:
		perk = "YOU READ A SEAM'S ORE AT A DISTANCE"
	# AND THE TIER-0 LINE NAMES THE VERB, per §58's rule that a line must either
	# use a word the game has taught or say what to do about it. "ORE READS AS
	# GREY ROCK" describes an absence to a pilot who has no idea the ladder
	# exists — and mining's is the one that most needs saying, because the
	# ELEVEN authored charted seams are worth 11 XP against a tier-1 threshold of
	# 18. A player who never crosses the marker cannot reach tier 1 at all. That
	# is the design (charted mining is a windfall, not an income); the silence
	# about it was not.
	if mining < MINING_READ_TIER:
		perk = "CUT SEAMS PAST THE MARKER — THE DEEP ONES ARE WORTH MORE"
	return "MINING %d — %s · %s" % [mining, perk, tail]


# --- charted seams ----------------------------------------------------------

func seam_key(system_id: String, index: int) -> String:
	return "%s:%d" % [system_id, index]


func is_seam_cut(key: String) -> bool:
	return seams_cut.has(key)


func note_seam_cut(key: String) -> void:
	if key == "":
		return
	seams_cut[key] = true
	_queue_save()


# --- the intel dossier ------------------------------------------------------

func apex_hints(system_id: String) -> Array:
	# A COPY. Callers plot from this every frame; handing out the live array
	# invites a renderer to sort it in place and quietly reorder what the cap
	# evicts next.
	return (apex_intel.get(system_id, []) as Array).duplicate()


func apex_hint_count(system_id: String) -> int:
	return (apex_intel.get(system_id, []) as Array).size()


func add_apex_hint(system_id: String, hint: Dictionary) -> bool:
	# Returns whether the dossier actually took it, so a channel that charges
	# for a reading can refuse to charge for one it could not file.
	#
	# A system with no engine left cannot accumulate intel: the kill deletes the
	# entry, and without this guard the next mast in a cleared system would
	# start a fresh dossier for a hunt that is already over.
	if not SystemDB.exists(system_id) or apex_killed.has(system_id):
		return false
	if not apex_intel.has(system_id):
		apex_intel[system_id] = []
	var list: Array = apex_intel[system_id]

	# Same channel, same origin, same bearing: a re-read of the same instrument
	# from the same spot. Refused rather than stacked — otherwise parking on a
	# mast and re-triggering it would narrow the estimate for free, and the
	# whole design is that precision is bought.
	for h_v in list:
		var h: Dictionary = h_v
		if String(h.get("kind", "")) != String(hint.get("kind", "")):
			continue
		if String(hint.get("kind", "")) == "ring":
			if int(h.get("band", -1)) == int(hint.get("band", -2)) \
					and String(h.get("quadrant", "")) == String(hint.get("quadrant", "")):
				return false
		elif is_equal_approx(float(h.get("ox", 0.0)), float(hint.get("ox", 0.0))) \
				and is_equal_approx(float(h.get("oz", 0.0)), float(hint.get("oz", 0.0))):
			return false

	list.append(hint)
	# Widest error evicted first, and ONLY once over the cap — a stable sort on
	# every insert would reorder equal-error hints for no reason.
	if list.size() > HINT_CAP:
		var widest := 0
		for i in range(list.size()):
			if hint_error(list[i]) > hint_error(list[widest]):
				widest = i
		list.remove_at(widest)
	intel_version += 1
	_queue_save()
	return true


func hint_error(hint: Dictionary) -> float:
	# A ring hint has no half-angle of its own, so it is scored as the quadrant
	# it names: 90 degrees, wider than any bearing channel in the game. That is
	# what makes the cap evict rumours before it evicts instrument readings.
	if String(hint.get("kind", "")) == "ring":
		return 90.0
	return float(hint.get("err", 90.0))


func clear_apex_intel(system_id: String) -> void:
	if not apex_intel.has(system_id):
		return
	apex_intel.erase(system_id)
	intel_version += 1
	_queue_save()


func archeology_line() -> String:
	# ONE RULE, three renderers — the lab head, the pause menu and the refit
	# strip. The string was written once inside the lab tab, which meant the only
	# place a pilot could read their own skill was a console they had to fly to a
	# station to open. There is deliberately no skill SCREEN ("a skill with its
	# own screen is a skill that has become bookkeeping"); what was missing was
	# never a tree, it was visibility.
	var readable: String = DeepSpace.BAND_NAMES[mini(archeology + 1,
		DeepSpace.BAND_NAMES.size() - 1)]
	var field: String = DeepSpace.BAND_NAMES[mini(archeology,
		DeepSpace.BAND_NAMES.size() - 1)]
	var next_at := archeology_next_at()
	# FLOORED AT ZERO. The subtraction was unguarded, and it only ever showed a
	# sane number because the ladder's top rung was also the last one: xp could
	# not sit above a threshold that did not exist. Adding two rungs made
	# `next_at` a real number where it used to be -1, and a hold carrying more xp
	# than the next tier costs printed "· -891 TO NEXT" on the pilot strip.
	# Nothing about the arithmetic was frontier-specific; the frontier only made
	# it reachable.
	var tail := ("%d TO NEXT" % maxi(next_at - archeology_xp, 0)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# AND AT TIER 0 IT SAYS WHAT TO DO. Breaching hulls is the feed that carries
	# this ladder on its own — a playtester's 48 xp was 12 breaches x 4 exactly,
	# with ZERO from the other feed — so the verb worth naming is the one nobody
	# uses: reading. It is also the hub, because Reaches salvage reads as the
	# Forged Manifest that smuggling's and persuasion's bluff both want.
	if archeology < 1:
		return "ARCHEOLOGY 0 — BREACH HULLS, AND READ WHAT THEY HOLD AT A LAB · %s" % tail
	return "ARCHEOLOGY %d — READS %s IN THE FIELD, %s AT A LAB · %s" % [
		archeology, field, readable, tail]


func archeology_next_at() -> int:
	# XP needed for the next tier, or -1 at the cap.
	var next := archeology + 1
	return ARCHEOLOGY_TIERS[next] if next < ARCHEOLOGY_TIERS.size() else -1


func mark_archeology(xp: int) -> bool:
	# Returns true if a tier was gained, so callers can announce it.
	if xp <= 0 or archeology >= ARCHEOLOGY_TIERS.size() - 1:
		return false
	archeology_xp += xp
	var gained := false
	while archeology < ARCHEOLOGY_TIERS.size() - 1 \
			and archeology_xp >= ARCHEOLOGY_TIERS[archeology + 1]:
		archeology += 1
		gained = true
	# One line, final tier only — see mark_smuggling for why.
	if gained:
		note_log("ARCHEOLOGY %d — READS %s" % [archeology,
			DeepSpace.BAND_NAMES[mini(archeology, DeepSpace.BAND_NAMES.size() - 1)]])
	_queue_save()
	return gained


func can_read(salvage_id: String, at_lab: bool) -> bool:
	var band := CommodityDB.band_of(salvage_id)
	if band < 0:
		return false
	return band <= archeology + (1 if at_lab else 0)


func skill_ids() -> Array:
	return SKILL_TIERS.keys()


func skill_xp(id: String) -> int:
	return int(skills.get(id, 0))


func skill_tier(id: String) -> int:
	# DERIVED, NEVER STORED. The legacy four keep a tier var beside an xp var and
	# a loader that clamps one against the other; this cannot drift because there
	# is only one number.
	var tiers: Array = SKILL_TIERS.get(id, [])
	var xp := skill_xp(id)
	var t := 0
	for i in range(tiers.size()):
		if xp >= int(tiers[i]):
			t = i
	return t


func skill_cap(id: String) -> int:
	return maxi((SKILL_TIERS.get(id, [0]) as Array).size() - 1, 0)


func skill_to_next(id: String) -> int:
	# -1 at the cap, which is what the line renders as NOTHING LEFT TO LEARN.
	var tiers: Array = SKILL_TIERS.get(id, [])
	var t := skill_tier(id)
	if t >= tiers.size() - 1:
		return -1
	return maxi(int(tiers[t + 1]) - skill_xp(id), 0)


func mark_skill(id: String, n := 1) -> bool:
	# THE ONE MUTATOR, and it returns whether a TIER landed rather than whether
	# xp moved -- mark_mining's signature, and for its reason: the caller wants
	# to know whether to say something, and xp moves constantly.
	if not SKILL_TIERS.has(id) or n <= 0:
		return false
	var before := skill_tier(id)
	skills[id] = skill_xp(id) + n
	var after := skill_tier(id)
	_queue_save()
	if after <= before:
		return false
	# The FINAL tier only. A jump of two rungs is one line in the log, not two --
	# mark_smuggling's rule.
	note_log("%s %d — %s" % [String(SKILL_LABELS.get(id, id.to_upper())), after,
		String((SKILL_PERKS.get(id, []) as Array)[after])])
	return true


func skill_line(id: String) -> String:
	# ONE RULE, rendered everywhere. The legacy four each wrote their own; these
	# share this, so a new ladder is a table row and never a line function.
	var label := String(SKILL_LABELS.get(id, id.to_upper()))
	var t := skill_tier(id)
	if t <= 0:
		# §58: the unearned rung names the ACT, not the gate.
		return "%s 0 — %s" % [label, String(SKILL_VERBS.get(id, ""))]
	var perk := String((SKILL_PERKS.get(id, []) as Array)[t])
	var left := skill_to_next(id)
	if left < 0:
		return "%s %d — %s · NOTHING LEFT TO LEARN" % [label, t, perk]
	return "%s %d — %s · %d TO NEXT" % [label, t, perk, left]


func note_read(component: String) -> void:
	# The order desk's gate, written by the one thing that produces a component.
	if CommodityDB.is_component(component):
		reads_done[component] = int(reads_done.get(component, 0)) + 1


func has_read(component: String) -> bool:
	return int(reads_done.get(component, 0)) > 0


func orders_at(port_key: String) -> Array:
	var out: Array = []
	for o in requisition_orders:
		if String((o as Dictionary).get("port", "")) == port_key:
			out.append(o)
	return out


func order_ready(order: Dictionary) -> bool:
	return played_seconds - float(order.get("at", 0.0)) >= REQ_DELAY


func order_seconds_left(order: Dictionary) -> float:
	return maxf(REQ_DELAY - (played_seconds - float(order.get("at", 0.0))), 0.0)


func can_order(good: String) -> bool:
	# THREE REFUSALS, and each states its own terms at the desk. Not a component,
	# never read one, or the book is full.
	if not CommodityDB.is_component(good):
		return false
	if not has_read(good):
		return false
	return requisition_orders.size() < REQ_MAX_OPEN


func place_order(good: String, port_key: String) -> bool:
	# The CALLER pays -- port_panel._order does, the way _buy does -- so this
	# stays a store and the counter stays the place money changes hands.
	if not can_order(good):
		return false
	requisition_orders.append({"good": good, "port": port_key, "at": played_seconds})
	_queue_save()
	return true


func collect_order(index: int) -> bool:
	if index < 0 or index >= requisition_orders.size():
		return false
	var o: Dictionary = requisition_orders[index]
	if not order_ready(o):
		return false
	var good := String(o.get("good", ""))
	# ALL OR NOTHING, and the order SURVIVES a full hold. A requisition that
	# evaporated because the player arrived with two spare units of space would
	# be paid-for cargo deleted by a rounding error -- mineable_seam's own rule,
	# and the reason it asks before it spends.
	if cargo_free() < CommodityDB.space_of(good):
		return false
	if load_cargo(good, 1) < 1:
		return false
	requisition_orders.remove_at(index)
	_queue_save()
	return true


func identify(salvage_id: String, output_id: String, at_lab: bool) -> bool:
	# Consumes one unit of salvage and produces one of the chosen output. The
	# player picks the output from CommodityDB.reads_as() — there is no roll here
	# and there must never be one; see the comment on READS_AS.
	if cargo_count(salvage_id) <= 0:
		return false
	if not CommodityDB.reads_as(salvage_id).has(output_id):
		return false
	if not can_read(salvage_id, at_lab):
		return false
	# Space first. A component can be bulkier than the salvage it came out of, and
	# a read that cannot be stowed must fail cleanly rather than half-happen.
	var freed := CommodityDB.space_of(salvage_id)
	var needed := CommodityDB.space_of(output_id)
	if cargo_free() + freed < needed:
		return false
	unload_cargo(salvage_id, 1)
	if load_cargo(output_id, 1) < 1:
		load_cargo(salvage_id, 1)   # put it back; nothing may vanish
		return false
	# Reported, not swallowed. A tier that arrives in silence cannot teach the
	# player anything, and "did 0->1 arrive fast enough" is the whole question the
	# first play-test has to answer.
	last_read_tiered = mark_archeology(ARCHEOLOGY_PER_READ)
	# §110. The order desk sources what you have held. Recorded HERE, in the one
	# function that has ever produced a component, so the gate cannot drift from
	# the thing it gates on.
	note_read(output_id)

	# SOMEBODY ELSE'S CHART, read properly. `index_cartographic` is the one
	# salvage in the catalog that literally IS a survey somebody else made, so it
	# is the natural carrier for a bearing — and reading it is already a
	# deliberate, paid-for act at a lab bench rather than something that happens
	# to you. The reading is taken from where the ship is, because that is where
	# the chart is being cross-referenced against known positions, which is
	# exactly the geometry a cone from here describes.
	#
	# ±12°: wider than a mast, because a mast measures the engine live and this
	# infers it from someone else's decade-old survey.
	if salvage_id == "index_cartographic":
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var main: Node = tree.get_first_node_in_group("main")
			if main != null and main.has_method("file_apex_intel"):
				var player: Node3D = tree.get_first_node_in_group("player") as Node3D
				var from := Vector3.ZERO
				if player != null:
					from = player.global_position
				main.file_apex_intel("relic", from, 12.0)

	_queue_save()
	return true


func hold_has(good: String) -> bool:
	# What the world reads to decide whether a carried thing is doing something.
	# Deliberately NOT a fitted stat: cargo_after() probes compute_stats(fit) while
	# cargo_capacity() reads live stats, so a good that moved a fitted number would
	# make the hold guard subtract two different piles from each other.
	return cargo_count(good) > 0


func _sanitize_ship_name(raw: String) -> String:
	var clean := raw.strip_edges()
	if clean.length() > SHIP_NAME_MAX:
		clean = clean.substr(0, SHIP_NAME_MAX)
	return clean if clean != "" else DEFAULT_SHIP_NAME


func set_ship_name(raw: String) -> void:
	ship_name = _sanitize_ship_name(raw)
	_queue_save()


func note_ledger(key: String, amount: int) -> void:
	# Deliberately does NOT _queue_save. distance_flown ticks every physics frame,
	# and a save on each would be a disk write per frame — the same reasoning
	# played_seconds already carries. The logbook rides the ambient saves and the
	# close-request flush.
	if not DEFAULT_LEDGER.has(key) or amount <= 0:
		return
	ledger[key] = int(ledger.get(key, 0)) + amount


func note_ledger_max(key: String, value: int) -> void:
	# For records rather than tallies: deepest_depth is a high-water mark, and
	# adding to it every frame would make it a distance counter by accident.
	if not DEFAULT_LEDGER.has(key):
		return
	ledger[key] = maxi(int(ledger.get(key, 0)), value)


func note_log(line: String) -> void:
	# DISCRETE EVENTS ONLY. A per-frame source here would fill all ten slots in
	# under a second and evict the run — which is the same reason note_ledger
	# exists separately from this.
	#
	# Deliberately does NOT _queue_save, and the reason is stronger than
	# note_ledger's disk-write one: this array and `deepest_depth` are written by
	# the SAME save_game() dict, so they can never disagree. Saving the log on its
	# own would let a line naming THE DRIFT outlive a high-water mark that never
	# reached it — and the next crossing would then log the band a second time.
	# They ride the ambient saves together or not at all.
	var clean := line.strip_edges()
	if clean == "":
		return
	if clean.length() > LOG_LINE_MAX:
		clean = clean.substr(0, LOG_LINE_MAX)
	captains_log.append(clean)
	while captains_log.size() > LOG_MAX:
		captains_log.remove_at(0)


func log_lines() -> Array:
	# One read-only accessor, the title_summary() precedent: the text a player
	# sees is worth asserting and nothing else can reach it. A duplicate, so a
	# renderer cannot quietly become a second writer.
	return captains_log.duplicate()


func strip_hottest(target_value: int) -> int:
	# The raiders' half of a paid parley: cargo comes out HOTTEST FIRST —
	# interdiction weight x value — because they take what they came for. The
	# deliberate asymmetry with jettison_to_fit's cheapest-first is the point:
	# there the PLAYER chooses what to lose, here the raiders do. Returns the
	# base value actually removed. Pays nothing, transfers nothing — a departing
	# raider carrying the toll would hand it back to anyone who shot them, which
	# is the printer.
	if target_value <= 0:
		return 0
	var order := CommodityDB.ids().filter(func(g) -> bool: return cargo_count(String(g)) > 0)
	order.sort_custom(func(a, b) -> bool:
		return CommodityDB.interdiction_weight(String(a)) * CommodityDB.base_price(String(a)) \
			> CommodityDB.interdiction_weight(String(b)) * CommodityDB.base_price(String(b)))
	var removed := 0
	for g_v in order:
		var g := String(g_v)
		while removed < target_value and cargo_count(g) > 0:
			unload_cargo(g, 1)
			removed += CommodityDB.base_price(g)
	if removed > 0:
		_queue_save()
	return removed


func jettison(good: String, units: int) -> int:
	# Deliberately pays nothing. Dumping cargo to fit a refit is a cost you chose
	# over flying to a port, and paying for it would make it the better option.
	var removed := unload_cargo(good, units)
	if removed > 0:
		_queue_save()
	return removed


func jettison_to_fit(slot: int, id: String) -> int:
	# Dumps cheapest-first until the swap is legal, so the player loses the least
	# valuable thing in the hold rather than whatever happens to be iterated first.
	var goods := CommodityDB.ids()
	goods.sort_custom(func(a, b) -> bool:
		return CommodityDB.base_price(String(a)) < CommodityDB.base_price(String(b)))
	var dumped := 0
	for g_v in goods:
		var g := String(g_v)
		while cargo_overflow(slot, id) > 0 and cargo_count(g) > 0:
			unload_cargo(g, 1)
			dumped += 1
	if dumped > 0:
		_queue_save()
	return dumped


func equip(slot: int, id: String) -> bool:
	if not can_equip(slot, id):
		return false
	fit[slot] = id
	_recompute()
	_queue_save()
	return true


func fit_has(module_id: String) -> bool:
	# Is this module actually EQUIPPED — not merely owned. Fitted world-effects
	# are read through this at their point of use, exactly the way carried ones
	# are read through hold_has(), and deliberately NOT through compute_stats:
	# 19's rule is that a thing may change what the world does to you or what the
	# ship can do, never both, and the hold guard subtracts two different piles
	# the moment those cross.
	for slot in fit:
		if String(fit[slot]) == module_id:
			return true
	return false


func can_craft(id: String) -> bool:
	var rec := ModuleDB.recipe(id)
	if rec.is_empty() or owns(id):
		return false
	for good in rec:
		if cargo_count(String(good)) < int(rec[good]):
			return false
	return true


func craft(id: String) -> bool:
	# Consumes the components and hands over the module. Costs no salvage: the
	# price is the fence sale you did not make, which for these inputs is over
	# two thousand at a deep haven — dearer than most of the catalog.
	if not can_craft(id):
		return false
	var rec := ModuleDB.recipe(id)
	for good in rec:
		unload_cargo(String(good), int(rec[good]))
	owned.append(id)
	_queue_save()
	fit_changed.emit(stats)
	return true


func grant_module(id: String) -> bool:
	# v25 (§99). A MODULE THAT ARRIVES WITHOUT A COUNTER. craft() is the same
	# verb with a recipe in front of it and buy() is the same verb with a price;
	# this is the one for a thing that was found. Kept separate rather than
	# calling buy(0), which would SUCCEED at price zero for any module in the
	# catalogue -- the guarantee that a prototype is not for sale is its absence
	# from every stock list, and a zero-price buy path is exactly how that
	# guarantee would be reached around.
	#
	# Returns false when the pilot already owns it, which is not a failure but
	# an ANSWER: the caller has to have something to say about a second copy,
	# and the drift does.
	if not ModuleDB.exists(id) or owns(id):
		return false
	owned.append(id)
	_queue_save()
	fit_changed.emit(stats)
	return true


func buy(id: String) -> bool:
	if not ModuleDB.exists(id) or owns(id):
		return false
	var price := int(ModuleDB.get_module(id)["price"])
	if not spend_salvage(price):
		return false
	owned.append(id)
	_queue_save()
	return true


func upgrade_reactor(cap := ModuleDB.REACTOR_CAP_DEFAULT) -> bool:
	# THE CAP ARRIVES AS AN ARGUMENT, the way drop_beacon's depth does: GameState
	# cannot read the world, and a rule it cannot be handed is a rule it cannot
	# enforce. The caller is the counter, and the counter knows what it stocks.
	#
	# Defaulted so every existing call site keeps the shipped ceiling. Before
	# this the function checked nothing but the price, which would have put the
	# Mk V — the deepest purchase in the game, meant to be bought at the far end
	# of the Unsounded — on sale at the Waypoint Anchor.
	var next := reactor_tier + 1
	if next >= ModuleDB.REACTOR_TIERS.size():
		return false
	if next > cap:
		return false
	if not spend_salvage(int(ModuleDB.REACTOR_TIERS[next]["price"])):
		return false
	reactor_tier = next
	_recompute()
	_queue_save()
	return true


func reactor_name() -> String:
	return ModuleDB.REACTOR_TIERS[reactor_tier]["name"]


func next_reactor_price(cap := ModuleDB.REACTOR_CAP_DEFAULT) -> int:
	# -1 means "nothing to sell you here", and it now covers two different
	# reasons: the ladder is finished, or this counter does not go that high. The
	# row reads the reason off reactor_tier rather than off this number, so the
	# player is told which.
	var next := reactor_tier + 1
	if next >= ModuleDB.REACTOR_TIERS.size() or next > cap:
		return -1
	return int(ModuleDB.REACTOR_TIERS[next]["price"])


func preview_stats(slot: int, id: String) -> Dictionary:
	# DIVERSIONS ARE FOLDED IN HERE TOO, and leaving them out made every refit
	# delta lie while one was live. UIKit.delta_line renders
	# delta_lines(GameState.stats, after): the BEFORE has diversions in it and
	# the AFTER did not, so with a mount burned into the drive every weapon in
	# the list advertised a fabricated ~+100% DPS gain, and equipping one
	# re-applied the halving the strip had just promised to undo. A delta is only
	# meaningful between two comparable worlds.
	var probe := fit.duplicate()
	probe[slot] = id
	# AND THE BERTHS RIDE THE PROBE (v24), by the same argument the paragraph
	# above makes about diversions: a delta is only meaningful between two
	# comparable worlds. GameState.stats is computed with the hull's mass in it,
	# so an AFTER computed without it would advertise a speed gain on every swap
	# a berthed pilot previewed -- the identical defect, from the other side.
	return ModuleDB.enforce_floors(
		SectionDB.apply(ModuleDB.compute_stats(probe, berths), diverts))


func can_divert(source: String, target: String, integrity: float) -> bool:
	# THE WHOLE RULE, ASKED RATHER THAN RE-DERIVED. The panel needs to know which
	# rows to light up and divert_power needs to know what to refuse, and those
	# are the same question -- the moment they are answered in two places they
	# disagree, which is how "you may only burn something broken" ended up living
	# in a `disabled` flag. divert_power is now a thin wrapper over this.
	if not SectionDB.is_section(source) or not SectionDB.is_section(target):
		return false
	if source == target:
		return false
	# Only a damaged section has power going spare, and a working section is
	# never a legal source however desperate the player is.
	if not SectionDB.is_damaged(source, integrity):
		return false
	if SectionDB.is_damaged(target, integrity):
		return false
	# Nothing is spent twice, in any of the four directions.
	if diverts.has(source) or diverts.has(target):
		return false
	if diverts.values().has(source) or diverts.values().has(target):
		return false
	# And a system cannot pay itself -- see divert_power's note.
	if String(SectionDB.section(source).get("governs", "")) \
			== String(SectionDB.section(target).get("governs", "")):
		return false
	return true


func divert_power(source: String, target: String, integrity: float) -> bool:
	# BURN A DAMAGED SECTION TO OVERCHARGE A WORKING ONE. Refuses rather than
	# half-applies, so a caller cannot mistake "nothing happened" for a trade --
	# claim_commission's rule, and the panel reads the return to decide whether
	# to narrate.
	#
	# A THIN WRAPPER OVER can_divert, deliberately. The first draft spelled the
	# rules out here and let the panel decide which rows were tappable, which put
	# "you may only burn something already broken" in the RENDERING -- true only
	# until somebody added a second caller, and invisible to any assertion that
	# did not drive a UI. The panel now asks can_divert too, so there is exactly
	# one answer and the mutator cannot drift from what the sheet offered.
	#
	# INTEGRITY IS AN ARGUMENT because GameState cannot read the ship's shields:
	# the caller passes what it measured.
	if not can_divert(source, target, integrity):
		return false
	diverts[source] = target
	_recompute()
	return true


func clear_diverts() -> bool:
	# Docking is repair. Returns whether anything was actually undone so the
	# dock line can stay quiet on a ship that never diverted.
	if diverts.is_empty():
		return false
	diverts = {}
	_recompute()
	return true


func _recompute() -> void:
	stats = ModuleDB.compute_stats(fit, berths)
	# AFTER the catalog, never inside it. compute_stats is pure over a fit and is
	# probed speculatively by the refit sheet and by cargo_after(); folding a
	# live diversion into it would make those previews describe a ship that only
	# exists while something is burned out.
	stats = SectionDB.apply(stats, diverts)
	# AND THE FLOORS GO BACK ON. compute_stats applies them and SectionDB then
	# multiplies through them, so without this a diversion could put a legal fit
	# under a bound the catalog guarantees to every ship.
	stats = ModuleDB.enforce_floors(stats)
	fit_changed.emit(stats)


# --- persistence -----------------------------------------------------------

func _queue_save() -> void:
	# Debounced: loot pickups fire constantly during a vortex.
	if _save_timer != null:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		save_game()
	)


func save_dict() -> Dictionary:
	# EXACTLY WHAT GETS WRITTEN, and nothing about writing it. Extracted from
	# save_game (§92) so a harness can ask "did this feature add a field?"
	# by comparing two of these -- the claim that a horizon costs zero bytes is
	# only worth as much as the check behind it, and every previous version of
	# that check had to write a file to the disk to make it.
	#
	# Pure: it reads state and returns a dictionary. save_game keeps every
	# decision about WHETHER and WHERE to write.
	var fit_out := {}
	for slot in fit:
		fit_out[str(slot)] = fit[slot]
	return {
		"version": SAVE_VERSION,
		"salvage": salvage,
		"owned": owned,
		"fit": fit_out,
		"reactor_tier": reactor_tier,
		"berths": berths,
		"current_system": current_system,
		"breached": breached,
		"contract_state": contract_state,
		"barks_seen": barks_seen,
		"apex_killed": apex_killed,
		"apex_down": apex_down,
		"lanes_open": lanes_open,
		"run_seed": run_seed,
		"cargo": cargo,
		"played_seconds": played_seconds,
		"docked_at": docked_at,
		"market_pressure": market_pressure,
		"market_stock": market_stock,
		"requisition_orders": requisition_orders,
		"reads_done": reads_done,
		"skills": skills,
		"market_events": market_events,
		# NO `settings` AND NO `audio_muted`. Both moved to prefs.json when the
		# save became per-pilot: they belong to the device, and leaving them here
		# would mean switching pilots rebinds the player's keyboard and changes
		# their colour-vision mode. Saves written before the split still carry
		# them and load_game still reads them -- once, to seed prefs.json -- but
		# nothing writes them again, so the stale copies age out on first save.
		#
		# `tutorial_step` stays: a pilot halfway through step three is run state.
		# What is shared is `tutorial_seen` in prefs, which only decides whether a
		# NEW pilot starts at -1.
		"tutorial_step": tutorial_step,
		"livery": livery,
		"archeology": archeology,
		"archeology_xp": archeology_xp,
		"smuggling": smuggling,
		"smuggling_xp": smuggling_xp,
		"mining": mining,
		"mining_xp": mining_xp,
		"persuasion": persuasion,
		"persuasion_xp": persuasion_xp,
		"seams_cut": seams_cut,
		"survey_coverage": survey_coverage,
		"survey_filed": survey_filed,
		"structures_seen": structures_seen,
		"deep_logs": deep_logs,
		"marks_seen": marks_seen,
		"nursery": nursery,
		"apex_intel": apex_intel,
		"beacons": beacons,
		"colonies": colonies,
		"last_outbound_jump": last_outbound_jump,
		"warehouse": warehouse,
		"ledger": ledger,
		"ship_name": ship_name,
		"captains_log": captains_log,
		"commission_claimed": commission_claimed,
		"commissioned": commissioned,
		"faction_deltas": faction_deltas,
	}


func save_game() -> void:
	if not save_enabled:
		return
	var data := save_dict()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Pyxis: could not open save for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# The registry row follows the save it describes, so the title screen's
	# summary is the last thing this pilot actually did.
	#
	# DOUBLE-GUARDED, and the second guard is the one that matters: a harness
	# redirects save_path to a probe file WITHOUT redirecting the registry, so
	# `save_path == the active pilot's path` is what proves this write belongs to
	# a real pilot rather than to a test that happens to be running.
	if active_profile != "" and save_path == Profiles.save_path_for(active_profile):
		Profiles.touch(active_profile, Time.get_unix_time_from_system(), {
			"ship_name": ship_name,
			"deepest": int(ledger.get("deepest_depth", 0)),
			"hulks": int(ledger.get("hulks_cracked", 0)),
			"flown": int(ledger.get("distance_flown", 0)),
			"commissioned": commissioned,
		})


func can_switch_profile() -> bool:
	# Public so the pilots page can REFUSE BEFORE IT CREATES. Profiles.create
	# stamps the new id as active, so asking afterwards leaves an empty folder
	# holding the active flag every time the answer is no.
	return not newer_save_refused


func switch_profile(id: String) -> bool:
	# THE ONE FUNCTION, because `save_path = X; load_game()` is not a switch.
	# load_game no-ops on a missing file and returns false, which would leave the
	# OUTGOING pilot fully loaded in memory under the incoming pilot's name --
	# the first thing that then saved would write one run into another's folder.
	if id == "":
		return false
	# GATED ON THE REFUSAL, NOT ON save_enabled. lock_saving() is one-way and
	# process-wide, and load_game takes it whenever it meets a save from a newer
	# build -- which was fine when there was one save and is wrong now that there
	# are five. One future-dated pilot would otherwise make EVERY row on the
	# pilots page a dead button for the rest of the session, with four perfectly
	# readable runs behind them. The lock is about the FILE it refused, and this
	# is moving away from that file.
	if not can_switch_profile():
		return false
	# The outgoing pilot is written FIRST and synchronously, because _queue_save's
	# one-second debounce is pending on almost every switch and the run would
	# otherwise lose its last second of play. Clearing the handle afterwards only
	# lets a fresh save queue immediately; it does not cancel the pending
	# callback, which is safe because every line below runs without an await, so
	# that callback cannot land between save_path moving and load_game reading.
	if active_profile != "":
		save_game()
		_save_timer = null
	active_profile = id
	save_path = Profiles.save_path_for(id)
	Profiles.set_active(id)
	if not load_game():
		# A pilot with no file yet -- the row exists, the run does not. Starter
		# state, and `tutorial_seen` decides whether they are walked through it.
		reset_to_starter()
		# AND THE THREE reset_to_starter WILL NOT TOUCH. Its comments call
		# ship_name, livery and commissioned things that "outlive the run", and
		# they are right about the run -- they are wrong about the PILOT, which
		# is the distinction this horizon settled. Left alone, a brand-new pilot
		# boots wearing the outgoing pilot's paint, under their ship's name,
		# already commissioned, and their first save writes all three into the
		# new file permanently. reset_to_starter is not changed, because a NEW
		# SURVEY on one pilot should still keep that pilot's identity; the
		# difference belongs here, where the pilot itself changes.
		ship_name = DEFAULT_SHIP_NAME
		livery = DEFAULT_LIVERY.duplicate()
		commissioned = false
		tutorial_step = -1 if tutorial_seen else 0
	# Nothing below is in the save and none of it is cleared by reset_to_starter,
	# so without these three the new pilot inherits the old one's derived stats,
	# their power diversions and their last tier readout.
	diverts = {}
	last_read_tiered = false
	_recompute()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	# The save carries no diversions by design, so loading one has to CLEAR them
	# rather than merely not set them -- CONTINUE from the title runs through
	# here with a live dictionary from the abandoned run still in memory.
	diverts = {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pyxis: save unreadable, starting fresh")
		return false
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		# REFUSING IT IS NOT ENOUGH. _ready calls reset_to_starter() when this
		# returns false, and the first _queue_save() a second later writes a
		# starter run straight over the file -- so running an older build once,
		# after a rollback or on a second machine or a beta lane, DELETED the
		# run rather than declining to open it. The only notice was a
		# push_warning, which on a phone is no notice at all.
		#
		# lock_saving() is the existing one-way "never write" and is exactly the
		# right shape: nothing downstream can opt back in, so the newer file
		# survives the session no matter what the player does next.
		push_warning("Pyxis: save is v%d, this build reads v%d — not loaded, and saving is locked so it cannot be overwritten" % [version, SAVE_VERSION])
		newer_save_refused = true
		lock_saving()
		return false
	if version <= 0:
		# A save with no readable version is not a save from the future, it is
		# rubbish -- there is nothing here to protect, so this keeps the old
		# start-fresh behaviour.
		push_warning("Pyxis: save version %d unsupported, starting fresh" % version)
		return false
	# Older saves are migrated, never discarded: any field added after their
	# version simply falls back to its default below.

	# Cleared on the way past the gate, not left latched: load_game is called
	# again whenever the save layer is pointed somewhere else, and a stale flag
	# would keep the title screen refusing a run it had just read fine.
	newer_save_refused = false

	salvage = int(data.get("salvage", 0))
	owned = []
	for id in data.get("owned", []):
		if ModuleDB.exists(str(id)):
			owned.append(str(id))
	for id in ModuleDB.STARTER_OWNED:
		if not owned.has(id):
			owned.append(id)

	# v24 BERTHS, and this must load BEFORE the fit below: the fit loop asks
	# slot_unlocked, and a berth read afterwards would drop every module standing
	# in a berth slot on every load. Validated against the catalog, deduplicated,
	# dropping what it does not recognise -- `owned`'s posture one block up.
	berths = []
	for bid_v in (data.get("berths", []) as Array):
		# TYPE FIRST. This is an ARRAY out of JSON, not a dictionary key, so its
		# elements can be anything a file holds -- and `String(7)` is not a
		# constructor GDScript has. Written bare, migrate23's own rubbish
		# fixture (which puts a 7 in this list precisely to be rejected) threw a
		# script error on the way to rejecting it: the leg passed, the loader
		# was right, and the run logged an error. A loader's contract is DROP,
		# NEVER CRASH, and a thrown call is not a drop.
		if typeof(bid_v) != TYPE_STRING:
			continue
		var bid := String(bid_v)
		if ModuleDB.BERTHS.has(bid) and not berths.has(bid):
			berths.append(bid)

	# v7 adds Slot.UTILITY_B. Starting from STARTER_FIT means any slot a saved fit
	# does not mention simply keeps its default — so a v6 fit loads with the new
	# slot empty and needs no migration branch of its own. v24's berth slots are
	# absent from STARTER_FIT for the same reason and arrive the same way.
	fit = ModuleDB.STARTER_FIT.duplicate()
	var saved_fit: Dictionary = data.get("fit", {})
	for key in saved_fit:
		var slot := int(key)
		var id := str(saved_fit[key])
		# v24. AND THE SLOT MUST EXIST ON THIS HULL. can_equip is not the only
		# door into `fit` -- a hand-edited file is the other one -- so a module
		# standing in a berth this pilot never bought is dropped here rather
		# than being flown for free.
		if not slot_unlocked(slot):
			continue
		if id == "" or (ModuleDB.exists(id) and owned.has(id)):
			fit[slot] = id

	reactor_tier = clampi(int(data.get("reactor_tier", 0)), 0, ModuleDB.REACTOR_TIERS.size() - 1)

	# v2 fields. A v1 save has none of these and gets sane defaults.
	current_system = str(data.get("current_system", SystemDB.START_SYSTEM))
	if not SystemDB.exists(current_system):
		current_system = SystemDB.START_SYSTEM
	breached = []
	for id in data.get("breached", []):
		if SystemDB.exists(str(id)):
			breached.append(str(id))
	contract_state = data.get("contract_state", {})
	barks_seen = []
	for key in data.get("barks_seen", []):
		barks_seen.append(str(key))
	# v3 field; absent in v1 and v2 saves, which simply start with no apex kills.
	apex_killed = []
	for id in data.get("apex_killed", []):
		if SystemDB.exists(str(id)):
			apex_killed.append(str(id))

	# v17. THE SECOND GRANDFATHER, and it is the conservative one on purpose.
	#
	# Before v17 the kill was not persisted at all, so a v16 save cannot tell us
	# which engines are down — only which ones PAID, in apex_killed. Seeding from
	# that is exact where it speaks and silent where it does not: a player who
	# cracked a wreck never sees that engine again, which is the fix they are
	# owed, and nobody is handed a system they did not clear.
	#
	# It under-counts by exactly one case — killed, warped out, wreck never
	# cracked — and that is the right way to be wrong. Under-counting rebuilds an
	# engine the player already beat, which is today's behaviour and merely
	# unchanged; over-counting would delete a wreck worth up to 32,000 credits
	# that they can still see on the radar. NOT seeded from lanes_open for the
	# same reason: its own pre-v15 grandfather fills it from `breached`, so a save
	# old enough would report living engines as dead.
	apex_down = []
	if data.has("apex_down"):
		for id in data.get("apex_down", []):
			if SystemDB.exists(str(id)) and not apex_down.has(str(id)):
				apex_down.append(str(id))
	else:
		apex_down = apex_killed.duplicate()

	# v15. THE GRANDFATHER, and it is the whole reason this stage is safe to ship.
	#
	# Before v15 a breach opened the lane. A player who breached PYX-01 last night
	# could fly to PYX-02 this morning — and a straight `lanes_open = []` default
	# would take that away, because their save has no such key and their engine is
	# very much alive. Revoking access a player already had is the one migration
	# outcome this codebase will not ship.
	#
	# So an absent key means "this save predates the split": every system they had
	# BREACHED is treated as a lane they had OPEN. It costs them nothing and grants
	# nothing new — it reproduces exactly the reachability the old rule gave them.
	# A v15+ save always writes the key, so this branch is genuinely only ever
	# taken once per save file. Asserted by SAVETEST=migrate14.
	lanes_open = []
	if data.has("lanes_open"):
		for id in data.get("lanes_open", []):
			if SystemDB.exists(str(id)) and not lanes_open.has(str(id)):
				lanes_open.append(str(id))
	else:
		lanes_open = breached.duplicate()

	# 0 means "no run salt yet" — a pre-v15 save, or one written before the field
	# existed. Roll one rather than leaving every such save sharing seed 0, which
	# would hide every lair in the same place for every returning player.
	run_seed = int(data.get("run_seed", 0))
	if run_seed == 0:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		run_seed = seed_rng.randi()

	# v4 economy fields; absent in v1-v3 saves, which simply start with an empty
	# hold, a fresh clock, and a market at rest.
	cargo = {}
	for good in data.get("cargo", {}):
		var id := str(good)
		if CommodityDB.exists(id):
			cargo[id] = int(data["cargo"][good])
	played_seconds = float(data.get("played_seconds", 0.0))
	docked_at = str(data.get("docked_at", ""))
	market_pressure = {}
	for k in data.get("market_pressure", {}):
		market_pressure[str(k)] = clampf(float(data["market_pressure"][k]),
			-Market.PRESSURE_CAP, Market.PRESSURE_CAP)
	# v27. Entry by entry, dropping rather than crashing -- _load_seams_cut's
	# posture. Four ways a hand-edited file is refused: a value that is not a
	# dictionary, a key with no counter/good join in it, a good this build has
	# never heard of, and a deficit at or below zero (which is not a hole, it is
	# the default, and the default is never written down).
	#
	# A stamp is CLAMPED rather than dropped. A clock from the future is corrupt
	# bookkeeping about a shelf that really is empty, and clamping it to now
	# replenishes from this instant -- the safe direction, and the nursery's rule
	# for the same shape of rubbish. It must run after played_seconds is read.
	market_stock = {}
	for k in data.get("market_stock", {}):
		var sk := str(k)
		var srec = data["market_stock"][k]
		if typeof(srec) != TYPE_DICTIONARY or not sk.contains("|"):
			continue
		if not CommodityDB.exists(sk.substr(sk.rfind("|") + 1)):
			continue
		var sd := int((srec as Dictionary).get("d", 0))
		if sd <= 0:
			continue
		var st := float((srec as Dictionary).get("t", 0.0))
		if st < 0.0 or st > played_seconds:
			st = played_seconds
		market_stock[sk] = {"d": sd, "t": st}
	# v27 (§110). Same posture, one row at a time. An order must name a component
	# this build still has, sit on a real point of the player's own clock, and
	# survive the open cap -- which is enforced here as well as at the desk,
	# because the desk is a button and this is the rule.
	requisition_orders = []
	for o in data.get("requisition_orders", []):
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var og := str((o as Dictionary).get("good", ""))
		if not CommodityDB.is_component(og):
			continue
		var oat := float((o as Dictionary).get("at", 0.0))
		if oat < 0.0 or oat > played_seconds:
			oat = played_seconds
		requisition_orders.append({
			"good": og,
			"port": str((o as Dictionary).get("port", "")),
			"at": oat,
		})
		if requisition_orders.size() >= REQ_MAX_OPEN:
			break
	reads_done = {}
	for rk in data.get("reads_done", {}):
		var rid := str(rk)
		if not CommodityDB.is_component(rid):
			continue
		var rn := int(data["reads_done"][rk])
		if rn > 0:
			reads_done[rid] = rn
	# v27 (§111). Only ids this build still has, only positive xp. No clamp on
	# the value: xp past the last rung is harmless (the tier derives to the cap)
	# and clamping it would silently rewrite a save every time a tier is added.
	skills = {}
	for kk in data.get("skills", {}):
		var kid := str(kk)
		if not SKILL_TIERS.has(kid):
			continue
		var kx := int(data["skills"][kk])
		if kx > 0:
			skills[kid] = kx
	# v5 fields. Anyone loading a v1-v4 save has been playing already, so the
	# tutorial is treated as finished rather than replayed at them.
	#
	# audio_muted only when prefs.json has not spoken -- same seeding rule as
	# `settings` below. Reading it unconditionally would mean loading a pilot who
	# was saved muted mutes the device for every other pilot.
	if not _prefs_loaded:
		audio_muted = bool(data.get("audio_muted", false))
	tutorial_step = int(data.get("tutorial_step", -1))
	# v8. A v7 save simply arrives at tier 0 with nothing read — no branch needed,
	# which is the whole reason load_game has never had one.
	archeology = clampi(int(data.get("archeology", 0)), 0, ARCHEOLOGY_TIERS.size() - 1)
	archeology_xp = maxi(int(data.get("archeology_xp", 0)), 0)
	smuggling = clampi(int(data.get("smuggling", 0)), 0, SMUGGLING_TIERS.size() - 1)
	smuggling_xp = maxi(int(data.get("smuggling_xp", 0)), 0)
	# v14. A v13 save arrives at mining 0 with nothing cut, by the same policy —
	# there is no migration branch here and there never has been one.
	mining = clampi(int(data.get("mining", 0)), 0, MINING_TIERS.size() - 1)
	mining_xp = maxi(int(data.get("mining_xp", 0)), 0)
	# v19. PERSUASION, and there is no migration branch here for the reason there
	# has never been one on this path: an absent key defaults, and tier 0 with no
	# xp is exactly what a pilot who has never talked a pack down should load as.
	# Seeding it from smuggling_xp was considered and refused — migrate13 records
	# why a truthy default that hands a returning player a skill they never
	# touched is the wrong kind of generosity.
	persuasion = clampi(int(data.get("persuasion", 0)), 0, PERSUASION_TIERS.size() - 1)
	persuasion_xp = maxi(int(data.get("persuasion_xp", 0)), 0)
	_load_seams_cut(data.get("seams_cut", {}))
	# v21. Defaults-not-branches: a v20 file has no key, gets {}, and loads as a
	# pilot who has surveyed nothing -- which, before v21, is what every pilot
	# effectively was between sessions.
	_load_survey(data.get("survey_coverage", {}))
	# v22. AFTER coverage, both of them, and the order is load-bearing for the
	# first: _load_survey_filed filters against the coverage store, so it has to
	# run once coverage is populated or every filed key is dropped as unknown.
	_load_survey_filed(data.get("survey_filed", {}))
	_load_structures_seen(data.get("structures_seen", {}))
	# v23. Defaults-not-branches again: a v22 file has no key, gets {}, and
	# loads as a pilot who has read nothing -- true of every pilot before the
	# unsounded existed.
	_load_deep_logs(data.get("deep_logs", {}))
	# 98. Rides v25 with no bump: a file from either earlier v25 commit has no
	# key, gets {}, and loads as a pilot who has read no marks.
	_load_marks_seen(data.get("marks_seen", {}))
	# v26. Defaults-not-branches, the standing rule: a v25 file has no key, gets
	# {}, and loads as a pilot who never took the ground -- true of every pilot
	# before the nursery existed.
	_load_nursery(data.get("nursery", {}))
	_load_apex_intel(data.get("apex_intel", {}))
	# v20. Beacons: no migration branch, per this file's standing rule — an
	# absent key is an empty store and a full stock, which is exactly what a
	# pilot who has never dropped one should load as.
	_load_beacons(data.get("beacons", {}))
	# v20 stage 6, riding the same version as beacons — one bump for both stores,
	# since neither needs a grandfather and an absent key is the correct empty.
	_load_colonies(data.get("colonies", {}))
	# BOTH KEYS, and no version bump. A rename is a shape change only if the old
	# file stops loading; reading the legacy key as the default for the new one
	# means a v20 save keeps its cooldown instead of silently coming back with
	# the drives cold. Defaults-not-branches, one line.
	last_outbound_jump = float(data.get("last_outbound_jump",
		data.get("last_colony_jump", -1.0e9)))
	_load_warehouse(data.get("warehouse", {}))
	# v18. A v17 save has no key and arrives at the authored baseline — which by
	# construction IS the world that save was written in, so the migration can
	# neither grant nor revoke anything. No grandfather branch needed, and per
	# the v8/v14 precedent there never should be one.
	_load_faction_deltas(data.get("faction_deltas", {}))

	# v6 fields. Merged key-by-key onto the defaults rather than taken wholesale,
	# so a v6 save written before a later setting existed still gets that
	# setting's default instead of a missing key.
	#
	# ONLY WHEN prefs.json IS NOT THERE. These keys stopped being written to the
	# save when device preferences moved out of it, but every save written before
	# that still carries them -- and on the first boot after upgrading they are
	# the only copy of the player's bindings and volumes, so they seed the new
	# file. Once prefs.json exists it is the authority and the save's stale copy
	# is ignored rather than merged, or switching pilots would drag one pilot's
	# keyboard onto another.
	if not _prefs_loaded:
		settings = DEFAULT_SETTINGS.duplicate()
		var saved_settings: Dictionary = data.get("settings", {})
		for key in DEFAULT_SETTINGS:
			if saved_settings.has(key):
				settings[key] = saved_settings[key]
		_clamp_settings()

	livery = DEFAULT_LIVERY.duplicate()
	var saved_livery: Dictionary = data.get("livery", {})
	for key in DEFAULT_LIVERY:
		if saved_livery.has(key):
			livery[key] = int(saved_livery[key])
	# CLAMPED. These were the only ints in load_game with no bound, protected
	# solely by Palette's posmod wrap -- which is not protection, it is a rename:
	# `accent: 17` wraps to 1 and `accent: 8` wraps to 0, so a hand-edited save
	# silently wears a colour it never earned rather than being corrected. That
	# becomes load-bearing the moment an accent is EARNED rather than bought,
	# because player_ship.gd reads Palette.livery_accent(livery_index("accent"))
	# directly and never asks set_livery anything.
	livery["hull"] = clampi(int(livery["hull"]), 0, Palette.LIVERY_HULLS.size() - 1)
	livery["accent"] = clampi(int(livery["accent"]), 0, Palette.LIVERY_ACCENTS.size() - 1)

	# Key by key onto the defaults, so a v9 save arrives with every counter at 0
	# rather than with the dict missing. Floored at 0: a hand-edited negative
	# would print as a nonsense logbook line forever.
	ledger = DEFAULT_LEDGER.duplicate()
	var saved_ledger: Dictionary = data.get("ledger", {})
	for key in DEFAULT_LEDGER:
		if saved_ledger.has(key):
			ledger[key] = maxi(0, int(saved_ledger[key]))
	ship_name = _sanitize_ship_name(str(data.get("ship_name", DEFAULT_SHIP_NAME)))

	# v13. Clamped against STAGES.size() rather than a literal 4, so adding a
	# fifth stage cannot leave a stale bound behind. A v12 save arrives with
	# nothing claimed and uncommissioned, which is the correct reading of a save
	# written before the Commission existed.
	commission_claimed = clampi(int(data.get("commission_claimed", 0)), 0, CommissionDB.count())
	commissioned = bool(data.get("commissioned", false))
	# The accent lock, AT THE LOAD PATH. Finding 2: a hand-edited save never calls
	# set_livery, and the ship reads the index straight out of Palette -- so this
	# is the only place that can refuse it. The clamp above turns 17 into a valid
	# index; this turns a valid-but-unearned one into 0.
	if not commissioned and int(livery["accent"]) >= REGISTRY_ACCENT:
		livery["accent"] = 0

	# v12. Rebuilt element by element rather than taken wholesale — the
	# market_events posture — so a save carrying a number, a null or a 200-char
	# line arrives as a valid log instead of as a crash in the pause menu. Shed
	# from the FRONT, keeping the NEWEST ten: an over-long log is the same
	# invalid state an over-capacity warehouse is, and it self-corrects the same
	# way rather than being tolerated.
	captains_log = []
	for entry in data.get("captains_log", []):
		var line := str(entry).strip_edges()
		if line == "":
			continue
		if line.length() > LOG_LINE_MAX:
			line = line.substr(0, LOG_LINE_MAX)
		captains_log.append(line)
	while captains_log.size() > LOG_MAX:
		captains_log.remove_at(0)

	market_events = []
	for e in data.get("market_events", []):
		var ev: Dictionary = e
		if CommodityDB.exists(str(ev.get("good", ""))) and float(ev.get("remaining", 0.0)) > 0.0:
			market_events.append({
				"kind": str(ev.get("kind", "shortage")),
				"port": str(ev.get("port", "")),
				"good": str(ev.get("good", "")),
				# v27/§108. Two additive fields, defaults-not-branches: a save
				# written before deep weather existed has neither, arrives with
				# an empty name and deep=false, and Market.event_place falls back
				# to the chart for it -- which is exactly what it was.
				"name": str(ev.get("name", "")),
				"deep": bool(ev.get("deep", false)),
				"mult": float(ev.get("mult", 1.0)),
				"remaining": float(ev.get("remaining", 0.0)),
			})
	# Never strand the player in a system they can no longer reach.
	if not is_system_unlocked(current_system):
		current_system = SystemDB.START_SYSTEM

	# A fit that no longer fits the budget (edited save, changed balance) falls
	# back rather than trapping the player in an invalid state.
	if ModuleDB.power_draw(fit) > power_cap():
		fit = ModuleDB.STARTER_FIT.duplicate()
	return true


func _notification(what: int) -> void:
	# BACKGROUNDING A PHONE IS NOT A CLOSE. Until this clause, the only triggers
	# here were the desktop window closing and the object being deleted -- so on
	# the platform this game is actually FOR, everything since the last debounced
	# write depended on the player returning to the app. A task-switch that the OS
	# then reclaimed took it. Saving on pause costs one write at the moment the
	# player stops playing, which is exactly when it is free.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
		_save_prefs()
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_game()
		# One row per session, at the same moment the save is written. Guarded by
		# save_enabled for the same reason save_game is: a harness that has said
		# "never write" must not leave a row behind that a later playtest reads
		# as if a person had produced it.
		if save_enabled:
			Telemetry.record_session(played_seconds)
