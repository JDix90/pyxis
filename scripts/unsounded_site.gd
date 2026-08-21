class_name UnsoundedSite
extends Node3D
# THE UNSOUNDED ANSWERS (v23, Horizon 7 commit 4 — §91). One authored structure
# per system past the last band edge, and the rival's wreck in band 5: the
# places that say what killed the frontier. Not a fight — §76's rule at full
# volume. The deep already has hulks, packs, traps and guards; these are graves
# with paperwork, and the reward is an ANSWER.
#
# ONE CLASS, FOUR KINDS — "the gradient is parameters, not new classes" (§17),
# SignatureSite's own pattern one shelf up:
#
#   meridian (PYX-01, past 5,200u)  THE FIRST MERIDIAN — the position datum.
#   glass    (PYX-02, past 5,200u)  THE STILL GLASS — the time datum.
#   return   (PYX-03, past 5,200u)  THE LAST RETURN — the bearing datum, and
#                                   the evacuation tender that never left.
#   wreck    (PYX-01, band 5)       the other cartographer, found.
#
# READ IN STAGES, each a long hold that pays one fragment on the broadcast
# plate plus chart_unsounded in the hold — the band-6 good that was authored
# unearnable finally has a source. Progress persists (v23): the whole point is
# that the answer accumulates across however many trips it takes.
#
# THE MULTI-EXPEDITION METER WAS CUT, deliberately, against the plan's first
# draft. A per-visit fragment cap forced revisits with no fiction behind the
# refusal — manufactured tedium of exactly the kind long-expeditions was
# deferred over. The fifteen-minute outbound flight, band-6 weather and an
# unattended hull are the gate; a player who reads all three in one heroic
# trip has earned all three.
#
# JOINS GROUP "unsounded" AND NOTHING ELSE. Not "hyper" (COLONYTEST and the
# warden sweeps iterate that group and cast), not "crackable" (the radar
# collects it, and a permanent SITE arrow pointing 5,600u out would spoil the
# expedition the silhouette design is for). Both interaction ladders pick
# "unsounded" explicitly, last — the biggest-thing-loses-contested-taps rule.

const READ_RANGE := 10.0
const READ_TIME := 14.0
const DECAY_RATE := 0.5
# Units of chart_unsounded per fragment read. A mast's reading, for a mast's
# worth of holding still somewhere much worse.
const YIELD_UNITS := 2

# Where each datum stands, as DEPTH. The three structures sit past the last
# band edge — the only place in the game you must actually fly to (§79 capped
# the jump at 4,200) — and the wreck sits in band 5, on the way: the rival
# died OUTBOUND, which is what their log says.
const DEPTHS := {
	"meridian": 5650.0, "glass": 5820.0, "return": 6040.0, "wreck": 4650.0,
}

const NAMES := {
	"meridian": "THE FIRST MERIDIAN",
	"glass": "THE STILL GLASS",
	"return": "THE LAST RETURN",
	"wreck": "A HULL IN SOMEBODY ELSE'S LIVERY",
}

