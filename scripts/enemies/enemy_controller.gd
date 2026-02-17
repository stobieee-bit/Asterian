## EnemyController — AI, stats, and behavior for individual enemies
##
## Attached to the Enemy CharacterBody3D scene.
## Reads stats from DataManager, runs a simple state machine:
##   IDLE → AGGRO → CHASE → RETURNING → IDLE
##
## Enemies wander in idle, aggro when player enters aggro range,
## chase the player, and leash back to spawn when too far.
extends CharacterBody3D

# ── Enums ──
enum State { IDLE, AGGRO, CHASE, ATTACKING, RETURNING, DEAD }

# ── Stats (loaded from DataManager) ──
var enemy_id: String = ""
var enemy_name: String = "Unknown"
var level: int = 1
var hp: int = 50
var max_hp: int = 50
var damage: int = 5
var defense: int = 0
var attack_speed: float = 3.0    # Seconds between attacks
var aggro_range: float = 8.0
var leash_range: float = 20.0
var combat_style: String = "nano"
var is_boss: bool = false
var respawn_time: float = 30.0
var mesh_color: Color = Color(0.5, 0.3, 0.2)
var mesh_template: String = ""          # e.g. "insectoid", "jellyfish"
var mesh_params: Dictionary = {}        # color, scale, variant from JSON data

# ── Mesh builder ──
var _mesh_builder: EnemyMeshBuilder = null  # Template builder for this enemy
var _mesh_root: Node3D = null               # Root of the built mesh hierarchy
var _anim_phase: float = 0.0               # Animation accumulator (radians)

# ── Movement ──
var move_speed: float = 3.0
var spawn_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var wander_interval: float = 4.0

# ── State machine ──
var state: State = State.IDLE
var _player: CharacterBody3D = null
var _area_mgr: Node3D = null
var _attack_timer: float = 0.0
var _dead_timer: float = 0.0
var _return_speed_mult: float = 2.0  # Move faster when returning

# ── Debuffs & Stun ──
var _debuffs: Dictionary = {}  # { "defense": {value, duration, timer}, "damage": {value, duration, timer} }
var _stun_timer: float = 0.0
var _active_dots: Array = []   # Array of { damage_per_tick, tick_interval, ticks_remaining, tick_timer, from_style }

# ── Dungeon Modifiers ──
var _dungeon_modifiers: Array = []
var _regen_timer: float = 0.0

# ── Loot ──
var loot_table: Array = []

# ── Node refs ──
@onready var mesh_node: Node3D = $EnemyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var nameplate: Label3D = $Nameplate
@onready var hp_bar_bg: CSGBox3D = $HPBarPivot/HPBarBG
@onready var hp_bar_fill: CSGBox3D = $HPBarPivot/HPBarFill
@onready var hp_bar_pivot: Node3D = $HPBarPivot

