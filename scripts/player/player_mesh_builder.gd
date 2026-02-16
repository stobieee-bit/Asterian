## PlayerMeshBuilder — Constructs a highly detailed sci-fi power-armored character
## from MeshInstance3D primitives. All positions relative to feet at y=0.
##
## The character is a sleek, modern exosuit pilot with sculpted musculature
## visible through a form-fitting nano-weave suit, overlaid with contoured
## composite armor plating, integrated energy conduits, a swept-back helmet
## with panoramic visor, and a compact fusion reactor backpack.
##
## Inspired by modern RPG character aesthetics — realistic proportions,
## layered materials, strong silhouette, glowing energy accents.
##
## Usage:
##   var root: Node3D = PlayerMeshBuilder.build_player_mesh()
##   add_child(root)
##   PlayerMeshBuilder.animate_walk(root, phase, speed)
##   PlayerMeshBuilder.animate_idle(root, phase)
class_name PlayerMeshBuilder
extends RefCounted

# ── Colour palette ──────────────────────────────────────────────────────────
# Base suit layers
const COL_SKIN: Color = Color(0.08, 0.09, 0.12)             # Near-black nano-weave base
const COL_SUIT: Color = Color(0.12, 0.16, 0.24)             # Dark blue-grey bodysuit
const COL_SUIT_LIGHT: Color = Color(0.16, 0.21, 0.32)       # Lighter suit accents

# Armor plating
const COL_PLATE: Color = Color(0.25, 0.30, 0.40)            # Matte gunmetal armor
const COL_PLATE_HI: Color = Color(0.32, 0.38, 0.50)         # Highlighted armor edges
const COL_PLATE_DARK: Color = Color(0.18, 0.22, 0.30)       # Shadowed armor recesses

# Energy / glow
const COL_ENERGY: Color = Color(0.0, 0.85, 0.65)            # Primary teal energy
const COL_ENERGY_BRIGHT: Color = Color(0.1, 1.0, 0.8)       # Bright energy highlights
const COL_VISOR: Color = Color(0.12, 0.7, 1.0)              # Cyan HUD visor
const COL_REACTOR: Color = Color(0.0, 0.95, 0.85)           # Reactor core glow

# Accents
const COL_JOINT: Color = Color(0.04, 0.04, 0.06)            # Ultra-dark flex joints
const COL_TRIM: Color = Color(0.55, 0.42, 0.12)             # Subtle gold trim
const COL_BOOT: Color = Color(0.07, 0.07, 0.09)             # Boot base
const COL_THRUSTER: Color = Color(0.95, 0.45, 0.08)         # Thruster exhaust orange
const COL_ANTENNA: Color = Color(0.5, 0.5, 0.55)            # Metallic antenna
const COL_BACKPACK: Color = Color(0.13, 0.17, 0.25)         # Reactor housing

# ── Head position constant for animations ──
const HEAD_Y: float = 1.62

# ═══════════════════════════════════════════════════════════════════════════
#  STYLE THEMES — distinct colour palettes per combat style
# ═══════════════════════════════════════════════════════════════════════════

## Each theme maps semantic slot names to colors. apply_style_theme() walks
## every MeshInstance3D child and recolors based on which slot it belongs to.

static func _get_style_theme(style: String) -> Dictionary:
	match style:
		"nano":
			# Cool cyan/teal — stealthy tech operative
			return {
				"suit": Color(0.1, 0.14, 0.22),
				"suit_light": Color(0.14, 0.19, 0.3),
				"plate": Color(0.22, 0.28, 0.4),
				"plate_hi": Color(0.3, 0.36, 0.5),
				"plate_dark": Color(0.15, 0.2, 0.3),
				"energy": Color(0.0, 0.85, 0.65),
				"energy_bright": Color(0.1, 1.0, 0.8),
				"visor": Color(0.12, 0.7, 1.0),
				"reactor": Color(0.0, 0.95, 0.85),
				"trim": Color(0.4, 0.55, 0.6),
				"thruster": Color(0.0, 0.8, 0.6),
			}
		"tesla":
			# Crackling gold/amber — high-voltage shock trooper
			return {
				"suit": Color(0.14, 0.1, 0.06),
				"suit_light": Color(0.2, 0.16, 0.08),
				"plate": Color(0.38, 0.3, 0.14),
				"plate_hi": Color(0.5, 0.4, 0.18),
				"plate_dark": Color(0.25, 0.2, 0.1),
				"energy": Color(1.0, 0.85, 0.1),
				"energy_bright": Color(1.0, 0.95, 0.3),
				"visor": Color(1.0, 0.8, 0.15),
				"reactor": Color(1.0, 0.9, 0.2),
				"trim": Color(0.7, 0.55, 0.1),
				"thruster": Color(1.0, 0.7, 0.1),
			}
		"void":
			# Deep violet/magenta — reality-warping psion
			return {
				"suit": Color(0.1, 0.06, 0.16),
				"suit_light": Color(0.16, 0.1, 0.24),
				"plate": Color(0.28, 0.15, 0.4),
				"plate_hi": Color(0.38, 0.22, 0.52),
				"plate_dark": Color(0.18, 0.1, 0.28),
				"energy": Color(0.6, 0.15, 0.95),
				"energy_bright": Color(0.75, 0.3, 1.0),
				"visor": Color(0.55, 0.15, 0.9),
				"reactor": Color(0.7, 0.2, 1.0),
				"trim": Color(0.45, 0.2, 0.6),
				"thruster": Color(0.5, 0.1, 0.8),
			}
		_:
			# Fallback — neutral grey
			return {
				"suit": Color(0.12, 0.12, 0.14),
				"suit_light": Color(0.18, 0.18, 0.2),
				"plate": Color(0.3, 0.3, 0.32),
				"plate_hi": Color(0.4, 0.4, 0.42),
				"plate_dark": Color(0.2, 0.2, 0.22),
				"energy": Color(0.5, 0.5, 0.5),
				"energy_bright": Color(0.7, 0.7, 0.7),
				"visor": Color(0.5, 0.5, 0.6),
				"reactor": Color(0.6, 0.6, 0.65),
				"trim": Color(0.4, 0.4, 0.4),
				"thruster": Color(0.5, 0.5, 0.5),
			}


## Map a mesh's original material color to a semantic slot name.
## Returns empty string if the mesh shouldn't be recolored.
static func _color_to_slot(color: Color) -> String:
	# Use approximate matching (within tolerance) to map original build colors to slots
	if _color_close(color, COL_SUIT): return "suit"
	if _color_close(color, COL_SUIT_LIGHT): return "suit_light"
	if _color_close(color, COL_PLATE): return "plate"
	if _color_close(color, COL_PLATE_HI): return "plate_hi"
	if _color_close(color, COL_PLATE_DARK): return "plate_dark"
	if _color_close(color, COL_ENERGY): return "energy"
	if _color_close(color, COL_ENERGY_BRIGHT): return "energy_bright"
	if _color_close(color, COL_VISOR): return "visor"
	if _color_close(color, COL_REACTOR): return "reactor"
	if _color_close(color, COL_TRIM): return "trim"
	if _color_close(color, COL_THRUSTER): return "thruster"
	return ""


