## AreaManager — Builds a richly detailed 3D sci-fi world from JSON area data
##
## Reads AREAS and CORRIDORS from DataManager and generates:
## - Ground discs for each area (MeshInstance3D via PrimitiveMesh) with layered detail
## - Corridor ground boxes with guide lights and wall structures
## - Environmental props: energy pylons, tech panels, alien flora, crystals,
##   floating debris, light columns, pipe structures, ruined walls, platforms
## - Per-area unique structures (landing pads, hive arches, void pillars, etc.)
## - Scattered OmniLight3D for rich local lighting
## - Animated elements (rotating rings, pulsing lights, hovering objects)
## - Area labels, collision bodies, fog/atmosphere per area
##
## All walkable ground sits at Y = 0. Visual meshes use tiny Y offsets
## and render_priority to prevent z-fighting between overlapping areas.
extends Node3D

## The single Y position for ALL walkable collision surfaces.
const GROUND_Y: float = -0.1

# ── References ──
@onready var world_env: WorldEnvironment = $"../WorldEnvironment"

# ── Terrain (removed Terrain3D — using flat ground + navmesh) ──

# ── Area collision detection ──
var _area_bodies: Dictionary = {}   # { area_id: { center: Vector3, radius: float } }
var _player: CharacterBody3D = null

# ── Materials cache ──
var _ground_materials: Dictionary = {}

# ── Animated elements ──
var _animated_nodes: Array[Dictionary] = []   # { node, type, speed, base_y, phase }
var _time: float = 0.0

func _ready() -> void:
	add_to_group("area_manager")
	_add_fallback_ground()
	_build_areas()
	_build_corridors()
	_build_corridor_gates()
	_add_area_boundaries()
	_add_safety_floor()
	_setup_enhanced_glow()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

## Public API: query terrain height at any world XZ position.
## Returns 0.0 (flat ground plane). Override or extend for elevation.
func get_terrain_height(_x: float, _z: float) -> float:
	return 0.0

## Internal shorthand for prop placement.
func _terrain_y(_x: float, _z: float) -> float:
	return 0.0

## Add a visible ground plane with collision at y=0.
func _add_fallback_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "FallbackGround"
	body.collision_layer = 1

	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000.0, 0.5, 2000.0)
	col.shape = shape
	body.add_child(col)

	# Visible mesh — large flat plane with subtle sci-fi feel
	var mesh_inst := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(2000.0, 2000.0)
	plane_mesh.subdivide_width = 4
	plane_mesh.subdivide_depth = 4
	mesh_inst.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.08, 0.12, 1.0)  # Dark blue-gray sci-fi ground
	mat.roughness = 0.85
	mat.metallic = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.015, 0.02, 0.04)
	mat.emission_energy_multiplier = 0.2
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	body.position = Vector3(0, -0.25, 0)  # Mesh surface at y=0
	add_child(body)
	print("AreaManager: Fallback ground plane added at y=0")

