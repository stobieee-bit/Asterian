## DungeonSystem -- Procedural dungeon generation and management
##
## Generates multi-floor combat gauntlets with grid-based room layouts.
## Each floor is a connected graph of rooms populated with enemies, traps,
## and special encounters. Floors scale in difficulty, grid size, and loot.
##
## Reads theme, modifier, trap, and loot data from DataManager (dungeons.json).
## Enemies are sourced from DataManager.enemies filtered by level range.
extends Node


# ──────────────────────────────────────────────
#  Constants
# ──────────────────────────────────────────────

## Room type identifiers
const ROOM_ENTRANCE: String  = "entrance"
const ROOM_NORMAL: String    = "normal"
const ROOM_TREASURE: String  = "treasure"
const ROOM_SHRINE: String    = "shrine"
const ROOM_BOSS: String      = "boss"
const ROOM_MINIBOSS: String  = "miniboss"

## Target fill ratio for the grid (approximately 60% of cells become rooms)
const GRID_FILL_RATIO: float = 0.60

## Trap type keys (must match keys in dungeons.json trap_types)
const TRAP_KEYS: Array[String] = ["fire", "slow", "poison"]


# ──────────────────────────────────────────────
#  Internal state
# ──────────────────────────────────────────────

## The theme dict for the current dungeon run (from DataManager.dungeon_themes)
var _current_theme: Dictionary = {}

## Full floor data returned by _generate_floor()
var _current_floor_data: Dictionary = {}

## Active modifier dicts for this dungeon run
var _active_modifiers: Array = []

## Area ID that started this dungeon (used for theme lookup)
var _area_id: String = ""

## Stats tracked across the entire run
var _rooms_cleared: int = 0
var _total_kills: int = 0
var _run_start_time: float = 0.0

## Player's position before entering the dungeon (for return teleport)
var _return_position: Vector3 = Vector3(0, 1, 0)


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("dungeon_system")


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Start a new dungeon run in the given area with optional modifiers.
## Generates floor 1 and returns the full floor data dictionary.
func start_dungeon(area_id: String, modifiers: Array) -> Dictionary:
	# Reset run state
	_area_id = str(area_id)
	_rooms_cleared = 0
	_total_kills = 0
	_run_start_time = Time.get_unix_time_from_system()

	# Save the player's current position so we can return them after exiting
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node != null:
		_return_position = player_node.global_position

	# Activate GameState flags
	GameState.dungeon_active = true
	GameState.dungeon_floor = 1

	# Resolve theme from area_theme_map (default to "industrial")
	var theme_key: String = str(DataManager.dungeon_area_theme_map.get(_area_id, "industrial"))
	if DataManager.dungeon_themes.has(theme_key):
		_current_theme = DataManager.dungeon_themes[theme_key]
	else:
		_current_theme = DataManager.dungeon_themes.get("industrial", {})

	# Store active modifiers -- look up full dicts from DataManager
	_active_modifiers = []
	for mod_key in modifiers:
		var mod_id: String = str(mod_key)
		if DataManager.dungeon_modifiers.has(mod_id):
			var mod_dict: Dictionary = DataManager.dungeon_modifiers[mod_id].duplicate()
			mod_dict["id"] = mod_id
			_active_modifiers.append(mod_dict)

	# Generate the first floor
	_current_floor_data = _generate_floor()

	EventBus.chat_message.emit(
		"Dungeon started! Floor 1 — %s" % str(_current_theme.get("name", "Unknown")),
		"dungeon"
	)

	# Emit signal so the renderer and panel can react
	EventBus.dungeon_started.emit(_current_floor_data)

	return _current_floor_data


## Advance to the next floor. Returns the new floor data dictionary.
func advance_floor() -> Dictionary:
	GameState.dungeon_floor += 1
	var floor_num: int = GameState.dungeon_floor

	# Update personal best
	if floor_num > GameState.dungeon_max_floor:
		GameState.dungeon_max_floor = floor_num

	_current_floor_data = _generate_floor()

	EventBus.chat_message.emit(
		"Descending to floor %d..." % floor_num,
		"dungeon"
	)

	# Emit signal so the renderer builds the new floor
	EventBus.dungeon_floor_advanced.emit(_current_floor_data)

	return _current_floor_data


