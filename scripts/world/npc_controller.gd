## NPCController — Individual NPC behavior and interaction
##
## Attached to an NPC StaticBody3D. Loads data from DataManager.
## Click to talk. Shows a nameplate overhead. Uses PlayerMeshBuilder-style
## humanoid mesh with NPC-specific colors and idle animation.
extends StaticBody3D

# ── NPC data ──
var npc_id: String = ""
var npc_name: String = "NPC"
var npc_desc: String = ""
var dialogue: Dictionary = {}
var shop_data: Dictionary = {}
var body_color: Color = Color(0.5, 0.5, 0.5)
var head_color: Color = Color(0.7, 0.7, 0.7)

# ── Node refs ──
var _nameplate: Label3D = null
var _mesh_root: Node3D = null
var _idle_phase: float = 0.0

## Initialize this NPC from DataManager data
func setup(p_npc_id: String) -> void:
	npc_id = p_npc_id
	var data: Dictionary = DataManager.get_npc(p_npc_id)
	if data.is_empty():
		push_warning("NPCController: Unknown NPC '%s'" % p_npc_id)
		return

	npc_name = str(data.get("name", p_npc_id))
	npc_desc = str(data.get("desc", ""))
	dialogue = data.get("dialogue", {})
	shop_data = data.get("shop", {})

	# Position
	var pos_data: Dictionary = data.get("position", {})
	var px: float = float(pos_data.get("x", 0))
	var pz: float = float(pos_data.get("z", 0))
	global_position = Vector3(px, 0.0, pz)

	# Colors
	var bc: int = int(data.get("bodyColor", 0x808080))
	var hc: int = int(data.get("headColor", 0xb0b0b0))
	body_color = Color(
		((bc >> 16) & 0xFF) / 255.0,
		((bc >> 8) & 0xFF) / 255.0,
		(bc & 0xFF) / 255.0
	)
	head_color = Color(
		((hc >> 16) & 0xFF) / 255.0,
		((hc >> 8) & 0xFF) / 255.0,
		(hc & 0xFF) / 255.0
	)

	_build_npc_mesh()

func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 8  # NPC layer (layer 4)
	collision_mask = 0

	# Collision shape
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95
	add_child(collision)

func _process(delta: float) -> void:
	_idle_phase += delta
	if _mesh_root:
		_animate_npc_idle(_idle_phase)

