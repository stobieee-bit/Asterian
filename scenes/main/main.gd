## Main scene script — Entry point for Asterian
##
## Sets up the initial 3D world with a ground plane, sky, lighting,
## and a simple camera. This is the "Hello Asterian" verification scene.
## Phase 1 will add the real world, player, and camera rig.
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var label: Label = $CanvasLayer/CenterLabel

func _ready() -> void:
	print("=== Asterian ===")
	print("Godot %s" % Engine.get_version_info()["string"])
	print("Current area: %s" % GameState.current_area)

	# Verify DataManager loaded
	var item_count := DataManager.items.size()
	var enemy_count := DataManager.enemies.size()
	print("DataManager: %d items, %d enemies loaded" % [item_count, enemy_count])

	# Update label with data summary
	if label:
		label.text = "Asterian\n%d items | %d enemies | %d recipes" % [
			item_count, enemy_count, DataManager.recipes.size()
		]

func _process(_delta: float) -> void:
	# Slowly rotate camera around origin for visual interest
	if camera:
		camera.position.x = sin(Time.get_ticks_msec() * 0.0003) * 12.0
		camera.position.z = cos(Time.get_ticks_msec() * 0.0003) * 12.0
		camera.look_at(Vector3.ZERO, Vector3.UP)
