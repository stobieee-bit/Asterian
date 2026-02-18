## AreaManager — Builds a richly detailed 3D sci-fi world from JSON area data
##
## Reads AREAS and CORRIDORS from DataManager and generates:
## - Ground discs for each area (CSGCylinder3D) with layered detail
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

# ── Terrain ──
var _terrain3d = null  # Terrain3D plugin node (painted terrain)

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
	# Find Terrain3D plugin node (user-painted terrain)
	_terrain3d = _find_terrain3d(get_tree().root)
	if _terrain3d:
		print("AreaManager: Found Terrain3D node")
	else:
		push_warning("AreaManager: Terrain3D node not found — adding fallback ground plane")
		_add_fallback_ground()
	_build_areas()
	_build_corridors()
	_build_corridor_gates()
	_add_area_boundaries()
	_add_safety_floor()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

## Public API: query terrain height at any world XZ position.
## Uses Terrain3D plugin (painted terrain in editor).
func get_terrain_height(x: float, z: float) -> float:
	if _terrain3d and _terrain3d.data:
		var h: float = _terrain3d.data.get_height(Vector3(x, 0.0, z))
		if not is_nan(h):
			return h
	return 0.0

## Internal shorthand for prop placement.
func _terrain_y(x: float, z: float) -> float:
	return get_terrain_height(x, z)

## Recursively search the scene tree for a Terrain3D node.
func _find_terrain3d(node: Node):
	if node.get_class() == "Terrain3D":
		return node
	for child in node.get_children():
		var found = _find_terrain3d(child)
		if found:
			return found
	return null

## Add a visible ground plane when Terrain3D is not available (web export fallback).
## Creates a large flat mesh + collision at y=0 so the world has a visible floor.
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

	# Visible mesh — large flat plane with a subtle sci-fi ground color
	var mesh_inst := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(2000.0, 2000.0)
	plane_mesh.subdivide_width = 0
	plane_mesh.subdivide_depth = 0
	mesh_inst.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.16, 1.0)  # Dark sci-fi ground
	mat.roughness = 0.95
	mat.metallic = 0.05
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	body.position = Vector3(0, -0.25, 0)  # Mesh surface at y=0
	add_child(body)
	print("AreaManager: Fallback ground plane added at y=0")

var _gate_update_timer: float = 0.0
var _last_rejected_gate: String = ""  # Prevents chat spam — only message once per gated area

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
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
	for area_id in DataManager.areas:
		_create_area_ground(area_id, DataManager.areas[area_id])
	print("AreaManager: Built %d area grounds" % _area_bodies.size())

func _create_area_ground(area_id: String, data: Dictionary) -> void:
	var center_x: float = float(data.get("center", {}).get("x", 0.0))
	var center_z: float = float(data.get("center", {}).get("z", 0.0))
	var radius: float = data.get("radius", 50.0)
	var ground_color_int: int = int(data.get("groundColor", 0x1a2030))
	var floor_y: float = float(data.get("floorY", 0.0))

	var logical_center: Vector3 = Vector3(center_x, floor_y, center_z)
	_area_bodies[area_id] = { "center": logical_center, "radius": radius }

	var base_color: Color = _hex_to_color(ground_color_int)

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
	var sign_pole: CSGCylinder3D = CSGCylinder3D.new()
	sign_pole.radius = 0.04
	sign_pole.height = 8.0
	sign_pole.sides = 4
	sign_pole.position = Vector3(center_x, _terrain_y(center_x, center_z) + 4.0, center_z)
	var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.3, 0.5, 0.6, 0.4)
	pole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sign_pole.material = pole_mat
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

	# ── Edge atmosphere — subtle glow ring at terrain boundary ──
	_add_edge_atmosphere(area_id, center_x, center_z, radius, base_color, floor_y)

# ═══════════════════════════════════════════════════════════════════════════════
#  EDGE ATMOSPHERE — subtle glow ring at terrain boundaries
# ═══════════════════════════════════════════════════════════════════════════════

## Adds a ring of faint glowing fog at the terrain edge to mask the hard boundary.
## Uses a CSGTorus3D with a semi-transparent emissive material.
func _add_edge_atmosphere(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, floor_y: float) -> void:
	# Skip very small areas (like bio-lab) — edges aren't visible
	if radius < 25.0:
		return

	var edge_y: float = _terrain_y(cx + radius * 0.85, cz) if radius < 100.0 \
		else floor_y

	# Outer fog ring — wide, very faint
	var fog_ring: CSGTorus3D = CSGTorus3D.new()
	fog_ring.inner_radius = radius * 0.88
	fog_ring.outer_radius = radius * 1.02
	fog_ring.ring_sides = 8
	fog_ring.sides = 48 if radius > 100.0 else 32
	fog_ring.position = Vector3(cx, floor_y + 0.3, cz)

	var fog_mat: StandardMaterial3D = StandardMaterial3D.new()
	var fog_color: Color = base_color.lightened(0.2)
	fog_mat.albedo_color = Color(fog_color.r, fog_color.g, fog_color.b, 0.08)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.emission_enabled = true
	fog_mat.emission = fog_color
	fog_mat.emission_energy_multiplier = 0.3
	fog_mat.no_depth_test = false
	fog_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_ring.material = fog_mat
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

