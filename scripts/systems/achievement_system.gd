## AchievementSystem -- Checks and unlocks achievements based on player progress
##
## Listens to relevant EventBus signals (kills, crafting, quests, levels, etc.)
## and checks whether any locked achievement conditions are now met.
## Does NOT poll every frame — only re-evaluates on relevant gameplay events.
##
## Achievement definitions come from DataManager.achievements (loaded from
## data/achievements.json). Each entry has: id, name, desc, category, points.
## The original JS "check" functions are re-implemented here in GDScript.
extends Node

# ── Internal counters (not stored on GameState — rebuilt from signals) ──
## Total enemies killed this session (persisted via save/load hooks below)
var _total_kills: int = 0
## Total abilities used this session
var _abilities_used: int = 0
## Total ultimate abilities used this session
var _ultimates_used: int = 0
## Total items crafted this session
var _total_crafts: int = 0

# ── Deferred check flag ──
## When true, a deferred check_all() call is already queued for the end of
## the current frame. This coalesces multiple signals in the same frame into
## a single scan, avoiding redundant work.
var _check_queued: bool = false


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("achievement_system")

	# ── Connect to signals that can trigger achievement progress ──

	# Combat
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Crafting
	EventBus.crafting_complete.connect(_on_crafting_complete)

	# Quests
	EventBus.quest_completed.connect(_on_quest_completed)

	# Skills / leveling
	EventBus.player_level_up.connect(_on_player_level_up)

	# Economy
	EventBus.player_credits_changed.connect(_on_credits_changed)

	# Prestige
	EventBus.prestige_triggered.connect(_on_prestige_triggered)

	# Equipment changes
	EventBus.item_equipped.connect(_on_item_equipped)

	# Game loaded — restore internal counters and re-check
	EventBus.game_loaded.connect(_on_game_loaded)


# ──────────────────────────────────────────────
#  Signal handlers — increment counters and queue a check
# ──────────────────────────────────────────────

func _on_enemy_killed(_enemy_id: String, _enemy_type: String) -> void:
	_total_kills += 1
	_queue_check()


func _on_crafting_complete(_recipe_id: String) -> void:
	_total_crafts += 1
	_queue_check()


func _on_quest_completed(_quest_id: String) -> void:
	_queue_check()


func _on_player_level_up(_skill: String, _level: int) -> void:
	_queue_check()


func _on_credits_changed(_total: int) -> void:
	_queue_check()


func _on_prestige_triggered(_tier: int) -> void:
	_queue_check()


func _on_item_equipped(_slot: String, _item_id: String) -> void:
	_queue_check()


func _on_game_loaded() -> void:
	# After a save is loaded, GameState has the authoritative counters.
	# Internal counters (_total_kills, etc.) are persisted alongside the save
	# via to_save_data / from_save_data on this node, so they are already
	# restored before this signal fires. Re-check all achievements now.
	_queue_check()


# ──────────────────────────────────────────────
#  Public API — called by external systems
# ──────────────────────────────────────────────

## Increment the internal ability-use counter. Call this from the combat
## system when the player activates a non-ultimate ability.
func record_ability_use() -> void:
	_abilities_used += 1
	_queue_check()


## Increment the internal ultimate-use counter. Call this from the combat
## system when the player activates an ultimate ability.
func record_ultimate_use() -> void:
	_ultimates_used += 1
	_queue_check()


## Scan every achievement definition and unlock any whose conditions are now
## met. Safe to call at any time; already-unlocked achievements are skipped.
func check_all() -> void:
	for entry in DataManager.achievements:
		var ach_id: String = str(entry.get("id", ""))
		if ach_id == "":
			continue
		# Skip if already unlocked
		if GameState.unlocked_achievements.has(ach_id):
			continue
		if _evaluate(ach_id):
			_unlock(entry)


## Return the total achievement points the player has earned so far.
func get_total_points() -> int:
	var total: int = 0
	for entry in DataManager.achievements:
		var ach_id: String = str(entry.get("id", ""))
		if GameState.unlocked_achievements.has(ach_id):
			total += int(entry.get("points", 0))
	return total


## Return a summary of progress: { unlocked: int, total: int, points: int, max_points: int }
func get_progress_summary() -> Dictionary:
	var unlocked: int = GameState.unlocked_achievements.size()
	var total: int = DataManager.achievements.size()
	var points: int = 0
	var max_points: int = 0
	for entry in DataManager.achievements:
		var ach_id: String = str(entry.get("id", ""))
		var pts: int = int(entry.get("points", 0))
		max_points += pts
		if GameState.unlocked_achievements.has(ach_id):
			points += pts
	return {
		"unlocked": unlocked,
		"total": total,
		"points": points,
		"max_points": max_points,
	}


## Serialize internal counters for save data. Called by the save system.
func to_save_data() -> Dictionary:
	return {
		"total_kills": _total_kills,
		"abilities_used": _abilities_used,
		"ultimates_used": _ultimates_used,
		"total_crafts": _total_crafts,
	}


