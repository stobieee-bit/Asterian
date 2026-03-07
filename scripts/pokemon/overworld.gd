## Overworld — 2D top-down overworld with touch/tap movement
##
## Renders a tiled overworld with the player character, grass patches
## for wild encounters, and touch-to-move controls for mobile.
extends Node2D

# ── Constants ──
const TILE_SIZE: int = 32
const MAP_WIDTH: int = 30
const MAP_HEIGHT: int = 22
const PLAYER_SPEED: float = 120.0
const ENCOUNTER_RATE: float = 0.15  # 15% chance per grass tile step

# ── Tile types ──
enum Tile { GRASS, TALL_GRASS, PATH, WATER, TREE, BUILDING, DOOR, HEAL_PAD }

# ── Tile colors ──
const TILE_COLORS: Dictionary = {
	Tile.GRASS: Color(0.3, 0.65, 0.25),
	Tile.TALL_GRASS: Color(0.2, 0.55, 0.15),
	Tile.PATH: Color(0.72, 0.62, 0.42),
	Tile.WATER: Color(0.2, 0.4, 0.85),
	Tile.TREE: Color(0.12, 0.4, 0.1),
	Tile.BUILDING: Color(0.5, 0.45, 0.4),
	Tile.DOOR: Color(0.6, 0.3, 0.15),
	Tile.HEAL_PAD: Color(0.85, 0.3, 0.3),
}

# ── State ──
var _map: Array = []
var _player_pos: Vector2 = Vector2(15, 18)
var _player_target: Vector2 = Vector2(15, 18)
var _player_node: ColorRect = null
var _is_moving: bool = false
var _move_direction: Vector2 = Vector2.ZERO
var _camera: Camera2D = null
var _touch_start: Vector2 = Vector2.ZERO
var _in_battle: bool = false
var _tile_nodes: Array = []
var _hud: CanvasLayer = null
var _area_label: Label = null
var _party_btn: Button = null
var _encounter_areas: Dictionary = {}

# ── Signals ──
signal encounter_triggered(area_name: String)
signal heal_pad_entered
signal door_entered(target_area: String)

func _ready() -> void:
	_generate_map()
	_build_visual_map()
	_create_player()
	_create_camera()
	_create_hud()
	_setup_encounter_tables()

# ── Map generation ──

func _generate_map() -> void:
	_map.clear()
	for y in range(MAP_HEIGHT):
		var row: Array = []
		for x in range(MAP_WIDTH):
			row.append(_get_tile_for_position(x, y))
		_map.append(row)

func _get_tile_for_position(x: int, y: int) -> int:
	# Border trees
	if x == 0 or y == 0 or x == MAP_WIDTH - 1 or y == MAP_HEIGHT - 1:
		return Tile.TREE
	# Water pond
	if x >= 22 and x <= 26 and y >= 3 and y <= 6:
		return Tile.WATER
	# Town area (bottom center)
	if x >= 12 and x <= 18 and y >= 16 and y <= 20:
		return Tile.PATH
	# Buildings
	if (x == 13 or x == 17) and y == 16:
		return Tile.BUILDING
	if x == 14 and y == 16:
		return Tile.BUILDING
	if x == 13 and y == 17:
		return Tile.DOOR
	# Heal pad (Pokémon center)
	if x == 15 and y == 17:
		return Tile.HEAL_PAD
	# Main paths
	if x == 15 and y >= 5 and y <= 20:
		return Tile.PATH
	if y == 10 and x >= 3 and x <= 27:
		return Tile.PATH
	if y == 5 and x >= 8 and x <= 20:
		return Tile.PATH
	# Tall grass patches
	if x >= 3 and x <= 10 and y >= 3 and y <= 8:
		return Tile.TALL_GRASS
	if x >= 18 and x <= 25 and y >= 12 and y <= 16:
		return Tile.TALL_GRASS
	if x >= 4 and x <= 12 and y >= 12 and y <= 15:
		return Tile.TALL_GRASS
	# Trees scattered
	if (x + y * 7) % 13 == 0 and x > 1 and y > 1 and x < MAP_WIDTH - 2 and y < MAP_HEIGHT - 2:
		return Tile.TREE
	return Tile.GRASS