static func _color_close(a: Color, b: Color, tol: float = 0.05) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol


## Apply a combat style color theme to an already-built mesh root.
## First call tags each mesh with its semantic slot (via metadata).
## Subsequent calls use the stored slot tag to recolor correctly.
static func apply_style_theme(root: Node3D, style: String) -> void:
	var theme: Dictionary = _get_style_theme(style)
	if theme.is_empty():
		return
	var needs_tagging: bool = not root.has_meta("_style_tagged")
	_apply_theme_recursive(root, theme, needs_tagging)
	if needs_tagging:
		root.set_meta("_style_tagged", true)


static func _apply_theme_recursive(node: Node, theme: Dictionary, tag: bool) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var mat: StandardMaterial3D = mi.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			mat = mi.material_override as StandardMaterial3D
		if mat != null:
			var slot: String = ""
			# Use stored slot tag if available, otherwise detect from original color
			if mi.has_meta("_color_slot"):
				slot = str(mi.get_meta("_color_slot"))
			else:
				slot = _color_to_slot(mat.albedo_color)
				if slot != "" and tag:
					mi.set_meta("_color_slot", slot)
			if slot != "" and theme.has(slot):
				var new_col: Color = theme[slot] as Color
				var alpha: float = mat.albedo_color.a
				mat.albedo_color = new_col
				mat.albedo_color.a = alpha
				if mat.emission_enabled:
					mat.emission = new_col
	for child in node.get_children():
		_apply_theme_recursive(child, theme, tag)


# ═══════════════════════════════════════════════════════════════════════════
#  BUILD
# ═══════════════════════════════════════════════════════════════════════════

