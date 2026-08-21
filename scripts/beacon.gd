class_name Beacon
extends Node3D
# A WAYPOINT THE PLAYER PAID FOR (v19, Hunt stage 5). The deep has no lattice
# and no chart; the one navigation instrument out there is the bottom-left
# readout, and a place worth returning to — a rich cell, a station, and next
# stage a hyper-structure — could only be remembered by writing its bearing on
# paper. A beacon is that memory, dropped in the world and persisted in the
# save: three in stock, each one standing somewhere until it is recovered.
#
# THE STOCK IS THE DESIGN, and it was re-derived once (§87): eight, when a
# beacon was a passive bookmark, was route-threading; after §79 made each one
# a free course destination and a jump target, eight was a fast-travel network
# and the recover verb went unused — the exact failure this paragraph warned
# about, arrived from the other direction. At three, placing one is a
# commitment and recovering one is routine. Stock is
# DERIVED (BEACON_STOCK minus every dropped entry across every system), never
# stored: §59's derived-not-tracked rule, so the save cannot disagree with
# itself about how many beacons exist.
#
# RECOVERY IS THE MAST'S VERB. hold_begin/hold_tick/hold_release mirror
# SurveyMast — the ship parks in range and holds — because the deep already
# taught that gesture, and a flyover pickup would delete the marker at the
# exact moment the player arrives at the thing it marks.

const HOLD_RANGE := 6.0
const RECOVER_TIME := 1.6
const DECAY_RATE := 0.8
# §93. Reading a page clipped to somebody else's mast. Longer than the 1.6s
# recovery because it is a different act, and far shorter than the archive's
# fourteen seconds because a page on a beacon is not an expedition -- it is
# something left where the next person through would find it.
const READ_TIME := 3.0
# §96. The second stop of the same hold: filing the return itself. Longer than
# the read, because it is the irreversible half and the bar is the only warning
# a player gets between deciding and having decided.
const FILE_TIME := 4.0

# THE SHALLOWEST BAND A PAGE IS EVER LEFT IN. Foreign beacons stand wherever
# the rival has filed, which begins at CONTENT_MIN_DEPTH (24u) -- and the rival
# takes the shallows inside single sessions, so an ungated page would put the
# order's own text at the chart edge in a new pilot's first hours. Band 3 is
# where the shipped broadcast arc already turns strange, so the hints arrive
# once the game has said things are no longer fine, and the fiction agrees:
# you do not leave contraband where the authority still sweeps.
const PAGE_MIN_BAND := 3

# DIRECTIVE 9, six pages, passed hand to hand. Verbatim from the reviewed draft
# (docs/DIRECTIVE-NINE-DRAFT.md, read and approved 2026-08-19). Each page is the
# order's own words and then one line from whoever copied it out: the order is
# bureaucratic and plain, the margins are people and also plain. Nothing here is
# written to be decoded -- §92's register rule, which this content is the first
# test of. Page 5 is the spine.
const DIRECTIVE_PAGES := [
	{
		"clause": "The frontier beyond the bearing terminus is reclassified UNSOUNDABLE. Survey operations in the reclassified volume are suspended indefinitely.",
		"margin": "COPIED AND PASSED ON. WHOEVER GAVE IT TO ME WOULD NOT GIVE A NAME.",
	},
	{
		"clause": "No return filed from the reclassified volume shall be logged, corroborated, or entered against a commission.",
		"margin": "READ IT TWICE. IT DOES NOT SAY THE CREWS WERE LOST. IT SAYS THE CREWS CAME BACK, AND THE RETURNS WENT IN THE BIN.",
	},
	{
		"clause": "Vessels remaining in the reclassified volume at the effective date are removed from the active register.",
		"margin": "NO RESCUE WAS SENT. NO SEARCH WAS FLOWN. THEY DELETED THE SHIPS FROM THE LIST AND CALLED IT DONE.",
	},
	{
		"clause": "Automated instruments, relays and standing security assets within the reclassified volume are to remain in service. Recall is not authorized at this time.",
		"margin": "SO EVERY MACHINE OUT THERE IS STILL ON DUTY. THE WARDENS, THE ENGINES, THE BEACONS. NOBODY EVER TOLD THEM IT WAS OVER.",
	},
	{
		"clause": "APPENDIX B — NOT CIRCULATED. Reclassification is recommended on the grounds that repeated resurvey of the volume produces charts which do not agree with one another. Publication of charts known to be provisional exposes the authority to severe commercial and legal liability.",
		"margin": "THERE IT IS. THEY DID NOT CLOSE THE FRONTIER BECAUSE SOMETHING WAS WRONG WITH IT. THEY CLOSED IT BECAUSE THE MAPS WOULD NOT AGREE — AND THEY SELL MAPS.",
	},
	{
		"clause": "ATTACHED: vessels known to have filed after the effective date.",
		"margin": "NINE NAMES. I HAVE MET TWO OF THEM. THE LAST ONE ON THE LIST IS A HULL IN A LIVERY NOBODY REGISTERED, LAST SEEN HEADING OUT, STILL FILING.",
	},
]

