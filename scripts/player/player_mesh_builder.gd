## PlayerMeshBuilder — Constructs a detailed sci-fi power-armored character
## from MeshInstance3D primitives. All positions relative to feet at y=0.
##
## The character is a heavily armored space marine / exosuit pilot with
## glowing energy conduits, layered armor plating, a full-face HUD visor,
## thruster vents, and an integrated power pack.
##
## Usage:
##   var root: Node3D = PlayerMeshBuilder.build_player_mesh()
##   add_child(root)
##   PlayerMeshBuilder.animate_walk(root, phase, speed)
##   PlayerMeshBuilder.animate_idle(root, phase)
class_name PlayerMeshBuilder
extends RefCounted

# ── Colour palette ──────────────────────────────────────────────────────────
const COL_MAIN: Color = Color(0.15, 0.22, 0.35)          # Deep navy suit base
const COL_PLATE: Color = Color(0.22, 0.32, 0.48)         # Steel-blue armor plates
const COL_PLATE_EDGE: Color = Color(0.28, 0.38, 0.55)    # Lighter plate edges
const COL_VISOR: Color = Color(0.15, 0.75, 1.0)          # Bright cyan visor
const COL_ENERGY: Color = Color(0.0, 0.9, 0.7)           # Teal energy glow
const COL_ENERGY_HOT: Color = Color(0.2, 1.0, 0.85)      # Brighter energy accents
const COL_JOINT: Color = Color(0.06, 0.06, 0.09)         # Near-black flex joints
const COL_UNDERSUIT: Color = Color(0.08, 0.1, 0.14)      # Dark undersuit
const COL_BOOT: Color = Color(0.1, 0.1, 0.13)            # Dark boot base
const COL_BOOT_PLATE: Color = Color(0.18, 0.22, 0.3)     # Boot armor layer
const COL_BACKPACK: Color = Color(0.14, 0.2, 0.3)        # Power pack housing
const COL_THRUSTER: Color = Color(1.0, 0.5, 0.1)         # Thruster vent orange
const COL_ANTENNA: Color = Color(0.55, 0.55, 0.6)        # Light metallic
const COL_TRIM: Color = Color(0.6, 0.45, 0.15)           # Gold trim accents


# ═══════════════════════════════════════════════════════════════════════════
#  BUILD
# ═══════════════════════════════════════════════════════════════════════════

