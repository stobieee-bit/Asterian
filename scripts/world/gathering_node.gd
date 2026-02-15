## GatheringNode — A clickable resource node in the world (ore, spores, etc.)
##
## Player clicks to start gathering. Shows a progress bar while channeling.
## Awards resources and XP on completion. Respawns after a timer.
## Each ore tier has a unique silhouette so players can tell them apart at a glance.
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
var _mesh_parts: Array[Node3D] = []   # All CSG parts for deplete/respawn animation
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

	# Build tier-specific mesh
	_build_mesh_for_tier()

	# Label — large, high-contrast, readable from distance
	_label = Label3D.new()
	_label.position = Vector3(0, 2.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.95)
	_label.pixel_size = 0.01
	add_child(_label)

	# Collision
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

## Build unique mesh based on skill_level tier
func _build_mesh_for_tier() -> void:
	if skill_level <= 1:
		_build_rock_mound()       # Stellarite — simple low rock
	elif skill_level <= 10:
		_build_flat_crystal()     # Ferrite — chunky rock with crystal slab
	elif skill_level <= 20:
		_build_crystal_cluster()  # Cobaltium — cluster of angled spikes
	elif skill_level <= 30:
		_build_layered_deposit()  # Duranite — stacked cube layers
	elif skill_level <= 40:
		_build_obelisk()          # Titanex — tall hexagonal pillar
	elif skill_level <= 50:
		_build_floating_orb()     # Plasmite — hovering sphere with ring
	elif skill_level <= 60:
		_build_gem_formation()    # Quantite — rotated cube diamond shape
	else:
		_build_star_core()        # Neutronium — dense intersecting star

# ── Tier 1: Stellarite — Low, wide rock mound ──
func _build_rock_mound() -> void:
	# Wide flat base rock
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.9
	base.height = 0.6
	base.sides = 6
	base.position.y = 0.3
	add_child(base)
	_mesh_parts.append(base)

	# Small bump on top
	var bump: CSGSphere3D = CSGSphere3D.new()
	bump.radius = 0.45
	bump.radial_segments = 6
	bump.rings = 4
	bump.position.y = 0.7
	add_child(bump)
	bump.name = "Accent1"
	_mesh_parts.append(bump)

	# Glow ring
	_add_glow_ring(0.7, 0.9)

# ── Tier 2: Ferrite — Chunky rock with flat crystal slab ──
func _build_flat_crystal() -> void:
	# Pentagonal rock body
	var body: CSGCylinder3D = CSGCylinder3D.new()
	body.radius = 0.7
	body.height = 0.9
	body.sides = 5
	body.position.y = 0.45
	add_child(body)
	_mesh_parts.append(body)

	# Flat crystal slab on top (wide, thin box)
	var slab: CSGBox3D = CSGBox3D.new()
	slab.size = Vector3(1.0, 0.15, 0.6)
	slab.position.y = 1.05
	slab.rotation.y = 0.4
	add_child(slab)
	slab.name = "Accent1"
	_mesh_parts.append(slab)

	# Small shard poking out at angle
	var shard: CSGBox3D = CSGBox3D.new()
	shard.size = Vector3(0.15, 0.5, 0.12)
	shard.position = Vector3(0.3, 1.1, 0.1)
	shard.rotation.z = -0.3
	add_child(shard)
	shard.name = "Accent2"
	_mesh_parts.append(shard)

	_add_glow_ring(0.6, 0.8)

# ── Tier 3: Cobaltium — Crystal cluster (3 angled spikes) ──
func _build_crystal_cluster() -> void:
	# Low rocky base
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.5
	base.height = 0.5
	base.sides = 5
	base.position.y = 0.25
	add_child(base)
	_mesh_parts.append(base)

	# Three crystal spikes at different angles
	for i in range(3):
		var spike: CSGCylinder3D = CSGCylinder3D.new()
		spike.radius = 0.12
		spike.height = 1.0 + i * 0.25
		spike.sides = 4
		spike.cone = true

		var angle: float = i * TAU / 3.0
		spike.position = Vector3(cos(angle) * 0.15, 0.7 + i * 0.15, sin(angle) * 0.15)
		spike.rotation.x = sin(angle) * 0.25
		spike.rotation.z = cos(angle) * 0.25
		add_child(spike)
		spike.name = "Accent%d" % (i + 1)
		_mesh_parts.append(spike)

	_add_glow_ring(0.4, 0.6)

