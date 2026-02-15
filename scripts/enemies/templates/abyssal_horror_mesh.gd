## AbyssalHorrorMesh — Procedural mesh builder for a Lovecraftian deep-sea horror
##
## A nightmarish deep-ocean entity with a bulbous central mass, gaping maw
## ringed with teeth, writhing tentacles with bioluminescent tips, multiple
## scattered eyes, barnacle growths, and membrane fins.
##
## ~45-55 mesh nodes. Animate: tentacle writhing, body pulse, eye blink.
class_name AbyssalHorrorMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	# ── Extract parameters ──
	var base_color: Color = EnemyMeshBuilder.int_to_color(int(params.get("color", 0x1e1028)))
	var s: float = float(params.get("scale", 1.0))

	var root: Node3D = Node3D.new()
	root.name = "AbyssalHorrorRoot"

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.2, 0.85  # Low metallic, very rough — organic
	)
	var mat_body_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.06), 0.2, 0.9
	)
	var mat_maw: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.3, 0.7,
		Color(0.4, 0.05, 0.08), 0.8  # Faint reddish inner glow
	)
	var mat_tooth: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.85, 0.82, 0.7), 0.4, 0.4  # Pale bone
	)
	var mat_tentacle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.04), 0.15, 0.8
	)
	var mat_tentacle_tip: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.15, 0.8, 0.6), 0.3, 0.4,
		Color(0.1, 0.9, 0.7), 2.8  # Teal bioluminescent tips
	)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.85, 0.15), 0.5, 0.3,
		Color(1.0, 0.9, 0.1), 3.5  # Sickly yellow glow
	)
	var mat_pupil: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.02, 0.02, 0.02), 0.1, 0.9  # Dark pupil
	)
	var mat_barnacle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.15, 0.95  # Rough growths
	)
	var mat_membrane: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.06), 0.15, 0.7,
		Color.BLACK, 0.0, true, 0.4  # Translucent membrane
	)

	# ── Central body — floats slightly above ground ──
	var body_y: float = 0.9 * s
	var body_radius: float = 0.35 * s

	var body: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, body_radius,
		Vector3(0.0, body_y, 0.0),
		mat_body, Vector3(1.0, 0.9, 1.1)  # Slightly elongated along Z
	)
	body.name = "Body"

	# Secondary body lump — organic asymmetry on top
	var body_lump: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, body_radius * 0.55,
		Vector3(0.06 * s, body_y + 0.2 * s, -0.05 * s),
		mat_body_dark, Vector3(1.1, 0.7, 1.0)
	)
	body_lump.name = "BodyLump"

	# ── MAW — torus ring at the front of the body ──
	var maw_pos: Vector3 = Vector3(0.0, body_y - 0.05 * s, -body_radius * 0.8)
	var maw: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.1 * s, 0.2 * s,
		maw_pos, mat_maw,
		Vector3(PI * 0.5, 0.0, 0.0)  # Face forward (-Z)
	)
	maw.name = "Maw"

	# Maw teeth — cones arranged in a ring around the torus
	var tooth_count: int = 8
	var teeth: Array[MeshInstance3D] = []
	for i: int in range(tooth_count):
		var angle: float = float(i) / float(tooth_count) * TAU
		var tooth_r: float = 0.15 * s  # Distance from maw center
		var tx: float = cos(angle) * tooth_r
		var ty: float = sin(angle) * tooth_r
		# Teeth point inward toward the center of the maw
		var inward_rot: Vector3 = Vector3(
			sin(angle) * 0.8,
			0.0,
			-cos(angle) * 0.8
		)
		var tooth: MeshInstance3D = EnemyMeshBuilder.add_cone(
			root, 0.018 * s, 0.09 * s,
			maw_pos + Vector3(tx, ty, -0.03 * s),
			mat_tooth, inward_rot
		)
		tooth.name = "Tooth%d" % i
		teeth.append(tooth)

	# ── TENTACLES — 8 capsules radiating from the body ──
	# Each tentacle has a pivot for animation, a capsule body, and a glowing tip.
	var tentacle_count: int = 8
	var tentacle_pivots: Array[Node3D] = []
	var tentacle_tips: Array[MeshInstance3D] = []

	# Pre-defined tentacle directions (angle around body, vertical angle, length)
	# Distribute in a varied organic pattern: some up, some down, some forward
	var tent_configs: Array[Dictionary] = [
		{"h_angle": 0.0,    "v_angle": -0.3, "len": 0.55, "droop": 0.2},   # Forward-left
		{"h_angle": 0.8,    "v_angle":  0.4, "len": 0.50, "droop": -0.1},  # Upper-right
		{"h_angle": 1.6,    "v_angle": -0.5, "len": 0.60, "droop": 0.35},  # Right drooping
		{"h_angle": 2.4,    "v_angle":  0.1, "len": 0.45, "droop": 0.1},   # Back-right
		{"h_angle": 3.2,    "v_angle": -0.6, "len": 0.58, "droop": 0.4},   # Back drooping
		{"h_angle": 4.0,    "v_angle":  0.5, "len": 0.48, "droop": -0.15}, # Back-left upper
		{"h_angle": 4.8,    "v_angle": -0.2, "len": 0.52, "droop": 0.25},  # Left
		{"h_angle": 5.6,    "v_angle":  0.3, "len": 0.50, "droop": 0.0},   # Upper-left-forward
	]

	for i: int in range(tentacle_count):
		var cfg: Dictionary = tent_configs[i]
		var h_angle: float = float(cfg["h_angle"])
		var v_angle: float = float(cfg["v_angle"])
		var tent_len: float = float(cfg["len"]) * s
		var droop: float = float(cfg["droop"])

		# Pivot at the body surface
		var attach_x: float = cos(h_angle) * body_radius * 0.7
		var attach_z: float = sin(h_angle) * body_radius * 0.7
		var attach_y: float = body_y + v_angle * body_radius * 0.5

		var pivot: Node3D = Node3D.new()
		pivot.name = "TentaclePivot%d" % i
		pivot.position = Vector3(attach_x, attach_y, attach_z)
		root.add_child(pivot)
		tentacle_pivots.append(pivot)

		# Tentacle body — capsule extending outward from the pivot
		var outward_dir_x: float = cos(h_angle) * tent_len * 0.5
		var outward_dir_z: float = sin(h_angle) * tent_len * 0.5
		var outward_dir_y: float = -droop * tent_len

		# Rotation to point the capsule outward (approximate with Euler angles)
		var tent_rot: Vector3 = Vector3(
			droop * 1.2,
			-h_angle + PI * 0.5,
			0.0
		)

		var tentacle: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			pivot, 0.03 * s, tent_len,
			Vector3(outward_dir_x, outward_dir_y, outward_dir_z),
			mat_tentacle, tent_rot
		)
		tentacle.name = "Tentacle%d" % i

		# Glowing tip sphere at the end of the tentacle
		var tip: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			pivot, 0.025 * s,
			Vector3(outward_dir_x * 2.0, outward_dir_y * 2.0, outward_dir_z * 2.0),
			mat_tentacle_tip
		)
		tip.name = "TentacleTip%d" % i
		tentacle_tips.append(tip)

	# ── EYES — 6 glowing eyes scattered across the body surface ──
	var eye_positions: Array[Vector3] = [
		Vector3(-0.18 * s, body_y + 0.22 * s, -0.18 * s),  # Upper-left-front
		Vector3(0.20 * s,  body_y + 0.18 * s, -0.12 * s),  # Upper-right-front
		Vector3(-0.10 * s, body_y + 0.30 * s, 0.05 * s),   # Top-left
		Vector3(0.14 * s,  body_y + 0.28 * s, 0.10 * s),   # Top-right
		Vector3(-0.22 * s, body_y + 0.05 * s, -0.08 * s),  # Mid-left
		Vector3(0.08 * s,  body_y - 0.10 * s, -0.25 * s),  # Lower-front
	]
	var eyes: Array[MeshInstance3D] = []
	for i: int in range(eye_positions.size()):
		# Eye globe
		var eye: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.04 * s, eye_positions[i], mat_eye
		)
		eye.name = "Eye%d" % i
		eyes.append(eye)

		# Pupil (smaller, dark, slightly forward of the eye)
		var pupil_offset: Vector3 = (eye_positions[i] - Vector3(0.0, body_y, 0.0)).normalized() * 0.025 * s
		var pupil: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.018 * s,
			eye_positions[i] + pupil_offset,
			mat_pupil
		)
		pupil.name = "Pupil%d" % i

	# ── BARNACLE GROWTHS — 4 rough bumps on the body surface ──
	var barnacle_positions: Array[Vector3] = [
		Vector3(0.25 * s,  body_y + 0.1 * s,  0.15 * s),
		Vector3(-0.20 * s, body_y - 0.12 * s, 0.20 * s),
		Vector3(0.12 * s,  body_y + 0.25 * s,  0.22 * s),
		Vector3(-0.28 * s, body_y + 0.08 * s, -0.05 * s),
	]
	for i: int in range(barnacle_positions.size()):
		var barnacle: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.04 * s, barnacle_positions[i],
			mat_barnacle, Vector3(1.2, 0.8, 1.1)
		)
		barnacle.name = "Barnacle%d" % i

	# ── MEMBRANE FINS — 2 flattened spheres on left/right sides ──
	var fin_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.12 * s,
		Vector3(-body_radius * 0.9, body_y + 0.05 * s, 0.1 * s),
		mat_membrane, Vector3(0.2, 0.7, 1.3)
	)
	fin_l.name = "MembraneFinL"
	var fin_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.12 * s,
		Vector3(body_radius * 0.9, body_y + 0.05 * s, 0.1 * s),
		mat_membrane, Vector3(0.2, 0.7, 1.3)
	)
	fin_r.name = "MembraneFinR"

	# ── Store animatable parts as metadata ──
	root.set_meta("body", body)
	root.set_meta("body_lump", body_lump)
	root.set_meta("tentacle_pivots", tentacle_pivots)
	root.set_meta("tentacle_tips", tentacle_tips)
	root.set_meta("eyes", eyes)
	root.set_meta("fins", [fin_l, fin_r])
	root.set_meta("teeth", teeth)
	root.set_meta("maw", maw)
	root.set_meta("scale", s)
	root.set_meta("body_y", body_y)

	return root


