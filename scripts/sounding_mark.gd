class_name SoundingMark
extends Node3D
# THE NETWORK'S BUOYS (Horizon 9 commit 2 — §98). Five per system standing
# 6,500–9,000u out, past every archive, where the FarMarks generator says they
# stand. A mark is a plate: it records what the network sounded in this volume
# and nothing else, which is why it can ship a whole horizon before the things
# it names are built.
#
# EVERYONE SEES A MARK; ONLY A FILER CAN READ ONE. The notation is the
# network's own, and a pilot who has never clipped a return to somebody else's
# mast cannot read it — but the mark ANSWERS the tap and says so, and says what
# would change it (§58). A thing you can see and never touch with no word about
# why is §88's monument problem, and the refusal is also the teaching: the only
# way to learn that filing buys literacy is to stand in front of something you
# cannot read.
#
# THE MARK IS NOT THE LEGEND. Reading it resolves it and shows the plate; the
# encounter each plate names is commits 3–5, and it will stand at this same
# position. The plate is written in the past tense on purpose — it is a record
# of a sounding, so it is true the day it ships and still true the day the
# thing it describes is built. Nothing here needs rewriting later.
#
# PAYS NOTHING, EVER. Not one unit, not one credit. The legends are windfalls
# (the horizon's own economy rule) and a signpost that paid would turn fifteen
# buoys into a milk round — the exact "second salary" the horizon document
# refuses by name.
#
# JOINS GROUP "farmark" AND NOTHING ELSE. Not "crackable" (the radar would hang
# a permanent arrow on a thing whose whole design is that you fly a bearing to
# it), not "hyper" (COLONYTEST casts that group to HyperStructure), not
# "unsounded" (both ladders pick that one explicitly and the archives are a
# different verb). Both interaction ladders pick "farmark" last, the
# biggest-thing-loses-contested-taps rule.

# The tallest axis of the silhouette, and it is deliberately a fortieth of the
# hyper structure's. THAT number (140u, readable at ~1000u) is what a blind
# sweep of a 2,600u annulus costs. A mark is not found by sweeping: the channel
# QUOTES a bearing and a range for it, so what the silhouette has to beat is
# the error in the quote — the keep-out nudge below is bounded at 204u, so a
# lamp readable at ~400u is read from inside the quote's own error.
const SILHOUETTE_SPAN := 40.0
# How near to read. A mast's range, not an archive's: you come alongside a buoy.
const READ_RANGE := 12.0
# A plate, not an archive. UnsoundedSite holds for fourteen seconds because it
# is paying out a fragment of a record; this is one page and it is free.
const READ_TIME := 3.0
const DECAY_RATE := 0.5


# §111. FILING's two tiers, and neither of them touches what a plate SAYS. The
# kind is revealed by the reading and never before it -- that is the rule this
# file states about itself, and the whole reason reading a mark is worth doing.
# What a filer's hand earns is the same reading, sooner and from further out.
func read_seconds() -> float:
	if GameState.skill_tier("filing") >= GameState.FILING_QUICK_TIER:
		return READ_TIME * (1.0 - GameState.FILING_QUICK_BONUS)
	return READ_TIME


func read_range() -> float:
	if GameState.skill_tier("filing") >= GameState.FILING_REACH_TIER:
		return READ_RANGE * GameState.FILING_REACH_MULT
	return READ_RANGE

# WHAT THE NETWORK CALLS EACH OF THEM, revealed by the reading and never
# before it: an unread mark is "A SOUNDING MARK" to everybody, because the kind
# is precisely what the notation tells you. Keys are FarMarks.kinds() and the
# harness pins the two sets together rather than trusting this comment.
const NAMES := {
	"vein": "THE VEIN",
	"layup": "THE LAYUP",
	"drift": "THE PROVING DRIFT",
	"stillness": "THE STILLNESS' GROUND",
	"order": "THE STANDING ORDER",
	"serpent": "THE SOUNDING SERPENT",
	"orrery": "THE ORRERY STILL RUNNING",
	"nursery": "THE TALLY'S NURSERY",
	"forge": "THE PATTERN FORGE",
	"procession": "THE PROCESSION'S END",
}