## Scatter rocks and boulders of various sizes
func _add_rocks_and_boulders(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = area_id.hash()

	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = base_color.darkened(0.3)
	rock_mat.roughness = 0.85
	rock_mat.metallic = 0.1

	# Scale count by area size, reduced by per-area clutter density
	var rock_count: int = int((12 + radius * 0.08) * _clutter_density(area_id))
	rock_count = maxi(rock_count, 2)  # Always at least a couple
	rock_count = mini(rock_count, 40)  # Cap for performance

	for i in range(rock_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(3.0, radius * 0.88)
		var rock_r: float = rng.randf_range(0.3, 2.5)
		var rx: float = cx + cos(angle) * dist
		var rz: float = cz + sin(angle) * dist
		var rock: CSGSphere3D = CSGSphere3D.new()
		rock.radius = rock_r
		rock.radial_segments = 6
		rock.rings = 4
		rock.position = Vector3(
			rx,
			_terrain_y(rx, rz) + rock_r * 0.2,
			rz
		)
		rock.scale = Vector3(
			1.0 + rng.randf() * 0.6,
			0.25 + rng.randf() * 0.5,
			1.0 + rng.randf() * 0.6
		)
		rock.rotation.y = rng.randf() * TAU
		rock.material = rock_mat
		add_child(rock)
		# No collision — scatter rocks are decorative; collision traps the player

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
		var pedestal: CSGCylinder3D = CSGCylinder3D.new()
		pedestal.radius = 0.8
		pedestal.height = 0.6
		pedestal.sides = 6
		pedestal.position = Vector3(px, ty + 0.3, pz)
		var ped_mat: StandardMaterial3D = StandardMaterial3D.new()
		ped_mat.albedo_color = base_color.darkened(0.2)
		ped_mat.metallic = 0.6
		ped_mat.roughness = 0.3
		pedestal.material = ped_mat
		add_child(pedestal)
		# No collision — thin pylons are walk-through scenery to avoid trapping player

		# Main column
		var column: CSGCylinder3D = CSGCylinder3D.new()
		column.radius = 0.25
		column.height = height
		column.sides = 8
		column.position = Vector3(px, ty + height * 0.5 + 0.6, pz)
		var col_mat: StandardMaterial3D = StandardMaterial3D.new()
		col_mat.albedo_color = base_color.darkened(0.1)
		col_mat.metallic = 0.7
		col_mat.roughness = 0.2
		col_mat.emission_enabled = true
		col_mat.emission = base_color.lightened(0.3)
		col_mat.emission_energy_multiplier = 0.5
		column.material = col_mat
		add_child(column)

		# Glowing energy orb on top
		var orb: CSGSphere3D = CSGSphere3D.new()
		orb.radius = 0.4
		orb.radial_segments = 12
		orb.rings = 6
		orb.position = Vector3(px, ty + height + 1.0, pz)
		var orb_mat: StandardMaterial3D = StandardMaterial3D.new()
		orb_mat.albedo_color = base_color.lightened(0.5)
		orb_mat.emission_enabled = true
		orb_mat.emission = base_color.lightened(0.6)
		orb_mat.emission_energy_multiplier = 2.0
		orb.material = orb_mat
		add_child(orb)

		# Horizontal ring around the orb
		var h_ring: CSGTorus3D = CSGTorus3D.new()
		h_ring.inner_radius = 0.55
		h_ring.outer_radius = 0.7
		h_ring.ring_sides = 6
		h_ring.sides = 16
		h_ring.position = Vector3(px, ty + height + 1.0, pz)
		h_ring.material = orb_mat
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

		var panel: CSGBox3D = CSGBox3D.new()
		var pw: float = rng.randf_range(1.5, 4.0)
		var pd: float = rng.randf_range(1.0, 3.0)
		panel.size = Vector3(pw, 0.08, pd)
		panel.position = Vector3(px, ty + 0.04, pz)  # Flush with terrain surface
		panel.rotation.y = rng.randf() * TAU

		var panel_mat: StandardMaterial3D = StandardMaterial3D.new()
		var panel_color: Color = base_color.lightened(0.3)
		panel_mat.albedo_color = panel_color
		panel_mat.emission_enabled = true
		panel_mat.emission = panel_color.lightened(0.2)
		panel_mat.emission_energy_multiplier = 1.5
		panel_mat.metallic = 0.8
		panel_mat.roughness = 0.1
		panel.material = panel_mat
		add_child(panel)

		# Border frame around panel
		var frame: CSGBox3D = CSGBox3D.new()
		frame.size = Vector3(pw + 0.2, 0.12, pd + 0.2)
		frame.position = Vector3(px, ty + 0.02, pz)
		frame.rotation.y = panel.rotation.y
		var frame_mat: StandardMaterial3D = StandardMaterial3D.new()
		frame_mat.albedo_color = base_color.darkened(0.15)
		frame_mat.metallic = 0.5
		frame_mat.roughness = 0.3
		frame.material = frame_mat
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
		var beam: CSGCylinder3D = CSGCylinder3D.new()
		beam.radius = 0.3
		beam.height = beam_h
		beam.sides = 8
		beam.position = Vector3(px, ty + beam_h * 0.5, pz)
		var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
		var beam_color: Color = base_color.lightened(0.5)
		beam_mat.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.15)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.emission_enabled = true
		beam_mat.emission = beam_color
		beam_mat.emission_energy_multiplier = 1.5
		beam_mat.no_depth_test = true
		beam.material = beam_mat
		add_child(beam)

		# Base emitter disc
		var base_disc: CSGCylinder3D = CSGCylinder3D.new()
		base_disc.radius = 1.2
		base_disc.height = 0.15
		base_disc.sides = 12
		base_disc.position = Vector3(px, ty + 0.08, pz)
		var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
		disc_mat.albedo_color = beam_color
		disc_mat.emission_enabled = true
		disc_mat.emission = beam_color
		disc_mat.emission_energy_multiplier = 1.5
		disc_mat.metallic = 0.5
		base_disc.material = disc_mat
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

		var crystal: CSGCylinder3D = CSGCylinder3D.new()
		crystal.radius = c_radius
		crystal.height = c_height
		crystal.sides = 5
		crystal.cone = true
		crystal.position = Vector3(
			crx,
			ty + c_height * 0.5,
			crz
		)
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
		crystal.material = cryst_mat
		add_child(crystal)
		# No collision — scatter crystals are decorative scenery

		# Add cluster mates (2-3 smaller crystals near each large one)
		if rng.randf() > 0.4:
			for j in range(rng.randi_range(1, 3)):
				var sub: CSGCylinder3D = CSGCylinder3D.new()
				sub.radius = c_radius * rng.randf_range(0.3, 0.6)
				sub.height = c_height * rng.randf_range(0.3, 0.7)
				sub.sides = 5
				sub.cone = true
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
				sub.material = cryst_mat
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
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = 0.08 + rng.randf() * 0.06
		stem.height = stem_h
		stem.sides = 6
		stem.position = Vector3(px, ty + stem_h * 0.5, pz)
		stem.rotation.z = rng.randf_range(-0.2, 0.2)
		stem.rotation.x = rng.randf_range(-0.1, 0.1)
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.06, 0.25, 0.12)
		stem_mat.roughness = 0.55
		stem_mat.emission_enabled = true
		stem_mat.emission = Color(0.04, 0.12, 0.06)
		stem_mat.emission_energy_multiplier = 0.4
		stem.material = stem_mat
		add_child(stem)

		# Bulb on top
		var bulb: CSGSphere3D = CSGSphere3D.new()
		var bulb_r: float = rng.randf_range(0.2, 0.7)
		bulb.radius = bulb_r
		bulb.radial_segments = 10
		bulb.rings = 6
		bulb.position = Vector3(px, ty + stem_h + bulb_r * 0.3, pz)
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
		bulb.material = bulb_mat
		add_child(bulb)

		# Tendril branches (1-3 per plant)
		if rng.randf() > 0.5:
			for j in range(rng.randi_range(1, 3)):
				var tendril: CSGCylinder3D = CSGCylinder3D.new()
				tendril.radius = 0.03
				tendril.height = stem_h * rng.randf_range(0.3, 0.6)
				tendril.sides = 4
				var t_y: float = ty + stem_h * rng.randf_range(0.3, 0.7)
				tendril.position = Vector3(px, t_y, pz)
				tendril.rotation = Vector3(
					rng.randf_range(-0.8, 0.8),
					rng.randf() * TAU,
					rng.randf_range(-0.5, 0.5)
				)
				tendril.material = stem_mat
				add_child(tendril)

				# Small light on tendril tip
				var tip: CSGSphere3D = CSGSphere3D.new()
				tip.radius = 0.08
				tip.radial_segments = 6
				tip.rings = 4
				var tip_offset: Vector3 = Vector3(
					sin(tendril.rotation.y) * tendril.height * 0.4,
					tendril.height * 0.3,
					cos(tendril.rotation.y) * tendril.height * 0.4
				)
				tip.position = tendril.position + tip_offset
				tip.material = bulb_mat
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

		var debris: CSGBox3D = CSGBox3D.new()
		var s: float = rng.randf_range(0.2, 0.8)
		# Varied aspect ratios to look like broken ship/tech fragments
		var aspect: int = rng.randi_range(0, 2)
		match aspect:
			0: debris.size = Vector3(s, s * 0.3, s * 1.2)   # flat plate
			1: debris.size = Vector3(s * 0.4, s * 0.4, s * 1.5)  # beam fragment
			2: debris.size = Vector3(s, s * 0.5, s * 0.5)  # chunk
		var ty: float = _terrain_y(px, pz)
		debris.position = Vector3(px, ty + hover_h, pz)
		debris.rotation = Vector3(
			rng.randf() * TAU,
			rng.randf() * TAU,
			rng.randf() * TAU
		)
		debris.material = debris_mat
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
		var pipe: CSGCylinder3D = CSGCylinder3D.new()
		pipe.radius = pipe_r
		pipe.height = pipe_len
		pipe.sides = 8
		pipe.position = Vector3(px, ty + pipe_h, pz)
		pipe.rotation = Vector3(0, pipe_yaw, PI / 2.0)
		pipe.material = pipe_mat
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
			var leg: CSGCylinder3D = CSGCylinder3D.new()
			leg.radius = pipe_r * 0.4
			leg.height = leg_h
			leg.sides = 6
			leg.position = Vector3(leg_x, leg_ty + leg_h * 0.5, leg_z)
			leg.material = pipe_mat
			add_child(leg)

		# Pipe junction rings
		for j in range(rng.randi_range(1, 3)):
			var junc: CSGTorus3D = CSGTorus3D.new()
			junc.inner_radius = pipe_r
			junc.outer_radius = pipe_r + 0.08
			junc.ring_sides = 6
			junc.sides = 8
			var frac: float = rng.randf_range(-0.4, 0.4)
			junc.position = Vector3(
				px + cos(pipe_yaw) * pipe_len * frac,
				ty + pipe_h,
				pz + sin(pipe_yaw) * pipe_len * frac
			)
			junc.rotation.z = PI / 2.0
			junc.rotation.y = pipe_yaw
			junc.material = pipe_mat
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
		var wall: CSGBox3D = CSGBox3D.new()
		wall.size = Vector3(wall_w, wall_h, 0.4)
		wall.position = Vector3(px, ty + wall_h * 0.5, pz)
		wall.rotation.y = rng.randf() * TAU
		wall.material = wall_mat
		add_child(wall)
		# No collision — ruined walls are walk-through scenery to avoid trapping player

		# Broken top — irregular jagged silhouette (smaller boxes on top)
		for j in range(rng.randi_range(2, 5)):
			var chunk: CSGBox3D = CSGBox3D.new()
			var cw: float = rng.randf_range(0.5, wall_w * 0.4)
			var ch: float = rng.randf_range(0.5, 2.0)
			chunk.size = Vector3(cw, ch, 0.4)
			chunk.position = Vector3(
				px + (rng.randf() - 0.5) * wall_w * 0.5,
				ty + wall_h + ch * 0.3,
				pz
			)
			chunk.rotation.y = wall.rotation.y
			chunk.rotation.z = rng.randf_range(-0.15, 0.15)
			chunk.material = wall_mat
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
	var center_plat: CSGCylinder3D = CSGCylinder3D.new()
	center_plat.radius = 12.0
	center_plat.height = 0.25
	center_plat.sides = 32
	center_plat.position = Vector3(cx, y_base + 0.15, cz)
	center_plat.material = dark_metal
	add_child(center_plat)

	# Central platform glowing edge
	var center_ring: CSGTorus3D = CSGTorus3D.new()
	center_ring.inner_radius = 11.5
	center_ring.outer_radius = 12.0
	center_ring.ring_sides = 6
	center_ring.sides = 32
	center_ring.position = Vector3(cx, y_base + 0.3, cz)
	center_ring.material = glow_mat
	add_child(center_ring)

	# Holographic station map (center feature)
	var holo_base: CSGCylinder3D = CSGCylinder3D.new()
	holo_base.radius = 1.2
	holo_base.height = 0.8
	holo_base.sides = 8
	holo_base.position = Vector3(cx, y_base + 0.7, cz)
	holo_base.material = dark_metal
	add_child(holo_base)

	var holo_globe: CSGSphere3D = CSGSphere3D.new()
	holo_globe.radius = 0.6
	holo_globe.radial_segments = 12
	holo_globe.rings = 8
	holo_globe.position = Vector3(cx, y_base + 1.5, cz)
	var holo_mat: StandardMaterial3D = StandardMaterial3D.new()
	holo_mat.albedo_color = Color(0.1, 0.5, 0.8, 0.4)
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo_mat.emission_enabled = true
	holo_mat.emission = Color(0.2, 0.7, 1.0)
	holo_mat.emission_energy_multiplier = 1.0
	holo_globe.material = holo_mat
	add_child(holo_globe)
	_animated_nodes.append({
		"node": holo_globe, "type": "rotate",
		"speed": 0.4, "phase": 0.0
	})

	# Holo ring orbiting the globe
	var holo_ring: CSGTorus3D = CSGTorus3D.new()
	holo_ring.inner_radius = 0.7
	holo_ring.outer_radius = 0.75
	holo_ring.ring_sides = 4
	holo_ring.sides = 20
	holo_ring.position = Vector3(cx, y_base + 1.5, cz)
	holo_ring.rotation.x = 0.4
	holo_ring.material = glow_mat
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
		var post: CSGCylinder3D = CSGCylinder3D.new()
		post.radius = 0.08
		post.height = 3.5
		post.sides = 6
		post.position = Vector3(lx, y_base + 1.75, lz)
		post.material = metal_mat
		add_child(post)

		# Lamp head
		var lamp: CSGSphere3D = CSGSphere3D.new()
		lamp.radius = 0.2
		lamp.radial_segments = 8
		lamp.rings = 4
		lamp.position = Vector3(lx, y_base + 3.6, lz)
		lamp.material = warm_glow
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
		var counter: CSGBox3D = CSGBox3D.new()
		counter.size = Vector3(2.5, 0.9, 0.8)
		counter.position = Vector3(sx, y_base + 0.5, sz + 1.5)
		counter.material = metal_mat
		add_child(counter)
		_add_box_collision(counter, Vector3(2.5, 0.9, 0.8))

		# Awning roof
		var awning: CSGBox3D = CSGBox3D.new()
		awning.size = Vector3(3.5, 0.08, 2.5)
		awning.position = Vector3(sx, y_base + 3.0, sz + 0.5)
		var awning_mat: StandardMaterial3D = StandardMaterial3D.new()
		awning_mat.albedo_color = sc
		awning_mat.metallic = 0.3
		awning_mat.roughness = 0.5
		awning_mat.emission_enabled = true
		awning_mat.emission = sc.lightened(0.2)
		awning_mat.emission_energy_multiplier = 0.3
		awning.material = awning_mat
		add_child(awning)

		# Support poles
		for px_off in [-1.5, 1.5]:
			var pole: CSGCylinder3D = CSGCylinder3D.new()
			pole.radius = 0.06
			pole.height = 2.8
			pole.sides = 6
			pole.position = Vector3(sx + px_off, y_base + 1.4, sz + 1.7)
			pole.material = metal_mat
			add_child(pole)

		# Small glow strip under awning
		var strip: CSGBox3D = CSGBox3D.new()
		strip.size = Vector3(2.8, 0.04, 0.04)
		strip.position = Vector3(sx, y_base + 2.9, sz - 0.6)
		var strip_mat: StandardMaterial3D = StandardMaterial3D.new()
		strip_mat.albedo_color = sc.lightened(0.4)
		strip_mat.emission_enabled = true
		strip_mat.emission = sc.lightened(0.5)
		strip_mat.emission_energy_multiplier = 1.0
		strip.material = strip_mat
		add_child(strip)

	# ── Landing pad (NE quadrant) ──
	var pad: CSGCylinder3D = CSGCylinder3D.new()
	pad.radius = 8.0
	pad.height = 0.3
	pad.sides = 32
	pad.position = Vector3(cx + 25, y_base + 0.2, cz + 20)
	pad.material = metal_mat
	add_child(pad)

	for i in range(3):
		var mark: CSGTorus3D = CSGTorus3D.new()
		mark.inner_radius = 2.0 + float(i) * 2.0
		mark.outer_radius = 2.2 + float(i) * 2.0
		mark.ring_sides = 6
		mark.sides = 24
		mark.position = Vector3(cx + 25, y_base + 0.4, cz + 20)
		mark.material = glow_mat
		add_child(mark)

	# Pad corner beacons
	for bi in range(4):
		var ba: float = float(bi) / 4.0 * TAU + PI * 0.25
		var bx: float = cx + 25 + cos(ba) * 7.5
		var bz: float = cz + 20 + sin(ba) * 7.5
		var pad_beacon: CSGCylinder3D = CSGCylinder3D.new()
		pad_beacon.radius = 0.12
		pad_beacon.height = 2.0
		pad_beacon.sides = 6
		pad_beacon.position = Vector3(bx, y_base + 1.0, bz)
		pad_beacon.material = metal_mat
		add_child(pad_beacon)

		var pad_light: CSGSphere3D = CSGSphere3D.new()
		pad_light.radius = 0.15
		pad_light.radial_segments = 6
		pad_light.rings = 4
		pad_light.position = Vector3(bx, y_base + 2.1, bz)
		pad_light.material = glow_mat
		add_child(pad_light)
		_animated_nodes.append({
			"node": pad_light, "type": "pulse_scale",
			"speed": 1.5, "phase": float(bi),
			"min_scale": 0.7, "max_scale": 1.2
		})

	# ── Control tower (NW) ──
	var tower_base: CSGCylinder3D = CSGCylinder3D.new()
	tower_base.radius = 1.8
	tower_base.height = 14.0
	tower_base.sides = 8
	tower_base.position = Vector3(cx - 20, y_base + 7.0, cz - 15)
	tower_base.material = metal_mat
	add_child(tower_base)
	_add_cylinder_collision(tower_base, 2.0, 14.0)

	# Tower windows (rings)
	for wi in range(3):
		var win_ring: CSGTorus3D = CSGTorus3D.new()
		win_ring.inner_radius = 1.7
		win_ring.outer_radius = 1.85
		win_ring.ring_sides = 4
		win_ring.sides = 8
		win_ring.position = Vector3(cx - 20, y_base + 4.0 + float(wi) * 4.0, cz - 15)
		win_ring.material = glow_mat
		add_child(win_ring)

	# Tower observation deck
	var deck: CSGCylinder3D = CSGCylinder3D.new()
	deck.radius = 3.5
	deck.height = 2.5
	deck.sides = 12
	deck.position = Vector3(cx - 20, y_base + 15.5, cz - 15)
	deck.material = metal_mat
	add_child(deck)

	# Deck railing
	var deck_rail: CSGTorus3D = CSGTorus3D.new()
	deck_rail.inner_radius = 3.3
	deck_rail.outer_radius = 3.5
	deck_rail.ring_sides = 4
	deck_rail.sides = 12
	deck_rail.position = Vector3(cx - 20, y_base + 17.0, cz - 15)
	deck_rail.material = dark_metal
	add_child(deck_rail)

	# Tower beacon
	var beacon: CSGSphere3D = CSGSphere3D.new()
	beacon.radius = 0.6
	beacon.radial_segments = 10
	beacon.rings = 6
	beacon.position = Vector3(cx - 20, y_base + 17.8, cz - 15)
	beacon.material = glow_mat
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
		var ant: CSGCylinder3D = CSGCylinder3D.new()
		ant.radius = 0.06
		ant.height = ant_h
		ant.sides = 6
		ant.position = Vector3(ax, y_base + ant_h * 0.5, cz - 22)
		ant.material = metal_mat
		add_child(ant)

		var dish: CSGSphere3D = CSGSphere3D.new()
		dish.radius = 0.9
		dish.radial_segments = 8
		dish.rings = 4
		dish.position = Vector3(ax, y_base + ant_h + 0.5, cz - 22)
		dish.scale = Vector3(1.0, 0.3, 1.0)
		dish.material = metal_mat
		add_child(dish)

		# Dish glow point
		var dish_glow: CSGSphere3D = CSGSphere3D.new()
		dish_glow.radius = 0.12
		dish_glow.radial_segments = 6
		dish_glow.rings = 4
		dish_glow.position = Vector3(ax, y_base + ant_h + 0.6, cz - 22)
		dish_glow.material = glow_mat
		add_child(dish_glow)

	# ── Supply depot (SE — cargo crates and containers) ──
	var depot_positions: Array[Vector3] = [
		Vector3(cx + 20, y_base + 0.5, cz - 8),
		Vector3(cx + 22, y_base + 0.5, cz - 6),
		Vector3(cx + 21, y_base + 1.0, cz - 7),
		Vector3(cx + 23, y_base + 0.5, cz - 9),
	]
	for pos in depot_positions:
		var crate: CSGBox3D = CSGBox3D.new()
		crate.size = Vector3(1.2 + randf() * 0.4, 0.8 + randf() * 0.4, 1.2 + randf() * 0.3)
		crate.position = pos
		crate.rotation.y = randf() * 0.8
		crate.material = crate_mat
		add_child(crate)

	# Large shipping container
	var container: CSGBox3D = CSGBox3D.new()
	container.size = Vector3(4.0, 2.5, 2.0)
	container.position = Vector3(cx + 22, y_base + 1.25, cz - 12)
	var container_mat: StandardMaterial3D = StandardMaterial3D.new()
	container_mat.albedo_color = Color(0.18, 0.3, 0.22)
	container_mat.metallic = 0.6
	container_mat.roughness = 0.35
	container.material = container_mat
	add_child(container)
	_add_box_collision(container, Vector3(4.0, 2.5, 2.0))

	# Container marking strip
	var cont_strip: CSGBox3D = CSGBox3D.new()
	cont_strip.size = Vector3(3.8, 0.15, 0.05)
	cont_strip.position = Vector3(cx + 22, y_base + 2.2, cz - 11.0)
	cont_strip.material = warm_glow
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
		var barrier: CSGBox3D = CSGBox3D.new()
		barrier.size = Vector3(8.0, 1.0, 0.3)
		barrier.position = Vector3(bx, y_base + 0.5, bz)
		barrier.rotation.y = angle + PI * 0.5
		barrier.material = dark_metal
		add_child(barrier)
		_add_box_collision(barrier, Vector3(8.0, 1.5, 0.5))

		# Barrier glow strip
		var b_strip: CSGBox3D = CSGBox3D.new()
		b_strip.size = Vector3(7.5, 0.06, 0.05)
		b_strip.position = Vector3(bx, y_base + 0.9, bz)
		b_strip.rotation.y = angle + PI * 0.5
		b_strip.material = glow_mat
		add_child(b_strip)

	# ── Commander's platform (north center — Vex & Grax area) ──
	var cmd_plat: CSGBox3D = CSGBox3D.new()
	cmd_plat.size = Vector3(8.0, 0.2, 4.0)
	cmd_plat.position = Vector3(cx, y_base + 0.15, cz - 25)
	cmd_plat.material = dark_metal
	add_child(cmd_plat)

	# Command console
	var console: CSGBox3D = CSGBox3D.new()
	console.size = Vector3(2.0, 1.0, 0.5)
	console.position = Vector3(cx + 2, y_base + 0.7, cz - 26)
	console.material = metal_mat
	add_child(console)

	var console_screen: CSGBox3D = CSGBox3D.new()
	console_screen.size = Vector3(1.6, 0.6, 0.04)
	console_screen.position = Vector3(cx + 2, y_base + 1.0, cz - 25.7)
	var screen_mat: StandardMaterial3D = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.3, 0.2)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.5, 0.3)
	screen_mat.emission_energy_multiplier = 1.5
	console_screen.material = screen_mat
	add_child(console_screen)

	# ── Researchers' alcove (south — Dr. Elara Voss & Archivist area) ──
	var res_plat: CSGBox3D = CSGBox3D.new()
	res_plat.size = Vector3(10.0, 0.15, 4.0)
	res_plat.position = Vector3(cx, y_base + 0.12, cz + 20)
	res_plat.material = dark_metal
	add_child(res_plat)

	# Research equipment
	var res_pod: CSGCylinder3D = CSGCylinder3D.new()
	res_pod.radius = 0.6
	res_pod.height = 2.5
	res_pod.sides = 8
	res_pod.position = Vector3(cx - 3, y_base + 1.25, cz + 21)
	var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
	pod_mat.albedo_color = Color(0.1, 0.15, 0.25, 0.5)
	pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pod_mat.emission_enabled = true
	pod_mat.emission = Color(0.2, 0.4, 0.6)
	pod_mat.emission_energy_multiplier = 1.0
	res_pod.material = pod_mat
	add_child(res_pod)

	var res_pod2: CSGCylinder3D = CSGCylinder3D.new()
	res_pod2.radius = 0.5
	res_pod2.height = 2.0
	res_pod2.sides = 8
	res_pod2.position = Vector3(cx + 3, y_base + 1.0, cz + 21)
	res_pod2.material = pod_mat
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
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = 0.5
		stem.height = stem_h
		stem.sides = 8
		stem.position = Vector3(px, y_base + stem_h * 0.5, pz)
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.12, 0.3, 0.18)
		stem_mat.roughness = 0.7
		stem.material = stem_mat
		add_child(stem)
		# No collision — mushroom stems are walk-through scenery

		# Large cap
		var cap: CSGCylinder3D = CSGCylinder3D.new()
		cap.radius = rng.randf_range(2.0, 4.0)
		cap.height = 0.8
		cap.sides = 12
		cap.position = Vector3(px, y_base + stem_h + 0.3, pz)
		cap.material = cap_mat
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
		var vent: CSGCylinder3D = CSGCylinder3D.new()
		vent.radius = 0.6
		vent.height = 0.5
		vent.sides = 8
		vent.position = Vector3(
			cx + cos(angle) * dist,
			y_base + 0.25,
			cz + sin(angle) * dist
		)
		vent.material = vent_mat
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

		var pod: CSGSphere3D = CSGSphere3D.new()
		pod.radius = rng.randf_range(0.8, 2.5)
		pod.rings = 8
		pod.radial_segments = 8
		pod.position = Vector3(px, py + pod.radius * 0.5, pz)
		pod.material = pod_mat
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

		var reed: CSGCylinder3D = CSGCylinder3D.new()
		reed.radius = rng.randf_range(0.05, 0.15)
		reed.height = rng.randf_range(2.0, 5.0)
		reed.sides = 6
		reed.position = Vector3(px, py + reed.height * 0.5, pz)
		reed.material = reed_mat
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

		var wall: CSGBox3D = CSGBox3D.new()
		wall.size = Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(2.0, 4.5), rng.randf_range(0.5, 1.2))
		wall.position = Vector3(px, py + wall.size.y * 0.5, pz)
		wall.rotation.y = rng.randf() * TAU
		wall.material = chitin_mat
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
		var lp: CSGCylinder3D = CSGCylinder3D.new()
		lp.radius = 0.4
		lp.height = arch_h
		lp.sides = 8
		lp.position = Vector3(px - cos(yaw) * gap, py + arch_h * 0.5, pz - sin(yaw) * gap)
		lp.material = amber_mat
		add_child(lp)

		# Right pillar
		var rp: CSGCylinder3D = CSGCylinder3D.new()
		rp.radius = 0.4
		rp.height = arch_h
		rp.sides = 8
		rp.position = Vector3(px + cos(yaw) * gap, py + arch_h * 0.5, pz + sin(yaw) * gap)
		rp.material = amber_mat
		add_child(rp)

		# Crossbar
		var bar: CSGBox3D = CSGBox3D.new()
		bar.size = Vector3(gap * 2.0 + 0.8, 0.6, 0.6)
		bar.position = Vector3(px, py + arch_h, pz)
		bar.rotation.y = yaw
		bar.material = amber_mat
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
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = rng.randf_range(0.3, 0.7)
		stem.height = stem_h
		stem.sides = 8
		stem.position = Vector3(px, py + stem_h * 0.5, pz)
		stem.material = stem_mat
		add_child(stem)

		# Cap (flattened sphere)
		var cap: CSGSphere3D = CSGSphere3D.new()
		cap.radius = cap_r
		cap.rings = 8
		cap.radial_segments = 12
		cap.position = Vector3(px, py + stem_h + cap_r * 0.3, pz)
		cap.scale = Vector3(1.0, 0.35, 1.0)
		cap.material = cap_mat
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

		var tendril: CSGBox3D = CSGBox3D.new()
		tendril.size = Vector3(rng.randf_range(2.0, 6.0), 0.15, rng.randf_range(0.3, 0.8))
		tendril.position = Vector3(px, py + 0.1, pz)
		tendril.rotation.y = rng.randf() * TAU
		tendril.material = myc_mat
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

		var pillar: CSGCylinder3D = CSGCylinder3D.new()
		pillar.radius = rng.randf_range(0.3, 0.7)
		pillar.height = h
		pillar.sides = 6
		pillar.position = Vector3(px, py + h * 0.5, pz)
		pillar.material = pillar_mat
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

		var cocoon: CSGSphere3D = CSGSphere3D.new()
		cocoon.radius = rng.randf_range(0.5, 1.5)
		cocoon.rings = 6
		cocoon.radial_segments = 8
		cocoon.position = Vector3(px, py + rng.randf_range(1.0, 3.0), pz)
		cocoon.scale = Vector3(0.7, 1.3, 0.7)
		cocoon.material = cocoon_mat
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

		var block: CSGBox3D = CSGBox3D.new()
		var s: float = rng.randf_range(0.5, 2.0)
		block.size = Vector3(s * rng.randf_range(0.8, 1.5), s, s * rng.randf_range(0.8, 1.5))
		block.position = Vector3(px, py + block.size.y * 0.5, pz)
		block.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		block.material = stone_mat
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

		var pillar: CSGCylinder3D = CSGCylinder3D.new()
		pillar.radius = rng.randf_range(0.5, 2.0)
		pillar.height = pillar_h
		pillar.sides = 6
		pillar.position = Vector3(px, y_base + pillar_h * 0.5, pz)
		pillar.rotation = Vector3(
			rng.randf_range(-0.1, 0.1), 0,
			rng.randf_range(-0.1, 0.1)
		)
		pillar.material = void_mat
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

		var rift: CSGBox3D = CSGBox3D.new()
		rift.size = Vector3(rng.randf_range(0.5, 2.0), rift_h, 0.05)
		rift.position = Vector3(px, rift_ty + rift_h * 0.5, pz)
		rift.rotation.y = rng.randf() * TAU
		rift.material = rift_mat
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
			var leg: CSGCylinder3D = CSGCylinder3D.new()
			leg.radius = 0.15
			leg.height = tower_h
			leg.sides = 6
			leg.position = Vector3(
				px + cos(la) * 1.5,
				y_base + tower_h * 0.5,
				pz + sin(la) * 1.5
			)
			leg.rotation = Vector3(0.08 * cos(la), 0, 0.08 * sin(la))
			leg.material = metal_mat
			add_child(leg)

		# Platform at top
		var top: CSGBox3D = CSGBox3D.new()
		top.size = Vector3(4.0, 0.3, 4.0)
		top.position = Vector3(px, y_base + tower_h, pz)
		top.material = metal_mat
		add_child(top)
		# Collision cylinder around the tower footprint
		_add_cylinder_collision(top, 2.0, tower_h, -tower_h * 0.5)

		# Drill bit
		var drill: CSGCylinder3D = CSGCylinder3D.new()
		drill.radius = 0.4
		drill.height = 3.0
		drill.sides = 6
		drill.cone = true
		drill.position = Vector3(px, y_base + tower_h - 2.0, pz)
		drill.rotation.x = PI
		drill.material = orange_mat
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
		var beam: CSGBox3D = CSGBox3D.new()
		beam.size = Vector3(conv_len, 0.3, 0.8)
		beam.position = Vector3(px, y_base + conv_h, pz)
		beam.rotation.y = angle
		beam.material = metal_mat
		add_child(beam)

		# Support legs
		for j in range(4):
			var frac: float = -0.4 + float(j) * 0.27
			var support: CSGCylinder3D = CSGCylinder3D.new()
			support.radius = 0.1
			support.height = conv_h
			support.sides = 6
			support.position = Vector3(
				px + cos(angle) * conv_len * frac,
				y_base + conv_h * 0.5,
				pz + sin(angle) * conv_len * frac
			)
			support.material = metal_mat
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
	var reactor_base: CSGCylinder3D = CSGCylinder3D.new()
	reactor_base.radius = 1.8
	reactor_base.height = 0.35
	reactor_base.sides = 16
	reactor_base.position = Vector3(cx, y_base + 0.18, cz)
	reactor_base.material = lab_mat
	add_child(reactor_base)

	var reactor_glass: CSGCylinder3D = CSGCylinder3D.new()
	reactor_glass.radius = 1.2
	reactor_glass.height = 3.0
	reactor_glass.sides = 12
	reactor_glass.position = Vector3(cx, y_base + 1.85, cz)
	reactor_glass.material = glass_mat
	add_child(reactor_glass)

	var reactor_cap: CSGCylinder3D = CSGCylinder3D.new()
	reactor_cap.radius = 1.5
	reactor_cap.height = 0.25
	reactor_cap.sides = 16
	reactor_cap.position = Vector3(cx, y_base + 3.5, cz)
	reactor_cap.material = lab_mat
	add_child(reactor_cap)

	# Slow-spinning glow ring around reactor
	var ring: CSGTorus3D = CSGTorus3D.new()
	ring.inner_radius = 1.6
	ring.outer_radius = 2.0
	ring.ring_sides = 6
	ring.sides = 20
	ring.position = Vector3(cx, y_base + 2.0, cz)
	ring.material = glow_mat
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

		var pod_base: CSGCylinder3D = CSGCylinder3D.new()
		pod_base.radius = 0.8
		pod_base.height = 0.3
		pod_base.sides = 10
		pod_base.position = Vector3(px, y_base + 0.15, pz)
		pod_base.material = lab_mat
		add_child(pod_base)

		var pod_glass: CSGCylinder3D = CSGCylinder3D.new()
		pod_glass.radius = 0.6
		pod_glass.height = 2.5
		pod_glass.sides = 10
		pod_glass.position = Vector3(px, y_base + 1.55, pz)
		pod_glass.material = glass_mat
		add_child(pod_glass)

		var pod_cap: CSGCylinder3D = CSGCylinder3D.new()
		pod_cap.radius = 0.8
		pod_cap.height = 0.2
		pod_cap.sides = 10
		pod_cap.position = Vector3(px, y_base + 2.9, pz)
		pod_cap.material = lab_mat
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
var _gate_barriers: Dictionary = {}  # { area_id: Array[CSGBox3D] }