# The fragments, verbatim from the reviewed draft (docs/UNSOUNDED-FRAGMENTS-
# DRAFT.md, read and approved 2026-08-19). The three FINAL ENTRY beats are the
# spine; 3-3 is the handoff that keeps the grave from being only a grave.
const FRAGMENTS := {
	"meridian": [
		"GSA DATUM STATION 0. IF YOU CAN READ THIS, YOUR POSITION IS DEFINED. EVERY CHART OF THE FRONTIER BEGINS AT THIS MARK.",
		"RESURVEY 44 FILED. DISPLACEMENT OF DATUM: 41 UNITS. A ZERO POINT THAT MOVES IS NOT AN ERROR IN THE CHART. IT IS AN ERROR IN THE IDEA OF ONE.",
		"FINAL ENTRY. THE COMMISSION ASKS WHERE THE FRONTIER IS. WE HAVE MEASURED CAREFULLY AND THE HONEST ANSWER IS: WHEN.",
	],
	"glass": [
		"GSA CHRONOMETRY VAULT. TWO CLOCKS AGREE HERE OR NOWHERE. ALL FRONTIER TIME IS THIS TIME.",
		"THE DEEP RUNS SLOW. NOT THE CLOCKS — WE CHANGED THE CLOCKS. THE CONVOYS CAME BACK YOUNG, WITH MANIFESTS SIGNED BY SCHEDULES THAT HAD ALREADY EXPIRED. COMMERCE DID NOT SURVIVE THE ARITHMETIC.",
		"FINAL ENTRY. WE ARE ORDERED HOME BY A DEADLINE COMPUTED IN A TIME THIS VAULT NO LONGER KEEPS. WE HAVE DECIDED TO BE LATE.",
	],
	"return": [
		"GSA BEARING TERMINUS. ALL COURSES HOME ARE MEASURED FROM THIS PYLON. OUTBOUND ENDS HERE. EVERYTHING PAST THIS MARK IS BEARING ONLY.",
		"DIRECTIVE 9 RECEIVED. THE FRONTIER IS RECLASSIFIED UNSOUNDABLE. NO FURTHER RETURNS WILL BE LOGGED. CREWS BEYOND THE TERMINUS ARE INSTRUCTED NOT TO FILE. THE SURVEY THANKS THEM FOR THEIR CONTRIBUTION.",
		"FINAL ENTRY. THE ENGINES WERE NOT RECALLED. THE WARDENS WERE NOT STOOD DOWN. SOMEBODY DECIDED THE MACHINES DID NOT NEED TO KNOW. IF YOU ARE READING THIS, YOU CAME OUT ANYWAY — CHECK YOUR CLOCK, TRUST YOUR OWN MARKS, AND FILE A RETURN FOR US.",
	],
	# "Four hundred cells" is SURVEY_CELL_CAP. The wreck's log and the player's
	# own store share the number on purpose — the assertion below pins it.
	"wreck": [
		"SURVEY LOG, INDEPENDENT. THE AUTHORITY SAYS THIS PLACE CANNOT BE CHARTED. I HAVE FOUR HUNDRED CELLS FILED THAT SAY OTHERWISE. IF SOMEBODY FINDS THIS — THE CHART WAS TRUE. THE CHART WAS TRUE, THE FUEL WAS SHORT.",
	],
}

# Identity, set by the spawner before add_child — every spawner's contract.
var kind := ""
var system_id := ""

var _holding := false
var _progress := 0.0
var _lamp_mat: StandardMaterial3D
var _t := 0.0


func stages_total() -> int:
	return (FRAGMENTS.get(kind, []) as Array).size()


func log_key() -> String:
	return "%s:%s" % [system_id, kind]


func stages_read() -> int:
	return GameState.deep_log_stage(log_key())


func _ready() -> void:
	add_to_group("unsounded")
	_build_mesh()


func _build_mesh() -> void:
	# A dark monolith, or a broken hull. Primitive meshes like everything else
	# here; the silhouette does the talking and the lamp does the breathing.
	if kind == "wreck":
		var hull := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.7, 0.9, 5.1)     # the player's hull, three times over,
		hull.mesh = pm                       # lying wrong
		hull.rotation_degrees = Vector3(8.0, 40.0, 168.0)
		hull.material_override = Palette.emissive(Color(0.10, 0.10, 0.12), 0.4)
		add_child(hull)
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		lamp.mesh = sm
		lamp.position = Vector3(0.0, 1.1, -1.8)
		_lamp_mat = Palette.emissive(Palette.RIVAL, 1.6)
		lamp.material_override = _lamp_mat
		add_child(lamp)
		return
	var mono := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 64.0, 7.0)
	mono.mesh = bm
	mono.position.y = 18.0
	mono.material_override = Palette.emissive(Color(0.05, 0.05, 0.07), 0.35)
	add_child(mono)
	var band_lamp := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(7.4, 1.0, 7.4)
	band_lamp.mesh = lb
	band_lamp.position.y = 40.0
	_lamp_mat = Palette.emissive(Palette.band_color(DeepSpace.BAND_NAMES.size() - 1), 1.2)
	band_lamp.material_override = _lamp_mat
	add_child(band_lamp)


func _process(delta: float) -> void:
	_t += delta
	if _lamp_mat:
		# Read out, the lamp settles; unread, it breathes very slowly — furniture
		# that has waited a long time and is not excited to see you.
		_lamp_mat.emission_energy_multiplier = 0.8 if stages_read() >= stages_total() \
			else 0.9 + sin(_t * 0.45) * 0.5
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()


func pick_anchor() -> Vector3:
	return global_position + Vector3(0, 2.0, 0)


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= READ_RANGE


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(READ_RANGE * 0.6, 0.0, 0.0))


