## PlayerController — Handles click-to-move, player state, and basic physics
##
## Attached to the Player CharacterBody3D scene.
## Click on the ground to set a move target; the player walks toward it.
## Port of the JS movement system with smooth steering.
## Includes boundary clamping so the player can't walk off area edges.
extends CharacterBody3D

# ── Movement settings ──
@export var move_speed: float = 6.0        # Units per second (matches JS walkSpeed)
@export var run_speed: float = 10.0         # Sprint speed
@export var turn_speed: float = 10.0        # Radians per second for smooth turning
@export var stop_distance: float = 0.3      # How close to target before stopping
@export var gravity: float = 20.0           # Downward pull

# ── State ──
var move_target: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_running: bool = false
var current_speed: float = 0.0
var current_area: String = "station-hub"

# ── References ──
@onready var mesh: Node3D = $PlayerMesh
@onready var collision: CollisionShape3D = $CollisionShape3D

# ── Boundary clamping ──
var _area_manager: Node3D = null  # Cached ref to AreaManager

# ── Ground plane for raycasting ──
var _ground_plane: Plane = Plane(Vector3.UP, 0.0)

# ── Click-to-move ground marker ──
var _move_marker: Node3D = null
var _move_marker_ring: MeshInstance3D = null
var _move_marker_time: float = 0.0
var _move_marker_active: bool = false

func _ready() -> void:
	# CharacterBody3D floor settings — prevent sinking into ground geometry
	floor_snap_length = 0.3        # Snap to floor within this distance
	floor_max_angle = deg_to_rad(50)  # Treat slopes up to 50° as walkable floor
	wall_min_slide_angle = deg_to_rad(15)  # Avoid getting stuck sliding along walls
	floor_block_on_wall = true     # Don't slide off floors into walls
	floor_constant_speed = true    # Maintain speed on slopes

	# Sync move_target to wherever the player was placed (by main.gd)
	# Don't override global_position — main.gd handles spawn/save position
	move_target = global_position
	# Find AreaManager after a frame so the scene tree is ready
	await get_tree().process_frame
	_area_manager = get_tree().get_first_node_in_group("area_manager")
	if _area_manager == null:
		# Fallback: search by node name
		_area_manager = get_node_or_null("/root/Main/GameWorld/AreaManager")
	# Build click-to-move ground marker (pulsing cyan ring)
	_build_move_marker()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_process_movement(delta)
	move_and_slide()
	# Safety net: prevent sinking below ground plane
	if global_position.y < -0.5:
		global_position.y = 0.0
		velocity.y = 0.0
	# Safety net: after physics, clamp position back inside world bounds
	_clamp_position()
	# Update move marker
	_update_move_marker(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Click-to-move: left click sets move target
	if event.is_action_pressed("move_click"):
		_handle_move_click(event)

# ── Movement ──

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		# Cap downward velocity to prevent tunneling through thin floors
		velocity.y = maxf(velocity.y, -30.0)
	else:
		# Small downward nudge keeps floor_snap_length engaged
		velocity.y = -0.5

func _process_movement(delta: float) -> void:
	if not is_moving:
		# Decelerate smoothly
		current_speed = move_toward(current_speed, 0.0, move_speed * delta * 5.0)
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target_2d: Vector2 = Vector2(move_target.x, move_target.z)
	var pos_2d: Vector2 = Vector2(global_position.x, global_position.z)
	var dist: float = pos_2d.distance_to(target_2d)

	# Arrived at target
	if dist < stop_distance:
		is_moving = false
		current_speed = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Direction toward target
	var direction: Vector2 = (target_2d - pos_2d).normalized()
	var target_speed: float = run_speed if is_running else move_speed

	# Accelerate smoothly
	current_speed = move_toward(current_speed, target_speed, target_speed * delta * 4.0)

	# Apply velocity (xz plane only, gravity handles y)
	velocity.x = direction.x * current_speed
	velocity.z = direction.y * current_speed

	# Smooth rotation to face movement direction
	if direction.length_squared() > 0.01:
		# Godot's rotation.y=0 faces -Z, so negate to convert from +Z-forward atan2
		var target_angle: float = atan2(-direction.x, -direction.y)
		var current_angle: float = rotation.y
		rotation.y = lerp_angle(current_angle, target_angle, turn_speed * delta)

# ── Click handling ──

func _handle_move_click(event: InputEvent) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2
	if event is InputEventMouseButton:
		mouse_pos = event.position
	else:
		mouse_pos = get_viewport().get_mouse_position()

	# Raycast from camera through mouse position to ground plane
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)

	# First try physics raycast for better accuracy with terrain
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	query.collision_mask = 1  # Ground layer
	query.exclude = [get_rid()]  # Exclude self
	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		move_target = result.position
		move_target.y = 0.0  # Keep on ground plane
		move_target = _clamp_move_target(move_target)
		is_moving = true
		_show_move_marker(move_target)
	else:
		# Fallback: intersect with flat ground plane at y=0
		var hit = _ground_plane.intersects_ray(from, dir)
		if hit:
			move_target = hit
			move_target.y = 0.0
			move_target = _clamp_move_target(move_target)
			is_moving = true
			_show_move_marker(move_target)