# THE PLATES, verbatim from the reviewed draft (docs/FAR-MARKS-DRAFT.md, second
# draft, read and approved). The marks are HONEST — the network does not lie to
# its own people — and where there is horror the horror is that honesty out
# here is frightening enough. Register rule (§92, restated by the player): a
# line must be understandable on first read, and eerie by what it MEANS rather
# than by being hard to parse. These are the furthest-out copy in the game and
# they are still plain sentences.
const PLATES := {
	"vein": "MARK: DEEP LODE. THE VEIN RUNS RICHER THAN ANYTHING ON THE CHARTED SIDE AND IT HAS NO BOTTOM THAT WE FOUND. BRING A TORCH AND WATCH THE WEATHER.",
	"layup": "MARK: LAYUP. STORES CACHED BY CREWS WHO DID NOT ALL COME BACK FOR THEM. TAKE WHAT YOU NEED. LEAVE WHAT YOU CAN. IT HAS ALWAYS WORKED THAT WAY.",
	"drift": "MARK: PROVING DRIFT. A WORKSHOP HULL. THEY WERE BUILDING PAST THE CATALOGUE BECAUSE NOBODY OUT HERE IS SELLING THEM ANYTHING. SOME OF IT WORKS.",
	"stillness": "MARK: STANDING WARNING. IT PASSES HERE. IF YOUR DRIVES GO QUIET, THEY WILL COME BACK. DO NOT BURN. DO NOT TRANSMIT. WAIT.",
	"order": "MARK: HAZARD, PERMANENT. AN AUTHORITY ASSET HOLDS THIS GROUND. IT WAS NOT RECALLED. IT CANNOT BE REASONED WITH, BECAUSE NOBODY EVER TOLD IT ANYTHING. IF YOU FIGHT IT, FIGHT IT AWAKE.",
	"serpent": "MARK: DO NOT SOUND HERE. WE PAID OUT THE WHOLE LINE AND SOMETHING TOOK THE WEIGHT OFF THE END OF IT. IT IS LONG. IT IS NOT A MACHINE.",
	"orrery": "MARK: AN INSTRUMENT NOBODY SWITCHED OFF. IT HAS BEEN SURVEYING THIS VOLUME SINCE BEFORE THE ORDER. IT HAS FILED EVERY CYCLE. NOTHING HAS EVER COLLECTED.",
	"nursery": "MARK: THEIR GROUND. HULLS WE DO NOT HAVE NAMES FOR, IN NUMBERS. THEY DO NOT RAID AND THEY DO NOT TRADE. THEY COUNT. WE HAVE NEVER SEEN ONE LOSE ANYTHING IT WAS HOLDING.",
	"forge": "MARK: A FORGE THAT COPIES. FEED IT A HULL AND IT PRINTS THE PATTERN. IT DOES NOT ASK WHOSE HULL. WE DID NOT BUILD IT AND WE DO NOT KNOW WHO DID.",
	"procession": "MARK: THEY ARE ALL POINTED HOME. WE COUNTED FOUR HUNDRED AND STOPPED COUNTING. IF YOU READ THE HULLS, READ THEM SLOWLY.",
}

# THE REFUSAL, and it states its own terms. Naming the act rather than the gate
# keeps it true for every pilot who can read it: one who has not yet heard the
# request is told the same thing, and it becomes actionable the hour they do.
const CANNOT_READ := "A SOUNDING MARK — THE NOTATION IS NOT THE AUTHORITY'S, AND YOU CANNOT READ IT. FILE A RETURN AT A FOREIGN MAST AND YOU WILL."

# Identity, set by the spawner before add_child — every spawner's contract.
var system_id := ""
var index := -1
var kind := ""

var _holding := false
# §112/§113. The far-mark bark is ARMED by a refusal and FIRED at range-exit.
# Fired inline it stomped the refusal itself -- Barks.fire's own v18 comment
# says a bark writes straight to the same prompt label, and A MARK IS THE
# NETWORK'S TO READ went red on exactly that. At range-exit the refusal is a
# STALE line the player is flying away from, so replacing it is a handoff,
# not a stomp -- and if anything else has written the prompt first, the
# moment has passed and the bark stands down unspent.
var _refused := false
var _progress := 0.0
var _lamp_mat: StandardMaterial3D
var _t := 0.0


func mark_key() -> String:
	return GameState.mark_key(system_id, index)


func is_read() -> bool:
	return GameState.is_mark_read(mark_key())


func mark_name() -> String:
	return String(NAMES.get(kind, "A SOUNDING MARK"))


# §101, S1 adopted: the layup's plate after a deposit, one clause and no tally.
# The arrangement does not keep books, which is the entire difference between
# the cache and the registry -- so the plate changes by three words, once,
# however much has been left there.
const PLATE_LAYUP_GIVEN := "MARK: LAYUP. STORES CACHED BY CREWS WHO DID NOT ALL COME BACK FOR THEM — AND BY YOU. TAKE WHAT YOU NEED. LEAVE WHAT YOU CAN."


func plate() -> String:
	if kind == "layup" and GameState.is_mark_given(mark_key()):
		return PLATE_LAYUP_GIVEN
	return String(PLATES.get(kind, ""))


func _ready() -> void:
	add_to_group("farmark")
	_build_mesh()


