class_name DeepSpace
extends Node3D
# Everything outside the charted system: the endless backdrop, and the distance
# bands that decide how strange, how dangerous and how rewarding a place is.
#
# NOTHING HERE IS SAVED. Every feature of the expanse is a pure function of
# (system id, cell x, cell z), computed on demand, so the same cell always
# produces the same thing and revisiting it costs zero bytes. The alternative —
# a visited-cells array — would grow every minute the player flies.
#
# Bands are measured on DEPTH (distance past the chart edge), never on radius,
# so a bigger system pushes its own expanse out with it: PYX-03's Reaches begin
# where PYX-03 ends, not at some absolute number that happens to suit PYX-01.

# v20 THE FRONTIER. THE QUIET used to start at 1100 and never end, so a player
# 8000u out read the same row of every table below as one 1100u out — same packs,
# same guards, same five shopfronts — while the authored content (convoys stop at
# 1000, rifts at 1200, the instruments at 4200) had run out behind them. Past
# 4244u the deep was strictly POORER than halfway there, which is the opposite of
# what distance is supposed to buy.
#
# Two more bands, and the edges are appended rather than inserted: band_of walks
# this list from the top down, so every depth under 2600 skips the new entries
# and takes a byte-identical path. That is what makes the world fingerprint safe
# BY CONSTRUCTION rather than by luck — the same argument the salted sub-streams
# below rest on, applied to a table instead of a roll.
#
# 2600 sits inside the instruments' span (1600-4200), so THE FATHOMS inherits
# them as authored landmarks in its lower half. 5200 is past the deepest authored
# thing in the game (pyx03's bounds 44 + HYPER_DEPTH_MAX 4200 = 4244), which is
# exactly what THE UNSOUNDED is: the band past even the instruments, where the
# only thing out there is what the generator makes.
const BAND_EDGES := [0.0, 160.0, 440.0, 1100.0, 2600.0, 5200.0]
const BAND_NAMES := ["CHARTED", "THE SHOALS", "THE DRIFT", "THE REACHES", "THE QUIET",
	"THE FATHOMS", "THE UNSOUNDED"]

# Depth at which the deep dressing is fully faded in.
const DEEP_FULL := 260.0
const STAR_COUNT := 520
const MOTE_COUNT := 120

# --- sector streaming --------------------------------------------------------
# The expanse is a grid. A cell is generated when the player comes within WINDOW
# cells of it and torn down once they are KEEP cells away — the gap between the
# two is hysteresis, and without it a player hovering on a boundary would thrash
# a whole column of content in and out every few seconds.
#
# The sizing is load-bearing, not taste. At CELL 64 and WINDOW 2 the live block
# is 5x5, 320u across; crossing into a new cell adds a column whose nearest edge
# is 2*CELL = 128u away, against a visible ground half-extent of ~35u at maximum
# zoom. Content therefore always appears and disappears at least three screens
# off camera, which is the only reason this can be done without a fade.
const CELL := 64.0
const WINDOW := 2
const KEEP := 3
# Nothing generates until well past the chart edge. The charted system is
# authored down to the placement of its rocks, and streamed content dropped on
# top of it would fight that — as well as landing next to whatever a harness has
# hand-placed just outside `bounds`.
const CONTENT_MIN_DEPTH := 24.0

# --- the danger gradient -----------------------------------------------------
# No new enemy classes: the whole gradient is the parameters SwarmHostile and
# Hostile already carry, turned up per band. What changes with distance is how
# hard the thing hits, how long it takes to kill, how many of it there are and
# what colour it is — and colour is the tell that reads at a glance on a phone.
#
# Indexed by band, so the row for CHARTED is the identity row and every existing
# encounter in the game is untouched by construction.
#                        charted shoals drift reaches quiet fathoms unsounded
const PACK_CHANCE := [0.0, 0.0, 0.30, 0.42, 0.50, 0.56, 0.60]
const PACK_HP := [1.0, 1.0, 1.6, 2.4, 3.2, 4.0, 4.9]
const PACK_DIFFICULTY := [1.0, 1.0, 1.4, 2.0, 2.6, 3.2, 3.8]
const PACK_MIN := [0, 0, 3, 5, 6, 7, 8]
const PACK_MAX := [0, 0, 5, 7, 9, 11, 13]
# What they are carrying. The reward for going out is not a bigger number on the
# same crate, it is a better crate.
#
# And past the Quiet the crate stops being a good at all: the deepest packs carry
# the UNREAD SALVAGE of their own band, which is worth more than relics and worth
# nothing until the archeology ladder can read it. That is the frontier's answer
# to "what does another 4000u buy" — not a bigger pile, a thing you cannot spend
# yet.
const PACK_DROP := ["", "", "isotopes", "cores", "relics",
	"salvage_fathom", "salvage_unsounded"]
# A sentry rides along from the Reaches out: something that does not die to one
# Arc hop, which is the same lever the corsair pulls on a rich interdiction.
const PACK_ESCORT_FROM := 3
# HOW MANY sentries, and this is the first thing that makes the Fathoms feel
# unlike the Quiet rather than merely cost more. One escort is a fight with an
# anchor in it; two is a fight with a FORMATION, and arc-kiting the swarm stops
# being the whole answer. Indexed by band so the rows the game already shipped
# are the identity row — 1 wherever PACK_ESCORT_FROM used to say "yes".
const PACK_ESCORTS := [0, 0, 0, 1, 1, 2, 2]

# --- chartfolk convoys -------------------------------------------------------
# TERRITORY VERSUS TRAFFIC. The deep's GROUND stays the unknowns' — the band
# flag, the nests, the guard posts, everything THE DEEP BELONGS TO THE UNKNOWNS
# asserts — but the known factions TRAVEL it: small escorted groups walking a
# short beat between two waypoints, sprung once per cell per session exactly
# like a nest. They hold nothing, they claim nothing, and when the player
# leaves they leash away. That distinction is what lets chart powers appear
# out here without contradicting a claim the harness has pinned since stage 6.
#
# 200 is the floor the feature was asked for, and it also clears the Shoals —
# the band whose whole job is teaching that going out is survivable. 1000 stops
# a hundred units short of the Quiet: the Hollowing's ground stays untravelled,
# which is most of what makes arriving there feel like the traffic KNOWS.
const CONVOY_MIN_DEPTH := 200.0
const CONVOY_MAX_DEPTH := 1000.0
# Per-cell odds, on the convoy's own salted stream, AND a cell holds a pack or
# a convoy, never both — so the effective rate is (1 - PACK_CHANCE) * this,
# roughly 7% of eligible cells. Meeting traffic should stay an event.
const CONVOY_CHANCE := 0.10
# Mirrors PACK_INSET's arithmetic: a convoy anchor and a station in adjacent
# cells are at least STATION_INSET + CONVOY_INSET = 36 >= STATION_SAFE_RADIUS
# apart, because a cell only knows its own contents and cross-boundary
# clearance has to come from geometry.
const CONVOY_INSET := 14.0
# Beat half-length. The worst cross-cell case keeps a waypoint 24u from a
# neighbouring dock ring (22 + 14 - 12), clear of DOCK_RANGE + ENGAGE_RANGE;
# and 24u end to end is 4x MARCH_ARRIVE, so darts genuinely walk it rather
# than standing inside the arrive radius of both ends at once.
const CONVOY_LEG := 12.0
# Fixed pick order; the weight rows index it. Weighted toward the factions
# with DESKS out here — league's relay, grin's haven and combine's forge are
# band-2 stations, bastion's Blackwatch Yard is band 3 — because traffic near
# a door it could plausibly be walking toward reads as a world, and the same
# names on the standing line at the desk and the paint outside is the whole
# faction system agreeing with itself. The Tithe is pinned low at 0.10: it is
# the ONLY hostile convoy and the only one that pays, and 14's weather-not-tax
# rule applies to how often the sky may contain it.
const CONVOY_FACTIONS := ["league", "grin", "combine", "embers", "procession",
	"bastion", "tithe"]
# What a good name is worth out here: ONE reading, once, from people who know
# you. FRIENDLY or better -- the band a defence, a toll, a fence deal or a held
# line can each buy -- and the band is the only thing any code reads anyway.
const CONVOY_HAIL_MIN_BAND := FactionDB.Band.FRIENDLY
# The cone their navigator quotes, and it is deliberately the WIDEST reading in
# the game: equal to the free hull cone, so a gift can never undercut something
# somebody paid for. The two agree by ASSERTION rather than by a compile-time
# reference -- DeepSpace naming Derelict would add an edge to the class graph
# for the sake of one number, the same arrangement LAIR_KEEPOUT and
# ApexBoss.LEASH_RANGE already use. A CONVOY CONE IS THE WIDEST reads both.
const CONVOY_HINT_ERROR_DEG := 20.0

const CONVOY_WEIGHTS := {
	2: [0.22, 0.20, 0.20, 0.12, 0.11, 0.05, 0.10],
	3: [0.15, 0.15, 0.15, 0.10, 0.10, 0.25, 0.10],
}

# --- deep stations -----------------------------------------------------------
# Sparse and getting less so with distance — the reward for going out is that
# there is somewhere out there. At these odds a 5x5 window holds a station about
# one visit in eight in the Drift, so finding one is an event rather than a
# feature of the landscape.
const STATION_CHANCE := [0.0, 0.035, 0.055, 0.075, 0.095, 0.115, 0.135]
# Debris and wrecks stay this far off a station; a nest stays much further, since
# it is the difference between a hard approach and an unreachable dock.
const STATION_CLEARANCE := 14.0
const STATION_SAFE_RADIUS := 34.0

# How far in from its cell's edges each thing is placed. These are not taste —
# they are what makes the clearances above hold ACROSS a cell boundary, which is
# the case the per-cell check cannot see. A cell only knows its own contents, so
# a nest in the cell next door is invisible to the station's keep-out test; the
# guarantee has to come from the geometry instead:
#
#     STATION_INSET + PACK_INSET = 36 >= STATION_SAFE_RADIUS (34)
#     STATION_INSET + ROCK_INSET = 26 >= STATION_CLEARANCE   (14)
#
# So the nearest a neighbouring cell's nest can ever get to a station is 36u,
# whatever either of them rolls.
const STATION_INSET := 22.0
const PACK_INSET := 14.0
const HULK_INSET := 12.0
const ROCK_INSET := 4.0

# --- the engine's arena ------------------------------------------------------
# v15. NOTHING ELSE LIVES INSIDE THE ENGINE'S REACH.
#
# The apex used to sit at an authored point inside the charted volume, where the
# generator never runs, so the question never came up. It hides out in the
# expanse now — and the expanse is exactly where stations, nests and guarded
# hulks come from. Left alone, the game would eventually roll a nest, a dock or a
# standing garrison into the middle of a boss arena.
#
# IT IS ApexBoss.LEASH_RANGE, and the number is not chosen — the leash is the
# radius inside which the game says you are in the fight, so anything inside it
# that is not the fight is the game contradicting itself. It also comfortably
# clears WAKE_RANGE (60), which is the floor that actually matters: a dock at 50u
# would wake the engine on the approach and lock every console while the player
# was still trying to berth.
#
# WRITTEN OUT RATHER THAN DERIVED, and that is not laziness. `const LAIR_KEEPOUT
# := ApexBoss.LEASH_RANGE` is a compile-time dependency on that class, and the
# chain closes: ApexBoss names HUD, HUD names DeepSpace. Godot answers a cycle in
# the global class list by declaring EVERY class_name in the project undeclared —
# a wall of parse errors in files that were never touched, and a boot that hangs
# instead of failing. So the two constants agree by assertion instead:
# PYXIS_HUNTTEST's THE ARENA IS THE ENGINE'S REACH reads both and fails if they
# ever part company.
#
# WHAT IT DOES NOT TOUCH: rocks, seams and the landmark. A sphere of genuinely
# empty space 240u across would read as a hole in the world — a bug, not a place.
# The debris is still there, the ore is still on the debris, and the
# supercell's landmark still stands where it stood. What is missing is everything
# that would have brought its OWN encounter to the fight.
#
# The hulk is suppressed with the other two despite carrying no hostiles of its
# own by default: it is the thing GUARD POSTS ride on (a standing garrison, which
# is a nest by another name) and the thing TRAP_CHANCE rigs to spawn a pack the
# moment it is cracked. Suppressing packs while leaving the object that mints one
# would be a rule that only half held.
const LAIR_KEEPOUT := 120.0

# v18. AND A SECOND, MUCH SMALLER KEEP-OUT, around the survey hull.
#
# The hull moved out past the marker in stage 2b, which puts it in generated
# space for the first time — and the one thing that must not roll on top of it
# is ANOTHER CRACKABLE HULL. Two derelicts a few units apart, one of which
# charts the next system and one of which does not, is the most confusing
# object this game could produce. A station's docking ring landing on the
# breach point is the other case.
#
# 40 rather than the lair's 120, and the difference is what each is protecting.
# The lair is an ARENA: the leash says everything inside it is the fight, so
# nothing that is not the fight may be there. The hull is a DESTINATION with a
# 6.5u interaction range — it needs elbow room, not solitude. Nests are
# deliberately NOT suppressed: the hull has always had sentries standing over
# it, and something drifting in to guard a wreck out past the cordon is the
# fiction working rather than the generator misfiring.
const HULL_KEEPOUT := 40.0

