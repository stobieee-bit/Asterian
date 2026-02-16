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

	# Build mesh and apply materials AFTER resource_id is set
	# (setup() is called after add_child() in spawner, so _ready() runs first
	#  when resource_id is still empty — we must build here instead)
	_build_mesh_for_tier()

	# Label — large, high-contrast, readable from distance
	# Must be created BEFORE _apply_visuals() so label text can be set
	var max_y: float = 2.0
	for part in _mesh_parts:
		var top: float = part.position.y + 1.0
		if top > max_y:
			max_y = top
	_label = Label3D.new()
	_label.position = Vector3(0, max_y + 0.5, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.95)
	_label.pixel_size = 0.01
	add_child(_label)

	_apply_visuals()

func _ready() -> void:
	add_to_group("gathering_nodes")
	collision_layer = 16  # Gathering layer (layer 5)
	collision_mask = 0

	# Collision
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

## Build unique mesh per resource — every resource has its own silhouette
func _build_mesh_for_tier() -> void:
	match resource_id:
		# ── ASTROMINING (10 resources) ──
		"stellarite_ore":    _build_rock_mound()
		"ferrite_ore":       _build_flat_crystal()
		"cobaltium_ore":     _build_crystal_cluster()
		"duranite_ore":      _build_layered_deposit()
		"titanex_ore":       _build_obelisk()
		"plasmite_ore":      _build_floating_orb()
		"quantite_ore":      _build_gem_formation()
		"neutronium_ore":    _build_star_core()
		"darkmatter_shard":  _build_darkmatter_shard()
		"voidsteel_ore":     _build_voidsteel_ore()
		# ── XENOBOTANY (14 resources) ──
		"space_lichen":      _build_lichen_patch()
		"cryo_kelp":         _build_kelp_stalks()
		"nebula_fruit":      _build_nebula_fruit()
		"solar_grain":       _build_grain_cluster()
		"chitin_shard":      _build_chitin_shard()
		"alien_steak":       _build_alien_steak()
		"spore_cap":         _build_mushroom_cluster()
		"plasma_pepper":     _build_vine_pods()
		"void_moss":         _build_void_moss()
		"crystal_honey":     _build_flower_bloom()
		"neural_bloom":      _build_neural_bloom()
		"void_truffle":      _build_truffle_tendrils()
		"quantum_vine":      _build_quantum_vine()
		"gravity_residue":   _build_alien_tree()
		_:                   _build_rock_mound()

# ══════════════════════════════════════════════════════════════
# ASTROMINING MESHES — 10 unique mineral/ore silhouettes
# ══════════════════════════════════════════════════════════════

# ── Stellarite Ore (lv1) — LOW wide boulder pile, very round and squat ──
func _build_rock_mound() -> void:
	# Big main boulder - wide and low
	var b1: CSGSphere3D = CSGSphere3D.new()
	b1.radius = 1.0
	b1.radial_segments = 6
	b1.rings = 4
	b1.position = Vector3(0.0, 0.5, 0.0)
	b1.scale = Vector3(1.3, 0.7, 1.2)
	add_child(b1)
	_mesh_parts.append(b1)

	# Smaller side boulder
	var b2: CSGSphere3D = CSGSphere3D.new()
	b2.radius = 0.6
	b2.radial_segments = 5
	b2.rings = 3
	b2.position = Vector3(0.8, 0.3, 0.5)
	b2.scale = Vector3(1.1, 0.8, 1.0)
	add_child(b2)
	b2.name = "Accent1"
	_mesh_parts.append(b2)

	# Tiny pebble
	var b3: CSGSphere3D = CSGSphere3D.new()
	b3.radius = 0.35
	b3.radial_segments = 5
	b3.rings = 3
	b3.position = Vector3(-0.7, 0.2, 0.4)
	add_child(b3)
	b3.name = "Accent2"
	_mesh_parts.append(b3)

	_add_glow_ring(1.2, 1.4)

# ── Ferrite Ore (lv10) — WIDE flat anvil slab, very boxy and horizontal ──
func _build_flat_crystal() -> void:
	# Very wide flat base slab
	var base: CSGBox3D = CSGBox3D.new()
	base.size = Vector3(2.2, 0.5, 1.6)
	base.position.y = 0.25
	add_child(base)
	_mesh_parts.append(base)

	# Stepped upper block
	var top: CSGBox3D = CSGBox3D.new()
	top.size = Vector3(1.4, 0.5, 1.0)
	top.position = Vector3(-0.2, 0.75, 0.0)
	add_child(top)
	top.name = "Accent1"
	_mesh_parts.append(top)

	# Small angular shard on top
	var shard: CSGBox3D = CSGBox3D.new()
	shard.size = Vector3(0.5, 0.7, 0.4)
	shard.position = Vector3(0.3, 1.35, 0.0)
	shard.rotation = Vector3(0.0, 0.4, 0.15)
	add_child(shard)
	shard.name = "Accent2"
	_mesh_parts.append(shard)

	_add_glow_ring(1.3, 1.5)

# ── Cobaltium Ore (lv20) — TALL spiky crystal spires pointing UP ──
func _build_crystal_cluster() -> void:
	# Very tall central spire
	var main_spire: CSGCylinder3D = CSGCylinder3D.new()
	main_spire.radius = 0.25
	main_spire.height = 3.5
	main_spire.sides = 4
	main_spire.cone = true
	main_spire.position.y = 1.75
	add_child(main_spire)
	main_spire.name = "Accent1"
	_mesh_parts.append(main_spire)

	# Five surrounding spires at different heights and angles
	for i in range(5):
		var spike: CSGCylinder3D = CSGCylinder3D.new()
		spike.radius = 0.18
		spike.height = 1.5 + i * 0.4
		spike.sides = 4
		spike.cone = true
		var a: float = i * TAU / 5.0 + 0.4
		var dist: float = 0.55
		spike.position = Vector3(cos(a) * dist, spike.height * 0.5, sin(a) * dist)
		spike.rotation.x = sin(a) * 0.25
		spike.rotation.z = -cos(a) * 0.25
		add_child(spike)
		spike.name = "Accent%d" % (i + 2)
		_mesh_parts.append(spike)

	# Rocky base platform
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.8
	base.height = 0.4
	base.sides = 5
	base.position.y = 0.2
	add_child(base)
	_mesh_parts.append(base)

	_add_glow_ring(0.9, 1.1)

