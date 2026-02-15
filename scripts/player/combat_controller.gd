## CombatController — Handles targeting, auto-attack, damage intake, food, regen, adrenaline
##
## Attached as a child node of the Player scene.
## Click on an enemy to target it. When in range, auto-attacks on a timer.
## Handles taking damage from enemies, death, and respawn.
## Integrates prestige bonuses, pet buffs, food healing, HP/energy regen,
## adrenaline build-up, and 3 style-based abilities.
extends Node

# ── Combat settings ──
@export var attack_range: float = 2.5      ## Must be within this to attack
@export var base_attack_speed: float = 2.4 ## Auto-attack interval (RS-style: 2.4/3.0/3.6s)
@export var base_damage: int = 3           ## Base damage (weapon adds more)

# ── Global cooldown (GCD) for abilities ──
const GCD_TIME: float = 1.8           ## Minimum time between ability uses
var _gcd_timer: float = 0.0

# ── Regen settings ──
const REGEN_INTERVAL: float = 5.0    ## Seconds between passive HP/energy ticks
const REGEN_HP_PERCENT: float = 0.02 ## 2% max HP per tick (out of combat only)
const REGEN_ENERGY_RATE: float = 5.0 ## Flat energy per tick

# ── Adrenaline settings (RS3-style) ──
const ADRENALINE_PER_AUTO: float = 3.0   ## Gained per auto-attack hit
const ADRENALINE_PER_BASIC: float = 8.0  ## Gained per basic ability hit
const ADRENALINE_DECAY: float = 5.0      ## Lost per second out of combat (faster drain)
const ADRENALINE_MAX: float = 100.0

# ── Food cooldown ──
const FOOD_COOLDOWN: float = 1.8  ## Seconds between eating food

# ── State ──
var target: Node = null           ## Currently targeted enemy
var is_in_combat: bool = false
var attack_timer: float = 0.0
var _player: CharacterBody3D = null
var _regen_timer: float = REGEN_INTERVAL
var _food_cooldown_timer: float = 0.0
var _combat_exit_timer: float = 0.0  ## Time since last combat action
const COMBAT_EXIT_DELAY: float = 8.0 ## Seconds without combat to start regen

# ── Target highlight ──
var _target_indicator: MeshInstance3D = null

func _ready() -> void:
	_player = get_parent()

	# Listen for enemy death so we can clear target
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Listen for enemy attacks on player
	EventBus.hit_landed.connect(_on_hit_landed)

	# Load abilities for current combat style
	refresh_abilities()

	# Create target indicator ring (MeshInstance3D — no CSG compile flash)
	_target_indicator = MeshInstance3D.new()
	var cyl_mesh: CylinderMesh = CylinderMesh.new()
	cyl_mesh.top_radius = 0.8
	cyl_mesh.bottom_radius = 0.8
	cyl_mesh.height = 0.05
	cyl_mesh.radial_segments = 16
	_target_indicator.mesh = cyl_mesh
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.6)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.2, 0.0)
	ring_mat.emission_energy_multiplier = 1.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_indicator.material_override = ring_mat
	_target_indicator.visible = false
	_target_indicator.top_level = true
	_player.add_child(_target_indicator)

func _process(delta: float) -> void:
	# Update target indicator position
	if target and is_instance_valid(target) and target.state != target.State.DEAD:
		_target_indicator.visible = true
		_target_indicator.global_position = target.global_position
		_target_indicator.global_position.y = target.global_position.y + 0.05
	else:
		_target_indicator.visible = false
		if target and (not is_instance_valid(target) or target.state == target.State.DEAD):
			_clear_target()

	# Auto-attack (use XZ distance so large boss Y offset doesn't prevent melee)
	if target and is_instance_valid(target) and target.state != target.State.DEAD:
		var to_target_xz: Vector2 = Vector2(target.global_position.x - _player.global_position.x, target.global_position.z - _player.global_position.z)
		var dist: float = to_target_xz.length()
		# Extend attack range by the target's collision radius so large bosses are reachable
		var effective_range: float = attack_range + _get_target_collision_radius(target)
		if dist <= effective_range:
			is_in_combat = true
			_combat_exit_timer = 0.0
			attack_timer -= delta
			if attack_timer <= 0:
				_do_attack()
				attack_timer = base_attack_speed
		else:
			is_in_combat = false
	else:
		is_in_combat = false

	# Track time since last combat for regen/adrenaline decay
	if not is_in_combat:
		_combat_exit_timer += delta

	# Adrenaline decay out of combat
	if _combat_exit_timer > COMBAT_EXIT_DELAY:
		GameState.player["adrenaline"] = maxf(0.0, float(GameState.player["adrenaline"]) - ADRENALINE_DECAY * delta)

	# Passive HP/energy regen (only out of combat)
	_process_regen(delta)

	# GCD cooldown
	if _gcd_timer > 0:
		_gcd_timer -= delta

	# Food cooldown
	if _food_cooldown_timer > 0:
		_food_cooldown_timer -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_click"):
		_try_target_enemy(event)

	# Right-click on enemies/ground items → context menu
	if event.is_action_pressed("right_click"):
		_try_right_click_entity(event)

# ── Targeting ──

