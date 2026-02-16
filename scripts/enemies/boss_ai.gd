## BossAI -- Phase-based boss encounter controller
##
## Attach as a child Node of an enemy CharacterBody3D (enemy_controller.gd).
## Manages phase transitions, telegraphed special attacks, enrage timers,
## minion spawning, and telegraph visual indicators.
##
## Automatically self-destructs (queue_free) if the parent is not a boss.
extends Node

# ────────────────────────────────────────────────────────────────────
# Constants
# ────────────────────────────────────────────────────────────────────

## Maximum boss-spawned adds alive at any one time.
const MAX_BOSS_ADDS: int = 12

## Radius around the boss where adds spawn in a circle.
const ADD_SPAWN_RADIUS: float = 5.0

## Height offset for telegraph meshes (slightly above ground).
const TELEGRAPH_Y: float = 0.15

## Recovery pause in seconds after a telegraph resolves.
const POST_TELEGRAPH_PAUSE: float = 1.5

## Enemy scene used to spawn minion adds.
const ENEMY_SCENE_PATH: String = "res://scenes/entities/enemy.tscn"

## Per-boss mechanics data: phases, enrage, and telegraph definitions.
const BOSS_MECHANICS: Dictionary = {
	"hive_queen": {
		"phases": [
			{ "hp_pct": 1.0, "attacks": ["basic", "acid_spray", "venom_charge"], "spawn_adds": false },
			{ "hp_pct": 0.5, "attacks": ["basic", "acid_spray", "venom_charge", "swarm_summon"], "spawn_adds": true, "add_type": "chithari", "add_count": 3 },
		],
		"enrage": { "start_time": 60, "dmg_per_sec": 0.005 },
		"telegraphs": {
			"acid_spray": { "type": "cone", "angle": 60, "range": 10, "delay": 2.0, "color": 0x44ff00, "dmg_pct": 0.3, "cooldown": 8 },
			"venom_charge": { "type": "line", "width": 4, "range": 12, "delay": 1.5, "color": 0x88ff00, "dmg_pct": 0.4, "cooldown": 12 },
			"swarm_summon": { "type": "circle", "radius": 8, "delay": 3.0, "color": 0xaaaa00, "dmg_pct": 0.15, "cooldown": 15, "spawn_adds": true, "add_type": "chithari", "add_count": 2 },
		},
	},
	"void_sentinel": {
		"phases": [
			{ "hp_pct": 1.0, "attacks": ["basic", "void_beam"] },
			{ "hp_pct": 0.6, "attacks": ["basic", "void_beam", "collapsing_field"] },
			{ "hp_pct": 0.3, "attacks": ["basic", "void_beam", "collapsing_field"] },
		],
		"enrage": { "start_time": 90, "dmg_per_sec": 0.008 },
		"telegraphs": {
			"void_beam": { "type": "line", "width": 3, "range": 15, "delay": 2.5, "color": 0x8800ff, "dmg_pct": 0.4, "cooldown": 10 },
			"collapsing_field": { "type": "circle", "radius": 6, "delay": 3.0, "color": 0x440088, "dmg_pct": 0.5, "cooldown": 15 },
		},
	},
	"crystal_colossus": {
		"phases": [
			{ "hp_pct": 1.0, "attacks": ["basic", "crystal_barrage"] },
			{ "hp_pct": 0.5, "attacks": ["basic", "crystal_barrage", "shatter_nova"] },
		],
		"enrage": { "start_time": 75, "dmg_per_sec": 0.006 },
		"telegraphs": {
			"crystal_barrage": { "type": "circle", "radius": 3, "delay": 2.0, "color": 0x00ffff, "dmg_pct": 0.25, "cooldown": 8 },
			"shatter_nova": { "type": "circle", "radius": 12, "delay": 3.5, "color": 0xff4444, "dmg_pct": 0.6, "cooldown": 20 },
		},
	},
	"the_formless_one": {
		"phases": [
			{ "hp_pct": 1.0, "attacks": ["basic", "shadow_tendrils"] },
			{ "hp_pct": 0.4, "attacks": ["basic", "shadow_tendrils", "void_eruption"], "spawn_adds": true, "add_type": "void_lurker", "add_count": 2 },
		],
		"enrage": { "start_time": 120, "dmg_per_sec": 0.01 },
		"telegraphs": {
			"shadow_tendrils": { "type": "line", "width": 2, "range": 12, "delay": 2.0, "color": 0x330033, "dmg_pct": 0.35, "cooldown": 8 },
			"void_eruption": { "type": "circle", "radius": 15, "delay": 4.0, "color": 0x110011, "dmg_pct": 0.7, "cooldown": 25 },
		},
	},
	"the_primordial": {
		"phases": [
			{ "hp_pct": 1.0, "attacks": ["basic", "primordial_slam"] },
			{ "hp_pct": 0.7, "attacks": ["basic", "primordial_slam", "elemental_wave"], "spawn_adds": true, "add_type": "cosmic_sentinel", "add_count": 2 },
			{ "hp_pct": 0.3, "attacks": ["basic", "primordial_slam", "elemental_wave", "extinction_beam"], "spawn_adds": true, "add_type": "cosmic_sentinel", "add_count": 3 },
		],
		"enrage": { "start_time": 90, "dmg_per_sec": 0.012 },
		"telegraphs": {
			"primordial_slam": { "type": "circle", "radius": 8, "delay": 2.0, "color": 0xff8800, "dmg_pct": 0.4, "cooldown": 10 },
			"elemental_wave": { "type": "cone", "angle": 90, "range": 15, "delay": 2.5, "color": 0x00ff88, "dmg_pct": 0.45, "cooldown": 12 },
			"extinction_beam": { "type": "line", "width": 5, "range": 25, "delay": 3.0, "color": 0xff0000, "dmg_pct": 0.8, "cooldown": 20 },
		},
	},
}

