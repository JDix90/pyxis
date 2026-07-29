class_name TargetMarker
extends Node3D
# A ring locked to whatever the ship is currently shooting.
#
# Until now nothing on screen said what the target was — you inferred it from
# where the beams went. That was survivable when every target was chosen by
# tapping it, but Tab-cycling makes the gap obvious, and it helps on touch too.

const SPIN_SPEED := 1.4

var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _ticks: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.ring_segments = 32
	_ring.mesh = torus
	_mat = Palette.emissive(Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.85), 2.4)
	_ring.material_override = _mat
	add_child(_ring)

	# Four corner ticks so the marker reads as a reticle, not a decal.
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var tick := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.06, 0.34)
		tick.mesh = bm
		tick.position = Vector3(cos(ang), 0, sin(ang)) * 1.25
		tick.rotation.y = -ang
		tick.material_override = _mat
		add_child(tick)
		_ticks.append(tick)

	visible = false


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		visible = false
		return
	# Read untyped and validate before binding: a target freed earlier this
	# frame is still referenced by the ship, and assigning a freed instance to a
	# typed variable throws every frame.
	var candidate = player.attack_target
	if not is_instance_valid(candidate):
		visible = false
		return
	var target := candidate as Node3D

	visible = true
	global_position = target.global_position
	_t += delta
	rotation.y = _t * SPIN_SPEED

	# Size to the thing being marked so a swarm dart and the Gnomon both read.
	var radius := 1.0
	if target is ApexBoss:
		radius = 3.4
	elif target is Hostile:
		radius = 1.5
	elif target is SwarmHostile:
		radius = 0.75
	var pulse := 1.0 + sin(_t * 4.0) * 0.04
	scale = Vector3.ONE * radius * pulse