static func build_player_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PowerArmorMesh"

	# ══════════════════════════════════════════════════════════════════════
	#  HEAD & HELMET
	# ══════════════════════════════════════════════════════════════════════
	var head_group: Node3D = Node3D.new()
	head_group.name = "HeadGroup"
	head_group.position = Vector3(0.0, HEAD_Y, 0.0)
	root.add_child(head_group)

	# Skull base — elongated sphere for realistic head shape
	var skull: MeshInstance3D = _sphere("Skull", 0.17, COL_SUIT, true)
	skull.scale = Vector3(0.95, 1.08, 1.0)
	head_group.add_child(skull)

	# Outer helmet shell — swept-back aerodynamic shape
	var helmet_main: MeshInstance3D = _sphere("HelmetMain", 0.21, COL_PLATE, true)
	helmet_main.position = Vector3(0.0, 0.02, 0.02)
	helmet_main.scale = Vector3(1.0, 1.0, 1.12)
	head_group.add_child(helmet_main)

	# Helmet top ridge — sharp central crest
	var crest: MeshInstance3D = _box("Crest", Vector3(0.03, 0.025, 0.26), COL_PLATE_HI, true)
	crest.position = Vector3(0.0, 0.19, 0.02)
	head_group.add_child(crest)

	# Crest energy line
	var crest_glow: MeshInstance3D = _box("CrestGlow", Vector3(0.012, 0.012, 0.22), COL_ENERGY, false, true, 2.5)
	crest_glow.position = Vector3(0.0, 0.205, 0.02)
	head_group.add_child(crest_glow)

	# Panoramic visor — wide curved faceplate
	var visor: MeshInstance3D = _sphere("Visor", 0.18, COL_VISOR, false, true, 3.0)
	visor.position = Vector3(0.0, -0.01, -0.06)
	visor.scale = Vector3(0.85, 0.42, 0.45)
	head_group.add_child(visor)

	# Visor frame — top brow ridge
	var brow: MeshInstance3D = _box("BrowRidge", Vector3(0.30, 0.025, 0.1), COL_PLATE_HI, true)
	brow.position = Vector3(0.0, 0.065, -0.14)
	head_group.add_child(brow)

	# Visor frame — cheek guards
	for side_x in [-1.0, 1.0]:
		var cheek: MeshInstance3D = _box("CheekGuard", Vector3(0.035, 0.09, 0.08), COL_PLATE, true)
		cheek.position = Vector3(side_x * 0.16, -0.02, -0.1)
		head_group.add_child(cheek)

	# Chin / jaw guard — angled protective plate
	var jaw: MeshInstance3D = _box("JawGuard", Vector3(0.18, 0.05, 0.12), COL_PLATE_DARK, true)
	jaw.position = Vector3(0.0, -0.1, -0.08)
	head_group.add_child(jaw)

	# Breather vents on jaw
	for side_x in [-1.0, 1.0]:
		var vent: MeshInstance3D = _box("JawVent", Vector3(0.04, 0.025, 0.03), COL_JOINT, true)
		vent.position = Vector3(side_x * 0.06, -0.1, -0.15)
		head_group.add_child(vent)

	# Helmet side panels
	for side_x in [-1.0, 1.0]:
		var side_panel: MeshInstance3D = _box("SidePanel", Vector3(0.02, 0.1, 0.14), COL_PLATE, true)
		side_panel.position = Vector3(side_x * 0.2, 0.0, 0.02)
		head_group.add_child(side_panel)

		# Ear comm module
		var comm: MeshInstance3D = _cylinder("CommModule", 0.03, 0.025, COL_PLATE_HI, true)
		comm.position = Vector3(side_x * 0.22, 0.0, 0.0)
		comm.rotation.z = deg_to_rad(90.0)
		head_group.add_child(comm)

		# Side energy strip
		var side_glow: MeshInstance3D = _box("SideGlow", Vector3(0.008, 0.06, 0.02), COL_ENERGY, false, true, 2.0)
		side_glow.position = Vector3(side_x * 0.215, -0.01, -0.04)
		head_group.add_child(side_glow)

	# Rear helmet — neck guard extension
	var rear_guard: MeshInstance3D = _box("RearGuard", Vector3(0.16, 0.06, 0.06), COL_PLATE, true)
	rear_guard.position = Vector3(0.0, -0.06, 0.16)
	head_group.add_child(rear_guard)

	# Rear energy strip
	var rear_glow: MeshInstance3D = _box("RearGlow", Vector3(0.1, 0.012, 0.015), COL_ENERGY, false, true, 2.0)
	rear_glow.position = Vector3(0.0, 0.06, 0.19)
	head_group.add_child(rear_glow)

	# ══════════════════════════════════════════════════════════════════════
	#  NECK
	# ══════════════════════════════════════════════════════════════════════
	var neck: MeshInstance3D = _capsule("Neck", 0.065, 0.18, COL_SKIN, false)
	neck.position = Vector3(0.0, 1.47, 0.0)
	root.add_child(neck)

	# Armored neck collar — layered rings
	var collar_inner: MeshInstance3D = _torus("CollarInner", 0.1, 0.02, COL_SUIT, true)
	collar_inner.position = Vector3(0.0, 1.43, 0.0)
	root.add_child(collar_inner)

	var collar_outer: MeshInstance3D = _torus("CollarOuter", 0.13, 0.025, COL_PLATE, true)
	collar_outer.position = Vector3(0.0, 1.4, 0.0)
	root.add_child(collar_outer)

	# ══════════════════════════════════════════════════════════════════════
	#  TORSO — muscular build with layered armor
	# ══════════════════════════════════════════════════════════════════════

	# Inner bodysuit torso
	var torso_inner: MeshInstance3D = _capsule("TorsoInner", 0.22, 0.52, COL_SKIN, false)
	torso_inner.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(torso_inner)

	# Broad chest undersuit — slightly wider, tapered
	var chest_base: MeshInstance3D = _capsule("ChestBase", 0.25, 0.35, COL_SUIT, true)
	chest_base.position = Vector3(0.0, 1.18, 0.0)
	chest_base.scale = Vector3(1.1, 0.85, 0.9)
	root.add_child(chest_base)

	# Front chest plate — contoured pectoral armor
	var chest_plate_l: MeshInstance3D = _sphere("ChestPlateL", 0.13, COL_PLATE, true)
	chest_plate_l.position = Vector3(-0.1, 1.18, -0.1)
	chest_plate_l.scale = Vector3(0.9, 0.75, 0.45)
	root.add_child(chest_plate_l)

	var chest_plate_r: MeshInstance3D = _sphere("ChestPlateR", 0.13, COL_PLATE, true)
	chest_plate_r.position = Vector3(0.1, 1.18, -0.1)
	chest_plate_r.scale = Vector3(0.9, 0.75, 0.45)
	root.add_child(chest_plate_r)

	# Central chest divider
	var chest_center: MeshInstance3D = _box("ChestCenter", Vector3(0.025, 0.22, 0.06), COL_PLATE_DARK, true)
	chest_center.position = Vector3(0.0, 1.18, -0.12)
	root.add_child(chest_center)

	# Upper chest collar plate
	var upper_chest: MeshInstance3D = _box("UpperChest", Vector3(0.32, 0.05, 0.1), COL_PLATE_HI, true)
	upper_chest.position = Vector3(0.0, 1.32, -0.08)
	root.add_child(upper_chest)

	# Energy core — glowing reactor on chest
	var energy_core: MeshInstance3D = _sphere("EnergyCore", 0.04, COL_REACTOR, false, true, 6.0)
	energy_core.position = Vector3(0.0, 1.15, -0.16)
	root.add_child(energy_core)

	# Core housing ring
	var core_ring: MeshInstance3D = _torus("CoreRing", 0.045, 0.012, COL_PLATE_HI, true)
	core_ring.position = Vector3(0.0, 1.15, -0.16)
	core_ring.rotation.x = deg_to_rad(90.0)
	root.add_child(core_ring)

	# Core outer ring
	var core_ring2: MeshInstance3D = _torus("CoreRing2", 0.06, 0.008, COL_PLATE, true)
	core_ring2.position = Vector3(0.0, 1.15, -0.16)
	core_ring2.rotation.x = deg_to_rad(90.0)
	root.add_child(core_ring2)

	# Abdominal section — segmented plates
	for i in range(3):
		var y_off: float = 0.96 - float(i) * 0.06
		var w: float = 0.26 - float(i) * 0.01
		var ab_seg: MeshInstance3D = _box("AbSeg%d" % i, Vector3(w, 0.045, 0.08), COL_PLATE, true)
		ab_seg.position = Vector3(0.0, y_off, -0.08)
		root.add_child(ab_seg)

	# Side torso — muscle contour panels
	for side_x in [-1.0, 1.0]:
		var side_torso: MeshInstance3D = _box("SideTorso", Vector3(0.04, 0.26, 0.15), COL_SUIT_LIGHT, true)
		side_torso.position = Vector3(side_x * 0.22, 1.1, 0.0)
		root.add_child(side_torso)

		# Side energy conduit — thin glowing line
		var conduit: MeshInstance3D = _capsule("SideConduit", 0.012, 0.22, COL_ENERGY, false, true, 1.5)
		conduit.position = Vector3(side_x * 0.25, 1.1, -0.04)
		root.add_child(conduit)

	# Back plate — broad and layered
	var back_plate: MeshInstance3D = _box("BackPlate", Vector3(0.32, 0.28, 0.06), COL_PLATE, true)
	back_plate.position = Vector3(0.0, 1.14, 0.12)
	root.add_child(back_plate)

	var back_detail: MeshInstance3D = _box("BackDetail", Vector3(0.2, 0.16, 0.02), COL_PLATE_HI, true)
	back_detail.position = Vector3(0.0, 1.18, 0.155)
	root.add_child(back_detail)

	# ══════════════════════════════════════════════════════════════════════
	#  BELT / WAIST
	# ══════════════════════════════════════════════════════════════════════
	var belt_main: MeshInstance3D = _torus("BeltMain", 0.2, 0.03, COL_PLATE, true)
	belt_main.position = Vector3(0.0, 0.83, 0.0)
	root.add_child(belt_main)

	var belt_inner: MeshInstance3D = _torus("BeltInner", 0.19, 0.015, COL_SUIT, true)
	belt_inner.position = Vector3(0.0, 0.85, 0.0)
	root.add_child(belt_inner)

	# Belt buckle — gold accent
	var buckle: MeshInstance3D = _box("Buckle", Vector3(0.08, 0.05, 0.04), COL_TRIM, true, true, 0.8)
	buckle.position = Vector3(0.0, 0.83, -0.18)
	root.add_child(buckle)

	# Utility pouches
	for side_x in [-1.0, 1.0]:
		var pouch: MeshInstance3D = _box("Pouch", Vector3(0.05, 0.055, 0.04), COL_SUIT, true)
		pouch.position = Vector3(side_x * 0.17, 0.83, -0.12)
		root.add_child(pouch)

		var pouch_flap: MeshInstance3D = _box("PouchFlap", Vector3(0.05, 0.015, 0.042), COL_PLATE_DARK, true)
		pouch_flap.position = Vector3(side_x * 0.17, 0.86, -0.12)
		root.add_child(pouch_flap)

	# Hip armor plates
	for side_x in [-1.0, 1.0]:
		var hip_plate: MeshInstance3D = _box("HipPlate", Vector3(0.08, 0.1, 0.1), COL_PLATE, true)
		hip_plate.position = Vector3(side_x * 0.18, 0.8, 0.0)
		root.add_child(hip_plate)

	# ══════════════════════════════════════════════════════════════════════
	#  SHOULDERS — sculpted pauldrons
	# ══════════════════════════════════════════════════════════════════════
	for side_x in [-1.0, 1.0]:
		var side_name: String = "L" if side_x < 0 else "R"

		# Layered pauldron — rounded contour
		var pauldron: MeshInstance3D = _sphere(side_name + "Pauldron", 0.11, COL_PLATE, true)
		pauldron.position = Vector3(side_x * 0.3, 1.32, 0.0)
		pauldron.scale = Vector3(1.15, 0.55, 1.0)
		root.add_child(pauldron)

		# Pauldron ridge
		var p_ridge: MeshInstance3D = _box(side_name + "PauldronRidge", Vector3(0.12, 0.02, 0.1), COL_PLATE_HI, true)
		p_ridge.position = Vector3(side_x * 0.3, 1.35, 0.0)
		root.add_child(p_ridge)

		# Pauldron energy accent
		var p_glow: MeshInstance3D = _box(side_name + "PauldronGlow", Vector3(0.08, 0.008, 0.06), COL_ENERGY, false, true, 2.0)
		p_glow.position = Vector3(side_x * 0.3, 1.34, -0.02)
		root.add_child(p_glow)

		# Pauldron lower trim
		var p_trim: MeshInstance3D = _box(side_name + "PauldronTrim", Vector3(0.1, 0.015, 0.08), COL_TRIM, true, true, 0.5)
		p_trim.position = Vector3(side_x * 0.3, 1.28, 0.0)
		root.add_child(p_trim)

	# ══════════════════════════════════════════════════════════════════════
	#  LEFT ARM
	# ══════════════════════════════════════════════════════════════════════
	var left_arm_upper: Node3D = Node3D.new()
	left_arm_upper.name = "LeftArmUpper"
	left_arm_upper.position = Vector3(-0.3, 1.24, 0.0)
	root.add_child(left_arm_upper)

	# Bicep undersuit
	var lua_under: MeshInstance3D = _capsule("LUA_Under", 0.06, 0.28, COL_SKIN, false)
	lua_under.position = Vector3(0.0, -0.11, 0.0)
	left_arm_upper.add_child(lua_under)

	# Bicep muscle layer
	var lua_muscle: MeshInstance3D = _capsule("LUA_Muscle", 0.065, 0.22, COL_SUIT, true)
	lua_muscle.position = Vector3(0.0, -0.08, 0.0)
	left_arm_upper.add_child(lua_muscle)

	# Upper arm armor — contoured plate
	var lua_plate: MeshInstance3D = _box("LUA_Plate", Vector3(0.085, 0.16, 0.07), COL_PLATE, true)
	lua_plate.position = Vector3(-0.02, -0.09, 0.0)
	left_arm_upper.add_child(lua_plate)

	# Bicep energy strip
	var lua_glow: MeshInstance3D = _box("LUA_Glow", Vector3(0.008, 0.12, 0.015), COL_ENERGY, false, true, 1.5)
	lua_glow.position = Vector3(-0.05, -0.09, -0.02)
	left_arm_upper.add_child(lua_glow)

	# Elbow joint — articulated
	var left_elbow: MeshInstance3D = _sphere("LeftElbow", 0.048, COL_JOINT, true)
	left_elbow.position = Vector3(0.0, -0.25, 0.0)
	left_arm_upper.add_child(left_elbow)

	var left_elbow_cap: MeshInstance3D = _sphere("LeftElbowCap", 0.035, COL_PLATE, true)
	left_elbow_cap.position = Vector3(-0.025, -0.25, 0.02)
	left_arm_upper.add_child(left_elbow_cap)

	# Lower arm
	var left_arm_lower: Node3D = Node3D.new()
	left_arm_lower.name = "LeftArmLower"
	left_arm_lower.position = Vector3(0.0, -0.25, 0.0)
	left_arm_upper.add_child(left_arm_lower)

	# Forearm
	var lla_mesh: MeshInstance3D = _capsule("LLA_Mesh", 0.05, 0.24, COL_SUIT, true)
	lla_mesh.position = Vector3(0.0, -0.1, 0.0)
	left_arm_lower.add_child(lla_mesh)

	# Vambrace — contoured forearm armor
	var lla_vambrace: MeshInstance3D = _box("LLA_Vambrace", Vector3(0.07, 0.14, 0.065), COL_PLATE, true)
	lla_vambrace.position = Vector3(-0.01, -0.08, 0.0)
	left_arm_lower.add_child(lla_vambrace)

	# Vambrace detail
	var lla_detail: MeshInstance3D = _box("LLA_Detail", Vector3(0.05, 0.06, 0.02), COL_PLATE_HI, true)
	lla_detail.position = Vector3(-0.01, -0.06, -0.04)
	left_arm_lower.add_child(lla_detail)

	# Wrist energy band
	var left_wrist: MeshInstance3D = _torus("LeftWrist", 0.045, 0.012, COL_ENERGY, false, true, 2.0)
	left_wrist.position = Vector3(0.0, -0.2, 0.0)
	left_arm_lower.add_child(left_wrist)

	# Gauntlet hand — articulated fingers suggested
	var left_hand: MeshInstance3D = _box("LeftHand", Vector3(0.05, 0.06, 0.07), COL_PLATE, true)
	left_hand.position = Vector3(0.0, -0.25, 0.0)
	left_arm_lower.add_child(left_hand)

	var left_fingers: MeshInstance3D = _box("LeftFingers", Vector3(0.04, 0.035, 0.06), COL_SUIT, true)
	left_fingers.position = Vector3(0.0, -0.28, -0.01)
	left_arm_lower.add_child(left_fingers)

	# ══════════════════════════════════════════════════════════════════════
	#  RIGHT ARM
	# ══════════════════════════════════════════════════════════════════════
	var right_arm_upper: Node3D = Node3D.new()
	right_arm_upper.name = "RightArmUpper"
	right_arm_upper.position = Vector3(0.3, 1.24, 0.0)
	root.add_child(right_arm_upper)

	var rua_under: MeshInstance3D = _capsule("RUA_Under", 0.06, 0.28, COL_SKIN, false)
	rua_under.position = Vector3(0.0, -0.11, 0.0)
	right_arm_upper.add_child(rua_under)

	var rua_muscle: MeshInstance3D = _capsule("RUA_Muscle", 0.065, 0.22, COL_SUIT, true)
	rua_muscle.position = Vector3(0.0, -0.08, 0.0)
	right_arm_upper.add_child(rua_muscle)

	var rua_plate: MeshInstance3D = _box("RUA_Plate", Vector3(0.085, 0.16, 0.07), COL_PLATE, true)
	rua_plate.position = Vector3(0.02, -0.09, 0.0)
	right_arm_upper.add_child(rua_plate)

	var rua_glow: MeshInstance3D = _box("RUA_Glow", Vector3(0.008, 0.12, 0.015), COL_ENERGY, false, true, 1.5)
	rua_glow.position = Vector3(0.05, -0.09, -0.02)
	right_arm_upper.add_child(rua_glow)

	var right_elbow: MeshInstance3D = _sphere("RightElbow", 0.048, COL_JOINT, true)
	right_elbow.position = Vector3(0.0, -0.25, 0.0)
	right_arm_upper.add_child(right_elbow)

	var right_elbow_cap: MeshInstance3D = _sphere("RightElbowCap", 0.035, COL_PLATE, true)
	right_elbow_cap.position = Vector3(0.025, -0.25, 0.02)
	right_arm_upper.add_child(right_elbow_cap)

	var right_arm_lower: Node3D = Node3D.new()
	right_arm_lower.name = "RightArmLower"
	right_arm_lower.position = Vector3(0.0, -0.25, 0.0)
	right_arm_upper.add_child(right_arm_lower)

	var rla_mesh: MeshInstance3D = _capsule("RLA_Mesh", 0.05, 0.24, COL_SUIT, true)
	rla_mesh.position = Vector3(0.0, -0.1, 0.0)
	right_arm_lower.add_child(rla_mesh)

	var rla_vambrace: MeshInstance3D = _box("RLA_Vambrace", Vector3(0.07, 0.14, 0.065), COL_PLATE, true)
	rla_vambrace.position = Vector3(0.01, -0.08, 0.0)
	right_arm_lower.add_child(rla_vambrace)

	var rla_detail: MeshInstance3D = _box("RLA_Detail", Vector3(0.05, 0.06, 0.02), COL_PLATE_HI, true)
	rla_detail.position = Vector3(0.01, -0.06, -0.04)
	right_arm_lower.add_child(rla_detail)

	var right_wrist: MeshInstance3D = _torus("RightWrist", 0.045, 0.012, COL_ENERGY, false, true, 2.0)
	right_wrist.position = Vector3(0.0, -0.2, 0.0)
	right_arm_lower.add_child(right_wrist)

	var right_hand: MeshInstance3D = _box("RightHand", Vector3(0.05, 0.06, 0.07), COL_PLATE, true)
	right_hand.position = Vector3(0.0, -0.25, 0.0)
	right_arm_lower.add_child(right_hand)

	var right_fingers: MeshInstance3D = _box("RightFingers", Vector3(0.04, 0.035, 0.06), COL_SUIT, true)
	right_fingers.position = Vector3(0.0, -0.28, -0.01)
	right_arm_lower.add_child(right_fingers)

	# ══════════════════════════════════════════════════════════════════════
	#  LEFT LEG
	# ══════════════════════════════════════════════════════════════════════
	var left_leg_upper: Node3D = Node3D.new()
	left_leg_upper.name = "LeftLegUpper"
	left_leg_upper.position = Vector3(-0.12, 0.79, 0.0)
	root.add_child(left_leg_upper)

	# Thigh undersuit — muscular contour
	var llu_under: MeshInstance3D = _capsule("LLU_Under", 0.08, 0.34, COL_SKIN, false)
	llu_under.position = Vector3(0.0, -0.13, 0.0)
	left_leg_upper.add_child(llu_under)

	var llu_muscle: MeshInstance3D = _capsule("LLU_Muscle", 0.082, 0.26, COL_SUIT, true)
	llu_muscle.position = Vector3(0.0, -0.1, 0.0)
	left_leg_upper.add_child(llu_muscle)

	# Thigh front plate
	var llu_plate: MeshInstance3D = _box("LLU_Plate", Vector3(0.1, 0.18, 0.07), COL_PLATE, true)
	llu_plate.position = Vector3(0.0, -0.11, -0.04)
	left_leg_upper.add_child(llu_plate)

	# Thigh side plate
	var llu_side: MeshInstance3D = _box("LLU_Side", Vector3(0.03, 0.14, 0.08), COL_PLATE_HI, true)
	llu_side.position = Vector3(-0.07, -0.12, 0.0)
	left_leg_upper.add_child(llu_side)

	# Thigh energy line
	var llu_glow: MeshInstance3D = _box("LLU_Glow", Vector3(0.008, 0.14, 0.015), COL_ENERGY, false, true, 1.5)
	llu_glow.position = Vector3(-0.075, -0.12, -0.02)
	left_leg_upper.add_child(llu_glow)

	# Knee joint
	var left_knee: MeshInstance3D = _sphere("LeftKnee", 0.055, COL_JOINT, true)
	left_knee.position = Vector3(0.0, -0.31, 0.0)
	left_leg_upper.add_child(left_knee)

	var left_knee_cap: MeshInstance3D = _sphere("LeftKneeCap", 0.04, COL_PLATE, true)
	left_knee_cap.position = Vector3(0.0, -0.31, -0.04)
	left_knee_cap.scale = Vector3(1.0, 0.8, 0.6)
	left_leg_upper.add_child(left_knee_cap)

	# Lower leg
	var left_leg_lower: Node3D = Node3D.new()
	left_leg_lower.name = "LeftLegLower"
	left_leg_lower.position = Vector3(0.0, -0.31, 0.0)
	left_leg_upper.add_child(left_leg_lower)

	# Shin
	var lll_mesh: MeshInstance3D = _capsule("LLL_Mesh", 0.06, 0.32, COL_SUIT, true)
	lll_mesh.position = Vector3(0.0, -0.13, 0.0)
	left_leg_lower.add_child(lll_mesh)

	# Shin guard — contoured plate
	var lll_guard: MeshInstance3D = _box("LLL_Guard", Vector3(0.07, 0.2, 0.05), COL_PLATE, true)
	lll_guard.position = Vector3(0.0, -0.1, -0.04)
	left_leg_lower.add_child(lll_guard)

	# Shin energy strip
	var lll_glow: MeshInstance3D = _box("LLL_Glow", Vector3(0.015, 0.15, 0.012), COL_ENERGY, false, true, 1.5)
	lll_glow.position = Vector3(0.0, -0.1, -0.07)
	left_leg_lower.add_child(lll_glow)

	# Calf plate
	var lll_calf: MeshInstance3D = _box("LLL_Calf", Vector3(0.06, 0.14, 0.04), COL_PLATE_DARK, true)
	lll_calf.position = Vector3(0.0, -0.1, 0.04)
	left_leg_lower.add_child(lll_calf)

	# Ankle energy band
	var left_ankle: MeshInstance3D = _torus("LeftAnkle", 0.06, 0.01, COL_ENERGY, false, true, 1.5)
	left_ankle.position = Vector3(0.0, -0.27, 0.0)
	left_leg_lower.add_child(left_ankle)

	# Boot — armored, realistic sole
	var left_boot: MeshInstance3D = _box("LeftBoot", Vector3(0.1, 0.1, 0.16), COL_PLATE_DARK, true)
	left_boot.position = Vector3(0.0, -0.33, -0.01)
	left_leg_lower.add_child(left_boot)

	var left_sole: MeshInstance3D = _box("LeftSole", Vector3(0.11, 0.03, 0.18), COL_BOOT, true)
	left_sole.position = Vector3(0.0, -0.375, -0.01)
	left_leg_lower.add_child(left_sole)

	var left_toe: MeshInstance3D = _box("LeftToe", Vector3(0.08, 0.04, 0.03), COL_PLATE, true)
	left_toe.position = Vector3(0.0, -0.35, -0.09)
	left_leg_lower.add_child(left_toe)

	# ══════════════════════════════════════════════════════════════════════
	#  RIGHT LEG
	# ══════════════════════════════════════════════════════════════════════
	var right_leg_upper: Node3D = Node3D.new()
	right_leg_upper.name = "RightLegUpper"
	right_leg_upper.position = Vector3(0.12, 0.79, 0.0)
	root.add_child(right_leg_upper)

	var rlu_under: MeshInstance3D = _capsule("RLU_Under", 0.08, 0.34, COL_SKIN, false)
	rlu_under.position = Vector3(0.0, -0.13, 0.0)
	right_leg_upper.add_child(rlu_under)

	var rlu_muscle: MeshInstance3D = _capsule("RLU_Muscle", 0.082, 0.26, COL_SUIT, true)
	rlu_muscle.position = Vector3(0.0, -0.1, 0.0)
	right_leg_upper.add_child(rlu_muscle)

	var rlu_plate: MeshInstance3D = _box("RLU_Plate", Vector3(0.1, 0.18, 0.07), COL_PLATE, true)
	rlu_plate.position = Vector3(0.0, -0.11, -0.04)
	right_leg_upper.add_child(rlu_plate)

	var rlu_side: MeshInstance3D = _box("RLU_Side", Vector3(0.03, 0.14, 0.08), COL_PLATE_HI, true)
	rlu_side.position = Vector3(0.07, -0.12, 0.0)
	right_leg_upper.add_child(rlu_side)

	var rlu_glow: MeshInstance3D = _box("RLU_Glow", Vector3(0.008, 0.14, 0.015), COL_ENERGY, false, true, 1.5)
	rlu_glow.position = Vector3(0.075, -0.12, -0.02)
	right_leg_upper.add_child(rlu_glow)

	var right_knee: MeshInstance3D = _sphere("RightKnee", 0.055, COL_JOINT, true)
	right_knee.position = Vector3(0.0, -0.31, 0.0)
	right_leg_upper.add_child(right_knee)

	var right_knee_cap: MeshInstance3D = _sphere("RightKneeCap", 0.04, COL_PLATE, true)
	right_knee_cap.position = Vector3(0.0, -0.31, -0.04)
	right_knee_cap.scale = Vector3(1.0, 0.8, 0.6)
	right_leg_upper.add_child(right_knee_cap)

	var right_leg_lower: Node3D = Node3D.new()
	right_leg_lower.name = "RightLegLower"
	right_leg_lower.position = Vector3(0.0, -0.31, 0.0)
	right_leg_upper.add_child(right_leg_lower)

	var rll_mesh: MeshInstance3D = _capsule("RLL_Mesh", 0.06, 0.32, COL_SUIT, true)
	rll_mesh.position = Vector3(0.0, -0.13, 0.0)
	right_leg_lower.add_child(rll_mesh)

	var rll_guard: MeshInstance3D = _box("RLL_Guard", Vector3(0.07, 0.2, 0.05), COL_PLATE, true)
	rll_guard.position = Vector3(0.0, -0.1, -0.04)
	right_leg_lower.add_child(rll_guard)

	var rll_glow: MeshInstance3D = _box("RLL_Glow", Vector3(0.015, 0.15, 0.012), COL_ENERGY, false, true, 1.5)
	rll_glow.position = Vector3(0.0, -0.1, -0.07)
	right_leg_lower.add_child(rll_glow)

	var rll_calf: MeshInstance3D = _box("RLL_Calf", Vector3(0.06, 0.14, 0.04), COL_PLATE_DARK, true)
	rll_calf.position = Vector3(0.0, -0.1, 0.04)
	right_leg_lower.add_child(rll_calf)

	var right_ankle: MeshInstance3D = _torus("RightAnkle", 0.06, 0.01, COL_ENERGY, false, true, 1.5)
	right_ankle.position = Vector3(0.0, -0.27, 0.0)
	right_leg_lower.add_child(right_ankle)

	var right_boot: MeshInstance3D = _box("RightBoot", Vector3(0.1, 0.1, 0.16), COL_PLATE_DARK, true)
	right_boot.position = Vector3(0.0, -0.33, -0.01)
	right_leg_lower.add_child(right_boot)

	var right_sole: MeshInstance3D = _box("RightSole", Vector3(0.11, 0.03, 0.18), COL_BOOT, true)
	right_sole.position = Vector3(0.0, -0.375, -0.01)
	right_leg_lower.add_child(right_sole)

	var right_toe: MeshInstance3D = _box("RightToe", Vector3(0.08, 0.04, 0.03), COL_PLATE, true)
	right_toe.position = Vector3(0.0, -0.35, -0.09)
	right_leg_lower.add_child(right_toe)

	# ══════════════════════════════════════════════════════════════════════
	#  BACKPACK — compact fusion reactor
	# ══════════════════════════════════════════════════════════════════════
	# Main housing — rounded box
	var bp_main: MeshInstance3D = _box("BackpackMain", Vector3(0.24, 0.3, 0.12), COL_BACKPACK, true)
	bp_main.position = Vector3(0.0, 1.1, 0.19)
	root.add_child(bp_main)

	# Top cap
	var bp_top: MeshInstance3D = _box("BackpackTop", Vector3(0.22, 0.03, 0.1), COL_PLATE, true)
	bp_top.position = Vector3(0.0, 1.27, 0.19)
	root.add_child(bp_top)

	# Bottom vent
	var bp_bottom: MeshInstance3D = _box("BackpackBottom", Vector3(0.22, 0.025, 0.1), COL_PLATE, true)
	bp_bottom.position = Vector3(0.0, 0.93, 0.19)
	root.add_child(bp_bottom)

	# Reactor core window — bright glow
	var bp_core: MeshInstance3D = _box("BackpackCore", Vector3(0.12, 0.1, 0.015), COL_REACTOR, false, true, 4.0)
	bp_core.position = Vector3(0.0, 1.12, 0.26)
	root.add_child(bp_core)

	# Core frame
	var bp_frame: MeshInstance3D = _box("BackpackFrame", Vector3(0.14, 0.12, 0.01), COL_PLATE_HI, true)
	bp_frame.position = Vector3(0.0, 1.12, 0.255)
	root.add_child(bp_frame)

	# Heat vents — side exhaust
	for side_x in [-1.0, 1.0]:
		var vent_housing: MeshInstance3D = _box("VentHousing", Vector3(0.03, 0.08, 0.08), COL_PLATE_DARK, true)
		vent_housing.position = Vector3(side_x * 0.13, 1.0, 0.2)
		root.add_child(vent_housing)

		var vent_glow: MeshInstance3D = _box("VentGlow", Vector3(0.015, 0.05, 0.04), COL_THRUSTER, false, true, 2.5)
		vent_glow.position = Vector3(side_x * 0.14, 1.0, 0.2)
		root.add_child(vent_glow)

	# Thruster nozzles — bottom
	for side_x in [-1.0, 1.0]:
		var thruster: MeshInstance3D = _cylinder("Thruster", 0.035, 0.06, COL_JOINT, true)
		thruster.position = Vector3(side_x * 0.08, 0.9, 0.2)
		root.add_child(thruster)

		var thruster_glow: MeshInstance3D = _cylinder("ThrusterGlow", 0.02, 0.015, COL_THRUSTER, false, true, 3.5)
		thruster_glow.position = Vector3(side_x * 0.08, 0.865, 0.2)
		root.add_child(thruster_glow)

	# Antenna — right side
	var antenna_base: MeshInstance3D = _cylinder("AntennaBase", 0.02, 0.04, COL_JOINT, true)
	antenna_base.position = Vector3(0.09, 1.31, 0.19)
	root.add_child(antenna_base)

	var antenna_rod: MeshInstance3D = _cylinder("AntennaRod", 0.006, 0.18, COL_ANTENNA, true)
	antenna_rod.position = Vector3(0.09, 1.43, 0.19)
	root.add_child(antenna_rod)

	var antenna_tip: MeshInstance3D = _sphere("AntennaTip", 0.015, COL_ENERGY_BRIGHT, false, true, 5.0)
	antenna_tip.position = Vector3(0.09, 1.53, 0.19)
	root.add_child(antenna_tip)

	# Secondary antenna — left side, shorter
	var antenna2_rod: MeshInstance3D = _cylinder("Antenna2Rod", 0.004, 0.1, COL_ANTENNA, true)
	antenna2_rod.position = Vector3(-0.07, 1.35, 0.19)
	root.add_child(antenna2_rod)

	var antenna2_tip: MeshInstance3D = _sphere("Antenna2Tip", 0.01, COL_ENERGY, false, true, 3.0)
	antenna2_tip.position = Vector3(-0.07, 1.41, 0.19)
	root.add_child(antenna2_tip)

	# Shoulder straps
	for side_x in [-1.0, 1.0]:
		var strap: MeshInstance3D = _box("Strap", Vector3(0.035, 0.3, 0.025), COL_SUIT, true)
		strap.position = Vector3(side_x * 0.12, 1.12, 0.05)
		strap.rotation.z = side_x * deg_to_rad(4.0)
		root.add_child(strap)

	# ══════════════════════════════════════════════════════════════════════
	#  STORE ANIMATABLE PART REFERENCES IN META
	# ══════════════════════════════════════════════════════════════════════
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
		head_group.position.y = HEAD_Y + absf(sin(phase * 2.0)) * 0.015 * intensity