# ────────────────────────────────────────────────────────────────────
# Parent reference
# ────────────────────────────────────────────────────────────────────

## The parent enemy CharacterBody3D (enemy_controller.gd).
var _parent: CharacterBody3D = null

# ────────────────────────────────────────────────────────────────────
# Mechanics state
# ────────────────────────────────────────────────────────────────────

## Mechanics dictionary for this specific boss (pulled from BOSS_MECHANICS).
var _mechanics: Dictionary = {}

## Index of the current phase (0 = first / highest HP phase).
var _current_phase_index: int = 0

## Seconds elapsed since the boss entered combat.
var _combat_timer: float = 0.0

## Whether the boss is currently in active combat.
var _in_combat: bool = false

## Current enrage damage multiplier (starts at 1.0).
var _enrage_multiplier: float = 1.0

## Whether the enrage chat message has been sent.
var _enrage_announced: bool = false

## Original mesh color cached so we can tint back from enrage.
var _original_mesh_color: Color = Color.WHITE

# ────────────────────────────────────────────────────────────────────
# Telegraph / channeling state
# ────────────────────────────────────────────────────────────────────

## True while the boss is channeling a telegraph attack. Freezes movement.
var channeling: bool = false

## The currently active telegraph CSG mesh node (or null).
var _telegraph_node: Node3D = null

## Remaining delay before the current telegraph resolves.
var _telegraph_timer: float = 0.0

## Telegraph data dictionary for the current attack.
var _telegraph_data: Dictionary = {}

## Direction the telegraph was aimed when it started.
var _telegraph_direction: Vector3 = Vector3.FORWARD

## World position the telegraph is targeted at (for circle type).
var _telegraph_target_pos: Vector3 = Vector3.ZERO

## Post-resolve recovery timer.
var _recovery_timer: float = 0.0

## Total elapsed time for the pulsing sine wave on telegraph opacity.
var _pulse_time: float = 0.0

# ────────────────────────────────────────────────────────────────────
# Cooldowns
# ────────────────────────────────────────────────────────────────────

## Map of attack_name -> remaining cooldown seconds.
var _cooldowns: Dictionary = {}

## Timer between special attack selection attempts.
var _attack_select_timer: float = 0.0

## Interval between attack selection attempts.
const ATTACK_SELECT_INTERVAL: float = 1.5

# ────────────────────────────────────────────────────────────────────
# Minion tracking
# ────────────────────────────────────────────────────────────────────

## References to boss-spawned add enemies (WeakRef to avoid dangling).
var _spawned_adds: Array = []

## Preloaded enemy scene for spawning adds.
var _enemy_scene: PackedScene = null

# ────────────────────────────────────────────────────────────────────
# Player reference (cached)
# ────────────────────────────────────────────────────────────────────

var _player: CharacterBody3D = null


