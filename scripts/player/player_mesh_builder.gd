## PlayerMeshBuilder — Constructs a sci-fi astronaut/space suit player character
## from MeshInstance3D primitives. All positions relative to feet at y=0.
##
## Usage:
##   var root: Node3D = PlayerMeshBuilder.build_player_mesh()
##   add_child(root)
##   # Animate:
##   PlayerMeshBuilder.animate_walk(root, phase, speed)
##   PlayerMeshBuilder.animate_idle(root, phase)
class_name PlayerMeshBuilder
extends RefCounted

# ── Colour palette ──────────────────────────────────────────────────────────
const COL_PRIMARY: Color = Color(0.2, 0.35, 0.55)        # Blue-gray suit
const COL_ARMOR: Color = Color(0.25, 0.4, 0.6)           # Lighter armor plates
const COL_VISOR: Color = Color(0.2, 0.8, 1.0)            # Bright cyan visor
const COL_ENERGY: Color = Color(0.0, 1.0, 0.8)           # Teal energy core
const COL_JOINT: Color = Color(0.1, 0.1, 0.15)           # Near-black joints
const COL_BOOT: Color = Color(0.12, 0.12, 0.15)          # Very dark boots
const COL_BACKPACK: Color = Color(0.18, 0.25, 0.38)      # Slightly dark blue-gray
const COL_ANTENNA: Color = Color(0.6, 0.6, 0.65)         # Light metallic


# ═══════════════════════════════════════════════════════════════════════════
#  BUILD
# ═══════════════════════════════════════════════════════════════════════════

