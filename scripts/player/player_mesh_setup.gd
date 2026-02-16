## PlayerMeshSetup — Replaces placeholder mesh children with the full
## astronaut model built by PlayerMeshBuilder.  Also drives walk/idle/attack
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

# ── Attack animation state ─────────────────────────────────────────────
var _attack_phase: float = -1.0    # -1 = not attacking, 0..1 = in progress
var _attack_duration: float = 0.4  # Seconds for one attack swing
var _attack_queued: bool = false    # Whether an attack was requested


func _ready() -> void:
	# Remove any placeholder children (old Body / Head CSG nodes)
	for child: Node in get_children():
		child.queue_free()

	# Build the astronaut mesh and add it
	_mesh_root = PlayerMeshBuilder.build_player_mesh()
	add_child(_mesh_root)
	set_meta("mesh_root", _mesh_root)

	# Apply initial combat style theme
	var initial_style: String = str(GameState.player.get("combat_style", "nano"))
	PlayerMeshBuilder.apply_style_theme(_mesh_root, initial_style)

	# Cache reference to the parent CharacterBody3D (PlayerController)
	_player = get_parent() as CharacterBody3D

	# Listen for attack events to trigger animation
	if EventBus.has_signal("player_attacked"):
		EventBus.player_attacked.connect(_on_player_attacked)

	# Listen for combat style changes to recolor mesh
	if EventBus.has_signal("combat_style_changed"):
		EventBus.combat_style_changed.connect(_on_style_changed)


func _process(delta: float) -> void:
	if _mesh_root == null or _player == null:
		return

	# Process attack animation if active (takes priority over walk/idle)
	if _attack_phase >= 0.0:
		_attack_phase += delta / _attack_duration
		if _attack_phase >= 1.0:
			_attack_phase = -1.0  # Attack finished
			PlayerMeshBuilder.reset_pose(_mesh_root)
		else:
			PlayerMeshBuilder.animate_attack(_mesh_root, _attack_phase)
			return  # Don't blend with walk/idle during attack

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


## Trigger an attack animation swing. Called by CombatController.
func play_attack() -> void:
	_attack_phase = 0.0


## Signal callback for player_attacked event
func _on_player_attacked() -> void:
	play_attack()


## Signal callback for combat style change — recolor the mesh
func _on_style_changed(new_style: String) -> void:
	if _mesh_root:
		PlayerMeshBuilder.apply_style_theme(_mesh_root, new_style)
