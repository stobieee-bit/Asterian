## PetSystem -- Manages pets that follow the player and provide passive buffs
##
## Handles summoning/dismissing pets, awarding pet XP from enemy kills,
## levelling and evolution, and maintaining a 3D follower node that orbits
## the player.
##
## Architecture:
##   - Reads pet definitions from DataManager.pets (Array of dicts)
##   - Mutates GameState.active_pet, GameState.owned_pets
##   - Emits EventBus.chat_message for all player-facing messages
##   - Emits custom pet signals via EventBus (pet_summoned, pet_dismissed, pet_level_up)
extends Node


# ──────────────────────────────────────────────
#  Constants
# ──────────────────────────────────────────────

## Rarity → sphere colour mapping for the 3D pet visual
const RARITY_COLORS: Dictionary = {
	"common":   Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.9, 0.3),
	"rare":     Color(0.3, 0.6, 1.0),
	"epic":     Color(0.8, 0.3, 1.0),
}

## Orbit and bobbing parameters
const ORBIT_DISTANCE: float = 2.0
const ORBIT_HEIGHT: float   = 1.5
const ORBIT_SPEED: float    = 1.0
const BOB_SPEED: float      = 2.0
const BOB_AMPLITUDE: float  = 0.3
const SPHERE_RADIUS: float  = 0.4

## XP awarded per enemy kill
const XP_PER_KILL: int = 10


# ──────────────────────────────────────────────
#  Internal state
# ──────────────────────────────────────────────

## The 3D node that orbits the player
var _pet_visual: Node3D = null

## Elapsed time for orbit and bob calculations
var _orbit_time: float = 0.0

## Cached player reference (resolved lazily)
var _player: Node3D = null


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("pet_system")

	# Connect to enemy kills so we can award pet XP
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# If a pet was already active (e.g. loaded save), spawn its visual
	if GameState.active_pet != "":
		_spawn_visual(GameState.active_pet)


func _process(delta: float) -> void:
	if _pet_visual == null:
		return

	# Resolve player reference lazily
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	_orbit_time += delta

	# Orbit around the player's position
	var angle: float = _orbit_time * ORBIT_SPEED
	var offset_x: float = cos(angle) * ORBIT_DISTANCE
	var offset_z: float = sin(angle) * ORBIT_DISTANCE
	var bob_y: float = sin(_orbit_time * BOB_SPEED) * BOB_AMPLITUDE

	var target_pos: Vector3 = _player.global_position + Vector3(
		offset_x,
		ORBIT_HEIGHT + bob_y,
		offset_z
	)

	# Smooth follow so it doesn't teleport on sudden player movement
	_pet_visual.global_position = _pet_visual.global_position.lerp(target_pos, clampf(delta * 5.0, 0.0, 1.0))


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Activate a pet the player owns.
## Returns true if successfully summoned, false otherwise.
func summon_pet(pet_id: String) -> bool:
	if not GameState.owned_pets.has(pet_id):
		EventBus.chat_message.emit("You don't own that pet.", "system")
		return false

	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		push_warning("PetSystem: Unknown pet definition '%s'" % pet_id)
		return false

	# Dismiss current pet first (if any)
	if GameState.active_pet != "":
		dismiss_pet()

	GameState.active_pet = pet_id

	# Spawn 3D visual
	_spawn_visual(pet_id)

	var pet_name: String = str(pet_def.get("name", pet_id))
	EventBus.chat_message.emit("Summoned %s!" % pet_name, "pet")

	# Emit pet_summoned if the signal exists, otherwise silently skip
	if EventBus.has_signal("pet_summoned"):
		EventBus.emit_signal("pet_summoned", pet_id)

	return true


## Deactivate the current pet and remove its 3D visual.
func dismiss_pet() -> void:
	if GameState.active_pet == "":
		return

	var pet_def: Dictionary = get_pet_data(GameState.active_pet)
	var pet_name: String = str(pet_def.get("name", GameState.active_pet))

	GameState.active_pet = ""
	_remove_visual()

	EventBus.chat_message.emit("Dismissed %s." % pet_name, "pet")

	if EventBus.has_signal("pet_dismissed"):
		EventBus.emit_signal("pet_dismissed")


