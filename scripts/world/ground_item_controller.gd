## GroundItemController — Visual + interaction for a ground item drop
##
## Shows a 3D shape based on item type with glow, light beam, particles,
## floating label, and gentle bob/spin animation. Click to pick up.
extends Node3D

# ── Visual refs ──
var _shape_mesh: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _label: Label3D = null
var _beam: MeshInstance3D = null
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null
var _bob_time: float = 0.0
var _pulse_time: float = 0.0
var _base_y: float = 0.35

# ── Item data ──
var item_id: String = ""
var quantity: int = 1

func setup(p_item_id: String, p_quantity: int) -> void:
	item_id = p_item_id
	quantity = p_quantity

	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	var item_name: String = str(item_data.get("name", item_id))
	var tier: int = int(item_data.get("tier", 1))
	var item_type: String = str(item_data.get("type", ""))
	var col: Color = _tier_color(tier)

	# Set the mesh shape based on item type
	if _shape_mesh:
		_shape_mesh.mesh = _get_shape_for_type(item_type)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.9
		mat.metallic = 0.6
		mat.roughness = 0.3
		_shape_mesh.material_override = mat

	# Label
	if _label:
		var qty_text: String = " x%d" % quantity if quantity > 1 else ""
		_label.text = "%s%s" % [item_name, qty_text]
		_label.modulate = col.lightened(0.3)

	# Ring color
	if _ring:
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.albedo_color = col.darkened(0.1)
		ring_mat.albedo_color.a = 0.5
		ring_mat.emission_enabled = true
		ring_mat.emission = col
		ring_mat.emission_energy_multiplier = 1.0
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.no_depth_test = true
		_ring.material_override = ring_mat

	# Light beam color
	if _beam:
		var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
		beam_mat.albedo_color = col
		beam_mat.albedo_color.a = 0.12
		beam_mat.emission_enabled = true
		beam_mat.emission = col
		beam_mat.emission_energy_multiplier = 0.5
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.no_depth_test = true
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam.material_override = beam_mat

	# Particle color
	if _particles:
		var p_mat: ParticleProcessMaterial = _particles.process_material as ParticleProcessMaterial
		if p_mat:
			p_mat.color = col

	# Point light color
	if _light:
		_light.light_color = col
		# Higher tier = brighter light
		_light.light_energy = 0.4 + tier * 0.15

func _ready() -> void:
	add_to_group("ground_items")

	# ── Collision body for raycasting (layer 5 = mask 16) ──
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.5
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0.35, 0)
	body.add_child(col_shape)
	add_child(body)

	# ── Main item shape (replaced per-type in setup) ──
	_shape_mesh = MeshInstance3D.new()
	_shape_mesh.mesh = _get_shape_for_type("")  # Default sphere
	_shape_mesh.position.y = _base_y
	_shape_mesh.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shape_mesh)

	# ── Ground ring / pickup indicator ──
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.42
	torus.rings = 12
	torus.ring_segments = 16
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.02
	_ring.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	# ── Vertical light beam (thin cylinder reaching upward) ──
	_beam = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.15
	cyl.height = 3.0
	cyl.radial_segments = 8
	_beam.mesh = cyl
	_beam.position.y = 1.5
	_beam.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

	# ── Particles floating upward around the item ──
	_particles = GPUParticles3D.new()
	_particles.amount = 8
	_particles.lifetime = 1.5
	_particles.position.y = 0.35
	_particles.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	var p_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.3
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.initial_velocity_min = 0.3
	p_mat.initial_velocity_max = 0.6
	p_mat.gravity = Vector3(0, 0.2, 0)
	p_mat.scale_min = 0.03
	p_mat.scale_max = 0.07
	p_mat.color = Color(1, 1, 1)
	_particles.process_material = p_mat
	# Use a tiny sphere as the particle mesh
	var p_draw: QuadMesh = QuadMesh.new()
	p_draw.size = Vector2(0.08, 0.08)
	var p_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	p_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_draw_mat.albedo_color = Color(1, 1, 1, 0.8)
	p_draw_mat.emission_enabled = true
	p_draw_mat.emission = Color(1, 1, 1)
	p_draw_mat.emission_energy_multiplier = 2.0
	p_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p_draw.material = p_draw_mat
	_particles.draw_pass_1 = p_draw
	add_child(_particles)

	# ── Small omni light for glow on the ground ──
	_light = OmniLight3D.new()
	_light.position.y = 0.5
	_light.light_energy = 0.5
	_light.omni_range = 2.5
	_light.omni_attenuation = 1.5
	_light.light_color = Color(1, 1, 1)
	_light.shadow_enabled = false
	add_child(_light)

	# ── Floating label ──
	_label = Label3D.new()
	_label.position = Vector3(0, 0.85, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 16
	_label.outline_size = 4
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.text = "Item"
	add_child(_label)

	# Random starting offset so items don't sync
	_bob_time = randf() * TAU
	_pulse_time = randf() * TAU

func _process(delta: float) -> void:
	# Bob the shape gently
	_bob_time += delta * 2.0
	if _shape_mesh:
		_shape_mesh.position.y = _base_y + sin(_bob_time) * 0.08

	# Spin the shape slowly
	if _shape_mesh:
		_shape_mesh.rotation.y += delta * 1.5

	# Pulse the ring scale
	_pulse_time += delta * 2.5
	if _ring:
		var s: float = 1.0 + sin(_pulse_time) * 0.15
		_ring.scale = Vector3(s, s, s)

	# Fade the beam gently
	if _beam and _beam.material_override:
		var beam_alpha: float = 0.08 + sin(_pulse_time * 0.7) * 0.04
		(_beam.material_override as StandardMaterial3D).albedo_color.a = beam_alpha

## Return a mesh shape based on item type
func _get_shape_for_type(item_type: String) -> Mesh:
	match item_type:
		"ore", "bar", "material":
			# Cube / box shape for raw materials
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.22, 0.22, 0.22)
			return box
		"food", "consumable":
			# Capsule shape for food & potions
			var cap: CapsuleMesh = CapsuleMesh.new()
			cap.radius = 0.1
			cap.height = 0.3
			return cap
		"weapon":
			# Prism shape for weapons
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(0.22, 0.3, 0.12)
			return prism
		"armor":
			# Cylinder for armor pieces
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.14
			cyl.bottom_radius = 0.14
			cyl.height = 0.22
			cyl.radial_segments = 6
			return cyl
		"gadget", "tool":
			# Diamond / octahedron approximation for gadgets
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(0.18, 0.22, 0.18)
			return prism
		_:
			# Default: glowing sphere
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.32
			sphere.radial_segments = 16
			sphere.rings = 8
			return sphere

## Get the color for a given tier
func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		var color_hex: String = str(tiers[tier_str].get("color", "#ffffff"))
		return Color.html(color_hex)

	# Fallback by tier number
	match tier:
		1: return Color(0.6, 0.6, 0.6)     # Gray — common
		2: return Color(0.27, 0.85, 0.4)    # Green — uncommon
		3: return Color(0.3, 0.55, 1.0)     # Blue — rare
		4: return Color(0.4, 0.75, 0.85)    # Teal — superior
		5: return Color(0.6, 0.85, 0.27)    # Lime — epic
		6: return Color(0.72, 0.27, 1.0)    # Purple — legendary
		7: return Color(1.0, 0.55, 0.2)     # Orange — mythic
		8: return Color(1.0, 0.27, 0.55)    # Pink — transcendent
		_: return Color(0.85, 0.85, 0.85)   # White — unknown