## Add a colored ground disc per area.
func _add_area_ground_disc(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, floor_y: float) -> void:
	# Outer disc — area base color
	var disc := MeshInstance3D.new()
	disc.name = "GroundDisc_%s" % area_id
	var _disc_mesh := CylinderMesh.new()
	_disc_mesh.top_radius = radius
	_disc_mesh.bottom_radius = radius
	_disc_mesh.height = 0.15
	_disc_mesh.radial_segments = 16
	disc.mesh = _disc_mesh
	disc.position = Vector3(cx, floor_y + 0.08, cz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.8
	mat.metallic = 0.1
	mat.emission_enabled = true
	mat.emission = base_color.darkened(0.5)
	mat.emission_energy_multiplier = 0.15
	disc.material_override = mat
	add_child(disc)

	# Inner disc — lighter center for visual depth
	var inner := MeshInstance3D.new()
	inner.name = "GroundDiscInner_%s" % area_id
	var inner_r: float = radius * 0.7
	var _inner_mesh := CylinderMesh.new()
	_inner_mesh.top_radius = inner_r
	_inner_mesh.bottom_radius = inner_r
	_inner_mesh.height = 0.16
	_inner_mesh.radial_segments = 16
	inner.mesh = _inner_mesh
	inner.position = Vector3(cx, floor_y + 0.09, cz)
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = base_color.lightened(0.08)
	inner_mat.roughness = 0.75
	inner_mat.metallic = 0.12
	inner.material_override = inner_mat
	add_child(inner)

var _gate_update_timer: float = 0.0
var _area_check_timer: float = 0.0  # Throttle area transition checks
var _rejected_gates: Dictionary = {}  # { area_id: true } — tracks which gates already messaged

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	# Throttle area transition checks to 10 Hz (not every frame)
	_area_check_timer += delta
	if _area_check_timer >= 0.1:
		_area_check_timer = 0.0
		_check_area_transition()
	_animate_world(delta)
	# Update gate barrier colors every 2 seconds (not every frame)
	_gate_update_timer += delta
	if _gate_update_timer >= 2.0:
		_gate_update_timer = 0.0
		_update_gate_barriers()

# ═══════════════════════════════════════════════════════════════════════════════
#  WORLD BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func _build_areas() -> void:
	var loaded_count: int = 0
	var built_count: int = 0
	for area_id in DataManager.areas:
		var data: Dictionary = DataManager.areas[area_id]
		# Always register area body for detection (needed even if loading a scene)
		var cx: float = float(data.get("center", {}).get("x", 0.0))
		var cz: float = float(data.get("center", {}).get("z", 0.0))
		var radius: float = data.get("radius", 50.0)
		var floor_y: float = float(data.get("floorY", 0.0))
		_area_bodies[area_id] = { "center": Vector3(cx, floor_y, cz), "radius": radius }
		# Try loading baked scene
		var scene_path: String = "res://scenes/areas/%s.tscn" % area_id
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			if scene:
				var instance: Node3D = scene.instantiate()
				add_child(instance)
				loaded_count += 1
				continue
		# Fallback: procedural building
		_create_area_ground(area_id, data)
		built_count += 1
	print("AreaManager: %d areas loaded from scenes, %d built procedurally" % [loaded_count, built_count])

func _create_area_ground(area_id: String, data: Dictionary) -> void:
	var center_x: float = float(data.get("center", {}).get("x", 0.0))
	var center_z: float = float(data.get("center", {}).get("z", 0.0))
	var radius: float = data.get("radius", 50.0)
	var ground_color_int: int = int(data.get("groundColor", 0x1a2030))
	var floor_y: float = float(data.get("floorY", 0.0))

	# _area_bodies is now registered in _build_areas() before scene loading
	if not _area_bodies.has(area_id):
		var logical_center: Vector3 = Vector3(center_x, floor_y, center_z)
		_area_bodies[area_id] = { "center": logical_center, "radius": radius }

	var base_color: Color = _hex_to_color(ground_color_int)

	# ── Area ground disc ──
	_add_area_ground_disc(area_id, center_x, center_z, radius, base_color, floor_y)

	# ── Area label (terrain-relative, with subtle pole) ──
	var label_y: float = _terrain_y(center_x, center_z) + 8.0
	var label: Label3D = Label3D.new()
	label.name = "Label_%s" % area_id
	label.text = data.get("name", area_id)
	label.position = Vector3(center_x, label_y, center_z)
	label.font_size = 72
	label.outline_size = 10
	label.modulate = Color(0.7, 1.0, 0.9, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	# Holographic sign pole
	var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.3, 0.5, 0.6, 0.4)
	pole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sign_pole: MeshInstance3D = MeshInstance3D.new()
	var _pole_mesh := CylinderMesh.new()
	_pole_mesh.top_radius = 0.04
	_pole_mesh.bottom_radius = 0.04
	_pole_mesh.height = 8.0
	_pole_mesh.radial_segments = 16
	sign_pole.mesh = _pole_mesh
	sign_pole.material_override = pole_mat
	sign_pole.position = Vector3(center_x, _terrain_y(center_x, center_z) + 4.0, center_z)
	add_child(sign_pole)

	# y_base kept for compatibility with decoration functions (they'll use _terrain_y internally)
	var y_base: float = floor_y

	# ── Build all detail layers ──
	# Bio-Lab and Station Hub are structured hubs — skip random clutter to avoid
	# clipping with hand-placed structures (shops, landing pad, control tower, etc.)
	var _is_clean_area: bool = area_id == "bio-lab" or area_id == "station-hub"

	# Ground variation, terrain bumps, concentric rings, grid lines are all replaced
	# by the procedural terrain mesh (noise height + vertex colors)
	if not _is_clean_area:
		_add_rocks_and_boulders(area_id, center_x, center_z, radius, base_color, y_base)
		_add_energy_pylons(area_id, center_x, center_z, radius, base_color, y_base)
		_add_tech_panels(area_id, center_x, center_z, radius, base_color, y_base)
		_add_light_columns(area_id, center_x, center_z, radius, base_color, y_base)
	_add_crystals(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_clean_area:
		_add_alien_flora(area_id, center_x, center_z, radius, base_color, y_base)
		_add_pipe_structures(area_id, center_x, center_z, radius, base_color, y_base)
	_add_ruined_walls(area_id, center_x, center_z, radius, base_color, y_base)
	_add_area_unique_structures(area_id, center_x, center_z, radius, base_color, y_base)
	_add_point_lights(area_id, center_x, center_z, radius, base_color, y_base)

	# ── Edge atmosphere — subtle glow ring at terrain boundaries ──
	_add_edge_atmosphere(area_id, center_x, center_z, radius, base_color, floor_y)

# ═══════════════════════════════════════════════════════════════════════════════
#  EDGE ATMOSPHERE — subtle glow ring at terrain boundaries
# ═══════════════════════════════════════════════════════════════════════════════

## Adds a ring of faint glowing fog at the terrain edge to mask the hard boundary.
## Uses a MeshInstance3D + TorusMesh with a semi-transparent emissive material.
func _add_edge_atmosphere(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, floor_y: float) -> void:
	# Skip very small areas (like bio-lab) — edges aren't visible
	if radius < 25.0:
		return

	var edge_y: float = _terrain_y(cx + radius * 0.85, cz) if radius < 100.0 \
		else floor_y

	# Outer fog ring — thin, very faint glow at terrain edge
	var fog_ring: MeshInstance3D = MeshInstance3D.new()
	var ir: float = radius * 0.97
	var or_: float = radius * 1.01
	var _fog_torus := TorusMesh.new()
	_fog_torus.inner_radius = ir
	_fog_torus.outer_radius = or_
	_fog_torus.rings = 20
	_fog_torus.ring_segments = 16
	fog_ring.mesh = _fog_torus
	fog_ring.position = Vector3(cx, floor_y + 0.3, cz)

	var fog_mat: StandardMaterial3D = StandardMaterial3D.new()
	var fog_color: Color = base_color.lightened(0.2)
	fog_mat.albedo_color = Color(fog_color.r, fog_color.g, fog_color.b, 0.04)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.emission_enabled = true
	fog_mat.emission = fog_color
	fog_mat.emission_energy_multiplier = 0.15
	fog_mat.no_depth_test = false
	fog_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_ring.material_override = fog_mat
	fog_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fog_ring)

	# Scattered edge lights — a few dim lights around the perimeter
	var light_count: int = 6 if radius > 100.0 else 4
	for i in range(light_count):
		var angle: float = float(i) / float(light_count) * TAU
		var lx: float = cx + cos(angle) * radius * 0.9
		var lz: float = cz + sin(angle) * radius * 0.9
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(lx, _terrain_y(lx, lz) + 1.5, lz)
		light.light_color = base_color.lightened(0.3)
		light.light_energy = 0.15
		light.omni_range = 8.0
		light.omni_attenuation = 2.0
		add_child(light)


# ═══════════════════════════════════════════════════════════════════════════════
#  DECORATION COLLISION — add physics bodies so the player can't walk through props
# ═══════════════════════════════════════════════════════════════════════════════

## Attach a cylindrical collision body to a node so the player bumps into it.
## The shape is centered at the node's position; `col_radius` and `col_height`
## define the cylinder dimensions.  Layer 1 matches the ground/wall layer that
## the player's collision mask already checks.
func _add_cylinder_collision(parent: Node3D, col_radius: float, col_height: float,
		y_offset: float = 0.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = col_radius
	shape.height = col_height
	col.shape = shape
	if y_offset != 0.0:
		col.position.y = y_offset
	body.add_child(col)
	parent.add_child(body)

## Attach a box collision body (for walls, beams, etc.)
func _add_box_collision(parent: Node3D, box_size: Vector3,
		y_offset: float = 0.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	if y_offset != 0.0:
		col.position.y = y_offset
	body.add_child(col)
	parent.add_child(body)

# ═══════════════════════════════════════════════════════════════════════════════
#  CLUTTER DENSITY — per-area multiplier so gathering/combat zones stay readable
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a 0.0-1.0 density multiplier for generic decoration counts.
## Areas where gameplay objects (ores, enemies, flora nodes) are the visual focus
## get lower density so the important stuff isn't buried in scenery.
func _clutter_density(area_id: String) -> float:
	match area_id:
		"asteroid-mines":    return 0.3   # ores are the stars
		"gathering-grounds": return 0.4   # gathering nodes need visibility
		"mycelium-hollows":  return 0.55  # fungal zone — moderate clutter, nodes must be visible
		"solarith-wastes":   return 0.5   # desert outpost — wide-open feel, moderate props
		"station-hub":       return 0.5   # town hub, keep some bustle but not overwhelming
		"the-abyss":         return 0.35  # supposed to feel empty and ominous
		"corrupted-wastes":  return 0.5   # small area, moderate clutter
		"spore-marshes":     return 0.6
		"hive-tunnels":      return 0.5
		"fungal-wastes":     return 0.5
		"stalker-reaches":   return 0.4
		"bio-lab":           return 0.0   # already handled by _is_clean_area
		_:                   return 1.0

# ═══════════════════════════════════════════════════════════════════════════════
#  DETAIL LAYERS
# ═══════════════════════════════════════════════════════════════════════════════

## Scatter rocks and boulders of various sizes with material variety
func _add_rocks_and_boulders(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = area_id.hash()

	# Create 5 material variants for visual variety
	var rock_variants: Array[StandardMaterial3D] = []
	for v in range(5):
		var vm := StandardMaterial3D.new()
		var shift: float = (v - 2) * 0.04  # -0.08, -0.04, 0, 0.04, 0.08
		vm.albedo_color = base_color.darkened(0.3 + shift)
		vm.roughness = 0.75 + v * 0.04
		vm.metallic = 0.08 + v * 0.03
		# Some variants have faint emission (glowing mineral veins)
		if v == 0 or v == 4:
			vm.emission_enabled = true
			vm.emission = base_color.lightened(0.4)
			vm.emission_energy_multiplier = 0.12
		rock_variants.append(vm)

	# Scale count by area size, reduced by per-area clutter density
	var rock_count: int = int((12 + radius * 0.08) * _clutter_density(area_id))
	rock_count = maxi(rock_count, 2)  # Always at least a couple
	rock_count = mini(rock_count, 40)  # Cap for performance

	# Create 5 rock blob variants (approximated with SphereMesh)
	var rock_meshes: Array[SphereMesh] = []
	for v in range(5):
		var _rock_sph := SphereMesh.new()
		_rock_sph.radius = 1.0
		_rock_sph.height = 2.0
		_rock_sph.radial_segments = 16
		_rock_sph.rings = 8
		rock_meshes.append(_rock_sph)

	for i in range(rock_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(3.0, radius * 0.88)
		var rock_r: float = rng.randf_range(0.3, 2.5)
		var rx: float = cx + cos(angle) * dist
		var rz: float = cz + sin(angle) * dist
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = rock_meshes[i % rock_meshes.size()]
		rock.position = Vector3(rx, _terrain_y(rx, rz) + rock_r * 0.2, rz)
		rock.scale = Vector3(
			rock_r * (1.0 + rng.randf() * 0.6),
			rock_r * (0.25 + rng.randf() * 0.5),
			rock_r * (1.0 + rng.randf() * 0.6)
		)
		rock.rotation.y = rng.randf() * TAU
		rock.material_override = rock_variants[i % rock_variants.size()]
		add_child(rock)

## Energy pylons — tall glowing pillars scattered through the area
func _add_energy_pylons(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_pylons").hash()

	var pylon_count: int = int((4 + radius * 0.03) * _clutter_density(area_id))
	pylon_count = mini(pylon_count, 15)

	for i in range(pylon_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.8)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)
		var height: float = rng.randf_range(4.0, 12.0)

		# Base pedestal
		var pedestal: MeshInstance3D = MeshInstance3D.new()
		var _ped_mesh := CylinderMesh.new()
		_ped_mesh.top_radius = 0.8
		_ped_mesh.bottom_radius = 0.8
		_ped_mesh.height = 0.6
		_ped_mesh.radial_segments = 16
		pedestal.mesh = _ped_mesh
		pedestal.position = Vector3(px, ty + 0.3, pz)
		var ped_mat: StandardMaterial3D = StandardMaterial3D.new()
		ped_mat.albedo_color = base_color.darkened(0.2)
		ped_mat.metallic = 0.6
		ped_mat.roughness = 0.3
		pedestal.material_override = ped_mat
		add_child(pedestal)

		# Main column
		var column: MeshInstance3D = MeshInstance3D.new()
		var _col_mesh := CylinderMesh.new()
		_col_mesh.top_radius = 0.25
		_col_mesh.bottom_radius = 0.25
		_col_mesh.height = height
		_col_mesh.radial_segments = 16
		column.mesh = _col_mesh
		column.position = Vector3(px, ty + height * 0.5 + 0.6, pz)
		var col_mat: StandardMaterial3D = StandardMaterial3D.new()
		col_mat.albedo_color = base_color.darkened(0.1)
		col_mat.metallic = 0.7
		col_mat.roughness = 0.2
		col_mat.emission_enabled = true
		col_mat.emission = base_color.lightened(0.3)
		col_mat.emission_energy_multiplier = 0.5
		column.material_override = col_mat
		add_child(column)

		# Glowing energy orb on top
		var orb: MeshInstance3D = MeshInstance3D.new()
		var _orb_mesh := SphereMesh.new()
		_orb_mesh.radius = 0.4
		_orb_mesh.height = 0.8
		_orb_mesh.radial_segments = 16
		_orb_mesh.rings = 8
		orb.mesh = _orb_mesh
		orb.position = Vector3(px, ty + height + 1.0, pz)
		var orb_mat: StandardMaterial3D = StandardMaterial3D.new()
		orb_mat.albedo_color = base_color.lightened(0.5)
		orb_mat.emission_enabled = true
		orb_mat.emission = base_color.lightened(0.6)
		orb_mat.emission_energy_multiplier = 2.0
		orb.material_override = orb_mat
		add_child(orb)

		# Horizontal ring around the orb
		var h_ring: MeshInstance3D = MeshInstance3D.new()
		var _hring_torus := TorusMesh.new()
		_hring_torus.inner_radius = 0.55
		_hring_torus.outer_radius = 0.7
		_hring_torus.rings = 20
		_hring_torus.ring_segments = 16
		h_ring.mesh = _hring_torus
		h_ring.position = Vector3(px, ty + height + 1.0, pz)
		h_ring.material_override = orb_mat
		add_child(h_ring)

		# Register orb for animation (gentle hover + pulse)
		_animated_nodes.append({
			"node": orb, "type": "hover",
			"base_y": ty + height + 1.0,
			"speed": rng.randf_range(1.0, 2.0),
			"phase": rng.randf() * TAU,
			"amplitude": 0.3
		})
		_animated_nodes.append({
			"node": h_ring, "type": "rotate",
			"speed": rng.randf_range(0.3, 0.8),
			"phase": 0.0
		})

## Tech panels — flat glowing screens embedded in the ground
func _add_tech_panels(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_panels").hash()

	var panel_count: int = int((6 + radius * 0.04) * _clutter_density(area_id))
	panel_count = mini(panel_count, 18)

	for i in range(panel_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, radius * 0.85)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)

		var pw: float = rng.randf_range(1.5, 4.0)
		var pd: float = rng.randf_range(1.0, 3.0)
		var panel_yaw: float = rng.randf() * TAU

		var panel_mat: StandardMaterial3D = StandardMaterial3D.new()
		var panel_color: Color = base_color.lightened(0.3)
		panel_mat.albedo_color = panel_color
		panel_mat.emission_enabled = true
		panel_mat.emission = panel_color.lightened(0.2)
		panel_mat.emission_energy_multiplier = 1.5
		panel_mat.metallic = 0.8
		panel_mat.roughness = 0.1

		var panel: MeshInstance3D = MeshInstance3D.new()
		var _panel_box := BoxMesh.new()
		_panel_box.size = Vector3(pw, 0.08, pd)
		panel.mesh = _panel_box
		panel.material_override = panel_mat
		panel.position = Vector3(px, ty + 0.04, pz)
		panel.rotation.y = panel_yaw
		add_child(panel)

		# Border frame around panel
		var frame_mat: StandardMaterial3D = StandardMaterial3D.new()
		frame_mat.albedo_color = base_color.darkened(0.15)
		frame_mat.metallic = 0.5
		frame_mat.roughness = 0.3

		var frame: MeshInstance3D = MeshInstance3D.new()
		var _frame_box := BoxMesh.new()
		_frame_box.size = Vector3(pw + 0.2, 0.12, pd + 0.2)
		frame.mesh = _frame_box
		frame.material_override = frame_mat
		frame.position = Vector3(px, ty + 0.02, pz)
		frame.rotation.y = panel_yaw
		add_child(frame)

## Light columns — tall beams of light shooting upward
func _add_light_columns(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_lightcols").hash()

	var col_count: int = 2 if radius < 60 else (4 if radius < 300 else 8)
	col_count = maxi(int(col_count * _clutter_density(area_id)), 1)

	for i in range(col_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(radius * 0.3, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)
		var beam_h: float = rng.randf_range(15.0, 35.0)

		# Light beam (semi-transparent tall cylinder)
		var beam_color: Color = base_color.lightened(0.5)
		var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
		beam_mat.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.06)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.emission_enabled = true
		beam_mat.emission = beam_color
		beam_mat.emission_energy_multiplier = 0.5
		beam_mat.no_depth_test = false

		var beam: MeshInstance3D = MeshInstance3D.new()
		var _beam_cyl := CylinderMesh.new()
		_beam_cyl.top_radius = 0.3
		_beam_cyl.bottom_radius = 0.3
		_beam_cyl.height = beam_h
		_beam_cyl.radial_segments = 16
		beam.mesh = _beam_cyl
		beam.material_override = beam_mat
		beam.position = Vector3(px, ty + beam_h * 0.5, pz)
		add_child(beam)

		# Base emitter disc
		var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
		disc_mat.albedo_color = beam_color
		disc_mat.emission_enabled = true
		disc_mat.emission = beam_color
		disc_mat.emission_energy_multiplier = 1.5
		disc_mat.metallic = 0.5

		var base_disc: MeshInstance3D = MeshInstance3D.new()
		var _bdisc_cyl := CylinderMesh.new()
		_bdisc_cyl.top_radius = 1.2
		_bdisc_cyl.bottom_radius = 1.2
		_bdisc_cyl.height = 0.15
		_bdisc_cyl.radial_segments = 16
		base_disc.mesh = _bdisc_cyl
		base_disc.material_override = disc_mat
		base_disc.position = Vector3(px, ty + 0.08, pz)
		add_child(base_disc)

		# Register beam for pulsing animation
		_animated_nodes.append({
			"node": beam, "type": "pulse_alpha",
			"speed": rng.randf_range(0.5, 1.5),
			"phase": rng.randf() * TAU,
			"min_alpha": 0.08, "max_alpha": 0.25
		})

## Crystal formations — hostile/exotic areas
func _add_crystals(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var crystal_areas: Array[String] = [
		"spore-marshes", "hive-tunnels", "fungal-wastes", "stalker-reaches",
		"the-abyss", "asteroid-mines", "corrupted-wastes"
	]
	if area_id not in crystal_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_crystals").hash()

	var crystal_count: int = int((10 + radius * 0.06) * _clutter_density(area_id))
	crystal_count = mini(crystal_count, 30)

	for i in range(crystal_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.8)
		var c_height: float = rng.randf_range(1.5, 8.0)
		var c_radius: float = rng.randf_range(0.15, 0.8)
		var crx: float = cx + cos(angle) * dist
		var crz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(crx, crz)

		# Crystal approximated with CylinderMesh (cone shape)
		var crystal: MeshInstance3D = MeshInstance3D.new()
		var _crys_mesh := CylinderMesh.new()
		_crys_mesh.top_radius = 0.001
		_crys_mesh.bottom_radius = c_radius
		_crys_mesh.height = c_height
		_crys_mesh.radial_segments = 5
		crystal.mesh = _crys_mesh
		crystal.position = Vector3(crx, ty + c_height * 0.5, crz)
		crystal.rotation = Vector3(
			rng.randf_range(-0.35, 0.35),
			rng.randf() * TAU,
			rng.randf_range(-0.35, 0.35)
		)
		var cryst_mat: StandardMaterial3D = StandardMaterial3D.new()
		cryst_mat.albedo_color = base_color.lightened(0.3)
		cryst_mat.metallic = 0.8
		cryst_mat.roughness = 0.1
		cryst_mat.emission_enabled = true
		cryst_mat.emission = base_color.lightened(0.6)
		cryst_mat.emission_energy_multiplier = 1.8
		crystal.material_override = cryst_mat
		add_child(crystal)

		# Add cluster mates (2-3 smaller crystals near each large one)
		if rng.randf() > 0.4:
			for j in range(rng.randi_range(1, 3)):
				var sub_r: float = c_radius * rng.randf_range(0.3, 0.6)
				var sub_h: float = c_height * rng.randf_range(0.3, 0.7)
				var sub: MeshInstance3D = MeshInstance3D.new()
				var _sub_crys := CylinderMesh.new()
				_sub_crys.top_radius = 0.001
				_sub_crys.bottom_radius = sub_r
				_sub_crys.height = sub_h
				_sub_crys.radial_segments = 5
				sub.mesh = _sub_crys
				sub.position = crystal.position + Vector3(
					rng.randf_range(-1.0, 1.0),
					-c_height * 0.1,
					rng.randf_range(-1.0, 1.0)
				)
				sub.rotation = Vector3(
					rng.randf_range(-0.5, 0.5),
					rng.randf() * TAU,
					rng.randf_range(-0.5, 0.5)
				)
				sub.material_override = cryst_mat
				add_child(sub)

## Alien flora — bioluminescent plants for safe/gathering areas and marsh/fungal zones
func _add_alien_flora(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var flora_areas: Array[String] = [
		"gathering-grounds", "spore-marshes", "fungal-wastes"
	]
	if area_id not in flora_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_flora").hash()

	var flora_count: int = int((12 + radius * 0.06) * _clutter_density(area_id))
	flora_count = mini(flora_count, 25)

	for i in range(flora_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, radius * 0.8)
		var stem_h: float = rng.randf_range(1.0, 6.0)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)

		# Stem
		var stem_r: float = 0.08 + rng.randf() * 0.06
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.06, 0.25, 0.12)
		stem_mat.roughness = 0.55
		stem_mat.emission_enabled = true
		stem_mat.emission = Color(0.04, 0.12, 0.06)
		stem_mat.emission_energy_multiplier = 0.4

		var stem: MeshInstance3D = MeshInstance3D.new()
		var _stem_cyl := CylinderMesh.new()
		_stem_cyl.top_radius = stem_r
		_stem_cyl.bottom_radius = stem_r
		_stem_cyl.height = stem_h
		_stem_cyl.radial_segments = 16
		stem.mesh = _stem_cyl
		stem.material_override = stem_mat
		stem.position = Vector3(px, ty + stem_h * 0.5, pz)
		stem.rotation.z = rng.randf_range(-0.2, 0.2)
		stem.rotation.x = rng.randf_range(-0.1, 0.1)
		add_child(stem)

		# Bulb on top
		var bulb_r: float = rng.randf_range(0.2, 0.7)
		var bulb_color: Color = Color(
			rng.randf_range(0.1, 0.4),
			rng.randf_range(0.6, 1.0),
			rng.randf_range(0.3, 0.9)
		)
		var bulb_mat: StandardMaterial3D = StandardMaterial3D.new()
		bulb_mat.albedo_color = bulb_color
		bulb_mat.emission_enabled = true
		bulb_mat.emission = bulb_color
		bulb_mat.emission_energy_multiplier = 1.2

		var bulb: MeshInstance3D = MeshInstance3D.new()
		var _bulb_sph := SphereMesh.new()
		_bulb_sph.radius = bulb_r
		_bulb_sph.height = bulb_r * 2.0
		_bulb_sph.radial_segments = 16
		_bulb_sph.rings = 8
		bulb.mesh = _bulb_sph
		bulb.material_override = bulb_mat
		bulb.position = Vector3(px, ty + stem_h + bulb_r * 0.3, pz)
		add_child(bulb)

		# Tendril branches (1-3 per plant)
		if rng.randf() > 0.5:
			for j in range(rng.randi_range(1, 3)):
				var t_h: float = stem_h * rng.randf_range(0.3, 0.6)
				var t_y: float = ty + stem_h * rng.randf_range(0.3, 0.7)
				var t_yaw: float = rng.randf() * TAU

				var tendril: MeshInstance3D = MeshInstance3D.new()
				var _tend_cyl := CylinderMesh.new()
				_tend_cyl.top_radius = 0.03
				_tend_cyl.bottom_radius = 0.03
				_tend_cyl.height = t_h
				_tend_cyl.radial_segments = 16
				tendril.mesh = _tend_cyl
				tendril.material_override = stem_mat
				tendril.position = Vector3(px, t_y, pz)
				tendril.rotation = Vector3(
					rng.randf_range(-0.8, 0.8),
					t_yaw,
					rng.randf_range(-0.5, 0.5)
				)
				add_child(tendril)

				# Small light on tendril tip
				var tip_offset: Vector3 = Vector3(
					sin(t_yaw) * t_h * 0.4,
					t_h * 0.3,
					cos(t_yaw) * t_h * 0.4
				)
				var tip: MeshInstance3D = MeshInstance3D.new()
				var _tip_sph := SphereMesh.new()
				_tip_sph.radius = 0.08
				_tip_sph.height = 0.16
				_tip_sph.radial_segments = 16
				_tip_sph.rings = 8
				tip.mesh = _tip_sph
				tip.material_override = bulb_mat
				tip.position = tendril.position + tip_offset
				add_child(tip)

## Floating debris — small rocks/metal fragments hovering in the air
func _add_floating_debris(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_debris").hash()

	var debris_count: int = int(5 + radius * 0.02)
	debris_count = mini(debris_count, 25)

	var debris_mat: StandardMaterial3D = StandardMaterial3D.new()
	debris_mat.albedo_color = base_color.darkened(0.2)
	debris_mat.metallic = 0.4
	debris_mat.roughness = 0.5
	debris_mat.emission_enabled = true
	debris_mat.emission = base_color.lightened(0.2)
	debris_mat.emission_energy_multiplier = 0.5

	for i in range(debris_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.75)
		var hover_h: float = rng.randf_range(2.0, 8.0)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist

		var s: float = rng.randf_range(0.2, 0.8)
		# Varied aspect ratios to look like broken ship/tech fragments
		var debris_size: Vector3
		var aspect: int = rng.randi_range(0, 2)
		match aspect:
			0: debris_size = Vector3(s, s * 0.3, s * 1.2)   # flat plate
			1: debris_size = Vector3(s * 0.4, s * 0.4, s * 1.5)  # beam fragment
			_: debris_size = Vector3(s, s * 0.5, s * 0.5)  # chunk
		var ty: float = _terrain_y(px, pz)

		var debris: MeshInstance3D = MeshInstance3D.new()
		var _debris_box := BoxMesh.new()
		_debris_box.size = debris_size
		debris.mesh = _debris_box
		debris.material_override = debris_mat
		debris.position = Vector3(px, ty + hover_h, pz)
		debris.rotation = Vector3(
			rng.randf() * TAU,
			rng.randf() * TAU,
			rng.randf() * TAU
		)
		add_child(debris)

		# Register for slow hovering animation
		_animated_nodes.append({
			"node": debris, "type": "hover",
			"base_y": ty + hover_h,
			"speed": rng.randf_range(0.3, 0.8),
			"phase": rng.randf() * TAU,
			"amplitude": rng.randf_range(0.3, 1.0)
		})
		_animated_nodes.append({
			"node": debris, "type": "slow_rotate",
			"speed": rng.randf_range(0.1, 0.4),
			"phase": 0.0
		})

## Pipe structures — horizontal and diagonal conduits running across the ground
func _add_pipe_structures(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_pipes").hash()

	var pipe_count: int = int((3 + radius * 0.02) * _clutter_density(area_id))
	pipe_count = mini(pipe_count, 8)

	var pipe_mat: StandardMaterial3D = StandardMaterial3D.new()
	pipe_mat.albedo_color = base_color.darkened(0.15)
	pipe_mat.metallic = 0.7
	pipe_mat.roughness = 0.25
	pipe_mat.emission_enabled = true
	pipe_mat.emission = base_color
	pipe_mat.emission_energy_multiplier = 0.15

	for i in range(pipe_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)
		var pipe_len: float = rng.randf_range(4.0, 15.0)
		var pipe_h: float = rng.randf_range(0.3, 2.0)
		var pipe_r: float = rng.randf_range(0.12, 0.3)
		var pipe_yaw: float = rng.randf() * TAU

		# Pipe cylinder
		var pipe: MeshInstance3D = MeshInstance3D.new()
		var _pipe_cyl := CylinderMesh.new()
		_pipe_cyl.top_radius = pipe_r
		_pipe_cyl.bottom_radius = pipe_r
		_pipe_cyl.height = pipe_len
		_pipe_cyl.radial_segments = 16
		pipe.mesh = _pipe_cyl
		pipe.material_override = pipe_mat
		pipe.position = Vector3(px, ty + pipe_h, pz)
		pipe.rotation = Vector3(0, pipe_yaw, PI / 2.0)
		add_child(pipe)

		# Support legs (2 per pipe) so they don't appear to float
		for leg_idx in range(2):
			var leg_frac: float = -0.3 + 0.6 * leg_idx  # -0.3 and 0.3 along pipe
			var leg_x: float = px + cos(pipe_yaw) * pipe_len * leg_frac
			var leg_z: float = pz + sin(pipe_yaw) * pipe_len * leg_frac
			var leg_ty: float = _terrain_y(leg_x, leg_z)
			var leg_h: float = pipe_h + (ty - leg_ty)
			if leg_h < 0.2:
				leg_h = 0.2
			var leg_r: float = pipe_r * 0.4
			var leg: MeshInstance3D = MeshInstance3D.new()
			var _leg_cyl := CylinderMesh.new()
			_leg_cyl.top_radius = leg_r
			_leg_cyl.bottom_radius = leg_r
			_leg_cyl.height = leg_h
			_leg_cyl.radial_segments = 16
			leg.mesh = _leg_cyl
			leg.material_override = pipe_mat
			leg.position = Vector3(leg_x, leg_ty + leg_h * 0.5, leg_z)
			add_child(leg)

		# Pipe junction rings
		for j in range(rng.randi_range(1, 3)):
			var frac: float = rng.randf_range(-0.4, 0.4)
			var junc: MeshInstance3D = MeshInstance3D.new()
			var _junc_torus := TorusMesh.new()
			_junc_torus.inner_radius = 0.04
			_junc_torus.outer_radius = pipe_r + 0.04
			_junc_torus.rings = 20
			_junc_torus.ring_segments = 16
			junc.mesh = _junc_torus
			junc.material_override = pipe_mat
			junc.position = Vector3(
				px + cos(pipe_yaw) * pipe_len * frac,
				ty + pipe_h,
				pz + sin(pipe_yaw) * pipe_len * frac
			)
			junc.rotation.z = PI / 2.0
			junc.rotation.y = pipe_yaw
			add_child(junc)

## Ruined wall sections — broken structures suggesting ancient civilization
func _add_ruined_walls(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var ruin_areas: Array[String] = [
		"spore-marshes", "hive-tunnels", "fungal-wastes", "stalker-reaches",
		"the-abyss", "corrupted-wastes", "asteroid-mines"
	]
	if area_id not in ruin_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_ruins").hash()

	var wall_count: int = int((3 + radius * 0.015) * _clutter_density(area_id))
	wall_count = mini(wall_count, 8)

	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = base_color.darkened(0.25)
	wall_mat.metallic = 0.3
	wall_mat.roughness = 0.7

	for i in range(wall_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, radius * 0.75)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var ty: float = _terrain_y(px, pz)
		var wall_h: float = rng.randf_range(2.0, 7.0)
		var wall_w: float = rng.randf_range(3.0, 10.0)

		# Wall section
		var wall_yaw: float = rng.randf() * TAU
		var wall: MeshInstance3D = MeshInstance3D.new()
		var _wall_box := BoxMesh.new()
		_wall_box.size = Vector3(wall_w, wall_h, 0.4)
		wall.mesh = _wall_box
		wall.material_override = wall_mat
		wall.position = Vector3(px, ty + wall_h * 0.5, pz)
		wall.rotation.y = wall_yaw
		add_child(wall)
		# No collision — ruined walls are walk-through scenery to avoid trapping player

		# Broken top — irregular jagged silhouette (smaller boxes on top)
		for j in range(rng.randi_range(2, 5)):
			var cw: float = rng.randf_range(0.5, wall_w * 0.4)
			var ch: float = rng.randf_range(0.5, 2.0)
			var chunk: MeshInstance3D = MeshInstance3D.new()
			var _chunk_box := BoxMesh.new()
			_chunk_box.size = Vector3(cw, ch, 0.4)
			chunk.mesh = _chunk_box
			chunk.material_override = wall_mat
			chunk.position = Vector3(
				px + (rng.randf() - 0.5) * wall_w * 0.5,
				ty + wall_h + ch * 0.3,
				pz
			)
			chunk.rotation.y = wall_yaw
			chunk.rotation.z = rng.randf_range(-0.15, 0.15)
			add_child(chunk)

## Per-area unique structures — each area gets its signature landmarks
func _add_area_unique_structures(area_id: String, cx: float, cz: float,
		radius: float, base_color: Color, y_base: float) -> void:
	match area_id:
		"station-hub":
			_build_hub_structures(cx, cz, radius, base_color, y_base)
		"gathering-grounds":
			_build_gathering_structures(cx, cz, radius, base_color, y_base)
		"spore-marshes":
			_build_spore_marshes_structures(cx, cz, radius, base_color, y_base)
		"hive-tunnels":
			_build_hive_tunnels_structures(cx, cz, radius, base_color, y_base)
		"fungal-wastes":
			_build_fungal_structures(cx, cz, radius, base_color, y_base)
		"stalker-reaches":
			_build_stalker_structures(cx, cz, radius, base_color, y_base)
		"the-abyss":
			_build_abyss_structures(cx, cz, radius, base_color, y_base)
		"asteroid-mines":
			_build_mines_structures(cx, cz, radius, base_color, y_base)
		"bio-lab":
			_build_biolab_structures(cx, cz, radius, base_color, y_base)

## Station Hub — central marketplace, control tower, landing pads, supply depot
func _build_hub_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	y_base = _terrain_y(cx, cz)
	# ── Shared materials ──
	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 0.8, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 0.8, 1.0)
	glow_mat.emission_energy_multiplier = 1.5

	var metal_mat: StandardMaterial3D = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.15, 0.2, 0.3)
	metal_mat.metallic = 0.7
	metal_mat.roughness = 0.25

	var dark_metal: StandardMaterial3D = StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.1, 0.12, 0.18)
	dark_metal.metallic = 0.8
	dark_metal.roughness = 0.2

	var warm_glow: StandardMaterial3D = StandardMaterial3D.new()
	warm_glow.albedo_color = Color(1.0, 0.6, 0.2)
	warm_glow.emission_enabled = true
	warm_glow.emission = Color(1.0, 0.6, 0.2)
	warm_glow.emission_energy_multiplier = 1.2

	var crate_mat: StandardMaterial3D = StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.2, 0.25, 0.35)
	crate_mat.metallic = 0.5
	crate_mat.roughness = 0.4

	# ── Central platform (raised marketplace area where NPCs cluster) ──
	var center_plat: MeshInstance3D = MeshInstance3D.new()
	var _cplat_cyl := CylinderMesh.new()
	_cplat_cyl.top_radius = 12.0
	_cplat_cyl.bottom_radius = 12.0
	_cplat_cyl.height = 0.25
	_cplat_cyl.radial_segments = 16
	center_plat.mesh = _cplat_cyl
	center_plat.material_override = dark_metal
	center_plat.position = Vector3(cx, y_base + 0.15, cz)
	add_child(center_plat)

	# Central platform glowing edge
	var center_ring: MeshInstance3D = MeshInstance3D.new()
	var _cring_torus := TorusMesh.new()
	_cring_torus.inner_radius = 11.5
	_cring_torus.outer_radius = 12.0
	_cring_torus.rings = 20
	_cring_torus.ring_segments = 16
	center_ring.mesh = _cring_torus
	center_ring.material_override = glow_mat
	center_ring.position = Vector3(cx, y_base + 0.3, cz)
	add_child(center_ring)

	# Holographic station map (center feature)
	var holo_base: MeshInstance3D = MeshInstance3D.new()
	var _hbase_cyl := CylinderMesh.new()
	_hbase_cyl.top_radius = 1.2
	_hbase_cyl.bottom_radius = 1.2
	_hbase_cyl.height = 0.8
	_hbase_cyl.radial_segments = 16
	holo_base.mesh = _hbase_cyl
	holo_base.material_override = dark_metal
	holo_base.position = Vector3(cx, y_base + 0.7, cz)
	add_child(holo_base)

	var holo_mat: StandardMaterial3D = StandardMaterial3D.new()
	holo_mat.albedo_color = Color(0.1, 0.5, 0.8, 0.4)
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo_mat.emission_enabled = true
	holo_mat.emission = Color(0.2, 0.7, 1.0)
	holo_mat.emission_energy_multiplier = 1.0

	var holo_globe: MeshInstance3D = MeshInstance3D.new()
	var _hglobe_sph := SphereMesh.new()
	_hglobe_sph.radius = 0.6
	_hglobe_sph.height = 1.2
	_hglobe_sph.radial_segments = 16
	_hglobe_sph.rings = 8
	holo_globe.mesh = _hglobe_sph
	holo_globe.material_override = holo_mat
	holo_globe.position = Vector3(cx, y_base + 1.5, cz)
	add_child(holo_globe)
	_animated_nodes.append({
		"node": holo_globe, "type": "rotate",
		"speed": 0.4, "phase": 0.0
	})

	# Holo ring orbiting the globe
	var holo_ring: MeshInstance3D = MeshInstance3D.new()
	var _hring2_torus := TorusMesh.new()
	_hring2_torus.inner_radius = 0.7
	_hring2_torus.outer_radius = 0.75
	_hring2_torus.rings = 20
	_hring2_torus.ring_segments = 16
	holo_ring.mesh = _hring2_torus
	holo_ring.material_override = glow_mat
	holo_ring.position = Vector3(cx, y_base + 1.5, cz)
	holo_ring.rotation.x = 0.4
	add_child(holo_ring)
	_animated_nodes.append({
		"node": holo_ring, "type": "rotate",
		"speed": -0.8, "phase": 0.0
	})

	# ── Street lamps around center ──
	for i in range(4):
		var angle: float = float(i) / 6.0 * TAU
		var lx: float = cx + cos(angle) * 10.0
		var lz: float = cz + sin(angle) * 10.0

		# Lamp post
		var post: MeshInstance3D = MeshInstance3D.new()
		var _post_cyl := CylinderMesh.new()
		_post_cyl.top_radius = 0.08
		_post_cyl.bottom_radius = 0.08
		_post_cyl.height = 3.5
		_post_cyl.radial_segments = 16
		post.mesh = _post_cyl
		post.material_override = metal_mat
		post.position = Vector3(lx, y_base + 1.75, lz)
		add_child(post)

		# Lamp head
		var lamp: MeshInstance3D = MeshInstance3D.new()
		var _lamp_sph := SphereMesh.new()
		_lamp_sph.radius = 0.2
		_lamp_sph.height = 0.4
		_lamp_sph.radial_segments = 16
		_lamp_sph.rings = 8
		lamp.mesh = _lamp_sph
		lamp.material_override = warm_glow
		lamp.position = Vector3(lx, y_base + 3.6, lz)
		add_child(lamp)

		# Lamp light
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.5)
		light.light_energy = 0.6
		light.omni_range = 6.0
		light.omni_attenuation = 1.5
		light.position = Vector3(lx, y_base + 3.4, lz)
		add_child(light)

	# ── Shop awnings (overhangs near NPC positions) ──
	# Zik (-5, -5), Dr. Luma (5, -5), Ori (-5, 5), Kael (5, 5)
	var shop_positions: Array[Dictionary] = [
		{"x": -5.0, "z": -5.0, "color": Color(0.2, 0.5, 0.3)},   # Zik - green
		{"x": 5.0, "z": -5.0, "color": Color(0.3, 0.2, 0.5)},    # Luma - purple
		{"x": -5.0, "z": 5.0, "color": Color(0.5, 0.35, 0.15)},  # Ori - orange
		{"x": 5.0, "z": 5.0, "color": Color(0.35, 0.15, 0.15)},  # Kael - red
	]
	for sp in shop_positions:
		var sx: float = cx + float(sp["x"])
		var sz: float = cz + float(sp["z"])
		var sc: Color = sp["color"] as Color

		# Counter/stall
		var counter: MeshInstance3D = MeshInstance3D.new()
		var _counter_box := BoxMesh.new()
		_counter_box.size = Vector3(2.5, 0.9, 0.8)
		counter.mesh = _counter_box
		counter.material_override = metal_mat
		counter.position = Vector3(sx, y_base + 0.5, sz + 1.5)
		add_child(counter)
		_add_box_collision(counter, Vector3(2.5, 0.9, 0.8))

		# Awning roof
		var awning_mat: StandardMaterial3D = StandardMaterial3D.new()
		awning_mat.albedo_color = sc
		awning_mat.metallic = 0.3
		awning_mat.roughness = 0.5
		awning_mat.emission_enabled = true
		awning_mat.emission = sc.lightened(0.2)
		awning_mat.emission_energy_multiplier = 0.3

		var awning: MeshInstance3D = MeshInstance3D.new()
		var _awning_box := BoxMesh.new()
		_awning_box.size = Vector3(3.5, 0.08, 2.5)
		awning.mesh = _awning_box
		awning.material_override = awning_mat
		awning.position = Vector3(sx, y_base + 3.0, sz + 0.5)
		add_child(awning)

		# Support poles
		for px_off in [-1.5, 1.5]:
			var pole: MeshInstance3D = MeshInstance3D.new()
			var _pole2_cyl := CylinderMesh.new()
			_pole2_cyl.top_radius = 0.06
			_pole2_cyl.bottom_radius = 0.06
			_pole2_cyl.height = 2.8
			_pole2_cyl.radial_segments = 16
			pole.mesh = _pole2_cyl
			pole.material_override = metal_mat
			pole.position = Vector3(sx + px_off, y_base + 1.4, sz + 1.7)
			add_child(pole)

		# Small glow strip under awning
		var strip_mat: StandardMaterial3D = StandardMaterial3D.new()
		strip_mat.albedo_color = sc.lightened(0.4)
		strip_mat.emission_enabled = true
		strip_mat.emission = sc.lightened(0.5)
		strip_mat.emission_energy_multiplier = 1.0

		var strip: MeshInstance3D = MeshInstance3D.new()
		var _strip_box := BoxMesh.new()
		_strip_box.size = Vector3(2.8, 0.04, 0.04)
		strip.mesh = _strip_box
		strip.material_override = strip_mat
		strip.position = Vector3(sx, y_base + 2.9, sz - 0.6)
		add_child(strip)

	# ── Landing pad (NE quadrant) ──
	var pad: MeshInstance3D = MeshInstance3D.new()
	var _pad_cyl := CylinderMesh.new()
	_pad_cyl.top_radius = 8.0
	_pad_cyl.bottom_radius = 8.0
	_pad_cyl.height = 0.3
	_pad_cyl.radial_segments = 16
	pad.mesh = _pad_cyl
	pad.material_override = metal_mat
	pad.position = Vector3(cx + 25, y_base + 0.2, cz + 20)
	add_child(pad)

	for i in range(3):
		var m_inner: float = 2.0 + float(i) * 2.0
		var m_outer: float = 2.2 + float(i) * 2.0
		var mark: MeshInstance3D = MeshInstance3D.new()
		var _mark_torus := TorusMesh.new()
		_mark_torus.inner_radius = m_inner
		_mark_torus.outer_radius = m_outer
		_mark_torus.rings = 20
		_mark_torus.ring_segments = 16
		mark.mesh = _mark_torus
		mark.material_override = glow_mat
		mark.position = Vector3(cx + 25, y_base + 0.4, cz + 20)
		add_child(mark)

	# Pad corner beacons
	for bi in range(4):
		var ba: float = float(bi) / 4.0 * TAU + PI * 0.25
		var bx: float = cx + 25 + cos(ba) * 7.5
		var bz: float = cz + 20 + sin(ba) * 7.5

		var pad_beacon: MeshInstance3D = MeshInstance3D.new()
		var _pbeacon_cyl := CylinderMesh.new()
		_pbeacon_cyl.top_radius = 0.12
		_pbeacon_cyl.bottom_radius = 0.12
		_pbeacon_cyl.height = 2.0
		_pbeacon_cyl.radial_segments = 16
		pad_beacon.mesh = _pbeacon_cyl
		pad_beacon.material_override = metal_mat
		pad_beacon.position = Vector3(bx, y_base + 1.0, bz)
		add_child(pad_beacon)

		var pad_light: MeshInstance3D = MeshInstance3D.new()
		var _plight_sph := SphereMesh.new()
		_plight_sph.radius = 0.15
		_plight_sph.height = 0.3
		_plight_sph.radial_segments = 16
		_plight_sph.rings = 8
		pad_light.mesh = _plight_sph
		pad_light.material_override = glow_mat
		pad_light.position = Vector3(bx, y_base + 2.1, bz)
		add_child(pad_light)
		_animated_nodes.append({
			"node": pad_light, "type": "pulse_scale",
			"speed": 1.5, "phase": float(bi),
			"min_scale": 0.7, "max_scale": 1.2
		})

	# ── Control tower (NW) ──
	var tower_base: MeshInstance3D = MeshInstance3D.new()
	var _tower_cyl := CylinderMesh.new()
	_tower_cyl.top_radius = 1.8
	_tower_cyl.bottom_radius = 1.8
	_tower_cyl.height = 14.0
	_tower_cyl.radial_segments = 16
	tower_base.mesh = _tower_cyl
	tower_base.material_override = metal_mat
	tower_base.position = Vector3(cx - 20, y_base + 7.0, cz - 15)
	add_child(tower_base)
	_add_cylinder_collision(tower_base, 2.0, 14.0)

	# Tower windows (rings)
	for wi in range(3):
		var win_ring: MeshInstance3D = MeshInstance3D.new()
		var _wring_torus := TorusMesh.new()
		_wring_torus.inner_radius = 1.7
		_wring_torus.outer_radius = 1.85
		_wring_torus.rings = 20
		_wring_torus.ring_segments = 16
		win_ring.mesh = _wring_torus
		win_ring.material_override = glow_mat
		win_ring.position = Vector3(cx - 20, y_base + 4.0 + float(wi) * 4.0, cz - 15)
		add_child(win_ring)

	# Tower observation deck
	var deck: MeshInstance3D = MeshInstance3D.new()
	var _deck_cyl := CylinderMesh.new()
	_deck_cyl.top_radius = 3.5
	_deck_cyl.bottom_radius = 3.5
	_deck_cyl.height = 2.5
	_deck_cyl.radial_segments = 16
	deck.mesh = _deck_cyl
	deck.material_override = metal_mat
	deck.position = Vector3(cx - 20, y_base + 15.5, cz - 15)
	add_child(deck)

	# Deck railing
	var deck_rail: MeshInstance3D = MeshInstance3D.new()
	var _drail_torus := TorusMesh.new()
	_drail_torus.inner_radius = 3.3
	_drail_torus.outer_radius = 3.5
	_drail_torus.rings = 20
	_drail_torus.ring_segments = 16
	deck_rail.mesh = _drail_torus
	deck_rail.material_override = dark_metal
	deck_rail.position = Vector3(cx - 20, y_base + 17.0, cz - 15)
	add_child(deck_rail)

	# Tower beacon
	var beacon: MeshInstance3D = MeshInstance3D.new()
	var _beacon_sph := SphereMesh.new()
	_beacon_sph.radius = 0.6
	_beacon_sph.height = 1.2
	_beacon_sph.radial_segments = 16
	_beacon_sph.rings = 8
	beacon.mesh = _beacon_sph
	beacon.material_override = glow_mat
	beacon.position = Vector3(cx - 20, y_base + 17.8, cz - 15)
	add_child(beacon)
	_animated_nodes.append({
		"node": beacon, "type": "pulse_scale",
		"speed": 2.0, "phase": 0.0,
		"min_scale": 0.8, "max_scale": 1.3
	})

	# ── Antenna array (north) ──
	for i in range(4):
		var ax: float = cx + 10 + float(i) * 3.0
		var ant_h: float = 5.0 + float(i) * 2.5

		var ant: MeshInstance3D = MeshInstance3D.new()
		var _ant_cyl := CylinderMesh.new()
		_ant_cyl.top_radius = 0.06
		_ant_cyl.bottom_radius = 0.06
		_ant_cyl.height = ant_h
		_ant_cyl.radial_segments = 16
		ant.mesh = _ant_cyl
		ant.material_override = metal_mat
		ant.position = Vector3(ax, y_base + ant_h * 0.5, cz - 22)
		add_child(ant)

		var dish: MeshInstance3D = MeshInstance3D.new()
		var _dish_sph := SphereMesh.new()
		_dish_sph.radius = 0.9
		_dish_sph.height = 1.8
		_dish_sph.radial_segments = 16
		_dish_sph.rings = 8
		dish.mesh = _dish_sph
		dish.material_override = metal_mat
		dish.position = Vector3(ax, y_base + ant_h + 0.5, cz - 22)
		dish.scale = Vector3(1.0, 0.3, 1.0)
		add_child(dish)

		# Dish glow point
		var dish_glow: MeshInstance3D = MeshInstance3D.new()
		var _dglow_sph := SphereMesh.new()
		_dglow_sph.radius = 0.12
		_dglow_sph.height = 0.24
		_dglow_sph.radial_segments = 16
		_dglow_sph.rings = 8
		dish_glow.mesh = _dglow_sph
		dish_glow.material_override = glow_mat
		dish_glow.position = Vector3(ax, y_base + ant_h + 0.6, cz - 22)
		add_child(dish_glow)

	# ── Supply depot (SE — cargo crates and containers) ──
	var depot_positions: Array[Vector3] = [
		Vector3(cx + 20, y_base + 0.5, cz - 8),
		Vector3(cx + 22, y_base + 0.5, cz - 6),
		Vector3(cx + 21, y_base + 1.0, cz - 7),
		Vector3(cx + 23, y_base + 0.5, cz - 9),
	]
	for pos in depot_positions:
		var cs: Vector3 = Vector3(1.2 + randf() * 0.4, 0.8 + randf() * 0.4, 1.2 + randf() * 0.3)
		var crate: MeshInstance3D = MeshInstance3D.new()
		var _crate_box := BoxMesh.new()
		_crate_box.size = cs
		crate.mesh = _crate_box
		crate.material_override = crate_mat
		crate.position = pos
		crate.rotation.y = randf() * 0.8
		add_child(crate)

	# Large shipping container
	var container_mat: StandardMaterial3D = StandardMaterial3D.new()
	container_mat.albedo_color = Color(0.18, 0.3, 0.22)
	container_mat.metallic = 0.6
	container_mat.roughness = 0.35

	var container: MeshInstance3D = MeshInstance3D.new()
	var _cont_box := BoxMesh.new()
	_cont_box.size = Vector3(4.0, 2.5, 2.0)
	container.mesh = _cont_box
	container.material_override = container_mat
	container.position = Vector3(cx + 22, y_base + 1.25, cz - 12)
	add_child(container)
	_add_box_collision(container, Vector3(4.0, 2.5, 2.0))

	# Container marking strip
	var cont_strip: MeshInstance3D = MeshInstance3D.new()
	var _cstrip_box := BoxMesh.new()
	_cstrip_box.size = Vector3(3.8, 0.15, 0.05)
	cont_strip.mesh = _cstrip_box
	cont_strip.material_override = warm_glow
	cont_strip.position = Vector3(cx + 22, y_base + 2.2, cz - 11.0)
	add_child(cont_strip)

	# ── Perimeter barriers (low walls around hub edge) ──
	for i in range(6):
		var angle: float = float(i) / 6.0 * TAU
		var next_a: float = float(i + 1) / 6.0 * TAU
		# Skip angles near corridor exits (east and south)
		var skip: bool = false
		if absf(angle) < 0.5 or absf(angle - TAU) < 0.5:
			skip = true  # East exit
		if absf(angle - PI * 1.5) < 0.5:
			skip = true  # South exit
		if skip:
			continue

		var bx: float = cx + cos(angle + 0.2) * (radius - 5.0)
		var bz: float = cz + sin(angle + 0.2) * (radius - 5.0)
		var barrier: MeshInstance3D = MeshInstance3D.new()
		var _barrier_box := BoxMesh.new()
		_barrier_box.size = Vector3(8.0, 1.0, 0.3)
		barrier.mesh = _barrier_box
		barrier.material_override = dark_metal
		barrier.position = Vector3(bx, y_base + 0.5, bz)
		barrier.rotation.y = angle + PI * 0.5
		add_child(barrier)
		_add_box_collision(barrier, Vector3(8.0, 1.5, 0.5))

		# Barrier glow strip
		var b_strip: MeshInstance3D = MeshInstance3D.new()
		var _bstrip_box := BoxMesh.new()
		_bstrip_box.size = Vector3(7.5, 0.06, 0.05)
		b_strip.mesh = _bstrip_box
		b_strip.material_override = glow_mat
		b_strip.position = Vector3(bx, y_base + 0.9, bz)
		b_strip.rotation.y = angle + PI * 0.5
		add_child(b_strip)

	# ── Commander's platform (north center — Vex & Grax area) ──
	var cmd_plat: MeshInstance3D = MeshInstance3D.new()
	var _cmdp_box := BoxMesh.new()
	_cmdp_box.size = Vector3(8.0, 0.2, 4.0)
	cmd_plat.mesh = _cmdp_box
	cmd_plat.material_override = dark_metal
	cmd_plat.position = Vector3(cx, y_base + 0.15, cz - 25)
	add_child(cmd_plat)

	# Command console
	var console: MeshInstance3D = MeshInstance3D.new()
	var _cons_box := BoxMesh.new()
	_cons_box.size = Vector3(2.0, 1.0, 0.5)
	console.mesh = _cons_box
	console.material_override = metal_mat
	console.position = Vector3(cx + 2, y_base + 0.7, cz - 26)
	add_child(console)

	var screen_mat: StandardMaterial3D = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.3, 0.2)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.5, 0.3)
	screen_mat.emission_energy_multiplier = 1.5

	var console_screen: MeshInstance3D = MeshInstance3D.new()
	var _screen_box := BoxMesh.new()
	_screen_box.size = Vector3(1.6, 0.6, 0.04)
	console_screen.mesh = _screen_box
	console_screen.material_override = screen_mat
	console_screen.position = Vector3(cx + 2, y_base + 1.0, cz - 25.7)
	add_child(console_screen)

	# ── Researchers' alcove (south — Dr. Elara Voss & Archivist area) ──
	var res_plat: MeshInstance3D = MeshInstance3D.new()
	var _respl_box := BoxMesh.new()
	_respl_box.size = Vector3(10.0, 0.15, 4.0)
	res_plat.mesh = _respl_box
	res_plat.material_override = dark_metal
	res_plat.position = Vector3(cx, y_base + 0.12, cz + 20)
	add_child(res_plat)

	# Research equipment
	var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
	pod_mat.albedo_color = Color(0.1, 0.15, 0.25, 0.5)
	pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pod_mat.emission_enabled = true
	pod_mat.emission = Color(0.2, 0.4, 0.6)
	pod_mat.emission_energy_multiplier = 1.0

	var res_pod: MeshInstance3D = MeshInstance3D.new()
	var _rpod_cyl := CylinderMesh.new()
	_rpod_cyl.top_radius = 0.6
	_rpod_cyl.bottom_radius = 0.6
	_rpod_cyl.height = 2.5
	_rpod_cyl.radial_segments = 16
	res_pod.mesh = _rpod_cyl
	res_pod.material_override = pod_mat
	res_pod.position = Vector3(cx - 3, y_base + 1.25, cz + 21)
	add_child(res_pod)

	var res_pod2: MeshInstance3D = MeshInstance3D.new()
	var _rpod2_cyl := CylinderMesh.new()
	_rpod2_cyl.top_radius = 0.5
	_rpod2_cyl.bottom_radius = 0.5
	_rpod2_cyl.height = 2.0
	_rpod2_cyl.radial_segments = 16
	res_pod2.mesh = _rpod2_cyl
	res_pod2.material_override = pod_mat
	res_pod2.position = Vector3(cx + 3, y_base + 1.0, cz + 21)
	add_child(res_pod2)

## Gathering Grounds — mushroom groves, spore vents, resource nodes highlighted
func _build_gathering_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	y_base = _terrain_y(cx, cz)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("gathering_unique")

	# Giant mushrooms
	var cap_mat: StandardMaterial3D = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.15, 0.5, 0.3)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.1, 0.4, 0.25)
	cap_mat.emission_energy_multiplier = 1.5

	for i in range(4):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var stem_h: float = rng.randf_range(5.0, 10.0)

		# Thick stem
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.12, 0.3, 0.18)
		stem_mat.roughness = 0.7

		var stem: MeshInstance3D = MeshInstance3D.new()
		var _gstem_cyl := CylinderMesh.new()
		_gstem_cyl.top_radius = 0.5
		_gstem_cyl.bottom_radius = 0.5
		_gstem_cyl.height = stem_h
		_gstem_cyl.radial_segments = 16
		stem.mesh = _gstem_cyl
		stem.material_override = stem_mat
		stem.position = Vector3(px, y_base + stem_h * 0.5, pz)
		add_child(stem)
		# No collision — mushroom stems are walk-through scenery

		# Large cap
		var cap_r: float = rng.randf_range(2.0, 4.0)
		var cap: MeshInstance3D = MeshInstance3D.new()
		var _gcap_cyl := CylinderMesh.new()
		_gcap_cyl.top_radius = cap_r
		_gcap_cyl.bottom_radius = cap_r
		_gcap_cyl.height = 0.8
		_gcap_cyl.radial_segments = 16
		cap.mesh = _gcap_cyl
		cap.material_override = cap_mat
		cap.position = Vector3(px, y_base + stem_h + 0.3, pz)
		add_child(cap)

	# Spore vent holes
	var vent_mat: StandardMaterial3D = StandardMaterial3D.new()
	vent_mat.albedo_color = Color(0.3, 0.7, 0.2)
	vent_mat.emission_enabled = true
	vent_mat.emission = Color(0.3, 0.8, 0.2)
	vent_mat.emission_energy_multiplier = 1.0

	for i in range(4):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.6)
		var vent: MeshInstance3D = MeshInstance3D.new()
		var _vent_cyl := CylinderMesh.new()
		_vent_cyl.top_radius = 0.6
		_vent_cyl.bottom_radius = 0.6
		_vent_cyl.height = 0.5
		_vent_cyl.radial_segments = 16
		vent.mesh = _vent_cyl
		vent.material_override = vent_mat
		vent.position = Vector3(
			cx + cos(angle) * dist,
			y_base + 0.25,
			cz + sin(angle) * dist
		)
		add_child(vent)

