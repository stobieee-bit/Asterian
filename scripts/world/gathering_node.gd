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
var _grounded: bool = false
var _mesh_parts: Array[Node3D] = []   # All mesh parts for deplete/respawn animation
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

# ── Helper: create MeshInstance3D, add to self & _mesh_parts ──
func _mi(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	if node_name != "":
		mi.name = node_name
	add_child(mi)
	_mesh_parts.append(mi)
	return mi

# ══════════════════════════════════════════════════════════════
# ASTROMINING MESHES — 10 unique mineral/ore silhouettes
# ══════════════════════════════════════════════════════════════

# ── Stellarite Ore (lv1) — LOW wide boulder pile, very round and squat ──
func _build_rock_mound() -> void:
	# Big main boulder - wide and low (sphere approximating organic blob)
	var _sm1 := SphereMesh.new()
	_sm1.radius = 1.0
	_sm1.height = 2.0
	_sm1.radial_segments = 16
	_sm1.rings = 8
	var b1: MeshInstance3D = _mi("", _sm1)
	b1.position = Vector3(0.0, 0.5, 0.0)
	b1.scale = Vector3(1.3, 0.7, 1.2)

	# Smaller side boulder
	var _sm2 := SphereMesh.new()
	_sm2.radius = 0.6
	_sm2.height = 1.2
	_sm2.radial_segments = 16
	_sm2.rings = 8
	var b2: MeshInstance3D = _mi("Accent1", _sm2)
	b2.position = Vector3(0.8, 0.3, 0.5)
	b2.scale = Vector3(1.1, 0.8, 1.0)

	# Tiny pebble
	var _sm3 := SphereMesh.new()
	_sm3.radius = 0.35
	_sm3.height = 0.7
	_sm3.radial_segments = 16
	_sm3.rings = 8
	var b3: MeshInstance3D = _mi("Accent2", _sm3)
	b3.position = Vector3(-0.7, 0.2, 0.4)

	_add_glow_ring(1.2, 1.4)

# ── Ferrite Ore (lv10) — WIDE flat anvil slab, very boxy and horizontal ──
func _build_flat_crystal() -> void:
	var _bm1 := BoxMesh.new()
	_bm1.size = Vector3(2.2, 0.5, 1.6)
	var base: MeshInstance3D = _mi("", _bm1)
	base.position.y = 0.25

	var _bm2 := BoxMesh.new()
	_bm2.size = Vector3(1.4, 0.5, 1.0)
	var top: MeshInstance3D = _mi("Accent1", _bm2)
	top.position = Vector3(-0.2, 0.75, 0.0)

	var _bm3 := BoxMesh.new()
	_bm3.size = Vector3(0.5, 0.7, 0.4)
	var shard: MeshInstance3D = _mi("Accent2", _bm3)
	shard.position = Vector3(0.3, 1.35, 0.0)
	shard.rotation = Vector3(0.0, 0.4, 0.15)

	_add_glow_ring(1.3, 1.5)

# ── Cobaltium Ore (lv20) — TALL spiky crystal spires pointing UP ──
func _build_crystal_cluster() -> void:
	# Very tall central crystal spire
	var _cm1 := CylinderMesh.new()
	_cm1.bottom_radius = 0.25
	_cm1.top_radius = maxf(0.7 * 0.15, 0.001)
	_cm1.height = 3.5 + 0.7
	_cm1.radial_segments = 6
	var main_spire: MeshInstance3D = _mi("Accent1", _cm1)
	main_spire.position.y = 1.75

	# Five surrounding spires at different heights and angles
	for i in range(5):
		var h: float = 1.5 + i * 0.4
		var _cm2 := CylinderMesh.new()
		_cm2.bottom_radius = 0.18
		_cm2.top_radius = maxf(0.3 * 0.15, 0.001)
		_cm2.height = h + 0.3
		_cm2.radial_segments = 6
		var spike: MeshInstance3D = _mi("Accent%d" % (i + 2), _cm2)
		var a: float = i * TAU / 5.0 + 0.4
		var dist: float = 0.55
		spike.position = Vector3(cos(a) * dist, h * 0.5, sin(a) * dist)
		spike.rotation.x = sin(a) * 0.25
		spike.rotation.z = -cos(a) * 0.25

	# Rocky base platform
	var _cm3 := CylinderMesh.new()
	_cm3.top_radius = 0.8
	_cm3.bottom_radius = 0.8
	_cm3.height = 0.4
	_cm3.radial_segments = 5
	var base: MeshInstance3D = _mi("", _cm3)
	base.position.y = 0.2

	_add_glow_ring(0.9, 1.1)

# ── Duranite Ore (lv30) — STAIRCASE of stacked offset slabs ──
func _build_layered_deposit() -> void:
	var widths: Array[float] = [2.0, 1.7, 1.4, 1.1, 0.8]
	var depths: Array[float] = [1.6, 1.3, 1.0, 0.8, 0.6]
	for i in range(5):
		var slab_name: String = "Accent%d" % i if i > 0 else ""
		var w: float = widths[i]
		var d: float = depths[i]
		var _bm := BoxMesh.new()
		_bm.size = Vector3(w, 0.35, d)
		var slab: MeshInstance3D = _mi(slab_name, _bm)
		slab.position.y = 0.18 + i * 0.38
		slab.position.x = i * 0.15 - 0.3
		slab.rotation.y = i * 0.25

	_add_glow_ring(1.2, 1.4)

# ── Titanex Ore (lv40) — WIDE angular archway gate with keystone ──
func _build_obelisk() -> void:
	var _cm_pillar := CylinderMesh.new()
	_cm_pillar.top_radius = 0.4
	_cm_pillar.bottom_radius = 0.4
	_cm_pillar.height = 3.0
	_cm_pillar.radial_segments = 6
	var pillar_l: MeshInstance3D = _mi("", _cm_pillar)
	pillar_l.position = Vector3(-0.9, 1.5, 0.0)
	var pillar_r: MeshInstance3D = _mi("", _cm_pillar)
	pillar_r.position = Vector3(0.9, 1.5, 0.0)

	var _bm1 := BoxMesh.new()
	_bm1.size = Vector3(2.6, 0.5, 0.7)
	var lintel: MeshInstance3D = _mi("Accent1", _bm1)
	lintel.position.y = 3.25

	var _bm2 := BoxMesh.new()
	_bm2.size = Vector3(0.6, 0.7, 0.6)
	var keystone: MeshInstance3D = _mi("Accent2", _bm2)
	keystone.position.y = 3.85
	keystone.rotation.y = PI / 4.0

	var _bm3 := BoxMesh.new()
	_bm3.size = Vector3(2.4, 0.3, 1.0)
	var base: MeshInstance3D = _mi("", _bm3)
	base.position.y = 0.15

	var _tm_collar := TorusMesh.new()
	_tm_collar.inner_radius = (0.55 - 0.35) / 2.0
	_tm_collar.outer_radius = (0.35 + 0.55) / 2.0
	_tm_collar.rings = 20
	_tm_collar.ring_segments = 16
	for i in range(2):
		var collar: MeshInstance3D = _mi("Accent%d" % (i + 3), _tm_collar)
		collar.position = Vector3(-0.9, 1.0 + i * 1.2, 0.0)
		var collar2: MeshInstance3D = _mi("Accent%d" % (i + 5), _tm_collar)
		collar2.position = Vector3(0.9, 1.0 + i * 1.2, 0.0)

	_add_glow_ring(1.3, 1.5)

# ── Plasmite Ore (lv50) — FLOATING ORB with orbital rings, hovers high ──
func _build_floating_orb() -> void:
	var _sm1 := SphereMesh.new()
	_sm1.radius = 1.0
	_sm1.height = 2.0
	_sm1.radial_segments = 16
	_sm1.rings = 8
	var orb: MeshInstance3D = _mi("", _sm1)
	orb.position.y = 2.5

	var _tm1 := TorusMesh.new()
	_tm1.inner_radius = (1.4 - 1.2) / 2.0
	_tm1.outer_radius = (1.2 + 1.4) / 2.0
	_tm1.rings = 20
	_tm1.ring_segments = 16
	var ring1: MeshInstance3D = _mi("Accent1", _tm1)
	ring1.position.y = 2.5

	var _tm2 := TorusMesh.new()
	_tm2.inner_radius = (1.5 - 1.3) / 2.0
	_tm2.outer_radius = (1.3 + 1.5) / 2.0
	_tm2.rings = 20
	_tm2.ring_segments = 16
	var ring2: MeshInstance3D = _mi("Accent2", _tm2)
	ring2.position.y = 2.5
	ring2.rotation.x = PI / 2.0
	ring2.rotation.y = 0.5

	var _cm1 := CylinderMesh.new()
	_cm1.top_radius = 0.15
	_cm1.bottom_radius = 0.15
	_cm1.height = 1.5
	_cm1.radial_segments = 8
	var pillar: MeshInstance3D = _mi("Accent3", _cm1)
	pillar.position.y = 0.75

	_add_glow_ring(0.8, 1.0)

# ── Quantite Ore (lv60) — HUGE diamond shape standing on vertex ──
func _build_gem_formation() -> void:
	# Use cylinder for diamond/crystal look
	var _cm1 := CylinderMesh.new()
	_cm1.bottom_radius = 0.9
	_cm1.top_radius = maxf(0.5 * 0.15, 0.001)
	_cm1.height = 1.6 + 0.5
	_cm1.radial_segments = 8
	var gem: MeshInstance3D = _mi("", _cm1)
	gem.position.y = 2.0
	gem.rotation.x = PI / 4.0
	gem.rotation.z = PI / 4.0

	var frag_data: Array = [
		{"size": 0.5, "pos": Vector3(1.2, 1.2, 0.6), "rot_y": 0.5},
		{"size": 0.45, "pos": Vector3(-1.0, 2.2, -0.5), "rot_y": 1.2},
		{"size": 0.4, "pos": Vector3(0.4, 3.0, -0.9), "rot_y": 2.5},
		{"size": 0.35, "pos": Vector3(-0.5, 0.8, 0.8), "rot_y": 3.8},
	]
	for i in range(frag_data.size()):
		var fd: Dictionary = frag_data[i]
		var s: float = fd["size"]
		var _cm2 := CylinderMesh.new()
		_cm2.bottom_radius = s * 0.5
		_cm2.top_radius = maxf(s * 0.3 * 0.15, 0.001)
		_cm2.height = s + s * 0.3
		_cm2.radial_segments = 6
		var frag: MeshInstance3D = _mi("Accent%d" % (i + 1), _cm2)
		frag.position = fd["pos"]
		frag.rotation.x = PI / 4.0
		frag.rotation.y = fd["rot_y"]
		frag.rotation.z = PI / 4.0

	_add_glow_ring(1.0, 1.2)

# ── Neutronium Ore (lv70) — STARBURST sphere with 8 radiating arms ──
func _build_star_core() -> void:
	var _sm1 := SphereMesh.new()
	_sm1.radius = 0.9
	_sm1.height = 1.8
	_sm1.radial_segments = 16
	_sm1.rings = 8
	var core: MeshInstance3D = _mi("", _sm1)
	core.position.y = 2.0

	var _bm_arm := BoxMesh.new()
	_bm_arm.size = Vector3(0.2, 2.2, 0.2)
	for i in range(8):
		var arm: MeshInstance3D = _mi("Accent%d" % (i + 1), _bm_arm)
		arm.position.y = 2.0
		arm.rotation.z = i * PI / 4.0
		arm.rotation.x = fmod(i * 0.5, PI)

	var _tm_ring := TorusMesh.new()
	_tm_ring.inner_radius = (1.5 - 1.3) / 2.0
	_tm_ring.outer_radius = (1.3 + 1.5) / 2.0
	_tm_ring.rings = 20
	_tm_ring.ring_segments = 16
	for i in range(2):
		var ring: MeshInstance3D = _mi("Ring%d" % (i + 1), _tm_ring)
		ring.position.y = 2.0
		ring.rotation.x = PI / 2.0 * i
		ring.rotation.y = 0.6 * i

	_add_glow_ring(1.1, 1.3)

# ── Darkmatter Shard (lv80) — HUGE jagged blade jutting at sharp angle ──
func _build_darkmatter_shard() -> void:
	var _cm1 := CylinderMesh.new()
	_cm1.bottom_radius = 0.4
	_cm1.top_radius = maxf(0.8 * 0.15, 0.001)
	_cm1.height = 4.0 + 0.8
	_cm1.radial_segments = 6
	var main_shard: MeshInstance3D = _mi("", _cm1)
	main_shard.position = Vector3(0.0, 1.8, 0.0)
	main_shard.rotation = Vector3(0.0, 0.6, 0.5)

	var _cm2 := CylinderMesh.new()
	_cm2.bottom_radius = 0.25
	_cm2.top_radius = maxf(0.4 * 0.15, 0.001)
	_cm2.height = 2.0 + 0.4
	_cm2.radial_segments = 6
	var f1: MeshInstance3D = _mi("Accent1", _cm2)
	f1.position = Vector3(0.8, 1.0, 0.5)
	f1.rotation = Vector3(0.5, 0.8, 0.3)

	var _cm3 := CylinderMesh.new()
	_cm3.bottom_radius = 0.2
	_cm3.top_radius = maxf(0.3 * 0.15, 0.001)
	_cm3.height = 1.5 + 0.3
	_cm3.radial_segments = 6
	var f2: MeshInstance3D = _mi("Accent2", _cm3)
	f2.position = Vector3(-0.6, 0.8, -0.3)
	f2.rotation = Vector3(-0.4, 1.2, -0.4)

	var _sm_orb := SphereMesh.new()
	_sm_orb.radius = 0.18
	_sm_orb.height = 0.36
	_sm_orb.radial_segments = 16
	_sm_orb.rings = 8
	for i in range(4):
		var orb: MeshInstance3D = _mi("Accent%d" % (i + 3), _sm_orb)
		var a: float = i * TAU / 4.0 + 1.0
		orb.position = Vector3(cos(a) * 1.2, 2.0 + sin(i * 0.8) * 0.6, sin(a) * 1.2)

	_add_glow_ring(1.0, 1.2)

# ── Voidsteel Ore (lv90) — MASSIVE rotated cube with dimensional rift rings ──
func _build_voidsteel_ore() -> void:
	var _bm1 := BoxMesh.new()
	_bm1.size = Vector3(1.5, 1.5, 1.5)
	var core: MeshInstance3D = _mi("", _bm1)
	core.position.y = 2.0
	core.rotation = Vector3(0.4, 0.6, 0.3)

	var rifts: Array = [
		{"size": Vector3(0.1, 3.0, 0.8), "pos": Vector3(1.0, 2.0, 0.0), "rot": Vector3(0.0, 0.0, 0.3)},
		{"size": Vector3(0.8, 2.8, 0.1), "pos": Vector3(0.0, 2.0, 1.0), "rot": Vector3(0.3, 0.0, 0.0)},
		{"size": Vector3(0.1, 2.5, 0.7), "pos": Vector3(-0.9, 2.0, -0.3), "rot": Vector3(0.0, 0.5, -0.2)},
	]
	for i in range(rifts.size()):
		var r: Dictionary = rifts[i]
		var sz: Vector3 = r["size"]
		var _bm2 := BoxMesh.new()
		_bm2.size = sz
		var rift: MeshInstance3D = _mi("Accent%d" % (i + 1), _bm2)
		rift.position = r["pos"]
		rift.rotation = r["rot"]

	for i in range(4):
		var ir: float = 1.1 + i * 0.15
		var or_: float = 1.3 + i * 0.15
		var _tm := TorusMesh.new()
		_tm.inner_radius = (or_ - ir) / 2.0
		_tm.outer_radius = (ir + or_) / 2.0
		_tm.rings = 20
		_tm.ring_segments = 16
		var ring: MeshInstance3D = _mi("Accent%d" % (i + 4), _tm)
		ring.position.y = 2.0
		ring.rotation.x = i * 0.5
		ring.rotation.y = i * 0.7
		ring.rotation.z = i * 0.3

	_add_glow_ring(1.2, 1.4)

# ══════════════════════════════════════════════════════════════
# XENOBOTANY MESHES — 14 unique organic/plant silhouettes
# ══════════════════════════════════════════════════════════════

# ── Space Lichen (lv1) — VERY FLAT ground-level spreading discs ──
func _build_lichen_patch() -> void:
	var patch_data: Array = [
		{"r": 1.0, "pos": Vector3(0.0, 0.06, 0.0), "sy": 0.12},
		{"r": 0.7, "pos": Vector3(0.9, 0.05, 0.4), "sy": 0.1},
		{"r": 0.6, "pos": Vector3(-0.8, 0.04, 0.3), "sy": 0.08},
		{"r": 0.5, "pos": Vector3(0.3, 0.05, -0.7), "sy": 0.1},
		{"r": 0.4, "pos": Vector3(-0.5, 0.04, -0.5), "sy": 0.08},
	]
	for i in range(patch_data.size()):
		var pd: Dictionary = patch_data[i]
		var r: float = pd["r"]
		var h: float = pd["sy"]
		var disc_name: String = "Accent%d" % i if i > 0 else ""
		var _cm := CylinderMesh.new()
		_cm.top_radius = r
		_cm.bottom_radius = r
		_cm.height = h
		_cm.radial_segments = 14
		var disc: MeshInstance3D = _mi(disc_name, _cm)
		disc.position = pd["pos"]
		disc.rotation.y = i * 1.3

	var _sm_nub := SphereMesh.new()
	_sm_nub.radius = 0.1
	_sm_nub.height = 0.2
	_sm_nub.radial_segments = 16
	_sm_nub.rings = 8
	for i in range(5):
		var nub: MeshInstance3D = _mi("Accent%d" % (patch_data.size() + i), _sm_nub)
		var a: float = i * TAU / 5.0 + 0.5
		nub.position = Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5)

	_add_glow_ring(1.2, 1.4)

