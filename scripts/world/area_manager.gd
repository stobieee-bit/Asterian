## AreaManager — Builds a richly detailed 3D sci-fi world from JSON area data
##
## Reads AREAS, CORRUPTED_AREAS, and CORRIDORS from DataManager and generates:
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
	_build_areas()
	_build_corridors()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	_check_area_transition()
	_animate_world(delta)

# ═══════════════════════════════════════════════════════════════════════════════
#  WORLD BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func _build_areas() -> void:
	for area_id in DataManager.areas:
		var data: Dictionary = DataManager.areas[area_id]
		_create_area_ground(area_id, data)
	for area_id in DataManager.corrupted_areas:
		var data: Dictionary = DataManager.corrupted_areas[area_id]
		_create_area_ground(area_id, data)
	print("AreaManager: Built %d area grounds" % _area_bodies.size())

func _create_area_ground(area_id: String, data: Dictionary) -> void:
	var center_x: float = float(data.get("center", {}).get("x", 0.0))
	var center_z: float = float(data.get("center", {}).get("z", 0.0))
	var radius: float = data.get("radius", 50.0)
	var ground_color_int: int = int(data.get("groundColor", 0x1a2030))

	var logical_center: Vector3 = Vector3(center_x, float(data.get("floorY", 0.0)), center_z)
	_area_bodies[area_id] = { "center": logical_center, "radius": radius }

	# Visual Y offset to prevent z-fighting
	var visual_y_bump: float = 0.0
	if radius < 30:
		visual_y_bump = 0.06
	elif radius < 80:
		visual_y_bump = 0.04
	elif radius < 300:
		visual_y_bump = 0.02

	# ── Ground disc ──
	var ground: CSGCylinder3D = CSGCylinder3D.new()
	ground.name = "Ground_%s" % area_id
	ground.radius = radius
	ground.height = 0.2
	ground.sides = 64 if radius > 100 else 48
	ground.position = Vector3(center_x, GROUND_Y + visual_y_bump, center_z)

	var base_color: Color = _hex_to_color(ground_color_int)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = base_color.lightened(0.2)
	mat.roughness = 0.45
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = base_color.lightened(0.35)
	mat.emission_energy_multiplier = 0.25
	mat.uv1_scale = Vector3(radius / 8.0, radius / 8.0, 1.0)
	if radius < 30:
		mat.render_priority = 3
	elif radius < 80:
		mat.render_priority = 2
	elif radius < 300:
		mat.render_priority = 1
	else:
		mat.render_priority = 0
	ground.material = mat

	# Collision shape
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.4
	col_shape.shape = shape
	static_body.add_child(col_shape)
	ground.add_child(static_body)
	add_child(ground)

	# ── Edge ring — subtle glowing border ──
	var edge_ring: CSGTorus3D = CSGTorus3D.new()
	edge_ring.name = "Edge_%s" % area_id
	edge_ring.inner_radius = radius - 0.3
	edge_ring.outer_radius = radius + 0.3
	edge_ring.ring_sides = 8
	edge_ring.sides = 64 if radius > 100 else 48
	edge_ring.position = Vector3(center_x, GROUND_Y + 0.15 + visual_y_bump, center_z)
	var edge_mat: StandardMaterial3D = StandardMaterial3D.new()
	edge_mat.albedo_color = base_color.lightened(0.2)
	edge_mat.albedo_color.a = 0.3
	edge_mat.emission_enabled = true
	edge_mat.emission = base_color.lightened(0.3)
	edge_mat.emission_energy_multiplier = 0.5
	edge_mat.metallic = 0.3
	edge_mat.roughness = 0.4
	edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_ring.material = edge_mat
	add_child(edge_ring)

	# ── Area label ──
	var label: Label3D = Label3D.new()
	label.name = "Label_%s" % area_id
	label.text = data.get("name", area_id)
	label.position = Vector3(center_x, 6.0, center_z)
	label.font_size = 72
	label.outline_size = 10
	label.modulate = Color(0.7, 1.0, 0.9, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

	var y_base: float = GROUND_Y + 0.1 + visual_y_bump

	# ── Build all detail layers ──
	# Bio-Lab is a small crafting hub — skip heavy clutter, keep it clean
	var _is_clean_area: bool = area_id == "bio-lab"
	# Asteroid Mines: sparse clutter so ore nodes are the visual focus
	var _is_mines: bool = area_id == "asteroid-mines"

	_add_ground_variation(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_clean_area and not _is_mines:
		_add_terrain_bumps(area_id, center_x, center_z, radius, base_color, y_base)
	_add_concentric_rings(area_id, center_x, center_z, radius, base_color, y_base)
	_add_grid_lines(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_clean_area:
		_add_rocks_and_boulders(area_id, center_x, center_z, radius, base_color, y_base)
		if not _is_mines:
			_add_energy_pylons(area_id, center_x, center_z, radius, base_color, y_base)
			_add_tech_panels(area_id, center_x, center_z, radius, base_color, y_base)
		_add_light_columns(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_mines:
		_add_crystals(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_clean_area:
		_add_alien_flora(area_id, center_x, center_z, radius, base_color, y_base)
		# Floating debris removed — will revisit with proper particle system later
		if not _is_mines:
			_add_pipe_structures(area_id, center_x, center_z, radius, base_color, y_base)
	if not _is_mines:
		_add_ruined_walls(area_id, center_x, center_z, radius, base_color, y_base)
	_add_area_unique_structures(area_id, center_x, center_z, radius, base_color, y_base)
	_add_point_lights(area_id, center_x, center_z, radius, base_color, y_base)

# ═══════════════════════════════════════════════════════════════════════════════
#  DETAIL LAYERS
# ═══════════════════════════════════════════════════════════════════════════════

## Ground variation — inner and outer color bands for visual depth
func _add_ground_variation(_area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	# Inner ring at 70% radius with lighter color
	var inner_ring: CSGCylinder3D = CSGCylinder3D.new()
	inner_ring.radius = radius * 0.7
	inner_ring.height = 0.05
	inner_ring.sides = 32 if radius < 80 else 48
	inner_ring.position = Vector3(cx, y_base + 0.01, cz)
	var inner_mat: StandardMaterial3D = StandardMaterial3D.new()
	inner_mat.albedo_color = base_color.lightened(0.08)
	inner_mat.albedo_color.a = 0.4
	inner_mat.roughness = 0.55
	inner_mat.metallic = 0.3
	inner_mat.emission_enabled = true
	inner_mat.emission = base_color.lightened(0.1)
	inner_mat.emission_energy_multiplier = 0.15
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_ring.material = inner_mat
	add_child(inner_ring)

	# Outer band at 85% radius, darker
	var outer_band: CSGCylinder3D = CSGCylinder3D.new()
	outer_band.radius = radius * 0.85
	outer_band.height = 0.04
	outer_band.sides = 32 if radius < 80 else 48
	outer_band.position = Vector3(cx, y_base + 0.005, cz)
	var outer_mat: StandardMaterial3D = StandardMaterial3D.new()
	outer_mat.albedo_color = base_color.darkened(0.1)
	outer_mat.albedo_color.a = 0.3
	outer_mat.roughness = 0.6
	outer_mat.metallic = 0.2
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_band.material = outer_mat
	add_child(outer_band)

## Terrain bumps and craters — purely visual height variation
func _add_terrain_bumps(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = area_id.hash()

	# Raised bumps (3-8 per area depending on radius)
	var bump_count: int = clampi(int(radius / 15.0) + 2, 3, 8)
	for i in range(bump_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(0.2, 0.75) * radius
		var bx: float = cx + cos(angle) * dist
		var bz: float = cz + sin(angle) * dist
		var bump_radius: float = rng.randf_range(2.0, 5.0)
		var bump_height: float = rng.randf_range(0.2, 0.6)

		var bump: CSGCylinder3D = CSGCylinder3D.new()
		bump.radius = bump_radius
		bump.height = bump_height
		bump.sides = 12
		bump.position = Vector3(bx, y_base + bump_height * 0.5, bz)
		var bump_mat: StandardMaterial3D = StandardMaterial3D.new()
		bump_mat.albedo_color = base_color.lightened(rng.randf_range(-0.05, 0.05))
		bump_mat.roughness = 0.5
		bump_mat.metallic = 0.35
		bump_mat.emission_enabled = true
		bump_mat.emission = base_color
		bump_mat.emission_energy_multiplier = 0.1
		bump.material = bump_mat
		add_child(bump)

	# Crater depressions (2-5 per area)
	var crater_count: int = clampi(int(radius / 25.0) + 1, 2, 5)
	for i in range(crater_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(0.3, 0.65) * radius
		var crx: float = cx + cos(angle) * dist
		var crz: float = cz + sin(angle) * dist

		var crater: CSGCylinder3D = CSGCylinder3D.new()
		crater.radius = rng.randf_range(1.5, 4.0)
		crater.height = 0.06
		crater.sides = 12
		crater.position = Vector3(crx, y_base - 0.02, crz)
		var cr_mat: StandardMaterial3D = StandardMaterial3D.new()
		cr_mat.albedo_color = base_color.darkened(0.15)
		cr_mat.roughness = 0.65
		cr_mat.metallic = 0.2
		cr_mat.emission_enabled = true
		cr_mat.emission = base_color.darkened(0.1)
		cr_mat.emission_energy_multiplier = 0.08
		crater.material = cr_mat
		add_child(crater)

## Concentric accent rings — glowing circuit-like rings on the ground
func _add_concentric_rings(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var ring_count: int = 4 if radius < 60 else (6 if radius < 300 else 10)
	for i in range(ring_count):
		var ring_frac: float = 0.15 + float(i) * (0.75 / float(ring_count))
		var ring_r: float = radius * ring_frac
		var ring: CSGTorus3D = CSGTorus3D.new()
		ring.inner_radius = ring_r - 0.15
		ring.outer_radius = ring_r + 0.15
		ring.ring_sides = 6
		ring.sides = 48
		ring.position = Vector3(cx, y_base + 0.02, cz)
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.albedo_color = base_color.lightened(0.4)
		ring_mat.emission_enabled = true
		ring_mat.emission = base_color.lightened(0.55)
		ring_mat.emission_energy_multiplier = 1.2
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.5
		ring.material = ring_mat
		add_child(ring)

## Grid / radial line patterns on the ground (tech floor look)
func _add_grid_lines(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.albedo_color = base_color.lightened(0.45)
	line_mat.emission_enabled = true
	line_mat.emission = base_color.lightened(0.55)
	line_mat.emission_energy_multiplier = 0.8
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color.a = 0.35

	# Radial lines from center
	var line_count: int = 8 if radius < 60 else (12 if radius < 300 else 16)
	for i in range(line_count):
		var angle: float = float(i) * TAU / float(line_count)
		var length: float = radius * 0.85
		var line: CSGBox3D = CSGBox3D.new()
		line.size = Vector3(0.08, 0.05, length)
		line.position = Vector3(
			cx + cos(angle) * length * 0.5,
			y_base + 0.03,
			cz + sin(angle) * length * 0.5
		)
		line.rotation.y = -angle + PI / 2.0
		line.material = line_mat
		add_child(line)

## Scatter rocks and boulders of various sizes
func _add_rocks_and_boulders(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = area_id.hash()

	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = base_color.darkened(0.3)
	rock_mat.roughness = 0.85
	rock_mat.metallic = 0.1

	# Scale count by area size — mines gets fewer so ore nodes stand out
	var rock_count: int = int(12 + radius * 0.08)
	if area_id == "asteroid-mines":
		rock_count = 6
	rock_count = mini(rock_count, 80)  # Cap for performance

	for i in range(rock_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(3.0, radius * 0.88)
		var rock_r: float = rng.randf_range(0.3, 2.5)
		var rock: CSGSphere3D = CSGSphere3D.new()
		rock.radius = rock_r
		rock.radial_segments = 6
		rock.rings = 4
		rock.position = Vector3(
			cx + cos(angle) * dist,
			y_base + rock_r * 0.2,
			cz + sin(angle) * dist
		)
		rock.scale = Vector3(
			1.0 + rng.randf() * 0.6,
			0.25 + rng.randf() * 0.5,
			1.0 + rng.randf() * 0.6
		)
		rock.rotation.y = rng.randf() * TAU
		rock.material = rock_mat
		add_child(rock)

## Energy pylons — tall glowing pillars scattered through the area
func _add_energy_pylons(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_pylons").hash()

	var pylon_count: int = int(4 + radius * 0.03)
	pylon_count = mini(pylon_count, 30)

	for i in range(pylon_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, radius * 0.8)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var height: float = rng.randf_range(4.0, 12.0)

		# Base pedestal
		var pedestal: CSGCylinder3D = CSGCylinder3D.new()
		pedestal.radius = 0.8
		pedestal.height = 0.6
		pedestal.sides = 6
		pedestal.position = Vector3(px, y_base + 0.3, pz)
		var ped_mat: StandardMaterial3D = StandardMaterial3D.new()
		ped_mat.albedo_color = base_color.darkened(0.2)
		ped_mat.metallic = 0.6
		ped_mat.roughness = 0.3
		pedestal.material = ped_mat
		add_child(pedestal)

		# Main column
		var column: CSGCylinder3D = CSGCylinder3D.new()
		column.radius = 0.25
		column.height = height
		column.sides = 8
		column.position = Vector3(px, y_base + height * 0.5 + 0.6, pz)
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
		orb.position = Vector3(px, y_base + height + 1.0, pz)
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
		h_ring.position = Vector3(px, y_base + height + 1.0, pz)
		h_ring.material = orb_mat
		add_child(h_ring)

		# Register orb for animation (gentle hover + pulse)
		_animated_nodes.append({
			"node": orb, "type": "hover",
			"base_y": y_base + height + 1.0,
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

	var panel_count: int = int(6 + radius * 0.04)
	panel_count = mini(panel_count, 35)

	for i in range(panel_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, radius * 0.85)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist

		var panel: CSGBox3D = CSGBox3D.new()
		var pw: float = rng.randf_range(1.5, 4.0)
		var pd: float = rng.randf_range(1.0, 3.0)
		panel.size = Vector3(pw, 0.08, pd)
		panel.position = Vector3(px, y_base + 0.06, pz)
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
		frame.position = Vector3(px, y_base + 0.04, pz)
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

	for i in range(col_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(radius * 0.3, radius * 0.7)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var beam_h: float = rng.randf_range(15.0, 35.0)

		# Light beam (semi-transparent tall cylinder)
		var beam: CSGCylinder3D = CSGCylinder3D.new()
		beam.radius = 0.3
		beam.height = beam_h
		beam.sides = 8
		beam.position = Vector3(px, y_base + beam_h * 0.5, pz)
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
		base_disc.position = Vector3(px, y_base + 0.08, pz)
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
		"alien-wastes", "the-abyss", "asteroid-mines",
		"corrupted-wastes", "corrupted-abyss"
	]
	if area_id not in crystal_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_crystals").hash()

	var crystal_count: int = int(10 + radius * 0.06)
	crystal_count = mini(crystal_count, 60)

	for i in range(crystal_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, radius * 0.8)
		var c_height: float = rng.randf_range(1.5, 8.0)
		var c_radius: float = rng.randf_range(0.15, 0.8)

		var crystal: CSGCylinder3D = CSGCylinder3D.new()
		crystal.radius = c_radius
		crystal.height = c_height
		crystal.sides = 5
		crystal.cone = true
		crystal.position = Vector3(
			cx + cos(angle) * dist,
			y_base + c_height * 0.4,
			cz + sin(angle) * dist
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

## Alien flora — bioluminescent plants for safe/gathering areas and alien wastes
func _add_alien_flora(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var flora_areas: Array[String] = [
		"gathering-grounds", "alien-wastes", "station-hub", "bio-lab"
	]
	if area_id not in flora_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_flora").hash()

	var flora_count: int = int(12 + radius * 0.06)
	flora_count = mini(flora_count, 50)

	for i in range(flora_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, radius * 0.8)
		var stem_h: float = rng.randf_range(1.0, 6.0)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist

		# Stem
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = 0.08 + rng.randf() * 0.06
		stem.height = stem_h
		stem.sides = 6
		stem.position = Vector3(px, y_base + stem_h * 0.5, pz)
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
		bulb.position = Vector3(px, y_base + stem_h + bulb_r * 0.3, pz)
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
				var t_y: float = y_base + stem_h * rng.randf_range(0.3, 0.7)
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
		var s: float = rng.randf_range(0.2, 1.0)
		debris.size = Vector3(s, s * 0.6, s * 0.8)
		debris.position = Vector3(px, y_base + hover_h, pz)
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
			"base_y": y_base + hover_h,
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

	var pipe_count: int = int(3 + radius * 0.02)
	pipe_count = mini(pipe_count, 15)

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
		var pipe_len: float = rng.randf_range(4.0, 15.0)
		var pipe_h: float = rng.randf_range(0.3, 2.0)

		# Pipe cylinder
		var pipe: CSGCylinder3D = CSGCylinder3D.new()
		pipe.radius = rng.randf_range(0.12, 0.3)
		pipe.height = pipe_len
		pipe.sides = 8
		pipe.position = Vector3(px, y_base + pipe_h, pz)
		pipe.rotation = Vector3(0, rng.randf() * TAU, PI / 2.0)
		pipe.material = pipe_mat
		add_child(pipe)

		# Pipe junction rings
		for j in range(rng.randi_range(1, 3)):
			var junc: CSGTorus3D = CSGTorus3D.new()
			junc.inner_radius = pipe.radius
			junc.outer_radius = pipe.radius + 0.08
			junc.ring_sides = 6
			junc.sides = 8
			var frac: float = rng.randf_range(-0.4, 0.4)
			junc.position = Vector3(
				px + cos(pipe.rotation.y) * pipe_len * frac,
				y_base + pipe_h,
				pz + sin(pipe.rotation.y) * pipe_len * frac
			)
			junc.rotation.z = PI / 2.0
			junc.rotation.y = pipe.rotation.y
			junc.material = pipe_mat
			add_child(junc)

## Ruined wall sections — broken structures suggesting ancient civilization
func _add_ruined_walls(area_id: String, cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	var ruin_areas: Array[String] = [
		"alien-wastes", "the-abyss", "corrupted-wastes", "corrupted-abyss",
		"asteroid-mines"
	]
	if area_id not in ruin_areas:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (area_id + "_ruins").hash()

	var wall_count: int = int(3 + radius * 0.015)
	wall_count = mini(wall_count, 15)

	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = base_color.darkened(0.25)
	wall_mat.metallic = 0.3
	wall_mat.roughness = 0.7

	for i in range(wall_count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, radius * 0.75)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var wall_h: float = rng.randf_range(2.0, 7.0)
		var wall_w: float = rng.randf_range(3.0, 10.0)

		# Wall section
		var wall: CSGBox3D = CSGBox3D.new()
		wall.size = Vector3(wall_w, wall_h, 0.4)
		wall.position = Vector3(px, y_base + wall_h * 0.5, pz)
		wall.rotation.y = rng.randf() * TAU
		wall.material = wall_mat
		add_child(wall)

		# Broken top — irregular jagged silhouette (smaller boxes on top)
		for j in range(rng.randi_range(2, 5)):
			var chunk: CSGBox3D = CSGBox3D.new()
			var cw: float = rng.randf_range(0.5, wall_w * 0.4)
			var ch: float = rng.randf_range(0.5, 2.0)
			chunk.size = Vector3(cw, ch, 0.4)
			chunk.position = Vector3(
				px + (rng.randf() - 0.5) * wall_w * 0.5,
				y_base + wall_h + ch * 0.3,
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
		"alien-wastes":
			_build_wastes_structures(cx, cz, radius, base_color, y_base)
		"the-abyss":
			_build_abyss_structures(cx, cz, radius, base_color, y_base)
		"asteroid-mines":
			_build_mines_structures(cx, cz, radius, base_color, y_base)
		"bio-lab":
			_build_biolab_structures(cx, cz, radius, base_color, y_base)

## Station Hub — central marketplace, control tower, landing pads, supply depot
func _build_hub_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
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
	for i in range(6):
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
		Vector3(cx + 19, y_base + 0.5, cz - 5),
		Vector3(cx + 24, y_base + 0.5, cz - 7),
		Vector3(cx + 20, y_base + 1.5, cz - 7),
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

	# Container marking strip
	var cont_strip: CSGBox3D = CSGBox3D.new()
	cont_strip.size = Vector3(3.8, 0.15, 0.05)
	cont_strip.position = Vector3(cx + 22, y_base + 2.2, cz - 11.0)
	cont_strip.material = warm_glow
	add_child(cont_strip)

	# ── Perimeter barriers (low walls around hub edge) ──
	for i in range(8):
		var angle: float = float(i) / 8.0 * TAU
		var next_a: float = float(i + 1) / 8.0 * TAU
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("gathering_unique")

	# Giant mushrooms
	var cap_mat: StandardMaterial3D = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.15, 0.5, 0.3)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.1, 0.4, 0.25)
	cap_mat.emission_energy_multiplier = 1.5

	for i in range(6):
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

## Alien Wastes — hive arches, bone pillars, organic mounds
func _build_wastes_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
	# The Alien Wastes is a massive area with 7 distinct sub-zones stretching
	# along the Z axis. Each zone gets its own visual identity, color palette,
	# and thematic props to make exploration feel purposeful and varied.
	#
	# Sub-zone layout (all at cx≈0, stretching south from z=-180 to z=-880):
	#   Spore Fields    (40, -180)  r=60   Lv 1-10   — bioluminescent spore pods, soft green/teal glow
	#   Hive Perimeter  (-45, -290) r=70   Lv 8-20   — chitin walls, hive tunnels, organic arches
	#   Fungal Depths   (50, -420)  r=75   Lv 18-35  — giant mushrooms, mycelium networks, purple haze
	#   Toxic Heart     (-40, -550) r=70   Lv 30-50  — acid pools, toxic geysers, corroded bone
	#   Stalker Dens    (45, -670)  r=70   Lv 40-50  — web canopies, cocoons, trap tendrils
	#   Aberration Wastes (-50,-790) r=70  Lv 40-50  — mutated terrain, fleshy growths, pulsing veins
	#   Eldritch Edge   (40, -880)  r=75   Lv 45-50  — void cracks, reality distortions, the queen's throne

	_build_wastes_spore_fields(y_base)
	_build_wastes_hive_perimeter(y_base)
	_build_wastes_fungal_depths(y_base)
	_build_wastes_toxic_heart(y_base)
	_build_wastes_stalker_dens(y_base)
	_build_wastes_aberration_wastes(y_base)
	_build_wastes_eldritch_edge(y_base)
	_build_wastes_zone_borders(y_base)

## Helper: create a material with emission
func _make_wastes_mat(color: Color, emission_color: Color, emission_str: float = 1.0,
		metal: float = 0.2, rough: float = 0.6) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_str
	return mat

## Helper: create a transparent material
func _make_wastes_alpha_mat(color: Color, alpha: float, emission_color: Color,
		emission_str: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = _make_wastes_mat(color, emission_color, emission_str)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = alpha
	return mat

## Helper: scatter items in a circle
func _scatter_positions(rng: RandomNumberGenerator, zcx: float, zcz: float,
		zr: float, count: int, min_dist: float = 3.0) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for i in range(count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(min_dist, zr * 0.85)
		positions.append(Vector3(zcx + cos(angle) * dist, 0.0, zcz + sin(angle) * dist))
	return positions

## Helper: place a sub-zone ground tint disc
func _add_zone_ground_tint(zcx: float, zcz: float, zr: float, color: Color,
		alpha: float, y_base: float) -> void:
	var disc: CSGCylinder3D = CSGCylinder3D.new()
	disc.radius = zr
	disc.height = 0.06
	disc.sides = 48
	disc.position = Vector3(zcx, y_base + 0.08, zcz)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mat.render_priority = 4
	disc.material = mat
	add_child(disc)

## Helper: place a sub-zone label
func _add_zone_label(text: String, zcx: float, zcz: float, y_base: float,
		color: Color = Color(0.7, 0.9, 0.8, 0.8)) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = Vector3(zcx, y_base + 4.0, zcz)
	label.font_size = 48
	label.outline_size = 6
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

# ── SPORE FIELDS — Bioluminescent entry zone, soft green/teal glow ──
func _build_wastes_spore_fields(y_base: float) -> void:
	var zcx: float = 40.0; var zcz: float = -180.0; var zr: float = 60.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_spore_fields")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.05, 0.2, 0.15), 0.35, y_base)
	_add_zone_label("Spore Fields", zcx, zcz, y_base, Color(0.3, 0.9, 0.6, 0.85))

	var spore_glow: StandardMaterial3D = _make_wastes_mat(
		Color(0.1, 0.6, 0.4), Color(0.15, 0.9, 0.5), 3.0, 0.1, 0.4)
	var pod_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.08, 0.3, 0.18), Color(0.06, 0.2, 0.12), 0.5, 0.15, 0.65)
	var tendril_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.04, 0.15, 0.1), Color(0.03, 0.1, 0.06), 0.3, 0.1, 0.7)

	# Large spore pods — bulbous organic sacs that glow softly
	var positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 18)
	for pos in positions:
		var pod_r: float = rng.randf_range(0.8, 2.5)
		var pod: CSGSphere3D = CSGSphere3D.new()
		pod.radius = pod_r
		pod.radial_segments = 10
		pod.rings = 6
		pod.position = Vector3(pos.x, y_base + pod_r * 0.5, pos.z)
		pod.scale = Vector3(1.0, rng.randf_range(0.6, 1.2), 1.0)
		pod.material = pod_mat
		add_child(pod)

		# Glowing tip on top
		var tip: CSGSphere3D = CSGSphere3D.new()
		tip.radius = pod_r * 0.3
		tip.radial_segments = 8
		tip.rings = 4
		tip.position = Vector3(pos.x, y_base + pod_r * 0.9, pos.z)
		tip.material = spore_glow
		add_child(tip)

		# Register tip for pulsing
		_animated_nodes.append({
			"node": tip, "type": "pulse_scale",
			"speed": rng.randf_range(0.8, 1.5),
			"phase": rng.randf() * TAU,
			"min_scale": 0.85, "max_scale": 1.15
		})

	# Tendril clusters — thin organic stalks reaching upward
	var tendril_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 25)
	for pos in tendril_positions:
		var t_height: float = rng.randf_range(2.0, 5.0)
		var tendril: CSGCylinder3D = CSGCylinder3D.new()
		tendril.radius = 0.05 + rng.randf() * 0.05
		tendril.height = t_height
		tendril.sides = 5
		tendril.cone = true
		tendril.position = Vector3(pos.x, y_base + t_height * 0.5, pos.z)
		tendril.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		tendril.material = tendril_mat
		add_child(tendril)

	# Floating spore particles removed — will revisit with proper particle system later

	# Omni lights for ambient glow
	for i in range(4):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.6)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 3.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.15, 0.8, 0.5)
		light.light_energy = 0.6
		light.omni_range = 15.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── HIVE PERIMETER — Chitin walls, organic tunnels, hive arches ──
func _build_wastes_hive_perimeter(y_base: float) -> void:
	var zcx: float = -45.0; var zcz: float = -290.0; var zr: float = 70.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_hive_perimeter")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.15, 0.08, 0.03), 0.35, y_base)
	_add_zone_label("Hive Perimeter", zcx, zcz, y_base, Color(0.8, 0.6, 0.2, 0.85))

	var chitin_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.25, 0.15, 0.08), Color(0.2, 0.1, 0.0), 0.3, 0.3, 0.75)
	var hive_glow: StandardMaterial3D = _make_wastes_mat(
		Color(0.6, 0.35, 0.1), Color(0.8, 0.4, 0.1), 2.0, 0.2, 0.5)
	var membrane_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.5, 0.3, 0.1), 0.4, Color(0.6, 0.3, 0.05), 1.5)

	# Chitin wall segments — curved organic barriers
	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(15.0, zr * 0.75)
		var px: float = zcx + cos(angle) * dist
		var pz: float = zcz + sin(angle) * dist
		var wall_h: float = rng.randf_range(3.0, 8.0)
		var wall_w: float = rng.randf_range(4.0, 12.0)

		var wall: CSGBox3D = CSGBox3D.new()
		wall.size = Vector3(wall_w, wall_h, rng.randf_range(0.6, 1.2))
		wall.position = Vector3(px, y_base + wall_h * 0.5, pz)
		wall.rotation.y = angle + PI * 0.5
		wall.material = chitin_mat
		add_child(wall)

	# Hive arch structures — paired pillars with organic arches
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var dist: float = rng.randf_range(20.0, zr * 0.6)
		var px: float = zcx + cos(angle) * dist
		var pz: float = zcz + sin(angle) * dist
		var arch_h: float = rng.randf_range(6.0, 14.0)
		var arch_w: float = rng.randf_range(4.0, 8.0)

		# Pillars
		for side in [-1.0, 1.0]:
			var pillar: CSGCylinder3D = CSGCylinder3D.new()
			pillar.radius = rng.randf_range(0.4, 0.8)
			pillar.height = arch_h
			pillar.sides = 6
			pillar.position = Vector3(px + side * arch_w * 0.5, y_base + arch_h * 0.5, pz)
			pillar.rotation = Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
			pillar.material = chitin_mat
			add_child(pillar)

		# Arch crossbar
		var arch: CSGCylinder3D = CSGCylinder3D.new()
		arch.radius = 0.5
		arch.height = arch_w + 1.0
		arch.sides = 6
		arch.position = Vector3(px, y_base + arch_h, pz)
		arch.rotation.z = PI / 2.0
		arch.material = chitin_mat
		add_child(arch)

	# Hive mounds — large organic domes
	var mound_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 10, 8.0)
	for pos in mound_positions:
		var mound_r: float = rng.randf_range(3.0, 7.0)
		var mound: CSGSphere3D = CSGSphere3D.new()
		mound.radius = mound_r
		mound.radial_segments = 10
		mound.rings = 6
		mound.position = Vector3(pos.x, y_base + mound_r * 0.25, pos.z)
		mound.scale = Vector3(1.2, 0.35, 1.0)
		mound.material = chitin_mat
		add_child(mound)

		# Glowing openings on some mounds
		if rng.randf() > 0.4:
			var opening: CSGSphere3D = CSGSphere3D.new()
			opening.radius = mound_r * 0.3
			opening.radial_segments = 8
			opening.rings = 4
			opening.position = Vector3(pos.x + rng.randf_range(-1.0, 1.0),
				y_base + mound_r * 0.2, pos.z + rng.randf_range(-1.0, 1.0))
			opening.material = hive_glow
			add_child(opening)

	# Ambient lights — warm amber
	for i in range(3):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.5)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 4.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.8, 0.5, 0.15)
		light.light_energy = 0.5
		light.omni_range = 18.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── FUNGAL DEPTHS — Giant mushrooms, mycelium networks, purple haze ──
func _build_wastes_fungal_depths(y_base: float) -> void:
	var zcx: float = 50.0; var zcz: float = -420.0; var zr: float = 75.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_fungal_depths")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.12, 0.05, 0.18), 0.35, y_base)
	_add_zone_label("Fungal Depths", zcx, zcz, y_base, Color(0.7, 0.3, 0.9, 0.85))

	var cap_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.35, 0.12, 0.5), Color(0.5, 0.15, 0.7), 2.0, 0.15, 0.5)
	var stem_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.2, 0.15, 0.25), Color(0.12, 0.08, 0.15), 0.3, 0.1, 0.7)
	var mycelium_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.4, 0.2, 0.6), 0.3, Color(0.5, 0.2, 0.8), 1.5)
	var spore_cloud_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.5, 0.15, 0.7), 0.12, Color(0.6, 0.2, 0.8), 2.0)

	# Giant mushrooms — towering fungi with wide caps
	var mushroom_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 14, 5.0)
	for pos in mushroom_positions:
		var stem_h: float = rng.randf_range(4.0, 14.0)
		var cap_r: float = rng.randf_range(2.0, 6.0)
		var stem_r: float = rng.randf_range(0.3, 0.8)

		# Stem
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = stem_r
		stem.height = stem_h
		stem.sides = 8
		stem.position = Vector3(pos.x, y_base + stem_h * 0.5, pos.z)
		stem.rotation = Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		stem.material = stem_mat
		add_child(stem)

		# Cap (flattened sphere on top)
		var cap: CSGSphere3D = CSGSphere3D.new()
		cap.radius = cap_r
		cap.radial_segments = 12
		cap.rings = 6
		cap.position = Vector3(pos.x, y_base + stem_h + cap_r * 0.15, pos.z)
		cap.scale = Vector3(1.0, 0.3, 1.0)
		cap.material = cap_mat
		add_child(cap)

		# Glow spots under cap
		if rng.randf() > 0.3:
			var glow_ring: CSGTorus3D = CSGTorus3D.new()
			glow_ring.inner_radius = cap_r * 0.4
			glow_ring.outer_radius = cap_r * 0.6
			glow_ring.ring_sides = 6
			glow_ring.sides = 12
			glow_ring.position = Vector3(pos.x, y_base + stem_h - 0.3, pos.z)
			glow_ring.material = _make_wastes_mat(
				Color(0.6, 0.2, 0.9), Color(0.7, 0.3, 1.0), 3.5, 0.1, 0.3)
			add_child(glow_ring)

	# Mycelium ground networks — flat glowing veins on the ground
	for i in range(10):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, zr * 0.75)
		var length: float = rng.randf_range(5.0, 20.0)
		var vein: CSGBox3D = CSGBox3D.new()
		vein.size = Vector3(rng.randf_range(0.15, 0.4), 0.04, length)
		vein.position = Vector3(zcx + cos(angle) * dist, y_base + 0.08, zcz + sin(angle) * dist)
		vein.rotation.y = angle + rng.randf_range(-0.5, 0.5)
		vein.material = mycelium_mat
		add_child(vein)

	# Spore clouds — large translucent spheres of haze
	for i in range(6):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.6)
		var cloud: CSGSphere3D = CSGSphere3D.new()
		cloud.radius = rng.randf_range(3.0, 8.0)
		cloud.radial_segments = 10
		cloud.rings = 6
		cloud.position = Vector3(zcx + cos(angle) * dist, y_base + rng.randf_range(2.0, 6.0), zcz + sin(angle) * dist)
		cloud.material = spore_cloud_mat
		add_child(cloud)

	# Purple ambient lights
	for i in range(5):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, zr * 0.6)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 5.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.5, 0.15, 0.8)
		light.light_energy = 0.7
		light.omni_range = 20.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── TOXIC HEART — Acid pools, toxic geysers, corroded bone structures ──
