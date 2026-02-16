## PlayerMeshSetup — Replaces placeholder mesh children with the full
## astronaut model built by PlayerMeshBuilder.  Also drives walk/idle/attack
## animation each frame based on the parent PlayerController state.
##
## Attach this script to the PlayerMesh Node3D inside the Player scene.
extends Node3D

# ── References ──────────────────────────────────────────────────────────
var _mesh_root: Node3D = null
var _player: CharacterBody3D = null
var _weapon_nodes: Array[Node3D] = []  # Currently attached weapon meshes

# ── Animation state ─────────────────────────────────────────────────────
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _walk_intensity: float = 0.0   # Smoothly ramps 0..1

# ── Attack animation state ─────────────────────────────────────────────
var _attack_phase: float = -1.0    # -1 = not attacking, 0..1 = in progress
var _attack_style: String = "nano" # Style for current attack animation
var _vfx_spawned: bool = false     # Whether VFX has been spawned for this swing

# ── Per-style attack durations ─────────────────────────────────────────
const ATTACK_DURATIONS: Dictionary = {
	"nano": 0.35,   # Fast precision strikes
	"tesla": 0.5,   # Slower heavy swings
	"void": 0.55,   # Channeled ranged push
}


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

	# Attach initial weapon model
	_attach_weapon(initial_style)

	# Cache reference to the parent CharacterBody3D (PlayerController)
	_player = get_parent() as CharacterBody3D

	# Listen for attack events to trigger animation
	if EventBus.has_signal("player_attacked"):
		EventBus.player_attacked.connect(_on_player_attacked)

	# Listen for combat style changes to recolor mesh and swap weapon
	if EventBus.has_signal("combat_style_changed"):
		EventBus.combat_style_changed.connect(_on_style_changed)

	# Listen for equipment changes to show/hide weapon model
	if EventBus.has_signal("item_equipped"):
		EventBus.item_equipped.connect(_on_item_equipped)
	if EventBus.has_signal("item_unequipped"):
		EventBus.item_unequipped.connect(_on_item_unequipped)


func _process(delta: float) -> void:
	if _mesh_root == null or _player == null:
		return

	# Process attack animation if active (takes priority over walk/idle)
	if _attack_phase >= 0.0:
		var duration: float = ATTACK_DURATIONS.get(_attack_style, 0.4)
		_attack_phase += delta / duration
		if _attack_phase >= 1.0:
			_attack_phase = -1.0  # Attack finished
			_vfx_spawned = false
			PlayerMeshBuilder.reset_pose(_mesh_root)
		else:
			PlayerMeshBuilder.animate_attack(_mesh_root, _attack_phase, _attack_style)
			# Spawn impact VFX at strike moment
			if not _vfx_spawned and _attack_phase > 0.35:
				_vfx_spawned = true
				_spawn_attack_vfx()
			return  # Don't blend with walk/idle during attack

	var is_moving: bool = _player.get("is_moving") as bool if _player.get("is_moving") != null else false
	var current_speed: float = _player.get("current_speed") as float if _player.get("current_speed") != null else 0.0

	# Determine target intensity from movement state
	var target_intensity: float = 0.0
	if is_moving and current_speed > 0.5:
		target_intensity = clampf(current_speed / 6.0, 0.3, 1.0)

	# Smooth ramp up/down
	_walk_intensity = move_toward(_walk_intensity, target_intensity, delta * 4.0)

	var current_style: String = str(GameState.player.get("combat_style", "nano"))
	if _walk_intensity > 0.01:
		# Walk animation
		var walk_speed: float = 6.0 + current_speed * 1.5
		_walk_phase += delta * walk_speed
		if _walk_phase > TAU * 100.0:
			_walk_phase -= TAU * 100.0
		PlayerMeshBuilder.animate_walk(_mesh_root, _walk_phase, _walk_intensity, current_style)
	else:
		# Idle animation
		_idle_phase += delta
		if _idle_phase > TAU * 100.0:
			_idle_phase -= TAU * 100.0
		PlayerMeshBuilder.animate_idle(_mesh_root, _idle_phase, current_style)


## Trigger an attack animation swing
func play_attack() -> void:
	_attack_style = str(GameState.player.get("combat_style", "nano"))
	_attack_phase = 0.0
	_vfx_spawned = false


## Signal callback for player_attacked event
func _on_player_attacked() -> void:
	play_attack()


