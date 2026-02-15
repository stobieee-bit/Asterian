## NPCSpawner — Spawns all NPCs from DataManager at their positions
##
## Iterates over DataManager.npcs and creates NPC instances for each.
extends Node3D

var npc_script: GDScript = preload("res://scripts/world/npc_controller.gd")

func _ready() -> void:
	_spawn_all_npcs()

func _spawn_all_npcs() -> void:
	var count: int = 0
	for npc_id in DataManager.npcs:
		var npc_data: Dictionary = DataManager.npcs[npc_id]

		# Create NPC node
		var npc: StaticBody3D = StaticBody3D.new()
		npc.name = "NPC_%s" % npc_id
		npc.set_script(npc_script)
		add_child(npc)
		npc.setup(npc_id)
		count += 1

	print("NPCSpawner: %d NPCs spawned" % count)
