## SlugMesh — Large alien slug
##
## A bulky, glistening slug with a 3-segment body (mantle, mid, tail), a pointed
## tail tip, mantle shield, dorsal stripe, skin warts, optical and sensory
## tentacles, mouth torus, mucus trail, flat foot, skin ridges, lateral color
## bands, pneumostome breathing pore, foot sole texture, mucus droplets, mantle
## edge detail, and eye stalk joint bulges.
## Animate: gentle bobbing, tentacle sway, body compression wave, pneumostome pulse.
class_name SlugMesh
extends EnemyMeshBuilder

# ──────────────────────────────────────────────
# Build
# ──────────────────────────────────────────────
func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x667744))
	var sc: float = params.get("scale", 1.0)
	root.scale = Vector3(sc, sc, sc)

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(base_color, 0.1, 0.75)
	var mat_mantle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.06), 0.15, 0.65)
	var mat_belly: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.15), 0.05, 0.8)
	var mat_stripe: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.18), 0.2, 0.6)
	var mat_wart: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.08), 0.15, 0.7)
	var mat_mantle_plate: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.12), 0.3, 0.5)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.9, 0.3, 0.6), 0.0, 0.3,
		Color(0.95, 0.25, 0.65), 2.2)
	var mat_tentacle: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.08), 0.05, 0.75)
	var mat_mouth: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(0.35, 0.15, 0.15), 0.1, 0.7)
	var mat_mucus: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.25), 0.0, 0.9,
		Color.BLACK, 0.0, true, 0.2)
	var mat_ridge: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.04), 0.1, 0.7)
	var mat_tail_tip: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.1), 0.15, 0.65)

	# New detail materials
	var mat_lateral_band: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.15), 0.12, 0.65)
	var mat_pneumostome: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.darken(base_color, 0.2), 0.1, 0.7,
		EnemyMeshBuilder.darken(base_color, 0.1), 0.5)
	var mat_sensory_pad: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.1), 0.0, 0.85,
		EnemyMeshBuilder.lighten(base_color, 0.12), 0.3)
	var mat_mucus_bright: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.3), 0.0, 0.9,
		Color.BLACK, 0.0, true, 0.35)

	# ── Body segments — 3 large flattened spheres ──

	# Front mantle segment
	var mantle: Node3D = Node3D.new()
	mantle.position = Vector3(0.3, 0.3, 0.0)
	root.add_child(mantle)

	EnemyMeshBuilder.add_sphere(mantle, 0.3, Vector3.ZERO, mat_mantle,
		Vector3(1.1, 0.65, 1.0))

	# Mid segment
	var mid: Node3D = Node3D.new()
	mid.position = Vector3(-0.1, 0.28, 0.0)
	root.add_child(mid)

	EnemyMeshBuilder.add_sphere(mid, 0.28, Vector3.ZERO, mat_body,
		Vector3(1.15, 0.6, 0.95))

	# Tail segment
	var tail: Node3D = Node3D.new()
	tail.position = Vector3(-0.48, 0.25, 0.0)
	root.add_child(tail)

	EnemyMeshBuilder.add_sphere(tail, 0.22, Vector3.ZERO, mat_body,
		Vector3(1.2, 0.55, 0.85))

	# ── Pointed tail tip (cone) ──
	EnemyMeshBuilder.add_cone(tail, 0.07, 0.2, Vector3(-0.22, -0.02, 0.0),
		mat_tail_tip, Vector3(0.0, 0.0, PI * 0.5))

	# ── Foot — flat underside sphere ──
	EnemyMeshBuilder.add_sphere(root, 0.25, Vector3(-0.05, 0.06, 0.0), mat_belly,
		Vector3(2.8, 0.2, 0.85))

	# ── Foot sole texture — muscular ripple capsules ──
	for i: int in range(6):
		var fx: float = 0.3 - i * 0.14
		EnemyMeshBuilder.add_capsule(root, 0.008, 0.12,
			Vector3(fx, 0.03, 0.0), mat_sensory_pad,
			Vector3(0.0, 0.0, 0.0))

	# ── Mantle shield — dorsal plate on front segment ──
	EnemyMeshBuilder.add_sphere(mantle, 0.22, Vector3(0.02, 0.12, 0.0), mat_mantle_plate,
		Vector3(1.3, 0.35, 1.15))

	# ── Mantle edge detail — torus ring + ridge capsules ──
	EnemyMeshBuilder.add_torus(mantle, 0.01, 0.28, Vector3(0.0, 0.0, 0.0),
		mat_mantle_plate, Vector3(0.0, 0.0, PI * 0.5))
	for i: int in range(3):
		var angle: float = -0.4 + i * 0.4
		EnemyMeshBuilder.add_capsule(mantle, 0.008, 0.08,
			Vector3(cos(angle) * 0.25, 0.08, sin(angle) * 0.22), mat_ridge,
			Vector3(0.0, angle, 0.0))

	# ── Dorsal stripe — dark ridge line head to tail ──
	for i: int in range(6):
		var sx: float = 0.5 - i * 0.22
		var sy: float = 0.42 - abs(i - 2.5) * 0.02
		EnemyMeshBuilder.add_sphere(root, 0.025, Vector3(sx, sy, 0.0), mat_stripe,
			Vector3(1.5, 0.8, 0.4))

	# ── Lateral color bands — capsules along each body side ──
	for side: int in [-1, 1]:
		EnemyMeshBuilder.add_capsule(root, 0.01, 0.18,
			Vector3(0.3, 0.22, side * 0.2), mat_lateral_band,
			Vector3(0.0, 0.0, PI * 0.5))
		EnemyMeshBuilder.add_capsule(root, 0.01, 0.2,
			Vector3(-0.1, 0.2, side * 0.18), mat_lateral_band,
			Vector3(0.0, 0.0, PI * 0.5))
		EnemyMeshBuilder.add_capsule(root, 0.01, 0.15,
			Vector3(-0.48, 0.18, side * 0.13), mat_lateral_band,
			Vector3(0.0, 0.0, PI * 0.5))

	# ── Skin warts / bumps (scattered spheres) ──
	var wart_positions: Array = [
		Vector3(0.2, 0.38, 0.18), Vector3(0.35, 0.35, -0.14),
		Vector3(-0.05, 0.36, 0.2), Vector3(-0.15, 0.33, -0.17),
		Vector3(-0.38, 0.3, 0.12), Vector3(-0.42, 0.28, -0.1),
		Vector3(0.12, 0.37, -0.22), Vector3(-0.25, 0.32, 0.16),
		# Additional warts for detail
		Vector3(0.4, 0.32, 0.08), Vector3(0.28, 0.37, 0.12),
		Vector3(-0.02, 0.35, -0.22), Vector3(-0.3, 0.31, -0.14),
		Vector3(-0.5, 0.27, 0.08), Vector3(0.18, 0.36, 0.22),
		Vector3(-0.35, 0.3, -0.16), Vector3(-0.55, 0.25, -0.06),
	]
	for wp: int in range(wart_positions.size()):
		var wart_size: float = 0.02 + fmod(float(wp) * 0.37, 0.015)
		EnemyMeshBuilder.add_sphere(root, wart_size, wart_positions[wp], mat_wart)

	# ── Pneumostome (breathing pore) on right side of mantle ──
	var pneumostome: MeshInstance3D = EnemyMeshBuilder.add_torus(
		mantle, 0.008, 0.03, Vector3(0.08, 0.06, 0.25),
		mat_pneumostome, Vector3(0.0, 0.0, 0.3))
	EnemyMeshBuilder.add_sphere(mantle, 0.012,
		Vector3(0.08, 0.06, 0.25), mat_pneumostome)

	# ── Optical tentacles (2 upper eye stalks) ──
	var upper_tentacles: Array = []

	for side: int in [-1, 1]:
		var tentacle: Node3D = Node3D.new()
		tentacle.position = Vector3(0.42, 0.42, side * 0.1)
		root.add_child(tentacle)
		upper_tentacles.append(tentacle)

		# Stalk
		EnemyMeshBuilder.add_capsule(tentacle, 0.02, 0.2,
			Vector3(0.0, 0.12, 0.0), mat_tentacle,
			Vector3(0.0, 0.0, side * -0.2))

		# Eye stalk joint bulges
		EnemyMeshBuilder.add_sphere(tentacle, 0.025,
			Vector3(0.0, 0.02, 0.0), mat_tentacle)
		EnemyMeshBuilder.add_sphere(tentacle, 0.018,
			Vector3(side * -0.01, 0.18, 0.0), mat_tentacle)

		# Eye at tip — pink/magenta emissive
		EnemyMeshBuilder.add_sphere(tentacle, 0.035, Vector3(side * -0.04, 0.26, 0.0), mat_eye)

	# ── Sensory tentacles (2 lower, shorter) ──
	var lower_tentacles: Array = []

	for side: int in [-1, 1]:
		var tentacle: Node3D = Node3D.new()
		tentacle.position = Vector3(0.48, 0.26, side * 0.08)
		root.add_child(tentacle)
		lower_tentacles.append(tentacle)

		# Shorter stalk, angled forward and outward
		EnemyMeshBuilder.add_capsule(tentacle, 0.015, 0.12,
			Vector3(0.04, 0.04, side * 0.02), mat_tentacle,
			Vector3(0.0, 0.0, side * -0.5 + 0.4))

	# ── Mouth — torus ring at front ──
	EnemyMeshBuilder.add_torus(root, 0.02, 0.06, Vector3(0.55, 0.22, 0.0),
		mat_mouth, Vector3(0.0, 0.0, PI * 0.5))

	# ── Mucus trail — faint transparent capsule behind ──
	EnemyMeshBuilder.add_capsule(root, 0.12, 0.6,
		Vector3(-0.85, 0.04, 0.0), mat_mucus,
		Vector3(0.0, 0.0, PI * 0.5))

	# ── Mucus droplets — transparent spheres at body edges ──
	var droplet_positions: Array = [
		Vector3(0.15, 0.08, 0.22), Vector3(-0.1, 0.07, -0.2),
		Vector3(-0.35, 0.06, 0.15), Vector3(-0.55, 0.05, -0.1),
		Vector3(0.3, 0.08, -0.18),
	]
	for dp: int in range(droplet_positions.size()):
		EnemyMeshBuilder.add_sphere(root, 0.01 + fmod(float(dp) * 0.23, 0.008),
			droplet_positions[dp], mat_mucus_bright)

	# ── Skin ridges — several torus rings along body ──
	var ridge_positions: Array = [
		Vector3(0.2, 0.28, 0.0),
		Vector3(0.05, 0.27, 0.0),
		Vector3(-0.05, 0.26, 0.0),
		Vector3(-0.2, 0.25, 0.0),
		Vector3(-0.28, 0.24, 0.0),
		Vector3(-0.38, 0.23, 0.0),
		Vector3(-0.48, 0.22, 0.0),
		Vector3(-0.56, 0.21, 0.0),
	]
	for rp: int in range(ridge_positions.size()):
		var ridge_outer: float = 0.26 - rp * 0.02
		EnemyMeshBuilder.add_torus(root, 0.01, ridge_outer,
			ridge_positions[rp], mat_ridge,
			Vector3(0.0, 0.0, PI * 0.5))

	# ── Store animatable references ──
	root.set_meta("mantle", [mantle])
	root.set_meta("mid", [mid])
	root.set_meta("tail", [tail])
	root.set_meta("upper_tentacles", upper_tentacles)
	root.set_meta("lower_tentacles", lower_tentacles)
	root.set_meta("pneumostome", [pneumostome])

	# Built facing +X, rotate to face -Z (Godot forward)
	root.rotation.y = PI / 2.0
	return root


