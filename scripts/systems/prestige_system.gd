## PrestigeSystem -- Manages the prestige (rebirth) mechanic
##
## Allows players to reset all skills in exchange for permanent passive bonuses,
## prestige points for the prestige shop, and access to higher-tier content.
## Prestige data definitions (config, passives, shop items) are loaded by
## DataManager from data/prestige.json.
##
## Architecture:
##   - Reads config from DataManager.prestige_config
##   - Reads passive definitions from DataManager.prestige_passives
##   - Reads shop item list from DataManager.prestige_shop_items
##   - Mutates GameState.prestige_tier, prestige_points, prestige_purchases
##   - Emits EventBus.prestige_triggered on successful prestige
extends Node


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("prestige_system")


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Check whether the player meets the requirements to prestige.
## Requires total skill level >= minTotalLevel and current tier < maxTier.
func can_prestige() -> bool:
	var config: Dictionary = DataManager.prestige_config
	var max_tier: int = int(config.get("maxTier", 10))
	var min_total_level: int = int(config.get("minTotalLevel", 500))

	if GameState.prestige_tier >= max_tier:
		return false
	if GameState.get_total_level() < min_total_level:
		return false
	return true


## Execute a prestige reset.
## Awards prestige points based on total level, resets skills/equipment/inventory,
## increments prestige tier, and applies any relevant passive effects.
func prestige() -> void:
	if not can_prestige():
		EventBus.chat_message.emit("You do not meet the requirements to prestige.", "system")
		return

	var config: Dictionary = DataManager.prestige_config
	var points_per_level: int = int(config.get("pointsPerTotalLevel", 10))
	var starting_credits: int = int(config.get("startingCredits", 500))

	# ── Calculate prestige points earned ──
	var total_level: int = GameState.get_total_level()
	var points_earned: int = total_level * points_per_level

	# ── Increment tier ──
	GameState.prestige_tier += 1
	var new_tier: int = GameState.prestige_tier

	# ── Award prestige points ──
	GameState.prestige_points += points_earned

	# ── Reset all skills to level 1, 0 xp ──
	for skill_id: String in GameState.skills:
		GameState.skills[skill_id] = { "level": 1, "xp": 0 }

	# ── Clear equipment slots ──
	for slot: String in GameState.equipment:
		GameState.equipment[slot] = ""

	# ── Clear inventory ──
	GameState.inventory.clear()

	# ── Calculate starting credits (base + any credit_bonus purchases) ──
	var credit_bonus: int = _get_total_credit_bonus()
	GameState.add_credits(starting_credits + credit_bonus)

	# ── Apply "hardened" passive: 120 max HP if tier >= 2 ──
	if has_passive("hardened"):
		GameState.player["max_hp"] = 120
		GameState.player["hp"] = 120
	else:
		GameState.player["max_hp"] = 100
		GameState.player["hp"] = 100

	# ── Emit prestige signal ──
	EventBus.prestige_triggered.emit(new_tier)

	# ── Chat message ──
	EventBus.chat_message.emit(
		"Prestige Tier %d achieved! +%d prestige points. All skills have been reset." % [new_tier, points_earned],
		"prestige"
	)

	# ── Float text above player ──
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		EventBus.float_text_requested.emit(
			"PRESTIGE TIER %d" % new_tier,
			player_node.global_position + Vector3(0, 4.0, 0),
			Color(1.0, 0.84, 0.0)  # Gold
		)

	# ── Emit level-up signals so UI refreshes ──
	for skill_id: String in GameState.skills:
		EventBus.player_level_up.emit(skill_id, 1)

	# ── Update credits display ──
	EventBus.player_credits_changed.emit(int(GameState.player["credits"]))


## Returns a Dictionary of the current prestige bonuses.
## Keys: "xp_rate", "damage", "reduction" — all floats representing multiplier bonuses.
## Tier 9 "transcendent" enhances all bonuses by +20%.
## Tier 10 "ascended" doubles all bonuses.
func get_prestige_bonuses() -> Dictionary:
	var config: Dictionary = DataManager.prestige_config
	var tier: int = GameState.prestige_tier
	var xp_per_tier: float = float(config.get("xpRatePerTier", 0.05))
	var dmg_per_tier: float = float(config.get("damagePerTier", 0.02))
	var red_per_tier: float = float(config.get("reductionPerTier", 0.01))

	var xp_rate: float = float(tier) * xp_per_tier
	var damage: float = float(tier) * dmg_per_tier
	var reduction: float = float(tier) * red_per_tier

	# Tier 9 "transcendent": enhance all bonuses by 20%
	if has_passive("transcendent"):
		xp_rate *= 1.2
		damage *= 1.2
		reduction *= 1.2

	# Tier 10 "ascended": double all bonuses
	if has_passive("ascended"):
		xp_rate *= 2.0
		damage *= 2.0
		reduction *= 2.0

	return {
		"xp_rate": xp_rate,
		"damage": damage,
		"reduction": reduction,
	}


## Check whether the player's current prestige tier unlocks a specific passive.
## passive_id is the string identifier (e.g. "hardened", "echo_of_knowledge").
func has_passive(passive_id: String) -> bool:
	var passives: Dictionary = DataManager.prestige_passives
	var tier: int = GameState.prestige_tier

	for tier_key: String in passives:
		var tier_num: int = int(tier_key)
		var passive: Dictionary = passives[tier_key]
		if str(passive.get("id", "")) == passive_id and tier >= tier_num:
			return true
	return false