## Spore Marshes — bioluminescent pods and spore clouds
func _build_spore_marshes_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var zones: Array = DataManager.get_sub_zones_for_area("spore-marshes")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = "spore_marshes".hash()

	# Spore pods scattered around the marsh
	var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
	pod_mat.albedo_color = Color(0.3, 0.8, 0.4, 0.8)
	pod_mat.emission_enabled = true
	pod_mat.emission = Color(0.2, 0.6, 0.3)
	pod_mat.emission_energy_multiplier = 1.2
	pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(15):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.8)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var pod_r: float = rng.randf_range(0.8, 2.5)
		var pod: MeshInstance3D = MeshInstance3D.new()
		var _pod_sph := SphereMesh.new()
		_pod_sph.radius = pod_r
		_pod_sph.height = pod_r * 2.0
		_pod_sph.radial_segments = 16
		_pod_sph.rings = 8
		pod.mesh = _pod_sph
		pod.material_override = pod_mat
		pod.position = Vector3(px, py + pod_r * 0.5, pz)
		add_child(pod)

	# Tall marsh reeds
	var reed_mat: StandardMaterial3D = StandardMaterial3D.new()
	reed_mat.albedo_color = Color(0.25, 0.5, 0.2)

	for i in range(20):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.85)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var reed_r: float = rng.randf_range(0.05, 0.15)
		var reed_h: float = rng.randf_range(2.0, 5.0)
		var reed: MeshInstance3D = MeshInstance3D.new()
		var _reed_cyl := CylinderMesh.new()
		_reed_cyl.top_radius = reed_r
		_reed_cyl.bottom_radius = reed_r
		_reed_cyl.height = reed_h
		_reed_cyl.radial_segments = 16
		reed.mesh = _reed_cyl
		reed.material_override = reed_mat
		reed.position = Vector3(px, py + reed_h * 0.5, pz)
		add_child(reed)

