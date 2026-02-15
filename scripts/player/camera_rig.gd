## CameraRig — Third-person orbit camera that follows the player
##
## Port of the JS camera system: middle-click drag to rotate,
## scroll wheel to zoom, smooth follow of player position.
## Attached to a Node3D that is a child of the Player scene.
extends Node3D

# ── Camera settings ──
@export var follow_speed: float = 8.0       # How quickly camera catches up
@export var min_distance: float = 8.0       # Closest zoom
@export var max_distance: float = 60.0      # Farthest zoom (need to see big areas)
@export var default_distance: float = 25.0  # Starting distance — wider view
@export var zoom_speed: float = 3.0         # Scroll wheel sensitivity
@export var rotate_speed: float = 0.005     # Mouse drag sensitivity
@export var min_pitch: float = -1.4         # Look almost straight down (radians)
@export var max_pitch: float = -0.15        # Don't look below horizon

# ── State ──
var _orbit_angle: float = 0.0       # Horizontal angle (radians)
var _pitch: float = -0.9            # Vertical angle — more top-down by default
var _distance: float = 25.0         # Current zoom distance
var _target_distance: float = 25.0  # Smoothed zoom target
var _is_rotating: bool = false       # Is middle mouse held?

# ── Screen shake ──
var _shake_intensity: float = 0.0   # Current shake strength (decays to 0)
var _shake_decay: float = 8.0       # How fast shake decays per second

# ── References ──
@onready var camera: Camera3D = $Camera3D
var _follow_target: Node3D = null    # The player node to follow

func _ready() -> void:
	_distance = default_distance
	_target_distance = default_distance
	# Find the player (parent should be the player scene)
	_follow_target = get_parent()
	# Make this node top-level so it doesn't rotate with the player
	top_level = true

func _process(delta: float) -> void:
	if _follow_target == null:
		return

	# Snap to player position (no lerp — prevents blurry/jittery player mesh)
	global_position = _follow_target.global_position

	# Smooth zoom
	_distance = lerp(_distance, _target_distance, 8.0 * delta)

	# Update camera position from orbit angles
	_update_camera_transform()

	# Apply screen shake offset
	if _shake_intensity > 0.01 and camera:
		var shake_offset: Vector3 = Vector3(
			randf_range(-1.0, 1.0) * _shake_intensity,
			randf_range(-1.0, 1.0) * _shake_intensity * 0.5,
			randf_range(-1.0, 1.0) * _shake_intensity
		)
		camera.position += shake_offset
		_shake_intensity = move_toward(_shake_intensity, 0.0, _shake_decay * delta)

## Trigger screen shake with given intensity (0.1 = subtle, 0.7 = heavy)
func shake(intensity: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)

func _unhandled_input(event: InputEvent) -> void:
	# Middle mouse button: start/stop rotating
	if event.is_action_pressed("camera_rotate"):
		_is_rotating = true
	elif event.is_action_released("camera_rotate"):
		_is_rotating = false

	# Mouse motion while rotating: orbit the camera
	if event is InputEventMouseMotion and _is_rotating:
		_orbit_angle -= event.relative.x * rotate_speed
		_pitch = clampf(_pitch - event.relative.y * rotate_speed, min_pitch, max_pitch)
		get_viewport().set_input_as_handled()

	# Scroll wheel: zoom in/out
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_distance = clampf(_target_distance - zoom_speed, min_distance, max_distance)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance = clampf(_target_distance + zoom_speed, min_distance, max_distance)
			get_viewport().set_input_as_handled()

func _update_camera_transform() -> void:
	if camera == null:
		return

	# Calculate camera position on a sphere around the pivot
	var offset: Vector3 = Vector3.ZERO
	offset.x = sin(_orbit_angle) * cos(_pitch) * _distance
	offset.z = cos(_orbit_angle) * cos(_pitch) * _distance
	offset.y = -sin(_pitch) * _distance  # Negative pitch = above

	camera.position = offset
	camera.look_at(global_position, Vector3.UP)  # Look at rig pivot (player position)
