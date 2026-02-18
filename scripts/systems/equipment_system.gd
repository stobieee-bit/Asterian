## EquipmentSystem — Manages equipping/unequipping items and stat calculations
##
## Provides functions to equip items, calculate total stats from equipment,
## and generate equipment item IDs from tier definitions.
## Equipment degradation: tier 5+ items lose condition through combat.
## Attached as a child of Player or used as a utility class.
extends Node

# ── Degradation constants ──
const DEGRADE_MIN_TIER: int = 5          # Only tier 5+ items degrade
const DEGRADE_PER_HIT_TAKEN: float = 0.002  # 0.2% per hit taken (armor slots)
const DEGRADE_PER_ATTACK: float = 0.001     # 0.1% per attack made (weapon/offhand)
const BROKEN_THRESHOLD: float = 0.0         # At 0.0 the item is fully broken
const REPAIR_COST_PER_PERCENT: float = 2.0  # Credits per 1% to repair (scaled by tier)

var _player: CharacterBody3D = null

func _ready() -> void:
	_player = get_parent()
	# Connect combat signals to degrade equipment
	EventBus.hit_landed.connect(_on_hit_for_degrade)
	EventBus.player_attacked.connect(_on_player_attack_degrade)

## Equip an item from inventory to its appropriate slot
## Returns true if equipped successfully
func equip_item(item_id: String) -> bool:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		push_warning("EquipmentSystem: Unknown item '%s'" % item_id)
		return false

	var item_type: String = str(item.get("type", ""))
	var slot: String = str(item.get("slot", ""))

	# Determine slot from type if not specified
	if slot == "":
		match item_type:
			"weapon":
				slot = "weapon"
			"offhand":
				slot = "offhand"
			"armor":
				slot = str(item.get("slot", "body"))
			_:
				push_warning("EquipmentSystem: Item '%s' type '%s' is not equippable" % [item_id, item_type])
				return false

	if not GameState.equipment.has(slot):
		push_warning("EquipmentSystem: Invalid slot '%s'" % slot)
		return false

	# Check level requirement — use style's skill level if item has a style
	var level_req: int = int(item.get("levelReq", 0))
	if level_req > 0:
		var item_style: String = str(item.get("style", ""))
		if item_style == "":
			item_style = str(item.get("armorStyle", ""))

		var check_level: int = 0
		var skill_name_display: String = "Combat"

		if item_style != "" and GameState.skills.has(item_style):
			check_level = int(GameState.skills[item_style]["level"])
			var skill_data: Dictionary = DataManager.get_skill(item_style)
			skill_name_display = str(skill_data.get("name", item_style))
		else:
			check_level = GameState.get_combat_level()

		if check_level < level_req:
			EventBus.chat_message.emit("Need %s level %d to equip this." % [skill_name_display, level_req], "system")
			return false

	# Check skill requirements
	var equip_req: Dictionary = item.get("equipReq", {})
	for skill_id in equip_req:
		var req_level: int = int(equip_req[skill_id])
		var current_level: int = int(GameState.skills.get(skill_id, {}).get("level", 1))
		if current_level < req_level:
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = str(skill_data.get("name", skill_id))
			EventBus.chat_message.emit("Need %s level %d to equip this." % [skill_name, req_level], "system")
			return false

	# Unequip current item in that slot first
	var current_id: String = str(GameState.equipment.get(slot, ""))
	if current_id != "":
		unequip_slot(slot)

	# Remove from inventory
	if not GameState.remove_item(item_id):
		return false

	# Equip it
	GameState.equipment[slot] = item_id
	# Fresh items start at full condition
	GameState.equipment_condition[slot] = 1.0

	# If weapon, switch combat style to match
	if slot == "weapon":
		var weapon_style: String = str(item.get("style", ""))
		if weapon_style != "":
			GameState.player["combat_style"] = weapon_style
			EventBus.combat_style_changed.emit(weapon_style)
			# Refresh combat controller abilities
			var combat: Node = get_node_or_null("../CombatController")
			if combat and combat.has_method("refresh_abilities"):
				combat.refresh_abilities()

	EventBus.item_equipped.emit(slot, item_id)

	# Recalculate stats
	_recalc_stats()

	var item_name: String = str(item.get("name", item_id))
	EventBus.chat_message.emit("Equipped %s." % item_name, "equipment")
	return true