# ── Cryo Kelp (lv5) — THREE VERY TALL thin wavy stalks with bulb tips ──
func _build_kelp_stalks() -> void:
	var stalk_data: Array = [
		{"h": 4.0, "pos": Vector3(0.0, 2.0, 0.0), "lean": Vector3(0.12, 0.0, 0.06)},
		{"h": 3.2, "pos": Vector3(0.45, 1.6, 0.25), "lean": Vector3(-0.18, 0.0, 0.14)},
		{"h": 2.6, "pos": Vector3(-0.4, 1.3, 0.2), "lean": Vector3(0.1, 0.0, -0.12)},
	]
	var _sm_bulb := SphereMesh.new()
	_sm_bulb.radius = 0.3
	_sm_bulb.height = 0.6
	_sm_bulb.radial_segments = 16
	_sm_bulb.rings = 8
	for i in range(stalk_data.size()):
		var sd: Dictionary = stalk_data[i]
		var h: float = sd["h"]
		var _cm := CylinderMesh.new()
		_cm.top_radius = 0.08
		_cm.bottom_radius = 0.08
		_cm.height = h
		_cm.radial_segments = 8
		var stalk: MeshInstance3D = _mi("", _cm)
		stalk.position = sd["pos"]
		stalk.rotation = sd["lean"]

		var bulb: MeshInstance3D = _mi("Accent%d" % (i + 1), _sm_bulb)
		bulb.position = sd["pos"] + Vector3(sin(sd["lean"].x) * h * 0.5, h * 0.5, 0.0)

	var _cm_base := CylinderMesh.new()
	_cm_base.top_radius = 0.6
	_cm_base.bottom_radius = 0.6
	_cm_base.height = 0.15
	_cm_base.radial_segments = 10
	var base: MeshInstance3D = _mi("", _cm_base)
	base.position.y = 0.08

	_add_glow_ring(0.7, 0.9)