# ════════════════════════════════════════════════════════════════════
#  Lifecycle
# ════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_parent = get_parent() as CharacterBody3D
	if _parent == null or not _parent.get("is_boss"):
		push_warning("BossAI: Parent is not a boss enemy. Removing self.")
		queue_free()
		return

	# Add parent to boss group for easy lookups.
	_parent.add_to_group("boss_enemies")

	# Look up mechanics by enemy_id.
	var boss_id: String = _parent.enemy_id
	if BOSS_MECHANICS.has(boss_id):
		_mechanics = BOSS_MECHANICS[boss_id]
	else:
		push_warning("BossAI: No mechanics data for boss '%s'. Removing self." % boss_id)
		queue_free()
		return

	# Cache original mesh color for enrage tinting.
	_original_mesh_color = _parent.mesh_color

	# Preload the enemy scene for minion spawning.
	_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene

	# Initialize phase.
	_current_phase_index = 0

	# Initialize all telegraph cooldowns to 0 (ready).
	var telegraphs: Dictionary = _mechanics.get("telegraphs", {})
	for atk_name: String in telegraphs:
		_cooldowns[atk_name] = 0.0


func _process(delta: float) -> void:
	if _parent == null or not is_instance_valid(_parent):
		queue_free()
		return

	# Cache player reference.
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Determine if the boss is in combat based on parent state.
	var parent_state: int = _parent.state
	var combat_states: Array[int] = [
		_parent.State.CHASE,
		_parent.State.ATTACKING,
	]
	var was_in_combat: bool = _in_combat
	_in_combat = parent_state in combat_states

	# Combat just started.
	if _in_combat and not was_in_combat:
		_on_combat_start()

	# Combat just ended (boss returned, died, etc.).
	if not _in_combat and was_in_combat:
		_on_combat_end()

	# --- Active combat logic ---
	if _in_combat:
		_combat_timer += delta
		_tick_enrage(delta)
		_tick_phase_check()
		_tick_cooldowns(delta)

		# If currently channeling a telegraph, tick that.
		if channeling:
			_tick_telegraph(delta)
		elif _recovery_timer > 0.0:
			_recovery_timer -= delta
		else:
			_tick_attack_selection(delta)


# ════════════════════════════════════════════════════════════════════
#  Combat start / end
# ════════════════════════════════════════════════════════════════════

func _on_combat_start() -> void:
	_combat_timer = 0.0
	_enrage_multiplier = 1.0
	_enrage_announced = false
	_current_phase_index = 0
	_attack_select_timer = 0.0
	_recovery_timer = 0.0
	channeling = false

	# Reset cooldowns.
	for key: String in _cooldowns:
		_cooldowns[key] = 0.0


func _on_combat_end() -> void:
	channeling = false
	_cleanup_telegraph()
	_combat_timer = 0.0
	_enrage_multiplier = 1.0
	_enrage_announced = false
	_current_phase_index = 0
	_recovery_timer = 0.0

	# Reset enrage tint.
	_apply_enrage_tint(0.0)


# ════════════════════════════════════════════════════════════════════
#  Phase system
# ════════════════════════════════════════════════════════════════════

## Check HP percentage and transition to the lowest-threshold matching phase.
func _tick_phase_check() -> void:
	var phases: Array = _mechanics.get("phases", [])
	if phases.is_empty():
		return

	var hp_pct: float = float(_parent.hp) / float(maxi(1, _parent.max_hp))

	# Find the deepest phase whose threshold we have crossed.
	var target_index: int = 0
	for i: int in range(phases.size()):
		var phase: Dictionary = phases[i]
		var threshold: float = float(phase.get("hp_pct", 1.0))
		if hp_pct <= threshold:
			target_index = i

	# If we moved to a deeper phase, trigger the transition.
	if target_index > _current_phase_index:
		_transition_to_phase(target_index)


## Transition to a new phase: announce, spawn adds if applicable.
func _transition_to_phase(new_index: int) -> void:
	var phases: Array = _mechanics.get("phases", [])
	if new_index < 0 or new_index >= phases.size():
		return

	_current_phase_index = new_index
	var phase: Dictionary = phases[new_index]

	# Announce phase transition.
	var boss_name: String = _parent.enemy_name
	var phase_number: int = new_index + 1
	var total_phases: int = phases.size()
	EventBus.chat_message.emit(
		"%s enters phase %d/%d!" % [boss_name, phase_number, total_phases],
		"combat"
	)
	EventBus.float_text_requested.emit(
		"Phase %d" % phase_number,
		_parent.global_position + Vector3.UP * 2.5,
		Color(1.0, 0.8, 0.2)
	)

	# Spawn adds if the phase calls for it.
	var should_spawn: bool = bool(phase.get("spawn_adds", false))
	if should_spawn:
		var add_type: String = str(phase.get("add_type", ""))
		var add_count: int = int(phase.get("add_count", 0))
		if add_type != "" and add_count > 0:
			_spawn_adds(add_type, add_count)


