## ComboSystem — Tracks ability sequences and triggers combo bonuses
##
## Listens to EventBus.ability_used, maintains a sliding window of recent
## ability IDs (last 3 abilities within 5s). Checks against combo definitions
## loaded from data/combos.json. Emits combo_completed when a match is found.
extends Node

const COMBO_WINDOW: float = 5.0  ## Max seconds between abilities for combo
const MAX_HISTORY: int = 3       ## Track last N abilities

var _combo_data: Array = []       ## Loaded combo definitions
var _ability_history: Array = []  ## [{ "id": String, "time": float }, ...]
var _last_combo_time: float = 0.0 ## Prevent double-triggering same combo

# ── Active combo bonus state ──
var _damage_mult_bonus: float = 1.0
var _damage_mult_timer: float = 0.0


func _ready() -> void:
	add_to_group("combo_system")

	# Load combo data
	if DataManager.has_method("get_combo_list"):
		_combo_data = DataManager.get_combo_list()
	else:
		# Fallback: load directly
		_load_combo_data()

	# Listen for abilities
	EventBus.ability_used.connect(_on_ability_used)


func _process(delta: float) -> void:
	# Tick down damage mult bonus
	if _damage_mult_timer > 0:
		_damage_mult_timer -= delta
		if _damage_mult_timer <= 0:
			_damage_mult_bonus = 1.0


func _load_combo_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/combos.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		for key in parsed:
			var combo: Dictionary = parsed[key]
			combo["id"] = key
			_combo_data.append(combo)


func _on_ability_used(ability_id: String, _slot: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0

	# Add to history
	_ability_history.append({ "id": ability_id, "time": now })

	# Trim old entries (outside window)
	while _ability_history.size() > 0:
		if now - float(_ability_history[0]["time"]) > COMBO_WINDOW:
			_ability_history.pop_front()
		else:
			break

	# Cap history size
	while _ability_history.size() > MAX_HISTORY:
		_ability_history.pop_front()

	# Check for combo matches
	_check_combos(now)


func _check_combos(now: float) -> void:
	var history_ids: Array = []
	for entry in _ability_history:
		history_ids.append(str(entry["id"]))

	for combo in _combo_data:
		var sequence: Array = combo.get("sequence", [])
		if sequence.is_empty():
			continue

		# Check if recent history ends with this sequence
		if history_ids.size() < sequence.size():
			continue

		var start_idx: int = history_ids.size() - sequence.size()
		var matched: bool = true
		for i in range(sequence.size()):
			if history_ids[start_idx + i] != str(sequence[i]):
				matched = false
				break

		if matched and (now - _last_combo_time) > 1.0:
			_trigger_combo(combo)
			_last_combo_time = now
			_ability_history.clear()  # Reset after combo triggers
			break


func _trigger_combo(combo: Dictionary) -> void:
	var combo_id: String = str(combo.get("id", ""))
	var combo_name: String = str(combo.get("name", "Combo"))
	var bonus: Dictionary = combo.get("bonus", {})
	var bonus_type: String = str(bonus.get("type", ""))

	# Emit completion signal
	EventBus.combo_completed.emit(combo_id, combo_name)

	# Apply bonus
	match bonus_type:
		"damage_mult":
			_damage_mult_bonus = float(bonus.get("value", 1.0))
			_damage_mult_timer = float(bonus.get("duration", 5.0))
			EventBus.chat_message.emit(
				"COMBO: %s! %.0f%% damage for %.0fs!" % [combo_name, (_damage_mult_bonus - 1.0) * 100, _damage_mult_timer],
				"combat"
			)

		"heal":
			var heal_pct: float = float(bonus.get("value", 0.1))
			var max_hp: int = int(GameState.player["max_hp"])
			var heal_amount: int = maxi(1, int(float(max_hp) * heal_pct))
			var old_hp: int = int(GameState.player["hp"])
			GameState.player["hp"] = mini(max_hp, old_hp + heal_amount)
			var actual_heal: int = int(GameState.player["hp"]) - old_hp
			if actual_heal > 0:
				EventBus.player_healed.emit(actual_heal)
			EventBus.chat_message.emit(
				"COMBO: %s! Healed %d HP!" % [combo_name, actual_heal],
				"combat"
			)

		"stun_aoe":
			var stun_dur: float = float(bonus.get("value", 1.5))
			var radius: float = float(bonus.get("radius", 5.0))
			var player: Node = get_tree().get_first_node_in_group("player")
			if player:
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(enemy):
						continue
					if enemy.global_position.distance_to(player.global_position) <= radius:
						if enemy.has_method("apply_stun"):
							enemy.apply_stun(stun_dur)
			EventBus.chat_message.emit(
				"COMBO: %s! All nearby enemies stunned for %.1fs!" % [combo_name, stun_dur],
				"combat"
			)

		"aoe_explosion":
			var dmg_mult: float = float(bonus.get("value", 2.0))
			var radius: float = float(bonus.get("radius", 8.0))
			var player: Node = get_tree().get_first_node_in_group("player")
			if player:
				var base_dmg: int = int(GameState.player.get("combat_level", 10)) * 5
				var explosion_dmg: int = int(float(base_dmg) * dmg_mult)
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(enemy):
						continue
					if enemy.global_position.distance_to(player.global_position) <= radius:
						if enemy.has_method("take_damage"):
							enemy.take_damage(explosion_dmg, str(GameState.player["combat_style"]))
			EventBus.chat_message.emit(
				"COMBO: %s! Massive AoE explosion!" % combo_name,
				"combat"
			)

		"chain_bonus":
			# Store chain bonus — combat controller checks this
			_damage_mult_bonus = 1.0  # Not really damage mult, but can be read
			_damage_mult_timer = float(bonus.get("duration", 5.0))
			EventBus.chat_message.emit(
				"COMBO: %s! +%d chain targets for %.0fs!" % [combo_name, int(bonus.get("value", 2)), _damage_mult_timer],
				"combat"
			)

	# Visual feedback — big golden flash text
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		EventBus.float_text_requested.emit(
			"COMBO: %s!" % combo_name,
			player.global_position + Vector3(0, 4.0, 0),
			Color(1.0, 0.85, 0.1)
		)


## Get current combo damage multiplier bonus (for combat_controller to query)
func get_damage_mult() -> float:
	return _damage_mult_bonus