## Raycast from click to find an enemy
func _try_target_enemy(event: InputEvent) -> void:
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
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	query.collision_mask = 4  # Enemy layer (layer 3)
	query.exclude = [_player.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		var hit_node: Node = result.collider
		# Walk up to find the enemy CharacterBody3D
		while hit_node and not hit_node.is_in_group("enemies"):
			hit_node = hit_node.get_parent()

		if hit_node and hit_node.is_in_group("enemies"):
			_set_target(hit_node)
			# Stop player movement — they clicked an enemy, not ground
			if _player.has_method("stop_movement"):
				_player.stop_movement()
			# Walk toward the enemy
			_player.move_target = hit_node.global_position
			_player.is_moving = true
			# Consume the input so player_controller doesn't also process it
			_player.get_viewport().set_input_as_handled()

## Set the current target
func _set_target(enemy: Node) -> void:
	target = enemy
	attack_timer = 0.0  # Attack immediately when in range
	EventBus.combat_started.emit(enemy.enemy_id)

## Clear the current target
func _clear_target() -> void:
	target = null
	is_in_combat = false
	_target_indicator.visible = false
	EventBus.combat_ended.emit()

# ── Auto-attack ──

## Execute an attack on the target
func _do_attack() -> void:
	if target == null or not is_instance_valid(target):
		return

	# Calculate base damage
	var weapon_damage: int = _get_weapon_damage()
	var total_damage: int = base_damage + weapon_damage

	# Apply prestige damage bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		var dmg_mult: float = float(bonuses.get("damage_mult", 1.0))
		total_damage = int(float(total_damage) * dmg_mult)

	# Apply pet damage buff
	var pet_sys: Node = get_tree().get_first_node_in_group("pet_system")
	if pet_sys and pet_sys.has_method("get_pet_buff"):
		var buff: Dictionary = pet_sys.get_pet_buff()
		var buff_type: String = str(buff.get("type", ""))
		var buff_value: float = float(buff.get("value", 0.0))
		if buff_type == "damage":
			total_damage += int(buff_value)
		elif buff_type == "all":
			total_damage += int(buff_value)

	# Small random variance (±15%)
	var variance: float = randf_range(0.85, 1.15)
	total_damage = int(float(total_damage) * variance)

	# Accuracy check (5% miss chance base)
	var miss_chance: float = 0.05
	if miss_chance > 0 and randf() < miss_chance:
		EventBus.hit_missed.emit(target)
		EventBus.float_text_requested.emit("Miss", target.global_position + Vector3(0, 2.5, 0), Color(0.5, 0.5, 0.5))
		return

	# Critical hit (10% chance, 1.5x damage)
	var is_crit: bool = randf() < 0.10
	if is_crit:
		total_damage = int(float(total_damage) * 1.5)
		# Screen shake on crit
		var cam_rig: Node = _player.get_node_or_null("CameraRig")
		if cam_rig and cam_rig.has_method("shake"):
			cam_rig.shake(0.3)

	# Capture position BEFORE damage — target may die and get cleared
	var target_pos: Vector3 = (target as Node3D).global_position

	# Deal damage (may kill enemy → triggers _on_enemy_killed → clears target)
	var style: String = GameState.player["combat_style"]
	var actual: int = target.take_damage(total_damage, style)

	# Build adrenaline (small amount from auto-attacks, like RS3)
	GameState.player["adrenaline"] = minf(ADRENALINE_MAX, float(GameState.player["adrenaline"]) + ADRENALINE_PER_AUTO)

	# Float text — use cached position since target may be null now
	var color: Color = Color(1.0, 0.7, 0.0) if is_crit else Color(1.0, 0.2, 0.1)
	var text: String = str(actual)
	if is_crit:
		text += "!"
	EventBus.float_text_requested.emit(text, target_pos + Vector3(randf_range(-0.5, 0.5), 2.5, 0), color)

	# Broadcast attack to multiplayer
	var mp_client: Node = get_tree().get_first_node_in_group("multiplayer_client")
	if mp_client and mp_client.has_method("send_attack"):
		var enemy_type: String = ""
		if target != null and "enemy_id" in target:
			enemy_type = str(target.enemy_id)
		mp_client.send_attack(enemy_type, actual, style)

	# Face target while attacking — use cached position
	var to_target: Vector3 = target_pos - _player.global_position
	if to_target.length() > 0.1:
		_player.rotation.y = atan2(-to_target.x, -to_target.z)

# ── Passive Regen ──

## HP and energy regeneration when out of combat
func _process_regen(delta: float) -> void:
	_regen_timer -= delta
	if _regen_timer > 0:
		return
	_regen_timer = REGEN_INTERVAL

	# Energy always regens
	var max_energy: int = int(GameState.player["max_energy"])
	var cur_energy: float = float(GameState.player["energy"])
	if cur_energy < float(max_energy):
		GameState.player["energy"] = mini(max_energy, int(cur_energy + REGEN_ENERGY_RATE))

	# HP only regens out of combat
	if _combat_exit_timer < COMBAT_EXIT_DELAY:
		return

	var max_hp: int = int(GameState.player["max_hp"])
	var cur_hp: int = int(GameState.player["hp"])
	if cur_hp < max_hp:
		var regen_amount: int = maxi(1, int(float(max_hp) * REGEN_HP_PERCENT))
		GameState.player["hp"] = mini(max_hp, cur_hp + regen_amount)

# ── Food Healing ──

## Eat a food item from inventory to heal. Called by inventory panel or keybind.
## Looks for any food item in inventory (has "heal" or "healAmount" field).
func eat_food(item_id: String = "") -> bool:
	if _food_cooldown_timer > 0:
		EventBus.chat_message.emit("You must wait before eating again.", "system")
		return false

	# If no specific item, find the best food in inventory
	if item_id == "":
		item_id = _find_best_food()
		if item_id == "":
			EventBus.chat_message.emit("No food in inventory.", "system")
			return false

	# Verify player has it
	if GameState.count_item(item_id) <= 0:
		return false

	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return false

	# Get heal amount
	var heal: int = int(item_data.get("healAmount", item_data.get("heal", 0)))
	if heal <= 0:
		return false

	# Consume the item
	GameState.remove_item(item_id, 1)

	# Heal
	var max_hp: int = int(GameState.player["max_hp"])
	var old_hp: int = int(GameState.player["hp"])
	GameState.player["hp"] = mini(max_hp, old_hp + heal)
	var actual_heal: int = int(GameState.player["hp"]) - old_hp

	# Feedback
	var item_name: String = str(item_data.get("name", item_id))
	EventBus.chat_message.emit("Ate %s, healed %d HP." % [item_name, actual_heal], "combat")
	EventBus.float_text_requested.emit(
		"+%d" % actual_heal,
		_player.global_position + Vector3(0, 3.0, 0),
		Color(0.3, 1.0, 0.3)
	)
	EventBus.player_healed.emit(actual_heal)

	_food_cooldown_timer = FOOD_COOLDOWN
	return true

## Find the best (highest heal) food item in inventory
func _find_best_food() -> String:
	var best_id: String = ""
	var best_heal: int = 0
	for slot in GameState.inventory:
		var sid: String = str(slot.get("item_id", ""))
		var data: Dictionary = DataManager.get_item(sid)
		if data.is_empty():
			continue
		var h: int = int(data.get("healAmount", data.get("heal", 0)))
		if h > best_heal:
			best_heal = h
			best_id = sid
	return best_id

# ── Abilities (adrenaline-based, data-driven) ──

## Cached active abilities for current style (refreshed on style change)
var _active_abilities: Array = []

## Refresh abilities from DataManager for current combat style
func refresh_abilities() -> void:
	var style: String = str(GameState.player.get("combat_style", "nano"))
	_active_abilities = DataManager.get_abilities_for_style(style)
	_active_abilities.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))

