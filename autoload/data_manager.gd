## DataManager — Loads and serves all JSON game data (autoloaded singleton)
##
## All game balance data lives in res://data/*.json files (extracted from game.js).
## This singleton loads them at startup and provides typed lookup functions.
##
## Usage:
##   var enemy = DataManager.get_enemy("chithari")
##   var item = DataManager.get_item("ferrite_ore")
##   var recipe = DataManager.get_recipe("ferrite_bar")
extends Node

# ── Raw data dictionaries (loaded from JSON) ──
var items: Dictionary = {}
var recipes: Dictionary = {}
var enemies: Dictionary = {}
var enemy_defs: Array = []
var areas: Dictionary = {}
var corrupted_areas: Dictionary = {}
var area_atmosphere: Dictionary = {}
var corridors: Array = []
var area_level_ranges: Dictionary = {}
var enemy_sub_zones: Array = []
var processing_stations: Array = []
var skill_defs: Dictionary = {}
var synergy_defs: Array = []  # Deprecated — kept empty for compatibility
var skill_unlocks: Dictionary = {}
var xp_table: Array = []
var quests: Dictionary = {}
var quest_chains: Array = []
var board_quests: Dictionary = {}
var slayer_shop: Dictionary = {}
var relic_recipes: Dictionary = {}
var npcs: Dictionary = {}
var achievements: Array = []
var prestige_config: Dictionary = {}
var prestige_passives: Dictionary = {}
var prestige_shop_items: Array = []
var dungeon_themes: Dictionary = {}
var dungeon_area_theme_map: Dictionary = {}
var dungeon_modifiers: Dictionary = {}
var dungeon_config: Dictionary = {}
var dungeon_trap_types: Dictionary = {}
var dungeon_loot_tiers: Array = []
var pets: Array = []
var equipment_data: Dictionary = {}
var enemy_loot_tables: Dictionary = {}
var abilities: Dictionary = {}

# ── Loading ──

func _ready() -> void:
	_load_all_data()
	print("DataManager: All game data loaded.")

func _load_all_data() -> void:
	# Items
	items = _load_json("res://data/items.json")

	# Recipes
	recipes = _load_json("res://data/recipes.json")

	# Enemies
	enemies = _load_json("res://data/enemies.json")

	# Enemy defs (raw)
	var ed = _load_json("res://data/enemy_defs.json")
	if ed is Array:
		enemy_defs = ed
	elif ed is Dictionary:
		enemy_defs = ed.values() if ed.size() > 0 else []

	# Areas (compound file)
	var area_data: Dictionary = _load_json("res://data/areas.json")
	areas = area_data.get("areas", {})
	corrupted_areas = area_data.get("corrupted_areas", {})
	area_atmosphere = area_data.get("atmosphere", {})
	corridors = area_data.get("corridors", [])
	area_level_ranges = area_data.get("level_ranges", {})
	enemy_sub_zones = area_data.get("sub_zones", [])
	processing_stations = area_data.get("processing_stations", [])

	# Skills (compound file)
	var skill_data: Dictionary = _load_json("res://data/skills.json")
	skill_defs = skill_data.get("skill_defs", {})
	# synergy_defs removed — no longer used
	skill_unlocks = skill_data.get("unlocks", {})
	xp_table = skill_data.get("xp_table", [])

	# Quests (compound file)
	var quest_data: Dictionary = _load_json("res://data/quests.json")
	quests = quest_data.get("quests", {})
	quest_chains = quest_data.get("quest_chains", [])
	board_quests = quest_data.get("board_quests", {})
	slayer_shop = quest_data.get("slayer_shop", {})
	relic_recipes = quest_data.get("relic_recipes", {})

	# NPCs
	var npcs_data: Variant = _load_json("res://data/npcs.json")
	if npcs_data is Dictionary:
		npcs = npcs_data

	# Achievements
	var ach: Variant = _load_json("res://data/achievements.json")
	if ach is Array:
		achievements = ach

	# Prestige (compound file)
	var pres_data: Dictionary = _load_json("res://data/prestige.json")
	prestige_config = pres_data.get("config", {})
	prestige_passives = pres_data.get("passives", {})
	prestige_shop_items = pres_data.get("shop_items", [])

	# Dungeons (compound file)
	var dung_data: Dictionary = _load_json("res://data/dungeons.json")
	dungeon_themes = dung_data.get("themes", {})
	dungeon_area_theme_map = dung_data.get("area_theme_map", {})
	dungeon_modifiers = dung_data.get("modifiers", {})
	dungeon_config = dung_data.get("config", {})
	dungeon_trap_types = dung_data.get("trap_types", {})
	dungeon_loot_tiers = dung_data.get("loot_tiers", [])

	# Pets
	var pet_data: Variant = _load_json("res://data/pets.json")
	if pet_data is Array:
		pets = pet_data

	# Equipment data (compound file)
	var equip_data: Variant = _load_json("res://data/equipment.json")
	if equip_data is Dictionary:
		equipment_data = equip_data

	# Enemy loot lookup tables
	var loot_data: Variant = _load_json("res://data/enemy_loot_tables.json")
	if loot_data is Dictionary:
		enemy_loot_tables = loot_data

	# Abilities
	var ability_data: Variant = _load_json("res://data/abilities.json")
	if ability_data is Dictionary:
		abilities = ability_data

	# Print summary
	print("  Items: %d" % items.size())
	print("  Recipes: %d" % recipes.size())
	print("  Enemies: %d" % enemies.size())
	print("  Areas: %d + %d corrupted" % [areas.size(), corrupted_areas.size()])
	print("  Skills: %d" % skill_defs.size())
	print("  Quests: %d + %d board" % [quests.size(), board_quests.size()])
	print("  NPCs: %d" % npcs.size())
	print("  Achievements: %d" % achievements.size())
	print("  Pets: %d" % pets.size())
	print("  Abilities: %d" % abilities.size())

