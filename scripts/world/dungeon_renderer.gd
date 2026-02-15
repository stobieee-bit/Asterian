## DungeonRenderer -- Renders dungeon floors as 3D geometry
##
## Takes floor data produced by DungeonSystem and builds the physical dungeon:
## rooms (floor, walls, ceiling, lights, decorations), corridors, enemies,
## traps, and environment settings.  Connects to EventBus dungeon signals to
## automatically build/clear floors as the player progresses.
##
## Each room is a box-like enclosure with themed materials, typed lighting,
## Label3D room-type indicators, and special decorations for treasure, shrine,
## and boss rooms.  Corridors are walled strips connecting adjacent rooms.
## Traps are Area3D nodes that apply damage-over-time or debuffs on contact.
extends Node3D


# ──────────────────────────────────────────────
#  Constants
# ──────────────────────────────────────────────

## World-space size of one room (must match dungeon_config.roomSize)
const ROOM_SIZE: float = 15.0

## Width of connecting corridors (must match dungeon_config.corridorWidth)
const CORRIDOR_WIDTH: float = 4.0

## Grid-cell spacing in world units (must match dungeon_config.roomSpacing)
const ROOM_SPACING: float = 22.0

## Room wall height
const WALL_HEIGHT: float = 5.0

## Wall thickness
const WALL_THICKNESS: float = 0.5

## Floor slab thickness
const FLOOR_THICKNESS: float = 0.3

## Room type display names
const ROOM_TYPE_LABELS: Dictionary = {
	"entrance":  "Entrance",
	"normal":    "Room",
	"treasure":  "Treasure",
	"shrine":    "Shrine",
	"boss":      "Boss Room",
	"miniboss":  "Mini-Boss",
}


# ──────────────────────────────────────────────
#  Preloads
# ──────────────────────────────────────────────

## Scene used to instance dungeon enemies
var enemy_scene: PackedScene = preload("res://scenes/entities/enemy.tscn")


# ──────────────────────────────────────────────
#  State
# ──────────────────────────────────────────────

## Parent node for all generated 3D dungeon content
var _floor_node: Node3D = null

## Spawned dungeon enemy instances
var _dungeon_enemies: Array = []

## Spawned trap Area3D instances
var _trap_areas: Array = []

## Label3D nodes per room, keyed by "grid_x,grid_z"
var _room_labels: Dictionary = {}

## Cached player reference (CharacterBody3D in "player" group)
var _player: CharacterBody3D = null

## The floor data dictionary currently being rendered
var _active_floor_data: Dictionary = {}

## Tracks active trap damage timers keyed by trap_key for cleanup
var _trap_timers: Dictionary = {}

## Corridor connectivity lookup: "grid_x,grid_z" -> Array of direction strings
## where direction is "north", "south", "east", or "west"
var _corridor_openings: Dictionary = {}


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("dungeon_renderer")

	# Connect to dungeon lifecycle signals
	EventBus.dungeon_started.connect(_on_dungeon_started)
	EventBus.dungeon_floor_advanced.connect(_on_dungeon_floor_advanced)
	EventBus.dungeon_exited.connect(_on_dungeon_exited)

	# Cache player reference (may not exist yet at startup)
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Build all 3D geometry for a dungeon floor.
## Clears any previous floor, creates rooms, corridors, enemies, traps,
## environment, then teleports the player to the entrance.
func build_floor(floor_data: Dictionary) -> void:
	# Clean up any previous floor first
	clear_floor()

	# Store the active data
	_active_floor_data = floor_data

	# Ensure we have a player reference
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Create the parent node for all dungeon geometry
	_floor_node = Node3D.new()
	_floor_node.name = "DungeonFloor"
	add_child(_floor_node)

	# Read theme from floor data
	var theme: Dictionary = floor_data.get("theme", {})
	var rooms: Array = floor_data.get("rooms", [])
	var corridors: Array = floor_data.get("corridors", [])

	# Pre-compute which walls need gaps for corridors
	_build_corridor_openings(corridors)

	# Build room geometry
	for room in rooms:
		_build_room(room, theme)

	# Build corridor geometry
	for corridor in corridors:
		_build_corridor(corridor, theme, rooms)

	# Spawn enemies and traps for each room
	for room in rooms:
		_spawn_room_enemies(room)
		_spawn_room_traps(room, theme)

	# Set up ambient light and fog
	_setup_environment(theme)

	# Teleport player to entrance
	var entrance_pos: Vector3 = floor_data.get("entrance_pos", Vector3.ZERO)
	if _player != null:
		_player.global_position = entrance_pos + Vector3(0, 1, 0)

	# Debug summary
	var floor_num: int = int(floor_data.get("floor", 0))
	var enemy_count: int = _dungeon_enemies.size()
	var room_count: int = rooms.size()
	print("DungeonRenderer: Floor %d built (%d rooms, %d enemies)" % [
		floor_num, room_count, enemy_count
	])