func _build_visual_map() -> void:
	_tile_nodes.clear()
	for y in range(MAP_HEIGHT):
		var row_nodes: Array = []
		for x in range(MAP_WIDTH):
			var tile: ColorRect = ColorRect.new()
			tile.size = Vector2(TILE_SIZE, TILE_SIZE)
			tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			tile.color = TILE_COLORS.get(_map[y][x], Color.MAGENTA)
			# Add visual variety to grass
			if _map[y][x] == Tile.GRASS:
				tile.color = tile.color.lightened(randf_range(-0.05, 0.05))
			elif _map[y][x] == Tile.TALL_GRASS:
				tile.color = tile.color.lightened(randf_range(-0.08, 0.08))
			add_child(tile)
			row_nodes.append(tile)
		_tile_nodes.append(row_nodes)

func _create_player() -> void:
	_player_node = ColorRect.new()
	_player_node.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	_player_node.position = Vector2(_player_pos.x * TILE_SIZE + 2, _player_pos.y * TILE_SIZE + 2)
	_player_node.color = Color(0.9, 0.2, 0.2)
	_player_node.z_index = 10
	add_child(_player_node)

func _create_camera() -> void:
	_camera = Camera2D.new()
	_camera.make_current()
	_camera.zoom = Vector2(2.5, 2.5)
	_player_node.add_child(_camera)

func _create_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 15
	add_child(_hud)

	# Area label
	_area_label = Label.new()
	_area_label.text = "Starter Meadow"
	_area_label.position = Vector2(10, 10)
	_area_label.add_theme_font_size_override("font_size", 18)
	_area_label.add_theme_color_override("font_color", Color.WHITE)
	_area_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_area_label.add_theme_constant_override("shadow_offset_x", 1)
	_area_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_child(_area_label)

	# Party button (top-right)
	_party_btn = Button.new()
	_party_btn.text = "MENU"
	_party_btn.position = Vector2(520, 10)
	_party_btn.custom_minimum_size = Vector2(80, 40)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.3, 0.5, 0.85)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_party_btn.add_theme_stylebox_override("normal", sb)
	_party_btn.add_theme_font_size_override("font_size", 14)
	_party_btn.add_theme_color_override("font_color", Color.WHITE)
	_party_btn.pressed.connect(_on_menu_pressed)
	_hud.add_child(_party_btn)

	# D-pad for mobile touch controls
	_create_dpad()

func _create_dpad() -> void:
	var dpad_center: Vector2 = Vector2(80, 420)
	var btn_size: Vector2 = Vector2(52, 52)
	var directions: Array = [
		{ "dir": Vector2.UP, "pos": Vector2(0, -54), "label": "^" },
		{ "dir": Vector2.DOWN, "pos": Vector2(0, 54), "label": "v" },
		{ "dir": Vector2.LEFT, "pos": Vector2(-54, 0), "label": "<" },
		{ "dir": Vector2.RIGHT, "pos": Vector2(54, 0), "label": ">" },
	]

	for d in directions:
		var btn: Button = Button.new()
		btn.text = str(d["label"])
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.position = dpad_center + Vector2(d["pos"]) - btn_size / 2.0
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.3, 0.4, 0.7)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var dir_vec: Vector2 = Vector2(d["dir"])
		btn.button_down.connect(func(): _start_move(dir_vec))
		btn.button_up.connect(func(): _stop_move())
		_hud.add_child(btn)

func _setup_encounter_tables() -> void:
	_encounter_areas = {
		"starter_meadow": {
			"creatures": [
				{ "id": "bulbascion", "level_min": 3, "level_max": 6, "weight": 30 },
				{ "id": "charmeleon", "level_min": 3, "level_max": 6, "weight": 30 },
				{ "id": "aqualung", "level_min": 3, "level_max": 6, "weight": 30 },
				{ "id": "pidgeotto", "level_min": 2, "level_max": 5, "weight": 40 },
				{ "id": "zaprat", "level_min": 3, "level_max": 5, "weight": 20 },
				{ "id": "thornvine", "level_min": 3, "level_max": 5, "weight": 25 },
				{ "id": "venomoth", "level_min": 3, "level_max": 5, "weight": 20 },
			],
		},
		"east_forest": {
			"creatures": [
				{ "id": "gastlore", "level_min": 8, "level_max": 12, "weight": 20 },
				{ "id": "darkfang", "level_min": 8, "level_max": 12, "weight": 20 },
				{ "id": "geodude", "level_min": 8, "level_max": 11, "weight": 30 },
				{ "id": "machoke", "level_min": 10, "level_max": 14, "weight": 15 },
				{ "id": "sandclaw", "level_min": 8, "level_max": 12, "weight": 25 },
			],
		},
		"west_meadow": {
			"creatures": [
				{ "id": "pidgeotto", "level_min": 5, "level_max": 9, "weight": 30 },
				{ "id": "zaprat", "level_min": 6, "level_max": 10, "weight": 25 },
				{ "id": "pixibell", "level_min": 6, "level_max": 10, "weight": 15 },
				{ "id": "psyduck", "level_min": 5, "level_max": 8, "weight": 20 },
				{ "id": "steelshell", "level_min": 8, "level_max": 12, "weight": 10 },
			],
		},
	}