# --- what the beacons say ----------------------------------------------------
# Crossing a band plays an automated broadcast. This replaces the soft outer
# limit the plan originally called for, and it is a better answer: a wall says
# "the designer stopped building here", whereas a survey authority washing its
# hands of you says "people stopped coming here", which is the same information
# delivered as fiction instead of as UI.
#
# It also does the job the interdiction taper needs doing. Raiders thin out with
# distance (Main.DEEP_RAID_TAPER) and the reason is exactly this: nobody is
# watching. Saying so out loud is what turns a number into a place.
const BROADCASTS := [
	{},
	{
		"from": "GALACTIC SURVEY AUTHORITY — AUTOMATED BEACON",
		"body": "You are leaving charted space. Security patrols do not operate beyond this marker and cannot be dispatched to assist. Salvage, navigation and rescue are unsupported. Proceed at your own risk.",
		# v13. What the same beacon says once the register knows your name. "On
		# file" was stage one of the Commission, and this is the callback.
		"from_commissioned": "GALACTIC SURVEY AUTHORITY — REGISTERED VESSEL",
		"body_commissioned": "Charts on file. This marker stands on your readings. Patrols still do not operate beyond it, and the authority still cannot be dispatched to assist — but the bearing is yours, and it is written down.",
	},
	{
		"from": "GSA RELAY — LAST REPEATER",
		"body": "This is the final beacon on this bearing. No vessel has filed a return from beyond it this cycle. Contacts logged out here are not registered to any fleet.",
		"from_commissioned": "GSA RELAY — LAST REPEATER",
		"body_commissioned": "This is the final beacon on this bearing. One vessel has filed a return from beyond it. The file is open and the readings are yours.",
	},
	{
		"from": "GSA RELAY — SIGNAL DEGRADED",
		"body": "Carrier lost. This transmission is a recording. Whatever is out here was not surveyed, is not catalogued, and is not ours.",
		"from_commissioned": "GSA RELAY — SIGNAL DEGRADED",
		"body_commissioned": "Carrier lost. This transmission is a recording. Whatever is out here was not surveyed by us. It has been surveyed.",
	},
	# Band 4 carries NO commissioned keys, and that is the note the whole arc ends
	# on rather than an oversight. COMMISSIONED requires reaching THE QUIET, and
	# THE QUIET is the one band that will never acknowledge it — GUARD_DESIGNATION
	# for this band is already "UNREADABLE — IT DOES NOT ANSWER", so the data and
	# the fiction agree. Do not "finish" this entry.
	{
		"from": "· · · —— · · ·",
		"body": "The beacon net does not reach this far. Nothing is transmitting. Nothing is listening.",
	},
	# Band 5. The first voice out here that is not the GSA, and the first one in
	# the whole arc that offers something. The register's arc ENDED at the Quiet,
	# so this carries no commissioned keys either — being known by the authority
	# is not what gets you spoken to out here. Arriving is.
	#
	# It also teaches the thing the band needs taught before it is discovered:
	# there are lights past the Quiet, and one of them will let you dock.
	{
		"from": "A KEPT LIGHT",
		"body": "There is a light ahead of you. It is kept. It has been kept a long time, and by somebody. If you need it, it is there.",
	},
	# Band 6, and it inverts band 4's closing line one word at a time. "Nothing
	# is transmitting" stays true; "nothing is listening" stops being.
	{
		"from": "· · ·",
		"body": "Nothing is transmitting. Something is listening.",
	},
]


static func broadcast_for(band: int, commissioned := false) -> Dictionary:
	# Optional keys with a fallback rather than a parallel three-entry array: a
	# second array would be a second bounds contract that could disagree with the
	# first, and "band 4 is unchanged" would become a size mismatch instead of a
	# stated property of the data.
	if band <= 0 or band >= BROADCASTS.size():
		return {}
	var entry: Dictionary = BROADCASTS[band]
	if not commissioned:
		return entry
	return {
		"from": String(entry.get("from_commissioned", entry.get("from", ""))),
		"body": String(entry.get("body_commissioned", entry.get("body", ""))),
	}


# --- rigged hulks ------------------------------------------------------------
# Some wrecks out there are bait. Breaching one blows an EMP across the bay —
# drives and mounts dead for a few seconds — and whoever left it there comes to
# collect. Deeper means a better chance of it, a longer lockout, a bigger pack,
# and from the Reaches out a proper fighter riding along with the swarm.
#
# Two things make this a decision rather than a tax:
#
#   * it is SEEDED, like everything else here, so a given hulk is always rigged
#     or always is not. A trap that rerolled per visit would be a coin flip
#     wearing a mechanic's clothes.
#   * a rigged hulk carries MORE. You are not being punished for salvaging, you
#     are being offered a worse-odds bet with a bigger pot — and the tell below
#     is what lets you take it knowingly.
const TRAP_CHANCE := [0.0, 0.12, 0.26, 0.38, 0.50, 0.60, 0.68]
const TRAP_EMP := [0.0, 1.4, 1.9, 2.4, 2.8, 3.2, 3.5]
const TRAP_PACK_MIN := [0, 3, 4, 6, 7, 8, 9]
const TRAP_PACK_MAX := [0, 4, 6, 8, 10, 12, 13]
const TRAP_LOOT_BONUS := 1.6          # what the bet pays if you take it and live
const TRAP_ESCORT_FROM := 3
# The trap's own escort count, PACK_ESCORTS' sibling. At 3.5s of EMP with three
# sentries already firing, the Thermal Sink in the hold and the Sink Lattice in
# a utility slot stop being nice-to-have and become the reason the Unsounded is
# survivable at all — a mitigation the game has shipped since v16 and never
# needed. This is what gives it a job.
const TRAP_ESCORTS := [0, 0, 0, 1, 1, 2, 3]

# --- grave-fields (v20 stage 4, THE UNSOUNDED only) --------------------------
# How often a band-6 cell that already holds a wreck holds a SECOND one beside
# it. Gated on the first existing, so this is a conditional on the plan rather
# than an independent roll: a grave-field is two ships that died together, and
# one of them has to be the one the cell already had.
const GRAVE_CHANCE := 0.34
# How far apart. Close enough to read as one event at a glance, far enough that
# the two hulls do not intersect — HULL_KEEPOUT is 40 and a hull's own obstacle
# is well inside this.
const GRAVE_GAP_MIN := 11.0
const GRAVE_GAP_MAX := 19.0

# How many deep stations keep a bonded store. Deliberately a minority: stations
# out here are already scarce, and one that will hold your cargo has to be a
# relief rather than an amenity. Not finding one is the point.
const DEEP_STORAGE_CHANCE := 0.15           # a Hostile joins the ambush from here out

# Nothing the expanse spawns may chase further than this. See
# SwarmHostile.despawn_radius for why the number has to exist at all.
# --- guarded hulks -----------------------------------------------------------
# Past a certain depth a wreck is not just lying there — something is standing
# over it. This is what makes approaching a hulk a DECISION rather than a flight
# plan: you can read the post from further out than you can read the rigged
# beacon, so the choice to commit is always available.
#
# Not from the chart edge: the Shoals have to keep teaching that going out is
# survivable, so the first wrecks a player ever finds stay unguarded.
const GUARD_MIN_DEPTH := 55.0

# 20% none, 25% two, 30% three, 25% four. There is deliberately NO one-guard
# case: a lone sentry reads as a straggler rather than a post, and it is the one
# size the geometry cannot make contest the breach (one gun in range instead of
# two). GUARD_BEARINGS enforces it structurally — a 1 added here has nowhere to
# stand.
const GUARD_COUNTS := [0, 2, 3, 4]
const GUARD_WEIGHTS := [0.20, 0.25, 0.30, 0.25]

# Guards get their OWN curve, not PACK_*. Hostile.difficulty scales BOTH hp and
# damage, and for a standing post those have to come apart. On the swarm curve a
# Quiet guard's shot is 14.0 x 2.6 = 36.4, against PYX-03's authored sentries at
# 14.0 x 2.2 = 30.8 — a machine 1100u from the nearest dock hitting 18% harder
# than anything on the chart, where you have a station to run to and a regen
# window. That inversion was the defect; HP was never the lethal axis.
#
# So a guard is scary through COUNT, HP and where it is standing, never alpha.
# What falls out is a band-gated decision with its answer already in the fitting
# console: you can tank a guarded crack in the Shoals and the Drift, and from the
# Reaches out you clear the post first or you fit Bulwark.
#                         charted shoals drift reaches quiet fathoms unsounded
# THE FRONTIER'S ALPHA IS ALMOST FLAT, AND THAT IS THE POINT. The first draft
# read 1.85 / 2.05, extrapolating the +0.20 step, and GUARD HOLD caught it: at
# 2.05 a three-gun post over a 3.0s crack costs 14.0 x 2.05 x 3 x 3 = 258
# against Bulwark's 250 pool, so the deepest posts in the game were the ones no
# fit could hold — including the fit built to hold them. That contradicts the
# paragraph directly above this one, which is a standing decision and not a
# curve to extrapolate: "you clear the post first or you fit Bulwark" has to
# stay true at every band, or the answer the game taught stops being an answer.
#
# So 1.90 (239 against 250, surviving with 4% left — dramatic, and survivable),
# and the threat the alpha gave up is paid back in HP: +0.20 at band 6 where
# every earlier step was +0.10, making an Unsounded post the LONGEST fight in
# the game rather than the sharpest. Count and standing are already maxed —
# GUARD_BEARINGS runs out at four — so HP is the axis left, which is exactly
# what the paragraph above says it should be.
#
# An Unsounded guard's shot is 14.0 x 1.90 = 26.6, still under PYX-03's authored
# sentries at 14.0 x 2.2 = 30.8. Nothing in the deep out-hits the chart.
const GUARD_DIFFICULTY := [1.0, 0.90, 1.10, 1.40, 1.65, 1.85, 1.90]
const GUARD_HP_SCALE := [1.0, 1.20, 1.45, 1.50, 1.60, 1.70, 1.90]

# Posts ring the BREACH POINT, not the hull: what they are guarding is the way in.
#
# Derelict._approach parks the ship at CRACK_RANGE * 0.78 = 5.07u from the breach
# point, on a bearing bounded to 32 degrees off the hull's outward axis by the
# 1.6 weighting in that function. Against ENGAGE_RANGE 9.0 at this stand-off the
# inner pair are always engaged (2.6-3.8u) and the outer pair only on an oblique
# approach (7.4u vs 9.8u straight-in). So a post puts TWO guns on you typically
# and three at worst, never four — the count sets how LONG the fight is, not how
# hard the hold is, and the difficulty curve above is tuned against that.
const GUARD_STANDOFF := 7.6
const GUARD_BEARINGS := [
	[], [],
	[26.0, -26.0],
	[26.0, -26.0, 100.0],
	[26.0, -26.0, 100.0, -100.0],
]
const GUARD_JITTER_DEG := 6.0
const GUARD_JITTER_STANDOFF := 0.4

# What the scanner can still tell you about the thing pointing a gun at you. The
# machine does not change with distance; your ability to NAME it does — the same
# arc BROADCASTS walks (authority, lapsed authority, a recording, no carrier) and
# the same arc the salvage grades walk. Index 0 is never read: nothing charted is
# guarded.
const GUARD_DESIGNATION := [
	"",
	"GSA PICKET — DECOMMISSIONED",
	"PICKET — REGISTRY LAPSED",
	"UNFLAGGED — NO PATTERN ON FILE",
	"UNREADABLE — IT DOES NOT ANSWER",
	# The arc's last two rungs. Silence was the Quiet's; what is past it is worse
	# than silence — first the things out there answer EACH OTHER (you are not
	# being talked to, you are being discussed), and then the scan comes back
	# with your own signature on it. Both say what they are without a word the
	# game has not taught: "answer" and "scan" are already in the vocabulary.
	"UNREADABLE — THEY ANSWER EACH OTHER",
	"NO READING — THE SCAN COMES BACK YOURS",
]
const GUARD_COUNT_WORD := ["NOTHING", "ONE", "TWO", "THREE", "FOUR"]

const HOSTILE_LEASH := 140.0
# How far the frontier follows. A LONGER chase, never an unending one: the
# no-leash tell belongs to the Tally alone (unknown_a, band 3) and giving a
# second faction the same behaviour would spend the one thing that makes being
# followed home mean something. 0 here means "use HOSTILE_LEASH" — the identity
# row, the way every table in this file does it — so bands 0-4 are untouched by
# construction and only the two new rows say anything.
#
# 220 and 260 against a 140 baseline is the first time breaking off costs real
# distance rather than a moment's patience, which is the whole of what THE
# UNSOUNDED is for.
const FAR_LEASH := [0.0, 0.0, 0.0, 0.0, 0.0, 220.0, 260.0]


static func leash_for(band: int, flag: String) -> float:
	# One place, because the pack loop and its escorts have to agree: a swarm
	# that gave up at 140 while its sentry chased to 260 would read as the sentry
	# being special rather than the band being deep.
	if flag == "unknown_a":
		return 0.0
	var i := clampi(band, 0, FAR_LEASH.size() - 1)
	return FAR_LEASH[i] if FAR_LEASH[i] > 0.0 else HOSTILE_LEASH
# How close the player gets before a seeded nest actually becomes ships. Comfortably
# outside the ~34u visible half-extent at maximum zoom, so a pack is never seen
# popping into existence, and comfortably inside HOSTILE_LEASH, so it is never
# born already past the range at which it gives up.
const ENCOUNTER_TRIGGER := 44.0