## Unequip an item from a slot and put it back in inventory
func unequip_slot(slot: String) -> bool:
	if not GameState.equipment.has(slot):
		return false

	var item_id: String = str(GameState.equipment.get(slot, ""))
	if item_id == "":
		return false

	# Need inventory space
	if not GameState.has_inventory_space():
		EventBus.inventory_full.emit()
		EventBus.chat_message.emit("Inventory full — can't unequip.", "system")
		return false

	# Move to inventory
	GameState.equipment[slot] = ""
	GameState.add_item(item_id, 1)
	EventBus.item_unequipped.emit(slot, item_id)

	# Recalculate stats
	_recalc_stats()

	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_name: String = str(item_data.get("name", item_id))
	EventBus.chat_message.emit("Unequipped %s." % item_name, "equipment")
	return true

## Get condition multiplier for a slot. Returns 1.0 for non-degradable items.
func get_condition_mult(slot: String) -> float:
	var item_id: String = str(GameState.equipment.get(slot, ""))
	if item_id == "":
		return 1.0
	var item: Dictionary = DataManager.get_item(item_id)
	var tier: int = int(item.get("tier", 1))
	if tier < DEGRADE_MIN_TIER:
		return 1.0  # Low-tier items don't degrade
	var cond: float = float(GameState.equipment_condition.get(slot, 1.0))
	# At 0% condition, stats reduced to 25% (not zero — still usable but weak)
	return 0.25 + 0.75 * cond

## Get total armor from all equipped armor pieces (condition-adjusted)
func get_total_armor() -> int:
	var total: float = 0.0
	for slot in ["head", "body", "legs", "boots", "gloves"]:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			continue
		var item: Dictionary = DataManager.get_item(item_id)
		var base: float = float(item.get("armor", 0))
		total += base * get_condition_mult(slot)
	return int(total)

## Get weapon damage for equipped weapon (condition-adjusted)
func get_weapon_damage() -> int:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 0
	var item: Dictionary = DataManager.get_item(weapon_id)
	var base: float = float(item.get("damage", 0))
	return int(base * get_condition_mult("weapon"))

## Get weapon accuracy for equipped weapon (condition-adjusted)
func get_weapon_accuracy() -> int:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 70  # Base accuracy
	var item: Dictionary = DataManager.get_item(weapon_id)
	var base_acc: float = float(item.get("accuracy", 70))
	# Accuracy degrades more gently — only half the condition penalty
	var cond: float = get_condition_mult("weapon")
	var adj_cond: float = 0.5 + 0.5 * cond
	return int(base_acc * adj_cond)

## Get offhand stats
func get_offhand_stats() -> Dictionary:
	var oh_id: String = str(GameState.equipment.get("offhand", ""))
	if oh_id == "":
		return {}
	return DataManager.get_item(oh_id)

## Get total damage bonus from all equipment (condition-adjusted)
func get_total_damage_bonus() -> int:
	var total: float = 0.0
	for slot in GameState.equipment:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			continue
		var item: Dictionary = DataManager.get_item(item_id)
		var base: float = float(item.get("damage", 0))
		total += base * get_condition_mult(slot)
	return int(total)

# ── Set bonus system ──
# Armor slots that count for set bonuses
const SET_ARMOR_SLOTS: Array = ["head", "body", "legs", "boots", "gloves"]

## Set bonus thresholds: { pieces_required: { stat_key: value } }
## "nano" = offensive (damage focus), "tesla" = balanced (accuracy + defense),
## "void" = caster (range + damage at distance)
const SET_BONUSES: Dictionary = {
	"nano": {
		3: { "damage": 5, "desc": "+5 Damage" },
		5: { "damage": 12, "attack_speed_mult": 0.9, "passive": "bleed_on_hit", "desc": "+12 Damage, +10% Attack Speed, 30% Bleed on Hit" },
	},
	"tesla": {
		3: { "accuracy": 8, "desc": "+8 Accuracy" },
		5: { "accuracy": 15, "armor": 10, "passive": "chain_lightning", "desc": "+15 Accuracy, +10 Armor, 20% Chain Lightning" },
	},
	"void": {
		3: { "range": 1.0, "desc": "+1.0 Attack Range" },
		5: { "range": 2.0, "damage": 8, "passive": "void_explosion", "desc": "+2.0 Range, +8 Damage, AoE on Kill" },
	},
}

