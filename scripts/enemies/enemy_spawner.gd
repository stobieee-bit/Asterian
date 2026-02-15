## EnemySpawner — Populates the world with enemies based on sub-zone data
##
## Reads ENEMY_SUB_ZONES from DataManager, picks appropriate enemy types
## for each zone's level range, and spawns them in clusters.
## Uses proximity-based activation to avoid spawning 500+ enemies at once.
extends Node3D

# Scene to instantiate
var enemy_scene: PackedScene = preload("res://scenes/entities/enemy.tscn")

# ── Spawn configuration ──
@export var spawn_radius_from_player: float = 120.0  # Only spawn zones near player
@export var despawn_radius: float = 180.0             # Remove enemies far from player
@export var max_enemies_total: int = 80               # Cap total active enemies
@export var respawn_check_interval: float = 5.0       # Seconds between zone checks

# ── State ──
var _active_enemies: Array[Node] = []
var _zone_spawn_data: Array[Dictionary] = []  # Precomputed zone info
var _check_timer: float = 0.0
var _player: Node3D = null

func _ready() -> void:
	_precompute_zones()
	# Initial spawn after a short delay (let world build)
	await get_tree().create_timer(0.5).timeout
	_player = get_tree().get_first_node_in_group("player")
	_spawn_nearby_zones()

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	_check_timer -= delta
	if _check_timer <= 0:
		_check_timer = respawn_check_interval
		_spawn_nearby_zones()
		_despawn_far_enemies()

## Precompute which enemy types go in which zones
func _precompute_zones() -> void:
	for zone in DataManager.enemy_sub_zones:
		var zone_data: Dictionary = {
			"id": str(zone.get("id", "")),
			"area": str(zone.get("area", "")),
			"cx": float(zone.get("cx", 0)),
			"cz": float(zone.get("cz", 0)),
			"radius": float(zone.get("radius", 50)),
			"level_min": int(zone.get("levelMin", 1)),
			"level_max": int(zone.get("levelMax", 10)),
			"density": float(zone.get("density", 0.5)),
			"enemy_types": [] as Array[String],
			"spawned_count": 0,
			"target_count": 0,
		}

		# Find enemy types that fit this zone's level range and area
		var types: Array[String] = []
		for enemy_id in DataManager.enemies:
			var edata: Dictionary = DataManager.enemies[enemy_id]
			var elevel: int = int(edata.get("level", 0))
			var earea: String = str(edata.get("area", ""))
			if elevel >= zone_data["level_min"] and elevel <= zone_data["level_max"]:
				if earea == zone_data["area"] or earea == "":
					types.append(enemy_id)

		zone_data["enemy_types"] = types

		# Target count based on density and zone radius
		var r: float = zone_data["radius"]
		var d: float = zone_data["density"]
		var area_factor: float = r * r * PI / 1000.0
		zone_data["target_count"] = maxi(2, int(area_factor * d))

		if types.size() > 0:
			_zone_spawn_data.append(zone_data)

	print("EnemySpawner: %d zones precomputed" % _zone_spawn_data.size())

## Spawn enemies in zones near the player
func _spawn_nearby_zones() -> void:
	if _player == null:
		return

	var player_pos: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	var total_active: int = _active_enemies.size()

	for zone in _zone_spawn_data:
		# Skip if we're at the global cap
		if total_active >= max_enemies_total:
			break

		var zone_center: Vector2 = Vector2(float(zone["cx"]), float(zone["cz"]))
		var dist: float = player_pos.distance_to(zone_center)

		# Only process nearby zones
		if dist > spawn_radius_from_player:
			continue

		# Count living enemies in this zone
		var living: int = _count_living_in_zone(zone)
		var target: int = zone["target_count"]

		# Spawn up to target
		var to_spawn: int = mini(target - living, max_enemies_total - total_active)
		if to_spawn <= 0:
			continue

		var types: Array = zone["enemy_types"]
		if types.size() == 0:
			continue

		for i in range(to_spawn):
			var type_id: String = types[randi() % types.size()]
			var pos: Vector3 = _random_position_in_zone(zone)
			_spawn_enemy(type_id, pos, zone["id"])
			total_active += 1

## Spawn a single enemy. Bosses automatically get BossAI child node.
func _spawn_enemy(type_id: String, pos: Vector3, zone_id: String) -> void:
	var enemy: CharacterBody3D = enemy_scene.instantiate()
	add_child(enemy)
	enemy.setup(type_id, pos)
	enemy.set_meta("zone_id", zone_id)
	_active_enemies.append(enemy)

	# Attach BossAI controller to boss enemies
	if enemy.is_boss:
		var boss_ai_script: GDScript = preload("res://scripts/enemies/boss_ai.gd")
		var boss_ai: Node = Node.new()
		boss_ai.name = "BossAI"
		boss_ai.set_script(boss_ai_script)
		enemy.add_child(boss_ai)

## Remove enemies far from player
func _despawn_far_enemies() -> void:
	if _player == null:
		return

	var to_remove: Array[int] = []
	for i in range(_active_enemies.size() - 1, -1, -1):
		var enemy: Node = _active_enemies[i]
		if not is_instance_valid(enemy):
			_active_enemies.remove_at(i)
			continue
		var dist: float = (enemy as Node3D).global_position.distance_to(_player.global_position)
		if dist > despawn_radius:
			enemy.queue_free()
			_active_enemies.remove_at(i)

## Count living (non-dead) enemies in a zone
func _count_living_in_zone(zone: Dictionary) -> int:
	var count: int = 0
	var zone_id: String = zone["id"]
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get_meta("zone_id", "") == zone_id:
			if enemy.state != enemy.State.DEAD:
				count += 1
	return count

## Random position within a zone's circle
func _random_position_in_zone(zone: Dictionary) -> Vector3:
	var angle: float = randf() * TAU
	var dist: float = randf_range(2.0, float(zone["radius"]) * 0.8)
	return Vector3(
		float(zone["cx"]) + cos(angle) * dist,
		0.1,  # Just above ground level so gravity settles immediately
		float(zone["cz"]) + sin(angle) * dist
	)
