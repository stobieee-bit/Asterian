## LootSystem — Handles enemy loot drops and ground item management
##
## When an enemy dies, rolls its loot table and spawns ground items.
## All pickups are click-only — no auto-pickup. Player right-clicks an item,
## selects "Pick up", walks to it, and the item is collected on arrival.
extends Node3D

# Ground item scene
var ground_item_scene: PackedScene = preload("res://scenes/world/ground_item.tscn")

# ── Active ground items ──
var _ground_items: Array[Node3D] = []
var _max_ground_items: int = 30
var _player: Node3D = null

# ── Pickup config ──
var pickup_range: float = 3.0  # Max distance to collect an item
var ground_item_lifetime: float = 45.0  # Despawn after 45 seconds

# ── Pending pickup (player is walking toward this item) ──
var _pending_pickup: Node3D = null

func _ready() -> void:
	# Listen for enemy kills to roll loot
	EventBus.enemy_killed.connect(_on_enemy_killed)
	# Listen for items dropped from inventory onto the ground
	EventBus.item_dropped_to_ground.connect(_on_item_dropped_to_ground)
	# Listen for click-to-pickup requests from context menu
	EventBus.ground_item_pickup_requested.connect(_on_pickup_requested)


## Called when player drops an item from inventory onto the ground
func _on_item_dropped_to_ground(item_id: String, quantity: int, pos: Vector3) -> void:
	_spawn_ground_item(item_id, quantity, pos)

## Called when the player selects "Pick up" from context menu
func _on_pickup_requested(gitem: Node3D) -> void:
	if is_instance_valid(gitem) and _ground_items.has(gitem):
		_pending_pickup = gitem

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	# ── Check pending pickup — player walked close enough to collect ──
	if _pending_pickup != null:
		if not is_instance_valid(_pending_pickup):
			_pending_pickup = null
		else:
			var dist: float = _player.global_position.distance_to(_pending_pickup.global_position)
			if dist <= pickup_range:
				var idx: int = _ground_items.find(_pending_pickup)
				if idx >= 0:
					_pickup_item(_pending_pickup, idx)
				_pending_pickup = null

	# ── Lifetime despawn + cleanup ──
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
			if _pending_pickup == gitem:
				_pending_pickup = null
			_ground_items.remove_at(i)
			gitem.queue_free()
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

	# Elite loot bonus: 1.5x drop chances
	var is_elite: bool = ("is_elite" in enemy_node and enemy_node.is_elite)
	var elite_mult: float = 1.5 if is_elite else 1.0

	# Bestiary loot bonus: +1% per 10 bestiary entries (max +10%)
	var bestiary_bonus: float = minf(0.10, float(GameState.collection_log.size()) * 0.001)

	# Roll each loot entry
	for entry in loot_table:
		var chance: float = float(entry.get("chance", 0.0))
		chance += bestiary_bonus  # Bestiary completion bonus
		chance *= elite_mult      # Elite bonus
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
	var drop_pos: Vector3 = pos + offset
	var area_mgr: Node3D = get_tree().get_first_node_in_group("area_manager")
	if area_mgr and area_mgr.has_method("get_terrain_height"):
		drop_pos.y = area_mgr.get_terrain_height(drop_pos.x, drop_pos.z) + 0.3
	else:
		drop_pos.y = pos.y + 0.3
	gitem.global_position = drop_pos

	# Store item data on the node
	gitem.set_meta("item_id", item_id)
	gitem.set_meta("quantity", quantity)
	gitem.set_meta("spawn_time", 0.0)

	# Set up visuals based on item data
	if gitem.has_method("setup"):
		gitem.setup(item_id, quantity)

	_ground_items.append(gitem)

	# Loot beam for rare items (tier 4+)
	var item_data: Dictionary = DataManager.get_item(item_id)
	var tier: int = int(item_data.get("tier", 0))
	if tier >= 4:
		_spawn_loot_beam(drop_pos, tier)
		EventBus.rare_loot_dropped.emit(item_id, drop_pos)

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

## Spawn a loot beam (emissive CSGCylinder3D) at a position for rare drops
func _spawn_loot_beam(pos: Vector3, tier: int) -> void:
	var beam: CSGCylinder3D = CSGCylinder3D.new()
	beam.radius = 0.08
	beam.height = 15.0
	beam.sides = 6
	beam.global_position = pos + Vector3(0, 7.5, 0)

	# Color by tier
	var beam_color: Color
	match tier:
		4: beam_color = Color(0.2, 0.6, 1.0)     # Blue
		5: beam_color = Color(0.8, 0.2, 1.0)      # Purple
		_: beam_color = Color(1.0, 0.85, 0.1)     # Gold (tier 6+)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = beam_color
	mat.emission_enabled = true
	mat.emission = beam_color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	beam.material = mat

	add_child(beam)

	# Fade out over 10 seconds
	var tween: Tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 10.0)
	tween.tween_callback(beam.queue_free)