# ── Nebula Fruit (lv10) — SHORT thick stump with BIG dangling fruit ──
func _build_nebula_fruit() -> void:
	var _cm_stalk := CylinderMesh.new()
	_cm_stalk.top_radius = 0.25
	_cm_stalk.bottom_radius = 0.25
	_cm_stalk.height = 1.0
	_cm_stalk.radial_segments = 8
	var stalk: MeshInstance3D = _mi("", _cm_stalk)
	stalk.position.y = 0.5

	var fruit_data: Array = [
		{"r": 0.55, "pos": Vector3(0.5, 0.7, 0.3)},
		{"r": 0.65, "pos": Vector3(-0.4, 0.85, 0.0)},
		{"r": 0.45, "pos": Vector3(0.15, 0.55, -0.45)},
	]
	var _cm_stem := CylinderMesh.new()
	_cm_stem.top_radius = 0.05
	_cm_stem.bottom_radius = 0.05
	_cm_stem.height = 0.2
	_cm_stem.radial_segments = 4
	for i in range(fruit_data.size()):
		var fd: Dictionary = fruit_data[i]
		var r: float = fd["r"]
		var _sm := SphereMesh.new()
		_sm.radius = r
		_sm.height = r * 2.0
		_sm.radial_segments = 16
		_sm.rings = 8
		var fruit: MeshInstance3D = _mi("Accent%d" % (i + 1), _sm)
		fruit.position = fd["pos"]
		fruit.scale = Vector3(1.0, 1.2, 1.0)

		var stem: MeshInstance3D = _mi("", _cm_stem)
		stem.position = fd["pos"] + Vector3(0.0, r * 0.7, 0.0)

	var _cm_base := CylinderMesh.new()
	_cm_base.top_radius = 0.7
	_cm_base.bottom_radius = 0.7
	_cm_base.height = 0.15
	_cm_base.radial_segments = 8
	var base: MeshInstance3D = _mi("", _cm_base)
	base.position.y = 0.08

	_add_glow_ring(0.8, 1.0)