# ── Duranite Ore (lv30) — STAIRCASE of stacked offset slabs ──
func _build_layered_deposit() -> void:
	# 5 slabs stacked like geological strata, each offset and rotated
	var widths: Array[float] = [2.0, 1.7, 1.4, 1.1, 0.8]
	var depths: Array[float] = [1.6, 1.3, 1.0, 0.8, 0.6]
	for i in range(5):
		var slab: CSGBox3D = CSGBox3D.new()
		slab.size = Vector3(widths[i], 0.35, depths[i])
		slab.position.y = 0.18 + i * 0.38
		slab.position.x = i * 0.15 - 0.3
		slab.rotation.y = i * 0.25
		add_child(slab)
		if i > 0:
			slab.name = "Accent%d" % i
		_mesh_parts.append(slab)

	_add_glow_ring(1.2, 1.4)

# ── Titanex Ore (lv40) — WIDE angular archway gate with keystone ──
func _build_obelisk() -> void:
	# Two thick hexagonal pillars forming a gateway
	var pillar_l: CSGCylinder3D = CSGCylinder3D.new()
	pillar_l.radius = 0.4
	pillar_l.height = 3.0
	pillar_l.sides = 6
	pillar_l.position = Vector3(-0.9, 1.5, 0.0)
	add_child(pillar_l)
	_mesh_parts.append(pillar_l)

	var pillar_r: CSGCylinder3D = CSGCylinder3D.new()
	pillar_r.radius = 0.4
	pillar_r.height = 3.0
	pillar_r.sides = 6
	pillar_r.position = Vector3(0.9, 1.5, 0.0)
	add_child(pillar_r)
	_mesh_parts.append(pillar_r)

	# Wide horizontal lintel across the top
	var lintel: CSGBox3D = CSGBox3D.new()
	lintel.size = Vector3(2.6, 0.5, 0.7)
	lintel.position.y = 3.25
	add_child(lintel)
	lintel.name = "Accent1"
	_mesh_parts.append(lintel)

	# Angular keystone block at center top
	var keystone: CSGBox3D = CSGBox3D.new()
	keystone.size = Vector3(0.6, 0.7, 0.6)
	keystone.position.y = 3.85
	keystone.rotation.y = PI / 4.0
	add_child(keystone)
	keystone.name = "Accent2"
	_mesh_parts.append(keystone)

	# Base platform connecting the pillars
	var base: CSGBox3D = CSGBox3D.new()
	base.size = Vector3(2.4, 0.3, 1.0)
	base.position.y = 0.15
	add_child(base)
	_mesh_parts.append(base)

	# Two decorative collar rings on each pillar
	for i in range(2):
		var collar: CSGTorus3D = CSGTorus3D.new()
		collar.inner_radius = 0.35
		collar.outer_radius = 0.55
		collar.ring_sides = 6
		collar.sides = 6
		collar.position = Vector3(-0.9, 1.0 + i * 1.2, 0.0)
		add_child(collar)
		collar.name = "Accent%d" % (i + 3)
		_mesh_parts.append(collar)

		var collar2: CSGTorus3D = CSGTorus3D.new()
		collar2.inner_radius = 0.35
		collar2.outer_radius = 0.55
		collar2.ring_sides = 6
		collar2.sides = 6
		collar2.position = Vector3(0.9, 1.0 + i * 1.2, 0.0)
		add_child(collar2)
		collar2.name = "Accent%d" % (i + 5)
		_mesh_parts.append(collar2)

	_add_glow_ring(1.3, 1.5)

# ── Plasmite Ore (lv50) — FLOATING ORB with orbital rings, hovers high ──
func _build_floating_orb() -> void:
	# Large hovering sphere — well above ground
	var orb: CSGSphere3D = CSGSphere3D.new()
	orb.radius = 1.0
	orb.radial_segments = 14
	orb.rings = 10
	orb.position.y = 2.5
	add_child(orb)
	_mesh_parts.append(orb)

	# Horizontal orbit ring
	var ring1: CSGTorus3D = CSGTorus3D.new()
	ring1.inner_radius = 1.2
	ring1.outer_radius = 1.4
	ring1.ring_sides = 6
	ring1.sides = 16
	ring1.position.y = 2.5
	add_child(ring1)
	ring1.name = "Accent1"
	_mesh_parts.append(ring1)

	# Tilted vertical ring
	var ring2: CSGTorus3D = CSGTorus3D.new()
	ring2.inner_radius = 1.3
	ring2.outer_radius = 1.5
	ring2.ring_sides = 6
	ring2.sides = 16
	ring2.position.y = 2.5
	ring2.rotation.x = PI / 2.0
	ring2.rotation.y = 0.5
	add_child(ring2)
	ring2.name = "Accent2"
	_mesh_parts.append(ring2)

	# Ground energy pillar connecting to ground
	var pillar: CSGCylinder3D = CSGCylinder3D.new()
	pillar.radius = 0.15
	pillar.height = 1.5
	pillar.sides = 8
	pillar.position.y = 0.75
	add_child(pillar)
	pillar.name = "Accent3"
	_mesh_parts.append(pillar)

	_add_glow_ring(0.8, 1.0)