## Clamp the click target to valid world areas so the player never walks toward the void.
func _clamp_move_target(target: Vector3) -> Vector3:
	if _area_manager == null or not _area_manager.has_method("clamp_to_world"):
		return target
	return _area_manager.clamp_to_world(target)

## Stop movement (called by external systems, e.g. portal teleport)
func stop_movement() -> void:
	is_moving = false
	current_speed = 0.0
	velocity = Vector3.ZERO

## Teleport to a position
func teleport_to(pos: Vector3) -> void:
	stop_movement()
	global_position = pos
	move_target = pos

# ── Boundary clamping ──

## After move_and_slide(), push the player back inside the world if they slipped out.
func _clamp_position() -> void:
	if _area_manager == null or not _area_manager.has_method("is_position_in_world"):
		return
	if not _area_manager.is_position_in_world(global_position):
		var clamped: Vector3 = _area_manager.clamp_to_world(global_position)
		global_position.x = clamped.x
		global_position.z = clamped.z
		# Also stop movement so the player doesn't keep pushing into the wall
		is_moving = false
		current_speed = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_target = global_position

# ── Click-to-move ground marker ──

## Build a pulsing ring marker that shows where the player is walking to
func _build_move_marker() -> void:
	_move_marker = Node3D.new()
	_move_marker.name = "MoveMarker"
	_move_marker.top_level = true  # World space, not relative to player
	_move_marker.visible = false
	add_child(_move_marker)

	_move_marker_ring = MeshInstance3D.new()
	var torus_mesh: TorusMesh = TorusMesh.new()
	torus_mesh.inner_radius = 0.3
	torus_mesh.outer_radius = 0.5
	torus_mesh.rings = 24
	torus_mesh.ring_segments = 12
	_move_marker_ring.mesh = torus_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.7, 0.9)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # Always visible even through terrain
	_move_marker_ring.material_override = mat
	_move_marker.add_child(_move_marker_ring)

## Flash the marker at the click position
func _show_move_marker(pos: Vector3) -> void:
	if _move_marker == null:
		return
	_move_marker.global_position = Vector3(pos.x, 0.05, pos.z)
	_move_marker.visible = true
	_move_marker_active = true
	_move_marker_time = 0.0
	# Reset scale for a pop-in effect
	_move_marker_ring.scale = Vector3(1.2, 1.2, 1.2)

## Animate the marker: shrink to size, pulse gently, fade when player arrives
func _update_move_marker(delta: float) -> void:
	if not _move_marker_active or _move_marker == null:
		return

	_move_marker_time += delta

	# Pop-in: scale from 1.2 down to 1.0 over 0.15s
	if _move_marker_time < 0.15:
		var t: float = _move_marker_time / 0.15
		var s: float = lerp(1.2, 1.0, t)
		_move_marker_ring.scale = Vector3(s, s, s)
	else:
		# Gentle pulse
		var pulse: float = 1.0 + 0.08 * sin(_move_marker_time * 4.0)
		_move_marker_ring.scale = Vector3(pulse, pulse, pulse)

	# Fade out when player arrives at target or after timeout (3s)
	if not is_moving or _move_marker_time > 3.0:
		# Quick fade-out via scale shrink
		_move_marker_ring.scale *= 0.85
		if _move_marker_ring.scale.x < 0.1:
			_move_marker.visible = false
			_move_marker_active = false