static func build_player_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "AstronautMesh"

	# ── Head & Helmet ───────────────────────────────────────────────────
	var head_group: Node3D = Node3D.new()
	head_group.name = "HeadGroup"
	head_group.position = Vector3(0.0, 1.65, 0.0)
	root.add_child(head_group)

	# Helmet shell (back)
	var helmet_shell: MeshInstance3D = _sphere("HelmetShell", 0.21, COL_ARMOR, true)
	helmet_shell.position = Vector3(0.0, 0.0, 0.02)
	head_group.add_child(helmet_shell)

	# Head sphere
	var head: MeshInstance3D = _sphere("Head", 0.18, COL_PRIMARY, true)
	head_group.add_child(head)

	# Visor (front face)
	var visor: MeshInstance3D = _box("Visor", Vector3(0.26, 0.1, 0.05), COL_VISOR, false, true, 3.0)
	visor.position = Vector3(0.0, 0.0, -0.16)
	head_group.add_child(visor)

	# Helmet rim (ring around visor opening)
	var helmet_rim: MeshInstance3D = _torus("HelmetRim", 0.19, 0.02, COL_ARMOR, true)
	helmet_rim.position = Vector3(0.0, 0.0, -0.04)
	helmet_rim.rotation.x = deg_to_rad(90.0)
	head_group.add_child(helmet_rim)

	# ── Neck ────────────────────────────────────────────────────────────
	var neck: MeshInstance3D = _capsule("Neck", 0.06, 0.18, COL_JOINT, true)
	neck.position = Vector3(0.0, 1.48, 0.0)
	root.add_child(neck)

	# ── Torso ───────────────────────────────────────────────────────────
	var torso: MeshInstance3D = _capsule("Torso", 0.22, 0.5, COL_PRIMARY, true)
	torso.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(torso)

	# Chest plate (front armor)
	var chest_plate: MeshInstance3D = _sphere("ChestPlate", 0.2, COL_ARMOR, true)
	chest_plate.position = Vector3(0.0, 1.15, -0.1)
	chest_plate.scale = Vector3(1.1, 0.9, 0.5)
	root.add_child(chest_plate)

	# Energy core
	var energy_core: MeshInstance3D = _sphere("EnergyCore", 0.045, COL_ENERGY, false, true, 5.0)
	energy_core.position = Vector3(0.0, 1.1, -0.18)
	root.add_child(energy_core)

	# ── Belt ────────────────────────────────────────────────────────────
	var belt: MeshInstance3D = _torus("Belt", 0.2, 0.03, COL_JOINT, true)
	belt.position = Vector3(0.0, 0.85, 0.0)
	root.add_child(belt)

	# Belt buckle
	var buckle: MeshInstance3D = _box("BeltBuckle", Vector3(0.08, 0.05, 0.04), COL_ARMOR, true)
	buckle.position = Vector3(0.0, 0.85, -0.2)
	root.add_child(buckle)

	# ── Shoulders (pauldrons) ───────────────────────────────────────────
	var left_pauldron: MeshInstance3D = _sphere("LeftPauldron", 0.1, COL_ARMOR, true)
	left_pauldron.position = Vector3(-0.32, 1.28, 0.0)
	left_pauldron.scale = Vector3(1.1, 0.7, 1.0)
	root.add_child(left_pauldron)

	var right_pauldron: MeshInstance3D = _sphere("RightPauldron", 0.1, COL_ARMOR, true)
	right_pauldron.position = Vector3(0.32, 1.28, 0.0)
	right_pauldron.scale = Vector3(1.1, 0.7, 1.0)
	root.add_child(right_pauldron)

	# ── Left Arm ────────────────────────────────────────────────────────
	var left_arm_upper: Node3D = Node3D.new()
	left_arm_upper.name = "LeftArmUpper"
	left_arm_upper.position = Vector3(-0.32, 1.2, 0.0)
	root.add_child(left_arm_upper)

	var lua_mesh: MeshInstance3D = _capsule("LeftUpperArmMesh", 0.065, 0.28, COL_PRIMARY, true)
	lua_mesh.position = Vector3(0.0, -0.1, 0.0)
	left_arm_upper.add_child(lua_mesh)

	var left_elbow: MeshInstance3D = _sphere("LeftElbow", 0.05, COL_JOINT, true)
	left_elbow.position = Vector3(0.0, -0.25, 0.0)
	left_arm_upper.add_child(left_elbow)

	var left_arm_lower: Node3D = Node3D.new()
	left_arm_lower.name = "LeftArmLower"
	left_arm_lower.position = Vector3(0.0, -0.25, 0.0)
	left_arm_upper.add_child(left_arm_lower)

	var lla_mesh: MeshInstance3D = _capsule("LeftLowerArmMesh", 0.055, 0.26, COL_PRIMARY, true)
	lla_mesh.position = Vector3(0.0, -0.12, 0.0)
	left_arm_lower.add_child(lla_mesh)

	var left_hand: MeshInstance3D = _sphere("LeftHand", 0.05, COL_ARMOR, true)
	left_hand.position = Vector3(0.0, -0.26, 0.0)
	left_arm_lower.add_child(left_hand)

	# ── Right Arm ───────────────────────────────────────────────────────
	var right_arm_upper: Node3D = Node3D.new()
	right_arm_upper.name = "RightArmUpper"
	right_arm_upper.position = Vector3(0.32, 1.2, 0.0)
	root.add_child(right_arm_upper)

	var rua_mesh: MeshInstance3D = _capsule("RightUpperArmMesh", 0.065, 0.28, COL_PRIMARY, true)
	rua_mesh.position = Vector3(0.0, -0.1, 0.0)
	right_arm_upper.add_child(rua_mesh)

	var right_elbow: MeshInstance3D = _sphere("RightElbow", 0.05, COL_JOINT, true)
	right_elbow.position = Vector3(0.0, -0.25, 0.0)
	right_arm_upper.add_child(right_elbow)

	var right_arm_lower: Node3D = Node3D.new()
	right_arm_lower.name = "RightArmLower"
	right_arm_lower.position = Vector3(0.0, -0.25, 0.0)
	right_arm_upper.add_child(right_arm_lower)

	var rla_mesh: MeshInstance3D = _capsule("RightLowerArmMesh", 0.055, 0.26, COL_PRIMARY, true)
	rla_mesh.position = Vector3(0.0, -0.12, 0.0)
	right_arm_lower.add_child(rla_mesh)

	var right_hand: MeshInstance3D = _sphere("RightHand", 0.05, COL_ARMOR, true)
	right_hand.position = Vector3(0.0, -0.26, 0.0)
	right_arm_lower.add_child(right_hand)

	# ── Left Leg ────────────────────────────────────────────────────────
	var left_leg_upper: Node3D = Node3D.new()
	left_leg_upper.name = "LeftLegUpper"
	left_leg_upper.position = Vector3(-0.12, 0.8, 0.0)
	root.add_child(left_leg_upper)

	var llu_mesh: MeshInstance3D = _capsule("LeftUpperLegMesh", 0.08, 0.34, COL_PRIMARY, true)
	llu_mesh.position = Vector3(0.0, -0.14, 0.0)
	left_leg_upper.add_child(llu_mesh)

	var left_knee: MeshInstance3D = _sphere("LeftKnee", 0.06, COL_JOINT, true)
	left_knee.position = Vector3(0.0, -0.32, 0.0)
	left_leg_upper.add_child(left_knee)

	var left_leg_lower: Node3D = Node3D.new()
	left_leg_lower.name = "LeftLegLower"
	left_leg_lower.position = Vector3(0.0, -0.32, 0.0)
	left_leg_upper.add_child(left_leg_lower)

	var lll_mesh: MeshInstance3D = _capsule("LeftLowerLegMesh", 0.065, 0.32, COL_PRIMARY, true)
	lll_mesh.position = Vector3(0.0, -0.14, 0.0)
	left_leg_lower.add_child(lll_mesh)

	# Left boot
	var left_boot: MeshInstance3D = _box("LeftBoot", Vector3(0.1, 0.1, 0.16), COL_BOOT, true)
	left_boot.position = Vector3(0.0, -0.34, -0.02)
	left_leg_lower.add_child(left_boot)

	# Left boot sole
	var left_sole: MeshInstance3D = _box("LeftBootSole", Vector3(0.11, 0.03, 0.17), COL_JOINT, true)
	left_sole.position = Vector3(0.0, -0.38, -0.02)
	left_leg_lower.add_child(left_sole)

	# ── Right Leg ───────────────────────────────────────────────────────
	var right_leg_upper: Node3D = Node3D.new()
	right_leg_upper.name = "RightLegUpper"
	right_leg_upper.position = Vector3(0.12, 0.8, 0.0)
	root.add_child(right_leg_upper)

	var rlu_mesh: MeshInstance3D = _capsule("RightUpperLegMesh", 0.08, 0.34, COL_PRIMARY, true)
	rlu_mesh.position = Vector3(0.0, -0.14, 0.0)
	right_leg_upper.add_child(rlu_mesh)

	var right_knee: MeshInstance3D = _sphere("RightKnee", 0.06, COL_JOINT, true)
	right_knee.position = Vector3(0.0, -0.32, 0.0)
	right_leg_upper.add_child(right_knee)

	var right_leg_lower: Node3D = Node3D.new()
	right_leg_lower.name = "RightLegLower"
	right_leg_lower.position = Vector3(0.0, -0.32, 0.0)
	right_leg_upper.add_child(right_leg_lower)

	var rll_mesh: MeshInstance3D = _capsule("RightLowerLegMesh", 0.065, 0.32, COL_PRIMARY, true)
	rll_mesh.position = Vector3(0.0, -0.14, 0.0)
	right_leg_lower.add_child(rll_mesh)

	# Right boot
	var right_boot: MeshInstance3D = _box("RightBoot", Vector3(0.1, 0.1, 0.16), COL_BOOT, true)
	right_boot.position = Vector3(0.0, -0.34, -0.02)
	right_leg_lower.add_child(right_boot)

	# Right boot sole
	var right_sole: MeshInstance3D = _box("RightBootSole", Vector3(0.11, 0.03, 0.17), COL_JOINT, true)
	right_sole.position = Vector3(0.0, -0.38, -0.02)
	right_leg_lower.add_child(right_sole)

	# ── Backpack ────────────────────────────────────────────────────────
	var backpack: MeshInstance3D = _box("Backpack", Vector3(0.24, 0.3, 0.12), COL_BACKPACK, true)
	backpack.position = Vector3(0.0, 1.1, 0.18)
	root.add_child(backpack)

	# Backpack detail strip
	var bp_strip: MeshInstance3D = _box("BackpackStrip", Vector3(0.2, 0.02, 0.13), COL_ENERGY, false, true, 1.5)
	bp_strip.position = Vector3(0.0, 1.15, 0.18)
	root.add_child(bp_strip)

	# Antenna base
	var antenna_base: MeshInstance3D = _cylinder("AntennaBase", 0.025, 0.06, COL_JOINT, true)
	antenna_base.position = Vector3(0.08, 1.28, 0.18)
	root.add_child(antenna_base)

	# Antenna rod
	var antenna_rod: MeshInstance3D = _cylinder("AntennaRod", 0.01, 0.16, COL_ANTENNA, true)
	antenna_rod.position = Vector3(0.08, 1.4, 0.18)
	root.add_child(antenna_rod)

	# Antenna tip (small glowing sphere)
	var antenna_tip: MeshInstance3D = _sphere("AntennaTip", 0.02, COL_ENERGY, false, true, 3.0)
	antenna_tip.position = Vector3(0.08, 1.5, 0.18)
	root.add_child(antenna_tip)

	# ── Store animatable part references in meta ────────────────────────
	root.set_meta("head_group", head_group)
	root.set_meta("left_arm_upper", left_arm_upper)
	root.set_meta("left_arm_lower", left_arm_lower)
	root.set_meta("right_arm_upper", right_arm_upper)
	root.set_meta("right_arm_lower", right_arm_lower)
	root.set_meta("left_leg_upper", left_leg_upper)
	root.set_meta("left_leg_lower", left_leg_lower)
	root.set_meta("right_leg_upper", right_leg_upper)
	root.set_meta("right_leg_lower", right_leg_lower)
	root.set_meta("energy_core", energy_core)
	root.set_meta("visor", visor)

	return root


