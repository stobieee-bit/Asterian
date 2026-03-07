## BattleSystem — Turn-based creature battle engine
##
## Manages the flow of a wild creature battle: move selection,
## damage calculation, status effects, catching, and rewards.
class_name BattleSystem
extends Node

enum BattleState { IDLE, PLAYER_TURN, ENEMY_TURN, ANIMATING, ENDED }

# ── State ──
var _state: BattleState = BattleState.IDLE
var _player_creature: CreatureInstance = null
var _wild_creature: CreatureInstance = null
var _turn_count: int = 0
var _can_escape: bool = true
var _escape_attempts: int = 0
var _is_trainer_battle: bool = false
var _message_queue: Array[String] = []
var _battle_active: bool = false

# ── Signals (local, for UI binding) ──
signal message_posted(text: String)
signal battle_state_changed(new_state: BattleState)
signal hp_updated(is_player: bool, current: int, max_hp: int)
signal status_changed(is_player: bool, status: String)
signal battle_ended(result: String)
signal xp_awarded(creature: CreatureInstance, amount: int)
signal move_animation_requested(move_id: String, is_player: bool)

# ── Battle flow ──

func start_wild_battle(player_creature: CreatureInstance, wild_id: String, wild_level: int) -> void:
	_player_creature = player_creature
	_wild_creature = CreatureInstance.create(wild_id, wild_level)
	_turn_count = 0
	_escape_attempts = 0
	_battle_active = true
	_player_creature.reset_stat_stages()

	_post_message("A wild %s appeared!" % _wild_creature.nickname)
	_post_message("Go, %s!" % _player_creature.nickname)

	_update_hp(true)
	_update_hp(false)

	EventBus.creature_battle_started.emit(_wild_creature.to_dict())
	_set_state(BattleState.PLAYER_TURN)

func is_active() -> bool:
	return _battle_active

# ── Player actions ──

func select_move(move_index: int) -> void:
	if _state != BattleState.PLAYER_TURN:
		return
	if move_index < 0 or move_index >= _player_creature.known_moves.size():
		return
	var player_move: Dictionary = _player_creature.known_moves[move_index]
	if player_move["current_pp"] <= 0:
		_post_message("No PP left for this move!")
		return
	_set_state(BattleState.ANIMATING)
	_execute_turn(player_move)

func attempt_catch(ball_type: String) -> void:
	if _state != BattleState.PLAYER_TURN:
		return
	if _is_trainer_battle:
		_post_message("You can't catch a trainer's creature!")
		return

	var ball_count: int = int(GameState.creature_bag.get(ball_type, 0))
	if ball_count <= 0:
		_post_message("No %ss left!" % ball_type)
		return

	GameState.creature_bag[ball_type] = ball_count - 1
	_set_state(BattleState.ANIMATING)
	EventBus.pokeball_thrown.emit(ball_type, _wild_creature.to_dict())

	var catch_rate: float = _calculate_catch_rate(ball_type)
	var roll: float = randf()

	_post_message("You threw a %s!" % _format_ball_name(ball_type))

	if roll < catch_rate:
		_post_message("Gotcha! %s was caught!" % _wild_creature.nickname)
		_add_to_party_or_pc(_wild_creature)
		# Update Pokédex
		GameState.pokedex[_wild_creature.creature_id] = { "seen": true, "caught": true }
		EventBus.pokedex_updated.emit(_wild_creature.creature_id)
		EventBus.creature_caught.emit(_wild_creature.to_dict())
		_end_battle("caught")
	else:
		_post_message("Oh no! The creature broke free!")
		_execute_wild_turn()

func attempt_run() -> void:
	if _state != BattleState.PLAYER_TURN:
		return
	_escape_attempts += 1
	var player_speed: int = _player_creature.get_effective_speed()
	var wild_speed: int = _wild_creature.get_effective_speed()
	var escape_chance: float = (float(player_speed) * 128.0 / float(wild_speed) + 30.0 * _escape_attempts) / 256.0
	escape_chance = clampf(escape_chance, 0.1, 1.0)

	_set_state(BattleState.ANIMATING)
	if randf() < escape_chance:
		_post_message("Got away safely!")
		_end_battle("run")
	else:
		_post_message("Can't escape!")
		_execute_wild_turn()