## Get the available attacks list for the current phase.
func _get_current_attacks() -> Array:
	var phases: Array = _mechanics.get("phases", [])
	if _current_phase_index < 0 or _current_phase_index >= phases.size():
		return ["basic"]
	var phase: Dictionary = phases[_current_phase_index]
	var attacks: Array = phase.get("attacks", ["basic"])
	return attacks


# ════════════════════════════════════════════════════════════════════
#  Enrage system
# ════════════════════════════════════════════════════════════════════

func _tick_enrage(delta: float) -> void:
	var enrage_data: Dictionary = _mechanics.get("enrage", {})
	if enrage_data.is_empty():
		return

	var start_time: float = float(enrage_data.get("start_time", 120))
	var dmg_per_sec: float = float(enrage_data.get("dmg_per_sec", 0.005))

	if _combat_timer < start_time:
		_enrage_multiplier = 1.0
		return

	# Enrage is active.
	var elapsed_enrage: float = _combat_timer - start_time
	_enrage_multiplier = 1.0 + elapsed_enrage * dmg_per_sec

	# Announce once.
	if not _enrage_announced:
		_enrage_announced = true
		EventBus.chat_message.emit(
			"%s becomes enraged!" % _parent.enemy_name,
			"combat"
		)
		EventBus.float_text_requested.emit(
			"ENRAGED!",
			_parent.global_position + Vector3.UP * 3.0,
			Color(1.0, 0.1, 0.1)
		)

	# Tint the boss redder as enrage grows (cap visual at 3x).
	var tint_factor: float = clampf((elapsed_enrage * dmg_per_sec) / 2.0, 0.0, 1.0)
	_apply_enrage_tint(tint_factor)


## Lerp the boss mesh color toward red based on enrage factor (0..1).
func _apply_enrage_tint(factor: float) -> void:
	if _parent == null or not is_instance_valid(_parent):
		return

	var target_color: Color = _original_mesh_color.lerp(Color(1.0, 0.1, 0.1), factor)
	var mesh_root: Node3D = _parent.get_node_or_null("EnemyMesh")
	if mesh_root == null:
		return

	for child: Node in mesh_root.get_children():
		if child is CSGPrimitive3D:
			var mat: Material = (child as CSGPrimitive3D).material
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = target_color
				(mat as StandardMaterial3D).emission = target_color * 0.4


# ════════════════════════════════════════════════════════════════════
#  Cooldowns
# ════════════════════════════════════════════════════════════════════

func _tick_cooldowns(delta: float) -> void:
	for key: String in _cooldowns:
		var remaining: float = float(_cooldowns[key])
		if remaining > 0.0:
			_cooldowns[key] = maxf(0.0, remaining - delta)


# ════════════════════════════════════════════════════════════════════
#  Attack selection
# ════════════════════════════════════════════════════════════════════

func _tick_attack_selection(delta: float) -> void:
	_attack_select_timer -= delta
	if _attack_select_timer > 0.0:
		return
	_attack_select_timer = ATTACK_SELECT_INTERVAL

	if _player == null or not is_instance_valid(_player):
		return

	var available: Array = _get_current_attacks()
	var telegraphs: Dictionary = _mechanics.get("telegraphs", {})

	# Gather special attacks that are off cooldown.
	var specials: Array[String] = []
	for atk_name: Variant in available:
		var name_str: String = str(atk_name)
		if name_str == "basic":
			continue
		if not telegraphs.has(name_str):
			continue
		var cd_remaining: float = float(_cooldowns.get(name_str, 0.0))
		if cd_remaining <= 0.0:
			specials.append(name_str)

	# If no specials are ready, let the parent handle basic attacks.
	if specials.is_empty():
		return

	# Pick a random available special attack.
	var chosen: String = specials[randi() % specials.size()]
	_begin_telegraph(chosen)


# ════════════════════════════════════════════════════════════════════
#  Telegraph system
# ════════════════════════════════════════════════════════════════════