func _build_wastes_toxic_heart(y_base: float) -> void:
	var zcx: float = -40.0; var zcz: float = -550.0; var zr: float = 70.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_toxic_heart")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.15, 0.2, 0.02), 0.4, y_base)
	_add_zone_label("Toxic Heart", zcx, zcz, y_base, Color(0.6, 0.9, 0.1, 0.85))

	var acid_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.3, 0.7, 0.05), 0.6, Color(0.4, 0.9, 0.1), 3.0)
	var bone_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.5, 0.45, 0.3), Color(0.3, 0.25, 0.15), 0.2, 0.1, 0.8)
	var corroded_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.35, 0.4, 0.15), Color(0.25, 0.35, 0.1), 0.5, 0.3, 0.6)
	var geyser_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.4, 0.8, 0.1), 0.3, Color(0.5, 1.0, 0.15), 4.0)

	# Acid pools — flat glowing discs on the ground
	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, zr * 0.7)
		var pool_r: float = rng.randf_range(2.0, 6.0)
		var pool: CSGCylinder3D = CSGCylinder3D.new()
		pool.radius = pool_r
		pool.height = 0.08
		pool.sides = 16
		pool.position = Vector3(zcx + cos(angle) * dist, y_base + 0.06, zcz + sin(angle) * dist)
		pool.material = acid_mat
		add_child(pool)

	# Toxic geysers — tall translucent columns that pulse
	for i in range(5):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.6)
		var geyser_h: float = rng.randf_range(6.0, 15.0)
		var geyser: CSGCylinder3D = CSGCylinder3D.new()
		geyser.radius = rng.randf_range(0.3, 0.8)
		geyser.height = geyser_h
		geyser.sides = 8
		var gx: float = zcx + cos(angle) * dist
		var gz: float = zcz + sin(angle) * dist
		geyser.position = Vector3(gx, y_base + geyser_h * 0.5, gz)
		geyser.material = geyser_mat
		add_child(geyser)
		_animated_nodes.append({
			"node": geyser, "type": "pulse_scale",
			"speed": rng.randf_range(1.5, 3.0),
			"phase": rng.randf() * TAU,
			"min_scale": 0.7, "max_scale": 1.3
		})

	# Corroded bone pillars — weathered skeletal remains
	var bone_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 12, 6.0)
	for pos in bone_positions:
		var bone_h: float = rng.randf_range(3.0, 10.0)
		var bone: CSGCylinder3D = CSGCylinder3D.new()
		bone.radius = rng.randf_range(0.2, 0.6)
		bone.height = bone_h
		bone.sides = 5
		bone.cone = rng.randf() > 0.5
		bone.position = Vector3(pos.x, y_base + bone_h * 0.5, pos.z)
		bone.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
		bone.material = bone_mat if rng.randf() > 0.4 else corroded_mat
		add_child(bone)

	# Toxic green lights
	for i in range(4):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.5)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 3.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.4, 0.9, 0.1)
		light.light_energy = 0.7
		light.omni_range = 15.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── STALKER DENS — Web canopies, cocoons, trap tendrils ──
