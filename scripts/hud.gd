class_name HUD
extends CanvasLayer
# Diegetic corner HUD: salvage counter with tweened count-up and ticking audio,
# floating gain popups, a contextual prompt line, and the crack progress gauge.
# Anchored so it holds up at any window size. Never modal, never covers play.

const TICK_INTERVAL := 0.055

# The action dock. Sized by its contents, so these are the only numbers that
# decide how much of the bottom edge the controls occupy — on every screen.
const DOCK_BOTTOM := 24.0

# --- the notification bands --------------------------------------------------
# Named rather than left as literals at their build sites, because BANDS CLEAR
# asserts against these same numbers: a reflow that moved a plate without moving
# the assertion would be a reflow the assertion could not see.
#
# The desktop canvas is what forced this. A wide window pins the logical height
# to ~820 against the 1280 these were authored in, so every vertical gap is 64%
# of what it looks like in the design space — and three surfaces were already
# overlapping at the design size: the toast rested ON the boss bar (128 against
# a plate spanning 86-136), the broadcast plate nearly touched the toast, and
# the parley button clipped the crack gauge.
const BOSS_TOP := 86.0
const TOAST_ENTER := 164.0      # slides up from here
const TOAST_REST := 142.0       # clears the boss plate's ~136 by 6
const TOAST_HOLD := 2.2         # the longest shipped toast is ~47 chars; at a
                                # transient-read rate of ~19 chars/s, 1.6s never
                                # covered it. Only safe with the tween kill above.
const BROADCAST_TOP := 176.0    # clears a 25px toast at 142 by 9
const PARLEY_WIDTH := 240.0
const PARLEY_HEIGHT := 40.0
const PARLEY_BOTTOM := -252.0
const BLUFF_BOTTOM := -296.0   # was -216, which overlapped the crack gauge.
                                # -252 is the tutorial card's slot, and the two
                                # are provably exclusive: interdiction_eligible()
                                # excludes tutorial_active(). BANDS CLEAR asserts
                                # that exclusion rather than assuming it.      # gap between the dock and the screen's bottom edge
const ABILITY_SCALE := 1.15    # the centre button is the emphasised one

signal refit_pressed
# The HOLD readout is the door to the hold console. Deliberately NOT a fourth
# RoundButton in the action dock: four buttons leave no centre slot, and the
# ability would end up ~49 design units off centre against the dock's own rule
# that it "gets the position the eye returns to" because it is "the button
# pressed under pressure". The readout costs no dock width and is already where
# a player looks to ask this question.
signal hold_pressed
signal chart_pressed
signal pause_pressed