## Build a full humanoid mesh matching the PlayerMeshBuilder style
func _build_npc_mesh() -> void:
	if _mesh_root:
		_mesh_root.queue_free()

	_mesh_root = Node3D.new()
	_mesh_root.name = "NPCMesh"
	add_child(_mesh_root)

	var suit_color: Color = body_color
	var armor_color: Color = body_color.lightened(0.15)
	var visor_color: Color = _npc_visor_color()
	var joint_color: Color = body_color.darkened(0.5)
	var boot_color: Color = body_color.darkened(0.6)

	# ── Head & Helmet ──
	var head_group: Node3D = Node3D.new()
	head_group.name = "HeadGroup"
	head_group.position = Vector3(0.0, 1.65, 0.0)
	_mesh_root.add_child(head_group)

	# Helmet shell
	var helmet_shell: MeshInstance3D = _sphere("HelmetShell", 0.21, armor_color, true)
	helmet_shell.position = Vector3(0.0, 0.0, 0.02)
	head_group.add_child(helmet_shell)

	# Head
	var head: MeshInstance3D = _sphere("Head", 0.18, head_color, true)
	head_group.add_child(head)

	# Visor
	var visor: MeshInstance3D = _box("Visor", Vector3(0.26, 0.1, 0.05), visor_color, false, true, 3.0)
	visor.position = Vector3(0.0, 0.0, -0.16)
	head_group.add_child(visor)

	# ── Neck ──
	var neck: MeshInstance3D = _capsule("Neck", 0.06, 0.18, joint_color, true)
	neck.position = Vector3(0.0, 1.48, 0.0)
	_mesh_root.add_child(neck)

	# ── Torso ──
	var torso: MeshInstance3D = _capsule("Torso", 0.22, 0.5, suit_color, true)
	torso.position = Vector3(0.0, 1.1, 0.0)
	_mesh_root.add_child(torso)

	# Chest plate
	var chest_plate: MeshInstance3D = _sphere("ChestPlate", 0.2, armor_color, true)
	chest_plate.position = Vector3(0.0, 1.15, -0.1)
	chest_plate.scale = Vector3(1.1, 0.9, 0.5)
	_mesh_root.add_child(chest_plate)

	# Energy core (uses NPC visor color)
	var energy_core: MeshInstance3D = _sphere("EnergyCore", 0.04, visor_color, false, true, 4.0)
	energy_core.position = Vector3(0.0, 1.1, -0.18)
	_mesh_root.add_child(energy_core)

	# ── Belt ──
	var belt: MeshInstance3D = _torus("Belt", 0.2, 0.03, joint_color, true)
	belt.position = Vector3(0.0, 0.85, 0.0)
	_mesh_root.add_child(belt)

	# ── Shoulders ──
	var left_pauldron: MeshInstance3D = _sphere("LeftPauldron", 0.1, armor_color, true)
	left_pauldron.position = Vector3(-0.32, 1.28, 0.0)
	left_pauldron.scale = Vector3(1.1, 0.7, 1.0)
	_mesh_root.add_child(left_pauldron)

	var right_pauldron: MeshInstance3D = _sphere("RightPauldron", 0.1, armor_color, true)
	right_pauldron.position = Vector3(0.32, 1.28, 0.0)
	right_pauldron.scale = Vector3(1.1, 0.7, 1.0)
	_mesh_root.add_child(right_pauldron)

	# ── Left Arm ──
	var left_arm_upper: Node3D = Node3D.new()
	left_arm_upper.name = "LeftArmUpper"
	left_arm_upper.position = Vector3(-0.32, 1.2, 0.0)
	_mesh_root.add_child(left_arm_upper)

	var lua_mesh: MeshInstance3D = _capsule("LeftUpperArmMesh", 0.06, 0.26, suit_color, true)
	lua_mesh.position = Vector3(0.0, -0.1, 0.0)
	left_arm_upper.add_child(lua_mesh)

	var left_elbow: MeshInstance3D = _sphere("LeftElbow", 0.045, joint_color, true)
	left_elbow.position = Vector3(0.0, -0.24, 0.0)
	left_arm_upper.add_child(left_elbow)

	var left_arm_lower: Node3D = Node3D.new()
	left_arm_lower.name = "LeftArmLower"
	left_arm_lower.position = Vector3(0.0, -0.24, 0.0)
	left_arm_upper.add_child(left_arm_lower)

	var lla_mesh: MeshInstance3D = _capsule("LeftLowerArmMesh", 0.05, 0.24, suit_color, true)
	lla_mesh.position = Vector3(0.0, -0.11, 0.0)
	left_arm_lower.add_child(lla_mesh)

	var left_hand: MeshInstance3D = _sphere("LeftHand", 0.045, armor_color, true)
	left_hand.position = Vector3(0.0, -0.24, 0.0)
	left_arm_lower.add_child(left_hand)

	# ── Right Arm ──
	var right_arm_upper: Node3D = Node3D.new()
	right_arm_upper.name = "RightArmUpper"
	right_arm_upper.position = Vector3(0.32, 1.2, 0.0)
	_mesh_root.add_child(right_arm_upper)

	var rua_mesh: MeshInstance3D = _capsule("RightUpperArmMesh", 0.06, 0.26, suit_color, true)
	rua_mesh.position = Vector3(0.0, -0.1, 0.0)
	right_arm_upper.add_child(rua_mesh)

	var right_elbow: MeshInstance3D = _sphere("RightElbow", 0.045, joint_color, true)
	right_elbow.position = Vector3(0.0, -0.24, 0.0)
	right_arm_upper.add_child(right_elbow)

	var right_arm_lower: Node3D = Node3D.new()
	right_arm_lower.name = "RightArmLower"
	right_arm_lower.position = Vector3(0.0, -0.24, 0.0)
	right_arm_upper.add_child(right_arm_lower)

	var rla_mesh: MeshInstance3D = _capsule("RightLowerArmMesh", 0.05, 0.24, suit_color, true)
	rla_mesh.position = Vector3(0.0, -0.11, 0.0)
	right_arm_lower.add_child(rla_mesh)

	var right_hand: MeshInstance3D = _sphere("RightHand", 0.045, armor_color, true)
	right_hand.position = Vector3(0.0, -0.24, 0.0)
	right_arm_lower.add_child(right_hand)

	# ── Left Leg ──
	var left_leg_upper: Node3D = Node3D.new()
	left_leg_upper.name = "LeftLegUpper"
	left_leg_upper.position = Vector3(-0.1, 0.8, 0.0)
	_mesh_root.add_child(left_leg_upper)

	var llu_mesh: MeshInstance3D = _capsule("LeftUpperLegMesh", 0.075, 0.32, suit_color, true)
	llu_mesh.position = Vector3(0.0, -0.13, 0.0)
	left_leg_upper.add_child(llu_mesh)

	var left_knee: MeshInstance3D = _sphere("LeftKnee", 0.055, joint_color, true)
	left_knee.position = Vector3(0.0, -0.3, 0.0)
	left_leg_upper.add_child(left_knee)

	var left_leg_lower: Node3D = Node3D.new()
	left_leg_lower.name = "LeftLegLower"
	left_leg_lower.position = Vector3(0.0, -0.3, 0.0)
	left_leg_upper.add_child(left_leg_lower)

	var lll_mesh: MeshInstance3D = _capsule("LeftLowerLegMesh", 0.06, 0.3, suit_color, true)
	lll_mesh.position = Vector3(0.0, -0.13, 0.0)
	left_leg_lower.add_child(lll_mesh)

	var left_boot: MeshInstance3D = _box("LeftBoot", Vector3(0.09, 0.09, 0.14), boot_color, true)
	left_boot.position = Vector3(0.0, -0.32, -0.02)
	left_leg_lower.add_child(left_boot)

	# ── Right Leg ──
	var right_leg_upper: Node3D = Node3D.new()
	right_leg_upper.name = "RightLegUpper"
	right_leg_upper.position = Vector3(0.1, 0.8, 0.0)
	_mesh_root.add_child(right_leg_upper)

	var rlu_mesh: MeshInstance3D = _capsule("RightUpperLegMesh", 0.075, 0.32, suit_color, true)
	rlu_mesh.position = Vector3(0.0, -0.13, 0.0)
	right_leg_upper.add_child(rlu_mesh)

	var right_knee: MeshInstance3D = _sphere("RightKnee", 0.055, joint_color, true)
	right_knee.position = Vector3(0.0, -0.3, 0.0)
	right_leg_upper.add_child(right_knee)

	var right_leg_lower: Node3D = Node3D.new()
	right_leg_lower.name = "RightLegLower"
	right_leg_lower.position = Vector3(0.0, -0.3, 0.0)
	right_leg_upper.add_child(right_leg_lower)

	var rll_mesh: MeshInstance3D = _capsule("RightLowerLegMesh", 0.06, 0.3, suit_color, true)
	rll_mesh.position = Vector3(0.0, -0.13, 0.0)
	right_leg_lower.add_child(rll_mesh)

	var right_boot: MeshInstance3D = _box("RightBoot", Vector3(0.09, 0.09, 0.14), boot_color, true)
	right_boot.position = Vector3(0.0, -0.32, -0.02)
	right_leg_lower.add_child(right_boot)

	# ── Backpack ──
	var backpack: MeshInstance3D = _box("Backpack", Vector3(0.2, 0.25, 0.1), armor_color.darkened(0.1), true)
	backpack.position = Vector3(0.0, 1.1, 0.16)
	_mesh_root.add_child(backpack)

	# Backpack glow strip
	var bp_strip: MeshInstance3D = _box("BackpackStrip", Vector3(0.16, 0.02, 0.11), visor_color, false, true, 1.5)
	bp_strip.position = Vector3(0.0, 1.15, 0.16)
	_mesh_root.add_child(bp_strip)

	# ── Base platform ring ──
	var base_ring_mesh: MeshInstance3D = _torus("BaseRing", 0.5, 0.035, visor_color, false, true, 2.0)
	base_ring_mesh.position = Vector3(0.0, 0.03, 0.0)
	_mesh_root.add_child(base_ring_mesh)

	# ── Nameplate ──
	_nameplate = Label3D.new()
	_nameplate.position = Vector3(0, 2.2, 0)
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.font_size = 24
	_nameplate.outline_size = 6
	_nameplate.outline_modulate = Color(0, 0, 0, 0.9)
	_nameplate.modulate = visor_color.lightened(0.3)
	_nameplate.text = npc_name
	add_child(_nameplate)

	# Store animatable parts in meta
	_mesh_root.set_meta("head_group", head_group)
	_mesh_root.set_meta("left_arm_upper", left_arm_upper)
	_mesh_root.set_meta("left_arm_lower", left_arm_lower)
	_mesh_root.set_meta("right_arm_upper", right_arm_upper)
	_mesh_root.set_meta("right_arm_lower", right_arm_lower)
	_mesh_root.set_meta("left_leg_upper", left_leg_upper)
	_mesh_root.set_meta("left_leg_lower", left_leg_lower)
	_mesh_root.set_meta("right_leg_upper", right_leg_upper)
	_mesh_root.set_meta("right_leg_lower", right_leg_lower)
	_mesh_root.set_meta("energy_core", energy_core)
	_mesh_root.set_meta("visor", visor)