# ═══════════════════════════════════════════════════════════════════════════
#  ANIMATION
# ═══════════════════════════════════════════════════════════════════════════

## Walk cycle — swing arms and legs in alternating pattern.
## `phase` should increase by delta * speed each frame (e.g. 0..2*PI loops).
## `intensity` 0..1 controls amplitude (ramp up/down when starting/stopping).
static func animate_walk(root: Node3D, phase: float, intensity: float = 1.0) -> void:
	var swing: float = sin(phase) * 0.45 * intensity
	var half_swing: float = sin(phase) * 0.2 * intensity
	var knee_bend: float = maxf(0.0, -sin(phase)) * 0.5 * intensity
	var knee_bend_opp: float = maxf(0.0, sin(phase)) * 0.5 * intensity

	# -- Legs (left forward when swing > 0) --
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	var left_leg_lower: Node3D = root.get_meta("left_leg_lower") as Node3D
	var right_leg_lower: Node3D = root.get_meta("right_leg_lower") as Node3D

	if left_leg_upper:
		left_leg_upper.rotation.x = swing
	if right_leg_upper:
		right_leg_upper.rotation.x = -swing
	if left_leg_lower:
		left_leg_lower.rotation.x = knee_bend
	if right_leg_lower:
		right_leg_lower.rotation.x = knee_bend_opp

	# -- Arms (opposite to legs) --
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	var left_arm_lower: Node3D = root.get_meta("left_arm_lower") as Node3D
	var right_arm_lower: Node3D = root.get_meta("right_arm_lower") as Node3D

	if left_arm_upper:
		left_arm_upper.rotation.x = -half_swing
	if right_arm_upper:
		right_arm_upper.rotation.x = half_swing
	# Slight elbow bend during swing
	var elbow_l: float = absf(sin(phase)) * 0.25 * intensity
	var elbow_r: float = absf(sin(phase + PI)) * 0.25 * intensity
	if left_arm_lower:
		left_arm_lower.rotation.x = -elbow_l
	if right_arm_lower:
		right_arm_lower.rotation.x = -elbow_r

	# -- Subtle torso/head bob --
	var head_group: Node3D = root.get_meta("head_group") as Node3D
	if head_group:
		head_group.position.y = 1.65 + absf(sin(phase * 2.0)) * 0.015 * intensity