## Grant the player a new pet.
## Returns true if the pet was new, false if already owned.
func add_pet(pet_id: String) -> bool:
	if GameState.owned_pets.has(pet_id):
		return false

	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		push_warning("PetSystem: Cannot add unknown pet '%s'" % pet_id)
		return false

	GameState.owned_pets[pet_id] = { "level": 1, "xp": 0 }

	var pet_name: String = str(pet_def.get("name", pet_id))
	EventBus.chat_message.emit("New pet obtained: %s!" % pet_name, "pet")

	# Float text above the player
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		var rarity: String = str(pet_def.get("rarity", "common"))
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		EventBus.float_text_requested.emit(
			"NEW PET: %s" % pet_name,
			player_node.global_position + Vector3(0, 3.5, 0),
			color
		)

	return true


## Award XP to the currently active pet.
## Handles level-ups and evolution stage transitions.
func feed_pet_xp(amount: int) -> void:
	if GameState.active_pet == "":
		return

	var pet_id: String = GameState.active_pet
	if not GameState.owned_pets.has(pet_id):
		return

	var pet_state: Dictionary = GameState.owned_pets[pet_id]
	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		return

	var max_level: int = int(pet_def.get("maxLevel", 20))
	var current_level: int = int(pet_state.get("level", 1))

	# Already at max level — no XP to give
	if current_level >= max_level:
		return

	var current_xp: int = int(pet_state.get("xp", 0))
	current_xp += amount
	pet_state["xp"] = current_xp

	# Check for level ups (pet XP curve: level * 100 per level)
	var xp_needed: int = current_level * 100
	while current_xp >= xp_needed and current_level < max_level:
		current_xp -= xp_needed
		current_level += 1

		pet_state["level"] = current_level
		pet_state["xp"] = current_xp

		var pet_name: String = str(pet_def.get("name", pet_id))
		EventBus.chat_message.emit(
			"%s levelled up to %d!" % [pet_name, current_level],
			"pet"
		)

		if EventBus.has_signal("pet_level_up"):
			EventBus.emit_signal("pet_level_up", pet_id, current_level)

		# Check for evolution at this new level
		_check_evolution(pet_id, pet_def, current_level)

		# Recalculate XP needed for the next level
		xp_needed = current_level * 100


## Return the active pet's calculated buff.
## Returns { "type": String, "value": float } or an empty Dictionary if no pet is active.
func get_pet_buff() -> Dictionary:
	if GameState.active_pet == "":
		return {}

	var pet_id: String = GameState.active_pet
	if not GameState.owned_pets.has(pet_id):
		return {}

	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		return {}

	var buff_def: Dictionary = pet_def.get("buff", {})
	if buff_def.is_empty():
		return {}

	var pet_level: int = int(GameState.owned_pets[pet_id].get("level", 1))
	var buff_type: String = str(buff_def.get("type", ""))
	var base_value: float = float(buff_def.get("baseValue", 0.0))
	var per_level: float = float(buff_def.get("perLevel", 0.0))

	var value: float = base_value + float(pet_level - 1) * per_level

	return { "type": buff_type, "value": value }


## Look up a pet definition from DataManager.pets by its id.
## Returns empty Dictionary if not found.
func get_pet_data(pet_id: String) -> Dictionary:
	for entry: Dictionary in DataManager.pets:
		if str(entry.get("id", "")) == pet_id:
			return entry
	return {}


## Return an enriched Array of all owned pets with level, xp, buff, and
## evolution info appended to each pet definition dict.
func get_owned_pets_enriched() -> Array:
	var result: Array = []

	for pid: String in GameState.owned_pets:
		var pet_def: Dictionary = get_pet_data(pid)
		if pet_def.is_empty():
			continue

		var pet_state: Dictionary = GameState.owned_pets[pid]
		var enriched: Dictionary = pet_def.duplicate(true)
		enriched["level"] = int(pet_state.get("level", 1))
		enriched["xp"] = int(pet_state.get("xp", 0))
		enriched["xp_to_next"] = int(pet_state.get("level", 1)) * 100
		enriched["evolution_stage"] = get_evolution_stage(pid)

		# Calculate current buff at this level
		var buff_def: Dictionary = pet_def.get("buff", {})
		if not buff_def.is_empty():
			var pet_level: int = int(pet_state.get("level", 1))
			var base_value: float = float(buff_def.get("baseValue", 0.0))
			var per_level: float = float(buff_def.get("perLevel", 0.0))
			var value: float = base_value + float(pet_level - 1) * per_level
			enriched["buff_value"] = value

		enriched["is_active"] = (pid == GameState.active_pet)
		result.append(enriched)

	return result