func use_item(item_type: String) -> void:
	if _state != BattleState.PLAYER_TURN:
		return
	var count: int = int(GameState.creature_bag.get(item_type, 0))
	if count <= 0:
		_post_message("No %ss left!" % item_type)
		return

	GameState.creature_bag[item_type] = count - 1
	_set_state(BattleState.ANIMATING)

	match item_type:
		"potion":
			var healed: int = _player_creature.heal(20)
			_post_message("%s recovered %d HP!" % [_player_creature.nickname, healed])
		"super_potion":
			var healed: int = _player_creature.heal(50)
			_post_message("%s recovered %d HP!" % [_player_creature.nickname, healed])
		"hyper_potion":
			var healed: int = _player_creature.heal(200)
			_post_message("%s recovered %d HP!" % [_player_creature.nickname, healed])

	_update_hp(true)
	_execute_wild_turn()

func switch_creature(party_index: int) -> void:
	if _state != BattleState.PLAYER_TURN:
		return
	if party_index < 0 or party_index >= GameState.creature_party.size():
		return
	var new_creature_data: Dictionary = GameState.creature_party[party_index]
	var new_creature: CreatureInstance = CreatureInstance.from_dict(new_creature_data)
	if new_creature.is_fainted:
		_post_message("That creature has fainted!")
		return

	# Save current creature back
	_save_active_creature()

	_post_message("Come back, %s!" % _player_creature.nickname)
	_player_creature = new_creature
	_player_creature.reset_stat_stages()
	_post_message("Go, %s!" % _player_creature.nickname)

	_update_hp(true)
	EventBus.creature_switched.emit(_player_creature.to_dict())
	_set_state(BattleState.ANIMATING)
	_execute_wild_turn()

# ── Turn execution ──

func _execute_turn(player_move: Dictionary) -> void:
	_turn_count += 1
	var player_move_data: Dictionary = DataManager.get_creature_move(player_move["id"])
	var wild_move: Dictionary = _select_wild_move()
	var wild_move_data: Dictionary = DataManager.get_creature_move(wild_move["id"])

	# Determine turn order by speed (with priority moves)
	var player_prio: int = int(player_move_data.get("priority", 0))
	var wild_prio: int = int(wild_move_data.get("priority", 0))
	var player_first: bool = true

	if player_prio != wild_prio:
		player_first = player_prio > wild_prio
	else:
		player_first = _player_creature.get_effective_speed() >= _wild_creature.get_effective_speed()

	if player_first:
		_execute_move(_player_creature, _wild_creature, player_move, player_move_data, true)
		if _check_battle_over():
			return
		_apply_status_damage(_player_creature, true)
		if _check_battle_over():
			return
		_execute_move(_wild_creature, _player_creature, wild_move, wild_move_data, false)
		if _check_battle_over():
			return
		_apply_status_damage(_wild_creature, false)
	else:
		_execute_move(_wild_creature, _player_creature, wild_move, wild_move_data, false)
		if _check_battle_over():
			return
		_apply_status_damage(_wild_creature, false)
		if _check_battle_over():
			return
		_execute_move(_player_creature, _wild_creature, player_move, player_move_data, true)
		if _check_battle_over():
			return
		_apply_status_damage(_player_creature, true)

	_check_battle_over()
	if _battle_active:
		_set_state(BattleState.PLAYER_TURN)

func _execute_wild_turn() -> void:
	if not _battle_active:
		return
	var wild_move: Dictionary = _select_wild_move()
	var wild_move_data: Dictionary = DataManager.get_creature_move(wild_move["id"])
	_execute_move(_wild_creature, _player_creature, wild_move, wild_move_data, false)
	_apply_status_damage(_wild_creature, false)
	if not _check_battle_over():
		_apply_status_damage(_player_creature, true)
		if not _check_battle_over():
			_set_state(BattleState.PLAYER_TURN)

