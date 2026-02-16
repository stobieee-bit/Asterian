## RealityWarperMesh — Space-distorting entity with fracturing body
##
## A being that warps reality around it. Fractured outer shell with an inner
## void sphere, bright emissive "reality cracks" leaking through, orbiting
## debris fragments, and spinning distortion rings at various angles.
## ~78 mesh nodes. Animates fragment orbits, ring spins, body pulse,
## void eye rotation, tendril wave, glitch flicker.
class_name RealityWarperMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RealityWarperRoot"
	var s: float = float(params.get("scale", 1.0))
	var base_color: Color = EnemyMeshBuilder.int_to_color(int(params.get("color", 0x6A0DAD)))

	# ── Hover height — floats above the ground ──
	var body_y: float = 1.0 * s

	# ── Materials ──
	var mat_shell: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.6, 0.35,
		base_color, 0.5,
		true, 0.7)
	var mat_shell_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.6, 0.35,
		EnemyMeshBuilder.darken(base_color, 0.1), 0.3,
		true, 0.65)
	var mat_void: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.02, 0.0, 0.04), 0.0, 1.0,
		Color(0.05, 0.0, 0.08), 0.2)
	var mat_crack: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.95, 1.0), 0.1, 0.2,
		Color(0.7, 0.95, 1.0), 6.0)
	var mat_crack_warm: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(1.0, 0.85, 0.7), 0.1, 0.2,
		Color(1.0, 0.7, 0.4), 4.5)
	var mat_fragment: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.5, 0.4,
		EnemyMeshBuilder.lighten(base_color, 0.12), 0.8)
	var mat_fragment_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.06), 0.5, 0.4,
		base_color, 0.4)
	var mat_ring: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.3, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.2), 2.0,
		true, 0.5)
	var mat_void_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(1.0, 0.0, 0.5), 0.0, 0.2,
		Color(1.0, 0.0, 0.5), 4.0,
		true, 0.5)
	var mat_tendril: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.2, 0.4,
		base_color, 1.2,
		true, 0.4)
	var mat_glitch: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.0, 1.0, 0.5), 0.0, 0.2,
		Color(0.0, 1.0, 0.5), 3.0)

	# ══════════════════════════════════════════════════════════════
	# INNER VOID — dark core sphere
	# ══════════════════════════════════════════════════════════════

	var void_core: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.22 * s, Vector3(0.0, body_y, 0.0), mat_void)
	void_core.name = "VoidCore"

	# ══════════════════════════════════════════════════════════════
	# FRACTURED SHELL — main sphere + offset half-spheres at angles
	# ══════════════════════════════════════════════════════════════

	# Main outer shell (semi-transparent, slightly larger than void)
	var shell_main: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.35 * s, Vector3(0.0, body_y, 0.0), mat_shell)
	shell_main.name = "ShellMain"

	# Fracture shards — offset half-spheres suggesting the body is cracking apart
	# Each shard: [offset_direction, scale_distortion]
	var shard_data: Array = [
		[Vector3(0.12, 0.1, 0.08),   Vector3(0.7, 0.85, 0.9)],
		[Vector3(-0.1, 0.12, -0.06), Vector3(0.8, 0.7, 0.85)],
		[Vector3(0.06, -0.12, 0.1),  Vector3(0.85, 0.75, 0.8)],
		[Vector3(-0.08, -0.08, -0.12), Vector3(0.75, 0.8, 0.7)],
		[Vector3(0.14, 0.0, -0.1),   Vector3(0.65, 0.9, 0.75)],
	]

	for si: int in range(shard_data.size()):
		var sd: Array = shard_data[si]
		var shard_offset: Vector3 = (sd[0] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var shard_scale: Vector3 = sd[1] as Vector3
		var shard_mat: StandardMaterial3D = mat_shell if si % 2 == 0 else mat_shell_dark
		var shard: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.2 * s, shard_offset, shard_mat, shard_scale)
		shard.name = "Shard%d" % si

	# ══════════════════════════════════════════════════════════════
	# REALITY CRACKS — thin bright emissive capsules through the body
	# ══════════════════════════════════════════════════════════════

	# Each crack: [position_offset, rotation, length]
	var crack_data: Array = [
		[Vector3(0.0, 0.1, -0.05),   Vector3(0.3, 0.8, 0.5),    0.45],
		[Vector3(0.08, -0.05, 0.06), Vector3(-0.5, 0.3, -0.7),  0.40],
		[Vector3(-0.06, 0.08, 0.04), Vector3(0.7, -0.4, 0.2),   0.38],
		[Vector3(0.04, 0.0, -0.1),   Vector3(-0.2, 1.0, -0.3),  0.42],
		[Vector3(-0.03, -0.1, 0.08), Vector3(0.9, 0.2, 0.6),    0.35],
	]

	var cracks: Array[MeshInstance3D] = []
	for ci: int in range(crack_data.size()):
		var cd: Array = crack_data[ci]
		var c_pos: Vector3 = (cd[0] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var c_rot: Vector3 = cd[1] as Vector3
		var c_len: float = (cd[2] as float) * s
		var c_mat: StandardMaterial3D = mat_crack if ci % 2 == 0 else mat_crack_warm
		var crack: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, c_len, c_pos, c_mat, c_rot)
		crack.name = "Crack%d" % ci
		cracks.append(crack)

	# ══════════════════════════════════════════════════════════════
	# ORBITING FRAGMENTS — small boxes and spheres floating around
	# ══════════════════════════════════════════════════════════════

	# Fragment pivot — rotates to orbit all fragments as a group
	var frag_pivot: Node3D = Node3D.new()
	frag_pivot.name = "FragmentPivot"
	frag_pivot.position = Vector3(0.0, body_y, 0.0)
	root.add_child(frag_pivot)

	# Each fragment: [orbit_radius, height_offset, angle, is_box, size_scale]
	var frag_data: Array = [
		[0.55, 0.1,  0.0,    true,  0.06],
		[0.50, -0.08, 0.785,  false, 0.04],
		[0.60, 0.15,  1.57,   true,  0.05],
		[0.45, -0.12, 2.36,   false, 0.05],
		[0.58, 0.05,  3.14,   true,  0.04],
		[0.52, -0.05, 3.93,   false, 0.035],
		[0.48, 0.18,  4.71,   true,  0.055],
		[0.56, -0.15, 5.50,   false, 0.045],
	]

	var fragments: Array[MeshInstance3D] = []
	for fi: int in range(frag_data.size()):
		var fd: Array = frag_data[fi]
		var orbit_r: float = (fd[0] as float) * s
		var h_off: float = (fd[1] as float) * s
		var angle: float = fd[2] as float
		var is_box: bool = fd[3] as bool
		var frag_size: float = (fd[4] as float) * s
		var frag_pos: Vector3 = Vector3(
			cos(angle) * orbit_r,
			h_off,
			sin(angle) * orbit_r)
		var frag_mat: StandardMaterial3D = mat_fragment if fi % 2 == 0 else mat_fragment_dark
		var frag_rot: Vector3 = Vector3(angle * 0.5, angle, angle * 0.3)
		var fragment: MeshInstance3D
		if is_box:
			var box_size: Vector3 = Vector3(frag_size, frag_size * 1.3, frag_size * 0.8)
			fragment = EnemyMeshBuilder.add_box(
				frag_pivot, box_size, frag_pos, frag_mat, frag_rot)
		else:
			fragment = EnemyMeshBuilder.add_sphere(
				frag_pivot, frag_size, frag_pos, frag_mat,
				Vector3(1.0, 0.8, 1.2))
		fragment.name = "Fragment%d" % fi
		fragments.append(fragment)

	# ══════════════════════════════════════════════════════════════
	# DISTORTION RINGS — 3 torus rings at different orbital angles
	# ══════════════════════════════════════════════════════════════

	# Each ring has its own pivot for independent spinning
	# Ring data: [tilt_rotation, inner_radius, outer_radius]
	var ring_data: Array = [
		[Vector3(0.4, 0.0, 0.2),   0.06, 0.42],
		[Vector3(-0.3, 0.8, -0.5), 0.05, 0.48],
		[Vector3(1.2, 0.3, 0.0),   0.04, 0.38],
	]

	var ring_pivots: Array[Node3D] = []
	for ri: int in range(ring_data.size()):
		var rd: Array = ring_data[ri]
		var r_tilt: Vector3 = rd[0] as Vector3
		var r_inner: float = (rd[1] as float) * s
		var r_outer: float = (rd[2] as float) * s

		# Pivot for this ring's spin
		var ring_pivot: Node3D = Node3D.new()
		ring_pivot.name = "RingPivot%d" % ri
		ring_pivot.position = Vector3(0.0, body_y, 0.0)
		ring_pivot.rotation = r_tilt
		root.add_child(ring_pivot)

		var ring: MeshInstance3D = EnemyMeshBuilder.add_torus(
			ring_pivot, r_inner, r_outer,
			Vector3.ZERO, mat_ring)
		ring.name = "Ring%d" % ri

		ring_pivots.append(ring_pivot)

	# ══════════════════════════════════════════════════════════════
	# ENERGY CORE GLOW — small bright sphere at the very center
	# ══════════════════════════════════════════════════════════════

	var mat_core_glow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.8, 0.9, 1.0), 0.0, 0.1,
		Color(0.7, 0.9, 1.0), 8.0,
		true, 0.6)
	var core_glow: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.1 * s, Vector3(0.0, body_y, 0.0), mat_core_glow)
	core_glow.name = "CoreGlow"

	# ══════════════════════════════════════════════════════════════
	# ENERGY MOTES — tiny emissive spheres scattered around the body
	# ══════════════════════════════════════════════════════════════

	var mat_mote: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.8, 0.95, 1.0), 0.0, 0.1,
		Color(0.6, 0.9, 1.0), 5.0,
		true, 0.5)
	var mote_positions: Array = [
		Vector3(0.35, 0.2, 0.15),
		Vector3(-0.3, -0.15, 0.25),
		Vector3(0.15, 0.3, -0.3),
		Vector3(-0.25, 0.1, -0.2),
		Vector3(0.28, -0.25, -0.1),
		Vector3(-0.1, 0.35, 0.1),
	]
	var motes: Array[MeshInstance3D] = []
	for mi: int in range(mote_positions.size()):
		var m_pos: Vector3 = (mote_positions[mi] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var mote: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.018 * s, m_pos, mat_mote)
		mote.name = "Mote%d" % mi
		motes.append(mote)

	# ══════════════════════════════════════════════════════════════
	# OUTER DISTORTION SHELL — large transparent sphere
	# ══════════════════════════════════════════════════════════════

	var mat_outer_shell: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.0, 1.0,
		base_color, 0.3,
		true, 0.06)
	var outer_shell: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.6 * s, Vector3(0.0, body_y, 0.0), mat_outer_shell)
	outer_shell.name = "OuterShell"

	# ══════════════════════════════════════════════════════════════
	# CENTRAL VOID EYE — iris torus, pupil sphere, eye glow
	# ══════════════════════════════════════════════════════════════

	var void_eye: Array[MeshInstance3D] = []
	var eye_pos: Vector3 = Vector3(0.0, body_y + 0.05 * s, -0.33 * s)
	var iris_torus: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.015 * s, 0.06 * s, eye_pos, mat_void_eye,
		Vector3(PI * 0.5, 0.0, 0.0))
	iris_torus.name = "IrisTorus"
	void_eye.append(iris_torus)
	var pupil_sphere: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.03 * s,
		Vector3(eye_pos.x, eye_pos.y, eye_pos.z - 0.02 * s), mat_void)
	pupil_sphere.name = "Pupil"
	var eye_glow: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(eye_pos.x, eye_pos.y, eye_pos.z + 0.01 * s), mat_void_eye)
	eye_glow.name = "EyeGlow"

	# ══════════════════════════════════════════════════════════════
	# REALITY TENDRILS — reaching capsules radiating from the body
	# ══════════════════════════════════════════════════════════════

	# Each tendril: [position_offset, rotation]
	var tendril_data: Array = [
		[Vector3(0.25, 0.1, 0.15),   Vector3(0.3, 0.0, -0.8)],
		[Vector3(-0.22, 0.12, 0.18), Vector3(0.4, 0.0, 0.7)],
		[Vector3(0.18, -0.1, -0.22), Vector3(-0.5, 0.0, -0.4)],
		[Vector3(-0.2, -0.08, -0.2), Vector3(-0.3, 0.0, 0.6)],
		[Vector3(0.0, 0.25, 0.2),    Vector3(0.8, 0.0, 0.0)],
		[Vector3(0.0, -0.22, -0.18), Vector3(-0.7, 0.0, 0.2)],
	]
	var tendrils: Array[MeshInstance3D] = []
	for ti: int in range(tendril_data.size()):
		var td: Array = tendril_data[ti]
		var t_pos: Vector3 = (td[0] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var t_rot: Vector3 = td[1] as Vector3
		var tendril: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.015 * s, 0.2 * s, t_pos, mat_tendril, t_rot)
		tendril.name = "Tendril%d" % ti
		tendrils.append(tendril)

	# ══════════════════════════════════════════════════════════════
	# ADDITIONAL REALITY CRACKS — 6 more crack capsules
	# ══════════════════════════════════════════════════════════════

	var extra_crack_data: Array = [
		[Vector3(0.1, 0.06, 0.05),    Vector3(0.6, -0.3, 0.9),   0.36],
		[Vector3(-0.09, 0.0, -0.08),  Vector3(-0.4, 0.7, -0.2),  0.40],
		[Vector3(0.05, -0.07, 0.1),   Vector3(1.0, 0.1, -0.5),   0.33],
		[Vector3(-0.07, 0.1, 0.06),   Vector3(-0.8, -0.5, 0.3),  0.38],
		[Vector3(0.02, -0.06, -0.12), Vector3(0.5, 0.9, 0.1),    0.42],
		[Vector3(-0.1, 0.04, 0.0),    Vector3(-0.1, -0.7, 0.8),  0.35],
	]
	for eci: int in range(extra_crack_data.size()):
		var ecd: Array = extra_crack_data[eci]
		var ec_pos: Vector3 = (ecd[0] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var ec_rot: Vector3 = ecd[1] as Vector3
		var ec_len: float = (ecd[2] as float) * s
		var ec_mat: StandardMaterial3D = mat_crack if eci % 2 == 0 else mat_crack_warm
		var extra_crack: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.012 * s, ec_len, ec_pos, ec_mat, ec_rot)
		extra_crack.name = "Crack%d" % (5 + eci)
		cracks.append(extra_crack)

	# ══════════════════════════════════════════════════════════════
	# ADDITIONAL DEBRIS — 6 more fragments on the fragment pivot
	# ══════════════════════════════════════════════════════════════

	var extra_frag_data: Array = [
		[0.62, 0.08,  0.52,  true,  0.045],
		[0.47, -0.18, 1.18,  false, 0.05],
		[0.54, 0.2,   2.0,   true,  0.04],
		[0.59, -0.1,  2.75,  false, 0.035],
		[0.51, 0.14,  4.2,   true,  0.05],
		[0.57, -0.06, 5.1,   false, 0.04],
	]
	for efi: int in range(extra_frag_data.size()):
		var efd: Array = extra_frag_data[efi]
		var e_orbit_r: float = (efd[0] as float) * s
		var e_h_off: float = (efd[1] as float) * s
		var e_angle: float = efd[2] as float
		var e_is_box: bool = efd[3] as bool
		var e_frag_size: float = (efd[4] as float) * s
		var e_frag_pos: Vector3 = Vector3(
			cos(e_angle) * e_orbit_r,
			e_h_off,
			sin(e_angle) * e_orbit_r)
		var e_frag_mat: StandardMaterial3D = mat_fragment if efi % 2 == 0 else mat_fragment_dark
		var e_frag_rot: Vector3 = Vector3(e_angle * 0.4, e_angle * 1.1, e_angle * 0.6)
		var extra_frag: MeshInstance3D
		if e_is_box:
			var e_box_size: Vector3 = Vector3(e_frag_size, e_frag_size * 1.3, e_frag_size * 0.8)
			extra_frag = EnemyMeshBuilder.add_box(
				frag_pivot, e_box_size, e_frag_pos, e_frag_mat, e_frag_rot)
		else:
			extra_frag = EnemyMeshBuilder.add_sphere(
				frag_pivot, e_frag_size, e_frag_pos, e_frag_mat,
				Vector3(1.0, 0.8, 1.2))
		extra_frag.name = "Fragment%d" % (8 + efi)
		fragments.append(extra_frag)

	# ══════════════════════════════════════════════════════════════
	# ADDITIONAL DISTORTION RINGS — 2 more torus rings
	# ══════════════════════════════════════════════════════════════

	var extra_ring_data: Array = [
		[Vector3(0.7, -0.5, 0.9),  0.045, 0.44],
		[Vector3(-0.9, 0.6, -0.3), 0.05,  0.40],
	]
	for eri: int in range(extra_ring_data.size()):
		var erd: Array = extra_ring_data[eri]
		var er_tilt: Vector3 = erd[0] as Vector3
		var er_inner: float = (erd[1] as float) * s
		var er_outer: float = (erd[2] as float) * s
		var extra_ring_pivot: Node3D = Node3D.new()
		extra_ring_pivot.name = "RingPivot%d" % (3 + eri)
		extra_ring_pivot.position = Vector3(0.0, body_y, 0.0)
		extra_ring_pivot.rotation = er_tilt
		root.add_child(extra_ring_pivot)
		var extra_ring: MeshInstance3D = EnemyMeshBuilder.add_torus(
			extra_ring_pivot, er_inner, er_outer,
			Vector3.ZERO, mat_ring)
		extra_ring.name = "Ring%d" % (3 + eri)
		ring_pivots.append(extra_ring_pivot)

	# ══════════════════════════════════════════════════════════════
	# GLITCH FRAGMENTS — flickering boxes floating around the body
	# ══════════════════════════════════════════════════════════════

	var glitch_positions: Array = [
		Vector3(0.3, 0.15, -0.1),
		Vector3(-0.28, -0.1, 0.22),
		Vector3(0.12, -0.2, -0.28),
		Vector3(-0.18, 0.25, 0.12),
	]
	var glitch_frags: Array[MeshInstance3D] = []
	for gi: int in range(glitch_positions.size()):
		var g_pos: Vector3 = (glitch_positions[gi] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var g_rot: Vector3 = Vector3(float(gi) * 0.7, float(gi) * 1.3, float(gi) * 0.4)
		var g_size: Vector3 = Vector3(0.03 * s, 0.03 * s, 0.03 * s)
		var glitch_frag: MeshInstance3D = EnemyMeshBuilder.add_box(
			root, g_size, g_pos, mat_glitch, g_rot)
		glitch_frag.name = "GlitchFrag%d" % gi
		glitch_frags.append(glitch_frag)

	# ══════════════════════════════════════════════════════════════
	# SHELL SURFACE RIDGES — thin capsules on the main shell
	# ══════════════════════════════════════════════════════════════

	var ridge_data: Array = [
		[Vector3(0.0, 0.15, -0.3),   Vector3(0.2, 0.0, 0.6)],
		[Vector3(0.28, 0.05, 0.12),  Vector3(-0.4, 0.7, 0.0)],
		[Vector3(-0.26, -0.08, 0.1), Vector3(0.5, -0.3, -0.5)],
		[Vector3(0.1, -0.14, -0.25), Vector3(-0.6, 0.4, 0.3)],
	]
	for rdi: int in range(ridge_data.size()):
		var rdd: Array = ridge_data[rdi]
		var rd_pos: Vector3 = (rdd[0] as Vector3) * s + Vector3(0.0, body_y, 0.0)
		var rd_rot: Vector3 = rdd[1] as Vector3
		var ridge: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.006 * s, 0.2 * s, rd_pos, mat_shell, rd_rot)
		ridge.name = "ShellRidge%d" % rdi

	# ── Store animatable parts ──
	root.set_meta("frag_pivot", frag_pivot)
	root.set_meta("fragments", fragments)
	root.set_meta("ring_pivots", ring_pivots)
	root.set_meta("cracks", cracks)
	root.set_meta("shell_main", shell_main)
	root.set_meta("core_glow", core_glow)
	root.set_meta("motes", motes)
	root.set_meta("outer_shell", outer_shell)
	root.set_meta("void_eye", void_eye)
	root.set_meta("tendrils", tendrils)
	root.set_meta("glitch_frags", glitch_frags)
	root.set_meta("body_y", body_y)
	root.set_meta("scale", s)

	return root


