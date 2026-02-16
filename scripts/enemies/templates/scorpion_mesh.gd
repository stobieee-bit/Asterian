## ScorpionMesh — Scorpion with pincers and stinger tail
##
## Flattened prosoma with carapace plate, eye cluster, 2 pedipalp pincers,
## 7-segment mesosoma, 5-segment metasoma (tail) curving up, telson stinger
## with emissive glow, 8 walking legs (3-segment each).
## Tail sway, pincer open/close, walking leg cycle.
## ~93 mesh nodes.
class_name ScorpionMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x6B3A2A))
	var s: float = params.get("scale", 1.0)

	# ── Materials ──
	# Main exoskeleton
	var mat_exo: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.4, 0.45,
		Color.BLACK, 0.0
	)
	# Darker segment joints
	var mat_joint: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.35, 0.5,
		Color.BLACK, 0.0
	)
	# Carapace plate — slightly lighter, more metallic
	var mat_carapace: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.06), 0.55, 0.35,
		Color.BLACK, 0.0
	)
	# Eye material — small red emissive
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.1, 0.05), 0.5, 0.2,
		Color(0.9, 0.1, 0.05), 2.5
	)
	# Pincer claw material — hardened chitin
	var mat_claw: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.6, 0.3,
		Color.BLACK, 0.0
	)
	# Telson/stinger — purple emissive glow
	var stinger_color: Color = Color(0.55, 0.1, 0.65)
	var mat_stinger: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		stinger_color, 0.4, 0.25,
		stinger_color, 3.0
	)
	# Stinger barb — dark sharp tip
	var mat_barb: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(stinger_color, 0.2), 0.7, 0.2,
		stinger_color, 1.5
	)
	# Leg material
	var mat_leg: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.06), 0.3, 0.5,
		Color.BLACK, 0.0
	)
	# Pectine (sensory comb) material — slightly lighter
	var mat_pectine: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.3, 0.6,
		Color.BLACK, 0.0
	)
	# Venom drip material — bright green emissive, transparent
	var mat_venom: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.2, 0.9, 0.3), 0.2, 0.3,
		Color(0.2, 0.9, 0.3), 2.5, true, 0.5
	)

	# Body sits low to the ground
	var y_base: float = 0.25 * s

	# ── PROSOMA (cephalothorax — flattened squashed sphere) ──
	var prosoma: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.22 * s,
		Vector3(0.0, y_base + 0.08 * s, 0.35 * s),
		mat_exo,
		Vector3(1.3, 0.5, 1.1)
	)

	# Carapace plate on top of prosoma
	var _carapace: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.2 * s,
		Vector3(0.0, y_base + 0.14 * s, 0.35 * s),
		mat_carapace,
		Vector3(1.15, 0.25, 1.0)
	)

	# ── PECTINES (ventral sensory combs) ──
	var _pectine_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.01 * s, 0.08 * s,
		Vector3(-0.08 * s, y_base - 0.05 * s, 0.3 * s),
		mat_pectine,
		Vector3(0.0, 0.0, PI * 0.5)
	)
	var _pectine_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.01 * s, 0.08 * s,
		Vector3(0.08 * s, y_base - 0.05 * s, 0.3 * s),
		mat_pectine,
		Vector3(0.0, 0.0, PI * 0.5)
	)

	# ── CARAPACE SURFACE RIDGES ──
	var _ridge_l1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(-0.06 * s, y_base + 0.16 * s, 0.38 * s),
		mat_carapace,
		Vector3(0.0, 0.3, 0.2)
	)
	var _ridge_l2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(-0.1 * s, y_base + 0.16 * s, 0.34 * s),
		mat_carapace,
		Vector3(0.0, 0.5, 0.3)
	)
	var _ridge_l3: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(-0.13 * s, y_base + 0.16 * s, 0.30 * s),
		mat_carapace,
		Vector3(0.0, 0.7, 0.4)
	)
	var _ridge_r1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(0.06 * s, y_base + 0.16 * s, 0.38 * s),
		mat_carapace,
		Vector3(0.0, -0.3, -0.2)
	)
	var _ridge_r2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(0.1 * s, y_base + 0.16 * s, 0.34 * s),
		mat_carapace,
		Vector3(0.0, -0.5, -0.3)
	)
	var _ridge_r3: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.005 * s, 0.1 * s,
		Vector3(0.13 * s, y_base + 0.16 * s, 0.30 * s),
		mat_carapace,
		Vector3(0.0, -0.7, -0.4)
	)

	# ── EYE CLUSTER ──
	# 2 median eyes (center top)
	var eyes: Array = []
	var _median_eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.02 * s,
		Vector3(-0.025 * s, y_base + 0.17 * s, 0.4 * s),
		mat_eye
	)
	eyes.append(_median_eye_l)
	var _median_eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.02 * s,
		Vector3(0.025 * s, y_base + 0.17 * s, 0.4 * s),
		mat_eye
	)
	eyes.append(_median_eye_r)

	# 6 lateral eyes (3 per side, along front edge)
	for side: int in [-1, 1]:
		var sf: float = float(side)
		for j: int in range(3):
			var jf: float = float(j)
			var lat_eye: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.015 * s,
				Vector3(
					sf * (0.15 + jf * 0.04) * s,
					y_base + 0.15 * s,
					(0.42 - jf * 0.03) * s
				),
				mat_eye
			)
			eyes.append(lat_eye)

	# ── PEDIPALPS WITH PINCERS (2, articulated claws) ──
	var pincer_pivots: Array = []
	for side: int in [-1, 1]:
		var sf: float = float(side)

		# Pivot for entire pedipalp
		var ped_pivot: Node3D = Node3D.new()
		ped_pivot.position = Vector3(sf * 0.2 * s, y_base + 0.06 * s, 0.45 * s)
		root.add_child(ped_pivot)

		# Segment 1 — trochanter (base)
		var _troch: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			ped_pivot, 0.035 * s, 0.15 * s,
			Vector3(sf * 0.06 * s, 0.0, 0.05 * s),
			mat_exo,
			Vector3(0.0, sf * -0.3, sf * 0.4)
		)

		# Segment 2 — femur (middle, wider)
		var _ped_femur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			ped_pivot, 0.04 * s, 0.13 * s,
			Vector3(sf * 0.16 * s, 0.0, 0.15 * s),
			mat_exo,
			Vector3(0.0, sf * -0.2, sf * 0.2)
		)

		# Segment 3 — tibia / "palm" of claw (flat, wide)
		var _ped_palm: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			ped_pivot, 0.05 * s,
			Vector3(sf * 0.26 * s, 0.0, 0.25 * s),
			mat_claw,
			Vector3(0.7, 0.5, 1.0)
		)

		# Pincer — upper jaw (fixed finger)
		var _pincer_upper: MeshInstance3D = EnemyMeshBuilder.add_cone(
			ped_pivot, 0.02 * s, 0.12 * s,
			Vector3(sf * 0.28 * s, 0.02 * s, 0.35 * s),
			mat_claw,
			Vector3(-1.3, 0.0, 0.0)
		)

		# Pincer — lower jaw (movable finger, animated)
		var pincer_lower: MeshInstance3D = EnemyMeshBuilder.add_cone(
			ped_pivot, 0.018 * s, 0.11 * s,
			Vector3(sf * 0.28 * s, -0.02 * s, 0.35 * s),
			mat_claw,
			Vector3(-1.5, 0.0, 0.0)
		)

		# Pincer finger serrations — tiny cones on jaw edges
		var _serration_upper: MeshInstance3D = EnemyMeshBuilder.add_cone(
			ped_pivot, 0.008 * s, 0.04 * s,
			Vector3(sf * 0.28 * s, 0.035 * s, 0.32 * s),
			mat_claw,
			Vector3(-1.1, 0.0, 0.0)
		)
		var _serration_lower: MeshInstance3D = EnemyMeshBuilder.add_cone(
			ped_pivot, 0.008 * s, 0.04 * s,
			Vector3(sf * 0.28 * s, -0.035 * s, 0.32 * s),
			mat_claw,
			Vector3(-1.7, 0.0, 0.0)
		)

		# Store lower jaw reference for open/close animation
		ped_pivot.set_meta("lower_jaw", pincer_lower)
		pincer_pivots.append(ped_pivot)

	# ── MESOSOMA (7 body segments, tapered) ──
	var meso_segs: Array = []
	for i: int in range(7):
		var seg_t: float = float(i) / 6.0
		# Taper from front to back
		var seg_rx: float = (0.2 - seg_t * 0.06) * s
		var seg_ry: float = (0.1 - seg_t * 0.02) * s
		var seg_z: float = (0.2 - float(i) * 0.12) * s
		var seg_y: float = y_base + (0.06 - seg_t * 0.02) * s
		var seg: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, seg_rx,
			Vector3(0.0, seg_y, seg_z),
			mat_exo if i % 2 == 0 else mat_joint,
			Vector3(1.0, seg_ry / seg_rx, 0.7)
		)
		meso_segs.append(seg)

	# ── MESOSOMA INTER-SEGMENT GROOVES ──
	for i: int in range(6):
		var groove_t: float = float(i) / 5.0
		var groove_z: float = (0.14 - float(i) * 0.12) * s
		var groove_y: float = y_base + (0.06 - groove_t * 0.02) * s
		var _groove: MeshInstance3D = EnemyMeshBuilder.add_torus(
			root, 0.005 * s, 0.15 * s,
			Vector3(0.0, groove_y, groove_z),
			mat_joint,
			Vector3(PI * 0.5, 0.0, 0.0)
		)

	# ── METASOMA (5-segment tail curving upward) ──
	var tail_segs: Array = []
	# Tail curves upward and backward in an arc
	for i: int in range(5):
		var seg_t: float = float(i) / 4.0
		# Arc trajectory: z goes backward, y goes up
		var tail_angle: float = seg_t * PI * 0.55
		var arc_r: float = 0.55 * s
		var tail_z: float = (-0.65 - cos(tail_angle) * arc_r * 0.5) * s
		var tail_y: float = y_base + (0.05 + sin(tail_angle) * arc_r * 0.7) * s
		# Segments get thinner toward tip
		var tail_r: float = (0.07 - seg_t * 0.025) * s
		# Each segment rotates to follow the curve
		var seg_rot_x: float = -tail_angle * 0.6
		var seg: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, tail_r, 0.08 * s,
			Vector3(0.0, tail_y, tail_z),
			mat_exo if i % 2 == 0 else mat_joint,
			Vector3(seg_rot_x, 0.0, 0.0)
		)
		tail_segs.append(seg)

	# ── TELSON (stinger bulb at tail tip) ──
	# Position at end of tail arc
	var telson_angle: float = PI * 0.55
	var telson_z: float = (-0.65 - cos(telson_angle) * 0.55 * 0.5) * s - 0.06 * s
	var telson_y: float = y_base + (0.05 + sin(telson_angle) * 0.55 * 0.7) * s + 0.05 * s
	var telson: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.06 * s,
		Vector3(0.0, telson_y, telson_z),
		mat_stinger,
		Vector3(0.8, 1.0, 1.2)
	)

	# Stinger barb — sharp cone pointing down/forward from telson
	var barb: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.02 * s, 0.1 * s,
		Vector3(0.0, telson_y - 0.06 * s, telson_z + 0.04 * s),
		mat_barb,
		Vector3(0.5, 0.0, 0.0)
	)

	# ── STINGER BARB SPURS (flanking the main barb) ──
	var _barb_spur_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.012 * s, 0.06 * s,
		Vector3(-0.02 * s, telson_y - 0.06 * s, telson_z + 0.04 * s),
		mat_barb,
		Vector3(0.4, 0.0, 0.2)
	)
	var _barb_spur_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.012 * s, 0.06 * s,
		Vector3(0.02 * s, telson_y - 0.06 * s, telson_z + 0.04 * s),
		mat_barb,
		Vector3(0.4, 0.0, -0.2)
	)

	# ── VENOM DRIP (emissive droplets below barb tip) ──
	var venom_drips: Array = []
	var barb_tip_y: float = telson_y - 0.06 * s - 0.08 * s
	var barb_tip_z: float = telson_z + 0.04 * s
	var venom_drop_1: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.015 * s,
		Vector3(0.0, barb_tip_y, barb_tip_z),
		mat_venom
	)
	venom_drips.append(venom_drop_1)
	var venom_drop_2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.01 * s,
		Vector3(0.0, barb_tip_y - 0.02 * s, barb_tip_z),
		mat_venom
	)
	venom_drips.append(venom_drop_2)

	# ── WALKING LEGS (8 legs, 4 per side, 3 segments each) ──
	var walk_legs: Array = []
	for pair: int in range(4):
		for side: int in [-1, 1]:
			var sf: float = float(side)
			# Attachment point along mesosoma
			var attach_z: float = (0.15 - float(pair) * 0.12) * s
			var attach_x: float = sf * 0.18 * s

			var leg_pivot: Node3D = Node3D.new()
			leg_pivot.position = Vector3(attach_x, y_base + 0.02 * s, attach_z)
			root.add_child(leg_pivot)

			# Coxa (base segment) — angled outward
			var _coxa: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.02 * s, 0.1 * s,
				Vector3(sf * 0.05 * s, 0.0, 0.0),
				mat_leg,
				Vector3(0.0, 0.0, sf * 0.8)
			)

			# Coxa-femur joint spheres
			var _joint_upper: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				leg_pivot, 0.015 * s,
				Vector3(sf * 0.1 * s, -0.03 * s, 0.0),
				mat_joint
			)
			var _joint_lower: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				leg_pivot, 0.015 * s,
				Vector3(sf * 0.1 * s, -0.03 * s, 0.015 * s),
				mat_joint
			)

			# Femur (middle segment) — angled down
			var _femur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.016 * s, 0.1 * s,
				Vector3(sf * 0.14 * s, -0.06 * s, 0.0),
				mat_leg,
				Vector3(0.3, 0.0, sf * 0.4)
			)

			# Tarsus (foot) — touches ground
			var _tarsus: MeshInstance3D = EnemyMeshBuilder.add_capsule(
				leg_pivot, 0.012 * s, 0.07 * s,
				Vector3(sf * 0.2 * s, -0.16 * s, 0.0),
				mat_leg,
				Vector3(0.6, 0.0, sf * 0.1)
			)

			walk_legs.append(leg_pivot)

	# ── Store animatable references ──
	root.set_meta("prosoma", [prosoma])
	root.set_meta("eyes", eyes)
	root.set_meta("pincer_pivots", pincer_pivots)
	root.set_meta("meso_segs", meso_segs)
	root.set_meta("tail_segs", tail_segs)
	root.set_meta("telson", [telson])
	root.set_meta("barb", [barb])
	root.set_meta("walk_legs", walk_legs)
	root.set_meta("venom_drips", venom_drips)
	root.set_meta("scale", s)
	root.set_meta("y_base", y_base)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = root.get_meta("scale", 1.0)
	var y_base: float = root.get_meta("y_base", 0.25)

	# ── Tail sway (lateral wave through metasoma segments) ──
	var tail_segs: Array = root.get_meta("tail_segs", [])
	var sway_speed: float = 2.5 if is_moving else 1.5
	var sway_amount: float = 0.12 if is_moving else 0.06
	for i: int in range(tail_segs.size()):
		var seg: MeshInstance3D = tail_segs[i] as MeshInstance3D
		var delay: float = float(i) * 0.5
		var lateral_sway: float = sin(phase * sway_speed + delay) * sway_amount * (float(i + 1) / 5.0)
		seg.position.x += (lateral_sway * s - seg.position.x) * delta * 5.0
		# Slight rotation to follow the sway
		var rot_sway: float = sin(phase * sway_speed + delay) * 0.08 * (float(i + 1) / 5.0)
		seg.rotation.z += (rot_sway - seg.rotation.z) * delta * 5.0

	# Telson and barb follow tail tip sway
	var telson_arr: Array = root.get_meta("telson", [])
	var barb_arr: Array = root.get_meta("barb", [])
	var tip_sway: float = sin(phase * sway_speed + 2.5) * sway_amount * s
	if telson_arr.size() > 0:
		var telson_node: MeshInstance3D = telson_arr[0] as MeshInstance3D
		telson_node.position.x += (tip_sway - telson_node.position.x) * delta * 5.0
		# Slight up/down bob on telson
		var telson_bob: float = sin(phase * 3.0) * 0.02 * s
		var telson_angle: float = PI * 0.55
		var base_telson_y: float = y_base + (0.05 + sin(telson_angle) * 0.55 * 0.7) * s + 0.05 * s
		telson_node.position.y += (base_telson_y + telson_bob - telson_node.position.y) * delta * 4.0
	if barb_arr.size() > 0:
		var barb_node: MeshInstance3D = barb_arr[0] as MeshInstance3D
		barb_node.position.x += (tip_sway - barb_node.position.x) * delta * 5.0

	# ── Pincer open/close ──
	var pincer_pivots: Array = root.get_meta("pincer_pivots", [])
	for i: int in range(pincer_pivots.size()):
		var pivot: Node3D = pincer_pivots[i] as Node3D
		# Sway pincers forward/back slightly
		var pincer_sway: float = sin(phase * 1.8 + float(i) * PI) * 0.08
		pivot.rotation.x += (pincer_sway - pivot.rotation.x) * delta * 4.0

		# Animate lower jaw open/close
		if pivot.has_meta("lower_jaw"):
			var jaw: MeshInstance3D = pivot.get_meta("lower_jaw") as MeshInstance3D
			# Periodic open/close: mostly closed, occasionally opening
			var open_cycle: float = sin(phase * 2.0 + float(i) * 1.5)
			var open_amount: float = 0.0
			if open_cycle > 0.5:
				# Opening phase
				open_amount = (open_cycle - 0.5) * 2.0 * 0.3
			jaw.rotation.x = -1.5 + open_amount

	# ── Walking legs cycle ──
	var walk_legs: Array = root.get_meta("walk_legs", [])
	for i: int in range(walk_legs.size()):
		var leg: Node3D = walk_legs[i] as Node3D
		if is_moving:
			# Alternating gait pattern — opposite corners move together
			# Legs 0,3,4,7 vs 1,2,5,6 for scorpion alternating tetrapod gait
			var gait_offset: float = 0.0
			if i % 4 == 0 or i % 4 == 3:
				gait_offset = 0.0
			else:
				gait_offset = PI
			var leg_phase: float = phase * 7.0 + gait_offset
			var swing: float = sin(leg_phase) * 0.2
			var lift: float = maxf(0.0, sin(leg_phase)) * 0.02 * s
			leg.rotation.x += (swing - leg.rotation.x) * delta * 8.0
			leg.position.y = y_base + 0.02 * s + lift
		else:
			# Idle: subtle leg adjustments
			var idle_shift: float = sin(phase * 0.8 + float(i) * 0.9) * 0.03
			leg.rotation.x += (idle_shift - leg.rotation.x) * delta * 3.0

	# ── Mesosoma body segments subtle wave ──
	var meso_segs: Array = root.get_meta("meso_segs", [])
	for i: int in range(meso_segs.size()):
		var seg: MeshInstance3D = meso_segs[i] as MeshInstance3D
		var wave_delay: float = float(i) * 0.3
		var wave: float = sin(phase * 2.0 + wave_delay) * 0.005 * s
		seg.position.x += (wave - seg.position.x) * delta * 6.0

	# ── Prosoma slight tilt when moving ──
	var prosoma_arr: Array = root.get_meta("prosoma", [])
	if prosoma_arr.size() > 0:
		var prosoma_node: MeshInstance3D = prosoma_arr[0] as MeshInstance3D
		if is_moving:
			var tilt: float = sin(phase * 7.0) * 0.02
			prosoma_node.rotation.z += (tilt - prosoma_node.rotation.z) * delta * 5.0
		else:
			prosoma_node.rotation.z += (0.0 - prosoma_node.rotation.z) * delta * 3.0

	# ── Venom drip sway ──
	var venom_drips: Array = root.get_meta("venom_drips", [])
	for i: int in range(venom_drips.size()):
		var drip: MeshInstance3D = venom_drips[i] as MeshInstance3D
		var drip_sway: float = sin(phase * 1.5 + float(i)) * 0.15
		drip.rotation.z += (drip_sway - drip.rotation.z) * delta * 4.0
		var drip_bob: float = sin(phase * 1.5 + float(i) + 0.5) * 0.005 * s
		drip.position.y += drip_bob * delta * 4.0