# ── Quantite Ore (lv60) — HUGE diamond shape standing on vertex ──
func _build_gem_formation() -> void:
	# Large rotated cube (diamond) standing on vertex — very tall
	var gem: CSGBox3D = CSGBox3D.new()
	gem.size = Vector3(1.6, 1.6, 1.6)
	gem.position.y = 2.0
	gem.rotation.x = PI / 4.0
	gem.rotation.z = PI / 4.0
	add_child(gem)
	_mesh_parts.append(gem)

	# Four orbiting fragment shards
	var frag_data: Array = [
		{"size": 0.5, "pos": Vector3(1.2, 1.2, 0.6), "rot_y": 0.5},
		{"size": 0.45, "pos": Vector3(-1.0, 2.2, -0.5), "rot_y": 1.2},
		{"size": 0.4, "pos": Vector3(0.4, 3.0, -0.9), "rot_y": 2.5},
		{"size": 0.35, "pos": Vector3(-0.5, 0.8, 0.8), "rot_y": 3.8},
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

	_add_glow_ring(1.0, 1.2)

# ── Neutronium Ore (lv70) — STARBURST sphere with 8 radiating arms ──
func _build_star_core() -> void:
	# Large central sphere
	var core: CSGSphere3D = CSGSphere3D.new()
	core.radius = 0.9
	core.radial_segments = 12
	core.rings = 8
	core.position.y = 2.0
	add_child(core)
	_mesh_parts.append(core)

	# Eight radiating crystal arms in starburst pattern — very long
	for i in range(8):
		var arm: CSGBox3D = CSGBox3D.new()
		arm.size = Vector3(0.2, 2.2, 0.2)
		arm.position.y = 2.0
		var rot_a: float = i * PI / 4.0
		arm.rotation.z = rot_a
		arm.rotation.x = fmod(i * 0.5, PI)
		add_child(arm)
		arm.name = "Accent%d" % (i + 1)
		_mesh_parts.append(arm)

	# Two crossing energy rings
	for i in range(2):
		var ring: CSGTorus3D = CSGTorus3D.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.5
		ring.ring_sides = 6
		ring.sides = 12
		ring.position.y = 2.0
		ring.rotation.x = PI / 2.0 * i
		ring.rotation.y = 0.6 * i
		add_child(ring)
		ring.name = "Ring%d" % (i + 1)
		_mesh_parts.append(ring)

	_add_glow_ring(1.1, 1.3)

# ── Darkmatter Shard (lv80) — HUGE jagged blade jutting at sharp angle ──
func _build_darkmatter_shard() -> void:
	# Main shard — massive angled crystal blade
	var main_shard: CSGBox3D = CSGBox3D.new()
	main_shard.size = Vector3(0.8, 4.0, 0.5)
	main_shard.position = Vector3(0.0, 1.8, 0.0)
	main_shard.rotation = Vector3(0.0, 0.6, 0.5)
	add_child(main_shard)
	_mesh_parts.append(main_shard)

	# Two secondary blade fragments
	var f1: CSGBox3D = CSGBox3D.new()
	f1.size = Vector3(0.5, 2.0, 0.35)
	f1.position = Vector3(0.8, 1.0, 0.5)
	f1.rotation = Vector3(0.5, 0.8, 0.3)
	add_child(f1)
	f1.name = "Accent1"
	_mesh_parts.append(f1)

	var f2: CSGBox3D = CSGBox3D.new()
	f2.size = Vector3(0.4, 1.5, 0.3)
	f2.position = Vector3(-0.6, 0.8, -0.3)
	f2.rotation = Vector3(-0.4, 1.2, -0.4)
	add_child(f2)
	f2.name = "Accent2"
	_mesh_parts.append(f2)

	# Void energy orbs orbiting
	for i in range(4):
		var orb: CSGSphere3D = CSGSphere3D.new()
		orb.radius = 0.18
		orb.radial_segments = 8
		orb.rings = 6
		var a: float = i * TAU / 4.0 + 1.0
		orb.position = Vector3(cos(a) * 1.2, 2.0 + sin(i * 0.8) * 0.6, sin(a) * 1.2)
		add_child(orb)
		orb.name = "Accent%d" % (i + 3)
		_mesh_parts.append(orb)

	_add_glow_ring(1.0, 1.2)

# ── Voidsteel Ore (lv90) — MASSIVE rotated cube with dimensional rift rings ──
func _build_voidsteel_ore() -> void:
	# Dense metallic core cube — large and imposing
	var core: CSGBox3D = CSGBox3D.new()
	core.size = Vector3(1.5, 1.5, 1.5)
	core.position.y = 2.0
	core.rotation = Vector3(0.4, 0.6, 0.3)
	add_child(core)
	_mesh_parts.append(core)

	# Three void rift blades — thin elongated plates
	var rifts: Array = [
		{"size": Vector3(0.1, 3.0, 0.8), "pos": Vector3(1.0, 2.0, 0.0), "rot": Vector3(0.0, 0.0, 0.3)},
		{"size": Vector3(0.8, 2.8, 0.1), "pos": Vector3(0.0, 2.0, 1.0), "rot": Vector3(0.3, 0.0, 0.0)},
		{"size": Vector3(0.1, 2.5, 0.7), "pos": Vector3(-0.9, 2.0, -0.3), "rot": Vector3(0.0, 0.5, -0.2)},
	]
	for i in range(rifts.size()):
		var r: Dictionary = rifts[i]
		var rift: CSGBox3D = CSGBox3D.new()
		rift.size = r["size"]
		rift.position = r["pos"]
		rift.rotation = r["rot"]
		add_child(rift)
		rift.name = "Accent%d" % (i + 1)
		_mesh_parts.append(rift)

	# Four dimensional distortion rings at crossed angles
	for i in range(4):
		var ring: CSGTorus3D = CSGTorus3D.new()
		ring.inner_radius = 1.1 + i * 0.15
		ring.outer_radius = 1.3 + i * 0.15
		ring.ring_sides = 6
		ring.sides = 12
		ring.position.y = 2.0
		ring.rotation.x = i * 0.5
		ring.rotation.y = i * 0.7
		ring.rotation.z = i * 0.3
		add_child(ring)
		ring.name = "Accent%d" % (i + 4)
		_mesh_parts.append(ring)

	_add_glow_ring(1.2, 1.4)

# ══════════════════════════════════════════════════════════════
# XENOBOTANY MESHES — 14 unique organic/plant silhouettes
# ══════════════════════════════════════════════════════════════

# ── Space Lichen (lv1) — VERY FLAT ground-level spreading discs ──
func _build_lichen_patch() -> void:
	# Multiple flat wide discs spreading on ground — almost no height
	var patch_data: Array = [
		{"r": 1.0, "pos": Vector3(0.0, 0.06, 0.0), "sy": 0.12},
		{"r": 0.7, "pos": Vector3(0.9, 0.05, 0.4), "sy": 0.1},
		{"r": 0.6, "pos": Vector3(-0.8, 0.04, 0.3), "sy": 0.08},
		{"r": 0.5, "pos": Vector3(0.3, 0.05, -0.7), "sy": 0.1},
		{"r": 0.4, "pos": Vector3(-0.5, 0.04, -0.5), "sy": 0.08},
	]
	for i in range(patch_data.size()):
		var pd: Dictionary = patch_data[i]
		var disc: CSGCylinder3D = CSGCylinder3D.new()
		disc.radius = pd["r"]
		disc.height = pd["sy"]
		disc.sides = 14
		disc.position = pd["pos"]
		disc.rotation.y = i * 1.3
		add_child(disc)
		if i > 0:
			disc.name = "Accent%d" % i
		_mesh_parts.append(disc)

	# Bumpy spore nubs scattered across
	for i in range(5):
		var nub: CSGSphere3D = CSGSphere3D.new()
		nub.radius = 0.1
		nub.radial_segments = 6
		nub.rings = 4
		var a: float = i * TAU / 5.0 + 0.5
		nub.position = Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5)
		add_child(nub)
		nub.name = "Accent%d" % (patch_data.size() + i)
		_mesh_parts.append(nub)

	_add_glow_ring(1.2, 1.4)

