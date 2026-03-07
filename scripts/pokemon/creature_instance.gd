## CreatureInstance — Runtime representation of an individual creature
##
## Holds all instance data: nickname, level, IVs, EVs, current HP,
## known moves, status, and XP. Created from base creature data.
class_name CreatureInstance
extends RefCounted

# ── Instance data ──
var creature_id: String = ""
var nickname: String = ""
var level: int = 1
var xp: int = 0
var current_hp: int = 0
var max_hp: int = 0
var status: String = ""  # "", "burn", "paralyze", "poison", "sleep", "freeze"
var sleep_turns: int = 0
var known_moves: Array[Dictionary] = []  # [{ id, current_pp, max_pp }]
var is_fainted: bool = false

# ── IVs (0-31 random at creation) ──
var ivs: Dictionary = {
	"hp": 0, "attack": 0, "defense": 0,
	"sp_attack": 0, "sp_defense": 0, "speed": 0,
}

# ── EVs (0-252 each, 510 total max) ──
var evs: Dictionary = {
	"hp": 0, "attack": 0, "defense": 0,
	"sp_attack": 0, "sp_defense": 0, "speed": 0,
}

# ── Stat stages (-6 to +6, reset on switch/battle end) ──
var stat_stages: Dictionary = {
	"attack": 0, "defense": 0,
	"sp_attack": 0, "sp_defense": 0,
	"speed": 0, "accuracy": 0, "evasion": 0,
}

# ── Static creation methods ──

## Create a new creature instance from base data at a given level
static func create(creature_id: String, level: int) -> CreatureInstance:
	var inst: CreatureInstance = CreatureInstance.new()
	inst.creature_id = creature_id
	var base: Dictionary = DataManager.get_creature(creature_id)
	inst.nickname = str(base.get("name", creature_id))
	inst.level = level
	inst.xp = _xp_for_level(level)

	# Random IVs
	for stat in inst.ivs:
		inst.ivs[stat] = randi_range(0, 31)

	# Learn moves up to current level (take last 4)
	var available_moves: Array[String] = DataManager.get_creature_moves_at_level(creature_id, level)
	var start_idx: int = maxi(0, available_moves.size() - 4)
	for i in range(start_idx, available_moves.size()):
		var move_data: Dictionary = DataManager.get_creature_move(available_moves[i])
		if not move_data.is_empty():
			inst.known_moves.append({
				"id": available_moves[i],
				"current_pp": int(move_data.get("pp", 10)),
				"max_pp": int(move_data.get("pp", 10)),
			})

	# Calculate stats
	inst._recalculate_stats()
	inst.current_hp = inst.max_hp
	return inst

## Create from save dictionary
static func from_dict(data: Dictionary) -> CreatureInstance:
	var inst: CreatureInstance = CreatureInstance.new()
	inst.creature_id = str(data.get("creature_id", ""))
	inst.nickname = str(data.get("nickname", ""))
	inst.level = int(data.get("level", 1))
	inst.xp = int(data.get("xp", 0))
	inst.current_hp = int(data.get("current_hp", 1))
	inst.status = str(data.get("status", ""))
	inst.ivs = data.get("ivs", inst.ivs)
	inst.evs = data.get("evs", inst.evs)
	var saved_moves: Array = data.get("known_moves", [])
	inst.known_moves.clear()
	for m in saved_moves:
		inst.known_moves.append(m)
	inst._recalculate_stats()
	inst.is_fainted = inst.current_hp <= 0
	return inst

# ── Stat calculation (gen-style formula) ──

func _recalculate_stats() -> void:
	var base: Dictionary = DataManager.get_creature(creature_id)
	if base.is_empty():
		return
	var base_stats: Dictionary = base.get("base_stats", {})
	max_hp = _calc_hp(int(base_stats.get("hp", 50)))

func _calc_hp(base_hp: int) -> int:
	return int(((2.0 * base_hp + ivs["hp"] + evs["hp"] / 4.0) * level) / 100.0) + level + 10

func get_stat(stat_name: String) -> int:
	var base: Dictionary = DataManager.get_creature(creature_id)
	if base.is_empty():
		return 1
	var base_stats: Dictionary = base.get("base_stats", {})
	var base_val: int = int(base_stats.get(stat_name, 50))
	var raw: int = int(((2.0 * base_val + ivs.get(stat_name, 0) + evs.get(stat_name, 0) / 4.0) * level) / 100.0) + 5
	# Apply stat stage
	var stage: int = stat_stages.get(stat_name, 0)
	if stage > 0:
		raw = int(raw * (2.0 + stage) / 2.0)
	elif stage < 0:
		raw = int(raw * 2.0 / (2.0 - stage))
	return maxi(1, raw)

