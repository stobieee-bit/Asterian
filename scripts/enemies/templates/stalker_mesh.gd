## StalkerMesh — Panther-like quadruped predator
##
## A sleek, low-slung stalking beast with an elongated torso, articulated legs,
## spine ridges, wedge-shaped head with fangs, whiskers, pointed ears, and a
## segmented tail. Animate: prowling walk cycle, tail sway, head bob.
class_name StalkerMesh
extends EnemyMeshBuilder

# ──────────────────────────────────────────────
# Build
# ──────────────────────────────────────────────
func build_mesh(params: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var base_color: Color = EnemyMeshBuilder.int_to_color(params.get("color", 0x443322))
	var sc: float = params.get("scale", 1.0)
	root.scale = Vector3(sc, sc, sc)

	# ── Materials ──
	var mat_body: StandardMaterial3D = EnemyMeshBuilder.mat_sci(base_color, 0.25, 0.55)
	var mat_dark: StandardMaterial3D = EnemyMeshBuilder.mat_sci(EnemyMeshBuilder.darken(base_color, 0.1), 0.3, 0.5)
	var mat_belly: StandardMaterial3D = EnemyMeshBuilder.mat_sci(EnemyMeshBuilder.lighten(base_color, 0.12), 0.15, 0.6)
	var mat_ridge: StandardMaterial3D = EnemyMeshBuilder.mat_sci(EnemyMeshBuilder.darken(base_color, 0.15), 0.5, 0.4)
	var mat_eye: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		Color(1.0, 0.6, 0.0), 0.0, 0.3,
		Color(1.0, 0.55, 0.0), 2.0)
	var mat_pupil: StandardMaterial3D = EnemyMeshBuilder.mat_sci(Color(0.05, 0.05, 0.05), 0.0, 0.8)
	var mat_fang: StandardMaterial3D = EnemyMeshBuilder.mat_sci(Color(0.92, 0.9, 0.85), 0.1, 0.35)
	var mat_whisker: StandardMaterial3D = EnemyMeshBuilder.mat_sci(
		EnemyMeshBuilder.lighten(base_color, 0.2), 0.0, 0.7)
	var mat_claw: StandardMaterial3D = EnemyMeshBuilder.mat_sci(Color(0.2, 0.18, 0.15), 0.6, 0.35)
	var mat_tail_tuft: StandardMaterial3D = EnemyMeshBuilder.mat_sci(EnemyMeshBuilder.darken(base_color, 0.18), 0.3, 0.5)

	# ── Torso — elongated panther body ──
	EnemyMeshBuilder.add_sphere(root, 0.45, Vector3(0.0, 0.7, 0.0), mat_body,
		Vector3(1.8, 0.75, 0.85))

	# Belly highlight
	EnemyMeshBuilder.add_sphere(root, 0.32, Vector3(0.0, 0.52, 0.0), mat_belly,
		Vector3(1.5, 0.45, 0.7))

	# ── Spine ridges (5 small cones along back) ──
	for i: int in range(5):
		var xoff: float = -0.5 + i * 0.25
		EnemyMeshBuilder.add_cone(root, 0.04, 0.14, Vector3(xoff, 1.05, 0.0), mat_ridge,
			Vector3(0.0, 0.0, 0.0))

	# ── Head ──
	var head: Node3D = Node3D.new()
	head.position = Vector3(0.95, 0.82, 0.0)
	root.add_child(head)

	# Skull — wedge-shaped
	EnemyMeshBuilder.add_sphere(head, 0.18, Vector3(0.0, 0.0, 0.0), mat_body,
		Vector3(1.3, 0.85, 0.9))

	# Snout
	EnemyMeshBuilder.add_sphere(head, 0.1, Vector3(0.18, -0.06, 0.0), mat_dark,
		Vector3(1.4, 0.65, 0.75))

	# ── Eyes — amber emissive with slit pupils ──
	EnemyMeshBuilder.add_sphere(head, 0.045, Vector3(0.1, 0.06, 0.12), mat_eye)
	EnemyMeshBuilder.add_sphere(head, 0.045, Vector3(0.1, 0.06, -0.12), mat_eye)

	# Slit pupils — very thin vertical ellipses
	EnemyMeshBuilder.add_sphere(head, 0.025, Vector3(0.13, 0.06, 0.12), mat_pupil,
		Vector3(0.3, 1.2, 0.3))
	EnemyMeshBuilder.add_sphere(head, 0.025, Vector3(0.13, 0.06, -0.12), mat_pupil,
		Vector3(0.3, 1.2, 0.3))

	# ── Fangs (4 visible) ──
	# Upper fangs
	EnemyMeshBuilder.add_cone(head, 0.018, 0.1, Vector3(0.22, -0.12, 0.06), mat_fang,
		Vector3(PI, 0.0, 0.0))
	EnemyMeshBuilder.add_cone(head, 0.018, 0.1, Vector3(0.22, -0.12, -0.06), mat_fang,
		Vector3(PI, 0.0, 0.0))
	# Lower fangs (smaller)
	EnemyMeshBuilder.add_cone(head, 0.014, 0.07, Vector3(0.2, -0.1, 0.04), mat_fang,
		Vector3(0.0, 0.0, 0.0))
	EnemyMeshBuilder.add_cone(head, 0.014, 0.07, Vector3(0.2, -0.1, -0.04), mat_fang,
		Vector3(0.0, 0.0, 0.0))

	# ── Whiskers / sensor filaments (3 per side) ──
	for side: int in [-1, 1]:
		for w: int in range(3):
			var angle: float = -0.3 + w * 0.3
			var wz: float = side * (0.12 + w * 0.02)
			EnemyMeshBuilder.add_capsule(head, 0.006, 0.18,
				Vector3(0.22 + cos(angle) * 0.05, -0.04, wz), mat_whisker,
				Vector3(0.0, 0.0, angle + side * 0.4))

	# ── Pointed ears ──
	EnemyMeshBuilder.add_cone(head, 0.06, 0.14, Vector3(-0.06, 0.16, 0.12), mat_body,
		Vector3(-0.3, 0.0, 0.15))
	EnemyMeshBuilder.add_cone(head, 0.06, 0.14, Vector3(-0.06, 0.16, -0.12), mat_body,
		Vector3(-0.3, 0.0, -0.15))

	# ── Legs (4) — each: upper + lower + paw + 3 claws ──
	var leg_roots: Array = []
	var leg_positions: Array = [
		Vector3(0.45, 0.45, 0.32),   # front-right
		Vector3(0.45, 0.45, -0.32),  # front-left
		Vector3(-0.5, 0.45, 0.32),   # rear-right
		Vector3(-0.5, 0.45, -0.32),  # rear-left
	]

	for i: int in range(4):
		var leg: Node3D = Node3D.new()
		leg.position = leg_positions[i]
		root.add_child(leg)
		leg_roots.append(leg)

		# Upper leg
		EnemyMeshBuilder.add_capsule(leg, 0.065, 0.22,
			Vector3(0.0, -0.05, 0.0), mat_body, Vector3(0.0, 0.0, 0.0))

		# Lower leg
		var lower: Node3D = Node3D.new()
		lower.position = Vector3(0.0, -0.28, 0.0)
		leg.add_child(lower)

		EnemyMeshBuilder.add_capsule(lower, 0.05, 0.2,
			Vector3(0.0, 0.0, 0.0), mat_dark, Vector3(0.0, 0.0, 0.0))

		# Paw
		EnemyMeshBuilder.add_sphere(lower, 0.06, Vector3(0.03, -0.18, 0.0), mat_dark,
			Vector3(1.3, 0.6, 1.1))

		# 3 claws per paw
		for c: int in range(3):
			var cz: float = (c - 1) * 0.035
			EnemyMeshBuilder.add_cone(lower, 0.015, 0.06,
				Vector3(0.07, -0.2, cz), mat_claw,
				Vector3(0.5, 0.0, 0.3))

	# ── Tail (segmented: 5 segments + tuft) ──
	var tail_root: Node3D = Node3D.new()
	tail_root.position = Vector3(-0.85, 0.75, 0.0)
	root.add_child(tail_root)

	var tail_segments: Array = []
	for i: int in range(5):
		var seg: Node3D = Node3D.new()
		var seg_x: float = -(i * 0.18)
		var seg_y: float = 0.05 + i * 0.04
		seg.position = Vector3(seg_x, seg_y, 0.0)
		tail_root.add_child(seg)
		tail_segments.append(seg)

		var seg_radius: float = 0.04 - i * 0.005
		EnemyMeshBuilder.add_capsule(seg, seg_radius, 0.12,
			Vector3(0.0, 0.0, 0.0), mat_body,
			Vector3(0.0, 0.0, PI * 0.5))

	# Tail tuft
	EnemyMeshBuilder.add_sphere(tail_root, 0.06,
		Vector3(-0.92, 0.26, 0.0), mat_tail_tuft,
		Vector3(1.6, 0.8, 0.8))

	# ── Store animatable references ──
	root.set_meta("head", [head])
	root.set_meta("legs", leg_roots)
	root.set_meta("tail_root", [tail_root])
	root.set_meta("tail_segments", tail_segments)

	# Built facing +X, rotate to face -Z (Godot forward)
	root.rotation.y = -PI / 2.0
	return root