## Remove all dungeon geometry, enemies, traps, and environment nodes.
func clear_floor() -> void:
	# Despawn all dungeon enemies
	for enemy in _dungeon_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_dungeon_enemies.clear()

	# Remove all trap areas and their timers
	for trap_area in _trap_areas:
		if is_instance_valid(trap_area):
			trap_area.queue_free()
	_trap_areas.clear()

	# Stop and free any active trap timers
	for timer_key in _trap_timers:
		var timer: Timer = _trap_timers[timer_key] as Timer
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_trap_timers.clear()

	# Clear room labels tracking
	_room_labels.clear()

	# Clear corridor openings cache
	_corridor_openings.clear()

	# Remove the floor parent node (takes all children with it)
	if _floor_node != null and is_instance_valid(_floor_node):
		_floor_node.queue_free()
		_floor_node = null

	# Clear stored data
	_active_floor_data = {}


## Find which room (if any) contains the given world position.
## Returns the room Dictionary, or an empty Dictionary if outside all rooms.
func get_room_at_position(pos: Vector3) -> Dictionary:
	var rooms: Array = _active_floor_data.get("rooms", [])
	var half_size: float = ROOM_SIZE / 2.0
	var closest_room: Dictionary = {}
	var closest_dist: float = INF

	for room in rooms:
		var room_pos: Vector3 = room.get("world_position", Vector3.ZERO)
		var dx: float = absf(pos.x - room_pos.x)
		var dz: float = absf(pos.z - room_pos.z)

		# Check if position is within the room's bounding box
		if dx <= half_size and dz <= half_size:
			var dist: float = dx * dx + dz * dz
			if dist < closest_dist:
				closest_dist = dist
				closest_room = room

	return closest_room


## Mark a room as cleared: update data, remove its enemies, brighten its light.
func mark_room_cleared(room: Dictionary) -> void:
	room["cleared"] = true

	# Remove enemies that belong to this room
	var room_key: String = "%d,%d" % [int(room.get("grid_x", 0)), int(room.get("grid_z", 0))]

	var i: int = _dungeon_enemies.size() - 1
	while i >= 0:
		var enemy: Node = _dungeon_enemies[i]
		if is_instance_valid(enemy) and enemy.get_meta("dungeon_room", "") == room_key:
			enemy.queue_free()
			_dungeon_enemies.remove_at(i)
		i -= 1

	# Brighten the room light to indicate cleared state
	_brighten_room_light(room_key)


# ──────────────────────────────────────────────
#  Signal handlers
# ──────────────────────────────────────────────

## Called when a dungeon run begins — build the first floor.
func _on_dungeon_started(floor_data: Dictionary) -> void:
	build_floor(floor_data)


## Called when the player advances to the next floor.
func _on_dungeon_floor_advanced(floor_data: Dictionary) -> void:
	build_floor(floor_data)


## Called when the player exits the dungeon — tear everything down.
func _on_dungeon_exited() -> void:
	clear_floor()


# ──────────────────────────────────────────────
#  Corridor opening pre-computation
# ──────────────────────────────────────────────

## Build a lookup of which walls in each room should have gaps for corridors.
## Populates _corridor_openings: { "gx,gz": ["east", "south", ...] }
func _build_corridor_openings(corridors: Array) -> void:
	_corridor_openings.clear()

	for corridor in corridors:
		var from: Vector2i = corridor.get("from", Vector2i.ZERO)
		var to: Vector2i = corridor.get("to", Vector2i.ZERO)

		var from_key: String = "%d,%d" % [from.x, from.y]
		var to_key: String = "%d,%d" % [to.x, to.y]

		# Determine direction
		var dx: int = to.x - from.x
		var dz: int = to.y - from.y

		if not _corridor_openings.has(from_key):
			_corridor_openings[from_key] = []
		if not _corridor_openings.has(to_key):
			_corridor_openings[to_key] = []

		if dx > 0:
			# from -> east, to -> west
			_corridor_openings[from_key].append("east")
			_corridor_openings[to_key].append("west")
		elif dx < 0:
			_corridor_openings[from_key].append("west")
			_corridor_openings[to_key].append("east")
		elif dz > 0:
			# from -> south (positive Z), to -> north
			_corridor_openings[from_key].append("south")
			_corridor_openings[to_key].append("north")
		elif dz < 0:
			_corridor_openings[from_key].append("north")
			_corridor_openings[to_key].append("south")


