## GatheringSpawner — Places gathering nodes (ore, spores) in the world
##
## Creates clusters of resource nodes in appropriate areas based on skill type.
## Asteroid Mines get ore nodes, Bio-Lab area gets spore nodes, etc.
extends Node3D

var gathering_script: GDScript = preload("res://scripts/world/gathering_node.gd")

# ── Spawn definitions ──
# Each entry: { area_center, skill, resource_tiers: [{ level, item_id, color }] }
var _spawn_defs: Array[Dictionary] = []

func _ready() -> void:
	_define_spawn_zones()
	_spawn_all_nodes()

func _define_spawn_zones() -> void:
	# Asteroid Mines — Ore nodes
	_spawn_defs.append({
		"area": "asteroid-mines",
		"cx": 300.0, "cz": 0.0, "radius": 70.0,
		"skill": "astromining",
		"nodes": [
			{"level": 1, "item": "stellarite_ore", "color": Color(0.6, 0.6, 0.55), "count": 12},
			{"level": 10, "item": "ferrite_ore", "color": Color(0.4, 0.65, 0.45), "count": 10},
			{"level": 20, "item": "cobaltium_ore", "color": Color(0.3, 0.45, 0.8), "count": 8},
			{"level": 30, "item": "duranite_ore", "color": Color(0.35, 0.6, 0.7), "count": 6},
			{"level": 40, "item": "titanex_ore", "color": Color(0.5, 0.7, 0.3), "count": 5},
			{"level": 50, "item": "plasmite_ore", "color": Color(0.6, 0.3, 0.8), "count": 4},
			{"level": 60, "item": "quantite_ore", "color": Color(0.8, 0.5, 0.2), "count": 3},
			{"level": 70, "item": "neutronium_ore", "color": Color(0.8, 0.25, 0.45), "count": 3},
		]
	})

	# Gathering Grounds — Bio resources (spores, lichen, etc.)
	_spawn_defs.append({
		"area": "gathering-grounds",
		"cx": 0.0, "cz": -100.0, "radius": 50.0,
		"skill": "xenobotany",
		"nodes": [
			{"level": 1, "item": "space_lichen", "color": Color(0.3, 0.5, 0.25), "count": 10},
			{"level": 5, "item": "cryo_kelp", "color": Color(0.2, 0.5, 0.6), "count": 8},
			{"level": 10, "item": "nebula_fruit", "color": Color(0.6, 0.3, 0.7), "count": 6},
			{"level": 20, "item": "chitin_shard", "color": Color(0.5, 0.4, 0.2), "count": 5},
		]
	})

func _spawn_all_nodes() -> void:
	var total: int = 0
	for zone in _spawn_defs:
		var cx: float = float(zone["cx"])
		var cz: float = float(zone["cz"])
		var radius: float = float(zone["radius"])
		var skill: String = str(zone["skill"])
		var nodes: Array = zone["nodes"]

		for node_def in nodes:
			var level: int = int(node_def["level"])
			var item_id: String = str(node_def["item"])
			var color: Color = node_def["color"]
			var count: int = int(node_def["count"])

			for i in range(count):
				var angle: float = randf() * TAU
				var dist: float = randf_range(5.0, radius * 0.85)
				var pos: Vector3 = Vector3(
					cx + cos(angle) * dist,
					0.1,
					cz + sin(angle) * dist
				)

				var node_id: String = "%s_%s_%d" % [skill, item_id, i]
				var gnode: StaticBody3D = StaticBody3D.new()
				gnode.name = "GatherNode_%s" % node_id
				gnode.set_script(gathering_script)
				add_child(gnode)
				gnode.setup(node_id, item_id, skill, level, pos, color)
				total += 1

	print("GatheringSpawner: %d gathering nodes spawned" % total)