## Animate the reality warper each frame.
## Fragments orbit, rings spin, body pulses, cracks flicker.
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	var s: float = float(root.get_meta("scale", 1.0))

	# ── Hover bob — slow, eerie float ──
	var bob_speed: float = 1.5 if not is_moving else 2.8
	var bob_amount: float = 0.05 * s if not is_moving else 0.025 * s
	root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Fragment orbit — rotate the pivot so all fragments circle the body ──
	if root.has_meta("frag_pivot"):
		var frag_pivot: Node3D = root.get_meta("frag_pivot") as Node3D
		if frag_pivot != null:
			var orbit_speed: float = 0.4 if not is_moving else 0.8
			frag_pivot.rotation.y += orbit_speed * delta

	# ── Individual fragment tumble — each fragment rotates on its own axes ──
	if root.has_meta("fragments"):
		var fragments: Array = root.get_meta("fragments") as Array
		for i: int in range(fragments.size()):
			var frag: MeshInstance3D = fragments[i] as MeshInstance3D
			if frag == null:
				continue
			var tumble_speed: float = 1.5 + float(i) * 0.3
			frag.rotation.x += tumble_speed * delta * 0.5
			frag.rotation.z += tumble_speed * delta * 0.3

	# ── Distortion rings — each ring spins at its own rate/axis ──
	if root.has_meta("ring_pivots"):
		var ring_pivots: Array = root.get_meta("ring_pivots") as Array
		var ring_speeds: Array = [0.8, -0.6, 1.1, -0.9, 0.7]
		for i: int in range(ring_pivots.size()):
			var pivot: Node3D = ring_pivots[i] as Node3D
			if pivot == null:
				continue
			var spd: float = ring_speeds[i % ring_speeds.size()] as float
			if is_moving:
				spd *= 1.5
			# Spin around a different axis per ring for variety
			match i % 3:
				0:
					pivot.rotation.y += spd * delta
				1:
					pivot.rotation.x += spd * delta
				2:
					pivot.rotation.z += spd * delta

	# ── Body pulse — main shell breathes in and out ──
	if root.has_meta("shell_main"):
		var shell: MeshInstance3D = root.get_meta("shell_main") as MeshInstance3D
		if shell != null:
			var pulse: float = 1.0 + sin(phase * 2.0) * 0.04
			shell.scale = Vector3(pulse, pulse, pulse)

	# ── Core glow pulse — brighter, faster pulse than the shell ──
	if root.has_meta("core_glow"):
		var core: MeshInstance3D = root.get_meta("core_glow") as MeshInstance3D
		if core != null:
			var core_pulse: float = 1.0 + sin(phase * 3.5) * 0.12
			core.scale = Vector3(core_pulse, core_pulse, core_pulse)

	# ── Crack flicker — subtle scale oscillation to simulate light pulsing ──
	if root.has_meta("cracks"):
		var cracks: Array = root.get_meta("cracks") as Array
		for i: int in range(cracks.size()):
			var crack: MeshInstance3D = cracks[i] as MeshInstance3D
			if crack == null:
				continue
			# Each crack flickers at a unique frequency
			var flicker_freq: float = 4.0 + float(i) * 1.7
			var flicker: float = 1.0 + sin(phase * flicker_freq) * 0.15
			# Scale the radius (x and z) but keep length (y) stable
			crack.scale = Vector3(flicker, 1.0, flicker)

	# ── Energy motes — gentle drift and scale pulse ──
	if root.has_meta("motes"):
		var motes: Array = root.get_meta("motes") as Array
		for i: int in range(motes.size()):
			var mote: MeshInstance3D = motes[i] as MeshInstance3D
			if mote == null:
				continue
			# Each mote pulses at a different rate and drifts slightly
			var mote_phase: float = phase * 2.5 + float(i) * 1.05
			var mote_pulse: float = 1.0 + sin(mote_phase) * 0.4
			mote.scale = Vector3(mote_pulse, mote_pulse, mote_pulse)
			# Subtle positional drift
			mote.position.y += sin(mote_phase * 0.7) * delta * 0.01

	# ── Void eye iris — steady rotation ──
	if root.has_meta("void_eye"):
		var void_eye: Array = root.get_meta("void_eye") as Array
		for i: int in range(void_eye.size()):
			var eye_part: MeshInstance3D = void_eye[i] as MeshInstance3D
			if eye_part == null:
				continue
			eye_part.rotation.z = phase * 2.0

	# ── Reality tendrils — wave motion ──
	if root.has_meta("tendrils"):
		var tendrils: Array = root.get_meta("tendrils") as Array
		for i: int in range(tendrils.size()):
			var tendril: MeshInstance3D = tendrils[i] as MeshInstance3D
			if tendril == null:
				continue
			tendril.rotation.x = sin(phase * 1.5 + float(i) * 1.0) * 0.3

	# ── Glitch fragments — visibility flicker via scale ──
	if root.has_meta("glitch_frags"):
		var glitch_frags: Array = root.get_meta("glitch_frags") as Array
		for i: int in range(glitch_frags.size()):
			var gf: MeshInstance3D = glitch_frags[i] as MeshInstance3D
			if gf == null:
				continue
			if sin(phase * 8.0 + float(i) * 2.0) > 0.3:
				gf.scale = Vector3.ZERO
			else:
				gf.scale = Vector3(1.0, 1.0, 1.0)