## Idle animation — gentle breathing bob, slight arm sway, energy core pulse.
## `phase` should increase by delta each frame (slow continuous counter).
static func animate_idle(root: Node3D, phase: float) -> void:
	var breath: float = sin(phase * 1.5) * 0.008
	var sway: float = sin(phase * 0.8) * 0.03

	# Head bob from breathing
	var head_group: Node3D = root.get_meta("head_group") as Node3D
	if head_group:
		head_group.position.y = HEAD_Y + breath

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
				bp_mat.emission_energy_multiplier = 3.0 + sin(phase * 2.5 + 1.0) * 1.5

	# Antenna tips flicker
	if root.has_meta("antenna_tip"):
		var atip: MeshInstance3D = root.get_meta("antenna_tip") as MeshInstance3D
		if atip and atip.mesh:
			var atip_mat: StandardMaterial3D = atip.get_surface_override_material(0) as StandardMaterial3D
			if atip_mat:
				atip_mat.emission_energy_multiplier = 3.5 + sin(phase * 5.0) * 2.0

	# Visor subtle brightness shift
	var visor: MeshInstance3D = root.get_meta("visor") as MeshInstance3D
	if visor and visor.mesh:
		var mat: StandardMaterial3D = visor.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.5 + sin(phase * 2.0) * 0.8