## Use style-based ability (data-driven from abilities.json).
## Slot 1-5 corresponds to current style's abilities sorted by slot.
func use_ability(ability_slot: int) -> bool:
	if target == null or not is_instance_valid(target):
		EventBus.chat_message.emit("No target selected.", "system")
		return false
	if target.state == target.State.DEAD:
		return false

	# Check GCD
	if _gcd_timer > 0:
		return false

	# Refresh if empty
	if _active_abilities.is_empty():
		refresh_abilities()

	# Find the ability for this slot
	var slot_idx: int = ability_slot - 1
	if slot_idx < 0 or slot_idx >= _active_abilities.size():
		return false

	var ab: Dictionary = _active_abilities[slot_idx]
	var adrenaline: float = float(GameState.player["adrenaline"])
	var cost: float = float(ab.get("adr_cost", 0))
	var adr_gain: float = float(ab.get("adr_gain", 0))
	var damage_mult: float = float(ab.get("damage_mult", 1.0))
	var ability_name: String = str(ab.get("name", "Ability"))
	var tier: String = str(ab.get("tier", "basic"))
	var style: String = str(GameState.player["combat_style"])
	var effects: Array = ab.get("effects", [])

	if adrenaline < cost:
		EventBus.chat_message.emit("Not enough adrenaline (%d/%d)." % [int(adrenaline), int(cost)], "combat")
		return false

	# Spend or gain adrenaline
	if cost > 0:
		GameState.player["adrenaline"] = adrenaline - cost
	elif adr_gain > 0:
		GameState.player["adrenaline"] = minf(ADRENALINE_MAX, adrenaline + adr_gain)

	# Calculate base damage
	var weapon_damage: int = _get_weapon_damage()
	var total_damage: int = int(float(base_damage + weapon_damage) * damage_mult)

	# Apply prestige damage bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		total_damage = int(float(total_damage) * float(bonuses.get("damage_mult", 1.0)))

	# Variance
	total_damage = int(float(total_damage) * randf_range(0.9, 1.1))

	# Capture position
	var target_pos: Vector3 = (target as Node3D).global_position

	# Deal primary damage
	var actual: int = target.take_damage(total_damage, style)

	# Tier-based color
	var ability_color: Color
	match tier:
		"basic": ability_color = Color(0.3, 0.9, 1.0)
		"threshold": ability_color = Color(1.0, 0.6, 0.1)
		"ultimate": ability_color = Color(1.0, 0.2, 0.9)
		_: ability_color = Color.WHITE

	# Feedback
	EventBus.chat_message.emit("%s hit for %d!" % [ability_name, actual], "combat")
	EventBus.float_text_requested.emit(
		"%s %d" % [ability_name, actual],
		target_pos + Vector3(randf_range(-0.5, 0.5), 3.0, 0),
		ability_color
	)

	# Apply special effects
	_apply_ability_effects(effects, target, target_pos, total_damage, style, ability_color)

	# Screen shake for threshold/ultimate
	if tier == "threshold" or tier == "ultimate":
		var cam_rig: Node = _player.get_node_or_null("CameraRig")
		if cam_rig and cam_rig.has_method("shake"):
			var shake_strength: float = 0.4 if tier == "threshold" else 0.7
			cam_rig.shake(shake_strength)

	# Impact ring for threshold/ultimate
	if tier == "threshold" or tier == "ultimate":
		var ring_slot: int = 2 if tier == "threshold" else 3
		_spawn_impact_ring(target_pos, ability_color, ring_slot)

	# Reset attack timer and start GCD
	attack_timer = base_attack_speed
	_gcd_timer = GCD_TIME

	# Face target
	var to_target: Vector3 = target_pos - _player.global_position
	if to_target.length() > 0.1:
		_player.rotation.y = atan2(-to_target.x, -to_target.z)

	return true

