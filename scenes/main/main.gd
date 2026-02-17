## Main scene script — Entry point for Asterian
##
## Loads the game world, spawns the player, sets up HUD and systems.
## This is the root node that orchestrates all top-level scenes.
extends Node3D

# Scene references (loaded at runtime)
var world_scene: PackedScene = preload("res://scenes/world/game_world.tscn")
var player_scene: PackedScene = preload("res://scenes/entities/player.tscn")
var hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")

# System scripts
var float_text_script: GDScript = preload("res://scripts/systems/float_text.gd")
var loot_system_script: GDScript = preload("res://scripts/systems/loot_system.gd")
var equipment_system_script: GDScript = preload("res://scripts/systems/equipment_system.gd")
var crafting_system_script: GDScript = preload("res://scripts/systems/crafting_system.gd")
var interaction_script: GDScript = preload("res://scripts/player/interaction_controller.gd")
var npc_spawner_script: GDScript = preload("res://scripts/world/npc_spawner.gd")
var gathering_spawner_script: GDScript = preload("res://scripts/world/gathering_spawner.gd")
var station_spawner_script: GDScript = preload("res://scripts/world/station_spawner.gd")
var quest_system_script: GDScript = preload("res://scripts/systems/quest_system.gd")
var slayer_system_script: GDScript = preload("res://scripts/systems/slayer_system.gd")
var achievement_system_script: GDScript = preload("res://scripts/systems/achievement_system.gd")
var prestige_system_script: GDScript = preload("res://scripts/systems/prestige_system.gd")
var dungeon_system_script: GDScript = preload("res://scripts/systems/dungeon_system.gd")
var pet_system_script: GDScript = preload("res://scripts/systems/pet_system.gd")
var dungeon_renderer_script: GDScript = preload("res://scripts/world/dungeon_renderer.gd")
var weather_system_script: GDScript = preload("res://scripts/world/weather_system.gd")
var multiplayer_client_script: GDScript = preload("res://scripts/systems/multiplayer_client.gd")

# Runtime references
var game_world: Node3D = null
var player: CharacterBody3D = null
var hud: CanvasLayer = null
var float_text: Node3D = null
var loot_system: Node3D = null

# ── Auto-save ──
const AUTO_SAVE_INTERVAL: float = 30.0  # Save every 30 seconds
var _auto_save_timer: float = 0.0
var _loaded_from_save: bool = false

func _ready() -> void:
	print("=== Asterian ===")
	print("Godot %s" % Engine.get_version_info()["string"])

	# Verify DataManager loaded
	print("DataManager: %d items, %d enemies, %d recipes" % [
		DataManager.items.size(),
		DataManager.enemies.size(),
		DataManager.recipes.size()
	])

	# ── Load existing save BEFORE spawning anything ──
	_loaded_from_save = SaveManager.load_game()

	# Spawn game world
	game_world = world_scene.instantiate()
	add_child(game_world)
	print("World loaded.")

	# Spawn player
	player = player_scene.instantiate()
	player.add_to_group("player")
	add_child(player)

	# Apply saved position, or default to Station Hub
	var spawn_pos: Vector3 = Vector3(0, 1, 0)
	if _loaded_from_save and GameState.player.has("position") and GameState.player["position"] is Vector3:
		var saved_pos: Vector3 = GameState.player["position"]
		# Sanity check — if position is (0,0,0) default to hub spawn
		if saved_pos.length() > 0.1:
			spawn_pos = saved_pos
			print("Player restored to saved position: %s" % str(saved_pos))
		else:
			print("Player spawned at Station Hub (default).")
	else:
		print("Player spawned at Station Hub.")

	# Snap spawn position to terrain surface so player doesn't clip through
	var area_mgr: Node3D = get_tree().get_first_node_in_group("area_manager")
	if area_mgr and area_mgr.has_method("get_terrain_height"):
		var terrain_y: float = area_mgr.get_terrain_height(spawn_pos.x, spawn_pos.z)
		spawn_pos.y = terrain_y + 1.0

	player.global_position = spawn_pos
	player.move_target = spawn_pos

	# Add equipment system to player
	var equip_sys: Node = Node.new()
	equip_sys.name = "EquipmentSystem"
	equip_sys.set_script(equipment_system_script)
	player.add_child(equip_sys)
	print("Equipment system ready.")

	# Add interaction controller to player
	var interact: Node = Node.new()
	interact.name = "InteractionController"
	interact.set_script(interaction_script)
	player.add_child(interact)
	print("Interaction controller ready.")

	# Spawn float text system
	float_text = Node3D.new()
	float_text.name = "FloatTextSystem"
	float_text.set_script(float_text_script)
	add_child(float_text)

	# Spawn loot system
	loot_system = Node3D.new()
	loot_system.name = "LootSystem"
	loot_system.set_script(loot_system_script)
	add_child(loot_system)
	print("Loot system ready.")

	# Spawn crafting system
	var crafting: Node = Node.new()
	crafting.name = "CraftingSystem"
	crafting.set_script(crafting_system_script)
	crafting.add_to_group("crafting_system")
	add_child(crafting)
	print("Crafting system ready.")

	# Spawn quest system
	var quest_sys: Node = Node.new()
	quest_sys.name = "QuestSystem"
	quest_sys.set_script(quest_system_script)
	add_child(quest_sys)
	print("Quest system ready.")

	# Spawn slayer system
	var slayer_sys: Node = Node.new()
	slayer_sys.name = "SlayerSystem"
	slayer_sys.set_script(slayer_system_script)
	add_child(slayer_sys)
	print("Slayer system ready.")

	# Spawn achievement system
	var achieve_sys: Node = Node.new()
	achieve_sys.name = "AchievementSystem"
	achieve_sys.set_script(achievement_system_script)
	add_child(achieve_sys)
	print("Achievement system ready.")

	# Spawn prestige system
	var prestige_sys: Node = Node.new()
	prestige_sys.name = "PrestigeSystem"
	prestige_sys.set_script(prestige_system_script)
	add_child(prestige_sys)
	print("Prestige system ready.")

	# Spawn dungeon system
	var dungeon_sys: Node = Node.new()
	dungeon_sys.name = "DungeonSystem"
	dungeon_sys.set_script(dungeon_system_script)
	add_child(dungeon_sys)
	print("Dungeon system ready.")

	# Spawn pet system
	var pet_sys: Node = Node.new()
	pet_sys.name = "PetSystem"
	pet_sys.set_script(pet_system_script)
	add_child(pet_sys)
	print("Pet system ready.")

	# Spawn dungeon renderer (3D geometry builder for dungeon floors)
	var dungeon_renderer: Node3D = Node3D.new()
	dungeon_renderer.name = "DungeonRenderer"
	dungeon_renderer.set_script(dungeon_renderer_script)
	add_child(dungeon_renderer)
	print("Dungeon renderer ready.")

	# Weather system disabled — square particles were visually distracting
	# var weather: Node3D = Node3D.new()
	# weather.name = "WeatherSystem"
	# weather.set_script(weather_system_script)
	# add_child(weather)
	# print("Weather system ready.")

	# Spawn NPC spawner
	var npc_spawner: Node3D = Node3D.new()
	npc_spawner.name = "NPCSpawner"
	npc_spawner.set_script(npc_spawner_script)
	add_child(npc_spawner)

	# Spawn gathering nodes
	var gather_spawner: Node3D = Node3D.new()
	gather_spawner.name = "GatheringSpawner"
	gather_spawner.set_script(gathering_spawner_script)
	add_child(gather_spawner)

	# Spawn processing stations
	var station_spawner: Node3D = Node3D.new()
	station_spawner.name = "StationSpawner"
	station_spawner.set_script(station_spawner_script)
	add_child(station_spawner)

	# Spawn multiplayer client (WebSocket connection to game server)
	var mp_client: Node = Node.new()
	mp_client.name = "MultiplayerClient"
	mp_client.set_script(multiplayer_client_script)
	add_child(mp_client)
	print("Multiplayer client ready.")

	# Spawn HUD
	hud = hud_scene.instantiate()
	hud.add_to_group("hud")
	add_child(hud)
	print("HUD loaded.")

	# Only give starter gear on a brand new game (no save loaded)
	if not _loaded_from_save:
		_give_starter_gear()
	else:
		print("Save loaded — skipping starter gear.")

	# Connect save-worthy events for auto-saving on important moments
	EventBus.player_level_up.connect(_on_save_event)
	EventBus.quest_completed.connect(_on_save_event_str)
	EventBus.achievement_unlocked.connect(_on_save_event_str)
	EventBus.prestige_triggered.connect(_on_save_event_int)

	# ── Web: register beforeunload + visibilitychange to save on tab close/refresh ──
	if OS.has_feature("web"):
		_register_web_save_hooks()

	print("=== Ready! ===")