## Start channeling a telegraphed attack.
func _begin_telegraph(attack_name: String) -> void:
	var telegraphs: Dictionary = _mechanics.get("telegraphs", {})
	if not telegraphs.has(attack_name):
		return

	_telegraph_data = telegraphs[attack_name]
	_telegraph_timer = float(_telegraph_data.get("delay", 2.0))
	_pulse_time = 0.0
	channeling = true

	# Freeze parent movement.
	_parent.velocity = Vector3.ZERO

	# Calculate direction toward player.
	if _player != null and is_instance_valid(_player):
		_telegraph_direction = (_player.global_position - _parent.global_position).normalized()
		_telegraph_target_pos = _player.global_position
	else:
		_telegraph_direction = -_parent.basis.z
		_telegraph_target_pos = _parent.global_position + _telegraph_direction * 5.0

	# Ensure direction is horizontal.
	_telegraph_direction.y = 0.0
	if _telegraph_direction.length() < 0.01:
		_telegraph_direction = Vector3.FORWARD
	else:
		_telegraph_direction = _telegraph_direction.normalized()

	# Build the visual indicator.
	var telegraph_type: String = str(_telegraph_data.get("type", "circle"))
	match telegraph_type:
		"circle":
			_create_circle_telegraph()
		"line":
			_create_line_telegraph()
		"cone":
			_create_cone_telegraph()


## Tick the active telegraph (pulsing, countdown, resolve).
func _tick_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	_pulse_time += delta

	# Update telegraph visual pulsing.
	if _telegraph_node != null and is_instance_valid(_telegraph_node):
		_update_telegraph_pulse()

	# Keep parent frozen.
	_parent.velocity = Vector3.ZERO

	# Resolve when timer expires.
	if _telegraph_timer <= 0.0:
		_resolve_telegraph()


## Pulse the telegraph mesh opacity using a sine wave.
func _update_telegraph_pulse() -> void:
	if _telegraph_node == null or not is_instance_valid(_telegraph_node):
		return

	var alpha: float = 0.15 + sin(_pulse_time * 4.0) * 0.15

	# Find the CSG child and update its material alpha.
	for child: Node in _telegraph_node.get_children():
		if child is CSGPrimitive3D:
			var mat: Material = (child as CSGPrimitive3D).material
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color.a = alpha


## Resolve the telegraph: check hit, apply damage, spawn adds, cleanup.
func _resolve_telegraph() -> void:
	var telegraph_type: String = str(_telegraph_data.get("type", "circle"))
	var dmg_pct: float = float(_telegraph_data.get("dmg_pct", 0.3))
	var cooldown: float = float(_telegraph_data.get("cooldown", 10.0))

	# Find which attack name this was to put it on cooldown.
	var telegraphs: Dictionary = _mechanics.get("telegraphs", {})
	for atk_name: String in telegraphs:
		if telegraphs[atk_name] == _telegraph_data:
			_cooldowns[atk_name] = cooldown
			break

	# Check if the player is inside the telegraph zone.
	var player_hit: bool = false
	if _player != null and is_instance_valid(_player):
		player_hit = _is_player_in_telegraph(telegraph_type)

	# Apply damage if hit.
	if player_hit:
		var raw_damage: int = int(float(_parent.damage) * dmg_pct * _enrage_multiplier)
		var final_damage: int = maxi(1, raw_damage)
		EventBus.hit_landed.emit(_player, final_damage, false, _parent)

	# Show impact float text at telegraph position.
	var impact_pos: Vector3 = _telegraph_target_pos + Vector3.UP * 1.0
	if _telegraph_node != null and is_instance_valid(_telegraph_node):
		impact_pos = _telegraph_node.global_position + Vector3.UP * 1.0

	var impact_color: Color = Color(1.0, 0.5, 0.0) if player_hit else Color(0.6, 0.6, 0.6)
	var impact_text: String = "HIT!" if player_hit else "Dodged!"
	EventBus.float_text_requested.emit(impact_text, impact_pos, impact_color)

	# Spawn adds if this telegraph has add spawning.
	var should_spawn_adds: bool = bool(_telegraph_data.get("spawn_adds", false))
	if should_spawn_adds:
		var add_type: String = str(_telegraph_data.get("add_type", ""))
		var add_count: int = int(_telegraph_data.get("add_count", 0))
		if add_type != "" and add_count > 0:
			_spawn_adds(add_type, add_count)

	# Cleanup visual and enter recovery.
	_cleanup_telegraph()
	channeling = false
	_recovery_timer = POST_TELEGRAPH_PAUSE