# ──────────────────────────────────────────────
# Animate
# ──────────────────────────────────────────────
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	# ── Head bob ──
	var heads: Array = root.get_meta("head", [])
	if heads.size() > 0:
		var head_node: Node3D = heads[0] as Node3D
		if is_moving:
			# Slight forward-back bob while prowling
			head_node.rotation.z = sin(phase * 3.0) * 0.04
			head_node.position.y = 0.82 + sin(phase * 6.0) * 0.01
		else:
			# Idle: slow ambient scan
			head_node.rotation.y = sin(phase * 0.7) * 0.12
			head_node.rotation.z = sin(phase * 0.5) * 0.02

	# ── Leg walk cycle ──
	var legs: Array = root.get_meta("legs", [])
	if legs.size() == 4:
		# Diagonal gait: front-right + rear-left move together
		var offsets: Array = [0.0, PI, PI, 0.0]
		for i: int in range(4):
			var leg_node: Node3D = legs[i] as Node3D
			if is_moving:
				var stride: float = sin(phase * 4.0 + offsets[i])
				leg_node.rotation.x = stride * 0.35
				# Lift paw off ground on forward swing
				leg_node.position.y = 0.45 + maxf(0.0, stride) * 0.06
			else:
				# Return to rest gradually
				leg_node.rotation.x = lerp(leg_node.rotation.x, 0.0, delta * 3.0)
				leg_node.position.y = lerp(leg_node.position.y, 0.45, delta * 3.0)

	# ── Tail sway ──
	var tail_roots: Array = root.get_meta("tail_root", [])
	if tail_roots.size() > 0:
		var tail_node: Node3D = tail_roots[0] as Node3D
		if is_moving:
			tail_node.rotation.y = sin(phase * 3.5) * 0.25
		else:
			tail_node.rotation.y = sin(phase * 0.8) * 0.15

	# Segmented tail wave
	var t_segs: Array = root.get_meta("tail_segments", [])
	for i: int in range(t_segs.size()):
		var seg_node: Node3D = t_segs[i] as Node3D
		var wave_speed: float = 3.0 if is_moving else 0.9
		var wave_amp: float = 0.12 + i * 0.05
		seg_node.rotation.y = sin(phase * wave_speed + i * 0.6) * wave_amp