# ──────────────────────────────────────────────
#  Room building
# ──────────────────────────────────────────────

## Build the 3D enclosure for a single room: floor, walls, ceiling, light,
## label, and any special decorations based on room type.
func _build_room(room: Dictionary, theme: Dictionary) -> void:
	var room_pos: Vector3 = room.get("world_position", Vector3.ZERO)
	var room_type: String = str(room.get("type", "normal"))
	var grid_x: int = int(room.get("grid_x", 0))
	var grid_z: int = int(room.get("grid_z", 0))
	var room_key: String = "%d,%d" % [grid_x, grid_z]

	# Container for this room's geometry
	var room_node: Node3D = Node3D.new()
	room_node.name = "Room_%s" % room_key
	_floor_node.add_child(room_node)

	# ── Materials ──
	var floor_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("floorColor", 0x1a1a2e)))
	)
	var wall_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("wallColor", 0x2a2a3e)))
	)
	var ceiling_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("ceilingColor", 0x0e0e1e)))
	)

	# ── Floor ──
	var floor_box: CSGBox3D = CSGBox3D.new()
	floor_box.name = "Floor"
	floor_box.size = Vector3(ROOM_SIZE, FLOOR_THICKNESS, ROOM_SIZE)
	floor_box.position = room_pos
	floor_box.material = floor_mat

	# Add static body for ground raycasting
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1  # Ground layer
	var floor_col: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(ROOM_SIZE, FLOOR_THICKNESS + 0.1, ROOM_SIZE)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_box.add_child(floor_body)

	room_node.add_child(floor_box)

	# ── Ceiling ──
	var ceiling_box: CSGBox3D = CSGBox3D.new()
	ceiling_box.name = "Ceiling"
	ceiling_box.size = Vector3(ROOM_SIZE, FLOOR_THICKNESS, ROOM_SIZE)
	ceiling_box.position = room_pos + Vector3(0, WALL_HEIGHT, 0)
	ceiling_box.material = ceiling_mat
	room_node.add_child(ceiling_box)

	# ── Walls ──
	# Determine which walls need corridor gaps
	var openings: Array = _corridor_openings.get(room_key, [])

	_build_room_walls(room_node, room_pos, wall_mat, openings)

	# ── Room light ──
	var light_colors: Dictionary = theme.get("lightColors", {})
	var light_color_int: int = int(light_colors.get(room_type, light_colors.get("normal", 0xFFFFFF)))
	var light_color: Color = _int_to_color(light_color_int)

	var omni: OmniLight3D = OmniLight3D.new()
	omni.name = "RoomLight_%s" % room_key
	omni.position = room_pos + Vector3(0, 4.0, 0)
	omni.light_color = light_color
	omni.omni_range = 16.0 if room_type == "boss" else 12.0
	omni.light_energy = 2.0 if room_type == "boss" else 1.5
	omni.shadow_enabled = false  # Cheaper for procedural dungeons
	room_node.add_child(omni)

	# ── Room type label ──
	var label: Label3D = Label3D.new()
	label.name = "Label_%s" % room_key
	label.text = ROOM_TYPE_LABELS.get(room_type, "Room")
	label.position = room_pos + Vector3(0, 3.5, 0)
	label.font_size = 32
	label.outline_size = 6
	label.modulate = light_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	room_node.add_child(label)
	_room_labels[room_key] = label

	# ── Special room decorations ──
	match room_type:
		"treasure":
			_add_treasure_chest(room_node, room_pos)
		"shrine":
			_add_shrine_pillar(room_node, room_pos)
		"boss":
			_add_boss_decoration(room_node, room_pos, omni)
		"miniboss":
			# Slightly more intense lighting for miniboss rooms
			omni.light_energy = 1.8
			omni.omni_range = 14.0


