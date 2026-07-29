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

# --- FEEL CONSTANTS (tune these first) ---
const THREAT_RADIUS := 14.0     # a contact this close counts as "in the fight"
const FADE_IN := 1.6            # seconds to bring the combat layer up
const FADE_OUT := 3.4           # slower down: fights end raggedly, music shouldn't
const THREAT_HOLD := 3.0        # keep the combat mix this long after the last contact
const SCAN_INTERVAL := 0.25     # how often we ask the tree what is nearby
const DOCK_DUCK := 0.42         # docked is the safe state; the score steps back
const DOCK_FADE := 0.8
const BASE_DB := -14.0          # headroom: this sits under every gameplay sound

var enabled := true

var _calm: AudioStreamPlayer
var _combat: AudioStreamPlayer
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


func _make_player(stream_name: String, bus: String) -> AudioStreamPlayer:
	var path := "res://audio/%s.wav" % stream_name
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path)
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2   # 16-bit mono: two bytes per frame
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func available() -> bool:
	return _calm != null and _combat != null


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
	_calm.play()
	_combat.play()
	_apply_mix()


func stop() -> void:
	# The title screen is scored by the ambient drone alone, on purpose: arriving
	# at the menu should feel like the music has not started yet.
	if not available():
		return
	_playing = false
	_calm.stop()
	_combat.stop()


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
		fx.cutoff_hz = clampf(cutoff_hz, 300.0, 20500.0)


# --- adaptive mix -----------------------------------------------------------

func blend() -> float:
	return _blend


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
	_apply_mix()


func _apply_mix() -> void:
	# Linear amplitude crossfade, not equal-power: the two layers are the same
	# recording, so they sum coherently and equal-power would bulge in the middle.
	_calm.volume_db = _layer_db(1.0 - _blend)
	_combat.volume_db = _layer_db(_blend)


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
		if is_instance_valid(h) \
				and h.global_position.distance_squared_to(player.global_position) <= r2:
			return true
	return false
