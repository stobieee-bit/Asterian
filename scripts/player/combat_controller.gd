## CombatController — Handles targeting, auto-attack, damage intake, food, regen, adrenaline
##
## Attached as a child node of the Player scene.
## Click on an enemy to target it. When in range, auto-attacks on a timer.
## Handles taking damage from enemies, death, and respawn.
## Integrates prestige bonuses, pet buffs, food healing, HP/energy regen,
## adrenaline build-up, and 3 style-based abilities.
extends Node

# ── Combat settings ──
@export var base_damage: int = 3           ## Base damage (weapon adds more)

# ── Per-style combat parameters ──
# Nano: fast close-range precision strikes
# Tesla: medium-range heavy arc swings
# Void: slower long-range channeled attacks
const STYLE_ATTACK_RANGE: Dictionary = {
	"nano": 2.0,
	"tesla": 2.8,
	"void": 4.5,
}
const STYLE_ATTACK_SPEED: Dictionary = {
	"nano": 2.0,    # Fast — 2.0s between autos
	"tesla": 2.8,   # Medium — 2.8s between autos
	"void": 3.2,    # Slow — 3.2s between autos
}

## Dynamic attack range based on current combat style + set bonus
var attack_range: float:
	get:
		var s: String = str(GameState.player.get("combat_style", "nano"))
		var base: float = STYLE_ATTACK_RANGE.get(s, 2.5)
		# Add set bonus range (e.g., void set gives +range)
		var equip_sys: Node = get_node_or_null("../EquipmentSystem")
		if equip_sys and equip_sys.has_method("get_set_bonus_range"):
			base += equip_sys.get_set_bonus_range()
		return base

## Dynamic attack speed based on current combat style + set bonus
var base_attack_speed: float:
	get:
		var s: String = str(GameState.player.get("combat_style", "nano"))
		var base: float = STYLE_ATTACK_SPEED.get(s, 2.4)
		# Apply set bonus speed multiplier (e.g., nano set gives faster attacks)
		var equip_sys: Node = get_node_or_null("../EquipmentSystem")
		if equip_sys and equip_sys.has_method("get_set_bonus_attack_speed_mult"):
			base *= equip_sys.get_set_bonus_attack_speed_mult()
		return base

# ── Global cooldown (GCD) for abilities ──
const GCD_TIME: float = 1.8           ## Minimum time between ability uses
var _gcd_timer: float = 0.0

# ── Ability queue (RS3-style) ──
var _queued_ability_slot: int = -1        ## -1 = no queue, 1-5 = queued slot
var _queued_ability_timeout: float = 0.0  ## Clear queue if it sits too long
const QUEUE_TIMEOUT: float = 3.0          ## Max seconds an ability can sit in queue
var _ability_fired_this_frame: bool = false  ## Suppress auto-attack on ability tick

# ── Per-ability cooldowns (separate from GCD) ──
var _ability_cooldowns: Dictionary = {}  ## { ability_id: remaining_seconds }

# ── Adrenaline gain multiplier (Natural Instinct buff) ──
var _adrenaline_gain_mult: float = 1.0
var _adrenaline_gain_timer: float = 0.0

# ── Last attack style tracking (for XP distribution) ──
var _last_attack_style: String = ""

# ── Revolution (auto-fire basics) ──
var _revolution_slot_index: int = 0

# ── Defensive ability state ──
var _resonance_active: bool = false
var _resonance_timer: float = 0.0
var _reflect_active: bool = false
var _reflect_value: float = 0.0
var _reflect_timer: float = 0.0

# ── Shared (defensive/utility) abilities ──
var _shared_abilities: Array = []

# ── Channeled ability state ──
var _channeling: bool = false
var _channel_target: Node = null
var _channel_hits_remaining: int = 0
var _channel_timer: float = 0.0
var _channel_interval: float = 0.0
var _channel_hit_mult: float = 1.0
var _channel_style: String = ""
var _channel_elapsed: float = 0.0
var _channel_total_duration: float = 0.0

# ── Weapon special attack cooldown tracking ──
# Cooldowns are stored in GameState.weapon_special_cooldowns so the HUD can read them

# ── Regen settings ──
const REGEN_INTERVAL: float = 5.0    ## Seconds between passive HP/energy ticks
const REGEN_HP_PERCENT: float = 0.02 ## 2% max HP per tick (out of combat only)
const REGEN_ENERGY_RATE: float = 5.0 ## Flat energy per tick