## Check if the player is inside the resolved telegraph zone.
func _is_player_in_telegraph(telegraph_type: String) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false

	var player_pos: Vector3 = _player.global_position
	var boss_pos: Vector3 = _parent.global_position

	match telegraph_type:
		"circle":
			var radius: float = float(_telegraph_data.get("radius", 5.0))
			var center: Vector3 = _telegraph_target_pos
			var dist_sq: float = (
				(player_pos.x - center.x) * (player_pos.x - center.x) +
				(player_pos.z - center.z) * (player_pos.z - center.z)
			)
			return dist_sq <= radius * radius

		"line":
			var line_width: float = float(_telegraph_data.get("width", 3.0))
			var line_range: float = float(_telegraph_data.get("range", 12.0))
			# Project player position onto the line axis.
			var to_player: Vector3 = player_pos - boss_pos
			to_player.y = 0.0
			var forward: float = to_player.dot(_telegraph_direction)
			if forward < 0.0 or forward > line_range:
				return false
			# Perpendicular distance.
			var right: Vector3 = Vector3(-_telegraph_direction.z, 0.0, _telegraph_direction.x)
			var lateral: float = absf(to_player.dot(right))
			return lateral <= line_width * 0.5

		"cone":
			var cone_angle: float = float(_telegraph_data.get("angle", 60.0))
			var cone_range: float = float(_telegraph_data.get("range", 10.0))
			var to_player: Vector3 = player_pos - boss_pos
			to_player.y = 0.0
			var dist: float = to_player.length()
			if dist > cone_range or dist < 0.01:
				return false
			var angle_to_player: float = rad_to_deg(to_player.normalized().angle_to(_telegraph_direction))
			return angle_to_player <= cone_angle * 0.5

	return false


## Remove the telegraph visual node.
func _cleanup_telegraph() -> void:
	if _telegraph_node != null and is_instance_valid(_telegraph_node):
		_telegraph_node.queue_free()
	_telegraph_node = null
	_telegraph_data = {}


# ════════════════════════════════════════════════════════════════════
#  Telegraph visual creation
# ════════════════════════════════════════════════════════════════════

## Convert a hex integer color (e.g., 0x44ff00) to a Godot Color with alpha.
func _hex_to_color(hex: int, alpha: float) -> Color:
	var r: float = float((hex >> 16) & 0xFF) / 255.0
	var g: float = float((hex >> 8) & 0xFF) / 255.0
	var b: float = float(hex & 0xFF) / 255.0
	return Color(r, g, b, alpha)