# ── Solar Grain (lv15) — TALL thin wheat stalks with seed heads fanning out ──
func _build_grain_cluster() -> void:
	var _cm_head := CylinderMesh.new()
	_cm_head.top_radius = 0.12
	_cm_head.bottom_radius = 0.12
	_cm_head.height = 0.4
	_cm_head.radial_segments = 6
	for i in range(7):
		var angle: float = i * TAU / 7.0 + 0.3
		var lean: float = 0.2 + fmod(i * 0.13, 0.1)
		var h: float = 2.5 + i * 0.25

		var _cm := CylinderMesh.new()
		_cm.top_radius = 0.04
		_cm.bottom_radius = 0.04
		_cm.height = h
		_cm.radial_segments = 6
		var stalk: MeshInstance3D = _mi("", _cm)
		stalk.position = Vector3(cos(angle) * 0.2, h * 0.5, sin(angle) * 0.2)
		stalk.rotation.x = sin(angle) * lean
		stalk.rotation.z = -cos(angle) * lean

		var tip_y: float = h + 0.15
		var head: MeshInstance3D = _mi("Accent%d" % (i + 1), _cm_head)
		head.position = Vector3(cos(angle) * 0.2 + sin(angle) * lean * h * 0.3, tip_y, sin(angle) * 0.2 - cos(angle) * lean * h * 0.1)
		head.rotation = stalk.rotation

	var _sm_root := SphereMesh.new()
	_sm_root.radius = 0.4
	_sm_root.height = 0.8
	_sm_root.radial_segments = 16
	_sm_root.rings = 8
	var root: MeshInstance3D = _mi("", _sm_root)
	root.position = Vector3(0.0, 0.15, 0.0)
	root.scale = Vector3(1.2, 0.4, 1.2)

	_add_glow_ring(0.6, 0.8)