## Count how many armor pieces of each style are equipped
func get_set_piece_counts() -> Dictionary:
	var counts: Dictionary = {}  # { style: count }
	for slot in SET_ARMOR_SLOTS:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			continue
		var item: Dictionary = DataManager.get_item(item_id)
		var style: String = str(item.get("armorStyle", ""))
		if style == "":
			continue
		if not counts.has(style):
			counts[style] = 0
		counts[style] += 1
	return counts

## Get the active set bonus for a given style (highest threshold met)
func get_active_set_bonus(style: String) -> Dictionary:
	var counts: Dictionary = get_set_piece_counts()
	var pieces: int = int(counts.get(style, 0))
	var bonuses: Dictionary = SET_BONUSES.get(style, {})
	var result: Dictionary = {}

	# Apply all bonuses where threshold is met (cumulative)
	for threshold in bonuses:
		if pieces >= int(threshold):
			var bonus: Dictionary = bonuses[threshold]
			for key in bonus:
				if key == "desc":
					continue
				if result.has(key):
					result[key] = float(result[key]) + float(bonus[key])
				else:
					result[key] = float(bonus[key])
			result["desc"] = str(bonus.get("desc", ""))
			result["threshold"] = int(threshold)

	result["pieces"] = pieces
	result["style"] = style
	return result

## Get combined set bonus across all styles (player benefits from best matching set)
func get_current_set_bonus() -> Dictionary:
	var counts: Dictionary = get_set_piece_counts()
	var best: Dictionary = { "pieces": 0 }
	for style in counts:
		var bonus: Dictionary = get_active_set_bonus(style)
		if int(bonus.get("pieces", 0)) > int(best.get("pieces", 0)):
			best = bonus
	return best

## Get set bonus damage (for combat_controller)
func get_set_bonus_damage() -> int:
	var bonus: Dictionary = get_current_set_bonus()
	return int(bonus.get("damage", 0))

## Get set bonus accuracy (for combat_controller)
func get_set_bonus_accuracy() -> int:
	var bonus: Dictionary = get_current_set_bonus()
	return int(bonus.get("accuracy", 0))

## Get set bonus armor (for combat_controller)
func get_set_bonus_armor() -> int:
	var bonus: Dictionary = get_current_set_bonus()
	return int(bonus.get("armor", 0))

## Get set bonus attack range (for combat_controller)
func get_set_bonus_range() -> float:
	var bonus: Dictionary = get_current_set_bonus()
	return float(bonus.get("range", 0.0))

## Get set bonus attack speed multiplier (for combat_controller)
func get_set_bonus_attack_speed_mult() -> float:
	var bonus: Dictionary = get_current_set_bonus()
	return float(bonus.get("attack_speed_mult", 1.0))

## Get 5-piece set passive name (empty string if not active)
func get_set_bonus_passive() -> String:
	var bonus: Dictionary = get_current_set_bonus()
	if int(bonus.get("threshold", 0)) >= 5:
		return str(bonus.get("passive", ""))
	return ""

## Recalculate player stats based on equipment
func _recalc_stats() -> void:
	# Base max HP = 100, plus armor-based bonus (includes set bonus armor)
	var armor: int = get_total_armor() + get_set_bonus_armor()
	var hp_bonus: int = int(armor * 0.5)
	GameState.player["max_hp"] = 100 + hp_bonus

	# Clamp current HP
	if GameState.player["hp"] > GameState.player["max_hp"]:
		GameState.player["hp"] = GameState.player["max_hp"]

## Generate an equipment item ID from tier and type
## e.g., generate_item_id(3, "nanoblade") → "cobalt_nanoblade"
static func generate_item_id(tier: int, suffix: String) -> String:
	var tier_defs: Array = DataManager.equipment_data.get("tier_defs", [])
	for td in tier_defs:
		if int(td.get("tier", 0)) == tier:
			return "%s_%s" % [str(td.get("prefix", "scrap")), suffix]
	return "scrap_%s" % suffix

# ── Equipment degradation ──

## Check if a slot's item is degradable (tier 5+)
func _is_slot_degradable(slot: String) -> bool:
	var item_id: String = str(GameState.equipment.get(slot, ""))
	if item_id == "":
		return false
	var item: Dictionary = DataManager.get_item(item_id)
	return int(item.get("tier", 1)) >= DEGRADE_MIN_TIER