func _execute_move(attacker: CreatureInstance, defender: CreatureInstance, move: Dictionary, move_data: Dictionary, is_player: bool) -> void:
	if attacker.is_fainted:
		return

	# Check paralysis
	if attacker.status == "paralyze" and randf() < 0.25:
		_post_message("%s is paralyzed! It can't move!" % attacker.nickname)
		return

	# Check sleep
	if attacker.status == "sleep":
		attacker.sleep_turns -= 1
		if attacker.sleep_turns <= 0:
			attacker.status = ""
			_post_message("%s woke up!" % attacker.nickname)
			status_changed.emit(is_player, "")
		else:
			_post_message("%s is fast asleep." % attacker.nickname)
			return

	# Check freeze (20% thaw each turn)
	if attacker.status == "freeze":
		if randf() < 0.2:
			attacker.status = ""
			_post_message("%s thawed out!" % attacker.nickname)
			status_changed.emit(is_player, "")
		else:
			_post_message("%s is frozen solid!" % attacker.nickname)
			return

	# Use PP
	move["current_pp"] = maxi(0, int(move["current_pp"]) - 1)

	var move_name: String = str(move_data.get("name", move["id"]))
	_post_message("%s used %s!" % [attacker.nickname, move_name])
	move_animation_requested.emit(move["id"], is_player)

	var category: String = str(move_data.get("category", "physical"))

	if category == "status":
		_apply_status_move(attacker, defender, move_data, is_player)
		return

	# Accuracy check
	var accuracy: int = int(move_data.get("accuracy", 100))
	if accuracy < 999:
		var acc_stage: int = attacker.stat_stages.get("accuracy", 0) - defender.stat_stages.get("evasion", 0)
		var acc_mult: float = 1.0
		if acc_stage > 0:
			acc_mult = (3.0 + acc_stage) / 3.0
		elif acc_stage < 0:
			acc_mult = 3.0 / (3.0 - acc_stage)
		var final_acc: float = accuracy * acc_mult
		if randf() * 100.0 > final_acc:
			_post_message("%s's attack missed!" % attacker.nickname)
			return

	# Calculate damage
	var damage: int = _calculate_damage(attacker, defender, move_data)
	var actual: int = defender.take_damage(damage)

	# Type effectiveness message
	var effectiveness: float = TypeChart.get_effectiveness(
		str(move_data.get("type", "normal")), defender.get_types()
	)
	var eff_text: String = TypeChart.get_effectiveness_text(effectiveness)
	if eff_text != "":
		_post_message(eff_text)

	_update_hp(not is_player)
	EventBus.creature_turn_executed.emit(attacker.nickname, move_data, actual)

	# Recoil
	var recoil: float = float(move_data.get("recoil", 0.0))
	if recoil > 0:
		var recoil_dmg: int = maxi(1, int(actual * recoil))
		attacker.take_damage(recoil_dmg)
		_post_message("%s took recoil damage!" % attacker.nickname)
		_update_hp(is_player)

	# Move secondary effects
	var effect_chance: int = int(move_data.get("effect_chance", 0))
	var effect: String = str(move_data.get("effect", ""))
	if effect != "" and effect_chance > 0 and randi_range(1, 100) <= effect_chance:
		_apply_effect(defender, effect, not is_player)