## Initialize this enemy from DataManager data
func setup(type_id: String, spawn_pos: Vector3) -> void:
	enemy_id = type_id
	spawn_position = spawn_pos
	global_position = spawn_pos

	var data: Dictionary = DataManager.get_enemy(type_id)
	if data.is_empty():
		push_warning("EnemyController: Unknown enemy type '%s'" % type_id)
		return

	enemy_name = str(data.get("name", type_id))
	level = int(data.get("level", 1))
	hp = int(data.get("hp", 50))
	max_hp = int(data.get("maxHp", hp))
	damage = int(data.get("damage", 5))
	defense = int(data.get("defense", 0))
	attack_speed = float(data.get("attackSpeed", 3.0))
	aggro_range = float(data.get("aggroRange", 8.0))
	leash_range = float(data.get("leashRange", 20.0))
	combat_style = str(data.get("combatStyle", "nano"))
	is_boss = bool(data.get("isBoss", false))
	respawn_time = float(data.get("respawnTime", 30.0))

	# Loot table
	var lt: Variant = data.get("lootTable", [])
	if lt is Array:
		loot_table = lt

	# Set movement speed based on level
	move_speed = 2.5 + level * 0.02

	# Read mesh template info from enemy data
	mesh_template = str(data.get("meshTemplate", ""))
	var mp: Variant = data.get("meshParams", {})
	if mp is Dictionary:
		mesh_params = mp

	# Mesh color — use meshParams color if available, else fallback by combat style
	if mesh_params.has("color") and mesh_params["color"] is float:
		mesh_color = EnemyMeshBuilder.int_to_color(int(mesh_params["color"]))
	elif mesh_params.has("color") and mesh_params["color"] is int:
		mesh_color = EnemyMeshBuilder.int_to_color(mesh_params["color"])
	else:
		match combat_style:
			"nano":
				mesh_color = Color(0.2, 0.9, 0.4)  # Green
			"tesla":
				mesh_color = Color(0.2, 0.5, 1.0)  # Blue
			"void":
				mesh_color = Color(0.6, 0.2, 0.9)  # Purple
			_:
				mesh_color = Color(0.7, 0.4, 0.2)  # Brown default

	# Boss tint — redder
	if is_boss:
		mesh_color = mesh_color.lerp(Color(1.0, 0.1, 0.1), 0.3)

	# Build proper mesh from template, or fall back to placeholder visuals
	_build_template_mesh()

	# If no template was built, use old placeholder visuals
	if _mesh_root == null:
		_apply_visuals()

	# Update nameplate — bigger text with outline for visibility
	if nameplate:
		nameplate.text = "%s (Lv %d)" % [enemy_name, level]
		nameplate.outline_size = 8
		nameplate.outline_modulate = Color(0, 0, 0, 0.9)
		if is_boss:
			nameplate.modulate = Color(1.0, 0.3, 0.3, 1.0)
		else:
			nameplate.modulate = Color(1.0, 1.0, 0.6, 1.0)

## Apply dungeon modifier stat changes. Called by dungeon_renderer after setup().
func apply_dungeon_modifiers(modifiers: Array) -> void:
	_dungeon_modifiers = modifiers
	for mod in modifiers:
		var mod_id: String = str(mod.get("id", ""))
		match mod_id:
			"armored":
				defense = int(float(defense) * 1.3)
			"frenzied":
				attack_speed *= 0.75  # lower = faster attacks

## Check if a specific dungeon modifier is active on this enemy.
func _has_modifier(mod_id: String) -> bool:
	for mod in _dungeon_modifiers:
		if str(mod.get("id", "")) == mod_id:
			return true
	return false

func _ready() -> void:
	add_to_group("enemies")
	# Floor-snap settings — keeps CharacterBody3D pressed against Terrain3D surface
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	# Initial wander target
	wander_target = spawn_position

func _physics_process(delta: float) -> void:
	# Find player if not cached
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	# ── Process stun ──
	if _stun_timer > 0:
		_stun_timer -= delta
		velocity = Vector3.ZERO
		if GameState.dungeon_active:
			# Dungeon has real floor colliders — use physics gravity
			if not is_on_floor():
				velocity.y -= 20.0 * delta
		move_and_slide()
		if not GameState.dungeon_active:
			_snap_to_terrain()
		_update_hp_bar()
		# Process DoTs even while stunned
		_process_dots(delta)
		# Process debuff timers
		_process_debuffs(delta)
		return

	# ── Process debuff timers ──
	_process_debuffs(delta)

	# ── Process DoTs ──
	_process_dots(delta)

	# ── Dungeon: Regenerating modifier ──
	if _has_modifier("regenerating") and state != State.DEAD and hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= 5.0:
			_regen_timer -= 5.0
			var heal_amount: int = int(float(max_hp) * 0.02)
			hp = mini(max_hp, hp + heal_amount)
			_update_hp_bar()

	match state:
		State.IDLE:
			_process_idle(delta)
		State.AGGRO:
			_process_aggro(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.RETURNING:
			_process_returning(delta)
		State.DEAD:
			_process_dead(delta)

	# Vertical movement: dungeon uses physics gravity, overworld snaps to terrain
	if GameState.dungeon_active:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = -0.5  # Downward nudge keeps floor_snap_length engaged
	else:
		velocity.y = 0.0  # No gravity — terrain snap handles Y

	move_and_slide()

	# Overworld: pin to Terrain3D surface every frame
	if state != State.DEAD and not GameState.dungeon_active:
		_snap_to_terrain()

	# Update HP bar
	_update_hp_bar()

	# Animate template mesh (walk cycle, idle bob, etc.)
	if _mesh_builder != null and _mesh_root != null and state != State.DEAD:
		_anim_phase += delta * 3.0
		var is_moving: bool = (state == State.CHASE or state == State.RETURNING or
			(state == State.IDLE and velocity.length_squared() > 0.1))
		_mesh_builder.animate(_mesh_root, _anim_phase, is_moving, delta)

# ── State: IDLE ──

func _process_idle(delta: float) -> void:
	# Check for player aggro
	if _player and _can_aggro():
		_enter_state(State.AGGRO)
		return

	# Wander
	wander_timer -= delta
	if wander_timer <= 0:
		_pick_wander_target()
		wander_timer = wander_interval + randf_range(-1.0, 1.0)

	var to_target: Vector2 = Vector2(wander_target.x - global_position.x, wander_target.z - global_position.z)
	if to_target.length() > 0.5:
		var dir: Vector2 = to_target.normalized()
		velocity.x = dir.x * move_speed * 0.5
		velocity.z = dir.y * move_speed * 0.5
		# Face movement direction
		# Godot's rotation.y=0 faces -Z, negate to fix facing direction
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), 5.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

