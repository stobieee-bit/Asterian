## GroundItemController — Visual + interaction for a ground item drop
##
## Shows a small glowing orb with a pulsing ring and a label. Bobs gently.
## Click to pick up (if in range). Glow color based on item tier.
extends Node3D

# ── Visual refs ──
var _orb: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _label: Label3D = null
var _bob_time: float = 0.0
var _pulse_time: float = 0.0

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

	# Set label text
	if _label:
		var qty_text: String = " x%d" % quantity if quantity > 1 else ""
		_label.text = "%s%s" % [item_name, qty_text]
		_label.modulate = col.lightened(0.2)

	# Set orb color
	if _orb:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.2
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		_orb.material_override = mat

	# Set ring color (matching but dimmer)
	if _ring:
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.albedo_color = col.darkened(0.2)
		ring_mat.albedo_color.a = 0.4
		ring_mat.emission_enabled = true
		ring_mat.emission = col
		ring_mat.emission_energy_multiplier = 0.6
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.no_depth_test = true
		_ring.material_override = ring_mat

func _ready() -> void:
	# Add to ground_items group for raycasting/hover detection
	add_to_group("ground_items")

	# Add a small collision body so raycasts can hit this item (layer 5, mask 16)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 16  # Layer 5
	body.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	col.position = Vector3(0, 0.35, 0)
	body.add_child(col)
	add_child(body)

	# Create a small glowing sphere (orb) to represent the item
	_orb = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 12
	sphere.rings = 6
	_orb.mesh = sphere
	add_child(_orb)

	# Create a flat ring below the orb (pickup indicator)
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.35
	torus.rings = 8
	torus.ring_segments = 12
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.02
	add_child(_ring)

	# Create floating label
	_label = Label3D.new()
	_label.position = Vector3(0, 0.65, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 14
	_label.outline_size = 3
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.text = "Item"
	add_child(_label)

	# Random starting bob offset so items don't sync
	_bob_time = randf() * TAU
	_pulse_time = randf() * TAU

func _process(delta: float) -> void:
	# Bob the orb gently
	_bob_time += delta * 2.5
	if _orb:
		_orb.position.y = 0.35 + sin(_bob_time) * 0.06

	# Rotate the orb slowly
	if _orb:
		_orb.rotation.y += delta * 2.0

	# Pulse the ring scale
	_pulse_time += delta * 3.0
	if _ring:
		var s: float = 1.0 + sin(_pulse_time) * 0.12
		_ring.scale = Vector3(s, s, s)

## Get the color for a given tier
func _tier_color(tier: int) -> Color:
	# Look up from equipment.json tier data
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		var color_hex: String = str(tiers[tier_str].get("color", "#ffffff"))
		return Color.html(color_hex)

	# Fallback by tier number
	match tier:
		1: return Color(0.55, 0.55, 0.55)  # Gray
		2: return Color(0.27, 0.8, 0.4)    # Green
		3: return Color(0.27, 0.53, 1.0)   # Blue
		4: return Color(0.4, 0.67, 0.8)    # Teal
		5: return Color(0.53, 0.8, 0.27)   # Yellow-green
		6: return Color(0.67, 0.27, 1.0)   # Purple
		7: return Color(1.0, 0.53, 0.27)   # Orange
		8: return Color(1.0, 0.27, 0.53)   # Pink
		_: return Color(0.8, 0.8, 0.8)     # White
