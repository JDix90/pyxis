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