## Signal callback for combat style change — recolor mesh and swap weapon
func _on_style_changed(new_style: String) -> void:
	if _mesh_root:
		PlayerMeshBuilder.apply_style_theme(_mesh_root, new_style)
		_attach_weapon(new_style)


## Signal callback for weapon equip — refresh weapon model
func _on_item_equipped(slot: String, _item_id: String) -> void:
	if slot == "weapon":
		var style: String = str(GameState.player.get("combat_style", "nano"))
		_attach_weapon(style)


## Signal callback for weapon unequip — remove weapon model
func _on_item_unequipped(slot: String, _item_id: String) -> void:
	if slot == "weapon":
		_remove_weapons()


## Remove all currently attached weapon meshes
func _remove_weapons() -> void:
	for node in _weapon_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_weapon_nodes.clear()


## Build and attach weapon mesh(es) for the given combat style
func _attach_weapon(style: String) -> void:
	_remove_weapons()

	if _mesh_root == null:
		return

	# Only show weapon if one is actually equipped
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return

	var right_arm_lower: Node3D = _mesh_root.get_meta("right_arm_lower") as Node3D
	var left_arm_lower: Node3D = _mesh_root.get_meta("left_arm_lower") as Node3D

	match style:
		"nano":
			# Dual blades — one per hand
			if right_arm_lower:
				var r_blade: Node3D = PlayerMeshBuilder.build_weapon_mesh("nano")
				right_arm_lower.add_child(r_blade)
				_weapon_nodes.append(r_blade)
			if left_arm_lower:
				var l_blade: Node3D = PlayerMeshBuilder.build_weapon_mesh("nano")
				left_arm_lower.add_child(l_blade)
				_weapon_nodes.append(l_blade)
		"tesla":
			# Single coilgun in right hand
			if right_arm_lower:
				var coilgun: Node3D = PlayerMeshBuilder.build_weapon_mesh("tesla")
				right_arm_lower.add_child(coilgun)
				_weapon_nodes.append(coilgun)
		"void":
			# Staff in right hand
			if right_arm_lower:
				var staff: Node3D = PlayerMeshBuilder.build_weapon_mesh("void")
				right_arm_lower.add_child(staff)
				_weapon_nodes.append(staff)

	# Apply style theme so weapon colors match the armor
	for node in _weapon_nodes:
		PlayerMeshBuilder.apply_style_theme(node, style)


## Spawn a quick style-specific visual effect at the attack impact point
func _spawn_attack_vfx() -> void:
	if _player == null:
		return

	var style: String = _attack_style
	var color: Color
	var emission_color: Color
	var vfx_scale: float = 1.0

	match style:
		"nano":
			color = Color(0.0, 0.9, 0.7, 0.7)
			emission_color = Color(0.1, 1.0, 0.8)
			vfx_scale = 0.6
		"tesla":
			color = Color(1.0, 0.85, 0.1, 0.7)
			emission_color = Color(1.0, 0.95, 0.3)
			vfx_scale = 1.0
		"void":
			color = Color(0.6, 0.15, 0.95, 0.7)
			emission_color = Color(0.75, 0.3, 1.0)
			vfx_scale = 0.9
		_:
			return

	# Create a flash mesh at the player's forward position
	var flash: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.3 * vfx_scale
	mesh.height = 0.6 * vfx_scale
	mesh.radial_segments = 8
	mesh.rings = 4
	flash.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	flash.material_override = mat

	# Position in front of player at chest height
	flash.top_level = true
	_player.add_child(flash)
	var forward: Vector3 = -_player.global_transform.basis.z.normalized()
	var offset: float = 1.2
	match style:
		"tesla":
			offset = 1.0  # Closer — melee cleave
		"void":
			offset = 2.0  # Further — ranged push
	flash.global_position = _player.global_position + forward * offset + Vector3(0, 1.2, 0)

	# Animate: scale up + fade out then remove
	var tween: Tween = flash.create_tween()
	flash.scale = Vector3(0.3, 0.3, 0.3)

	match style:
		"nano":
			# Quick sharp flash
			tween.tween_property(flash, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
		"tesla":
			# Larger, lingering arc
			tween.tween_property(flash, "scale", Vector3(2.0, 0.8, 2.0), 0.12)
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		"void":
			# Expanding ring
			tween.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.2)
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)

	tween.tween_callback(flash.queue_free)