var generating := true

var _bounds := 40.0
var _id := ""
var _stars: DeepField
var _motes: DeepField
var _cold: MeshInstance3D
var _cold_mat: StandardMaterial3D
var _k_last := -1.0

# Where this system's apex engine hides, resolved ONCE in configure() and held.
# Not recomputed per cell: lair_pos hashes a string and builds a generator, and
# this is asked four times per cell across the whole streaming window.
#
# Caching also pins it to the right moment. SystemBuilder positions the boss node
# from GameState.run_seed and then builds this, so both read the salt on the same
# frame — and a harness that re-pins the salt afterwards moves neither the boss
# nor the hole in the world it stands in. The keep-out is guaranteed to be around
# the engine that actually exists rather than around one a later assignment
# implies.
var _lair := Vector3.ZERO
var _has_lair := false
var _hull := Vector3.ZERO
var _has_hull := false
# The authored deep block (v19 stage 4). Empty for pyx01 and for every def that
# predates it, which is what keeps the weighted branches inert by construction.
var _deep: Dictionary = {}

# Live cells, keyed by Vector2i. The value is the cell's content node, or null
# for a cell that generated nothing — the key still has to be present, or an
# empty cell is re-planned on every frame it stays in the window.
var _cells := {}
var _cell_last := Vector2i(0x7fffffff, 0x7fffffff)
# Cells registered but not yet dressed. See _stream for the split and why.
var _build_queue: Array[Vector2i] = []
# cell -> { seam index: true }. A dict of dicts rather than the flat set
# _cracked and _surveyed use, because a cell holds at most one SURVEY but can
# hold a seam on every rock in it. (_cracked stopped being a flat cell set in
# stage 4: a band-6 grave-field puts two hulls in one cell, so it keys on
# cell-and-index now — see _hulk_key.)
var _mined := {}
# Per-frame budget for building meshes. About a third of a 60Hz frame, which
# leaves room for everything else that happens on a frame where the player
# crossed a boundary -- and cells are drained nearest-first, so the budget
# spends itself on what is in front of the ship.
const BUILD_BUDGET_USEC := 5000

# Nests that are seeded but have not been walked into yet, keyed by cell.
# Guard posts. The tree and the ownership record are different things — the same
# split Obstacles already makes with owner tags. Nodes live in system_root so
# Hostile._die()'s deferred loot spawn keeps the guarantee every other deep
# hostile has; the CELL owns them, and _despawn_cell frees them explicitly.
var _guards := {}       # Vector2i -> Array[Hostile]
var _guard_origin := {} # Vector2i -> Vector3, the hulk the post stands over
# Sprung convoys: Vector2i -> {"darts": [...], "escorts": [...], "wp": [a, b]}.
# Members live in system_root like every sprung hostile; the LEASH ends their
# lives, not the cell, so this dict only exists to drive _tick_convoys and to
# give the harness a member list. Erased when its last member goes.
var _convoys := {}
var _cleared := {}      # Vector2i -> true, posts whose last guard died this session
# Hulls already opened this session. The post standing over the wreck has had
# this guarantee since it shipped and the mast on its stern has had it since the
# survey landed; the HULL was the one that forgot, and _build_post's own comment
# describes the exact farm that left open — 200u out and back, full loot every
# lap, somewhere ports cannot reach. Session-scoped like its two neighbours, so
# a warp resets it and the geometry argument in 22 keeps covering all three.
var _cracked := {}      # Vector2i -> true, hulls breached this session
var _hailed := {}       # Vector2i -> true, posts already announced this session
var _convoy_hailed := {}  # Vector2i -> true, convoys that have already spoken
var _defended := {}       # convoy_id -> true, convoys already credited
var _counted := {}      # Vector2i -> true, posts already credited to the logbook
# Cells whose landmark has already been read this session. Session-only like
# _sprung, and for the same reason 17 gives: persisting it would be a
# visited-cells array by another name, growing every minute the player flies.
# The consequence — a warp resets surveys — is asserted on purpose in CARTTEST,
# so a future "fix" that saves this trips a FAIL and forces the conversation.
var _surveyed := {}

var _armed := {}
# Cells whose nest has already been sprung this visit. Session-only and rebuilt
# with the system, like everything else out here — flying a circle back through
# a sector you just fought in must not hand you the same pack a second time.
var _sprung := {}


# --- bands (pure) -----------------------------------------------------------

static func band_of(depth: float) -> int:
	if depth <= 0.0:
		return 0
	for i in range(BAND_EDGES.size() - 1, 0, -1):
		if depth >= BAND_EDGES[i]:
			return i + 1
	return 1


static func band_name(depth: float) -> String:
	return BAND_NAMES[band_of(depth)]


# The four compass sectors a rumour can name. COARSE on purpose: a quadrant of
# the Drift is still an enormous amount of nothing to search, which is exactly
# what the cheapest tier of intel should buy.
#
# Pure and shared, because three separate places need to agree on it — the free
# lane-obstructed broadcast, the dossier's save-side validator, and Hunt's
# estimator. The moment two of them derive "which quadrant is that" independently
# they will disagree at a boundary, and a rumour that names the wrong sector is
# worse than no rumour: it costs credits AND sends you the wrong way.
const QUADRANTS := ["EAST", "SOUTH", "WEST", "NORTH"]

# THE ANGLE THE WORLD IS BUILT ON, and the one the player is shown, are not the
# same number -- and keeping them separate is what makes this safe.
#
# Everything internal uses `atan2(z, x)`: the lair derivation, the authored
# `bearing_deg` in every system def, Hunt's search cone, and the bearings already
# WRITTEN INTO PLAYERS' SAVES as apex hints. In that convention +X is 0, so 0 is
# EAST and 270 is NORTH -- which is fine for maths and indefensible on an
# instrument. A playtest screenshot read `HDG 270 · NORTH`, and no compass any
# player has ever used puts north at 270.
#
# So the rotation happens at the GLASS, never in the model. compass_deg is the
# only thing that converts, every readout and every quoted bearing goes through
# it, and not one stored number moves -- a save written last night still points
# where it always did. The offset is +90 because +X must go from 0 to 90.
const COMPASS_OFFSET := 90.0


static func to_compass(world_deg: float) -> int:
	# For callers that already hold an atan2(z, x) angle -- the stored hints and
	# the authored defs both arrive that way.
	return int(round(fposmod(world_deg + COMPASS_OFFSET, 360.0))) % 360


static func compass_deg(pos: Vector3) -> int:
	# For callers holding a direction. Equivalent to to_compass(atan2(z,x)) and
	# asserted to be, so the two entry points cannot drift.
	return to_compass(rad_to_deg(atan2(pos.z, pos.x)))


static func quadrant_of(pos: Vector3) -> String:
	# DERIVED FROM THE DISPLAYED NUMBER, so the word and the digits on the same
	# line cannot contradict each other. They agreed before only because two
	# separate tables happened to match; now there is one.
	var deg := float(compass_deg(pos))
	if deg < 45.0 or deg >= 315.0:
		return "NORTH"
	if deg < 135.0:
		return "EAST"
	if deg < 225.0:
		return "SOUTH"
	return "WEST"


static func band_color(depth: float) -> Color:
	return Palette.band_color(band_of(depth))


# --- construction -----------------------------------------------------------

func configure(def: Dictionary, system_id: String) -> void:
	_bounds = float(def.get("bounds", 40.0))
	_id = system_id
	# Asked of the DEF rather than of the position, because "this system has no
	# apex" and "this system's apex hides at the origin" both come back as
	# Vector3.ZERO from lair_pos and only one of them means there is no keep-out.
	_has_lair = not ((def.get("apex", {}) as Dictionary).get("lair", {}) as Dictionary).is_empty()
	_lair = SystemDB.lair_pos(system_id, GameState.run_seed) if _has_lair else Vector3.ZERO
	# Same question, asked the same way: an empty `derelict` def and a hull at
	# the origin both read as Vector3.ZERO, and only one of them means there is
	# nothing to keep clear.
	_has_hull = not (def.get("derelict", {}) as Dictionary).is_empty()
	_hull = SystemDB.derelict_pos(system_id) if _has_hull else Vector3.ZERO
	# v19 HUNT STAGE 4. The system's deep accent, resolved once — the _lair
	# cache's idiom. Asked of the DEF so a harness that configures a probe with
	# a stripped def gets the stripped world, which is what THE DRAW COUNT DID
	# NOT MOVE stages.
	_deep = def.get("deep", {})
	var sf: Dictionary = def.get("starfield", {})
	var seed_value := hash(system_id)

	# Far layer: the sky that never runs out. Low parallax, so it slides slowly
	# and reads as genuinely distant against the world-locked per-system field,
	# which is left exactly as it was and becomes the NEAR sky over the system.
	_stars = DeepField.new()
	_stars.parallax = 0.30
	_stars.half = 120.0
	add_child(_stars)
	_stars.build(STAR_COUNT, sf.get("tint", Color(0.85, 0.9, 1.0)), 0.05, seed_value)

	# Near layer: specks that slide past the hull at nearly full speed. Once the
	# lattice is behind you this is the only thing left that sells motion, so it
	# fades IN with depth rather than being on everywhere.
	_motes = DeepField.new()
	_motes.parallax = 0.92
	_motes.half = 30.0
	_motes.rebake_step = 4.0
	add_child(_motes)
	_motes.build(MOTE_COUNT, Color(0.72, 0.78, 0.9), 0.022, seed_value ^ 0x5bf03)
	_motes.set_presence(0.0)

	# The colour of nothing: one huge inside-out sphere under the play plane that
	# follows the camera, replacing the system's haze once the haze is behind
	# you. Same primitive as _build_haze, one instance, effectively free.
	_cold = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 8
	_cold.mesh = sm
	_cold.scale = Vector3.ONE * 190.0
	_cold_mat = Palette.emissive(Color(Palette.DEEP_COLD.r, Palette.DEEP_COLD.g,
		Palette.DEEP_COLD.b, 0.0), 1.0)
	_cold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cold_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_cold.material_override = _cold_mat
	add_child(_cold)


func set_generation(on: bool) -> void:
	# Harnesses that assert against a hand-placed world turn generation off, the
	# same way they already pin `_wave_timer`. PYXIS_COLLISIONTEST in particular
	# puts its synthetic body at (34, 0, 34) — magnitude 48.1, which is OUTSIDE
	# PYX-01's bounds of 40, so a generated rock could land next to it and
	# corrupt the slide assertion.
	generating = on
	if not on:
		_despawn_all()


# --- sector streaming -------------------------------------------------------

static func guard_count(roll: float) -> int:
	# Pure, so the distribution's edges are assertable with no RNG, no spawning
	# and no flying.
	var acc := 0.0
	for i in range(GUARD_WEIGHTS.size()):
		acc += GUARD_WEIGHTS[i]
		if roll < acc:
			return GUARD_COUNTS[i]
	return GUARD_COUNTS[GUARD_COUNTS.size() - 1]


static func convoy_faction(band: int, roll: float) -> String:
	# Pure, for guard_count's reason. Falls back to the band-3 row for any
	# band without one — the same fail-toward-the-shipped-shape direction
	# every default in this file takes.
	var w: Array = CONVOY_WEIGHTS.get(band, CONVOY_WEIGHTS[3])
	var acc := 0.0
	for i in range(w.size()):
		acc += float(w[i])
		if roll < acc:
			return String(CONVOY_FACTIONS[i])
	return String(CONVOY_FACTIONS[0])


static func weighted_index(roll_u32: int, count: int, weights: Array) -> int:
	# v19 HUNT STAGE 4. One weighted pick that is BYTE-IDENTICAL to the shipped
	# uniform pick whenever no weights are authored — and that equivalence is
	# the entire fingerprint argument, so it is the first line, not a comment.
	#
	# The caller keeps drawing `rng.randi()` exactly as it always did and hands
	# the uint32 here. Deriving the index from the RETURNED value is what makes
	# this safe: swapping the draw for randf() would advance the PCG stream
	# differently and shift every draw after it — station positions included,
	# which the fingerprint hashes. THE DRAW COUNT DID NOT MOVE red-verifies
	# precisely that swap.
	#
	# A row of the wrong length falls back to the shipped pick too — toward the
	# shipped shape, the direction every default in this file takes — because a
	# row authored against ARCHETYPES instead of for_band's filtered output
	# would otherwise misweight silently.
	if weights.is_empty() or weights.size() != count:
		return roll_u32 % count
	var total := 0.0
	for w_v in weights:
		total += float(w_v)
	if total <= 0.0:
		return roll_u32 % count
	# The uint32 remapped onto [0,1): the same entropy the modulo consumed,
	# spent on a cumulative walk — guard_count's shape, one roll, pure.
	var roll := float(roll_u32) / 4294967296.0 * total
	var acc := 0.0
	for i in range(count):
		acc += float(weights[i])
		if roll < acc:
			return i
	return count - 1