## Return an Array of passive Dictionaries for all tiers up to and including
## the player's current prestige tier. Each entry includes { id, name, desc, color, tier }.
func get_unlocked_passives() -> Array:
	var passives: Dictionary = DataManager.prestige_passives
	var tier: int = GameState.prestige_tier
	var result: Array = []

	for tier_key: String in passives:
		var tier_num: int = int(tier_key)
		if tier_num <= tier:
			var entry: Dictionary = passives[tier_key].duplicate()
			entry["tier"] = tier_num
			result.append(entry)

	# Sort by tier ascending
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tier", 0)) < int(b.get("tier", 0))
	)
	return result


## Attempt to purchase a shop item using prestige points.
## Returns true if the purchase succeeds, false otherwise.
func purchase_shop_item(item_id: String) -> bool:
	var shop_items: Array = DataManager.prestige_shop_items
	var item: Dictionary = {}

	# Find the item definition
	for entry: Dictionary in shop_items:
		if str(entry.get("id", "")) == item_id:
			item = entry
			break

	if item.is_empty():
		EventBus.chat_message.emit("Unknown prestige shop item.", "system")
		return false

	var cost: int = int(item.get("cost", 0))
	var is_repeatable: bool = bool(item.get("repeatable", false))
	var item_name: String = str(item.get("name", item_id))
	var item_type: String = str(item.get("type", ""))

	# Check if already purchased (non-repeatable)
	if not is_repeatable and GameState.prestige_purchases.has(item_id):
		EventBus.chat_message.emit("You already own %s." % item_name, "system")
		return false

	# Check if player can afford it
	if GameState.prestige_points < cost:
		EventBus.chat_message.emit(
			"Not enough prestige points. Need %d, have %d." % [cost, GameState.prestige_points],
			"system"
		)
		return false

	# ── Deduct points ──
	GameState.prestige_points -= cost

	# ── Record purchase ──
	GameState.prestige_purchases.append(item_id)

	# ── Apply immediate effects based on type ──
	match item_type:
		"bank":
			var bank_value: int = int(item.get("value", 10))
			GameState.bank_size += bank_value
			EventBus.chat_message.emit(
				"Purchased %s! Bank expanded by %d slots." % [item_name, bank_value],
				"prestige"
			)
		"credits":
			# Credit bonus is applied on next prestige — just recorded in purchases.
			EventBus.chat_message.emit(
				"Purchased %s! Bonus will apply on next prestige." % item_name,
				"prestige"
			)
		"title":
			EventBus.chat_message.emit(
				"Purchased title: %s!" % str(item.get("value", "")),
				"prestige"
			)
		"cosmetic":
			EventBus.chat_message.emit(
				"Purchased %s!" % item_name,
				"prestige"
			)
		"xp_token":
			EventBus.chat_message.emit(
				"Purchased %s!" % item_name,
				"prestige"
			)
		_:
			EventBus.chat_message.emit(
				"Purchased %s." % item_name,
				"prestige"
			)

	return true


## Return the shop items array with a "purchased" field appended to each entry.
## For repeatable items, "purchase_count" indicates how many times it has been bought.
func get_shop_items() -> Array:
	var shop_items: Array = DataManager.prestige_shop_items
	var result: Array = []

	for entry: Dictionary in shop_items:
		var enriched: Dictionary = entry.duplicate()
		var sid: String = str(entry.get("id", ""))
		var is_repeatable: bool = bool(entry.get("repeatable", false))

		if is_repeatable:
			var count: int = _count_purchases(sid)
			enriched["purchased"] = count > 0
			enriched["purchase_count"] = count
		else:
			enriched["purchased"] = GameState.prestige_purchases.has(sid)

		result.append(enriched)

	return result


# ──────────────────────────────────────────────
#  Save / Load
# ──────────────────────────────────────────────

## Serialize internal state for the save system.
## Note: prestige_tier, prestige_points, and prestige_purchases are stored on
## GameState directly, so this only needs to capture any system-local state.
func to_save_data() -> Dictionary:
	# All prestige state lives on GameState. This hook exists for consistency
	# with other systems and future-proofing (e.g. cooldown timers).
	return {}


## Restore internal state from save data.
func from_save_data(data: Dictionary) -> void:
	# No system-local state to restore currently.
	# Guard against null data gracefully.
	if data.is_empty():
		return


# ──────────────────────────────────────────────
#  Internal Helpers
# ──────────────────────────────────────────────

## Calculate the total starting credit bonus from all "credit_bonus" purchases.
## Each purchase adds its value (default 100) to the starting credits on prestige.
func _get_total_credit_bonus() -> int:
	var bonus: int = 0
	var shop_items: Array = DataManager.prestige_shop_items

	# Find the credit_bonus item definition to get its value
	var credit_value: int = 100  # Fallback default
	for entry: Dictionary in shop_items:
		if str(entry.get("id", "")) == "credit_bonus":
			credit_value = int(entry.get("value", 100))
			break

	# Count how many times credit_bonus was purchased
	var count: int = _count_purchases("credit_bonus")
	bonus = count * credit_value

	return bonus


## Count how many times a specific item_id appears in prestige_purchases.
## Useful for repeatable items.
func _count_purchases(item_id: String) -> int:
	var count: int = 0
	for purchase: String in GameState.prestige_purchases:
		if purchase == item_id:
			count += 1
	return count