# ── Chitin Shard (lv20) — ANGULAR overlapping armor plates with spikes ──
func _build_chitin_shard() -> void:
	var plates: Array = [
		{"size": Vector3(1.4, 1.8, 0.12), "pos": Vector3(0.0, 0.9, 0.0), "rot": Vector3(0.35, 0.0, 0.0)},
		{"size": Vector3(1.2, 1.5, 0.12), "pos": Vector3(0.5, 0.8, 0.4), "rot": Vector3(0.4, 0.6, 0.1)},
		{"size": Vector3(1.0, 1.3, 0.12), "pos": Vector3(-0.4, 0.7, 0.2), "rot": Vector3(0.35, -0.5, -0.1)},
	]
	for i in range(plates.size()):
		var p: Dictionary = plates[i]
		var sz: Vector3 = p["size"]
		var plate_name: String = "Accent%d" % i if i > 0 else ""
		var _bm := BoxMesh.new()
		_bm.size = sz
		var plate: MeshInstance3D = _mi(plate_name, _bm)
		plate.position = p["pos"]
		plate.rotation = p["rot"]

	var _cm_spike := CylinderMesh.new()
	_cm_spike.top_radius = 0.001
	_cm_spike.bottom_radius = 0.08
	_cm_spike.height = 0.6
	_cm_spike.radial_segments = 4
	for i in range(5):
		var spike: MeshInstance3D = _mi("Accent%d" % (i + 3), _cm_spike)
		var a: float = i * TAU / 5.0 + 0.5
		spike.position = Vector3(cos(a) * 0.5, 1.5 + i * 0.08, sin(a) * 0.5)
		spike.rotation.z = cos(a) * 0.3
		spike.rotation.x = sin(a) * 0.3

	_add_glow_ring(0.8, 1.0)

# ── Alien Steak (lv25) — LOW wide fleshy mass with visible veins, very organic ──
func _build_alien_steak() -> void:
	var masses: Array = [
		{"r": 0.8, "pos": Vector3(0.0, 0.4, 0.0), "scale": Vector3(1.5, 0.5, 1.3), "seed": 73},
		{"r": 0.6, "pos": Vector3(0.6, 0.35, 0.4), "scale": Vector3(1.3, 0.6, 1.2), "seed": 74},
		{"r": 0.55, "pos": Vector3(-0.5, 0.3, -0.3), "scale": Vector3(1.4, 0.45, 1.1), "seed": 75},
	]
	for i in range(masses.size()):
		var m: Dictionary = masses[i]
		var r: float = m["r"]
		var mass_name: String = "Accent%d" % i if i > 0 else ""
		var _sm := SphereMesh.new()
		_sm.radius = r
		_sm.height = r * 2.0
		_sm.radial_segments = 16
		_sm.rings = 8
		var mass: MeshInstance3D = _mi(mass_name, _sm)
		mass.position = m["pos"]
		mass.scale = m["scale"]

	var _cm_vein := CylinderMesh.new()
	_cm_vein.top_radius = 0.05
	_cm_vein.bottom_radius = 0.05
	_cm_vein.height = 1.0
	_cm_vein.radial_segments = 6
	for i in range(6):
		var vein: MeshInstance3D = _mi("Accent%d" % (i + 3), _cm_vein)
		var a: float = i * TAU / 6.0
		vein.position = Vector3(cos(a) * 0.5, 0.35 + i * 0.03, sin(a) * 0.5)
		vein.rotation.x = sin(a) * 0.7
		vein.rotation.z = -cos(a) * 0.7

	var _sm_bump := SphereMesh.new()
	_sm_bump.radius = 0.12
	_sm_bump.height = 0.24
	_sm_bump.radial_segments = 16
	_sm_bump.rings = 8
	for i in range(5):
		var bump: MeshInstance3D = _mi("", _sm_bump)
		var na: float = i * TAU / 5.0 + 0.7
		bump.position = Vector3(cos(na) * 0.6, 0.5, sin(na) * 0.6)

	_add_glow_ring(1.1, 1.3)

# ── Spore Cap (lv30) — BIG MUSHROOM cluster, very tall with wide caps ──
func _build_mushroom_cluster() -> void:
	# Mushroom 1: stem + cap as cylinder approximation
	var _cm_m1 := CylinderMesh.new()
	_cm_m1.top_radius = 0.25
	_cm_m1.bottom_radius = 0.25
	_cm_m1.height = 2.5
	_cm_m1.radial_segments = 12
	var m1: MeshInstance3D = _mi("", _cm_m1)
	m1.position = Vector3(0.0, 1.25, 0.0)

	# Accent cap glow overlay for main mushroom (hemisphere approximated as sphere)
	var _sm_cap1 := SphereMesh.new()
	_sm_cap1.radius = 1.2
	_sm_cap1.height = 2.4
	_sm_cap1.radial_segments = 16
	_sm_cap1.rings = 8
	var cap1: MeshInstance3D = _mi("Accent1", _sm_cap1)
	cap1.position = Vector3(0.0, 2.7, 0.0)
	cap1.scale = Vector3(1.0, 0.35, 1.0)

	var _cm_m2 := CylinderMesh.new()
	_cm_m2.top_radius = 0.15
	_cm_m2.bottom_radius = 0.15
	_cm_m2.height = 1.5
	_cm_m2.radial_segments = 10
	var m2: MeshInstance3D = _mi("", _cm_m2)
	m2.position = Vector3(0.8, 0.75, 0.5)
	m2.rotation.z = -0.25

	var _sm_cap2 := SphereMesh.new()
	_sm_cap2.radius = 0.7
	_sm_cap2.height = 1.4
	_sm_cap2.radial_segments = 16
	_sm_cap2.rings = 8
	var cap2: MeshInstance3D = _mi("Accent2", _sm_cap2)
	cap2.position = Vector3(0.9, 1.7, 0.5)
	cap2.scale = Vector3(1.0, 0.35, 1.0)

	var _cm_m3 := CylinderMesh.new()
	_cm_m3.top_radius = 0.1
	_cm_m3.bottom_radius = 0.1
	_cm_m3.height = 0.9
	_cm_m3.radial_segments = 8
	var m3: MeshInstance3D = _mi("", _cm_m3)
	m3.position = Vector3(-0.6, 0.45, 0.35)
	m3.rotation.z = 0.2

	var _sm_cap3 := SphereMesh.new()
	_sm_cap3.radius = 0.4
	_sm_cap3.height = 0.8
	_sm_cap3.radial_segments = 16
	_sm_cap3.rings = 8
	var cap3: MeshInstance3D = _mi("Accent3", _sm_cap3)
	cap3.position = Vector3(-0.65, 1.05, 0.35)
	cap3.scale = Vector3(1.0, 0.35, 1.0)

	_add_glow_ring(1.0, 1.2)