static func guard_posts(hulk_pos: Vector3, rot_y: float, count: int,
		rng: RandomNumberGenerator) -> Array:
	# Derived ANALYTICALLY from the hull transform, never by reading
	# Derelict.breach_point — that is set in _ready, which fires from add_child,
	# before the spawner assigns global_position. Reading it at plan time returns
	# the container origin. Same trap as Hostile._home.
	var out: Array = []
	if count <= 0 or count >= GUARD_BEARINGS.size():
		return out
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	var breach: Vector3 = hulk_pos + basis * Derelict.BEACON_LOCAL
	breach.y = 0.0
	# The outward prow axis: the direction the beacon sits from the hull centre.
	var outward := breach - hulk_pos
	outward.y = 0.0
	if outward.length() < 0.01:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	for b_v in GUARD_BEARINGS[count]:
		var ang := deg_to_rad(float(b_v) + rng.randf_range(-GUARD_JITTER_DEG, GUARD_JITTER_DEG))
		var reach := GUARD_STANDOFF + rng.randf_range(-GUARD_JITTER_STANDOFF, GUARD_JITTER_STANDOFF)
		var dir := Basis(Vector3.UP, ang) * outward
		out.append(breach + dir * reach)
	return out


static func cell_key(system_id: String, cx: int, cz: int) -> String:
	# The stable identity of a deep station: not its archetype (shared by every
	# station of that kind, everywhere) but the cell it stands in.
	return "%s:%d:%d" % [system_id, cx, cz]


func cell_has_bay(system_id: String, cx: int, cz: int) -> bool:
	# Re-derives a cell from the generator and reports whether it holds a station
	# with a bay. GameState validates every saved deep bay key through this, so a
	# stale or edited save self-corrects instead of carrying phantom stores.
	# THROUGH THE ARENA FILTER, like every other consumer. A bay the generator
	# describes but the world never builds is worse than no bay at all: the store
	# would survive every validation pass and hold cargo the player could never
	# reach, because the Port it belongs to is suppressed as lair keep-out.
	if system_id != _id:
		return false
	var st: Dictionary = built_plan(cx, cz).get("station", {})
	return not st.is_empty() and bool(st.get("storage", false))


static func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


static func cell_centre(cx: int, cz: int) -> Vector3:
	return Vector3((float(cx) + 0.5) * CELL, 0.0, (float(cz) + 0.5) * CELL)


func _owner_tag(cx: int, cz: int) -> String:
	return "deep:%d:%d" % [cx, cz]


func plan_cell(cx: int, cz: int) -> Dictionary:
	# PURE. Given a cell it returns exactly what that cell contains, with no nodes
	# built and no state touched, and `_spawn_cell` builds from what this returns.
	# One source of truth is what makes "the same cell always holds the same
	# thing" a property of the code rather than a claim about it — and it lets a
	# harness compare two visits without having to fly there twice.
	var depth := depth_at(cell_centre(cx, cz))
	var band := band_of(depth)
	# EVERY CONTENT KEY IS PRESENT ON EVERY PATH, including this early return.
	# built_plan indexes plan["convoy"] with no .get -- it is a keep-out filter,
	# and a filter that tolerates a missing key would silently stop filtering --
	# so a band-0 cell that omitted the key was a runtime error, not an empty
	# cell.
	#
	# Band 0 is depth <= 0, i.e. INSIDE the charted volume, which looks
	# unreachable until you check the arithmetic: cell centres sit at
	# (64i+32, 64k+32), so the four innermost are 45.25u from the origin, and
	# PYX-02's bounds are 48.0 -- putting all four at depth -2.75. pyx01 (40.0)
	# and pyx03 (44.0) leave them at band 1, which is why this only ever broke
	# the second system, and only for a player who reached it.
	#
	# THE RULE WAS THEN BROKEN ONCE PER APPEND. `landmark`, `seams` and `hulk2`
	# were each added to the band>0 path below and to nothing else, and `hulk2`
	# is in built_plan's OWN keep-out loop, so from v20 every band-0 cell in
	# PYX-02 threw `Invalid access to key 'hulk2'` -- the identical defect this
	# comment was written about, reintroduced three feet under it. The
	# assertion missed it because it asked for the seven keys that existed the
	# day it was written; it now derives the list from a deep cell instead, so
	# the next append cannot be silent. Anything added below is added here too.
	var out := {"band": band, "depth": depth, "rocks": [], "hulk": {}, "pack": {},
		"station": {}, "convoy": {}, "landmark": {}, "seams": [], "hulk2": {}}
	if band == 0:
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [_id, cx, cz])
	var base := Vector3(float(cx) * CELL, 0.0, float(cz) * CELL)

	# A station rolls FIRST, and everything after it gives it room. It is the
	# rarest and most valuable thing a cell can hold — somewhere to dock is the
	# only safe state this game has — and losing one to a boulder that happened to
	# roll on top of it would be the worst possible way to lose one.
	if rng.randf() < STATION_CHANCE[band]:
		var kinds := DeepPortDB.for_band(band)
		if not kinds.is_empty():
			# v19 stage 4: the ONE edit inside plan_cell. The draw is still
			# rng.randi(), verbatim — the index is derived from the returned
			# uint32, and with no authored row weighted_index IS the old modulo.
			var arch: Dictionary = kinds[weighted_index(rng.randi(), kinds.size(),
				(_deep.get("station_weights", {}) as Dictionary).get(band, []))]
			var sp := base + Vector3(rng.randf_range(STATION_INSET, CELL - STATION_INSET), 0.0,
				rng.randf_range(STATION_INSET, CELL - STATION_INSET))
			if depth_at(sp) >= CONTENT_MIN_DEPTH:
				# A bonded store, on a minority of stations. Rolled here from the
				# same seeded stream as everything else, so a given station always
				# has one or always does not — the scarcity has to be a property
				# of the place, or "is there a bay at that relay" stops being
				# something a player can learn and remember.
				out["station"] = {"pos": sp, "archetype": String(arch["id"]),
					"storage": rng.randf() < DEEP_STORAGE_CHANCE}
	var keep_out: Vector3 = out["station"].get("pos", Vector3(1e9, 0.0, 1e9))

	# Debris. Thin in the Shoals and thickening outward, so the expanse reads as
	# emptier near home and more cluttered where nobody has ever swept it.
	if rng.randf() < [0.0, 0.34, 0.46, 0.58, 0.66, 0.72, 0.78][band]:
		for i in range(rng.randi_range(2, 2 + band)):
			var pos := base + Vector3(rng.randf_range(ROCK_INSET, CELL - ROCK_INSET), -3.0,
				rng.randf_range(ROCK_INSET, CELL - ROCK_INSET))
			if depth_at(pos) < CONTENT_MIN_DEPTH or pos.distance_to(keep_out) < STATION_CLEARANCE:
				continue
			var sx := rng.randf_range(2.2, 4.0 + float(band))
			out["rocks"].append({
				"pos": pos,
				"scale": Vector3(sx, rng.randf_range(2.0, 4.0), sx * rng.randf_range(0.7, 1.3)),
			})

	# A drifting wreck: the reason to go out at all. Loot climbs with the band,
	# so the trip pays for itself further out — and NOT a survey, so cracking one
	# charts nothing and wakes nothing (see Derelict.counts_as_survey).
	if rng.randf() < [0.0, 0.10, 0.15, 0.19, 0.24, 0.28, 0.32][band]:
		var hp := base + Vector3(rng.randf_range(HULK_INSET, CELL - HULK_INSET), 0.0,
			rng.randf_range(HULK_INSET, CELL - HULK_INSET))
		if depth_at(hp) >= CONTENT_MIN_DEPTH and hp.distance_to(keep_out) >= STATION_CLEARANCE:
			var rigged: bool = rng.randf() < float(TRAP_CHANCE[band])
			# Hoisted out of the dict literal: guard_posts needs the same hull
			# rotation to derive the breach point, and re-rolling it there would
			# put the posts around a hull facing somewhere else.
			var rng_rot := rng.randf_range(0.0, 360.0)
			out["hulk"] = {
				"pos": hp,
				"rot_y": rng_rot,
				"loot": int(round(70.0 * [1.0, 1.15, 1.6, 2.2, 2.9, 3.7, 4.6][band]
					* (TRAP_LOOT_BONUS if rigged else 1.0))),
				"crack_time": 1.8 + 0.2 * float(band),
				"trap": {
					"emp": TRAP_EMP[band],
					"count": rng.randi_range(TRAP_PACK_MIN[band], TRAP_PACK_MAX[band]),
					"hp_scale": PACK_HP[band],
					"difficulty": PACK_DIFFICULTY[band],
					"tint": Palette.band_color(band),
					"drop": PACK_DROP[band],
					"escort": band >= TRAP_ESCORT_FROM,
					"escort_count": TRAP_ESCORTS[band],
					"band": band,
				} if rigged else {},
			}
			# A STANDING POST, on its own salted stream.
			#
			# plan_cell's RNG is one linear sequence, so a roll inserted anywhere
			# but the last line reshuffles every cell in the game. Salting mirrors
			# _spring's "|pack" and buys two things: existing determinism is
			# untouched by construction, and "guards roll independently of whether
			# the hulk is rigged" becomes true STRUCTURALLY rather than
			# statistically — on a shared stream the guard roll would sit
			# downstream of the trap roll's consumption.
			#
			# STATION_SAFE_RADIUS, not STATION_CLEARANCE: a hulk keeps only 14u
			# from a station in its own cell, and a post reaches 14.2u past the
			# hulk centre, so on the tighter constant a guard could stand on a
			# docking ring. At 34u the arithmetic is 34 - 14.2 = 19.8 against
			# DOCK_RANGE 5 + ENGAGE_RANGE 9 = 14, so no guard from this cell or
			# the one next door can ever put a docking ship inside its range.
			if depth_at(hp) >= GUARD_MIN_DEPTH \
					and hp.distance_to(keep_out) >= STATION_SAFE_RADIUS:
				var grng := RandomNumberGenerator.new()
				grng.seed = hash("%s|%d|%d|guard" % [_id, cx, cz])
				var gn := guard_count(grng.randf())
				if gn > 0:
					out["hulk"]["guards"] = {
						"count": gn,
						"band": band,
						"difficulty": GUARD_DIFFICULTY[band],
						"hp_scale": GUARD_HP_SCALE[band],
						"tint": Palette.band_color(band),
						"designation": GUARD_DESIGNATION[band],
						"origin": hp,
						"posts": guard_posts(hp, rng_rot, gn, grng),
					}

	# A nest. Nothing hunts you in the Shoals — the first band out is the one that
	# has to teach that the expanse is survivable, or nobody goes to the second.
	if rng.randf() < PACK_CHANCE[band]:
		var pp := base + Vector3(rng.randf_range(PACK_INSET, CELL - PACK_INSET), 0.0,
			rng.randf_range(PACK_INSET, CELL - PACK_INSET))
		# And nothing camps the dock ring. Docking is the game's one safe state;
		# a nest sitting on the only station for four hundred units would turn the
		# reward for the whole trip into a thing you cannot reach.
		if depth_at(pp) >= CONTENT_MIN_DEPTH and pp.distance_to(keep_out) >= STATION_SAFE_RADIUS:
			out["pack"] = {
				"pos": pp,
				"count": rng.randi_range(PACK_MIN[band], PACK_MAX[band]),
				"hp_scale": PACK_HP[band],
				"difficulty": PACK_DIFFICULTY[band],
				"tint": Palette.band_color(band),
				"drop": PACK_DROP[band],
				"escort": band >= PACK_ESCORT_FROM,
				# HOW MANY of them, added BESIDE the bool rather than replacing it:
				# `escort` is read elsewhere, and a key that quietly changed meaning
				# would be the `band` bug below wearing a different hat. Both stay
				# true together — the bool says whether this nest brings a fighter,
				# the count says how many. Takes no roll, so the stream does not
				# move.
				"escort_count": PACK_ESCORTS[band],
				# THE KEY _spring HAS BEEN READING SINCE STAGE 6, and it was
				# never written. `pack.get("band", 0)` therefore always said 0,
				# so every nest in the Reaches and the Quiet flew the HOST
				# ENGINE's flag with a 140u leash — the Tally's no-leash tell
				# never once fired from a real nest. THE DEEP BELONGS TO THE
				# UNKNOWNS stayed green throughout because it asserts
				# flag_for_band(), not what a spawned ship carries: the rule
				# was right and every node was wrong. THE PACK REMEMBERS ITS
				# BAND now asserts the nodes. (Fingerprint-safe: the world
				# fingerprint hashes pack pos and count only.)
				"band": band,
			}

	# APPENDED, after every existing roll and on its own salted stream, exactly
	# like the guards. The roll ORDER above is load-bearing -- a roll inserted
	# anywhere in it reshuffles every cell in the game -- so a new feature may
	# only ever be added at the end, and one that needs randomness of its own
	# takes a separate seed rather than a slice of this one.
	out["landmark"] = landmark_at(cx, cz, band)
	# APPENDED AFTER THE LANDMARK, on its own salted stream, for the reason
	# written directly above. This one looks riskier than it is: it READS
	# out["rocks"], which the shared sequence produced, but it must never DRAW
	# from `rng` -- a seam roll on the shared stream would move every rock, hulk,
	# nest and station in the game by one draw. PYXIS_MINETEST's WORLD
	# FINGERPRINT is the check, against a hash recorded before seams existed.
	out["seams"] = seams_for(cx, cz, band, out["rocks"])
	# APPENDED AFTER THE SEAMS, on its own salted stream, for the reason both
	# comments above give. Reads out["pack"] and keep_out — products of the
	# shared stream — and never draws from `rng`.
	#
	# The red-verify taught the rule more precisely than it was written: a
	# draw from `rng` HERE, after every existing draw, moves NOTHING — the
	# fingerprint stayed green on it — because trailing the stream is exactly
	# what makes appending safe. The same draw at the TOP of this function
	# moved the fingerprint on the first run. So the salted stream is not
	# protecting today's cells from this block; it is protecting this block
	# from tomorrow's edits, and the NEXT appended feature from this one.
	#
	# EVERY DRAW HAPPENS BEFORE THE GATE. The salted stream's shape must not
	# depend on what the shared stream rolled (a pack in this cell, a station
	# nearby): a conditional draw would make the convoy's OWN determinism
	# hostage to unrelated content, and THE DEEP IS TRAVELLED plans each cell
	# twice to prove it cannot happen.
	#
	# The key is set UNCONDITIONALLY, empty or not, because _deep_probe
	# indexes pl[key] without a .get — the same contract every other content
	# key in this dict already honours.
	out["convoy"] = {}
	if band >= 2:
		var crng := RandomNumberGenerator.new()
		crng.seed = hash("%s|%d|%d|convoy" % [_id, cx, cz])
		var convoy_roll := crng.randf()
		var cp := base + Vector3(crng.randf_range(CONVOY_INSET, CELL - CONVOY_INSET), 0.0,
			crng.randf_range(CONVOY_INSET, CELL - CONVOY_INSET))
		var cang := crng.randf_range(0.0, TAU)
		var cfac := convoy_faction(band, crng.randf())
		var cesc := crng.randi_range(1, 2 if band >= 3 else 1)
		var cdart := crng.randi_range(4 if band >= 3 else 3, 5 if band >= 3 else 4)
		var cdepth := depth_at(cp)
		var leg := Vector3(cos(cang), 0.0, sin(cang)) * CONVOY_LEG
		# A cell holds a pack OR a convoy, never both: one _armed slot per
		# cell stays structurally true, and a nest ambushing a convoy it
		# spawned next to would be the generator staging theatre. Both beat
		# endpoints respect the station keep-out, not just the anchor — the
		# escorts WALK, and a waypoint on a dock ring is a picket post nobody
		# authored.
		if convoy_roll < CONVOY_CHANCE and (out["pack"] as Dictionary).is_empty() \
				and cdepth >= CONVOY_MIN_DEPTH and cdepth <= CONVOY_MAX_DEPTH \
				and cp.distance_to(keep_out) >= STATION_SAFE_RADIUS \
				and (cp + leg).distance_to(keep_out) >= STATION_SAFE_RADIUS \
				and (cp - leg).distance_to(keep_out) >= STATION_SAFE_RADIUS:
			out["convoy"] = {"pos": cp, "band": band, "faction": cfac,
				"escorts": cesc, "darts": cdart, "wp": [cp + leg, cp - leg]}

	# A GRAVE-FIELD. v20 stage 4, band 6 only, and the LAST thing in this
	# function — appended after every existing roll on its own salted stream,
	# for the reason the three comments above give and the one the seam roll's
	# red-verify taught: trailing the stream is what makes appending safe, and
	# the salt is what protects the NEXT appended feature from this one.
	#
	# EVERY DRAW HAPPENS BEFORE THE GATE, the convoy's rule: the stream's shape
	# must not depend on what the shared stream rolled, or this block's
	# determinism becomes hostage to whether a cell happened to hold a hulk.
	#
	# WHAT IT IS. The Unsounded's one piece of authored weather: a second wreck
	# beside the first, close enough to read as one event. Everything else out
	# there is a single hull adrift; a PAIR says they arrived together and
	# neither left. It carries no trap and no guards — the cell's first hulk
	# already rolled both, and doubling them would make the field a fight rather
	# than a place.
	#
	# It also pays, and the payment is deliberately the SAME loot table the first
	# hulk uses rather than a richer one. The frontier's reward for depth is
	# already in the band tables; this is the same crate twice, which is volume,
	# which is what the deep is supposed to give.
	out["hulk2"] = {}
	if band >= 6:
		var h2rng := RandomNumberGenerator.new()
		h2rng.seed = hash("%s|%d|%d|hulk2" % [_id, cx, cz])
		var h2_roll := h2rng.randf()
		var h2_ang := h2rng.randf_range(0.0, TAU)
		var h2_gap := h2rng.randf_range(GRAVE_GAP_MIN, GRAVE_GAP_MAX)
		var h2_rot := h2rng.randf_range(0.0, 360.0)
		var first: Dictionary = out["hulk"]
		if h2_roll < GRAVE_CHANCE and not first.is_empty():
			var h2p: Vector3 = (first["pos"] as Vector3) \
				+ Vector3(cos(h2_ang), 0.0, sin(h2_ang)) * h2_gap
			# The same two keep-outs the first hulk answered to. A second wreck
			# is not exempt from the dock ring just because its partner cleared it.
			if depth_at(h2p) >= CONTENT_MIN_DEPTH \
					and h2p.distance_to(keep_out) >= STATION_CLEARANCE:
				out["hulk2"] = {
					"pos": h2p,
					"rot_y": h2_rot,
					"loot": int(first["loot"]),
					"crack_time": float(first["crack_time"]),
					"trap": {},
				}
	return out


