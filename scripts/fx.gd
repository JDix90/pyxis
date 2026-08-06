class_name FX
extends Object
# Presentational one-shots: beams, bursts, ring pulses, flashes.
# All are fire-and-forget nodes added under `parent` and self-freeing.


static func beam(parent: Node3D, from: Vector3, to: Vector3, color: Color, width := 0.06, life := 0.12) -> void:
	if from.distance_to(to) < 0.05:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, from.distance_to(to))
	mi.mesh = box
	mi.material_override = Palette.emissive(color, 3.5)
	parent.add_child(mi)
	var mid := (from + to) * 0.5
	mi.look_at_from_position(mid, to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), life)
	tw.tween_callback(mi.queue_free)


static func burst(parent: Node3D, pos: Vector3, color: Color, count := 40, speed := 7.0, size := 0.22, life := 0.7) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.14
	mesh.material = Palette.emissive(color, 3.0)
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


static func ring_pulse(parent: Node3D, pos: Vector3, color: Color, radius := 1.2, life := 0.45) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.04
	torus.outer_radius = radius + 0.04
	mi.mesh = torus
	var mat := Palette.emissive(Color(color.r, color.g, color.b, 0.9), 2.5)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3.ONE * 0.25
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


static func shockwave(parent: Node3D, pos: Vector3, color: Color, max_radius := 4.0, life := 0.55) -> void:
	# Flat expanding ring on the system plane — reads as force, not just light.
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.ring_segments = 48
	mi.mesh = torus
	var mat := Palette.emissive(Color(color.r, color.g, color.b, 0.8), 3.0)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(max_radius, 0.4, max_radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func vortex(parent: Node3D, pos: Vector3, color: Color, duration := 3.0) -> Node3D:
	# Inward-swirling shimmer for the salvage-vacuum climax. Returns the node
	# so the caller can stop it early.
	#
	# GATED AT THE FUNCTION, which is 30's rule and the reason this is here and
	# not at the two call sites: an accommodation checked by callers is an
	# accommodation the next caller forgets. This one had been missed since it
	# shipped — every other effect in this file honours the setting and the
	# vortex did not. Both existing callers already discard the return value, so
	# null is safe.
	if GameState.reduce_motion():
		return null
	var p := CPUParticles3D.new()
	p.amount = 220
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 5.0
	p.direction = Vector3.ZERO
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.radial_accel_min = -16.0
	p.radial_accel_max = -26.0
	p.tangential_accel_min = 9.0
	p.tangential_accel_max = 15.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.26
	p.color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.16
	mesh.material = Palette.emissive(color, 3.0)
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			parent.get_tree().create_timer(1.4).timeout.connect(func() -> void:
				if is_instance_valid(p):
					p.queue_free()
			)
	)
	return p


static func flash(parent: Node3D, pos: Vector3, color: Color, scale := 1.4, life := 0.18) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	var mat := Palette.emissive(Color(color.r, color.g, color.b, 0.85), 4.0)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * scale, life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)
