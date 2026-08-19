class_name Palette
extends Object
# Pyxis design tokens: near-black space, amber cartography, gold reward,
# magenta "signal glitch" threat accent (the cyberpunk twang), teal tech accent.

const SPACE_BG := Color(0.012, 0.014, 0.022)
const AMBER := Color(0.96, 0.65, 0.14)
const AMBER_DIM := Color(0.96, 0.65, 0.14, 0.28)
const GOLD := Color(1.0, 0.84, 0.35)
const THREAT := Color(1.0, 0.13, 0.45)
const TEAL := Color(0.15, 0.9, 0.85)
const HULL := Color(0.75, 0.78, 0.82)
const WHITE_HOT := Color(1.0, 0.97, 0.9)


# --- deep space bands --------------------------------------------------------
# Colour is the only band tell that reads at a glance on a phone. Each is either
# an existing token or from the same near-monochrome family, so the expanse still
# looks like this game rather than a different one.
const DEEP_DRIFT := Color(0.62, 0.42, 1.00)     # violet — not from around here
const DEEP_REACHES := Color(0.40, 1.00, 0.62)   # bile — actively wrong
const DEEP_QUIET := Color(0.92, 0.96, 1.00)     # no colour left at all
# v20 THE FRONTIER. THE QUIET is "no colour left", so the two bands past it
# cannot go on getting whiter — there is nowhere whiter to go, and the band whose
# whole idea is absence would stop being the end of anything. They come back
# WRONG instead: a cold deep blue that reads as pressure rather than distance,
# and a phosphor green that is the colour of a readout rather than of a place —
# the scan coming back at you, which is exactly what the Unsounded's guard
# designation says in words.
const DEEP_FATHOMS := Color(0.00, 0.50, 0.75)   # pressure, not distance
const DEEP_UNSOUNDED := Color(0.00, 0.70, 0.00) # a readout, not a place
const DEEP_BANDS := [AMBER, THREAT, DEEP_DRIFT, DEEP_REACHES, DEEP_QUIET,
	DEEP_FATHOMS, DEEP_UNSOUNDED]
const DEEP_COLD := Color(0.10, 0.12, 0.22)      # replaces the system's haze


# --- colour vision -----------------------------------------------------------
# The band set above is the one place in this game where colour carries
# information nothing else carries, and it is close to a worst case: amber,
# rose, violet, bile green. Under deuteranopia the amber and the bile collapse
# toward each other and so do the rose and the violet, which turns four
# distinguishable bands into two. Under protanopia the rose darkens until it
# reads as the violet. There is no arrangement of "nice" colours that survives
# all three confusion lines, so each mode gets its own set chosen to stay
# separated along the axis that mode still has.
#
# The CONSTS ABOVE ARE NEVER TOUCHED. Mode 0 returns them byte-identically --
# asserted -- so the default look cannot drift as a side effect of this feature
# existing, and every other palette token stays exactly what it always was.
enum Vision {NORMAL, DEUTAN, PROTAN, TRITAN}

