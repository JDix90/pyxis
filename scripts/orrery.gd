class_name Orrery
extends Node3D
# THE ORRERY STILL RUNNING (§103, Horizon 9 commit 5). A GSA survey
# instrument, still working, holding forty years of charts nobody came for.
# It has been filing every cycle since before the order, into a survey that
# stopped collecting, and it does not know that. Hold to collect.
#
# THE ONLY PLACE IN THE GAME CHARTS ARRIVE WITHOUT BEING SURVEYED, at a scale
# a pilot cannot earn in a session: twenty units is five standard loops of
# masting (~40 minutes) delivered in one hold. Once ever — the mark spends on
# the payout, the drift's and vein's rule, because a windfall that rebuilt
# would be the deep-hulk farm at seven thousand units.
#
# IT PAYS IN `chart_unsounded`, THE REAL GOOD, and that decision is the whole
# design rather than a shortcut. The research pass recommended a distinct
# windfall id excluded from the Commission's ledger; building it found four
# reasons the catalogue refuses one, and one reason the fiction wants the
# opposite:
#
#   1. `NOT SALVAGE` asserts exactly one chart good per band edge. A seventh
#      goes red, loudly.
#   2. `chart_for_band` returns the FIRST good matching a band, and the mast
#      and the deep-station berth both mint through it. A second band-6 chart
#      would make what a mast pays depend on dictionary insertion order —
#      silent, seed-independent, and wrong.
#   3. `family()` reads `chart_band`; without one the hold screen draws forty
#      years of survey data under the BULK glyph, and `family_color` loses the
#      band tint that makes chart goods legible without colour vision.
#   4. Tolls exclude chart goods by `is_chart`. A distinct id would make an
#      orrery hold the largest toll in the game — punishing the collection
#      with a mechanic written to spare exactly this cargo.
#
# AND THE COMMISSION SHOULD HEAR ABOUT IT. Selling these moves
# `chart_data_sold`, which is what the Grand Commission counts, and that is
# the arc's thesis landing rather than a leak: the instrument logs you as the
# collecting vessel, you hand the Authority's own forty years of uncollected
# work back to an Authority counter, and the Authority thanks you for your
# contribution. The horror is that every one of those sentences is true and
# the paperwork is in order. Twenty units is five loops of credit for the
# hardest-won windfall in the game, not a pillar handed over: the size is
# what keeps it a legend instead of a shortcut, and THE ORRERY IS A WINDFALL
# pins it where a retune has to argue with it.
#
# JOINS GROUP "legend" — the shared ladder group commit 5 opens for every
# legend node that carries a verb of its own (this, and the forge and the
# procession after it). One rung in each ladder for the whole rest of the
# horizon, rather than three.

const COLLECT_GOOD := "chart_unsounded"
const COLLECT_UNITS := 20
# Long, because it is forty years of filing and because the flight home with
# a full hold of chart data is the real encounter. Between the mast's seconds
# and the archives' fourteen.
const COLLECT_TIME := 8.0
const COLLECT_RANGE := 14.0
const DECAY_RATE := 0.5

const PLATE_SENDER := "COLLECTION ACKNOWLEDGED"
const PLATE_BODY := "YOUR CARRIER IS LOGGED AS THE COLLECTING VESSEL. THE SURVEY THANKS YOU FOR YOUR CONTRIBUTION."

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

var _holding := false
var _progress := 0.0
var _t := 0.0
var _rings: Array = []


func _ready() -> void:
	add_to_group("legend")
	_build_mesh()


func _build_mesh() -> void:
	# An armillary, turning. Three rings on different axes at different rates:
	# the one silhouette in the deep that is unmistakably STILL WORKING, which
	# is the whole of what the mark says about it.
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.2
	core.mesh = sm
	core.material_override = Palette.emissive(FactionDB.tint_of("gsa"), 1.6)
	add_child(core)
	for i in range(3):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var r := 4.0 + 2.2 * float(i)
		tm.inner_radius = r - 0.16
		tm.outer_radius = r + 0.16
		tm.ring_segments = 72
		ring.mesh = tm
		ring.rotation_degrees = Vector3(78.0 * float(i), 34.0 * float(i), 0.0)
		# Authority teal, in perfect working order. The Standing Order's paint,
		# and the same horror one shelf quieter: somebody's budget line still
		# covers this, and nobody has ever come for what it makes.
		ring.material_override = Palette.emissive(FactionDB.tint_of("gsa"), 0.9)
		add_child(ring)
		_rings.append(ring)


func _process(delta: float) -> void:
	_t += delta
	# Different rates, none of them fast. An instrument keeping time nobody is
	# reading. reduce_motion is honoured the way the lattice's deleted spin
	# taught: motion that carries meaning stays, but it stays SLOW.
	for i in range(_rings.size()):
		var ring := _rings[i] as Node3D
		ring.rotate_y(delta * (0.12 + 0.05 * float(i)))
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()


func pick_anchor() -> Vector3:
	return global_position


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= COLLECT_RANGE


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(COLLECT_RANGE * 0.6, 0.0, 0.0))


func on_tapped() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	FX.ring_pulse(get_parent(), pick_anchor(), FactionDB.tint_of("gsa"), 3.0, 0.8)
	if hud:
		# Names the verb AND the price of taking it, because twenty units is
		# most of a starter hold and a pilot deserves to know before they fly
		# in rather than at the refusal.
		hud.prompt("THE ORRERY — STILL FILING. HOLD TO COLLECT %d UNITS OF SURVEY DATA." % COLLECT_UNITS)
	if not _player_in_range():
		_approach()


func hold_begin() -> void:
	if not _player_in_range():
		_approach()
		return
	_holding = true


func hold_release() -> void:
	_holding = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _progress < 1.0:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if not _holding:
		return
	if not _player_in_range():
		hold_release()
		return
	_progress += delta / COLLECT_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_collect()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "COLLECTING THE FILE")


func _collect() -> void:
	# ALL OR NOTHING, AND IT DEFERS. The mast's rule and the Stillness',
	# hardest here: twenty units is most of a starter hold, so a pilot who
	# arrives full is the ORDINARY case rather than the edge one. The mark
	# stays unspent, the instrument keeps filing, and they can come back with
	# room — which is exactly what an instrument that has waited forty years
	# would do about it.
	var hud := get_tree().get_first_node_in_group("hud")
	if not GameState.can_load(COLLECT_GOOD, COLLECT_UNITS):
		_holding = false
		_progress = 0.0
		if hud:
			hud.crack_progress(-1.0)
			hud.show_toast("NO ROOM FOR THE FILE — %d UNITS, AND IT WILL KEEP" % COLLECT_UNITS,
				Palette.THREAT)
		return
	_holding = false
	_progress = 0.0
	GameState.load_cargo(COLLECT_GOOD, COLLECT_UNITS)
	GameState.note_mark_spent(owns_mark)
	if hud:
		hud.crack_progress(-1.0)
		hud.refresh_cargo()
		# The acknowledgement, in the warm shipped register, from a machine
		# that means it. Directive 9's own closing line spoken by the last
		# thing still doing the job the directive retired.
		hud.show_broadcast(PLATE_SENDER, PLATE_BODY, FactionDB.tint_of("gsa"))
	GameState.note_log("COLLECTED FORTY YEARS OF FILINGS")
	Sfx.play("equip", -5.0, 0.7)
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.GOLD, 5.0, 1.0)
