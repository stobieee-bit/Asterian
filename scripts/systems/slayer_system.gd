## SlayerSystem -- Assigns and tracks slayer tasks (RS3-style)
##
## Picks a level-appropriate enemy type for the player to hunt, tracks kills,
## awards slayer XP (split across all three combat skills) and slayer points
## on task completion. Maintains a streak that boosts point rewards.
extends Node

# ── Combat skill IDs for splitting slayer XP ──
const COMBAT_SKILLS: Array[String] = ["nano", "tesla", "void"]

# ── Task size range ──
const TASK_COUNT_MIN: int = 15
const TASK_COUNT_MAX: int = 40

# ── Boss combat-level threshold (excluded unless player is high level) ──
const BOSS_COMBAT_LEVEL: int = 80
## Player combat level required before boss-type enemies appear in the task pool
const BOSS_UNLOCK_COMBAT_LEVEL: int = 70


func _ready() -> void:
	add_to_group("slayer_system")

	# Listen for kills so we can tick down the active task
	EventBus.enemy_killed.connect(_on_enemy_killed)


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Assign a new slayer task. Returns true if a task was successfully assigned,
## false if the player already has one or no valid enemies exist.
func assign_task() -> bool:
	if has_task():
		EventBus.chat_message.emit("You already have a slayer task.", "system")
		return false

	var combat_level: int = GameState.get_combat_level()
	var pool: Array[Dictionary] = _build_enemy_pool(combat_level)

	if pool.is_empty():
		EventBus.chat_message.emit("No suitable enemies found for your level.", "system")
		return false

	# Pick a random enemy from the filtered pool
	var chosen: Dictionary = pool[randi() % pool.size()]
	var enemy_type: String = str(chosen.get("type_id", ""))
	var enemy_name: String = str(chosen.get("name", enemy_type))
	var area: String = str(chosen.get("area", ""))
	var count: int = randi_range(TASK_COUNT_MIN, TASK_COUNT_MAX)

	# Store the task on GameState
	GameState.slayer_task = {
		"enemy_type": enemy_type,
		"count": count,
		"remaining": count,
		"area": area,
	}

	# Increment the completion streak (it only resets on cancel)
	GameState.slayer_streak += 1

	EventBus.chat_message.emit(
		"Slayer task: Kill %d %s in %s." % [count, enemy_name, area],
		"slayer"
	)
	return true


## Cancel the current task. Resets the streak to 0.
func cancel_task() -> void:
	if not has_task():
		EventBus.chat_message.emit("You don't have a slayer task to cancel.", "system")
		return

	GameState.slayer_task = {}
	GameState.slayer_streak = 0

	EventBus.chat_message.emit("Slayer task cancelled. Streak reset.", "slayer")


## Whether the player currently has an active slayer task.
func has_task() -> bool:
	return not GameState.slayer_task.is_empty()


## Snapshot of the current task. Returns an empty Dictionary when no task is active.
func get_task_info() -> Dictionary:
	if not has_task():
		return {}

	var task: Dictionary = GameState.slayer_task
	var enemy_type: String = str(task.get("enemy_type", ""))
	var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
	var enemy_name: String = str(enemy_data.get("name", enemy_type))

	return {
		"enemy_type": enemy_type,
		"enemy_name": enemy_name,
		"count": int(task.get("count", 0)),
		"remaining": int(task.get("remaining", 0)),
		"area": str(task.get("area", "")),
		"streak": GameState.slayer_streak,
		"points": GameState.slayer_points,
	}


# ──────────────────────────────────────────────
#  Signal handlers
# ──────────────────────────────────────────────