# ── Plasma Pepper (lv35) — ARCHING vine with hanging pods underneath ──
func _build_vine_pods() -> void:
	var vine_segments: int = 8
	for i in range(vine_segments):
		var t: float = float(i) / (vine_segments - 1)
		var r: float = 0.12 - t * 0.04
		var _cm := CylinderMesh.new()
		_cm.top_radius = r
		_cm.bottom_radius = r
		_cm.height = 0.5
		_cm.radial_segments = 6
		var seg: MeshInstance3D = _mi("", _cm)
		seg.position = Vector3(t * 1.2 - 0.6, 0.3 + sin(t * PI) * 2.5, t * 0.4 - 0.2)
		seg.rotation.z = -t * 0.8 + 0.4
		seg.rotation.x = t * 0.3

	var _sm_pod := SphereMesh.new()
	_sm_pod.radius = 0.25
	_sm_pod.height = 0.5
	_sm_pod.radial_segments = 16
	_sm_pod.rings = 8
	var _cm_stem := CylinderMesh.new()
	_cm_stem.top_radius = 0.03
	_cm_stem.bottom_radius = 0.03
	_cm_stem.height = 0.3
	_cm_stem.radial_segments = 4
	var pod_positions: Array = [
		Vector3(-0.3, 1.8, 0.0), Vector3(0.0, 2.5, 0.1),
		Vector3(0.3, 2.2, -0.1), Vector3(0.5, 1.5, 0.05),
	]
	for i in range(pod_positions.size()):
		var pod: MeshInstance3D = _mi("Accent%d" % (i + 1), _sm_pod)
		pod.position = pod_positions[i]
		pod.scale = Vector3(0.6, 1.5, 0.6)

		var stem: MeshInstance3D = _mi("", _cm_stem)
		stem.position = pod_positions[i] + Vector3(0.0, 0.3, 0.0)

	_add_glow_ring(0.8, 1.0)

# ── Void Moss (lv40) — SPRAWLING ground cover with creeping tendrils reaching UP ──
func _build_void_moss() -> void:
	var patches: Array = [
		{"r": 0.9, "h": 0.15, "pos": Vector3(0.0, 0.08, 0.0)},
		{"r": 0.7, "h": 0.12, "pos": Vector3(0.8, 0.06, 0.5)},
		{"r": 0.6, "h": 0.1, "pos": Vector3(-0.7, 0.05, -0.4)},
		{"r": 0.5, "h": 0.1, "pos": Vector3(0.4, 0.05, -0.6)},
	]
	for i in range(patches.size()):
		var p: Dictionary = patches[i]
		var r: float = p["r"]
		var h: float = p["h"]
		var patch_name: String = "Accent%d" % i if i > 0 else ""
		var _cm := CylinderMesh.new()
		_cm.top_radius = r
		_cm.bottom_radius = r
		_cm.height = h
		_cm.radial_segments = 16
		var patch: MeshInstance3D = _mi(patch_name, _cm)
		patch.position = p["pos"]
		patch.rotation.y = i * 0.8

	var _sm_tip := SphereMesh.new()
	_sm_tip.radius = 0.06
	_sm_tip.height = 0.12
	_sm_tip.radial_segments = 16
	_sm_tip.rings = 8
	for i in range(6):
		var th: float = 1.2 + fmod(i * 0.31, 0.5)
		var _cm_tendril := CylinderMesh.new()
		_cm_tendril.top_radius = 0.04
		_cm_tendril.bottom_radius = 0.04
		_cm_tendril.height = th
		_cm_tendril.radial_segments = 4
		var tendril: MeshInstance3D = _mi("Accent%d" % (i + 4), _cm_tendril)
		var ta: float = i * TAU / 6.0 + 0.3
		var tdist: float = 0.4 + fmod(i * 0.17, 0.3)
		tendril.position = Vector3(cos(ta) * tdist, th * 0.5, sin(ta) * tdist)
		tendril.rotation.x = sin(ta) * 0.3
		tendril.rotation.z = -cos(ta) * 0.3

		var tip: MeshInstance3D = _mi("Accent%d" % (i + 10), _sm_tip)
		tip.position = Vector3(cos(ta) * tdist, th + 0.05, sin(ta) * tdist)

	_add_glow_ring(1.0, 1.2)

# ── Crystal Honey (lv45) — BIG alien flower with wide petals ──
func _build_flower_bloom() -> void:
	var _cm_stem := CylinderMesh.new()
	_cm_stem.top_radius = 0.2
	_cm_stem.bottom_radius = 0.2
	_cm_stem.height = 2.2
	_cm_stem.radial_segments = 8
	var stem: MeshInstance3D = _mi("", _cm_stem)
	stem.position.y = 1.1

	var _sm_pistil := SphereMesh.new()
	_sm_pistil.radius = 0.45
	_sm_pistil.height = 0.9
	_sm_pistil.radial_segments = 16
	_sm_pistil.rings = 8
	var pistil: MeshInstance3D = _mi("Accent1", _sm_pistil)
	pistil.position.y = 2.5

	var _sm_petal := SphereMesh.new()
	_sm_petal.radius = 0.55
	_sm_petal.height = 1.1
	_sm_petal.radial_segments = 16
	_sm_petal.rings = 8
	for i in range(6):
		var petal: MeshInstance3D = _mi("Accent%d" % (i + 2), _sm_petal)
		var a: float = i * TAU / 6.0
		petal.position = Vector3(cos(a) * 0.6, 2.3, sin(a) * 0.6)
		petal.scale = Vector3(1.0, 0.2, 0.7)
		petal.rotation.y = -a
		petal.rotation.x = 0.6

	var _sm_leaf := SphereMesh.new()
	_sm_leaf.radius = 0.5
	_sm_leaf.height = 1.0
	_sm_leaf.radial_segments = 16
	_sm_leaf.rings = 8
	for i in range(2):
		var leaf: MeshInstance3D = _mi("", _sm_leaf)
		var la: float = i * PI + 0.5
		leaf.position = Vector3(cos(la) * 0.5, 0.5, sin(la) * 0.5)
		leaf.scale = Vector3(0.9, 0.1, 1.6)
		leaf.rotation.y = -la

	_add_glow_ring(0.8, 1.0)

