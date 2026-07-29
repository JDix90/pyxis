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
const DEEP_BANDS := [AMBER, THREAT, DEEP_DRIFT, DEEP_REACHES, DEEP_QUIET]
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
	# The last entry stays near-white in every mode. THE QUIET is the band with
	# "no colour left at all", and recolouring it would win a number and lose the
	# thing the band is about.
	#
	# Scores against PYXIS_ACCESSTEST's threshold of 0.20, with the shipped set
	# measuring 0.173 under deuteranopia -- which is the whole reason for this.
	Vision.DEUTAN: [                    # closest pair 0.307
		Color(0.85, 0.32, 0.15),
		Color(0.15, 0.85, 0.98),
		Color(0.85, 0.98, 0.15),
		Color(0.15, 0.32, 0.68),
		Color(0.95, 0.97, 1.00),
	],
	Vision.PROTAN: [                    # closest pair 0.317
		Color(0.98, 0.85, 0.15),
		Color(0.15, 0.85, 0.15),
		Color(0.32, 0.98, 0.85),
		Color(0.15, 0.32, 0.98),
		Color(0.95, 0.97, 1.00),
	],
	Vision.TRITAN: [                    # closest pair 0.333
		Color(0.15, 0.85, 0.15),
		Color(0.15, 0.85, 0.85),
		Color(0.85, 0.85, 0.32),
		Color(0.85, 0.15, 0.15),
		Color(0.95, 0.97, 1.00),
	],
}

# THE REAL FIX, and the one that works in every mode including the default:
# colour stops being the only tell. Each band carries a glyph on the wayfinding
# label and on every broadcast header, so the bands are legible in greyscale, to
# a player who has turned the saturation down, and on a phone in sunlight.
# Redundancy beats remapping -- remapping only helps the modes it was tuned for.
const BAND_GLYPHS := ["", "◈", "▲", "●", "◆"]

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