# --- radar pings ------------------------------------------------------------
# Edge-of-screen markers for contacts the camera cannot see. The systems roughly
# doubled in size in phase 2, which made "where is everything" a real question
# for the first time — the chart answers it between systems, this answers it
# during one.
class RadarLayer:
	extends Control

	const EDGE_MARGIN := 26.0     # how far in from the border the tips sit
	const MAX_MARKERS := 12       # a border ring of arrows is noise, not information
	const OFFSCREEN_PAD := 34.0   # a contact must be this far out before it pings
	const SIZE_NORMAL := 9.0
	const SIZE_APEX := 15.0

	# Priority tiers, so the cap never drops the thing you most needed to know
	# about in favour of the eleventh nearest swarm fighter.
	#
	# HOME is above the apex, and it is the only marker that is not a contact:
	# it points at the system origin whenever the player is outside the charted
	# volume. Out in the Reaches with thirty things on the board, the one marker
	# that must never be dropped is the one that says which way home is.
	const TIER_HOME := -1
	const TIER_APEX := 0
	const TIER_PORT := 1
	const TIER_SITE := 2
	const TIER_HOSTILE := 3
	const TIER_SEAM := 4
	# v16. Appended at the BOTTOM, the same way TIER_SEAM was, so nothing above
	# it renumbered. Below the seams on purpose: the hunt ghost is the least
	# certain thing on the board -- it is not a contact, it is a guess -- and
	# when the 12-marker cap bites it should be the first thing to go.
	const TIER_HUNT := 5
	# What the dossier has to be worth before the ghost appears at all. Three
	# agreeing hints and a search circle under 200u is the point where an arrow
	# is honest guidance rather than a confident lie: below that the estimate
	# still spans more sky than the radar can meaningfully point at.
	const HUNT_MIN_STRENGTH := 3
	const HUNT_MAX_RADIUS := 200.0

	# Contact alpha falls off over this many units — at which point a marker sits
	# at its floor and everything further away looks identical. Sixty is right
	# inside a system 40-48 units across and badly wrong outside one, where
	# contacts are hundreds of units apart and every one of them pinned at 0.3.
	# Scaled by the player's band so distance keeps reading as distance.
	const ALPHA_SPAN := 60.0
	const ALPHA_SPAN_BY_BAND := [1.0, 2.5, 5.0, 8.0, 12.0]
	# A Cartographic Index in the hold is somebody else's chart of out here, and
	# stations answer it. Applied to PORT markers only — this is a thing that
	# finds stations, not a general sensor upgrade, and a carried good must never
	# quietly become a fitted stat (19).
	const INDEX_RANGE_FACTOR := 2.5
	# The FITTED array, weaker than the carried index: 1.9 against 2.5. Same
	# rule, and the same reason — a craft may not obsolete carrying.
	const FITTED_INDEX := 1.9

	var markers: Array = []
	var alpha_span := ALPHA_SPAN     # published so the harness can assert on it

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		_collect()
		queue_redraw()

	func _collect() -> void:
		markers.clear()
		var cam := get_viewport().get_camera_3d()
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if cam == null or player == null or not visible:
			return

		var rect := get_viewport_rect()
		var centre := rect.size * 0.5
		var inset := Rect2(Vector2(EDGE_MARGIN, EDGE_MARGIN),
			rect.size - Vector2(EDGE_MARGIN, EDGE_MARGIN) * 2.0)
		if inset.size.x <= 1.0 or inset.size.y <= 1.0:
			return

		var seen := {}
		var found: Array = []

		# The way home, and the band that sets how fast everything else fades.
		var main := get_tree().get_first_node_in_group("main")
		var depth := 0.0
		if main != null and main.has_method("deep_depth"):
			depth = float(main.deep_depth())
		alpha_span = ALPHA_SPAN * ALPHA_SPAN_BY_BAND[DeepSpace.band_of(depth)]
		if depth > 0.0:
			# Deliberately NOT subject to the on-screen skip the contacts use. This
			# is a compass, not a ping: it should be on the border the whole way
			# out and the whole way back, not blink off near the edge of the chart.
			found.append({
				"id": 0,
				"tier": TIER_HOME,
				"dist": player.global_position.length(),
				"screen": _project(cam, Vector3.ZERO, centre, rect),
				"color": Palette.TEAL,
				"size": SIZE_APEX,
			})

		# v16. THE HUNT GHOST. Not a contact — a place the dossier says to look,
		# drawn at the ESTIMATE and therefore honestly wrong by whatever error
		# the player has not yet bought out. It is deliberately the same shape
		# as every other marker rather than a special icon: what makes it a
		# guess is that it moves when you buy a reading, and that the engine is
		# not there when you arrive.
		#
		# Gated, because a weak estimate pointing confidently is worse than
		# nothing. Below HUNT_MIN_STRENGTH the hints do not agree enough to
		# average, and above HUNT_MAX_RADIUS the circle is wider than the arrow
		# could usefully aim inside.
		if main != null and main.has_method("hunt_estimate"):
			var est: Dictionary = main.hunt_estimate()
			if int(est.get("strength", 0)) >= HUNT_MIN_STRENGTH \
					and float(est.get("radius", 1.0e9)) <= HUNT_MAX_RADIUS:
				var ghost: Vector3 = est.get("center", Vector3.ZERO)
				found.append({
					"id": 1,
					"tier": TIER_HUNT,
					"dist": player.global_position.distance_to(ghost),
					"screen": _project(cam, ghost, centre, rect),
					"color": Palette.GOLD,
					"size": SIZE_NORMAL,
				})

		# --- muster force clusters (v18, stage 4) ------------------------
		# ONE MARKER PER FORCE, not per ship. A muster puts ~32 machines in the
		# sky and MAX_MARKERS is 12: rendered individually they would evict the
		# port, the hull and every seam off the board and leave a border of
		# identical arrows, which is noise rather than information.
		#
		# Every muster node is marked `seen` here, which is what suppresses its
		# individual marker below — the dedup mechanism that already exists,
		# rather than a second exclusion the per-node loop would have to learn.
		# So this sidesteps the marker cap instead of reworking the tier system.
		for spec_m in [
			["muster_column", Palette.THREAT, SIZE_APEX],
			["muster_line", Palette.TEAL, SIZE_APEX],
		]:
			var group := String(spec_m[0])
			var sum := Vector3.ZERO
			var live := 0
			for node in get_tree().get_nodes_in_group(group):
				var n := node as Node3D
				if not is_instance_valid(n):
					continue
				seen[n.get_instance_id()] = true
				sum += n.global_position
				live += 1
			if live == 0:
				continue
			var centre_of := sum / float(live)
			var scr := _project(cam, centre_of, centre, rect)
			if inset.grow(-OFFSCREEN_PAD + EDGE_MARGIN).has_point(scr):
				continue
			found.append({
				# A stable synthetic id: the group name hashed. Instance ids
				# belong to nodes, and this marker outlives any one of them.
				"id": group.hash(),
				"tier": TIER_APEX,   # a massed force outranks a single contact
				"dist": player.global_position.distance_to(centre_of),
				"screen": scr,
				"color": spec_m[1] as Color,
				"size": float(spec_m[2]),
			})

		# --- deep convoy clusters (chartfolk traffic) --------------------
		# ONE MARKER PER CONVOY — the muster pass's dedup trick, bucketed by
		# the convoy_id meta instead of by group, because two convoys can be
		# live at once and a single centroid over both would point at empty
		# space between them. TIER_SITE, not TIER_APEX: a neutral convoy is
		# a place to look at, not a threat that outranks the port and the
		# way home. Painted the faction's colour, which is the entire reason
		# the six chartfolk tints exist.
		var conv_pos := {}
		var conv_n := {}
		var conv_col := {}
		for node_c in get_tree().get_nodes_in_group("deep_convoy"):
			var nc := node_c as Node3D
			if not is_instance_valid(nc):
				continue
			seen[nc.get_instance_id()] = true
			var cid := String(nc.get_meta("convoy_id", ""))
			if cid == "":
				continue
			conv_pos[cid] = (conv_pos.get(cid, Vector3.ZERO) as Vector3) \
				+ nc.global_position
			conv_n[cid] = int(conv_n.get(cid, 0)) + 1
			if not conv_col.has(cid):
				conv_col[cid] = FactionDB.tint_of(String(nc.faction))
		for cid_v in conv_pos.keys():
			var cid2 := String(cid_v)
			var conv_at: Vector3 = (conv_pos[cid2] as Vector3) / float(conv_n[cid2])
			var conv_scr := _project(cam, conv_at, centre, rect)
			if inset.grow(-OFFSCREEN_PAD + EDGE_MARGIN).has_point(conv_scr):
				continue
			found.append({
				"id": cid2.hash(),
				"tier": TIER_SITE,
				"dist": player.global_position.distance_to(conv_at),
				"screen": conv_scr,
				"color": conv_col[cid2] as Color,
				"size": SIZE_NORMAL,
			})

		for spec in [
			["apex", TIER_APEX, Palette.THREAT, SIZE_APEX],
			["dockable", TIER_PORT, Palette.TEAL, SIZE_NORMAL],
			["crackable", TIER_SITE, Palette.AMBER, SIZE_NORMAL],
			["hostiles", TIER_HOSTILE, Palette.THREAT, SIZE_NORMAL],
		# Below hostiles on purpose. found.sort_custom is ascending and
		# MAX_MARKERS is 12, so when a nest springs the rocks fall off the board
		# first -- which is correct, and free. TIER_SEAM is appended at the
		# bottom of the tier list so nothing above it was renumbered.
		["mineable", TIER_SEAM, Palette.HULL, SIZE_NORMAL],
		]:
			for node in get_tree().get_nodes_in_group(String(spec[0])):
				var n := node as Node3D
				if not is_instance_valid(n) or seen.has(n.get_instance_id()):
					continue
				seen[n.get_instance_id()] = true
				# Ports mark their dock ring, not their hull centre: the ring is
				# the thing you are actually flying to.
				var world: Vector3 = n.global_position
				if n.has_method("pick_anchor"):
					world = n.pick_anchor()
				# v15. THE ENGINE IS NOT ON THE MAP UNTIL YOU ARE ON TOP OF IT.
				# Every other marker earns its place by being a thing you already
				# know is there. The apex used to be handed over free -- top tier,
				# never dropped by the 12-marker cap, alpha floored at 0.3 so it
				# rendered at ANY distance -- which was harmless when it sat in
				# plain sight inside the charted volume and is fatal now: a
				# permanent red arrow pointing at the lair would answer the hunt
				# before the first hint was ever bought.
				if String(spec[0]) == "apex" \
						and player.global_position.distance_to(world) > ApexBoss.DETECT_RANGE:
					continue
				var screen := _project(cam, world, centre, rect)
				if inset.grow(-OFFSCREEN_PAD + EDGE_MARGIN).has_point(screen):
					continue     # on screen: the player can already see it
				# The colour is per-GROUP by default, which is right for everything
				# that is one kind of thing. A seam is not: what it holds is worth
				# 60 credits or 240 and the marker is the only place that can say
				# so before you fly there. An optional per-node override keeps that
				# knowledge in the node instead of teaching this loop about ore.
				var col: Color = spec[2] as Color
				if n.has_method("marker_color"):
					col = n.marker_color()
				found.append({
					"id": n.get_instance_id(),
					"tier": int(spec[1]),
					"dist": player.global_position.distance_to(world),
					"screen": screen,
					"color": col,
					"size": float(spec[3]),
				})

		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["tier"]) != int(b["tier"]):
				return int(a["tier"]) < int(b["tier"])
			return float(a["dist"]) < float(b["dist"]))

		for entry in found:
			if markers.size() >= MAX_MARKERS:
				break
			var dir: Vector2 = (entry["screen"] as Vector2) - centre
			if dir.length() < 0.001:
				continue
			markers.append({
				"id": entry["id"],
				"tier": entry["tier"],
				"pos": _clamp_to_border(centre, dir.normalized(), inset),
				"angle": dir.angle(),
				"color": entry["color"],
				"size": entry["size"],
				"dist": entry["dist"],
			})

	func _project(cam: Camera3D, world: Vector3, centre: Vector2, rect: Rect2) -> Vector2:
		# unproject_position mirrors anything behind the lens, which on a pitched
		# top-down rig is a real case: at full zoom-out the camera sits ~20 units
		# back, so contacts below the player can fall behind it. For those, take
		# the bearing from the world instead. The rig never yaws, so world +X is
		# screen right and world +Z is screen down.
		if cam.is_position_behind(world):
			var to := world - cam.global_position
			var bearing := Vector2(to.x, to.z)
			if bearing.length() < 0.001:
				bearing = Vector2(0, 1)
			return centre + bearing.normalized() * rect.size.length()
		return cam.unproject_position(world)

	func _clamp_to_border(centre: Vector2, dir: Vector2, inset: Rect2) -> Vector2:
		# Ray from the centre to the inset rect's edge: scale by whichever axis
		# runs out of room first.
		var half := inset.size * 0.5
		var tx := half.x / maxf(absf(dir.x), 0.00001)
		var ty := half.y / maxf(absf(dir.y), 0.00001)
		return centre + dir * minf(tx, ty)

	func marker_alpha(tier: int, dist: float) -> float:
		# The fade RULE, lifted out of _draw so it can be asserted without reading
		# pixels. Home never fades — it is the one marker whose whole job is to be
		# legible from as far away as possible.
		if tier == TIER_HOME:
			return 0.95
		var span := alpha_span
		# A Cartographic Index is somebody else's chart of out here, and stations
		# answer it. PORT markers only: this finds stations, it is not a sensor
		# upgrade, and a carried good must never become a general buff.
		# Carried index or fitted array, better of the two, never both — the same
		# non-stacking rule the EMP dampers follow.
		if tier == TIER_PORT:
			if GameState.hold_has("index_cartographic"):
				span *= INDEX_RANGE_FACTOR
			elif GameState.fit_has("mod_survey_array"):
				span *= FITTED_INDEX
		return clampf(1.0 - (dist - 12.0) / span, 0.3, 0.95)


	func _draw() -> void:
		for m in markers:
			var pos: Vector2 = m["pos"]
			var ang: float = m["angle"]
			var s: float = m["size"]
			var col: Color = m["color"]
			# Distance-faded so a contact across the system is a hint and one
			# just past the edge is a warning. Home never fades: it is the one
			# marker whose whole job is to be legible from as far away as
			# possible.
			var alpha := marker_alpha(int(m.get("tier", TIER_HOSTILE)), float(m["dist"]))
			var tri := PackedVector2Array([
				Vector2(s, 0.0).rotated(ang) + pos,
				Vector2(-s * 0.7, s * 0.62).rotated(ang) + pos,
				Vector2(-s * 0.7, -s * 0.62).rotated(ang) + pos,
			])
			draw_colored_polygon(tri, Color(col.r, col.g, col.b, alpha))