func flag_for_band(band: int) -> String:
	# v18 stage 3. WHOSE REACH EXTENDS HOW FAR.
	#
	# The Shoals and the Drift are the host engine's back yard — its packs, its
	# guards, its writ. The REACHES AND THE QUIET ARE NOT, and they stay
	# unflagged: those bands belong to the three powers nobody has a word for
	# yet, and the shipped data already says so out loud —
	# GUARD_DESIGNATION[3] is "UNFLAGGED — NO PATTERN ON FILE" and [4] is
	# "UNREADABLE — IT DOES NOT ANSWER". Claiming them for a known faction now
	# would spend stage 6's reveal early, and would make the designation a lie.
	# v18 STAGE 6. THE DEEP CHANGES HANDS. Stages 3-5 left bands 3 and 4
	# deliberately unflagged so the shipped designations stayed honest —
	# GUARD_DESIGNATION[3] "UNFLAGGED — NO PATTERN ON FILE" and [4]
	# "UNREADABLE — IT DOES NOT ANSWER". They were never nobody's; they were
	# nobody the register could name. Now they have names, and the designations
	# are still true: the register still cannot read them, and the beacon at
	# band 4 still does not answer.
	if band >= 4:
		return "unknown_b"     # THE HOLLOWING holds the Quiet
	if band == 3:
		return "unknown_a"     # THE TALLY holds the Reaches
	return SystemDB.faction_of(_id)


func built_plan(cx: int, cz: int) -> Dictionary:
	# WHAT THE WORLD ACTUALLY BUILDS, as opposed to what the generator said. The
	# differences are the keep-outs — the lair's and, since v18, the hull's —
	# and the split is the whole reason a keep-out is safe.
	#
	# plan_cell stays untouched and stays the fingerprint's subject. Its rolls are
	# one linear sequence and PYXIS_MINETEST's WORLD FINGERPRINT hashes cells
	# -5..5 -- a square reaching ~384u per axis, which pyx01's Drift band lands
	# squarely inside. Subtracting the lair's neighbours THERE would move the hash
	# for a reason that has nothing to do with the seam roll it was recorded to
	# police, and the recorded constant would have to be re-derived every time the
	# salt or a depth band changed. Subtracting them HERE cannot: this function
	# draws from no generator, is called by nothing that hashes, and runs at the
	# moment a cell becomes real.
	#
	# So: plan_cell is the generator's word, built_plan is the world's, and every
	# consumer that turns a cell into nodes, obstacles, armed nests or a save-file
	# validation goes through this one.
	var plan := plan_cell(cx, cz)
	# Mutated in place, which is only safe because plan_cell builds a fresh
	# dictionary on every call and shares nothing between them.
	# "hulk2" rides in both lists beside "hulk", because a grave-field is two
	# crackables and the keep-outs exist to stop a SECOND crackable landing on
	# the survey hull or inside the apex arena. Filtered independently rather
	# than with its partner: the pair is 11-19u apart, so one of them can be
	# inside a keep-out while the other is not, and dropping both would delete
	# content the keep-out never objected to.
	if _has_lair:
		for key_v in ["station", "pack", "hulk", "hulk2", "convoy"]:
			var key := String(key_v)
			var thing: Dictionary = plan[key]
			if not thing.is_empty() \
					and (thing["pos"] as Vector3).distance_to(_lair) < LAIR_KEEPOUT:
				plan[key] = {}
	# v18. The survey hull's elbow room. NOT "pack": a nest drifting in to stand
	# over a wreck out past the cordon is the fiction working, and the hull has
	# had sentries on it since the game shipped. What must not land here is a
	# SECOND CRACKABLE (two hulls a few units apart, one of which charts the
	# next system) or a docking ring on the breach point. "convoy" IS filtered,
	# deliberately stricter than the pack: its escorts walk a beat, and a beat
	# ringing the breach point would read as a second guard post nobody
	# authored.
	if _has_hull:
		for key_v in ["station", "hulk", "hulk2", "convoy"]:
			var key := String(key_v)
			var thing: Dictionary = plan[key]
			if not thing.is_empty() \
					and (thing["pos"] as Vector3).distance_to(_hull) < HULL_KEEPOUT:
				plan[key] = {}
	return plan


# --- seams -------------------------------------------------------------------
# Ore lives on the surface of rocks that were already there. Thin and poor near
# home, thick and rich outward -- and that gradient is not flavour, it is the
# anti-farm mechanism. `_mined` is SESSION state (see note_mined), so a warp
# re-rolls the expanse; what makes that safe is that the band you can reach in
# one warp is the band that pays worst. Band 1 works out at roughly 330 credits
# a minute against a combat baseline of about 2,000 -- PYXIS_MINETEST's WARP FARM
# prints the measured figure. (This said 195 until stage 3: 195 is the band-1
# mean SEAM VALUE from CommodityDB.SEAM_YIELDS, not a rate, and the two were
# transcribed into one sentence.)
# SEAM_CHANCE[0] stays 0.0 forever: charted seams are AUTHORED by SystemBuilder,
# one per asteroid, never rolled. seams_for() early-returns on band <= 0 to match.
const SEAM_CHANCE := [0.0, 0.22, 0.30, 0.38, 0.45, 0.51, 0.56]
# Index 0 became a real entry in stage 4 (it was unread padding before). Nothing
# indexes it except the charted placement and the RICHER OUTWARD assertion.
#
# The frontier rows stay at 6 rather than climbing: a seam's value gradient is
# carried by WHAT it yields (CommodityDB.SEAM_YIELDS' new osmium and vitrite
# rows), not by how many times you hold the button. Six units already takes
# longer than any fight out there lasts.
const SEAM_UNITS := [2, 3, 4, 4, 5, 6, 6]
# How far outside the rock's own collision sphere the seam node sits. A seam
# measured from the ROCK's centre would be unreachable on a big one: a QUIET
# boulder's obstacle radius reaches 6.56 and MineableSeam.MINE_RANGE is 6.0, so
# the ship would be pushed out past its own hold range and the seam could never
# be worked. system_builder.gd:288 records this exact bug being shipped once.
const SEAM_STANDOFF := 0.6


func seams_for(cx: int, cz: int, band: int, rocks: Array) -> Array:
	var out: Array = []
	if band <= 0 or rocks.is_empty():
		return out
	var table: Array = CommodityDB.seam_yields(band)
	if table.is_empty():
		return out
	var srng := RandomNumberGenerator.new()
	srng.seed = hash("%s|%d|%d|seam" % [_id, cx, cz])
	for i in range(rocks.size()):
		if srng.randf() >= SEAM_CHANCE[band]:
			continue
		var r: Dictionary = rocks[i]
		var sc: Vector3 = r["scale"]
		var radius := minf(sc.x, sc.z) * 0.82
		# On the rock's flank, on the play plane. The rock itself sits at y -3,
		# below the plane the ship flies on, so the seam is what the player
		# actually approaches.
		var ang := srng.randf_range(0.0, TAU)
		out.append({
			"rock": i,
			"pos": Vector3(r["pos"].x, 0.0, r["pos"].z)
				+ Vector3(cos(ang), 0.0, sin(ang)) * (radius + SEAM_STANDOFF),
			"good": String(table[srng.randi() % table.size()]),
			"units": SEAM_UNITS[band],
			"band": band,
		})
	return out


func note_mined(cell: Vector2i, index: int) -> void:
	# SESSION state, like _cracked and _surveyed. 17 refuses a persistent
	# visited-cells array because it grows every minute the player flies, and
	# rocks are the most numerous thing out there -- a saved one would grow
	# faster than surveys would. What stops this being a farm is the band
	# gradient, not a save. See PYXIS_MINETEST's WARP FARM.
	if not _mined.has(cell):
		_mined[cell] = {}
	(_mined[cell] as Dictionary)[index] = true


func is_mined(cell: Vector2i, index: int) -> bool:
	return _mined.has(cell) and (_mined[cell] as Dictionary).has(index)


