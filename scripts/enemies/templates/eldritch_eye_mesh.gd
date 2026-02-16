## EldritchEyeMesh — Floating giant eyeball with trailing nerve tentacles
##
## A massive hovering eye with blood-vessel-textured sclera, colored iris,
## dark pupil, eyelid frames (half-torus), trailing nerve tentacles with
## secondary eyes at their tips, and a faint transparent aura glow.
## ~78 mesh nodes. Animates iris look-around, tentacle sway, hover bob,
## nerve-node pulse, and mini-eye scale pulse.
class_name EldritchEyeMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "EldritchEyeRoot"
	var s: float = float(params.get("scale", 1.0))
	var base_color: Color = EnemyMeshBuilder.int_to_color(int(params.get("color", 0x8B0000)))

	# ── Hover height — the eye floats above the ground ──
	var eye_y: float = 1.0 * s

	# ── Materials ──
	var mat_sclera: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.95, 0.92, 0.85), 0.15, 0.6)
	var mat_vessel: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.7, 0.12, 0.08), 0.2, 0.7,
		Color(0.5, 0.05, 0.02), 0.3)
	var mat_iris: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.5, 0.3,
		base_color, 1.5)
	var mat_pupil: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.02, 0.02, 0.02), 0.1, 0.9)
	var mat_eyelid: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.2), 0.4, 0.5)
	var mat_nerve: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.75, 0.55, 0.5), 0.15, 0.7)
	var mat_nerve_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(Color(0.75, 0.55, 0.5), 0.1), 0.15, 0.7)
	var mat_mini_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.5, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.15), 1.2)
	var mat_aura: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.2), 0.0, 1.0,
		base_color, 0.6,
		true, 0.08)
	var mat_iris_detail: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.5, 0.3,
		EnemyMeshBuilder.darken(base_color, 0.05), 0.8)
	var mat_nerve_node: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(Color(0.75, 0.55, 0.5), 0.1), 0.15, 0.7,
		EnemyMeshBuilder.lighten(Color(0.75, 0.55, 0.5), 0.1), 1.0)
	var mat_tear: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.8, 0.85, 0.9), 0.0, 0.1,
		Color.BLACK, 0.0,
		true, 0.2)
	var mat_lid_inner: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.7, 0.3, 0.25), 0.15, 0.8)

	# ══════════════════════════════════════════════════════════════
	# CENTRAL EYEBALL
	# ══════════════════════════════════════════════════════════════

	# Main sclera sphere (the white of the eye)
	var sclera: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.4 * s, Vector3(0.0, eye_y, 0.0),
		mat_sclera, Vector3(1.0, 0.9, 1.0))
	sclera.name = "Sclera"

	# ── Blood vessels — small red capsules on the sclera surface ──
	# Placed at various positions around the eyeball
	var vessel_data: Array = [
		# [pos_offset, rotation, length]
		[Vector3(0.25, 0.2, 0.2), Vector3(0.4, 0.3, 0.8), 0.18],
		[Vector3(-0.22, 0.25, 0.15), Vector3(-0.3, 0.5, -0.6), 0.16],
		[Vector3(0.18, -0.15, 0.25), Vector3(0.6, -0.2, 0.4), 0.14],
		[Vector3(-0.15, -0.2, 0.22), Vector3(-0.5, -0.4, -0.3), 0.15],
		[Vector3(0.1, 0.3, -0.2), Vector3(0.2, 0.7, 0.1), 0.12],
		[Vector3(-0.2, 0.1, -0.25), Vector3(-0.4, 0.2, -0.5), 0.13],
		[Vector3(0.0, 0.28, 0.18), Vector3(0.1, -0.6, 0.3), 0.11],
		[Vector3(0.12, -0.25, -0.18), Vector3(0.7, 0.1, -0.4), 0.14],
	]
	for vi: int in range(vessel_data.size()):
		var vd: Array = vessel_data[vi]
		var v_pos: Vector3 = (vd[0] as Vector3) * s + Vector3(0.0, eye_y, 0.0)
		var v_rot: Vector3 = vd[1] as Vector3
		var v_len: float = (vd[2] as float) * s
		var vessel: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, v_len, v_pos, mat_vessel, v_rot)
		vessel.name = "Vessel%d" % vi

	# ── Additional blood vessels — back and sides of sclera ──
	var vessel_data_extra: Array = [
		[Vector3(0.2, 0.15, 0.25), Vector3(0.3, -0.5, 0.6), 0.15],
		[Vector3(-0.25, 0.18, 0.12), Vector3(-0.6, 0.3, 0.5), 0.17],
		[Vector3(0.15, -0.22, -0.22), Vector3(0.5, 0.4, -0.6), 0.13],
		[Vector3(-0.1, 0.26, -0.2), Vector3(-0.2, -0.5, 0.4), 0.16],
		[Vector3(0.22, 0.05, -0.24), Vector3(0.4, 0.6, 0.2), 0.14],
		[Vector3(-0.18, -0.18, -0.2), Vector3(-0.7, -0.3, -0.5), 0.12],
		[Vector3(0.05, 0.22, 0.26), Vector3(0.1, 0.4, -0.7), 0.15],
		[Vector3(-0.08, -0.28, 0.2), Vector3(-0.3, 0.6, 0.3), 0.11],
	]
	for vi: int in range(vessel_data_extra.size()):
		var vd: Array = vessel_data_extra[vi]
		var v_pos: Vector3 = (vd[0] as Vector3) * s + Vector3(0.0, eye_y, 0.0)
		var v_rot: Vector3 = vd[1] as Vector3
		var v_len: float = (vd[2] as float) * s
		var vessel_extra: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, v_len, v_pos, mat_vessel, v_rot)
		vessel_extra.name = "VesselExtra%d" % vi

	# ══════════════════════════════════════════════════════════════
	# IRIS + PUPIL (on the front face of the eye, facing -Z)
	# ══════════════════════════════════════════════════════════════

	# Iris pivot — allows the iris+pupil to shift for look-around animation
	var iris_pivot: Node3D = Node3D.new()
	iris_pivot.name = "IrisPivot"
	iris_pivot.position = Vector3(0.0, eye_y, 0.0)
	root.add_child(iris_pivot)

	# Iris sphere (colored, slightly flattened, on front surface)
	var iris: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		iris_pivot, 0.18 * s, Vector3(0.0, 0.0, -0.3 * s),
		mat_iris, Vector3(1.0, 1.0, 0.4))
	iris.name = "Iris"

	# Pupil (dark sphere, smaller, in front of iris)
	var pupil: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		iris_pivot, 0.08 * s, Vector3(0.0, 0.0, -0.36 * s),
		mat_pupil, Vector3(1.0, 1.3, 0.3))
	pupil.name = "Pupil"

	# Iris ring detail — thin torus around the iris edge
	var mat_iris_ring: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.5, 0.3,
		base_color, 1.0)
	var iris_ring: MeshInstance3D = EnemyMeshBuilder.add_torus(
		iris_pivot, 0.02 * s, 0.17 * s,
		Vector3(0.0, 0.0, -0.29 * s),
		mat_iris_ring, Vector3(PI * 0.5, 0.0, 0.0))
	iris_ring.name = "IrisRing"

	# Inner iris glow — smaller emissive sphere behind the pupil
	var mat_iris_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.2), 0.0, 0.2,
		base_color, 2.5, true, 0.4)
	var iris_glow: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		iris_pivot, 0.12 * s, Vector3(0.0, 0.0, -0.28 * s),
		mat_iris_glow, Vector3(1.0, 1.0, 0.2))
	iris_glow.name = "IrisGlow"

	# ── Iris concentric ring details — 4 torus rings on the iris face ──
	var iris_detail_radii: Array[float] = [0.05, 0.09, 0.13, 0.16]
	for ri: int in range(iris_detail_radii.size()):
		var ring_r: float = iris_detail_radii[ri] * s
		var iris_detail: MeshInstance3D = EnemyMeshBuilder.add_torus(
			iris_pivot, 0.008 * s, ring_r,
			Vector3(0.0, 0.0, -0.29 * s),
			mat_iris_detail, Vector3(PI * 0.5, 0.0, 0.0))
		iris_detail.name = "IrisDetail%d" % ri

	# ── Pupil depth — dark sphere behind the pupil for depth illusion ──
	var pupil_depth: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		iris_pivot, 0.06 * s, Vector3(0.0, 0.0, -0.25 * s),
		mat_pupil, Vector3(1.0, 1.0, 0.3))
	pupil_depth.name = "PupilDepth"

	# ══════════════════════════════════════════════════════════════
	# EYELIDS — half-torus shapes framing top and bottom of the eye
	# ══════════════════════════════════════════════════════════════

	# Upper eyelid
	var eyelid_upper: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.12 * s, 0.35 * s,
		Vector3(0.0, eye_y + 0.18 * s, -0.12 * s),
		mat_eyelid, Vector3(0.3, 0.0, 0.0))
	eyelid_upper.name = "EyelidUpper"
	eyelid_upper.scale = Vector3(1.0, 0.5, 0.6)

	# Lower eyelid
	var eyelid_lower: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.12 * s, 0.35 * s,
		Vector3(0.0, eye_y - 0.18 * s, -0.12 * s),
		mat_eyelid, Vector3(-0.3, 0.0, 0.0))
	eyelid_lower.name = "EyelidLower"
	eyelid_lower.scale = Vector3(1.0, 0.5, 0.6)

	# ── Eyelid inner linings — capsules along the inner edges ──
	var lid_inner_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.015 * s, 0.22 * s,
		Vector3(0.0, eye_y + 0.14 * s, -0.15 * s),
		mat_lid_inner, Vector3(0.2, 0.0, 0.0))
	lid_inner_upper.name = "LidInnerUpper"

	var lid_inner_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.015 * s, 0.22 * s,
		Vector3(0.0, eye_y - 0.14 * s, -0.15 * s),
		mat_lid_inner, Vector3(-0.2, 0.0, 0.0))
	lid_inner_lower.name = "LidInnerLower"

	# ── Tear / moisture details — transparent spheres at lower eye ──
	var tear_left: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.03 * s,
		Vector3(-0.06 * s, eye_y - 0.22 * s, -0.18 * s),
		mat_tear)
	tear_left.name = "TearLeft"

	var tear_right: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.03 * s,
		Vector3(0.06 * s, eye_y - 0.22 * s, -0.18 * s),
		mat_tear)
	tear_right.name = "TearRight"

	# ══════════════════════════════════════════════════════════════
	# NERVE TENTACLES — 8 capsules trailing from the back/bottom
	# ══════════════════════════════════════════════════════════════

	var tentacles: Array[MeshInstance3D] = []
	var mini_eyes: Array[MeshInstance3D] = []
	var nerve_nodes: Array[MeshInstance3D] = []

	# Each tentacle: [attach_offset, hang_rotation, length, has_mini_eye]
	var tentacle_data: Array = [
		[Vector3(0.0, -0.15, 0.3),   Vector3(0.5, 0.0, 0.0),    0.50, true],
		[Vector3(0.2, -0.1, 0.25),   Vector3(0.6, 0.0, -0.3),   0.45, false],
		[Vector3(-0.2, -0.1, 0.25),  Vector3(0.6, 0.0, 0.3),    0.45, true],
		[Vector3(0.15, -0.25, 0.2),  Vector3(0.8, 0.0, -0.2),   0.40, false],
		[Vector3(-0.15, -0.25, 0.2), Vector3(0.8, 0.0, 0.2),    0.40, true],
		[Vector3(0.1, -0.3, 0.15),   Vector3(1.0, 0.0, -0.15),  0.35, false],
		[Vector3(-0.1, -0.3, 0.15),  Vector3(1.0, 0.0, 0.15),   0.35, true],
		[Vector3(0.0, -0.35, 0.1),   Vector3(1.2, 0.0, 0.0),    0.30, false],
	]

	for ti: int in range(tentacle_data.size()):
		var td: Array = tentacle_data[ti]
		var t_offset: Vector3 = (td[0] as Vector3) * s + Vector3(0.0, eye_y, 0.0)
		var t_rot: Vector3 = td[1] as Vector3
		var t_len: float = (td[2] as float) * s
		var t_has_eye: bool = td[3] as bool
		var t_mat: StandardMaterial3D = mat_nerve if ti % 2 == 0 else mat_nerve_dark

		var tentacle: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.025 * s, t_len, t_offset, t_mat, t_rot)
		tentacle.name = "Tentacle%d" % ti
		tentacles.append(tentacle)

		# Secondary mini-eye at tentacle tip (4 tentacles get eyes)
		if t_has_eye:
			# Calculate approximate tip position
			var tip_dir: Vector3 = Vector3(0.0, -1.0, 0.0).rotated(
				Vector3.RIGHT, t_rot.x).rotated(
				Vector3.FORWARD, t_rot.z)
			var tip_pos: Vector3 = t_offset + tip_dir * t_len * 0.55
			var mini_eye: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.04 * s, tip_pos, mat_mini_eye)
			mini_eye.name = "MiniEye%d" % ti
			mini_eyes.append(mini_eye)

		# Additional mini-eyes at nerve tips without existing eyes (indices 1,3,5,7)
		if not t_has_eye:
			var tip_dir_extra: Vector3 = Vector3(0.0, -1.0, 0.0).rotated(
				Vector3.RIGHT, t_rot.x).rotated(
				Vector3.FORWARD, t_rot.z)
			var tip_pos_extra: Vector3 = t_offset + tip_dir_extra * t_len * 0.55
			var mini_eye_extra: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.04 * s, tip_pos_extra, mat_mini_eye)
			mini_eye_extra.name = "MiniEyeExtra%d" % ti
			mini_eyes.append(mini_eye_extra)

		# Nerve tentacle nodes — emissive midpoint spheres (indices 0,2,4,6)
		if ti % 2 == 0:
			var mid_dir: Vector3 = Vector3(0.0, -1.0, 0.0).rotated(
				Vector3.RIGHT, t_rot.x).rotated(
				Vector3.FORWARD, t_rot.z)
			var mid_pos: Vector3 = t_offset + mid_dir * t_len * 0.25
			var nerve_node: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.02 * s, mid_pos, mat_nerve_node)
			nerve_node.name = "NerveNode%d" % ti
			nerve_nodes.append(nerve_node)

	# ══════════════════════════════════════════════════════════════
	# AURA GLOW — large transparent sphere around the eyeball
	# ══════════════════════════════════════════════════════════════

	var aura: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.55 * s, Vector3(0.0, eye_y, 0.0),
		mat_aura)
	aura.name = "Aura"

	# ── Store animatable parts ──
	root.set_meta("iris_pivot", iris_pivot)
	root.set_meta("tentacles", tentacles)
	root.set_meta("mini_eyes", mini_eyes)
	root.set_meta("eyelids", [eyelid_upper, eyelid_lower])
	root.set_meta("aura", aura)
	root.set_meta("nerve_nodes", nerve_nodes)
	root.set_meta("eye_y", eye_y)
	root.set_meta("scale", s)

	return root


