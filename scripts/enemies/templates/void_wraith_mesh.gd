## VoidWraithMesh -- Ghostly spectral wraith enemy mesh
##
## Translucent robed figure with tattered hem, hooded head, glowing eyes,
## spectral arms reaching forward, and ghostly wisp trails. Floats above
## ground with a gentle bob and rotation. Everything semi-transparent
## with emissive glow.
## ~25 mesh nodes.
class_name VoidWraithMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x6633AA) as int)

	# ── Materials ──

	# Outer robe -- semi-transparent, strong emissive glow
	var mat_robe: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.1, 0.4,
		base_color, 1.8,
		true, 0.35)

	# Inner void darkness -- very dark, slight emission
	var mat_void: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.35), 0.0, 0.9,
		EnemyMeshBuilder.darken(base_color, 0.30), 0.3,
		true, 0.6)

	# Hood / head -- semi-transparent, moderate glow
	var mat_hood: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.10), 0.1, 0.5,
		base_color, 1.2,
		true, 0.4)

	# Glowing eyes -- bright emissive
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.95, 1.0), 0.5, 0.2,
		EnemyMeshBuilder.lighten(base_color, 0.4), 3.5)

	# Spectral arms -- semi-transparent, emissive
	var mat_arm: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.1, 0.4,
		base_color, 1.0,
		true, 0.3)

	# Tattered hem strips -- slightly darker, semi-transparent
	var mat_hem: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.1, 0.5,
		EnemyMeshBuilder.darken(base_color, 0.04), 0.8,
		true, 0.3)

	# Wisp trails -- very transparent, bright glow
	var mat_wisp: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.0, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.20), 2.0,
		true, 0.2)

	# ── Float offset -- wraith hovers above ground ──
	var float_y: float = 0.3 * s

	# ── Outer robe body (cone shape) ──
	var robe: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.45 * s, 1.4 * s,
		Vector3(0.0, 0.7 * s + float_y, 0.0),
		mat_robe)

	# ── Inner void core (smaller darker cone inside robe) ──
	var void_core: MeshInstance3D = EnemyMeshBuilder.add_cone(
		root, 0.30 * s, 1.1 * s,
		Vector3(0.0, 0.6 * s + float_y, 0.0),
		mat_void)

	# ── Tattered hem strips (capsules hanging at robe bottom) ──
	var hem_strips: Array[MeshInstance3D] = []
	var hem_count: int = 6
	for i: int in range(hem_count):
		var angle: float = (float(i) / float(hem_count)) * TAU
		var hx: float = cos(angle) * 0.32 * s
		var hz: float = sin(angle) * 0.32 * s
		var strip: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.03 * s, 0.22 * s,
			Vector3(hx, 0.05 * s + float_y, hz),
			mat_hem,
			Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)))
		hem_strips.append(strip)

	# ── Hooded head (semi-transparent sphere at top of robe) ──
	var hood: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.18 * s,
		Vector3(0.0, 1.35 * s + float_y, 0.02 * s),
		mat_hood,
		Vector3(1.0, 1.1, 1.0))

	# ── Glowing eyes (two small bright spheres inside hood) ──
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.03 * s,
		Vector3(0.055 * s, 1.35 * s + float_y, 0.12 * s),
		mat_eye)
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.03 * s,
		Vector3(-0.055 * s, 1.35 * s + float_y, 0.12 * s),
		mat_eye)

	# ── Spectral arms (thin capsules reaching forward) ──
	# Upper arm segments
	var arm_l_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.04 * s, 0.35 * s,
		Vector3(0.30 * s, 1.05 * s + float_y, 0.15 * s),
		mat_arm,
		Vector3(-0.3, 0.0, -0.5))
	var arm_r_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.04 * s, 0.35 * s,
		Vector3(-0.30 * s, 1.05 * s + float_y, 0.15 * s),
		mat_arm,
		Vector3(-0.3, 0.0, 0.5))

	# Forearm / hand segments (thinner, reaching further forward)
	var arm_l_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.025 * s, 0.28 * s,
		Vector3(0.38 * s, 0.85 * s + float_y, 0.38 * s),
		mat_arm,
		Vector3(-0.6, 0.0, -0.3))
	var arm_r_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.025 * s, 0.28 * s,
		Vector3(-0.38 * s, 0.85 * s + float_y, 0.38 * s),
		mat_arm,
		Vector3(-0.6, 0.0, 0.3))

	# ── Spectral fingers / claws at arm tips (tiny capsules) ──
	var finger_l1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.012 * s, 0.08 * s,
		Vector3(0.42 * s, 0.72 * s + float_y, 0.50 * s),
		mat_arm,
		Vector3(-0.8, 0.2, -0.2))
	var finger_l2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.010 * s, 0.07 * s,
		Vector3(0.36 * s, 0.70 * s + float_y, 0.52 * s),
		mat_arm,
		Vector3(-0.9, 0.0, -0.1))
	var finger_r1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.012 * s, 0.08 * s,
		Vector3(-0.42 * s, 0.72 * s + float_y, 0.50 * s),
		mat_arm,
		Vector3(-0.8, -0.2, 0.2))
	var finger_r2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.010 * s, 0.07 * s,
		Vector3(-0.36 * s, 0.70 * s + float_y, 0.52 * s),
		mat_arm,
		Vector3(-0.9, 0.0, 0.1))

	# ── Cowl / collar around hood (torus for dimensional ring) ──
	var cowl: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.10 * s, 0.16 * s,
		Vector3(0.0, 1.22 * s + float_y, 0.02 * s),
		mat_robe,
		Vector3(0.3, 0.0, 0.0))

	# ── Ghostly wisp trails (small capsules trailing behind) ──
	var wisps: Array[MeshInstance3D] = []
	var wisp1: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.03 * s, 0.20 * s,
		Vector3(0.12 * s, 0.9 * s + float_y, -0.40 * s),
		mat_wisp,
		Vector3(0.4, 0.2, 0.0))
	wisps.append(wisp1)

	var wisp2: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.025 * s, 0.18 * s,
		Vector3(-0.10 * s, 0.7 * s + float_y, -0.45 * s),
		mat_wisp,
		Vector3(0.3, -0.3, 0.0))
	wisps.append(wisp2)

	var wisp3: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.02 * s, 0.15 * s,
		Vector3(0.0, 1.1 * s + float_y, -0.38 * s),
		mat_wisp,
		Vector3(0.5, 0.0, 0.2))
	wisps.append(wisp3)

	# Additional trailing wisps for fuller ghostly effect
	var wisp4: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.018 * s, 0.12 * s,
		Vector3(0.18 * s, 0.6 * s + float_y, -0.50 * s),
		mat_wisp,
		Vector3(0.6, 0.4, 0.0))
	wisps.append(wisp4)

	var wisp5: MeshInstance3D = EnemyMeshBuilder.add_capsule(
		root, 0.015 * s, 0.10 * s,
		Vector3(-0.15 * s, 1.0 * s + float_y, -0.48 * s),
		mat_wisp,
		Vector3(0.35, -0.2, 0.15))
	wisps.append(wisp5)

	# ── Store animatable parts ──
	root.set_meta("robe", [robe, void_core, cowl])
	root.set_meta("hood", [hood])
	root.set_meta("eyes", [eye_l, eye_r])
	root.set_meta("arms", [arm_l_upper, arm_r_upper, arm_l_lower, arm_r_lower])
	root.set_meta("fingers", [finger_l1, finger_l2, finger_r1, finger_r2])
	root.set_meta("hem_strips", hem_strips)
	root.set_meta("wisps", wisps)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Gentle floating bob ──
	var bob_speed: float = 2.0 if not is_moving else 3.0
	var bob_amount: float = 0.06 if not is_moving else 0.03
	root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Slow ghostly rotation (very subtle), preserving the PI base facing ──
	var rot_speed: float = 0.3 if not is_moving else 0.1
	root.rotation.y = PI + sin(phase * rot_speed) * 0.08

	# ── Arm sway -- spectral reaching motion ──
	if root.has_meta("arms"):
		var arms: Array = root.get_meta("arms") as Array
		if arms.size() >= 4:
			var sway: float = sin(phase * 1.5) * 0.15
			var sway_fwd: float = sin(phase * 1.2 + 0.5) * 0.1
			# Upper arms sway side to side
			var al_u: MeshInstance3D = arms[0] as MeshInstance3D
			var ar_u: MeshInstance3D = arms[1] as MeshInstance3D
			al_u.rotation.z = -0.5 + sway
			ar_u.rotation.z = 0.5 - sway
			# Lower arms wave forward/back
			var al_l: MeshInstance3D = arms[2] as MeshInstance3D
			var ar_l: MeshInstance3D = arms[3] as MeshInstance3D
			al_l.rotation.x = -0.6 + sway_fwd
			ar_l.rotation.x = -0.6 - sway_fwd

	# ── Tattered hem strips -- subtle sway ──
	if root.has_meta("hem_strips"):
		var strips: Array = root.get_meta("hem_strips") as Array
		for i: int in range(strips.size()):
			var strip: MeshInstance3D = strips[i] as MeshInstance3D
			var strip_phase: float = phase * 1.8 + float(i) * 1.2
			strip.rotation.x = sin(strip_phase) * 0.15
			strip.rotation.z = cos(strip_phase * 0.7) * 0.10

	# ── Wisps -- floating drift ──
	if root.has_meta("wisps"):
		var wisps: Array = root.get_meta("wisps") as Array
		for i: int in range(wisps.size()):
			var wisp: MeshInstance3D = wisps[i] as MeshInstance3D
			var wisp_phase: float = phase * 1.0 + float(i) * 2.1
			wisp.position.y += sin(wisp_phase) * 0.003
			wisp.position.x += cos(wisp_phase * 0.8) * 0.002
			wisp.rotation.z = sin(wisp_phase * 0.6) * 0.2
