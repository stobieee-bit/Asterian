## WormMesh — Segmented worm creature
##
## A burrowing annelid with 8 tapering body segments, alternating dark/light
## banding, bristle setae, a distinct head prostomium with radial mandibles and
## mouth glow, a clitellum band, dorsal bumps, lateral bioluminescent spots,
## ventral grooves, inter-segment connective tissue, lateral veins, head sensory
## nubs, inner mouth detail, dorsal ridge line, mucus nodes, bristle glow tips,
## and a tail pygidium. Animate: serpentine undulation, bristle glow pulse.
class_name WormMesh
extends EnemyMeshBuilder

# ──────────────────────────────────────────────
# Build
# ──────────────────────────────────────────────
func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x885544))
	var sc: float = params.get("scale", 1.0)
	root.scale = Vector3(sc, sc, sc)

	# ── Materials ──
	var mat_light: StandardMaterial3D = EnemyMeshBuilder.mat_sci(base_color, 0.15, 0.65)
	var mat_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.2, 0.6)
	var mat_bristle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.1, 0.5)
	var mat_bump: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.06), 0.2, 0.55)
	var mat_clitellum: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.2), 0.1, 0.4)
	var mat_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.3, 0.9, 0.5), 0.0, 0.3,
		Color(0.3, 0.9, 0.5), 1.8, true, 0.7)
	var mat_mouth_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.4, 0.2), 0.0, 0.3,
		Color(0.95, 0.45, 0.2), 2.5)
	var mat_mandible: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.15, 0.12, 0.1), 0.5, 0.4)
	var mat_head: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.2, 0.55)

	# New detail materials
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.6, 0.2, 0.15), 0.1, 0.6,
		Color(0.5, 0.15, 0.1), 0.3, true, 0.5)
	var mat_sensory_nub: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.05, 0.5,
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.8)
	var mat_slime: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.25), 0.0, 0.9,
		Color.BLACK, 0.0, true, 0.3)
	var mat_bristle_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.4, 0.9, 0.6), 0.0, 0.3,
		Color(0.4, 0.95, 0.6), 1.0)
	var mat_inner_mouth: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.5, 0.12, 0.1), 0.0, 0.7,
		Color(0.6, 0.15, 0.1), 0.5)

	# ── Segment layout ──
	# 8 segments along the X axis, tapering from front to rear
	var segment_count: int = 8
	var segment_spacing: float = 0.28
	var start_x: float = (segment_count - 1) * segment_spacing * 0.5
	var segment_nodes: Array = []
	var bristle_glow_tips: Array = []

	for i: int in range(segment_count):
		var seg: Node3D = Node3D.new()
		var seg_x: float = start_x - i * segment_spacing
		seg.position = Vector3(seg_x, 0.35, 0.0)
		root.add_child(seg)
		segment_nodes.append(seg)

		# Taper: largest at front (index 0), smallest at rear
		var taper: float = 1.0 - (i * 0.08)
		var seg_radius: float = 0.18 * taper

		# Alternating dark/light banding
		var seg_mat: StandardMaterial3D = mat_light if (i % 2 == 0) else mat_dark

		# Clitellum override on segment 3 (index 2)
		if i == 2:
			seg_mat = mat_clitellum

		# Main segment body — flattened sphere
		EnemyMeshBuilder.add_sphere(seg, seg_radius, Vector3.ZERO, seg_mat,
			Vector3(1.0, 0.7, 1.0))

		# ── Bristles / setae — 4 small cones around circumference ──
		var bristle_angles: Array = [0.4, -0.4, PI - 0.4, PI + 0.4]
		for a: int in range(bristle_angles.size()):
			var angle: float = bristle_angles[a]
			var bz: float = cos(angle) * (seg_radius + 0.02)
			var by: float = sin(angle) * (seg_radius * 0.7 + 0.02) - 0.02
			var bristle_rot: Vector3 = Vector3(angle, 0.0, 0.0)
			EnemyMeshBuilder.add_cone(seg, 0.012, 0.06,
				Vector3(0.0, by, bz), mat_bristle, bristle_rot)

		# ── Bristle glow tips on select bristles (first 4 segments, top 2 bristles) ──
		if i < 4:
			for bi: int in [0, 1]:
				var angle: float = bristle_angles[bi]
				var bz: float = cos(angle) * (seg_radius + 0.06)
				var by: float = sin(angle) * (seg_radius * 0.7 + 0.06) - 0.02
				var glow_tip: MeshInstance3D = EnemyMeshBuilder.add_sphere(
					seg, 0.008, Vector3(0.0, by, bz), mat_bristle_glow)
				bristle_glow_tips.append(glow_tip)

		# ── Dorsal bump on top of each segment ──
		EnemyMeshBuilder.add_sphere(seg, 0.035, Vector3(0.0, seg_radius * 0.65, 0.0), mat_bump)

		# ── Dorsal ridge capsule above each bump ──
		EnemyMeshBuilder.add_capsule(seg, 0.012, 0.06,
			Vector3(0.0, seg_radius * 0.7 + 0.02, 0.0), mat_bump,
			Vector3(0.0, 0.0, PI * 0.5))

		# ── Ventral groove — capsule along underside ──
		EnemyMeshBuilder.add_capsule(seg, 0.015, 0.08,
			Vector3(0.0, -(seg_radius * 0.55), 0.0), mat_dark,
			Vector3(0.0, 0.0, PI * 0.5))

		# ── Lateral vein lines — thin semi-transparent capsules ──
		EnemyMeshBuilder.add_capsule(seg, 0.005, 0.10,
			Vector3(0.0, 0.0, seg_radius * 0.6), mat_vein,
			Vector3(0.0, 0.0, PI * 0.5))
		EnemyMeshBuilder.add_capsule(seg, 0.005, 0.10,
			Vector3(0.0, 0.0, -(seg_radius * 0.6)), mat_vein,
			Vector3(0.0, 0.0, PI * 0.5))

		# ── Lateral bioluminescent glow spots (one per side, skip head/tail) ──
		if i > 0 and i < segment_count - 1:
			EnemyMeshBuilder.add_sphere(seg, 0.025,
				Vector3(0.0, 0.0, seg_radius + 0.01), mat_glow)
			EnemyMeshBuilder.add_sphere(seg, 0.025,
				Vector3(0.0, 0.0, -(seg_radius + 0.01)), mat_glow)

		# ── Mucus secretion nodes (underside, on even segments) ──
		if i % 2 == 0 and i > 0:
			EnemyMeshBuilder.add_sphere(seg, 0.012,
				Vector3(0.0, -(seg_radius * 0.65), 0.0), mat_slime)

	# ── Inter-segment connective tissue — small spheres at junctions ──
	for i: int in range(segment_count - 1):
		var x1: float = start_x - i * segment_spacing
		var x2: float = start_x - (i + 1) * segment_spacing
		var mid_x: float = (x1 + x2) * 0.5
		EnemyMeshBuilder.add_sphere(root, 0.04, Vector3(mid_x, 0.33, 0.0), mat_dark,
			Vector3(0.8, 0.5, 0.8))

	# ── Head (prostomium) — distinct front segment ──
	var head: Node3D = Node3D.new()
	head.position = Vector3(start_x + 0.22, 0.35, 0.0)
	root.add_child(head)

	# Head dome
	EnemyMeshBuilder.add_sphere(head, 0.15, Vector3.ZERO, mat_head,
		Vector3(1.2, 0.85, 0.9))

	# ── Head sensory nubs — 6 spheres around prostomium ──
	for i: int in range(6):
		var angle: float = (float(i) / 6.0) * TAU
		var nub_z: float = cos(angle) * 0.12
		var nub_y: float = sin(angle) * 0.10
		EnemyMeshBuilder.add_sphere(head, 0.015,
			Vector3(0.08, nub_y, nub_z), mat_sensory_nub)

	# ── Mouth glow ring ──
	EnemyMeshBuilder.add_torus(head, 0.03, 0.07, Vector3(0.12, -0.02, 0.0),
		mat_mouth_glow, Vector3(0.0, 0.0, PI * 0.5))

	# ── Inner mouth detail ──
	EnemyMeshBuilder.add_sphere(head, 0.04, Vector3(0.10, -0.02, 0.0), mat_inner_mouth)
	EnemyMeshBuilder.add_cone(head, 0.012, 0.04,
		Vector3(0.11, 0.02, 0.03), mat_mandible, Vector3(0.0, 0.0, 0.5))
	EnemyMeshBuilder.add_cone(head, 0.012, 0.04,
		Vector3(0.11, 0.02, -0.03), mat_mandible, Vector3(0.0, 0.0, -0.5))

	# ── 4 radial mandibles ──
	var mandible_offsets: Array = [
		Vector3(0.14, 0.06, 0.0),   # top
		Vector3(0.14, -0.1, 0.0),   # bottom
		Vector3(0.14, -0.02, 0.06), # right
		Vector3(0.14, -0.02, -0.06) # left
	]
	var mandible_rots: Array = [
		Vector3(0.0, 0.0, -0.4),   # top curves out
		Vector3(0.0, 0.0, 0.4),    # bottom curves out
		Vector3(0.4, 0.0, 0.0),    # right curves out
		Vector3(-0.4, 0.0, 0.0)    # left curves out
	]
	for m: int in range(4):
		EnemyMeshBuilder.add_cone(head, 0.025, 0.1,
			mandible_offsets[m], mat_mandible, mandible_rots[m])

	# ── Clitellum band (prominent ring on segment 3, index 2) ──
	var clitellum_seg: Node3D = segment_nodes[2]
	EnemyMeshBuilder.add_torus(clitellum_seg, 0.04, 0.2 * 0.84 + 0.02,
		Vector3.ZERO, mat_clitellum, Vector3(0.0, 0.0, PI * 0.5))

	# ── Tail pygidium — small rounded end ──
	var tail_x: float = start_x - (segment_count - 1) * segment_spacing - 0.15
	EnemyMeshBuilder.add_sphere(root, 0.08, Vector3(tail_x, 0.32, 0.0), mat_dark,
		Vector3(1.3, 0.7, 0.7))

	# ── Store animatable references ──
	root.set_meta("segments", segment_nodes)
	root.set_meta("head", [head])
	root.set_meta("bristle_glow_tips", bristle_glow_tips)

	# Built facing +X, rotate to face -Z (Godot forward)
	root.rotation.y = PI / 2.0
	return root