## Style-specific attack animation. Each style has its own distinct motion:
## - Nano: fast precision dual-stab — both arms thrust forward in quick succession
## - Tesla: wide horizontal arc swing — heavy overhead-to-side cleave
## - Void: channeled force push — arms extend outward, body floats back
static func animate_attack(root: Node3D, phase: float, style: String = "nano") -> void:
	match style:
		"tesla":
			_animate_attack_tesla(root, phase)
		"void":
			_animate_attack_void(root, phase)
		_:
			_animate_attack_nano(root, phase)


## Nano: fast precision dual-stab — quick alternating thrusts, tight and surgical
static func _animate_attack_nano(root: Node3D, phase: float) -> void:
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	var right_arm_lower: Node3D = root.get_meta("right_arm_lower") as Node3D
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var left_arm_lower: Node3D = root.get_meta("left_arm_lower") as Node3D
	var head_group: Node3D = root.get_meta("head_group") as Node3D

	var r_arm_x: float = 0.0
	var r_elbow: float = 0.0
	var l_arm_x: float = 0.0
	var l_elbow: float = 0.0
	var torso_lean: float = 0.0

	if phase < 0.2:
		# Quick windup — pull right arm back
		var t: float = phase / 0.2
		r_arm_x = lerpf(0.0, -0.6, t)
		r_elbow = lerpf(0.0, -0.8, t)
		torso_lean = lerpf(0.0, -0.06, t)
	elif phase < 0.4:
		# Right stab forward
		var t: float = (phase - 0.2) / 0.2
		r_arm_x = lerpf(-0.6, 1.0, t)
		r_elbow = lerpf(-0.8, -0.1, t)
		l_arm_x = lerpf(0.0, -0.4, t)  # Left arm prepares
		l_elbow = lerpf(0.0, -0.7, t)
		torso_lean = lerpf(-0.06, 0.1, t)
	elif phase < 0.6:
		# Left stab forward (right recovers)
		var t: float = (phase - 0.4) / 0.2
		r_arm_x = lerpf(1.0, 0.2, t)
		r_elbow = lerpf(-0.1, -0.3, t)
		l_arm_x = lerpf(-0.4, 0.9, t)
		l_elbow = lerpf(-0.7, -0.1, t)
		torso_lean = lerpf(0.1, 0.12, t)
	else:
		# Recover both arms
		var t: float = (phase - 0.6) / 0.4
		r_arm_x = lerpf(0.2, 0.0, t)
		r_elbow = lerpf(-0.3, 0.0, t)
		l_arm_x = lerpf(0.9, 0.0, t)
		l_elbow = lerpf(-0.1, 0.0, t)
		torso_lean = lerpf(0.12, 0.0, t)

	if right_arm_upper:
		right_arm_upper.rotation.x = r_arm_x
		right_arm_upper.rotation.z = -0.05
	if right_arm_lower:
		right_arm_lower.rotation.x = r_elbow
	if left_arm_upper:
		left_arm_upper.rotation.x = l_arm_x
		left_arm_upper.rotation.z = 0.05
	if left_arm_lower:
		left_arm_lower.rotation.x = l_elbow
	if head_group:
		head_group.position.y = HEAD_Y + torso_lean * 0.08

	# Small forward step
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	if phase < 0.6:
		var step: float = sin(phase / 0.6 * PI) * 0.12
		if right_leg_upper:
			right_leg_upper.rotation.x = -step
		if left_leg_upper:
			left_leg_upper.rotation.x = step * 0.5
	else:
		if right_leg_upper:
			right_leg_upper.rotation.x = 0.0
		if left_leg_upper:
			left_leg_upper.rotation.x = 0.0