# ── Cryo Kelp (lv5) — THREE VERY TALL thin wavy stalks with bulb tips ──
func _build_kelp_stalks() -> void:
	# Three tall kelp stalks — very tall and thin, distinctive vertical shape
	var stalk_data: Array = [
		{"h": 4.0, "pos": Vector3(0.0, 2.0, 0.0), "lean": Vector3(0.12, 0.0, 0.06)},
		{"h": 3.2, "pos": Vector3(0.45, 1.6, 0.25), "lean": Vector3(-0.18, 0.0, 0.14)},
		{"h": 2.6, "pos": Vector3(-0.4, 1.3, 0.2), "lean": Vector3(0.1, 0.0, -0.12)},
	]
	for i in range(stalk_data.size()):
		var sd: Dictionary = stalk_data[i]
		# Very thin cylindrical stalk
		var stalk: CSGCylinder3D = CSGCylinder3D.new()
		stalk.radius = 0.08
		stalk.height = sd["h"]
		stalk.sides = 8
		stalk.position = sd["pos"]
		stalk.rotation = sd["lean"]
		add_child(stalk)
		_mesh_parts.append(stalk)

		# Large bulbous tip at top
		var bulb: CSGSphere3D = CSGSphere3D.new()
		bulb.radius = 0.3
		bulb.radial_segments = 8
		bulb.rings = 6
		bulb.position = sd["pos"] + Vector3(sin(sd["lean"].x) * sd["h"] * 0.5, sd["h"] * 0.5, 0.0)
		add_child(bulb)
		bulb.name = "Accent%d" % (i + 1)
		_mesh_parts.append(bulb)

	# Flat base rosette
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.6
	base.height = 0.15
	base.sides = 10
	base.position.y = 0.08
	add_child(base)
	_mesh_parts.append(base)

	_add_glow_ring(0.7, 0.9)

# ── Nebula Fruit (lv10) — SHORT thick stump with BIG dangling fruit ──
func _build_nebula_fruit() -> void:
	# Short thick stalk
	var stalk: CSGCylinder3D = CSGCylinder3D.new()
	stalk.radius = 0.25
	stalk.height = 1.0
	stalk.sides = 8
	stalk.position.y = 0.5
	add_child(stalk)
	_mesh_parts.append(stalk)

	# Three BIG hanging fruits — oversized spheres at different heights
	var fruit_data: Array = [
		{"r": 0.55, "pos": Vector3(0.5, 0.7, 0.3)},
		{"r": 0.65, "pos": Vector3(-0.4, 0.85, 0.0)},
		{"r": 0.45, "pos": Vector3(0.15, 0.55, -0.45)},
	]
	for i in range(fruit_data.size()):
		var fd: Dictionary = fruit_data[i]
		var fruit: CSGSphere3D = CSGSphere3D.new()
		fruit.radius = fd["r"]
		fruit.radial_segments = 10
		fruit.rings = 8
		fruit.position = fd["pos"]
		fruit.scale = Vector3(1.0, 1.2, 1.0)
		add_child(fruit)
		fruit.name = "Accent%d" % (i + 1)
		_mesh_parts.append(fruit)

		# Short stem attaching fruit
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = 0.05
		stem.height = 0.2
		stem.sides = 4
		stem.position = fd["pos"] + Vector3(0.0, fd["r"] * 0.7, 0.0)
		add_child(stem)
		_mesh_parts.append(stem)

	# Wide leaf base
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.7
	base.height = 0.15
	base.sides = 8
	base.position.y = 0.08
	add_child(base)
	_mesh_parts.append(base)

	_add_glow_ring(0.8, 1.0)

# ── Solar Grain (lv15) — TALL thin wheat stalks with seed heads fanning out ──
func _build_grain_cluster() -> void:
	# Seven grain stalks fanning outward like wheat — very tall and thin
	for i in range(7):
		var angle: float = i * TAU / 7.0 + 0.3
		var lean: float = 0.2 + fmod(i * 0.13, 0.1)
		var h: float = 2.5 + i * 0.25

		# Very thin stalk
		var stalk: CSGCylinder3D = CSGCylinder3D.new()
		stalk.radius = 0.04
		stalk.height = h
		stalk.sides = 6
		stalk.position = Vector3(cos(angle) * 0.2, h * 0.5, sin(angle) * 0.2)
		stalk.rotation.x = sin(angle) * lean
		stalk.rotation.z = -cos(angle) * lean
		add_child(stalk)
		_mesh_parts.append(stalk)

		# Seed head — elongated capsule at tip
		var head: CSGCylinder3D = CSGCylinder3D.new()
		head.radius = 0.12
		head.height = 0.4
		head.sides = 6
		var tip_y: float = h + 0.15
		head.position = Vector3(cos(angle) * 0.2 + sin(angle) * lean * h * 0.3, tip_y, sin(angle) * 0.2 - cos(angle) * lean * h * 0.1)
		head.rotation = stalk.rotation
		add_child(head)
		head.name = "Accent%d" % (i + 1)
		_mesh_parts.append(head)

	# Root clump at base
	var root: CSGSphere3D = CSGSphere3D.new()
	root.radius = 0.4
	root.radial_segments = 6
	root.rings = 4
	root.position = Vector3(0.0, 0.15, 0.0)
	root.scale = Vector3(1.2, 0.4, 1.2)
	add_child(root)
	_mesh_parts.append(root)

	_add_glow_ring(0.6, 0.8)

