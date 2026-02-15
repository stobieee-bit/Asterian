## GatheringNode — A clickable resource node in the world (ore, spores, etc.)
##
## Player clicks to start gathering. Shows a progress bar while channeling.
## Awards resources and XP on completion. Respawns after a timer.
extends StaticBody3D

# ── Configuration ──
var node_id: String = ""
var resource_id: String = ""       # Item to give on gather
var skill_id: String = ""          # Required skill
var skill_level: int = 1           # Required level
var gather_time: float = 3.0       # Seconds to gather
var xp_reward: int = 20            # XP per gather
var respawn_time: float = 15.0     # Seconds to respawn

# ── State ──
var _is_depleted: bool = false
var _respawn_timer: float = 0.0
var _mesh: CSGCylinder3D = null
var _label: Label3D = null
var _node_color: Color = Color(0.6, 0.5, 0.3)

func setup(p_node_id: String, p_resource_id: String, p_skill: String, p_level: int, pos: Vector3, color: Color) -> void:
	node_id = p_node_id
	resource_id = p_resource_id
	skill_id = p_skill
	skill_level = p_level
	global_position = pos
	_node_color = color

	# Scale gather time and XP by level
	gather_time = 2.0 + skill_level * 0.1
	xp_reward = 15 + skill_level * 3
	respawn_time = 10.0 + skill_level * 0.5

	_apply_visuals()

func _ready() -> void:
	add_to_group("gathering_nodes")
	collision_layer = 16  # Gathering layer (layer 5)
	collision_mask = 0

	# Build mesh — rocky formation with glow
	_mesh = CSGCylinder3D.new()
	_mesh.radius = 0.7
	_mesh.height = 1.2
	_mesh.sides = 5  # Pentagonal for rock look
	_mesh.position.y = 0.6
	add_child(_mesh)

	# Crystal spike on top for visual interest
	var spike: CSGCylinder3D = CSGCylinder3D.new()
	spike.radius = 0.2
	spike.height = 0.8
	spike.sides = 4
	spike.cone = true
	spike.position.y = 1.4
	spike.rotation.z = 0.2
	add_child(spike)
	spike.name = "Spike"

	# Glow ring at base
	var glow_ring: CSGTorus3D = CSGTorus3D.new()
	glow_ring.inner_radius = 0.6
	glow_ring.outer_radius = 0.8
	glow_ring.ring_sides = 6
	glow_ring.sides = 12
	glow_ring.position.y = 0.05
	add_child(glow_ring)
	glow_ring.name = "GlowRing"

	# Label — large, high-contrast, readable from distance
	_label = Label3D.new()
	_label.position = Vector3(0, 2.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.95)
	_label.pixel_size = 0.01  # Slightly larger pixel scale for far visibility
	add_child(_label)

	# Collision — slightly larger
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.5
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)

func _process(delta: float) -> void:
	if _is_depleted:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_respawn()

func _apply_visuals() -> void:
	if _mesh:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = _node_color
		mat.metallic = 0.3
		mat.roughness = 0.5
		mat.emission_enabled = true
		mat.emission = _node_color.lightened(0.2)
		mat.emission_energy_multiplier = 0.6
		_mesh.material = mat

	# Apply bright crystal material to spike
	var spike: Node = get_node_or_null("Spike")
	if spike:
		var spike_mat: StandardMaterial3D = StandardMaterial3D.new()
		spike_mat.albedo_color = _node_color.lightened(0.3)
		spike_mat.metallic = 0.6
		spike_mat.roughness = 0.2
		spike_mat.emission_enabled = true
		spike_mat.emission = _node_color.lightened(0.5)
		spike_mat.emission_energy_multiplier = 2.5
		spike.material = spike_mat

	# Glow ring at base
	var glow_ring: Node = get_node_or_null("GlowRing")
	if glow_ring:
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.albedo_color = _node_color.lightened(0.4)
		ring_mat.emission_enabled = true
		ring_mat.emission = _node_color.lightened(0.5)
		ring_mat.emission_energy_multiplier = 2.0
		glow_ring.material = ring_mat

	if _label:
		var item_data: Dictionary = DataManager.get_item(resource_id)
		var item_name: String = str(item_data.get("name", resource_id))
		var skill_data: Dictionary = DataManager.get_skill(skill_id)
		var skill_name: String = str(skill_data.get("name", skill_id))
		_label.text = "%s\nLv %d %s" % [item_name, skill_level, skill_name]
		# Color by whether player meets level requirement
		if can_gather():
			_label.modulate = Color(0.9, 0.8, 0.4, 1.0)
		else:
			_label.modulate = Color(0.7, 0.3, 0.3, 1.0)

## Check if player can gather this node
func can_gather() -> bool:
	if _is_depleted:
		return false
	var current_level: int = int(GameState.skills.get(skill_id, {}).get("level", 1))
	return current_level >= skill_level

## Get the time to gather
func get_gather_time() -> float:
	return gather_time