func _build_wastes_stalker_dens(y_base: float) -> void:
	var zcx: float = 45.0; var zcz: float = -670.0; var zr: float = 70.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_stalker_dens")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.08, 0.06, 0.1), 0.4, y_base)
	_add_zone_label("Stalker Dens", zcx, zcz, y_base, Color(0.6, 0.5, 0.7, 0.85))

	var web_mat: StandardMaterial3D = _make_wastes_alpha_mat(
		Color(0.7, 0.7, 0.65), 0.2, Color(0.5, 0.5, 0.45), 0.8)
	var cocoon_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.35, 0.3, 0.25), Color(0.2, 0.15, 0.1), 0.3, 0.15, 0.75)
	var tendril_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.2, 0.12, 0.25), Color(0.15, 0.08, 0.2), 0.5, 0.2, 0.65)

	# Web canopy sheets — large flat planes stretched between invisible anchor points
	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.7)
		var web_w: float = rng.randf_range(5.0, 15.0)
		var web_d: float = rng.randf_range(4.0, 10.0)
		var web: CSGBox3D = CSGBox3D.new()
		web.size = Vector3(web_w, 0.03, web_d)
		web.position = Vector3(zcx + cos(angle) * dist,
			y_base + rng.randf_range(4.0, 9.0), zcz + sin(angle) * dist)
		web.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		web.material = web_mat
		add_child(web)

	# Cocoons — elongated egg-like shapes hanging or resting
	var cocoon_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 15, 4.0)
	for pos in cocoon_positions:
		var c_r: float = rng.randf_range(0.4, 1.2)
		var cocoon: CSGSphere3D = CSGSphere3D.new()
		cocoon.radius = c_r
		cocoon.radial_segments = 8
		cocoon.rings = 5
		var hanging: bool = rng.randf() > 0.5
		cocoon.position = Vector3(pos.x,
			y_base + (rng.randf_range(3.0, 7.0) if hanging else c_r * 0.6), pos.z)
		cocoon.scale = Vector3(0.6, 1.4, 0.6)
		cocoon.material = cocoon_mat
		add_child(cocoon)

		# Web strand connecting hanging cocoons to canopy
		if hanging:
			var strand: CSGCylinder3D = CSGCylinder3D.new()
			strand.radius = 0.02
			strand.height = rng.randf_range(1.0, 3.0)
			strand.sides = 4
			strand.position = Vector3(pos.x, cocoon.position.y + c_r * 1.2, pos.z)
			strand.material = web_mat
			add_child(strand)

	# Trap tendrils — menacing stalks that sway
	for i in range(12):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, zr * 0.8)
		var t_h: float = rng.randf_range(2.0, 6.0)
		var tendril: CSGCylinder3D = CSGCylinder3D.new()
		tendril.radius = 0.06 + rng.randf() * 0.06
		tendril.height = t_h
		tendril.sides = 5
		var tx: float = zcx + cos(angle) * dist
		var tz: float = zcz + sin(angle) * dist
		tendril.position = Vector3(tx, y_base + t_h * 0.5, tz)
		tendril.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		tendril.material = tendril_mat
		add_child(tendril)

	# Dim purple lights
	for i in range(3):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.5)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 3.5, zcz + sin(angle) * dist)
		light.light_color = Color(0.4, 0.3, 0.6)
		light.light_energy = 0.4
		light.omni_range = 16.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── ABERRATION WASTES — Mutated terrain, fleshy growths, pulsing veins ──