# ── Chitin Shard (lv20) — ANGULAR overlapping armor plates with spikes ──
func _build_chitin_shard() -> void:
	# Three large overlapping armored plates at dramatic angles
	var plates: Array = [
		{"size": Vector3(1.4, 1.8, 0.12), "pos": Vector3(0.0, 0.9, 0.0), "rot": Vector3(0.35, 0.0, 0.0)},
		{"size": Vector3(1.2, 1.5, 0.12), "pos": Vector3(0.5, 0.8, 0.4), "rot": Vector3(0.4, 0.6, 0.1)},
		{"size": Vector3(1.0, 1.3, 0.12), "pos": Vector3(-0.4, 0.7, 0.2), "rot": Vector3(0.35, -0.5, -0.1)},
	]
	for i in range(plates.size()):
		var p: Dictionary = plates[i]
		var plate: CSGBox3D = CSGBox3D.new()
		plate.size = p["size"]
		plate.position = p["pos"]
		plate.rotation = p["rot"]
		add_child(plate)
		if i > 0:
			plate.name = "Accent%d" % i
		_mesh_parts.append(plate)

	# Tall sharp spike cones jutting upward from plates
	for i in range(5):
		var spike: CSGCylinder3D = CSGCylinder3D.new()
		spike.radius = 0.08
		spike.height = 0.6
		spike.sides = 4
		spike.cone = true
		var a: float = i * TAU / 5.0 + 0.5
		spike.position = Vector3(cos(a) * 0.5, 1.5 + i * 0.08, sin(a) * 0.5)
		spike.rotation.z = cos(a) * 0.3
		spike.rotation.x = sin(a) * 0.3
		add_child(spike)
		spike.name = "Accent%d" % (i + 3)
		_mesh_parts.append(spike)

	_add_glow_ring(0.8, 1.0)

# ── Alien Steak (lv25) — LOW wide fleshy mass with visible veins, very organic ──
func _build_alien_steak() -> void:
	# Main fleshy mass — big overlapping flattened spheres, very LOW and WIDE
	var masses: Array = [
		{"r": 0.8, "pos": Vector3(0.0, 0.4, 0.0), "scale": Vector3(1.5, 0.5, 1.3)},
		{"r": 0.6, "pos": Vector3(0.6, 0.35, 0.4), "scale": Vector3(1.3, 0.6, 1.2)},
		{"r": 0.55, "pos": Vector3(-0.5, 0.3, -0.3), "scale": Vector3(1.4, 0.45, 1.1)},
	]
	for i in range(masses.size()):
		var m: Dictionary = masses[i]
		var mass: CSGSphere3D = CSGSphere3D.new()
		mass.radius = m["r"]
		mass.radial_segments = 10
		mass.rings = 8
		mass.position = m["pos"]
		mass.scale = m["scale"]
		add_child(mass)
		if i > 0:
			mass.name = "Accent%d" % i
		_mesh_parts.append(mass)

	# Thick vein-like tubes crawling across surface
	for i in range(6):
		var vein: CSGCylinder3D = CSGCylinder3D.new()
		vein.radius = 0.05
		vein.height = 1.0
		vein.sides = 6
		var a: float = i * TAU / 6.0
		vein.position = Vector3(cos(a) * 0.5, 0.35 + i * 0.03, sin(a) * 0.5)
		vein.rotation.x = sin(a) * 0.7
		vein.rotation.z = -cos(a) * 0.7
		add_child(vein)
		vein.name = "Accent%d" % (i + 3)
		_mesh_parts.append(vein)

	# Pulsing surface bumps
	for i in range(5):
		var bump: CSGSphere3D = CSGSphere3D.new()
		bump.radius = 0.12
		bump.radial_segments = 6
		bump.rings = 4
		var na: float = i * TAU / 5.0 + 0.7
		bump.position = Vector3(cos(na) * 0.6, 0.5, sin(na) * 0.6)
		add_child(bump)
		_mesh_parts.append(bump)

	_add_glow_ring(1.1, 1.3)

# ── Spore Cap (lv30) — BIG MUSHROOM cluster, very tall with wide caps ──
func _build_mushroom_cluster() -> void:
	# LARGE central mushroom — very tall stem with huge flat cap
	var stem1: CSGCylinder3D = CSGCylinder3D.new()
	stem1.radius = 0.25
	stem1.height = 2.5
	stem1.sides = 8
	stem1.position = Vector3(0.0, 1.25, 0.0)
	add_child(stem1)
	_mesh_parts.append(stem1)

	var cap1: CSGSphere3D = CSGSphere3D.new()
	cap1.radius = 1.2
	cap1.radial_segments = 12
	cap1.rings = 6
	cap1.position = Vector3(0.0, 2.7, 0.0)
	cap1.scale = Vector3(1.0, 0.35, 1.0)
	add_child(cap1)
	cap1.name = "Accent1"
	_mesh_parts.append(cap1)

	# Medium side mushroom — shorter, leaning
	var stem2: CSGCylinder3D = CSGCylinder3D.new()
	stem2.radius = 0.15
	stem2.height = 1.5
	stem2.sides = 8
	stem2.position = Vector3(0.8, 0.75, 0.5)
	stem2.rotation.z = -0.25
	add_child(stem2)
	_mesh_parts.append(stem2)

	var cap2: CSGSphere3D = CSGSphere3D.new()
	cap2.radius = 0.7
	cap2.radial_segments = 10
	cap2.rings = 5
	cap2.position = Vector3(0.9, 1.7, 0.5)
	cap2.scale = Vector3(1.0, 0.35, 1.0)
	add_child(cap2)
	cap2.name = "Accent2"
	_mesh_parts.append(cap2)

	# Small mushroom
	var stem3: CSGCylinder3D = CSGCylinder3D.new()
	stem3.radius = 0.1
	stem3.height = 0.9
	stem3.sides = 6
	stem3.position = Vector3(-0.6, 0.45, 0.35)
	stem3.rotation.z = 0.2
	add_child(stem3)
	_mesh_parts.append(stem3)

	var cap3: CSGSphere3D = CSGSphere3D.new()
	cap3.radius = 0.4
	cap3.radial_segments = 8
	cap3.rings = 5
	cap3.position = Vector3(-0.65, 1.05, 0.35)
	cap3.scale = Vector3(1.0, 0.35, 1.0)
	add_child(cap3)
	cap3.name = "Accent3"
	_mesh_parts.append(cap3)

	_add_glow_ring(1.0, 1.2)