## Hive Tunnels — chitin walls and hive arches
func _build_hive_tunnels_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = "hive_tunnels".hash()

	# Chitin wall segments
	var chitin_mat: StandardMaterial3D = StandardMaterial3D.new()
	chitin_mat.albedo_color = Color(0.35, 0.25, 0.15)
	chitin_mat.metallic = 0.3
	chitin_mat.roughness = 0.6

	for i in range(12):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, radius * 0.75)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var ws: Vector3 = Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(2.0, 4.5), rng.randf_range(0.5, 1.2))
		var wall: MeshInstance3D = MeshInstance3D.new()
		var _hwall_box := BoxMesh.new()
		_hwall_box.size = ws
		wall.mesh = _hwall_box
		wall.material_override = chitin_mat
		wall.position = Vector3(px, py + ws.y * 0.5, pz)
		wall.rotation.y = rng.randf() * TAU
		add_child(wall)

	# Hive arch structures (pairs of pillars with crossbar)
	var amber_mat: StandardMaterial3D = StandardMaterial3D.new()
	amber_mat.albedo_color = Color(0.6, 0.4, 0.1)
	amber_mat.emission_enabled = true
	amber_mat.emission = Color(0.5, 0.3, 0.05)
	amber_mat.emission_energy_multiplier = 0.8

	for i in range(5):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(15.0, radius * 0.6)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)
		var arch_h: float = rng.randf_range(4.0, 7.0)
		var gap: float = rng.randf_range(2.0, 4.0)
		var yaw: float = rng.randf() * TAU

		# Left pillar
		var lp: MeshInstance3D = MeshInstance3D.new()
		var _lp_cyl := CylinderMesh.new()
		_lp_cyl.top_radius = 0.4
		_lp_cyl.bottom_radius = 0.4
		_lp_cyl.height = arch_h
		_lp_cyl.radial_segments = 16
		lp.mesh = _lp_cyl
		lp.material_override = amber_mat
		lp.position = Vector3(px - cos(yaw) * gap, py + arch_h * 0.5, pz - sin(yaw) * gap)
		add_child(lp)

		# Right pillar
		var rp: MeshInstance3D = MeshInstance3D.new()
		rp.mesh = lp.mesh
		rp.material_override = amber_mat
		rp.position = Vector3(px + cos(yaw) * gap, py + arch_h * 0.5, pz + sin(yaw) * gap)
		add_child(rp)

		# Crossbar
		var bar_w: float = gap * 2.0 + 0.8
		var bar: MeshInstance3D = MeshInstance3D.new()
		var _bar_box := BoxMesh.new()
		_bar_box.size = Vector3(bar_w, 0.6, 0.6)
		bar.mesh = _bar_box
		bar.material_override = amber_mat
		bar.position = Vector3(px, py + arch_h, pz)
		bar.rotation.y = yaw
		add_child(bar)

