## InteractionController — Handles NPC, gathering node, and processing station clicks
##
## Attached as a child node of the Player scene.
## Raycasts on click to find NPCs (layer 8), gathering nodes (layer 16),
## and processing stations (layer 32).
## Walks toward target, then interacts when in range.
extends Node

# ── Settings ──
var interact_range: float = 3.0
var gather_range: float = 2.5
var station_range: float = 3.0

# ── State ──
var _player: CharacterBody3D = null
var _target_npc: Node = null
var _target_gather: Node = null
var _target_station: Node = null
var _is_gathering: bool = false
var _gather_timer: float = 0.0
var _gather_total: float = 0.0

# ── HUD reference for progress bar ──
var _hud: Node = null

# ── Hover tracking ──
var _hover_station: Node = null
var _hover_timer: float = 0.0
const HOVER_RAYCAST_INTERVAL: float = 0.15  # Raycast for hover every 150ms

func _ready() -> void:
	_player = get_parent()

func _process(delta: float) -> void:
	# Lazy-find HUD reference
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")

	# Hover tooltip raycast (throttled)
	_hover_timer += delta
	if _hover_timer >= HOVER_RAYCAST_INTERVAL:
		_hover_timer = 0.0
		_check_hover()

	# NPC proximity check — interact when close
	if _target_npc and is_instance_valid(_target_npc):
		var dist: float = _player.global_position.distance_to(_target_npc.global_position)
		if dist <= interact_range:
			_interact_with_npc(_target_npc)
			_target_npc = null
			# Stop player movement
			if _player.has_method("stop_movement"):
				_player.stop_movement()

	# Processing station proximity check
	if _target_station and is_instance_valid(_target_station):
		var dist: float = _player.global_position.distance_to(_target_station.global_position)
		if dist <= station_range:
			_interact_with_station(_target_station)
			_target_station = null
			if _player.has_method("stop_movement"):
				_player.stop_movement()

	# Gathering proximity + channeling
	if _target_gather and is_instance_valid(_target_gather):
		var dist: float = _player.global_position.distance_to(_target_gather.global_position)
		if dist <= gather_range:
			if not _is_gathering:
				_start_gathering()
			else:
				_gather_timer += delta
				var progress: float = _gather_timer / _gather_total
				if _hud and _hud.has_method("show_gather_progress"):
					_hud.show_gather_progress(progress)
				if _gather_timer >= _gather_total:
					_complete_gathering()
		else:
			if _is_gathering:
				_cancel_gathering()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_click"):
		_try_interact(event)

	# Right-click for context menus on stations, NPCs, gathering nodes
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_try_right_click(event)