# ── Neural Bloom (lv50) — BRAIN on a stalk with radiating neural tendrils ──
func _build_neural_bloom() -> void:
	var _cm_stem := CylinderMesh.new()
	_cm_stem.top_radius = 0.22
	_cm_stem.bottom_radius = 0.22
	_cm_stem.height = 2.0
	_cm_stem.radial_segments = 8
	var stem: MeshInstance3D = _mi("", _cm_stem)
	stem.position.y = 1.0

	# Brain-like core — overlapping spheres for wrinkled look
	var core_offsets: Array = [
		{"r": 0.55, "pos": Vector3(0.0, 2.3, 0.0), "scale": Vector3(1.0, 0.85, 1.0), "seed": 30},
		{"r": 0.4, "pos": Vector3(0.25, 2.4, 0.15), "scale": Vector3(1.1, 0.8, 0.9), "seed": 31},
		{"r": 0.35, "pos": Vector3(-0.2, 2.5, -0.12), "scale": Vector3(0.9, 0.9, 1.1), "seed": 32},
		{"r": 0.3, "pos": Vector3(0.08, 2.2, -0.2), "scale": Vector3(1.05, 0.95, 0.95), "seed": 33},
		{"r": 0.28, "pos": Vector3(-0.1, 2.6, 0.1), "scale": Vector3(0.95, 0.85, 1.05), "seed": 34},
	]
	for i in range(core_offsets.size()):
		var co: Dictionary = core_offsets[i]
		var r: float = co["r"]
		var lobe_name: String = "Accent%d" % i if i > 0 else ""
		var _sm := SphereMesh.new()
		_sm.radius = r
		_sm.height = r * 2.0
		_sm.radial_segments = 16
		_sm.rings = 8
		var lobe: MeshInstance3D = _mi(lobe_name, _sm)
		lobe.position = co["pos"]
		lobe.scale = co["scale"]

	var _cm_tendril := CylinderMesh.new()
	_cm_tendril.top_radius = 0.05
	_cm_tendril.bottom_radius = 0.05
	_cm_tendril.height = 1.0
	_cm_tendril.radial_segments = 5
	var _sm_tip := SphereMesh.new()
	_sm_tip.radius = 0.1
	_sm_tip.height = 0.2
	_sm_tip.radial_segments = 16
	_sm_tip.rings = 8
	for i in range(8):
		var a: float = i * TAU / 8.0
		var tendril: MeshInstance3D = _mi("Accent%d" % (i + 5), _cm_tendril)
		tendril.position = Vector3(cos(a) * 0.5, 2.3, sin(a) * 0.5)
		tendril.rotation.x = sin(a) * 0.7
		tendril.rotation.z = -cos(a) * 0.7

		var tip_node: MeshInstance3D = _mi("Accent%d" % (i + 13), _sm_tip)
		tip_node.position = Vector3(cos(a) * 0.5 + cos(a) * 0.7, 2.3 + sin(a) * 0.4, sin(a) * 0.5 + sin(a) * 0.7)

	_add_glow_ring(0.8, 1.0)

# ── Void Truffle (lv55) — LUMPY bulbous mass with thick root tendrils ──
func _build_truffle_tendrils() -> void:
	var _sm1 := SphereMesh.new()
	_sm1.radius = 0.9
	_sm1.height = 1.8
	_sm1.radial_segments = 16
	_sm1.rings = 8
	var body1: MeshInstance3D = _mi("", _sm1)
	body1.position = Vector3(0.0, 0.7, 0.0)
	body1.scale = Vector3(1.2, 0.8, 1.1)

	var _sm2 := SphereMesh.new()
	_sm2.radius = 0.6
	_sm2.height = 1.2
	_sm2.radial_segments = 16
	_sm2.rings = 8
	var body2: MeshInstance3D = _mi("Accent1", _sm2)
	body2.position = Vector3(0.5, 0.85, 0.25)
	body2.scale = Vector3(1.1, 0.9, 1.0)

	var _sm3 := SphereMesh.new()
	_sm3.radius = 0.5
	_sm3.height = 1.0
	_sm3.radial_segments = 16
	_sm3.rings = 8
	var body3: MeshInstance3D = _mi("Accent2", _sm3)
	body3.position = Vector3(-0.4, 0.95, -0.2)
	body3.scale = Vector3(1.0, 0.85, 1.15)

	for i in range(7):
		var th: float = 1.2 + fmod(i * 0.19, 0.4)
		var _cm := CylinderMesh.new()
		_cm.top_radius = 0.08
		_cm.bottom_radius = 0.08
		_cm.height = th
		_cm.radial_segments = 5
		var tendril: MeshInstance3D = _mi("Accent%d" % (i + 3), _cm)
		var a: float = i * TAU / 7.0 + 0.2
		tendril.position = Vector3(cos(a) * 0.7, 0.15, sin(a) * 0.7)
		tendril.rotation.x = sin(a) * 0.75
		tendril.rotation.z = -cos(a) * 0.75

	var _sm_bump := SphereMesh.new()
	_sm_bump.radius = 0.15
	_sm_bump.height = 0.3
	_sm_bump.radial_segments = 16
	_sm_bump.rings = 8
	for i in range(4):
		var bump: MeshInstance3D = _mi("", _sm_bump)
		var ba: float = i * TAU / 4.0
		bump.position = Vector3(cos(ba) * 0.3, 1.3, sin(ba) * 0.3)

	_add_glow_ring(1.0, 1.2)