func _apply_status_move(attacker: CreatureInstance, defender: CreatureInstance, move_data: Dictionary, is_player: bool) -> void:
	var effect: String = str(move_data.get("effect", ""))
	var accuracy: int = int(move_data.get("accuracy", 100))

	# Accuracy check for status moves
	if accuracy < 100:
		if randf() * 100.0 > accuracy:
			_post_message("But it missed!")
			return

	match effect:
		"lower_attack":
			var change: int = defender.change_stat_stage("attack", -1)
			_post_message("%s's Attack fell!" % defender.nickname if change != 0 else "Nothing happened!")
		"lower_defense":
			var change: int = defender.change_stat_stage("defense", -1)
			_post_message("%s's Defense fell!" % defender.nickname if change != 0 else "Nothing happened!")
		"lower_attack_2":
			var change: int = defender.change_stat_stage("attack", -2)
			_post_message("%s's Attack harshly fell!" % defender.nickname if change != 0 else "Nothing happened!")
		"lower_accuracy":
			var change: int = defender.change_stat_stage("accuracy", -1)
			_post_message("%s's accuracy fell!" % defender.nickname if change != 0 else "Nothing happened!")
		"lower_speed_2":
			var change: int = defender.change_stat_stage("speed", -2)
			_post_message("%s's Speed harshly fell!" % defender.nickname if change != 0 else "Nothing happened!")
		"raise_defense":
			var change: int = attacker.change_stat_stage("defense", 1)
			_post_message("%s's Defense rose!" % attacker.nickname if change != 0 else "Nothing happened!")
		"raise_defense_2":
			var change: int = attacker.change_stat_stage("defense", 2)
			_post_message("%s's Defense sharply rose!" % attacker.nickname if change != 0 else "Nothing happened!")
		"raise_crit":
			_post_message("%s is getting pumped!" % attacker.nickname)
		"raise_speed_2":
			var change: int = attacker.change_stat_stage("speed", 2)
			_post_message("%s's Speed sharply rose!" % attacker.nickname if change != 0 else "Nothing happened!")
		"paralyze":
			if defender.status == "":
				defender.status = "paralyze"
				_post_message("%s was paralyzed!" % defender.nickname)
				status_changed.emit(not is_player, "paralyze")
			else:
				_post_message("But it failed!")
		"sleep":
			if defender.status == "":
				defender.status = "sleep"
				defender.sleep_turns = randi_range(1, 3)
				_post_message("%s fell asleep!" % defender.nickname)
				status_changed.emit(not is_player, "sleep")
			else:
				_post_message("But it failed!")
		"poison":
			if defender.status == "" and not defender.get_types().has("poison"):
				defender.status = "poison"
				_post_message("%s was poisoned!" % defender.nickname)
				status_changed.emit(not is_player, "poison")
			else:
				_post_message("But it failed!")
		"confuse":
			_post_message("%s became confused!" % defender.nickname)
		"cure_status":
			attacker.status = ""
			_post_message("All status problems were healed!")
			status_changed.emit(is_player, "")
		"weather_sand":
			_post_message("A sandstorm kicked up!")

func _apply_effect(target: CreatureInstance, effect: String, is_player: bool) -> void:
	match effect:
		"burn":
			if target.status == "" and not target.get_types().has("fire"):
				target.status = "burn"
				_post_message("%s was burned!" % target.nickname)
				status_changed.emit(is_player, "burn")
		"paralyze":
			if target.status == "" and not target.get_types().has("electric"):
				target.status = "paralyze"
				_post_message("%s was paralyzed!" % target.nickname)
				status_changed.emit(is_player, "paralyze")
		"freeze":
			if target.status == "" and not target.get_types().has("ice"):
				target.status = "freeze"
				_post_message("%s was frozen!" % target.nickname)
				status_changed.emit(is_player, "freeze")
		"poison":
			if target.status == "" and not target.get_types().has("poison"):
				target.status = "poison"
				_post_message("%s was poisoned!" % target.nickname)
				status_changed.emit(is_player, "poison")
		"flinch":
			pass  # Flinch only matters same turn — simplified
		"lower_defense":
			target.change_stat_stage("defense", -1)
			_post_message("%s's Defense fell!" % target.nickname)
		"lower_sp_defense":
			target.change_stat_stage("sp_defense", -1)
			_post_message("%s's Sp. Def fell!" % target.nickname)
		"lower_sp_attack":
			target.change_stat_stage("sp_attack", -1)
			_post_message("%s's Sp. Atk fell!" % target.nickname)
		"lower_speed":
			target.change_stat_stage("speed", -1)
			_post_message("%s's Speed fell!" % target.nickname)

func _apply_status_damage(creature: CreatureInstance, is_player: bool) -> void:
	if creature.is_fainted:
		return
	match creature.status:
		"burn":
			var dmg: int = maxi(1, int(creature.max_hp / 16.0))
			creature.take_damage(dmg)
			_post_message("%s was hurt by its burn!" % creature.nickname)
			_update_hp(is_player)
		"poison":
			var dmg: int = maxi(1, int(creature.max_hp / 8.0))
			creature.take_damage(dmg)
			_post_message("%s was hurt by poison!" % creature.nickname)
			_update_hp(is_player)

