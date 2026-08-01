class_name Torpedo
extends Node3D
# A slow projectile with an area detonation — the first weapon in the game that
# is not an instant hit.
#
# It aims at where the target IS, not where it will be, and takes 0.7s to get
# there. That single decision is the whole family's identity: a strafing swarm
# fighter at 7.5u/s simply is not there any more when it lands, while a sentry
# holding station, a probe welded to the Gnomon's shell, or a clustered pack all
# eat it. Torpedoes are the answer to "several things standing still together",
# and they are the wrong answer to everything else.
#
# The flight is a tween over a hand-built arc, not physics: this codebase has no
# physics (see obstacles.gd), and a projectile that integrated its own motion
# would be the only thing in the game that did.

const FLIGHT_TIME := 0.7
const ARC_HEIGHT := 1.1          # how far off the play plane the arc bulges
const STEPS := 14                # arc samples, purely visual
const SURFACE_STANDOFF := 0.35   # how far short of a struck surface it goes off

var damage := 90.0
var splash_radius := 2.2
var origin := Vector3.ZERO
var destination := Vector3.ZERO
# WHO FIRED IT (v18). A torpedo outlives its launch by 0.7 seconds of flight,
# so unlike a hitscan weapon it cannot ask "who is shooting" at the moment it
# lands — the shooter has to be carried. Set by the launcher before add_child,
# same contract as `damage`. Null is legal and means an unattributed blast:
# it damages, and it pays nobody.
var shooter: Node3D = null

var _mat: StandardMaterial3D


func launch(from: Vector3, to: Vector3) -> void:
	origin = from
	origin.y = 0.0
	destination = to
	destination.y = 0.0


func _ready() -> void:
	_build_mesh()
	global_position = origin
	_fly()


func _build_mesh() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.11
	cm.height = 0.48
	cm.radial_segments = 8
	cm.rings = 2
	body.mesh = cm
	body.rotation_degrees.x = 90.0
	_mat = Palette.emissive(Palette.AMBER, 2.4)
	body.material_override = _mat
	add_child(body)

	var trail := CPUParticles3D.new()
	trail.amount = 26
	trail.lifetime = 0.4
	trail.local_coords = false
	trail.direction = Vector3.ZERO
	trail.spread = 18.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.7
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.05
	trail.scale_amount_max = 0.18
	trail.color = Palette.AMBER
	var pm := SphereMesh.new()
	pm.radius = 0.1
	pm.height = 0.2
	pm.radial_segments = 6
	pm.rings = 3
	pm.material = Palette.emissive(Palette.AMBER, 2.0)
	trail.mesh = pm
	add_child(trail)


func _fly() -> void:
	# Cover is tested ONCE over the whole path, exactly like a beam.
	#
	# It is tempting to test each arc segment instead, and it silently does not
	# work: Obstacles.blocked() ignores any sphere containing either end of the
	# segment — the rule that keeps the apex boss shootable while embedded in its
	# own hull sphere — so once a stepped path enters a rock, every subsequent
	# segment has an endpoint inside it and reports clear. A torpedo checked that
	# way flies straight through moons.
	var obstruction = Obstacles.blocked(origin, destination)
	var on_target := obstruction == null
	if not on_target:
		# Stop just short of the surface rather than on it. On it, the detonation
		# point sits exactly at radius, and the per-victim check below would treat
		# the rock as "contains an endpoint" and wave the splash straight through.
		var inward := (destination - origin).normalized()
		destination = _flat(obstruction) - inward * SURFACE_STANDOFF

	var tw := create_tween()
	for i in range(1, STEPS + 1):
		var t := float(i) / float(STEPS)
		var point := origin.lerp(destination, t)
		point.y = sin(t * PI) * ARC_HEIGHT
		tw.tween_property(self, "global_position", point, FLIGHT_TIME / float(STEPS))
	tw.tween_callback(func() -> void: _detonate())


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _detonate() -> void:
	var parent := get_parent()
	var pos := _flat(global_position)

	FX.flash(parent, pos, Palette.WHITE_HOT, 2.2, 0.18)
	FX.shockwave(parent, pos, Palette.AMBER, splash_radius * 2.0, 0.5)
	FX.burst(parent, pos, Color(1.0, 0.6, 0.2), 34, splash_radius * 2.4, 0.22, 0.6)
	Sfx.play("explode", -8.0, 1.15)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.09)

	# The blast always happens, wherever the shell stopped — including against a
	# rock it was fired into. Whether that blast reaches anything is decided per
	# victim by the same line-of-sight rule every weapon obeys, so "it went off
	# early on the near side of a moon" needs no special case: the thing hiding
	# behind the moon is simply not in line with the explosion.
	var r2 := splash_radius * splash_radius
	for node in get_tree().get_nodes_in_group("hostiles"):
		var n := node as Node3D
		if not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var offset := _flat(n.global_position) - pos
		if offset.length_squared() > r2:
			continue
		if Obstacles.blocked(pos, n.global_position) != null:
			continue
		# Falls off to 45% at the rim, so landing it in the middle of a pack is
		# meaningfully better than clipping the edge of one.
		var falloff := 1.0 - 0.55 * (offset.length() / maxf(splash_radius, 0.01))
		n.take_damage(damage * falloff, shooter)
	queue_free()