## Apply special effects from ability data (DoT, AoE, chain, stun, debuff, heal)
func _apply_ability_effects(effects: Array, primary_target: Node, target_pos: Vector3, base_dmg: int, style: String, color: Color) -> void:
	for effect in effects:
		if not effect is Dictionary:
			continue
		var etype: String = str(effect.get("type", ""))

		match etype:
			"dot":
				# Damage over time on primary target
				if primary_target and is_instance_valid(primary_target) and primary_target.has_method("apply_dot"):
					var ticks: int = int(effect.get("ticks", 3))
					var tick_mult: float = float(effect.get("tick_damage_mult", 0.4))
					var duration: float = float(effect.get("duration", 6.0))
					var weapon_damage: int = _get_weapon_damage()
					var tick_dmg: int = maxi(1, int(float(base_damage + weapon_damage) * tick_mult))
					primary_target.apply_dot(tick_dmg, ticks, duration, style)
					EventBus.float_text_requested.emit("DoT!", target_pos + Vector3(0, 3.5, 0), Color(0.6, 0.9, 0.3))

			"aoe":
				# Area of effect — damage all enemies in radius
				var radius: float = float(effect.get("radius", 5.0))
				var aoe_targets: Array = _find_enemies_in_radius(target_pos, radius)
				for enemy in aoe_targets:
					if enemy == primary_target:
						continue  # Already hit
					if not is_instance_valid(enemy):
						continue
					var aoe_dmg: int = int(float(base_dmg) * 0.8)  # AoE does 80% of primary
					var aoe_actual: int = enemy.take_damage(aoe_dmg, style)
					EventBus.float_text_requested.emit(
						str(aoe_actual),
						enemy.global_position + Vector3(randf_range(-0.3, 0.3), 2.5, 0),
						color.darkened(0.15)
					)

			"chain":
				# Chain to nearby enemies
				var chain_count: int = int(effect.get("chain_count", 2))
				var chain_range: float = float(effect.get("chain_range", 6.0))
				var chain_mult: float = float(effect.get("chain_damage_mult", 0.6))
				var chain_targets: Array = _find_chain_targets(target_pos, chain_count, chain_range, primary_target)
				for enemy in chain_targets:
					if not is_instance_valid(enemy):
						continue
					var chain_dmg: int = maxi(1, int(float(base_dmg) * chain_mult))
					var chain_actual: int = enemy.take_damage(chain_dmg, style)
					EventBus.float_text_requested.emit(
						str(chain_actual),
						enemy.global_position + Vector3(randf_range(-0.3, 0.3), 2.5, 0),
						Color(0.4, 0.8, 1.0)
					)
					# Visual chain line
					_spawn_chain_line(target_pos, enemy.global_position, color)

			"stun":
				# Stun the primary target
				var stun_dur: float = float(effect.get("duration", 2.0))
				if primary_target and is_instance_valid(primary_target) and primary_target.has_method("apply_stun"):
					primary_target.apply_stun(stun_dur)

			"debuff":
				# Apply a debuff to the primary target
				var debuff_type: String = str(effect.get("debuff_type", "defense"))
				var value: float = float(effect.get("value", 0.2))
				var duration: float = float(effect.get("duration", 8.0))
				if primary_target and is_instance_valid(primary_target) and primary_target.has_method("apply_debuff"):
					primary_target.apply_debuff(debuff_type, value, duration)

			"heal":
				# Heal the player for a percentage of damage dealt
				var heal_pct: float = float(effect.get("heal_percent", 0.5))
				var heal_amount: int = maxi(1, int(float(base_dmg) * heal_pct))
				var max_hp: int = int(GameState.player["max_hp"])
				var old_hp: int = int(GameState.player["hp"])
				GameState.player["hp"] = mini(max_hp, old_hp + heal_amount)
				var actual_heal: int = int(GameState.player["hp"]) - old_hp
				if actual_heal > 0:
					EventBus.float_text_requested.emit(
						"+%d" % actual_heal,
						_player.global_position + Vector3(0, 3.0, 0),
						Color(0.3, 1.0, 0.3)
					)
					EventBus.player_healed.emit(actual_heal)

			"ground_aoe":
				# Ground AoE — creates a persistent damage zone
				var gaoe_radius: float = float(effect.get("radius", 4.0))
				var gaoe_tick_mult: float = float(effect.get("tick_damage_mult", 0.5))
				var gaoe_duration: float = float(effect.get("duration", 5.0))
				# Apply DoT to all enemies in the area
				var gaoe_targets: Array = _find_enemies_in_radius(target_pos, gaoe_radius)
				var weapon_damage: int = _get_weapon_damage()
				var tick_dmg: int = maxi(1, int(float(base_damage + weapon_damage) * gaoe_tick_mult))
				var ticks: int = int(gaoe_duration)  # 1 tick per second
				for enemy in gaoe_targets:
					if is_instance_valid(enemy) and enemy.has_method("apply_dot"):
						enemy.apply_dot(tick_dmg, ticks, gaoe_duration, style)
				# Visual feedback — spawn ground ring
				_spawn_ground_aoe_visual(target_pos, gaoe_radius, gaoe_duration, color)

