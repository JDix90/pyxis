extends Node
# Autoloaded as `Music`. Adaptive two-layer score.
#
# The two tracks are not two pieces of music — they are ONE eight-bar phrase
# rendered twice, once as bare pad and once with an arpeggio and a pulse on top
# (see tools/gen_sfx.py). Both players start together and never stop, so the
# harmony is always at the same point in the bar; "going to combat" is a
# crossfade between two mixes of the same moment, never a transition between two
# cues. That is what stops the music announcing a fight a beat late, and it is
# why the generator asserts both files are the same length.
#
# Everything here is volume. No seeking, no restarting, no queueing.

const CALM := "music_calm"
const COMBAT := "music_combat"
const DEEP := "music_deep"
const QUIET := "music_quiet"

# --- FEEL CONSTANTS (tune these first) ---
const THREAT_RADIUS := 14.0     # a contact this close counts as "in the fight"
const FADE_IN := 1.6            # seconds to bring the combat layer up
const FADE_OUT := 3.4           # slower down: fights end raggedly, music shouldn't
const THREAT_HOLD := 3.0        # keep the combat mix this long after the last contact
const SCAN_INTERVAL := 0.25     # how often we ask the tree what is nearby
const DOCK_DUCK := 0.42         # docked is the safe state; the score steps back
const DOCK_FADE := 0.8
const BASE_DB := -14.0          # headroom: this sits under every gameplay sound

# --- the depth axis ---
# The score had ONE axis -- threat -- and the game's central fiction is the
# other one. Going further out changed the colour of the sky, the radar span,
# the spawn tables and the beacon text, and did not change a single thing you
# could hear. The Shoals and the Reaches sounded identical.
#
# Depth and threat are ORTHOGONAL, not a single "intensity" dial. Being jumped
# in the Reaches has to sound like being jumped, and drifting home through the
# Drift has to sound like the Drift; collapsing them into one number makes deep
# space permanently tense and shallow space permanently safe, which is a
# statement about the map rather than about what is happening.
#
# So: threat picks between calm and combat, exactly as before, and depth picks
# which BED that pair is heard over. All four stems are the same eight bars at
# the same length, started in the same frame, and never stopped -- so this is
# volume, like everything else here.
const DEPTH_ANCHORS := [0.0, 160.0, 440.0, 1100.0]
# How fast the bed follows depth. Slow: band edges are crossed at speed, and a
# mix that snapped at the boundary would turn a threshold into a door.
const DEPTH_FADE := 5.0
# The calm layer's low-pass closes as you go out, on top of the per-system tint.
# The world gets quieter and further away; the filter is what sells it.
const DEPTH_CUTOFF_NEAR := 20500.0
const DEPTH_CUTOFF_FAR := 900.0

var enabled := true

var _calm: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _deep: AudioStreamPlayer
var _quiet: AudioStreamPlayer
# 0 at the chart edge, 1 in THE QUIET. Smoothed, never stepped.
var _depth := 0.0
var _depth_target := 0.0
var _system_cutoff := 20500.0
var _blend := 0.0               # 0 = calm, 1 = combat
var _duck := 1.0
var _duck_target := 1.0
var _threat_timer := 0.0
var _scan_timer := 0.0
var _playing := false


func _ready() -> void:
	# ALWAYS: the pause menu has a music-volume slider, and a slider you cannot
	# hear move is not a slider.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.ensure_buses()
	_calm = _make_player(CALM, Sfx.BUS_MUSIC_CALM)
	_combat = _make_player(COMBAT, Sfx.BUS_MUSIC)
	# The deep bed rides the calm bus so the depth filter reaches it too; the
	# quiet bed does not, because filtering something that is already a single
	# low sine just removes it.
	_deep = _make_player(DEEP, Sfx.BUS_MUSIC_CALM)
	_quiet = _make_player(QUIET, Sfx.BUS_MUSIC)


func _make_player(stream_name: String, bus: String) -> AudioStreamPlayer:
	var path := "res://audio/%s.wav" % stream_name
	if not ResourceLoader.exists(path):
		return null
	# Loop points come from Sfx so the two layers and the ambient drone all use
	# one definition of "how long is this file". The old inline `data.size() / 2`
	# assumed uncompressed 16-bit frames while the importer writes QOA, which put
	# the loop point about a third of the way in. PYXIS_MUSICTEST's LOOP ALIGN
	# check compares the layers to each other, so it stayed green throughout.
	var stream: AudioStream = Sfx.loopify(load(path))
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func available() -> bool:
	return _calm != null and _combat != null and _deep != null and _quiet != null


# --- transport --------------------------------------------------------------

func play() -> void:
	# Both layers start in the same frame. If they ever drift apart the whole
	# design collapses into two songs fighting each other.
	if not available() or _playing:
		return
	_playing = true
	_blend = 0.0
	_duck = 1.0
	_duck_target = 1.0
	_threat_timer = 0.0
	_depth = 0.0
	_depth_target = 0.0
	# All four in the same frame. Nothing is ever started late, because a player
	# begun mid-phrase would need seeking to line up and seeking is the one thing
	# this design does not do.
	_calm.play()
	_combat.play()
	_deep.play()
	_quiet.play()
	_apply_mix()


func stop() -> void:
	# The title screen is scored by the ambient drone alone, on purpose: arriving
	# at the menu should feel like the music has not started yet.
	if not available():
		return
	_playing = false
	_calm.stop()
	_combat.stop()
	_deep.stop()
	_quiet.stop()


func is_playing() -> bool:
	return _playing


func set_docked(v: bool) -> void:
	_duck_target = DOCK_DUCK if v else 1.0


