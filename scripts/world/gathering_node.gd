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

# ── Tier 1: Stellarite — Small scattered boulders ──
func _build_rock_mound() -> void:
	# Three boulders of different sizes clustered together
	var b1: CSGSphere3D = CSGSphere3D.new()
	b1.radius = 0.6
	b1.radial_segments = 6
	b1.rings = 4
	b1.position = Vector3(0.0, 0.5, 0.0)
	add_child(b1)
	_mesh_parts.append(b1)

	var b2: CSGSphere3D = CSGSphere3D.new()
	b2.radius = 0.4
	b2.radial_segments = 5
	b2.rings = 3
	b2.position = Vector3(0.5, 0.35, 0.3)
	add_child(b2)
	b2.name = "Accent1"
	_mesh_parts.append(b2)

	var b3: CSGSphere3D = CSGSphere3D.new()
	b3.radius = 0.3
	b3.radial_segments = 5
	b3.rings = 3
	b3.position = Vector3(-0.4, 0.25, 0.2)
	add_child(b3)
	b3.name = "Accent2"
	_mesh_parts.append(b3)

	_add_glow_ring(0.7, 0.9)

# ── Tier 2: Ferrite — Blocky anvil-shaped rock ──
func _build_flat_crystal() -> void:
	# Wide flat base
	var base: CSGBox3D = CSGBox3D.new()
	base.size = Vector3(1.4, 0.5, 1.0)
	base.position.y = 0.25
	add_child(base)
	_mesh_parts.append(base)

	# Narrower top block (anvil)
	var top: CSGBox3D = CSGBox3D.new()
	top.size = Vector3(0.8, 0.6, 0.6)
	top.position.y = 0.8
	add_child(top)
	top.name = "Accent1"
	_mesh_parts.append(top)

	# Crystal shard poking up from top
	var shard: CSGCylinder3D = CSGCylinder3D.new()
	shard.radius = 0.15
	shard.height = 0.7
	shard.sides = 4
	shard.cone = true
	shard.position = Vector3(0.15, 1.45, 0.0)
	shard.rotation.z = 0.15
	add_child(shard)
	shard.name = "Accent2"
	_mesh_parts.append(shard)

	_add_glow_ring(0.8, 1.0)

# ── Tier 3: Cobaltium — Tall crystal spire cluster ──
func _build_crystal_cluster() -> void:
	# Central tall spire
	var main_spire: CSGCylinder3D = CSGCylinder3D.new()
	main_spire.radius = 0.2
	main_spire.height = 2.5
	main_spire.sides = 4
	main_spire.cone = true
	main_spire.position.y = 1.25
	add_child(main_spire)
	main_spire.name = "Accent1"
	_mesh_parts.append(main_spire)

	# Four surrounding shorter spires
	for i in range(4):
		var spike: CSGCylinder3D = CSGCylinder3D.new()
		spike.radius = 0.14
		spike.height = 1.2 + randf_range(0.0, 0.8)
		spike.sides = 4
		spike.cone = true
		var a: float = i * TAU / 4.0 + 0.4
		var dist: float = 0.4
		spike.position = Vector3(cos(a) * dist, spike.height * 0.5, sin(a) * dist)
		spike.rotation.x = sin(a) * 0.2
		spike.rotation.z = -cos(a) * 0.2
		add_child(spike)
		spike.name = "Accent%d" % (i + 2)
		_mesh_parts.append(spike)

	# Low rocky base that spires grow from
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.6
	base.height = 0.4
	base.sides = 5
	base.position.y = 0.2
	add_child(base)
	_mesh_parts.append(base)

	_add_glow_ring(0.5, 0.7)

# ── Tier 4: Duranite — Stacked slab staircase ──
func _build_layered_deposit() -> void:
	# 4 slabs stacked like tectonic plates, each offset
	var widths: Array[float] = [1.6, 1.3, 1.0, 0.7]
	var depths: Array[float] = [1.2, 1.0, 0.8, 0.6]
	for i in range(4):
		var slab: CSGBox3D = CSGBox3D.new()
		slab.size = Vector3(widths[i], 0.3, depths[i])
		slab.position.y = 0.15 + i * 0.32
		slab.position.x = i * 0.1 - 0.15
		slab.rotation.y = i * 0.2
		add_child(slab)
		if i > 0:
			slab.name = "Accent%d" % i
		_mesh_parts.append(slab)

	_add_glow_ring(0.9, 1.1)

# ── Tier 5: Titanex — Tall hexagonal obelisk with runes ──
func _build_obelisk() -> void:
	# Tall hexagonal pillar
	var pillar: CSGCylinder3D = CSGCylinder3D.new()
	pillar.radius = 0.5
	pillar.height = 3.0
	pillar.sides = 6
	pillar.position.y = 1.5
	add_child(pillar)
	_mesh_parts.append(pillar)

	# Pointed pyramid cap
	var cap: CSGCylinder3D = CSGCylinder3D.new()
	cap.radius = 0.45
	cap.height = 0.9
	cap.sides = 6
	cap.cone = true
	cap.position.y = 3.45
	add_child(cap)
	cap.name = "Accent1"
	_mesh_parts.append(cap)

	# Decorative collar rings at two heights
	for i in range(2):
		var collar: CSGTorus3D = CSGTorus3D.new()
		collar.inner_radius = 0.45
		collar.outer_radius = 0.7
		collar.ring_sides = 6
		collar.sides = 6
		collar.position.y = 0.8 + i * 1.4
		add_child(collar)
		collar.name = "Accent%d" % (i + 2)
		_mesh_parts.append(collar)

	_add_glow_ring(0.6, 0.85)