var ability_button: RoundButton
var refit_button: RoundButton
var chart_button: RoundButton
var pause_button: Button

var _root: Control
var _radar: RadarLayer
var _dock: PanelContainer
var _system_label: Label
var _contract_box: VBoxContainer
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_state: Label
var _boss_fill: ColorRect
var _boss_plates: HBoxContainer
var _cargo_label: Label
var _hull_label: Label
var _tutorial_box: VBoxContainer
var _tutorial_step_label: Label
var _tutorial_text: Label
var _tutorial_skip: Button
var _arrival_label: Label
var _toast_label: Label
var _value_label: Label
var _gain_label: Label
var _prompt_label: Label
var _crack_box: VBoxContainer
var _crack_fill: ColorRect
# Drain rate for an abandoned hold. Fast enough not to linger into the next
# thing the player does, slow enough to read as a decision rather than a bug.
const CRACK_DRAIN := 9.0
var _crack_shown := 0.0
var _crack_releasing := false
var _crack_label: Label
var _toast_tween: Tween = null
var _parley_button: Button
var _bluff_button: Button
var _broadcast_box: PanelContainer
var _broadcast_tween: Tween = null
var _broadcast_from: Label
var _broadcast_body: Label

var _shown_value := 0.0
var _last_tick := 0.0
var _pending_gain := 0

# The bottom-left "you are here". Held in pieces so leaving the charted system
# rewrites it without the caller having to know what it used to say.
const SYSTEM_TAG_HOME := Color(1.0, 0.13, 0.45, 0.65)
var _system_base := ""
var _system_short := ""
var _deep_band := ""
var _deep_out := 0.0
var _gain_timer: SceneTreeTimer = null