## Animate the horror each frame.
## Tentacles writhe, body pulses, eyes blink, fins undulate.
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = float(root.get_meta("scale", 1.0))
	var base_y: float = float(root.get_meta("body_y", 0.9))

	# ── Body pulse — rhythmic breathing/throbbing ──
	if root.has_meta("body"):
		var body: MeshInstance3D = root.get_meta("body") as MeshInstance3D
		if body != null:
			var pulse_speed: float = 1.5 if not is_moving else 2.5
			var pulse: float = 1.0 + sin(phase * pulse_speed) * 0.04
			var target_scale: Vector3 = Vector3(pulse, 0.9 * pulse, 1.1 * pulse)
			body.scale = body.scale.lerp(target_scale, delta * 4.0)

			# Subtle vertical bob
			var bob_speed: float = 1.2 if not is_moving else 2.0
			var bob_amp: float = 0.03 * s if not is_moving else 0.05 * s
			body.position.y = lerpf(body.position.y, base_y + sin(phase * bob_speed) * bob_amp, delta * 3.0)

	# Body lump follows the main body pulse with slight delay
	if root.has_meta("body_lump"):
		var lump: MeshInstance3D = root.get_meta("body_lump") as MeshInstance3D
		if lump != null:
			var lump_pulse: float = 1.0 + sin(phase * 1.5 + 0.5) * 0.06
			var lump_target: Vector3 = Vector3(1.1 * lump_pulse, 0.7 * lump_pulse, 1.0 * lump_pulse)
			lump.scale = lump.scale.lerp(lump_target, delta * 3.5)

	# ── Tentacle writhing — each tentacle pivot oscillates differently ──
	if root.has_meta("tentacle_pivots"):
		var pivots: Array = root.get_meta("tentacle_pivots") as Array
		var writhe_speed: float = 2.0 if not is_moving else 3.5
		var writhe_amp: float = 0.25 if not is_moving else 0.4

		for i: int in range(pivots.size()):
			var pivot: Node3D = pivots[i] as Node3D
			if pivot == null:
				continue
			# Each tentacle has unique phase offset for organic variation
			var offset: float = float(i) * 1.37  # Golden-ratio-ish spacing
			var wx: float = sin(phase * writhe_speed + offset) * writhe_amp
			var wz: float = cos(phase * writhe_speed * 0.8 + offset * 1.5) * writhe_amp * 0.7
			var wy: float = sin(phase * writhe_speed * 0.6 + offset * 0.9) * writhe_amp * 0.4

			pivot.rotation.x = lerpf(pivot.rotation.x, wx, delta * 3.0)
			pivot.rotation.z = lerpf(pivot.rotation.z, wz, delta * 3.0)
			pivot.rotation.y = lerpf(pivot.rotation.y, wy, delta * 2.5)

	# ── Tentacle tip glow pulse — tips throb brighter/dimmer ──
	if root.has_meta("tentacle_tips"):
		var tips: Array = root.get_meta("tentacle_tips") as Array
		for i: int in range(tips.size()):
			var tip: MeshInstance3D = tips[i] as MeshInstance3D
			if tip == null:
				continue
			var glow_phase: float = phase * 2.0 + float(i) * 0.9
			var glow_scale: float = 1.0 + sin(glow_phase) * 0.3
			var target_s: float = lerpf(tip.scale.x, glow_scale, delta * 4.0)
			tip.scale = Vector3(target_s, target_s, target_s)

	# ── Eye blink — eyes periodically scale to 0 and back ──
	if root.has_meta("eyes"):
		var eyes: Array = root.get_meta("eyes") as Array
		for i: int in range(eyes.size()):
			var eye: MeshInstance3D = eyes[i] as MeshInstance3D
			if eye == null:
				continue
			# Each eye blinks at a different rate using a sharp sine threshold
			var blink_offset: float = float(i) * 2.1
			var blink_cycle: float = sin(phase * 0.8 + blink_offset)
			# Blink when cycle drops below -0.85 (brief ~10% of the cycle)
			var eye_scale: float = 1.0
			if blink_cycle < -0.85:
				# Map -0.85..-1.0 to 1..0 for a smooth close
				eye_scale = (blink_cycle + 1.0) / 0.15
				eye_scale = maxf(0.05, eye_scale)
			var current_eye_s: float = lerpf(eye.scale.y, eye_scale, delta * 12.0)
			eye.scale = Vector3(eye.scale.x, current_eye_s, eye.scale.z)
			# Keep X and Z at normal scale — only Y squishes for blink
			eye.scale.x = lerpf(eye.scale.x, 1.0, delta * 8.0)
			eye.scale.z = lerpf(eye.scale.z, 1.0, delta * 8.0)

	# ── Membrane fin undulation ──
	if root.has_meta("fins"):
		var fins: Array = root.get_meta("fins") as Array
		var fin_speed: float = 3.0 if is_moving else 1.5
		var fin_amp: float = 0.35 if is_moving else 0.18
		if fins.size() >= 2:
			var fl: MeshInstance3D = fins[0] as MeshInstance3D
			var fr: MeshInstance3D = fins[1] as MeshInstance3D
			if fl != null:
				fl.rotation.z = lerpf(fl.rotation.z, sin(phase * fin_speed) * fin_amp, delta * 4.0)
				fl.rotation.x = lerpf(fl.rotation.x, cos(phase * fin_speed * 0.7) * fin_amp * 0.3, delta * 3.0)
			if fr != null:
				fr.rotation.z = lerpf(fr.rotation.z, -sin(phase * fin_speed + 0.5) * fin_amp, delta * 4.0)
				fr.rotation.x = lerpf(fr.rotation.x, cos(phase * fin_speed * 0.7 + 0.5) * fin_amp * 0.3, delta * 3.0)

	# ── Maw pulse — the mouth ring throbs slightly ──
	if root.has_meta("maw"):
		var maw: MeshInstance3D = root.get_meta("maw") as MeshInstance3D
		if maw != null:
			var maw_pulse: float = 1.0 + sin(phase * 2.0) * 0.06
			var maw_target: Vector3 = Vector3(maw_pulse, maw_pulse, 1.0)
			maw.scale = maw.scale.lerp(maw_target, delta * 4.0)

	# ── Whole-body gentle drift (idle) or forward bob (moving) ──
	var drift_speed: float = 0.8 if not is_moving else 1.8
	var drift_amp: float = 0.015 * s if not is_moving else 0.025 * s
	root.position.y = lerpf(root.position.y, sin(phase * drift_speed) * drift_amp, delta * 2.0)
	if not is_moving:
		# Subtle lateral sway when idle
		root.position.x = lerpf(root.position.x, sin(phase * 0.5) * 0.02 * s, delta * 1.5)