## Find all enemies within a radius of a position
func _find_enemies_in_radius(center: Vector3, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.state == enemy.State.DEAD:
			continue
		var dist: float = enemy.global_position.distance_to(center)
		if dist <= radius:
			result.append(enemy)
	return result

## Find chain targets (closest enemies not already hit)
func _find_chain_targets(origin: Vector3, count: int, max_range: float, exclude: Node) -> Array:
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy == exclude:
			continue
		if enemy.state == enemy.State.DEAD:
			continue
		var dist: float = enemy.global_position.distance_to(origin)
		if dist <= max_range:
			candidates.append({ "enemy": enemy, "dist": dist })
	# Sort by distance
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for i in range(mini(count, candidates.size())):
		result.append(candidates[i]["enemy"])
	return result

## Spawn a visual chain lightning line between two positions
func _spawn_chain_line(from: Vector3, to: Vector3, color: Color) -> void:
	# Create a simple line using a stretched CSGBox3D
	var midpoint: Vector3 = (from + to) / 2.0
	midpoint.y = maxf(from.y, to.y) + 1.0
	var chain_visual: CSGBox3D = CSGBox3D.new()
	chain_visual.size = Vector3(0.08, 0.08, from.distance_to(to))
	chain_visual.top_level = true
	chain_visual.global_position = midpoint
	chain_visual.look_at(to, Vector3.UP)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chain_visual.material = mat
	_player.get_tree().root.add_child(chain_visual)
	# Fade out quickly
	var tween: Tween = chain_visual.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(chain_visual.queue_free)

## Spawn a ground AoE visual ring that persists for duration then fades
func _spawn_ground_aoe_visual(pos: Vector3, radius: float, duration: float, color: Color) -> void:
	var ring: CSGTorus3D = CSGTorus3D.new()
	ring.inner_radius = radius - 0.15
	ring.outer_radius = radius
	ring.ring_sides = 6
	ring.sides = 32
	ring.rotation_degrees.x = 90.0
	ring.top_level = true
	ring.global_position = Vector3(pos.x, 0.1, pos.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material = mat
	_player.get_tree().root.add_child(ring)
	# Hold then fade
	var tween: Tween = ring.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

# ── Damage taken ──

## Get damage from equipped weapon
func _get_weapon_damage() -> int:
	var equip_sys: Node = _player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("get_weapon_damage"):
		return equip_sys.get_weapon_damage()
	# Fallback: read directly
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 0
	var item: Dictionary = DataManager.get_item(weapon_id)
	if item.is_empty():
		return 0
	return int(item.get("damage", 0))

## Get the collision radius of a target enemy (accounts for scaled-up bosses)
func _get_target_collision_radius(enemy: Node) -> float:
	var col: CollisionShape3D = enemy.get_node_or_null("CollisionShape3D")
	if col and col.shape is CapsuleShape3D:
		return (col.shape as CapsuleShape3D).radius
	return 0.0

## Get total armor from equipped gear
func _get_total_armor() -> int:
	var equip_sys: Node = _player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("get_total_armor"):
		return equip_sys.get_total_armor()
	return 0

## Handle incoming damage from enemies
func _on_hit_landed(hit_target: Node, dmg: int, _is_crit: bool) -> void:
	# Only process if the target is the player
	if hit_target != _player:
		return

	# Reduce by player armor from equipment
	var armor: int = _get_total_armor()
	var reduction: float = float(armor) * 0.3  # Each armor point reduces ~0.3 damage
	var actual: int = maxi(1, dmg - int(reduction))

	# Apply prestige damage reduction
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		var red_mult: float = float(bonuses.get("reduction_mult", 1.0))
		if red_mult < 1.0:
			actual = maxi(1, int(float(actual) * red_mult))

	# Apply pet defense buff
	var pet_sys: Node = get_tree().get_first_node_in_group("pet_system")
	if pet_sys and pet_sys.has_method("get_pet_buff"):
		var buff: Dictionary = pet_sys.get_pet_buff()
		var buff_type: String = str(buff.get("type", ""))
		var buff_value: float = float(buff.get("value", 0.0))
		if buff_type == "defense" or buff_type == "all":
			actual = maxi(1, actual - int(buff_value))

	GameState.player["hp"] -= actual
	GameState.player["hp"] = maxi(0, GameState.player["hp"])

	# Build a small adrenaline on being hit
	GameState.player["adrenaline"] = minf(ADRENALINE_MAX, float(GameState.player["adrenaline"]) + 3.0)
	_combat_exit_timer = 0.0

	EventBus.player_damaged.emit(actual, "enemy")
	EventBus.float_text_requested.emit(str(actual), _player.global_position + Vector3(randf_range(-0.3, 0.3), 2.8, 0), Color(0.9, 0.1, 0.1))

	# Death check
	if GameState.player["hp"] <= 0:
		_player_death()

## Handle player death
func _player_death() -> void:
	_clear_target()
	GameState.player["adrenaline"] = 0.0
	EventBus.player_died.emit()

	# If in a dungeon, exit the dungeon run on death
	if GameState.dungeon_active:
		EventBus.chat_message.emit("You have been defeated in the dungeon! Run ended.", "dungeon")
		var dungeon_sys: Node = get_tree().get_first_node_in_group("dungeon_system")
		if dungeon_sys and dungeon_sys.has_method("exit_dungeon"):
			dungeon_sys.exit_dungeon()
	else:
		EventBus.chat_message.emit("You have been defeated! Respawning at Station Hub...", "combat")
		_player.teleport_to(Vector3(0, 1, 0))

	# Respawn with full HP/energy
	GameState.player["hp"] = GameState.player["max_hp"]
	GameState.player["energy"] = GameState.player["max_energy"]
	EventBus.player_respawned.emit()
	EventBus.float_text_requested.emit("Respawned!", _player.global_position + Vector3(0, 3.0, 0), Color(0.3, 1.0, 0.5))

## Spawn an expanding ring at target position for ability impact feedback
func _spawn_impact_ring(pos: Vector3, color: Color, slot: int) -> void:
	var ring: CSGTorus3D = CSGTorus3D.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.5
	ring.ring_sides = 6
	ring.sides = 24
	ring.rotation_degrees.x = 90.0  # Lay flat on ground
	ring.top_level = true
	ring.global_position = Vector3(pos.x, 0.1, pos.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material = mat
	_player.get_tree().root.add_child(ring)
	# Expand and fade
	var max_radius: float = 2.0 if slot == 2 else 3.5
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "inner_radius", max_radius - 0.2, 0.4)
	tween.tween_property(ring, "outer_radius", max_radius, 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)

## Handle enemy death — clear target if it was our target, handle dungeon logic
func _on_enemy_killed(eid: String, _etype: String) -> void:
	if target and is_instance_valid(target) and target.enemy_id == eid:
		# Award XP (scaled to require ~15-20 kills per level at appropriate tier)
		var xp_reward: int = target.level * 4 + (target.level * target.level) / 2
		if target.is_boss:
			xp_reward *= 3

		# Apply prestige XP bonus
		var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
		if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
			var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
			xp_reward = int(float(xp_reward) * float(bonuses.get("xp_mult", 1.0)))

		# Apply pet XP bonus
		var pet_sys: Node = get_tree().get_first_node_in_group("pet_system")
		if pet_sys and pet_sys.has_method("get_pet_buff"):
			var buff: Dictionary = pet_sys.get_pet_buff()
			if str(buff.get("type", "")) == "xp":
				xp_reward = int(float(xp_reward) * (1.0 + float(buff.get("value", 0.0))))

		var skill: String = GameState.player["combat_style"]
		_award_xp(skill, xp_reward)

		# ── Dungeon: register kill, roll loot, check room clear ──
		if GameState.dungeon_active:
			_handle_dungeon_kill(target)

		# Broadcast kill to multiplayer
		var mp_client: Node = get_tree().get_first_node_in_group("multiplayer_client")
		if mp_client and mp_client.has_method("send_kill"):
			mp_client.send_kill(eid)

		_clear_target()

## Handle dungeon-specific logic when an enemy is killed
func _handle_dungeon_kill(killed_enemy: Node) -> void:
	var dungeon_sys: Node = get_tree().get_first_node_in_group("dungeon_system")
	if dungeon_sys == null:
		return

	# Register kill count
	if dungeon_sys.has_method("register_kill"):
		dungeon_sys.register_kill()

	# Roll dungeon loot
	var floor_num: int = int(GameState.dungeon_floor)
	var is_boss_room: bool = false
	var room_key: String = str(killed_enemy.get_meta("dungeon_room", ""))

	# Check if this is a boss room kill
	if dungeon_sys.has_method("get_current_theme") and "_current_floor_data" in dungeon_sys:
		var floor_data: Dictionary = dungeon_sys._current_floor_data
		for room in floor_data.get("rooms", []):
			var rk: String = "%d,%d" % [int(room.get("grid_x", 0)), int(room.get("grid_z", 0))]
			if rk == room_key and str(room.get("type", "")) == "boss":
				is_boss_room = true
				break

	# Roll loot
	var loot: Array = []
	if is_boss_room and dungeon_sys.has_method("get_loot_for_boss"):
		loot = dungeon_sys.get_loot_for_boss(floor_num)
	elif dungeon_sys.has_method("get_loot_for_enemy"):
		loot = dungeon_sys.get_loot_for_enemy(floor_num)

	for drop in loot:
		var item_id: String = str(drop.get("item_id", ""))
		var qty: int = int(drop.get("quantity", 1))
		if item_id != "" and GameState.add_item(item_id, qty):
			var item_name: String = str(DataManager.get_item(item_id).get("name", item_id))
			EventBus.chat_message.emit("Loot: %s x%d" % [item_name, qty], "loot")

	# Check if all enemies in this room are dead → mark cleared
	if room_key != "":
		_check_dungeon_room_clear(room_key, dungeon_sys)

## Check if all enemies in a dungeon room are dead and mark it cleared
func _check_dungeon_room_clear(room_key: String, dungeon_sys: Node) -> void:
	# Find the dungeon renderer to check living enemies in this room
	var renderer: Node = get_tree().get_first_node_in_group("dungeon_renderer")
	if renderer == null:
		return

	# Count living enemies in this room
	var living: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.get_meta("dungeon_room", "") == room_key:
			if enemy.state != enemy.State.DEAD:
				living += 1

	if living <= 0:
		# All enemies in this room are dead — find and clear the room
		if "_current_floor_data" in dungeon_sys:
			var floor_data: Dictionary = dungeon_sys._current_floor_data
			for room in floor_data.get("rooms", []):
				var rk: String = "%d,%d" % [int(room.get("grid_x", 0)), int(room.get("grid_z", 0))]
				if rk == room_key and not bool(room.get("cleared", false)):
					# Clear via dungeon system (emits signal)
					dungeon_sys.clear_room(int(room.get("grid_x", 0)), int(room.get("grid_z", 0)))
					# Also update renderer visual
					if renderer.has_method("mark_room_cleared"):
						renderer.mark_room_cleared(room)
					break

## Award XP to a skill and check for level up
func _award_xp(skill_id: String, amount: int) -> void:
	if not GameState.skills.has(skill_id):
		return

	GameState.skills[skill_id]["xp"] = int(GameState.skills[skill_id]["xp"]) + amount
	EventBus.player_xp_gained.emit(skill_id, amount)

	# Show float text
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id))
	EventBus.float_text_requested.emit("+%d %s XP" % [amount, skill_name], _player.global_position + Vector3(0, 3.2, 0), Color(0.3, 0.9, 0.3))

	# Check level up
	var current_level: int = int(GameState.skills[skill_id]["level"])
	var current_xp: int = int(GameState.skills[skill_id]["xp"])
	var next_level_xp: int = DataManager.xp_for_level(current_level + 1)

	if next_level_xp > 0 and current_xp >= next_level_xp:
		GameState.skills[skill_id]["level"] = current_level + 1
		EventBus.player_level_up.emit(skill_id, current_level + 1)
		EventBus.chat_message.emit(
			"%s levelled up to %d!" % [skill_name, current_level + 1],
			"levelup"
		)
		EventBus.float_text_requested.emit(
			"%s Level %d!" % [skill_name, current_level + 1],
			_player.global_position + Vector3(0, 3.8, 0),
			Color(1.0, 0.9, 0.2)
		)