func _ready() -> void:
	add_to_group("hud")
	# THE READOUT FOLLOWS THE HOLD WITHOUT BEING ASKED. Nineteen sites call
	# refresh_cargo() by hand and two of them had already forgotten -- salvage
	# spilled on death and a delivery settled on docking both left this label
	# showing a hold the player no longer had. Connected in _ready and never in
	# a resize handler: refit_panel records what re-connecting on size_changed
	# does, which is that Godot cannot dedupe lambdas and a dragged window
	# multiplies the connection.
	GameState.cargo_changed.connect(refresh_cargo)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Deliberately a sibling of _root rather than a child: _root is squeezed into
	# a centred column on wide windows (see UILayout), and edge markers have to
	# hug the actual screen edge, not the column's.
	_radar = RadarLayer.new()
	add_child(_radar)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(26, 26)
	top.add_theme_constant_override("separation", -2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var tag := Label.new()
	tag.text = "SALVAGE"
	tag.add_theme_color_override("font_color", Palette.AMBER_DIM)
	tag.add_theme_font_size_override("font_size", 15)
	top.add_child(tag)

	_value_label = Label.new()
	_value_label.text = "0"
	_value_label.add_theme_color_override("font_color", Palette.GOLD)
	_value_label.add_theme_font_size_override("font_size", 36)
	_value_label.pivot_offset = Vector2(0, 18)
	top.add_child(_value_label)

	# The one control in this stack that takes input. `top` is MOUSE_FILTER_IGNORE
	# so a glance-only readout never eats a tap meant for the ship; this label
	# opts back in for itself, and nothing around it changes.
	_cargo_label = Label.new()
	_cargo_label.text = "HOLD 0/24"
	_cargo_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_cargo_label.add_theme_font_size_override("font_size", 12)
	_cargo_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_cargo_label.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			hold_pressed.emit())
	top.add_child(_cargo_label)

	# Hull integrity. The ship has always carried a bar over its own hull, which
	# is readable when you are looking AT the ship and useless when you are
	# looking at whatever is shooting it. This is the glanceable copy.
	_hull_label = Label.new()
	_hull_label.text = "HULL 100%"
	_hull_label.add_theme_color_override("font_color", Palette.TEAL)
	_hull_label.add_theme_font_size_override("font_size", 12)
	top.add_child(_hull_label)

	_gain_label = Label.new()
	_gain_label.add_theme_color_override("font_color", Palette.GOLD)
	_gain_label.add_theme_font_size_override("font_size", 19)
	_gain_label.modulate.a = 0.0
	_gain_label.position = Vector2(30, 88)
	_gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gain_label)

	_system_label = Label.new()
	_system_label.text = "SYS // PYX-01 :: DERELICT FIELD"
	_system_label.add_theme_color_override("font_color", Color(1.0, 0.13, 0.45, 0.65))
	_system_label.add_theme_font_size_override("font_size", 13)
	_system_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Back in the corner: the controls moved to the centre dock, so the
	# bottom-left is the label's again and the clearance hack is unnecessary.
	_system_label.position = Vector2(26, -30)
	_system_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_system_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Clears the action dock, which occupies the band from -24 up to about -134.
	# -140 left six pixels, which is under the font's ascender — "TAP THE COLD
	# FORGE TO DOCK" sat on the dock's top border. -152 clears the glyphs, not
	# just the box.
	_prompt_label.position = Vector2(0, -152)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Palette.AMBER)
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.modulate.a = 0.0
	_root.add_child(_prompt_label)

	_build_broadcast()
	_build_crack_gauge()
	_build_action_dock()
	_build_parley_button()
	_build_pause_button()
	_build_contract_tracker()
	_build_banners()
	_build_boss_bar()
	_build_tutorial_card()

	# Keep the chrome in a centred column so corner controls stay grouped on a
	# wide desktop window instead of drifting to opposite edges.
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	# chrome(), not column(): the corner controls belong at the screen's corners.
	# See UILayout.chrome for why the sheets still get the column treatment.
	UILayout.chrome(_root)


func _build_tutorial_card() -> void:
	# Sits above the prompt line so a step instruction and a world prompt can
	# coexist without fighting for the same row.
	_tutorial_box = VBoxContainer.new()
	_tutorial_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# x=0, not -150: grow_horizontal BOTH already centres a min-sized box on its
	# anchor, so a manual negative-half-width offset double-compensates and shifts
	# the card half its own width to the LEFT. _prompt_label and _toast_label had
	# it right all along at x=0.
	_tutorial_box.position = Vector2(0, -252)
	_tutorial_box.custom_minimum_size = Vector2(300, 0)
	_tutorial_box.add_theme_constant_override("separation", 2)
	_tutorial_box.visible = false
	_root.add_child(_tutorial_box)

	var head := HBoxContainer.new()
	_tutorial_step_label = Label.new()
	_tutorial_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_step_label.add_theme_font_size_override("font_size", 11)
	_tutorial_step_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
	head.add_child(_tutorial_step_label)

	_tutorial_skip = Button.new()
	_tutorial_skip.text = "SKIP"
	_tutorial_skip.flat = true
	_tutorial_skip.add_theme_font_size_override("font_size", 11)
	_tutorial_skip.add_theme_color_override("font_color", Palette.AMBER_DIM)
	head.add_child(_tutorial_skip)
	_tutorial_box.add_child(head)

	_tutorial_text = Label.new()
	_tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.custom_minimum_size = Vector2(300, 0)
	_tutorial_text.add_theme_font_size_override("font_size", 15)
	_tutorial_text.add_theme_color_override("font_color", Palette.GOLD)
	_tutorial_box.add_child(_tutorial_text)


func set_tutorial(step: int, total: int, text: String) -> void:
	_tutorial_box.visible = true
	_tutorial_step_label.text = "STEP %d / %d" % [step, total]
	_tutorial_text.text = text
	_tutorial_text.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tutorial_text, "modulate:a", 1.0, 0.25)


func flash_tutorial() -> void:
	var tw := create_tween()
	tw.tween_property(_tutorial_text, "modulate", Color(0.6, 1.0, 0.9, 1.0), 0.12)
	tw.tween_property(_tutorial_text, "modulate", Color(1, 1, 1, 1), 0.3)


func hide_tutorial() -> void:
	_tutorial_box.visible = false


func tutorial_skip_button() -> Button:
	return _tutorial_skip


func set_chrome_visible(v: bool) -> void:
	# Attract mode shows the system, not the cockpit.
	_root.visible = v
	if _radar:
		_radar.visible = v


func dock_width() -> float:
	return _dock.size.x if _dock else 0.0