const BAND_SETS := {
	# NOT chosen by eye. Each set is the best of 60,000 candidates from a grid,
	# scored by the minimum pairwise distance BETWEEN THE SIMULATED COLOURS --
	# which is the only measurement that matters, because two colours can be far
	# apart in RGB and land on top of each other on a confusion line. That is
	# precisely what happens to the shipped amber and bile green.
	#
	# Constrained to stay emissive-legible: a luminance floor of 0.30 and a peak
	# channel of at least 0.68, because these glow against a near-black sky and a
	# dark "safe" colour is a colour nobody can see at all.
	#
	# THE QUIET's entry (index 4) stays near-white in every mode. It is the band
	# with "no colour left at all", and recolouring it would win a number and lose
	# the thing the band is about. It is index 4 rather than the last entry now
	# that the frontier sits past it -- the pin is on the BAND, not on the end of
	# the array.
	#
	# Scores against PYXIS_ACCESSTEST's threshold of 0.20, with the shipped set
	# measuring 0.173 under deuteranopia -- which is the whole reason for this.
	#
	# v20 THE FRONTIER: RE-SEARCHED AT SEVEN, not appended to at five. Appending
	# was tried first and it is what the plan called for; the grid says the best
	# two colours that can be ADDED to each shipped five score 0.214 / 0.216 /
	# 0.215 -- over the 0.20 threshold, and with a seventh of the headroom these
	# sets have today. Passing a threshold by 0.014 is how a palette that "meets
	# the standard" ships unreadable, so each set was re-run whole by the same
	# method (farthest-point seed, then swap refinement, same luminance floor of
	# 0.30, same peak floor of 0.68, near-white pinned at index 4). Two more
	# colours in a space that comfortably held five costs a little separation --
	# 0.307 -> 0.283 under deuteranopia -- and that is the honest price. The
	# alternative was 0.214.
	Vision.DEUTAN: [                    # closest pair 0.283 (was 0.307 at five)
		Color(1.00, 0.30, 0.00),
		Color(0.00, 0.95, 1.00),
		Color(1.00, 1.00, 0.00),
		Color(0.00, 0.35, 1.00),
		Color(0.95, 0.97, 1.00),
		Color(0.00, 0.70, 0.10),
		Color(0.45, 1.00, 0.45),
	],
	Vision.PROTAN: [                    # closest pair 0.304 (was 0.317 at five)
		Color(1.00, 1.00, 0.00),
		Color(0.00, 0.70, 0.05),
		Color(0.05, 0.95, 1.00),
		Color(0.00, 0.35, 0.90),
		Color(0.95, 0.97, 1.00),
		Color(1.00, 0.15, 0.00),
		Color(0.90, 0.50, 0.65),
	],
	Vision.TRITAN: [                    # closest pair 0.317 (was 0.333 at five)
		Color(0.55, 0.90, 0.60),
		Color(0.00, 1.00, 1.00),
		Color(1.00, 0.80, 0.10),
		Color(1.00, 0.05, 0.00),
		Color(0.95, 0.97, 1.00),
		Color(0.00, 0.55, 0.70),
		Color(0.45, 0.70, 0.00),
	],
}

# THE REAL FIX, and the one that works in every mode including the default:
# colour stops being the only tell. Each band carries a glyph on the wayfinding
# label and on every broadcast header, so the bands are legible in greyscale, to
# a player who has turned the saturation down, and on a phone in sunlight.
# Redundancy beats remapping -- remapping only helps the modes it was tuned for.
#
# The frontier's two continue the shape rather than inventing one: ◇ is ◆ with
# the fill gone, and ∙ is what is left when even the outline goes. The arc the
# names walk (measured, then unmeasurable) is the arc the marks walk too. Both
# are checked against FAMILY_GLYPHS -- one shape must not mean two things in the
# same game -- and both are plain BMP characters, not emoji or dingbats, so the
# UI font has them.
const BAND_GLYPHS := ["", "◈", "▲", "●", "◆", "◇", "∙"]

# v22. THE OTHER CARTOGRAPHER'S ACCENT. One colour that means "somebody else's"
# the way the livery accent means "yours". Violet on purpose: it is in neither
# BAND_SETS (place) nor the livery accents (you) nor THREAT (danger), because a
# rival beacon is none of those things. Per 30 the colour is never the only
# tell -- a foreign beacon is the same SHAPE as your own, and ownership is
# carried by the refusal when you try to recover it, with the hue as the
# at-a-glance channel.
const RIVAL := Color(0.70, 0.54, 0.86)

static var vision := Vision.NORMAL


static func band_color(index: int) -> Color:
	# The one accessor. Everything that tints by band goes through here so a mode
	# change reaches all of it -- DeepSpace's dressing and broadcasts, SurveyMast's
	# dish, Rift's tear, and the HUD.
	var i := clampi(index, 0, DEEP_BANDS.size() - 1)
	if vision == Vision.NORMAL or not BAND_SETS.has(vision):
		return DEEP_BANDS[i]
	return (BAND_SETS[vision] as Array)[i]


static func band_glyph(index: int) -> String:
	return BAND_GLYPHS[clampi(index, 0, BAND_GLYPHS.size() - 1)]


