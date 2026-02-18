## QuestSystem — Tracks quest progress and handles completion rewards
##
## Listens to EventBus signals (enemy_killed, gathering_complete, crafting_complete)
## and advances matching quest steps. Manages the full lifecycle: accept → progress
## → complete → claim rewards → offer follow-up quest.
extends Node

# ── Cached references ──
# (Autoloads EventBus, GameState, DataManager are globally available)


func _ready() -> void:
	add_to_group("quest_system")

	# Connect gameplay signals that can advance quest steps
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.item_added.connect(_on_item_added)
	EventBus.crafting_complete.connect(_on_crafting_complete)


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Check whether a quest can be accepted (not active, not completed, and
## prerequisite chain satisfied — if another quest has this one as followUp,
## that predecessor must be in completed_quests).
func can_accept_quest(quest_id: String) -> bool:
	if GameState.active_quests.has(quest_id):
		return false
	if GameState.completed_quests.has(quest_id):
		return false
	# Verify the quest actually exists in data
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return false
	# Check prerequisite: is this quest a followUp of another quest?
	# If so, the predecessor must be completed before this one is available.
	if _has_unfinished_prerequisite(quest_id):
		return false
	return true

## Returns true if quest_id is the followUp of some other quest that has NOT
## been completed yet.  This prevents follow-up quests from appearing early.
func _has_unfinished_prerequisite(quest_id: String) -> bool:
	# Search all quests for one that lists quest_id as its followUp
	for other_id in DataManager.quests:
		var other: Dictionary = DataManager.quests[other_id]
		var follow: Variant = other.get("followUp", null)
		if follow != null and str(follow) == quest_id:
			# Found the predecessor — it must be completed
			if not GameState.completed_quests.has(str(other_id)):
				return true
	# Also check board_quests (they don't chain, but safety check)
	for other_id in DataManager.board_quests:
		var other: Dictionary = DataManager.board_quests[other_id]
		var follow: Variant = other.get("followUp", null)
		if follow != null and str(follow) == quest_id:
			if not GameState.completed_quests.has(str(other_id)):
				return true
	return false


## Accept a quest: add it to active_quests with step 0 and blank progress for
## every step in the quest definition.
func accept_quest(quest_id: String) -> bool:
	if not can_accept_quest(quest_id):
		return false

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		push_warning("QuestSystem: Unknown quest '%s'" % quest_id)
		return false

	var steps: Array = quest_data.get("steps", [])

	# Build per-step progress entries  { "0": { "count": 0 }, "1": { "count": 0 }, ... }
	var progress: Dictionary = {}
	for i in range(steps.size()):
		progress[str(i)] = { "count": 0 }

	GameState.active_quests[quest_id] = {
		"step": 0,
		"progress": progress,
	}

	# Notify the rest of the game
	EventBus.quest_accepted.emit(quest_id)

	var quest_name: String = str(quest_data.get("name", quest_id))
	EventBus.chat_message.emit("Quest accepted: %s" % quest_name, "quest")
	return true


## Check if every step of an active quest has met its required count.
func is_quest_complete(quest_id: String) -> bool:
	if not GameState.active_quests.has(quest_id):
		return false

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return false

	var steps: Array = quest_data.get("steps", [])
	var tracking: Dictionary = GameState.active_quests[quest_id]
	var progress: Dictionary = tracking.get("progress", {})

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var required: int = int(step.get("count", 1))
		var current: int = int(progress.get(str(i), {}).get("count", 0))
		if current < required:
			return false

	return true


## Return a snapshot of the player's progress on an active quest.
## { "quest_id": String, "step": int, "steps": [ { "desc", "current", "required", "done" } ], "completable": bool }
func get_quest_progress(quest_id: String) -> Dictionary:
	if not GameState.active_quests.has(quest_id):
		return {}

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return {}

	var steps: Array = quest_data.get("steps", [])
	var tracking: Dictionary = GameState.active_quests[quest_id]
	var current_step: int = int(tracking.get("step", 0))
	var progress: Dictionary = tracking.get("progress", {})

	var step_info: Array[Dictionary] = []
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var required: int = int(step.get("count", 1))
		var current: int = int(progress.get(str(i), {}).get("count", 0))
		step_info.append({
			"desc": str(step.get("desc", "")),
			"current": current,
			"required": required,
			"done": current >= required,
		})

	return {
		"quest_id": quest_id,
		"name": str(quest_data.get("name", quest_id)),
		"step": current_step,
		"steps": step_info,
		"completable": is_quest_complete(quest_id),
	}


## Complete a quest: grant all rewards, move to completed_quests, and offer
## the follow-up quest if one is defined.
func complete_quest(quest_id: String) -> bool:
	if not GameState.active_quests.has(quest_id):
		push_warning("QuestSystem: Quest '%s' is not active." % quest_id)
		return false

	if not is_quest_complete(quest_id):
		EventBus.chat_message.emit("Quest not finished yet.", "system")
		return false

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	if quest_data.is_empty():
		return false

	var quest_name: String = str(quest_data.get("name", quest_id))

	# ── Grant rewards ──
	var rewards: Dictionary = quest_data.get("rewards", {})
	_grant_rewards(rewards)

	# ── Move quest from active → completed ──
	GameState.active_quests.erase(quest_id)
	if not GameState.completed_quests.has(quest_id):
		GameState.completed_quests.append(quest_id)

	# Emit completion signals
	EventBus.quest_completed.emit(quest_id)
	EventBus.quest_reward_claimed.emit(quest_id)
	EventBus.chat_message.emit("Quest complete: %s!" % quest_name, "quest")

	# ── Offer follow-up quest ──
	var follow_up: Variant = quest_data.get("followUp", null)
	if follow_up != null and follow_up is String and str(follow_up) != "":
		var follow_id: String = str(follow_up)
		if can_accept_quest(follow_id):
			EventBus.chat_message.emit("New quest available: %s" % str(DataManager.get_quest(follow_id).get("name", follow_id)), "quest")

	return true


## Abandon an active quest — removes it from active_quests and resets progress.
## The quest can be re-accepted afterwards if prerequisites are still met.
func abandon_quest(quest_id: String) -> bool:
	if not GameState.active_quests.has(quest_id):
		return false

	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	var quest_name: String = str(quest_data.get("name", quest_id))

	GameState.active_quests.erase(quest_id)
	EventBus.quest_abandoned.emit(quest_id)
	EventBus.chat_message.emit("Quest abandoned: %s" % quest_name, "quest")
	return true


# ──────────────────────────────────────────────
#  Signal handlers — advance matching quest steps
# ──────────────────────────────────────────────

## Called when any enemy is killed. Checks all active quests for "kill" steps
## whose target matches the enemy_type.
func _on_enemy_killed(_enemy_id: String, enemy_type: String) -> void:
	_advance_steps("kill", "target", enemy_type)


## Called when any item enters the player's inventory (gathering nodes, loot
## drops, purchases, ground pickups, bank withdrawals, etc.).  Replaces the
## old gathering_complete handler so "gather" quest steps track correctly
## regardless of how the item was obtained (e.g. chitin shards from enemies).
func _on_item_added(item_id: String, quantity: int) -> void:
	_advance_steps("gather", "item", item_id, quantity)


## Called when a crafting action completes. Checks for "craft" steps matching
## the recipe_id.
func _on_crafting_complete(recipe_id: String) -> void:
	_advance_steps("craft", "recipe", recipe_id)


# ──────────────────────────────────────────────
#  Internal helpers
# ──────────────────────────────────────────────

## Generic step advancement. Iterates every active quest and every step to find
## steps of `step_type` whose `match_key` field equals `match_value`.
## Increments the count by `amount` and auto-advances `tracking.step` when the
## current step is finished.
func _advance_steps(step_type: String, match_key: String, match_value: String, amount: int = 1) -> void:
	# Snapshot keys so we can safely modify the dict during iteration
	var quest_ids: Array = GameState.active_quests.keys().duplicate()

	for quest_id in quest_ids:
		if not GameState.active_quests.has(quest_id):
			continue

		var quest_data: Dictionary = DataManager.get_quest(str(quest_id))
		if quest_data.is_empty():
			continue

		var steps: Array = quest_data.get("steps", [])
		var tracking: Dictionary = GameState.active_quests[quest_id]
		var progress: Dictionary = tracking.get("progress", {})
		var changed: bool = false
		var quest_name: String = str(quest_data.get("name", str(quest_id)))

		# Check ALL steps in parallel (not just the current one)
		for i in range(steps.size()):
			var step: Dictionary = steps[i]
			var stype: String = str(step.get("type", ""))
			if stype != step_type:
				continue

			var target_val: String = str(step.get(match_key, ""))
			if target_val != match_value:
				continue

			var required: int = int(step.get("count", 1))
			var step_key: String = str(i)
			if not progress.has(step_key):
				progress[step_key] = { "count": 0 }

			var current_count: int = int(progress[step_key]["count"])
			if current_count >= required:
				continue  # Step already done

			# Increment progress (clamp to required so we don't overshoot)
			current_count = mini(current_count + amount, required)
			progress[step_key]["count"] = current_count
			changed = true

			# Chat progress update — strip existing (x/y) from desc to avoid duplication
			var step_desc: String = str(step.get("desc", ""))
			var paren_idx: int = step_desc.rfind(" (")
			if paren_idx >= 0 and step_desc.ends_with(")"):
				step_desc = step_desc.substr(0, paren_idx)
			EventBus.chat_message.emit(
				"%s — %s (%d/%d)" % [quest_name, step_desc, current_count, required],
				"quest"
			)

		# Recalculate the "step" pointer — advance to the first incomplete step
		if changed:
			var all_done: bool = true
			var first_incomplete: int = steps.size()
			for i in range(steps.size()):
				var step_key: String = str(i)
				var step_data: Dictionary = steps[i]
				var required: int = int(step_data.get("count", 1))
				var count: int = int(progress.get(step_key, {}).get("count", 0))
				if count < required:
					all_done = false
					if i < first_incomplete:
						first_incomplete = i

			tracking["step"] = first_incomplete if not all_done else steps.size()
			tracking["progress"] = progress
			GameState.active_quests[quest_id] = tracking

			EventBus.quest_progress.emit(str(quest_id), int(tracking["step"]))

			if all_done:
				EventBus.chat_message.emit(
					"%s — All objectives complete! Return to turn in." % quest_name,
					"quest"
				)


## Grant all rewards defined in a quest's rewards dictionary.
## Handles XP (per-skill with level-up check), credits, and items.
func _grant_rewards(rewards: Dictionary) -> void:
	var player_node: Node3D = get_tree().get_first_node_in_group("player")

	# ── XP rewards ──
	var xp_rewards: Dictionary = rewards.get("xp", {})
	for skill_id in xp_rewards:
		var amount: int = int(xp_rewards[skill_id])
		if amount <= 0:
			continue
		if not GameState.skills.has(str(skill_id)):
			push_warning("QuestSystem: Unknown skill '%s' in quest reward" % str(skill_id))
			continue

		var skill_entry: Dictionary = GameState.skills[str(skill_id)]
		var old_level: int = int(skill_entry["level"])
		skill_entry["xp"] = int(skill_entry["xp"]) + amount
		EventBus.player_xp_gained.emit(str(skill_id), amount)

		# Level-up check via DataManager.level_for_xp
		var new_level: int = DataManager.level_for_xp(int(skill_entry["xp"]))
		if new_level > old_level:
			skill_entry["level"] = new_level
			EventBus.player_level_up.emit(str(skill_id), new_level)

			var lvl_skill_data: Dictionary = DataManager.get_skill(str(skill_id))
			var lvl_skill_name: String = str(lvl_skill_data.get("name", str(skill_id)))
			EventBus.chat_message.emit(
				"%s leveled up to %d!" % [lvl_skill_name, new_level],
				"levelup"
			)

		# XP float text on player
		if player_node:
			var xp_skill_data: Dictionary = DataManager.get_skill(str(skill_id))
			var xp_skill_name: String = str(xp_skill_data.get("name", str(skill_id)))
			EventBus.float_text_requested.emit(
				"+%d %s XP" % [amount, xp_skill_name],
				player_node.global_position + Vector3(0, 3.5, 0),
				Color(0.3, 0.9, 0.3)
			)

	# ── Credit rewards ──
	var credit_amount: int = int(rewards.get("credits", 0))
	if credit_amount > 0:
		GameState.add_credits(credit_amount)
		EventBus.chat_message.emit("Received %d credits." % credit_amount, "quest")

		if player_node:
			EventBus.float_text_requested.emit(
				"+%d credits" % credit_amount,
				player_node.global_position + Vector3(0, 3.0, 0),
				Color(1.0, 0.85, 0.2)
			)

	# ── Item rewards ──
	var item_rewards: Array = rewards.get("items", [])
	for entry in item_rewards:
		var item_id: String = ""
		var quantity: int = 1

		# Support both "item_id" strings and { "item": "id", "qty": n } dicts
		if entry is String:
			item_id = entry
		elif entry is Dictionary:
			item_id = str(entry.get("item", ""))
			quantity = int(entry.get("qty", 1))

		if item_id == "":
			continue

		var success: bool = GameState.add_item(item_id, quantity)
		if success:
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_name: String = str(item_data.get("name", item_id))
			var qty_text: String = " x%d" % quantity if quantity > 1 else ""
			EventBus.chat_message.emit("Received %s%s." % [item_name, qty_text], "quest")
		else:
			EventBus.chat_message.emit("Inventory full — could not receive reward item.", "system")
