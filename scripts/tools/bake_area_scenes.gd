## Headless zone bake script — generates one .tscn per area + per corridor
## Usage: Godot_v4.4.1-stable_win64_console.exe --headless --path <project> --script res://scripts/tools/bake_area_scenes.gd
extends SceneTree

const OUTPUT_DIR: String = "res://scenes/areas/"

var _am: Node3D = null
var _world: Node3D = null
var _frame: int = 0
var _phase: int = 0  # 0=wait for autoloads, 1=build area_manager, 2=wait for build, 3=bake

func _init() -> void:
	print("BakeAreas: Initializing, waiting for autoloads...")

func _process(_delta: float) -> bool:
	_frame += 1

	if _phase == 0:
		# Phase 0: Wait for autoloads to be ready (a few frames)
		if _frame >= 3:
			_phase = 1
			_setup_area_manager()
		return false

	elif _phase == 1:
		# Phase 1: area_manager is being added, wait for _ready() to run
		_phase = 2
		return false

	elif _phase == 2:
		# Phase 2: Wait for area_manager to finish building (await process_frame in _ready)
		if _frame >= 15:
			_phase = 3
			_do_bake()
			return true  # Quit

	return false

func _setup_area_manager() -> void:
	print("BakeAreas: Setting up scene tree...")

	_world = Node3D.new()
	_world.name = "World"

	# area_manager uses @onready var world_env = $"../WorldEnvironment"
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	_world.add_child(we)

	# Load area_manager script (autoloads should be available now)
	var am_script = load("res://scripts/world/area_manager.gd")
	if am_script == null:
		printerr("BakeAreas: FATAL — could not load area_manager.gd")
		quit()
		return

	_am = Node3D.new()
	_am.name = "AreaManager"
	_am.set_script(am_script)
	_world.add_child(_am)

	# Add to scene tree — triggers _ready() cascade
	root.add_child(_world)
	print("BakeAreas: Area manager added to tree, waiting for build to complete...")

func _do_bake() -> void:
	var child_count: int = _am.get_child_count()
	print("BakeAreas: Area manager has %d children, starting classification..." % child_count)

	if child_count == 0:
		printerr("BakeAreas: No children found! area_manager may not have built properly.")
		return

	# Ensure output directory
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# Load area data for classification
	var file := FileAccess.open("res://data/areas.json", FileAccess.READ)
	var json: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var areas: Dictionary = json["areas"]
	var corridors: Array = json["corridors"]

	# Prepare classification containers
	var area_nodes: Dictionary = {}   # area_id -> Array[Node]
	var corridor_nodes: Dictionary = {}  # corridor_id -> Array[Node]
	var skip_nodes: Array = []

	for area_id in areas:
		area_nodes[area_id] = []
	for corr in corridors:
		corridor_nodes[str(corr["id"])] = []

	# Classify each child of area_manager
	for child in _am.get_children():
		if not child is Node3D:
			continue

		var node3d: Node3D = child as Node3D
		var name_str: String = node3d.name

		# Skip runtime-only nodes (fallback ground, safety floor, boundaries)
		if name_str == "FallbackGround" or name_str == "SafetyFloor":
			skip_nodes.append(child)
			continue
		if name_str.begins_with("Boundary_") or name_str.begins_with("BoundaryWall"):
			skip_nodes.append(child)
			continue

		var pos: Vector3 = node3d.position

		# Try to classify by corridor rectangle first (corridors overlap areas)
		var in_corridor: bool = false
		for corr in corridors:
			var min_x: float = float(corr["minX"])
			var max_x: float = float(corr["maxX"])
			var min_z: float = float(corr["minZ"])
			var max_z: float = float(corr["maxZ"])
			var margin: float = 20.0
			if pos.x >= min_x - margin and pos.x <= max_x + margin \
					and pos.z >= min_z - margin and pos.z <= max_z + margin:
				var corr_cx: float = (min_x + max_x) / 2.0
				var corr_cz: float = (min_z + max_z) / 2.0
				var corr_dist: float = _dist2d(pos.x, pos.z, corr_cx, corr_cz)
				var closest_area_dist: float = _closest_area_dist(pos.x, pos.z, areas)
				var corr_half_diag: float = sqrt((max_x - min_x) ** 2 + (max_z - min_z) ** 2) / 2.0
				if corr_dist <= corr_half_diag + margin and corr_dist < closest_area_dist:
					corridor_nodes[str(corr["id"])].append(child)
					in_corridor = true
					break
		if in_corridor:
			continue

		# Classify by area (closest area center within 1.5x radius)
		var best_id: String = ""
		var best_dist: float = INF
		for area_id in areas:
			var data: Dictionary = areas[area_id]
			var cx: float = float(data["center"]["x"])
			var cz: float = float(data["center"]["z"])
			var radius: float = float(data["radius"])
			var dist: float = _dist2d(pos.x, pos.z, cx, cz)
			if dist <= radius * 1.5 and dist < best_dist:
				best_dist = dist
				best_id = area_id
		if best_id != "":
			area_nodes[best_id].append(child)
		else:
			# Fallback: nearest area regardless of radius
			best_dist = INF
			for area_id in areas:
				var data: Dictionary = areas[area_id]
				var cx: float = float(data["center"]["x"])
				var cz: float = float(data["center"]["z"])
				var dist: float = _dist2d(pos.x, pos.z, cx, cz)
				if dist < best_dist:
					best_dist = dist
					best_id = area_id
			if best_id != "":
				area_nodes[best_id].append(child)

	# Save area scenes
	var success: int = 0
	for area_id in area_nodes:
		var nodes: Array = area_nodes[area_id]
		if nodes.is_empty():
			print("BakeAreas: [SKIP] %s — no nodes" % area_id)
			continue
		if _save_scene(area_id, nodes):
			success += 1

	# Save corridor scenes
	for corr_id in corridor_nodes:
		var nodes: Array = corridor_nodes[corr_id]
		if nodes.is_empty():
			continue
		if _save_scene("corridor_%s" % corr_id, nodes):
			success += 1

	print("BakeAreas: Done! %d scenes saved, %d nodes skipped (runtime-only)" % [
		success, skip_nodes.size()])

func _save_scene(scene_name: String, nodes: Array) -> bool:
	var root_node := Node3D.new()
	root_node.name = scene_name

	for node in nodes:
		var dupe: Node = node.duplicate()
		root_node.add_child(dupe)

	_set_owner_recursive(root_node, root_node)

	var scene := PackedScene.new()
	var err: Error = scene.pack(root_node)
	if err != OK:
		printerr("BakeAreas: Failed to pack '%s' (error %d)" % [scene_name, err])
		root_node.free()
		return false

	var save_path: String = OUTPUT_DIR + scene_name + ".tscn"
	err = ResourceSaver.save(scene, save_path)
	if err != OK:
		printerr("BakeAreas: Failed to save '%s' (error %d)" % [save_path, err])
		root_node.free()
		return false

	print("BakeAreas: Saved %s (%d nodes)" % [save_path, nodes.size()])
	root_node.free()
	return true

func _dist2d(x1: float, z1: float, x2: float, z2: float) -> float:
	return sqrt((x1 - x2) ** 2 + (z1 - z2) ** 2)

func _closest_area_dist(x: float, z: float, areas: Dictionary) -> float:
	var best: float = INF
	for area_id in areas:
		var data: Dictionary = areas[area_id]
		var cx: float = float(data["center"]["x"])
		var cz: float = float(data["center"]["z"])
		var dist: float = _dist2d(x, z, cx, cz)
		if dist < best:
			best = dist
	return best

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)
