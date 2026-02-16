## DarkEntityMesh -- Shadowy amorphous entity enemy mesh
##
## A menacing dark mass with shadow tendrils, a glowing inner core,
## orbiting shadow particles, piercing eyes, shadow puddle below,
## and a wispy aura envelope. Tendrils wave, particles orbit, body pulses.
## Surface veins, shadow spikes, extra eyes, ground corruption, energy arcs,
## and aura ripple rings add menacing detail.
## ~64 mesh nodes.
class_name DarkEntityMesh
extends EnemyMeshBuilder


func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: float = params.get("scale", 1.0) as float
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x2A0845) as int)

	# ── Materials ──

	# Outer body -- very dark, slight purple emission
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.20), 0.2, 0.7,
		base_color, 0.6,
		true, 0.7)

	# Inner core -- bright emissive, visible through outer shell
	var mat_core: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.30), 0.5, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.40), 4.0)

	# Tendrils -- dark with subtle glow
	var mat_tendril: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.1, 0.8,
		base_color, 0.4,
		true, 0.6)

	# Orbiting particles -- very dark shadow cubes
	var mat_particle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.25), 0.3, 0.9,
		base_color, 0.3)

	# Eyes -- bright red/purple emissive
	var eye_color: Color = Color(0.9, 0.1, 0.3)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		eye_color, 0.5, 0.2,
		eye_color, 5.0)

	# Shadow puddle -- flat dark disc
	var mat_shadow: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.02, 0.01, 0.04), 0.0, 1.0,
		Color.BLACK, 0.0,
		true, 0.5)

	# Wispy aura -- very transparent, faint glow
	var mat_aura: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.0, 0.3,
		base_color, 0.5,
		true, 0.1)

	# Surface veins -- dark red-purple, emissive, transparent
	var mat_vein: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.5, 0.1, 0.2), 0.1, 0.5,
		Color(0.5, 0.1, 0.2), 1.2,
		true, 0.6)

	# Ground corruption -- very dark near-black
	var mat_corruption: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.05, 0.02, 0.06), 0.0, 0.95)

	# Inner energy arcs -- bright emissive matching core
	var mat_arc: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.30), 0.5, 0.3,
		EnemyMeshBuilder.lighten(base_color, 0.40), 3.0)

	# Aura ripple rings -- semi-transparent, faint emission
	var mat_ripple: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		base_color, 0.0, 0.3,
		base_color, 0.6,
		true, 0.15)

	# ── Body center height ──
	var body_y: float = 0.75 * s

	# ── Main body (large dark sphere) ──
	var body: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.40 * s,
		Vector3(0.0, body_y, 0.0),
		mat_body,
		Vector3(1.0, 0.9, 1.0))

	# ── Inner core (smaller bright sphere) ──
	var core: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.15 * s,
		Vector3(0.0, body_y, 0.0),
		mat_core)

	# ── Eyes (1-2 bright emissive spheres on front) ──
	var eye_l: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.04 * s,
		Vector3(0.10 * s, body_y + 0.06 * s, 0.34 * s),
		mat_eye)
	var eye_r: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.035 * s,
		Vector3(-0.08 * s, body_y + 0.03 * s, 0.35 * s),
		mat_eye)

	# ── Secondary body shell (slightly larger, very transparent layer) ──
	var body_shell: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.44 * s,
		Vector3(0.0, body_y + 0.02 * s, 0.0),
		mat_tendril,
		Vector3(1.05, 0.95, 1.05))

	# ── Surface veins/cracks (8 thin emissive capsules on body surface) ──
	var vein_data: Array[Array] = [
		[Vector3(0.18 * s, body_y + 0.15 * s, 0.30 * s), Vector3(0.5, 0.2, 0.0)],
		[Vector3(-0.20 * s, body_y + 0.10 * s, 0.28 * s), Vector3(-0.3, 0.8, 0.1)],
		[Vector3(0.30 * s, body_y - 0.05 * s, 0.18 * s), Vector3(0.1, -0.4, 0.6)],
		[Vector3(-0.28 * s, body_y - 0.10 * s, 0.20 * s), Vector3(0.7, 1.2, -0.2)],
		[Vector3(0.10 * s, body_y + 0.22 * s, -0.28 * s), Vector3(-0.6, 0.3, 0.4)],
		[Vector3(-0.15 * s, body_y + 0.18 * s, -0.25 * s), Vector3(0.4, -0.7, 0.2)],
		[Vector3(0.25 * s, body_y - 0.15 * s, -0.22 * s), Vector3(-0.2, 1.0, -0.5)],
		[Vector3(-0.10 * s, body_y + 0.25 * s, 0.10 * s), Vector3(0.8, 0.5, 0.3)],
	]
	for vd: Array in vein_data:
		var vpos: Vector3 = vd[0] as Vector3
		var vrot: Vector3 = vd[1] as Vector3
		EnemyMeshBuilder.add_capsule(
			root, 0.006 * s, 0.15 * s,
			vpos,
			mat_vein,
			vrot)

	# ── Shadow spikes (6 cones pointing outward from body) ──
	var shadow_spikes: Array[MeshInstance3D] = []
	var spike_data: Array[Array] = [
		[Vector3(0.32 * s, body_y + 0.08 * s, 0.20 * s), Vector3(0.3, 0.0, -0.5)],
		[Vector3(-0.30 * s, body_y + 0.05 * s, 0.22 * s), Vector3(0.2, PI, 0.6)],
		[Vector3(0.20 * s, body_y - 0.12 * s, 0.30 * s), Vector3(0.7, 0.5, 0.0)],
		[Vector3(-0.22 * s, body_y - 0.08 * s, -0.28 * s), Vector3(-0.4, -0.6, 0.3)],
		[Vector3(0.28 * s, body_y + 0.15 * s, -0.18 * s), Vector3(-0.2, 1.0, -0.4)],
		[Vector3(-0.10 * s, body_y + 0.20 * s, -0.32 * s), Vector3(0.5, -1.2, 0.2)],
	]
	for sd: Array in spike_data:
		var spos: Vector3 = sd[0] as Vector3
		var srot: Vector3 = sd[1] as Vector3
		var spike: MeshInstance3D = EnemyMeshBuilder.add_cone(
			root, 0.025 * s, 0.12 * s,
			spos,
			mat_tendril,
			srot)
		shadow_spikes.append(spike)

	# ── Additional eyes (4 smaller emissive eye spheres) ──
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(0.16 * s, body_y + 0.12 * s, 0.32 * s),
		mat_eye)
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(-0.14 * s, body_y + 0.10 * s, 0.33 * s),
		mat_eye)
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(0.05 * s, body_y - 0.04 * s, 0.36 * s),
		mat_eye)
	EnemyMeshBuilder.add_sphere(
		root, 0.025 * s,
		Vector3(-0.04 * s, body_y + 0.16 * s, 0.30 * s),
		mat_eye)

	# ── Shadow tendrils (6 capsules radiating outward) ──
	var tendrils: Array[MeshInstance3D] = []
	var tendril_count: int = 6
	for i: int in range(tendril_count):
		var angle: float = (float(i) / float(tendril_count)) * TAU + 0.3
		var tx: float = cos(angle) * 0.30 * s
		var tz: float = sin(angle) * 0.30 * s
		# Tendrils point outward and slightly downward
		var rot_y: float = -angle + PI * 0.5
		var rot_x: float = 0.4 + float(i % 2) * 0.2
		var length: float = (0.35 + float(i % 3) * 0.08) * s
		var tendril: MeshInstance3D = EnemyMeshBuilder.add_capsule(
			root, 0.035 * s, length,
			Vector3(tx, body_y - 0.10 * s, tz),
			mat_tendril,
			Vector3(rot_x, rot_y, 0.0))
		tendrils.append(tendril)

	# ── Tendril tips (small spheres at the end of each tendril) ──
	for i: int in range(tendril_count):
		var angle: float = (float(i) / float(tendril_count)) * TAU + 0.3
		var tip_dist: float = (0.55 + float(i % 3) * 0.06) * s
		var tip_x: float = cos(angle) * tip_dist
		var tip_z: float = sin(angle) * tip_dist
		var tip_y: float = body_y - 0.35 * s - float(i % 2) * 0.08 * s
		var tip: MeshInstance3D = EnemyMeshBuilder.add_sphere(
			root, 0.025 * s,
			Vector3(tip_x, tip_y, tip_z),
			mat_tendril)
		tendrils.append(tip)

	# ── Orbiting shadow particles (5 small dark cubes) ──
	var particles: Array[MeshInstance3D] = []
	var particle_count: int = 5
	for i: int in range(particle_count):
		var angle: float = (float(i) / float(particle_count)) * TAU
		var orbit_r: float = 0.55 * s
		var px: float = cos(angle) * orbit_r
		var pz: float = sin(angle) * orbit_r
		var py: float = body_y + sin(angle * 2.0) * 0.10 * s
		var cube_size: float = (0.04 + float(i % 2) * 0.02) * s
		var particle: MeshInstance3D = EnemyMeshBuilder.add_box(
			root, Vector3(cube_size, cube_size, cube_size),
			Vector3(px, py, pz),
			mat_particle,
			Vector3(angle * 0.5, angle, 0.3))
		particles.append(particle)

	# ── Additional orbiting particles (3 more cubes) ──
	var extra_particle_angles: Array[float] = [TAU * 0.1, TAU * 0.37, TAU * 0.63]
	for i: int in range(extra_particle_angles.size()):
		var angle: float = extra_particle_angles[i]
		var orbit_r: float = 0.55 * s
		var px: float = cos(angle) * orbit_r
		var pz: float = sin(angle) * orbit_r
		var py: float = body_y + sin(angle * 2.0) * 0.10 * s
		var cube_size: float = (0.035 + float(i % 2) * 0.015) * s
		var extra_p: MeshInstance3D = EnemyMeshBuilder.add_box(
			root, Vector3(cube_size, cube_size, cube_size),
			Vector3(px, py, pz),
			mat_particle,
			Vector3(angle * 0.5, angle, 0.3))
		particles.append(extra_p)
	particle_count = 8

	# ── Shadow puddle (flat cylinder under body) ──
	var puddle: MeshInstance3D = EnemyMeshBuilder.add_cylinder(
		root, 0.50 * s, 0.55 * s, 0.02 * s,
		Vector3(0.0, 0.01 * s, 0.0),
		mat_shadow)

	# ── Ground corruption (6 crack capsules radiating from puddle) ──
	var corruption_angles: Array[float] = [0.0, 1.05, 2.1, 3.14, 4.19, 5.24]
	for i: int in range(corruption_angles.size()):
		var ca: float = corruption_angles[i]
		var cx: float = cos(ca) * 0.35 * s
		var cz: float = sin(ca) * 0.35 * s
		EnemyMeshBuilder.add_capsule(
			root, 0.008 * s, 0.2 * s,
			Vector3(cx, 0.02 * s, cz),
			mat_corruption,
			Vector3(PI * 0.5, ca, 0.0))

	# ── Inner energy arcs (4 capsules between core and shell) ──
	var arc_data: Array[Array] = [
		[Vector3(0.08 * s, body_y + 0.10 * s, 0.06 * s), Vector3(0.4, 0.2, 0.8)],
		[Vector3(-0.06 * s, body_y + 0.05 * s, -0.08 * s), Vector3(-0.3, 1.0, -0.5)],
		[Vector3(0.05 * s, body_y - 0.08 * s, -0.07 * s), Vector3(0.7, -0.4, 0.3)],
		[Vector3(-0.07 * s, body_y - 0.05 * s, 0.09 * s), Vector3(-0.6, 0.8, -0.2)],
	]
	for ad: Array in arc_data:
		var apos: Vector3 = ad[0] as Vector3
		var arot: Vector3 = ad[1] as Vector3
		EnemyMeshBuilder.add_capsule(
			root, 0.005 * s, 0.18 * s,
			apos,
			mat_arc,
			arot)

	# ── Wispy aura (large transparent sphere around everything) ──
	var aura: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.60 * s,
		Vector3(0.0, body_y, 0.0),
		mat_aura,
		Vector3(1.1, 1.0, 1.1))

	# ── Dark motes rising upward (small shadow spheres above body) ──
	var motes: Array[MeshInstance3D] = []
	var mote1: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.02 * s,
		Vector3(0.15 * s, body_y + 0.45 * s, 0.10 * s),
		mat_particle)
	motes.append(mote1)
	var mote2: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.018 * s,
		Vector3(-0.12 * s, body_y + 0.50 * s, -0.08 * s),
		mat_particle)
	motes.append(mote2)
	var mote3: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.015 * s,
		Vector3(0.05 * s, body_y + 0.55 * s, 0.12 * s),
		mat_particle)
	motes.append(mote3)

	# ── Additional dark motes (4 more shadow spheres above body) ──
	var mote4: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.016 * s,
		Vector3(-0.18 * s, body_y + 0.42 * s, 0.05 * s),
		mat_particle)
	motes.append(mote4)
	var mote5: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.014 * s,
		Vector3(0.08 * s, body_y + 0.60 * s, -0.10 * s),
		mat_particle)
	motes.append(mote5)
	var mote6: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.017 * s,
		Vector3(-0.06 * s, body_y + 0.48 * s, 0.15 * s),
		mat_particle)
	motes.append(mote6)
	var mote7: MeshInstance3D = EnemyMeshBuilder.add_sphere(
		root, 0.013 * s,
		Vector3(0.12 * s, body_y + 0.52 * s, -0.06 * s),
		mat_particle)
	motes.append(mote7)

	# ── Aura ripple rings (2 torus rings around body) ──
	var aura_rings: Array[MeshInstance3D] = []
	var ring1: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.01 * s, 0.45 * s,
		Vector3(0.0, body_y + 0.1 * s, 0.0),
		mat_ripple)
	aura_rings.append(ring1)
	var ring2: MeshInstance3D = EnemyMeshBuilder.add_torus(
		root, 0.01 * s, 0.45 * s,
		Vector3(0.0, body_y - 0.1 * s, 0.0),
		mat_ripple)
	aura_rings.append(ring2)

	# ── Store animatable parts ──
	root.set_meta("body", [body, body_shell])
	root.set_meta("core", [core])
	root.set_meta("eyes", [eye_l, eye_r])
	root.set_meta("motes", motes)
	root.set_meta("tendrils", tendrils)
	root.set_meta("particles", particles)
	root.set_meta("aura", [aura])
	root.set_meta("particle_count", particle_count)
	root.set_meta("orbit_radius", 0.55 * s)
	root.set_meta("body_y", body_y)
	root.set_meta("shadow_spikes", shadow_spikes)
	root.set_meta("aura_rings", aura_rings)

	# Built facing +Z, rotate to face -Z (Godot forward)
	root.rotation.y = PI
	return root


