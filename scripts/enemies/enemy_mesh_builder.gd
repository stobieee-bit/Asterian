## EnemyMeshBuilder — Base class for procedural enemy mesh templates
##
## Provides shared utilities for building enemy meshes from CSG primitives
## and MeshInstance3D nodes. Each template (insectoid, jellyfish, etc.)
## extends this class and implements build_mesh().
##
## Usage:
##   var builder: EnemyMeshBuilder = InsectoidMeshBuilder.new()
##   var mesh_root: Node3D = builder.build(params)
##   enemy_mesh_node.add_child(mesh_root)
class_name EnemyMeshBuilder
extends RefCounted

## Convert an integer color (0xRRGGBB) from JSON to a Godot Color
static func int_to_color(c: int) -> Color:
	var r: float = ((c >> 16) & 0xFF) / 255.0
	var g: float = ((c >> 8) & 0xFF) / 255.0
	var b: float = (c & 0xFF) / 255.0
	return Color(r, g, b)

## Darken a color by subtracting RGB offsets (clamped to 0)
static func darken(c: Color, amount: float = 0.06) -> Color:
	return Color(
		maxf(0.0, c.r - amount),
		maxf(0.0, c.g - amount),
		maxf(0.0, c.b - amount),
		c.a
	)

## Lighten a color by adding RGB offsets (clamped to 1)
static func lighten(c: Color, amount: float = 0.08) -> Color:
	return Color(
		minf(1.0, c.r + amount),
		minf(1.0, c.g + amount),
		minf(1.0, c.b + amount),
		c.a
	)

## Create a StandardMaterial3D with sci-fi metallic style
static func mat_sci(color: Color, metallic: float = 0.4, roughness: float = 0.5,
		emission: Color = Color.BLACK, emission_energy: float = 0.0,
		transparent: bool = false, opacity: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission != Color.BLACK or emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission if emission != Color.BLACK else color
		mat.emission_energy_multiplier = emission_energy
	if transparent or opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = opacity
	return mat

## Create a simple unlit material (like MeshBasicMaterial in Three.js)
static func mat_basic(color: Color, opacity: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = opacity
	return mat

## Add a sphere mesh to a parent node
static func add_sphere(parent: Node3D, radius: float, pos: Vector3,
		material: StandardMaterial3D, scale_xyz: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.position = pos
	mesh.scale = scale_xyz
	parent.add_child(mesh)
	return mesh

## Add a capsule mesh to a parent node
static func add_capsule(parent: Node3D, radius: float, height: float, pos: Vector3,
		material: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height + radius * 2.0
	mesh.mesh = capsule
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation = rot
	parent.add_child(mesh)
	return mesh

## Add a cylinder mesh to a parent node
static func add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float,
		height: float, pos: Vector3, material: StandardMaterial3D,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = top_radius
	cyl.bottom_radius = bottom_radius
	cyl.height = height
	cyl.radial_segments = 12
	mesh.mesh = cyl
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation = rot
	parent.add_child(mesh)
	return mesh

## Add a cone (cylinder with top_radius=0)
static func add_cone(parent: Node3D, radius: float, height: float, pos: Vector3,
		material: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return add_cylinder(parent, 0.0, radius, height, pos, material, rot)

## Add a box mesh to a parent node
static func add_box(parent: Node3D, size: Vector3, pos: Vector3,
		material: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation = rot
	parent.add_child(mesh)
	return mesh

## Add a torus mesh to a parent node
static func add_torus(parent: Node3D, inner_radius: float, outer_radius: float,
		pos: Vector3, material: StandardMaterial3D,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 16
	torus.ring_segments = 12
	mesh.mesh = torus
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation = rot
	parent.add_child(mesh)
	return mesh

## Build the enemy mesh. Override in subclasses.
## Returns the root Node3D containing all mesh parts.
## params: Dictionary with "color" (int), "scale" (float), "variant" (String), etc.
func build_mesh(params: Dictionary) -> Node3D:
	push_warning("EnemyMeshBuilder.build_mesh() not overridden!")
	var root: Node3D = Node3D.new()
	# Fallback: magenta debug sphere
	add_sphere(root, 0.5, Vector3(0, 0.5, 0), mat_basic(Color(1, 0, 1)))
	return root

## Animate the mesh each frame. Override in subclasses for walk/idle cycles.
## phase: accumulated animation time (radians)
## is_moving: whether the enemy is walking
## delta: frame delta time
func animate(root: Node3D, phase: float, is_moving: bool, delta: float) -> void:
	pass

## Play a hit flash effect — pulse emissive white then fade back
static func flash_hit(root: Node3D, intensity: float) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override
			if mat.emission_enabled:
				mat.emission = Color.WHITE.lerp(mat.albedo_color, 1.0 - intensity)

## Play death animation — scale down uniformly
static func animate_death(root: Node3D, progress: float) -> void:
	var s: float = maxf(0.01, 1.0 - progress)
	root.scale = Vector3(s, s, s)
	root.position.y = -0.5 * progress

# ── Template Registry ──
# Maps mesh template names to builder instances.
# Populated by _register_templates() called once at startup.
static var _builders: Dictionary = {}
static var _initialized: bool = false

## Get a mesh builder for a template name. Returns null if not found.
static func get_builder(template_name: String) -> EnemyMeshBuilder:
	if not _initialized:
		_register_templates()
		_initialized = true
	if _builders.has(template_name):
		return _builders[template_name]
	return null

## Register all template builders
static func _register_templates() -> void:
	_builders["insectoid"] = InsectoidMesh.new()
	_builders["swarm_bug"] = SwarmBugMesh.new()
	_builders["arachnid"] = ArachnidMesh.new()
	_builders["jellyfish"] = JellyfishMesh.new()
	_builders["mantis"] = MantisMesh.new()
	_builders["scorpion"] = ScorpionMesh.new()
	_builders["stalker"] = StalkerMesh.new()
	_builders["worm"] = WormMesh.new()
	_builders["slug"] = SlugMesh.new()
	_builders["void_wraith"] = VoidWraithMesh.new()
	_builders["dark_entity"] = DarkEntityMesh.new()
	_builders["crystal_golem"] = CrystalGolemMesh.new()
	_builders["eldritch_eye"] = EldritchEyeMesh.new()
	_builders["reality_warper"] = RealityWarperMesh.new()
	_builders["abyssal_serpent"] = AbyssalSerpentMesh.new()
	_builders["abyssal_horror"] = AbyssalHorrorMesh.new()
	_builders["cosmic_sentinel"] = CosmicSentinelMesh.new()
	_builders["cosmic_titan"] = CosmicTitanMesh.new()