# ──────────────────────────────────────────────
# Animate
# ──────────────────────────────────────────────
func animate(root: Node3D, phase: float, is_moving: bool, _delta: float) -> void:
	var segments: Array = root.get_meta("segments", [])
	var heads: Array = root.get_meta("head", [])
	var seg_count: int = segments.size()

	if seg_count == 0:
		return

	# ── Serpentine undulation ──
	# Each segment sways side-to-side with a phase offset, creating a wave
	var wave_speed: float = 4.0 if is_moving else 1.0
	var wave_amp_z: float = 0.08 if is_moving else 0.03
	var wave_amp_y: float = 0.03 if is_moving else 0.01

	for i: int in range(seg_count):
		var seg_node: Node3D = segments[i] as Node3D
		var seg_phase: float = phase * wave_speed - i * 0.7

		# Lateral sway (Z axis)
		seg_node.position.z = sin(seg_phase) * wave_amp_z * (1.0 + i * 0.15)

		# Slight vertical bob
		seg_node.position.y = 0.35 + sin(seg_phase * 2.0) * wave_amp_y

		# Body segment rotation follows the wave
		seg_node.rotation.y = sin(seg_phase) * 0.12

	# ── Head motion ──
	if heads.size() > 0:
		var head_node: Node3D = heads[0] as Node3D
		if is_moving:
			# Head leads the wave — slight side-to-side search
			head_node.position.z = sin(phase * wave_speed + 0.5) * wave_amp_z * 0.6
			head_node.rotation.y = sin(phase * wave_speed + 0.5) * 0.1
			head_node.position.y = 0.35 + sin(phase * wave_speed * 2.0 + 0.5) * 0.015
		else:
			# Idle: slow probing motion
			head_node.rotation.y = sin(phase * 0.6) * 0.15
			head_node.rotation.z = sin(phase * 0.4) * 0.05

	# ── Bristle glow tip pulse ──
	var glow_tips: Array = root.get_meta("bristle_glow_tips", [])
	for i: int in range(glow_tips.size()):
		var tip: MeshInstance3D = glow_tips[i] as MeshInstance3D
		var pulse: float = 0.7 + sin(phase * 1.8 + float(i) * 0.9) * 0.3
		tip.scale = Vector3(pulse, pulse, pulse)