## Degrade a specific slot by an amount
func _degrade_slot(slot: String, amount: float) -> void:
	if not _is_slot_degradable(slot):
		return
	var old_cond: float = float(GameState.equipment_condition.get(slot, 1.0))
	var new_cond: float = maxf(BROKEN_THRESHOLD, old_cond - amount)
	GameState.equipment_condition[slot] = new_cond

	# Warn at 25% condition
	if old_cond > 0.25 and new_cond <= 0.25:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		var item: Dictionary = DataManager.get_item(item_id)
		var name: String = str(item.get("name", item_id))
		EventBus.chat_message.emit("⚠ %s is badly damaged! Repair soon." % name, "system")

	# Warn when broken
	if old_cond > 0.0 and new_cond <= 0.0:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		var item: Dictionary = DataManager.get_item(item_id)
		var name: String = str(item.get("name", item_id))
		EventBus.chat_message.emit("✖ %s has broken! Stats severely reduced." % name, "system")

## Called when the player takes a hit — degrade armor
func _on_hit_for_degrade(target: Node, _damage: int, _is_crit: bool) -> void:
	# Only degrade when the PLAYER is the target
	if target != _player:
		return
	for slot in ["head", "body", "legs", "boots", "gloves", "offhand"]:
		_degrade_slot(slot, DEGRADE_PER_HIT_TAKEN)

## Called when the player attacks — degrade weapon and offhand
func _on_player_attack_degrade() -> void:
	_degrade_slot("weapon", DEGRADE_PER_ATTACK)
	_degrade_slot("offhand", DEGRADE_PER_ATTACK)

# ── Repair system ──

## Get repair cost for a single slot. Returns 0 if nothing to repair.
func get_repair_cost(slot: String) -> int:
	if not _is_slot_degradable(slot):
		return 0
	var cond: float = float(GameState.equipment_condition.get(slot, 1.0))
	if cond >= 1.0:
		return 0
	var item_id: String = str(GameState.equipment.get(slot, ""))
	var item: Dictionary = DataManager.get_item(item_id)
	var tier: int = int(item.get("tier", 1))
	var missing_pct: float = (1.0 - cond) * 100.0
	# Cost scales with tier: tier 5 = 2x base, tier 9 = 10x base
	var tier_mult: float = float(tier - DEGRADE_MIN_TIER + 2)
	return int(ceilf(missing_pct * REPAIR_COST_PER_PERCENT * tier_mult))

## Get total repair cost for all equipment
func get_total_repair_cost() -> int:
	var total: int = 0
	for slot in GameState.equipment:
		total += get_repair_cost(slot)
	return total

## Repair a single slot. Returns true if successful.
func repair_slot(slot: String) -> bool:
	var cost: int = get_repair_cost(slot)
	if cost <= 0:
		return false
	if not GameState.has_credits(cost):
		EventBus.chat_message.emit("Not enough credits to repair (%d needed)." % cost, "system")
		return false
	GameState.add_credits(-cost)
	GameState.equipment_condition[slot] = 1.0
	var item_id: String = str(GameState.equipment.get(slot, ""))
	var item: Dictionary = DataManager.get_item(item_id)
	var name: String = str(item.get("name", item_id))
	EventBus.chat_message.emit("Repaired %s for %d credits." % [name, cost], "equipment")
	_recalc_stats()
	return true

## Repair all equipment. Returns total credits spent.
func repair_all() -> int:
	var total_spent: int = 0
	var total_cost: int = get_total_repair_cost()
	if total_cost <= 0:
		EventBus.chat_message.emit("All equipment is in good condition.", "system")
		return 0
	if not GameState.has_credits(total_cost):
		EventBus.chat_message.emit("Not enough credits to repair all (%d needed)." % total_cost, "system")
		return 0
	for slot in GameState.equipment:
		var cost: int = get_repair_cost(slot)
		if cost > 0:
			GameState.add_credits(-cost)
			GameState.equipment_condition[slot] = 1.0
			total_spent += cost
	EventBus.chat_message.emit("Repaired all equipment for %d credits." % total_spent, "equipment")
	_recalc_stats()
	return total_spent

## Check if any equipment needs repair
func has_degraded_equipment() -> bool:
	for slot in GameState.equipment:
		if _is_slot_degradable(slot):
			var cond: float = float(GameState.equipment_condition.get(slot, 1.0))
			if cond < 1.0:
				return true
	return false