func _process(delta: float) -> void:
	# ── Auto-save timer ──
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		_sync_player_state()
		SaveManager.save_game()

func _notification(what: int) -> void:
	# Save when the game is about to close (Alt+F4, browser tab close, etc.)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_sync_player_state()
		SaveManager.save_game()

## Sync the live player node state back into GameState before saving
func _sync_player_state() -> void:
	if player:
		GameState.player["position"] = player.global_position
	# Sync panel layout from HUD
	if hud and hud.has_method("_save_all_panel_states"):
		hud._save_all_panel_states()

## Event-based save triggers (fire-and-forget, various signatures)
func _on_save_event(_a: Variant = null, _b: Variant = null) -> void:
	_sync_player_state()
	SaveManager.save_game()

func _on_save_event_str(_s: String) -> void:
	_sync_player_state()
	SaveManager.save_game()

func _on_save_event_int(_i: int) -> void:
	_sync_player_state()
	SaveManager.save_game()

## Register JavaScript hooks for web export to save on tab close/refresh/hide
func _register_web_save_hooks() -> void:
	# Use a Callable that Godot can expose to JS via JavaScriptBridge
	var save_callback: Callable = _web_save_callback
	var js_cb: JavaScriptObject = JavaScriptBridge.create_callback(save_callback)

	# beforeunload — fires on tab close, refresh, navigate away
	JavaScriptBridge.get_interface("window").addEventListener("beforeunload", js_cb)

	# visibilitychange — fires when user switches tabs or minimizes
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", js_cb)

	print("Web save hooks registered (beforeunload + visibilitychange).")

## Called from JavaScript when the page is about to close or become hidden
func _web_save_callback(_args: Variant) -> void:
	_sync_player_state()
	SaveManager.save_game()

## Give player some starter gear on a new game
func _give_starter_gear() -> void:
	# Add a Scrap Nanoblade if they have nothing
	if GameState.equipment["weapon"] == "":
		var item: Dictionary = DataManager.get_item("scrap_nanoblade")
		if not item.is_empty():
			GameState.equipment["weapon"] = "scrap_nanoblade"
			print("Starter weapon equipped: Scrap Nanoblade")
		else:
			print("Note: No starter weapon found in items data.")

	# Add some food and resources for testing
	GameState.add_item("lichen_wrap", 3)
	GameState.add_item("chitin_shard", 5)
	GameState.add_item("stellarite_ore", 3)

	# Starting credits
	GameState.add_credits(100)

	# Save the new game immediately so it persists
	_sync_player_state()
	SaveManager.save_game()