# --- landmarks ---------------------------------------------------------------
# The expanse was uniform noise: every cell rolled the same four things with the
# same tables, so flying out felt like more of the same rather than like going
# somewhere. Landmarks are the second layer -- one per SUPERCELL of 4x4 cells,
# themed by band, so there is roughly one deliberate object every 256 units and
# what it is tells you where you are without reading the label.
#
# This is what "designed rather than random" means here: not less randomness,
# but randomness at two scales, with the coarse one carrying meaning. A single
# scale is noise however you tune it.
const SUPERCELL := 4
# What stands in each band. Band 0 is charted space and gets nothing -- a
# landmark inside the survey volume would be a landmark on a map that already
# has one.
const LANDMARKS := ["", "pylon", "frame", "monolith", "marker", "gate", "cairn"]
# The four real kinds, index-stable, for the weighted per-system pick. A weights
# row is authored against THIS list, not against LANDMARKS — the empty band-0
# entry would put every row off by one.
#
# IT STAYED FOUR FOR A STAGE, ON PURPOSE, and this is the commit that grows it.
# weighted_index falls back to the uniform pick when a row's width does not match
# the list's — silently, by design — so appending here without widening every
# authored row in system_db would have turned pyx02's and pyx03's landmark
# accents off without a word and rolled frontier kinds into the Shoals. §68
# deferred it for exactly that reason and said so in §64.
#
# What makes it safe NOW rather than then is not care, it is coverage: EVERY
# AUTHORED ROW IS THE RIGHT WIDTH (stage 3) checks all eight shipped rows against
# this list's live length, so a row left at four goes red instead of going quiet.
# The assertion was written for the station list and pays for itself here.
#
# Fingerprint-safe by measurement, not assumption: WORLD FINGERPRINT hashes
# rocks, hulk, pack, station, seams and convoy — not the landmark — and
# landmark_at draws from its own salted stream either way.
const LANDMARK_KINDS := ["pylon", "frame", "monolith", "marker", "gate", "cairn"]


static func supercell_of(cx: int, cz: int) -> Vector2i:
	# Floor division, not truncation: -1 / 4 truncates toward zero and puts the
	# cells either side of the origin in the same supercell, which would double
	# the landmark density in exactly the region the player crosses first.
	return Vector2i(floori(float(cx) / float(SUPERCELL)), floori(float(cz) / float(SUPERCELL)))


static func landmark_cell(id: String, sx: int, sz: int) -> Vector2i:
	# Which cell of the supercell carries it. Pure, salted, and independent of
	# every other roll, so adding or removing landmarks cannot move a rock.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|landmark" % [id, sx, sz])
	return Vector2i(sx * SUPERCELL + rng.randi_range(0, SUPERCELL - 1),
		sz * SUPERCELL + rng.randi_range(0, SUPERCELL - 1))


func landmark_at(cx: int, cz: int, band: int) -> Dictionary:
	if band <= 0 or band >= LANDMARKS.size():
		return {}
	var sc := supercell_of(cx, cz)
	if landmark_cell(_id, sc.x, sc.y) != Vector2i(cx, cz):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|landmark_at" % [_id, cx, cz])
	var base := Vector3(float(cx) * CELL, 0.0, float(cz) * CELL)
	var at := base + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	if depth_at(at) < CONTENT_MIN_DEPTH:
		return {}
	# v19 stage 4. WHICH monument stands here can now be authored per system.
	# The shipped pick was a zero-draw table lookup, so the weighted pick is
	# GATED ON ROW PRESENCE and takes its roll from its own salted stream — a
	# system with no row draws nothing anywhere, and a system with one leaves
	# rot_y untouched because the kind roll never shares this rng. THE
	# LANDMARKS DID NOT TURN pins three rotations against exactly that mistake.
	var kind := String(LANDMARKS[band])
	var row: Array = (_deep.get("landmark_weights", {}) as Dictionary).get(band, [])
	if not row.is_empty():
		var krng := RandomNumberGenerator.new()
		krng.seed = hash("%s|%d|%d|landmark_kind" % [_id, cx, cz])
		kind = String(LANDMARK_KINDS[weighted_index(krng.randi(),
			LANDMARK_KINDS.size(), row)])
	return {
		"kind": kind,
		"pos": at,
		"rot_y": rng.randf_range(0.0, 360.0),
		"band": band,
	}


func _stream(around: Vector3) -> void:
	var here := cell_of(around)
	if here == _cell_last:
		return
	_cell_last = here

	# Two passes, and the split between them is the whole point.
	#
	# Everything the GAME needs from a cell -- that it exists, where its collision
	# spheres are, whether a nest is armed -- is derived from plan_cell, which is
	# pure arithmetic and costs nothing. That happens now, for the whole window,
	# exactly as it always did.
	#
	# Everything the EYE needs -- meshes, a Derelict, a Port -- is queued. That is
	# where the time actually goes: measured by PYXIS_STREAMTEST, a single
	# crossing spiked to 44ms building one row of five when one of them held a
	# station, which is roughly three dropped frames in the middle of flying.
	#
	# Determinism is untouched. plan_cell is still the only source of truth and is
	# still called in exactly the same order; only the moment a mesh appears
	# moves, and nothing reads a mesh to decide anything.
	for cz in range(here.y - WINDOW, here.y + WINDOW + 1):
		for cx in range(here.x - WINDOW, here.x + WINDOW + 1):
			var key := Vector2i(cx, cz)
			if not _cells.has(key):
				_cells[key] = _register_cell(cx, cz)
				# built_plan, not plan_cell: arming a nest is instantiation, and a
				# nest armed inside the keep-out would ambush the player in the
				# middle of the boss arena from a node that was never built.
				var bp := built_plan(cx, cz)
				var pack: Dictionary = bp["pack"]
				if not pack.is_empty() and not _sprung.has(key):
					_armed[key] = pack
				# A convoy arms through the same slot — the generator already
				# guarantees a cell rolls one or the other, and the "kind" tag
				# is what _check_encounters dispatches on. Mutating bp is safe
				# for built_plan's own reason: plan_cell builds a fresh dict
				# per call and shares nothing.
				var convoy: Dictionary = bp.get("convoy", {})
				if not convoy.is_empty() and not _sprung.has(key) \
						and not _armed.has(key):
					convoy["kind"] = "convoy"
					_armed[key] = convoy
				if _cells[key] != null:
					_build_queue.append(key)

	for key_v in _cells.keys():
		var key: Vector2i = key_v
		if absi(key.x - here.x) > KEEP or absi(key.y - here.y) > KEEP:
			_despawn_cell(key)

	# Nearest first, so what the player is flying toward is dressed before what
	# they are flying away from.
	var origin := here
	_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - origin).length_squared() < (b - origin).length_squared())


# Cells dressed on the most recent frame that dressed any. This, not a
# stopwatch, is what the budget actually guarantees -- and unlike wall-clock
# milliseconds it means the same thing on a loaded build machine as on a phone.
var built_last_frame := 0


func build_backlog() -> int:
	# Read-back for PYXIS_STREAMTEST. Whether the queue actually empties is the
	# question that decides if amortising was correct or merely quieter.
	return _build_queue.size()


func _drain_queue() -> void:
	# At least one cell per frame, so the queue provably empties even if a single
	# cell exceeds the whole budget -- which is exactly the case that made this
	# necessary, and a budget that could refuse everything would stall forever.
	if _build_queue.is_empty():
		return
	var started := Time.get_ticks_usec()
	var built := 0
	while not _build_queue.is_empty():
		var key: Vector2i = _build_queue.pop_front()
		var node = _cells.get(key)
		if node == null or not is_instance_valid(node):
			continue
		_populate_cell(key.x, key.y, node)
		built += 1
		if Time.get_ticks_usec() - started >= BUILD_BUDGET_USEC:
			break
	built_last_frame = built


func stream_now(around: Vector3) -> void:
	# The escape hatch. Arriving somewhere must never show a frame of empty space
	# where a station is, and first entry was measured at 6.4ms for the whole
	# window -- comfortably inside the warp flash that already covers it. Used by
	# warps and by the capture harnesses, which frame compositions by hand and
	# cannot wait for a queue.
	_stream(around)
	while not _build_queue.is_empty():
		var key: Vector2i = _build_queue.pop_front()
		var node = _cells.get(key)
		if node != null and is_instance_valid(node):
			_populate_cell(key.x, key.y, node)


func _register_cell(cx: int, cz: int):
	# The cheap half: the container plus every collision sphere, all derived from
	# plan_cell. Runs synchronously for the whole window on the frame the player
	# crosses a boundary, so the world is solid before it is visible -- flying
	# through a rock that has not been dressed yet would be a far worse bug than
	# seeing it appear a frame late.
	#
	# built_plan, and this is the call site that MOST needs it: obstacles are the
	# half of a cell that has no mesh. A station suppressed here but registered
	# above would leave a docking ring's worth of invisible wall in the middle of
	# the boss arena, with nothing on screen to explain it.
	var plan := built_plan(cx, cz)
	var rocks: Array = plan["rocks"]
	var hulk: Dictionary = plan["hulk"]
	var station: Dictionary = plan["station"]
	# A landmark counts as content. Without it here, a supercell whose elected
	# cell happens to roll no rocks, no hulk and no station is discarded as empty
	# and the landmark never spawns -- which would silently thin them out in
	# exactly the sparse cells where one is most worth having.
	var mark: Dictionary = plan.get("landmark", {})
	# Seams only exist where rocks do, so they cannot make an otherwise-empty
	# cell contentful -- but naming them here keeps the check honest if that ever
	# stops being true. A convoy counts too, for the landmark's exact reason: a
	# cell whose only content is a convoy would otherwise be discarded as empty
	# and the "content implies a container node" invariant would quietly stop
	# being true in the sparse cells this feature exists to make less empty.
	var convoy: Dictionary = plan.get("convoy", {})
	# hulk2 counts as content for the landmark's and the convoy's exact reason: a
	# cell discarded as empty builds no container node, and the second hull would
	# have nowhere to hang. It cannot currently be the ONLY content — it is gated
	# on the first hulk existing — but naming it here keeps the check honest if
	# that ever stops being true, which is the same sentence the convoy earned.
	if rocks.is_empty() and hulk.is_empty() and station.is_empty() \
			and mark.is_empty() and convoy.is_empty() \
			and (plan.get("hulk2", {}) as Dictionary).is_empty():
		return null

	var tag := _owner_tag(cx, cz)
	var node := Node3D.new()
	node.name = "Cell_%d_%d" % [cx, cz]
	add_child(node)

	for r_v in rocks:
		var r: Dictionary = r_v
		var s: Vector3 = r["scale"]
		Obstacles.add(r["pos"], minf(s.x, s.z) * 0.82, tag)

	if not hulk.is_empty():
		# Derived from rot_y rather than read off the node's basis, because the
		# node does not exist yet. Same vector either way: the Derelict's only
		# rotation is this yaw, applied right after add_child in _populate_cell.
		var fwd := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(float(hulk["rot_y"])))
		var at: Vector3 = hulk["pos"]
		Obstacles.add(at - fwd * 2.6, 1.9, tag)
		Obstacles.add(at + fwd * 2.6, 1.9, tag)

	# The grave-field's second hull, obstacled exactly like the first. A wreck you
	# can fly through is the failure this whole block exists to prevent, and it
	# would only ever show up at band 6 — the least-visited place in the game and
	# the worst one to find a bug in.
	var hulk2r: Dictionary = plan.get("hulk2", {})
	if not hulk2r.is_empty():
		var fwd2 := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(float(hulk2r["rot_y"])))
		var at2: Vector3 = hulk2r["pos"]
		Obstacles.add(at2 - fwd2 * 2.6, 1.9, tag)
		Obstacles.add(at2 + fwd2 * 2.6, 1.9, tag)

	if not station.is_empty():
		var arch0 := DeepPortDB.by_id(String(station["archetype"]))
		if not arch0.is_empty():
			Obstacles.add(station["pos"], Port.HULL_OBSTACLE_RADIUS, tag)
	return node


