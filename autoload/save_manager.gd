## SaveManager — Handles save/load to user:// directory (autoloaded singleton)
##
## On HTML5 export, user:// maps to IndexedDB via Godot's VFS layer.
## Saves are stored as JSON files for easy debugging.
extends Node

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data_backup.json"

## Save current game state to disk
func save_game() -> bool:
	var data: Dictionary = GameState.to_save_data()
	data["save_version"] = 2
	data["save_timestamp"] = Time.get_unix_time_from_system()

	# Save achievement system internal counters
	var achieve_sys: Node = get_tree().get_first_node_in_group("achievement_system")
	if achieve_sys and achieve_sys.has_method("to_save_data"):
		data["achievement_data"] = achieve_sys.to_save_data()

	# Create backup of existing save first
	if FileAccess.file_exists(SAVE_PATH):
		var old: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var old_text: String = old.get_as_text()
			old.close()
			var backup: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup:
				backup.store_string(old_text)
				backup.close()

	# Write new save
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open save file for writing.")
		return false
	file.store_string(json_text)
	file.close()

	print("SaveManager: Game saved successfully.")
	EventBus.game_saved.emit()
	return true

## Load game state from disk. Returns true if successful.
## If the primary save is corrupt, automatically tries the backup.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: No save file found.")
		return false

	var data: Dictionary = _try_load_file(SAVE_PATH)
	if data.is_empty():
		push_warning("SaveManager: Primary save corrupt — trying backup...")
		data = _try_load_file(BACKUP_PATH)
		if data.is_empty():
			push_error("SaveManager: Backup also corrupt or missing. Cannot load.")
			return false
		print("SaveManager: Restored from backup successfully.")

	# ── Save migration ──
	var version: int = int(data.get("save_version", 0))
	if version < 2:
		data = _migrate_v1_to_v2(data)

	GameState.from_save_data(data)

	# Restore achievement system internal counters
	var achieve_sys: Node = get_tree().get_first_node_in_group("achievement_system")
	if achieve_sys and achieve_sys.has_method("from_save_data"):
		achieve_sys.from_save_data(data.get("achievement_data", {}))

	print("SaveManager: Game loaded successfully (save version %d)." % data.get("save_version", 0))
	EventBus.game_loaded.emit()
	return true

## Attempt to parse a save file. Returns empty Dictionary on failure.
func _try_load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("SaveManager: Data in %s is not a Dictionary." % path)
		return {}
	return json.data

## Check if a save file exists
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("SaveManager: Save file deleted.")
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)

# ── Save migration helpers ──

## Migrate v1 (alien-wastes single area) to v2 (4 separate areas)
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	print("SaveManager: Migrating save v1 -> v2 (alien-wastes split)")

	# If player was in the removed alien-wastes, relocate to spore-marshes
	var area: String = data.get("current_area", "station-hub")
	if area == "alien-wastes":
		data["current_area"] = "spore-marshes"
		# Reset position to station hub for safety
		data["position"] = { "x": 0, "y": 0, "z": 0 }
		print("  Relocated player from alien-wastes -> spore-marshes (Station Hub)")

	# Migrate visited_areas — replace alien-wastes with all 4 replacement areas
	var visited: Array = data.get("visited_areas", [])
	if "alien-wastes" in visited:
		visited.erase("alien-wastes")
		for new_area in ["spore-marshes", "hive-tunnels", "fungal-wastes", "stalker-reaches"]:
			if new_area not in visited:
				visited.append(new_area)
		data["visited_areas"] = visited
		print("  Migrated visited_areas: alien-wastes -> 4 new areas")

	data["save_version"] = 2
	return data