func _build_mesh() -> void:
	# A spar with a lamp on it. Primitive meshes like everything else out here;
	# what carries at range is the light, because a buoy is the only thing in
	# this volume that is deliberately trying to be seen.
	var spar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = SILHOUETTE_SPAN
	spar.mesh = cm
	spar.position.y = SILHOUETTE_SPAN * 0.5
	spar.material_override = Palette.emissive(Color(0.09, 0.08, 0.11), 0.4)
	add_child(spar)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.4
	tm.outer_radius = 5.0
	tm.ring_segments = 48
	ring.mesh = tm
	ring.position.y = SILHOUETTE_SPAN * 0.62
	ring.material_override = Palette.emissive(Palette.RIVAL, 1.0)
	add_child(ring)

	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	lamp.mesh = sm
	lamp.position.y = SILHOUETTE_SPAN
	# THE NETWORK'S OWN COLOUR, the one the channel's replies and the rival's
	# annotations already speak in. Not a band colour: band paint means "how far
	# out", and every mark is at the same how-far-out. This means "whose".
	_lamp_mat = Palette.emissive(Palette.RIVAL, 2.2)
	lamp.material_override = _lamp_mat
	add_child(lamp)


func _process(delta: float) -> void:
	_t += delta
	if _lamp_mat:
		# Read, the lamp settles; unread, it turns over slowly. The archives'
		# tell and the instruments' tell, so a pilot who has met either already
		# knows how to read this one at range.
		_lamp_mat.emission_energy_multiplier = 1.4 if is_read() \
			else 1.6 + sin(_t * 0.7) * 0.8
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()
	if _refused:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud == null or not hud.has_method("prompt_text"):
			_refused = false
		elif String(hud.prompt_text()) != CANNOT_READ:
			# Something else owns the prompt now; the moment has passed, and a
			# bark must not be spent where it cannot be seen.
			_refused = false
		else:
			var p := get_tree().get_first_node_in_group("player")
			if p == null or global_position.distance_to(
					(p as Node3D).global_position) > read_range() * 1.5:
				_refused = false
				Barks.fire("far_mark_locked")


func pick_anchor() -> Vector3:
	return global_position + Vector3(0.0, SILHOUETTE_SPAN * 0.5, 0.0)


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= read_range()


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(read_range() * 0.6, 0.0, 0.0))


func on_tapped() -> void:
	# EVERY BRANCH ANSWERS, on the day the class is born rather than a playtest
	# later — §88's lesson taken as a construction rule.
	var hud := get_tree().get_first_node_in_group("hud")
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.RIVAL, 3.0, 0.8)
	if not GameState.files_with_the_network():
		# NO APPROACH ON THIS BRANCH. Flying a pilot twelve units closer to
		# something they have just been told they cannot read is the tap moving
		# the ship for nothing, which is the affordance problem inverted.
		if hud:
			hud.prompt_refusal(CANNOT_READ)
			_refused = true
		return
	if hud:
		if is_read():
			hud.prompt("%s — YOU HAVE READ THIS MARK. HOLD TO READ IT AGAIN." % mark_name())
		else:
			# The kind is NOT named here: what stands out here is exactly what
			# the notation is for, so the tap can only offer the verb.
			hud.prompt("A SOUNDING MARK — THE NOTATION IS THE NETWORK'S, AND YOU CAN READ IT. HOLD TO READ.")
	if not _player_in_range():
		_approach()


func hold_begin() -> void:
	if not GameState.files_with_the_network():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.prompt_refusal(CANNOT_READ)
			_refused = true
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
	_progress += delta / read_seconds()
	_sync_gauge()
	if _progress >= 1.0:
		_read()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "READING THE MARK")


func _read() -> void:
	# NO CARGO GUARD, and its absence is the design rather than an omission: the
	# archives defer a full hold because a reading that paid nothing would burn
	# a persisted stage, and this pays nothing to begin with. There is no state
	# in which reading a mark can fail.
	_holding = false
	_progress = 0.0
	var first := GameState.note_mark_read(mark_key())
	# §111. FILING's second feed. FIRST READS ONLY -- `first` is exactly that
	# question, already asked here for the legend spawn -- so re-reading a plate
	# you have already read pays nothing and the ladder cannot be farmed off one
	# buoy. Filing a return is the other half; the two are one act (§98) and
	# feed one ladder.
	if first:
		GameState.mark_skill("filing")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_broadcast("A SOUNDING MARK — %s" % mark_name(), plate(), Palette.RIVAL)
	Sfx.play("equip", -7.0, 0.7)
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.RIVAL, 4.0, 0.9)
	if first:
		# ON THE TRANSITION ONLY, the archives' rule: a pilot who comes back and
		# re-reads a mark is not written into the log a second time. 48
		# characters is the whole line (note_log truncates silently), and the
		# longest name in the table leaves this at 38.
		GameState.note_log("READ A MARK — %s" % mark_name())
		# §99. AND THE LEGEND ARRIVES. Asked of MAIN through a duck-typed call
		# rather than of SystemBuilder directly, and that is a class-edge
		# decision rather than a style one: SystemBuilder already references
		# this class to build the buoys, so calling it back by name would close
		# a mutual class reference -- the shape main.gd records as forty parse
		# errors and a hanging boot. Derelict asks main for arm_apex_wake the
		# same way and for the same reason.
		#
		# ON THE TRANSITION, like the log line above it: build_legend refuses a
		# mark it has already built for, but a re-read should not even ask.
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("legend_arrives"):
			main.legend_arrives(system_id, index, kind, global_position)