# ── State: AGGRO ──

func _process_aggro(delta: float) -> void:
	# Transition to chase immediately
	_enter_state(State.CHASE)

# ── State: CHASE ──

func _process_chase(delta: float) -> void:
	if _player == null:
		_enter_state(State.RETURNING)
		return

	# Boss channeling — freeze movement during telegraph wind-up
	var boss_ai: Node = get_node_or_null("BossAI")
	if boss_ai != null and boss_ai.get("channeling") == true:
		velocity = Vector3.ZERO
		return

	# Check leash
	if global_position.distance_squared_to(spawn_position) > leash_range * leash_range:
		_enter_state(State.RETURNING)
		return

	# Check if player left aggro range (with hysteresis)
	var deaggro: float = aggro_range * 1.5
	if global_position.distance_squared_to(_player.global_position) > deaggro * deaggro:
		_enter_state(State.RETURNING)
		return

	# Move toward player
	var to_player: Vector2 = Vector2(
		_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z
	)
	var dist_2d: float = to_player.length()

	var melee_reach: float = _get_melee_reach()
	if dist_2d > melee_reach:
		# Chase
		var dir: Vector2 = to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.y * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), 8.0 * delta)
	else:
		# In attack range
		velocity.x = 0.0
		velocity.z = 0.0
		_enter_state(State.ATTACKING)

# ── State: ATTACKING ──

func _process_attacking(delta: float) -> void:
	if _player == null:
		_enter_state(State.RETURNING)
		return

	# Boss channeling — freeze during telegraph wind-up (but still face player)
	var boss_ai: Node = get_node_or_null("BossAI")
	if boss_ai != null and boss_ai.get("channeling") == true:
		velocity = Vector3.ZERO
		# Still face the player during channel
		var face_dir: Vector2 = Vector2(
			_player.global_position.x - global_position.x,
			_player.global_position.z - global_position.z
		)
		if face_dir.length() > 0.1:
			var fd: Vector2 = face_dir.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-fd.x, -fd.y), 8.0 * delta)
		return

	# Face player
	var to_player: Vector2 = Vector2(
		_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z
	)
	var dist_2d: float = to_player.length()

	# If player moved away, chase again
	var melee_reach: float = _get_melee_reach()
	if dist_2d > melee_reach + 1.0:
		_enter_state(State.CHASE)
		return

	# Check leash
	if global_position.distance_squared_to(spawn_position) > leash_range * leash_range:
		_enter_state(State.RETURNING)
		return

	# Face player
	if to_player.length() > 0.1:
		var dir: Vector2 = to_player.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), 8.0 * delta)

	velocity.x = 0.0
	velocity.z = 0.0

	# Attack timer
	_attack_timer -= delta
	if _attack_timer <= 0:
		_do_attack()
		_attack_timer = attack_speed

# ── State: RETURNING ──

