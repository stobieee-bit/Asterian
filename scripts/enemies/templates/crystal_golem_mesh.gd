## CrystalGolemMesh -- Hulking crystal and rock golem enemy mesh
##
## A massive golem built from rough stone with crystalline growths.
## Large rocky torso, thick limbs, small head nestled between shoulders,
## angular crystal spikes protruding at various angles, and a ground
## crystal cluster at its feet. Rocky brown/gray base with emissive
## cyan/teal crystal accents.
## ~66 mesh nodes.
class_name CrystalGolemMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x6B5B4F) as int)

	# ── Materials ──

	# Rocky body -- high roughness, brown/gray, minimal metallic
	var mat_rock: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.1, 0.85)

	# Darker rock accents (joints, underside)
	var mat_rock_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.1, 0.9)

	# Lighter rock (shoulders, highlights)
	var mat_rock_light: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.15, 0.8)

	# Crystal material -- metallic cyan/teal with emissive glow
	var crystal_color: Color = Color(0.1, 0.85, 0.8)
	var mat_crystal: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		crystal_color, 0.7, 0.2,
		crystal_color, 2.5,
		true, 0.85)

	# Crystal eyes -- bright emissive cyan
	var mat_crystal_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.3, 1.0, 0.95), 0.6, 0.1,
		Color(0.2, 1.0, 0.9), 4.0)

	# Crystal dim -- darker crystal for ground clusters
	var mat_crystal_dim: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(crystal_color, 0.15), 0.6, 0.3,
		crystal_color, 1.2,
		true, 0.8)

	# Rock surface crack lines -- very dark, high roughness
	var mat_crack: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.25), 0.05, 0.95)

	# Crystal vein lines -- emissive translucent veins between crystals
	var mat_crystal_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		crystal_color, 0.5, 0.3,
		crystal_color, 1.5,
		true, 0.7)

	# Alien moss patches -- rough matte green
	var mat_moss: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.15, 0.4, 0.1), 0.0, 0.9)

	# ── Torso (large rocky sphere, slightly squashed) ──
	var torso: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.45 * s,
		Vector3(0.0, 0.90 * s, 0.0),
		mat_rock,
		Vector3(1.1, 0.95, 0.9))

	# ── Torso belly plate (overlapping rock slab) ──
	var belly: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.50 * s, 0.35 * s, 0.25 * s),
		Vector3(0.0, 0.80 * s, 0.20 * s),
		mat_rock_dark,
		Vector3(0.1, 0.0, 0.0))

	# ── Head (small sphere nestled between shoulders) ──
	var head: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.16 * s,
		Vector3(0.0, 1.35 * s, 0.08 * s),
		mat_rock_light)

	# ── Crystal eyes (glowing cyan) ──
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.035 * s,
		Vector3(0.065 * s, 1.37 * s, 0.20 * s),
		mat_crystal_eye)
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.035 * s,
		Vector3(-0.065 * s, 1.37 * s, 0.20 * s),
		mat_crystal_eye)

	# ── Shoulders (rocky spheres atop arms) ──
	var shoulder_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s,
		Vector3(0.48 * s, 1.18 * s, 0.0),
		mat_rock_light,
		Vector3(1.0, 0.85, 0.9))
	var shoulder_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s,
		Vector3(-0.48 * s, 1.18 * s, 0.0),
		mat_rock_light,
		Vector3(1.0, 0.85, 0.9))

	# ── Arms (thick capsules) ──
	var arm_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.10 * s, 0.50 * s,
		Vector3(0.52 * s, 0.75 * s, 0.05 * s),
		mat_rock,
		Vector3(0.15, 0.0, -0.1))
	var arm_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.10 * s, 0.50 * s,
		Vector3(-0.52 * s, 0.75 * s, 0.05 * s),
		mat_rock,
		Vector3(0.15, 0.0, 0.1))

	# ── Fists (rocky spheres at arm ends) ──
	var fist_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.10 * s,
		Vector3(0.55 * s, 0.45 * s, 0.10 * s),
		mat_rock_dark)
	var fist_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.10 * s,
		Vector3(-0.55 * s, 0.45 * s, 0.10 * s),
		mat_rock_dark)

	# ── Legs (thick capsules) ──
	var leg_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.12 * s, 0.40 * s,
		Vector3(0.22 * s, 0.30 * s, 0.0),
		mat_rock,
		Vector3(0.0, 0.0, 0.05))
	var leg_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.12 * s, 0.40 * s,
		Vector3(-0.22 * s, 0.30 * s, 0.0),
		mat_rock,
		Vector3(0.0, 0.0, -0.05))

	# ── Feet (blocky boxes) ──
	var foot_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.16 * s, 0.08 * s, 0.22 * s),
		Vector3(0.22 * s, 0.04 * s, 0.04 * s),
		mat_rock_dark)
	var foot_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.16 * s, 0.08 * s, 0.22 * s),
		Vector3(-0.22 * s, 0.04 * s, 0.04 * s),
		mat_rock_dark)

	# ── Crystal spike growths on body (8 cones/boxes at angles) ──
	var crystals: Array[MeshInstance3D] = []

	# Right shoulder spike (large)
	var c1: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.06 * s, 0.30 * s,
		Vector3(0.40 * s, 1.35 * s, -0.05 * s),
		mat_crystal,
		Vector3(-0.3, 0.0, -0.6))
	crystals.append(c1)

	# Left shoulder spike (large)
	var c2: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.055 * s, 0.28 * s,
		Vector3(-0.38 * s, 1.38 * s, 0.02 * s),
		mat_crystal,
		Vector3(-0.2, 0.0, 0.7))
	crystals.append(c2)

	# Back spike (tall)
	var c3: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.05 * s, 0.35 * s,
		Vector3(0.05 * s, 1.25 * s, -0.30 * s),
		mat_crystal,
		Vector3(0.4, 0.2, 0.0))
	crystals.append(c3)

	# Back spike small
	var c4: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.035 * s, 0.20 * s,
		Vector3(-0.12 * s, 1.15 * s, -0.28 * s),
		mat_crystal,
		Vector3(0.5, -0.3, 0.0))
	crystals.append(c4)

	# Right arm crystal shard (box shape)
	var c5: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.04 * s, 0.18 * s, 0.04 * s),
		Vector3(0.60 * s, 0.90 * s, 0.0),
		mat_crystal,
		Vector3(0.0, 0.3, -0.8))
	crystals.append(c5)

	# Left arm crystal shard (box shape)
	var c6: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.035 * s, 0.15 * s, 0.035 * s),
		Vector3(-0.58 * s, 0.85 * s, 0.05 * s),
		mat_crystal,
		Vector3(0.2, -0.2, 0.7))
	crystals.append(c6)

	# Chest crystal emergence
	var c7: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.04 * s, 0.16 * s,
		Vector3(0.15 * s, 1.05 * s, 0.32 * s),
		mat_crystal,
		Vector3(-0.8, 0.2, 0.0))
	crystals.append(c7)

	# Head crystal spike (small, sticking up)
	var c8: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.03 * s, 0.14 * s,
		Vector3(0.04 * s, 1.50 * s, -0.02 * s),
		mat_crystal,
		Vector3(0.15, 0.0, -0.2))
	crystals.append(c8)

	# ── Ground crystal cluster at feet (3 small cones sticking up) ──
	var ground_crystals: Array[MeshInstance3D] = []

	var gc1: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.04 * s, 0.15 * s,
		Vector3(0.30 * s, 0.075 * s, 0.15 * s),
		mat_crystal_dim,
		Vector3(-0.1, 0.3, 0.0))
	ground_crystals.append(gc1)

	var gc2: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.03 * s, 0.12 * s,
		Vector3(-0.28 * s, 0.06 * s, -0.10 * s),
		mat_crystal_dim,
		Vector3(0.15, -0.2, 0.1))
	ground_crystals.append(gc2)

	var gc3: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.035 * s, 0.10 * s,
		Vector3(0.10 * s, 0.05 * s, -0.20 * s),
		mat_crystal_dim,
		Vector3(0.2, 0.0, 0.3))
	ground_crystals.append(gc3)

	# ── Rock surface cracks (8 thin dark capsules on torso) ──
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(0.15 * s, 1.00 * s, 0.30 * s),
		mat_crack,
		Vector3(0.3, 0.8, 0.0))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(-0.10 * s, 0.95 * s, 0.32 * s),
		mat_crack,
		Vector3(-0.2, -0.5, 0.1))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(0.25 * s, 0.85 * s, 0.25 * s),
		mat_crack,
		Vector3(0.6, 0.3, -0.2))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(-0.20 * s, 1.05 * s, 0.28 * s),
		mat_crack,
		Vector3(-0.4, 0.6, 0.3))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(0.05 * s, 0.78 * s, 0.22 * s),
		mat_crack,
		Vector3(1.0, 0.0, 0.4))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(-0.18 * s, 0.88 * s, -0.20 * s),
		mat_crack,
		Vector3(0.5, -0.4, -0.3))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(0.20 * s, 1.10 * s, -0.18 * s),
		mat_crack,
		Vector3(-0.7, 0.2, 0.5))
	EnemyMeshBuilder.add_capsule(
		root, 0.006 * s, 0.12 * s,
		Vector3(0.0, 0.72 * s, 0.26 * s),
		mat_crack,
		Vector3(0.2, 1.0, -0.1))

	# ── Additional crystal spikes (6 smaller cones on body) ──
	# Left leg spike
	var cs1: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(0.28 * s, 0.35 * s, 0.08 * s),
		mat_crystal,
		Vector3(-0.4, 0.3, 0.5))
	crystals.append(cs1)

	# Right leg spike
	var cs2: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(-0.28 * s, 0.38 * s, -0.06 * s),
		mat_crystal,
		Vector3(0.3, -0.2, -0.6))
	crystals.append(cs2)

	# Left arm inner spike
	var cs3: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(0.48 * s, 0.65 * s, 0.12 * s),
		mat_crystal,
		Vector3(-0.6, 0.4, 0.2))
	crystals.append(cs3)

	# Right arm inner spike
	var cs4: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(-0.46 * s, 0.68 * s, 0.10 * s),
		mat_crystal,
		Vector3(0.5, -0.3, -0.4))
	crystals.append(cs4)

	# Upper back spike
	var cs5: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(0.18 * s, 1.20 * s, -0.35 * s),
		mat_crystal,
		Vector3(0.6, 0.5, 0.0))
	crystals.append(cs5)

	# Lower back spike
	var cs6: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(-0.08 * s, 0.90 * s, -0.32 * s),
		mat_crystal,
		Vector3(0.3, -0.6, 0.2))
	crystals.append(cs6)

	# ── Crystal vein lines (6 emissive capsules between crystal growths) ──
	# Vein between right shoulder spike (c1) and back spike (c3)
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(0.22 * s, 1.30 * s, -0.18 * s),
		mat_crystal_vein,
		Vector3(0.2, 0.1, -0.4))
	# Vein between left shoulder spike (c2) and head spike (c8)
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(-0.17 * s, 1.44 * s, 0.0),
		mat_crystal_vein,
		Vector3(-0.1, 0.0, 0.5))
	# Vein between chest crystal (c7) and right arm shard (c5)
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(0.38 * s, 0.98 * s, 0.16 * s),
		mat_crystal_vein,
		Vector3(-0.3, 0.5, -0.2))
	# Vein between left arm shard (c6) and back small spike (c4)
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(-0.35 * s, 1.00 * s, -0.12 * s),
		mat_crystal_vein,
		Vector3(0.4, -0.3, 0.3))
	# Vein across upper torso front
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(0.08 * s, 1.12 * s, 0.28 * s),
		mat_crystal_vein,
		Vector3(-0.5, 0.7, 0.0))
	# Vein across lower torso back
	EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.10 * s,
		Vector3(-0.05 * s, 0.82 * s, -0.25 * s),
		mat_crystal_vein,
		Vector3(0.6, 0.0, -0.3))

	# ── Alien moss patches (4 flattened green spheres) ──
	# Left shoulder moss
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.45 * s, 1.28 * s, -0.08 * s),
		mat_moss,
		Vector3(1.2, 0.3, 1.0))
	# Right shoulder moss
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(-0.42 * s, 1.26 * s, 0.06 * s),
		mat_moss,
		Vector3(1.2, 0.3, 1.0))
	# Upper back moss
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.0, 1.10 * s, -0.32 * s),
		mat_moss,
		Vector3(1.2, 0.3, 1.0))
	# Left leg moss
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.24 * s, 0.42 * s, 0.10 * s),
		mat_moss,
		Vector3(1.2, 0.3, 1.0))

	# ── Rubble at feet (6 irregular boxes at ground level) ──
	EnemyMeshBuilder.add_box(
		root, Vector3(0.07 * s, 0.04 * s, 0.05 * s),
		Vector3(0.35 * s, 0.03 * s, 0.12 * s),
		mat_rock_dark,
		Vector3(0.2, 0.5, 0.3))
	EnemyMeshBuilder.add_box(
		root, Vector3(0.05 * s, 0.04 * s, 0.06 * s),
		Vector3(-0.32 * s, 0.03 * s, -0.14 * s),
		mat_rock_dark,
		Vector3(-0.3, 0.8, 0.1))
	EnemyMeshBuilder.add_box(
		root, Vector3(0.06 * s, 0.05 * s, 0.04 * s),
		Vector3(0.12 * s, 0.03 * s, 0.25 * s),
		mat_rock_dark,
		Vector3(0.4, -0.2, 0.6))
	EnemyMeshBuilder.add_box(
		root, Vector3(0.04 * s, 0.04 * s, 0.07 * s),
		Vector3(-0.15 * s, 0.03 * s, 0.20 * s),
		mat_rock_dark,
		Vector3(-0.1, 0.6, -0.4))
	EnemyMeshBuilder.add_box(
		root, Vector3(0.05 * s, 0.05 * s, 0.05 * s),
		Vector3(0.28 * s, 0.03 * s, -0.18 * s),
		mat_rock_dark,
		Vector3(0.6, 0.3, 0.2))
	EnemyMeshBuilder.add_box(
		root, Vector3(0.06 * s, 0.04 * s, 0.06 * s),
		Vector3(-0.08 * s, 0.03 * s, -0.22 * s),
		mat_rock_dark,
		Vector3(-0.5, -0.4, 0.7))

	# ── Knuckle/finger detail (4 small spheres on fists) ──
	# Left fist knuckles
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(0.58 * s, 0.47 * s, 0.14 * s),
		mat_rock_dark)
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(0.52 * s, 0.43 * s, 0.06 * s),
		mat_rock_dark)
	# Right fist knuckles
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(-0.58 * s, 0.47 * s, 0.14 * s),
		mat_rock_dark)
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(-0.52 * s, 0.43 * s, 0.06 * s),
		mat_rock_dark)

	# ── Chest cavity inner glow (sphere + emerging cone) ──
	var chest_glow: Array[MeshInstance3D] = []

	var chest_glow_sphere: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.08 * s,
		Vector3(0.0, 0.92 * s, 0.10 * s),
		mat_crystal_eye)
	chest_glow.append(chest_glow_sphere)

	var chest_glow_cone: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.03 * s, 0.10 * s,
		Vector3(0.0, 0.98 * s, 0.28 * s),
		mat_crystal,
		Vector3(-0.7, 0.0, 0.0))
	crystals.append(chest_glow_cone)

	# ── Joint articulation (4 dark spheres at shoulder/hip joints) ──
	# Left shoulder joint
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.42 * s, 1.05 * s, 0.02 * s),
		mat_rock_dark)
	# Right shoulder joint
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(-0.42 * s, 1.05 * s, 0.02 * s),
		mat_rock_dark)
	# Left hip joint
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.20 * s, 0.52 * s, 0.02 * s),
		mat_rock_dark)
	# Right hip joint
	EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(-0.20 * s, 0.52 * s, 0.02 * s),
		mat_rock_dark)

	# ── Store animatable parts ──
	root.set_meta("torso", [torso, belly])
	root.set_meta("head", [head])
	root.set_meta("eyes", [eye_l, eye_r])
	root.set_meta("arms", [arm_l, arm_r, fist_l, fist_r])
	root.set_meta("shoulders", [shoulder_l, shoulder_r])
	root.set_meta("legs", [leg_l, leg_r])
	root.set_meta("feet", [foot_l, foot_r])
	root.set_meta("crystals", crystals)
	root.set_meta("ground_crystals", ground_crystals)
	root.set_meta("chest_glow", chest_glow)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Heavy body rock side to side ──
	var rock_speed: float = 3.0 if is_moving else 1.5
	var rock_amount: float = 0.06 if is_moving else 0.02
	root.rotation.z = sin(phase * rock_speed) * rock_amount

	# ── Stomping bob when moving ──
	if is_moving:
		# Double-frequency vertical stomp for heavy footfalls
		var stomp: float = absf(sin(phase * 6.0)) * 0.03
		root.position.y = -stomp
	else:
		# Idle: very subtle breathing bob
		root.position.y = sin(phase * 1.5) * 0.01

	# ── Leg animation (alternating forward/back when moving) ──
	if root.has_meta("legs"):
		var legs: Array = root.get_meta("legs") as Array
		if legs.size() >= 2:
			var leg_l: MeshInstance3D = legs[0] as MeshInstance3D
			var leg_r: MeshInstance3D = legs[1] as MeshInstance3D
			if is_moving:
				var stride: float = sin(phase * 3.0) * 0.25
				leg_l.rotation.x = stride
				leg_r.rotation.x = -stride
			else:
				leg_l.rotation.x = 0.0
				leg_r.rotation.x = 0.0

	# ── Foot stomp when moving ──
	if root.has_meta("feet") and is_moving:
		var feet: Array = root.get_meta("feet") as Array
		if feet.size() >= 2:
			var foot_l: MeshInstance3D = feet[0] as MeshInstance3D
			var foot_r: MeshInstance3D = feet[1] as MeshInstance3D
			foot_l.rotation.x = sin(phase * 3.0 + 0.5) * 0.15
			foot_r.rotation.x = sin(phase * 3.0 + PI + 0.5) * 0.15

	# ── Arm swing ──
	if root.has_meta("arms"):
		var arms: Array = root.get_meta("arms") as Array
		if arms.size() >= 4:
			var arm_l: MeshInstance3D = arms[0] as MeshInstance3D
			var arm_r: MeshInstance3D = arms[1] as MeshInstance3D
			var fist_l: MeshInstance3D = arms[2] as MeshInstance3D
			var fist_r: MeshInstance3D = arms[3] as MeshInstance3D
			if is_moving:
				# Arms swing opposite to legs
				var swing: float = sin(phase * 3.0) * 0.20
				arm_l.rotation.x = 0.15 - swing
				arm_r.rotation.x = 0.15 + swing
				fist_l.position.y = 0.45 + sin(phase * 3.0 + 0.3) * 0.03
				fist_r.position.y = 0.45 + sin(phase * 3.0 + PI + 0.3) * 0.03
			else:
				# Idle: slight sway
				var idle_swing: float = sin(phase * 1.2) * 0.04
				arm_l.rotation.x = 0.15 + idle_swing
				arm_r.rotation.x = 0.15 - idle_swing

	# ── Crystal glow pulse ──
	if root.has_meta("crystals"):
		var crystals: Array = root.get_meta("crystals") as Array
		for i: int in range(crystals.size()):
			var crystal: MeshInstance3D = crystals[i] as MeshInstance3D
			# Staggered scale pulse for each crystal
			var c_phase: float = phase * 2.0 + float(i) * 0.8
			var c_pulse: float = 1.0 + sin(c_phase) * 0.06
			crystal.scale = Vector3(c_pulse, c_pulse * 1.05, c_pulse)

	# ── Chest glow pulse ──
	if root.has_meta("chest_glow"):
		var chest_glow: Array = root.get_meta("chest_glow") as Array
		if chest_glow.size() >= 1:
			var glow_sphere: MeshInstance3D = chest_glow[0] as MeshInstance3D
			var glow_pulse: float = 1.0 + sin(phase * 2.5) * 0.1
			glow_sphere.scale = Vector3(glow_pulse, glow_pulse, glow_pulse)

	# ── Shoulder subtle shift ──
	if root.has_meta("shoulders"):
		var shoulders: Array = root.get_meta("shoulders") as Array
		if shoulders.size() >= 2:
			var sh_l: MeshInstance3D = shoulders[0] as MeshInstance3D
			var sh_r: MeshInstance3D = shoulders[1] as MeshInstance3D
			var sh_bob: float = sin(phase * rock_speed + 0.5) * 0.015
			sh_l.position.y = 1.18 + sh_bob
			sh_r.position.y = 1.18 - sh_bob