## Tesla: heavy arc swing — wide overhead cleave that sweeps across
static func _animate_attack_tesla(root: Node3D, phase: float) -> void:
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	var right_arm_lower: Node3D = root.get_meta("right_arm_lower") as Node3D
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var left_arm_lower: Node3D = root.get_meta("left_arm_lower") as Node3D
	var head_group: Node3D = root.get_meta("head_group") as Node3D

	var arm_x: float = 0.0
	var arm_z: float = 0.0
	var elbow_bend: float = 0.0
	var torso_lean: float = 0.0
	var torso_twist: float = 0.0

	if phase < 0.35:
		# Wind up — raise arm overhead and twist body back
		var t: float = phase / 0.35
		arm_x = lerpf(0.0, -1.4, t)       # Arm goes way up/back
		arm_z = lerpf(0.0, -0.4, t)       # Wide outward swing
		elbow_bend = lerpf(0.0, -0.6, t)  # Bent elbow
		torso_lean = lerpf(0.0, -0.15, t) # Lean back
		torso_twist = lerpf(0.0, -0.2, t) # Twist right shoulder back
	elif phase < 0.6:
		# Swing down and across — heavy arc
		var t: float = (phase - 0.35) / 0.25
		arm_x = lerpf(-1.4, 0.8, t)       # Swing down through center
		arm_z = lerpf(-0.4, 0.5, t)       # Sweep across body
		elbow_bend = lerpf(-0.6, -0.15, t)# Straighten through impact
		torso_lean = lerpf(-0.15, 0.2, t) # Lean forward into swing
		torso_twist = lerpf(-0.2, 0.3, t) # Twist through
	else:
		# Follow-through and recover
		var t: float = (phase - 0.6) / 0.4
		arm_x = lerpf(0.8, 0.0, t)
		arm_z = lerpf(0.5, 0.0, t)
		elbow_bend = lerpf(-0.15, 0.0, t)
		torso_lean = lerpf(0.2, 0.0, t)
		torso_twist = lerpf(0.3, 0.0, t)

	if right_arm_upper:
		right_arm_upper.rotation.x = arm_x
		right_arm_upper.rotation.z = arm_z
	if right_arm_lower:
		right_arm_lower.rotation.x = elbow_bend

	# Left arm braces across body
	if left_arm_upper:
		var brace: float = clampf(sin(phase * PI), 0.0, 1.0)
		left_arm_upper.rotation.x = lerpf(0.0, 0.5, brace)
		left_arm_upper.rotation.z = lerpf(0.0, -0.3, brace)
	if left_arm_lower:
		var brace: float = clampf(sin(phase * PI), 0.0, 1.0)
		left_arm_lower.rotation.x = lerpf(0.0, -0.6, brace)

	if head_group:
		head_group.position.y = HEAD_Y + torso_lean * 0.08
		head_group.rotation.y = torso_twist * 0.5

	# Strong forward lunge step
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	if phase < 0.6:
		var step: float = sin(phase / 0.6 * PI) * 0.25
		if right_leg_upper:
			right_leg_upper.rotation.x = -step
		if left_leg_upper:
			left_leg_upper.rotation.x = step * 0.4
	else:
		var t: float = (phase - 0.6) / 0.4
		if right_leg_upper:
			right_leg_upper.rotation.x = lerpf(-0.05, 0.0, t)
		if left_leg_upper:
			left_leg_upper.rotation.x = lerpf(0.02, 0.0, t)