## Idle animation — gentle breathing bob, slight arm sway, energy core pulse.
## `phase` should increase by delta each frame (slow continuous counter).
static func animate_idle(root: Node3D, phase: float) -> void:
	var breath: float = sin(phase * 1.5) * 0.008
	var sway: float = sin(phase * 0.8) * 0.03

	# Head bob from breathing
	var head_group: Node3D = root.get_meta("head_group") as Node3D
	if head_group:
		head_group.position.y = 1.65 + breath

	# Arms dangle slightly
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	if left_arm_upper:
		left_arm_upper.rotation.x = sway
		left_arm_upper.rotation.z = sin(phase * 0.6) * 0.015
	if right_arm_upper:
		right_arm_upper.rotation.x = -sway
		right_arm_upper.rotation.z = -sin(phase * 0.6) * 0.015

	# Reset legs to standing
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	var left_leg_lower: Node3D = root.get_meta("left_leg_lower") as Node3D
	var right_leg_lower: Node3D = root.get_meta("right_leg_lower") as Node3D
	if left_leg_upper:
		left_leg_upper.rotation.x = 0.0
	if right_leg_upper:
		right_leg_upper.rotation.x = 0.0
	if left_leg_lower:
		left_leg_lower.rotation.x = 0.0
	if right_leg_lower:
		right_leg_lower.rotation.x = 0.0

	# Energy core pulse
	var energy_core: MeshInstance3D = root.get_meta("energy_core") as MeshInstance3D
	if energy_core:
		var pulse: float = 0.9 + sin(phase * 3.0) * 0.15
		energy_core.scale = Vector3(pulse, pulse, pulse)

	# Visor subtle brightness shift
	var visor: MeshInstance3D = root.get_meta("visor") as MeshInstance3D
	if visor and visor.mesh:
		var mat: StandardMaterial3D = visor.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.5 + sin(phase * 2.0) * 0.5