func _populate_cell(cx: int, cz: int, node: Node3D) -> void:
	# The expensive half: meshes, a Derelict with its own kitbash, a Port with
	# six silhouettes' worth of construction. Drained under a frame budget.
	#
	# built_plan, matching _register_cell exactly. The two halves of a cell must
	# be filtered the same way or they describe different worlds.
	var plan := built_plan(cx, cz)
	var rocks: Array = plan["rocks"]
	var hulk: Dictionary = plan["hulk"]
	var station: Dictionary = plan["station"]

	for seam_v in (plan.get("seams", []) as Array):
		var sd: Dictionary = seam_v
		var seam := MineableSeam.new()
		seam.good = String(sd["good"])
		seam.units = int(sd["units"])
		seam.band = int(sd["band"])
		seam.mine_time = 4.0 + 0.6 * float(int(sd["band"]) - 1)
		seam.cell = Vector2i(cx, cz)
		seam.seam_index = int(sd["rock"])
		# Set BEFORE add_child, the ordering the mast and the derelict already
		# rely on: _ready is what applies the already-worked state.
		seam.mined = is_mined(Vector2i(cx, cz), int(sd["rock"]))
		node.add_child(seam)
		seam.global_position = sd["pos"]

	# Scenery, so it dresses with the meshes and registers no collision -- a
	# landmark you can bump into is an obstacle, and these exist to be looked at
	# from a distance rather than flown to.
	var mark: Dictionary = plan.get("landmark", {})
	if not mark.is_empty():
		var node_mark := Landmarks.build(String(mark["kind"]), int(mark["band"]))
		if node_mark != null:
			node.add_child(node_mark)
			node_mark.global_position = mark["pos"]
			node_mark.rotation_degrees.y = float(mark["rot_y"])

	for r_v in rocks:
		var r: Dictionary = r_v
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 6
		rock.mesh = sm
		rock.material_override = Palette.matte(Color(0.13, 0.12, 0.13))
		node.add_child(rock)
		rock.global_position = r["pos"]
		rock.scale = r["scale"]

	if not hulk.is_empty():
		var d := Derelict.new()
		d.loot_total = int(hulk["loot"])
		d.crack_time = float(hulk["crack_time"])
		# The one thing a deep hulk must NOT do is chart the next system.
		d.counts_as_survey = false
		# Set BEFORE add_child, the same ordering the mast below relies on: _ready
		# is what applies the already-opened state.
		d.cell = Vector2i(cx, cz)
		d.deep = true
		d.cracked = is_hulk_cracked(Vector2i(cx, cz), 0)
		node.add_child(d)
		d.global_position = hulk["pos"]
		d.rotation_degrees.y = float(hulk["rot_y"])
		# After add_child: arm_trap restyles the beacon, which _ready builds.
		d.arm_trap(hulk.get("trap", {}))
		_build_post(Vector2i(cx, cz), hulk.get("guards", {}))

		# The survey mast rides the STERN, opposite the prow breach beacon, at the
		# beacon's own offset mirrored: -6.6 forward, +6.6 aft.
		#
		# It used to sit at 4.5, which put the dish INSIDE the hull. Not partly --
		# the dish's worst-case box is x +/-0.52, y 1.445..2.455, z 3.98..5.02,
		# and _build_mesh's stern block spans x +/-0.7, y -0.75..2.75, z 2.5..5.5.
		# Inside on all three axes. What reached the screen was the fraction of
		# the ring that happened to clear a silhouette edge at one spin phase, on
		# an affordance the player is supposed to fly to and hold on.
		#
		# 6.6 clears it twice over: aft of the stern block (which ends at 5.5) and
		# above the spine roof (y 1.0, and the dish sits at 1.45 and up). The
		# stalk still passes THROUGH the spine, which is what a mast bolted to a
		# hull should look like.
		#
		# The old 4.5 was chosen for a separation figure, and the figure survives:
		# 13.2 units between the two anchors, against a CameraRig._pick radius of
		# 60 SCREEN pixels -- which the pair clears by roughly 5x at every legal
		# zoom. Moving aft also moves AWAY from the guard ring, so the "quiet
		# option" stand-off argument only gets stronger.
		#
		# It fixes a second bug for free. CRACK_RANGE and SURVEY_RANGE are 6.5
		# each, so at 11.1 apart the two in-range spheres OVERLAPPED: both wrote
		# hud.prompt's single slot, and leaving one cleared the other's still-
		# valid prompt. 13.2 > 13.0, so the lens is gone.
		var mast := SurveyMast.new()
		mast.band = int(plan["band"])
		mast.survey_time = 3.0 + 0.5 * float(int(plan["band"]) - 1)
		mast.cell = Vector2i(cx, cz)
		mast.surveyed = _surveyed.has(Vector2i(cx, cz))
		node.add_child(mast)
		mast.global_position = d.global_position + d.global_transform.basis.z * SurveyMast.HULL_OFFSET

	if not station.is_empty():
		var arch := DeepPortDB.by_id(String(station["archetype"]))
		if not arch.is_empty():
			var p := Port.new()
			p.port_id = String(arch["id"])
			p.port_name = String(arch["name"])
			p.kind = String(arch["kind"])
			# The def travels on the node. Nothing is added to SystemDB, so the
			# market-event roll, the rumour loop and STATIONTEST's registry sweeps
			# never see this station exist.
			# DUPLICATED, and this is not optional. DeepPortDB.by_id returns the
			# ARCHETYPES entry itself, and dictionaries are references — so
			# appending "storage" to p.def["services"] below would append it to
			# the archetype, and every Shoal Relay generated afterwards, in every
			# system, for the rest of the session, would have a bay.
			p.def = arch.duplicate(true)
			if bool(station.get("storage", false)):
				(p.def["services"] as Array).append("storage")
			# The bay is keyed on the CELL, never on port_id: port_id is the
			# archetype, shared by every station of this kind everywhere.
			p.bay_key = cell_key(_id, cx, cz)
			node.add_child(p)
			p.global_position = station["pos"]



	# THE SECOND HULL OF A GRAVE-FIELD. Built from the same block deliberately
	# rather than from a shared helper: it differs in exactly three ways, and all
	# three are the point. It carries hulk_index 1 so cracking one of the pair
	# does not open the other; it arms NO trap, because the cell's trap roll
	# belongs to the first wreck and two ambushes at one site is a fight rather
	# than a place; and it posts NO guards, for the same reason.
	var hulk2: Dictionary = plan.get("hulk2", {})
	if not hulk2.is_empty():
		var d2 := Derelict.new()
		d2.loot_total = int(hulk2["loot"])
		d2.crack_time = float(hulk2["crack_time"])
		d2.counts_as_survey = false
		d2.cell = Vector2i(cx, cz)
		d2.hulk_index = 1
		d2.deep = true
		d2.cracked = is_hulk_cracked(Vector2i(cx, cz), 1)
		node.add_child(d2)
		d2.global_position = hulk2["pos"]
		d2.rotation_degrees.y = float(hulk2["rot_y"])

func _check_encounters(at: Vector3) -> void:
	# At most 25 armed nests, and almost always none — this is a distance check
	# over a near-empty dictionary, not a search.
	if not _armed.is_empty():
		for key_v in _armed.keys():
			var key: Vector2i = key_v
			var pack: Dictionary = _armed[key]
			var p: Vector3 = pack["pos"]
			if Vector2(p.x - at.x, p.z - at.z).length() <= ENCOUNTER_TRIGGER:
				if String(pack.get("kind", "pack")) == "convoy":
					_spring_convoy(key, pack)
				else:
					_spring(key, pack)
	if not _guards.is_empty():
		_check_hails(at)
	if not _convoys.is_empty():
		_check_convoy_hails(at)


func _check_hails(at: Vector3) -> void:
	# Reuses ENCOUNTER_TRIGGER rather than inventing a hail range: one number for
	# "the expanse has noticed you" beats two, or the player learns two distances
	# for the same sensation.
	#
	# _hailed is session-only and deliberately NOT cleared on despawn, same as
	# _sprung: flying a circle back through a sector you already read must not
	# hand you the same announcement twice. A cleared post has no standing guards
	# and is skipped for free.
	for key_v in _guards.keys():
		var key: Vector2i = key_v
		if _hailed.has(key) or post_standing(key) == 0:
			continue
		var origin: Vector3 = _guard_origin.get(key, Vector3.ZERO)
		if Vector2(origin.x - at.x, origin.z - at.z).length() > ENCOUNTER_TRIGGER:
			continue
		_hailed[key] = true
		var band := band_of(depth_at(origin))
		var n := post_standing(key)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("%s STANDING — %s" % [
				GUARD_COUNT_WORD[mini(n, GUARD_COUNT_WORD.size() - 1)],
				GUARD_DESIGNATION[band]], Palette.band_color(band))