func _build_wastes_aberration_wastes(y_base: float) -> void:
	var zcx: float = -50.0; var zcz: float = -790.0; var zr: float = 70.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_aberration")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.2, 0.05, 0.08), 0.4, y_base)
	_add_zone_label("Aberration Wastes", zcx, zcz, y_base, Color(0.9, 0.3, 0.4, 0.85))

	var flesh_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.4, 0.12, 0.15), Color(0.5, 0.1, 0.12), 1.0, 0.15, 0.55)
	var vein_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.6, 0.08, 0.12), Color(0.8, 0.1, 0.15), 2.5, 0.2, 0.4)
	var eye_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.9, 0.8, 0.2), Color(1.0, 0.9, 0.3), 3.0, 0.3, 0.2)
	var growth_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.3, 0.08, 0.12), Color(0.25, 0.06, 0.1), 0.5, 0.1, 0.7)

	# Fleshy mounds — disturbing organic humps
	var mound_positions: Array[Vector3] = _scatter_positions(rng, zcx, zcz, zr, 12, 6.0)
	for pos in mound_positions:
		var m_r: float = rng.randf_range(1.5, 5.0)
		var mound: CSGSphere3D = CSGSphere3D.new()
		mound.radius = m_r
		mound.radial_segments = 10
		mound.rings = 6
		mound.position = Vector3(pos.x, y_base + m_r * 0.2, pos.z)
		mound.scale = Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.2, 0.5),
			rng.randf_range(0.8, 1.3))
		mound.material = flesh_mat
		add_child(mound)

		# Random eye on some mounds
		if rng.randf() > 0.6:
			var eye: CSGSphere3D = CSGSphere3D.new()
			eye.radius = m_r * 0.2
			eye.radial_segments = 8
			eye.rings = 4
			eye.position = Vector3(pos.x, y_base + m_r * 0.35, pos.z)
			eye.material = eye_mat
			add_child(eye)

	# Pulsing vein networks on the ground
	for i in range(15):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(4.0, zr * 0.8)
		var length: float = rng.randf_range(4.0, 18.0)
		var vein: CSGBox3D = CSGBox3D.new()
		vein.size = Vector3(rng.randf_range(0.1, 0.3), 0.05, length)
		vein.position = Vector3(zcx + cos(angle) * dist, y_base + 0.07, zcz + sin(angle) * dist)
		vein.rotation.y = angle + rng.randf_range(-0.4, 0.4)
		vein.material = vein_mat
		add_child(vein)

	# Twisted growth pillars — organic columns warped by mutation
	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.7)
		var g_h: float = rng.randf_range(3.0, 10.0)
		var growth: CSGCylinder3D = CSGCylinder3D.new()
		growth.radius = rng.randf_range(0.3, 1.0)
		growth.height = g_h
		growth.sides = 6
		growth.position = Vector3(zcx + cos(angle) * dist, y_base + g_h * 0.5, zcz + sin(angle) * dist)
		growth.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		growth.material = growth_mat
		add_child(growth)

	# Sickly red lights
	for i in range(4):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, zr * 0.5)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 3.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.8, 0.15, 0.2)
		light.light_energy = 0.6
		light.omni_range = 16.0
		light.omni_attenuation = 1.5
		add_child(light)