## Restore internal counters from save data. Called by the save system.
func from_save_data(data: Dictionary) -> void:
	_total_kills = int(data.get("total_kills", 0))
	_abilities_used = int(data.get("abilities_used", 0))
	_ultimates_used = int(data.get("ultimates_used", 0))
	_total_crafts = int(data.get("total_crafts", 0))


# ──────────────────────────────────────────────
#  Deferred check — coalesce multiple signals per frame
# ──────────────────────────────────────────────

## Queue a single check_all() call at the end of the current frame. If
## multiple signals fire in the same frame, only one scan happens.
func _queue_check() -> void:
	if _check_queued:
		return
	_check_queued = true
	call_deferred("_deferred_check")


func _deferred_check() -> void:
	_check_queued = false
	check_all()


# ──────────────────────────────────────────────
#  Achievement evaluation — maps achievement IDs to GDScript checks
# ──────────────────────────────────────────────

## Evaluate whether the condition for a single achievement ID is met.
## Returns true if the achievement should unlock.
func _evaluate(ach_id: String) -> bool:
	match ach_id:
		# ── Combat ──
		"first_blood":
			return _total_kills >= 1
		"centurion":
			return _total_kills >= 100
		"slayer_1k":
			return _total_kills >= 1000
		"boss_hunter":
			return not GameState.boss_kills.is_empty()
		"boss_master":
			return GameState.boss_kills.size() >= 5
		"ability_user":
			return _abilities_used >= 50
		"ultimate_power":
			return _ultimates_used >= 10
		"slayer_streak_10":
			return GameState.slayer_streak >= 10
		"full_equipment":
			return _all_equipment_slots_filled()

		# ── Skilling ──
		"first_craft":
			return _total_crafts >= 1
		"master_crafter":
			return _total_crafts >= 500
		"level_50":
			return _any_skill_at_least(50)
		"level_99":
			return _any_skill_at_least(99)
		"all_skills_50":
			return _all_skills_at_least(50)
		"all_skills_99":
			return _all_skills_at_least(99)
		"synergy_first":
			# Synergy system removed — auto-complete this achievement
			return true

		# ── Quests ──
		"quest_1":
			return GameState.completed_quests.size() >= 1
		"quest_all":
			return GameState.completed_quests.size() >= DataManager.quests.size()

		# ── Exploration ──
		"explore_all":
			# Not yet implemented — needs area visit tracking
			return false
		"dungeon_floor_10":
			return GameState.dungeon_max_floor >= 10
		"dungeon_floor_50":
			return GameState.dungeon_max_floor >= 50

		# ── Prestige ──
		"prestige_1":
			return GameState.prestige_tier >= 1
		"prestige_5":
			return GameState.prestige_tier >= 5
		"prestige_10":
			return GameState.prestige_tier >= 10

		# ── Economy ──
		"credits_10k":
			return int(GameState.player.get("credits", 0)) >= 10_000
		"credits_1m":
			return int(GameState.player.get("credits", 0)) >= 1_000_000

		# ── Collection ──
		"bestiary_25":
			return GameState.collection_log.size() >= 25
		"bestiary_100":
			return GameState.collection_log.size() >= 100
		"collect_50_items":
			# Not yet implemented — needs unique item tracking
			return false

	# Unknown achievement ID — leave locked
	push_warning("AchievementSystem: No check defined for achievement '%s'" % ach_id)
	return false


# ──────────────────────────────────────────────
#  Unlock logic
# ──────────────────────────────────────────────

## Unlock an achievement: update GameState, emit signals, show chat + float text.
func _unlock(entry: Dictionary) -> void:
	var ach_id: String = str(entry.get("id", ""))
	var ach_name: String = str(entry.get("name", ach_id))
	var ach_points: int = int(entry.get("points", 0))

	# Record on GameState
	if not GameState.unlocked_achievements.has(ach_id):
		GameState.unlocked_achievements.append(ach_id)

	# Emit achievement signal
	EventBus.achievement_unlocked.emit(ach_id)

	# Chat message in the "achievement" channel
	EventBus.chat_message.emit(
		"Achievement unlocked: %s (%d pts)" % [ach_name, ach_points],
		"achievement"
	)

	# Float text above the player
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		EventBus.float_text_requested.emit(
			"Achievement: %s" % ach_name,
			player_node.global_position + Vector3(0, 4.0, 0),
			Color(1.0, 0.84, 0.0)  # Gold color
		)


# ──────────────────────────────────────────────
#  Condition helpers
# ──────────────────────────────────────────────

## Returns true if any skill has reached at least the given level.
func _any_skill_at_least(min_level: int) -> bool:
	for skill_data: Dictionary in GameState.skills.values():
		if int(skill_data.get("level", 1)) >= min_level:
			return true
	return false


## Returns true if ALL skills have reached at least the given level.
func _all_skills_at_least(min_level: int) -> bool:
	if GameState.skills.is_empty():
		return false
	for skill_data: Dictionary in GameState.skills.values():
		if int(skill_data.get("level", 1)) < min_level:
			return false
	return true


## Returns true if all 7 equipment slots have a non-empty item ID.
func _all_equipment_slots_filled() -> bool:
	for slot: String in GameState.equipment:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			return false
	return true