# Which system this beacon's store entry lives in. Set by the spawner before
# add_child, like every identity field in this project. Removal is keyed by
# POSITION, not by index — an index held on a node goes stale the moment a
# sibling in the same system is recovered first, and a position cannot.
var system_id := ""
# v22. NOT YOURS. A rival beacon reuses this whole node -- mesh, breath, pick
# group, radar tier -- because it IS a beacon; what differs is small enough to
# be a flag. Foreign beacons are world dressing, not store entries: they are
# spawned by the cell streamer from the rival function, never live in
# GameState.beacons, never count against stock, and refuse recovery -- the
# anchor code is not yours to release.
var foreign := false
# §93. WHICH PAGE OF THE ORDER IS CLIPPED TO THIS MAST, 1..6, or 0 for none.
# Set by the spawner before add_child like every identity field here, and
# derived by page_for below -- the node never decides, so a beacon in a given
# cell always carries the same page and a harness can sweep the rule without
# building a world. Zero bytes of save: the authority's records persist, the
# refusers leave nothing behind.
var page := 0

# §96. WHICH STOP OF THE HOLD THIS IS: 0 reads the page (or recovers, on an own
# beacon), 1 files the return. A latch rather than a taller _progress, because
# the gauge is clamped to 0..1 by hud.crack_progress -- a progress that ran to
# 2.0 would pin the bar full for the entire second stage and show the player
# nothing at all.
var _stage := 0

var _holding := false
var _progress := 0.0
var _pulse_mat: StandardMaterial3D
var _t := 0.0


static func _accent() -> Color:
	# The player's livery accent — the colour that already means "yours". Read
	# through Palette.livery_accent, the accessor the refit sheet uses, with the
	# same default-0 the loader clamps to.
	return Palette.livery_accent(int(GameState.livery.get("accent", 0)))


static func page_for(cell_key: String, band: int) -> int:
	# THE WHOLE RULE, IN ONE PURE FUNCTION: which page a cell's foreign beacon
	# carries, and whether it carries one at all. The band gate lives HERE
	# rather than at the spawn site so the pacing decision cannot be
	# re-implemented slightly differently by the next caller -- and so the
	# harness can check every band over thousands of keys without spawning a
	# single node.
	#
	# Its own salt, never the beacon's presence hash: two derivations from one
	# hash correlate, and "which page" must not be inferable from "is there a
	# beacon here at all".
	if band < PAGE_MIN_BAND or DIRECTIVE_PAGES.is_empty():
		return 0
	return 1 + absi(hash("%s|directive_page" % cell_key)) % DIRECTIVE_PAGES.size()


func page_text() -> String:
	# The clause and the hand that copied it, in the order a reader meets them.
	if page < 1 or page > DIRECTIVE_PAGES.size():
		return ""
	var row: Dictionary = DIRECTIVE_PAGES[page - 1]
	return "%s\n\n— %s" % [String(row["clause"]), String(row["margin"])]


