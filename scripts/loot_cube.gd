class_name LootCube
extends Node3D
# Gold salvage cube: spills outward on spawn, then magnet-vacuums into the
# player ship. Credits salvage to Main on collection.

const MAGNET_ACCEL := 34.0
const MAGNET_SPEED := 16.0
const COLLECT_DIST := 0.85
const SEEK_ALWAYS_AFTER := 1.3

var _vel := Vector3.ZERO
var _age := 0.0
var _spin_axis := Vector3.UP
var value := 0

# Set before adding to the tree to make this a commodity crate instead of plain
# salvage. Crates are what tie combat to the market: every kind of fight
# produces something some port wants.
var commodity := ""

# Set below 1.0 by spawners whose payout should be discounted — currently only a
# repeat apex kill, which keeps the first-kill bonus special without making the
# fight pointless to replay.
var repeat_mult := 1.0

# SPILLED CARGO, not a fresh drop. Three stock behaviours are wrong for it, and
# each one silently deletes the mechanic rather than crashing:
#
#   * the 25s reaper would evaporate the spill long before the player, who is
#     offline ~2.4s and then has to fly back from the spawn point, arrives;
#   * SEEK_ALWAYS_AFTER homes from ANY distance, so the spill would chase the
#     dying ship across four hundred units to the respawn and hand itself back;
#   * collection during the warp-out would let the corpse vacuum its own cargo
#     in the 0.64s before the position tween fires.
#
# A flag rather than a subclass: 17's "parameters, not new classes".
var spill := false

# §111. Minted by an open shear. RIFT-WORK's one feed counts these on pickup --
# a flag rather than a subclass, spill's own reasoning one comment up, and a
# separate flag from `spill` because a death-spill is recovery, not a claim.
var from_rift := false


func place_at(pos: Vector3) -> void:
	# Cubes are added to the tree first and positioned after, so _ready runs at
	# the origin. Without the reset an interpolated cube spends its first frame
	# drawn somewhere along the line from the system centre to where it actually
	# spawned -- most visible in exactly the moment cubes matter, a hold breach
	# scattering a dozen of them at once.
	global_position = pos
	reset_physics_interpolation()


func _ready() -> void:
	# Magnets toward the ship on the fixed tick, and usually does it in clusters
	# the eye is already tracking. See project.godot's [physics] comment.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var system_mult := 1.0
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("loot_mult"):
		system_mult = main.loot_mult()
	# Phase 2 rebalance: was 80-140. A standard run used to buy nearly the whole
	# catalog with change left over, which made the fitting console a shopping
	# list rather than a set of choices. Halving the cube and roughly doubling
	# prices (see ModuleDB) puts one mid-tier module inside an eight-minute loop
	# and the full catalog several sessions out. Asserted by PYXIS_PACINGTEST.
	value = int(randi_range(34, 60) * float(GameState.stats.get("salvage_mult", 1.0))
		* system_mult * repeat_mult)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var is_crate := CommodityDB.exists(commodity)
	box.size = Vector3.ONE * (0.34 if is_crate else 0.24)
	mi.mesh = box
	mi.material_override = Palette.emissive(
		CommodityDB.color_of(commodity) if is_crate else Palette.GOLD, 2.2)
	add_child(mi)

	var ang := randf() * TAU
	_vel = Vector3(cos(ang), 0, sin(ang)) * randf_range(2.5, 5.5)
	_spin_axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# Pop into existence rather than blinking in.
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _physics_process(delta: float) -> void:
	_age += delta
	rotate(_spin_axis, delta * 4.0)

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if _age > 0.35 and player:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		# A protected ship is one that is warping, docked, in its grace window or
		# invulnerable — never a ship that should be picking anything up.
		if dist < COLLECT_DIST and not (spill and player.is_protected()):
			_collect(player)
			return
		# Close cubes snap in immediately; anything still loose after the
		# scatter beat homes from any distance so no salvage is ever stranded.
		var magnet_range := float(GameState.stats.get("magnet_range", 6.0))
		if dist < magnet_range or (not spill and _age > SEEK_ALWAYS_AFTER):
			_vel = _vel.move_toward(to_player.normalized() * MAGNET_SPEED, MAGNET_ACCEL * delta)
		else:
			_vel = _vel.move_toward(Vector3.ZERO, 3.0 * delta)
	else:
		_vel = _vel.move_toward(Vector3.ZERO, 3.0 * delta)

	global_position += _vel * delta
	if not spill and _age > 25.0:
		queue_free()


func _collect(player: Node3D) -> void:
	var main := get_tree().get_first_node_in_group("main")

	if CommodityDB.exists(commodity):
		if GameState.load_cargo(commodity, 1) > 0:
			# §111. RIFT-WORK's feed: a crate CLAIMED -- loaded, not scrapped.
			# The hold-full path below pays credits and pays this nothing, the
			# same line the seam draws between a cut and a sale.
			if from_rift:
				GameState.mark_skill("rift_work")
			FX.flash(get_parent(), player.global_position + Vector3(0, 0.3, 0),
				CommodityDB.color_of(commodity), 0.7, 0.16)
			Sfx.play_streak("pickup", -12.0)
			if main and main.hud:
				main.hud.gain_cargo(commodity)
			# The one line that introduces the whole loop. Fired on the first
			# unreadable thing that comes aboard, because until then there is no
			# reason for the player to open REFIT looking for a reader.
			if CommodityDB.is_salvage(commodity):
				Barks.fire("first_salvage")
			queue_free()
			return
		# Hold full: break the crate down rather than blocking pickup, so the
		# vacuum never stalls and the player is told why.
		Barks.fire("hold_full")
		if main and main.hud:
			main.hud.show_toast("HOLD FULL — %s SCRAPPED" % CommodityDB.short_name(commodity),
				Palette.THREAT)
		value = int(CommodityDB.base_price(commodity) * 0.5)

	FX.flash(get_parent(), player.global_position + Vector3(0, 0.3, 0), Palette.GOLD, 0.6, 0.15)
	Sfx.play_streak("pickup", -13.0)
	if main and main.has_method("add_salvage"):
		main.add_salvage(value)
	queue_free()