# --- cargo families (save v16 / the hold screen) -----------------------------
# The same argument as BAND_GLYPHS above, arrived at from a harder measurement.
#
# The bands at least HAD a remapping worth doing: the shipped set scores 0.173
# under deuteranopia against a 0.20 threshold, and the replacements clear it.
# The 34 commodity colours cannot be rescued that way. Measured pairwise with
# ACCESSTEST's own confusion maths, their worst pair is 0.022 IN NORMAL VISION
# -- an order of magnitude past the bands' worst case -- with 212 of 561 pairs
# under the threshold, and no seven-colour subset of this game's tokens clears
# it in all four modes. Twenty-six pairs of goods share family AND bulk AND an
# indistinguishable colour.
#
# So for the hold grid the glyph is not redundancy, it is the PRIMARY channel,
# and colour is the weaker second. That is also why the grid identifies nothing
# on its own: a cell says what KIND of thing is there and how much room it eats,
# and the strip beneath it says which good in words.
#
# NONE of these may be a BAND_GLYPHS entry. The manual teaches ▲ as THE DRIFT,
# and one shape must not mean two things in the same game. Asserted.
const FAMILY_GLYPHS := {
	"bulk": "■",         # solid, plain: the five things everyone trades
	"metal": "▣",        # a filled square with a rim -- ore, refined
	"mineral": "△",      # unfilled: the other half of what a seam yields
	"salvage": "○",      # sealed. Unread, unknown, worth something
	"component": "◎",    # the same circle, opened -- what a read turns it into
	"chart": "▤",        # a ruled sheet: somebody else's survey
	"restricted": "▽",   # a hazard sign, pointed the other way from mineral
}


static func family_glyph(family: String) -> String:
	return String(FAMILY_GLYPHS.get(family, ""))


static func family_color(family: String, band := -1) -> Color:
	# Salvage and charts route through band_color and everything else does not,
	# and that is not an inconsistency to tidy up. For those two families the
	# colour MEANS which band the thing came out of, which is exactly the meaning
	# the vision remaps exist to preserve. The other five wear fixed tokens, the
	# same way every other surface in the game does.
	match family:
		"salvage", "chart":
			return band_color(band)
		"metal":
			return HULL
		"mineral":
			return TEAL
		"component":
			return GOLD
		"restricted":
			return THREAT
		_:
			return AMBER


# --- ship liveries (save v6) -------------------------------------------------
# Eight hulls and eight accents, all derived from the tokens above rather than
# invented, so a painted ship still looks like it belongs in this game. Hulls are
# matte and desaturated because the hull is the largest surface on screen and a
# saturated one fights the cartography for attention; accents are the emissive
# trim, where the colour is allowed to be loud.
const LIVERY_HULLS := [
	{"name": "SURVEY GREY", "color": Color(0.75, 0.78, 0.82)},
	{"name": "VOID BLACK", "color": Color(0.20, 0.21, 0.25)},
	{"name": "BONE", "color": Color(0.87, 0.84, 0.74)},
	{"name": "OXIDE", "color": Color(0.55, 0.30, 0.22)},
	{"name": "DEEP TEAL", "color": Color(0.20, 0.45, 0.46)},
	{"name": "INDIGO", "color": Color(0.28, 0.28, 0.48)},
	{"name": "EMBER", "color": Color(0.62, 0.36, 0.16)},
	{"name": "PLUM", "color": Color(0.40, 0.24, 0.42)},
]

const LIVERY_ACCENTS := [
	{"name": "AMBER", "color": AMBER},
	{"name": "GOLD", "color": GOLD},
	{"name": "TEAL", "color": TEAL},
	{"name": "SIGNAL", "color": THREAT},
	{"name": "ICE", "color": Color(0.62, 0.86, 1.0)},
	{"name": "LIME", "color": Color(0.55, 1.0, 0.45)},
	{"name": "VIOLET", "color": Color(0.70, 0.50, 1.0)},
	{"name": "WHITE HOT", "color": WHITE_HOT},
	# v13. The ninth accent is not for sale at any price. It is the only cosmetic
	# in the game that is EARNED -- claiming COMMISSIONED, which requires reaching
	# THE QUIET -- and it is deliberately the palest, coldest trim in the set: the
	# colour of a register entry rather than of a paint counter. See
	# GameState.REGISTRY_ACCENT, which is what both renderers gate on.
	{"name": "REGISTRY", "color": Color(0.90, 0.88, 0.70)},
]


static func livery_hull(index: int) -> Color:
	return LIVERY_HULLS[posmod(index, LIVERY_HULLS.size())]["color"]


static func livery_accent(index: int) -> Color:
	return LIVERY_ACCENTS[posmod(index, LIVERY_ACCENTS.size())]["color"]


static func emissive(color: Color, energy: float = 2.0, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func matte(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
