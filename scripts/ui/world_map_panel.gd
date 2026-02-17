## WorldMapPanel — 2D overview panel showing all areas as a node graph
##
## Features:
## - Each area rendered as a colored circle with name + level range
## - Corridors drawn as connecting lines between area nodes
## - Current location highlighted with pulsing gold border
## - Gated areas show lock icon + requirement tooltip
## - Undiscovered areas grayed out with "???"
## - Opens via M key or Map button on action bar
##
## Data sources:
##   DataManager.areas (positions/names)
##   DataManager.corridors (connections)
##   DataManager.area_level_ranges (labels)
##   DataManager.area_requirements (gates)
##   GameState.visited_areas (fog of war)
##   GameState.current_area (player location)
extends PanelContainer

# ── Constants ──
const MAP_WIDTH: float = 580.0
const MAP_HEIGHT: float = 480.0
const NODE_RADIUS: float = 22.0
const PADDING: float = 40.0

# ── Internal refs ──
var _draw_area: Control = null  # Custom draw control for lines/circles
var _node_buttons: Dictionary = {}  # { area_id: Button }
var _pulse_time: float = 0.0
var _tooltip_label: Label = null

# ── Area color map by type ──
const AREA_COLORS: Dictionary = {
	"station-hub": Color(0.3, 0.8, 0.9),     # Cyan - safe
	"bio-lab": Color(0.2, 0.7, 0.6),         # Teal - crafting
	"asteroid-mines": Color(0.7, 0.55, 0.3),  # Brown - mining
	"gathering-grounds": Color(0.3, 0.75, 0.35), # Green - gathering
	"mycelium-hollows": Color(0.5, 0.7, 0.3), # Yellow-green
	"spore-marshes": Color(0.4, 0.8, 0.5),   # Green
	"hive-tunnels": Color(0.8, 0.6, 0.2),    # Amber
	"solarith-wastes": Color(0.9, 0.7, 0.2), # Gold
	"fungal-wastes": Color(0.6, 0.3, 0.7),   # Purple
	"corrupted-wastes": Color(0.8, 0.2, 0.3), # Red
	"stalker-reaches": Color(0.5, 0.3, 0.6), # Dark purple
	"void-citadel": Color(0.3, 0.2, 0.5),    # Deep purple
	"the-abyss": Color(0.15, 0.1, 0.3),      # Near-black purple
}

func _ready() -> void:
	name = "WorldMapPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(MAP_WIDTH + 20, MAP_HEIGHT + 60)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "World Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 0.9))
	vbox.add_child(title)

	# Map drawing area
	_draw_area = Control.new()
	_draw_area.custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_draw_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_draw_area)

	# Override draw on the control
	_draw_area.draw.connect(_on_draw)

	# Build area nodes as buttons on top of the draw area
	_build_area_nodes()

	# Tooltip label (follows mouse)
	_tooltip_label = Label.new()
	_tooltip_label.name = "MapTooltip"
	_tooltip_label.visible = false
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.95))
	_tooltip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_tooltip_label.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tooltip_label)

## Convert world coordinates to map pixel coordinates
func _world_to_map(world_x: float, world_z: float) -> Vector2:
	# World bounds (from areas.json layout)
	# X range: roughly -200 to 200, Z range: roughly 50 to -850
	var min_x: float = -230.0
	var max_x: float = 250.0
	var min_z: float = -900.0
	var max_z: float = 100.0

	var norm_x: float = (world_x - min_x) / (max_x - min_x)
	var norm_z: float = (world_z - min_z) / (max_z - min_z)

	return Vector2(
		PADDING + norm_x * (MAP_WIDTH - PADDING * 2),
		PADDING + (1.0 - norm_z) * (MAP_HEIGHT - PADDING * 2)
	)

## Build clickable area nodes
func _build_area_nodes() -> void:
	for area_id in DataManager.areas:
		var area_data: Dictionary = DataManager.areas[area_id]
		var center: Dictionary = area_data.get("center", {})
		var cx: float = float(center.get("x", 0))
		var cz: float = float(center.get("z", 0))
		var map_pos: Vector2 = _world_to_map(cx, cz)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		btn.position = map_pos - Vector2(NODE_RADIUS, NODE_RADIUS)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.flat = true

		# Transparent style so our custom draw shows through
		var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)

		# Tooltip with area info
		var area_name: String = str(area_data.get("name", area_id))
		var level_range: Dictionary = DataManager.area_level_ranges.get(area_id, {})
		var tooltip_text: String = area_name
		if not level_range.is_empty():
			tooltip_text += "\nLv %d-%d" % [int(level_range.get("min", 0)), int(level_range.get("max", 0))]

		# Gate info
		var reqs: Dictionary = DataManager.get_area_requirements(area_id)
		if not reqs.is_empty():
			var req_level: int = int(reqs.get("combat_level", 0))
			var req_quest: String = str(reqs.get("quest", ""))
			if req_level > 0:
				tooltip_text += "\nRequires: Combat Lv %d" % req_level
			if req_quest != "":
				var quest_data: Dictionary = DataManager.get_quest(req_quest)
				tooltip_text += "\nQuest: %s" % str(quest_data.get("name", req_quest))

		btn.tooltip_text = tooltip_text

		_draw_area.add_child(btn)
		_node_buttons[area_id] = btn