# ── Tier 4: Duranite — Layered cube deposit (stacked boxes) ──
func _build_layered_deposit() -> void:
	# Bottom layer — wide
	var layer1: CSGBox3D = CSGBox3D.new()
	layer1.size = Vector3(1.2, 0.35, 1.0)
	layer1.position.y = 0.175
	add_child(layer1)
	_mesh_parts.append(layer1)

	# Middle layer — offset and rotated
	var layer2: CSGBox3D = CSGBox3D.new()
	layer2.size = Vector3(0.9, 0.35, 0.75)
	layer2.position.y = 0.525
	layer2.rotation.y = 0.3
	add_child(layer2)
	layer2.name = "Accent1"
	_mesh_parts.append(layer2)

	# Top layer — smallest, tilted
	var layer3: CSGBox3D = CSGBox3D.new()
	layer3.size = Vector3(0.6, 0.3, 0.5)
	layer3.position.y = 0.85
	layer3.rotation.y = -0.2
	layer3.rotation.z = 0.1
	add_child(layer3)
	layer3.name = "Accent2"
	_mesh_parts.append(layer3)

	_add_glow_ring(0.7, 0.9)

# ── Tier 5: Titanex — Tall hexagonal obelisk ──
func _build_obelisk() -> void:
	# Tall hexagonal pillar
	var pillar: CSGCylinder3D = CSGCylinder3D.new()
	pillar.radius = 0.4
	pillar.height = 2.0
	pillar.sides = 6
	pillar.position.y = 1.0
	add_child(pillar)
	_mesh_parts.append(pillar)

	# Pointed cap
	var cap: CSGCylinder3D = CSGCylinder3D.new()
	cap.radius = 0.35
	cap.height = 0.6
	cap.sides = 6
	cap.cone = true
	cap.position.y = 2.3
	add_child(cap)
	cap.name = "Accent1"
	_mesh_parts.append(cap)

	# Small ledge / collar near base
	var collar: CSGTorus3D = CSGTorus3D.new()
	collar.inner_radius = 0.35
	collar.outer_radius = 0.55
	collar.ring_sides = 6
	collar.sides = 6
	collar.position.y = 0.4
	add_child(collar)
	collar.name = "Accent2"
	_mesh_parts.append(collar)

	_add_glow_ring(0.5, 0.7)

# ── Tier 6: Plasmite — Floating sphere with energy ring ──
func _build_floating_orb() -> void:
	# Hovering sphere
	var orb: CSGSphere3D = CSGSphere3D.new()
	orb.radius = 0.55
	orb.radial_segments = 12
	orb.rings = 8
	orb.position.y = 1.2
	add_child(orb)
	_mesh_parts.append(orb)

	# Orbiting ring (tilted torus)
	var ring: CSGTorus3D = CSGTorus3D.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.8
	ring.ring_sides = 6
	ring.sides = 16
	ring.position.y = 1.2
	ring.rotation.x = 0.5
	ring.rotation.z = 0.3
	add_child(ring)
	ring.name = "Accent1"
	_mesh_parts.append(ring)

	# Small ground anchor pebble
	var anchor: CSGCylinder3D = CSGCylinder3D.new()
	anchor.radius = 0.25
	anchor.height = 0.2
	anchor.sides = 6
	anchor.position.y = 0.1
	add_child(anchor)
	anchor.name = "Accent2"
	_mesh_parts.append(anchor)

	_add_glow_ring(0.5, 0.7)

# ── Tier 7: Quantite — Multi-faceted gem (rotated cube = diamond) ──
func _build_gem_formation() -> void:
	# Rotated cube standing on corner (diamond shape)
	var gem: CSGBox3D = CSGBox3D.new()
	gem.size = Vector3(0.8, 0.8, 0.8)
	gem.position.y = 1.0
	gem.rotation.x = PI / 4.0
	gem.rotation.z = PI / 4.0
	add_child(gem)
	_mesh_parts.append(gem)

	# Second smaller gem floating nearby
	var gem2: CSGBox3D = CSGBox3D.new()
	gem2.size = Vector3(0.4, 0.4, 0.4)
	gem2.position = Vector3(0.5, 0.7, 0.3)
	gem2.rotation.x = PI / 4.0
	gem2.rotation.y = PI / 6.0
	gem2.rotation.z = PI / 4.0
	add_child(gem2)
	gem2.name = "Accent1"
	_mesh_parts.append(gem2)

	# Tiny third shard
	var gem3: CSGBox3D = CSGBox3D.new()
	gem3.size = Vector3(0.25, 0.25, 0.25)
	gem3.position = Vector3(-0.4, 0.5, -0.2)
	gem3.rotation.x = PI / 3.0
	gem3.rotation.z = PI / 5.0
	add_child(gem3)
	gem3.name = "Accent2"
	_mesh_parts.append(gem3)

	_add_glow_ring(0.6, 0.8)