# ──────────────────────────────────────────────
# Animate
# ──────────────────────────────────────────────
func animate(root: Node3D, phase: float, is_moving: bool, _delta: float) -> void:
	var mantles: Array = root.get_meta("mantle", [])
	var mids: Array = root.get_meta("mid", [])
	var tails: Array = root.get_meta("tail", [])
	var upper_t: Array = root.get_meta("upper_tentacles", [])
	var lower_t: Array = root.get_meta("lower_tentacles", [])

	# ── Body compression wave ──
	# A slow peristaltic wave travels front-to-back
	var wave_speed: float = 3.0 if is_moving else 1.2
	var compress_amp: float = 0.03 if is_moving else 0.015

	if mantles.size() > 0:
		var mantle_node: Node3D = mantles[0] as Node3D
		var m_phase: float = sin(phase * wave_speed)
		# Mantle bobs up/down and compresses slightly
		mantle_node.position.y = 0.3 + m_phase * compress_amp
		mantle_node.scale.y = 1.0 - m_phase * 0.04

	if mids.size() > 0:
		var mid_node: Node3D = mids[0] as Node3D
		var mid_phase: float = sin(phase * wave_speed - 0.8)
		mid_node.position.y = 0.28 + mid_phase * compress_amp
		mid_node.scale.y = 1.0 - mid_phase * 0.04

	if tails.size() > 0:
		var tail_node: Node3D = tails[0] as Node3D
		var tail_phase: float = sin(phase * wave_speed - 1.6)
		tail_node.position.y = 0.25 + tail_phase * compress_amp
		tail_node.scale.y = 1.0 - tail_phase * 0.04

	# ── Upper tentacle sway (eye stalks) ──
	for i: int in range(upper_t.size()):
		var tent_node: Node3D = upper_t[i] as Node3D
		var side_sign: float = -1.0 if i == 0 else 1.0
		# Gentle independent sway
		tent_node.rotation.z = sin(phase * 1.5 + i * 1.2) * 0.15 * side_sign
		tent_node.rotation.x = sin(phase * 1.1 + i * 0.9) * 0.1
		if is_moving:
			# When moving, tentacles lean forward slightly
			tent_node.rotation.x += 0.12

	# ── Lower tentacle sway (sensory) ──
	for i: int in range(lower_t.size()):
		var tent_node: Node3D = lower_t[i] as Node3D
		var side_sign: float = -1.0 if i == 0 else 1.0
		# Faster, more erratic probing motion
		tent_node.rotation.z = sin(phase * 2.2 + i * 1.8 + 0.5) * 0.2 * side_sign
		tent_node.rotation.x = sin(phase * 1.8 + i * 1.4) * 0.15

	# ── Pneumostome breathing pulse ──
	var pneumostomes: Array = root.get_meta("pneumostome", [])
	if pneumostomes.size() > 0:
		var pore: MeshInstance3D = pneumostomes[0] as MeshInstance3D
		var breath: float = 0.8 + sin(phase * 1.5) * 0.2
		pore.scale = Vector3(breath, breath, breath)

	# ── Gentle overall bob (idle emphasis) ──
	if not is_moving:
		root.position.y = sin(phase * 0.7) * 0.01