## Fungal Wastes — giant mushrooms and mycelium networks
func _build_fungal_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = "fungal_wastes".hash()

	# Giant mushroom caps
	var cap_mat: StandardMaterial3D = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.6, 0.2, 0.7)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.4, 0.1, 0.5)
	cap_mat.emission_energy_multiplier = 0.6

	var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.7, 0.65, 0.5)

	for i in range(10):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.8)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)
		var stem_h: float = rng.randf_range(3.0, 8.0)
		var cap_r: float = rng.randf_range(1.5, 4.0)

		# Stem
		var stem_r: float = rng.randf_range(0.3, 0.7)
		var stem: MeshInstance3D = MeshInstance3D.new()
		var _fstem_cyl := CylinderMesh.new()
		_fstem_cyl.top_radius = stem_r
		_fstem_cyl.bottom_radius = stem_r
		_fstem_cyl.height = stem_h
		_fstem_cyl.radial_segments = 16
		stem.mesh = _fstem_cyl
		stem.material_override = stem_mat
		stem.position = Vector3(px, py + stem_h * 0.5, pz)
		add_child(stem)

		# Cap (flattened sphere)
		var cap: MeshInstance3D = MeshInstance3D.new()
		var _fcap_sph := SphereMesh.new()
		_fcap_sph.radius = cap_r
		_fcap_sph.height = cap_r * 2.0
		_fcap_sph.radial_segments = 16
		_fcap_sph.rings = 8
		cap.mesh = _fcap_sph
		cap.material_override = cap_mat
		cap.position = Vector3(px, py + stem_h + cap_r * 0.3, pz)
		cap.scale = Vector3(1.0, 0.35, 1.0)
		add_child(cap)

	# Mycelium ground tendrils
	var myc_mat: StandardMaterial3D = StandardMaterial3D.new()
	myc_mat.albedo_color = Color(0.8, 0.75, 0.9, 0.7)
	myc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(18):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.85)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var t_w: float = rng.randf_range(2.0, 6.0)
		var t_d: float = rng.randf_range(0.3, 0.8)
		var tendril: MeshInstance3D = MeshInstance3D.new()
		var _tend_box := BoxMesh.new()
		_tend_box.size = Vector3(t_w, 0.15, t_d)
		tendril.mesh = _tend_box
		tendril.material_override = myc_mat
		tendril.position = Vector3(px, py + 0.1, pz)
		tendril.rotation.y = rng.randf() * TAU
		add_child(tendril)