# ── Movement ──

func _start_move(direction: Vector2) -> void:
	if _in_battle:
		return
	_move_direction = direction
	_is_moving = true

func _stop_move() -> void:
	_is_moving = false
	_move_direction = Vector2.ZERO

func _process(delta: float) -> void:
	if _in_battle:
		return

	if _is_moving and _move_direction != Vector2.ZERO:
		var new_pos: Vector2 = _player_pos + _move_direction
		if _can_move_to(int(new_pos.x), int(new_pos.y)):
			_player_pos = new_pos
			_player_node.position = Vector2(_player_pos.x * TILE_SIZE + 2, _player_pos.y * TILE_SIZE + 2)
			GameState.creature_steps += 1
			_check_tile_effects()
			# Small delay between grid steps
			_is_moving = false
			await get_tree().create_timer(0.12).timeout
			if _move_direction != Vector2.ZERO:
				_is_moving = true

func _unhandled_input(event: InputEvent) -> void:
	if _in_battle:
		return

	# Keyboard controls
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_start_move(Vector2.UP)
			KEY_DOWN, KEY_S:
				_start_move(Vector2.DOWN)
			KEY_LEFT, KEY_A:
				_start_move(Vector2.LEFT)
			KEY_RIGHT, KEY_D:
				_start_move(Vector2.RIGHT)

	if event is InputEventKey and not event.pressed:
		_stop_move()

	# Tap to move (simple 4-dir from swipe)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			var delta_touch: Vector2 = event.position - _touch_start
			if delta_touch.length() > 30:
				if abs(delta_touch.x) > abs(delta_touch.y):
					_start_move(Vector2.RIGHT if delta_touch.x > 0 else Vector2.LEFT)
				else:
					_start_move(Vector2.DOWN if delta_touch.y > 0 else Vector2.UP)
				await get_tree().create_timer(0.15).timeout
				_stop_move()

func _can_move_to(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= MAP_WIDTH or y >= MAP_HEIGHT:
		return false
	var tile: int = _map[y][x]
	return tile != Tile.WATER and tile != Tile.TREE and tile != Tile.BUILDING

func _check_tile_effects() -> void:
	var x: int = int(_player_pos.x)
	var y: int = int(_player_pos.y)
	if y < 0 or y >= _map.size() or x < 0 or x >= _map[0].size():
		return
	var tile: int = _map[y][x]

	match tile:
		Tile.TALL_GRASS:
			if randf() < ENCOUNTER_RATE:
				_trigger_encounter()
		Tile.HEAL_PAD:
			heal_pad_entered.emit()
		Tile.DOOR:
			door_entered.emit("interior")

func _trigger_encounter() -> void:
	var area_data: Dictionary = _encounter_areas.get(_get_current_area(), {})
	if area_data.is_empty():
		area_data = _encounter_areas.get("starter_meadow", {})
	encounter_triggered.emit(_get_current_area())

func _get_current_area() -> String:
	var x: int = int(_player_pos.x)
	if x < 12:
		return "west_meadow" if _player_pos.y < 10 else "starter_meadow"
	elif x > 20:
		return "east_forest"
	return "starter_meadow"

func get_random_encounter(area_name: String) -> Dictionary:
	var area_data: Dictionary = _encounter_areas.get(area_name, _encounter_areas.get("starter_meadow", {}))
	var creatures: Array = area_data.get("creatures", [])
	if creatures.is_empty():
		return { "id": "pidgeotto", "level": 3 }

	# Weighted random selection
	var total_weight: int = 0
	for c in creatures:
		total_weight += int(c.get("weight", 10))
	var roll: int = randi_range(1, total_weight)
	var cumulative: int = 0
	for c in creatures:
		cumulative += int(c.get("weight", 10))
		if roll <= cumulative:
			var lvl: int = randi_range(int(c["level_min"]), int(c["level_max"]))
			return { "id": str(c["id"]), "level": lvl }

	return { "id": "pidgeotto", "level": 3 }

func set_in_battle(value: bool) -> void:
	_in_battle = value
	if _hud:
		_hud.visible = not value

func _on_menu_pressed() -> void:
	EventBus.panel_opened.emit("CreaturePartyPanel")