# ── Tier 6: Plasmite — Large floating orb with double rings ──
func _build_floating_orb() -> void:
	# Large hovering sphere
	var orb: CSGSphere3D = CSGSphere3D.new()
	orb.radius = 0.8
	orb.radial_segments = 14
	orb.rings = 10
	orb.position.y = 1.8
	add_child(orb)
	_mesh_parts.append(orb)

	# Horizontal ring
	var ring1: CSGTorus3D = CSGTorus3D.new()
	ring1.inner_radius = 0.9
	ring1.outer_radius = 1.1
	ring1.ring_sides = 6
	ring1.sides = 16
	ring1.position.y = 1.8
	add_child(ring1)
	ring1.name = "Accent1"
	_mesh_parts.append(ring1)

	# Tilted vertical ring
	var ring2: CSGTorus3D = CSGTorus3D.new()
	ring2.inner_radius = 1.0
	ring2.outer_radius = 1.15
	ring2.ring_sides = 6
	ring2.sides = 16
	ring2.position.y = 1.8
	ring2.rotation.x = PI / 2.0
	ring2.rotation.y = 0.5
	add_child(ring2)
	ring2.name = "Accent2"
	_mesh_parts.append(ring2)

	# Small ground pedestal
	var pedestal: CSGCylinder3D = CSGCylinder3D.new()
	pedestal.radius = 0.35
	pedestal.height = 0.3
	pedestal.sides = 8
	pedestal.position.y = 0.15
	add_child(pedestal)
	pedestal.name = "Accent3"
	_mesh_parts.append(pedestal)

	_add_glow_ring(0.6, 0.85)

# ── Tier 7: Quantite — Huge diamond gem with orbiting fragments ──
func _build_gem_formation() -> void:
	# Large rotated cube (diamond) standing on vertex
	var gem: CSGBox3D = CSGBox3D.new()
	gem.size = Vector3(1.2, 1.2, 1.2)
	gem.position.y = 1.5
	gem.rotation.x = PI / 4.0
	gem.rotation.z = PI / 4.0
	add_child(gem)
	_mesh_parts.append(gem)

	# Three orbiting fragment shards at different heights/positions
	var frag_data: Array = [
		{"size": 0.4, "pos": Vector3(0.9, 1.0, 0.5), "rot_y": 0.5},
		{"size": 0.35, "pos": Vector3(-0.8, 1.8, -0.4), "rot_y": 1.2},
		{"size": 0.3, "pos": Vector3(0.3, 2.4, -0.7), "rot_y": 2.5},
	]
	for i in range(frag_data.size()):
		var fd: Dictionary = frag_data[i]
		var frag: CSGBox3D = CSGBox3D.new()
		var s: float = fd["size"]
		frag.size = Vector3(s, s, s)
		frag.position = fd["pos"]
		frag.rotation.x = PI / 4.0
		frag.rotation.y = fd["rot_y"]
		frag.rotation.z = PI / 4.0
		add_child(frag)
		frag.name = "Accent%d" % (i + 1)
		_mesh_parts.append(frag)

	_add_glow_ring(0.8, 1.05)

# ── Tier 8: Neutronium — Massive star core with radiating arms ──
func _build_star_core() -> void:
	# Large central glowing sphere
	var core: CSGSphere3D = CSGSphere3D.new()
	core.radius = 0.7
	core.radial_segments = 12
	core.rings = 8
	core.position.y = 1.5
	add_child(core)
	_mesh_parts.append(core)

	# Six radiating crystal arms in a starburst pattern
	for i in range(6):
		var arm: CSGBox3D = CSGBox3D.new()
		arm.size = Vector3(0.18, 1.8, 0.18)
		arm.position.y = 1.5
		var rot_a: float = i * PI / 3.0
		arm.rotation.z = rot_a
		arm.rotation.x = fmod(i * 0.45, PI)
		add_child(arm)
		arm.name = "Accent%d" % (i + 1)
		_mesh_parts.append(arm)

	# Two crossing energy rings
	for i in range(2):
		var ring: CSGTorus3D = CSGTorus3D.new()
		ring.inner_radius = 1.1
		ring.outer_radius = 1.25
		ring.ring_sides = 6
		ring.sides = 16
		ring.position.y = 1.5
		ring.rotation.x = PI / 2.0 * i
		ring.rotation.y = 0.6 * i
		add_child(ring)
		ring.name = "Ring%d" % (i + 1)
		_mesh_parts.append(ring)

	_add_glow_ring(0.9, 1.15)

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
	# Body material — strong saturated color
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = _node_color
	body_mat.metallic = 0.3 + skill_level * 0.005
	body_mat.roughness = 0.5 - skill_level * 0.004
	body_mat.emission_enabled = true
	body_mat.emission = _node_color  # Pure color emission, no lightening
	body_mat.emission_energy_multiplier = 1.2 + skill_level * 0.03

	# Accent material — brighter, high-glow crystal parts
	var accent_mat: StandardMaterial3D = StandardMaterial3D.new()
	accent_mat.albedo_color = _node_color.lightened(0.15)
	accent_mat.metallic = 0.6 + skill_level * 0.004
	accent_mat.roughness = 0.2
	accent_mat.emission_enabled = true
	accent_mat.emission = _node_color.lightened(0.15)
	accent_mat.emission_energy_multiplier = 3.0 + skill_level * 0.04

	# Glow ring material — brightest
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = _node_color.lightened(0.2)
	ring_mat.emission_enabled = true
	ring_mat.emission = _node_color.lightened(0.2)
	ring_mat.emission_energy_multiplier = 3.5

	# Apply materials to mesh parts
	for part in _mesh_parts:
		if part.name.begins_with("Accent") or part.name.begins_with("Ring"):
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