# ── Plasma Pepper (lv35) — ARCHING vine with hanging pods underneath ──
func _build_vine_pods() -> void:
	# Thick vine arch made of stacked cylinders — tall arc
	var vine_segments: int = 8
	for i in range(vine_segments):
		var t: float = float(i) / (vine_segments - 1)
		var seg: CSGCylinder3D = CSGCylinder3D.new()
		seg.radius = 0.12 - t * 0.04
		seg.height = 0.5
		seg.sides = 6
		# Tall arc path
		seg.position = Vector3(
			t * 1.2 - 0.6,
			0.3 + sin(t * PI) * 2.5,
			t * 0.4 - 0.2
		)
		seg.rotation.z = -t * 0.8 + 0.4
		seg.rotation.x = t * 0.3
		add_child(seg)
		_mesh_parts.append(seg)

	# Four hanging pepper pods (elongated spheres dangling from arch)
	var pod_positions: Array = [
		Vector3(-0.3, 1.8, 0.0),
		Vector3(0.0, 2.5, 0.1),
		Vector3(0.3, 2.2, -0.1),
		Vector3(0.5, 1.5, 0.05),
	]
	for i in range(pod_positions.size()):
		var pod: CSGSphere3D = CSGSphere3D.new()
		pod.radius = 0.25
		pod.radial_segments = 8
		pod.rings = 6
		pod.position = pod_positions[i]
		pod.scale = Vector3(0.6, 1.5, 0.6)  # Very elongated pepper shape
		add_child(pod)
		pod.name = "Accent%d" % (i + 1)
		_mesh_parts.append(pod)

		# Short stem connecting pod to vine
		var stem: CSGCylinder3D = CSGCylinder3D.new()
		stem.radius = 0.03
		stem.height = 0.3
		stem.sides = 4
		stem.position = pod_positions[i] + Vector3(0.0, 0.3, 0.0)
		add_child(stem)
		_mesh_parts.append(stem)

	_add_glow_ring(0.8, 1.0)

# ── Void Moss (lv40) — SPRAWLING ground cover with creeping tendrils reaching UP ──
func _build_void_moss() -> void:
	# Very wide spreading flat patches — larger footprint than lichen
	var patches: Array = [
		{"r": 0.9, "h": 0.15, "pos": Vector3(0.0, 0.08, 0.0)},
		{"r": 0.7, "h": 0.12, "pos": Vector3(0.8, 0.06, 0.5)},
		{"r": 0.6, "h": 0.1, "pos": Vector3(-0.7, 0.05, -0.4)},
		{"r": 0.5, "h": 0.1, "pos": Vector3(0.4, 0.05, -0.6)},
	]
	for i in range(patches.size()):
		var p: Dictionary = patches[i]
		var patch: CSGCylinder3D = CSGCylinder3D.new()
		patch.radius = p["r"]
		patch.height = p["h"]
		patch.sides = 16
		patch.position = p["pos"]
		patch.rotation.y = i * 0.8
		add_child(patch)
		if i > 0:
			patch.name = "Accent%d" % i
		_mesh_parts.append(patch)

	# TALL spindly tendrils reaching UP from the moss — key visual differentiator from lichen
	for i in range(6):
		var tendril: CSGCylinder3D = CSGCylinder3D.new()
		tendril.radius = 0.04
		tendril.height = 1.2 + fmod(i * 0.31, 0.5)
		tendril.sides = 4
		var ta: float = i * TAU / 6.0 + 0.3
		var tdist: float = 0.4 + fmod(i * 0.17, 0.3)
		tendril.position = Vector3(cos(ta) * tdist, tendril.height * 0.5, sin(ta) * tdist)
		tendril.rotation.x = sin(ta) * 0.3
		tendril.rotation.z = -cos(ta) * 0.3
		add_child(tendril)
		tendril.name = "Accent%d" % (i + 4)
		_mesh_parts.append(tendril)

		# Tiny glowing tip sphere
		var tip: CSGSphere3D = CSGSphere3D.new()
		tip.radius = 0.06
		tip.radial_segments = 4
		tip.rings = 3
		tip.position = Vector3(cos(ta) * tdist, tendril.height + 0.05, sin(ta) * tdist)
		add_child(tip)
		tip.name = "Accent%d" % (i + 10)
		_mesh_parts.append(tip)

	_add_glow_ring(1.0, 1.2)

# ── Crystal Honey (lv45) — BIG alien flower with wide petals ──
func _build_flower_bloom() -> void:
	# Thick central stem — tall
	var stem: CSGCylinder3D = CSGCylinder3D.new()
	stem.radius = 0.2
	stem.height = 2.2
	stem.sides = 8
	stem.position.y = 1.1
	add_child(stem)
	_mesh_parts.append(stem)

	# Large central pistil sphere
	var pistil: CSGSphere3D = CSGSphere3D.new()
	pistil.radius = 0.45
	pistil.radial_segments = 10
	pistil.rings = 8
	pistil.position.y = 2.5
	add_child(pistil)
	pistil.name = "Accent1"
	_mesh_parts.append(pistil)

	# Six LARGE petals radiating outward — very dramatic flower shape
	for i in range(6):
		var petal: CSGSphere3D = CSGSphere3D.new()
		petal.radius = 0.55
		petal.radial_segments = 8
		petal.rings = 6
		var a: float = i * TAU / 6.0
		petal.position = Vector3(cos(a) * 0.6, 2.3, sin(a) * 0.6)
		petal.scale = Vector3(1.0, 0.2, 0.7)  # Very flat petal shape
		petal.rotation.y = -a
		petal.rotation.x = 0.6  # Tilt outward
		add_child(petal)
		petal.name = "Accent%d" % (i + 2)
		_mesh_parts.append(petal)

	# Two large drooping leaves near base
	for i in range(2):
		var leaf: CSGSphere3D = CSGSphere3D.new()
		leaf.radius = 0.5
		leaf.radial_segments = 6
		leaf.rings = 4
		var la: float = i * PI + 0.5
		leaf.position = Vector3(cos(la) * 0.5, 0.5, sin(la) * 0.5)
		leaf.scale = Vector3(0.9, 0.1, 1.6)
		leaf.rotation.y = -la
		add_child(leaf)
		_mesh_parts.append(leaf)

	_add_glow_ring(0.8, 1.0)