## Return the evolution stage for a pet (0, 1, or 2).
## Stage advances at each threshold in the pet's evolutionLevels array.
func get_evolution_stage(pet_id: String) -> int:
	if not GameState.owned_pets.has(pet_id):
		return 0

	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		return 0

	var pet_level: int = int(GameState.owned_pets[pet_id].get("level", 1))
	var evo_levels: Array = pet_def.get("evolutionLevels", [10, 20])

	var stage: int = 0
	for threshold in evo_levels:
		if pet_level >= int(threshold):
			stage += 1
	return stage


# ──────────────────────────────────────────────
#  Save / Load
# ──────────────────────────────────────────────

## Serialize system-local state for the save system.
## Note: active_pet and owned_pets live on GameState, so this only captures
## any transient system-local state (currently none).
func to_save_data() -> Dictionary:
	return {}


## Restore system-local state from save data.
func from_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	# No system-local state to restore currently.
	# On load, _ready() will re-spawn the visual if active_pet is set.


# ──────────────────────────────────────────────
#  Signal Callbacks
# ──────────────────────────────────────────────

## Award pet XP whenever an enemy is killed.
func _on_enemy_killed(_enemy_id: String, _enemy_type: String) -> void:
	feed_pet_xp(XP_PER_KILL)


# ──────────────────────────────────────────────
#  Internal Helpers
# ──────────────────────────────────────────────

## Spawn the 3D pet visual (a coloured sphere that orbits the player).
func _spawn_visual(pet_id: String) -> void:
	_remove_visual()

	var pet_def: Dictionary = get_pet_data(pet_id)
	if pet_def.is_empty():
		return

	var rarity: String = str(pet_def.get("rarity", "common"))
	var color: Color = RARITY_COLORS.get(rarity, Color(0.6, 0.6, 0.6))

	# Build a simple Node3D → CSGSphere3D hierarchy
	var root: Node3D = Node3D.new()
	root.name = "PetFollower"

	var sphere: CSGSphere3D = CSGSphere3D.new()
	sphere.name = "PetSphere"
	sphere.radius = SPHERE_RADIUS
	sphere.radial_segments = 16
	sphere.rings = 8

	# Apply a coloured material
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = 0.8
	sphere.material = mat

	root.add_child(sphere)
	add_child(root)
	_pet_visual = root

	# Position near the player immediately (avoid spawning at origin)
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		_pet_visual.global_position = player_node.global_position + Vector3(
			ORBIT_DISTANCE, ORBIT_HEIGHT, 0.0
		)


## Remove the 3D pet visual from the scene tree.
func _remove_visual() -> void:
	if _pet_visual != null and is_instance_valid(_pet_visual):
		_pet_visual.queue_free()
	_pet_visual = null
	_player = null
	_orbit_time = 0.0


## Check if the pet just reached an evolution threshold and announce it.
func _check_evolution(pet_id: String, pet_def: Dictionary, new_level: int) -> void:
	var evo_levels: Array = pet_def.get("evolutionLevels", [10, 20])

	for i in range(evo_levels.size()):
		if int(evo_levels[i]) == new_level:
			var pet_name: String = str(pet_def.get("name", pet_id))
			var stage: int = i + 1
			EventBus.chat_message.emit(
				"%s evolved to stage %d!" % [pet_name, stage],
				"pet"
			)

			# Visual feedback — float text above player
			var player_node: Node3D = get_tree().get_first_node_in_group("player")
			if player_node:
				EventBus.float_text_requested.emit(
					"EVOLUTION STAGE %d" % stage,
					player_node.global_position + Vector3(0, 4.0, 0),
					Color(1.0, 0.84, 0.0)  # Gold
				)

			# Update the sphere colour to reflect evolution (brighter tint)
			_update_visual_for_evolution(pet_def, stage)
			break


## Brighten the pet sphere material to reflect a higher evolution stage.
func _update_visual_for_evolution(pet_def: Dictionary, stage: int) -> void:
	if _pet_visual == null or not is_instance_valid(_pet_visual):
		return

	var sphere: CSGSphere3D = _pet_visual.get_node_or_null("PetSphere")
	if sphere == null:
		return

	var rarity: String = str(pet_def.get("rarity", "common"))
	var base_color: Color = RARITY_COLORS.get(rarity, Color(0.6, 0.6, 0.6))

	# Each evolution stage brightens the emission and scales the sphere slightly
	var brightness_boost: float = float(stage) * 0.4
	var scale_boost: float = 1.0 + float(stage) * 0.15

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = base_color.lightened(brightness_boost * 0.3)
	mat.emission_enabled = true
	mat.emission = base_color * (0.5 + brightness_boost)
	mat.emission_energy_multiplier = 0.8 + brightness_boost
	sphere.material = mat

	sphere.radius = SPHERE_RADIUS * scale_boost
