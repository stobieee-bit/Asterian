## ProcessingStation — A clickable crafting station in the world
##
## Player clicks to approach, then the crafting panel opens for
## this station's skill type (bioforge, xenocook, circuitry, etc.)
## Hover shows a tooltip with skill info. Right-click shows context menu.
extends StaticBody3D

# ── Station data ──
var station_id: String = ""
var station_name: String = "Station"
var skill_id: String = ""
var interact_radius: float = 3.0

# ── Visuals ──
var _mesh: CSGBox3D = null
var _label: Label3D = null
var _glow_light: OmniLight3D = null

# ── Pending interaction (walk-then-act) ──
var _pending_action: Callable = Callable()
var _pending_timeout: float = 0.0

## Initialize from data
func setup(data: Dictionary) -> void:
	station_id = str(data.get("id", ""))
	station_name = str(data.get("name", "Station"))
	skill_id = str(data.get("skill", ""))
	interact_radius = float(data.get("interactRadius", 3.0))

	var pos_data: Dictionary = data.get("position", {})
	var px: float = float(pos_data.get("x", 0))
	var pz: float = float(pos_data.get("z", 0))
	global_position = Vector3(px, 0.5, pz)

	_apply_visuals()

func _ready() -> void:
	add_to_group("processing_stations")
	collision_layer = 32  # Layer 6 for processing stations
	collision_mask = 0

	# Console base — dark metal slab
	var base: CSGBox3D = CSGBox3D.new()
	base.size = Vector3(1.2, 0.5, 0.7)
	base.position.y = 0.25
	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.1, 0.13, 0.18)
	base_mat.metallic = 0.6
	base_mat.roughness = 0.25
	base.material = base_mat
	add_child(base)

	# Work surface / screen (colored by skill)
	_mesh = CSGBox3D.new()
	_mesh.size = Vector3(0.9, 0.35, 0.5)
	_mesh.position = Vector3(0, 0.68, 0)
	add_child(_mesh)

	# Small glow accent light
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 1.2, 0)
	_glow_light.light_energy = 0.5
	_glow_light.omni_range = 4.0
	_glow_light.shadow_enabled = false
	add_child(_glow_light)

	# Label overhead
	_label = Label3D.new()
	_label.position = Vector3(0, 1.5, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 14
	_label.outline_size = 4
	_label.modulate = Color(0.9, 0.7, 0.3, 0.9)
	_label.text = station_name
	add_child(_label)

	# Collision shape
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.4, 1.2, 0.9)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)

func _apply_visuals() -> void:
	if _mesh == null:
		return

	var color: Color = _get_skill_color()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	mat.emission_energy_multiplier = 0.8
	mat.metallic = 0.3
	mat.roughness = 0.3
	_mesh.material = mat

	if _glow_light:
		_glow_light.light_color = color

	if _label:
		# Show station name + skill name for discoverability
		var skill_data: Dictionary = DataManager.get_skill(skill_id)
		var skill_name: String = str(skill_data.get("name", skill_id.capitalize()))
		_label.text = "%s\n[%s]" % [station_name, skill_name]
		_label.font_size = 16
		_label.outline_size = 5

	# Add "Click to craft" hint label
	var hint_label: Label3D = Label3D.new()
	hint_label.position = Vector3(0, 1.1, 0)
	hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_label.no_depth_test = true
	hint_label.font_size = 10
	hint_label.outline_size = 3
	hint_label.modulate = Color(0.6, 0.6, 0.6, 0.7)
	hint_label.text = "Click to craft"
	add_child(hint_label)

## Show tooltip — called by InteractionController on hover
func show_hover_tooltip() -> void:
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id.capitalize()))
	var skill_desc: String = str(skill_data.get("desc", ""))

	var tooltip_data: Dictionary = {
		"title": station_name,
		"title_color": _get_skill_color(),
		"lines": [
			{"text": "Skill: %s" % skill_name, "color": Color(0.7, 0.8, 0.7)},
			{"text": skill_desc, "color": Color(0.55, 0.55, 0.55)},
			{"text": "Click to use  |  Right-click for options", "color": Color(0.45, 0.5, 0.4)},
		],
		"source": "station",
	}
	EventBus.tooltip_requested.emit(tooltip_data, Vector2.ZERO)

## Hide tooltip
func hide_hover_tooltip() -> void:
	EventBus.tooltip_hidden.emit()

## Check if the player is within interaction range
func _is_player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= interact_radius + 1.0

func _process(delta: float) -> void:
	# ── Walk-then-act: fire pending action when player arrives ──
	if _pending_action.is_valid():
		_pending_timeout -= delta
		if _pending_timeout <= 0.0:
			_pending_action = Callable()
			return
		if _is_player_in_range():
			var action: Callable = _pending_action
			_pending_action = Callable()
			action.call()

## Walk the player toward this station and fire the callback when in range.
## If already in range, fires immediately.
func _walk_then_act(action: Callable) -> void:
	if _is_player_in_range():
		action.call()
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.move_target = global_position
		player.is_moving = true
	_pending_action = action
	_pending_timeout = 8.0  # Give up after 8 seconds

## Show right-click context menu
func show_context_menu(screen_pos: Vector2) -> void:
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id.capitalize()))

	var options: Array = []
	options.append({"title": station_name, "title_color": _get_skill_color()})

	options.append({
		"label": "Use %s" % station_name,
		"icon": "U",
		"color": _get_skill_color(),
		"callback": func():
			_walk_then_act(func():
				var hud: Node = get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("open_crafting"):
					hud.open_crafting(skill_id, station_name)
			)
	})

	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = str(skill_data.get("desc", "A crafting station."))
			EventBus.chat_message.emit(
				"%s — %s (requires %s)" % [station_name, desc, skill_name], "system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Get a color based on the station's skill type
func _get_skill_color() -> Color:
	match skill_id:
		"bioforge":
			return Color(0.2, 0.6, 0.3)
		"xenocook":
			return Color(0.7, 0.4, 0.15)
		"circuitry":
			return Color(0.3, 0.4, 0.7)
		"repair":
			return Color(0.6, 0.5, 0.2)
		"psionics":
			return Color(0.5, 0.2, 0.7)
		"chronomancy":
			return Color(0.2, 0.7, 0.7)
		"astromining":
			return Color(0.6, 0.6, 0.55)
		_:
			return Color(0.4, 0.4, 0.4)
