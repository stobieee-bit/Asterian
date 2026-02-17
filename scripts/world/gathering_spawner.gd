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

## Helper: read area center from DataManager, fallback to provided defaults
func _area_center(area_id: String) -> Dictionary:
	var area_data: Dictionary = DataManager.areas.get(area_id, {})
	var center: Dictionary = area_data.get("center", {})
	return {
		"cx": float(center.get("x", 0)),
		"cz": float(center.get("z", 0)),
		"radius": float(area_data.get("radius", 60))
	}

func _define_spawn_zones() -> void:
	var c: Dictionary

	# ── Asteroid Mines — Ore nodes ──
	c = _area_center("asteroid-mines")
	_spawn_defs.append({
		"area": "asteroid-mines",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "astromining",
		"nodes": [
			{"level": 1, "item": "stellarite_ore", "color": Color(0.85, 0.75, 0.5), "count": 12},
			{"level": 10, "item": "ferrite_ore", "color": Color(0.2, 0.9, 0.3), "count": 10},
			{"level": 20, "item": "cobaltium_ore", "color": Color(0.2, 0.4, 1.0), "count": 8},
			{"level": 30, "item": "duranite_ore", "color": Color(0.1, 0.9, 0.9), "count": 6},
			{"level": 40, "item": "titanex_ore", "color": Color(0.9, 0.95, 0.1), "count": 5},
			{"level": 50, "item": "plasmite_ore", "color": Color(0.8, 0.15, 1.0), "count": 4},
			{"level": 60, "item": "quantite_ore", "color": Color(1.0, 0.5, 0.0), "count": 3},
			{"level": 70, "item": "neutronium_ore", "color": Color(1.0, 0.1, 0.3), "count": 3},
			{"level": 80, "item": "darkmatter_shard", "color": Color(0.15, 0.0, 0.35), "count": 2},
			{"level": 90, "item": "voidsteel_ore", "color": Color(0.1, 0.0, 0.2), "count": 2},
		]
	})

	# ── Gathering Grounds — Bio resources ──
	c = _area_center("gathering-grounds")
	_spawn_defs.append({
		"area": "gathering-grounds",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.9,
		"skill": "xenobotany",
		"nodes": [
			{"level": 1, "item": "space_lichen", "color": Color(0.3, 0.5, 0.25), "count": 10},
			{"level": 5, "item": "cryo_kelp", "color": Color(0.2, 0.5, 0.6), "count": 8},
			{"level": 10, "item": "nebula_fruit", "color": Color(0.6, 0.3, 0.7), "count": 6},
			{"level": 15, "item": "solar_grain", "color": Color(0.8, 0.7, 0.2), "count": 6},
			{"level": 20, "item": "chitin_shard", "color": Color(0.5, 0.4, 0.2), "count": 5},
			{"level": 25, "item": "alien_steak", "color": Color(0.7, 0.3, 0.3), "count": 5},
			{"level": 30, "item": "spore_cap", "color": Color(0.5, 0.6, 0.3), "count": 5},
			{"level": 35, "item": "plasma_pepper", "color": Color(1.0, 0.3, 0.1), "count": 4},
			{"level": 40, "item": "void_moss", "color": Color(0.25, 0.5, 0.3), "count": 3},
		]
	})

	# ── Mycelium Hollows — Fungal gathering (xenobotany) ──
	c = _area_center("mycelium-hollows")
	_spawn_defs.append({
		"area": "mycelium-hollows",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "xenobotany",
		"nodes": [
			{"level": 5, "item": "glowcap_fungus", "color": Color(0.2, 0.9, 0.4), "count": 10},
			{"level": 10, "item": "mycelium_strand", "color": Color(0.8, 0.8, 0.9), "count": 8},
			{"level": 15, "item": "deeproot_bulb", "color": Color(0.6, 0.4, 0.2), "count": 6},
		]
	})

	# ── Mycelium Hollows — Mineral deposits (astromining) ──
	_spawn_defs.append({
		"area": "mycelium-hollows",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "astromining",
		"nodes": [
			{"level": 5, "item": "fungite_ore", "color": Color(0.5, 0.6, 0.3), "count": 10},
			{"level": 10, "item": "sporite_crystal", "color": Color(0.6, 0.9, 0.5), "count": 8},
			{"level": 15, "item": "hollow_geode", "color": Color(0.4, 0.3, 0.5), "count": 6},
		]
	})

	# ── Spore Marshes — Marsh flora (xenobotany) ──
	c = _area_center("spore-marshes")
	_spawn_defs.append({
		"area": "spore-marshes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "xenobotany",
		"nodes": [
			{"level": 1, "item": "space_lichen", "color": Color(0.3, 0.5, 0.25), "count": 4},
			{"level": 5, "item": "cryo_kelp", "color": Color(0.2, 0.5, 0.6), "count": 3},
			{"level": 10, "item": "nebula_fruit", "color": Color(0.6, 0.3, 0.7), "count": 3},
			{"level": 15, "item": "solar_grain", "color": Color(0.8, 0.7, 0.2), "count": 2},
		]
	})

	# ── Hive Tunnels — Hive resources (xenobotany) ──
	c = _area_center("hive-tunnels")
	_spawn_defs.append({
		"area": "hive-tunnels",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "xenobotany",
		"nodes": [
			{"level": 18, "item": "chitin_shard", "color": Color(0.5, 0.4, 0.2), "count": 3},
			{"level": 25, "item": "alien_steak", "color": Color(0.7, 0.3, 0.3), "count": 3},
			{"level": 30, "item": "spore_cap", "color": Color(0.5, 0.6, 0.3), "count": 2},
			{"level": 35, "item": "plasma_pepper", "color": Color(1.0, 0.3, 0.1), "count": 2},
		]
	})

	# ── Solarith Wastes — Desert flora (xenobotany) ──
	c = _area_center("solarith-wastes")
	_spawn_defs.append({
		"area": "solarith-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "xenobotany",
		"nodes": [
			{"level": 35, "item": "sun_cactus", "color": Color(0.9, 0.7, 0.1), "count": 8},
			{"level": 45, "item": "desert_thornvine", "color": Color(0.6, 0.5, 0.2), "count": 6},
			{"level": 55, "item": "mirage_bloom", "color": Color(0.9, 0.4, 0.8), "count": 4},
		]
	})

	# ── Solarith Wastes — Desert ores (astromining) ──
	_spawn_defs.append({
		"area": "solarith-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "astromining",
		"nodes": [
			{"level": 35, "item": "solarite_ore", "color": Color(1.0, 0.6, 0.1), "count": 8},
			{"level": 40, "item": "amber_crystal", "color": Color(0.9, 0.7, 0.2), "count": 6},
			{"level": 50, "item": "obsidian_ore", "color": Color(0.15, 0.1, 0.15), "count": 4},
		]
	})

	# ── Fungal Wastes — Fungal flora (xenobotany) ──
	c = _area_center("fungal-wastes")
	_spawn_defs.append({
		"area": "fungal-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "xenobotany",
		"nodes": [
			{"level": 40, "item": "void_moss", "color": Color(0.25, 0.5, 0.3), "count": 3},
			{"level": 50, "item": "neural_bloom", "color": Color(0.6, 0.3, 0.8), "count": 3},
			{"level": 60, "item": "quantum_vine", "color": Color(0.2, 0.8, 0.8), "count": 2},
		]
	})

	# ── Fungal Wastes — Fungal ores (astromining) ──
	_spawn_defs.append({
		"area": "fungal-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "astromining",
		"nodes": [
			{"level": 40, "item": "titanex_ore", "color": Color(0.9, 0.95, 0.1), "count": 2},
			{"level": 50, "item": "plasmite_ore", "color": Color(0.8, 0.15, 1.0), "count": 2},
		]
	})

	# ── Stalker Reaches — Shadow flora (xenobotany) ──
	c = _area_center("stalker-reaches")
	_spawn_defs.append({
		"area": "stalker-reaches",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "xenobotany",
		"nodes": [
			{"level": 55, "item": "void_truffle", "color": Color(0.3, 0.1, 0.4), "count": 2},
			{"level": 65, "item": "gravity_residue", "color": Color(0.4, 0.2, 0.6), "count": 2},
			{"level": 70, "item": "crystal_honey", "color": Color(0.9, 0.8, 0.3), "count": 2},
		]
	})

	# ── Stalker Reaches — Deep ores (astromining) ──
	_spawn_defs.append({
		"area": "stalker-reaches",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "astromining",
		"nodes": [
			{"level": 60, "item": "quantite_ore", "color": Color(1.0, 0.5, 0.0), "count": 2},
			{"level": 70, "item": "neutronium_ore", "color": Color(1.0, 0.1, 0.3), "count": 2},
		]
	})

	# ── Corrupted Wastes — Corrupted resources (xenobotany) ──
	c = _area_center("corrupted-wastes")
	_spawn_defs.append({
		"area": "corrupted-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "xenobotany",
		"nodes": [
			{"level": 80, "item": "neural_bloom", "color": Color(0.8, 0.2, 0.9), "count": 2},
			{"level": 90, "item": "void_truffle", "color": Color(0.4, 0.0, 0.5), "count": 2},
		]
	})

	# ── Corrupted Wastes — Dark ores (astromining) ──
	_spawn_defs.append({
		"area": "corrupted-wastes",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "astromining",
		"nodes": [
			{"level": 80, "item": "darkmatter_shard", "color": Color(0.15, 0.0, 0.35), "count": 2},
		]
	})

	# ── Void Citadel — Dimensional flora (xenobotany) ──
	c = _area_center("void-citadel")
	_spawn_defs.append({
		"area": "void-citadel",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "xenobotany",
		"nodes": [
			{"level": 65, "item": "dimensional_moss", "color": Color(0.3, 0.1, 0.6), "count": 6},
			{"level": 75, "item": "void_bloom", "color": Color(0.5, 0.0, 0.8), "count": 4},
			{"level": 85, "item": "architect_root", "color": Color(0.2, 0.3, 0.5), "count": 3},
		]
	})

	# ── Void Citadel — Void minerals (astromining) ──
	_spawn_defs.append({
		"area": "void-citadel",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.85,
		"skill": "astromining",
		"nodes": [
			{"level": 65, "item": "void_crystal", "color": Color(0.4, 0.0, 0.7), "count": 6},
			{"level": 75, "item": "phase_ore", "color": Color(0.3, 0.5, 0.9), "count": 4},
			{"level": 85, "item": "singularity_shard_ore", "color": Color(0.1, 0.0, 0.3), "count": 3},
		]
	})

	# ── The Abyss — Abyssal flora (xenobotany) ──
	c = _area_center("the-abyss")
	_spawn_defs.append({
		"area": "the-abyss",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "xenobotany",
		"nodes": [
			{"level": 100, "item": "architect_root", "color": Color(0.15, 0.2, 0.5), "count": 3},
			{"level": 140, "item": "void_bloom", "color": Color(0.6, 0.0, 0.9), "count": 2},
		]
	})

	# ── The Abyss — Abyssal ores (astromining) ──
	_spawn_defs.append({
		"area": "the-abyss",
		"cx": c.cx, "cz": c.cz, "radius": c.radius * 0.8,
		"skill": "astromining",
		"nodes": [
			{"level": 90, "item": "voidsteel_ore", "color": Color(0.1, 0.0, 0.2), "count": 3},
		]
	})