## Called whenever an enemy is killed. Decrements the task counter if the
## enemy_type matches, and completes the task when remaining hits 0.
func _on_enemy_killed(_enemy_id: String, enemy_type: String) -> void:
	if not has_task():
		return

	var task: Dictionary = GameState.slayer_task
	if str(task.get("enemy_type", "")) != enemy_type:
		return

	# Decrement remaining kills
	var remaining: int = int(task.get("remaining", 0)) - 1
	task["remaining"] = remaining
	GameState.slayer_task = task

	if remaining <= 0:
		_complete_task()
	else:
		# Progress update every kill
		var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
		var enemy_name: String = str(enemy_data.get("name", enemy_type))
		EventBus.chat_message.emit(
			"Slayer task: %d %s remaining." % [remaining, enemy_name],
			"slayer"
		)


# ──────────────────────────────────────────────
#  Internal helpers
# ──────────────────────────────────────────────

## Build a pool of enemies whose combat level is within an acceptable window
## of the player's combat level.
func _build_enemy_pool(combat_level: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var all_enemies: Dictionary = DataManager.enemies

	var level_floor: int = combat_level - 20
	var level_ceil: int = combat_level + 10

	for type_id in all_enemies:
		var data: Dictionary = all_enemies[type_id]
		var enemy_combat: int = int(data.get("level", 0))

		# Must be within the player's level window
		if enemy_combat < level_floor or enemy_combat > level_ceil:
			continue

		# Exclude boss-type enemies unless the player is high enough level
		if enemy_combat >= BOSS_COMBAT_LEVEL and combat_level < BOSS_UNLOCK_COMBAT_LEVEL:
			continue

		# Attach type_id so we can reference it after selection
		var entry: Dictionary = data.duplicate()
		entry["type_id"] = str(type_id)
		pool.append(entry)

	return pool


## Complete the current task -- award XP, slayer points, and clean up.
func _complete_task() -> void:
	var task: Dictionary = GameState.slayer_task
	var enemy_type: String = str(task.get("enemy_type", ""))
	var count: int = int(task.get("count", 0))

	var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
	var enemy_name: String = str(enemy_data.get("name", enemy_type))
	var enemy_combat: int = int(enemy_data.get("level", 1))

	# ── Calculate rewards ──
	var total_xp: int = count * enemy_combat * 2
	var xp_per_skill: int = int(total_xp / COMBAT_SKILLS.size())  # split evenly
	var points_earned: int = 10 + GameState.slayer_streak * 2

	# ── Award XP to each combat skill ──
	var player_node: Node3D = get_tree().get_first_node_in_group("player")

	for skill_id in COMBAT_SKILLS:
		if not GameState.skills.has(skill_id):
			push_warning("SlayerSystem: Unknown skill '%s'" % skill_id)
			continue

		var skill_entry: Dictionary = GameState.skills[skill_id]
		var old_level: int = int(skill_entry.get("level", 1))
		skill_entry["xp"] = int(skill_entry.get("xp", 0)) + xp_per_skill
		EventBus.player_xp_gained.emit(skill_id, xp_per_skill)

		# Level-up check
		var new_level: int = DataManager.level_for_xp(int(skill_entry["xp"]))
		if new_level > old_level:
			skill_entry["level"] = new_level
			EventBus.player_level_up.emit(skill_id, new_level)

			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = str(skill_data.get("name", skill_id))
			EventBus.chat_message.emit(
				"%s leveled up to %d!" % [skill_name, new_level],
				"levelup"
			)

	# ── Float text for XP ──
	if player_node:
		EventBus.float_text_requested.emit(
			"+%d Slayer XP" % total_xp,
			player_node.global_position + Vector3(0, 3.5, 0),
			Color(0.8, 0.2, 0.2)
		)

	# ── Award slayer points ──
	GameState.slayer_points += points_earned

	if player_node:
		EventBus.float_text_requested.emit(
			"+%d Slayer pts" % points_earned,
			player_node.global_position + Vector3(0, 4.0, 0),
			Color(0.9, 0.6, 0.1)
		)

	# ── Chat completion message ──
	EventBus.chat_message.emit(
		"Slayer task complete! Killed %d %s. +%d XP, +%d slayer points (streak: %d)." % [
			count, enemy_name, total_xp, points_earned, GameState.slayer_streak
		],
		"slayer"
	)

	# ── Clear the task ──
	GameState.slayer_task = {}