# ── Neural Bloom (lv50) — BRAIN on a stalk with radiating neural tendrils ──
func _build_neural_bloom() -> void:
	# Thick neural stem
	var stem: CSGCylinder3D = CSGCylinder3D.new()
	stem.radius = 0.22
	stem.height = 2.0
	stem.sides = 8
	stem.position.y = 1.0
	add_child(stem)
	_mesh_parts.append(stem)

	# Brain-like core — large overlapping spheres creating wrinkled look
	var core_offsets: Array = [
		{"r": 0.55, "pos": Vector3(0.0, 2.3, 0.0), "scale": Vector3(1.0, 0.85, 1.0)},
		{"r": 0.4, "pos": Vector3(0.25, 2.4, 0.15), "scale": Vector3(1.1, 0.8, 0.9)},
		{"r": 0.35, "pos": Vector3(-0.2, 2.5, -0.12), "scale": Vector3(0.9, 0.9, 1.1)},
		{"r": 0.3, "pos": Vector3(0.08, 2.2, -0.2), "scale": Vector3(1.05, 0.95, 0.95)},
		{"r": 0.28, "pos": Vector3(-0.1, 2.6, 0.1), "scale": Vector3(0.95, 0.85, 1.05)},
	]
	for i in range(core_offsets.size()):
		var co: Dictionary = core_offsets[i]
		var lobe: CSGSphere3D = CSGSphere3D.new()
		lobe.radius = co["r"]
		lobe.radial_segments = 10
		lobe.rings = 8
		lobe.position = co["pos"]
		lobe.scale = co["scale"]
		add_child(lobe)
		if i > 0:
			lobe.name = "Accent%d" % i
		_mesh_parts.append(lobe)

	# 8 neural tendrils radiating outward with bulb tips
	for i in range(8):
		var tendril: CSGCylinder3D = CSGCylinder3D.new()
		tendril.radius = 0.05
		tendril.height = 1.0
		tendril.sides = 5
		var a: float = i * TAU / 8.0
		tendril.position = Vector3(cos(a) * 0.5, 2.3, sin(a) * 0.5)
		tendril.rotation.x = sin(a) * 0.7
		tendril.rotation.z = -cos(a) * 0.7
		add_child(tendril)
		tendril.name = "Accent%d" % (i + 5)
		_mesh_parts.append(tendril)

		# Pulse node at tip
		var tip_node: CSGSphere3D = CSGSphere3D.new()
		tip_node.radius = 0.1
		tip_node.radial_segments = 6
		tip_node.rings = 4
		tip_node.position = Vector3(
			cos(a) * 0.5 + cos(a) * 0.7,
			2.3 + sin(a) * 0.4,
			sin(a) * 0.5 + sin(a) * 0.7
		)
		add_child(tip_node)
		tip_node.name = "Accent%d" % (i + 13)
		_mesh_parts.append(tip_node)

	_add_glow_ring(0.8, 1.0)

# ── Void Truffle (lv55) — LUMPY bulbous mass with thick root tendrils ──
func _build_truffle_tendrils() -> void:
	# Large lumpy main body — overlapping warped spheres, ground-hugging
	var body1: CSGSphere3D = CSGSphere3D.new()
	body1.radius = 0.9
	body1.radial_segments = 10
	body1.rings = 8
	body1.position = Vector3(0.0, 0.7, 0.0)
	body1.scale = Vector3(1.2, 0.8, 1.1)
	add_child(body1)
	_mesh_parts.append(body1)

	var body2: CSGSphere3D = CSGSphere3D.new()
	body2.radius = 0.6
	body2.radial_segments = 8
	body2.rings = 6
	body2.position = Vector3(0.5, 0.85, 0.25)
	body2.scale = Vector3(1.1, 0.9, 1.0)
	add_child(body2)
	body2.name = "Accent1"
	_mesh_parts.append(body2)

	var body3: CSGSphere3D = CSGSphere3D.new()
	body3.radius = 0.5
	body3.radial_segments = 8
	body3.rings = 6
	body3.position = Vector3(-0.4, 0.95, -0.2)
	body3.scale = Vector3(1.0, 0.85, 1.15)
	add_child(body3)
	body3.name = "Accent2"
	_mesh_parts.append(body3)

	# Thick tendril roots spreading outward on the ground
	for i in range(7):
		var tendril: CSGCylinder3D = CSGCylinder3D.new()
		tendril.radius = 0.08
		tendril.height = 1.2 + fmod(i * 0.19, 0.4)
		tendril.sides = 5
		var a: float = i * TAU / 7.0 + 0.2
		tendril.position = Vector3(cos(a) * 0.7, 0.15, sin(a) * 0.7)
		tendril.rotation.x = sin(a) * 0.75
		tendril.rotation.z = -cos(a) * 0.75
		add_child(tendril)
		tendril.name = "Accent%d" % (i + 3)
		_mesh_parts.append(tendril)

	# Top crest bumps
	for i in range(4):
		var bump: CSGSphere3D = CSGSphere3D.new()
		bump.radius = 0.15
		bump.radial_segments = 6
		bump.rings = 4
		var ba: float = i * TAU / 4.0
		bump.position = Vector3(cos(ba) * 0.3, 1.3, sin(ba) * 0.3)
		add_child(bump)
		_mesh_parts.append(bump)

	_add_glow_ring(1.0, 1.2)