## Determine NPC visor color based on their role
func _npc_visor_color() -> Color:
	match npc_id:
		"commander_vex": return Color(1.0, 0.6, 0.2)     # Orange — commander
		"slayer_grax": return Color(1.0, 0.2, 0.2)       # Red — slayer
		"the_archivist": return Color(0.7, 0.3, 1.0)     # Purple — prestige
		"dr_elara_voss": return Color(1.0, 0.3, 1.0)     # Pink — neural
		"warden_krios": return Color(0.2, 1.0, 0.4)      # Green — military
		"signal_officer_mira": return Color(0.2, 0.6, 1.0) # Blue — comms
		_: return Color(0.2, 0.9, 1.0)                    # Default cyan

## Idle animation — gentle breathing, arm sway, energy pulse
func _animate_npc_idle(phase: float) -> void:
	if not _mesh_root:
		return

	var breath: float = sin(phase * 1.2) * 0.006
	var sway: float = sin(phase * 0.7) * 0.025

	# Head bob
	var head_group: Node3D = _mesh_root.get_meta("head_group") as Node3D
	if head_group:
		head_group.position.y = 1.65 + breath

	# Arms dangle
	var left_arm: Node3D = _mesh_root.get_meta("left_arm_upper") as Node3D
	var right_arm: Node3D = _mesh_root.get_meta("right_arm_upper") as Node3D
	if left_arm:
		left_arm.rotation.x = sway
		left_arm.rotation.z = sin(phase * 0.5) * 0.01
	if right_arm:
		right_arm.rotation.x = -sway
		right_arm.rotation.z = -sin(phase * 0.5) * 0.01

	# Energy core pulse
	var energy_core: MeshInstance3D = _mesh_root.get_meta("energy_core") as MeshInstance3D
	if energy_core:
		var pulse: float = 0.9 + sin(phase * 2.5) * 0.15
		energy_core.scale = Vector3(pulse, pulse, pulse)

	# Visor glow shift
	var visor: MeshInstance3D = _mesh_root.get_meta("visor") as MeshInstance3D
	if visor and visor.mesh:
		var mat: StandardMaterial3D = visor.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.5 + sin(phase * 1.8) * 0.5