# ── Quantum Vine (lv60) — TALL double-helix spiraling vine structure ──
func _build_quantum_vine() -> void:
	var _cm_seg := CylinderMesh.new()
	_cm_seg.top_radius = 0.08
	_cm_seg.bottom_radius = 0.08
	_cm_seg.height = 0.35
	_cm_seg.radial_segments = 6
	var helix_segments: int = 10
	for h in range(2):
		for i in range(helix_segments):
			var t: float = float(i) / (helix_segments - 1)
			var seg_name: String = "Accent%d" % (i + 1) if h == 1 else ""
			var seg: MeshInstance3D = _mi(seg_name, _cm_seg)
			var angle: float = t * TAU * 2.0 + h * PI
			var rad: float = 0.45
			seg.position = Vector3(cos(angle) * rad, 0.3 + t * 3.5, sin(angle) * rad)
			seg.rotation = Vector3(sin(angle) * 0.3, angle + PI / 2.0, cos(angle) * 0.3)

	var _sm_node := SphereMesh.new()
	_sm_node.radius = 0.2
	_sm_node.height = 0.4
	_sm_node.radial_segments = 16
	_sm_node.rings = 8
	for i in range(5):
		var t: float = float(i) / 4.0
		var phase_node: MeshInstance3D = _mi("Accent%d" % (helix_segments + i + 1), _sm_node)
		phase_node.position.y = 0.5 + t * 3.2

	var _cm_base := CylinderMesh.new()
	_cm_base.top_radius = 0.5
	_cm_base.bottom_radius = 0.5
	_cm_base.height = 0.25
	_cm_base.radial_segments = 8
	var base: MeshInstance3D = _mi("", _cm_base)
	base.position.y = 0.12

	_add_glow_ring(0.6, 0.8)

# ── Gravity Residue (lv65) — MASSIVE alien tree with spreading canopy ──
func _build_alien_tree() -> void:
	var _cm_trunk := CylinderMesh.new()
	_cm_trunk.top_radius = 0.45
	_cm_trunk.bottom_radius = 0.45
	_cm_trunk.height = 3.5
	_cm_trunk.radial_segments = 8
	var trunk: MeshInstance3D = _mi("", _cm_trunk)
	trunk.position.y = 1.75

	# Trunk base flare (inverted cone)
	var _cm_flare := CylinderMesh.new()
	_cm_flare.top_radius = 0.001
	_cm_flare.bottom_radius = 0.7
	_cm_flare.height = 0.6
	_cm_flare.radial_segments = 8
	var flare: MeshInstance3D = _mi("", _cm_flare)
	flare.position.y = 0.3
	flare.rotation.x = PI

	var canopy_data: Array = [
		{"r": 1.3, "pos": Vector3(0.0, 3.8, 0.0)},
		{"r": 0.9, "pos": Vector3(0.8, 4.1, 0.5)},
		{"r": 0.85, "pos": Vector3(-0.7, 4.0, -0.4)},
		{"r": 0.7, "pos": Vector3(0.2, 4.3, -0.6)},
		{"r": 0.6, "pos": Vector3(-0.3, 3.7, 0.7)},
	]
	for i in range(canopy_data.size()):
		var cd: Dictionary = canopy_data[i]
		var r: float = cd["r"]
		var _sm := SphereMesh.new()
		_sm.radius = r
		_sm.height = r * 2.0
		_sm.radial_segments = 16
		_sm.rings = 8
		var canopy: MeshInstance3D = _mi("Accent%d" % (i + 1), _sm)
		canopy.position = cd["pos"]
		canopy.scale = Vector3(1.0, 0.35, 1.0)

	var _sm_fruit := SphereMesh.new()
	_sm_fruit.radius = 0.15
	_sm_fruit.height = 0.3
	_sm_fruit.radial_segments = 16
	_sm_fruit.rings = 8
	for i in range(4):
		var fruit: MeshInstance3D = _mi("Accent%d" % (canopy_data.size() + i + 1), _sm_fruit)
		var fa: float = i * TAU / 4.0 + 0.8
		fruit.position = Vector3(cos(fa) * 0.7, 3.2, sin(fa) * 0.7)

	_add_glow_ring(1.0, 1.2)

# ══════════════════════════════════════════════════════════════

# ── Shared: glow ring at base ──
func _add_glow_ring(inner_r: float, outer_r: float) -> void:
	var _tm := TorusMesh.new()
	_tm.inner_radius = (outer_r - inner_r) / 2.0
	_tm.outer_radius = (inner_r + outer_r) / 2.0
	_tm.rings = 20
	_tm.ring_segments = 16
	var glow_ring: MeshInstance3D = _mi("GlowRing", _tm)
	glow_ring.position.y = 0.05

func _process(delta: float) -> void:
	# One-time ground snap
	if not _grounded:
		_grounded = true
		var area_mgr: Node3D = get_tree().get_first_node_in_group("area_manager")
		if area_mgr and area_mgr.has_method("get_terrain_height"):
			var ty: float = area_mgr.get_terrain_height(global_position.x, global_position.z)
			global_position.y = ty + 0.1

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
		if part is MeshInstance3D:
			if part.name.begins_with("Accent") or part.name.begins_with("Ring"):
				part.material_override = accent_mat
			elif part.name == "GlowRing":
				part.material_override = ring_mat
			else:
				part.material_override = body_mat

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
		var p_r: float = 0.08 + randf() * 0.06
		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.albedo_color = _node_color.lightened(0.3)
		pmat.emission_enabled = true
		pmat.emission = _node_color.lightened(0.5)
		pmat.emission_energy_multiplier = 3.0

		var particle: MeshInstance3D = MeshInstance3D.new()
		var _sm := SphereMesh.new()
		_sm.radius = p_r
		_sm.height = p_r * 2.0
		_sm.radial_segments = 16
		_sm.rings = 8
		particle.mesh = _sm
		particle.material_override = pmat
		particle.top_level = true
		particle.global_position = global_position + Vector3(0, 0.8, 0)
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