## Void: channeled force push — both arms extend outward, body leans back slightly
static func _animate_attack_void(root: Node3D, phase: float) -> void:
	var right_arm_upper: Node3D = root.get_meta("right_arm_upper") as Node3D
	var right_arm_lower: Node3D = root.get_meta("right_arm_lower") as Node3D
	var left_arm_upper: Node3D = root.get_meta("left_arm_upper") as Node3D
	var left_arm_lower: Node3D = root.get_meta("left_arm_lower") as Node3D
	var head_group: Node3D = root.get_meta("head_group") as Node3D

	var arm_fwd: float = 0.0    # Both arms push forward symmetrically
	var arm_spread: float = 0.0 # Arms spread outward
	var elbow: float = 0.0
	var torso_lean: float = 0.0

	if phase < 0.25:
		# Channel — arms pull inward, body crouches slightly
		var t: float = phase / 0.25
		arm_fwd = lerpf(0.0, -0.3, t)
		arm_spread = lerpf(0.0, 0.25, t)
		elbow = lerpf(0.0, -0.8, t)      # Arms bent close
		torso_lean = lerpf(0.0, -0.08, t) # Slight lean back
	elif phase < 0.5:
		# Release — arms thrust forward and outward
		var t: float = (phase - 0.25) / 0.25
		arm_fwd = lerpf(-0.3, 0.9, t)
		arm_spread = lerpf(0.25, -0.35, t) # Spread wide during push
		elbow = lerpf(-0.8, -0.05, t)      # Arms straighten fully
		torso_lean = lerpf(-0.08, 0.1, t)
	elif phase < 0.7:
		# Hold — arms extended, channeling
		var t: float = (phase - 0.5) / 0.2
		arm_fwd = lerpf(0.9, 0.85, t)
		arm_spread = lerpf(-0.35, -0.3, t)
		elbow = lerpf(-0.05, -0.08, t)
		torso_lean = lerpf(0.1, 0.08, t)
	else:
		# Recover
		var t: float = (phase - 0.7) / 0.3
		arm_fwd = lerpf(0.85, 0.0, t)
		arm_spread = lerpf(-0.3, 0.0, t)
		elbow = lerpf(-0.08, 0.0, t)
		torso_lean = lerpf(0.08, 0.0, t)

	# Both arms move symmetrically
	if right_arm_upper:
		right_arm_upper.rotation.x = arm_fwd
		right_arm_upper.rotation.z = arm_spread
	if right_arm_lower:
		right_arm_lower.rotation.x = elbow
	if left_arm_upper:
		left_arm_upper.rotation.x = arm_fwd
		left_arm_upper.rotation.z = -arm_spread
	if left_arm_lower:
		left_arm_lower.rotation.x = elbow

	if head_group:
		head_group.position.y = HEAD_Y + torso_lean * 0.08

	# Legs: slight wide stance, no step (ranged attack)
	var left_leg_upper: Node3D = root.get_meta("left_leg_upper") as Node3D
	var right_leg_upper: Node3D = root.get_meta("right_leg_upper") as Node3D
	var stance: float = sin(phase * PI) * 0.06
	if left_leg_upper:
		left_leg_upper.rotation.z = stance
	if right_leg_upper:
		right_leg_upper.rotation.z = -stance


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
		head_group.position.y = HEAD_Y
		head_group.rotation = Vector3.ZERO
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
		mat.metallic = 0.7
		mat.metallic_specular = 0.55
		mat.roughness = 0.25
	else:
		mat.roughness = 0.45
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	if color == COL_VISOR:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.65
	return mat


static func _sphere(node_name: String, radius: float, color: Color,
		metallic: bool = false, emissive: bool = false,
		emission_strength: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
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
	mesh.radial_segments = 16
	mesh.rings = 6
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
	mesh.radial_segments = 16
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