## Stalker Reaches — web canopies and cocoons
func _build_stalker_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = "stalker_reaches".hash()

	# Web support pillars
	var pillar_mat: StandardMaterial3D = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.2, 0.15, 0.25)
	pillar_mat.metallic = 0.2

	for i in range(10):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.8)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)
		var h: float = rng.randf_range(4.0, 9.0)

		var p_r: float = rng.randf_range(0.3, 0.7)
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var _spil_cyl := CylinderMesh.new()
		_spil_cyl.top_radius = p_r
		_spil_cyl.bottom_radius = p_r
		_spil_cyl.height = h
		_spil_cyl.radial_segments = 16
		pillar.mesh = _spil_cyl
		pillar.material_override = pillar_mat
		pillar.position = Vector3(px, py + h * 0.5, pz)
		add_child(pillar)

	# Cocoon pods
	var cocoon_mat: StandardMaterial3D = StandardMaterial3D.new()
	cocoon_mat.albedo_color = Color(0.6, 0.55, 0.45, 0.85)
	cocoon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var coc_r: float = rng.randf_range(0.5, 1.5)
		var cocoon: MeshInstance3D = MeshInstance3D.new()
		var _coc_sph := SphereMesh.new()
		_coc_sph.radius = coc_r
		_coc_sph.height = coc_r * 2.0
		_coc_sph.radial_segments = 16
		_coc_sph.rings = 8
		cocoon.mesh = _coc_sph
		cocoon.material_override = cocoon_mat
		cocoon.position = Vector3(px, py + rng.randf_range(1.0, 3.0), pz)
		cocoon.scale = Vector3(0.7, 1.3, 0.7)
		add_child(cocoon)

	# Golem remains (shattered stone blocks)
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.3, 0.28, 0.35)
	stone_mat.roughness = 0.9

	for i in range(12):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.85)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var py: float = _terrain_y(px, pz)

		var s: float = rng.randf_range(0.5, 2.0)
		var bs: Vector3 = Vector3(s * rng.randf_range(0.8, 1.5), s, s * rng.randf_range(0.8, 1.5))
		var block: MeshInstance3D = MeshInstance3D.new()
		var _block_box := BoxMesh.new()
		_block_box.size = bs
		block.mesh = _block_box
		block.material_override = stone_mat
		block.position = Vector3(px, py + bs.y * 0.5, pz)
		block.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		add_child(block)

## The Abyss — void pillars, floating platforms, reality tears, eye clusters
func _build_abyss_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	y_base = _terrain_y(cx, cz)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("abyss_unique")

	var void_mat: StandardMaterial3D = StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.08, 0.02, 0.15)
	void_mat.metallic = 0.4
	void_mat.roughness = 0.3
	void_mat.emission_enabled = true
	void_mat.emission = Color(0.15, 0.03, 0.25)
	void_mat.emission_energy_multiplier = 1.0

	var rift_mat: StandardMaterial3D = StandardMaterial3D.new()
	rift_mat.albedo_color = Color(0.5, 0.1, 0.8)
	rift_mat.emission_enabled = true
	rift_mat.emission = Color(0.6, 0.15, 0.9)
	rift_mat.emission_energy_multiplier = 2.5

	# Massive void pillars
	for i in range(10):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(20.0, radius * 0.8)
		var pillar_h: float = rng.randf_range(8.0, 25.0)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist

		var vp_r: float = rng.randf_range(0.5, 2.0)
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var _vpil_cyl := CylinderMesh.new()
		_vpil_cyl.top_radius = vp_r
		_vpil_cyl.bottom_radius = vp_r
		_vpil_cyl.height = pillar_h
		_vpil_cyl.radial_segments = 16
		pillar.mesh = _vpil_cyl
		pillar.material_override = void_mat
		pillar.position = Vector3(px, y_base + pillar_h * 0.5, pz)
		pillar.rotation = Vector3(
			rng.randf_range(-0.1, 0.1), 0,
			rng.randf_range(-0.1, 0.1)
		)
		add_child(pillar)
		# No collision — scatter pillars are walk-through scenery

	# Reality tear rifts (thin vertical planes of energy — terrain-following)
	for i in range(6):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(30.0, radius * 0.6)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var rift_h: float = rng.randf_range(4.0, 12.0)
		var rift_ty: float = _terrain_y(px, pz)

		var rift_w: float = rng.randf_range(0.5, 2.0)
		var rift: MeshInstance3D = MeshInstance3D.new()
		var _rift_box := BoxMesh.new()
		_rift_box.size = Vector3(rift_w, rift_h, 0.05)
		rift.mesh = _rift_box
		rift.material_override = rift_mat
		rift.position = Vector3(px, rift_ty + rift_h * 0.5, pz)
		rift.rotation.y = rng.randf() * TAU
		add_child(rift)

		# Glow light at rift center
		var rift_light: OmniLight3D = OmniLight3D.new()
		rift_light.position = Vector3(px, rift_ty + rift_h * 0.4, pz)
		rift_light.light_color = Color(0.6, 0.1, 0.8)
		rift_light.light_energy = 0.25
		rift_light.omni_range = 6.0
		rift_light.omni_attenuation = 2.0
		add_child(rift_light)

		_animated_nodes.append({
			"node": rift, "type": "pulse_scale",
			"speed": rng.randf_range(1.0, 3.0),
			"phase": rng.randf() * TAU,
			"min_scale": 0.8, "max_scale": 1.2
		})

## Asteroid Mines — mining rigs, conveyor frames, ore carts, drill towers
func _build_mines_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	y_base = _terrain_y(cx, cz)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("mines_unique")

	var metal_mat: StandardMaterial3D = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.3, 0.25, 0.2)
	metal_mat.metallic = 0.7
	metal_mat.roughness = 0.35

	var orange_mat: StandardMaterial3D = StandardMaterial3D.new()
	orange_mat.albedo_color = Color(0.8, 0.4, 0.1)
	orange_mat.emission_enabled = true
	orange_mat.emission = Color(0.9, 0.5, 0.15)
	orange_mat.emission_energy_multiplier = 1.0

	# Drill towers (3 — enough to set the scene without cluttering ore fields)
	for i in range(3):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(20.0, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var tower_h: float = rng.randf_range(8.0, 16.0)

		# Tower frame (4 legs)
		for j in range(4):
			var la: float = float(j) * PI / 2.0
			var leg: MeshInstance3D = MeshInstance3D.new()
			var _mleg_cyl := CylinderMesh.new()
			_mleg_cyl.top_radius = 0.15
			_mleg_cyl.bottom_radius = 0.15
			_mleg_cyl.height = tower_h
			_mleg_cyl.radial_segments = 16
			leg.mesh = _mleg_cyl
			leg.material_override = metal_mat
			leg.position = Vector3(
				px + cos(la) * 1.5,
				y_base + tower_h * 0.5,
				pz + sin(la) * 1.5
			)
			leg.rotation = Vector3(0.08 * cos(la), 0, 0.08 * sin(la))
			add_child(leg)

		# Platform at top
		var top: MeshInstance3D = MeshInstance3D.new()
		var _top_box := BoxMesh.new()
		_top_box.size = Vector3(4.0, 0.3, 4.0)
		top.mesh = _top_box
		top.material_override = metal_mat
		top.position = Vector3(px, y_base + tower_h, pz)
		add_child(top)
		# Collision cylinder around the tower footprint
		_add_cylinder_collision(top, 2.0, tower_h, -tower_h * 0.5)

		# Drill bit (cone)
		var drill: MeshInstance3D = MeshInstance3D.new()
		var _drill_cyl := CylinderMesh.new()
		_drill_cyl.top_radius = 0.001
		_drill_cyl.bottom_radius = 0.4
		_drill_cyl.height = 3.0
		_drill_cyl.radial_segments = 16
		drill.mesh = _drill_cyl
		drill.material_override = orange_mat
		drill.position = Vector3(px, y_base + tower_h - 2.0, pz)
		drill.rotation.x = PI
		add_child(drill)
		_animated_nodes.append({
			"node": drill, "type": "rotate",
			"speed": rng.randf_range(1.0, 3.0),
			"phase": 0.0
		})

	# Conveyor frame structures (2 — trimmed to reduce ground clutter)
	for i in range(2):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(30.0, radius * 0.6)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var conv_len: float = rng.randf_range(10.0, 25.0)
		var conv_h: float = rng.randf_range(2.0, 4.0)

		# Main beam
		var beam: MeshInstance3D = MeshInstance3D.new()
		var _cbeam_box := BoxMesh.new()
		_cbeam_box.size = Vector3(conv_len, 0.3, 0.8)
		beam.mesh = _cbeam_box
		beam.material_override = metal_mat
		beam.position = Vector3(px, y_base + conv_h, pz)
		beam.rotation.y = angle
		add_child(beam)

		# Support legs
		for j in range(4):
			var frac: float = -0.4 + float(j) * 0.27
			var support: MeshInstance3D = MeshInstance3D.new()
			var _sup_cyl := CylinderMesh.new()
			_sup_cyl.top_radius = 0.1
			_sup_cyl.bottom_radius = 0.1
			_sup_cyl.height = conv_h
			_sup_cyl.radial_segments = 16
			support.mesh = _sup_cyl
			support.material_override = metal_mat
			support.position = Vector3(
				px + cos(angle) * conv_len * frac,
				y_base + conv_h * 0.5,
				pz + sin(angle) * conv_len * frac
			)
			add_child(support)

## Bio-Lab — containment pods, lab benches, data terminals, tubes
func _build_biolab_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	y_base = _terrain_y(cx, cz)
	## Bio-Lab is a small area (radius 18) — keep it clean and open.
	## Just a central reactor, 2 containment pods, and ambient lighting.
	## Processing stations are spawned separately by StationSpawner.

	var lab_mat: StandardMaterial3D = StandardMaterial3D.new()
	lab_mat.albedo_color = Color(0.12, 0.18, 0.16)
	lab_mat.metallic = 0.6
	lab_mat.roughness = 0.2

	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.3, 0.8, 0.6, 0.25)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.2, 0.7, 0.5)
	glass_mat.emission_energy_multiplier = 1.5

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 0.9, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 0.9, 0.5)
	glow_mat.emission_energy_multiplier = 1.2

	# ── Central reactor column ──
	var reactor_base: MeshInstance3D = MeshInstance3D.new()
	var _rbase_cyl := CylinderMesh.new()
	_rbase_cyl.top_radius = 1.8
	_rbase_cyl.bottom_radius = 1.8
	_rbase_cyl.height = 0.35
	_rbase_cyl.radial_segments = 16
	reactor_base.mesh = _rbase_cyl
	reactor_base.material_override = lab_mat
	reactor_base.position = Vector3(cx, y_base + 0.18, cz)
	add_child(reactor_base)

	var reactor_glass: MeshInstance3D = MeshInstance3D.new()
	var _rglass_cyl := CylinderMesh.new()
	_rglass_cyl.top_radius = 1.2
	_rglass_cyl.bottom_radius = 1.2
	_rglass_cyl.height = 3.0
	_rglass_cyl.radial_segments = 16
	reactor_glass.mesh = _rglass_cyl
	reactor_glass.material_override = glass_mat
	reactor_glass.position = Vector3(cx, y_base + 1.85, cz)
	add_child(reactor_glass)

	var reactor_cap: MeshInstance3D = MeshInstance3D.new()
	var _rcap_cyl := CylinderMesh.new()
	_rcap_cyl.top_radius = 1.5
	_rcap_cyl.bottom_radius = 1.5
	_rcap_cyl.height = 0.25
	_rcap_cyl.radial_segments = 16
	reactor_cap.mesh = _rcap_cyl
	reactor_cap.material_override = lab_mat
	reactor_cap.position = Vector3(cx, y_base + 3.5, cz)
	add_child(reactor_cap)

	# Slow-spinning glow ring around reactor
	var ring: MeshInstance3D = MeshInstance3D.new()
	var _ring_torus := TorusMesh.new()
	_ring_torus.inner_radius = 1.6
	_ring_torus.outer_radius = 2.0
	_ring_torus.rings = 20
	_ring_torus.ring_segments = 16
	ring.mesh = _ring_torus
	ring.material_override = glow_mat
	ring.position = Vector3(cx, y_base + 2.0, cz)
	add_child(ring)
	_animated_nodes.append({
		"node": ring, "type": "slow_rotate", "speed": 0.5, "base_y": 0.0, "phase": 0.0
	})

	# Reactor light
	var reactor_light: OmniLight3D = OmniLight3D.new()
	reactor_light.position = Vector3(cx, y_base + 2.5, cz)
	reactor_light.light_color = Color(0.2, 0.9, 0.5)
	reactor_light.light_energy = 1.5
	reactor_light.omni_range = 18.0
	reactor_light.shadow_enabled = false
	add_child(reactor_light)

	# ── Two containment pods (left and right of reactor) ──
	for side_sign in [-1.0, 1.0]:
		var px: float = cx + side_sign * 6.0
		var pz: float = cz

		var pod_base: MeshInstance3D = MeshInstance3D.new()
		var _pbase_cyl := CylinderMesh.new()
		_pbase_cyl.top_radius = 0.8
		_pbase_cyl.bottom_radius = 0.8
		_pbase_cyl.height = 0.3
		_pbase_cyl.radial_segments = 16
		pod_base.mesh = _pbase_cyl
		pod_base.material_override = lab_mat
		pod_base.position = Vector3(px, y_base + 0.15, pz)
		add_child(pod_base)

		var pod_glass: MeshInstance3D = MeshInstance3D.new()
		var _pglass_cyl := CylinderMesh.new()
		_pglass_cyl.top_radius = 0.6
		_pglass_cyl.bottom_radius = 0.6
		_pglass_cyl.height = 2.5
		_pglass_cyl.radial_segments = 16
		pod_glass.mesh = _pglass_cyl
		pod_glass.material_override = glass_mat
		pod_glass.position = Vector3(px, y_base + 1.55, pz)
		add_child(pod_glass)

		var pod_cap: MeshInstance3D = MeshInstance3D.new()
		var _pcap_cyl := CylinderMesh.new()
		_pcap_cyl.top_radius = 0.8
		_pcap_cyl.bottom_radius = 0.8
		_pcap_cyl.height = 0.2
		_pcap_cyl.radial_segments = 16
		pod_cap.mesh = _pcap_cyl
		pod_cap.material_override = lab_mat
		pod_cap.position = Vector3(px, y_base + 2.9, pz)
		add_child(pod_cap)

	# ── Overhead light (single warm lamp) ──
	var overhead: OmniLight3D = OmniLight3D.new()
	overhead.position = Vector3(cx, y_base + 6.0, cz)
	overhead.light_color = Color(0.5, 0.9, 0.7)
	overhead.light_energy = 1.0
	overhead.omni_range = 20.0
	overhead.shadow_enabled = false
	add_child(overhead)