func on_tapped() -> void:
	# Every branch answers — the monument lesson of §88, applied on the day the
	# class is born instead of a playtest later.
	var hud := get_tree().get_first_node_in_group("hud")
	FX.ring_pulse(get_parent(), pick_anchor(),
		Palette.RIVAL if kind == "wreck" else Palette.band_color(DeepSpace.BAND_NAMES.size() - 1),
		3.0, 0.8)
	if hud:
		if stages_read() >= stages_total():
			hud.prompt("%s — THE RECORD IS YOURS. NOTHING MORE IS WRITTEN HERE." % NAMES.get(kind, "?"))
		else:
			hud.prompt("%s — %d OF %d FRAGMENTS READ. HOLD TO READ." % [
				NAMES.get(kind, "?"), stages_read(), stages_total()])
	if not _player_in_range():
		_approach()


func hold_begin() -> void:
	if stages_read() >= stages_total():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.prompt("%s — THE RECORD IS YOURS. NOTHING MORE IS WRITTEN HERE." % NAMES.get(kind, "?"))
		return
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
	_progress += delta / READ_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_read()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "READING THE ARCHIVE")


func _read() -> void:
	# THE HOLD DEFERS ON A FULL HOLD, the mast's own guard: a read that paid
	# nothing because the cargo bounced would burn a persisted stage on a
	# player who just needed to dump two units.
	var hud := get_tree().get_first_node_in_group("hud")
	if not GameState.can_load("chart_unsounded", YIELD_UNITS):
		_holding = false
		_progress = 0.0
		if hud:
			hud.crack_progress(-1.0)
			hud.show_toast("NO ROOM FOR THE READING", Palette.THREAT)
		return
	var before := stages_read()
	# §92. WHETHER THE PILOT KNEW BEFORE THIS HOLD. Asked as a flag rather
	# than as "is this the return record's second fragment", so the ship answers
	# whichever record turns out to carry the order -- the accessor scans the
	# data and this reads the accessor, with no third place to edit.
	var knew := GameState.knows_directive_9()
	var stage := GameState.note_deep_log(log_key(), stages_total())
	_holding = false
	_progress = 0.0
	if stage <= 0:
		if hud:
			hud.crack_progress(-1.0)
		return
	if stage == before:
		# THE RECORD IS FINITE. A completed archive re-shows its last page and
		# pays nothing — without this branch a fourteen-second hold was two
		# units of sellable chart data forever, an income faucet out where the
		# fiction says everything has stopped. The refusal states its terms
		# (§58) by BEING the last fragment again: the archive still speaks, it
		# just has nothing new to say.
		if hud:
			hud.crack_progress(-1.0)
			var done: Array = FRAGMENTS.get(kind, [])
			hud.show_broadcast("%s — ARCHIVE COMPLETE" % NAMES.get(kind, "?"),
				String(done[stage - 1]),
				Palette.RIVAL if kind == "wreck" else Palette.band_color(DeepSpace.BAND_NAMES.size() - 1))
		return
	GameState.load_cargo("chart_unsounded", YIELD_UNITS)
	if hud:
		hud.crack_progress(-1.0)
		hud.refresh_cargo()
		# The fragment goes out on the broadcast plate — the one surface built
		# for a sender and a body, and the same voice the bands announce in.
		var frags: Array = FRAGMENTS.get(kind, [])
		hud.show_broadcast("%s — FRAGMENT %d OF %d" % [NAMES.get(kind, "?"), stage, stages_total()],
			String(frags[stage - 1]),
			Palette.RIVAL if kind == "wreck" else Palette.band_color(DeepSpace.BAND_NAMES.size() - 1))
	Sfx.play("equip", -7.0, 0.7)
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.GOLD, 4.0, 0.9)
	# THE ONE BEAT THAT IS THE PLAYER'S OWN. Reading the order changes nothing
	# in the world -- no faction turns, no marker appears, nothing out here has
	# heard. What it changes is the ship, the logbook and the file: you know,
	# and nothing else does. Fired on the TRANSITION so a pilot who comes back
	# and re-reads a finished record is not told twice.
	if not knew and GameState.knows_directive_9():
		Barks.fire("read_directive")
		GameState.note_log("READ DIRECTIVE 9 — THE RETURNS WERE REFUSED")