## Get the greeting dialogue node
func get_greeting() -> Dictionary:
	return dialogue.get("greeting", {})

## Get a specific dialogue node by key
func get_dialogue_node(key: String) -> Dictionary:
	return dialogue.get(key, {})

## Check if this NPC has a shop
func has_shop() -> bool:
	return not shop_data.is_empty()

## Get shop data
func get_shop_data() -> Dictionary:
	return shop_data


# ═══════════════════════════════════════════════════════════════════════════════
#  MESH FACTORY HELPERS (mirrors PlayerMeshBuilder)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_material(color: Color, metallic: bool = false,
		emissive: bool = false, emission_strength: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if metallic:
		mat.metallic = 0.5
		mat.metallic_specular = 0.4
		mat.roughness = 0.4
	else:
		mat.roughness = 0.5
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat

func _sphere(node_name: String, radius: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi

func _capsule(node_name: String, radius: float, height: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi

func _box(node_name: String, size: Vector3, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi

func _torus(node_name: String, inner_radius: float, ring_radius: float,
		color: Color, metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = inner_radius + ring_radius
	mesh.rings = 20
	mesh.ring_segments = 10
	mi.mesh = mesh
	mi.set_surface_override_material(0, _make_material(color, metallic, emissive, emission_strength))
	return mi