# ── Damage calculation ──

func _calculate_damage(attacker: CreatureInstance, defender: CreatureInstance, move_data: Dictionary) -> int:
	var power: int = int(move_data.get("power", 40))
	if power == 0:
		# Fixed damage moves (like Seismic Toss)
		var effect: String = str(move_data.get("effect", ""))
		if effect == "fixed_level_damage":
			return attacker.level
		return 0

	var category: String = str(move_data.get("category", "physical"))
	var atk_stat: int
	var def_stat: int

	if category == "physical":
		atk_stat = attacker.get_stat("attack")
		def_stat = defender.get_stat("defense")
		if attacker.status == "burn":
			atk_stat = int(atk_stat * 0.5)
	else:
		atk_stat = attacker.get_stat("sp_attack")
		def_stat = defender.get_stat("sp_defense")

	# Base damage formula
	var damage: float = ((2.0 * attacker.level / 5.0 + 2.0) * power * float(atk_stat) / float(def_stat)) / 50.0 + 2.0

	# STAB (Same Type Attack Bonus)
	var move_type: String = str(move_data.get("type", "normal"))
	if attacker.get_types().has(move_type):
		damage *= 1.5

	# Type effectiveness
	var effectiveness: float = TypeChart.get_effectiveness(move_type, defender.get_types())
	damage *= effectiveness

	# Critical hit (1/16 chance, 1.5x)
	var crit_rate: int = int(move_data.get("crit_rate", 1))
	var crit_threshold: float = 1.0 / (16.0 / crit_rate)
	if randf() < crit_threshold:
		damage *= 1.5
		_post_message("A critical hit!")

	# Random factor (85-100%)
	damage *= randf_range(0.85, 1.0)

	return maxi(1, int(damage))

# ── Catch rate ──

func _calculate_catch_rate(ball_type: String) -> float:
	var base: Dictionary = _wild_creature.get_base_data()
	var catch_rate: int = int(base.get("catch_rate", 45))
	var ball_bonus: float = 1.0

	match ball_type:
		"pokeball": ball_bonus = 1.0
		"greatball": ball_bonus = 1.5
		"ultraball": ball_bonus = 2.0
		"masterball": return 1.0  # Always catches

	var hp_factor: float = (3.0 * _wild_creature.max_hp - 2.0 * _wild_creature.current_hp) / (3.0 * _wild_creature.max_hp)
	var modified_rate: float = (catch_rate * ball_bonus * hp_factor) / 255.0

	# Status bonus
	if _wild_creature.status == "sleep" or _wild_creature.status == "freeze":
		modified_rate *= 2.0
	elif _wild_creature.status != "":
		modified_rate *= 1.5

	return clampf(modified_rate, 0.05, 1.0)

# ── Wild AI ──

func _select_wild_move() -> Dictionary:
	var available: Array[Dictionary] = []
	for m in _wild_creature.known_moves:
		if int(m["current_pp"]) > 0:
			available.append(m)
	if available.is_empty():
		# Struggle
		return { "id": "tackle", "current_pp": 99, "max_pp": 99 }
	return available[randi() % available.size()]

# ── Battle end ──