## Point lights — scattered OmniLight3D for local lighting richness
func _add_point_lights(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_lights").hash()

	var light_count: int = int(3 + radius * 0.015)
	light_count = mini(light_count, 12)  # Cap for performance

	for i in range(light_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.7)
		var lx: float = cx + cos(angle) * dist
		var lz: float = cz + sin(angle) * dist

		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(
			lx,
			_terrain_y(lx, lz) + rng.randf_range(3.0, 8.0),
			lz
		)
		light.light_color = base_color.lightened(0.5)
		light.light_energy = rng.randf_range(0.3, 0.8)
		light.omni_range = rng.randf_range(8.0, 20.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false  # Performance
		add_child(light)

# ═══════════════════════════════════════════════════════════════════════════════
#  CORRIDORS
# ═══════════════════════════════════════════════════════════════════════════════

## Gate barrier meshes — keyed by area_id, updated each frame for color
var _gate_barriers: Dictionary = {}  # { area_id: Array[MeshInstance3D] }

func _build_corridors() -> void:
	var loaded_count: int = 0
	var built_count: int = 0
	for corridor_data in DataManager.corridors:
		var corr_id: String = str(corridor_data.get("id", ""))
		var scene_path: String = "res://scenes/areas/corridor_%s.tscn" % corr_id
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			if scene:
				var instance: Node3D = scene.instantiate()
				add_child(instance)
				loaded_count += 1
				continue
		# Fallback: procedural building
		_create_corridor(corridor_data)
		built_count += 1
	print("AreaManager: %d corridors loaded from scenes, %d built procedurally" % [loaded_count, built_count])

## Build semi-transparent energy barriers at corridor mouths for gated areas
func _build_corridor_gates() -> void:
	var gate_count: int = 0
	for corridor_data in DataManager.corridors:
		var from_id: String = str(corridor_data.get("from", ""))
		var to_id: String = str(corridor_data.get("to", ""))

		# Check if either end has requirements
		for area_id in [from_id, to_id]:
			var reqs: Dictionary = DataManager.get_area_requirements(area_id)
			if reqs.is_empty():
				continue

			# Place barrier at the mouth of the gated area (on the corridor side near that area)
			var area_data: Dictionary = DataManager.get_area(area_id)
			var area_center: Dictionary = area_data.get("center", {})
			var area_cx: float = float(area_center.get("x", 0))
			var area_cz: float = float(area_center.get("z", 0))
			var area_radius: float = float(area_data.get("radius", 60))

			var min_x: float = float(corridor_data.get("minX", 0.0))
			var max_x: float = float(corridor_data.get("maxX", 0.0))
			var min_z: float = float(corridor_data.get("minZ", 0.0))
			var max_z: float = float(corridor_data.get("maxZ", 0.0))
			var corr_cx: float = (min_x + max_x) / 2.0
			var corr_cz: float = (min_z + max_z) / 2.0
			var corr_w: float = max_x - min_x
			var corr_d: float = max_z - min_z
			var is_vertical: bool = corr_d > corr_w

			# Position the barrier near the gated area edge
			var dir: Vector2 = Vector2(area_cx - corr_cx, area_cz - corr_cz).normalized()
			var gate_pos: Vector3 = Vector3(
				area_cx - dir.x * (area_radius * 0.85),
				0.0,
				area_cz - dir.y * (area_radius * 0.85)
			)

			# Build the energy barrier — a thin translucent wall
			var b_size: Vector3
			if is_vertical:
				b_size = Vector3(maxf(corr_w, 10.0), 5.0, 0.6)
			else:
				b_size = Vector3(0.6, 5.0, maxf(corr_d, 10.0))

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.8, 0.15, 0.1, 0.25)  # Red = locked
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.15, 0.1)
			mat.emission_energy_multiplier = 0.8
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			var barrier: MeshInstance3D = MeshInstance3D.new()
			barrier.name = "GateBarrier_%s" % area_id
			var _gbar_box := BoxMesh.new()
			_gbar_box.size = b_size
			barrier.mesh = _gbar_box
			barrier.material_override = mat
			barrier.position = gate_pos
			barrier.position.y = 2.5  # Center vertically

			add_child(barrier)
			if not _gate_barriers.has(area_id):
				_gate_barriers[area_id] = []
			_gate_barriers[area_id].append(barrier)
			gate_count += 1

	print("AreaManager: Built %d gate barriers" % gate_count)

## Update gate barrier colors based on current player eligibility
func _update_gate_barriers() -> void:
	for area_id in _gate_barriers:
		var accessible: bool = _check_area_gate(area_id)
		for barrier in _gate_barriers[area_id]:
			if barrier == null or not is_instance_valid(barrier):
				continue
			var mat: StandardMaterial3D = barrier.material_override as StandardMaterial3D
			if mat == null:
				continue
			if accessible:
				# Green = accessible
				mat.albedo_color = Color(0.1, 0.7, 0.3, 0.12)
				mat.emission = Color(0.1, 0.7, 0.3)
				mat.emission_energy_multiplier = 0.4
			else:
				# Red = locked
				mat.albedo_color = Color(0.8, 0.15, 0.1, 0.25)
				mat.emission = Color(0.8, 0.15, 0.1)
				mat.emission_energy_multiplier = 0.8

func _create_corridor(data: Dictionary) -> void:
	var min_x: float = data.get("minX", 0.0)
	var max_x: float = data.get("maxX", 0.0)
	var min_z: float = data.get("minZ", 0.0)
	var max_z: float = data.get("maxZ", 0.0)
	var ground_color_int: int = int(data.get("groundColor", 0x1a1a28))

	var width: float = max_x - min_x
	var depth: float = max_z - min_z
	var center_x: float = (min_x + max_x) / 2.0
	var center_z: float = (min_z + max_z) / 2.0
	var corridor_w: float = maxf(width, 12.0)
	var corridor_d: float = maxf(depth, 12.0)
	var is_vertical: bool = corridor_d > corridor_w
	var corridor_length: float = maxf(corridor_w, corridor_d)

	var corridor_color: Color = _hex_to_color(ground_color_int)

	# ── Corridor label ──
	var label_data = data.get("label", "")
	if label_data != "" and label_data != null:
		var label: Label3D = Label3D.new()
		label.text = str(label_data)
		var label_pos = data.get("labelPos", {})
		label.position = Vector3(
			label_pos.get("x", center_x),
			3.0,
			label_pos.get("z", center_z)
		)
		label.font_size = 36
		label.outline_size = 6
		label.modulate = Color(0.5, 0.7, 0.6, 0.7)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)

	# ── Guide light posts along the corridor ──
	var post_spacing: float = 8.0
	var post_count: int = int(corridor_length / post_spacing)

	var post_mat: StandardMaterial3D = StandardMaterial3D.new()
	post_mat.albedo_color = corridor_color.darkened(0.1)
	post_mat.metallic = 0.6
	post_mat.roughness = 0.3

	var lamp_mat: StandardMaterial3D = StandardMaterial3D.new()
	lamp_mat.albedo_color = corridor_color.lightened(0.6)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = corridor_color.lightened(0.6)
	lamp_mat.emission_energy_multiplier = 1.5

	for i in range(post_count):
		var frac: float = (float(i) + 0.5) / float(post_count)
		for side in [-1.0, 1.0]:
			var post_pos: Vector3
			if is_vertical:
				var pz: float = center_z + (frac - 0.5) * corridor_d
				var px: float = center_x + side * (corridor_w * 0.5 - 0.5)
				post_pos = Vector3(px, _terrain_y(px, pz), pz)
			else:
				var px: float = center_x + (frac - 0.5) * corridor_w
				var pz: float = center_z + side * (corridor_d * 0.5 - 0.5)
				post_pos = Vector3(px, _terrain_y(px, pz), pz)

			# Post
			var post: MeshInstance3D = MeshInstance3D.new()
			var _cpost_cyl := CylinderMesh.new()
			_cpost_cyl.top_radius = 0.08
			_cpost_cyl.bottom_radius = 0.08
			_cpost_cyl.height = 2.5
			_cpost_cyl.radial_segments = 16
			post.mesh = _cpost_cyl
			post.material_override = post_mat
			post.position = post_pos + Vector3(0, 1.25, 0)
			add_child(post)

			# Lamp orb on top
			var lamp: MeshInstance3D = MeshInstance3D.new()
			var _clamp_sph := SphereMesh.new()
			_clamp_sph.radius = 0.18
			_clamp_sph.height = 0.36
			_clamp_sph.radial_segments = 16
			_clamp_sph.rings = 8
			lamp.mesh = _clamp_sph
			lamp.material_override = lamp_mat
			lamp.position = post_pos + Vector3(0, 2.6, 0)
			add_child(lamp)

	# ── Arch structures over long corridors ──
	if corridor_length > 30:
		var arch_count: int = int(corridor_length / 25.0)
		for i in range(arch_count):
			var frac: float = (float(i) + 0.5) / float(arch_count)
			var arch_pos: Vector3
			if is_vertical:
				var apz: float = center_z + (frac - 0.5) * corridor_d
				arch_pos = Vector3(center_x, _terrain_y(center_x, apz), apz)
			else:
				var apx: float = center_x + (frac - 0.5) * corridor_w
				arch_pos = Vector3(apx, _terrain_y(apx, center_z), center_z)

			var arch_h: float = 6.0
			var arch_span: float = corridor_w if is_vertical else corridor_d

			# Left pillar
			var lp: MeshInstance3D = MeshInstance3D.new()
			var _alp_cyl := CylinderMesh.new()
			_alp_cyl.top_radius = 0.2
			_alp_cyl.bottom_radius = 0.2
			_alp_cyl.height = arch_h
			_alp_cyl.radial_segments = 16
			lp.mesh = _alp_cyl
			lp.material_override = post_mat
			if is_vertical:
				lp.position = arch_pos + Vector3(-arch_span * 0.5, arch_h * 0.5, 0)
			else:
				lp.position = arch_pos + Vector3(0, arch_h * 0.5, -arch_span * 0.5)
			add_child(lp)

			# Right pillar
			var rp_arch: MeshInstance3D = MeshInstance3D.new()
			rp_arch.mesh = lp.mesh
			rp_arch.material_override = post_mat
			if is_vertical:
				rp_arch.position = arch_pos + Vector3(arch_span * 0.5, arch_h * 0.5, 0)
			else:
				rp_arch.position = arch_pos + Vector3(0, arch_h * 0.5, arch_span * 0.5)
			add_child(rp_arch)

			# Cross beam
			var cb_size: Vector3
			if is_vertical:
				cb_size = Vector3(arch_span + 0.5, 0.25, 0.25)
			else:
				cb_size = Vector3(0.25, 0.25, arch_span + 0.5)
			var crossbeam: MeshInstance3D = MeshInstance3D.new()
			var _cb_box := BoxMesh.new()
			_cb_box.size = cb_size
			crossbeam.mesh = _cb_box
			crossbeam.material_override = post_mat
			crossbeam.position = arch_pos + Vector3(0, arch_h, 0)
			add_child(crossbeam)


## Add invisible collision walls around each area edge to prevent walking into the void.
## Only adds walls where there is NO corridor connecting — corridors punch through.
func _add_area_boundaries() -> void:
	# Collect corridor rectangles for gap-detection
	var corridor_rects: Array[Dictionary] = []
	for corridor_data in DataManager.corridors:
		corridor_rects.append({
			"min_x": float(corridor_data.get("minX", 0.0)) - 2.0,
			"max_x": float(corridor_data.get("maxX", 0.0)) + 2.0,
			"min_z": float(corridor_data.get("minZ", 0.0)) - 2.0,
			"max_z": float(corridor_data.get("maxZ", 0.0)) + 2.0,
		})

	for area_id in _area_bodies:
		var info: Dictionary = _area_bodies[area_id]
		var center: Vector3 = info["center"]
		var radius: float = float(info["radius"])

		# Build wall segments around the perimeter, skipping corridor openings
		# Scale segment count by circumference so wall pieces stay ~6 units long
		var wall_segments: int = clampi(int(radius * TAU / 6.0), 16, 128)
		for seg in range(wall_segments):
			var angle: float = float(seg) / float(wall_segments) * TAU
			var next_angle: float = float(seg + 1) / float(wall_segments) * TAU
			var mid_angle: float = (angle + next_angle) * 0.5
			var wx: float = center.x + cos(mid_angle) * radius
			var wz: float = center.z + sin(mid_angle) * radius

			# Skip this segment if it overlaps a corridor
			var in_corridor: bool = false
			for cr in corridor_rects:
				if wx >= cr["min_x"] and wx <= cr["max_x"] and wz >= cr["min_z"] and wz <= cr["max_z"]:
					in_corridor = true
					break
			if in_corridor:
				continue

			# Skip this segment if it falls inside another area (overlap zone)
			var in_other_area: bool = false
			for other_id in _area_bodies:
				if other_id == area_id:
					continue
				var other_info: Dictionary = _area_bodies[other_id]
				var oc: Vector3 = other_info["center"]
				var or_radius: float = float(other_info["radius"])
				var odx: float = wx - oc.x
				var odz: float = wz - oc.z
				if sqrt(odx * odx + odz * odz) < or_radius:
					in_other_area = true
					break
			if in_other_area:
				continue

			# Place an invisible wall segment
			var wall := StaticBody3D.new()
			wall.collision_layer = 1
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			var seg_length: float = radius * TAU / float(wall_segments)
			shape.size = Vector3(seg_length, 6.0, 1.0)
			col.shape = shape
			wall.add_child(col)
			var wy: float = _terrain_y(wx, wz)
			wall.position = Vector3(wx, wy + 3.0, wz)
			wall.rotation.y = mid_angle
			add_child(wall)