func _build_corridors() -> void:
	for corridor_data in DataManager.corridors:
		_create_corridor(corridor_data)
	print("AreaManager: Built %d corridors" % DataManager.corridors.size())

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
			var barrier: CSGBox3D = CSGBox3D.new()
			barrier.name = "GateBarrier_%s" % area_id
			if is_vertical:
				barrier.size = Vector3(maxf(corr_w, 10.0), 5.0, 0.6)
			else:
				barrier.size = Vector3(0.6, 5.0, maxf(corr_d, 10.0))
			barrier.position = gate_pos
			barrier.position.y = 2.5  # Center vertically

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.8, 0.15, 0.1, 0.25)  # Red = locked
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.15, 0.1)
			mat.emission_energy_multiplier = 0.8
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			barrier.material = mat

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
			var mat: StandardMaterial3D = barrier.material as StandardMaterial3D
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
			var post: CSGCylinder3D = CSGCylinder3D.new()
			post.radius = 0.08
			post.height = 2.5
			post.sides = 6
			post.position = post_pos + Vector3(0, 1.25, 0)
			post.material = post_mat
			add_child(post)

			# Lamp orb on top
			var lamp: CSGSphere3D = CSGSphere3D.new()
			lamp.radius = 0.18
			lamp.radial_segments = 8
			lamp.rings = 4
			lamp.position = post_pos + Vector3(0, 2.6, 0)
			lamp.material = lamp_mat
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
			var lp: CSGCylinder3D = CSGCylinder3D.new()
			lp.radius = 0.2
			lp.height = arch_h
			lp.sides = 6
			if is_vertical:
				lp.position = arch_pos + Vector3(-arch_span * 0.5, arch_h * 0.5, 0)
			else:
				lp.position = arch_pos + Vector3(0, arch_h * 0.5, -arch_span * 0.5)
			lp.material = post_mat
			add_child(lp)

			# Right pillar
			var rp_arch: CSGCylinder3D = CSGCylinder3D.new()
			rp_arch.radius = 0.2
			rp_arch.height = arch_h
			rp_arch.sides = 6
			if is_vertical:
				rp_arch.position = arch_pos + Vector3(arch_span * 0.5, arch_h * 0.5, 0)
			else:
				rp_arch.position = arch_pos + Vector3(0, arch_h * 0.5, arch_span * 0.5)
			rp_arch.material = post_mat
			add_child(rp_arch)

			# Cross beam
			var crossbeam: CSGBox3D = CSGBox3D.new()
			if is_vertical:
				crossbeam.size = Vector3(arch_span + 0.5, 0.25, 0.25)
			else:
				crossbeam.size = Vector3(0.25, 0.25, arch_span + 0.5)
			crossbeam.position = arch_pos + Vector3(0, arch_h, 0)
			crossbeam.material = post_mat
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
				if node is CSGCylinder3D:
					var csg: CSGCylinder3D = node as CSGCylinder3D
					if csg.material is StandardMaterial3D:
						var m: StandardMaterial3D = csg.material as StandardMaterial3D
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
		# Player is in their own area — reset rejected gate so message can fire again later
		_last_rejected_gate = ""
		return

	if new_area != GameState.current_area:
		# ── Area gate check ──
		if not _check_area_gate(new_area):
			_push_player_back()
			return
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

