## InsectoidMesh — Procedural mesh builder for insectoid-type enemies
##
## The most common enemy template, used for beetles, drones, ants, grubs, etc.
## Builds a complete insect body from simple primitives: head with compound eyes,
## mandibles, antennae, 3-segment thorax, 5-segment abdomen, and 6-8 articulated legs.
##
## Variants:
##   "drone"    — default, with elytra wing covers
##   "queen"    — crown, egg sacs, larger abdomen, 8 legs
##   "sentinel" — armored plates, horn, enlarged mandibles, 8 legs
##   "crawler"  — flattened body, digging claws
class_name InsectoidMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	# ── Extract parameters ──
	var base_color: Color = EnemyMeshBuilder.int_to_color(int(params.get("color", 0x3a5a2a)))
	var s: float = float(params.get("scale", 1.0))
	var variant: String = str(params.get("variant", "drone"))

	# ── Create root ──
	var root: Node3D = Node3D.new()
	root.name = "InsectoidRoot"

	# ── Materials ──
	var mat_chitin: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.5, 0.4
	)
	var mat_chitin_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.5, 0.45
	)
	var mat_chitin_light: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.06), 0.45, 0.5
	)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.8, 0.15, 0.05), 0.6, 0.3,
		Color(1.0, 0.3, 0.05), 2.5  # Red/orange emissive glow
	)
	var mat_mandible: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.55, 0.35
	)
	var mat_leg: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.4, 0.5
	)
	var mat_antenna: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.03), 0.3, 0.55
	)
	var mat_wing: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.12), 0.3, 0.3,
		Color.BLACK, 0.0,
		true, 0.45  # Semi-transparent wing covers
	)

	# ── Body layout offsets (scaled) ──
	# The insect faces -Z by default. Origin at ground level.
	var body_y: float = 0.6 * s  # Center-of-mass height

	# ── HEAD ──
	var head_z: float = -0.65 * s
	var head: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s, Vector3(0, body_y + 0.05 * s, head_z), mat_chitin_light,
		Vector3(1.0, 0.85, 1.1)
	)
	head.name = "Head"

	# Compound eyes (left and right)
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.07 * s, Vector3(-0.12 * s, body_y + 0.1 * s, head_z - 0.08 * s), mat_eye,
		Vector3(0.9, 1.0, 0.8)
	)
	eye_l.name = "EyeL"
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.07 * s, Vector3(0.12 * s, body_y + 0.1 * s, head_z - 0.08 * s), mat_eye,
		Vector3(0.9, 1.0, 0.8)
	)
	eye_r.name = "EyeR"

	# Mandibles (two small cones angled outward)
	var mandible_size: float = 0.12 * s
	if variant == "sentinel":
		mandible_size = 0.2 * s  # Enlarged mandibles
	var mandible_l: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.035 * s, mandible_size,
		Vector3(-0.08 * s, body_y - 0.04 * s, head_z - 0.16 * s), mat_mandible,
		Vector3(0.5, 0.0, 0.3)
	)
	mandible_l.name = "MandibleL"
	var mandible_r: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.035 * s, mandible_size,
		Vector3(0.08 * s, body_y - 0.04 * s, head_z - 0.16 * s), mat_mandible,
		Vector3(0.5, 0.0, -0.3)
	)
	mandible_r.name = "MandibleR"

	# Antennae (two thin capsules sweeping forward and outward)
	var antenna_pivot_l: Node3D = Node3D.new()
	antenna_pivot_l.name = "AntennaPivotL"
	antenna_pivot_l.position = Vector3(-0.06 * s, body_y + 0.17 * s, head_z - 0.05 * s)
	root.add_child(antenna_pivot_l)
	var antenna_seg_l: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		antenna_pivot_l, 0.012 * s, 0.25 * s,
		Vector3(-0.05 * s, 0.08 * s, -0.1 * s), mat_antenna,
		Vector3(-0.6, 0.0, -0.2)
	)
	antenna_seg_l.name = "AntennaL"

	var antenna_pivot_r: Node3D = Node3D.new()
	antenna_pivot_r.name = "AntennaPivotR"
	antenna_pivot_r.position = Vector3(0.06 * s, body_y + 0.17 * s, head_z - 0.05 * s)
	root.add_child(antenna_pivot_r)
	var antenna_seg_r: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		antenna_pivot_r, 0.012 * s, 0.25 * s,
		Vector3(0.05 * s, 0.08 * s, -0.1 * s), mat_antenna,
		Vector3(-0.6, 0.0, 0.2)
	)
	antenna_seg_r.name = "AntennaR"

	# ── THORAX (3 segments: prothorax, mesothorax, metathorax) ──
	var thorax_start_z: float = -0.35 * s
	var thorax_radii: Array = [0.16, 0.2, 0.19]
	var thorax_spacing: float = 0.22 * s
	for i: int in range(3):
		var tz: float = thorax_start_z + float(i) * thorax_spacing
		var tr: float = thorax_radii[i] * s
		# Flatten for crawler variant
		var thorax_scale: Vector3 = Vector3(1.1, 0.8, 1.0)
		if variant == "crawler":
			thorax_scale = Vector3(1.3, 0.5, 1.0)
		var seg: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, tr, Vector3(0, body_y, tz), mat_chitin_dark, thorax_scale
		)
		seg.name = "Thorax%d" % i
		# Chitin plate on top of each segment
		var plate: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, tr * 0.7,
			Vector3(0, body_y + tr * 0.5, tz), mat_chitin,
			Vector3(1.2, 0.3, 1.0)
		)
		plate.name = "ChitinPlate%d" % i

	# ── ABDOMEN (5 segments, tapering) ──
	var abd_start_z: float = thorax_start_z + 3.0 * thorax_spacing + 0.05 * s
	var abd_spacing: float = 0.18 * s
	var abd_base_radius: float = 0.22 * s
	if variant == "queen":
		abd_base_radius = 0.32 * s  # Engorged abdomen
		abd_spacing = 0.22 * s
	for i: int in range(5):
		var taper: float = 1.0 - float(i) * 0.16  # Taper toward rear
		var ar: float = abd_base_radius * taper
		var az: float = abd_start_z + float(i) * abd_spacing
		var abd_scale: Vector3 = Vector3(1.0, 0.85, 1.0)
		if variant == "queen":
			abd_scale = Vector3(1.1, 1.0, 1.0)
		elif variant == "crawler":
			abd_scale = Vector3(1.2, 0.5, 1.0)
		var seg: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, ar, Vector3(0, body_y - 0.02 * s * float(i), az),
			mat_chitin if i % 2 == 0 else mat_chitin_dark,
			abd_scale
		)
		seg.name = "Abdomen%d" % i

	# ── LEGS ──
	var leg_count: int = 6
	if variant == "queen" or variant == "sentinel":
		leg_count = 8

	var legs_array: Array = []
	# Legs attach to the thorax region. Distribute attachment points evenly.
	var leg_attach_z_start: float = thorax_start_z - 0.05 * s
	var leg_attach_z_end: float = thorax_start_z + 2.5 * thorax_spacing
	var leg_pairs: int = leg_count / 2

	for i: int in range(leg_count):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var pair_idx: int = i / 2
		var t: float = float(pair_idx) / float(maxi(1, leg_pairs - 1))
		var attach_z: float = lerpf(leg_attach_z_start, leg_attach_z_end, t)
		var attach_x: float = side * 0.18 * s

		# Leg pivot (allows animation)
		var leg_pivot: Node3D = Node3D.new()
		leg_pivot.name = "LegPivot%d" % i
		leg_pivot.position = Vector3(attach_x, body_y - 0.08 * s, attach_z)
		root.add_child(leg_pivot)

		# Coxa (short segment connecting to body)
		var coxa_angle: float = side * 0.8
		var coxa: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			leg_pivot, 0.025 * s, 0.08 * s,
			Vector3(side * 0.05 * s, -0.02 * s, 0.0), mat_leg,
			Vector3(0.0, 0.0, coxa_angle)
		)
		coxa.name = "Coxa"

		# Femur (upper leg, angled outward and down)
		var femur: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			leg_pivot, 0.02 * s, 0.18 * s,
			Vector3(side * 0.15 * s, -0.1 * s, 0.0), mat_leg,
			Vector3(0.0, 0.0, side * 0.5)
		)
		femur.name = "Femur"

		# Tibia (lower leg, angled down steeply)
		var tibia: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			leg_pivot, 0.015 * s, 0.2 * s,
			Vector3(side * 0.26 * s, -0.32 * s, 0.0), mat_leg,
			Vector3(0.0, 0.0, side * 0.15)
		)
		tibia.name = "Tibia"

		# Tarsus (foot, tiny tip — cone for crawlers, sphere otherwise)
		if variant == "crawler":
			# Digging claws
			var claw: MeshInstance3D = EnemyMeshBuilder.add_cone(
				leg_pivot, 0.025 * s, 0.08 * s,
				Vector3(side * 0.3 * s, -0.48 * s, 0.0), mat_mandible,
				Vector3(PI, 0.0, 0.0)
			)
			claw.name = "Claw"
		else:
			var tarsus: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				leg_pivot, 0.018 * s,
				Vector3(side * 0.3 * s, -0.48 * s, 0.0), mat_leg
			)
			tarsus.name = "Tarsus"

		legs_array.append(leg_pivot)

	# ── VARIANT-SPECIFIC FEATURES ──

	if variant == "drone":
		# Elytra wing covers on the mesothorax (second thorax segment)
		var elytra_z: float = thorax_start_z + thorax_spacing
		var elytra_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.12 * s,
			Vector3(-0.1 * s, body_y + 0.15 * s, elytra_z + 0.15 * s), mat_wing,
			Vector3(0.6, 0.15, 1.8)
		)
		elytra_l.name = "ElytraL"
		var elytra_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.12 * s,
			Vector3(0.1 * s, body_y + 0.15 * s, elytra_z + 0.15 * s), mat_wing,
			Vector3(0.6, 0.15, 1.8)
		)
		elytra_r.name = "ElytraR"

	elif variant == "queen":
		# Crown (torus on top of head)
		var mat_crown: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
			Color(0.85, 0.7, 0.15), 0.8, 0.2,
			Color(0.9, 0.75, 0.2), 1.5
		)
		var crown: MeshInstance3D = EnemyMeshBuilder.add_torus(
			root, 0.06 * s, 0.12 * s,
			Vector3(0, body_y + 0.25 * s, head_z), mat_crown,
			Vector3(0.2, 0.0, 0.0)
		)
		crown.name = "Crown"
		# Crown spikes
		for ci: int in range(5):
			var ca: float = float(ci) / 5.0 * TAU
			var spike: MeshInstance3D = EnemyMeshBuilder.add_cone(
				root, 0.018 * s, 0.07 * s,
				Vector3(
					cos(ca) * 0.1 * s,
					body_y + 0.32 * s,
					head_z + sin(ca) * 0.1 * s
				), mat_crown,
				Vector3(0.0, 0.0, 0.0)
			)
			spike.name = "CrownSpike%d" % ci

		# Egg sacs on last two abdomen segments
		var mat_egg: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
			EnemyMeshBuilder.lighten(base_color, 0.15), 0.2, 0.7,
			Color.BLACK, 0.0, true, 0.7
		)
		for ei: int in range(2):
			var egg_z: float = abd_start_z + float(3 + ei) * abd_spacing
			var egg_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.1 * s,
				Vector3(-0.18 * s, body_y - 0.08 * s, egg_z), mat_egg
			)
			egg_l.name = "EggSacL%d" % ei
			var egg_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, 0.1 * s,
				Vector3(0.18 * s, body_y - 0.08 * s, egg_z), mat_egg
			)
			egg_r.name = "EggSacR%d" % ei

	elif variant == "sentinel":
		# Armored plates on thorax (thicker dorsal armor)
		var mat_armor: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
			EnemyMeshBuilder.darken(base_color, 0.12), 0.7, 0.3
		)
		for ai: int in range(3):
			var az: float = thorax_start_z + float(ai) * thorax_spacing
			var armor_plate: MeshInstance3D = EnemyMeshBuilder.add_sphere(
				root, thorax_radii[ai] * s * 0.85,
				Vector3(0, body_y + thorax_radii[ai] * s * 0.55, az), mat_armor,
				Vector3(1.4, 0.25, 1.15)
			)
			armor_plate.name = "ArmorPlate%d" % ai

		# Horn on head (large forward-pointing cone)
		var horn: MeshInstance3D = EnemyMeshBuilder.add_cone(
			root, 0.04 * s, 0.25 * s,
			Vector3(0, body_y + 0.18 * s, head_z - 0.2 * s), mat_mandible,
			Vector3(-0.7, 0.0, 0.0)
		)
		horn.name = "Horn"

	# Crawler variant needs no extra decorations — its flattened body and claws define it.

	# ── Store animation references as metadata on root ──
	root.set_meta("legs", legs_array)
	root.set_meta("antenna_l", antenna_pivot_l)
	root.set_meta("antenna_r", antenna_pivot_r)
	root.set_meta("variant", variant)
	root.set_meta("scale", s)

	return root