# ── ELDRITCH EDGE — Void cracks, reality distortions, the queen's domain ──
func _build_wastes_eldritch_edge(y_base: float) -> void:
	var zcx: float = 40.0; var zcz: float = -880.0; var zr: float = 75.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("wastes_eldritch_edge")

	_add_zone_ground_tint(zcx, zcz, zr, Color(0.05, 0.02, 0.1), 0.45, y_base)
	_add_zone_label("Eldritch Edge", zcx, zcz, y_base, Color(0.9, 0.4, 0.8, 0.85))

	var void_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.06, 0.02, 0.12), Color(0.12, 0.04, 0.2), 1.5, 0.4, 0.3)
	var rift_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.6, 0.1, 0.8), Color(0.8, 0.15, 1.0), 5.0, 0.3, 0.15)
	var throne_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.15, 0.05, 0.2), Color(0.25, 0.08, 0.35), 1.0, 0.5, 0.35)
	var crystal_mat: StandardMaterial3D = _make_wastes_mat(
		Color(0.5, 0.15, 0.7), Color(0.7, 0.2, 1.0), 4.0, 0.8, 0.1)

	# Queen's Throne — massive elevated platform at the center
	var throne_base: CSGCylinder3D = CSGCylinder3D.new()
	throne_base.radius = 8.0
	throne_base.height = 1.5
	throne_base.sides = 12
	throne_base.position = Vector3(zcx, y_base + 0.75, zcz)
	throne_base.material = throne_mat
	add_child(throne_base)

	# Throne spires — tall spikes around the platform
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		var spire: CSGCylinder3D = CSGCylinder3D.new()
		spire.radius = 0.5
		spire.height = rng.randf_range(10.0, 18.0)
		spire.sides = 5
		spire.cone = true
		var sx: float = zcx + cos(angle) * 7.0
		var sz: float = zcz + sin(angle) * 7.0
		spire.position = Vector3(sx, y_base + spire.height * 0.5 + 1.5, sz)
		spire.material = void_mat
		add_child(spire)

		# Crystal tip on each spire
		var tip: CSGSphere3D = CSGSphere3D.new()
		tip.radius = 0.6
		tip.radial_segments = 8
		tip.rings = 4
		tip.position = Vector3(sx, y_base + spire.height + 2.0, sz)
		tip.material = crystal_mat
		add_child(tip)
		_animated_nodes.append({
			"node": tip, "type": "pulse_scale",
			"speed": rng.randf_range(1.0, 2.0),
			"phase": rng.randf() * TAU,
			"min_scale": 0.8, "max_scale": 1.2
		})

	# Reality tear rifts — vertical planes of crackling energy
	for i in range(8):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(12.0, zr * 0.7)
		var rift_h: float = rng.randf_range(4.0, 12.0)
		var rift: CSGBox3D = CSGBox3D.new()
		rift.size = Vector3(rng.randf_range(0.3, 1.5), rift_h, 0.04)
		rift.position = Vector3(zcx + cos(angle) * dist, y_base + rift_h * 0.5, zcz + sin(angle) * dist)
		rift.rotation.y = rng.randf() * TAU
		rift.material = rift_mat
		add_child(rift)
		_animated_nodes.append({
			"node": rift, "type": "pulse_scale",
			"speed": rng.randf_range(1.0, 3.0),
			"phase": rng.randf() * TAU,
			"min_scale": 0.85, "max_scale": 1.15
		})

	# Void cracks in the ground — dark lines with faint glow
	for i in range(12):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, zr * 0.8)
		var crack_len: float = rng.randf_range(3.0, 15.0)
		var crack: CSGBox3D = CSGBox3D.new()
		crack.size = Vector3(rng.randf_range(0.05, 0.2), 0.06, crack_len)
		crack.position = Vector3(zcx + cos(angle) * dist, y_base + 0.09, zcz + sin(angle) * dist)
		crack.rotation.y = angle + rng.randf_range(-0.5, 0.5)
		crack.material = rift_mat
		add_child(crack)

	# Intense purple/void lights
	for i in range(5):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, zr * 0.6)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(zcx + cos(angle) * dist, y_base + 4.0, zcz + sin(angle) * dist)
		light.light_color = Color(0.6, 0.1, 0.8)
		light.light_energy = 0.8
		light.omni_range = 18.0
		light.omni_attenuation = 1.5
		add_child(light)

	# Central throne light — bright beacon
	var throne_light: OmniLight3D = OmniLight3D.new()
	throne_light.position = Vector3(zcx, y_base + 6.0, zcz)
	throne_light.light_color = Color(0.7, 0.2, 0.9)
	throne_light.light_energy = 1.2
	throne_light.omni_range = 25.0
	throne_light.omni_attenuation = 1.2
	add_child(throne_light)