## Custom drawing for corridors and area circles
func _on_draw() -> void:
	if _draw_area == null:
		return

	# ── Draw corridors as lines ──
	for corridor_data in DataManager.corridors:
		var from_id: String = str(corridor_data.get("from", ""))
		var to_id: String = str(corridor_data.get("to", ""))

		var from_data: Dictionary = DataManager.areas.get(from_id, {})
		var to_data: Dictionary = DataManager.areas.get(to_id, {})
		if from_data.is_empty() or to_data.is_empty():
			continue

		var from_center: Dictionary = from_data.get("center", {})
		var to_center: Dictionary = to_data.get("center", {})
		var from_pos: Vector2 = _world_to_map(float(from_center.get("x", 0)), float(from_center.get("z", 0)))
		var to_pos: Vector2 = _world_to_map(float(to_center.get("x", 0)), float(to_center.get("z", 0)))

		# Check if either end is undiscovered
		var from_visited: bool = GameState.visited_areas.has(from_id) or from_id == "station-hub"
		var to_visited: bool = GameState.visited_areas.has(to_id) or to_id == "station-hub"

		var line_color: Color
		if from_visited and to_visited:
			line_color = Color(0.3, 0.45, 0.55, 0.5)
		elif from_visited or to_visited:
			line_color = Color(0.25, 0.3, 0.35, 0.3)
		else:
			line_color = Color(0.15, 0.18, 0.2, 0.2)

		_draw_area.draw_line(from_pos, to_pos, line_color, 2.0, true)

	# ── Draw area nodes ──
	for area_id in DataManager.areas:
		var area_data: Dictionary = DataManager.areas[area_id]
		var center: Dictionary = area_data.get("center", {})
		var map_pos: Vector2 = _world_to_map(float(center.get("x", 0)), float(center.get("z", 0)))

		var visited: bool = GameState.visited_areas.has(area_id) or area_id == "station-hub"
		var is_current: bool = (area_id == GameState.current_area)
		var node_color: Color = AREA_COLORS.get(area_id, Color(0.4, 0.4, 0.5))

		if not visited:
			# Undiscovered — gray
			node_color = Color(0.2, 0.22, 0.25, 0.6)

		# Draw filled circle
		_draw_area.draw_circle(map_pos, NODE_RADIUS, node_color)

		# Draw border
		var border_color: Color = node_color.lightened(0.3)
		border_color.a = 0.7
		if is_current:
			# Pulsing gold border for current area
			var pulse: float = 0.6 + 0.4 * sin(_pulse_time * 3.0)
			border_color = Color(0.95, 0.8, 0.2, pulse)
			_draw_area.draw_arc(map_pos, NODE_RADIUS + 2, 0, TAU, 32, border_color, 3.0)
		else:
			_draw_area.draw_arc(map_pos, NODE_RADIUS, 0, TAU, 32, border_color, 1.5)

		# Draw gate lock indicator
		var reqs: Dictionary = DataManager.get_area_requirements(area_id)
		if not reqs.is_empty() and visited:
			var player_level: int = GameState.get_combat_level()
			var req_level: int = int(reqs.get("combat_level", 0))
			var req_quest: String = str(reqs.get("quest", ""))
			var locked: bool = false
			if req_level > 0 and player_level < req_level:
				locked = true
			if req_quest != "" and not GameState.completed_quests.has(req_quest):
				locked = true
			if locked:
				# Red lock indicator
				_draw_area.draw_circle(map_pos + Vector2(NODE_RADIUS * 0.6, -NODE_RADIUS * 0.6), 6, Color(0.8, 0.15, 0.1, 0.9))
				# Small padlock shape
				_draw_area.draw_rect(Rect2(map_pos + Vector2(NODE_RADIUS * 0.6 - 3, -NODE_RADIUS * 0.6 - 1), Vector2(6, 5)), Color(0.95, 0.85, 0.2, 0.9))

		# Draw area label
		var area_name: String = str(area_data.get("name", area_id))
		if not visited:
			area_name = "???"

		# Use default font
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 9
		var text_size: Vector2 = font.get_string_size(area_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = map_pos + Vector2(-text_size.x / 2.0, NODE_RADIUS + 12)
		var text_color: Color = Color(0.8, 0.85, 0.9, 0.8) if visited else Color(0.4, 0.42, 0.45, 0.5)
		_draw_area.draw_string(font, text_pos, area_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		# Draw level range below name
		if visited:
			var level_range: Dictionary = DataManager.area_level_ranges.get(area_id, {})
			if not level_range.is_empty():
				var lv_text: String = "Lv %d-%d" % [int(level_range.get("min", 0)), int(level_range.get("max", 0))]
				var lv_size: Vector2 = font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
				var lv_pos: Vector2 = map_pos + Vector2(-lv_size.x / 2.0, NODE_RADIUS + 22)
				_draw_area.draw_string(font, lv_pos, lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.65, 0.4, 0.6))

func _process(delta: float) -> void:
	_pulse_time += delta
	if _draw_area and visible:
		_draw_area.queue_redraw()

## Refresh the map (called when panel becomes visible)
func refresh() -> void:
	if _draw_area:
		_draw_area.queue_redraw()