## Build the 4 walls of a room, leaving gaps where corridors connect.
## Each wall that has no corridor gap is a single solid box. Walls with
## a gap are split into two segments flanking the corridor opening.
func _build_room_walls(
	parent: Node3D,
	room_pos: Vector3,
	wall_mat: StandardMaterial3D,
	openings: Array
) -> void:
	var half_room: float = ROOM_SIZE / 2.0
	var half_corridor: float = CORRIDOR_WIDTH / 2.0
	var wall_y: float = room_pos.y + WALL_HEIGHT / 2.0

	# Wall definitions: direction -> { axis, offset, full_size }
	# "north" = -Z side, "south" = +Z side, "west" = -X side, "east" = +X side
	var walls: Array[Dictionary] = [
		{
			"dir": "north",
			"center": room_pos + Vector3(0, wall_y, -half_room),
			"full_size": Vector3(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS),
			"split_axis": "x",
		},
		{
			"dir": "south",
			"center": room_pos + Vector3(0, wall_y, half_room),
			"full_size": Vector3(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS),
			"split_axis": "x",
		},
		{
			"dir": "west",
			"center": room_pos + Vector3(-half_room, wall_y, 0),
			"full_size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE),
			"split_axis": "z",
		},
		{
			"dir": "east",
			"center": room_pos + Vector3(half_room, wall_y, 0),
			"full_size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE),
			"split_axis": "z",
		},
	]

	for wall_def in walls:
		var dir_name: String = wall_def["dir"]
		var center: Vector3 = wall_def["center"]
		var full_size: Vector3 = wall_def["full_size"]
		var split_axis: String = wall_def["split_axis"]

		if dir_name in openings:
			# This wall has a corridor gap -- split into two segments
			var segment_length: float = (half_room - half_corridor)

			if split_axis == "x":
				# Wall runs along X axis (north/south), split horizontally
				var left_size: Vector3 = Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS)
				var right_size: Vector3 = Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS)
				var left_offset: float = -(half_corridor + segment_length / 2.0)
				var right_offset: float = (half_corridor + segment_length / 2.0)

				var left_wall: CSGBox3D = CSGBox3D.new()
				left_wall.name = "Wall_%s_L" % dir_name
				left_wall.size = left_size
				left_wall.position = center + Vector3(left_offset, 0, 0)
				left_wall.material = wall_mat
				parent.add_child(left_wall)

				var right_wall: CSGBox3D = CSGBox3D.new()
				right_wall.name = "Wall_%s_R" % dir_name
				right_wall.size = right_size
				right_wall.position = center + Vector3(right_offset, 0, 0)
				right_wall.material = wall_mat
				parent.add_child(right_wall)
			else:
				# Wall runs along Z axis (east/west), split vertically (along Z)
				var front_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_length)
				var back_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_length)
				var front_offset: float = -(half_corridor + segment_length / 2.0)
				var back_offset: float = (half_corridor + segment_length / 2.0)

				var front_wall: CSGBox3D = CSGBox3D.new()
				front_wall.name = "Wall_%s_F" % dir_name
				front_wall.size = front_size
				front_wall.position = center + Vector3(0, 0, front_offset)
				front_wall.material = wall_mat
				parent.add_child(front_wall)

				var back_wall: CSGBox3D = CSGBox3D.new()
				back_wall.name = "Wall_%s_B" % dir_name
				back_wall.size = back_size
				back_wall.position = center + Vector3(0, 0, back_offset)
				back_wall.material = wall_mat
				parent.add_child(back_wall)
		else:
			# Solid wall -- no corridor gap
			var wall_box: CSGBox3D = CSGBox3D.new()
			wall_box.name = "Wall_%s" % dir_name
			wall_box.size = full_size
			wall_box.position = center
			wall_box.material = wall_mat
			parent.add_child(wall_box)


## Add a gold "chest" box at the center of a treasure room.
func _add_treasure_chest(parent: Node3D, room_pos: Vector3) -> void:
	var chest: CSGBox3D = CSGBox3D.new()
	chest.name = "TreasureChest"
	chest.size = Vector3(1.2, 0.8, 0.8)
	chest.position = room_pos + Vector3(0, 0.4, 0)

	var chest_mat: StandardMaterial3D = StandardMaterial3D.new()
	chest_mat.albedo_color = Color(0.85, 0.65, 0.13)  # Gold
	chest_mat.emission_enabled = true
	chest_mat.emission = Color(0.7, 0.5, 0.1)
	chest_mat.emission_energy_multiplier = 0.5
	chest_mat.metallic = 0.7
	chest_mat.roughness = 0.3
	chest.material = chest_mat

	parent.add_child(chest)


