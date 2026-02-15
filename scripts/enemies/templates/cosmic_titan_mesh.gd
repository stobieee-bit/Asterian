## CosmicTitanMesh -- Massive cosmic being, final boss territory
##
## Enormous body with semi-transparent outer shell and bright inner core,
## crown of spikes, massive multi-segment arms with energy joints,
## pillar legs with energy boots, three glowing eyes on a void face,
## cosmic aura rings, orbiting celestial debris, and energy veins.
## ~55-65 mesh nodes. Cosmic ring rotation, debris orbit, energy pulse, stomp walk.
class_name CosmicTitanMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x3344AA) as int)

	# ── Materials ──
	# Deep cosmic body color (dark, slightly metallic)
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.5, 0.4)
	# Outer shell (semi-transparent, slight emissive glow)
	var cosmic_glow: Color = Color(0.3, 0.2, 0.9)
	var mat_shell: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.2, 0.3,
		cosmic_glow, 1.5,
		true, 0.3)
	# Inner core (bright intense emissive)
	var core_color: Color = Color(0.6, 0.4, 1.0)
	var mat_core: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color.WHITE, 0.0, 0.1,
		core_color, 6.0,
		true, 0.9)
	# Spike/crown material (dark metallic with subtle glow)
	var mat_spike: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.7, 0.3,
		cosmic_glow, 0.5)
	# Arm/leg armor
	var mat_limb: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.6, 0.35)
	var mat_limb_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.65, 0.3)
	# Energy joint spheres (bright emissive)
	var energy_color: Color = Color(0.5, 0.3, 1.0)
	var mat_energy: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		energy_color, 0.1, 0.2,
		energy_color, 4.0)
	# Eye material (intense glowing)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.5, 1.0), 0.0, 0.1,
		Color(1.0, 0.6, 1.0), 5.0)
	# Third eye (slightly different color)
	var mat_third_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(1.0, 0.3, 0.5), 0.0, 0.1,
		Color(1.0, 0.4, 0.6), 6.0)
	# Void face material (very dark, matte)
	var mat_void: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.02, 0.01, 0.05), 0.1, 0.9)
	# Cosmic ring material (semi-transparent, emissive)
	var mat_ring: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(cosmic_glow, 0.2), 0.15, 0.25,
		cosmic_glow, 2.5,
		true, 0.4)
	# Debris material (rocky, rough)
	var mat_debris: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.35, 0.28, 0.22), 0.3, 0.8)
	# Energy vein material (bright emissive capsules)
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		energy_color, 0.1, 0.2,
		energy_color, 3.5,
		true, 0.75)
	# Boot torus material (glowing energy at feet)
	var mat_boot: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		energy_color, 0.1, 0.2,
		energy_color, 3.0,
		true, 0.6)

	# ── Body layout ──
	var body_y: float = 1.8 * s  # center of massive torso

	# ══════════════════════════════════════════════════════
	# BODY -- massive central sphere with outer shell and inner core
	# ══════════════════════════════════════════════════════
	# Outer semi-transparent shell
	var shell: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.65 * s,
		Vector3(0.0, body_y, 0.0),
		mat_shell,
		Vector3(1.0, 1.05, 0.95))

	# Inner solid body
	var body_inner: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.5 * s,
		Vector3(0.0, body_y, 0.0),
		mat_body,
		Vector3(1.0, 1.0, 0.95))

	# Bright energy core
	var core: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.2 * s,
		Vector3(0.0, body_y, 0.0),
		mat_core)

	# ══════════════════════════════════════════════════════
	# CROWN OF SPIKES -- 8 large cones pointing upward from top
	# ══════════════════════════════════════════════════════
	var spikes: Array[MeshInstance3D] = []
	var spike_count: int = 8
	var spike_ring_radius: float = 0.35 * s
	var spike_base_y: float = body_y + 0.5 * s
	for i: int in range(spike_count):
		var angle: float = (float(i) / float(spike_count)) * TAU
		var spike_x: float = cos(angle) * spike_ring_radius
		var spike_z: float = sin(angle) * spike_ring_radius
		# Slight outward tilt
		var tilt_x: float = -sin(angle) * 0.3
		var tilt_z: float = cos(angle) * 0.3
		var spike: MeshInstance3D = EnemyMeshBuilder.add_cone(
			root, 0.06 * s, 0.3 * s,
			Vector3(spike_x, spike_base_y + 0.15 * s, spike_z),
			mat_spike,
			Vector3(tilt_x, 0.0, tilt_z))
		spikes.append(spike)

	# ══════════════════════════════════════════════════════
	# FACE -- dark void area with 3 glowing eyes
	# ══════════════════════════════════════════════════════
	var face_y: float = body_y + 0.15 * s
	var face_z: float = 0.5 * s

	# Void face plate (dark flat area)
	var face_void: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.35 * s, 0.3 * s, 0.04 * s),
		Vector3(0.0, face_y, face_z),
		mat_void)

	# Left eye
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.055 * s,
		Vector3(-0.1 * s, face_y, face_z + 0.03 * s),
		mat_eye)

	# Right eye
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.055 * s,
		Vector3(0.1 * s, face_y, face_z + 0.03 * s),
		mat_eye)

	# Third eye (above, centered, slightly larger)
	var eye_third: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.045 * s,
		Vector3(0.0, face_y + 0.15 * s, face_z + 0.03 * s),
		mat_third_eye)

	# ══════════════════════════════════════════════════════
	# LEFT ARM -- 3 capsule segments with energy at joints
	# ══════════════════════════════════════════════════════
	var arm_y: float = body_y + 0.2 * s

	# Left shoulder
	var l_arm_1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.1 * s, 0.3 * s,
		Vector3(-0.7 * s, arm_y, 0.0),
		mat_limb,
		Vector3(0.0, 0.0, 0.5))
	# Left shoulder-elbow energy joint
	var l_joint_1: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.055 * s,
		Vector3(-0.9 * s, arm_y - 0.15 * s, 0.0),
		mat_energy)
	# Left mid-arm
	var l_arm_2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.09 * s, 0.28 * s,
		Vector3(-0.95 * s, arm_y - 0.4 * s, 0.0),
		mat_limb_dark)
	# Left elbow-wrist energy joint
	var l_joint_2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.05 * s,
		Vector3(-0.95 * s, arm_y - 0.62 * s, 0.0),
		mat_energy)
	# Left forearm/hand
	var l_arm_3: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.25 * s,
		Vector3(-0.92 * s, arm_y - 0.85 * s, 0.0),
		mat_limb)
	# Left fist
	var l_fist: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.1 * s,
		Vector3(-0.9 * s, arm_y - 1.05 * s, 0.0),
		mat_limb_dark)

	# ══════════════════════════════════════════════════════
	# RIGHT ARM -- mirror of left
	# ══════════════════════════════════════════════════════
	var r_arm_1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.1 * s, 0.3 * s,
		Vector3(0.7 * s, arm_y, 0.0),
		mat_limb,
		Vector3(0.0, 0.0, -0.5))
	var r_joint_1: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.055 * s,
		Vector3(0.9 * s, arm_y - 0.15 * s, 0.0),
		mat_energy)
	var r_arm_2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.09 * s, 0.28 * s,
		Vector3(0.95 * s, arm_y - 0.4 * s, 0.0),
		mat_limb_dark)
	var r_joint_2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.05 * s,
		Vector3(0.95 * s, arm_y - 0.62 * s, 0.0),
		mat_energy)
	var r_arm_3: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.08 * s, 0.25 * s,
		Vector3(0.92 * s, arm_y - 0.85 * s, 0.0),
		mat_limb)
	var r_fist: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.1 * s,
		Vector3(0.9 * s, arm_y - 1.05 * s, 0.0),
		mat_limb_dark)

	# ══════════════════════════════════════════════════════
	# LEFT LEG -- thick pillar with energy boot torus
	# ══════════════════════════════════════════════════════
	var hip_y: float = body_y - 0.55 * s

	# Left upper leg (thick capsule pillar)
	var l_leg_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.12 * s, 0.35 * s,
		Vector3(-0.25 * s, hip_y - 0.22 * s, 0.0),
		mat_limb)
	# Left knee energy
	var l_knee: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s,
		Vector3(-0.25 * s, hip_y - 0.48 * s, 0.0),
		mat_energy)
	# Left lower leg
	var l_leg_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.11 * s, 0.32 * s,
		Vector3(-0.25 * s, hip_y - 0.75 * s, 0.0),
		mat_limb_dark)
	# Left energy boot (glowing torus at foot)
	var l_boot: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.03 * s, 0.12 * s,
		Vector3(-0.25 * s, hip_y - 1.0 * s, 0.0),
		mat_boot)
	# Left foot pad
	var l_foot: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.15 * s, 0.06 * s, 0.2 * s),
		Vector3(-0.25 * s, hip_y - 1.05 * s, 0.02 * s),
		mat_limb_dark)

	# ══════════════════════════════════════════════════════
	# RIGHT LEG -- mirror of left
	# ══════════════════════════════════════════════════════
	var r_leg_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.12 * s, 0.35 * s,
		Vector3(0.25 * s, hip_y - 0.22 * s, 0.0),
		mat_limb)
	var r_knee: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s,
		Vector3(0.25 * s, hip_y - 0.48 * s, 0.0),
		mat_energy)
	var r_leg_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.11 * s, 0.32 * s,
		Vector3(0.25 * s, hip_y - 0.75 * s, 0.0),
		mat_limb_dark)
	var r_boot: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.03 * s, 0.12 * s,
		Vector3(0.25 * s, hip_y - 1.0 * s, 0.0),
		mat_boot)
	var r_foot: MeshInstance3D = EnemyMeshBuilder.add_box(
		root, Vector3(0.15 * s, 0.06 * s, 0.2 * s),
		Vector3(0.25 * s, hip_y - 1.05 * s, 0.02 * s),
		mat_limb_dark)

	# ══════════════════════════════════════════════════════
	# COSMIC AURA RINGS -- 3 torus rings at various angles
	# ══════════════════════════════════════════════════════
	var ring_1: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.04 * s, 0.85 * s,
		Vector3(0.0, body_y, 0.0),
		mat_ring,
		Vector3(0.3, 0.0, 0.0))
	var ring_2: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.03 * s, 0.95 * s,
		Vector3(0.0, body_y + 0.05 * s, 0.0),
		mat_ring,
		Vector3(0.0, 0.0, 0.4))
	var ring_3: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.025 * s, 1.05 * s,
		Vector3(0.0, body_y - 0.05 * s, 0.0),
		mat_ring,
		Vector3(-0.2, 0.5, 0.0))

	# ══════════════════════════════════════════════════════
	# ORBITING CELESTIAL DEBRIS -- 6 rock chunks (boxes)
	# ══════════════════════════════════════════════════════
	var debris: Array[MeshInstance3D] = []
	var debris_count: int = 6
	var debris_orbit_radius: float = 1.3 * s
	for i: int in range(debris_count):
		var angle: float = (float(i) / float(debris_count)) * TAU
		var d_x: float = cos(angle) * debris_orbit_radius
		var d_z: float = sin(angle) * debris_orbit_radius
		var d_y: float = body_y + sin(angle * 2.0) * 0.2 * s
		# Vary chunk sizes
		var chunk_size: float = (0.06 + float(i % 3) * 0.025) * s
		var chunk: MeshInstance3D = EnemyMeshBuilder.add_box(
			root, Vector3(chunk_size, chunk_size * 0.8, chunk_size * 1.2),
			Vector3(d_x, d_y, d_z),
			mat_debris,
			Vector3(0.3 + float(i) * 0.2, 0.5 + float(i) * 0.15, 0.1 * float(i)))
		debris.append(chunk)

	# ══════════════════════════════════════════════════════
	# ENERGY VEINS -- bright capsule lines from core to extremities
	# ══════════════════════════════════════════════════════
	# Vein to left shoulder
	var vein_l_shoulder: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.02 * s, 0.35 * s,
		Vector3(-0.4 * s, body_y + 0.1 * s, 0.0),
		mat_vein,
		Vector3(0.0, 0.0, 0.7))
	# Vein to right shoulder
	var vein_r_shoulder: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.02 * s, 0.35 * s,
		Vector3(0.4 * s, body_y + 0.1 * s, 0.0),
		mat_vein,
		Vector3(0.0, 0.0, -0.7))
	# Vein down to left hip
	var vein_l_hip: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.018 * s, 0.3 * s,
		Vector3(-0.15 * s, body_y - 0.35 * s, 0.0),
		mat_vein,
		Vector3(0.0, 0.0, 0.15))
	# Vein down to right hip
	var vein_r_hip: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.018 * s, 0.3 * s,
		Vector3(0.15 * s, body_y - 0.35 * s, 0.0),
		mat_vein,
		Vector3(0.0, 0.0, -0.15))
	# Vein upward to crown
	var vein_crown: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.022 * s, 0.25 * s,
		Vector3(0.0, body_y + 0.42 * s, 0.0),
		mat_vein)

	# ── Store animatable parts ──
	root.set_meta("core", [core])
	root.set_meta("shell", [shell])
	root.set_meta("rings", [ring_1, ring_2, ring_3])
	root.set_meta("debris", debris)
	root.set_meta("eyes", [eye_l, eye_r, eye_third])
	root.set_meta("left_arm", [l_arm_1, l_joint_1, l_arm_2, l_joint_2, l_arm_3, l_fist])
	root.set_meta("right_arm", [r_arm_1, r_joint_1, r_arm_2, r_joint_2, r_arm_3, r_fist])
	root.set_meta("left_leg", [l_leg_upper, l_knee, l_leg_lower, l_boot, l_foot])
	root.set_meta("right_leg", [r_leg_upper, r_knee, r_leg_lower, r_boot, r_foot])
	root.set_meta("energy_joints", [l_joint_1, l_joint_2, r_joint_1, r_joint_2, l_knee, r_knee])
	root.set_meta("veins", [vein_l_shoulder, vein_r_shoulder, vein_l_hip, vein_r_hip, vein_crown])
	root.set_meta("scale", s)
	root.set_meta("body_y", body_y)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = root.get_meta("scale", 1.0) as float
	var body_y: float = root.get_meta("body_y", 1.8) as float

	# ── Cosmic rings rotate continuously ──
	var rings: Array = root.get_meta("rings", []) as Array
	if rings.size() >= 3:
		var r1: MeshInstance3D = rings[0] as MeshInstance3D
		r1.rotation.y += delta * 0.6
		r1.rotation.x = 0.3 + sin(phase * 0.3) * 0.1
		var r2: MeshInstance3D = rings[1] as MeshInstance3D
		r2.rotation.y -= delta * 0.45
		r2.rotation.z = 0.4 + sin(phase * 0.4) * 0.08
		var r3: MeshInstance3D = rings[2] as MeshInstance3D
		r3.rotation.y += delta * 0.35
		r3.rotation.x = -0.2 + cos(phase * 0.35) * 0.12

	# ── Debris orbits around the body ──
	var debris: Array = root.get_meta("debris", []) as Array
	var debris_orbit_radius: float = 1.3 * s
	for i: int in range(debris.size()):
		var chunk: MeshInstance3D = debris[i] as MeshInstance3D
		var base_angle: float = (float(i) / float(debris.size())) * TAU
		# Slow orbit with slight vertical wave
		var orbit_angle: float = base_angle + phase * 0.4
		var orbit_y: float = body_y + sin(phase * 0.7 + float(i) * 1.2) * 0.25 * s
		chunk.position = Vector3(
			cos(orbit_angle) * debris_orbit_radius,
			orbit_y,
			sin(orbit_angle) * debris_orbit_radius)
		# Tumble the chunks slowly
		chunk.rotation.x += delta * (0.8 + float(i) * 0.2)
		chunk.rotation.z += delta * (0.5 + float(i) * 0.15)

	# ── Energy core pulse ──
	var core_arr: Array = root.get_meta("core", []) as Array
	if core_arr.size() > 0:
		var core_node: MeshInstance3D = core_arr[0] as MeshInstance3D
		var pulse: float = 1.0 + sin(phase * 2.5) * 0.25
		core_node.scale = Vector3(pulse, pulse, pulse)
		if core_node.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = core_node.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 5.0 + sin(phase * 2.5) * 2.5

	# ── Shell breathing (subtle scale pulse) ──
	var shell_arr: Array = root.get_meta("shell", []) as Array
	if shell_arr.size() > 0:
		var shell_node: MeshInstance3D = shell_arr[0] as MeshInstance3D
		var breathe: float = 1.0 + sin(phase * 1.5) * 0.03
		shell_node.scale = Vector3(breathe, 1.05 * breathe, 0.95 * breathe)

	# ── Eye glow flicker ──
	var eyes: Array = root.get_meta("eyes", []) as Array
	for i: int in range(eyes.size()):
		var eye: MeshInstance3D = eyes[i] as MeshInstance3D
		if eye.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = eye.material_override as StandardMaterial3D
			var flicker: float = 4.0 + sin(phase * 5.0 + float(i) * 2.0) * 1.5
			mat.emission_energy_multiplier = flicker
		# Subtle scale pulse
		var eye_pulse: float = 1.0 + sin(phase * 3.0 + float(i) * 1.8) * 0.1
		eye.scale = Vector3(eye_pulse, eye_pulse, eye_pulse)

	# ── Energy joint pulse ──
	var joints: Array = root.get_meta("energy_joints", []) as Array
	for i: int in range(joints.size()):
		var joint: MeshInstance3D = joints[i] as MeshInstance3D
		var j_pulse: float = 1.0 + sin(phase * 4.0 + float(i) * 1.0) * 0.2
		joint.scale = Vector3(j_pulse, j_pulse, j_pulse)

	# ── Energy vein glow modulation ──
	var veins: Array = root.get_meta("veins", []) as Array
	for i: int in range(veins.size()):
		var vein: MeshInstance3D = veins[i] as MeshInstance3D
		if vein.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = vein.material_override as StandardMaterial3D
			# Traveling pulse effect along veins
			var vein_pulse: float = 2.5 + sin(phase * 3.0 + float(i) * 1.3) * 1.5
			mat.emission_energy_multiplier = vein_pulse

	# ── Heavy stomp walk ──
	var walk_speed: float = 3.0
	var walk_amp: float = 0.08 * s if is_moving else 0.0
	# Body heave (heavy steps cause vertical displacement)
	var body_heave: float = 0.0
	if is_moving:
		body_heave = absf(sin(phase * walk_speed * 2.0)) * 0.04 * s
	else:
		body_heave = sin(phase * 1.0) * 0.015 * s
	root.position.y = body_heave

	# Left leg stomp
	var left_leg: Array = root.get_meta("left_leg", []) as Array
	if left_leg.size() >= 5:
		var leg_swing: float = sin(phase * walk_speed) * walk_amp
		var ul: MeshInstance3D = left_leg[0] as MeshInstance3D
		ul.position.y += leg_swing * delta * 6.0
		var ll: MeshInstance3D = left_leg[2] as MeshInstance3D
		ll.position.y += leg_swing * 0.7 * delta * 6.0
		var ft: MeshInstance3D = left_leg[4] as MeshInstance3D
		ft.position.y += leg_swing * 0.5 * delta * 6.0

	# Right leg stomp (opposite phase)
	var right_leg: Array = root.get_meta("right_leg", []) as Array
	if right_leg.size() >= 5:
		var leg_swing: float = sin(phase * walk_speed + PI) * walk_amp
		var ul: MeshInstance3D = right_leg[0] as MeshInstance3D
		ul.position.y += leg_swing * delta * 6.0
		var ll: MeshInstance3D = right_leg[2] as MeshInstance3D
		ll.position.y += leg_swing * 0.7 * delta * 6.0
		var ft: MeshInstance3D = right_leg[4] as MeshInstance3D
		ft.position.y += leg_swing * 0.5 * delta * 6.0

	# ── Arm sway (slower, heavier than sentinel) ──
	var left_arm: Array = root.get_meta("left_arm", []) as Array
	var right_arm: Array = root.get_meta("right_arm", []) as Array

	if is_moving:
		var arm_sway_l: float = sin(phase * walk_speed + PI) * 0.05 * s
		var arm_sway_r: float = sin(phase * walk_speed) * 0.05 * s
		if left_arm.size() >= 6:
			var seg: MeshInstance3D = left_arm[4] as MeshInstance3D
			seg.position.y += arm_sway_l * delta * 5.0
			var fist: MeshInstance3D = left_arm[5] as MeshInstance3D
			fist.position.y += arm_sway_l * 1.3 * delta * 5.0
		if right_arm.size() >= 6:
			var seg: MeshInstance3D = right_arm[4] as MeshInstance3D
			seg.position.y += arm_sway_r * delta * 5.0
			var fist: MeshInstance3D = right_arm[5] as MeshInstance3D
			fist.position.y += arm_sway_r * 1.3 * delta * 5.0
	else:
		# Idle: very subtle fist drift
		if left_arm.size() >= 6:
			var drift: float = sin(phase * 0.8) * 0.01 * s
			var fist: MeshInstance3D = left_arm[5] as MeshInstance3D
			fist.position.y += drift * delta * 3.0
		if right_arm.size() >= 6:
			var drift: float = sin(phase * 0.8 + 0.7) * 0.01 * s
			var fist: MeshInstance3D = right_arm[5] as MeshInstance3D
			fist.position.y += drift * delta * 3.0