static func build_player_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PowerArmorMesh"

	# ── HEAD & HELMET ──────────────────────────────────────────────────
	var head_group: Node3D = Node3D.new()
	head_group.name = "HeadGroup"
	head_group.position = Vector3(0.0, 1.65, 0.0)
	root.add_child(head_group)

	# Main helmet dome (back+top)
	var helmet_dome: MeshInstance3D = _sphere("HelmetDome", 0.23, COL_PLATE, true)
	helmet_dome.position = Vector3(0.0, 0.02, 0.02)
	helmet_dome.scale = Vector3(1.0, 1.05, 1.05)
	head_group.add_child(helmet_dome)

	# Inner head (darker base under helmet)
	var head_base: MeshInstance3D = _sphere("HeadBase", 0.19, COL_MAIN, true)
	head_base.position = Vector3(0.0, 0.0, 0.0)
	head_group.add_child(head_base)

	# Visor — wide wraparound face plate
	var visor: MeshInstance3D = _box("Visor", Vector3(0.30, 0.13, 0.06), COL_VISOR, false, true, 3.5)
	visor.position = Vector3(0.0, -0.01, -0.17)
	head_group.add_child(visor)

	# Visor frame (top bar)
	var visor_frame_top: MeshInstance3D = _box("VisorFrameTop", Vector3(0.32, 0.02, 0.07), COL_PLATE_EDGE, true)
	visor_frame_top.position = Vector3(0.0, 0.055, -0.17)
	head_group.add_child(visor_frame_top)

	# Visor frame (bottom bar)
	var visor_frame_bot: MeshInstance3D = _box("VisorFrameBot", Vector3(0.32, 0.02, 0.07), COL_PLATE_EDGE, true)
	visor_frame_bot.position = Vector3(0.0, -0.075, -0.17)
	head_group.add_child(visor_frame_bot)

	# Helmet chin guard
	var chin_guard: MeshInstance3D = _box("ChinGuard", Vector3(0.16, 0.06, 0.1), COL_PLATE, true)
	chin_guard.position = Vector3(0.0, -0.12, -0.1)
	head_group.add_child(chin_guard)

	# Helmet crest (raised ridge on top)
	var crest: MeshInstance3D = _box("HelmetCrest", Vector3(0.05, 0.04, 0.22), COL_PLATE_EDGE, true)
	crest.position = Vector3(0.0, 0.2, 0.0)
	head_group.add_child(crest)

	# Helmet side vents (left/right)
	for side_x in [-1.0, 1.0]:
		var vent: MeshInstance3D = _box("HelmetVent", Vector3(0.03, 0.06, 0.08), COL_JOINT, true)
		vent.position = Vector3(side_x * 0.22, -0.02, 0.0)
		head_group.add_child(vent)
		var vent_glow: MeshInstance3D = _box("VentGlow", Vector3(0.015, 0.04, 0.06), COL_ENERGY, false, true, 2.0)
		vent_glow.position = Vector3(side_x * 0.23, -0.02, 0.0)
		head_group.add_child(vent_glow)

	# Helmet energy strip (rear)
	var rear_strip: MeshInstance3D = _box("RearStrip", Vector3(0.12, 0.015, 0.02), COL_ENERGY, false, true, 2.0)
	rear_strip.position = Vector3(0.0, 0.08, 0.2)
	head_group.add_child(rear_strip)

	# ── NECK ────────────────────────────────────────────────────────────
	var neck: MeshInstance3D = _capsule("Neck", 0.07, 0.2, COL_UNDERSUIT, false)
	neck.position = Vector3(0.0, 1.48, 0.0)
	root.add_child(neck)

	# Neck ring (armor collar)
	var neck_ring: MeshInstance3D = _torus("NeckRing", 0.12, 0.03, COL_PLATE, true)
	neck_ring.position = Vector3(0.0, 1.42, 0.0)
	root.add_child(neck_ring)

	# ── TORSO ───────────────────────────────────────────────────────────
	# Core torso (undersuit)
	var torso: MeshInstance3D = _capsule("Torso", 0.24, 0.55, COL_MAIN, true)
	torso.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(torso)

	# Front chest plate (main armor)
	var chest_plate: MeshInstance3D = _box("ChestPlate", Vector3(0.38, 0.32, 0.12), COL_PLATE, true)
	chest_plate.position = Vector3(0.0, 1.14, -0.1)
	root.add_child(chest_plate)

	# Upper chest detail plate
	var upper_chest: MeshInstance3D = _box("UpperChest", Vector3(0.3, 0.08, 0.13), COL_PLATE_EDGE, true)
	upper_chest.position = Vector3(0.0, 1.3, -0.1)
	root.add_child(upper_chest)

	# Energy core (central reactor)
	var energy_core: MeshInstance3D = _sphere("EnergyCore", 0.055, COL_ENERGY, false, true, 5.0)
	energy_core.position = Vector3(0.0, 1.12, -0.17)
	root.add_child(energy_core)

	# Energy core housing ring
	var core_ring: MeshInstance3D = _torus("CoreRing", 0.06, 0.015, COL_PLATE_EDGE, true)
	core_ring.position = Vector3(0.0, 1.12, -0.17)
	core_ring.rotation.x = deg_to_rad(90.0)
	root.add_child(core_ring)

	# Abdominal plate
	var ab_plate: MeshInstance3D = _box("AbPlate", Vector3(0.28, 0.14, 0.1), COL_PLATE, true)
	ab_plate.position = Vector3(0.0, 0.93, -0.08)
	root.add_child(ab_plate)

	# Side torso energy conduits
	for side_x in [-1.0, 1.0]:
		var conduit: MeshInstance3D = _capsule("SideConduit", 0.02, 0.28, COL_ENERGY, false, true, 1.5)
		conduit.position = Vector3(side_x * 0.24, 1.1, -0.05)
		root.add_child(conduit)

	# Back plate
	var back_plate: MeshInstance3D = _box("BackPlate", Vector3(0.34, 0.3, 0.08), COL_PLATE, true)
	back_plate.position = Vector3(0.0, 1.12, 0.14)
	root.add_child(back_plate)

	# ── BELT / WAIST ────────────────────────────────────────────────────
	var belt: MeshInstance3D = _torus("Belt", 0.22, 0.035, COL_PLATE_EDGE, true)
	belt.position = Vector3(0.0, 0.84, 0.0)
	root.add_child(belt)

	# Belt buckle (gold trim)
	var buckle: MeshInstance3D = _box("BeltBuckle", Vector3(0.1, 0.06, 0.05), COL_TRIM, true, true, 1.0)
	buckle.position = Vector3(0.0, 0.84, -0.2)
	root.add_child(buckle)

	# Utility pouches on belt
	for side_x in [-1.0, 1.0]:
		var pouch: MeshInstance3D = _box("Pouch", Vector3(0.06, 0.07, 0.05), COL_MAIN, true)
		pouch.position = Vector3(side_x * 0.2, 0.84, -0.12)
		root.add_child(pouch)

	# ── SHOULDERS (pauldrons) ──────────────────────────────────────────
	for side_x in [-1.0, 1.0]:
		var side_name: String = "Left" if side_x < 0 else "Right"

		# Large layered pauldron
		var pauldron_base: MeshInstance3D = _sphere(side_name + "PauldronBase", 0.12, COL_PLATE, true)
		pauldron_base.position = Vector3(side_x * 0.34, 1.3, 0.0)
		pauldron_base.scale = Vector3(1.2, 0.6, 1.1)
		root.add_child(pauldron_base)

		# Pauldron top plate (raised ridge)
		var pauldron_ridge: MeshInstance3D = _box(side_name + "PauldronRidge", Vector3(0.14, 0.025, 0.12), COL_PLATE_EDGE, true)
		pauldron_ridge.position = Vector3(side_x * 0.34, 1.34, 0.0)
		root.add_child(pauldron_ridge)

		# Pauldron energy trim
		var pauldron_glow: MeshInstance3D = _box(side_name + "PauldronGlow", Vector3(0.1, 0.01, 0.08), COL_ENERGY, false, true, 2.0)
		pauldron_glow.position = Vector3(side_x * 0.34, 1.32, -0.04)
		root.add_child(pauldron_glow)

	# ── LEFT ARM ────────────────────────────────────────────────────────
	var left_arm_upper: Node3D = Node3D.new()
	left_arm_upper.name = "LeftArmUpper"
	left_arm_upper.position = Vector3(-0.34, 1.22, 0.0)
	root.add_child(left_arm_upper)

	# Upper arm undersuit
	var lua_under: MeshInstance3D = _capsule("LUA_Under", 0.065, 0.3, COL_UNDERSUIT, false)
	lua_under.position = Vector3(0.0, -0.12, 0.0)
	left_arm_upper.add_child(lua_under)

	# Upper arm armor plate
	var lua_plate: MeshInstance3D = _box("LUA_Plate", Vector3(0.1, 0.18, 0.09), COL_PLATE, true)
	lua_plate.position = Vector3(-0.02, -0.1, 0.0)
	left_arm_upper.add_child(lua_plate)

	# Elbow joint
	var left_elbow: MeshInstance3D = _sphere("LeftElbow", 0.055, COL_JOINT, true)
	left_elbow.position = Vector3(0.0, -0.27, 0.0)
	left_arm_upper.add_child(left_elbow)

	# Elbow cap
	var left_elbow_cap: MeshInstance3D = _sphere("LeftElbowCap", 0.04, COL_PLATE, true)
	left_elbow_cap.position = Vector3(-0.03, -0.27, 0.0)
	left_arm_upper.add_child(left_elbow_cap)

	var left_arm_lower: Node3D = Node3D.new()
	left_arm_lower.name = "LeftArmLower"
	left_arm_lower.position = Vector3(0.0, -0.27, 0.0)
	left_arm_upper.add_child(left_arm_lower)

	# Forearm
	var lla_mesh: MeshInstance3D = _capsule("LLA_Mesh", 0.055, 0.26, COL_MAIN, true)
	lla_mesh.position = Vector3(0.0, -0.12, 0.0)
	left_arm_lower.add_child(lla_mesh)

	# Forearm armor plate (vambrace)
	var lla_vambrace: MeshInstance3D = _box("LLA_Vambrace", Vector3(0.08, 0.16, 0.08), COL_PLATE, true)
	lla_vambrace.position = Vector3(-0.015, -0.1, 0.0)
	left_arm_lower.add_child(lla_vambrace)

	# Wrist energy band
	var left_wrist: MeshInstance3D = _torus("LeftWrist", 0.05, 0.015, COL_ENERGY, false, true, 2.0)
	left_wrist.position = Vector3(0.0, -0.22, 0.0)
	left_arm_lower.add_child(left_wrist)

	# Gauntlet hand
	var left_hand: MeshInstance3D = _box("LeftHand", Vector3(0.06, 0.07, 0.08), COL_PLATE, true)
	left_hand.position = Vector3(0.0, -0.27, 0.0)
	left_arm_lower.add_child(left_hand)

	# ── RIGHT ARM ───────────────────────────────────────────────────────
	var right_arm_upper: Node3D = Node3D.new()
	right_arm_upper.name = "RightArmUpper"
	right_arm_upper.position = Vector3(0.34, 1.22, 0.0)
	root.add_child(right_arm_upper)

	var rua_under: MeshInstance3D = _capsule("RUA_Under", 0.065, 0.3, COL_UNDERSUIT, false)
	rua_under.position = Vector3(0.0, -0.12, 0.0)
	right_arm_upper.add_child(rua_under)

	var rua_plate: MeshInstance3D = _box("RUA_Plate", Vector3(0.1, 0.18, 0.09), COL_PLATE, true)
	rua_plate.position = Vector3(0.02, -0.1, 0.0)
	right_arm_upper.add_child(rua_plate)

	var right_elbow: MeshInstance3D = _sphere("RightElbow", 0.055, COL_JOINT, true)
	right_elbow.position = Vector3(0.0, -0.27, 0.0)
	right_arm_upper.add_child(right_elbow)

	var right_elbow_cap: MeshInstance3D = _sphere("RightElbowCap", 0.04, COL_PLATE, true)
	right_elbow_cap.position = Vector3(0.03, -0.27, 0.0)
	right_arm_upper.add_child(right_elbow_cap)

	var right_arm_lower: Node3D = Node3D.new()
	right_arm_lower.name = "RightArmLower"
	right_arm_lower.position = Vector3(0.0, -0.27, 0.0)
	right_arm_upper.add_child(right_arm_lower)

	var rla_mesh: MeshInstance3D = _capsule("RLA_Mesh", 0.055, 0.26, COL_MAIN, true)
	rla_mesh.position = Vector3(0.0, -0.12, 0.0)
	right_arm_lower.add_child(rla_mesh)

	var rla_vambrace: MeshInstance3D = _box("RLA_Vambrace", Vector3(0.08, 0.16, 0.08), COL_PLATE, true)
	rla_vambrace.position = Vector3(0.015, -0.1, 0.0)
	right_arm_lower.add_child(rla_vambrace)

	var right_wrist: MeshInstance3D = _torus("RightWrist", 0.05, 0.015, COL_ENERGY, false, true, 2.0)
	right_wrist.position = Vector3(0.0, -0.22, 0.0)
	right_arm_lower.add_child(right_wrist)

	var right_hand: MeshInstance3D = _box("RightHand", Vector3(0.06, 0.07, 0.08), COL_PLATE, true)
	right_hand.position = Vector3(0.0, -0.27, 0.0)
	right_arm_lower.add_child(right_hand)

	# ── LEFT LEG ────────────────────────────────────────────────────────
	var left_leg_upper: Node3D = Node3D.new()
	left_leg_upper.name = "LeftLegUpper"
	left_leg_upper.position = Vector3(-0.13, 0.8, 0.0)
	root.add_child(left_leg_upper)

	# Thigh undersuit
	var llu_under: MeshInstance3D = _capsule("LLU_Under", 0.085, 0.36, COL_UNDERSUIT, false)
	llu_under.position = Vector3(0.0, -0.14, 0.0)
	left_leg_upper.add_child(llu_under)

	# Thigh armor (front plate)
	var llu_plate: MeshInstance3D = _box("LLU_Plate", Vector3(0.12, 0.2, 0.09), COL_PLATE, true)
	llu_plate.position = Vector3(0.0, -0.12, -0.04)
	left_leg_upper.add_child(llu_plate)

	# Thigh side plate
	var llu_side: MeshInstance3D = _box("LLU_Side", Vector3(0.04, 0.16, 0.1), COL_PLATE_EDGE, true)
	llu_side.position = Vector3(-0.08, -0.14, 0.0)
	left_leg_upper.add_child(llu_side)

	# Knee joint
	var left_knee: MeshInstance3D = _sphere("LeftKnee", 0.065, COL_JOINT, true)
	left_knee.position = Vector3(0.0, -0.33, 0.0)
	left_leg_upper.add_child(left_knee)

	# Knee cap armor
	var left_knee_cap: MeshInstance3D = _sphere("LeftKneeCap", 0.05, COL_PLATE, true)
	left_knee_cap.position = Vector3(0.0, -0.33, -0.05)
	left_knee_cap.scale = Vector3(1.0, 0.8, 0.6)
	left_leg_upper.add_child(left_knee_cap)

	var left_leg_lower: Node3D = Node3D.new()
	left_leg_lower.name = "LeftLegLower"
	left_leg_lower.position = Vector3(0.0, -0.33, 0.0)
	left_leg_upper.add_child(left_leg_lower)

	# Shin
	var lll_mesh: MeshInstance3D = _capsule("LLL_Mesh", 0.07, 0.34, COL_MAIN, true)
	lll_mesh.position = Vector3(0.0, -0.14, 0.0)
	left_leg_lower.add_child(lll_mesh)

	# Shin guard (front plate)
	var lll_guard: MeshInstance3D = _box("LLL_Guard", Vector3(0.08, 0.22, 0.06), COL_PLATE, true)
	lll_guard.position = Vector3(0.0, -0.12, -0.05)
	left_leg_lower.add_child(lll_guard)

	# Shin energy strip
	var lll_strip: MeshInstance3D = _box("LLL_Strip", Vector3(0.02, 0.16, 0.015), COL_ENERGY, false, true, 1.5)
	lll_strip.position = Vector3(0.0, -0.12, -0.08)
	left_leg_lower.add_child(lll_strip)

	# Left boot (heavy armored)
	var left_boot_main: MeshInstance3D = _box("LeftBootMain", Vector3(0.12, 0.12, 0.18), COL_BOOT_PLATE, true)
	left_boot_main.position = Vector3(0.0, -0.34, -0.02)
	left_leg_lower.add_child(left_boot_main)

	# Boot sole
	var left_sole: MeshInstance3D = _box("LeftBootSole", Vector3(0.13, 0.035, 0.2), COL_BOOT, true)
	left_sole.position = Vector3(0.0, -0.39, -0.02)
	left_leg_lower.add_child(left_sole)

	# Boot toe cap
	var left_toe: MeshInstance3D = _box("LeftToeCap", Vector3(0.1, 0.06, 0.04), COL_PLATE, true)
	left_toe.position = Vector3(0.0, -0.36, -0.1)
	left_leg_lower.add_child(left_toe)

	# Ankle energy band
	var left_ankle: MeshInstance3D = _torus("LeftAnkle", 0.07, 0.012, COL_ENERGY, false, true, 1.5)
	left_ankle.position = Vector3(0.0, -0.28, 0.0)
	left_leg_lower.add_child(left_ankle)

	# ── RIGHT LEG ───────────────────────────────────────────────────────
	var right_leg_upper: Node3D = Node3D.new()
	right_leg_upper.name = "RightLegUpper"
	right_leg_upper.position = Vector3(0.13, 0.8, 0.0)
	root.add_child(right_leg_upper)

	var rlu_under: MeshInstance3D = _capsule("RLU_Under", 0.085, 0.36, COL_UNDERSUIT, false)
	rlu_under.position = Vector3(0.0, -0.14, 0.0)
	right_leg_upper.add_child(rlu_under)

	var rlu_plate: MeshInstance3D = _box("RLU_Plate", Vector3(0.12, 0.2, 0.09), COL_PLATE, true)
	rlu_plate.position = Vector3(0.0, -0.12, -0.04)
	right_leg_upper.add_child(rlu_plate)

	var rlu_side: MeshInstance3D = _box("RLU_Side", Vector3(0.04, 0.16, 0.1), COL_PLATE_EDGE, true)
	rlu_side.position = Vector3(0.08, -0.14, 0.0)
	right_leg_upper.add_child(rlu_side)

	var right_knee: MeshInstance3D = _sphere("RightKnee", 0.065, COL_JOINT, true)
	right_knee.position = Vector3(0.0, -0.33, 0.0)
	right_leg_upper.add_child(right_knee)

	var right_knee_cap: MeshInstance3D = _sphere("RightKneeCap", 0.05, COL_PLATE, true)
	right_knee_cap.position = Vector3(0.0, -0.33, -0.05)
	right_knee_cap.scale = Vector3(1.0, 0.8, 0.6)
	right_leg_upper.add_child(right_knee_cap)

	var right_leg_lower: Node3D = Node3D.new()
	right_leg_lower.name = "RightLegLower"
	right_leg_lower.position = Vector3(0.0, -0.33, 0.0)
	right_leg_upper.add_child(right_leg_lower)

	var rll_mesh: MeshInstance3D = _capsule("RLL_Mesh", 0.07, 0.34, COL_MAIN, true)
	rll_mesh.position = Vector3(0.0, -0.14, 0.0)
	right_leg_lower.add_child(rll_mesh)

	var rll_guard: MeshInstance3D = _box("RLL_Guard", Vector3(0.08, 0.22, 0.06), COL_PLATE, true)
	rll_guard.position = Vector3(0.0, -0.12, -0.05)
	right_leg_lower.add_child(rll_guard)

	var rll_strip: MeshInstance3D = _box("RLL_Strip", Vector3(0.02, 0.16, 0.015), COL_ENERGY, false, true, 1.5)
	rll_strip.position = Vector3(0.0, -0.12, -0.08)
	right_leg_lower.add_child(rll_strip)

	var right_boot_main: MeshInstance3D = _box("RightBootMain", Vector3(0.12, 0.12, 0.18), COL_BOOT_PLATE, true)
	right_boot_main.position = Vector3(0.0, -0.34, -0.02)
	right_leg_lower.add_child(right_boot_main)

	var right_sole: MeshInstance3D = _box("RightBootSole", Vector3(0.13, 0.035, 0.2), COL_BOOT, true)
	right_sole.position = Vector3(0.0, -0.39, -0.02)
	right_leg_lower.add_child(right_sole)

	var right_toe: MeshInstance3D = _box("RightToeCap", Vector3(0.1, 0.06, 0.04), COL_PLATE, true)
	right_toe.position = Vector3(0.0, -0.36, -0.1)
	right_leg_lower.add_child(right_toe)

	var right_ankle: MeshInstance3D = _torus("RightAnkle", 0.07, 0.012, COL_ENERGY, false, true, 1.5)
	right_ankle.position = Vector3(0.0, -0.28, 0.0)
	right_leg_lower.add_child(right_ankle)

	# ── BACKPACK / POWER PACK ──────────────────────────────────────────
	# Main housing
	var bp_main: MeshInstance3D = _box("BackpackMain", Vector3(0.28, 0.34, 0.14), COL_BACKPACK, true)
	bp_main.position = Vector3(0.0, 1.1, 0.2)
	root.add_child(bp_main)

	# Power pack top cap
	var bp_top: MeshInstance3D = _box("BackpackTop", Vector3(0.24, 0.04, 0.12), COL_PLATE, true)
	bp_top.position = Vector3(0.0, 1.29, 0.2)
	root.add_child(bp_top)

	# Power pack bottom vent
	var bp_bottom: MeshInstance3D = _box("BackpackBottom", Vector3(0.24, 0.03, 0.12), COL_PLATE, true)
	bp_bottom.position = Vector3(0.0, 0.92, 0.2)
	root.add_child(bp_bottom)

	# Central energy window on backpack
	var bp_core: MeshInstance3D = _box("BackpackCore", Vector3(0.14, 0.12, 0.02), COL_ENERGY, false, true, 3.0)
	bp_core.position = Vector3(0.0, 1.12, 0.28)
	root.add_child(bp_core)

	# Thruster vents (bottom corners of backpack)
	for side_x in [-1.0, 1.0]:
		var thruster: MeshInstance3D = _cylinder("Thruster", 0.04, 0.08, COL_JOINT, true)
		thruster.position = Vector3(side_x * 0.1, 0.9, 0.22)
		root.add_child(thruster)

		var thruster_glow: MeshInstance3D = _cylinder("ThrusterGlow", 0.025, 0.02, COL_THRUSTER, false, true, 3.0)
		thruster_glow.position = Vector3(side_x * 0.1, 0.855, 0.22)
		root.add_child(thruster_glow)

	# Antenna assembly (right side of backpack)
	var antenna_base: MeshInstance3D = _cylinder("AntennaBase", 0.025, 0.06, COL_JOINT, true)
	antenna_base.position = Vector3(0.1, 1.33, 0.2)
	root.add_child(antenna_base)

	var antenna_rod: MeshInstance3D = _cylinder("AntennaRod", 0.008, 0.2, COL_ANTENNA, true)
	antenna_rod.position = Vector3(0.1, 1.46, 0.2)
	root.add_child(antenna_rod)

	var antenna_tip: MeshInstance3D = _sphere("AntennaTip", 0.018, COL_ENERGY_HOT, false, true, 4.0)
	antenna_tip.position = Vector3(0.1, 1.57, 0.2)
	root.add_child(antenna_tip)

	# Secondary antenna (left side, shorter)
	var antenna2_rod: MeshInstance3D = _cylinder("Antenna2Rod", 0.006, 0.12, COL_ANTENNA, true)
	antenna2_rod.position = Vector3(-0.08, 1.38, 0.2)
	root.add_child(antenna2_rod)

	var antenna2_tip: MeshInstance3D = _sphere("Antenna2Tip", 0.012, COL_ENERGY, false, true, 3.0)
	antenna2_tip.position = Vector3(-0.08, 1.45, 0.2)
	root.add_child(antenna2_tip)

	# Shoulder straps connecting backpack to front (left/right)
	for side_x in [-1.0, 1.0]:
		var strap: MeshInstance3D = _box("Strap", Vector3(0.04, 0.35, 0.03), COL_MAIN, true)
		strap.position = Vector3(side_x * 0.14, 1.12, 0.05)
		strap.rotation.z = side_x * deg_to_rad(5.0)
		root.add_child(strap)

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
	root.set_meta("bp_core", bp_core)
	root.set_meta("antenna_tip", antenna_tip)
	root.set_meta("antenna2_tip", antenna2_tip)

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

	# Energy core pulse (chest)
	var energy_core: MeshInstance3D = root.get_meta("energy_core") as MeshInstance3D
	if energy_core:
		var pulse: float = 0.9 + sin(phase * 3.0) * 0.15
		energy_core.scale = Vector3(pulse, pulse, pulse)

	# Backpack energy window pulse (offset phase)
	if root.has_meta("bp_core"):
		var bp_core: MeshInstance3D = root.get_meta("bp_core") as MeshInstance3D
		if bp_core and bp_core.mesh:
			var bp_mat: StandardMaterial3D = bp_core.get_surface_override_material(0) as StandardMaterial3D
			if bp_mat:
				bp_mat.emission_energy_multiplier = 2.5 + sin(phase * 2.5 + 1.0) * 1.0

	# Antenna tips flicker
	if root.has_meta("antenna_tip"):
		var atip: MeshInstance3D = root.get_meta("antenna_tip") as MeshInstance3D
		if atip and atip.mesh:
			var atip_mat: StandardMaterial3D = atip.get_surface_override_material(0) as StandardMaterial3D
			if atip_mat:
				atip_mat.emission_energy_multiplier = 3.0 + sin(phase * 5.0) * 1.5

	# Visor subtle brightness shift
	var visor: MeshInstance3D = root.get_meta("visor") as MeshInstance3D
	if visor and visor.mesh:
		var mat: StandardMaterial3D = visor.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.0 + sin(phase * 2.0) * 0.6