func get_effective_speed() -> int:
	var spd: int = get_stat("speed")
	if status == "paralyze":
		spd = int(spd * 0.5)
	return maxi(1, spd)

func get_types() -> Array:
	var base: Dictionary = DataManager.get_creature(creature_id)
	return base.get("types", ["normal"])

func get_base_data() -> Dictionary:
	return DataManager.get_creature(creature_id)

# ── HP management ──

func take_damage(amount: int) -> int:
	var actual: int = mini(amount, current_hp)
	current_hp = maxi(0, current_hp - amount)
	if current_hp <= 0:
		is_fainted = true
	return actual

func heal(amount: int) -> int:
	if is_fainted:
		return 0
	var actual: int = mini(amount, max_hp - current_hp)
	current_hp = mini(max_hp, current_hp + amount)
	return actual

func full_heal() -> void:
	_recalculate_stats()
	current_hp = max_hp
	status = ""
	is_fainted = false
	for m in known_moves:
		m["current_pp"] = m["max_pp"]

func revive(hp_fraction: float = 0.5) -> void:
	if not is_fainted:
		return
	is_fainted = false
	_recalculate_stats()
	current_hp = maxi(1, int(max_hp * hp_fraction))
	status = ""

# ── Stat stage management ──

func change_stat_stage(stat_name: String, change: int) -> int:
	var current: int = stat_stages.get(stat_name, 0)
	var new_val: int = clampi(current + change, -6, 6)
	stat_stages[stat_name] = new_val
	return new_val - current  # Actual change applied

func reset_stat_stages() -> void:
	for key in stat_stages:
		stat_stages[key] = 0

# ── XP and leveling ──

func add_xp(amount: int) -> Array[int]:
	var levels_gained: Array[int] = []
	xp += amount
	while xp >= _xp_for_level(level + 1) and level < 100:
		level += 1
		levels_gained.append(level)
		_recalculate_stats()
		# Heal proportionally on level up
		current_hp = mini(current_hp + 5, max_hp)
	return levels_gained

func check_new_moves() -> Array[String]:
	var base: Dictionary = DataManager.get_creature(creature_id)
	var moves_by_level: Dictionary = base.get("moves_by_level", {})
	var level_str: String = str(level)
	if not moves_by_level.has(level_str):
		return []
	var new_moves: Array[String] = []
	var move_list: Array = moves_by_level[level_str]
	for m in move_list:
		var move_id: String = str(m)
		var already_known: bool = false
		for km in known_moves:
			if km["id"] == move_id:
				already_known = true
				break
		if not already_known:
			new_moves.append(move_id)
	return new_moves

func learn_move(move_id: String, replace_index: int = -1) -> bool:
	var move_data: Dictionary = DataManager.get_creature_move(move_id)
	if move_data.is_empty():
		return false
	var entry: Dictionary = {
		"id": move_id,
		"current_pp": int(move_data.get("pp", 10)),
		"max_pp": int(move_data.get("pp", 10)),
	}
	if known_moves.size() < 4:
		known_moves.append(entry)
		return true
	elif replace_index >= 0 and replace_index < 4:
		known_moves[replace_index] = entry
		return true
	return false

func check_evolution() -> String:
	var base: Dictionary = DataManager.get_creature(creature_id)
	var evo: Variant = base.get("evolution")
	if evo is Dictionary and evo.has("level"):
		if level >= int(evo["level"]):
			return str(evo["into"])
	return ""

func evolve(new_id: String) -> void:
	creature_id = new_id
	var base: Dictionary = DataManager.get_creature(new_id)
	var old_max: int = max_hp
	_recalculate_stats()
	current_hp += max_hp - old_max
	current_hp = clampi(current_hp, 1, max_hp)
	if nickname == "" or nickname == str(DataManager.get_creature(creature_id).get("name", "")):
		nickname = str(base.get("name", new_id))

# ── Serialization ──

func to_dict() -> Dictionary:
	return {
		"creature_id": creature_id,
		"nickname": nickname,
		"level": level,
		"xp": xp,
		"current_hp": current_hp,
		"status": status,
		"ivs": ivs.duplicate(),
		"evs": evs.duplicate(),
		"known_moves": known_moves.duplicate(true),
	}

# ── XP curve (medium-fast) ──

static func _xp_for_level(lvl: int) -> int:
	return int(0.8 * pow(lvl, 3))