func _spring(key: Vector2i, pack: Dictionary) -> void:
	# Hostiles go into SYSTEM_ROOT, never into the cell node. A pack that belonged
	# to its cell would vanish mid-fight the moment the chase carried the player
	# past the streaming window — which, since a swarm is faster than the player,
	# is exactly what a real chase does.
	_armed.erase(key)
	_sprung[key] = true
	var root := get_parent()
	if root == null:
		return

	var origin: Vector3 = pack["pos"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|pack" % [_id, key.x, key.y])
	var count := int(pack["count"])
	var drop := String(pack["drop"])

	# The band is already in the plan; re-deriving it from the position would be
	# a second source for a number the generator has already decided.
	var pack_band := int(pack.get("band", 0))
	var flag := flag_for_band(pack_band)
	var leash := leash_for(pack_band, flag)
	for i in range(count):
		var s := SwarmHostile.new()
		s.difficulty = float(pack["difficulty"])
		s.hp_scale = float(pack["hp_scale"])
		s.faction = flag
		# THE TALLY'S TELL, and it is one line: everything else the expanse
		# seeds carries HOSTILE_LEASH so a pack picked up 400u out does not
		# follow you home. The Tally has no leash. It does not lose you, it
		# does not give up, and the only way it stops is if you stop it —
		# which is the whole of what "it counts what passes" means in play.
		# Legible without a tooltip: the thing behind you is still there.
		s.tint = pack["tint"]
		# One crate of the good thing, the same way a raider carries what it took.
		s.drop_good = drop if i == 0 else ""
		s.despawn_radius = leash
		root.add_child(s)
		s.global_position = origin + Vector3(rng.randf_range(-2.5, 2.5), 0.0,
			rng.randf_range(-2.5, 2.5))

	# The escort, and past the Quiet there is more than one of it. Ringed rather
	# than stacked on the origin: two machines at the same point read as one
	# sprite with a health bar that will not go down.
	var escorts := int(pack.get("escort_count", 1 if bool(pack["escort"]) else 0))
	for i in range(escorts):
		var h := Hostile.new()
		h.difficulty = float(pack["difficulty"])
		h.faction = flag
		h.despawn_radius = leash
		root.add_child(h)
		var a := TAU * float(i) / float(maxi(escorts, 1))
		h.global_position = origin + (Vector3.ZERO if escorts <= 1
			else Vector3(cos(a) * 3.4, 0.0, sin(a) * 3.4))

	FX.ring_pulse(root, origin, pack["tint"], 3.0, 0.9)
	Sfx.play("klaxon", -12.0, 1.15)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("CONTACT — %s" % band_name(depth_at(origin)), pack["tint"])


func _spring_convoy(key: Vector2i, cfg: Dictionary) -> void:
	# TRAFFIC, NOT TERRITORY. A convoy is the deep's other kind of encounter:
	# somebody's cargo walking a short beat past the chart, escorted, painted,
	# and — for six of the seven flags — not hostile to the surveyor at all.
	# _sprung is the income bound and the memory both: one convoy per cell per
	# session, exactly a nest's contract, so flying a circle cannot re-summon
	# what you already met (or already farmed).
	_armed.erase(key)
	_sprung[key] = true
	var root := get_parent()
	if root == null:
		return
	var origin: Vector3 = cfg["pos"]
	var flag := String(cfg["faction"])
	var band := int(cfg["band"])
	# EXPLICIT on both classes. Hostile would fall back to faction paint on
	# its own; SwarmHostile never does — its tint default is THREAT red — and
	# a convoy of generic red darts would read as an attack you are somehow
	# not being blamed for.
	var paint := FactionDB.tint_of(flag)
	var cid := cell_key(_id, key.x, key.y)
	var wp: Array = cfg["wp"]
	# Typed, appended, then assigned — the system_builder shape. An untyped
	# array literal fails the Array[Vector3] assignment at runtime.
	var route: Array[Vector3] = []
	route.append(wp[0] as Vector3)
	route.append(wp[1] as Vector3)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|convoyspring" % [_id, key.x, key.y])
	var darts: Array = []
	var escorts: Array = []
	for i in range(int(cfg["darts"])):
		var s := SwarmHostile.new()
		s.difficulty = float(PACK_DIFFICULTY[band])
		s.hp_scale = float(PACK_HP[band])
		s.faction = flag
		s.tint = paint
		# EVERYTHING LEASHED, the Tithe included. The Tally's no-leash is the
		# one tell that class of thing has (HORIZON-4 §9), and it stays
		# unique; and _sprung already forbids the leash-away-and-return
		# re-arm, which is the farm that forces guard posts to 0.0.
		s.despawn_radius = HOSTILE_LEASH
		# Staggered: half walk each way, so the group reads as a working
		# beat rather than a school of fish.
		s.march_to = wp[i % 2]
		s.add_to_group("deep_convoy")
		s.set_meta("convoy_id", cid)
		root.add_child(s)
		s.global_position = origin + Vector3(rng.randf_range(-2.5, 2.5), 0.0,
			rng.randf_range(-2.5, 2.5))
		darts.append(s)
	for i in range(int(cfg["escorts"])):
		var h := Hostile.new()
		h.difficulty = float(PACK_DIFFICULTY[band])
		h.faction = flag
		h.tint = paint
		h.despawn_radius = HOSTILE_LEASH
		h.patrol = route
		h.add_to_group("deep_convoy")
		h.set_meta("convoy_id", cid)
		root.add_child(h)
		h.global_position = origin + Vector3(rng.randf_range(-3.5, 3.5), 0.0,
			rng.randf_range(-3.5, 3.5))
		escorts.append(h)
	_convoys[key] = {"darts": darts, "escorts": escorts, "wp": wp}
	FX.ring_pulse(root, origin, paint, 3.0, 0.9)
	if flag == "tithe":
		# Only the hostile one gets the alarm. The klaxon means "you are
		# about to be shot at", and six of these seven are not that.
		Sfx.play("klaxon", -12.0, 1.15)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("TRAFFIC — %s" % FactionDB.display_name(flag), paint)


func _tick_convoys() -> void:
	# Re-arms the march when a dart clears a waypoint — arrival zeroes
	# march_to (SwarmHostile._march_step), and the FARTHER endpoint is always
	# the right next leg because arrival means standing within MARCH_ARRIVE
	# (6u) of one end of a 24u beat. No per-dart state to keep true.
	# Convoys are sparse; this walks a handful of nodes, almost always none.
	for key_v in _convoys.keys():
		var rec: Dictionary = _convoys[key_v]
		var live := 0
		var wps: Array = rec["wp"]
		for d_v in rec["darts"]:
			# Untyped loop variable: a leashed-away dart is a freed node, and
			# a typed access would fail at the boundary before
			# is_instance_valid could speak.
			if not is_instance_valid(d_v):
				continue
			live += 1
			if d_v.march_to == Vector3.ZERO:
				var a: Vector3 = wps[0]
				var b: Vector3 = wps[1]
				d_v.march_to = a if d_v.global_position.distance_to(a) \
					> d_v.global_position.distance_to(b) else b
		for e_v in rec["escorts"]:
			if is_instance_valid(e_v):
				live += 1
		if live == 0:
			_convoys.erase(key_v)   # keys() is a copy; erasing mid-walk is safe


func live_convoy(key: Vector2i) -> Dictionary:
	# Harness support, armed_nests' sibling: the live members of a sprung
	# convoy, or {} — so an assertion can sweep exactly one convoy's ships
	# without inferring membership from position.
	return _convoys.get(key, {})


func _build_post(key: Vector2i, cfg: Dictionary) -> void:
	# A post you have already cleared stays cleared. Hostile.LOOT_COUNT is 14
	# against a swarm's 2, so a four-guard post pays around 2,600 — and PACING_LOOP
	# budgets FIVE sentries for a whole eight-minute loop. A post that re-armed
	# every time its cell cycled would be an unbounded farm reachable by flying
	# 200u out and back: 11's money-printer rule, somewhere ports cannot reach.
	if cfg.is_empty() or _cleared.has(key):
		return
	var root := get_parent()
	if root == null:
		return
	var live: Array = []
	var post_flag := flag_for_band(int(cfg.get("band", 0)))
	for post_v in cfg.get("posts", []):
		var h := Hostile.new()
		h.difficulty = float(cfg["difficulty"])
		h.hp_scale = float(cfg["hp_scale"])
		h.faction = post_flag
		h.tint = cfg["tint"]
		h.designation = String(cfg["designation"])
		# NO LEASH, and that is deliberate rather than forgotten. despawn_radius
		# exists because a swarm does 7.5 against the ship's 5.75 and cannot be
		# outrun, so a chase needs an end. A guard does not chase — _process hard
		# writes it back to its post. A leash here would create a 141u disarm: back
		# off past it, return before the cell cycles at 192u, and the hulk is
		# unguarded. The CELL is what ends a guard's life.
		h.despawn_radius = 0.0
		h.add_to_group("deep_guard")
		# Which post this guard belongs to, so its death can ask whether the post
		# it was standing in is now empty.
		h.set_meta("post_key", key)
		root.add_child(h)
		h.global_position = post_v
		live.append(h)
	if not live.is_empty():
		_guards[key] = live
		_guard_origin[key] = cfg["origin"]


static func _hulk_key(key: Vector2i, index: int) -> String:
	# One place that decides what identifies a wreck, so the writer and the
	# reader cannot drift apart. Index DEFAULTS to 0 everywhere, which is what
	# keeps every shipped call site meaning exactly what it always meant.
	return "%d,%d,%d" % [key.x, key.y, index]


func note_hulk_cracked(key: Vector2i, index := 0) -> void:
	# Called from Derelict._breach, the same shape note_guard_died is called in.
	_cracked[_hulk_key(key, index)] = true


func is_hulk_cracked(key: Vector2i, index := 0) -> bool:
	return _cracked.has(_hulk_key(key, index))


func note_surveyed(key: Vector2i) -> void:
	_surveyed[key] = true


func is_surveyed(key: Vector2i) -> bool:
	return _surveyed.has(key)


func _check_convoy_hails(at: Vector3) -> void:
	# THE ONE THING A FRIEND OUT HERE HAS TO GIVE. Reuses ENCOUNTER_TRIGGER for
	# _check_hails' reason: one distance for "the expanse has noticed you" beats
	# two that drift apart. One-shot per convoy per session, _sprung's contract,
	# so flying a circle cannot re-read the same navigator.
	#
	# NO BUTTON, and that is the parley doctrine applied rather than ignored:
	# the HUD licenses a transient action for A DECISION WITH A COST. A hail
	# costs nothing and can be refused by nobody, so a button would be a confirm
	# dialog for a gift. The player's action is the approach -- which the
	# convoy's own radar marker is already inviting.
	for key_v in _convoys.keys():
		var key: Vector2i = key_v
		if _convoy_hailed.has(key):
			continue
		var rec: Dictionary = _convoys[key]
		var speaker: Node3D = null
		for m_v in (rec["escorts"] as Array) + (rec["darts"] as Array):
			if is_instance_valid(m_v):
				speaker = m_v as Node3D
				break
		if speaker == null:
			continue
		var flag := String(speaker.faction)
		if GameState.faction_band(FactionDB.SURVEYOR, flag) > CONVOY_HAIL_MIN_BAND:
			continue
		if Vector2(speaker.global_position.x - at.x,
				speaker.global_position.z - at.z).length() > ENCOUNTER_TRIGGER:
			continue
		# MARKED FIRST, whatever happens next: a hail the dossier refuses as a
		# duplicate must not be retried on every frame for the rest of the
		# session.
		# Marked before anything else, and it stays marked whatever happens
		# next: a hail retried every frame for the rest of the session is a
		# worse failure than a hail that had nothing to say.
		_convoy_hailed[key] = true
		var main := get_tree().get_first_node_in_group("main")
		if main == null or not main.has_method("file_apex_intel"):
			return
		# FILED FIRST, SPOKEN SECOND -- the hunt desk's rule, for its reason: a
		# convoy that announced a fix nothing recorded would be worse than a
		# convoy that said nothing at all.
		#
		# BUT A REFUSAL IS STILL AN ANSWER. The dossier declines a hint for a
		# system whose engine is already dead, which is most of a deep-farming
		# player's session -- and the first version returned there, so the one
		# convoy that would ever hail them burned its only line in silence.
		# Standing the player spent a trade route earning produced no
		# observable output at all. They get the greeting either way; only the
		# cargo of it changes.
		var filed: bool = main.file_apex_intel("convoy", speaker.global_position,
			CONVOY_HINT_ERROR_DEG)
		var hud := get_tree().get_first_node_in_group("hud")
		if not filed:
			if hud and hud.has_method("show_broadcast"):
				hud.show_broadcast("%s CONVOY" % FactionDB.display_name(flag),
					"Good hunting out here, surveyor. The lane is quiet and we "
					+ "have nothing you do not already know — but you have our "
					+ "thanks, and our channel, whenever you want them.",
					FactionDB.tint_of(flag))
			return
		if hud and hud.has_method("show_broadcast"):
			hud.show_broadcast("%s CONVOY" % FactionDB.display_name(flag),
				"You have been good to us, surveyor. Our navigator has a fix on "
				+ "what is jamming the lane — it is not a good one, we are "
				+ "haulers and not a survey, but it is honest and it is yours.",
				FactionDB.tint_of(flag))
		return


func note_convoy_defended(cid: String) -> bool:
	# ONE CREDIT PER CONVOY PER SESSION, _sprung's shape and _sprung's argument.
	# A Tally pack is six to eight ships; uncapped, one encounter would be six
	# steps of trust and reach ALLIED in an afternoon. Returns whether this was
	# the first, so the caller never has to know how the bound is stored.
	if cid == "" or _defended.has(cid):
		return false
	_defended[cid] = true
	return true


func note_guard_died(key: Vector2i) -> void:
	# Called from Hostile._die, NOT from _despawn_cell. A player who clears a post
	# and then keeps working the wreck beside it never triggers a despawn, so
	# crediting the clear at despawn time would miss exactly the case where the
	# player most obviously earned it — and would credit it minutes later, out of
	# sight of the thing that caused it.
	if _counted.has(key) or post_standing(key) > 0:
		return
	_counted[key] = true
	GameState.note_ledger("posts_cleared", 1)
	# Band from the HULK's own position, never from the cell centre: a cell is 64u
	# across and a band edge can run straight through one, so the two can name
	# different bands for the same post.
	var origin: Vector3 = _guard_origin.get(key, Vector3.ZERO)
	GameState.note_log("POST CLEARED — %s" % band_name(depth_at(origin)))

	# WHAT THE POST WAS GUARDING AGAINST. A cleared post gives up its standing
	# orders, and out here those orders point one way. Gated on band >= 2 for a
	# reason that is not difficulty scaling: the Shoals are close enough to the
	# chart that a post there is guarding a wreck, not keeping a watch on the
	# engine, and letting it talk would hand out a bearing before the player had
	# gone anywhere.
	#
	# +-15 degrees, the widest bearing channel in the game. This is the one hint
	# you can earn purely by fighting, so it is deliberately the vaguest: it
	# rewards clearing the deep without letting combat substitute for the desks
	# that sell precision.
	if band_of(depth_at(origin)) >= 2:
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("file_apex_intel"):
			main.file_apex_intel("guard", origin, 15.0)


func guards_at(key: Vector2i) -> Array:
	# Harness support: the streaming window holds several guarded hulks at once,
	# so anything asserting about ONE post has to ask by cell rather than sweep
	# the deep_guard group.
	return _guards.get(key, [])


func post_standing(key: Vector2i) -> int:
	var n := 0
	for g_v in _guards.get(key, []):
		var g = g_v
		if is_instance_valid(g) and not g.is_dying():
			n += 1
	return n


func _despawn_cell(key: Vector2i) -> void:
	var node = _cells.get(key)
	_cells.erase(key)
	# A cell that leaves the window before it was ever dressed drops out of the
	# queue with it. Without this the drain would later reach a key whose node is
	# gone -- harmless, because it checks, but it would also mean flying fast
	# enough could keep a stale backlog growing behind the player forever.
	_build_queue.erase(key)
	# The nest goes back to being a seed. It is not lost — plan_cell will produce
	# the identical pack if the player ever comes back — it is simply no longer
	# armed, because there is no cell here any more to walk into.
	_armed.erase(key)
	# Guards are freed by their OWNER, not by the tree they live in. Polled before
	# freeing: a post whose last guard died stays cleared, so leaving and coming
	# back cannot rebuild a fight you already won.
	if _guards.has(key):
		if post_standing(key) == 0:
			_cleared[key] = true
		for g_v in _guards[key]:
			var g = g_v
			if is_instance_valid(g):
				g.queue_free()
		_guards.erase(key)
		_guard_origin.erase(key)
	# Obstacles come out FIRST and synchronously. queue_free is deferred, so
	# clearing them afterwards would leave a frame in which the mesh is gone and
	# its collision sphere is not — an invisible wall, out where there is nothing
	# to explain it.
	Obstacles.remove_owner(_owner_tag(key.x, key.y))
	if node != null and is_instance_valid(node):
		node.queue_free()


func rebuild() -> void:
	# Drop every live cell and let the stream rebuild them. Used by the colour
	# vision setting, which changes what band_color returns -- and every deep
	# material was baked from that at construction, so nothing short of building
	# them again picks it up. Costs nothing that warping does not already cost,
	# and the world is a pure function of (system, cell), so what comes back is
	# identical apart from the tint.
	_despawn_all()
	_build_queue.clear()
	_cell_last = Vector2i(9999, 9999)      # force the next _stream to run


func _despawn_all() -> void:
	_build_queue.clear()
	_mined.clear()
	for key_v in _cells.keys():
		_despawn_cell(key_v)
	_armed.clear()
	_sprung.clear()
	_convoys.clear()
	_guards.clear()
	_guard_origin.clear()
	_cleared.clear()
	_hailed.clear()
	_convoy_hailed.clear()
	_defended.clear()
	_counted.clear()
	_cracked.clear()
	_surveyed.clear()
	_cell_last = Vector2i(0x7fffffff, 0x7fffffff)


# --- harness support --------------------------------------------------------

func live_cells() -> Array:
	return _cells.keys()


func live_cell_count() -> int:
	return _cells.size()


func content_cell_count() -> int:
	var n := 0
	for key in _cells:
		if _cells[key] != null:
			n += 1
	return n


func armed_nests() -> Array:
	# Where the loaded ambushes are, for PYXIS_HUNTTEST's arena assertion. A nest
	# is the one piece of deep content with no node until it springs, so counting
	# what is in the tree would report an empty arena that is merely a quiet one.
	# Since convoys, an armed entry may also be one of those — built_plan filters
	# both kinds out of the lair keep-out, so the arena clause reads the same.
	var out: Array = []
	for key_v in _armed:
		out.append((_armed[key_v] as Dictionary)["pos"])
	return out


func _process(_delta: float) -> void:
	# Ahead of the early return: cells already registered still owe their meshes
	# whether or not there is a rig to follow this frame.
	_drain_queue()
	var rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if rig == null or _stars == null:
		return
	var c := rig.global_position
	_stars.follow(c)
	_motes.follow(c)
	_cold.global_position = Vector3(c.x, -70.0, c.z)

	# Sectors stream around the SHIP, not the lens. The camera can be panned a
	# leash-length away from the player, and content that appeared because you
	# looked somewhere would be content that vanished when you looked back.
	if generating:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player != null:
			_stream(player.global_position)
			_check_encounters(player.global_position)
			_tick_convoys()

	var depth := maxf(Vector2(c.x, c.z).length() - _bounds, 0.0)
	var k := clampf(depth / DEEP_FULL, 0.0, 1.0)
	if is_equal_approx(k, _k_last):
		return
	_k_last = k
	_motes.set_presence(k)
	_cold_mat.albedo_color.a = lerpf(0.0, 0.030, k)


func depth_at(pos: Vector3) -> float:
	return maxf(Vector2(pos.x, pos.z).length() - _bounds, 0.0)


func star_field() -> DeepField:
	return _stars