## Attack animation — swings the right arm forward in a punching/striking motion.
## `phase` goes from 0.0 to 1.0 over the attack duration.
## 0.0-0.3: wind up (arm pulls back), 0.3-0.6: strike (arm thrusts forward),
## 0.6-1.0: recover (arm returns to neutral).
static func animate_attack(root: Node3D, phase: float) -> void:
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	var right_arm_lower: Node3D = root.get_meta("right_arm_lower") as Node3D
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var left_arm_lower: Node3D = root.get_meta("left_arm_lower") as Node3D
	var head_group: Node3D = root.get_meta("head_group") as Node3D

	# Attack phases
	var arm_x: float = 0.0  # Forward/back rotation
	var arm_z: float = 0.0  # Outward spread
	var elbow_bend: float = 0.0
	var torso_lean: float = 0.0

	if phase < 0.3:
		# Wind up — pull right arm back, bend elbow
		var t: float = phase / 0.3
		arm_x = lerpf(0.0, -0.8, t)       # Pull back (positive = back in arm space)
		arm_z = lerpf(0.0, -0.15, t)      # Slight outward
		elbow_bend = lerpf(0.0, -0.9, t)  # Bend elbow
		torso_lean = lerpf(0.0, -0.1, t)  # Lean back slightly
	elif phase < 0.6:
		# Strike — thrust arm forward hard
		var t: float = (phase - 0.3) / 0.3
		arm_x = lerpf(-0.8, 1.2, t)       # Swing forward past center
		arm_z = lerpf(-0.15, 0.1, t)      # Pull inward
		elbow_bend = lerpf(-0.9, -0.2, t) # Straighten elbow
		torso_lean = lerpf(-0.1, 0.15, t) # Lean forward
	else:
		# Recover — return to neutral
		var t: float = (phase - 0.6) / 0.4
		arm_x = lerpf(1.2, 0.0, t)
		arm_z = lerpf(0.1, 0.0, t)
		elbow_bend = lerpf(-0.2, 0.0, t)
		torso_lean = lerpf(0.15, 0.0, t)

	# Apply right arm (attacking arm)
	if right_arm_upper:
		right_arm_upper.rotation.x = arm_x
		right_arm_upper.rotation.z = arm_z
	if right_arm_lower:
		right_arm_lower.rotation.x = elbow_bend

	# Left arm — slight guard position during strike
	var guard: float = clampf(1.0 - phase * 2.0, 0.0, 1.0)
	if left_arm_upper:
		left_arm_upper.rotation.x = lerpf(0.0, 0.3, guard)
		left_arm_upper.rotation.z = lerpf(0.0, 0.2, guard)
	if left_arm_lower:
		left_arm_lower.rotation.x = lerpf(0.0, -0.5, guard)

	# Torso lean forward during strike
	if head_group:
		head_group.position.y = 1.65 + torso_lean * 0.08

	# Legs stay planted but front foot steps forward slightly
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	if phase < 0.6:
		var step: float = sin(phase / 0.6 * PI) * 0.15
		if right_leg_upper:
			right_leg_upper.rotation.x = -step  # Right foot steps forward with punch
		if left_leg_upper:
			left_leg_upper.rotation.x = step * 0.3  # Left leg braces
	else:
		if right_leg_upper:
			right_leg_upper.rotation.x = 0.0
		if left_leg_upper:
			left_leg_upper.rotation.x = 0.0


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
		mat.metallic = 0.65
		mat.metallic_specular = 0.5
		mat.roughness = 0.3
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