## Complete a gather — give item and XP
func complete_gather() -> void:
	if _is_depleted:
		return

	# Give item
	var success: bool = GameState.add_item(resource_id, 1)
	if not success:
		return  # Inventory full

	# Give XP
	if GameState.skills.has(skill_id):
		GameState.skills[skill_id]["xp"] = int(GameState.skills[skill_id]["xp"]) + xp_reward
		EventBus.player_xp_gained.emit(skill_id, xp_reward)

	# Check level up
	var current_level: int = int(GameState.skills[skill_id]["level"])
	var current_xp: int = int(GameState.skills[skill_id]["xp"])
	var next_xp: int = DataManager.xp_for_level(current_level + 1)
	if next_xp > 0 and current_xp >= next_xp:
		GameState.skills[skill_id]["level"] = current_level + 1
		EventBus.player_level_up.emit(skill_id, current_level + 1)

	# Float text
	var item_data: Dictionary = DataManager.get_item(resource_id)
	var item_name: String = str(item_data.get("name", resource_id))
	EventBus.float_text_requested.emit("+1 %s" % item_name, global_position + Vector3(0, 2.0, 0), Color(0.4, 0.8, 1.0))

	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id))
	EventBus.float_text_requested.emit("+%d %s XP" % [xp_reward, skill_name], global_position + Vector3(0, 2.5, 0), Color(0.3, 0.9, 0.3))

	EventBus.gathering_complete.emit(skill_id, resource_id)

	# Deplete
	_deplete()

func _deplete() -> void:
	_is_depleted = true
	_respawn_timer = respawn_time

	# Animate shrink before hiding
	if _mesh:
		var tween: Tween = create_tween()
		tween.tween_property(_mesh, "scale", Vector3(0.1, 0.1, 0.1), 0.3).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			if _mesh:
				_mesh.visible = false
				_mesh.scale = Vector3.ONE
		)

	# Hide spike and glow ring
	var spike: Node3D = get_node_or_null("Spike") as Node3D
	if spike:
		var st: Tween = create_tween()
		st.tween_property(spike, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
		st.tween_callback(func():
			if spike:
				spike.visible = false
				spike.scale = Vector3.ONE
		)

	var glow_ring: Node3D = get_node_or_null("GlowRing") as Node3D
	if glow_ring:
		var gt: Tween = create_tween()
		gt.tween_property(glow_ring, "scale", Vector3(1.5, 0.1, 1.5), 0.3).set_ease(Tween.EASE_OUT)
		gt.tween_callback(func():
			if glow_ring:
				glow_ring.visible = false
				glow_ring.scale = Vector3.ONE
		)

	if _label:
		_label.visible = false

	# Spawn burst particles (small CSG spheres that fly outward)
	_spawn_deplete_particles()

func _respawn() -> void:
	_is_depleted = false

	# Show elements
	var spike: Node3D = get_node_or_null("Spike") as Node3D
	var glow_ring: Node3D = get_node_or_null("GlowRing") as Node3D

	if _mesh:
		_mesh.visible = true
		_mesh.scale = Vector3(0.01, 0.01, 0.01)
		var mt: Tween = create_tween()
		mt.tween_property(_mesh, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if spike:
		spike.visible = true
		spike.scale = Vector3(0.01, 0.01, 0.01)
		var st: Tween = create_tween()
		st.tween_interval(0.15)
		st.tween_property(spike, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if glow_ring:
		glow_ring.visible = true
		glow_ring.scale = Vector3(0.01, 0.01, 0.01)
		var gt: Tween = create_tween()
		gt.tween_interval(0.25)
		gt.tween_property(glow_ring, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	if _label:
		_label.visible = true
		_label.modulate.a = 0.0
		var lt: Tween = create_tween()
		lt.tween_interval(0.3)
		lt.tween_property(_label, "modulate:a", 1.0, 0.3)

## Spawn small spheres that fly outward on depletion
func _spawn_deplete_particles() -> void:
	var particle_count: int = 5
	for i in range(particle_count):
		var particle: CSGSphere3D = CSGSphere3D.new()
		particle.radius = 0.08 + randf() * 0.06
		particle.radial_segments = 6
		particle.rings = 4
		particle.top_level = true
		particle.global_position = global_position + Vector3(0, 0.8, 0)

		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.albedo_color = _node_color.lightened(0.3)
		pmat.emission_enabled = true
		pmat.emission = _node_color.lightened(0.5)
		pmat.emission_energy_multiplier = 3.0
		particle.material = pmat

		add_child(particle)

		# Fly outward
		var angle: float = (float(i) / particle_count) * TAU + randf() * 0.5
		var target: Vector3 = particle.global_position + Vector3(
			cos(angle) * 1.5,
			1.0 + randf() * 0.5,
			sin(angle) * 1.5
		)

		var pt: Tween = create_tween()
		pt.set_parallel(true)
		pt.tween_property(particle, "global_position", target, 0.5 + randf() * 0.3).set_ease(Tween.EASE_OUT)
		pt.tween_property(particle, "scale", Vector3(0.01, 0.01, 0.01), 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
		pt.set_parallel(false)
		pt.tween_callback(particle.queue_free)