func _check_battle_over() -> bool:
	if _wild_creature.is_fainted:
		_post_message("The wild %s fainted!" % _wild_creature.nickname)
		EventBus.creature_fainted.emit(_wild_creature.to_dict(), false)
		# Award XP
		var xp_gain: int = _calculate_xp_yield()
		var levels: Array[int] = _player_creature.add_xp(xp_gain)
		_post_message("%s gained %d XP!" % [_player_creature.nickname, xp_gain])
		xp_awarded.emit(_player_creature, xp_gain)
		for lvl in levels:
			_post_message("%s grew to level %d!" % [_player_creature.nickname, lvl])
			EventBus.creature_level_up.emit(_player_creature.to_dict(), lvl)
			# Check new moves
			var new_moves: Array[String] = _player_creature.check_new_moves()
			for m_id in new_moves:
				var m_data: Dictionary = DataManager.get_creature_move(m_id)
				if _player_creature.known_moves.size() < 4:
					_player_creature.learn_move(m_id)
					_post_message("%s learned %s!" % [_player_creature.nickname, m_data.get("name", m_id)])
			# Check evolution
			var evo_id: String = _player_creature.check_evolution()
			if evo_id != "":
				var old_name: String = _player_creature.nickname
				_player_creature.evolve(evo_id)
				_post_message("%s evolved into %s!" % [old_name, _player_creature.nickname])
				EventBus.creature_evolved.emit(old_name, evo_id)
				GameState.pokedex[evo_id] = { "seen": true, "caught": true }
				EventBus.pokedex_updated.emit(evo_id)

		# Update Pokédex seen
		if not GameState.pokedex.has(_wild_creature.creature_id):
			GameState.pokedex[_wild_creature.creature_id] = { "seen": true, "caught": false }
		_save_active_creature()
		_end_battle("win")
		return true

	if _player_creature.is_fainted:
		_post_message("%s fainted!" % _player_creature.nickname)
		EventBus.creature_fainted.emit(_player_creature.to_dict(), true)
		_save_active_creature()
		# Try to send out next creature
		var next_idx: int = _find_next_alive()
		if next_idx == -1:
			_post_message("All your creatures have fainted!")
			_end_battle("lose")
			return true
		else:
			var next_data: Dictionary = GameState.creature_party[next_idx]
			_player_creature = CreatureInstance.from_dict(next_data)
			_player_creature.reset_stat_stages()
			_post_message("Go, %s!" % _player_creature.nickname)
			_update_hp(true)
			return false

	return false

func _find_next_alive() -> int:
	for i in range(GameState.creature_party.size()):
		var c: Dictionary = GameState.creature_party[i]
		if int(c.get("current_hp", 0)) > 0:
			return i
	return -1

func _calculate_xp_yield() -> int:
	var base: Dictionary = _wild_creature.get_base_data()
	var base_xp: int = int(base.get("base_xp", 50))
	return int(base_xp * _wild_creature.level / 7.0)

func _save_active_creature() -> void:
	# Find and update the player creature in party
	for i in range(GameState.creature_party.size()):
		if GameState.creature_party[i].get("creature_id", "") == _player_creature.creature_id:
			GameState.creature_party[i] = _player_creature.to_dict()
			break

func _add_to_party_or_pc(creature: CreatureInstance) -> void:
	if GameState.creature_party.size() < 6:
		GameState.creature_party.append(creature.to_dict())
		_post_message("%s was added to your party!" % creature.nickname)
	else:
		GameState.creature_pc_boxes.append(creature.to_dict())
		_post_message("%s was sent to the PC!" % creature.nickname)
	EventBus.creature_party_changed.emit()

func _end_battle(result: String) -> void:
	_battle_active = false
	_save_active_creature()
	_set_state(BattleState.ENDED)
	battle_ended.emit(result)
	EventBus.creature_battle_ended.emit(result)

# ── Helpers ──

func _set_state(new_state: BattleState) -> void:
	_state = new_state
	battle_state_changed.emit(new_state)

func _post_message(text: String) -> void:
	_message_queue.append(text)
	message_posted.emit(text)

func _update_hp(is_player: bool) -> void:
	if is_player:
		hp_updated.emit(true, _player_creature.current_hp, _player_creature.max_hp)
	else:
		hp_updated.emit(false, _wild_creature.current_hp, _wild_creature.max_hp)

func _format_ball_name(ball_type: String) -> String:
	match ball_type:
		"pokeball": return "Poké Ball"
		"greatball": return "Great Ball"
		"ultraball": return "Ultra Ball"
		"masterball": return "Master Ball"
	return ball_type

func get_player_creature() -> CreatureInstance:
	return _player_creature

func get_wild_creature() -> CreatureInstance:
	return _wild_creature

func get_state() -> BattleState:
	return _state
