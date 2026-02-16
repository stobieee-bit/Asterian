## GameState — Global game state singleton (autoloaded)
##
## Holds all runtime state: player data, current area, settings, etc.
## This is the single source of truth that gets saved/loaded.
extends Node

# ── Current area ──
var current_area: String = "station-hub"
var previous_area: String = ""

# ── Player data ──
var player: Dictionary = {
	"hp": 100,
	"max_hp": 100,
	"energy": 100,
	"max_energy": 100,
	"adrenaline": 0.0,
	"credits": 0,
	"combat_style": "nano",  # nano, tesla, or void
	"position": Vector3.ZERO,
}

# ── Skills: { skill_id: { level: int, xp: int } } ──
var skills: Dictionary = {
	"nano": { "level": 1, "xp": 0 },
	"tesla": { "level": 1, "xp": 0 },
	"void": { "level": 1, "xp": 0 },
	"astromining": { "level": 1, "xp": 0 },
	"xenobotany": { "level": 1, "xp": 0 },
	"bioforge": { "level": 1, "xp": 0 },
	"circuitry": { "level": 1, "xp": 0 },
	"xenocook": { "level": 1, "xp": 0 },
}

# ── Equipment: { slot_name: item_id or null } ──
var equipment: Dictionary = {
	"head": "",
	"body": "",
	"legs": "",
	"boots": "",
	"gloves": "",
	"weapon": "",
	"offhand": "",
}

# ── Inventory: Array of { item_id: String, quantity: int } ──
var inventory: Array[Dictionary] = []
var inventory_size: int = 28

# ── Bank: Array of { item_id: String, quantity: int } ──
var bank: Array[Dictionary] = []
var bank_size: int = 48

# ── Quest tracking ──
var active_quests: Dictionary = {}   # { quest_id: { step: int, progress: {} } }
var completed_quests: Array[String] = []

# ── Prestige ──
var prestige_tier: int = 0
var prestige_points: int = 0
var prestige_purchases: Array[String] = []

# ── Slayer ──
var slayer_task: Dictionary = {}  # { enemy_type, count, remaining, area }
var slayer_points: int = 0
var slayer_streak: int = 0

# ── Achievements ──
var unlocked_achievements: Array[String] = []

# ── Collection log ──
var collection_log: Array[String] = []

# ── Boss kill tracking ──
var boss_kills: Dictionary = {}  # { enemy_id: kill_count }

# ── Dungeon state ──
var dungeon_active: bool = false
var dungeon_floor: int = 0
var dungeon_max_floor: int = 0

# ── Pets ──
var active_pet: String = ""
var owned_pets: Dictionary = {}  # { pet_id: { level: int, xp: int } }

# ── Settings ──
var settings: Dictionary = {
	"music_volume": 0.5,
	"sfx_volume": 0.7,
	"show_damage_numbers": true,
	"show_hp_bars": true,
	"auto_retaliate": true,
}

# ── Panel layout: { panel_name: { x, y, visible, locked } } ──
var panel_layout: Dictionary = {}

# ── Tutorial tracking ──
var tutorial: Dictionary = {
	"completed": false,
	"skipped": false,
	"current_step": 0,
	"steps_done": [],
}

# ── Play time tracking ──
var total_play_time: float = 0.0
var session_start_time: float = 0.0

func _ready() -> void:
	session_start_time = Time.get_unix_time_from_system()

func _process(delta: float) -> void:
	total_play_time += delta

# ── Helper functions ──

## Get total combat level (average of 3 combat skills)
func get_combat_level() -> int:
	var total: int = int(skills["nano"]["level"]) + int(skills["tesla"]["level"]) + int(skills["void"]["level"])
	return int(total / 3.0)

## Get total level across all skills
func get_total_level() -> int:
	var total: int = 0
	for skill_data in skills.values():
		total += int(skill_data["level"])
	return total

## Check if player has enough credits
func has_credits(amount: int) -> bool:
	return player["credits"] >= amount

## Add credits (clamped to 0)
func add_credits(amount: int) -> void:
	player["credits"] = max(0, player["credits"] + amount)
	EventBus.player_credits_changed.emit(player["credits"])

## Check if inventory has space
func has_inventory_space() -> bool:
	return inventory.size() < inventory_size

## Find item in inventory by id, returns index or -1
func find_inventory_item(item_id: String) -> int:
	for i in range(inventory.size()):
		if inventory[i]["item_id"] == item_id:
			return i
	return -1

## Add item to inventory. Returns true if ALL items were added.
## Items NEVER stack in inventory — each item takes its own slot.
## If inventory fills mid-way, the items already added stay (no rollback),
## but returns false so callers know not all were placed.
func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		push_warning("GameState.add_item: Unknown item '%s'" % item_id)
		return false

	var added: int = 0
	for _i in range(quantity):
		if not has_inventory_space():
			break
		inventory.append({ "item_id": item_id, "quantity": 1 })
		added += 1

	if added > 0:
		EventBus.item_added.emit(item_id, added)

	if added < quantity:
		EventBus.inventory_full.emit()
		return false

	return true