# ── Tier 8: Neutronium — Dense star core (intersecting shapes + sphere) ──
func _build_star_core() -> void:
	# Central glowing sphere
	var core: CSGSphere3D = CSGSphere3D.new()
	core.radius = 0.4
	core.radial_segments = 10
	core.rings = 6
	core.position.y = 1.0
	add_child(core)
	_mesh_parts.append(core)

	# Three intersecting boxes forming a star burst
	for i in range(3):
		var arm: CSGBox3D = CSGBox3D.new()
		arm.size = Vector3(0.2, 1.4, 0.2)
		arm.position.y = 1.0
		var rot_angle: float = i * PI / 3.0
		arm.rotation.z = rot_angle
		arm.rotation.x = i * 0.3
		add_child(arm)
		arm.name = "Accent%d" % (i + 1)
		_mesh_parts.append(arm)

	# Outer energy ring
	var ring: CSGTorus3D = CSGTorus3D.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 0.9
	ring.ring_sides = 6
	ring.sides = 16
	ring.position.y = 1.0
	ring.rotation.x = PI / 2.0
	add_child(ring)
	ring.name = "Ring"
	_mesh_parts.append(ring)

	_add_glow_ring(0.6, 0.85)

# ── Shared: glow ring at base ──
func _add_glow_ring(inner_r: float, outer_r: float) -> void:
	var glow_ring: CSGTorus3D = CSGTorus3D.new()
	glow_ring.inner_radius = inner_r
	glow_ring.outer_radius = outer_r
	glow_ring.ring_sides = 6
	glow_ring.sides = 12
	glow_ring.position.y = 0.05
	add_child(glow_ring)
	glow_ring.name = "GlowRing"
	_mesh_parts.append(glow_ring)

func _process(delta: float) -> void:
	if _is_depleted:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_respawn()

func _apply_visuals() -> void:
	# Body material — rocky base look
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = _node_color
	body_mat.metallic = 0.2 + skill_level * 0.006  # Higher tiers more metallic
	body_mat.roughness = 0.6 - skill_level * 0.004  # Higher tiers smoother
	body_mat.emission_enabled = true
	body_mat.emission = _node_color.lightened(0.2)
	body_mat.emission_energy_multiplier = 0.5 + skill_level * 0.02

	# Accent material — brighter crystal/highlight parts
	var accent_mat: StandardMaterial3D = StandardMaterial3D.new()
	accent_mat.albedo_color = _node_color.lightened(0.3)
	accent_mat.metallic = 0.5 + skill_level * 0.005
	accent_mat.roughness = 0.25
	accent_mat.emission_enabled = true
	accent_mat.emission = _node_color.lightened(0.5)
	accent_mat.emission_energy_multiplier = 2.0 + skill_level * 0.02

	# Glow ring material
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = _node_color.lightened(0.4)
	ring_mat.emission_enabled = true
	ring_mat.emission = _node_color.lightened(0.5)
	ring_mat.emission_energy_multiplier = 2.0

	# Apply materials to mesh parts
	for part in _mesh_parts:
		if part.name.begins_with("Accent") or part.name == "Ring":
			part.material = accent_mat
		elif part.name == "GlowRing":
			part.material = ring_mat
		else:
			part.material = body_mat

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

	# Animate all mesh parts shrinking
	for i in range(_mesh_parts.size()):
		var part: Node3D = _mesh_parts[i]
		var delay: float = i * 0.05
		var tw: Tween = create_tween()
		tw.tween_interval(delay)
		tw.tween_property(part, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(part):
				part.visible = false
				part.scale = Vector3.ONE
		)

	if _label:
		_label.visible = false

	# Spawn burst particles
	_spawn_deplete_particles()

func _respawn() -> void:
	_is_depleted = false

	# Animate all mesh parts popping back in
	for i in range(_mesh_parts.size()):
		var part: Node3D = _mesh_parts[i]
		if is_instance_valid(part):
			part.visible = true
			part.scale = Vector3(0.01, 0.01, 0.01)
			var delay: float = i * 0.08
			var tw: Tween = create_tween()
			tw.tween_interval(delay)
			tw.tween_property(part, "scale", Vector3.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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