## Mark a room as cleared at the given grid coordinates.
func clear_room(grid_x: int, grid_z: int) -> void:
	var rooms: Array = _current_floor_data.get("rooms", [])
	for room in rooms:
		if int(room.get("grid_x", -1)) == grid_x and int(room.get("grid_z", -1)) == grid_z:
			room["cleared"] = true
			_rooms_cleared += 1

			var room_type: String = str(room.get("type", ROOM_NORMAL))
			if room_type == ROOM_BOSS:
				EventBus.chat_message.emit(
					"Boss room cleared on floor %d!" % GameState.dungeon_floor,
					"dungeon"
				)
			elif room_type == ROOM_MINIBOSS:
				EventBus.chat_message.emit(
					"Mini-boss room cleared!",
					"dungeon"
				)

			# Emit room cleared signal
			EventBus.dungeon_room_cleared.emit(grid_x, grid_z)
			return


## Check whether the current floor is complete (boss room cleared).
func is_floor_complete() -> bool:
	var rooms: Array = _current_floor_data.get("rooms", [])
	for room in rooms:
		if str(room.get("type", "")) == ROOM_BOSS:
			return bool(room.get("cleared", false))
	# No boss room found -- treat as complete
	return true


## Roll loot drops for a regular enemy on the given floor.
## Returns an Array of { item_id: String, quantity: int }.
func get_loot_for_enemy(floor_num: int) -> Array:
	return _roll_loot_table(floor_num, "enemyLoot")


## Roll loot drops for a boss enemy on the given floor.
## Returns an Array of { item_id: String, quantity: int }.
func get_loot_for_boss(floor_num: int) -> Array:
	return _roll_loot_table(floor_num, "bossLoot")


## Get enemy type IDs appropriate for the given floor level.
## Filters DataManager.enemies by level range: floor*3 to floor*3+15.
func get_floor_enemies(floor_num: int) -> Array:
	var min_level: int = floor_num * 3
	var max_level: int = floor_num * 3 + 15
	var result: Array = []

	for enemy_id in DataManager.enemies:
		var data: Dictionary = DataManager.enemies[enemy_id]
		var enemy_level: int = int(data.get("level", 0))
		if enemy_level >= min_level and enemy_level <= max_level:
			result.append(str(enemy_id))

	# Fallback: if no enemies match, pick the closest available
	if result.is_empty():
		var closest_id: String = ""
		var closest_diff: int = 999
		for enemy_id in DataManager.enemies:
			var data: Dictionary = DataManager.enemies[enemy_id]
			var enemy_level: int = int(data.get("level", 0))
			var diff: int = absi(enemy_level - min_level)
			if diff < closest_diff:
				closest_diff = diff
				closest_id = str(enemy_id)
		if closest_id != "":
			result.append(closest_id)

	return result


## End the current dungeon run and emit summary.
func exit_dungeon() -> void:
	GameState.dungeon_active = false

	var elapsed: float = Time.get_unix_time_from_system() - _run_start_time
	var minutes: int = int(elapsed / 60.0)
	var seconds: int = int(elapsed) % 60

	EventBus.chat_message.emit(
		"Dungeon complete! Reached floor %d. Rooms cleared: %d, Kills: %d, Time: %d:%02d" % [
			GameState.dungeon_floor, _rooms_cleared, _total_kills, minutes, seconds
		],
		"dungeon"
	)

	# Teleport player back to where they were before entering
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node != null:
		player_node.global_position = _return_position

	# Emit exit signal so renderer clears the 3D geometry
	EventBus.dungeon_exited.emit()

	# Clean up internal state
	_current_floor_data = {}
	_active_modifiers = []
	_current_theme = {}
	_area_id = ""


## Return the active modifier dicts for this run.
func get_active_modifiers() -> Array:
	return _active_modifiers