func dock_centre_x() -> float:
	return (_dock.position.x + _dock.size.x * 0.5) if _dock else 0.0


func band_controls() -> Dictionary:
	# Every centre-anchored plate, by name. The notification surfaces were absent
	# from this until the reflow: they are centre-anchored, nothing ever probed
	# them, and an 8px overlap shipped partly because nothing looked.
	return {
		"dock": _dock,
		"boss": _boss_box,
		"crack": _crack_box,
		"tutorial": _tutorial_box,
		"toast": _toast_label,
		"broadcast": _broadcast_box,
		"arrival": _arrival_label,
		"parley": _parley_button,
		"prompt": _prompt_label,
	}


func centred_probe() -> Array:
	# [name, centre_x] pairs. The CONTRACT is an array of pairs, not a dictionary:
	# BAND CENTRED indexes pair[1], and handing it a dictionary makes it iterate
	# KEYS — at which point pair[1] is the second character of a name, float()s to
	# zero, and the assertion reports the full half-width as an offset. It failed
	# loudly rather than silently, which is the only reason this is a comment and
	# not a bug.
	var out: Array = []
	for key in band_controls():
		var c: Control = band_controls()[key]
		if c == null:
			continue
		out.append([String(key), c.global_position.x + c.size.x * 0.5])
	return out


func band_rects() -> Dictionary:
	# Vertical extents in design units, measured from the TOP of the logical
	# canvas so bands anchored to opposite edges are directly comparable.
	# get_combined_minimum_size() is what a container actually reserves; reading
	# `size` alone returns zero before the first layout pass and would quietly
	# pass every clearance check.
	var out := {}
	for key in band_controls():
		var c: Control = band_controls()[key]
		if c == null:
			continue
		var extent: float = maxf(c.get_combined_minimum_size().y, c.size.y)
		# `position` is already RESOLVED to absolute canvas coordinates by the time
		# a layout pass has run, for top- and bottom-anchored controls alike — the
		# authored negative offsets are long gone. So this needs no anchor
		# branching, and adding one (as the first version did) invents a case that
		# never fires while hiding the real geometry.
		out[String(key)] = Vector2(c.position.y, c.position.y + extent)
	# The toast is measured where it is READ, not where it enters.
	if out.has("toast"):
		var t: Vector2 = out["toast"]
		out["toast"] = Vector2(TOAST_REST, TOAST_REST + (t.y - t.x))
	return out
func radar_markers() -> Array:
	return _radar.markers if _radar else []


func chrome_visible() -> bool:
	return _root.visible


func _build_boss_bar() -> void:
	# Centred under the top edge: the boss's HP, phase, and iris state, which is
	# the entire fight readable in one glance on a portrait screen.
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# See _build_tutorial_card: x=0 because grow BOTH does the centring.
	_boss_box.position = Vector2(0, BOSS_TOP)
	_boss_box.custom_minimum_size = Vector2(280, 0)
	_boss_box.add_theme_constant_override("separation", 3)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	_root.add_child(_boss_box)

	var header := HBoxContainer.new()
	_boss_name = Label.new()
	_boss_name.text = "THE GNOMON"
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name.add_theme_font_size_override("font_size", 13)
	_boss_name.add_theme_color_override("font_color", Palette.THREAT)
	header.add_child(_boss_name)

	_boss_state = Label.new()
	_boss_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_state.add_theme_font_size_override("font_size", 11)
	_boss_state.add_theme_color_override("font_color", Palette.AMBER_DIM)
	header.add_child(_boss_state)
	_boss_box.add_child(header)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(280, 9)
	track.color = Color(0.28, 0.03, 0.12, 0.85)
	_boss_box.add_child(track)

	_boss_fill = ColorRect.new()
	_boss_fill.color = Palette.THREAT
	_boss_fill.anchor_bottom = 1.0
	track.add_child(_boss_fill)

	_boss_plates = HBoxContainer.new()
	_boss_plates.add_theme_constant_override("separation", 4)
	_boss_plates.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_box.add_child(_boss_plates)
	for i in range(5):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(46, 5)
		pip.color = Palette.AMBER_DIM
		_boss_plates.add_child(pip)


func set_boss_status(status: Dictionary) -> void:
	if not bool(status.get("active", false)):
		_boss_box.visible = false
		return
	_boss_box.visible = true
	_boss_name.text = "%s  ·  PHASE %d/%d" % [
		String(status.get("name", "APEX")),
		int(status.get("phase", 1)), int(status.get("phase_total", 3))]
	_boss_state.text = String(status.get("state", ""))
	_boss_fill.size.x = 280.0 * clampf(float(status.get("hp", 1.0)), 0.0, 1.0)

	# Plate pips: gold = open (damage flows), magenta = welded shut. Only as many
	# pips as the boss actually has plates.
	var open := int(status.get("open", 0))
	var plates := int(status.get("plates", _boss_plates.get_child_count()))
	for i in range(_boss_plates.get_child_count()):
		var pip := _boss_plates.get_child(i) as ColorRect
		pip.visible = i < plates
		pip.color = Palette.GOLD if i < open else Color(1.0, 0.13, 0.45, 0.55)