## Check if the player meets requirements to enter an area
func _check_area_gate(area_id: String) -> bool:
	var reqs: Dictionary = DataManager.get_area_requirements(area_id)
	if reqs.is_empty():
		return true  # No requirements — always open

	# Only show chat message once per rejected area — resets when player returns to own area
	var can_message: bool = _last_rejected_gate != area_id

	# Check combat level
	var req_level: int = int(reqs.get("combat_level", 0))
	if req_level > 0:
		var player_level: int = GameState.get_combat_level()
		if player_level < req_level:
			if can_message:
				var area_data: Dictionary = DataManager.get_area(area_id)
				var area_name: String = str(area_data.get("name", area_id))
				EventBus.chat_message.emit(
					"Requires Combat Level %d to enter %s (current: %d)" % [req_level, area_name, player_level],
					"system"
				)
				_last_rejected_gate = area_id
			return false

	# Check quest completion
	var req_quest: String = str(reqs.get("quest", ""))
	if req_quest != "":
		if not GameState.completed_quests.has(req_quest):
			if can_message:
				var area_data: Dictionary = DataManager.get_area(area_id)
				var area_name: String = str(area_data.get("name", area_id))
				var quest_data: Dictionary = DataManager.get_quest(req_quest)
				var quest_name: String = str(quest_data.get("name", req_quest))
				EventBus.chat_message.emit(
					"Complete \"%s\" to unlock %s" % [quest_name, area_name],
					"system"
				)
				_last_rejected_gate = area_id
			return false

	return true

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
#  ATMOSPHERE
# ═══════════════════════════════════════════════════════════════════════════════

var _dir_light: DirectionalLight3D = null

func _update_atmosphere(area_id: String) -> void:
	var atmos: Dictionary = DataManager.get_atmosphere(area_id)
	if atmos.is_empty() or world_env == null:
		return

	var env: Environment = world_env.environment
	if env == null:
		return

	var fog_color_int: int = int(atmos.get("fogColor", 0x020810))
	env.fog_light_color = _hex_to_color(fog_color_int).lightened(0.1)
	env.fog_density = float(atmos.get("fogDensity", 0.005))

	var ambient_color_int: int = int(atmos.get("ambientColor", 0x1a2a4a))
	env.ambient_light_color = _hex_to_color(ambient_color_int).lightened(0.2)
	env.ambient_light_energy = maxf(float(atmos.get("ambientInt", 0.5)), 0.6)

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

# ═══════════════════════════════════════════════════════════════════════════════
#  UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

func _hex_to_color(hex: int) -> Color:
	var r: float = ((hex >> 16) & 0xFF) / 255.0
	var g: float = ((hex >> 8) & 0xFF) / 255.0
	var b: float = (hex & 0xFF) / 255.0
	return Color(r, g, b, 1.0)