## Remove item from inventory. Returns true if successful.
## Since items don't stack, removes individual slots.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	# Count available first
	if count_item(item_id) < quantity:
		return false

	var removed: int = 0
	# Remove from back to front so indices stay valid
	for i in range(inventory.size() - 1, -1, -1):
		if removed >= quantity:
			break
		if inventory[i]["item_id"] == item_id:
			inventory.remove_at(i)
			removed += 1

	EventBus.item_removed.emit(item_id, removed)
	return true

## Count how many of an item the player has (across all slots)
func count_item(item_id: String) -> int:
	var total: int = 0
	for entry in inventory:
		if entry["item_id"] == item_id:
			total += int(entry.get("quantity", 1))
	return total

## Convert full state to Dictionary for saving
func to_save_data() -> Dictionary:
	# Serialize player dict with Vector3 → array for JSON compatibility
	var player_copy: Dictionary = player.duplicate(true)
	if player_copy.has("position") and player_copy["position"] is Vector3:
		var pos: Vector3 = player_copy["position"]
		player_copy["position"] = [pos.x, pos.y, pos.z]
	return {
		"current_area": current_area,
		"player": player_copy,
		"skills": skills.duplicate(true),
		"equipment": equipment.duplicate(true),
		"inventory": inventory.duplicate(true),
		"bank": bank.duplicate(true),
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(true),
		"prestige_tier": prestige_tier,
		"prestige_points": prestige_points,
		"prestige_purchases": prestige_purchases.duplicate(true),
		"slayer_task": slayer_task.duplicate(true),
		"slayer_points": slayer_points,
		"slayer_streak": slayer_streak,
		"unlocked_achievements": unlocked_achievements.duplicate(true),
		"collection_log": collection_log.duplicate(true),
		"boss_kills": boss_kills.duplicate(true),
		"dungeon_max_floor": dungeon_max_floor,
		"active_pet": active_pet,
		"owned_pets": owned_pets.duplicate(true),
		"settings": settings.duplicate(true),
		"total_play_time": total_play_time,
		"panel_layout": panel_layout.duplicate(true),
		"tutorial": tutorial.duplicate(true),
	}

## Load state from a save Dictionary
func from_save_data(data: Dictionary) -> void:
	current_area = data.get("current_area", "station-hub")
	player = data.get("player", player)
	# Deserialize position from [x, y, z] array back to Vector3
	if player.has("position") and player["position"] is Array:
		var arr: Array = player["position"]
		if arr.size() >= 3:
			player["position"] = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		else:
			player["position"] = Vector3.ZERO
	elif not (player.get("position") is Vector3):
		player["position"] = Vector3.ZERO
	skills = data.get("skills", skills)
	# Ensure any new skills added since save was created exist with defaults
	var default_skills: Dictionary = {
		"nano": { "level": 1, "xp": 0 }, "tesla": { "level": 1, "xp": 0 },
		"void": { "level": 1, "xp": 0 }, "astromining": { "level": 1, "xp": 0 },
		"xenobotany": { "level": 1, "xp": 0 }, "bioforge": { "level": 1, "xp": 0 },
		"circuitry": { "level": 1, "xp": 0 }, "xenocook": { "level": 1, "xp": 0 },
	}
	for skill_id in default_skills:
		if not skills.has(skill_id):
			skills[skill_id] = default_skills[skill_id]
	equipment = data.get("equipment", equipment)
	inventory.assign(data.get("inventory", []))
	bank.assign(data.get("bank", []))
	active_quests = data.get("active_quests", {})
	completed_quests.assign(data.get("completed_quests", []))
	prestige_tier = data.get("prestige_tier", 0)
	prestige_points = data.get("prestige_points", 0)
	prestige_purchases.assign(data.get("prestige_purchases", []))
	slayer_task = data.get("slayer_task", {})
	slayer_points = data.get("slayer_points", 0)
	slayer_streak = data.get("slayer_streak", 0)
	unlocked_achievements.assign(data.get("unlocked_achievements", []))
	collection_log.assign(data.get("collection_log", []))
	boss_kills = data.get("boss_kills", {})
	dungeon_max_floor = data.get("dungeon_max_floor", 0)
	active_pet = data.get("active_pet", "")
	owned_pets = data.get("owned_pets", {})
	settings = data.get("settings", settings)
	total_play_time = data.get("total_play_time", 0.0)
	panel_layout = data.get("panel_layout", {})
	tutorial = data.get("tutorial", tutorial)
