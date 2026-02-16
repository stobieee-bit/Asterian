## JellyfishMesh — Translucent bioluminescent jellyfish enemy
##
## Bell dome with surface veins, inner radial canals, gonad structures,
## glowing core, torus rim with scalloped lappets, bioluminescent spots
## (two rings), central manubrium stalk, 4 oral arms with frilly edges,
## 8 trailing tentacles with mid-segment nodes and glowing tips.
## Floats above ground with pulsing bob, tentacle sway, frill flutter,
## and lappet ripple.
## ~87 mesh nodes, 12 materials.
class_name JellyfishMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x4488CC))
	var s: float = params.get("scale", 1.0)

	# ── Materials (8 original + 4 new = 12) ──
	# Semi-transparent bell material with emissive glow
	var mat_bell: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.1, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.3), 1.2,
		true, 0.45
	)
	# Rim material — slightly more opaque, metallic sheen
	var mat_rim: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.05), 0.3, 0.4,
		base_color, 0.8,
		true, 0.55
	)
	# Inner core — bright emissive glow
	var mat_core: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color.WHITE, 0.0, 0.2,
		EnemyMeshBuilder.lighten(base_color, 0.4), 3.0,
		true, 0.7
	)
	# Oral arm material — semi-transparent, moderate glow
	var mat_oral: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.1, 0.5,
		base_color, 0.6,
		true, 0.5
	)
	# Tentacle material — thin, translucent
	var mat_tentacle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.05, 0.6,
		Color.BLACK, 0.0,
		true, 0.35
	)
	# Tentacle tip glow
	var mat_tip: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.3), 0.0, 0.2,
		EnemyMeshBuilder.lighten(base_color, 0.5), 2.5,
		true, 0.8
	)
	# Bioluminescent spot material
	var mat_spot: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color.WHITE, 0.0, 0.1,
		EnemyMeshBuilder.lighten(base_color, 0.5), 4.0,
		true, 0.9
	)
	# Bell surface vein material — darker bell, semi-transparent
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.15, 0.35,
		EnemyMeshBuilder.darken(base_color, 0.05), 0.5,
		true, 0.4
	)
	# Radial canal material — lighter, very translucent
	var mat_canal: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.25), 0.05, 0.25,
		EnemyMeshBuilder.lighten(base_color, 0.35), 0.8,
		true, 0.3
	)
	# Gonad material — warm pinkish, slight emission
	var mat_gonad: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.85, 0.55, 0.65), 0.1, 0.4,
		Color(0.95, 0.6, 0.7), 1.0,
		true, 0.55
	)
	# Lappet material — softer rim variant for bell edge scallops
	var mat_lappet: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.02), 0.2, 0.45,
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.6,
		true, 0.5
	)

	# Floating offset — jellyfish hovers above ground
	var y_off: float = 1.0 * s

	# ── Bell Dome ──
	# Flattened half-sphere for the bell (scale Y < 1 for dome shape)
	var bell: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.55 * s,
		Vector3(0.0, y_off + 0.35 * s, 0.0),
		mat_bell,
		Vector3(1.0, 0.7, 1.0)
	)

	# ── Bell Surface Veins (8 capsules radiating from apex) ──
	var veins: Array = []
	for i: int in range(8):
		var angle: float = (float(i) / 8.0) * TAU
		# Veins radiate from near the apex down toward the rim
		var vein_cx: float = cos(angle) * 0.22 * s
		var vein_cz: float = sin(angle) * 0.22 * s
		var vein_cy: float = y_off + 0.28 * s
		# Tilt outward from apex to rim
		var tilt_x: float = sin(angle) * 0.45
		var tilt_z: float = -cos(angle) * 0.45
		var vein: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.008 * s, 0.32 * s,
			Vector3(vein_cx, vein_cy, vein_cz),
			mat_vein,
			Vector3(tilt_x, 0.0, tilt_z)
		)
		veins.append(vein)

	# ── Bell Rim ──
	# Torus at the base of the dome
	var rim: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.04 * s, 0.52 * s,
		Vector3(0.0, y_off + 0.02 * s, 0.0),
		mat_rim
	)

	# ── Bell Rim Lappets (8 scalloped spheres around rim) ──
	var lappets: Array = []
	for i: int in range(8):
		var angle: float = (float(i) / 8.0) * TAU
		var lap_r: float = 0.52 * s
		var lap: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.04 * s,
			Vector3(cos(angle) * lap_r, y_off + 0.0 * s, sin(angle) * lap_r),
			mat_lappet,
			Vector3(1.2, 0.6, 1.2)
		)
		lappets.append(lap)

	# ── Inner Glowing Core ──
	var core: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.15 * s,
		Vector3(0.0, y_off + 0.25 * s, 0.0),
		mat_core
	)

	# ── Radial Canals (4 thin cross-shaped capsules inside bell) ──
	var canals: Array = []
	for i: int in range(4):
		var angle: float = (float(i) / 4.0) * TAU
		var canal_cx: float = cos(angle) * 0.17 * s
		var canal_cz: float = sin(angle) * 0.17 * s
		var canal: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.006 * s, 0.3 * s,
			Vector3(canal_cx, y_off + 0.2 * s, canal_cz),
			mat_canal,
			Vector3(sin(angle) * 0.3, 0.0, -cos(angle) * 0.3)
		)
		canals.append(canal)

	# ── Gonad Structures (4 spheres along radial canals) ──
	var gonads: Array = []
	for i: int in range(4):
		var angle: float = (float(i) / 4.0) * TAU
		var gonad_r: float = 0.17 * s
		var gonad: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.035 * s,
			Vector3(cos(angle) * gonad_r, y_off + 0.18 * s, sin(angle) * gonad_r),
			mat_gonad
		)
		gonads.append(gonad)

	# ── Manubrium (central feeding stalk from core to oral arms) ──
	var manubrium: MeshInstance3D = EnemyMeshBuilder.add_cylinder(
		root, 0.02 * s, 0.02 * s, 0.3 * s,
		Vector3(0.0, y_off + 0.0 * s, 0.0),
		mat_canal
	)

	# ── Bioluminescent Spots — Ring 1 (6 spots on upper dome) ──
	var spots: Array = []
	var spot_count_r1: int = 6
	for i: int in range(spot_count_r1):
		var angle: float = (float(i) / float(spot_count_r1)) * TAU
		var spot_r: float = 0.35 * s
		var spot_y: float = y_off + 0.3 * s + 0.1 * s * sin(angle * 2.0)
		var spot: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.035 * s,
			Vector3(cos(angle) * spot_r, spot_y, sin(angle) * spot_r),
			mat_spot
		)
		spots.append(spot)

	# ── Bioluminescent Spots — Ring 2 (6 more at lower dome, different radius) ──
	var spot_count_r2: int = 6
	for i: int in range(spot_count_r2):
		var angle: float = (float(i) / float(spot_count_r2)) * TAU + PI / 6.0
		var spot_r2: float = 0.44 * s
		var spot_y2: float = y_off + 0.12 * s + 0.06 * s * sin(angle * 3.0)
		var spot2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.03 * s,
			Vector3(cos(angle) * spot_r2, spot_y2, sin(angle) * spot_r2),
			mat_spot
		)
		spots.append(spot2)

	# ── Oral Arms (4 thick tentacles from center) ──
	var oral_arms: Array = []
	for i: int in range(4):
		var angle: float = (float(i) / 4.0) * TAU + PI / 4.0
		var arm_x: float = cos(angle) * 0.1 * s
		var arm_z: float = sin(angle) * 0.1 * s
		# Upper segment
		var arm_upper: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.04 * s, 0.3 * s,
			Vector3(arm_x, y_off - 0.2 * s, arm_z),
			mat_oral,
			Vector3(sin(angle) * 0.15, 0.0, -cos(angle) * 0.15)
		)
		# Lower segment (thinner, dangling further)
		var arm_lower: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.03 * s, 0.25 * s,
			Vector3(arm_x * 1.3, y_off - 0.55 * s, arm_z * 1.3),
			mat_oral,
			Vector3(sin(angle) * 0.25, 0.0, -cos(angle) * 0.25)
		)
		oral_arms.append(arm_upper)
		oral_arms.append(arm_lower)

	# ── Oral Arm Frills (8 thin capsules, 2 per arm) ──
	var frills: Array = []
	for i: int in range(4):
		var angle: float = (float(i) / 4.0) * TAU + PI / 4.0
		var arm_x: float = cos(angle) * 0.1 * s
		var arm_z: float = sin(angle) * 0.1 * s
		# Frill A — offset to one side of the arm
		var frill_off_a: float = angle + 0.25
		var frill_a: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, 0.18 * s,
			Vector3(arm_x + cos(frill_off_a) * 0.04 * s, y_off - 0.32 * s, arm_z + sin(frill_off_a) * 0.04 * s),
			mat_oral,
			Vector3(sin(angle) * 0.2 + 0.1, 0.0, -cos(angle) * 0.2)
		)
		frills.append(frill_a)
		# Frill B — offset to the other side
		var frill_off_b: float = angle - 0.25
		var frill_b: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, 0.18 * s,
			Vector3(arm_x + cos(frill_off_b) * 0.04 * s, y_off - 0.35 * s, arm_z + sin(frill_off_b) * 0.04 * s),
			mat_oral,
			Vector3(sin(angle) * 0.2 - 0.1, 0.0, -cos(angle) * 0.2)
		)
		frills.append(frill_b)

	# ── Trailing Tentacles (8 thin strands with glowing tips) ──
	var tentacles: Array = []
	var tentacle_tips: Array = []
	var tentacle_mids: Array = []
	for i: int in range(8):
		var angle: float = (float(i) / 8.0) * TAU
		var t_radius: float = 0.42 * s
		var t_x: float = cos(angle) * t_radius
		var t_z: float = sin(angle) * t_radius

		# Main tentacle strand
		var strand_len: float = (0.4 + 0.15 * sin(float(i) * 1.7)) * s
		var strand: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.015 * s, strand_len,
			Vector3(t_x, y_off - 0.15 * s - strand_len * 0.5, t_z),
			mat_tentacle,
			Vector3(sin(angle) * 0.1, 0.0, -cos(angle) * 0.1)
		)
		tentacles.append(strand)

		# Mid-segment node sphere at tentacle midpoint
		var mid_y: float = y_off - 0.15 * s - strand_len * 0.5
		var mid_node: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.02 * s,
			Vector3(t_x * 1.02, mid_y, t_z * 1.02),
			mat_tip
		)
		tentacle_mids.append(mid_node)

		# Glowing tip at bottom
		var tip: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.025 * s,
			Vector3(t_x * 1.05, y_off - 0.15 * s - strand_len, t_z * 1.05),
			mat_tip
		)
		tentacle_tips.append(tip)

	# ── Store animatable references ──
	root.set_meta("bell", [bell])
	root.set_meta("core", [core])
	root.set_meta("rim", [rim])
	root.set_meta("oral_arms", oral_arms)
	root.set_meta("tentacles", tentacles)
	root.set_meta("tentacle_tips", tentacle_tips)
	root.set_meta("tentacle_mids", tentacle_mids)
	root.set_meta("spots", spots)
	root.set_meta("veins", veins)
	root.set_meta("canals", canals)
	root.set_meta("gonads", gonads)
	root.set_meta("manubrium", [manubrium])
	root.set_meta("frills", frills)
	root.set_meta("lappets", lappets)
	root.set_meta("y_off", y_off)
	root.set_meta("scale", s)

	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = root.get_meta("scale", 1.0)
	var y_off: float = root.get_meta("y_off", 1.0)

	# ── Bell pulsing bob ──
	# Gentle up/down floating motion
	var bob: float = sin(phase * 1.5) * 0.08 * s
	var bell_arr: Array = root.get_meta("bell", [])
	if bell_arr.size() > 0:
		var bell: MeshInstance3D = bell_arr[0] as MeshInstance3D
		bell.position.y = y_off + 0.35 * s + bob
		# Slight scale pulse for breathing effect
		var pulse: float = 1.0 + sin(phase * 1.5) * 0.04
		bell.scale = Vector3(pulse, 0.7 / pulse, pulse)

	# ── Bell Surface Veins follow bell bob ──
	var veins: Array = root.get_meta("veins", [])
	for i: int in range(veins.size()):
		var vein: MeshInstance3D = veins[i] as MeshInstance3D
		vein.position.y += bob * 0.9 * delta * 10.0

	# ── Core pulse ──
	var core_arr: Array = root.get_meta("core", [])
	if core_arr.size() > 0:
		var core_node: MeshInstance3D = core_arr[0] as MeshInstance3D
		core_node.position.y = y_off + 0.25 * s + bob
		var core_pulse: float = 1.0 + sin(phase * 3.0) * 0.15
		core_node.scale = Vector3(core_pulse, core_pulse, core_pulse)

	# ── Radial Canals follow bell bob ──
	var canals: Array = root.get_meta("canals", [])
	for i: int in range(canals.size()):
		var canal: MeshInstance3D = canals[i] as MeshInstance3D
		canal.position.y += bob * 0.85 * delta * 10.0

	# ── Gonad structures — gentle pulse and bob ──
	var gonads: Array = root.get_meta("gonads", [])
	for i: int in range(gonads.size()):
		var gonad: MeshInstance3D = gonads[i] as MeshInstance3D
		gonad.position.y += bob * 0.85 * delta * 10.0
		var g_pulse: float = 1.0 + sin(phase * 2.5 + float(i) * 1.6) * 0.1
		gonad.scale = Vector3(g_pulse, g_pulse, g_pulse)

	# ── Manubrium follows bell bob ──
	var manubrium_arr: Array = root.get_meta("manubrium", [])
	if manubrium_arr.size() > 0:
		var manub: MeshInstance3D = manubrium_arr[0] as MeshInstance3D
		manub.position.y += bob * 0.7 * delta * 10.0

	# ── Rim follows bell ──
	var rim_arr: Array = root.get_meta("rim", [])
	if rim_arr.size() > 0:
		var rim_node: MeshInstance3D = rim_arr[0] as MeshInstance3D
		rim_node.position.y = y_off + 0.02 * s + bob

	# ── Lappets — gentle bob following rim with ripple offset ──
	var lappets: Array = root.get_meta("lappets", [])
	for i: int in range(lappets.size()):
		var lap: MeshInstance3D = lappets[i] as MeshInstance3D
		var lap_bob: float = bob + sin(phase * 2.0 + float(i) * 0.8) * 0.015 * s
		lap.position.y = y_off + 0.0 * s + lap_bob
		var lap_pulse: float = 1.0 + sin(phase * 2.5 + float(i) * 1.0) * 0.08
		lap.scale = Vector3(1.2 * lap_pulse, 0.6 / lap_pulse, 1.2 * lap_pulse)

	# ── Oral arm sway ──
	var oral_arms: Array = root.get_meta("oral_arms", [])
	for i: int in range(oral_arms.size()):
		var arm: MeshInstance3D = oral_arms[i] as MeshInstance3D
		var arm_idx: float = float(i)
		var sway_x: float = sin(phase * 1.2 + arm_idx * 0.8) * 0.12
		var sway_z: float = cos(phase * 1.0 + arm_idx * 1.1) * 0.12
		arm.rotation.x += (sway_x - arm.rotation.x) * delta * 3.0
		arm.rotation.z += (sway_z - arm.rotation.z) * delta * 3.0
		# Shift Y with bob
		arm.position.y += bob * 0.5 * delta * 10.0

	# ── Oral Arm Frills — gentle sway offset from arms ──
	var frills: Array = root.get_meta("frills", [])
	for i: int in range(frills.size()):
		var frill: MeshInstance3D = frills[i] as MeshInstance3D
		var frill_idx: float = float(i)
		var frill_sway_x: float = sin(phase * 1.8 + frill_idx * 1.1) * 0.18
		var frill_sway_z: float = cos(phase * 1.4 + frill_idx * 0.9) * 0.18
		frill.rotation.x += (frill_sway_x - frill.rotation.x) * delta * 3.5
		frill.rotation.z += (frill_sway_z - frill.rotation.z) * delta * 3.5
		frill.position.y += bob * 0.4 * delta * 10.0

	# ── Tentacle sway ──
	var tentacles: Array = root.get_meta("tentacles", [])
	var tentacle_tips: Array = root.get_meta("tentacle_tips", [])
	var tentacle_mids: Array = root.get_meta("tentacle_mids", [])
	for i: int in range(tentacles.size()):
		var strand: MeshInstance3D = tentacles[i] as MeshInstance3D
		var idx_f: float = float(i)
		# Wavy sway with phase offsets per tentacle
		var sway_amt: float = 0.15 if is_moving else 0.08
		var sway_spd: float = 2.0 if is_moving else 1.0
		var rot_x: float = sin(phase * sway_spd + idx_f * 0.9) * sway_amt
		var rot_z: float = cos(phase * sway_spd * 0.7 + idx_f * 1.3) * sway_amt
		strand.rotation.x += (rot_x - strand.rotation.x) * delta * 4.0
		strand.rotation.z += (rot_z - strand.rotation.z) * delta * 4.0

		# Mid-segment nodes bob with tentacle
		if i < tentacle_mids.size():
			var mid: MeshInstance3D = tentacle_mids[i] as MeshInstance3D
			mid.position.y += bob * 0.4 * delta * 10.0
			var mid_pulse: float = 0.8 + 0.2 * sin(phase * 3.0 + idx_f * 1.2)
			mid.scale = Vector3(mid_pulse, mid_pulse, mid_pulse)

		# Tips follow tentacle ends loosely
		if i < tentacle_tips.size():
			var tip: MeshInstance3D = tentacle_tips[i] as MeshInstance3D
			tip.position.y += bob * 0.3 * delta * 10.0

	# ── Bioluminescent spot flicker (both rings) ──
	var spots: Array = root.get_meta("spots", [])
	for i: int in range(spots.size()):
		var spot: MeshInstance3D = spots[i] as MeshInstance3D
		var flicker: float = 0.7 + 0.3 * sin(phase * 4.0 + float(i) * 1.5)
		spot.scale = Vector3(flicker, flicker, flicker)
		spot.position.y += bob * 0.8 * delta * 10.0