## Animate the eldritch eye each frame.
## Iris drifts around to "look", tentacles sway, body hovers with a gentle bob.
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = float(root.get_meta("scale", 1.0))
	var eye_y: float = float(root.get_meta("eye_y", 1.0))

	# ── Hover bob — gentle vertical oscillation ──
	var bob_speed: float = 2.0 if not is_moving else 3.5
	var bob_amount: float = 0.06 * s if not is_moving else 0.03 * s
	root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Iris look-around — slow, organic drifting gaze ──
	if root.has_meta("iris_pivot"):
		var iris_pivot: Node3D = root.get_meta("iris_pivot") as Node3D
		if iris_pivot != null:
			# Use two sine waves at different frequencies for natural movement
			var look_x: float = sin(phase * 0.7) * 0.12 + sin(phase * 1.3) * 0.05
			var look_y: float = cos(phase * 0.5) * 0.08 + sin(phase * 1.1) * 0.04
			iris_pivot.rotation.y = lerpf(iris_pivot.rotation.y, look_x, delta * 2.0)
			iris_pivot.rotation.x = lerpf(iris_pivot.rotation.x, look_y, delta * 2.0)

	# ── Tentacle sway — each tentacle sways with a phase offset ──
	if root.has_meta("tentacles"):
		var tentacles: Array = root.get_meta("tentacles") as Array
		for i: int in range(tentacles.size()):
			var tentacle: MeshInstance3D = tentacles[i] as MeshInstance3D
			if tentacle == null:
				continue
			var t_phase: float = phase * 1.5 + float(i) * 0.8
			var sway_x: float = sin(t_phase) * 0.15
			var sway_z: float = cos(t_phase * 0.7) * 0.1
			# When moving, tentacles trail back more
			if is_moving:
				sway_x += 0.2
			tentacle.rotation.x = lerpf(tentacle.rotation.x,
				tentacle.rotation.x + sway_x * delta, delta * 3.0)
			tentacle.rotation.z = lerpf(tentacle.rotation.z, sway_z, delta * 3.0)

	# ── Mini-eye pulse — subtle scale oscillation ──
	if root.has_meta("mini_eyes"):
		var mini_eyes: Array = root.get_meta("mini_eyes") as Array
		for i: int in range(mini_eyes.size()):
			var eye: MeshInstance3D = mini_eyes[i] as MeshInstance3D
			if eye == null:
				continue
			var pulse: float = 1.0 + sin(phase * 3.0 + float(i) * 1.5) * 0.15
			eye.scale = Vector3(pulse, pulse, pulse)

	# ── Nerve node pulse — scale oscillation on tentacle midpoint nodes ──
	if root.has_meta("nerve_nodes"):
		var nerve_nodes: Array = root.get_meta("nerve_nodes") as Array
		for i: int in range(nerve_nodes.size()):
			var node_mesh: MeshInstance3D = nerve_nodes[i] as MeshInstance3D
			if node_mesh == null:
				continue
			var n_pulse: float = 1.0 + sin(phase * 2.5 + float(i) * 1.2) * 0.25
			node_mesh.scale = Vector3(n_pulse, n_pulse, n_pulse)

	# ── Aura pulse — breathing glow effect ──
	if root.has_meta("aura"):
		var aura: MeshInstance3D = root.get_meta("aura") as MeshInstance3D
		if aura != null:
			var aura_pulse: float = 1.0 + sin(phase * 1.2) * 0.05
			aura.scale = Vector3(aura_pulse, aura_pulse, aura_pulse)

	# ── Eyelid micro-movement — subtle squeeze ──
	if root.has_meta("eyelids"):
		var eyelids: Array = root.get_meta("eyelids") as Array
		if eyelids.size() >= 2:
			var upper: MeshInstance3D = eyelids[0] as MeshInstance3D
			var lower: MeshInstance3D = eyelids[1] as MeshInstance3D
			# Occasional slow blink-like squeeze
			var blink_factor: float = maxf(0.0, sin(phase * 0.4) * 0.5 - 0.3) * 0.15
			if upper != null:
				upper.position.y = eye_y + (0.18 - blink_factor) * s
			if lower != null:
				lower.position.y = eye_y - (0.18 - blink_factor) * s
