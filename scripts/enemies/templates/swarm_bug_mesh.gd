## SwarmBugMesh — Tiny flying insect enemy mesh
##
## Small buzzing bugs with oval body, veined wings, dangling legs,
## antennae, and compound eyes. Color-banded abdomen segments.
## Chitin plates, bioluminescent spots, segmentation ridges, compound
## eye facets, tarsal claws, and hind wings for high-detail rendering.
## Rapid wing-flap animation with hind wing offset.
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
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.1, 0.5,
		Color.BLACK, 0.0, true, 0.45)
	var mat_stinger: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.18, 0.14, 0.10), 0.5, 0.4)

	# New detail materials
	var mat_chitin_plate: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.5, 0.35)
	var mat_glow_spot: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.2, 0.85, 0.4), 0.0, 0.3,
		Color(0.2, 0.9, 0.4), 1.5)
	var mat_wing_frame: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.15, 0.5,
		Color.BLACK, 0.0, true, 0.5)
	var mat_joint: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.2), 0.4, 0.6)
	var mat_stinger_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.95, 0.5, 0.1), 0.0, 0.3,
		Color(1.0, 0.55, 0.1), 2.0)
	var mat_eye_facet: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.6, 0.1, 0.03), 0.6, 0.25,
		Color(0.7, 0.12, 0.0), 0.6)
	var mat_claw: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.12, 0.1, 0.08), 0.5, 0.4)

	# ── Thorax (front body) ──
	EnemyMeshBuilder.add_sphere(
		root, 0.12 * s, Vector3(0.0, 0.3 * s, 0.06 * s),
		mat_body, Vector3(1.0, 0.85, 1.1))

	# ── Chitin plate on thorax ──
	EnemyMeshBuilder.add_sphere(
		root, 0.08 * s, Vector3(0.0, 0.34 * s, 0.06 * s),
		mat_chitin_plate, Vector3(1.0, 0.3, 1.0))

	# ── Abdomen segments (banded color pattern) ──
	EnemyMeshBuilder.add_sphere(
		root, 0.10 * s, Vector3(0.0, 0.28 * s, -0.12 * s),
		mat_body_dark, Vector3(1.0, 0.9, 1.1))
	EnemyMeshBuilder.add_sphere(
		root, 0.11 * s, Vector3(0.0, 0.27 * s, -0.24 * s),
		mat_body_light, Vector3(1.0, 0.85, 1.15))
	EnemyMeshBuilder.add_sphere(
		root, 0.09 * s, Vector3(0.0, 0.26 * s, -0.35 * s),
		mat_body_dark, Vector3(1.0, 0.8, 1.1))

	# ── Chitin plates on abdomen segments ──
	EnemyMeshBuilder.add_sphere(
		root, 0.07 * s, Vector3(0.0, 0.32 * s, -0.12 * s),
		mat_chitin_plate, Vector3(0.95, 0.25, 1.0))
	EnemyMeshBuilder.add_sphere(
		root, 0.075 * s, Vector3(0.0, 0.31 * s, -0.24 * s),
		mat_chitin_plate, Vector3(0.95, 0.25, 1.05))
	EnemyMeshBuilder.add_sphere(
		root, 0.06 * s, Vector3(0.0, 0.30 * s, -0.35 * s),
		mat_chitin_plate, Vector3(0.9, 0.25, 0.95))

	# ── Abdomen segmentation ridges (torus rings between segments) ──
	EnemyMeshBuilder.add_torus(
		root, 0.005 * s, 0.09 * s, Vector3(0.0, 0.28 * s, -0.06 * s),
		mat_joint, Vector3(PI * 0.5, 0.0, 0.0))
	EnemyMeshBuilder.add_torus(
		root, 0.005 * s, 0.095 * s, Vector3(0.0, 0.275 * s, -0.18 * s),
		mat_joint, Vector3(PI * 0.5, 0.0, 0.0))
	EnemyMeshBuilder.add_torus(
		root, 0.005 * s, 0.085 * s, Vector3(0.0, 0.265 * s, -0.30 * s),
		mat_joint, Vector3(PI * 0.5, 0.0, 0.0))

	# ── Bioluminescent abdomen spots (2 per segment, lateral) ──
	var glow_spots: Array = []
	var abd_z_offsets: Array = [-0.12, -0.24, -0.35]
	var abd_radii: Array = [0.10, 0.11, 0.09]
	for i: int in range(3):
		for side: int in [-1, 1]:
			var spot: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.008 * s,
				Vector3(side * abd_radii[i] * 0.85 * s, 0.27 * s, abd_z_offsets[i] * s),
				mat_glow_spot)
			glow_spots.append(spot)

	# ── Head ──
	EnemyMeshBuilder.add_sphere(
		root, 0.08 * s, Vector3(0.0, 0.32 * s, 0.18 * s),
		mat_body, Vector3(1.0, 0.9, 0.9))

	# ── Compound eyes (left + right) ──
	EnemyMeshBuilder.add_sphere(
		root, 0.035 * s, Vector3(0.045 * s, 0.34 * s, 0.22 * s),
		mat_eye)
	EnemyMeshBuilder.add_sphere(
		root, 0.035 * s, Vector3(-0.045 * s, 0.34 * s, 0.22 * s),
		mat_eye)

	# ── Compound eye facets (smaller overlapping spheres for faceted look) ──
	for side: int in [-1, 1]:
		EnemyMeshBuilder.add_sphere(
			root, 0.018 * s,
			Vector3(side * 0.055 * s, 0.35 * s, 0.235 * s),
			mat_eye_facet)
		EnemyMeshBuilder.add_sphere(
			root, 0.015 * s,
			Vector3(side * 0.04 * s, 0.355 * s, 0.23 * s),
			mat_eye_facet)

	# ── Main wings (left + right) — thin, semi-transparent ──
	var wing_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s, Vector3(0.14 * s, 0.38 * s, 0.0),
		mat_wing, Vector3(1.8, 0.08, 2.8))
	var wing_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s, Vector3(-0.14 * s, 0.38 * s, 0.0),
		mat_wing, Vector3(1.8, 0.08, 2.8))

	# ── Hind wings (smaller, offset phase) ──
	var hind_wing_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s, Vector3(0.11 * s, 0.37 * s, -0.08 * s),
		mat_wing, Vector3(1.5, 0.06, 2.2))
	var hind_wing_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s, Vector3(-0.11 * s, 0.37 * s, -0.08 * s),
		mat_wing, Vector3(1.5, 0.06, 2.2))

	# ── Wing structural veins (4 per main wing, branching pattern) ──
	var vein_angles_l: Array = [-0.3, -0.1, 0.1, 0.3]
	for i: int in range(4):
		var a: float = vein_angles_l[i]
		EnemyMeshBuilder.add_capsule(
			root, 0.002 * s, 0.08 * s,
			Vector3((0.14 + cos(a) * 0.04) * s, 0.385 * s, sin(a) * 0.06 * s),
			mat_wing_frame, Vector3(0.0, a * 0.8, -PI * 0.5 + a * 0.3))
		EnemyMeshBuilder.add_capsule(
			root, 0.002 * s, 0.08 * s,
			Vector3((-0.14 - cos(a) * 0.04) * s, 0.385 * s, sin(a) * 0.06 * s),
			mat_wing_frame, Vector3(0.0, -a * 0.8, PI * 0.5 - a * 0.3))

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
	EnemyMeshBuilder.add_sphere(
		root, 0.012 * s, Vector3(0.05 * s, 0.46 * s, 0.38 * s),
		mat_antenna)
	EnemyMeshBuilder.add_sphere(
		root, 0.012 * s, Vector3(-0.05 * s, 0.46 * s, 0.38 * s),
		mat_antenna)

	# ── Tail stinger ──
	EnemyMeshBuilder.add_cone(
		root, 0.015 * s, 0.05 * s,
		Vector3(0.0, 0.25 * s, -0.42 * s),
		mat_stinger, Vector3(PI * 0.55, 0.0, 0.0))

	# ── Stinger glow tip ──
	EnemyMeshBuilder.add_sphere(
		root, 0.008 * s, Vector3(0.0, 0.23 * s, -0.45 * s),
		mat_stinger_glow)

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

	# ── Leg joints (spheres at leg-body attachment points) ──
	for i: int in range(3):
		var z_off: float = leg_offsets[i] * s
		EnemyMeshBuilder.add_sphere(
			root, 0.008 * s, Vector3(0.06 * s, 0.22 * s, z_off),
			mat_joint)
		EnemyMeshBuilder.add_sphere(
			root, 0.008 * s, Vector3(-0.06 * s, 0.22 * s, z_off),
			mat_joint)

	# ── Tarsal claws (2 tiny cones at each foot tip instead of spheres) ──
	for i: int in range(3):
		var z_off: float = leg_offsets[i] * s
		for side: int in [-1, 1]:
			# Inner claw
			EnemyMeshBuilder.add_cone(
				root, 0.004 * s, 0.02 * s,
				Vector3(side * 0.072 * s, 0.09 * s, z_off + 0.005 * s),
				mat_claw, Vector3(0.3, 0.0, 0.0))
			# Outer claw
			EnemyMeshBuilder.add_cone(
				root, 0.004 * s, 0.02 * s,
				Vector3(side * 0.072 * s, 0.09 * s, z_off - 0.005 * s),
				mat_claw, Vector3(0.3, 0.0, 0.0))

	# ── Store animatable parts ──
	root.set_meta("wings", [wing_l, wing_r])
	root.set_meta("hind_wings", [hind_wing_l, hind_wing_r])
	root.set_meta("legs", legs)
	root.set_meta("antennae", [ant_l, ant_r])
	root.set_meta("glow_spots", glow_spots)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, _delta: float) -> void:
	# ── Wing buzz — rapid flapping ──
	var wings: Array = root.get_meta("wings", [])
	var flap_angle: float = sin(phase * 15.0) * 0.5
	if wings.size() >= 2:
		var wl: MeshInstance3D = wings[0] as MeshInstance3D
		var wr: MeshInstance3D = wings[1] as MeshInstance3D
		wl.rotation.z = flap_angle + 0.2
		wr.rotation.z = -flap_angle - 0.2

	# ── Hind wing buzz — offset phase ──
	var hind_wings: Array = root.get_meta("hind_wings", [])
	var hind_flap: float = sin(phase * 15.0 + 0.4) * 0.4
	if hind_wings.size() >= 2:
		var hwl: MeshInstance3D = hind_wings[0] as MeshInstance3D
		var hwr: MeshInstance3D = hind_wings[1] as MeshInstance3D
		hwl.rotation.z = hind_flap + 0.15
		hwr.rotation.z = -hind_flap - 0.15

	# ── Idle body bob — gentle vertical float ──
	var bob_speed: float = 3.0 if not is_moving else 5.0
	var bob_amount: float = 0.02 if not is_moving else 0.01
	root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Leg dangle — subtle swing ──
	var legs: Array = root.get_meta("legs", [])
	for i: int in range(legs.size()):
		var leg: MeshInstance3D = legs[i] as MeshInstance3D
		var leg_phase: float = phase * 4.0 + float(i) * 1.0
		if is_moving:
			leg.rotation.x = sin(leg_phase) * 0.35
		else:
			leg.rotation.x = 0.2 + sin(leg_phase * 0.5) * 0.08

	# ── Antenna sway ──
	var antennae: Array = root.get_meta("antennae", [])
	if antennae.size() >= 2:
		var al: MeshInstance3D = antennae[0] as MeshInstance3D
		var ar: MeshInstance3D = antennae[1] as MeshInstance3D
		var sway: float = sin(phase * 2.5) * 0.12
		al.rotation.z = sway
		ar.rotation.z = -sway

	# ── Bioluminescent spot pulse ──
	var spots: Array = root.get_meta("glow_spots", [])
	for i: int in range(spots.size()):
		var spot: MeshInstance3D = spots[i] as MeshInstance3D
		var pulse: float = 0.85 + sin(phase * 2.0 + float(i) * 0.8) * 0.15
		spot.scale = Vector3(pulse, pulse, pulse)