func _process_returning(delta: float) -> void:
	var to_spawn: Vector2 = Vector2(spawn_position.x - global_position.x, spawn_position.z - global_position.z)
	if to_spawn.length() < 1.0:
		# Arrived back at spawn
		hp = max_hp  # Heal fully on return
		_enter_state(State.IDLE)
		return

	var dir: Vector2 = to_spawn.normalized()
	velocity.x = dir.x * move_speed * _return_speed_mult
	velocity.z = dir.y * move_speed * _return_speed_mult
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), 8.0 * get_physics_process_delta_time())

	# Re-aggro if player gets close while returning
	if _player and _can_aggro():
		_enter_state(State.CHASE)

# ── State: DEAD ──

func _process_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	_dead_timer -= delta
	if _dead_timer <= 0:
		_respawn()

# ── Combat ──

func _do_attack() -> void:
	if _player == null:
		return
	# Emit attack signal with effective damage (reduced by debuffs)
	var eff_damage: int = get_effective_damage()
	EventBus.hit_landed.emit(_player, eff_damage, false, self)

	# Dungeon: Vampiric — heal 10% of damage dealt
	if _has_modifier("vampiric") and state != State.DEAD:
		var heal: int = int(float(eff_damage) * 0.1)
		hp = mini(max_hp, hp + heal)
		_update_hp_bar()

## Take damage from player. Returns actual damage dealt.
func take_damage(amount: int, from_style: String = "") -> int:
	if state == State.DEAD:
		return 0

	# Combat triangle bonus/penalty
	var style_mult: float = 1.0
	if from_style != "" and combat_style != "":
		style_mult = _get_style_multiplier(from_style, combat_style)

	# Apply effective defense (reduced by defense debuff)
	var eff_defense: int = get_effective_defense()
	var actual: int = maxi(1, int(amount * style_mult) - eff_defense / 2)
	hp -= actual
	hp = maxi(0, hp)

	# Dungeon: Reflective — reflect 10% of damage back to player
	if _has_modifier("reflective") and _player != null:
		var reflect_dmg: int = maxi(1, int(float(actual) * 0.1))
		EventBus.hit_landed.emit(_player, reflect_dmg, false, self)

	# Hit flash on template mesh
	if _mesh_root != null:
		EnemyMeshBuilder.flash_hit(_mesh_root, 0.8)
		# Reset flash after a short delay via tween
		var tween: Tween = create_tween()
		tween.tween_callback(func() -> void: EnemyMeshBuilder.flash_hit(_mesh_root, 0.0)).set_delay(0.15)

	# If we were idle, aggro on damage
	if state == State.IDLE or state == State.RETURNING:
		_enter_state(State.CHASE)

	if hp <= 0:
		_die()

	return actual

func _die() -> void:
	_enter_state(State.DEAD)
	_dead_timer = respawn_time

	# Dungeon: Explosive — deal AoE damage on death
	if _has_modifier("explosive") and _player != null:
		var dist: float = global_position.distance_to(_player.global_position)
		if dist < 6.0:  # Only hit player within 6 units
			var explode_dmg: int = int(float(max_hp) * 0.15)
			EventBus.hit_landed.emit(_player, explode_dmg, false, self)
			EventBus.float_text_requested.emit(
				"EXPLOSION %d" % explode_dmg,
				global_position + Vector3(0, 2.5, 0),
				Color(1.0, 0.4, 0.1)
			)

	# Emit signals
	EventBus.enemy_killed.emit(enemy_id, enemy_id)

	# Death animation for template meshes
	if _mesh_root != null:
		EnemyMeshBuilder.animate_death(_mesh_root, 1.0)

	# Smooth death animation: shrink + spin over 0.5s, then hide
	if mesh_node:
		var death_tween: Tween = create_tween().set_parallel(true)
		death_tween.tween_property(mesh_node, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_ease(Tween.EASE_IN)
		death_tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.5)
		death_tween.chain().tween_callback(func():
			if is_instance_valid(self) and mesh_node:
				mesh_node.visible = false
				mesh_node.scale = Vector3.ONE
		)
	if nameplate:
		var np_tween: Tween = create_tween()
		np_tween.tween_property(nameplate, "modulate:a", 0.0, 0.3)
		np_tween.tween_callback(func():
			if is_instance_valid(self) and nameplate:
				nameplate.visible = false
		)
	if hp_bar_pivot:
		hp_bar_pivot.visible = false
	if collision_shape:
		collision_shape.disabled = true