## Raycast to find NPCs, gathering nodes, or processing stations
func _try_interact(event: InputEvent) -> void:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2
	if event is InputEventMouseButton:
		mouse_pos = event.position
	else:
		mouse_pos = _player.get_viewport().get_mouse_position()

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state

	# Check for NPCs (layer 8 = collision_mask 8)
	var npc_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	npc_query.collision_mask = 8
	npc_query.exclude = [_player.get_rid()]
	var npc_result: Dictionary = space_state.intersect_ray(npc_query)
	if npc_result:
		var hit: Node = npc_result.collider
		while hit and not hit.is_in_group("npcs"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("npcs"):
			_cancel_gathering()
			_target_npc = hit
			_target_gather = null
			_target_station = null
			# Walk toward NPC
			_player.move_target = hit.global_position
			_player.is_moving = true
			_player.get_viewport().set_input_as_handled()
			return

	# Check for processing stations (layer 32 = collision_mask 32)
	var station_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	station_query.collision_mask = 32
	station_query.exclude = [_player.get_rid()]
	var station_result: Dictionary = space_state.intersect_ray(station_query)
	if station_result:
		var hit: Node = station_result.collider
		while hit and not hit.is_in_group("processing_stations"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("processing_stations"):
			_cancel_gathering()
			_target_station = hit
			_target_npc = null
			_target_gather = null
			# Walk toward station
			_player.move_target = hit.global_position
			_player.is_moving = true
			_player.get_viewport().set_input_as_handled()
			return

	# Check for gathering nodes (layer 16 = collision_mask 16)
	var gather_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	gather_query.collision_mask = 16
	gather_query.exclude = [_player.get_rid()]
	var gather_result: Dictionary = space_state.intersect_ray(gather_query)
	if gather_result:
		var hit: Node = gather_result.collider
		while hit and not hit.is_in_group("gathering_nodes"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("gathering_nodes"):
			_cancel_gathering()
			_target_gather = hit
			_target_npc = null
			_target_station = null
			# Walk toward node
			_player.move_target = hit.global_position
			_player.is_moving = true
			_player.get_viewport().set_input_as_handled()
			return

## Interact with an NPC (open dialogue)
func _interact_with_npc(npc: Node) -> void:
	# Find the HUD and open dialogue
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_dialogue"):
		hud.open_dialogue(npc)
	else:
		# Fallback: emit chat
		EventBus.chat_message.emit("%s: %s" % [npc.npc_name, "Hello, traveler!"], "system")

## Interact with a processing station (open crafting panel)
func _interact_with_station(station: Node) -> void:
	if _hud and _hud.has_method("open_crafting"):
		_hud.open_crafting(station.skill_id, station.station_name)
	else:
		EventBus.chat_message.emit("Opened %s" % station.station_name, "system")

## Start gathering from a node
func _start_gathering() -> void:
	if _target_gather == null:
		return

	# Check if node can be gathered
	if not _target_gather.has_method("can_gather") or not _target_gather.can_gather():
		var skill_data: Dictionary = DataManager.get_skill(_target_gather.skill_id)
		var skill_name: String = str(skill_data.get("name", _target_gather.skill_id))
		EventBus.chat_message.emit("Need %s level %d to gather this." % [skill_name, _target_gather.skill_level], "system")
		_target_gather = null
		return

	_is_gathering = true
	_gather_timer = 0.0
	_gather_total = _target_gather.get_gather_time()
	EventBus.gathering_started.emit(_target_gather.skill_id, _target_gather.node_id)

	# Stop player movement while gathering
	if _player.has_method("stop_movement"):
		_player.stop_movement()

	# Show progress bar via HUD
	if _hud and _hud.has_method("show_gather_progress"):
		_hud.show_gather_progress(0.0)

	EventBus.chat_message.emit("Gathering...", "system")

## Complete gathering
func _complete_gathering() -> void:
	if _target_gather and _target_gather.has_method("complete_gather"):
		_target_gather.complete_gather()

	_is_gathering = false
	_gather_timer = 0.0
	if _hud and _hud.has_method("hide_gather_progress"):
		_hud.hide_gather_progress()

	# Auto-continue gathering if node not depleted
	if _target_gather and is_instance_valid(_target_gather) and _target_gather.has_method("can_gather"):
		if _target_gather.can_gather() and GameState.has_inventory_space():
			_start_gathering()
			return

	_target_gather = null

## Cancel gathering
func _cancel_gathering() -> void:
	_is_gathering = false
	_gather_timer = 0.0
	if _hud and _hud.has_method("hide_gather_progress"):
		_hud.hide_gather_progress()

## Check what the mouse is hovering over (for tooltips)
func _check_hover() -> void:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2 = _player.get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state

	# Check processing stations (layer 32)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = 32
	query.exclude = [_player.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		var hit: Node = result.collider
		while hit and not hit.is_in_group("processing_stations"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("processing_stations"):
			if _hover_station != hit:
				# New hover target
				if _hover_station and is_instance_valid(_hover_station) and _hover_station.has_method("hide_hover_tooltip"):
					_hover_station.hide_hover_tooltip()
				_hover_station = hit
				if hit.has_method("show_hover_tooltip"):
					hit.show_hover_tooltip()
			return

	# Not hovering over a station — clear tooltip if we were
	if _hover_station and is_instance_valid(_hover_station):
		if _hover_station.has_method("hide_hover_tooltip"):
			_hover_station.hide_hover_tooltip()
		_hover_station = null

## Right-click handler — show context menus for stations, NPCs, etc.
func _try_right_click(event: InputEvent) -> void:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2 = event.position if event is InputEventMouseButton else _player.get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var screen_pos: Vector2 = mouse_pos

	# Check processing stations (layer 32)
	var station_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	station_query.collision_mask = 32
	station_query.exclude = [_player.get_rid()]
	var station_result: Dictionary = space_state.intersect_ray(station_query)
	if station_result:
		var hit: Node = station_result.collider
		while hit and not hit.is_in_group("processing_stations"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("processing_stations") and hit.has_method("show_context_menu"):
			hit.show_context_menu(screen_pos)
			_player.get_viewport().set_input_as_handled()
			return

	# Check gathering nodes (layer 16)
	var gather_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	gather_query.collision_mask = 16
	gather_query.exclude = [_player.get_rid()]
	var gather_result: Dictionary = space_state.intersect_ray(gather_query)
	if gather_result:
		var hit: Node = gather_result.collider
		while hit and not hit.is_in_group("gathering_nodes"):
			hit = hit.get_parent()
		if hit and hit.is_in_group("gathering_nodes") and hit.has_method("show_context_menu"):
			hit.show_context_menu(screen_pos)
			_player.get_viewport().set_input_as_handled()
			return