func _ready() -> void:
	# The pick group CameraRig's hold ladder reads, LAST in priority: a beacon
	# stands alone in empty deep by construction (the player chose the spot),
	# so contested taps with hulks and seams are not its problem — but the
	# ladder order still has to be stated somewhere, and it is stated there.
	add_to_group("beacon")
	_build_mesh()


func _build_mesh() -> void:
	# A slim pylon with a breathing light in the player's accent — the one
	# colour vocabulary that already means "yours" (the livery system's).
	# Deliberately NOT band paint: band colour means "where", and a beacon's
	# whole point is "whose".
	var mast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 2.2, 0.16)
	mast.mesh = bm
	mast.position.y = 1.1
	mast.material_override = Palette.emissive(Palette.HULL, 1.2)
	add_child(mast)

	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	lamp.mesh = sm
	lamp.position.y = 2.4
	_pulse_mat = Palette.emissive(Palette.RIVAL if foreign else _accent(), 2.5)
	lamp.material_override = _pulse_mat
	add_child(lamp)


func _process(delta: float) -> void:
	_t += delta
	# A slow breath, not a strobe: this is furniture you left, not an alarm.
	if _pulse_mat:
		_pulse_mat.emission_energy_multiplier = 1.6 + sin(_t * 2.2) * 1.1
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()


func pick_anchor() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= HOLD_RANGE


func filing() -> bool:
	# §96. Stage two: the return itself. Asked rather than inferred from
	# _progress, because _progress is reset at every stage boundary and a float
	# cannot express "already read".
	return _stage == 1


func _stage_time() -> float:
	if filing():
		return FILE_TIME
	return READ_TIME if reading() else RECOVER_TIME


func _gauge_label() -> String:
	# The label IS the statement of terms (§58), and it rides the same call as
	# the value because crack_progress takes it as a second argument rather
	# than through a setter -- so a bare crack_progress(-1.0) anywhere would
	# stamp the derelict's "BREACHING HULL" over this bar on the way out.
	if filing():
		return "FILING WITH THE NETWORK — NO PAYMENT, NO REGISTRY"
	return "READING THE PAGE" if reading() else "RECOVERING BEACON"


func _can_file() -> bool:
	# Whether the filing stage is offered at this mast, at all. Every clause is
	# a fact about the pilot or the world, never about this node: a foreign
	# beacon is a projection of a streamed cell (it dies with the cell and is
	# rebuilt on a warp), so anything remembered ON it would evaporate and the
	# verb would silently re-offer itself.
	if not foreign or page <= 0 or not GameState.heard_the_request():
		return false
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("network_filing_plan"):
		return false
	var plan: Dictionary = main.network_filing_plan()
	return not (plan["cells"] as Array).is_empty() \
		or not (plan["lost"] as Array).is_empty()


func reading() -> bool:
	# What this hold IS. A foreign mast with a page on it is read; a foreign
	# mast without one still refuses, and an own beacon is still recovered. One
	# question, asked in four places, so the three verbs cannot drift apart.
	return foreign and page > 0 and _stage == 0


func hold_begin() -> void:
	if foreign and page <= 0:
		# WHICH refusal, per 58 -- and a refusal, not a silence: the hold
		# gesture on a beacon has meant "recover" since v19, so a foreign one
		# that simply did nothing would read as a bug.
		#
		# STILL THE ONLY ANSWER IN THE SHALLOWS (§93). A page does not replace
		# this refusal, it sits beside it: out where the rival works the near
		# ring there is nothing clipped to the mast, and the anchor code is
		# still not the player's to release.
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.show_toast("NOT YOUR ANCHOR CODE — THIS BEACON ANSWERS TO SOMEBODY ELSE",
				Palette.RIVAL)
		Sfx.play("hit", -12.0, 0.7)
		return
	if not _player_in_range():
		_approach()
		return
	_holding = true


