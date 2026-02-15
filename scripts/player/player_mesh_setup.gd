## PlayerMeshSetup — Replaces placeholder mesh children with the full
## astronaut model built by PlayerMeshBuilder.  Also drives walk/idle
## animation each frame based on the parent PlayerController state.
##
## Attach this script to the PlayerMesh Node3D inside the Player scene.
extends Node3D

# ── References ──────────────────────────────────────────────────────────
var _mesh_root: Node3D = null
var _player: CharacterBody3D = null

# ── Animation state ─────────────────────────────────────────────────────
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _walk_intensity: float = 0.0   # Smoothly ramps 0..1


func _ready() -> void:
	# Remove any placeholder children (old Body / Head CSG nodes)
	for child: Node in get_children():
		child.queue_free()

	# Build the astronaut mesh and add it
	_mesh_root = PlayerMeshBuilder.build_player_mesh()
	add_child(_mesh_root)
	set_meta("mesh_root", _mesh_root)

	# Cache reference to the parent CharacterBody3D (PlayerController)
	_player = get_parent() as CharacterBody3D


func _process(delta: float) -> void:
	if _mesh_root == null or _player == null:
		return

	var is_moving: bool = _player.get("is_moving") as bool if _player.get("is_moving") != null else false
	var current_speed: float = _player.get("current_speed") as float if _player.get("current_speed") != null else 0.0

	# Determine target intensity from movement state
	var target_intensity: float = 0.0
	if is_moving and current_speed > 0.5:
		target_intensity = clampf(current_speed / 6.0, 0.3, 1.0)

	# Smooth ramp up/down
	_walk_intensity = move_toward(_walk_intensity, target_intensity, delta * 4.0)

	if _walk_intensity > 0.01:
		# Walk animation
		var walk_speed: float = 6.0 + current_speed * 1.5
		_walk_phase += delta * walk_speed
		if _walk_phase > TAU * 100.0:
			_walk_phase -= TAU * 100.0
		PlayerMeshBuilder.animate_walk(_mesh_root, _walk_phase, _walk_intensity)
	else:
		# Idle animation
		_idle_phase += delta
		if _idle_phase > TAU * 100.0:
			_idle_phase -= TAU * 100.0
		PlayerMeshBuilder.animate_idle(_mesh_root, _idle_phase)