## Add an emissive blue pillar at the center of a shrine room.
func _add_shrine_pillar(parent: Node3D, room_pos: Vector3) -> void:
	var pillar: CSGCylinder3D = CSGCylinder3D.new()
	pillar.name = "ShrinePillar"
	pillar.radius = 0.5
	pillar.height = 3.0
	pillar.sides = 12
	pillar.position = room_pos + Vector3(0, 1.5, 0)

	var pillar_mat: StandardMaterial3D = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.2, 0.4, 0.9)
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.3, 0.5, 1.0)
	pillar_mat.emission_energy_multiplier = 1.2
	pillar_mat.roughness = 0.2
	pillar_mat.metallic = 0.4
	pillar.material = pillar_mat

	parent.add_child(pillar)

	# Add a glowing base ring
	var base_ring: CSGCylinder3D = CSGCylinder3D.new()
	base_ring.name = "ShrineBase"
	base_ring.radius = 1.5
	base_ring.height = 0.1
	base_ring.sides = 16
	base_ring.position = room_pos + Vector3(0, 0.05, 0)

	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.1, 0.2, 0.6, 0.5)
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.2, 0.3, 0.8)
	base_mat.emission_energy_multiplier = 0.8
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_ring.material = base_mat

	parent.add_child(base_ring)


## Add visual decoration to boss rooms (enhanced red lighting).
func _add_boss_decoration(parent: Node3D, room_pos: Vector3, main_light: OmniLight3D) -> void:
	# Add corner accent lights for a more dramatic atmosphere
	var accent_offsets: Array[Vector3] = [
		Vector3(-5.0, 1.0, -5.0),
		Vector3(5.0, 1.0, -5.0),
		Vector3(-5.0, 1.0, 5.0),
		Vector3(5.0, 1.0, 5.0),
	]

	for offset_idx in range(accent_offsets.size()):
		var accent_light: OmniLight3D = OmniLight3D.new()
		accent_light.name = "BossAccent_%d" % offset_idx
		accent_light.position = room_pos + accent_offsets[offset_idx]
		accent_light.light_color = Color(0.9, 0.15, 0.1)
		accent_light.omni_range = 6.0
		accent_light.light_energy = 0.6
		accent_light.shadow_enabled = false
		parent.add_child(accent_light)

	# Add a raised platform/pedestal for the boss
	var pedestal: CSGCylinder3D = CSGCylinder3D.new()
	pedestal.name = "BossPedestal"
	pedestal.radius = 3.0
	pedestal.height = 0.3
	pedestal.sides = 24
	pedestal.position = room_pos + Vector3(0, 0.15, 0)

	var pedestal_mat: StandardMaterial3D = StandardMaterial3D.new()
	pedestal_mat.albedo_color = Color(0.3, 0.08, 0.08)
	pedestal_mat.emission_enabled = true
	pedestal_mat.emission = Color(0.4, 0.05, 0.05)
	pedestal_mat.emission_energy_multiplier = 0.4
	pedestal_mat.roughness = 0.6
	pedestal.material = pedestal_mat

	parent.add_child(pedestal)


# ──────────────────────────────────────────────
#  Corridor building
# ──────────────────────────────────────────────

