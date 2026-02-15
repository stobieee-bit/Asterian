## CraftingSystem — Handles recipe lookup and crafting logic
##
## Player interacts with a processing station, selects a recipe,
## and crafts items. Checks ingredients, skill level, gives XP.
extends Node

## Check if a recipe can be crafted
func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = DataManager.get_recipe(recipe_id)
	if recipe.is_empty():
		return false

	# Check skill level
	var skill_id: String = str(recipe.get("skill", ""))
	var req_level: int = int(recipe.get("level", 1))
	if skill_id != "":
		var current_level: int = int(GameState.skills.get(skill_id, {}).get("level", 1))
		if current_level < req_level:
			return false

	# Check ingredients
	var inputs: Dictionary = recipe.get("input", {})
	for item_id in inputs:
		var needed: int = int(inputs[item_id])
		var have: int = GameState.count_item(item_id)
		if have < needed:
			return false

	# Check inventory space for outputs
	var outputs: Dictionary = recipe.get("output", {})
	var slots_needed: int = 0
	for item_id in outputs:
		var idx: int = GameState.find_inventory_item(item_id)
		if idx < 0:
			slots_needed += 1

	if GameState.inventory.size() + slots_needed > GameState.inventory_size:
		return false

	return true

## Craft a recipe. Returns true if successful.
func craft(recipe_id: String) -> bool:
	var recipe: Dictionary = DataManager.get_recipe(recipe_id)
	if recipe.is_empty():
		return false

	if not can_craft(recipe_id):
		EventBus.chat_message.emit("Cannot craft: missing ingredients or requirements.", "system")
		return false

	# Consume inputs
	var inputs: Dictionary = recipe.get("input", {})
	for item_id in inputs:
		var needed: int = int(inputs[item_id])
		GameState.remove_item(item_id, needed)

	# Give outputs
	var outputs: Dictionary = recipe.get("output", {})
	for item_id in outputs:
		var qty: int = int(outputs[item_id])
		GameState.add_item(item_id, qty)

	# Give XP
	var skill_id: String = str(recipe.get("skill", ""))
	var xp: int = int(recipe.get("xp", 0))
	if skill_id != "" and xp > 0 and GameState.skills.has(skill_id):
		GameState.skills[skill_id]["xp"] = int(GameState.skills[skill_id]["xp"]) + xp
		EventBus.player_xp_gained.emit(skill_id, xp)

		# Level up check
		var current_level: int = int(GameState.skills[skill_id]["level"])
		var current_xp: int = int(GameState.skills[skill_id]["xp"])
		var next_xp: int = DataManager.xp_for_level(current_level + 1)
		if next_xp > 0 and current_xp >= next_xp:
			GameState.skills[skill_id]["level"] = current_level + 1
			EventBus.player_level_up.emit(skill_id, current_level + 1)

	# Emit signals
	var recipe_name: String = str(recipe.get("name", recipe_id))
	EventBus.crafting_complete.emit(recipe_id)
	EventBus.chat_message.emit("Crafted %s!" % recipe_name, "loot")

	# Float text on player
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		EventBus.float_text_requested.emit(
			"Crafted %s" % recipe_name,
			player.global_position + Vector3(0, 3.0, 0),
			Color(0.2, 0.8, 1.0)
		)
		if xp > 0:
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = str(skill_data.get("name", skill_id))
			EventBus.float_text_requested.emit(
				"+%d %s XP" % [xp, skill_name],
				player.global_position + Vector3(0, 3.5, 0),
				Color(0.3, 0.9, 0.3)
			)

	return true

## Get all recipes for a skill that the player can see
func get_available_recipes(skill_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var all_recipes: Array = DataManager.get_recipes_for_skill(skill_id)
	for recipe in all_recipes:
		result.append(recipe)
	return result
