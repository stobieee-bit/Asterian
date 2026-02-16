## LootSystem — Handles enemy loot drops and ground item management
##
## When an enemy dies, rolls its loot table and spawns ground items.
## Ground items are clickable and auto-pickup when player walks near.
extends Node3D

# Ground item scene
var ground_item_scene: PackedScene = preload("res://scenes/world/ground_item.tscn")

# ── Active ground items ──
var _ground_items: Array[Node3D] = []
var _max_ground_items: int = 30
var _player: Node3D = null

# ── Pickup config ──
var auto_pickup_range: float = 3.0  # Slightly larger pickup range
var ground_item_lifetime: float = 45.0  # Despawn after 45 seconds

func _ready() -> void:
	# Listen for enemy kills to roll loot
	EventBus.enemy_killed.connect(_on_enemy_killed)
	# Listen for items dropped from inventory onto the ground
	EventBus.item_dropped_to_ground.connect(_on_item_dropped_to_ground)


## Called when player drops an item from inventory onto the ground
func _on_item_dropped_to_ground(item_id: String, quantity: int, pos: Vector3) -> void:
	_spawn_ground_item(item_id, quantity, pos)
	# Mark the most recently spawned ground item as player-dropped so it isn't
	# instantly auto-picked back up (2-second immunity window)
	if _ground_items.size() > 0:
		_ground_items[_ground_items.size() - 1].set_meta("pickup_immunity", 2.0)

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	# Check for auto-pickup proximity and lifetime despawn
	var i: int = _ground_items.size() - 1
	while i >= 0:
		var gitem: Node3D = _ground_items[i]
		if not is_instance_valid(gitem):
			_ground_items.remove_at(i)
			i -= 1
			continue

		# Track lifetime
		var age: float = float(gitem.get_meta("spawn_time", 0.0))
		age += delta
		gitem.set_meta("spawn_time", age)

		# Despawn if too old
		if age > ground_item_lifetime:
			_ground_items.remove_at(i)
			gitem.queue_free()
			i -= 1
			continue

		# Tick down pickup immunity for player-dropped items
		var immunity: float = float(gitem.get_meta("pickup_immunity", 0.0))
		if immunity > 0.0:
			immunity -= delta
			gitem.set_meta("pickup_immunity", immunity)
			i -= 1
			continue

		# Auto-pickup when player is close enough
		var dist: float = _player.global_position.distance_to(gitem.global_position)
		if dist <= auto_pickup_range:
			_pickup_item(gitem, i)
			# _pickup_item removes from array on success, so don't decrement
			i -= 1
			continue

		i -= 1

## Roll loot for an enemy and spawn ground items
func _on_enemy_killed(eid: String, _etype: String) -> void:
	# Find the enemy node to get position and loot table
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var enemy_node: Node = null
	for e in enemies:
		if is_instance_valid(e) and e.enemy_id == eid:
			enemy_node = e
			break

	if enemy_node == null:
		return

	var enemy_data: Dictionary = DataManager.get_enemy(eid)
	if enemy_data.is_empty():
		return

	var loot_table: Array = enemy_data.get("lootTable", [])
	var spawn_pos: Vector3 = (enemy_node as Node3D).global_position

	# Roll each loot entry
	for entry in loot_table:
		var chance: float = float(entry.get("chance", 0.0))
		if randf() > chance:
			continue

		var item_id: String = str(entry.get("itemId", ""))
		if item_id == "":
			continue

		var min_qty: int = int(entry.get("min", 1))
		var max_qty: int = int(entry.get("max", 1))
		var quantity: int = randi_range(min_qty, max_qty)

		# Handle credits as a special case
		if item_id == "credits":
			GameState.add_credits(quantity)
			EventBus.float_text_requested.emit(
				"+%d credits" % quantity,
				spawn_pos + Vector3(randf_range(-0.5, 0.5), 2.0, 0),
				Color(1.0, 0.85, 0.2)
			)
			continue

		# Spawn a ground item
		_spawn_ground_item(item_id, quantity, spawn_pos)

	# Also roll level-based loot from lookup tables
	var enemy_level: int = int(enemy_data.get("level", 1))
	_roll_level_loot(enemy_level, spawn_pos)

## Spawn a ground item at a position
func _spawn_ground_item(item_id: String, quantity: int, pos: Vector3) -> void:
	if _ground_items.size() >= _max_ground_items:
		# Remove oldest
		var oldest: Node3D = _ground_items[0]
		_ground_items.remove_at(0)
		if is_instance_valid(oldest):
			oldest.queue_free()

	var gitem: Node3D = ground_item_scene.instantiate()
	add_child(gitem)

	# Scatter slightly from kill position
	var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	gitem.global_position = pos + offset
	gitem.global_position.y = pos.y + 0.3

	# Store item data on the node
	gitem.set_meta("item_id", item_id)
	gitem.set_meta("quantity", quantity)
	gitem.set_meta("spawn_time", 0.0)

	# Set up visuals based on item data
	if gitem.has_method("setup"):
		gitem.setup(item_id, quantity)

	_ground_items.append(gitem)

## Try to pick up a ground item
func _pickup_item(gitem: Node3D, index: int) -> void:
	var item_id: String = str(gitem.get_meta("item_id", ""))
	var quantity: int = int(gitem.get_meta("quantity", 1))

	if item_id == "":
		return

	# Try to add to inventory
	var success: bool = GameState.add_item(item_id, quantity)
	if success:
		# Show pickup float text
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_name: String = str(item_data.get("name", item_id))
		var qty_text: String = " x%d" % quantity if quantity > 1 else ""
		EventBus.float_text_requested.emit(
			"+%s%s" % [item_name, qty_text],
			gitem.global_position + Vector3(0, 1.5, 0),
			Color(0.3, 0.9, 1.0)
		)
		EventBus.chat_message.emit("Picked up %s%s" % [item_name, qty_text], "loot")

		# Remove ground item
		_ground_items.remove_at(index)
		gitem.queue_free()
	# If inventory full, item stays on ground (inventory_full signal already emitted)

## Roll bonus loot from level-based lookup tables (ore, food, bio materials)
func _roll_level_loot(enemy_level: int, spawn_pos: Vector3) -> void:
	# 20% chance for bonus resource drop
	if randf() > 0.20:
		return

	# Pick a random loot category
	var categories: Array[String] = ["ore", "bio_mat", "food", "prestige_mat"]
	var cat: String = categories[randi() % categories.size()]

	var table: Array = DataManager.enemy_loot_tables.get(cat, [])
	if table.is_empty():
		return

	# Find matching entry for this level
	var item_id: String = ""
	for entry in table:
		if entry is Array and entry.size() >= 3:
			var min_lvl: int = int(entry[0])
			var max_lvl: int = int(entry[1])
			if enemy_level >= min_lvl and enemy_level <= max_lvl:
				item_id = str(entry[2])
				break

	if item_id != "":
		_spawn_ground_item(item_id, 1, spawn_pos)

## Click pickup — called when player clicks a ground item
func try_click_pickup(gitem: Node3D) -> void:
	var idx: int = _ground_items.find(gitem)
	if idx >= 0:
		_pickup_item(gitem, idx)