## Build the floor, walls, and ceiling strip that connects two adjacent rooms.
func _build_corridor(corridor: Dictionary, theme: Dictionary, rooms: Array) -> void:
	var from_grid: Vector2i = corridor.get("from", Vector2i.ZERO)
	var to_grid: Vector2i = corridor.get("to", Vector2i.ZERO)

	# Compute world positions from grid coordinates
	var from_pos: Vector3 = Vector3(
		float(from_grid.x) * ROOM_SPACING,
		0.0,
		float(from_grid.y) * ROOM_SPACING
	)
	var to_pos: Vector3 = Vector3(
		float(to_grid.x) * ROOM_SPACING,
		0.0,
		float(to_grid.y) * ROOM_SPACING
	)

	# Midpoint between the two rooms
	var midpoint: Vector3 = (from_pos + to_pos) / 2.0

	# Determine if horizontal (same z) or vertical (same x)
	var is_horizontal: bool = (from_grid.y == to_grid.y)

	# Corridor length spans the gap between room edges
	var corridor_length: float = ROOM_SPACING - ROOM_SIZE

	# Materials
	var floor_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("floorColor", 0x1a1a2e))).darkened(0.1)
	)
	var wall_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("wallColor", 0x2a2a3e))).darkened(0.05)
	)
	var ceiling_mat: StandardMaterial3D = _create_material(
		_int_to_color(int(theme.get("ceilingColor", 0x0e0e1e)))
	)

	# Container for this corridor
	var corridor_node: Node3D = Node3D.new()
	corridor_node.name = "Corridor_%d%d_to_%d%d" % [from_grid.x, from_grid.y, to_grid.x, to_grid.y]
	_floor_node.add_child(corridor_node)

	# ── Floor ──
	var floor_size: Vector3 = Vector3.ZERO
	if is_horizontal:
		floor_size = Vector3(corridor_length, FLOOR_THICKNESS, CORRIDOR_WIDTH)
	else:
		floor_size = Vector3(CORRIDOR_WIDTH, FLOOR_THICKNESS, corridor_length)

	var floor_box: CSGBox3D = CSGBox3D.new()
	floor_box.name = "CorridorFloor"
	floor_box.size = floor_size
	floor_box.position = midpoint
	floor_box.material = floor_mat

	# Add static body for ground raycasting
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = floor_size + Vector3(0, 0.1, 0)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_box.add_child(floor_body)

	corridor_node.add_child(floor_box)

	# ── Ceiling ──
	var ceiling_box: CSGBox3D = CSGBox3D.new()
	ceiling_box.name = "CorridorCeiling"
	ceiling_box.size = floor_size
	ceiling_box.position = midpoint + Vector3(0, WALL_HEIGHT, 0)
	ceiling_box.material = ceiling_mat
	corridor_node.add_child(ceiling_box)

	# ── Side walls ──
	var wall_y: float = midpoint.y + WALL_HEIGHT / 2.0

	if is_horizontal:
		# Corridor runs along X axis: walls on north/south sides (Z offset)
		var half_w: float = CORRIDOR_WIDTH / 2.0
		var wall_size: Vector3 = Vector3(corridor_length, WALL_HEIGHT, WALL_THICKNESS)

		var north_wall: CSGBox3D = CSGBox3D.new()
		north_wall.name = "CorridorWallN"
		north_wall.size = wall_size
		north_wall.position = Vector3(midpoint.x, wall_y, midpoint.z - half_w)
		north_wall.material = wall_mat
		corridor_node.add_child(north_wall)

		var south_wall: CSGBox3D = CSGBox3D.new()
		south_wall.name = "CorridorWallS"
		south_wall.size = wall_size
		south_wall.position = Vector3(midpoint.x, wall_y, midpoint.z + half_w)
		south_wall.material = wall_mat
		corridor_node.add_child(south_wall)
	else:
		# Corridor runs along Z axis: walls on east/west sides (X offset)
		var half_w: float = CORRIDOR_WIDTH / 2.0
		var wall_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, corridor_length)

		var west_wall: CSGBox3D = CSGBox3D.new()
		west_wall.name = "CorridorWallW"
		west_wall.size = wall_size
		west_wall.position = Vector3(midpoint.x - half_w, wall_y, midpoint.z)
		west_wall.material = wall_mat
		corridor_node.add_child(west_wall)

		var east_wall: CSGBox3D = CSGBox3D.new()
		east_wall.name = "CorridorWallE"
		east_wall.size = wall_size
		east_wall.position = Vector3(midpoint.x + half_w, wall_y, midpoint.z)
		east_wall.material = wall_mat
		corridor_node.add_child(east_wall)

	# ── Dim corridor light ──
	var corridor_light: OmniLight3D = OmniLight3D.new()
	corridor_light.name = "CorridorLight"
	corridor_light.position = midpoint + Vector3(0, 3.5, 0)
	corridor_light.light_color = _int_to_color(
		int(theme.get("lightColors", {}).get("normal", 0xCCCCCC))
	).darkened(0.3)
	corridor_light.omni_range = 8.0
	corridor_light.light_energy = 0.5
	corridor_light.shadow_enabled = false
	corridor_node.add_child(corridor_light)


# ──────────────────────────────────────────────
#  Enemy spawning
# ──────────────────────────────────────────────

## Spawn enemy instances for a room at randomized positions within the room.
func _spawn_room_enemies(room: Dictionary) -> void:
	var enemies: Array = room.get("enemies", [])
	if enemies.is_empty():
		return

	var room_pos: Vector3 = room.get("world_position", Vector3.ZERO)
	var grid_x: int = int(room.get("grid_x", 0))
	var grid_z: int = int(room.get("grid_z", 0))
	var room_key: String = "%d,%d" % [grid_x, grid_z]

	# Scatter radius: 35% of room size from center
	var scatter: float = ROOM_SIZE * 0.35

	for enemy_id in enemies:
		var enemy: CharacterBody3D = enemy_scene.instantiate()
		_floor_node.add_child(enemy)

		# Random offset within scatter radius
		var offset_x: float = randf_range(-scatter, scatter)
		var offset_z: float = randf_range(-scatter, scatter)
		var spawn_pos: Vector3 = room_pos + Vector3(offset_x, 1.0, offset_z)

		enemy.setup(str(enemy_id), spawn_pos)
		enemy.set_meta("dungeon_room", room_key)
		_dungeon_enemies.append(enemy)