# ── Zone border rings — glowing boundary markers between sub-zones ──
func _build_wastes_zone_borders(y_base: float) -> void:
	var zones: Array[Dictionary] = [
		{ "cx": 40.0, "cz": -180.0, "r": 60.0, "color": Color(0.15, 0.8, 0.5) },
		{ "cx": -45.0, "cz": -290.0, "r": 70.0, "color": Color(0.8, 0.5, 0.15) },
		{ "cx": 50.0, "cz": -420.0, "r": 75.0, "color": Color(0.5, 0.15, 0.8) },
		{ "cx": -40.0, "cz": -550.0, "r": 70.0, "color": Color(0.4, 0.9, 0.1) },
		{ "cx": 45.0, "cz": -670.0, "r": 70.0, "color": Color(0.4, 0.35, 0.6) },
		{ "cx": -50.0, "cz": -790.0, "r": 70.0, "color": Color(0.8, 0.15, 0.2) },
		{ "cx": 40.0, "cz": -880.0, "r": 75.0, "color": Color(0.6, 0.1, 0.8) },
	]
	for z in zones:
		var ring: CSGTorus3D = CSGTorus3D.new()
		ring.inner_radius = float(z["r"]) - 0.3
		ring.outer_radius = float(z["r"]) + 0.3
		ring.ring_sides = 6
		ring.sides = 32
		ring.position = Vector3(float(z["cx"]), y_base + 0.12, float(z["cz"]))
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		var col: Color = z["color"] as Color
		ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.3)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = col
		ring_mat.emission_energy_multiplier = 1.5
		ring.material = ring_mat
		add_child(ring)

