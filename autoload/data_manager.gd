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
var synergy_defs: Array = []
var skill_unlocks: Dictionary = {}
var xp_table: Array = []
var quests: Dictionary = {}
var quest_chains: Array = []
var board_quests: Dictionary = {}
var slayer_shop: Array = []
var relic_recipes: Array = []
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
	var area_data := _load_json("res://data/areas.json")
	areas = area_data.get("areas", {})
	corrupted_areas = area_data.get("corrupted_areas", {})
	area_atmosphere = area_data.get("atmosphere", {})
	corridors = area_data.get("corridors", [])
	area_level_ranges = area_data.get("level_ranges", {})
	enemy_sub_zones = area_data.get("sub_zones", [])
	processing_stations = area_data.get("processing_stations", [])

	# Skills (compound file)
	var skill_data := _load_json("res://data/skills.json")
	skill_defs = skill_data.get("skill_defs", {})
	synergy_defs = skill_data.get("synergies", [])
	skill_unlocks = skill_data.get("unlocks", {})
	xp_table = skill_data.get("xp_table", [])

	# Quests (compound file)
	var quest_data := _load_json("res://data/quests.json")
	quests = quest_data.get("quests", {})
	quest_chains = quest_data.get("quest_chains", [])
	board_quests = quest_data.get("board_quests", {})
	slayer_shop = quest_data.get("slayer_shop", [])
	relic_recipes = quest_data.get("relic_recipes", [])

	# NPCs
	npcs = _load_json("res://data/npcs.json")

	# Achievements
	var ach = _load_json("res://data/achievements.json")
	if ach is Array:
		achievements = ach

	# Prestige (compound file)
	var pres_data := _load_json("res://data/prestige.json")
	prestige_config = pres_data.get("config", {})
	prestige_passives = pres_data.get("passives", {})
	prestige_shop_items = pres_data.get("shop_items", [])

	# Dungeons (compound file)
	var dung_data := _load_json("res://data/dungeons.json")
	dungeon_themes = dung_data.get("themes", {})
	dungeon_area_theme_map = dung_data.get("area_theme_map", {})
	dungeon_modifiers = dung_data.get("modifiers", {})
	dungeon_config = dung_data.get("config", {})
	dungeon_trap_types = dung_data.get("trap_types", {})
	dungeon_loot_tiers = dung_data.get("loot_tiers", [])

	# Pets
	var pet_data = _load_json("res://data/pets.json")
	if pet_data is Array:
		pets = pet_data

	# Equipment data (compound file)
	equipment_data = _load_json("res://data/equipment.json")

	# Enemy loot lookup tables
	enemy_loot_tables = _load_json("res://data/enemy_loot_tables.json")

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

# ── JSON loading utility ──

func _load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_warning("DataManager: File not found: %s" % file_path)
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("DataManager: Could not open: %s" % file_path)
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
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

## Get XP required for a given level (1-99)
func xp_for_level(level: int) -> int:
	var idx := clampi(level - 1, 0, xp_table.size() - 1)
	return int(xp_table[idx]) if idx < xp_table.size() else 0

## Get level for a given amount of XP
func level_for_xp(xp: int) -> int:
	for i in range(xp_table.size() - 1, -1, -1):
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
	var result := []
	for zone in enemy_sub_zones:
		if zone.get("area", "") == area_id:
			result.append(zone)
	return result

## Get all recipes for a specific skill
func get_recipes_for_skill(skill_id: String) -> Array:
	var result := []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		if recipe.get("skill", "") == skill_id:
			result.append(recipe)
	return result