func hold_release() -> void:
	_holding = false
	# §96. THE STAGE ENDS WITH THE HOLD. One continuous hold is the commitment;
	# letting go and taking hold again starts at the page, which is the right
	# price for an irreversible act.
	#
	# AND THE FILING'S PROGRESS GOES WITH IT (§97, from the adversarial pass).
	# hold_begin does not reset _progress -- a released READ resumes where it
	# stopped, which is shipped behaviour and good. Carried into the filing
	# stage that becomes nonsense: abandon a filing at 87% and the residual
	# would be spent on the READ stage instead, so the bar drains under
	# "READING THE PAGE" (correctly, since that is what it now measures) after
	# the player filled it while filing, and a re-grab is 87% of the way to
	# re-reading a page they already have.
	#
	# The first fix for this captured the label before clearing the stage, and
	# it did nothing: _process calls _sync_gauge every frame of the drain and
	# _gauge_label re-derives from the live stage, overwriting it a frame later.
	# Zeroing is the fix that holds -- an abandoned filing simply clears, and
	# nothing anywhere has to name a verb the next hold will not perform.
	if _stage == 1:
		_progress = 0.0
	_stage = 0
	var hud := get_tree().get_first_node_in_group("hud")
	# CLEARED UNCONDITIONALLY, and the old `_progress < 1.0` guard is why. It
	# was correct while a completion always zeroed _progress; with a second
	# stage the value can sit anywhere, and a release above 1.0 skipped the
	# clear entirely -- leaving a full, static bar on screen until decay walked
	# it back down, which is the exact "released holds drain" feel the gauge
	# exists to give.
	if hud:
		hud.crack_progress(-1.0, _gauge_label())


func hold_tick(delta: float) -> void:
	if not _holding:
		return
	if not _player_in_range():
		hold_release()
		return
	_progress += delta / _stage_time()
	if _progress < 1.0:
		_sync_gauge()
		return
	# ONE COMPLETION PER TICK, AND THE OVERSHOOT IS DISCARDED. Both halves are
	# load-bearing:
	#
	# The `>= 1.0` test has no stage of its own, so without an explicit latch a
	# hold that stayed alive past a completion would re-fire it on every frame
	# -- a broadcast plate redrawn sixty times a second.
	#
	# And the leftover delta must NOT roll into the next stage. §93's own
	# assertion drives a single 4.0-second tick against a 3.0-second READ_TIME,
	# reaching 1.333 in one call, and then requires that nothing was stored and
	# no cargo moved. If that overshoot could carry into the filing stage, a
	# green assertion about the page would go red because of a verb it was never
	# testing. Resetting to zero here makes each stage cost a fresh hold's worth
	# of seconds, which is also what the player is being told the bar means.
	_progress = 0.0
	if _stage == 1:
		_stage = 0
		_holding = false
		_file_return()
		return
	if reading():
		_read_page()
		# THE SECOND STOP, only when there is something to file. _read_page has
		# already dropped _holding for the ordinary case; this picks the hold
		# back up and relabels the bar, so one gesture carries two verbs and the
		# deeper commitment sits literally deeper in the hold.
		if _can_file():
			_stage = 1
			_holding = true
			_sync_gauge()
		return
	_recover()


func marker_color() -> Color:
	# The radar override hud.gd already honours. Own beacons wear the livery
	# accent there too -- the same colour the world mesh already breathes, which
	# closes a small radar/world disagreement -- and foreign ones wear RIVAL.
	return Palette.RIVAL if foreign else _accent()


func on_tapped() -> void:
	# EVERY BRANCH ANSWERS (§88). This function used to pulse and fly the ship
	# in without saying anything at all, which is the affordance problem one
	# layer down -- a tap that moves you and stays silent reads as a bug, and it
	# matters most here because the three beacons a tap can land on now do three
	# different things.
	FX.ring_pulse(get_parent(), pick_anchor(),
		Palette.RIVAL if foreign else _accent(), 1.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("prompt"):
		if reading() and _can_file():
			# §96. Both stops named in one sentence, because they are one hold.
			# SHORT ENOUGH TO RENDER. hud's prompt label is a bare Label with no
			# autowrap and no width constraint, so it takes its own text width
			# and centres it -- a hundred-odd characters runs off both ends of a
			# phone. Both stops still named.
			hud.prompt("HOLD TO READ THE PAGE — KEEP HOLDING TO FILE YOUR RETURN")
		elif reading():
			hud.prompt("SOMEBODY ELSE'S BEACON — A PAGE IS CLIPPED TO THE MAST. HOLD TO READ IT")
		elif foreign:
			hud.prompt("SOMEBODY ELSE'S BEACON — THE ANCHOR CODE IS NOT YOURS")
		else:
			hud.prompt("YOUR BEACON — HOLD TO RECOVER IT")
	if not _player_in_range():
		_approach()


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(2.5, 0, 0))


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, _gauge_label())