func _build_parley_button() -> void:
	# One transient action, not a console. 14 excludes consoles from raid
	# starts, so a raid that opened a sheet would deadlock its own eligibility
	# rule — and a demand with a six-second fuse belongs on the screen, not
	# behind a tab.
	_parley_button = Button.new()
	_parley_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_parley_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_parley_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# SYMMETRIC OFFSETS, not position.x = 0. A container with grow BOTH recentres
	# itself around its anchor when you set position.x to zero — which is why the
	# dock and the tutorial card do exactly that and land dead centre. A Button
	# carrying an explicit custom_minimum_size does not: it kept its left edge on
	# the anchor and sat half a... four pixels right of true centre, which BAND
	# CENTRED caught the moment the notification surfaces were added to the probe.
	# Stating both offsets leaves nothing to infer. Note this is NOT the
	# double-compensation bug the probe exists for — that was a manual offset ON
	# TOP of grow-BOTH's own centring; this replaces it.
	_parley_button.custom_minimum_size = Vector2(PARLEY_WIDTH, PARLEY_HEIGHT)
	_parley_button.offset_left = -PARLEY_WIDTH * 0.5
	_parley_button.offset_right = PARLEY_WIDTH * 0.5
	# Y IS THE BOTTOM EDGE, matching every other element in this band ("all
	# bottom-centre elements use grow_vertical = BEGIN, so each y is its bottom
	# edge"). Writing offset_top = PARLEY_BOTTOM instead made -252 the TOP edge,
	# so the button grew DOWNWARD into the crack gauge — the exact 9px overlap
	# the reflow was supposed to remove, reintroduced by the fix for a different
	# bug. BANDS CLEAR caught it.
	_parley_button.offset_top = PARLEY_BOTTOM - PARLEY_HEIGHT
	_parley_button.offset_bottom = PARLEY_BOTTOM
	_parley_button.add_theme_font_size_override("font_size", 14)
	_parley_button.add_theme_color_override("font_color", Palette.GOLD)
	_parley_button.visible = false
	_parley_button.pressed.connect(func() -> void:
		var m := get_tree().get_first_node_in_group("main")
		if m and m.has_method("pay_toll"):
			m.pay_toll())
	_root.add_child(_parley_button)

	_bluff_button = Button.new()
	_bluff_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bluff_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bluff_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bluff_button.custom_minimum_size = Vector2(PARLEY_WIDTH, PARLEY_HEIGHT)
	_bluff_button.offset_left = -PARLEY_WIDTH * 0.5
	_bluff_button.offset_right = PARLEY_WIDTH * 0.5
	# Directly above the toll button, in the band the tutorial card owns — which
	# is free during a raid for the same reason parley may sit there at all.
	_bluff_button.offset_top = BLUFF_BOTTOM - PARLEY_HEIGHT
	_bluff_button.offset_bottom = BLUFF_BOTTOM
	_bluff_button.add_theme_font_size_override("font_size", 13)
	_bluff_button.add_theme_color_override("font_color", Palette.TEAL)
	_bluff_button.visible = false
	_bluff_button.pressed.connect(func() -> void:
		var m := get_tree().get_first_node_in_group("main")
		if m and m.has_method("run_bluff"):
			m.run_bluff())
	_root.add_child(_bluff_button)


func show_parley(toll: int, bluff_odds := 0.0) -> void:
	_parley_button.text = "PAY THE TOLL — %d IN CARGO" % toll
	_parley_button.visible = true
	# The odds go ON the button. 12's standard: an honest bad bet you can see is a
	# thing to do; a hidden one is a con — and a bluff whose chance the player
	# cannot read would be exactly the paid random reveal the lab refused.
	_bluff_button.visible = bluff_odds > 0.0
	if bluff_odds > 0.0:
		_bluff_button.text = "BLUFF — %d%%  (BURNS THE MANIFEST)" % int(bluff_odds * 100.0)


func hide_parley() -> void:
	_parley_button.visible = false
	_bluff_button.visible = false


func bluff_text() -> String:
	return _bluff_button.text


func _build_pause_button() -> void:
	# Top-right corner, small and quiet. Deliberately not a RoundButton: those
	# are the three big diegetic controls the game is played with, and pausing is
	# not one of them.
	pause_button = Button.new()
	pause_button.text = "| |"
	pause_button.flat = true
	pause_button.custom_minimum_size = Vector2(40, 34)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pause_button.position = Vector2(-58, 22)
	pause_button.add_theme_font_size_override("font_size", 15)
	pause_button.add_theme_color_override("font_color", Palette.AMBER)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(pause_button)


func _build_contract_tracker() -> void:
	# Quiet, top-right, under the pause button and where resource pills would sit.
	_contract_box = VBoxContainer.new()
	_contract_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_contract_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_contract_box.position = Vector2(-232, 62)
	_contract_box.custom_minimum_size = Vector2(206, 0)
	_contract_box.add_theme_constant_override("separation", 6)
	_contract_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_contract_box)


func _build_banners() -> void:
	_arrival_label = Label.new()
	_arrival_label.set_anchors_preset(Control.PRESET_CENTER)
	_arrival_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arrival_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_arrival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival_label.add_theme_color_override("font_color", Palette.GOLD)
	_arrival_label.add_theme_font_size_override("font_size", 26)
	_arrival_label.modulate.a = 0.0
	_arrival_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_arrival_label)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.position = Vector2(0, TOAST_ENTER)
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_label)


func refresh_cargo() -> void:
	var used := GameState.cargo_used()
	var cap := GameState.cargo_capacity()
	_cargo_label.text = "HOLD %d/%d" % [used, cap]
	_cargo_label.add_theme_color_override("font_color",
		Palette.THREAT if used >= cap else Palette.AMBER_DIM)


func cargo_text() -> String:
	# What the readout ACTUALLY SAYS, for the harness. Deliberately the rendered
	# string rather than a recomputation of it: an assertion that recomputed
	# "HOLD %d/%d" from GameState would agree with itself while the label on
	# screen showed a hold the player emptied ten seconds ago, which is the exact
	# defect THE READOUT FOLLOWS THE HOLD exists to catch.
	return _cargo_label.text if _cargo_label != null else ""


func gain_cargo(good: String) -> void:
	refresh_cargo()
	_gain_label.text = "+1 %s" % CommodityDB.short_name(good)
	_gain_label.add_theme_color_override("font_color", CommodityDB.color_of(good))
	_gain_label.position = Vector2(30, 104)
	_gain_label.modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gain_label, "position:y", 84.0, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gain_label, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)


func set_system_tag(text: String) -> void:
	_system_base = text
	# The short name is what survives leaving. "PYX-01 :: DERELICT FIELD" names a
	# charted volume, and the derelict field is precisely the thing that stops
	# being where you are the moment you cross its edge.
	_system_short = text.split(" ::")[0]
	_apply_system_tag()


func set_deep_tag(band_name: String, out_distance: float) -> void:
	# band_name "" means inside the charted system, where this whole readout
	# collapses back to exactly the string it has always shown.
	if band_name == _deep_band and absf(out_distance - _deep_out) < 1.0:
		return
	_deep_band = band_name
	_deep_out = out_distance
	_apply_system_tag()


func refresh_palette() -> void:
	# The HUD is code-drawn, so unlike the world it does not need rebuilding --
	# it needs re-asking, and only in one place. The band tag is the only chrome
	# holding a band colour in a theme override; the radar reads Palette inside
	# its own _draw and is already redrawing every frame.
	_apply_system_tag()