## The Abyss — void pillars, floating platforms, reality tears, eye clusters
func _build_abyss_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
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
	for i in range(15):
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

	# Reality tear rifts (thin vertical planes of energy)
	for i in range(6):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(30.0, radius * 0.6)
		var px: float = cx + cos(angle) * dist
		var pz: float = cz + sin(angle) * dist
		var rift_h: float = rng.randf_range(4.0, 12.0)

		var rift: CSGBox3D = CSGBox3D.new()
		rift.size = Vector3(rng.randf_range(0.5, 2.0), rift_h, 0.05)
		rift.position = Vector3(px, y_base + rift_h * 0.5, pz)
		rift.rotation.y = rng.randf() * TAU
		rift.material = rift_mat
		add_child(rift)

		_animated_nodes.append({
			"node": rift, "type": "pulse_scale",
			"speed": rng.randf_range(1.0, 3.0),
			"phase": rng.randf() * TAU,
			"min_scale": 0.8, "max_scale": 1.2
		})

## Asteroid Mines — mining rigs, conveyor frames, ore carts, drill towers
func _build_mines_structures(cx: float, cz: float, radius: float,
		base_color: Color, y_base: float) -> void:
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

		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(
			cx + cos(angle) * dist,
			y_base + rng.randf_range(3.0, 8.0),
			cz + sin(angle) * dist
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

func _build_corridors() -> void:
	for corridor_data in DataManager.corridors:
		_create_corridor(corridor_data)
	print("AreaManager: Built %d corridors" % DataManager.corridors.size())

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

	# ── Ground box ──
	var box: CSGBox3D = CSGBox3D.new()
	box.name = "Corridor_%s" % data.get("id", "unknown")
	box.size = Vector3(corridor_w, 0.2, corridor_d)
	box.position = Vector3(center_x, GROUND_Y - 0.02, center_z)

	var corridor_color: Color = _hex_to_color(ground_color_int)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = corridor_color.lightened(0.15)
	mat.roughness = 0.5
	mat.metallic = 0.35
	mat.emission_enabled = true
	mat.emission = corridor_color.lightened(0.25)
	mat.emission_energy_multiplier = 0.15
	mat.render_priority = -1
	box.material = mat

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(corridor_w, 0.4, corridor_d)
	col_shape.shape = shape
	static_body.add_child(col_shape)
	box.add_child(static_body)
	add_child(box)

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

	# ── Edge guide lines ──
	var edge_mat: StandardMaterial3D = StandardMaterial3D.new()
	edge_mat.albedo_color = corridor_color.lightened(0.5)
	edge_mat.emission_enabled = true
	edge_mat.emission = corridor_color.lightened(0.6)
	edge_mat.emission_energy_multiplier = 1.0
	edge_mat.metallic = 0.5

	var is_vertical: bool = corridor_d > corridor_w
	if is_vertical:
		# Left edge
		var left_edge: CSGBox3D = CSGBox3D.new()
		left_edge.size = Vector3(0.3, 0.15, corridor_d)
		left_edge.position = Vector3(center_x - corridor_w * 0.5, GROUND_Y + 0.15, center_z)
		left_edge.material = edge_mat
		add_child(left_edge)
		# Right edge
		var right_edge: CSGBox3D = CSGBox3D.new()
		right_edge.size = Vector3(0.3, 0.15, corridor_d)
		right_edge.position = Vector3(center_x + corridor_w * 0.5, GROUND_Y + 0.15, center_z)
		right_edge.material = edge_mat
		add_child(right_edge)
	else:
		# Front edge
		var front_edge: CSGBox3D = CSGBox3D.new()
		front_edge.size = Vector3(corridor_w, 0.15, 0.3)
		front_edge.position = Vector3(center_x, GROUND_Y + 0.15, center_z - corridor_d * 0.5)
		front_edge.material = edge_mat
		add_child(front_edge)
		# Back edge
		var back_edge: CSGBox3D = CSGBox3D.new()
		back_edge.size = Vector3(corridor_w, 0.15, 0.3)
		back_edge.position = Vector3(center_x, GROUND_Y + 0.15, center_z + corridor_d * 0.5)
		back_edge.material = edge_mat
		add_child(back_edge)

	# ── Guide light posts along the corridor ──
	var corridor_length: float = maxf(corridor_w, corridor_d)
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
				post_pos = Vector3(
					center_x + side * (corridor_w * 0.5 - 0.5),
					GROUND_Y,
					center_z + (frac - 0.5) * corridor_d
				)
			else:
				post_pos = Vector3(
					center_x + (frac - 0.5) * corridor_w,
					GROUND_Y,
					center_z + side * (corridor_d * 0.5 - 0.5)
				)

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
				arch_pos = Vector3(center_x, GROUND_Y, center_z + (frac - 0.5) * corridor_d)
			else:
				arch_pos = Vector3(center_x + (frac - 0.5) * corridor_w, GROUND_Y, center_z)

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

	if new_area != "" and new_area != GameState.current_area:
		var old_area: String = GameState.current_area
		GameState.current_area = new_area
		GameState.previous_area = old_area
		EventBus.area_entered.emit(new_area)
		EventBus.area_exited.emit(old_area)
		_update_atmosphere(new_area)

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
				if pos.distance_to(from_center) < pos.distance_to(to_center):
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
		if pos.distance_to(center) <= r:
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
		if p.distance_to(center) <= r:
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
