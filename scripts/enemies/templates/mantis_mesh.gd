## MantisMesh — Praying mantis predator enemy
##
## Triangular head with bulging compound eyes, long prothorax neck,
## wide mesothorax, 4-segment abdomen, 2 raptorial forelegs (signature),
## 4 walking legs, vestigial wing stubs, 2 antennae.
## Raptorial arms sway/strike, walking legs cycle.
## ~45-55 mesh nodes.
class_name MantisMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x44882A))
	var s: float = params.get("scale", 1.0)

	# ── Materials ──
	# Chitin exoskeleton — main body
	var mat_chitin: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.35, 0.45,
		Color.BLACK, 0.0
	)
	# Darker chitin for joints/segments
	var mat_chitin_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.3, 0.5,
		Color.BLACK, 0.0
	)
	# Compound eye material — red emissive
	var eye_color: Color = Color(0.9, 0.1, 0.05)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		eye_color, 0.6, 0.2,
		eye_color, 2.0
	)
	# Raptorial foreleg blade — lighter, slightly metallic
	var mat_blade: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.5, 0.35,
		Color.BLACK, 0.0
	)
	# Serration edge — dark accent
	var mat_serr: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.2), 0.6, 0.3,
		Color.BLACK, 0.0
	)
	# Wing stub — translucent
	var mat_wing: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.2), 0.1, 0.3,
		Color.BLACK, 0.0,
		true, 0.4
	)
	# Antenna material
	var mat_antenna: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.2, 0.6,
		Color.BLACK, 0.0
	)

	# ── HEAD ──
	# Triangular head (flattened sphere, wider than tall)
	var head: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.16 * s,
		Vector3(0.0, 0.75 * s, 0.65 * s),
		mat_chitin,
		Vector3(1.0, 0.75, 0.85)
	)

	# Compound eyes — large, bulging (2 spheres on sides)
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.09 * s,
		Vector3(-0.12 * s, 0.78 * s, 0.7 * s),
		mat_eye,
		Vector3(0.8, 1.0, 1.0)
	)
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.09 * s,
		Vector3(0.12 * s, 0.78 * s, 0.7 * s),
		mat_eye,
		Vector3(0.8, 1.0, 1.0)
	)

	# Mandibles — two small cones at front of head
	var _mandible_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.08 * s,
		Vector3(-0.05 * s, 0.7 * s, 0.78 * s),
		mat_chitin_dark,
		Vector3(0.6, 0.0, 0.2)
	)
	var _mandible_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.025 * s, 0.08 * s,
		Vector3(0.05 * s, 0.7 * s, 0.78 * s),
		mat_chitin_dark,
		Vector3(0.6, 0.0, -0.2)
	)

	# ── ANTENNAE (2) ──
	var antennae: Array = []
	for side: int in [-1, 1]:
		var sf: float = float(side)
		var ant: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.01 * s, 0.35 * s,
			Vector3(sf * 0.06 * s, 0.88 * s, 0.75 * s),
			mat_antenna,
			Vector3(-0.8, 0.0, sf * 0.3)
		)
		antennae.append(ant)

	# ── PROTHORAX (elongated neck segment) ──
	var prothorax: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.07 * s, 0.35 * s,
		Vector3(0.0, 0.7 * s, 0.35 * s),
		mat_chitin,
		Vector3(0.4, 0.0, 0.0)
	)

	# ── MESOTHORAX (wider mid-body) ──
	var mesothorax: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s,
		Vector3(0.0, 0.5 * s, 0.0),
		mat_chitin,
		Vector3(1.1, 0.7, 1.3)
	)

	# ── ABDOMEN (4 tapered segments) ──
	var abdomen_segs: Array = []
	for i: int in range(4):
		var seg_t: float = float(i) / 3.0
		var seg_r: float = (0.16 - 0.03 * seg_t) * s
		var seg_z: float = (-0.2 - float(i) * 0.18) * s
		var seg_y: float = (0.45 - float(i) * 0.04) * s
		var seg: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, seg_r,
			Vector3(0.0, seg_y, seg_z),
			mat_chitin if i % 2 == 0 else mat_chitin_dark,
			Vector3(1.0, 0.75, 1.15)
		)
		abdomen_segs.append(seg)

	# ── VESTIGIAL WING STUBS (2) ──
	for side: int in [-1, 1]:
		var sf: float = float(side)
		var _wing: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.03 * s, 0.18 * s,
			Vector3(sf * 0.18 * s, 0.58 * s, -0.08 * s),
			mat_wing,
			Vector3(-0.3, sf * 0.2, sf * 0.8)
		)

	# ── RAPTORIAL FORELEGS (2, 3-segment each with serrated edges) ──
	var rapt_arms: Array = []
	for side: int in [-1, 1]:
		var sf: float = float(side)
		# Pivot node for the entire arm
		var arm_pivot: Node3D = Node3D.new()
		arm_pivot.position = Vector3(sf * 0.15 * s, 0.6 * s, 0.2 * s)
		root.add_child(arm_pivot)

		# Coxa (upper arm) — angled forward and up
		var coxa: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			arm_pivot, 0.04 * s, 0.2 * s,
			Vector3(sf * 0.05 * s, 0.05 * s, 0.1 * s),
			mat_blade,
			Vector3(-0.6, 0.0, sf * 0.15)
		)

		# Femur (mid arm) — thicker, blade-like
		var femur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			arm_pivot, 0.035 * s, 0.22 * s,
			Vector3(sf * 0.08 * s, -0.1 * s, 0.25 * s),
			mat_blade,
			Vector3(-0.3, 0.0, sf * 0.1)
		)

		# Tibia (lower arm) — the striking blade
		var tibia: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			arm_pivot, 0.025 * s, 0.2 * s,
			Vector3(sf * 0.06 * s, -0.25 * s, 0.35 * s),
			mat_blade,
			Vector3(0.4, 0.0, sf * 0.05)
		)

		# Serrated edges along femur (3 small spines)
		for j: int in range(3):
			var spine_t: float = float(j) / 2.0
			var _spine: MeshInstance3D = EnemyMeshBuilder.add_cone(
				arm_pivot, 0.012 * s, 0.05 * s,
				Vector3(
					sf * (0.12 + spine_t * 0.02) * s,
					(-0.05 - spine_t * 0.08) * s,
					(0.22 + spine_t * 0.06) * s
				),
				mat_serr,
				Vector3(0.0, 0.0, sf * 1.2)
			)

		rapt_arms.append(arm_pivot)

	# ── WALKING LEGS (4, two pairs from mesothorax) ──
	var walk_legs: Array = []
	for pair: int in range(2):
		for side: int in [-1, 1]:
			var sf: float = float(side)
			var pair_offset_z: float = (0.05 - float(pair) * 0.2) * s
			var leg_pivot: Node3D = Node3D.new()
			leg_pivot.position = Vector3(sf * 0.16 * s, 0.4 * s, pair_offset_z)
			root.add_child(leg_pivot)

			# Femur
			var _wl_femur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.02 * s, 0.18 * s,
				Vector3(sf * 0.08 * s, -0.05 * s, 0.0),
				mat_chitin_dark,
				Vector3(0.0, 0.0, sf * 0.7)
			)

			# Tibia
			var _wl_tibia: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.015 * s, 0.15 * s,
				Vector3(sf * 0.2 * s, -0.15 * s, 0.0),
				mat_chitin_dark,
				Vector3(0.2, 0.0, sf * 0.3)
			)

			# Tarsus (foot)
			var _wl_tarsus: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.012 * s, 0.08 * s,
				Vector3(sf * 0.25 * s, -0.28 * s, 0.02 * s),
				mat_chitin_dark,
				Vector3(0.5, 0.0, 0.0)
			)

			walk_legs.append(leg_pivot)

	# ── Store animatable references ──
	root.set_meta("head", [head])
	root.set_meta("antennae", antennae)
	root.set_meta("prothorax", [prothorax])
	root.set_meta("mesothorax", [mesothorax])
	root.set_meta("abdomen", abdomen_segs)
	root.set_meta("rapt_arms", rapt_arms)
	root.set_meta("walk_legs", walk_legs)
	root.set_meta("eyes", [eye_l, eye_r])
	root.set_meta("scale", s)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = root.get_meta("scale", 1.0)

	# ── Head bob ──
	var head_arr: Array = root.get_meta("head", [])
	if head_arr.size() > 0:
		var head_node: MeshInstance3D = head_arr[0] as MeshInstance3D
		var head_bob: float = sin(phase * 2.0) * 0.01 * s
		head_node.position.y = 0.75 * s + head_bob

	# ── Antennae twitch ──
	var antennae: Array = root.get_meta("antennae", [])
	for i: int in range(antennae.size()):
		var ant: MeshInstance3D = antennae[i] as MeshInstance3D
		var twitch: float = sin(phase * 5.0 + float(i) * 2.0) * 0.15
		ant.rotation.z += (twitch - ant.rotation.z) * delta * 6.0

	# ── Raptorial arm sway / strike ──
	var rapt_arms: Array = root.get_meta("rapt_arms", [])
	for i: int in range(rapt_arms.size()):
		var arm: Node3D = rapt_arms[i] as Node3D
		var side_f: float = 1.0 if i == 0 else -1.0
		if is_moving:
			# Forward/back pumping motion while walking
			var pump: float = sin(phase * 4.0 + float(i) * PI) * 0.2
			arm.rotation.x += (pump - arm.rotation.x) * delta * 5.0
		else:
			# Idle: gentle sway with occasional twitch
			var sway: float = sin(phase * 1.5 + float(i) * 1.8) * 0.1
			var twitch: float = sin(phase * 6.0 + float(i) * 3.0) * 0.03
			arm.rotation.x += (sway + twitch - arm.rotation.x) * delta * 4.0
			arm.rotation.z += (side_f * sin(phase * 1.2) * 0.05 - arm.rotation.z) * delta * 3.0

	# ── Walking legs cycle ──
	var walk_legs: Array = root.get_meta("walk_legs", [])
	for i: int in range(walk_legs.size()):
		var leg: Node3D = walk_legs[i] as Node3D
		if is_moving:
			# Alternating gait — opposite legs move together
			var leg_phase: float = phase * 6.0 + float(i) * PI * 0.5
			var swing: float = sin(leg_phase) * 0.25
			var lift: float = maxf(0.0, sin(leg_phase)) * 0.03 * s
			leg.rotation.x += (swing - leg.rotation.x) * delta * 8.0
			leg.position.y = 0.4 * s + lift
		else:
			# Idle: subtle settle
			var settle: float = sin(phase * 1.0 + float(i) * 0.7) * 0.03
			leg.rotation.x += (settle - leg.rotation.x) * delta * 3.0

	# ── Abdomen gentle sway ──
	var abdomen: Array = root.get_meta("abdomen", [])
	for i: int in range(abdomen.size()):
		var seg: MeshInstance3D = abdomen[i] as MeshInstance3D
		var sway_delay: float = float(i) * 0.4
		var sway: float = sin(phase * 1.5 + sway_delay) * 0.02 * s
		seg.position.x = sway

	# ── Body bob while moving ──
	if is_moving:
		var body_bob: float = sin(phase * 6.0) * 0.015 * s
		var meso_arr: Array = root.get_meta("mesothorax", [])
		if meso_arr.size() > 0:
			var meso: MeshInstance3D = meso_arr[0] as MeshInstance3D
			meso.position.y = 0.5 * s + body_bob
		var pro_arr: Array = root.get_meta("prothorax", [])
		if pro_arr.size() > 0:
			var pro: MeshInstance3D = pro_arr[0] as MeshInstance3D
			pro.position.y = 0.7 * s + body_bob * 0.7
