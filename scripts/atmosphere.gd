class_name Atmosphere
extends Node
# The lighting model, as a thing that responds rather than a thing that is set.
#
# Before this the Environment was written once per system and never touched
# again: one background colour, one ambient, one glow, from boot to warp. The
# expanse changed the sky's colour by swapping a haze mesh, and threat changed
# nothing at all -- so the two axes the game is actually about, how far out you
# are and whether something is hunting you, were invisible in the light.
#
# Both are continuous, and both are eased. A band edge crossed at speed must be a
# gradient rather than a door, and a sentry waking up must not snap the room.
#
# ONE OWNER. SystemBuilder writes the system's baseline into this node once at
# build time; after that, nothing else assigns to the Environment. Two writers
# and the last one per frame wins, which is how a "fixed" lighting bug comes
# back six months later wearing different clothes.

# --- FEEL CONSTANTS ---
# Depth pulls the sky toward the cold and takes the glow down with it. THE QUIET
# is meant to be close to nothing: near-black, almost no bloom, so the few things
# still emitting out there are the only things on screen.
const DEPTH_GLOW_FLOOR := 0.42          # multiplier on the system's own glow
const DEPTH_AMBIENT_FLOOR := 0.30       # multiplier on the system's ambient
const DEPTH_SUN_FLOOR := 0.35           # the star is a long way behind you now
const DEPTH_FADE := 2.2                 # per-second approach; slower than the mix

# Threat is a LIFT, not a tint. Deep space is already a colour statement and
# stacking a red wash on top of the band gradient would fight it -- so a threat
# raises the bloom and pulls the ambient a little toward the threat hue, which
# reads as the room getting brighter and harder rather than as a warning light.
const THREAT_GLOW_LIFT := 0.30
const THREAT_AMBIENT_MIX := 0.18
const THREAT_RISE := 3.5                # fast in: this is a reaction
const THREAT_FALL := 0.9                # slow out: fights end raggedly

var _env: Environment = null
var _sun: DirectionalLight3D = null

# The system's own values, captured once. Every response is expressed as a
# multiple of these rather than as an absolute, so a system authored dim stays
# dim and one authored bright stays bright.
var _base_bg := Palette.SPACE_BG
var _base_ambient := Color(0.3, 0.35, 0.5)
var _base_ambient_energy := 0.6
var _base_glow := 0.95
var _base_sun := 0.9

var _depth := 0.0
var _depth_target := 0.0
var _threat := 0.0
var _threat_target := 0.0


func bind(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	_base_bg = env.background_color
	_base_ambient = env.ambient_light_color
	_base_ambient_energy = env.ambient_light_energy
	_base_glow = env.glow_intensity
	_base_sun = sun.light_energy if sun != null else 0.9
	# Snapped, not eased, on a fresh system: a warp arrival should open on the
	# new system's light, not ease into it from the old one's.
	_depth = _depth_target
	_threat = _threat_target
	_apply()


# THE LIGHT'S OWN ANCHORS, and they are a COPY of the first four band edges
# rather than a reference to them. That looks like duplication and it is the
# opposite: this list and DeepSpace.BAND_EDGES answer two different questions
# that happened to have the same answer until v20.
#
# set_depth reads its anchors as the knots of a normalised 0..1 ramp and divides
# by size() - 1, so the array's LENGTH sets how dark every band is. Sharing
# BAND_EDGES meant appending THE FATHOMS and THE UNSOUNDED silently re-lit the
# whole game: measured, THE QUIET at 1100u went from 1.0 (full dark, its whole
# point) to 0.6, and the Shoals and Drift brightened with it. Nothing about the
# lighting had been touched, and nobody would have looked here.
#
# The ramp SATURATES at the Quiet on purpose — the same argument the palette
# makes about DEEP_QUIET being "no colour left at all". There is nowhere darker
# to go, so the frontier is not darker, it is wrong in other ways. Adding a band
# must never again change what an existing one looks like.
const LIGHT_ANCHORS := [0.0, 160.0, 440.0, 1100.0]


func set_depth(units: float) -> void:
	# Piecewise for the same reason the music is: the bands are not evenly
	# spaced, and a linear map would spend most of the visible change inside one
	# band.
	var d := maxf(units, 0.0)
	var anchors := LIGHT_ANCHORS
	var last: float = anchors[anchors.size() - 1]
	if d >= last:
		_depth_target = 1.0
		return
	for i in range(anchors.size() - 1):
		var lo: float = anchors[i]
		var hi: float = anchors[i + 1]
		if d < hi:
			_depth_target = (float(i) + (d - lo) / maxf(hi - lo, 0.001)) / float(anchors.size() - 1)
			return


func set_threat(amount: float) -> void:
	_threat_target = clampf(amount, 0.0, 1.0)


func depth_level() -> float:
	return _depth


func threat_level() -> float:
	return _threat


func _process(delta: float) -> void:
	if _env == null:
		return
	_depth = Smoothing.toward(_depth, _depth_target, DEPTH_FADE, delta)
	_threat = Smoothing.toward_asymmetric(_threat, _threat_target, THREAT_RISE, THREAT_FALL, delta)
	_apply()


func _apply() -> void:
	if _env == null:
		return
	var d := clampf(_depth, 0.0, 1.0)
	var t := clampf(_threat, 0.0, 1.0)

	# The sky cools toward DEEP_COLD rather than toward black: black would make
	# the expanse read as "the renderer stopped" instead of as somewhere.
	_env.background_color = _base_bg.lerp(Palette.DEEP_COLD * 0.35, d * 0.8)

	var ambient := _base_ambient.lerp(Palette.DEEP_COLD, d * 0.7)
	if t > 0.0:
		ambient = ambient.lerp(Palette.THREAT, THREAT_AMBIENT_MIX * t)
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = _base_ambient_energy * lerpf(1.0, DEPTH_AMBIENT_FLOOR, d)

	# Glow falls with depth and lifts with threat, and the two compose rather
	# than one overriding the other -- being jumped in THE QUIET should still
	# brighten the room, just from a much lower floor.
	_env.glow_intensity = _base_glow * lerpf(1.0, DEPTH_GLOW_FLOOR, d) * (1.0 + THREAT_GLOW_LIFT * t)

	if _sun != null:
		_sun.light_energy = _base_sun * lerpf(1.0, DEPTH_SUN_FLOOR, d)