func _spawn_all_nodes() -> void:
	var total: int = 0
	var area_mgr: Node3D = get_tree().get_first_node_in_group("area_manager")

	for zone in _spawn_defs:
		var cx: float = float(zone["cx"])
		var cz: float = float(zone["cz"])
		var radius: float = float(zone["radius"])
		var skill: String = str(zone["skill"])
		var nodes: Array = zone["nodes"]

		# Find the level range in this zone for clustering
		var min_level: int = 999
		var max_level: int = 0
		for nd in nodes:
			var lv: int = int(nd["level"])
			min_level = mini(min_level, lv)
			max_level = maxi(max_level, lv)
		var level_range: int = max_level - min_level

		# Pick a random-but-deterministic base cluster direction per zone
		var zone_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		zone_rng.seed = hash(str(cx) + str(cz) + skill)
		var cluster_angle: float = zone_rng.randf() * TAU
		var num_tiers: int = nodes.size()

		for tier_idx in range(num_tiers):
			var node_def: Dictionary = nodes[tier_idx]
			var level: int = int(node_def["level"])
			var item_id: String = str(node_def["item"])
			var color: Color = node_def["color"]
			var count: int = int(node_def["count"])

			# Each tier gets its own angular direction (starburst pattern)
			var tier_angle: float = cluster_angle + float(tier_idx) / float(num_tiers) * TAU

			# Level-based radial offset: always at least 15% from center
			var level_frac: float = 0.0
			if level_range > 0:
				level_frac = float(level - min_level) / float(level_range)
			var cluster_dist: float = (radius * 0.15) + level_frac * radius * 0.45
			var cluster_cx: float = cx + cos(tier_angle) * cluster_dist
			var cluster_cz: float = cz + sin(tier_angle) * cluster_dist
			# Tighter scatter per tier — keeps tiers distinct without overlapping
			var scatter_r: float = radius * 0.2 if level_range > 0 else radius * 0.85
			var min_scatter: float = maxf(5.0, scatter_r * 0.15)

			for i in range(count):
				var angle: float = randf() * TAU
				var dist: float = randf_range(min_scatter, scatter_r)
				var gx: float = cluster_cx + cos(angle) * dist
				var gz: float = cluster_cz + sin(angle) * dist
				var gy: float = 0.1
				if area_mgr and area_mgr.has_method("get_terrain_height"):
					gy = area_mgr.get_terrain_height(gx, gz) + 0.1
				var pos: Vector3 = Vector3(gx, gy, gz)

				var node_id: String = "%s_%s_%d" % [skill, item_id, i]
				var gnode: StaticBody3D = StaticBody3D.new()
				gnode.name = "GatherNode_%s" % node_id
				gnode.set_script(gathering_script)
				add_child(gnode)
				gnode.setup(node_id, item_id, skill, level, pos, color)
				total += 1

	print("GatheringSpawner: %d gathering nodes spawned" % total)