# ── JSON loading utility ──

func _load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_warning("DataManager: File not found: %s" % file_path)
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("DataManager: Could not open: %s" % file_path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("DataManager: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return {}
	return json.data

# ── Lookup API ──

## Get an item definition by id. Returns empty dict if not found.
func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}

## Get a recipe definition by id. Returns empty dict if not found.
func get_recipe(recipe_id: String) -> Dictionary:
	if recipes.has(recipe_id):
		return recipes[recipe_id]
	return {}

## Get an enemy definition by type id. Returns empty dict if not found.
func get_enemy(enemy_id: String) -> Dictionary:
	if enemies.has(enemy_id):
		return enemies[enemy_id]
	return {}

## Get an area definition by id. Returns empty dict if not found.
func get_area(area_id: String) -> Dictionary:
	if areas.has(area_id):
		return areas[area_id]
	if corrupted_areas.has(area_id):
		return corrupted_areas[area_id]
	return {}

## Get atmosphere settings for an area. Returns empty dict if not found.
func get_atmosphere(area_id: String) -> Dictionary:
	if area_atmosphere.has(area_id):
		return area_atmosphere[area_id]
	return {}

## Get an NPC definition by id. Returns empty dict if not found.
func get_npc(npc_id: String) -> Dictionary:
	if npcs.has(npc_id):
		return npcs[npc_id]
	return {}

## Get a quest definition by id. Returns empty dict if not found.
func get_quest(quest_id: String) -> Dictionary:
	if quests.has(quest_id):
		return quests[quest_id]
	return {}

## Get a skill definition by id. Returns empty dict if not found.
func get_skill(skill_id: String) -> Dictionary:
	if skill_defs.has(skill_id):
		return skill_defs[skill_id]
	return {}

## Current max skill level (capped for early game testing)
const MAX_SKILL_LEVEL: int = 99

## Get XP required for a given level. Returns 0 if level exceeds cap.
func xp_for_level(level: int) -> int:
	if level > MAX_SKILL_LEVEL:
		return 0
	var idx: int = clampi(level - 1, 0, xp_table.size() - 1)
	return int(xp_table[idx]) if idx < xp_table.size() else 0

## Get level for a given amount of XP (capped at MAX_SKILL_LEVEL)
func level_for_xp(xp: int) -> int:
	for i in range(mini(xp_table.size() - 1, MAX_SKILL_LEVEL - 1), -1, -1):
		if xp >= int(xp_table[i]):
			return i + 1
	return 1

## Get all area IDs (including corrupted)
func get_all_area_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in areas.keys():
		ids.append(key)
	for key in corrupted_areas.keys():
		ids.append(key)
	return ids

## Get sub-zones for a specific area
func get_sub_zones_for_area(area_id: String) -> Array:
	var result: Array = []
	for zone in enemy_sub_zones:
		if zone.get("area", "") == area_id:
			result.append(zone)
	return result

## Get all recipes for a specific skill (includes "id" key in each recipe)
func get_recipes_for_skill(skill_id: String) -> Array:
	var result: Array = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id].duplicate()
		if recipe.get("skill", "") == skill_id:
			recipe["id"] = recipe_id
			result.append(recipe)
	return result

## Get an ability definition by id. Returns empty dict if not found.
func get_ability(ability_id: String) -> Dictionary:
	if abilities.has(ability_id):
		return abilities[ability_id]
	return {}

## Get all abilities for a specific combat style, sorted by slot.
func get_abilities_for_style(style: String) -> Array:
	var result: Array = []
	for ability_id in abilities:
		var ab: Dictionary = abilities[ability_id]
		if str(ab.get("style", "")) == style:
			result.append(ab)
	# Sort by slot number
	result.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return result

## Get all shared (defensive/utility) abilities, sorted by slot
func get_shared_abilities() -> Array:
	var result: Array = []
	for ability_id in abilities:
		var ab: Dictionary = abilities[ability_id]
		if ab.get("shared", false):
			result.append(ab)
	result.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return result