# ── Right-click context menu ──

## Raycast from right-click to find enemy, ground item, or NPC
func _try_right_click_entity(event: InputEvent) -> void:
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

	# Try all layers at once (enemies 4 + NPCs 8 + ground items 16 = 28)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	query.collision_mask = 4 | 8 | 16  # Enemies + NPCs + Ground items
	query.exclude = [_player.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return

	var hit_node: Node = result.collider

	# Walk up to find the entity root
	var check_node: Node = hit_node
	while check_node:
		if check_node.is_in_group("enemies"):
			_show_enemy_context_menu(check_node, mouse_pos)
			_player.get_viewport().set_input_as_handled()
			return
		if check_node.is_in_group("npcs"):
			_show_npc_context_menu(check_node, mouse_pos)
			_player.get_viewport().set_input_as_handled()
			return
		if check_node.is_in_group("ground_items"):
			_show_ground_item_context_menu(check_node, mouse_pos)
			_player.get_viewport().set_input_as_handled()
			return
		if check_node.is_in_group("gathering_nodes"):
			_show_gathering_context_menu(check_node, mouse_pos)
			_player.get_viewport().set_input_as_handled()
			return
		check_node = check_node.get_parent()

## Show context menu for an enemy
func _show_enemy_context_menu(enemy: Node, screen_pos: Vector2) -> void:
	var enemy_data: Dictionary = DataManager.get_enemy(enemy.enemy_id)
	var enemy_name: String = str(enemy_data.get("name", enemy.enemy_id))
	var enemy_level: int = int(enemy_data.get("level", 1))
	var combat_style: String = str(enemy_data.get("combatStyle", ""))

	var options: Array = []
	options.append({
		"title": "%s (Lv %d)" % [enemy_name, enemy_level],
		"title_color": Color(1.0, 0.4, 0.3)
	})
	options.append({
		"label": "Attack",
		"icon": "W",
		"color": Color(1.0, 0.3, 0.2),
		"callback": func():
			_set_target(enemy)
			_player.move_target = enemy.global_position
			_player.is_moving = true
	})
	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var style_text: String = " [%s]" % combat_style.capitalize() if combat_style != "" else ""
			var hp_text: String = ""
			if "hp" in enemy and "max_hp" in enemy:
				hp_text = "  HP: %d/%d" % [enemy.hp, enemy.max_hp]
			EventBus.chat_message.emit(
				"Examine: %s — Level %d%s%s" % [enemy_name, enemy_level, style_text, hp_text],
				"system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Show context menu for an NPC
func _show_npc_context_menu(npc: Node, screen_pos: Vector2) -> void:
	var npc_name: String = str(npc.npc_name) if "npc_name" in npc else "NPC"

	var options: Array = []
	options.append({
		"title": npc_name,
		"title_color": Color(0.3, 0.9, 1.0)
	})
	options.append({
		"label": "Talk to",
		"icon": "T",
		"color": Color(0.3, 0.9, 1.0),
		"callback": func():
			_player.move_target = npc.global_position
			_player.is_moving = true
			# NPC interaction is handled by proximity in the NPC controller
	})
	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = ""
			if "npc_id" in npc:
				var npc_data: Dictionary = DataManager.get_npc(str(npc.npc_id))
				desc = str(npc_data.get("desc", ""))
			if desc == "":
				desc = "A station inhabitant."
			EventBus.chat_message.emit("Examine: %s — %s" % [npc_name, desc], "system")
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Show context menu for a ground item
func _show_ground_item_context_menu(gitem: Node, screen_pos: Vector2) -> void:
	# ground_item_controller stores item_id/quantity as properties, not metadata
	var item_id: String = str(gitem.item_id) if "item_id" in gitem else ""
	var quantity: int = int(gitem.quantity) if "quantity" in gitem else 1
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_name: String = str(item_data.get("name", item_id))
	var tier: int = int(item_data.get("tier", 1))

	var options: Array = []

	# Get tier color for the title
	var tier_col: Color = Color(0.8, 0.8, 0.8)
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		tier_col = Color.html(str(tiers[tier_str].get("color", "#888888")))

	var qty_text: String = " x%d" % quantity if quantity > 1 else ""
	options.append({
		"title": "%s%s" % [item_name, qty_text],
		"title_color": tier_col
	})
	options.append({
		"label": "Pick up",
		"icon": "P",
		"color": Color(0.3, 1.0, 0.6),
		"callback": func():
			# Walk to the item then pick it up
			_player.move_target = gitem.global_position
			_player.is_moving = true
			# LootSystem handles auto-pickup when in range
	})
	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = str(item_data.get("desc", ""))
			if desc == "":
				desc = "A dropped item."
			var value: int = int(item_data.get("value", 0))
			var value_text: String = " (Value: %d cr)" % value if value > 0 else ""
			EventBus.chat_message.emit(
				"Examine: %s — %s%s" % [item_name, desc, value_text],
				"system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Show context menu for a gathering node
func _show_gathering_context_menu(gnode: Node, screen_pos: Vector2) -> void:
	var res_id: String = str(gnode.resource_id) if "resource_id" in gnode else ""
	var item_data: Dictionary = DataManager.get_item(res_id)
	var item_name: String = str(item_data.get("name", res_id))
	var g_skill_id: String = str(gnode.skill_id) if "skill_id" in gnode else ""
	var skill_data: Dictionary = DataManager.get_skill(g_skill_id)
	var skill_name: String = str(skill_data.get("name", g_skill_id))
	var g_level: int = int(gnode.skill_level) if "skill_level" in gnode else 1
	var is_depleted: bool = gnode._is_depleted if "_is_depleted" in gnode else false

	var options: Array = []
	options.append({
		"title": "%s" % item_name,
		"title_color": Color(0.9, 0.8, 0.4)
	})

	# Gather option (walk to node)
	if is_depleted:
		options.append({
			"label": "Depleted",
			"icon": "X",
			"color": Color(0.5, 0.5, 0.5),
			"callback": func():
				EventBus.chat_message.emit("That resource is depleted.", "system")
		})
	elif gnode.has_method("can_gather") and gnode.can_gather():
		options.append({
			"label": "Gather",
			"icon": "G",
			"color": Color(0.4, 0.9, 0.6),
			"callback": func():
				_player.move_target = gnode.global_position
				_player.is_moving = true
		})
	else:
		options.append({
			"label": "Requires Lv %d %s" % [g_level, skill_name],
			"icon": "!",
			"color": Color(0.7, 0.3, 0.3),
			"callback": func():
				EventBus.chat_message.emit(
					"You need level %d %s to gather this." % [g_level, skill_name],
					"system"
				)
		})

	# Examine option
	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var xp_text: String = "+%d XP" % gnode.xp_reward if "xp_reward" in gnode else ""
			var time_text: String = "%.1fs" % gnode.gather_time if "gather_time" in gnode else ""
			EventBus.chat_message.emit(
				"Examine: %s — Lv %d %s  |  %s  |  %s" % [item_name, g_level, skill_name, xp_text, time_text],
				"system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)