func _apply_system_tag() -> void:
	if _deep_band == "":
		_system_label.text = "SYS // " + _system_base
		_system_label.add_theme_color_override("font_color", SYSTEM_TAG_HOME)
		return
	# Out here the answer to "where am I" is the band and the range, not the
	# system's name — but which system's expanse it is still matters, because you
	# can warp between them, so the short name stays.
	# The glyph carries the band without colour. Colour is still the fastest read
	# at a glance, but it was the ONLY one -- and the deep set is amber, rose,
	# violet and bile, which is close to a worst case for the two most common
	# forms of colour blindness. A glyph works in every vision mode, in
	# greyscale, and on a phone in direct sunlight, which no palette does.
	var band := DeepSpace.band_of(_deep_out)
	_system_label.text = "SYS // %s · %s %s · %du OUT" % [
		_system_short, Palette.band_glyph(band), _deep_band, int(round(_deep_out))]
	var c: Color = Palette.band_color(band)
	_system_label.add_theme_color_override("font_color", Color(c.r, c.g, c.b, 0.75))


func show_broadcast(from_line: String, body: String, color: Color) -> void:
	# An incoming transmission, not a toast. It gets a plate and a sender because
	# out past the chart the only voice left is a recording, and a recording that
	# looked like every other status message would read as one.
	_broadcast_from.text = "◄ %s ►" % from_line
	_broadcast_from.add_theme_color_override("font_color", color)
	_broadcast_body.text = body
	_broadcast_box.visible = true
	_broadcast_box.modulate.a = 0.0
	var style := _broadcast_box.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(color.r, color.g, color.b, 0.55)
	Sfx.play("equip", -12.0, 0.7)
	# Kill the previous one first. Its tail ends in `visible = false`, so two
	# broadcasts in quick succession — crossing two bands in one run, which is
	# exactly what a long outward flight does — had the first one's callback
	# hiding the second. Same shape as the dock tween that outlived undock().
	if _broadcast_tween != null and _broadcast_tween.is_valid():
		_broadcast_tween.kill()
	var tw := create_tween()
	_broadcast_tween = tw
	tw.tween_property(_broadcast_box, "modulate:a", 1.0, 0.45)
	tw.tween_interval(6.2)
	tw.tween_property(_broadcast_box, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: _broadcast_box.visible = false)


func broadcast_text() -> String:
	return _broadcast_body.text if _broadcast_box.visible else ""


func system_tag_text() -> String:
	return _system_label.text


func radar() -> RadarLayer:
	return _radar


func has_home_marker() -> bool:
	for m in _radar.markers:
		if int(m.get("tier", RadarLayer.TIER_HOSTILE)) == RadarLayer.TIER_HOME:
			return true
	return false


func show_arrival(text: String) -> void:
	_arrival_label.text = text
	_arrival_label.modulate.a = 0.0
	_arrival_label.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_arrival_label, "modulate:a", 1.0, 0.35)
	tw.tween_property(_arrival_label, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(_arrival_label, "modulate:a", 0.0, 0.6)


func show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.modulate.a = 0.0
	_toast_label.position.y = TOAST_ENTER
	# Kill the previous toast first — the same fix show_broadcast already carries,
	# arrived at the same way. Two toasts in quick succession left both tweens
	# driving one label, and the FIRST one's fade tail put the second back to
	# alpha 0 mid-read. The pair that fires back to back today is "READ AS X"
	# followed by the ARCHEOLOGY tier-up, so the announcement 19 says must not
	# arrive in silence was the one being clipped.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	var tw := create_tween()
	_toast_tween = tw
	tw.set_parallel(true)
	tw.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	tw.tween_property(_toast_label, "position:y", TOAST_REST, 0.5).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(TOAST_HOLD)
	tw.chain().tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func set_contracts(rows: Array) -> void:
	for child in _contract_box.get_children():
		child.queue_free()
	for row in rows:
		var line := Label.new()
		line.text = "%s  %d/%d" % [row["title"], row["progress"], row["target"]]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_theme_font_size_override("font_size", 11)
		var done: bool = int(row["progress"]) >= int(row["target"])
		line.add_theme_color_override("font_color", Palette.GOLD if done else Palette.AMBER_DIM)
		_contract_box.add_child(line)


func _build_action_dock() -> void:
	# One cluster, always the same width, always at the bottom centre.
	#
	# The rule this encodes: INFORMATION lives at the edges, because you glance
	# at it and spreading costs nothing; ACTIONS live in one cluster, because you
	# reach for them and spreading costs travel. Corner-anchoring the three
	# controls put CHART and the ability button 1900px apart on a full-screen
	# Mac — two things pressed in the same breath, at opposite ends of the desk.
	#
	# The dock is sized by its contents, so it is identical on a phone and a 4K
	# monitor and needs no clamp of its own.
	_dock = PanelContainer.new()
	_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dock.position = Vector2(0, -DOCK_BOTTOM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.86)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.35)
	style.border_width_top = 2
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_dock.add_theme_stylebox_override("panel", style)
	_root.add_child(_dock)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock.add_child(row)

	chart_button = RoundButton.new()
	chart_button.label = "CHART"
	chart_button.accent = Palette.GOLD
	chart_button.pressed.connect(func() -> void: chart_pressed.emit())
	row.add_child(chart_button)

	# Centred and slightly larger: the ability is the button pressed under
	# pressure, so it gets the position the eye returns to and the biggest target.
	ability_button = RoundButton.new()
	ability_button.label = "ABILITY"
	ability_button.accent = Palette.TEAL
	ability_button.radius_scale = ABILITY_SCALE
	ability_button.pressed.connect(_on_ability_pressed)
	row.add_child(ability_button)

	refit_button = RoundButton.new()
	refit_button.label = "REFIT"
	refit_button.accent = Palette.AMBER
	refit_button.pressed.connect(func() -> void: refit_pressed.emit())
	row.add_child(refit_button)


func _on_ability_pressed() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("activate_ability"):
		player.activate_ability()


func set_panels_locked(locked: bool) -> void:
	# THE HOLD IS DELIBERATELY ABSENT FROM THIS, and it is not an oversight to
	# tidy up later. Two callers reach here -- docking and a boss fight -- and
	# the hold must stay reachable in both. During a fight because the apex wreck
	# seeds 13 units of cargo among its spill and a full hold cannot take it, so
	# dumping ore to make room is a real play; while docked because the bonded
	# stash exit is a docked flow and locking it would put the exit behind the
	# lock. Refit rewrites the fight's premise, which is why IT is locked; the
	# hold only shows you what you are carrying.
	# Console access is closed during a boss fight: refitting mid-encounter
	# would let the player rewrite the fight's premise (and used to be an
	# outright exploit — see PlayerShip._apply_fit).
	refit_button.enabled = not locked
	chart_button.enabled = not locked


