class_name DeepField
extends Node3D
# An endless star layer. `count` instances live in a box of side 2*half that is
# always centred on the camera, so the field can never run out however far the
# player flies.
#
# The motion is split in two, and that split is the whole trick:
#
#   * the NODE position carries the continuous parallax and moves every frame;
#   * the INSTANCE transforms carry the wrap and are rebaked only once the camera
#     has travelled `rebake_step`.
#
# The two are algebraically exact against each other. The target world position
# of star i is `cam + wrapf(base_i - P*cam, ±half)`. Between rebakes the node
# holds `cam*(1-P) + baked*P` and the instance holds `wrapf(base_i - baked*P)`,
# which sum to the unwrapped target; at a rebake the node becomes exactly `cam`
# and the instances are re-wrapped, and the two changes cancel except for the
# wrap itself. So the only discontinuity a star ever experiences is a jump of
# exactly 2*half — and half is far past anything the lens can see, so it always
# happens off screen.
#
# Cost is therefore one Vector3 assignment per frame, with a ~500-instance
# rebake roughly every 1.7 seconds at cruising speed.
#
#   parallax 1.0 = world-locked (what the per-system starfield already is)
#   parallax 0.0 = glued to the lens, i.e. infinitely far away

const Y_MIN := -46.0
const Y_MAX := -8.0

var parallax := 0.30
var half := 120.0
var rebake_step := 10.0

var _mm: MultiMesh
var _mat: StandardMaterial3D
var _tint := Color.WHITE
var _base := PackedVector3Array()
var _baked := Vector3.ZERO


func build(count: int, tint: Color, radius: float, seed_value: int) -> void:
	# Seeded off the system id, so the same expanse looks the same on every visit
	# without a single byte of save data.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_tint = tint

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	_mat = Palette.emissive(tint, 1.6)
	mesh.material = _mat

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = count

	_base.resize(count)
	for i in range(count):
		_base[i] = Vector3(rng.randf_range(-half, half),
			rng.randf_range(Y_MIN, Y_MAX), rng.randf_range(-half, half))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	# Pinned: the engine would otherwise recompute bounds on every rebake, which
	# is the one per-instance cost that cannot be amortised away.
	mmi.custom_aabb = AABB(Vector3(-half, Y_MIN, -half),
		Vector3(half * 2.0, Y_MAX - Y_MIN, half * 2.0))
	add_child(mmi)
	_rebake(Vector3.ZERO)


func follow(cam: Vector3) -> void:
	var flat := Vector3(cam.x, 0.0, cam.z)
	if flat.distance_to(_baked) >= rebake_step:
		_rebake(flat)
	global_position = flat * (1.0 - parallax) + _baked * parallax


func _rebake(centre: Vector3) -> void:
	_baked = centre
	for i in range(_mm.instance_count):
		var b := _base[i]
		var p := Vector3(
			wrapf(b.x - centre.x * parallax, -half, half),
			b.y,
			wrapf(b.z - centre.z * parallax, -half, half))
		# Size from the base position rather than the RNG, so a rebake never
		# changes how big a given star is.
		var s := 0.5 + fmod(absf(b.x + b.z), 1.1)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))


func set_presence(k: float) -> void:
	# Fades by walking the colour toward the background rather than by turning on
	# alpha: hundreds of tiny transparent spheres would cost a sorted pass on the
	# mobile renderer for a layer nobody ever looks at directly.
	var c := Palette.SPACE_BG.lerp(_tint, clampf(k, 0.0, 1.0))
	_mat.albedo_color = c
	_mat.emission = Color(c.r, c.g, c.b)


func nearest_instance_distance(from: Vector3) -> float:
	# Harness support: proves the field actually wrapped rather than being left
	# behind at the origin.
	var best := INF
	for i in range(_mm.instance_count):
		var p: Vector3 = global_position + _mm.get_instance_transform(i).origin
		best = minf(best, Vector2(p.x - from.x, p.z - from.z).length())
	return best
