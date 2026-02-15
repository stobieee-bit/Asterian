## EquipmentSystem — Manages equipping/unequipping items and stat calculations
##
## Provides functions to equip items, calculate total stats from equipment,
## and generate equipment item IDs from tier definitions.
## Attached as a child of Player or used as a utility class.
extends Node

var _player: CharacterBody3D = null

func _ready() -> void:
	_player = get_parent()

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

	# Check level requirement
	var level_req: int = int(item.get("levelReq", 0))
	if level_req > 0:
		var combat_lvl: int = GameState.get_combat_level()
		if combat_lvl < level_req:
			EventBus.chat_message.emit("Need combat level %d to equip this." % level_req, "system")
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

## Get total armor from all equipped armor pieces
func get_total_armor() -> int:
	var total: int = 0
	for slot in ["head", "body", "legs", "boots", "gloves"]:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			continue
		var item: Dictionary = DataManager.get_item(item_id)
		total += int(item.get("armor", 0))
	return total

## Get weapon damage for equipped weapon
func get_weapon_damage() -> int:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 0
	var item: Dictionary = DataManager.get_item(weapon_id)
	return int(item.get("damage", 0))

## Get weapon accuracy for equipped weapon
func get_weapon_accuracy() -> int:
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		return 70  # Base accuracy
	var item: Dictionary = DataManager.get_item(weapon_id)
	return int(item.get("accuracy", 70))

## Get offhand stats
func get_offhand_stats() -> Dictionary:
	var oh_id: String = str(GameState.equipment.get("offhand", ""))
	if oh_id == "":
		return {}
	return DataManager.get_item(oh_id)

## Get total damage bonus from all equipment
func get_total_damage_bonus() -> int:
	var total: int = 0
	for slot in GameState.equipment:
		var item_id: String = str(GameState.equipment.get(slot, ""))
		if item_id == "":
			continue
		var item: Dictionary = DataManager.get_item(item_id)
		total += int(item.get("damage", 0))
	return total

## Recalculate player stats based on equipment
func _recalc_stats() -> void:
	# Base max HP = 100, plus armor-based bonus
	var armor: int = get_total_armor()
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