func _process(_delta: float) -> void:
	# Ahead of the player lookup: an abandoned hold has to finish draining even
	# on the frames where there is no ship to poll, or it freezes half-full.
	_tick_crack(_delta)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("ability_info"):
		return
	# Hull readout, from the same poll that already drives the ability button.
	var frac := 1.0
	if player.has_method("shield_fraction"):
		frac = float(player.shield_fraction())
	_hull_label.text = "HULL %d%%" % int(round(frac * 100.0))
	_hull_label.add_theme_color_override("font_color",
		Palette.TEAL if frac > 0.6 else (Palette.AMBER if frac > 0.25 else Palette.THREAT))

	var info: Dictionary = player.ability_info()
	if info.is_empty():
		ability_button.visible = false
		return
	ability_button.visible = true
	ability_button.label = String(info.get("name", "ABILITY"))
	ability_button.accent = Palette.AMBER if String(info.get("accent", "")) == "amber" else Palette.TEAL
	ability_button.cooldown_fraction = player.ability_cooldown_fraction()
	ability_button.enabled = player.ability_ready()
	ability_button.glowing = player.ability_active()


func _build_broadcast() -> void:
	# Top-centre, under the arrival banner's band and well clear of the dock. It
	# is information, so by the rule in section 15 it may sit at an edge — but it
	# is information you are meant to READ, so it gets a plate and a width cap
	# rather than free rein across an ultrawide.
	_broadcast_box = PanelContainer.new()
	_broadcast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_broadcast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_broadcast_box.grow_vertical = Control.GROW_DIRECTION_END
	_broadcast_box.position = Vector2(0, BROADCAST_TOP)
	_broadcast_box.custom_minimum_size = Vector2(430, 0)
	_broadcast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_broadcast_box.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.9)
	style.border_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.55)
	style.border_width_left = 2
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_broadcast_box.add_theme_stylebox_override("panel", style)
	_root.add_child(_broadcast_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_broadcast_box.add_child(col)

	_broadcast_from = Label.new()
	_broadcast_from.add_theme_font_size_override("font_size", 12)
	_broadcast_from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_broadcast_from)

	_broadcast_body = Label.new()
	_broadcast_body.add_theme_font_size_override("font_size", 14)
	_broadcast_body.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	_broadcast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_broadcast_body.custom_minimum_size = Vector2(400, 0)
	col.add_child(_broadcast_body)


func _build_crack_gauge() -> void:
	_crack_box = VBoxContainer.new()
	_crack_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_crack_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crack_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# See _build_tutorial_card: x=0 because grow BOTH does the centring.
	_crack_box.position = Vector2(0, -190)
	_crack_box.custom_minimum_size = Vector2(220, 0)
	_crack_box.visible = false
	_crack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crack_box)

	var label := Label.new()
	label.text = "BREACHING HULL"
	_crack_label = label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Palette.AMBER)
	label.add_theme_font_size_override("font_size", 14)
	_crack_box.add_child(label)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(220, 7)
	track.color = Color(0.96, 0.65, 0.14, 0.18)
	_crack_box.add_child(track)

	_crack_fill = ColorRect.new()
	_crack_fill.color = Palette.AMBER
	_crack_fill.anchor_bottom = 1.0
	_crack_fill.offset_right = 0.0
	track.add_child(_crack_fill)


func set_value(v: int) -> void:
	var tw := create_tween()
	tw.tween_method(_show, _shown_value, float(v), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var pop := create_tween()
	pop.tween_property(_value_label, "scale", Vector2(1.12, 1.12), 0.07)
	pop.tween_property(_value_label, "scale", Vector2.ONE, 0.18)


func gain(amount: int) -> void:
	# Batch rapid pickups into a single readable "+N".
	_pending_gain += amount
	if _gain_timer == null:
		_gain_timer = get_tree().create_timer(0.25)
		_gain_timer.timeout.connect(_flush_gain)


func _flush_gain() -> void:
	var amount := _pending_gain
	_pending_gain = 0
	_gain_timer = null
	if amount <= 0:
		return
	_gain_label.text = "+%s" % _format(amount)
	_gain_label.add_theme_color_override("font_color", Palette.GOLD)
	_gain_label.position = Vector2(30, 104)
	_gain_label.modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gain_label, "position:y", 84.0, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gain_label, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)


func prompt(text: String) -> void:
	if _prompt_label.text == text and _prompt_label.modulate.a > 0.5:
		return
	_prompt_label.text = text
	var tw := create_tween()
	tw.tween_property(_prompt_label, "modulate:a", 1.0, 0.2)


func clear_prompt() -> void:
	var tw := create_tween()
	tw.tween_property(_prompt_label, "modulate:a", 0.0, 0.25)


func clear_prompt_if(text: String) -> void:
	# Only clears if the prompt is still the one the caller set, so a bark
	# timing out never wipes a live gameplay prompt.
	if _prompt_label.text == text:
		clear_prompt()


func crack_progress(t: float, label := "BREACHING HULL") -> void:
	# The label is a default parameter rather than a second gauge: every existing
	# caller stays valid untouched, and a survey hold reads as the same verb with
	# a different noun, which is what it is.
	if _crack_label:
		_crack_label.text = label
	if t < 0.0:
		# Releasing drains rather than disappears. The gauge used to vanish on the
		# frame the finger lifted, which read as the UI glitching rather than as
		# the hold being abandoned -- and abandoning a hold is a decision the
		# player made, so it should be something they watch happen.
		_crack_releasing = _crack_box.visible
		return
	_crack_releasing = false
	_crack_box.visible = true
	_crack_shown = clampf(t, 0.0, 1.0)
	_crack_fill.size.x = 220.0 * _crack_shown
	_crack_box.modulate.a = 1.0


func _tick_crack(delta: float) -> void:
	if not _crack_releasing:
		return
	_crack_shown = Smoothing.toward(_crack_shown, 0.0, CRACK_DRAIN, delta)
	_crack_fill.size.x = 220.0 * _crack_shown
	_crack_box.modulate.a = clampf(_crack_shown / 0.35, 0.0, 1.0)
	if _crack_shown <= 0.02:
		_crack_releasing = false
		_crack_shown = 0.0
		_crack_box.visible = false
		_crack_box.modulate.a = 1.0


func _show(v: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if absf(v - _shown_value) > 0.5 and now - _last_tick > TICK_INTERVAL:
		_last_tick = now
		Sfx.play("count", -20.0, 1.0, 0.03)
	_shown_value = v
	_value_label.text = _format(int(v))


func _format(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