func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Gentle body bob / pulse ──
	var bob_speed: float = 2.5 if not is_moving else 3.5
	var bob_amount: float = 0.04 if not is_moving else 0.02
	root.position.y = sin(phase * bob_speed) * bob_amount

	# ── Body scale pulse (breathing effect) ──
	if root.has_meta("body"):
		var body_arr: Array = root.get_meta("body") as Array
		if body_arr.size() >= 1:
			var body: MeshInstance3D = body_arr[0] as MeshInstance3D
			var pulse: float = 1.0 + sin(phase * 2.0) * 0.04
			body.scale = Vector3(pulse, pulse * 0.95, pulse)

	# ── Core glow pulse (opposite phase for contrast) ──
	if root.has_meta("core"):
		var core_arr: Array = root.get_meta("core") as Array
		if core_arr.size() >= 1:
			var core: MeshInstance3D = core_arr[0] as MeshInstance3D
			var core_pulse: float = 1.0 + sin(phase * 3.0 + PI) * 0.08
			core.scale = Vector3(core_pulse, core_pulse, core_pulse)

	# ── Tendril wave -- slow sinusoidal sway ──
	if root.has_meta("tendrils"):
		var tendrils: Array = root.get_meta("tendrils") as Array
		for i: int in range(tendrils.size()):
			var tendril: MeshInstance3D = tendrils[i] as MeshInstance3D
			var t_phase: float = phase * 1.5 + float(i) * 1.1
			tendril.rotation.x += sin(t_phase) * 0.005
			tendril.rotation.z = sin(t_phase * 0.8 + 0.5) * 0.12

	# ── Orbiting particles -- rotate around body ──
	if root.has_meta("particles") and root.has_meta("particle_count"):
		var particles: Array = root.get_meta("particles") as Array
		var p_count: int = root.get_meta("particle_count") as int
		var orbit_r: float = root.get_meta("orbit_radius") as float
		var body_y: float = root.get_meta("body_y") as float
		var orbit_speed: float = 0.6 if not is_moving else 1.0
		for i: int in range(particles.size()):
			var particle: MeshInstance3D = particles[i] as MeshInstance3D
			var base_angle: float = (float(i) / float(p_count)) * TAU
			var current_angle: float = base_angle + phase * orbit_speed
			particle.position.x = cos(current_angle) * orbit_r
			particle.position.z = sin(current_angle) * orbit_r
			particle.position.y = body_y + sin(current_angle * 2.0 + phase) * 0.10
			# Spin the cubes themselves
			particle.rotation.x = phase * 1.5 + float(i)
			particle.rotation.y = phase * 2.0 + float(i) * 0.7

	# ── Aura subtle scale pulse ──
	if root.has_meta("aura"):
		var aura_arr: Array = root.get_meta("aura") as Array
		if aura_arr.size() >= 1:
			var aura: MeshInstance3D = aura_arr[0] as MeshInstance3D
			var aura_pulse: float = 1.0 + sin(phase * 1.5) * 0.03
			aura.scale = Vector3(aura_pulse * 1.1, aura_pulse, aura_pulse * 1.1)

	# ── Dark motes -- slowly drift upward and reset ──
	if root.has_meta("motes"):
		var motes: Array = root.get_meta("motes") as Array
		for i: int in range(motes.size()):
			var mote: MeshInstance3D = motes[i] as MeshInstance3D
			var mote_phase: float = phase * 0.8 + float(i) * 2.2
			mote.position.y += sin(mote_phase) * 0.002
			mote.position.x += cos(mote_phase * 1.3) * 0.001

	# ── Shadow spikes -- growth/shrink pulse ──
	if root.has_meta("shadow_spikes"):
		var spikes: Array = root.get_meta("shadow_spikes") as Array
		for i: int in range(spikes.size()):
			var spike: MeshInstance3D = spikes[i] as MeshInstance3D
			var spike_scale: float = 1.0 + sin(phase * 2.5 + float(i) * 1.0) * 0.3
			spike.scale = Vector3(spike_scale, spike_scale, spike_scale)

	# ── Aura ripple rings -- slow rotation and scale pulse ──
	if root.has_meta("aura_rings"):
		var rings: Array = root.get_meta("aura_rings") as Array
		for i: int in range(rings.size()):
			var ring: MeshInstance3D = rings[i] as MeshInstance3D
			ring.rotation.y = phase * 0.5 + float(i) * PI
			var ring_pulse: float = 1.0 + sin(phase * 1.8 + float(i) * 1.5) * 0.05
			ring.scale = Vector3(ring_pulse, ring_pulse, ring_pulse)