## Return the current theme dictionary.
func get_current_theme() -> Dictionary:
	return _current_theme


## Increment the kill counter (called externally when an enemy dies in the dungeon).
func register_kill() -> void:
	_total_kills += 1


# ──────────────────────────────────────────────
#  Floor generation
# ──────────────────────────────────────────────

## Generate a complete floor layout.
## Returns a Dictionary with theme, floor number, grid, rooms, corridors, and key positions.
func _generate_floor() -> Dictionary:
	var floor_num: int = GameState.dungeon_floor
	var room_spacing: int = int(DataManager.dungeon_config.get("roomSpacing", 22))

	# Grid size scales with floor: min(3 + floor/3, 7)
	var grid_dim: int = mini(3 + int(floor_num / 3), 7)

	# Build the room grid
	var grid: Array = _create_empty_grid(grid_dim)
	var rooms: Array = _place_rooms(grid, grid_dim, floor_num)
	var corridors: Array = _connect_rooms(rooms, grid_dim)

	# Compute world positions for each room
	for room in rooms:
		var wx: float = float(int(room["grid_x"]) * room_spacing)
		var wz: float = float(int(room["grid_z"]) * room_spacing)
		room["world_position"] = Vector3(wx, 0.0, wz)

	# Find entrance and boss positions
	var entrance_pos: Vector3 = Vector3.ZERO
	var boss_pos: Vector3 = Vector3.ZERO
	for room in rooms:
		if str(room.get("type", "")) == ROOM_ENTRANCE:
			entrance_pos = room["world_position"]
		elif str(room.get("type", "")) == ROOM_BOSS:
			boss_pos = room["world_position"]

	return {
		"theme": _current_theme,
		"floor": floor_num,
		"grid_size": grid_dim,
		"rooms": rooms,
		"corridors": corridors,
		"entrance_pos": entrance_pos,
		"boss_pos": boss_pos,
	}


## Create a grid_dim x grid_dim 2D array filled with 0 (empty).
func _create_empty_grid(grid_dim: int) -> Array:
	var grid: Array = []
	for _x in range(grid_dim):
		var row: Array = []
		for _z in range(grid_dim):
			row.append(0)
		grid.append(row)
	return grid


## Place rooms on the grid using random walk / branching from (0,0).
## Returns an Array of room dictionaries.
func _place_rooms(grid: Array, grid_dim: int, floor_num: int) -> Array:
	var target_rooms: int = int(float(grid_dim * grid_dim) * GRID_FILL_RATIO)
	var rooms: Array = []
	var room_coords: Dictionary = {}  # "x,z" -> room index for fast lookup

	# Directional offsets: right, left, down, up
	var directions: Array = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]

	# ── Step 1: Place entrance at (0, 0) ──
	grid[0][0] = 1
	var entrance_room: Dictionary = _make_room(0, 0, ROOM_ENTRANCE)
	rooms.append(entrance_room)
	room_coords["0,0"] = 0

	# ── Step 2: Random walk / branch to fill ~60% of cells ──
	var frontier: Array = [Vector2i(0, 0)]

	while rooms.size() < target_rooms and not frontier.is_empty():
		# Pick a random frontier cell to branch from
		var idx: int = randi() % frontier.size()
		var current: Vector2i = frontier[idx]

		# Shuffle directions for variety
		var shuffled_dirs: Array = directions.duplicate()
		shuffled_dirs.shuffle()

		var placed: bool = false
		for dir in shuffled_dirs:
			var nx: int = current.x + int(dir.x)
			var nz: int = current.y + int(dir.y)

			# Bounds check
			if nx < 0 or nx >= grid_dim or nz < 0 or nz >= grid_dim:
				continue
			# Already occupied
			if grid[nx][nz] != 0:
				continue

			# Place the room
			grid[nx][nz] = 1
			var new_room: Dictionary = _make_room(nx, nz, ROOM_NORMAL)
			room_coords["%d,%d" % [nx, nz]] = rooms.size()
			rooms.append(new_room)
			frontier.append(Vector2i(nx, nz))
			placed = true

			if rooms.size() >= target_rooms:
				break

		# If no neighbours available, remove from frontier
		if not placed:
			frontier.remove_at(idx)

	# ── Step 3: Place boss room at the farthest room from entrance ──
	var farthest_idx: int = _find_farthest_room(rooms, 0)
	if farthest_idx > 0:
		rooms[farthest_idx]["type"] = ROOM_BOSS

	# ── Step 4: Place special rooms ──
	var available_indices: Array = _get_normal_room_indices(rooms)
	available_indices.shuffle()

	# 1-2 treasure rooms
	var treasure_count: int = randi_range(1, 2)
	for _i in range(treasure_count):
		if available_indices.is_empty():
			break
		var ti: int = available_indices.pop_back()
		rooms[ti]["type"] = ROOM_TREASURE

	# 0-1 shrine room (50% chance)
	if not available_indices.is_empty() and randf() < 0.5:
		var si: int = available_indices.pop_back()
		rooms[si]["type"] = ROOM_SHRINE

	# 0-1 miniboss room (appears on floor 3+)
	if not available_indices.is_empty() and floor_num >= 3 and randf() < 0.6:
		var mi: int = available_indices.pop_back()
		rooms[mi]["type"] = ROOM_MINIBOSS

	# ── Step 5: Assign enemies and traps ──
	var enemy_pool: Array = get_floor_enemies(floor_num)
	for room in rooms:
		var room_type: String = str(room.get("type", ROOM_NORMAL))
		_assign_enemies_to_room(room, room_type, floor_num, enemy_pool)
		_assign_traps_to_room(room, room_type, floor_num)

	return rooms