# ── Adrenaline settings (RS3-style) ──
const ADRENALINE_PER_AUTO: float = 3.0   ## Gained per auto-attack hit
const ADRENALINE_PER_BASIC: float = 8.0  ## Gained per basic ability hit
const ADRENALINE_DECAY: float = 2.0      ## Lost per second out of combat (gentle drain)
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
const COMBAT_EXIT_DELAY: float = 15.0 ## Seconds without combat to start regen/adrenaline decay

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
	# Reset per-frame flag
	_ability_fired_this_frame = false

	# Update target indicator position
	if target and is_instance_valid(target) and target.state != target.State.DEAD:
		_target_indicator.visible = true
		_target_indicator.global_position = target.global_position
		_target_indicator.global_position.y = target.global_position.y + 0.05
	else:
		_target_indicator.visible = false
		if target and (not is_instance_valid(target) or target.state == target.State.DEAD):
			_clear_target()

	# ── Tick down ability queue timeout ──
	if _queued_ability_slot > 0:
		_queued_ability_timeout -= delta
		if _queued_ability_timeout <= 0.0:
			_queued_ability_slot = -1  # Queue expired

	# ── Tick down GCD ──
	if _gcd_timer > 0:
		_gcd_timer -= delta

	# ── Tick down per-ability cooldowns ──
	if not _ability_cooldowns.is_empty():
		var expired: Array[String] = []
		for ab_id in _ability_cooldowns:
			_ability_cooldowns[ab_id] -= delta
			if _ability_cooldowns[ab_id] <= 0:
				expired.append(ab_id)
		for ab_id in expired:
			_ability_cooldowns.erase(ab_id)

	# ── Tick down weapon special cooldowns ──
	if not GameState.weapon_special_cooldowns.is_empty():
		var ws_expired: Array[String] = []
		for ws_id in GameState.weapon_special_cooldowns:
			GameState.weapon_special_cooldowns[ws_id] -= delta
			if GameState.weapon_special_cooldowns[ws_id] <= 0:
				ws_expired.append(ws_id)
		for ws_id in ws_expired:
			GameState.weapon_special_cooldowns.erase(ws_id)

	# ── Tick down adrenaline gain multiplier (Natural Instinct) ──
	if _adrenaline_gain_timer > 0:
		_adrenaline_gain_timer -= delta
		if _adrenaline_gain_timer <= 0:
			_adrenaline_gain_mult = 1.0
			EventBus.chat_message.emit("Natural Instinct has worn off.", "combat")

	# ── Tick down defensive buffs ──
	if _resonance_timer > 0:
		_resonance_timer -= delta
		if _resonance_timer <= 0:
			_resonance_active = false
	if _reflect_timer > 0:
		_reflect_timer -= delta
		if _reflect_timer <= 0:
			_reflect_active = false
			EventBus.chat_message.emit("Reflect has worn off.", "combat")

	# ── Channel tick ──
	if _channeling:
		# Cancel if target died or moved out of range
		if _channel_target == null or not is_instance_valid(_channel_target):
			_cancel_channel("Channel interrupted — target lost!")
		elif _channel_target.state == _channel_target.State.DEAD:
			_cancel_channel("Channel complete — target defeated!")
		elif _player.is_moving:
			_cancel_channel("Channel interrupted — you moved!")
		else:
			_channel_elapsed += delta
			_channel_timer -= delta
			if _channel_timer <= 0:
				_channel_do_hit()
				_channel_hits_remaining -= 1
				if _channel_hits_remaining <= 0:
					_channeling = false
					_gcd_timer = GCD_TIME  # Resume normal GCD after channel ends
					EventBus.chat_message.emit("Channel complete!", "combat")
				else:
					_channel_timer = _channel_interval

	# ── Fire queued ability as soon as GCD expires ──
	if _queued_ability_slot > 0 and _gcd_timer <= 0:
		var queued_slot: int = _queued_ability_slot
		_queued_ability_slot = -1  # Clear before firing (prevents re-queue loop)
		use_ability(queued_slot)
		# use_ability sets _ability_fired_this_frame = true on success

	# ── Revolution: auto-fire basic abilities when GCD is free and no queue ──
	if GameState.settings.get("revolution", false) and _gcd_timer <= 0 and _queued_ability_slot <= 0 and not _ability_fired_this_frame:
		if target and is_instance_valid(target) and target.state != target.State.DEAD:
			# Build list of usable basic ability slots (no individual CD)
			var basics: Array[int] = []
			for idx in range(_active_abilities.size()):
				var rev_ab: Dictionary = _active_abilities[idx]
				if str(rev_ab.get("tier", "")) == "basic":
					var rev_id: String = str(rev_ab.get("id", ""))
					if not _ability_cooldowns.has(rev_id):
						basics.append(idx + 1)  # 1-based slot
			if basics.size() > 0:
				_revolution_slot_index = _revolution_slot_index % basics.size()
				if use_ability(basics[_revolution_slot_index]):
					_revolution_slot_index += 1

	# ── Auto-attack (use XZ distance so large boss Y offset doesn't prevent melee) ──
	if target and is_instance_valid(target) and target.state != target.State.DEAD:
		var to_target_xz: Vector2 = Vector2(target.global_position.x - _player.global_position.x, target.global_position.z - _player.global_position.z)
		var dist: float = to_target_xz.length()
		# Extend attack range by the target's collision radius so large bosses are reachable
		var effective_range: float = attack_range + _get_target_collision_radius(target)
		if dist <= effective_range:
			# Stop the player from walking into the enemy — hold position at range
			if _player.is_moving:
				_player.stop_movement()
			is_in_combat = true
			_combat_exit_timer = 0.0
			attack_timer -= delta
			# Only auto-attack if no ability fired this tick (ability replaces auto)
			if attack_timer <= 0 and not _ability_fired_this_frame:
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

