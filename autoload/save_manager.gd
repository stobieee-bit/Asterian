## SaveManager — Handles save/load to user:// directory (autoloaded singleton)
##
## On HTML5 export, user:// maps to IndexedDB via Godot's VFS layer.
## Saves are stored as JSON files for easy debugging.
extends Node

const SAVE_PATH := "user://save_data.json"
const BACKUP_PATH := "user://save_data_backup.json"

## Save current game state to disk
func save_game() -> bool:
	var data := GameState.to_save_data()
	data["save_version"] = 1
	data["save_timestamp"] = Time.get_unix_time_from_system()

	# Create backup of existing save first
	if FileAccess.file_exists(SAVE_PATH):
		var old := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var old_text := old.get_as_text()
			old.close()
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup:
				backup.store_string(old_text)
				backup.close()

	# Write new save
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open save file for writing.")
		return false
	file.store_string(json_text)
	file.close()

	print("SaveManager: Game saved successfully.")
	EventBus.game_saved.emit()
	return true

## Load game state from disk. Returns true if successful.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: No save file found.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open save file for reading.")
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("SaveManager: JSON parse error: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data
	if not data is Dictionary:
		push_error("SaveManager: Save data is not a Dictionary.")
		return false

	GameState.from_save_data(data)
	print("SaveManager: Game loaded successfully (save version %d)." % data.get("save_version", 0))
	EventBus.game_loaded.emit()
	return true

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