## Create a minimal room dictionary at the given grid coordinates.
func _make_room(gx: int, gz: int, room_type: String) -> Dictionary:
	return {
		"grid_x": gx,
		"grid_z": gz,
		"type": room_type,
		"enemies": [] as Array,
		"traps": [] as Array,
		"cleared": false,
		"world_position": Vector3.ZERO,
	}


## Find the index of the room farthest (Manhattan distance) from the given start index.
func _find_farthest_room(rooms: Array, start_idx: int) -> int:
	if rooms.is_empty():
		return 0

	var start_x: int = int(rooms[start_idx].get("grid_x", 0))
	var start_z: int = int(rooms[start_idx].get("grid_z", 0))
	var best_idx: int = 0
	var best_dist: int = 0

	for i in range(rooms.size()):
		if i == start_idx:
			continue
		var dx: int = absi(int(rooms[i].get("grid_x", 0)) - start_x)
		var dz: int = absi(int(rooms[i].get("grid_z", 0)) - start_z)
		var dist: int = dx + dz
		if dist > best_dist:
			best_dist = dist
			best_idx = i

	return best_idx


## Return indices of rooms whose type is still "normal".
func _get_normal_room_indices(rooms: Array) -> Array:
	var indices: Array = []
	for i in range(rooms.size()):
		if str(rooms[i].get("type", "")) == ROOM_NORMAL:
			indices.append(i)
	return indices


## Assign enemy type IDs to a room based on its type and floor number.
func _assign_enemies_to_room(room: Dictionary, room_type: String, floor_num: int, enemy_pool: Array) -> void:
	if enemy_pool.is_empty():
		return

	var count: int = 0

	match room_type:
		ROOM_NORMAL:
			# 2-4 enemies, scaling slightly with floor
			count = randi_range(2, mini(4 + int(floor_num / 4), 6))
		ROOM_MINIBOSS:
			# 3-5 enemies plus a tougher crowd
			count = randi_range(3, mini(5 + int(floor_num / 3), 8))
		ROOM_BOSS:
			# 1 boss + 1-2 adds on higher floors
			count = 1 + randi_range(0, mini(int(floor_num / 5), 2))
		ROOM_ENTRANCE, ROOM_TREASURE, ROOM_SHRINE:
			# No enemies in safe rooms
			return

	var enemies: Array = []
	for _i in range(count):
		var eid: String = enemy_pool[randi() % enemy_pool.size()]
		enemies.append(eid)

	room["enemies"] = enemies