func _respawn() -> void:
	hp = max_hp
	global_position = spawn_position
	state = State.IDLE
	wander_target = spawn_position
	# Clear all status effects
	_debuffs.clear()
	_stun_timer = 0.0
	_active_dots.clear()
	_regen_timer = 0.0

	# Reset template mesh after death animation
	if _mesh_root != null:
		_mesh_root.scale = Vector3.ONE
		_mesh_root.position = Vector3.ZERO

	# Show visuals with spawn animation: scale up from 0 + fade in nameplate
	if mesh_node:
		mesh_node.visible = true
		mesh_node.scale = Vector3(0.01, 0.01, 0.01)
		var spawn_tween: Tween = create_tween()
		spawn_tween.tween_property(mesh_node, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if nameplate:
		nameplate.visible = true
		nameplate.modulate = Color(1, 1, 1, 0)
		var np_tween: Tween = create_tween()
		np_tween.tween_property(nameplate, "modulate:a", 1.0, 0.5)
	if hp_bar_pivot:
		hp_bar_pivot.visible = true
	if collision_shape:
		collision_shape.disabled = false

# ── Helpers ──

## Get this enemy's collision radius (accounts for scaled-up bosses)
func _get_melee_reach() -> float:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		return (collision_shape.shape as CapsuleShape3D).radius + 1.0
	return 2.0

## Snap this enemy's Y position to the Terrain3D surface.
## Called every physics frame in the overworld (Terrain3D has no physics collider,
## so gravity/is_on_floor() cannot work — we query height directly instead).
func _snap_to_terrain() -> void:
	if _area_mgr == null:
		_area_mgr = get_tree().get_first_node_in_group("area_manager")
	if _area_mgr:
		var terrain_y: float = _area_mgr.get_terrain_height(global_position.x, global_position.z)
		global_position.y = terrain_y + 0.1
		velocity.y = 0.0

func _can_aggro() -> bool:
	if _player == null:
		return false
	return global_position.distance_squared_to(_player.global_position) <= aggro_range * aggro_range

func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(2.0, 6.0)
	var wx: float = spawn_position.x + cos(angle) * dist
	var wz: float = spawn_position.z + sin(angle) * dist
	var wy: float = spawn_position.y
	var area_mgr: Node3D = get_tree().get_first_node_in_group("area_manager")
	if area_mgr and area_mgr.has_method("get_terrain_height"):
		wy = area_mgr.get_terrain_height(wx, wz)
	wander_target = Vector3(wx, wy, wz)

func _enter_state(new_state: State) -> void:
	state = new_state
	if new_state == State.ATTACKING:
		_attack_timer = attack_speed * 0.5  # First attack slightly faster

func _get_style_multiplier(attacker_style: String, defender_style: String) -> float:
	# Combat triangle: nano > tesla > void > nano (15% bonus)
	if attacker_style == defender_style:
		return 1.0
	if attacker_style == "nano" and defender_style == "tesla":
		return 1.15
	if attacker_style == "tesla" and defender_style == "void":
		return 1.15
	if attacker_style == "void" and defender_style == "nano":
		return 1.15
	# Disadvantage
	if attacker_style == "nano" and defender_style == "void":
		return 0.85
	if attacker_style == "tesla" and defender_style == "nano":
		return 0.85
	if attacker_style == "void" and defender_style == "tesla":
		return 0.85
	return 1.0

# ══════════════════════════════════════════════════════════════════
# DEBUFF / STUN / DOT SYSTEM
# ══════════════════════════════════════════════════════════════════

## Apply a stun effect (pauses attack timer and movement)
func apply_stun(duration: float) -> void:
	if state == State.DEAD:
		return
	_stun_timer = maxf(_stun_timer, duration)
	# Visual feedback — brief color tint
	EventBus.float_text_requested.emit("Stunned!", global_position + Vector3(0, 2.8, 0), Color(1.0, 0.9, 0.2))

## Apply a debuff (defense or damage reduction)
func apply_debuff(debuff_type: String, value: float, duration: float) -> void:
	if state == State.DEAD:
		return
	_debuffs[debuff_type] = { "value": value, "duration": duration, "timer": duration }
	var debuff_text: String = ""
	match debuff_type:
		"defense":
			debuff_text = "DEF -%d%%" % int(value * 100)
		"damage":
			debuff_text = "DMG -%d%%" % int(value * 100)
	if debuff_text != "":
		EventBus.float_text_requested.emit(debuff_text, global_position + Vector3(0, 2.5, 0), Color(0.8, 0.3, 1.0))

## Apply a damage-over-time effect
func apply_dot(damage_per_tick: int, ticks: int, duration: float, from_style: String = "") -> void:
	if state == State.DEAD:
		return
	var tick_interval: float = duration / float(ticks) if ticks > 0 else 2.0
	_active_dots.append({
		"damage_per_tick": damage_per_tick,
		"tick_interval": tick_interval,
		"ticks_remaining": ticks,
		"tick_timer": tick_interval,  # First tick after one interval
		"from_style": from_style,
	})

## Get defense after debuffs
func get_effective_defense() -> int:
	var eff: int = defense
	if _debuffs.has("defense"):
		var reduction: float = float(_debuffs["defense"].get("value", 0.0))
		eff = int(float(eff) * (1.0 - reduction))
	return maxi(0, eff)

## Get damage after debuffs
func get_effective_damage() -> int:
	var eff: int = damage
	if _debuffs.has("damage"):
		var reduction: float = float(_debuffs["damage"].get("value", 0.0))
		eff = int(float(eff) * (1.0 - reduction))
	if _debuffs.has("debilitate"):
		var reduction: float = float(_debuffs["debilitate"].get("value", 0.0))
		eff = int(float(eff) * (1.0 - reduction))
	return maxi(1, eff)

## Process debuff timers (called each physics frame)
func _process_debuffs(delta: float) -> void:
	var expired: Array = []
	for debuff_type in _debuffs:
		_debuffs[debuff_type]["timer"] = float(_debuffs[debuff_type]["timer"]) - delta
		if float(_debuffs[debuff_type]["timer"]) <= 0:
			expired.append(debuff_type)
	for debuff_type in expired:
		_debuffs.erase(debuff_type)

## Process DoT effects (called each physics frame)
func _process_dots(delta: float) -> void:
	if state == State.DEAD:
		_active_dots.clear()
		return

	var finished: Array = []
	for i in range(_active_dots.size()):
		var dot: Dictionary = _active_dots[i]
		dot["tick_timer"] = float(dot["tick_timer"]) - delta
		if float(dot["tick_timer"]) <= 0:
			# Apply tick damage
			var tick_dmg: int = int(dot["damage_per_tick"])
			var style: String = str(dot.get("from_style", ""))
			var style_mult: float = 1.0
			if style != "" and combat_style != "":
				style_mult = _get_style_multiplier(style, combat_style)
			var eff_def: int = get_effective_defense()
			var actual: int = maxi(1, int(float(tick_dmg) * style_mult) - eff_def / 4)
			hp -= actual
			hp = maxi(0, hp)
			# Float text for DoT damage (blood drop prefix, red-orange)
			EventBus.float_text_requested.emit("%d" % actual, global_position + Vector3(randf_range(-0.3, 0.3), 2.3, 0), Color(0.8, 0.3, 0.2))
			dot["ticks_remaining"] = int(dot["ticks_remaining"]) - 1
			dot["tick_timer"] = float(dot["tick_interval"])
			if int(dot["ticks_remaining"]) <= 0:
				finished.append(i)
			if hp <= 0:
				_die()
				return

	# Remove finished DoTs (iterate backwards)
	finished.reverse()
	for idx in finished:
		_active_dots.remove_at(idx)

## Build enemy mesh from the template system (replaces placeholder CSG)
func _build_template_mesh() -> void:
	if mesh_template == "":
		return

	# Look up the mesh builder for this template
	_mesh_builder = EnemyMeshBuilder.get_builder(mesh_template)
	if _mesh_builder == null:
		push_warning("EnemyController: No mesh builder for template '%s'" % mesh_template)
		return

	# Build the mesh with parameters from the enemy data
	var params: Dictionary = mesh_params.duplicate()
	# Ensure color is an int for the builder
	if params.has("color"):
		if params["color"] is float:
			params["color"] = int(params["color"])
	# Scale up 4x to match JS world scale (JS does: params.scale = baseScale * 4)
	var base_scale: float = float(params.get("scale", 1.0))
	params["scale"] = base_scale * 4.0
	_mesh_root = _mesh_builder.build_mesh(params)

	if _mesh_root == null:
		push_warning("EnemyController: Mesh builder returned null for '%s'" % mesh_template)
		_mesh_builder = null
		return

	# Remove the old placeholder CSG children from EnemyMesh
	if mesh_node:
		for child in mesh_node.get_children():
			child.queue_free()
		# Add the template-built mesh as child of EnemyMesh
		# Each template is responsible for facing -Z (Godot forward)
		mesh_node.add_child(_mesh_root)

	# Adjust collision shape based on scale (4x world scale applied)
	var mesh_scale: float = float(mesh_params.get("scale", 1.0)) * 4.0
	if is_boss:
		mesh_scale *= 1.5
	# Collision uses a capped scale so large bosses remain hittable in melee
	var col_scale: float = minf(mesh_scale, 3.0)
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
		cap.radius = 0.6 * col_scale
		cap.height = 1.2 * col_scale
		collision_shape.position.y = 0.6 * col_scale

	# Adjust nameplate and HP bar height for the mesh
	var height_offset: float = 1.4 * mesh_scale
	if nameplate:
		nameplate.position.y = height_offset + 0.5
		nameplate.font_size = int(36 * minf(mesh_scale, 2.0))
	if hp_bar_pivot:
		hp_bar_pivot.position.y = height_offset + 0.2

	# Randomize animation phase so enemies aren't in sync
	_anim_phase = randf() * TAU

func _apply_visuals() -> void:
	# Scale based on level and boss status
	var scale_mult: float = 0.8 + level * 0.005
	if is_boss:
		scale_mult *= 1.5

	if mesh_node:
		# The body CSGCylinder is the first child of EnemyMesh
		for child in mesh_node.get_children():
			if child is CSGCylinder3D:
				var body_mat: StandardMaterial3D = StandardMaterial3D.new()
				body_mat.albedo_color = mesh_color
				body_mat.emission_enabled = true
				body_mat.emission = mesh_color * 0.4
				body_mat.emission_energy_multiplier = 0.3
				child.material = body_mat
				child.radius = 0.35 * scale_mult
				child.height = 1.2 * scale_mult
			elif child is CSGSphere3D:
				var head_mat: StandardMaterial3D = StandardMaterial3D.new()
				head_mat.albedo_color = mesh_color.lightened(0.15)
				head_mat.emission_enabled = true
				head_mat.emission = mesh_color.lightened(0.2) * 0.3
				head_mat.emission_energy_multiplier = 0.3
				child.material = head_mat
				child.radius = 0.22 * scale_mult
				child.position.y = (1.2 * scale_mult) + 0.15

func _update_hp_bar() -> void:
	if hp_bar_pivot == null:
		return

	# Only show HP bar when damaged and alive
	var show_bar: bool = hp < max_hp and state != State.DEAD
	hp_bar_pivot.visible = show_bar

	if show_bar and hp_bar_fill:
		var fill_pct: float = float(hp) / float(max_hp)
		hp_bar_fill.size.x = 1.0 * fill_pct
		hp_bar_fill.position.x = -0.5 * (1.0 - fill_pct)

		# Color: green → yellow → red
		var bar_mat: StandardMaterial3D
		if hp_bar_fill.material is StandardMaterial3D:
			bar_mat = hp_bar_fill.material
		else:
			bar_mat = StandardMaterial3D.new()
			hp_bar_fill.material = bar_mat
		if fill_pct > 0.5:
			bar_mat.albedo_color = Color(0.2, 0.9, 0.2).lerp(Color(0.9, 0.9, 0.2), 1.0 - (fill_pct - 0.5) * 2.0)
		else:
			bar_mat.albedo_color = Color(0.9, 0.9, 0.2).lerp(Color(0.9, 0.1, 0.1), 1.0 - fill_pct * 2.0)
