## ArachnidMesh — Spider-like enemy mesh
##
## Cephalothorax + abdomen body, 8 articulated legs with joints,
## chelicerae, pedipalps, clustered eyes, and spinnerets.
## ~50 mesh nodes. Alternating leg gait when walking, subtle curl when idle.
class_name ArachnidMesh
extends EnemyMeshBuilder

func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x3B2F2F) as int)

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.35, 0.55)
	var mat_abdomen: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.06), 0.3, 0.6)
	var mat_leg: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.3, 0.65)
	var mat_joint: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.14), 0.4, 0.5)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.85, 0.08, 0.05), 0.5, 0.3,
		Color(1.0, 0.1, 0.0), 1.5)
	var mat_fang: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.15, 0.12, 0.10), 0.6, 0.4)
	var mat_pedipalp: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.03), 0.3, 0.6)
	var mat_spinneret: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.10), 0.25, 0.7)

	# ── Cephalothorax (front body section) ──
	var cephalothorax: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.22 * s, Vector3(0.0, 0.25 * s, 0.12 * s),
		mat_body, Vector3(1.1, 0.8, 1.0))

	# ── Abdomen (rear body, larger and rounder) ──
	var abdomen: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.30 * s, Vector3(0.0, 0.28 * s, -0.30 * s),
		mat_abdomen, Vector3(1.0, 0.85, 1.2))

	# ── Eyes — cluster of small red spheres on front of cephalothorax ──
	# Layout: 2 large center eyes, 2 medium outer, 2 small lower, 2 tiny top
	var eye_positions: Array[Vector3] = [
		Vector3(0.045 * s, 0.30 * s, 0.30 * s),   # center-right
		Vector3(-0.045 * s, 0.30 * s, 0.30 * s),   # center-left
		Vector3(0.09 * s, 0.28 * s, 0.27 * s),     # outer-right
		Vector3(-0.09 * s, 0.28 * s, 0.27 * s),    # outer-left
		Vector3(0.035 * s, 0.25 * s, 0.31 * s),    # lower-right
		Vector3(-0.035 * s, 0.25 * s, 0.31 * s),   # lower-left
		Vector3(0.03 * s, 0.34 * s, 0.28 * s),     # top-right
		Vector3(-0.03 * s, 0.34 * s, 0.28 * s),    # top-left
	]
	var eye_radii: Array[float] = [
		0.022 * s, 0.022 * s,  # center pair (largest)
		0.016 * s, 0.016 * s,  # outer pair
		0.013 * s, 0.013 * s,  # lower pair
		0.010 * s, 0.010 * s,  # top pair (smallest)
	]
	var eyes: Array[MeshInstance3D] = []
	for i: int in range(8):
		var eye: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, eye_radii[i], eye_positions[i], mat_eye)
		eyes.append(eye)

	# ── Chelicerae (fangs — 2 downward cones at front) ──
	var fang_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(0.05 * s, 0.16 * s, 0.30 * s),
		mat_fang, Vector3(PI * 0.85, 0.0, 0.15))
	var fang_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.12 * s,
		Vector3(-0.05 * s, 0.16 * s, 0.30 * s),
		mat_fang, Vector3(PI * 0.85, 0.0, -0.15))

	# ── Pedipalps (2 small arm-like appendages near mouth) ──
	var pp_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.018 * s, 0.08 * s,
		Vector3(0.08 * s, 0.22 * s, 0.28 * s),
		mat_pedipalp, Vector3(-0.4, 0.0, 0.3))
	var pp_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.018 * s, 0.08 * s,
		Vector3(-0.08 * s, 0.22 * s, 0.28 * s),
		mat_pedipalp, Vector3(-0.4, 0.0, -0.3))
	# Pedipalp tips (small spheres for the "hand")
	var pp_tip_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.015 * s, Vector3(0.10 * s, 0.19 * s, 0.33 * s),
		mat_pedipalp)
	var pp_tip_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.015 * s, Vector3(-0.10 * s, 0.19 * s, 0.33 * s),
		mat_pedipalp)

	# ── Spinnerets (2-3 small cones at rear of abdomen) ──
	var spin_c: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.022 * s, 0.06 * s,
		Vector3(0.0, 0.22 * s, -0.56 * s),
		mat_spinneret, Vector3(PI * 0.55, 0.0, 0.0))
	var spin_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.018 * s, 0.05 * s,
		Vector3(0.03 * s, 0.24 * s, -0.54 * s),
		mat_spinneret, Vector3(PI * 0.6, 0.0, 0.2))
	var spin_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.018 * s, 0.05 * s,
		Vector3(-0.03 * s, 0.24 * s, -0.54 * s),
		mat_spinneret, Vector3(PI * 0.6, 0.0, -0.2))

	# ── Legs — 8 total (4 per side) ──
	# Each leg: upper segment (capsule) + joint ball (sphere) + lower segment (capsule)
	# Legs attach at cephalothorax sides, spread outward and down
	var legs_upper: Array[MeshInstance3D] = []
	var legs_joint: Array[MeshInstance3D] = []
	var legs_lower: Array[MeshInstance3D] = []

	# Z offsets for 4 leg pairs (front to back along cephalothorax)
	var leg_z_offsets: Array[float] = [0.18, 0.08, -0.02, -0.12]
	# X spread increases slightly for rear legs
	var leg_x_base: Array[float] = [0.18, 0.20, 0.22, 0.20]
	# Upper leg angles (front legs reach forward, rear legs reach back)
	var leg_angle_z: Array[float] = [0.4, 0.15, -0.15, -0.4]

	for i: int in range(4):
		var z_off: float = leg_z_offsets[i] * s
		var x_base: float = leg_x_base[i] * s
		var ang_z: float = leg_angle_z[i]

		# ── Left leg ──
		# Upper segment — extends outward from body
		var ul: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.016 * s, 0.16 * s,
			Vector3(x_base, 0.26 * s, z_off),
			mat_leg, Vector3(0.0, 0.0, -0.9 + ang_z))
		legs_upper.append(ul)

		# Joint — small ball at the "knee"
		var jl_x: float = x_base + 0.14 * s
		var jl_y: float = 0.30 * s
		var jl: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.018 * s,
			Vector3(jl_x, jl_y, z_off),
			mat_joint)
		legs_joint.append(jl)

		# Lower segment — extends downward from knee to ground
		var ll: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, 0.20 * s,
			Vector3(jl_x + 0.04 * s, 0.12 * s, z_off),
			mat_leg, Vector3(0.0, 0.0, -0.25 + ang_z * 0.3))
		legs_lower.append(ll)

		# ── Right leg (mirrored X) ──
		var ur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.016 * s, 0.16 * s,
			Vector3(-x_base, 0.26 * s, z_off),
			mat_leg, Vector3(0.0, 0.0, 0.9 - ang_z))
		legs_upper.append(ur)

		var jr: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.018 * s,
			Vector3(-jl_x, jl_y, z_off),
			mat_joint)
		legs_joint.append(jr)

		var lr: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, 0.20 * s,
			Vector3(-jl_x - 0.04 * s, 0.12 * s, z_off),
			mat_leg, Vector3(0.0, 0.0, 0.25 - ang_z * 0.3))
		legs_lower.append(lr)

	# ── Store animatable parts ──
	root.set_meta("legs_upper", legs_upper)
	root.set_meta("legs_joint", legs_joint)
	root.set_meta("legs_lower", legs_lower)
	root.set_meta("pedipalps", [pp_l, pp_r, pp_tip_l, pp_tip_r])
	root.set_meta("chelicerae", [fang_l, fang_r])
	root.set_meta("abdomen", abdomen)
	root.set_meta("cephalothorax", cephalothorax)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Leg animation ──
	# Alternating tetrapod gait: legs 0,3,4,7 move together, legs 1,2,5,6 move together
	# (Groups: pair 0+3 left-side, pair 1+2 right-side — standard spider gait)
	if root.has_meta("legs_upper") and root.has_meta("legs_lower"):
		var uppers: Array = root.get_meta("legs_upper") as Array
		var lowers: Array = root.get_meta("legs_lower") as Array

		for i: int in range(uppers.size()):
			var upper: MeshInstance3D = uppers[i] as MeshInstance3D
			var lower: MeshInstance3D = lowers[i] as MeshInstance3D

			# Alternating gait groups: even index vs odd index in each pair
			# Array is [L0, R0, L1, R1, L2, R2, L3, R3]
			# Spider gait group A: L0, R1, L2, R3 (indices 0,3,4,7)
			# Spider gait group B: R0, L1, R2, L3 (indices 1,2,5,6)
			var gait_offset: float = 0.0
			if i == 0 or i == 3 or i == 4 or i == 7:
				gait_offset = 0.0
			else:
				gait_offset = PI

			if is_moving:
				# Walking — pronounced leg cycling
				var walk_phase: float = phase * 5.0 + gait_offset
				var swing: float = sin(walk_phase) * 0.3
				var lift: float = maxf(0.0, sin(walk_phase)) * 0.04

				# Upper leg swings forward/backward
				upper.rotation.x = swing * 0.5
				# Lower leg bends at knee during lift
				lower.rotation.x = swing * 0.3 - 0.1
				lower.position.y += lift * delta * 10.0
			else:
				# Idle — subtle curl/breathe
				var idle_phase: float = phase * 1.5 + float(i) * 0.4
				var curl: float = sin(idle_phase) * 0.06
				upper.rotation.x = curl
				lower.rotation.x = curl * 0.5

	# ── Pedipalp animation — gentle probing motion ──
	if root.has_meta("pedipalps"):
		var palps: Array = root.get_meta("pedipalps") as Array
		if palps.size() >= 2:
			var pl: MeshInstance3D = palps[0] as MeshInstance3D
			var pr: MeshInstance3D = palps[1] as MeshInstance3D
			var palp_speed: float = 2.0 if not is_moving else 3.5
			var palp_swing: float = sin(phase * palp_speed) * 0.15
			pl.rotation.x = -0.4 + palp_swing
			pr.rotation.x = -0.4 - palp_swing  # Alternate phase

	# ── Chelicerae animation — subtle open/close ──
	if root.has_meta("chelicerae"):
		var fangs: Array = root.get_meta("chelicerae") as Array
		if fangs.size() >= 2:
			var fl: MeshInstance3D = fangs[0] as MeshInstance3D
			var fr: MeshInstance3D = fangs[1] as MeshInstance3D
			var fang_pulse: float = sin(phase * 2.0) * 0.08
			fl.rotation.z = 0.15 + fang_pulse
			fr.rotation.z = -0.15 - fang_pulse

	# ── Abdomen sway — gentle side-to-side when moving ──
	if root.has_meta("abdomen"):
		var abd: MeshInstance3D = root.get_meta("abdomen") as MeshInstance3D
		if is_moving:
			abd.rotation.y = sin(phase * 4.0) * 0.04
		else:
			abd.rotation.y = sin(phase * 1.0) * 0.015

	# ── Whole-body idle bob ──
	if not is_moving:
		root.position.y = sin(phase * 1.2) * 0.005
	else:
		root.position.y = 0.0