# ──────────────────────────────────────────────
#  Trap spawning
# ──────────────────────────────────────────────

## Spawn trap Area3D nodes for each trap in a room.
## Each trap has a collision area, a visual disc, and damage-on-overlap logic.
func _spawn_room_traps(room: Dictionary, theme: Dictionary) -> void:
	var traps: Array = room.get("traps", [])
	if traps.is_empty():
		return

	var room_pos: Vector3 = room.get("world_position", Vector3.ZERO)

	# Scatter radius for trap placement: 25% of room size
	var scatter: float = ROOM_SIZE * 0.25

	for trap_key in traps:
		var trap_key_str: String = str(trap_key)

		# Look up trap definition from DataManager
		var trap_data: Dictionary = DataManager.dungeon_trap_types.get(trap_key_str, {})
		if trap_data.is_empty():
			push_warning("DungeonRenderer: Unknown trap type '%s'" % trap_key_str)
			continue

		var trap_radius: float = float(trap_data.get("radius", 1.5))
		var trap_color_int: int = int(trap_data.get("color", 0xFFFFFF))
		var trap_emissive_int: int = int(trap_data.get("emissive", 0x888888))

		# Random position within room
		var offset_x: float = randf_range(-scatter, scatter)
		var offset_z: float = randf_range(-scatter, scatter)
		var trap_pos: Vector3 = room_pos + Vector3(offset_x, 0.0, offset_z)

		# ── Area3D for collision detection ──
		var trap_area: Area3D = Area3D.new()
		trap_area.name = "Trap_%s_%d" % [trap_key_str, _trap_areas.size()]
		trap_area.position = trap_pos
		trap_area.collision_layer = 0
		trap_area.collision_mask = 2  # Player layer

		var col_shape: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = trap_radius
		col_shape.shape = sphere
		trap_area.add_child(col_shape)

		# ── Visual disc ──
		var disc: CSGCylinder3D = CSGCylinder3D.new()
		disc.name = "TrapDisc"
		disc.radius = trap_radius
		disc.height = 0.1
		disc.sides = 16
		disc.position = Vector3(0, 0.05, 0)

		var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
		disc_mat.albedo_color = _int_to_color(trap_color_int)
		disc_mat.albedo_color.a = 0.6
		disc_mat.emission_enabled = true
		disc_mat.emission = _int_to_color(trap_emissive_int)
		disc_mat.emission_energy_multiplier = 0.8
		disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc_mat.roughness = 0.5
		disc.material = disc_mat

		trap_area.add_child(disc)

		_floor_node.add_child(trap_area)

		# ── Connect signals ──
		# Store trap data as meta on the area for the callback
		trap_area.set_meta("trap_data", trap_data.duplicate())
		trap_area.set_meta("trap_key", trap_key_str)

		trap_area.body_entered.connect(_on_trap_entered.bind(trap_data.duplicate(), trap_area))
		trap_area.body_exited.connect(_on_trap_exited.bind(trap_key_str, trap_area))

		_trap_areas.append(trap_area)


# ──────────────────────────────────────────────
#  Trap damage logic
# ──────────────────────────────────────────────

## Called when a body enters a trap area.
## If the body is the player, start a repeating damage timer.
func _on_trap_entered(body: Node3D, trap_data: Dictionary, trap_area: Area3D) -> void:
	if not body.is_in_group("player"):
		return

	var trap_key: String = str(trap_area.get_meta("trap_key", "unknown"))
	var tick_interval: float = float(trap_data.get("tick", 1.0))
	var damage: int = int(trap_data.get("dmg", 5))
	var effect: String = str(trap_data.get("effect", "damage"))
	var trap_name: String = str(trap_data.get("name", "Trap"))

	# Create a unique timer key for this specific trap instance
	var timer_key: String = "trap_%d" % trap_area.get_instance_id()

	# Avoid duplicate timers for the same trap
	if _trap_timers.has(timer_key):
		return

	# Create the damage timer
	var timer: Timer = Timer.new()
	timer.name = "TrapTimer_%s" % timer_key
	timer.wait_time = tick_interval
	timer.one_shot = false
	add_child(timer)

	timer.timeout.connect(_on_trap_tick.bind(damage, effect, trap_name, trap_area))
	timer.start()

	_trap_timers[timer_key] = timer

	# Apply immediate first tick of damage
	_apply_trap_damage(damage, effect, trap_name, trap_area)