## Assign traps to a room. Higher floors get more traps.
func _assign_traps_to_room(room: Dictionary, room_type: String, floor_num: int) -> void:
	# No traps in entrance or shrine
	if room_type == ROOM_ENTRANCE or room_type == ROOM_SHRINE:
		return

	# Base trap chance increases with floor
	var trap_chance: float = 0.15 + float(floor_num) * 0.03
	trap_chance = minf(trap_chance, 0.70)

	# Boss/miniboss rooms always have some traps after floor 2
	if (room_type == ROOM_BOSS or room_type == ROOM_MINIBOSS) and floor_num >= 3:
		trap_chance = maxf(trap_chance, 0.50)

	if randf() > trap_chance:
		return

	# How many traps: 1-3 scaled by floor
	var max_traps: int = mini(1 + int(floor_num / 3), 3)
	var trap_count: int = randi_range(1, max_traps)

	var traps: Array = []
	for _i in range(trap_count):
		var trap_id: String = TRAP_KEYS[randi() % TRAP_KEYS.size()]
		traps.append(trap_id)

	room["traps"] = traps


# ──────────────────────────────────────────────
#  Corridor generation
# ──────────────────────────────────────────────

## Connect adjacent rooms with corridors.
## Returns an Array of { from: Vector2i, to: Vector2i } pairs.
func _connect_rooms(rooms: Array, grid_dim: int) -> Array:
	var corridors: Array = []
	var occupied: Dictionary = {}  # "x,z" -> true

	# Build occupancy map
	for room in rooms:
		var key: String = "%d,%d" % [int(room["grid_x"]), int(room["grid_z"])]
		occupied[key] = true

	# Check each room for adjacent neighbours (right and down only to avoid duplicates)
	for room in rooms:
		var gx: int = int(room["grid_x"])
		var gz: int = int(room["grid_z"])

		# Right neighbour
		if gx + 1 < grid_dim:
			var right_key: String = "%d,%d" % [gx + 1, gz]
			if occupied.has(right_key):
				corridors.append({
					"from": Vector2i(gx, gz),
					"to": Vector2i(gx + 1, gz),
				})

		# Down neighbour
		if gz + 1 < grid_dim:
			var down_key: String = "%d,%d" % [gx, gz + 1]
			if occupied.has(down_key):
				corridors.append({
					"from": Vector2i(gx, gz),
					"to": Vector2i(gx, gz + 1),
				})

	return corridors


# ──────────────────────────────────────────────
#  Loot rolling
# ──────────────────────────────────────────────

## Roll a loot table for the given floor and table key ("enemyLoot" or "bossLoot").
## Returns an Array of { item_id: String, quantity: int }.
func _roll_loot_table(floor_num: int, table_key: String) -> Array:
	var tier: Dictionary = _get_loot_tier(floor_num)
	if tier.is_empty():
		return []

	var table: Array = tier.get(table_key, [])
	var drops: Array = []

	for entry in table:
		var chance: float = float(entry.get("chance", 0.0))
		if randf() > chance:
			continue

		var item_id: String = str(entry.get("itemId", ""))
		if item_id == "":
			continue

		var min_qty: int = int(entry.get("min", 1))
		var max_qty: int = int(entry.get("max", 1))
		var quantity: int = randi_range(min_qty, max_qty)

		drops.append({
			"item_id": item_id,
			"quantity": quantity,
		})

	return drops


## Find the loot tier that contains the given floor number.
func _get_loot_tier(floor_num: int) -> Dictionary:
	for tier in DataManager.dungeon_loot_tiers:
		var min_floor: int = int(tier.get("minFloor", 0))
		var max_floor: int = int(tier.get("maxFloor", 0))
		if floor_num >= min_floor and floor_num <= max_floor:
			return tier
	# Fallback: return the last (highest) tier
	if not DataManager.dungeon_loot_tiers.is_empty():
		return DataManager.dungeon_loot_tiers[DataManager.dungeon_loot_tiers.size() - 1]
	return {}