## Raycast from click to find an enemy or ground item
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
	query.collision_mask = 4 | 16  # Enemy layer (3) + Ground items layer (5)
	query.exclude = [_player.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		var hit_node: Node = result.collider

		# Walk up to find the entity root
		var check_node: Node = hit_node
		while check_node:
			# Ground item — walk to it and pick up
			if check_node.is_in_group("ground_items"):
				_player.move_target = check_node.global_position
				_player.is_moving = true
				EventBus.ground_item_pickup_requested.emit(check_node)
				_player.get_viewport().set_input_as_handled()
				return
			# Enemy — target and walk toward
			if check_node.is_in_group("enemies"):
				_set_target(check_node)
				if _player.has_method("stop_movement"):
					_player.stop_movement()
				_player.move_target = check_node.global_position
				_player.is_moving = true
				_player.get_viewport().set_input_as_handled()
				return
			check_node = check_node.get_parent()

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
	if _channeling:
		return
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

	# Apply food/consumable damage buff
	var food_dmg_buff: float = GameState.get_buff_value("damage")
	if food_dmg_buff > 0:
		total_damage += int(food_dmg_buff)

	# Apply set bonus damage
	var equip_sys: Node = _player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("get_set_bonus_damage"):
		total_damage += equip_sys.get_set_bonus_damage()

	# Dungeon: Berserker — player deals +20% damage
	if _has_dungeon_modifier("berserker"):
		total_damage = int(float(total_damage) * 1.2)

	# Small random variance (±15%)
	var variance: float = randf_range(0.85, 1.15)
	total_damage = int(float(total_damage) * variance)

	# ── Offhand bonuses (auto-attacks) ──
	var oh_data: Dictionary = _get_offhand_data()
	var oh_type: String = _get_offhand_type(oh_data) if not oh_data.is_empty() else ""

	# Capacitor: reduce miss chance by 1% per accuracy point (accuracy stat on item)
	var miss_chance: float = 0.05
	if oh_type == "capacitor":
		var oh_acc: int = int(oh_data.get("accuracy", 0))
		miss_chance = maxf(0.0, miss_chance - float(oh_acc) * 0.01)

	# Set bonus accuracy: reduce miss chance by 0.5% per accuracy point
	if equip_sys and equip_sys.has_method("get_set_bonus_accuracy"):
		var set_acc: int = equip_sys.get_set_bonus_accuracy()
		if set_acc > 0:
			miss_chance = maxf(0.0, miss_chance - float(set_acc) * 0.005)

	# Accuracy check
	if miss_chance > 0 and randf() < miss_chance:
		EventBus.hit_missed.emit(target)
		EventBus.float_text_requested.emit("Miss", target.global_position + Vector3(0, 2.5, 0), Color(0.5, 0.5, 0.5))
		return

	# Orb: chance to trigger bonus void damage (15% chance, adds offhand damage again)
	if oh_type == "orb":
		var oh_dmg: int = int(oh_data.get("damage", 0))
		if oh_dmg > 0 and randf() < 0.15:
			total_damage += oh_dmg
			EventBus.float_text_requested.emit(
				"Void!", _player.global_position + Vector3(-0.3, 3.2, 0),
				Color(0.6, 0.2, 0.9)
			)

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
	_last_attack_style = style
	var actual: int = target.take_damage(total_damage, style)

	# Build adrenaline (small amount from auto-attacks, like RS3)
	GameState.player["adrenaline"] = minf(ADRENALINE_MAX, float(GameState.player["adrenaline"]) + ADRENALINE_PER_AUTO * _adrenaline_gain_mult)

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

	# Trigger attack animation
	EventBus.player_attacked.emit()

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

	# Get heal amount (items use "heals", "healAmount", or "heal" field)
	var heal: int = int(item_data.get("heals", item_data.get("healAmount", item_data.get("heal", 0))))
	if heal <= 0:
		return false

	# Consume the item
	GameState.remove_item(item_id, 1)

	# Heal
	var max_hp: int = int(GameState.player["max_hp"])
	var old_hp: int = int(GameState.player["hp"])
	GameState.player["hp"] = mini(max_hp, old_hp + heal)
	var actual_heal: int = int(GameState.player["hp"]) - old_hp

	# Apply food buff if defined
	var item_name: String = str(item_data.get("name", item_id))
	var buff_data: Dictionary = item_data.get("buff", {})
	var buff_msg: String = ""
	if not buff_data.is_empty():
		var buff_type: String = str(buff_data.get("type", ""))
		var buff_value: float = float(buff_data.get("value", 0))
		var buff_duration: float = float(buff_data.get("duration", 60))
		if buff_type != "" and buff_value > 0:
			GameState.apply_buff(buff_type, buff_value, buff_duration, item_name)
			var dur_text: String = "%ds" % int(buff_duration) if buff_duration < 120 else "%dm" % int(buff_duration / 60.0)
			buff_msg = " (+%.0f %s, %s)" % [buff_value, buff_type, dur_text]

	# Feedback
	EventBus.chat_message.emit("Ate %s, healed %d HP.%s" % [item_name, actual_heal, buff_msg], "combat")
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
		var h: int = int(data.get("heals", data.get("healAmount", data.get("heal", 0))))
		if h > best_heal:
			best_heal = h
			best_id = sid
	return best_id

# ── Abilities (adrenaline-based, data-driven) ──

## Cached active abilities for current style (refreshed on style change)
var _active_abilities: Array = []

## Get remaining cooldown for a specific ability (0.0 if not on cooldown)
func get_ability_cooldown(ability_id: String) -> float:
	return _ability_cooldowns.get(ability_id, 0.0)

## Refresh abilities from DataManager for current combat style
func refresh_abilities() -> void:
	var style: String = str(GameState.player.get("combat_style", "nano"))
	_active_abilities = DataManager.get_abilities_for_style(style)
	_active_abilities.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	# Apply custom ability bar order if set for this style
	var bar_orders: Dictionary = GameState.settings.get("ability_bar_order", {})
	if bar_orders is Dictionary:
		var style_order: Array = bar_orders.get(style, [])
		if style_order.size() > 0:
			var reordered: Array = []
			for ab_id in style_order:
				for ab in _active_abilities:
					if str(ab.get("id", "")) == str(ab_id):
						reordered.append(ab)
						break
			# Append any abilities not in the custom order (e.g. newly added abilities)
			for ab in _active_abilities:
				if not reordered.has(ab):
					reordered.append(ab)
			_active_abilities = reordered
	# Also load shared (defensive/utility) abilities
	if DataManager.has_method("get_shared_abilities"):
		_shared_abilities = DataManager.get_shared_abilities()

## Use a defensive/shared ability by defense slot index (1-based)
func use_defensive_ability(defense_slot: int) -> bool:
	var idx: int = defense_slot - 1
	if idx < 0 or idx >= _shared_abilities.size():
		return false
	return _fire_shared_ability(_shared_abilities[idx])

## Fire a shared/defensive ability (may not require a target)
func _fire_shared_ability(ab: Dictionary) -> bool:
	var ability_name: String = str(ab.get("name", "Ability"))
	var ab_id: String = str(ab.get("id", ""))
	var ab_cd: float = float(ab.get("cooldown", 0))

	# Check per-ability cooldown
	if ab_cd > 0 and _ability_cooldowns.has(ab_id):
		EventBus.chat_message.emit("%s on cooldown (%.1fs)." % [ability_name, _ability_cooldowns[ab_id]], "combat")
		return false

	# Check GCD
	if _gcd_timer > 0:
		EventBus.chat_message.emit("%s — waiting for GCD." % ability_name, "combat")
		return false

	var adrenaline: float = float(GameState.player["adrenaline"])
	var cost: float = float(ab.get("adr_cost", 0))
	var adr_gain: float = float(ab.get("adr_gain", 0))
	var effects: Array = ab.get("effects", [])

	if adrenaline < cost:
		EventBus.chat_message.emit("Not enough adrenaline (%d/%d)." % [int(adrenaline), int(cost)], "combat")
		return false

	# Spend or gain adrenaline
	if cost > 0:
		GameState.player["adrenaline"] = adrenaline - cost
	elif adr_gain > 0:
		GameState.player["adrenaline"] = minf(ADRENALINE_MAX, adrenaline + adr_gain * _adrenaline_gain_mult)

	# Debilitate needs a target — apply debuff to current target
	var primary_target: Node = target if target and is_instance_valid(target) else null
	var target_pos: Vector3 = _player.global_position
	if primary_target:
		target_pos = (primary_target as Node3D).global_position

	# Apply effects (self-targeted abilities like Resonance, Reflect, Freedom work without target)
	var style: String = str(GameState.player["combat_style"])
	_apply_ability_effects(effects, primary_target, target_pos, 0, style, Color(0.3, 1.0, 0.5))

	# Set GCD and per-ability cooldown
	_gcd_timer = GCD_TIME
	_ability_fired_this_frame = true
	if ab_cd > 0:
		_ability_cooldowns[ab_id] = ab_cd

	# Chat feedback
	EventBus.chat_message.emit("%s activated!" % ability_name, "combat")

	# Animation
	EventBus.player_attacked.emit()

	return true

## Use the equipped weapon's special attack (T5+ weapons only)
func use_weapon_special() -> bool:
	# Block during channeling
	if _channeling:
		EventBus.chat_message.emit("Cannot use weapon special while channeling!", "combat")
		return false

	# Get equipped weapon
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		EventBus.chat_message.emit("No weapon equipped.", "system")
		return false

	var weapon_data: Dictionary = DataManager.get_item(weapon_id)
	if weapon_data.is_empty():
		return false

	var special_raw: Variant = weapon_data.get("special", {})
	if not special_raw is Dictionary or (special_raw as Dictionary).is_empty():
		EventBus.chat_message.emit("Your weapon has no special attack.", "system")
		return false
	var special: Dictionary = special_raw as Dictionary

	var spec_name: String = str(special.get("name", "Special"))
	var spec_cost: float = float(special.get("adr_cost", 25))
	var spec_cd: float = float(special.get("cooldown", 30))
	var spec_dmg_mult: float = float(special.get("damage_mult", 2.0))
	var effects: Array = special.get("effects", [])

	# Check cooldown
	if GameState.weapon_special_cooldowns.has(weapon_id):
		EventBus.chat_message.emit("%s on cooldown (%.1fs)." % [spec_name, GameState.weapon_special_cooldowns[weapon_id]], "combat")
		return false

	# Check GCD
	if _gcd_timer > 0:
		EventBus.chat_message.emit("%s — waiting for GCD." % spec_name, "combat")
		return false

	# Need a target for damage-dealing specials
	if target == null or not is_instance_valid(target):
		EventBus.chat_message.emit("No target selected.", "system")
		return false
	if target.state == target.State.DEAD:
		return false

	# Check adrenaline
	var adrenaline: float = float(GameState.player["adrenaline"])
	if adrenaline < spec_cost:
		EventBus.chat_message.emit("Not enough adrenaline (%d/%d)." % [int(adrenaline), int(spec_cost)], "combat")
		return false

	# Spend adrenaline
	GameState.player["adrenaline"] = adrenaline - spec_cost

	# Calculate damage
	var weapon_damage: int = _get_weapon_damage()
	var total_damage: int = int(float(base_damage + weapon_damage) * spec_dmg_mult)

	# Apply prestige bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		total_damage = int(float(total_damage) * float(bonuses.get("damage_mult", 1.0)))

	# Dungeon: Berserker bonus
	if _has_dungeon_modifier("berserker"):
		total_damage = int(float(total_damage) * 1.2)

	# Capture position
	var target_pos: Vector3 = (target as Node3D).global_position
	var style: String = str(GameState.player.get("combat_style", "nano"))
	_last_attack_style = style

	# Deal primary damage
	var actual: int = target.take_damage(total_damage, style)

	# Gold color for weapon specials
	var spec_color: Color = Color(1.0, 0.85, 0.1)

	# Feedback
	EventBus.chat_message.emit("%s hit for %d!" % [spec_name, actual], "combat")
	EventBus.float_text_requested.emit(
		"%s %d" % [spec_name, actual],
		target_pos + Vector3(randf_range(-0.5, 0.5), 3.2, 0),
		spec_color
	)

	# Apply special effects (AoE, stun, debuff, etc.)
	_apply_ability_effects(effects, target, target_pos, total_damage, style, spec_color)

	# Set cooldowns
	GameState.weapon_special_cooldowns[weapon_id] = spec_cd
	_gcd_timer = GCD_TIME
	_ability_fired_this_frame = true

	# Screen shake
	var cam_rig: Node = _player.get_node_or_null("CameraRig")
	if cam_rig and cam_rig.has_method("shake"):
		cam_rig.shake(0.6)

	# Impact ring
	_spawn_impact_ring(target_pos, spec_color, 3)

	# Face target
	var to_target: Vector3 = target_pos - _player.global_position
	if to_target.length() > 0.1:
		_player.rotation.y = atan2(-to_target.x, -to_target.z)

	# Animation
	EventBus.player_attacked.emit()

	return true

## Get the weapon special cooldown remaining for current weapon (0.0 if none)
func get_weapon_special_cooldown() -> float:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 0.0
	return GameState.weapon_special_cooldowns.get(weapon_id, 0.0)

## Get the weapon special data for current weapon (empty dict if none)
func get_weapon_special_data() -> Dictionary:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return {}
	var weapon_data: Dictionary = DataManager.get_item(weapon_id)
	if weapon_data.is_empty():
		return {}
	var special: Variant = weapon_data.get("special", {})
	if special is Dictionary:
		return special
	return {}

## Use style-based ability (data-driven from abilities.json).
## Slot 1-5 corresponds to current style's abilities sorted by slot.
## If GCD is active, queues the ability to fire when GCD expires (RS3-style).
func use_ability(ability_slot: int) -> bool:
	# Block during channeling
	if _channeling:
		EventBus.chat_message.emit("Cannot use abilities while channeling!", "combat")
		return false

	if target == null or not is_instance_valid(target):
		EventBus.chat_message.emit("No target selected.", "system")
		return false
	if target.state == target.State.DEAD:
		return false

	# Refresh if empty
	if _active_abilities.is_empty():
		refresh_abilities()

	# Find the ability for this slot (need name before GCD check for queue message)
	var slot_idx: int = ability_slot - 1
	if slot_idx < 0 or slot_idx >= _active_abilities.size():
		return false

	var ab: Dictionary = _active_abilities[slot_idx]
	var ability_name: String = str(ab.get("name", "Ability"))

	# Check per-ability cooldown — hard block, do NOT queue
	var ab_id: String = str(ab.get("id", ""))
	var ab_cooldown: float = float(ab.get("cooldown", 0))
	if ab_cooldown > 0 and _ability_cooldowns.has(ab_id):
		EventBus.chat_message.emit("%s on cooldown (%.1fs)." % [ability_name, _ability_cooldowns[ab_id]], "combat")
		return false

	# Check GCD — if active, queue this ability instead of rejecting
	if _gcd_timer > 0:
		_queued_ability_slot = ability_slot
		_queued_ability_timeout = QUEUE_TIMEOUT
		return false

	var adrenaline: float = float(GameState.player["adrenaline"])
	var cost: float = float(ab.get("adr_cost", 0))
	var adr_gain: float = float(ab.get("adr_gain", 0))
	var tier: String = str(ab.get("tier", "basic"))
	var ability_style: String = str(ab.get("style", ""))
	var style: String = ability_style if ability_style != "shared" and ability_style != "" else str(GameState.player["combat_style"])
	_last_attack_style = style
	var effects: Array = ab.get("effects", [])

	if adrenaline < cost:
		EventBus.chat_message.emit("Not enough adrenaline (%d/%d)." % [int(adrenaline), int(cost)], "combat")
		return false

	# Spend or gain adrenaline (apply gain multiplier for basics)
	if cost > 0:
		GameState.player["adrenaline"] = adrenaline - cost
	elif adr_gain > 0:
		GameState.player["adrenaline"] = minf(ADRENALINE_MAX, adrenaline + adr_gain * _adrenaline_gain_mult)

	# Calculate damage using range (damage_min to damage_max) or flat mult fallback
	var damage_min_val: float = float(ab.get("damage_min", 0))
	var damage_max_val: float = float(ab.get("damage_max", 0))
	var damage_mult: float
	if damage_min_val > 0 and damage_max_val > 0:
		damage_mult = randf_range(damage_min_val, damage_max_val)
	else:
		damage_mult = float(ab.get("damage_mult", 1.0))

	var weapon_damage: int = _get_weapon_damage()
	var total_damage: int = int(float(base_damage + weapon_damage) * damage_mult)

	# Apply prestige damage bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		total_damage = int(float(total_damage) * float(bonuses.get("damage_mult", 1.0)))

	# Dungeon: Berserker — player deals +20% damage
	if _has_dungeon_modifier("berserker"):
		total_damage = int(float(total_damage) * 1.2)

	# Ability crit check — top 15% of range, 10% chance → 1.5x damage
	var is_ability_crit: bool = false
	if damage_min_val > 0 and damage_max_val > 0:
		var crit_threshold: float = damage_max_val - (damage_max_val - damage_min_val) * 0.15
		if damage_mult >= crit_threshold and randf() < 0.10:
			is_ability_crit = true
			total_damage = int(float(total_damage) * 1.5)

	# Capture position
	var target_pos: Vector3 = (target as Node3D).global_position

	# Deal primary damage
	var actual: int = target.take_damage(total_damage, style)

	# Tier-based color (gold for crits)
	var ability_color: Color
	if is_ability_crit:
		ability_color = Color(1.0, 0.85, 0.1)  # Gold for crit
	else:
		match tier:
			"basic": ability_color = Color(0.3, 0.9, 1.0)
			"threshold": ability_color = Color(1.0, 0.6, 0.1)
			"ultimate": ability_color = Color(1.0, 0.2, 0.9)
			_: ability_color = Color.WHITE

	# Feedback
	var crit_suffix: String = "!" if is_ability_crit else ""
	EventBus.chat_message.emit("%s hit for %d%s" % [ability_name, actual, "! (CRIT)" if is_ability_crit else "!"], "combat")
	EventBus.float_text_requested.emit(
		"%s %d%s" % [ability_name, actual, crit_suffix],
		target_pos + Vector3(randf_range(-0.5, 0.5), 3.0, 0),
		ability_color
	)

	# Camera shake for ability crits (basic abilities only — threshold/ultimate already shake)
	if is_ability_crit and tier == "basic":
		var cam_rig: Node = _player.get_node_or_null("CameraRig")
		if cam_rig and cam_rig.has_method("shake"):
			cam_rig.shake(0.3)

	# Apply special effects
	_apply_ability_effects(effects, target, target_pos, total_damage, style, ability_color)

	# Record ability/ultimate use for achievements
	var ach_sys: Node = get_tree().get_first_node_in_group("achievement_system")
	if ach_sys:
		if tier == "ultimate":
			ach_sys.record_ultimate_use()
		else:
			ach_sys.record_ability_use()

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

	# Reset attack timer and start GCD — ability replaces the next auto-attack
	attack_timer = base_attack_speed
	_gcd_timer = GCD_TIME
	_ability_fired_this_frame = true  # Suppress auto-attack this tick

	# Set per-ability cooldown (if ability has one beyond GCD)
	if ab_cooldown > 0:
		_ability_cooldowns[ab_id] = ab_cooldown

	# Face target
	var to_target: Vector3 = target_pos - _player.global_position
	if to_target.length() > 0.1:
		_player.rotation.y = atan2(-to_target.x, -to_target.z)

	# Trigger attack animation
	EventBus.player_attacked.emit()

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

			"natural_instinct":
				# Double adrenaline gain from all sources for a duration
				var ni_duration: float = float(effect.get("duration", 20.0))
				var ni_mult: float = float(effect.get("adr_mult", 2.0))
				_adrenaline_gain_mult = ni_mult
				_adrenaline_gain_timer = ni_duration
				EventBus.chat_message.emit("Natural Instinct active! Adrenaline gain x%.0f for %.0fs." % [ni_mult, ni_duration], "combat")
				EventBus.float_text_requested.emit(
					"Natural Instinct!",
					_player.global_position + Vector3(0, 3.5, 0),
					Color(0.2, 1.0, 0.6)
				)

			"resonance":
				# Next incoming hit heals instead of damages
				_resonance_active = true
				_resonance_timer = float(effect.get("duration", 30.0))
				EventBus.chat_message.emit("Resonance active — next hit will heal you.", "combat")
				EventBus.float_text_requested.emit(
					"Resonance!",
					_player.global_position + Vector3(0, 3.5, 0),
					Color(0.3, 1.0, 0.5)
				)

			"reflect":
				# Reflect damage back to attackers
				_reflect_active = true
				_reflect_value = float(effect.get("value", 0.5))
				_reflect_timer = float(effect.get("duration", 10.0))
				EventBus.chat_message.emit("Reflect active — %.0f%% damage reflected for %.0fs." % [_reflect_value * 100.0, _reflect_timer], "combat")
				EventBus.float_text_requested.emit(
					"Reflect!",
					_player.global_position + Vector3(0, 3.5, 0),
					Color(0.7, 0.4, 1.0)
				)

			"freedom":
				# Clear DoTs and stuns on the player
				# DoTs are tracked on enemy side, so freedom clears player debuff tracking
				EventBus.chat_message.emit("Freedom! Stuns and binds cleared.", "combat")
				EventBus.float_text_requested.emit(
					"Freedom!",
					_player.global_position + Vector3(0, 3.5, 0),
					Color(0.9, 0.9, 0.2)
				)

			"channel":
				# Start channeled ability — multiple hits over time
				_channeling = true
				_channel_target = primary_target
				_channel_hits_remaining = int(effect.get("hits", 3))
				_channel_interval = float(effect.get("interval", 1.0))
				_channel_hit_mult = float(effect.get("hit_mult", 1.0))
				_channel_timer = _channel_interval
				_channel_style = style
				_channel_total_duration = float(effect.get("hits", 3)) * float(effect.get("interval", 1.0))
				_channel_elapsed = 0.0
				_gcd_timer = 999.0  # Pause GCD during channel
				EventBus.chat_message.emit("Channeling... don't move!", "combat")

## Execute one hit of a channeled ability
func _channel_do_hit() -> void:
	if _channel_target == null or not is_instance_valid(_channel_target):
		_cancel_channel("Channel interrupted — target lost!")
		return

	var weapon_damage: int = _get_weapon_damage()
	var hit_dmg: int = maxi(1, int(float(base_damage + weapon_damage) * _channel_hit_mult * randf_range(0.9, 1.1)))

	# Apply prestige bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		hit_dmg = int(float(hit_dmg) * float(bonuses.get("damage_mult", 1.0)))

	var actual: int = _channel_target.take_damage(hit_dmg, _channel_style)
	_last_attack_style = _channel_style

	EventBus.float_text_requested.emit(
		str(actual),
		_channel_target.global_position + Vector3(randf_range(-0.5, 0.5), 2.8, 0),
		Color(1.0, 0.7, 0.2)  # Orange for channel hits
	)
	EventBus.player_attacked.emit()
	_combat_exit_timer = 0.0

## Cancel a channeled ability
func _cancel_channel(reason: String) -> void:
	_channeling = false
	_channel_hits_remaining = 0
	_gcd_timer = GCD_TIME  # Resume normal GCD
	EventBus.chat_message.emit(reason, "combat")

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

## Get total armor from equipped gear (includes set bonus)
func _get_total_armor() -> int:
	var equip_sys: Node = _player.get_node_or_null("EquipmentSystem")
	var total: int = 0
	if equip_sys:
		if equip_sys.has_method("get_total_armor"):
			total += equip_sys.get_total_armor()
		if equip_sys.has_method("get_set_bonus_armor"):
			total += equip_sys.get_set_bonus_armor()
	return total

## Get the offhand item data dictionary (empty if nothing equipped).
func _get_offhand_data() -> Dictionary:
	var equip_sys: Node = _player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("get_offhand_stats"):
		return equip_sys.get_offhand_stats()
	return {}

## Determine offhand category from the item name/id.
## Returns "shield", "capacitor", "orb", or "" if unknown.
func _get_offhand_type(offhand: Dictionary) -> String:
	var item_name: String = str(offhand.get("name", "")).to_lower()
	var item_id: String = str(offhand.get("id", str(GameState.equipment.get("offhand", "")))).to_lower()
	if "shield" in item_name or "shield" in item_id:
		return "shield"
	elif "capacitor" in item_name or "capacitor" in item_id:
		return "capacitor"
	elif "orb" in item_name or "orb" in item_id:
		return "orb"
	return ""

## Handle incoming damage from enemies
func _on_hit_landed(hit_target: Node, dmg: int, _is_crit: bool, attacker: Node = null) -> void:
	# Only process if the target is the player
	if hit_target != _player:
		return

	# ── Resonance: convert damage to healing ──
	if _resonance_active:
		_resonance_active = false
		_resonance_timer = 0.0
		var heal_amount: int = dmg
		var max_hp: int = int(GameState.player["max_hp"])
		var old_hp: int = int(GameState.player["hp"])
		GameState.player["hp"] = mini(max_hp, old_hp + heal_amount)
		var actual_heal: int = int(GameState.player["hp"]) - old_hp
		EventBus.float_text_requested.emit(
			"💚 +%d" % actual_heal,
			_player.global_position + Vector3(0, 3.2, 0),
			Color(0.3, 1.0, 0.5)
		)
		EventBus.chat_message.emit("Resonance healed you for %d!" % actual_heal, "combat")
		if actual_heal > 0:
			EventBus.player_healed.emit(actual_heal)
		_combat_exit_timer = 0.0
		return  # No damage taken

	# ── Shield block check ──
	# Shields give a % chance to block, reducing damage by offhand armor value
	var offhand: Dictionary = _get_offhand_data()
	if not offhand.is_empty() and _get_offhand_type(offhand) == "shield":
		var oh_armor: int = int(offhand.get("armor", 0))
		# Block chance scales with offhand armor: 5% base + 0.5% per armor point (cap 30%)
		var block_chance: float = minf(0.30, 0.05 + float(oh_armor) * 0.005)
		if randf() < block_chance:
			var blocked: int = maxi(1, int(float(dmg) * 0.5))  # Block absorbs 50% of raw hit
			dmg = maxi(1, dmg - blocked)
			EventBus.float_text_requested.emit(
				"🛡 Blocked!", _player.global_position + Vector3(0.3, 3.2, 0),
				Color(0.3, 0.7, 1.0)
			)

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

	# Apply food/consumable defense buff
	var food_def_buff: float = GameState.get_buff_value("defense")
	if food_def_buff > 0:
		actual = maxi(1, actual - int(food_def_buff))

	# Dungeon: Berserker — player takes +15% more damage
	if _has_dungeon_modifier("berserker"):
		actual = int(float(actual) * 1.15)

	GameState.player["hp"] -= actual
	GameState.player["hp"] = maxi(0, GameState.player["hp"])

	# ── Reflect: deal portion of damage back to attacker ──
	if _reflect_active and attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		var reflected: int = int(float(actual) * _reflect_value)
		if reflected > 0:
			var style: String = str(GameState.player["combat_style"])
			attacker.take_damage(reflected, style)
			EventBus.float_text_requested.emit(
				"↩ %d" % reflected,
				attacker.global_position + Vector3(randf_range(-0.3, 0.3), 2.8, 0),
				Color(0.7, 0.4, 1.0)
			)

	# Build a small adrenaline on being hit
	GameState.player["adrenaline"] = minf(ADRENALINE_MAX, float(GameState.player["adrenaline"]) + 3.0 * _adrenaline_gain_mult)
	_combat_exit_timer = 0.0

	EventBus.player_damaged.emit(actual, "enemy")
	EventBus.float_text_requested.emit(str(actual), _player.global_position + Vector3(randf_range(-0.3, 0.3), 2.8, 0), Color(0.9, 0.1, 0.1))

	# Death check
	if GameState.player["hp"] <= 0:
		_player_death()

## Fraction of carried credits lost on death
const DEATH_CREDIT_PENALTY: float = 0.10
## Number of random inventory items dropped as ground items on death
const DEATH_ITEM_DROP_COUNT: int = 3

## Handle player death
func _player_death() -> void:
	_clear_target()
	GameState.player["adrenaline"] = 0.0
	EventBus.player_died.emit()

	# ── Death penalties (applied before teleport so items drop at death location) ──
	var death_pos: Vector3 = _player.global_position
	_apply_death_penalty(death_pos)

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
	# Clear any active food buffs on death
	GameState.active_buffs.clear()
	EventBus.player_respawned.emit()
	EventBus.float_text_requested.emit("Respawned!", _player.global_position + Vector3(0, 3.0, 0), Color(0.3, 1.0, 0.5))

## Apply death penalties: lose 10% credits and drop up to 3 random items at death location.
## Items that are equipped or quest-related are never dropped.
func _apply_death_penalty(death_pos: Vector3) -> void:
	# ── Credit penalty ──
	var credits: int = int(GameState.player["credits"])
	if credits > 0:
		var lost: int = maxi(1, int(float(credits) * DEATH_CREDIT_PENALTY))
		GameState.add_credits(-lost)
		EventBus.chat_message.emit("Lost %d credits on death." % lost, "combat")

	# ── Item drops ──
	if GameState.inventory.is_empty():
		return

	# Collect droppable slot indices (skip quest items and equipped)
	var droppable: Array[int] = []
	for i in range(GameState.inventory.size()):
		var slot: Dictionary = GameState.inventory[i]
		var item_id: String = str(slot.get("item_id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_type: String = str(item_data.get("type", ""))
		# Never drop quest items, tools, or keys
		if item_type == "quest" or item_type == "key":
			continue
		droppable.append(i)

	if droppable.is_empty():
		return

	# Shuffle and pick up to DEATH_ITEM_DROP_COUNT items
	droppable.shuffle()
	var to_drop: int = mini(DEATH_ITEM_DROP_COUNT, droppable.size())
	# Process in reverse index order so removals don't shift later indices
	var indices_to_drop: Array[int] = []
	for i in range(to_drop):
		indices_to_drop.append(droppable[i])
	indices_to_drop.sort()
	indices_to_drop.reverse()

	for idx in indices_to_drop:
		var slot: Dictionary = GameState.inventory[idx]
		var item_id: String = str(slot.get("item_id", ""))
		var qty: int = int(slot.get("quantity", 1))
		# Drop only 1 from the stack
		var drop_qty: int = 1
		GameState.remove_item(item_id, drop_qty)
		EventBus.item_dropped_to_ground.emit(item_id, drop_qty, death_pos)
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_name: String = str(item_data.get("name", item_id))
		EventBus.chat_message.emit("Dropped %s on death." % item_name, "combat")

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
			# Track boss kill for achievements
			if not GameState.boss_kills.has(eid):
				GameState.boss_kills[eid] = 0
			GameState.boss_kills[eid] += 1

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

		# Award XP to the style that was last used (ability's style, not just equipped)
		var skill: String = _last_attack_style if _last_attack_style != "" else str(GameState.player["combat_style"])
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

	# Dungeon: Treasure — +50% loot quantity
	var treasure_active: bool = _has_dungeon_modifier("treasure")

	for drop in loot:
		var item_id: String = str(drop.get("item_id", ""))
		var qty: int = int(drop.get("quantity", 1))
		if treasure_active:
			qty = int(float(qty) * 1.5)
			qty = maxi(qty, 1)
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
			if npc.has_method("_walk_then_act"):
				npc._walk_then_act(func():
					var hud: Node = get_tree().get_first_node_in_group("hud")
					if hud and hud.has_method("open_dialogue"):
						hud.open_dialogue(npc)
				)
			else:
				_player.move_target = npc.global_position
				_player.is_moving = true
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
			# Walk to the item and request pickup when in range
			_player.move_target = gitem.global_position
			_player.is_moving = true
			EventBus.ground_item_pickup_requested.emit(gitem)
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


# ──────────────────────────────────────────────
#  Dungeon modifier helpers (player-side)
# ──────────────────────────────────────────────

## Check if a specific dungeon modifier is active in the current run.
func _has_dungeon_modifier(mod_id: String) -> bool:
	if not GameState.dungeon_active:
		return false
	var dungeon_sys: Node = get_tree().get_first_node_in_group("dungeon_system")
	if dungeon_sys == null or not dungeon_sys.has_method("get_active_modifiers"):
		return false
	for mod in dungeon_sys.get_active_modifiers():
		if str(mod.get("id", "")) == mod_id:
			return true
	return false
