## CosmicSentinelMesh -- Ancient armored guardian from deep space
##
## Humanoid alien/mechanical silhouette with angular armor plates,
## geometric head with glowing eye visor, bulky arms with pauldrons,
## thick legs with cube feet, energy core in chest, and floating
## cosmic shards near the shoulders.
## ~45-55 mesh nodes. Heavy march walk, core pulse, shard orbit.
class_name CosmicSentinelMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x556677) as int)

	# ── Materials ──
	# Primary metallic armor
	var mat_armor: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.7, 0.3)
	# Darker armor for contrast panels
	var mat_armor_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.75, 0.25)
	# Lighter trim
	var mat_armor_light: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.65, 0.35)
	# Cyan/teal emissive glow for energy accents
	var glow_color: Color = Color(0.0, 0.85, 0.95)
	var mat_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		glow_color, 0.2, 0.2,
		glow_color, 3.0)
	# Bright energy core (intense emissive)
	var mat_core: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color.WHITE, 0.0, 0.1,
		glow_color, 5.0,
		true, 0.85)
	# Floating shard material (emissive cyan, semi-transparent)
	var mat_shard: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(glow_color, 0.1), 0.3, 0.3,
		glow_color, 2.5,
		true, 0.7)
	# Eye visor material (bright emissive capsule)
	var mat_visor: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.0, 1.0, 1.0), 0.1, 0.15,
		Color(0.0, 1.0, 1.0), 4.0)
	# Joint/undersuit material (dark, matte)
	var mat_joint: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.2), 0.3, 0.7)

	# ── Body layout ──
	var body_y: float = 1.2 * s  # center of torso height

	# ══════════════════════════════════════════════════════
	# TORSO -- large sphere with angular armor plates
	# ══════════════════════════════════════════════════════
	var torso: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.4 * s,
		Vector3(0.0, body_y, 0.0),
		mat_armor,
		Vector3(1.0, 1.1, 0.85))

	# Chest armor plates (angled boxes on torso surface)
	var plate_chest_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.22 * s, 0.28 * s, 0.08 * s),
		Vector3(-0.18 * s, body_y + 0.08 * s, 0.3 * s),
		mat_armor_dark,
		Vector3(0.15, 0.2, 0.0))
	var plate_chest_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.22 * s, 0.28 * s, 0.08 * s),
		Vector3(0.18 * s, body_y + 0.08 * s, 0.3 * s),
		mat_armor_dark,
		Vector3(0.15, -0.2, 0.0))

	# Back armor plate
	var plate_back: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.35 * s, 0.3 * s, 0.06 * s),
		Vector3(0.0, body_y + 0.05 * s, -0.32 * s),
		mat_armor_dark)

	# Side torso armor plates
	var plate_side_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.06 * s, 0.25 * s, 0.2 * s),
		Vector3(-0.36 * s, body_y, 0.0),
		mat_armor_light,
		Vector3(0.0, 0.0, 0.1))
	var plate_side_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.06 * s, 0.25 * s, 0.2 * s),
		Vector3(0.36 * s, body_y, 0.0),
		mat_armor_light,
		Vector3(0.0, 0.0, -0.1))

	# ── Energy core (glowing sphere visible through front gap) ──
	var core: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.1 * s,
		Vector3(0.0, body_y, 0.2 * s),
		mat_core)

	# ══════════════════════════════════════════════════════
	# HEAD -- geometric angular shape with visor
	# ══════════════════════════════════════════════════════
	var head_y: float = body_y + 0.55 * s
	# Main head shape: angular sphere (scaled to look geometric)
	var head: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s,
		Vector3(0.0, head_y, 0.05 * s),
		mat_armor,
		Vector3(1.0, 1.15, 0.9))

	# Helmet crest (angular box on top)
	var crest: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.08 * s, 0.1 * s, 0.22 * s),
		Vector3(0.0, head_y + 0.16 * s, 0.0),
		mat_armor_dark)

	# Chin guard (box below head)
	var chin: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.12 * s, 0.06 * s, 0.1 * s),
		Vector3(0.0, head_y - 0.14 * s, 0.08 * s),
		mat_armor_dark)

	# Eye visor (bright cyan emissive capsule across the face)
	var visor: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.025 * s, 0.2 * s,
		Vector3(0.0, head_y + 0.02 * s, 0.16 * s),
		mat_visor,
		Vector3(0.0, 0.0, PI / 2.0))

	# Neck connector
	var neck: MeshInstance3D = EnemyMeshBuilder.add_cylinder(
		root, 0.08 * s, 0.1 * s, 0.12 * s,
		Vector3(0.0, body_y + 0.42 * s, 0.0),
		mat_joint)

	# ══════════════════════════════════════════════════════
	# LEFT ARM -- upper arm + forearm + fist + pauldron
	# ══════════════════════════════════════════════════════
	var arm_attach_y: float = body_y + 0.28 * s

	# Left shoulder pauldron (angular box)
	var pauldron_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.2 * s, 0.12 * s, 0.18 * s),
		Vector3(-0.48 * s, arm_attach_y + 0.06 * s, 0.0),
		mat_armor_dark,
		Vector3(0.0, 0.0, -0.15))

	# Left upper arm
	var upper_arm_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.22 * s,
		Vector3(-0.48 * s, arm_attach_y - 0.16 * s, 0.0),
		mat_armor)

	# Left elbow joint glow
	var elbow_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(-0.48 * s, arm_attach_y - 0.32 * s, 0.0),
		mat_glow)

	# Left forearm
	var forearm_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.07 * s, 0.2 * s,
		Vector3(-0.48 * s, arm_attach_y - 0.52 * s, 0.0),
		mat_armor_light)

	# Left fist (large sphere)
	var fist_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.09 * s,
		Vector3(-0.48 * s, arm_attach_y - 0.7 * s, 0.0),
		mat_armor_dark)

	# ══════════════════════════════════════════════════════
	# RIGHT ARM -- mirror of left
	# ══════════════════════════════════════════════════════
	var pauldron_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.2 * s, 0.12 * s, 0.18 * s),
		Vector3(0.48 * s, arm_attach_y + 0.06 * s, 0.0),
		mat_armor_dark,
		Vector3(0.0, 0.0, 0.15))

	var upper_arm_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.22 * s,
		Vector3(0.48 * s, arm_attach_y - 0.16 * s, 0.0),
		mat_armor)

	var elbow_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.48 * s, arm_attach_y - 0.32 * s, 0.0),
		mat_glow)

	var forearm_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.07 * s, 0.2 * s,
		Vector3(0.48 * s, arm_attach_y - 0.52 * s, 0.0),
		mat_armor_light)

	var fist_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.09 * s,
		Vector3(0.48 * s, arm_attach_y - 0.7 * s, 0.0),
		mat_armor_dark)

	# ══════════════════════════════════════════════════════
	# LEFT LEG -- upper leg + lower leg + foot
	# ══════════════════════════════════════════════════════
	var hip_y: float = body_y - 0.38 * s

	# Left hip joint
	var hip_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s,
		Vector3(-0.18 * s, hip_y, 0.0),
		mat_joint)

	# Left upper leg
	var upper_leg_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.09 * s, 0.28 * s,
		Vector3(-0.18 * s, hip_y - 0.22 * s, 0.0),
		mat_armor)

	# Left knee glow
	var knee_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.045 * s,
		Vector3(-0.18 * s, hip_y - 0.42 * s, 0.0),
		mat_glow)

	# Left lower leg
	var lower_leg_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.26 * s,
		Vector3(-0.18 * s, hip_y - 0.64 * s, 0.0),
		mat_armor_light)

	# Left leg armor plate
	var leg_plate_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.1 * s, 0.18 * s, 0.06 * s),
		Vector3(-0.18 * s, hip_y - 0.58 * s, 0.08 * s),
		mat_armor_dark)

	# Left foot (cube)
	var foot_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.12 * s, 0.06 * s, 0.18 * s),
		Vector3(-0.18 * s, hip_y - 0.85 * s, 0.03 * s),
		mat_armor_dark)

	# ══════════════════════════════════════════════════════
	# RIGHT LEG -- mirror of left
	# ══════════════════════════════════════════════════════
	var hip_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s,
		Vector3(0.18 * s, hip_y, 0.0),
		mat_joint)

	var upper_leg_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.09 * s, 0.28 * s,
		Vector3(0.18 * s, hip_y - 0.22 * s, 0.0),
		mat_armor)

	var knee_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.045 * s,
		Vector3(0.18 * s, hip_y - 0.42 * s, 0.0),
		mat_glow)

	var lower_leg_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.26 * s,
		Vector3(0.18 * s, hip_y - 0.64 * s, 0.0),
		mat_armor_light)

	var leg_plate_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.1 * s, 0.18 * s, 0.06 * s),
		Vector3(0.18 * s, hip_y - 0.58 * s, 0.08 * s),
		mat_armor_dark)

	var foot_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.12 * s, 0.06 * s, 0.18 * s),
		Vector3(0.18 * s, hip_y - 0.85 * s, 0.03 * s),
		mat_armor_dark)

	# ── Forearm armor plates ──
	var arm_plate_l: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.08 * s, 0.14 * s, 0.06 * s),
		Vector3(-0.48 * s, arm_attach_y - 0.48 * s, 0.08 * s),
		mat_armor_dark)
	var arm_plate_r: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.08 * s, 0.14 * s, 0.06 * s),
		Vector3(0.48 * s, arm_attach_y - 0.48 * s, 0.08 * s),
		mat_armor_dark)

	# ── Waist belt / hip armor ──
	var waist: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.03 * s, 0.28 * s,
		Vector3(0.0, body_y - 0.3 * s, 0.0),
		mat_armor_light)

	# ══════════════════════════════════════════════════════
	# FLOATING COSMIC SHARDS -- 4 small boxes near shoulders
	# ══════════════════════════════════════════════════════
	var shards: Array[MeshInstance3D] = []
	var shard_angles: Array[float] = [0.0, 1.6, 3.2, 4.8]
	var shard_radius: float = 0.6 * s
	for i: int in range(4):
		var angle: float = shard_angles[i]
		var shard_x: float = cos(angle) * shard_radius
		var shard_z: float = sin(angle) * shard_radius
		var shard_y: float = body_y + 0.35 * s + float(i % 2) * 0.12 * s
		var shard: MeshInstance3D = EnemyMeshBuilder.add_box(
			root, Vector3(0.05 * s, 0.08 * s, 0.04 * s),
			Vector3(shard_x, shard_y, shard_z),
			mat_shard,
			Vector3(0.4, 0.6 + float(i) * 0.3, 0.2))
		shards.append(shard)

	# ── Store animatable parts ──
	root.set_meta("left_arm", [upper_arm_l, elbow_l, forearm_l, fist_l, pauldron_l])
	root.set_meta("right_arm", [upper_arm_r, elbow_r, forearm_r, fist_r, pauldron_r])
	root.set_meta("left_leg", [hip_l, upper_leg_l, knee_l, lower_leg_l, leg_plate_l, foot_l])
	root.set_meta("right_leg", [hip_r, upper_leg_r, knee_r, lower_leg_r, leg_plate_r, foot_r])
	root.set_meta("core", [core])
	root.set_meta("shards", shards)
	root.set_meta("visor", [visor])
	root.set_meta("head_parts", [head, crest, chin, visor, neck])
	root.set_meta("scale", s)
	root.set_meta("body_y", body_y)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = root.get_meta("scale", 1.0) as float
	var body_y: float = root.get_meta("body_y", 1.2) as float

	# ── Heavy march walk ──
	var walk_speed: float = 4.0
	var walk_amp: float = 0.06 * s if is_moving else 0.0
	var body_bob: float = sin(phase * walk_speed * 2.0) * 0.03 * s if is_moving else sin(phase * 1.5) * 0.01 * s

	# Bob the entire root
	root.position.y = body_bob

	# Left leg swing (forward/back on walk)
	var left_leg: Array = root.get_meta("left_leg", []) as Array
	if left_leg.size() >= 6:
		var leg_swing: float = sin(phase * walk_speed) * walk_amp
		# Upper leg
		var ul: MeshInstance3D = left_leg[1] as MeshInstance3D
		ul.position.y += leg_swing * delta * 8.0
		# Lower leg
		var ll: MeshInstance3D = left_leg[3] as MeshInstance3D
		ll.position.y += leg_swing * 0.7 * delta * 8.0
		# Foot
		var ft: MeshInstance3D = left_leg[5] as MeshInstance3D
		ft.position.y += leg_swing * 0.5 * delta * 8.0

	# Right leg swing (opposite phase)
	var right_leg: Array = root.get_meta("right_leg", []) as Array
	if right_leg.size() >= 6:
		var leg_swing: float = sin(phase * walk_speed + PI) * walk_amp
		var ul: MeshInstance3D = right_leg[1] as MeshInstance3D
		ul.position.y += leg_swing * delta * 8.0
		var ll: MeshInstance3D = right_leg[3] as MeshInstance3D
		ll.position.y += leg_swing * 0.7 * delta * 8.0
		var ft: MeshInstance3D = right_leg[5] as MeshInstance3D
		ft.position.y += leg_swing * 0.5 * delta * 8.0

	# ── Arm swing (opposite to legs when walking, idle sway otherwise) ──
	var left_arm: Array = root.get_meta("left_arm", []) as Array
	var right_arm: Array = root.get_meta("right_arm", []) as Array

	if is_moving:
		var arm_swing_l: float = sin(phase * walk_speed + PI) * 0.04 * s
		var arm_swing_r: float = sin(phase * walk_speed) * 0.04 * s
		if left_arm.size() >= 4:
			var ua: MeshInstance3D = left_arm[0] as MeshInstance3D
			ua.position.y += arm_swing_l * delta * 8.0
			var fa: MeshInstance3D = left_arm[2] as MeshInstance3D
			fa.position.y += arm_swing_l * 1.2 * delta * 8.0
			var fist: MeshInstance3D = left_arm[3] as MeshInstance3D
			fist.position.y += arm_swing_l * 1.4 * delta * 8.0
		if right_arm.size() >= 4:
			var ua: MeshInstance3D = right_arm[0] as MeshInstance3D
			ua.position.y += arm_swing_r * delta * 8.0
			var fa: MeshInstance3D = right_arm[2] as MeshInstance3D
			fa.position.y += arm_swing_r * 1.2 * delta * 8.0
			var fist: MeshInstance3D = right_arm[3] as MeshInstance3D
			fist.position.y += arm_swing_r * 1.4 * delta * 8.0
	else:
		# Idle: subtle arm sway
		if left_arm.size() >= 4:
			var sway: float = sin(phase * 1.2) * 0.008 * s
			var fist: MeshInstance3D = left_arm[3] as MeshInstance3D
			fist.position.y += sway * delta * 5.0
		if right_arm.size() >= 4:
			var sway: float = sin(phase * 1.2 + 0.5) * 0.008 * s
			var fist: MeshInstance3D = right_arm[3] as MeshInstance3D
			fist.position.y += sway * delta * 5.0

	# ── Energy core pulse ──
	var core_arr: Array = root.get_meta("core", []) as Array
	if core_arr.size() > 0:
		var core_node: MeshInstance3D = core_arr[0] as MeshInstance3D
		var pulse: float = 1.0 + sin(phase * 3.5) * 0.2
		core_node.scale = Vector3(pulse, pulse, pulse)
		# Also modulate emission energy on the material
		if core_node.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = core_node.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 4.0 + sin(phase * 3.5) * 2.0

	# ── Visor glow pulse (subtle) ──
	var visor_arr: Array = root.get_meta("visor", []) as Array
	if visor_arr.size() > 0:
		var visor_node: MeshInstance3D = visor_arr[0] as MeshInstance3D
		if visor_node.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = visor_node.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 3.5 + sin(phase * 2.0) * 1.0

	# ── Floating shards orbit ──
	var shards: Array = root.get_meta("shards", []) as Array
	var shard_radius: float = 0.6 * s
	for i: int in range(shards.size()):
		var shard: MeshInstance3D = shards[i] as MeshInstance3D
		var base_angle: float = float(i) * (TAU / float(shards.size()))
		var orbit_angle: float = base_angle + phase * 0.8
		var orbit_y: float = body_y + 0.35 * s + sin(phase * 2.0 + float(i) * 1.5) * 0.06 * s
		shard.position = Vector3(
			cos(orbit_angle) * shard_radius,
			orbit_y,
			sin(orbit_angle) * shard_radius)
		# Spin the shards on their own axis
		shard.rotation.y = phase * 2.0 + float(i)
		shard.rotation.x = phase * 1.5