## Create a semi-transparent material for telegraph indicators.
func _make_telegraph_material(hex_color: int) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _hex_to_color(hex_color, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


## Create a circle telegraph (flat disc) at the target position.
func _create_circle_telegraph() -> void:
	var radius: float = float(_telegraph_data.get("radius", 5.0))
	var hex_color: int = int(_telegraph_data.get("color", 0xffffff))

	var pivot: Node3D = Node3D.new()
	pivot.name = "TelegraphCircle"

	var disc: CSGCylinder3D = CSGCylinder3D.new()
	disc.radius = radius
	disc.height = 0.05
	disc.sides = 32
	disc.material = _make_telegraph_material(hex_color)
	pivot.add_child(disc)

	# Position at target (player's position when telegraph started), just above ground.
	pivot.global_position = Vector3(
		_telegraph_target_pos.x,
		TELEGRAPH_Y,
		_telegraph_target_pos.z
	)

	# Add to the scene tree (not as child of boss, so it stays in world space).
	_parent.get_parent().add_child(pivot)
	_telegraph_node = pivot


## Create a line telegraph (flat rectangle) from boss toward player direction.
func _create_line_telegraph() -> void:
	var line_width: float = float(_telegraph_data.get("width", 3.0))
	var line_range: float = float(_telegraph_data.get("range", 12.0))
	var hex_color: int = int(_telegraph_data.get("color", 0xffffff))

	var pivot: Node3D = Node3D.new()
	pivot.name = "TelegraphLine"

	var box: CSGBox3D = CSGBox3D.new()
	box.size = Vector3(line_width, 0.05, line_range)
	box.material = _make_telegraph_material(hex_color)
	# Offset the box so it starts at the boss and extends forward.
	box.position = Vector3(0.0, 0.0, line_range * 0.5)
	pivot.add_child(box)

	# Position at boss, facing toward the player.
	pivot.global_position = Vector3(
		_parent.global_position.x,
		TELEGRAPH_Y,
		_parent.global_position.z
	)

	# Rotate to face the telegraph direction.
	var look_target: Vector3 = pivot.global_position + _telegraph_direction
	pivot.look_at(look_target, Vector3.UP)

	_parent.get_parent().add_child(pivot)
	_telegraph_node = pivot


## Create a cone telegraph using a scaled cylinder (wide base, zero top).
func _create_cone_telegraph() -> void:
	var cone_angle: float = float(_telegraph_data.get("angle", 60.0))
	var cone_range: float = float(_telegraph_data.get("range", 10.0))
	var hex_color: int = int(_telegraph_data.get("color", 0xffffff))

	# Approximate the cone's spread at max range.
	var half_angle_rad: float = deg_to_rad(cone_angle * 0.5)
	var end_radius: float = tan(half_angle_rad) * cone_range

	var pivot: Node3D = Node3D.new()
	pivot.name = "TelegraphCone"

	# Use a cylinder laid on its side: height = range, top_radius = 0, bottom_radius = spread.
	var cone: CSGCylinder3D = CSGCylinder3D.new()
	cone.radius = end_radius
	cone.height = cone_range
	cone.sides = 24
	cone.cone = true
	cone.material = _make_telegraph_material(hex_color)

	# The cylinder's default axis is Y. We need to rotate it to lie along Z
	# with the point (top) at the boss and the wide base at max range.
	# Rotate -90 degrees around X to align cylinder Y-axis with Z-axis.
	cone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# Offset so the cone tip starts at the pivot origin.
	cone.position = Vector3(0.0, 0.0, cone_range * 0.5)

	pivot.add_child(cone)

	# Position at boss.
	pivot.global_position = Vector3(
		_parent.global_position.x,
		TELEGRAPH_Y,
		_parent.global_position.z
	)

	# Rotate pivot to face the telegraph direction.
	var look_target: Vector3 = pivot.global_position + _telegraph_direction
	pivot.look_at(look_target, Vector3.UP)

	_parent.get_parent().add_child(pivot)
	_telegraph_node = pivot


# ════════════════════════════════════════════════════════════════════
#  Minion spawning
# ════════════════════════════════════════════════════════════════════

## Spawn minion adds in a circle around the boss.
func _spawn_adds(add_type: String, count: int) -> void:
	if _enemy_scene == null:
		return

	# Clean up stale references.
	_prune_dead_adds()

	# Respect the global cap.
	var alive_count: int = _spawned_adds.size()
	var can_spawn: int = mini(count, MAX_BOSS_ADDS - alive_count)
	if can_spawn <= 0:
		return

	var boss_pos: Vector3 = _parent.global_position
	var spawner: Node = _parent.get_parent()

	for i: int in range(can_spawn):
		var angle: float = (TAU / float(can_spawn)) * float(i)
		var offset: Vector3 = Vector3(cos(angle) * ADD_SPAWN_RADIUS, 0.0, sin(angle) * ADD_SPAWN_RADIUS)
		var spawn_pos: Vector3 = boss_pos + offset
		spawn_pos.y = boss_pos.y

		var enemy_node: CharacterBody3D = _enemy_scene.instantiate() as CharacterBody3D
		spawner.add_child(enemy_node)
		enemy_node.setup(add_type, spawn_pos)
		enemy_node.set_meta("boss_add", true)

		_spawned_adds.append(weakref(enemy_node))

		EventBus.enemy_spawned.emit(enemy_node)

	EventBus.chat_message.emit(
		"%s summons reinforcements!" % _parent.enemy_name,
		"combat"
	)


## Remove invalid / dead add references from the tracking array.
func _prune_dead_adds() -> void:
	var pruned: Array = []
	for wr: Variant in _spawned_adds:
		var ref: WeakRef = wr as WeakRef
		if ref == null:
			continue
		var node: Node = ref.get_ref() as Node
		if node == null or not is_instance_valid(node):
			continue
		# Check if the enemy is dead.
		if node.get("state") != null and node.state == node.State.DEAD:
			continue
		pruned.append(ref)
	_spawned_adds = pruned


# ════════════════════════════════════════════════════════════════════
#  Cleanup
# ════════════════════════════════════════════════════════════════════

func _exit_tree() -> void:
	_cleanup_telegraph()
