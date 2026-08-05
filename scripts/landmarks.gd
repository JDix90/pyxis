class_name Landmarks
extends Object
# The one deliberate object per supercell, built from the same six primitives as
# everything else in this game.
#
# Each band gets a DIFFERENT SILHOUETTE, not the same shape in a different
# colour. That is the point: colour already tells you the band, and a second
# tell that is also colour tells you nothing new. A shape reads at distance,
# reads in greyscale, and reads to a player who has the colour-vision setting on
# -- the same argument as the band glyphs on the HUD.
#
# They are scenery, deliberately. No loot, no collision, nothing to hold on.
# The expanse already has four things to do in it; what it lacked was somewhere
# to be, and an object that pays out stops being a landmark and becomes another
# errand. What these buy is the answer to "have I been here before" and "how far
# out am I" without reading a number.
#
# Read the six together and they are one story told outward: something the
# authority built, something people lived in, something that grew, something
# that is just a marker with nobody left to read it -- and then, past the last
# marker, something somebody started and abandoned, and something somebody left
# to say a person got this far.
#
# The frontier's two are the only landmarks NOBODY OFFICIAL made. Everything
# inside the Quiet was built by the GSA or by settlers working off its charts;
# the gate and the cairn are the work of whoever came out here after the maps
# stopped, which is the same person the player currently is.


static func build(kind: String, band: int) -> Node3D:
	match kind:
		"pylon":
			return _pylon(band)
		"frame":
			return _frame(band)
		"monolith":
			return _monolith(band)
		"marker":
			return _marker(band)
		"gate":
			return _gate(band)
		"cairn":
			return _cairn(band)
	return null


static func _pylon(band: int) -> Node3D:
	# THE SHOALS: a shattered survey pylon. The GSA built this, and it fell over.
	# The ring is broken -- three arcs with a gap -- because a complete ring reads
	# as maintained and this is the band where the authority stops maintaining
	# anything.
	var root := Node3D.new()
	var tint := Palette.band_color(band)

	var mast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 26.0, 1.1)
	mast.mesh = bm
	mast.material_override = Palette.matte(Color(0.16, 0.16, 0.18))
	mast.rotation_degrees.z = 14.0          # leaning, not standing
	mast.position.y = 9.0
	root.add_child(mast)

	for i in range(3):
		var arc := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 5.0 + float(i) * 2.2
		tm.outer_radius = tm.inner_radius + 0.28
		tm.ring_segments = 24
		arc.mesh = tm
		arc.material_override = Palette.emissive(
			Color(tint.r, tint.g, tint.b, 0.30 - 0.06 * float(i)), 1.6)
		arc.position.y = 2.0 + float(i) * 5.0
		arc.rotation_degrees = Vector3(0.0, float(i) * 37.0, 8.0 + float(i) * 5.0)
		root.add_child(arc)
	return root


static func _frame(band: int) -> Node3D:
	# THE DRIFT: the frame of a colony that was never finished, or was emptied.
	# Ribs with nothing on them. The one landmark with interior space, which is
	# what makes it read as having been meant for people.
	var root := Node3D.new()
	var tint := Palette.band_color(band)
	var grey := Palette.matte(Color(0.14, 0.13, 0.15))

	var spine := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(1.4, 1.4, 34.0)
	spine.mesh = sb
	spine.material_override = grey
	root.add_child(spine)

	for i in range(5):
		var rib := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 6.0
		tm.outer_radius = 6.5
		tm.ring_segments = 16              # faceted on purpose, like everything here
		rib.mesh = tm
		rib.material_override = grey
		rib.rotation_degrees.x = 90.0
		rib.position.z = -13.0 + float(i) * 6.5
		root.add_child(rib)

	# Two lit windows in the whole structure. Not zero, which would make it a
	# ruin; not many, which would make it inhabited. Two is somebody's lamp.
	for i in range(2):
		var win := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.7, 0.7, 0.2)
		win.mesh = wb
		win.material_override = Palette.emissive(tint, 2.4)
		win.position = Vector3(0.0, 5.4, -6.0 + float(i) * 12.0)
		root.add_child(win)
	return root


static func _monolith(band: int) -> Node3D:
	# THE REACHES: a slab that nobody built, scarred where a nest grew on it.
	# The only landmark with no right angles to a human plan -- it is tilted off
	# every axis, because the others were made and this one was found.
	var root := Node3D.new()
	var tint := Palette.band_color(band)

	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.0, 30.0, 3.2)
	slab.mesh = bm
	slab.material_override = Palette.matte(Color(0.09, 0.10, 0.11))
	slab.rotation_degrees = Vector3(-9.0, 22.0, 6.0)
	root.add_child(slab)

	# The scarring: cells clustered on one face, the way something colonial grows
	# on a surface rather than being fitted to it.
	for i in range(7):
		var pod := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5 + float(i % 3) * 0.28
		sm.height = sm.radius * 2.0
		sm.radial_segments = 7
		sm.rings = 4
		pod.mesh = sm
		pod.material_override = Palette.emissive(
			Color(tint.r, tint.g, tint.b, 0.85), 1.1)
		pod.position = Vector3(
			-3.4 + float(i % 3) * 2.1,
			-9.0 + float(i) * 2.7,
			1.9 + float(i % 2) * 0.5)
		root.add_child(pod)
	return root


static func _marker(band: int) -> Node3D:
	# THE QUIET: a GSA boundary marker, unlit.
	#
	# The loneliest object in the game and the only landmark that does not emit.
	# Everything else out here glows because it is powered or because it is
	# alive; this is neither. You see it because it occludes stars, which means
	# you have to already be looking. THE QUIET is the band whose beacons do not
	# answer and whose guard designation reads "UNREADABLE -- IT DOES NOT
	# ANSWER"; a marker with a working light on it would contradict all of that.
	var root := Node3D.new()
	var cold := Palette.matte(Color(0.17, 0.18, 0.20))

	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 16.0, 0.8)
	post.mesh = bm
	post.material_override = cold
	post.position.y = 6.0
	root.add_child(post)

	var plate := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(5.5, 3.4, 0.3)
	plate.mesh = pb
	plate.material_override = cold
	plate.position.y = 12.5
	root.add_child(plate)

	# Four stubs where the lamps were. Empty sockets, not dark lamps: the
	# difference is whether it broke or was stripped, and stripped is worse.
	for i in range(4):
		var stub := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.3, 0.3, 0.7)
		stub.mesh = sb
		stub.material_override = cold
		stub.position = Vector3(-2.1 + float(i) * 1.4, 14.4, 0.0)
		root.add_child(stub)
	return root


static func _gate(band: int) -> Node3D:
	# THE FATHOMS: an arch somebody stopped building.
	#
	# The frame's sibling and its opposite. A frame is a structure that was
	# finished and then failed; this was never finished -- two piers rising to
	# meet and stopping short, with the span between them missing. It is the
	# first landmark in the game that is passable, and flying THROUGH the gap
	# where the span should be is the whole read: you are crossing into
	# something, and whoever meant to mark the crossing properly did not get to.
	#
	# It emits, unlike the marker one band in. That is deliberate and it is the
	# band's argument in one object: the Quiet is where the authority's lights go
	# out, and the Fathoms is where somebody else's come on.
	var root := Node3D.new()
	var tint := Palette.band_color(band)
	var stone := Palette.matte(Color(0.15, 0.16, 0.19))

	for side in [-1.0, 1.0]:
		# A pier that leans inward, so the two read as reaching for each other.
		var pier := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(2.4, 34.0, 2.4)
		pier.mesh = pb
		pier.material_override = stone
		pier.rotation_degrees.z = -7.0 * side
		pier.position = Vector3(15.0 * side, 15.0, 0.0)
		root.add_child(pier)

		# The span, started from each side and stopping in mid-air. The gap is
		# 12u across at 30u up: wide enough to fly through at speed.
		var stub := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(7.0, 2.0, 2.0)
		stub.mesh = sb
		stub.material_override = stone
		stub.position = Vector3(9.5 * side, 30.0, 0.0)
		root.add_child(stub)

		# One lamp per pier, still lit. Two lights facing each other across a gap
		# that was never closed is the whole object in one detail.
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.7
		lm.height = 1.4
		lamp.mesh = lm
		lamp.material_override = Palette.emissive(tint, 2.2)
		lamp.position = Vector3(6.6 * side, 30.0, 0.0)
		root.add_child(lamp)
	return root


static func _cairn(band: int) -> Node3D:
	# THE UNSOUNDED: a pile of hull plate, stacked by hand.
	#
	# The oldest thing a person does when they reach somewhere nobody has been
	# and there is nothing to build with: stack what you have so the next one
	# knows somebody got here. It is made of SHIP, not of stone -- slabs cut off
	# a hull, which means whoever stacked it was not leaving in that ship.
	#
	# It does not emit, and that is the callback the band's arc needs: the Quiet's
	# marker was unlit because the authority stopped paying for the light. This
	# one is unlit because nobody is coming back to change it. You see it because
	# it occludes stars, standing where the surveyor's own vocabulary runs out.
	var root := Node3D.new()
	var plate := Palette.matte(Color(0.19, 0.19, 0.21))

	# Seven slabs, narrowing as they go up, each turned a little off the last so
	# the stack reads as placed rather than dropped.
	var n := 7
	for i in range(n):
		var t := float(i) / float(n - 1)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var w := 9.0 - 6.6 * t
		bm.size = Vector3(w, 1.6, w * 0.72)
		slab.mesh = bm
		slab.material_override = plate
		slab.position.y = 1.0 + float(i) * 1.75
		slab.rotation_degrees.y = 23.0 * float(i) + 9.0 * sin(float(i) * 2.1)
		slab.rotation_degrees.x = 2.4 * sin(float(i) * 1.7)
		root.add_child(slab)

	# The last piece, stood on its edge on top: the one deliberate line in an
	# otherwise horizontal object, and the reason it reads as a mark rather than
	# as debris that happened to settle.
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.5, 5.2, 2.6)
	top.mesh = tb
	top.material_override = plate
	top.position.y = 1.0 + float(n) * 1.75 + 2.0
	top.rotation_degrees.y = 31.0
	root.add_child(top)
	return root