func set_system_tint(cutoff_hz: float) -> void:
	# Per-system colour, applied to the calm layer only. Muffling the combat
	# layer too would take the bite out of exactly the moment that needs it.
	var idx := AudioServer.get_bus_index(Sfx.BUS_MUSIC_CALM)
	if idx < 0 or AudioServer.get_bus_effect_count(idx) == 0:
		return
	var fx := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if fx:
		# Remembered rather than written and forgotten: depth closes the same
		# filter, and the two have to combine instead of overwriting each other.
		# The system tint is the CEILING, so a naturally muffled system cannot be
		# made brighter by flying home.
		_system_cutoff = clampf(cutoff_hz, 300.0, 20500.0)
		fx.cutoff_hz = _system_cutoff


# --- adaptive mix -----------------------------------------------------------

func blend() -> float:
	return _blend


func depth_blend() -> float:
	# 0 at the chart edge, 1 in THE QUIET. Read by PYXIS_MUSICTEST, which cannot
	# hear anything.
	return _depth


func set_depth(units: float) -> void:
	# Called from main's depth poll. Piecewise across the band anchors rather
	# than linear across the whole range: the bands are not evenly spaced (0,
	# 160, 440, 1100), so a linear map would put three quarters of the audible
	# change inside THE REACHES and leave the first two bands sounding the same.
	var d := maxf(units, 0.0)
	var last: float = DEPTH_ANCHORS[DEPTH_ANCHORS.size() - 1]
	if d >= last:
		_depth_target = 1.0
		return
	for i in range(DEPTH_ANCHORS.size() - 1):
		var lo: float = DEPTH_ANCHORS[i]
		var hi: float = DEPTH_ANCHORS[i + 1]
		if d < hi:
			var within: float = (d - lo) / maxf(hi - lo, 0.001)
			_depth_target = (float(i) + within) / float(DEPTH_ANCHORS.size() - 1)
			return


func _process(delta: float) -> void:
	if not _playing or not available():
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		if _threat_present():
			_threat_timer = THREAT_HOLD
	_threat_timer = maxf(_threat_timer - delta, 0.0)

	# Asymmetric on purpose: combat arrives fast enough to feel like a reaction,
	# and leaves slowly enough that clearing the last contact of a wave does not
	# snap the room back to silence.
	var want := 1.0 if _threat_timer > 0.0 else 0.0
	var rate := (1.0 / FADE_IN) if want > _blend else (1.0 / FADE_OUT)
	_blend = move_toward(_blend, want, rate * delta)
	_duck = move_toward(_duck, _duck_target, (1.0 / DOCK_FADE) * delta)
	_depth = Smoothing.toward(_depth, _depth_target, DEPTH_FADE, delta)
	_apply_mix()


func _apply_mix() -> void:
	# Linear amplitude crossfade, not equal-power: the layers are the same
	# recording, so they sum coherently and equal-power would bulge in the middle.
	#
	# Two independent axes. `_blend` splits the mix between the calm pair and the
	# combat layer; `_depth` splits the CALM half between the near bed, the deep
	# bed and the quiet one. Combat is never attenuated by depth -- being jumped
	# in THE QUIET has to sound like being jumped, and a fight scored by a single
	# low sine is a fight the player cannot hear coming.
	var calm_share := 1.0 - _blend
	# Triangular weights across three beds: near is loudest at 0, deep peaks in
	# the middle bands, quiet takes over at the end.
	var near := clampf(1.0 - _depth * 2.0, 0.0, 1.0)
	var far := clampf((_depth - 0.5) * 2.0, 0.0, 1.0)
	var mid := clampf(1.0 - absf(_depth - 0.5) * 2.0, 0.0, 1.0)
	_calm.volume_db = _layer_db(calm_share * near)
	_deep.volume_db = _layer_db(calm_share * mid)
	_quiet.volume_db = _layer_db(calm_share * far)
	_combat.volume_db = _layer_db(_blend)
	_apply_depth_filter()


func _apply_depth_filter() -> void:
	# Depth closes the calm bus's low-pass, under the per-system tint. One filter,
	# one owner: set_system_tint records the ceiling and this is the only place
	# that writes to it.
	var idx := AudioServer.get_bus_index(Sfx.BUS_MUSIC_CALM)
	if idx < 0 or AudioServer.get_bus_effect_count(idx) == 0:
		return
	var fx := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if fx == null:
		return
	var want := lerpf(DEPTH_CUTOFF_NEAR, DEPTH_CUTOFF_FAR, clampf(_depth, 0.0, 1.0))
	fx.cutoff_hz = minf(want, _system_cutoff)


func _layer_db(amount: float) -> float:
	var a := clampf(amount, 0.0, 1.0) * _duck
	if a <= 0.001:
		return -80.0
	return BASE_DB + linear_to_db(a)


func _threat_present() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var main := tree.get_first_node_in_group("main")
	if main != null and bool(main.get("boss_active")):
		return true
	var player: Node3D = tree.get_first_node_in_group("player")
	if player == null:
		return false
	# Docked is the one place nothing hunts you, so nothing there is a threat
	# however close it parks.
	if bool(player.get("docked")):
		return false
	var r2 := THREAT_RADIUS * THREAT_RADIUS
	for n in tree.get_nodes_in_group("hostiles"):
		var h := n as Node3D
		# A flag that is not hunting you is not a threat, however close it
		# passes. Flying alongside a neutral convoy used to raise the combat
		# layer, which told the player they were in a fight nobody was having.
		if is_instance_valid(h) and GameState.hostile_to_player(h) \
				and h.global_position.distance_squared_to(player.global_position) <= r2:
			return true
	return false