## Reset all animated parts to default pose.
static func reset_pose(root: Node3D) -> void:
	for meta_key: String in ["left_arm_upper", "right_arm_upper", "left_arm_lower",
			"right_arm_lower", "left_leg_upper", "right_leg_upper",
			"left_leg_lower", "right_leg_lower"]:
		if root.has_meta(meta_key):
			var node: Node3D = root.get_meta(meta_key) as Node3D
			if node:
				node.rotation = Vector3.ZERO
	var head_group: Node3D = root.get_meta("head_group") as Node3D
	if head_group:
		head_group.position.y = 1.65
	var energy_core: MeshInstance3D = root.get_meta("energy_core") as MeshInstance3D
	if energy_core:
		energy_core.scale = Vector3.ONE


# ═══════════════════════════════════════════════════════════════════════════
#  MESH FACTORY HELPERS
# ═══════════════════════════════════════════════════════════════════════════

static func _make_material(color: Color, metallic: bool = false,
		emissive: bool = false, emission_strength: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if metallic:
		mat.metallic = 0.6
		mat.metallic_specular = 0.5
		mat.roughness = 0.35
	else:
		mat.roughness = 0.5
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	if color == COL_VISOR:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.7
	return mat


static func _sphere(node_name: String, radius: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi


static func _capsule(node_name: String, radius: float, height: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi


static func _box(node_name: String, size: Vector3, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi


static func _cylinder(node_name: String, radius: float, height: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi


static func _torus(node_name: String, inner_radius: float, ring_radius: float,
		color: Color, metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = inner_radius + ring_radius
	mesh.rings = 24
	mesh.ring_segments = 12
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi
