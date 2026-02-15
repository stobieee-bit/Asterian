## AbyssalSerpentMesh — Procedural mesh builder for a sea-serpent/dragon enemy
##
## A long, sinuous deep-sea serpent with bioluminescent markings.
## Body: 12 spherical segments in an S-curve, tapering toward the tail.
## Head: enlarged segment with glowing eyes, jaw mandibles, and lateral fins.
## Dorsal spines on alternating segments, bioluminescent belly spots,
## and a tail fin at the terminus.
##
## ~45-55 mesh nodes. Animate: sine-wave body undulation, jaw open/close, fin flutter.
class_name AbyssalSerpentMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	# ── Extract parameters ──
	var base_color: Color = EnemyMeshBuilder.int_to_color(int(params.get("color", 0x1a3a4a)))
	var s: float = float(params.get("scale", 1.0))

	var root: Node3D = Node3D.new()
	root.name = "AbyssalSerpentRoot"

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.35, 0.55
	)
	var mat_body_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.35, 0.6
	)
	var mat_belly: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.12), 0.25, 0.65
	)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.2, 0.9, 0.7), 0.5, 0.3,
		Color(0.1, 1.0, 0.8), 3.0  # Bright teal-green glow
	)
	var mat_jaw: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.5, 0.4
	)
	var mat_spine: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.05), 0.55, 0.35
	)
	var mat_fin: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.3, 0.5,
		Color.BLACK, 0.0, true, 0.6  # Semi-transparent fins
	)
	var mat_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.1, 0.6, 0.9), 0.2, 0.4,
		Color(0.05, 0.5, 1.0), 2.5  # Blue bioluminescence
	)
	var mat_tail_fin: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.06), 0.3, 0.45,
		Color.BLACK, 0.0, true, 0.55
	)

	# ── Body layout ──
	# 12 segments in an S-curve along the Z axis.
	# Segment 0 = head (front, -Z), segment 11 = tail tip (+Z).
	var segment_count: int = 12
	var segment_spacing: float = 0.28 * s
	var body_y: float = 0.7 * s  # Center height

	# Head radius is largest, tapering to tail
	var head_radius: float = 0.22 * s
	var segments: Array[MeshInstance3D] = []

	for i: int in range(segment_count):
		# ── Taper: head is biggest, linearly shrinks toward tail ──
		var taper: float = 1.0 - float(i) * 0.065
		var seg_radius: float = head_radius * taper

		# ── S-curve: sine wave offset on X axis ──
		var curve_t: float = float(i) / float(segment_count - 1)
		var x_offset: float = sin(curve_t * PI * 2.0) * 0.25 * s

		# ── Slight vertical wave too ──
		var y_offset: float = sin(curve_t * PI * 1.5) * 0.08 * s

		var seg_pos: Vector3 = Vector3(
			x_offset,
			body_y + y_offset,
			float(i) * segment_spacing
		)

		# Alternate materials for subtle banding
		var seg_mat: StandardMaterial3D = mat_body if i % 2 == 0 else mat_body_dark
		# Slightly elongated along Z for a smoother chain
		var seg: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, seg_radius, seg_pos, seg_mat,
			Vector3(1.0, 0.85, 1.2)
		)
		seg.name = "Segment%d" % i
		segments.append(seg)

	# ── HEAD DETAILS (segment 0) ──
	var head_pos: Vector3 = segments[0].position

	# Glowing eyes (left and right)
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.045 * s,
		head_pos + Vector3(-0.13 * s, 0.06 * s, -0.1 * s),
		mat_eye
	)
	eye_l.name = "EyeL"
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.045 * s,
		head_pos + Vector3(0.13 * s, 0.06 * s, -0.1 * s),
		mat_eye
	)
	eye_r.name = "EyeR"

	# Jaw mandibles — two capsules angled downward from the head
	var jaw_pivot_l: Node3D = Node3D.new()
	jaw_pivot_l.name = "JawPivotL"
	jaw_pivot_l.position = head_pos + Vector3(-0.08 * s, -0.1 * s, -0.12 * s)
	root.add_child(jaw_pivot_l)
	var jaw_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		jaw_pivot_l, 0.03 * s, 0.16 * s,
		Vector3(0.0, -0.04 * s, -0.06 * s), mat_jaw,
		Vector3(0.5, 0.0, 0.2)
	)
	jaw_l.name = "JawL"

	var jaw_pivot_r: Node3D = Node3D.new()
	jaw_pivot_r.name = "JawPivotR"
	jaw_pivot_r.position = head_pos + Vector3(0.08 * s, -0.1 * s, -0.12 * s)
	root.add_child(jaw_pivot_r)
	var jaw_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		jaw_pivot_r, 0.03 * s, 0.16 * s,
		Vector3(0.0, -0.04 * s, -0.06 * s), mat_jaw,
		Vector3(0.5, 0.0, -0.2)
	)
	jaw_r.name = "JawR"

	# Lateral fins — flattened spheres on left/right of the head
	var fin_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.08 * s,
		head_pos + Vector3(-0.22 * s, 0.0, 0.04 * s),
		mat_fin, Vector3(0.3, 0.8, 1.4)
	)
	fin_l.name = "FinL"
	var fin_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.08 * s,
		head_pos + Vector3(0.22 * s, 0.0, 0.04 * s),
		mat_fin, Vector3(0.3, 0.8, 1.4)
	)
	fin_r.name = "FinR"

	# ── DORSAL SPINES — cones on top of alternating segments (1, 3, 5, 7, 9) ──
	var spines: Array[MeshInstance3D] = []
	for i: int in range(1, segment_count - 1, 2):
		var seg_pos: Vector3 = segments[i].position
		var taper: float = 1.0 - float(i) * 0.065
		var spine_height: float = 0.14 * s * taper
		var spine: MeshInstance3D = EnemyMeshBuilder.add_cone(
			root, 0.025 * s * taper, spine_height,
			seg_pos + Vector3(0.0, head_radius * taper * 0.75, 0.0),
			mat_spine, Vector3(0.0, 0.0, 0.0)
		)
		spine.name = "Spine%d" % i
		spines.append(spine)

	# ── BIOLUMINESCENT BELLY SPOTS — small emissive spheres on underside ──
	var belly_spots: Array[MeshInstance3D] = []
	for i: int in range(0, segment_count, 2):
		var seg_pos: Vector3 = segments[i].position
		var taper: float = 1.0 - float(i) * 0.065
		var spot: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.025 * s * taper,
			seg_pos + Vector3(0.0, -head_radius * taper * 0.7, 0.0),
			mat_glow
		)
		spot.name = "BellySpot%d" % i
		belly_spots.append(spot)

	# ── SIDE FINS — small paired fins on segments 2, 4, 6 ──
	var side_fins: Array[MeshInstance3D] = []
	for i: int in [2, 4, 6]:
		var seg_pos: Vector3 = segments[i].position
		var taper: float = 1.0 - float(i) * 0.065
		var fin_size: float = 0.055 * s * taper
		# Left side fin
		var sf_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, fin_size,
			seg_pos + Vector3(-head_radius * taper * 0.85, -0.02 * s, 0.0),
			mat_fin, Vector3(0.25, 0.6, 1.2)
		)
		sf_l.name = "SideFin%dL" % i
		side_fins.append(sf_l)
		# Right side fin
		var sf_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, fin_size,
			seg_pos + Vector3(head_radius * taper * 0.85, -0.02 * s, 0.0),
			mat_fin, Vector3(0.25, 0.6, 1.2)
		)
		sf_r.name = "SideFin%dR" % i
		side_fins.append(sf_r)

	# ── HORN RIDGES — small cones flanking the head ──
	var horn_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.02 * s, 0.1 * s,
		head_pos + Vector3(-0.16 * s, 0.12 * s, -0.05 * s),
		mat_spine, Vector3(-0.3, 0.0, -0.4)
	)
	horn_l.name = "HornL"
	var horn_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.02 * s, 0.1 * s,
		head_pos + Vector3(0.16 * s, 0.12 * s, -0.05 * s),
		mat_spine, Vector3(-0.3, 0.0, 0.4)
	)
	horn_r.name = "HornR"

	# ── BELLY RIDGE — thin capsule running along segments 3-8 underside ──
	for i: int in [3, 5, 7]:
		var seg_pos: Vector3 = segments[i].position
		var taper: float = 1.0 - float(i) * 0.065
		var ridge: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.015 * s * taper, 0.2 * s * taper,
			seg_pos + Vector3(0.0, -head_radius * taper * 0.6, 0.0),
			mat_belly, Vector3(PI * 0.5, 0.0, 0.0)
		)
		ridge.name = "BellyRidge%d" % i

	# ── TAIL FIN — flattened cone at the end ──
	var tail_pos: Vector3 = segments[segment_count - 1].position
	var tail_fin: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.08 * s, 0.2 * s,
		tail_pos + Vector3(0.0, 0.0, 0.15 * s),
		mat_tail_fin, Vector3(PI * 0.5, 0.0, 0.0)
	)
	tail_fin.name = "TailFin"
	# Flatten the tail fin vertically for a fan shape
	tail_fin.scale = Vector3(0.3, 1.0, 1.0)

	# Secondary tail fin — smaller, offset vertically
	var tail_fin2: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.05 * s, 0.14 * s,
		tail_pos + Vector3(0.0, 0.08 * s, 0.1 * s),
		mat_tail_fin, Vector3(PI * 0.5, 0.0, 0.0)
	)
	tail_fin2.name = "TailFin2"
	tail_fin2.scale = Vector3(0.25, 1.0, 0.8)

	# ── Store animatable parts as metadata ──
	root.set_meta("segments", segments)
	root.set_meta("jaw_pivots", [jaw_pivot_l, jaw_pivot_r])
	root.set_meta("fins", [fin_l, fin_r])
	root.set_meta("side_fins", side_fins)
	root.set_meta("spines", spines)
	root.set_meta("belly_spots", belly_spots)
	root.set_meta("tail_fin", tail_fin)
	root.set_meta("scale", s)
	root.set_meta("segment_spacing", segment_spacing)
	root.set_meta("body_y", body_y)

	return root


## Animate the serpent each frame.
## Moving: sinusoidal body wave, jaw snapping, fin flutter.
## Idle: gentle swaying, slow jaw open/close, belly pulse.
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = float(root.get_meta("scale", 1.0))
	var spacing: float = float(root.get_meta("segment_spacing", 0.28))
	var base_y: float = float(root.get_meta("body_y", 0.7))

	# ── Body undulation — sinusoidal wave propagates along segments ──
	if root.has_meta("segments"):
		var segments: Array = root.get_meta("segments") as Array
		var wave_speed: float = 4.0 if is_moving else 1.5
		var wave_amp: float = 0.18 * s if is_moving else 0.08 * s
		var wave_freq: float = 1.8  # Spatial frequency along the body

		for i: int in range(segments.size()):
			var seg: MeshInstance3D = segments[i] as MeshInstance3D
			if seg == null:
				continue
			# Lateral (X) wave — primary undulation
			var wave_phase: float = phase * wave_speed - float(i) * wave_freq * 0.5
			var x_wave: float = sin(wave_phase) * wave_amp * (0.5 + float(i) * 0.05)

			# Vertical (Y) wave — subtle secondary motion
			var y_wave: float = sin(wave_phase * 0.7 + 1.0) * wave_amp * 0.3

			# Compute the base S-curve position for this segment
			var curve_t: float = float(i) / float(maxi(1, segments.size() - 1))
			var base_x: float = sin(curve_t * PI * 2.0) * 0.25 * s
			var base_y_off: float = sin(curve_t * PI * 1.5) * 0.08 * s

			seg.position.x = lerpf(seg.position.x, base_x + x_wave, delta * 6.0)
			seg.position.y = lerpf(seg.position.y, base_y + base_y_off + y_wave, delta * 6.0)

	# ── Jaw open/close ──
	if root.has_meta("jaw_pivots"):
		var jaw_pivots: Array = root.get_meta("jaw_pivots") as Array
		var jaw_speed: float = 3.0 if is_moving else 1.2
		var jaw_angle: float = (sin(phase * jaw_speed) * 0.5 + 0.5) * 0.25  # 0 to 0.25 rad
		if jaw_pivots.size() >= 2:
			var jl: Node3D = jaw_pivots[0] as Node3D
			var jr: Node3D = jaw_pivots[1] as Node3D
			if jl != null:
				jl.rotation.x = lerpf(jl.rotation.x, jaw_angle, delta * 5.0)
			if jr != null:
				jr.rotation.x = lerpf(jr.rotation.x, jaw_angle, delta * 5.0)

	# ── Fin flutter ──
	if root.has_meta("fins"):
		var fins: Array = root.get_meta("fins") as Array
		var flutter_speed: float = 5.0 if is_moving else 2.5
		var flutter_amp: float = 0.3 if is_moving else 0.15
		if fins.size() >= 2:
			var fl: MeshInstance3D = fins[0] as MeshInstance3D
			var fr: MeshInstance3D = fins[1] as MeshInstance3D
			if fl != null:
				fl.rotation.z = lerpf(fl.rotation.z, sin(phase * flutter_speed) * flutter_amp, delta * 6.0)
			if fr != null:
				fr.rotation.z = lerpf(fr.rotation.z, -sin(phase * flutter_speed) * flutter_amp, delta * 6.0)

	# ── Side fin flutter — paired fins along the body ripple ──
	if root.has_meta("side_fins"):
		var side_fins: Array = root.get_meta("side_fins") as Array
		for i: int in range(side_fins.size()):
			var sf: MeshInstance3D = side_fins[i] as MeshInstance3D
			if sf == null:
				continue
			var sf_speed: float = 4.0 if is_moving else 2.0
			var sf_amp: float = 0.25 if is_moving else 0.12
			var side: float = 1.0 if i % 2 == 0 else -1.0
			sf.rotation.z = lerpf(sf.rotation.z, side * sin(phase * sf_speed + float(i) * 0.8) * sf_amp, delta * 5.0)

	# ── Spine sway — dorsal spines tilt slightly with the body wave ──
	if root.has_meta("spines"):
		var spines: Array = root.get_meta("spines") as Array
		for i: int in range(spines.size()):
			var spine: MeshInstance3D = spines[i] as MeshInstance3D
			if spine == null:
				continue
			var spine_sway: float = sin(phase * 3.0 - float(i) * 1.2) * 0.15
			spine.rotation.x = lerpf(spine.rotation.x, spine_sway, delta * 4.0)

	# ── Belly spot pulse — bioluminescence throbs gently ──
	if root.has_meta("belly_spots"):
		var spots: Array = root.get_meta("belly_spots") as Array
		for i: int in range(spots.size()):
			var spot: MeshInstance3D = spots[i] as MeshInstance3D
			if spot == null:
				continue
			# Pulse scale between 0.8 and 1.2
			var pulse: float = 1.0 + sin(phase * 2.0 + float(i) * 1.5) * 0.2
			var current_s: float = lerpf(spot.scale.x, pulse, delta * 3.0)
			spot.scale = Vector3(current_s, current_s, current_s)

	# ── Tail fin sway ──
	if root.has_meta("tail_fin"):
		var tail: MeshInstance3D = root.get_meta("tail_fin") as MeshInstance3D
		if tail != null:
			var tail_speed: float = 4.5 if is_moving else 2.0
			var tail_amp: float = 0.4 if is_moving else 0.2
			tail.rotation.y = lerpf(tail.rotation.y, sin(phase * tail_speed) * tail_amp, delta * 5.0)
