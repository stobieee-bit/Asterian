## SwarmBugMesh — Tiny flying insect enemy mesh
##
## Small buzzing bugs with oval body, veined wings, dangling legs,
## antennae, and compound eyes. Color-banded abdomen segments.
## ~25 mesh nodes. Rapid wing-flap animation.
class_name SwarmBugMesh
extends EnemyMeshBuilder

func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x556B2F) as int)

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.3, 0.6)
	var mat_body_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.3, 0.6)
	var mat_body_light: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.10), 0.3, 0.6)
	var mat_wing: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.85, 0.92, 1.0), 0.1, 0.3,
		Color(0.7, 0.85, 1.0), 0.4,
		true, 0.3)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.15, 0.05), 0.5, 0.3,
		Color(1.0, 0.2, 0.0), 1.2)
	var mat_leg: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.18), 0.2, 0.7)
	var mat_antenna: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.2, 0.7)

	# ── Thorax (front body) ──
	var thorax: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.12 * s, Vector3(0.0, 0.3 * s, 0.06 * s),
		mat_body, Vector3(1.0, 0.85, 1.1))

	# ── Abdomen segments (banded color pattern) ──
	var abd_seg1: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.10 * s, Vector3(0.0, 0.28 * s, -0.12 * s),
		mat_body_dark, Vector3(1.0, 0.9, 1.1))
	var abd_seg2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.11 * s, Vector3(0.0, 0.27 * s, -0.24 * s),
		mat_body_light, Vector3(1.0, 0.85, 1.15))
	var abd_seg3: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.09 * s, Vector3(0.0, 0.26 * s, -0.35 * s),
		mat_body_dark, Vector3(1.0, 0.8, 1.1))

	# ── Head ──
	var head: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.08 * s, Vector3(0.0, 0.32 * s, 0.18 * s),
		mat_body, Vector3(1.0, 0.9, 0.9))

	# ── Compound eyes (left + right) ──
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.035 * s, Vector3(0.045 * s, 0.34 * s, 0.22 * s),
		mat_eye)
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.035 * s, Vector3(-0.045 * s, 0.34 * s, 0.22 * s),
		mat_eye)

	# ── Wings (left + right) — thin, semi-transparent ──
	var wing_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s, Vector3(0.14 * s, 0.38 * s, 0.0),
		mat_wing, Vector3(1.8, 0.08, 2.8))
	var wing_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s, Vector3(-0.14 * s, 0.38 * s, 0.0),
		mat_wing, Vector3(1.8, 0.08, 2.8))

	# ── Antennae (left + right) — thin capsules angled forward ──
	var ant_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.008 * s, 0.14 * s,
		Vector3(0.03 * s, 0.40 * s, 0.28 * s),
		mat_antenna, Vector3(-0.6, 0.0, 0.3))
	var ant_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.008 * s, 0.14 * s,
		Vector3(-0.03 * s, 0.40 * s, 0.28 * s),
		mat_antenna, Vector3(-0.6, 0.0, -0.3))
	# Antenna tips (tiny spheres)
	var ant_tip_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.012 * s, Vector3(0.05 * s, 0.46 * s, 0.38 * s),
		mat_antenna)
	var ant_tip_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.012 * s, Vector3(-0.05 * s, 0.46 * s, 0.38 * s),
		mat_antenna)

	# ── Wing veins (thin dark lines across each wing for detail) ──
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.1, 0.5,
		Color.BLACK, 0.0, true, 0.45)
	var vein_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.003 * s, 0.10 * s,
		Vector3(0.14 * s, 0.385 * s, 0.0),
		mat_vein, Vector3(0.0, 0.0, -PI * 0.5))
	var vein_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.003 * s, 0.10 * s,
		Vector3(-0.14 * s, 0.385 * s, 0.0),
		mat_vein, Vector3(0.0, 0.0, PI * 0.5))

	# ── Tail stinger (tiny cone at end of abdomen) ──
	var mat_stinger: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.18, 0.14, 0.10), 0.5, 0.4)
	var stinger: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.015 * s, 0.05 * s,
		Vector3(0.0, 0.25 * s, -0.42 * s),
		mat_stinger, Vector3(PI * 0.55, 0.0, 0.0))

	# ── Legs (6 total: 3 per side) — thin capsules dangling down ──
	var legs: Array[MeshInstance3D] = []
	var leg_offsets: Array[float] = [0.04, 0.0, -0.06]
	for i: int in range(3):
		var z_off: float = leg_offsets[i] * s
		# Left leg
		var leg_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.006 * s, 0.10 * s,
			Vector3(0.06 * s, 0.18 * s, z_off),
			mat_leg, Vector3(0.2, 0.0, 0.15))
		legs.append(leg_l)
		# Right leg
		var leg_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.006 * s, 0.10 * s,
			Vector3(-0.06 * s, 0.18 * s, z_off),
			mat_leg, Vector3(0.2, 0.0, -0.15))
		legs.append(leg_r)

	# ── Leg foot tips (tiny spheres at end of each leg) ──
	var feet: Array[MeshInstance3D] = []
	for i: int in range(3):
		var z_off: float = leg_offsets[i] * s
		var foot_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.005 * s, Vector3(0.07 * s, 0.10 * s, z_off),
			mat_leg)
		feet.append(foot_l)
		var foot_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.005 * s, Vector3(-0.07 * s, 0.10 * s, z_off),
			mat_leg)
		feet.append(foot_r)

	# ── Store animatable parts ──
	root.set_meta("wings", [wing_l, wing_r])
	root.set_meta("legs", legs)
	root.set_meta("antennae", [ant_l, ant_r, ant_tip_l, ant_tip_r])
	root.set_meta("body_parts", [thorax, abd_seg1, abd_seg2, abd_seg3, head])

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Wing buzz — rapid flapping ──
	if root.has_meta("wings"):
		var wings: Array = root.get_meta("wings") as Array
		# Very fast frequency for buzzing (phase * 15 gives ~15 cycles per phase radian)
		var flap_angle: float = sin(phase * 15.0) * 0.5
		if wings.size() >= 2:
			var wl: MeshInstance3D = wings[0] as MeshInstance3D
			var wr: MeshInstance3D = wings[1] as MeshInstance3D
			# Wings rotate around Z axis for up/down flap
			wl.rotation.z = flap_angle + 0.2
			wr.rotation.z = -flap_angle - 0.2

	# ── Idle body bob — gentle vertical float ──
	var bob_speed: float = 3.0 if not is_moving else 5.0
	var bob_amount: float = 0.02 if not is_moving else 0.01
	if root.has_meta("body_parts"):
		# Bob the entire root for simplicity
		root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Leg dangle — subtle swing ──
	if root.has_meta("legs"):
		var legs: Array = root.get_meta("legs") as Array
		for i: int in range(legs.size()):
			var leg: MeshInstance3D = legs[i] as MeshInstance3D
			var leg_phase: float = phase * 4.0 + float(i) * 1.0
			if is_moving:
				# Walking: more pronounced swing
				leg.rotation.x = sin(leg_phase) * 0.35
			else:
				# Idle: gentle sway
				leg.rotation.x = 0.2 + sin(leg_phase * 0.5) * 0.08

	# ── Antenna sway ──
	if root.has_meta("antennae"):
		var antennae: Array = root.get_meta("antennae") as Array
		if antennae.size() >= 2:
			var al: MeshInstance3D = antennae[0] as MeshInstance3D
			var ar: MeshInstance3D = antennae[1] as MeshInstance3D
			var sway: float = sin(phase * 2.5) * 0.12
			al.rotation.z = sway
			ar.rotation.z = -sway