func _read_page() -> void:
	# §93. THE PAGE, AND NOTHING ELSE. No cargo, no credits, no stage, no store
	# entry, no "seen" flag -- reading costs nothing and leaves nothing, which
	# is the rival's covenant applied to the people the rival was one of. The
	# beacon stays standing: it is not the player's to take, and a page that
	# vanished on reading would be a collectible rather than something somebody
	# left where the next crew through would find it.
	_holding = false
	_progress = 0.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		# LABELLED, not bare: hud.crack_progress writes the label BEFORE its
		# negative-t early return, so a bare clear stamps the derelict's
		# "BREACHING HULL" onto this bar for the whole drain. Shipped that way
		# in §93 and invisible only because the box was usually already fading.
		hud.crack_progress(-1.0, _gauge_label())
		hud.show_broadcast("DIRECTIVE 9 — PAGE %d OF %d · PASSED HAND TO HAND"
			% [page, DIRECTIVE_PAGES.size()], page_text(), Palette.RIVAL)
	Sfx.play("equip", -10.0, 0.8)
	FX.ring_pulse(get_parent(), global_position, Palette.RIVAL, 2.4, 0.7)


func _file_return() -> void:
	# §96. THE RETURN GOES OUT. Everything that decides WHAT is filed lives in
	# main (network_filing_plan / file_charts_with_network), beside the
	# counter's own verb and the cell/band glue -- this node's whole job is the
	# gesture that asks for it.
	var hud := get_tree().get_first_node_in_group("hud")
	var main := get_tree().get_first_node_in_group("main")
	if hud:
		hud.crack_progress(-1.0, _gauge_label())
	if main == null or not main.has_method("file_charts_with_network"):
		return
	var cells: int = main.file_charts_with_network()
	if cells <= 0:
		# The refusal states its own terms, and it is reachable: the plan is
		# recomputed at completion rather than trusted from four seconds ago,
		# because a hold is long enough for a hold to fill or a rival to arrive.
		if hud and hud.has_method("show_toast"):
			hud.show_toast("NOTHING NEW TO FILE — THE NETWORK ALREADY HOLDS YOUR MARKS",
				Palette.RIVAL)
		return
	if hud and hud.has_method("show_toast"):
		hud.show_toast("RETURN FILED — %d CELL%s, PASSED HAND TO HAND" % [
			cells, "" if cells == 1 else "S"], Palette.RIVAL)
	Sfx.play("equip", -8.0, 0.65)
	FX.ring_pulse(get_parent(), global_position, Palette.RIVAL, 3.2, 0.9)
	# AND THE CHANNEL ANSWERS, at the mast rather than at the next band
	# crossing: the crossing is unreachable from the deep where filing happens.
	if main.has_method("network_reply"):
		main.network_reply(cells, global_position)


func _recover() -> void:
	# THE STORE FIRST, then the theater. GameState is authoritative — the node
	# is a projection of it, rebuilt on every _load_system — so a recover that
	# freed the node before the store entry would leave a ghost that respawns
	# on the next warp.
	_holding = false
	GameState.recover_beacon(system_id, global_position.x, global_position.z)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0, _gauge_label())
		hud.show_toast("BEACON RECOVERED — %d IN STOCK" % GameState.beacon_stock_left(),
			_accent())
	Sfx.play("equip", -10.0, 1.1)
	FX.ring_pulse(get_parent(), global_position, _accent(), 3.0, 0.5)
	queue_free()