## Called when a body exits a trap area.
## Stops and frees the damage timer for that trap.
func _on_trap_exited(body: Node3D, trap_key: String, trap_area: Area3D) -> void:
	if not body.is_in_group("player"):
		return

	var timer_key: String = "trap_%d" % trap_area.get_instance_id()

	if _trap_timers.has(timer_key):
		var timer: Timer = _trap_timers[timer_key] as Timer
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		_trap_timers.erase(timer_key)

	# Remove slow effect if this was a slow trap
	if trap_key == "slow" and _player != null and is_instance_valid(_player):
		_player.set_meta("dungeon_slowed", false)


## Timer tick callback: apply trap damage each interval.
func _on_trap_tick(damage: int, effect: String, trap_name: String, trap_area: Area3D) -> void:
	# Safety check: if trap or player is gone, stop ticking
	if not is_instance_valid(trap_area) or _player == null or not is_instance_valid(_player):
		return

	_apply_trap_damage(damage, effect, trap_name, trap_area)


## Apply damage and effects from a trap to the player.
func _apply_trap_damage(damage: int, effect: String, trap_name: String, trap_area: Area3D) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	# Deal damage
	GameState.player["hp"] = int(GameState.player["hp"]) - damage

	# Request float text at the trap's position
	var trap_pos: Vector3 = trap_area.global_position + Vector3(0, 1.5, 0)
	var damage_color: Color = Color(1.0, 0.3, 0.1)

	match effect:
		"damage":
			damage_color = Color(1.0, 0.4, 0.1)  # Orange-red for fire
		"slow":
			damage_color = Color(0.3, 0.6, 1.0)  # Blue for stasis
			if _player != null and is_instance_valid(_player):
				_player.set_meta("dungeon_slowed", true)
		"poison":
			damage_color = Color(0.3, 0.9, 0.2)  # Green for poison

	EventBus.float_text_requested.emit(
		"-%d %s" % [damage, trap_name],
		trap_pos,
		damage_color
	)

	# Emit player damaged signal
	EventBus.player_damaged.emit(damage, trap_name)

	# Check for player death
	if int(GameState.player["hp"]) <= 0:
		GameState.player["hp"] = 0
		EventBus.player_died.emit()


# ──────────────────────────────────────────────
#  Environment
# ──────────────────────────────────────────────

## Set up a WorldEnvironment node with themed ambient light and fog.
func _setup_environment(theme: Dictionary) -> void:
	if _floor_node == null:
		return

	var ambient_color: Color = _int_to_color(int(theme.get("ambientColor", 0x1a2a4a)))
	var ambient_intensity: float = float(theme.get("ambientIntensity", 0.5))
	var fog_color: Color = _int_to_color(int(theme.get("fogColor", 0x020810)))

	# Create the Environment resource
	var env: Environment = Environment.new()

	# Ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color.lightened(0.15)
	env.ambient_light_energy = maxf(ambient_intensity, 0.4)

	# Fog
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.02

	# Background (solid dark color for enclosed dungeon feel)
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog_color.darkened(0.3)

	# Create WorldEnvironment node
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "DungeonEnvironment"
	world_env.environment = env
	_floor_node.add_child(world_env)


# ──────────────────────────────────────────────
#  Visual feedback
# ──────────────────────────────────────────────

## Brighten a room's light after it has been cleared.
func _brighten_room_light(room_key: String) -> void:
	if _floor_node == null:
		return

	var room_node: Node3D = _floor_node.get_node_or_null("Room_%s" % room_key) as Node3D
	if room_node == null:
		return

	var light: OmniLight3D = room_node.get_node_or_null("RoomLight_%s" % room_key) as OmniLight3D
	if light != null:
		# Increase brightness and range to indicate cleared
		light.light_energy = light.light_energy * 1.5
		light.omni_range = light.omni_range * 1.2
		light.light_color = light.light_color.lightened(0.2)

	# Update the room label to show "Cleared"
	if _room_labels.has(room_key):
		var label: Label3D = _room_labels[room_key] as Label3D
		if is_instance_valid(label):
			label.text = label.text + " [Cleared]"
			label.modulate = Color(0.4, 1.0, 0.4)


# ──────────────────────────────────────────────
#  Utility helpers
# ──────────────────────────────────────────────

## Convert a 0xRRGGBB integer (from JSON) to a Godot Color.
func _int_to_color(val: int) -> Color:
	var r: float = float((val >> 16) & 0xFF) / 255.0
	var g: float = float((val >> 8) & 0xFF) / 255.0
	var b: float = float(val & 0xFF) / 255.0
	return Color(r, g, b, 1.0)


## Create a StandardMaterial3D with the given albedo color and sensible defaults.
func _create_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.85
	mat.metallic = 0.05
	return mat