# ── Quantum Vine (lv60) — TALL double-helix spiraling vine structure ──
func _build_quantum_vine() -> void:
	# Two intertwined helical vines (DNA double helix) — TALL
	var helix_segments: int = 10
	for h in range(2):
		for i in range(helix_segments):
			var t: float = float(i) / (helix_segments - 1)
			var seg: CSGCylinder3D = CSGCylinder3D.new()
			seg.radius = 0.08
			seg.height = 0.35
			seg.sides = 6
			var angle: float = t * TAU * 2.0 + h * PI
			var rad: float = 0.45
			seg.position = Vector3(
				cos(angle) * rad,
				0.3 + t * 3.5,
				sin(angle) * rad
			)
			seg.rotation = Vector3(
				sin(angle) * 0.3,
				angle + PI / 2.0,
				cos(angle) * 0.3
			)
			add_child(seg)
			if h == 1:
				seg.name = "Accent%d" % (i + 1)
			_mesh_parts.append(seg)

	# Phase nodes at crossing points — larger and more prominent
	for i in range(5):
		var t: float = float(i) / 4.0
		var phase_node: CSGSphere3D = CSGSphere3D.new()
		phase_node.radius = 0.2
		phase_node.radial_segments = 8
		phase_node.rings = 6
		phase_node.position.y = 0.5 + t * 3.2
		add_child(phase_node)
		phase_node.name = "Accent%d" % (helix_segments + i + 1)
		_mesh_parts.append(phase_node)

	# Root base — wider
	var base: CSGCylinder3D = CSGCylinder3D.new()
	base.radius = 0.5
	base.height = 0.25
	base.sides = 8
	base.position.y = 0.12
	add_child(base)
	_mesh_parts.append(base)

	_add_glow_ring(0.6, 0.8)

# ── Gravity Residue (lv65) — MASSIVE alien tree with spreading canopy ──
func _build_alien_tree() -> void:
	# Thick organic trunk — very tall
	var trunk: CSGCylinder3D = CSGCylinder3D.new()
	trunk.radius = 0.45
	trunk.height = 3.5
	trunk.sides = 8
	trunk.position.y = 1.75
	add_child(trunk)
	_mesh_parts.append(trunk)

	# Trunk base flare
	var flare: CSGCylinder3D = CSGCylinder3D.new()
	flare.radius = 0.7
	flare.height = 0.6
	flare.sides = 8
	flare.cone = true
	flare.position.y = 0.3
	flare.rotation.x = PI
	add_child(flare)
	_mesh_parts.append(flare)

	# Massive canopy — very wide overlapping spheres
	var canopy_data: Array = [
		{"r": 1.3, "pos": Vector3(0.0, 3.8, 0.0)},
		{"r": 0.9, "pos": Vector3(0.8, 4.1, 0.5)},
		{"r": 0.85, "pos": Vector3(-0.7, 4.0, -0.4)},
		{"r": 0.7, "pos": Vector3(0.2, 4.3, -0.6)},
		{"r": 0.6, "pos": Vector3(-0.3, 3.7, 0.7)},
	]
	for i in range(canopy_data.size()):
		var cd: Dictionary = canopy_data[i]
		var canopy: CSGSphere3D = CSGSphere3D.new()
		canopy.radius = cd["r"]
		canopy.radial_segments = 10
		canopy.rings = 6
		canopy.position = cd["pos"]
		canopy.scale = Vector3(1.0, 0.35, 1.0)
		add_child(canopy)
		canopy.name = "Accent%d" % (i + 1)
		_mesh_parts.append(canopy)

	# Hanging fruit/spore pods under canopy
	for i in range(4):
		var fruit: CSGSphere3D = CSGSphere3D.new()
		fruit.radius = 0.15
		fruit.radial_segments = 6
		fruit.rings = 4
		var fa: float = i * TAU / 4.0 + 0.8
		fruit.position = Vector3(cos(fa) * 0.7, 3.2, sin(fa) * 0.7)
		add_child(fruit)
		fruit.name = "Accent%d" % (canopy_data.size() + i + 1)
		_mesh_parts.append(fruit)

	_add_glow_ring(1.0, 1.2)

# ══════════════════════════════════════════════════════════════

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
	# Body material — NO emission so lighting reveals shape/silhouette
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = _node_color
	body_mat.metallic = 0.3 + skill_level * 0.005
	body_mat.roughness = 0.5 - skill_level * 0.004
	# No emission on body — let scene lighting define edges and shadows

	# Accent material — subtle glow to highlight detail parts without washing out shape
	var accent_mat: StandardMaterial3D = StandardMaterial3D.new()
	accent_mat.albedo_color = _node_color.lightened(0.15)
	accent_mat.metallic = 0.6 + skill_level * 0.004
	accent_mat.roughness = 0.2
	accent_mat.emission_enabled = true
	accent_mat.emission = _node_color.lightened(0.15)
	accent_mat.emission_energy_multiplier = 0.5 + skill_level * 0.005  # 0.505 to 0.95

	# Glow ring material — ground beacon, moderately bright
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = _node_color.lightened(0.2)
	ring_mat.emission_enabled = true
	ring_mat.emission = _node_color.lightened(0.2)
	ring_mat.emission_energy_multiplier = 1.8

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

	# Give XP (with prestige and pet bonuses)
	var final_xp: int = xp_reward

	# Prestige XP bonus
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys and prestige_sys.has_method("get_prestige_bonuses"):
		var bonuses: Dictionary = prestige_sys.get_prestige_bonuses()
		final_xp = int(float(final_xp) * float(bonuses.get("xp_mult", 1.0)))

	# Pet XP bonus
	var pet_sys: Node = get_tree().get_first_node_in_group("pet_system")
	if pet_sys and pet_sys.has_method("get_pet_buff"):
		var buff: Dictionary = pet_sys.get_pet_buff()
		if str(buff.get("type", "")) == "xp" or str(buff.get("type", "")) == "all":
			final_xp = int(float(final_xp) * (1.0 + float(buff.get("value", 0.0))))

	if GameState.skills.has(skill_id):
		GameState.skills[skill_id]["xp"] = int(GameState.skills[skill_id]["xp"]) + final_xp
		EventBus.player_xp_gained.emit(skill_id, final_xp)

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
	EventBus.float_text_requested.emit("+%d %s XP" % [final_xp, skill_name], global_position + Vector3(0, 2.5, 0), Color(0.3, 0.9, 0.3))

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