## Animate the insectoid each frame.
## Walking: legs cycle up/down in alternating tripod gait.
## Idle: antennae sway gently, body bobs subtly.
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var legs: Array = root.get_meta("legs", [])
	var antenna_l: Node3D = root.get_meta("antenna_l", null)
	var antenna_r: Node3D = root.get_meta("antenna_r", null)
	var s: float = float(root.get_meta("scale", 1.0))

	if is_moving:
		# ── Tripod gait: alternate legs step up/down ──
		var leg_count: int = legs.size()
		for i: int in range(leg_count):
			var leg_pivot: Node3D = legs[i] as Node3D
			if leg_pivot == null:
				continue
			# Alternate phase offset: even legs vs odd legs are half-cycle apart
			var offset: float = 0.0 if i % 2 == 0 else PI
			# Additional offset per pair so not all left legs move identically
			var pair_offset: float = float(i / 2) * (TAU / float(maxi(1, leg_count / 2)))
			var leg_phase: float = phase * 8.0 + offset + pair_offset
			# Bob up/down
			var bob: float = sin(leg_phase) * 0.04 * s
			leg_pivot.position.y += bob * delta * 15.0
			# Slight forward/back swing
			var swing: float = sin(leg_phase) * 0.06
			leg_pivot.rotation.x = lerpf(leg_pivot.rotation.x, swing, delta * 10.0)

		# Antennae tuck back slightly while moving
		if antenna_l != null:
			antenna_l.rotation.x = lerpf(antenna_l.rotation.x, 0.15, delta * 4.0)
		if antenna_r != null:
			antenna_r.rotation.x = lerpf(antenna_r.rotation.x, 0.15, delta * 4.0)

	else:
		# ── Idle: legs settle to rest, antennae sway ──
		for i: int in range(legs.size()):
			var leg_pivot: Node3D = legs[i] as Node3D
			if leg_pivot == null:
				continue
			# Ease rotation back to zero
			leg_pivot.rotation.x = lerpf(leg_pivot.rotation.x, 0.0, delta * 5.0)

		# Antennae gentle sway (different frequencies for organic feel)
		if antenna_l != null:
			var sway_l: float = sin(phase * 1.8) * 0.12 + sin(phase * 3.1) * 0.05
			antenna_l.rotation.z = lerpf(antenna_l.rotation.z, sway_l, delta * 3.0)
			antenna_l.rotation.x = lerpf(antenna_l.rotation.x, sin(phase * 1.3) * 0.06, delta * 3.0)
		if antenna_r != null:
			var sway_r: float = sin(phase * 1.8 + 0.5) * 0.12 + sin(phase * 2.7) * 0.05
			antenna_r.rotation.z = lerpf(antenna_r.rotation.z, sway_r, delta * 3.0)
			antenna_r.rotation.x = lerpf(antenna_r.rotation.x, sin(phase * 1.5 + 0.3) * 0.06, delta * 3.0)

	# ── Subtle body bob (always active, more pronounced when moving) ──
	var bob_amp: float = 0.01 * s if not is_moving else 0.02 * s
	var bob_speed: float = 2.0 if not is_moving else 6.0
	root.position.y = sin(phase * bob_speed) * bob_amp
