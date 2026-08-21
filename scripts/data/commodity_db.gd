class_name CommodityDB
extends Object
# Tradeable goods. Every good must be obtainable by playing (not only by buying)
# so combat and salvage feed the market rather than sitting beside it.
#
# `space` is hold volume per unit — the reason a trading build has to argue with
# a combat build over the utility slot.

# What a ship out in the black pays for cargo, as a fraction of base price. It
# lives HERE, in the leaf that owns base_price, because it is a fact about what
# goods are worth rather than about who is buying — and because both the seller
# (Main.space_trade) and the label that quotes it (HUD.contact_options) need it,
# and neither of those two files can see the other's constants.
#
# DELIBERATELY WELL UNDER ANY SANE DOCK ROUTE. What is being sold to a passing
# convoy is the trip home, not the cargo. It is also flat, and applied to
# base_price rather than through Market: no price in this game consults standing
# (asserted by NO PRICE MOVES WITH STANDING), and the reputation gate on this
# trade decides only whether it is offered at all.
#
# It ignores market drift on purpose — a port whose price has drifted under
# 0.7x base is briefly the worse deal. Accepted, because a convoy never resells
# and no loop closes; if the drift range ever widens, re-check that.
const SPACE_TRADE_RATE := 0.7

const GOODS := {
	"alloys": {
		"name": "Scrap Alloys",
		"short": "ALLOYS",
		"base": 40,
		"space": 2,
		"color": Color(0.72, 0.74, 0.78),
		"desc": "Hull plate cut down for the furnaces.",
	},
	"volatiles": {
		"name": "Volatiles",
		"short": "VOLATILE",
		"base": 55,
		"space": 1,
		"color": Color(0.45, 0.95, 0.6),
		"desc": "Unspent drive propellant, still lively.",
	},
	"isotopes": {
		"name": "Rare Isotopes",
		"short": "ISOTOPE",
		"base": 130,
		"space": 1,
		"color": Color(0.35, 0.9, 0.95),
		"desc": "Reactor feedstock. Handled at arm's length.",
	},
	"cores": {
		"name": "Archive Cores",
		"short": "CORES",
		"base": 180,
		"space": 2,
		"color": Color(0.65, 0.55, 1.0),
		"desc": "Sealed memory lattices. Nobody has read one yet.",
	},
	"relics": {
		"name": "Intact Relics",
		"short": "RELICS",
		"base": 260,
		"space": 3,
		"color": Color(1.0, 0.72, 0.28),
		"desc": "Whole machines from before the war ended.",
	},
	# --- phase 2: goods that make the hold a liability as well as an asset ----
	"stolen": {
		"name": "Stolen Goods",
		"short": "STOLEN",
		"base": 150,
		"space": 2,
		"color": Color(0.88, 0.34, 0.42),
		"desc": "Somebody else's cargo, still in somebody else's crates.",
		# The two shady stops plus the neutral freeport. Bastion Yards buying
		# stolen cargo over the counter was the odd note; the Anchor stays on the
		# list so a raider drop in the starting system is never dead weight in a
		# hold with nowhere to take it.
		"trade_only_at": ["void", "cantina", "anchor"],
		# Raiders drop it, so carrying it draws more raiders. Fitting.
		"interdiction_weight": 2.0,
	},
	"contraband": {
		"name": "Contraband",
		"short": "BANNED",
		"base": 340,
		"space": 1,
		"color": Color(0.95, 0.2, 0.55),
		"desc": "Unlisted, unlicensed, and worth every bit of the trouble.",
		# The trade with teeth: dense, valuable, and only two buyers on the chart.
		# Everything about it is a bet that you can get where you are going.
		"trade_only_at": ["void", "cantina"],
		"interdiction_weight": 3.0,
	},

	# --- phase 4: salvage you cannot read yet --------------------------------
	# Five grades of UNIDENTIFIED salvage, one per distance band, named for the
	# places the player already knows (DeepSpace.BAND_NAMES). Provenance IS the
	# category: a haul out of THE QUIET is a different thing from one out of the
	# Shoals, without a single new noun to learn.
	#
	# Unread, they are scrap and sell as scrap — that is deliberate. Ignoring this
	# whole system has to stay a legitimate way to play, or reading becomes a toll
	# on your own loot rather than an upgrade to it.
	#
	# `no_retail` means never buyable, anywhere. Buy salvage cheap, read it, sell
	# the component dear is an infinite loop, so the buy side is closed at the
	# source the same way Market.can_buy already closes it for a fence's goods.
	"salvage_charted": {
		"name": "Charted Salvage", "short": "SLV-C",
		"base": 60, "space": 2, "color": Color(0.62, 0.66, 0.72),
		"desc": "Somebody's ship, once. The usual.",
		"band": 0, "no_retail": true,
	},
	"salvage_shoal": {
		"name": "Shoal Salvage", "short": "SLV-S",
		"base": 95, "space": 2, "color": Color(0.60, 0.74, 0.78),
		"desc": "Picked over already, but not thoroughly.",
		"band": 1, "no_retail": true,
	},
	"salvage_drift": {
		"name": "Drift Salvage", "short": "SLV-D",
		"base": 150, "space": 2, "color": Color(0.56, 0.72, 0.90),
		"desc": "Scorched, but the core of it held.",
		"band": 2, "no_retail": true, "interdiction_weight": 1.2,
	},
	"salvage_reaches": {
		"name": "Reaches Salvage", "short": "SLV-R",
		"base": 230, "space": 3, "color": Color(0.66, 0.60, 0.96),
		"desc": "Sealed, and the seal is not a standard one.",
		"band": 3, "no_retail": true, "interdiction_weight": 1.4,
	},
	"salvage_quiet": {
		"name": "Quiet Salvage", "short": "SLV-Q",
		"base": 340, "space": 3, "color": Color(0.86, 0.70, 1.0),
		"desc": "Unreadable. Something was built out here.",
		"band": 4, "no_retail": true, "interdiction_weight": 1.7,
	},
	# v20 THE FRONTIER. The ratios were 1.58 / 1.58 / 1.53 / 1.48 -- a curve
	# already tapering -- so 1.41 and 1.375 continue it rather than restarting it.
	# Both stay no_retail like every grade above them: unread salvage has never
	# been something a counter will sell you, and the deepest of it least of all.
	"salvage_fathom": {
		"name": "Fathom Salvage", "short": "SLV-F",
		"base": 480, "space": 3, "color": Color(0.62, 0.80, 0.96),
		"desc": "Crushed by depth, not by impact.",
		"band": 5, "no_retail": true, "interdiction_weight": 2.0,
	},
	"salvage_unsounded": {
		"name": "Unsounded Salvage", "short": "SLV-U",
		"base": 620, "space": 3, "color": Color(0.60, 0.92, 0.66),
		"desc": "It was not built. It grew.",
		"band": 6, "no_retail": true, "interdiction_weight": 2.4,
	},

	# --- phase 4: components -------------------------------------------------
	# What salvage becomes once it can be read. Each names its `parent`, which is
	# what makes the seven goods above read as CATEGORIES rather than as a flat
	# list — a Pre-War Servo is a relic, and says so.
	#
	# Sell-only and restricted to the ports that FENCE them, so they stay out of
	# the MARKET tab everywhere else and the Anchor's shopfront is still the seven
	# goods it always was. Selling one is deliberately the worse option; it exists
	# so a hold is never dead weight (11: a route needs both ends built).
	"plate_ablative": {
		"name": "Ablative Plate", "short": "PLATE",
		"base": 150, "space": 2, "color": Color(0.78, 0.80, 0.84),
		"desc": "Sacrificial hull layer, still scorched from whatever it stopped.",
		"parent": "alloys", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.1,
	},
	"cell_fuel": {
		"name": "Fuel Cell", "short": "CELL",
		"base": 190, "space": 2, "color": Color(0.50, 0.96, 0.66),
		"desc": "Sealed, pressurised, and older than it should be.",
		"parent": "volatiles", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.2,
	},
	"rod_decay": {
		"name": "Decay Rod", "short": "ROD",
		"base": 300, "space": 2, "color": Color(0.40, 0.94, 0.98),
		"desc": "Spent, mostly. The rest is why it is still warm.",
		"parent": "isotopes", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.4,
	},
	"sink_thermal": {
		"name": "Thermal Sink", "short": "SINK",
		"base": 360, "space": 2, "color": Color(0.32, 0.82, 0.92),
		"desc": "Drinks heat and gives nothing back. Shrugs off an EMP wash.",
		"parent": "isotopes", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.3,
	},
	"lattice_data": {
		"name": "Data Lattice", "short": "LATTICE",
		"base": 400, "space": 2, "color": Color(0.70, 0.60, 1.0),
		"desc": "One layer of an archive core, prised out intact.",
		"parent": "cores", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.4,
	},
	"index_cartographic": {
		"name": "Cartographic Index", "short": "INDEX",
		"base": 560, "space": 3, "color": Color(0.55, 0.70, 1.0),
		"desc": "Somebody else's chart, of somewhere nobody has been. Stations answer it.",
		"parent": "cores", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.6,
	},
	"servo_prewar": {
		"name": "Pre-War Servo", "short": "SERVO",
		"base": 480, "space": 3, "color": Color(1.0, 0.76, 0.34),
		"desc": "Still holds torque. Nothing built since comes close.",
		"parent": "relics", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.6,
	},
	"heart_reliquary": {
		"name": "Reliquary Heart", "short": "HEART",
		"base": 700, "space": 3, "color": Color(1.0, 0.62, 0.28),
		"desc": "Warm, and unpowered for an age. Rigged hulls hum near it.",
		"parent": "relics", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 1.9,
	},
	# v20 THE FRONTIER, and it exists because READING PAYS demanded it rather
	# than because the frontier wanted a new noun.
	#
	# The rule is that the CHEAPEST thing a grade reads into must still beat
	# selling it unread, or one of the player's choices is a trap. The component
	# table topped out at the Reliquary Heart's 700, so an Unsounded crate could
	# be priced no higher than ~560 and still offer two honest reads — which
	# flattened the raw gradient past the Quiet to 1.08x and quietly deleted the
	# thing depth is supposed to buy. One part above the Heart restores it: the
	# grade sits at 620 (1.29x on the Fathoms, continuing the 1.58/1.53/1.48/1.41
	# taper) with two reads that both pay.
	#
	# NOT a forge input, and the Unstable Charge is the precedent: a component may
	# be something you only ever sell. The four craft recipes are untouched.
	# SPACE 2, NOT 3, and that is READ COMPRESSION's doing rather than flavour's.
	# Reading has to be worth the hold space it frees — every shipped grade reads
	# into something at least 1.5x denser than itself — and the frontier's grades
	# are space 3 reading into space-3 parts, which came out at 1.45x: a read that
	# barely repaid the gesture. At space 2 the Lens is 450 a slot against the
	# Unsounded's 207, which is the 2.2x the rule is asking for. A lens being the
	# compact thing in a crate of wreckage is also simply true.
	"lens_unsounded": {
		"name": "Unsounded Lens", "short": "LENS",
		"base": 900, "space": 2, "color": Color(0.58, 0.94, 0.72),
		"desc": "Ground by nothing, to a figure nobody chose. It focuses something.",
		"parent": "relics", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 2.2,
	},
	"manifest_forged": {
		"name": "Forged Manifest", "short": "MANIFEST",
		"base": 320, "space": 2, "color": Color(0.92, 0.40, 0.48),
		"desc": "Says the hold is empty. Says it very convincingly.",
		"parent": "stolen", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 0.5,
	},
	"charge_unstable": {
		"name": "Unstable Charge", "short": "CHARGE",
		"base": 420, "space": 1, "color": Color(0.62, 1.0, 0.50),
		"desc": "Live. Reads hot to anyone scanning, and everyone out here scans.",
		"parent": "volatiles", "no_retail": true,
		"trade_only_at": ["void", "cantina", "deep_haven", "deep_watch", "deep_lantern"],
		"interdiction_weight": 3.5,
	},

	# --- phase 5: chart data --------------------------------------------------
	# What a survey is worth. The game is called Pyxis and pitched as salvage and
	# CARTOGRAPHY, and until now the second half of that was a progression gate
	# rather than a verb. This is the verb: fly out, read a landmark, carry the
	# reading home and sell it to people who will not go themselves.
	#
	# THE KEY IS `chart_band`, NOT `band`, and that is load-bearing rather than
	# cosmetic. `is_salvage()` is literally `has("band")` and `salvage_for_band()`
	# returns the FIRST good matching a band — so a chart good carrying `band`
	# could shadow a salvage grade in dictionary order, at which point
	# spawn_loot's 22% regrade would start minting free chart data out of ordinary
	# combat crates, everywhere in the game.
	#
	# Weight 0.5, NOT 0. Weightless data reads well as fiction and is a trap: a
	# pure explorer's weighted hold would never cross RAID_MIN_HOLD, making the
	# whole interdiction system inert for an entire playstyle and voiding 17's
	# "there is no range at which a full hold is safe". At 0.5 — the Forged
	# Manifest's own number — an explorer is quiet, not invisible.
	"chart_shoal": {
		"name": "Shoal Survey", "short": "CHT-S",
		"base": 80, "space": 1, "color": Color(0.58, 0.82, 0.92),
		"desc": "Bearings and masses, one band out. Somebody will want them eventually.",
		"chart_band": 1, "no_retail": true, "interdiction_weight": 0.5,
	},
	"chart_drift": {
		"name": "Drift Survey", "short": "CHT-D",
		"base": 140, "space": 1, "color": Color(0.54, 0.74, 0.98),
		"desc": "Nobody has swept this lane in a long time. Now somebody has.",
		"chart_band": 2, "no_retail": true, "interdiction_weight": 0.5,
	},
	"chart_reaches": {
		"name": "Reaches Survey", "short": "CHT-R",
		"base": 210, "space": 1, "color": Color(0.66, 0.62, 1.0),
		"desc": "Past where the beacons answer. The readings are yours alone.",
		"chart_band": 3, "no_retail": true, "interdiction_weight": 0.5,
	},
	"chart_quiet": {
		"name": "Quiet Survey", "short": "CHT-Q",
		"base": 300, "space": 1, "color": Color(0.88, 0.74, 1.0),
		"desc": "A place with a shape, and no name, and no record of anyone else.",
		"chart_band": 4, "no_retail": true, "interdiction_weight": 0.5,
	},
	# The frontier's two, on `chart_band` for the reason written above -- a `band`
	# key here would let spawn_loot's regrade mint survey data out of combat
	# crates. Steps of +110 and +130 continue +60/+70/+90.
	"chart_fathom": {
		"name": "Fathom Survey", "short": "CHT-F",
		"base": 410, "space": 1, "color": Color(0.60, 0.84, 0.98),
		"desc": "Depths, taken by a ship that was there. Nobody has these.",
		"chart_band": 5, "no_retail": true, "interdiction_weight": 0.5,
	},
	"chart_unsounded": {
		"name": "Unsounded Survey", "short": "CHT-U",
		"base": 540, "space": 1, "color": Color(0.62, 0.94, 0.68),
		"desc": "A sounding where the line never found bottom. It is still a reading.",
		"chart_band": 6, "no_retail": true, "interdiction_weight": 0.5,
	},

	# --- v14 ore: metals and minerals ----------------------------------------
	# THE MARKER KEY IS `ore`, NEVER `band`, for exactly the reason written above
	# the chart goods: is_salvage() is has("band") and salvage_for_band() takes
	# the FIRST dict-order match, so an ore carrying `band` would shadow a
	# salvage grade and Main.spawn_loot's 22% regrade would start minting ore out
	# of ordinary combat crates -- and, worse, feed ARCHEOLOGY off it. `ore` is
	# also a String rather than an int, so the two cannot be confused by a reader
	# or by a get() with the wrong default.
	#
	# ONE STEP. A seam yields the finished tradeable directly; there is no raw
	# ore and no refinery. A second inventory layer would be a second budget, and
	# 9 rule 1 allows exactly one.
	#
	# Priced BETWEEN the existing goods and every one of them under Intact Relics
	# (260). This is bulk industry, not treasure: the deep pays a prospector in
	# volume and density, never in one fat unit. The order below is the price
	# ladder, alternating mineral and metal so neither category is the rich one.
	#
	# interdiction_weight runs 0.7 -> 1.3 and is never 0 (17's weightless-data
	# trap): gravel genuinely is not worth stopping for, and a hold of Platinum
	# Sponge is exactly what a raider wants. That gradient puts 19's "the most
	# valuable haul is the most dangerous to carry" into a new loop with no new
	# mechanic.
	"ore_silicate": {
		"name": "Silicate Gravel", "short": "SILICA",
		"base": 60, "space": 2, "color": Color(0.68, 0.64, 0.56),
		"desc": "Crushed rock with just enough glass in it to be worth the cut.",
		"ore": "mineral", "interdiction_weight": 0.7,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_ferrite": {
		"name": "Ferrite Ingots", "short": "FERRITE",
		"base": 70, "space": 2, "color": Color(0.58, 0.62, 0.66),
		"desc": "Cut, cooled and stacked. Every yard on the chart takes these.",
		"ore": "metal", "interdiction_weight": 0.7,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_hydrate": {
		"name": "Hydrate Ice", "short": "HYDRATE",
		"base": 95, "space": 2, "color": Color(0.56, 0.84, 0.86),
		"desc": "Volatiles locked in rock. Warm it and it stops being cargo.",
		"ore": "mineral", "interdiction_weight": 0.8,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_tungsten": {
		"name": "Tungsten Billets", "short": "TUNGSTEN",
		"base": 110, "space": 2, "color": Color(0.44, 0.52, 0.60),
		"desc": "Dense enough that the hold notices. So does anything scanning it.",
		"ore": "metal", "interdiction_weight": 0.8,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_phosphor": {
		"name": "Phosphor Salts", "short": "PHOSPHOR",
		"base": 150, "space": 1, "color": Color(0.86, 0.72, 0.40),
		"desc": "Glows faintly in the dark of the hold. The crew stops noticing.",
		"ore": "mineral", "interdiction_weight": 1.1,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_platinum": {
		"name": "Platinum Sponge", "short": "PLATINUM",
		"base": 175, "space": 1, "color": Color(0.88, 0.90, 0.94),
		"desc": "Porous, grey, and worth more than the ship that carries it.",
		"ore": "metal", "interdiction_weight": 1.1,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_corundum": {
		"name": "Corundum Rough", "short": "CORUNDUM",
		"base": 220, "space": 1, "color": Color(0.80, 0.52, 0.74),
		"desc": "Uncut and unsorted. Somebody downstream decides what it becomes.",
		"ore": "mineral", "interdiction_weight": 1.3,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_iridium": {
		"name": "Iridium Matte", "short": "IRIDIUM",
		"base": 240, "space": 1, "color": Color(0.74, 0.70, 0.60),
		"desc": "Smelted where it was found, by whoever found it first.",
		"ore": "metal", "interdiction_weight": 1.3,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	# v20 THE FRONTIER: one mineral and one metal, in that order, because Iridium
	# above is a metal and the header's alternation rule is what keeps either
	# category from becoming the rich one.
	#
	# 248 AND 256, NOT 290 AND 330. The first draft priced them at 290/330 and
	# broke the ceiling stated at the top of this very block — "every one of them
	# under Intact Relics (260)... the deep pays a prospector in volume and
	# density, never in one fat unit." Nothing caught it, because BOTH of
	# MINETEST's gradient sweeps were written `for band in range(0, 5)` and could
	# not see bands 5 or 6 at all; they are derived now. A comment is a claim, and
	# this one had been true for four bands.
	#
	# The frontier still pays more per cut than the Quiet — 1447 against 981 —
	# and it does it the way the header says it should, through SEAM_UNITS 6 and
	# SEAM_CHANCE 0.56, which is volume and density rather than one fat unit.
	"ore_vitrite": {
		"name": "Vitrite Shards", "short": "VITRITE",
		"base": 248, "space": 1, "color": Color(0.56, 0.86, 0.80),
		"desc": "Glass that formed under pressure nobody has measured.",
		"ore": "mineral", "interdiction_weight": 1.5,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
	"ore_osmium": {
		"name": "Osmium Grit", "short": "OSMIUM",
		"base": 256, "space": 1, "color": Color(0.62, 0.68, 0.78),
		"desc": "Heavier than it has any business being. The hold notices.",
		"ore": "metal", "interdiction_weight": 1.5,
		"trade_only_at": ["anchor", "cinderworks", "depot", "bastion"],
	},
}

# What a seam of each band can hold. The depth axis lives in a TABLE, mirroring
# READS_AS, rather than in a second marker key on each good -- so `ore` stays the
# one new field and nothing has to be kept in sync with it.
#
# Every band carries at least one metal and one mineral, so neither category is
# a band you have to reach before you can see it. Mean seam value climbs
# 130 / 195 / 425 / 530 / 981 across the bands, which is the anti-farm gradient:
# the expanse resets on a warp, and the band you can reach in one warp is the
# band that pays worst. Band 0 is the charted systems and is poorest of all,
# because it is the only band that never resets.
const SEAM_YIELDS := {
	# BAND 0 IS THE CHARTED SYSTEMS, and it exists because stage 4 puts a seam on
	# each of the eleven authored asteroids. Two units of the two cheapest ores --
	# ~130 a seam against band 1's 195 -- so the outward gradient still holds at
	# its most reachable rung, and the whole charted supply across a playthrough
	# (~1,430) stays a windfall rather than an income. Asserted by CHARTED SEAMS
	# ARE A WINDFALL; the gradient is asserted by RICHER OUTWARD, which starts at
	# band 0 for exactly this reason.
	#
	# Charted seams are never ROLLED: seams_for() early-returns on band <= 0 and
	# SEAM_CHANCE[0] stays 0.0. They are placed from authored data by
	# SystemBuilder, because they persist and therefore need stable indices.
	0: ["ore_silicate", "ore_ferrite"],
	1: ["ore_ferrite", "ore_silicate"],
	2: ["ore_ferrite", "ore_tungsten", "ore_hydrate", "ore_phosphor"],
	3: ["ore_tungsten", "ore_hydrate", "ore_platinum", "ore_phosphor"],
	4: ["ore_platinum", "ore_iridium", "ore_phosphor", "ore_corundum"],
	# The frontier's rows. Means of 222.75 and 241 against band 4's 163.75, which
	# is what keeps RICHER OUTWARD strictly rising once SEAM_UNITS is folded in:
	# 981 -> 1337 -> 1446 per seam. Each row carries at least one metal and one
	# mineral, the contract every row above holds to.
	5: ["ore_iridium", "ore_osmium", "ore_corundum", "ore_platinum"],
	6: ["ore_osmium", "ore_vitrite", "ore_iridium", "ore_corundum"],
}

# What each grade of salvage can be READ AS. The player picks from this list —
# there is no roll anywhere in the conversion, and that is deliberate. 12 says
# the Cantina wager prints its odds "because a hidden bad bet is a con"; a paid
# random reveal is disqualified by the game's own standard. Choosing also makes a
# run plannable ("three servos means three Drift Salvage"), which is 9's
# legibility rule applied to loot instead of to fitting.
const READS_AS := {
	"salvage_charted": ["plate_ablative", "cell_fuel"],
	# v27 (§110). manifest ADDED here, and it is the whole fix for a recipe that
	# could not be planned. mod_baffle wants MANIFEST x1 + PLATE x2; manifest fell
	# from the Reaches ONLY and plate from the Charted and the Shoals ONLY, so no
	# single band in the game yielded both and nothing anywhere said so. The
	# Shoals now do. Every other recipe already had exactly one such band -- sink
	# at 2, survey at 3, resonance at 4 -- so this makes the set a ladder rather
	# than a set with one hole in it.
	#
	# Checked against both laws before it shipped, and neither number moved:
	# READING PAYS' worst margin is still SHOAL at +55 (manifest at 320 is not
	# the cheapest read of a Shoal crate, plate at 150 is), and the ceiling stays
	# monotone outward -- band 1's best read goes 300 -> 320 against band 2's 480.
	"salvage_shoal": ["plate_ablative", "cell_fuel", "rod_decay", "manifest_forged"],
	"salvage_drift": ["rod_decay", "sink_thermal", "lattice_data", "servo_prewar"],
	# v27 (§110). sink ADDED. It fell from the Drift ONLY -- the single narrowest
	# window in the table, and the one a playtest reported as "never drops". This
	# does not fix a recipe (band 2 already yields sink AND rod together); it
	# widens a supply that was one grade wide, OUTWARD, which is the safe
	# direction. Cheapest read of a Reaches crate is still manifest at 320.
	"salvage_reaches": ["lattice_data", "servo_prewar", "index_cartographic",
		"manifest_forged", "sink_thermal"],
	"salvage_quiet": ["index_cartographic", "heart_reliquary", "charge_unstable", "servo_prewar"],
	# THE FRONTIER'S LISTS ARE SHORT ON PURPOSE, and the first draft of them was
	# wrong in a way worth recording. It read
	#
	#   fathom:    [heart, charge, index, servo]     raw 480, cheapest read 420
	#   unsounded: [heart, index, charge]            raw 660, cheapest read 420
	#
	# with a comment claiming "at 480 and 660 a crate is already worth carrying
	# home unread" — which is not a justification, it is the broken rule written
	# out as if it were a feature. READING PAYS says the CHEAPEST thing a grade
	# reads into must beat selling it unread, because the alternative is a menu
	# where some entries lose the player money and nothing on screen says which.
	# Reading an Unsounded crate as an Unstable Charge lost 240.
	#
	# Every option in both lists now clears its own grade with room: the Fathoms
	# read at 560 or 700 against a raw 480, the Unsounded at 700 or 900 against
	# 620. Two honest choices each, which is what this table is for.
	# The Fathoms reaches the Lens too, and the two grades are told apart by their
	# FLOOR rather than by their ceiling: the cheapest honest read of a Fathom
	# crate is 560 and of an Unsounded one is 700. Both clear their own raw price
	# by exactly 80. That is what going deeper buys here — not a part nobody else
	# can reach, but a worse case that is better.
	"salvage_fathom": ["index_cartographic", "heart_reliquary", "lens_unsounded"],
	"salvage_unsounded": ["heart_reliquary", "lens_unsounded"],
}

# How often a crate that would have held a good holds unidentified salvage
# instead. Applied once, at Main.spawn_loot, which every drop in the game passes
# through.
const SALVAGE_CHANCE := 0.22

# What each activity yields. Combat feeds the market: every kind of fight
# produces something some port wants.
const DROPS := {
	"sentry": {"good": "alloys", "chance": 0.28, "count": 1},
	"swarm": {"good": "volatiles", "chance": 0.16, "count": 1},
}


static func get_good(id: String) -> Dictionary:
	return GOODS.get(id, {})


static func exists(id: String) -> bool:
	return GOODS.has(id)


static func ids() -> Array:
	return GOODS.keys()


static func base_price(id: String) -> int:
	return int(get_good(id).get("base", 0))


static func space_of(id: String) -> int:
	return int(get_good(id).get("space", 1))


static func display(id: String) -> String:
	return String(get_good(id).get("name", id))


static func short_name(id: String) -> String:
	return String(get_good(id).get("short", id.to_upper()))


static func color_of(id: String) -> Color:
	return get_good(id).get("color", Palette.GOLD)


static func interdiction_weight(id: String) -> float:
	# How much carrying this raises the odds somebody comes to take it. Ordinary
	# salvage is 1.0; the goods that are worth stealing weigh more.
	return float(get_good(id).get("interdiction_weight", 1.0))


static func band_of(id: String) -> int:
	# Which distance band this salvage grade came out of. -1 for anything that is
	# not unidentified salvage.
	return int(get_good(id).get("band", -1))


static func is_chart(id: String) -> bool:
	# Deliberately a DIFFERENT key from is_salvage's `band` — see the comment on
	# the chart goods for what sharing it would do.
	return get_good(id).has("chart_band")


static func chart_for_band(band: int) -> String:
	for id in GOODS:
		if int((GOODS[id] as Dictionary).get("chart_band", -1)) == band:
			return String(id)
	return ""


static func chart_band_of(id: String) -> int:
	# Which band this SURVEY covers. The sibling of band_of, and it reads
	# `chart_band` rather than `band` for the reason stated above the chart
	# goods: the two keys are deliberately different, and a reader that reached
	# for `band` here would come back with -1 for every chart in the game.
	return int(get_good(id).get("chart_band", -1))


static func family(id: String) -> String:
	# WHAT KIND OF THING THIS IS, in one word, derived rather than stored.
	#
	# The hold screen draws one glyph per family, because colour cannot carry it
	# — the 34 good colours were measured at a worst pair of 0.022 against the
	# 0.20 threshold ACCESSTEST holds the deep bands to, and that is in NORMAL
	# vision (see COLOUR IS NEVER THE ONLY TELL). The glyph is the primary
	# channel here, so every good must land in exactly one family.
	#
	# NOTHING IS STORED. The warning above the ore block is about adding a data
	# KEY that shadows `band` — which would let spawn_loot's regrade mint the
	# wrong good — and this answers it by adding no key at all: every branch
	# below reads a marker that is already there.
	#
	# ORDER IS LOAD-BEARING. `is_ore` is tested FIRST because all eight ores
	# carry `trade_only_at` (their four industrial buyers), so a version that
	# checked the allowlist first would file every ore beside the contraband.
	# That partition is still total and still 34, which is exactly why the
	# assertion in PYXIS_HOLDTEST names the ores rather than counting them.
	if is_ore(id):
		return ore_class(id)                  # "metal" | "mineral"
	if is_chart(id):
		return "chart"
	if is_salvage(id):
		return "salvage"
	if is_component(id):
		return "component"
	if not (get_good(id).get("trade_only_at", []) as Array).is_empty():
		return "restricted"
	return "bulk"


static func is_salvage(id: String) -> bool:
	return get_good(id).has("band")


static func is_ore(id: String) -> bool:
	return get_good(id).has("ore")


static func ore_class(id: String) -> String:
	# "metal", "mineral", or "" for everything else. The category a market tab
	# would group by.
	return String(get_good(id).get("ore", ""))


static func ore_ids() -> Array:
	var out: Array = []
	for id in GOODS:
		if GOODS[id].has("ore"):
			out.append(String(id))
	return out


static func seam_yields(band: int) -> Array:
	return SEAM_YIELDS.get(band, [])


static func is_component(id: String) -> bool:
	return get_good(id).has("parent")


static func parent_of(id: String) -> String:
	return String(get_good(id).get("parent", ""))


static func no_retail(id: String) -> bool:
	# Never buyable, anywhere. Read Market.can_buy for why this exists.
	return bool(get_good(id).get("no_retail", false))


static func salvage_for_band(band: int) -> String:
	for id in GOODS:
		if int((GOODS[id] as Dictionary).get("band", -1)) == band:
			return String(id)
	return ""


static func reads_as(salvage_id: String) -> Array:
	return READS_AS.get(salvage_id, [])


static func trades_at(id: String, port_id: String) -> bool:
	# Most goods trade everywhere. A restricted good lists its buyers, which is
	# what turns "I have contraband" into a route problem instead of a number.
	#
	# Out past the chart, nothing is restricted. Nobody there asks what is in the
	# crate, and being able to sell what you should not be carrying is the reward
	# for the trip. This branch cannot fire for a charted port id — they are the
	# ones in SystemDB and none of them start with "deep_" — so the chart's
	# restriction map, and the STATIONTEST sweep that guards it, are untouched.
	#
	# COMPONENTS ARE EXEMPT FROM THAT EXEMPTION. The deep hatch is a bypass for
	# RESTRICTION — the question "will they take this here" — and a component is
	# not restricted, it simply is not a commodity. Without this carve-out every
	# deep station's market tab would list all nine of them, which is both wrong
	# and a scroll-fest on a phone.
	var only: Array = get_good(id).get("trade_only_at", [])
	if is_component(id):
		return only.has(port_id)
	if DeepPortDB.is_deep_port(port_id):
		return true
	return only.is_empty() or only.has(port_id)


static func ids_for_port(port_id: String) -> Array:
	var out := []
	for id in GOODS:
		if trades_at(String(id), port_id):
			out.append(id)
	return out


static func roll_drop(kind: String) -> String:
	# Returns a good id, or "" for a plain salvage cube.
	var d: Dictionary = DROPS.get(kind, {})
	if d.is_empty():
		return ""
	if randf() > float(d.get("chance", 0.0)):
		return ""
	return String(d.get("good", ""))