## Invisible collision floor far below the world — catches anything that falls through terrain.
func _add_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4000.0, 1.0, 4000.0)
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(0, -20.0, 0)
	add_child(body)

# ═══════════════════════════════════════════════════════════════════════════════
#  ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

func _animate_world(delta: float) -> void:
	_time += delta

	for entry in _animated_nodes:
		var node: Node3D = entry["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue

		var anim_type: String = entry["type"]
		var speed: float = entry["speed"]
		var phase: float = entry.get("phase", 0.0)

		match anim_type:
			"hover":
				var base_y: float = entry["base_y"]
				var amp: float = entry.get("amplitude", 0.3)
				node.position.y = base_y + sin(_time * speed + phase) * amp

			"rotate":
				node.rotation.y += delta * speed

			"slow_rotate":
				node.rotation.y += delta * speed
				node.rotation.x += delta * speed * 0.3

			"pulse_scale":
				var min_s: float = entry.get("min_scale", 0.8)
				var max_s: float = entry.get("max_scale", 1.2)
				var s: float = lerpf(min_s, max_s, (sin(_time * speed + phase) + 1.0) * 0.5)
				node.scale = Vector3(s, s, s)

			"pulse_alpha":
				# For light beams — pulse their transparency
				var min_a: float = entry.get("min_alpha", 0.08)
				var max_a: float = entry.get("max_alpha", 0.25)
				if node is MeshInstance3D:
					var mi: MeshInstance3D = node as MeshInstance3D
					if mi.material_override is StandardMaterial3D:
						var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
						m.albedo_color.a = lerpf(min_a, max_a, (sin(_time * speed + phase) + 1.0) * 0.5)

# ═══════════════════════════════════════════════════════════════════════════════
#  AREA TRANSITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _check_area_transition() -> void:
	if _player == null:
		return
	var player_pos: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	var new_area: String = _get_area_at_position(player_pos)

	if new_area == "" or new_area == GameState.current_area:
		return

	# ── Area gate check ──
	if not _check_area_gate(new_area):
		_notify_gate_blocked(new_area)
		_push_player_back()
		return

	# Successfully entered a new area — clear rejected gates so messages can fire again
	_rejected_gates.clear()
	var old_area: String = GameState.current_area
	GameState.current_area = new_area
	GameState.previous_area = old_area
	EventBus.area_entered.emit(new_area)
	EventBus.area_exited.emit(old_area)
	_update_atmosphere(new_area)
	# Notify player of area entry
	var area_data: Dictionary = DataManager.get_area(new_area)
	var area_name: String = str(area_data.get("name", new_area))
	EventBus.chat_message.emit("Entered: %s" % area_name, "system")

## Check if the player meets requirements to enter an area (pure check, no side effects).
func _check_area_gate(area_id: String) -> bool:
	var reqs: Dictionary = DataManager.get_area_requirements(area_id)
	if reqs.is_empty():
		return true  # No requirements — always open

	# Check combat level
	var req_level: int = int(reqs.get("combat_level", 0))
	if req_level > 0:
		var player_level: int = GameState.get_combat_level()
		if player_level < req_level:
			return false

	# Check quest completion
	var req_quest: String = str(reqs.get("quest", ""))
	if req_quest != "":
		if not GameState.completed_quests.has(req_quest):
			return false

	return true

## Emit a one-shot chat message explaining why a gate blocked the player.
## Only fires once per area — resets when the player returns to their own area.
func _notify_gate_blocked(area_id: String) -> void:
	if _rejected_gates.has(area_id):
		return  # Already told the player about this gate
	_rejected_gates[area_id] = true

	var reqs: Dictionary = DataManager.get_area_requirements(area_id)
	var area_data: Dictionary = DataManager.get_area(area_id)
	var area_name: String = str(area_data.get("name", area_id))

	var req_level: int = int(reqs.get("combat_level", 0))
	if req_level > 0:
		var player_level: int = GameState.get_combat_level()
		if player_level < req_level:
			EventBus.chat_message.emit(
				"Requires Combat Level %d to enter %s (current: %d)" % [req_level, area_name, player_level],
				"system"
			)
			return

	var req_quest: String = str(reqs.get("quest", ""))
	if req_quest != "":
		if not GameState.completed_quests.has(req_quest):
			var quest_data: Dictionary = DataManager.get_quest(req_quest)
			var quest_name: String = str(quest_data.get("name", req_quest))
			EventBus.chat_message.emit(
				"Complete \"%s\" to unlock %s" % [quest_name, area_name],
				"system"
			)
			return

## Push the player back toward their current area center when gate check fails
func _push_player_back() -> void:
	if _player == null:
		return
	# Get current area center and push player toward it
	var current: Dictionary = _area_bodies.get(GameState.current_area, {})
	if current.is_empty():
		return
	var center: Vector3 = current.get("center", Vector3.ZERO)
	var dir: Vector3 = (center - _player.global_position).normalized()
	# Push player 3 units back toward current area
	_player.global_position += dir * 3.0
	_player.global_position.y = get_terrain_height(_player.global_position.x, _player.global_position.z)

func _get_area_at_position(pos: Vector2) -> String:
	for corridor_data in DataManager.corridors:
		var min_x_c: float = corridor_data.get("minX", 0.0)
		var max_x_c: float = corridor_data.get("maxX", 0.0)
		var min_z_c: float = corridor_data.get("minZ", 0.0)
		var max_z_c: float = corridor_data.get("maxZ", 0.0)
		if pos.x >= min_x_c and pos.x <= max_x_c and pos.y >= min_z_c and pos.y <= max_z_c:
			var from_id: String = corridor_data.get("from", "")
			var to_id: String = corridor_data.get("to", "")
			if _area_bodies.has(from_id) and _area_bodies.has(to_id):
				var from_c: Vector3 = _area_bodies[from_id]["center"]
				var to_c: Vector3 = _area_bodies[to_id]["center"]
				var from_center: Vector2 = Vector2(from_c.x, from_c.z)
				var to_center: Vector2 = Vector2(to_c.x, to_c.z)
				if pos.distance_squared_to(from_center) < pos.distance_squared_to(to_center):
					return from_id
				else:
					return to_id

	var best_area: String = ""
	var best_radius: float = INF
	for area_id in _area_bodies:
		var area_data: Dictionary = _area_bodies[area_id]
		var c: Vector3 = area_data["center"]
		var center: Vector2 = Vector2(c.x, c.z)
		var r: float = area_data["radius"]
		if pos.distance_squared_to(center) <= r * r:
			if r < best_radius:
				best_radius = r
				best_area = area_id

	if best_area != "":
		return best_area
	return GameState.current_area

# ═══════════════════════════════════════════════════════════════════════════════
#  BOUNDARY CLAMPING — Prevents the player from walking off into the void
# ═══════════════════════════════════════════════════════════════════════════════

## Small inset so the player stays visually on the disc, not right at the edge.
const BOUNDARY_MARGIN: float = 1.5

## Returns true if the given xz position is inside any area disc or corridor rect.
func is_position_in_world(pos: Vector3) -> bool:
	var p: Vector2 = Vector2(pos.x, pos.z)
	return _is_point_in_world(p)

## Clamps a world position so it stays inside areas/corridors.
## If the point is already valid, returns it unchanged.
## If outside, pushes it to the nearest valid edge (area rim or corridor wall).
func clamp_to_world(pos: Vector3) -> Vector3:
	var p: Vector2 = Vector2(pos.x, pos.z)
	if _is_point_in_world(p):
		return pos  # Already valid

	# Find the nearest valid point across all areas and corridors
	var best_point: Vector2 = p
	var best_dist_sq: float = INF

	# Check each area disc — find nearest point on disc edge
	for area_id in _area_bodies:
		var area_data: Dictionary = _area_bodies[area_id]
		var c: Vector3 = area_data["center"]
		var center: Vector2 = Vector2(c.x, c.z)
		var r: float = area_data["radius"] - BOUNDARY_MARGIN
		var to_point: Vector2 = p - center
		var dist_to_center: float = to_point.length()
		var clamped: Vector2
		if dist_to_center <= r:
			# Inside this area — shouldn't happen since _is_point_in_world was false,
			# but handle edge case with margin
			clamped = p
		else:
			# Outside — nearest point is on the circle rim
			clamped = center + to_point.normalized() * r
		var d_sq: float = p.distance_squared_to(clamped)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_point = clamped

	# Check each corridor rectangle — find nearest point inside the rect
	for corridor_data in DataManager.corridors:
		var min_x: float = corridor_data.get("minX", 0.0) + BOUNDARY_MARGIN
		var max_x: float = corridor_data.get("maxX", 0.0) - BOUNDARY_MARGIN
		var min_z: float = corridor_data.get("minZ", 0.0) + BOUNDARY_MARGIN
		var max_z: float = corridor_data.get("maxZ", 0.0) - BOUNDARY_MARGIN
		# Clamp to corridor AABB
		var clamped: Vector2 = Vector2(
			clampf(p.x, min_x, max_x),
			clampf(p.y, min_z, max_z)
		)
		var d_sq: float = p.distance_squared_to(clamped)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_point = clamped

	return Vector3(best_point.x, pos.y, best_point.y)

## Internal: checks if a 2D point (xz) is inside any area or corridor.
func _is_point_in_world(p: Vector2) -> bool:
	# Check corridors first (rectangular)
	for corridor_data in DataManager.corridors:
		var min_x: float = corridor_data.get("minX", 0.0)
		var max_x: float = corridor_data.get("maxX", 0.0)
		var min_z: float = corridor_data.get("minZ", 0.0)
		var max_z: float = corridor_data.get("maxZ", 0.0)
		if p.x >= min_x and p.x <= max_x and p.y >= min_z and p.y <= max_z:
			return true

	# Check area discs (circular)
	for area_id in _area_bodies:
		var area_data: Dictionary = _area_bodies[area_id]
		var c: Vector3 = area_data["center"]
		var center: Vector2 = Vector2(c.x, c.z)
		var r: float = area_data["radius"]
		if p.distance_squared_to(center) <= r * r:
			return true

	return false

# ═══════════════════════════════════════════════════════════════════════════════
#  ENHANCED GLOW / BLOOM
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_enhanced_glow() -> void:
	if world_env == null or world_env.environment == null:
		return
	var env: Environment = world_env.environment
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 0.6
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.0
	env.glow_hdr_luminance_cap = 8.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, true)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.set_glow_level(3, false)
	env.set_glow_level(4, false)
	env.set_glow_level(5, false)
	env.set_glow_level(6, false)

# ═══════════════════════════════════════════════════════════════════════════════
#  ATMOSPHERE
# ═══════════════════════════════════════════════════════════════════════════════

var _dir_light: DirectionalLight3D = null
var _sky_material: ProceduralSkyMaterial = null

func _update_atmosphere(area_id: String) -> void:
	var atmos: Dictionary = DataManager.get_atmosphere(area_id)
	if atmos.is_empty() or world_env == null:
		return

	var env: Environment = world_env.environment
	if env == null:
		return

	# ── Fog (boosted for atmosphere) ──
	var fog_color_int: int = int(atmos.get("fogColor", 0x020810))
	env.fog_light_color = _hex_to_color(fog_color_int).lightened(0.1)
	var base_fog_density: float = float(atmos.get("fogDensity", 0.005))
	env.fog_density = base_fog_density * 1.5
	env.fog_light_energy = 1.5
	env.fog_sun_scatter = 0.3
	env.fog_aerial_perspective = 0.3

	# ── Ambient light ──
	var ambient_color_int: int = int(atmos.get("ambientColor", 0x1a2a4a))
	var ambient_color: Color = _hex_to_color(ambient_color_int).lightened(0.2)
	env.ambient_light_energy = maxf(float(atmos.get("ambientInt", 0.5)), 0.6)

	# ── Color grading per area ──
	env.adjustment_enabled = true
	env.adjustment_saturation = float(atmos.get("cgSat", 1.0))
	env.adjustment_contrast = float(atmos.get("cgContrast", 1.0))
	env.adjustment_brightness = float(atmos.get("cgBright", 1.0))

	# Tint — blend into ambient light color
	var tint_str: float = float(atmos.get("cgTintStr", 0.0))
	if tint_str > 0.0:
		var tint_color: Color = _hex_to_color(int(atmos.get("cgTint", 0xFFFFFF)))
		ambient_color = ambient_color.lerp(tint_color, tint_str)
	env.ambient_light_color = ambient_color

	# ── Directional light ──
	if _dir_light == null:
		_dir_light = get_tree().get_first_node_in_group("dir_light") as DirectionalLight3D
		if _dir_light == null:
			var parent: Node = get_parent()
			if parent:
				for child in parent.get_children():
					if child is DirectionalLight3D:
						_dir_light = child
						break

	if _dir_light:
		var dir_color_int: int = int(atmos.get("dirColor", 0xAABBFF))
		_dir_light.light_color = _hex_to_color(dir_color_int)
		_dir_light.light_energy = float(atmos.get("dirInt", 0.7))

	# ── Per-area sky colors ──
	if _sky_material == null and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		_sky_material = env.sky.sky_material as ProceduralSkyMaterial

	if _sky_material:
		var sky_top: Color = _hex_to_color(int(atmos.get("skyTop", 0x000510)))
		var sky_bottom: Color = _hex_to_color(int(atmos.get("skyBottom", 0x020810)))
		_sky_material.sky_top_color = sky_top
		_sky_material.ground_bottom_color = sky_bottom
		var horizon: Color = sky_top.lerp(sky_bottom, 0.5).lightened(0.15)
		_sky_material.sky_horizon_color = horizon
		_sky_material.ground_horizon_color = horizon

# ═══════════════════════════════════════════════════════════════════════════════
#  UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

func _hex_to_color(hex: int) -> Color:
	var r: float = ((hex >> 16) & 0xFF) / 255.0
	var g: float = ((hex >> 8) & 0xFF) / 255.0
	var b: float = (hex & 0xFF) / 255.0
	return Color(r, g, b, 1.0)
