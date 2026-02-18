## EnemyTelegraph — Static helper for creating visual attack telegraphs
##
## Provides factory methods for circle, line, and cone telegraph indicators.
## Uses CSG meshes with pulsing animation. Configurable delay, color, and size.
## Extracted from boss_ai.gd's inline telegraph rendering for reuse by
## regular enemies and elites.
class_name EnemyTelegraph
extends RefCounted


## Create a circle telegraph (AoE indicator) at a position.
## Returns the CSG node — caller is responsible for adding it to the scene tree.
static func create_circle(
	center: Vector3,
	radius: float,
	delay: float,
	color: Color = Color(1.0, 0.2, 0.2, 0.3),
	parent: Node3D = null
) -> CSGCylinder3D:
	var telegraph: CSGCylinder3D = CSGCylinder3D.new()
	telegraph.radius = radius
	telegraph.height = 0.05
	telegraph.sides = 24
	telegraph.global_position = center + Vector3(0, 0.05, 0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	telegraph.material = mat

	if parent:
		parent.add_child(telegraph)
		_animate_and_remove(telegraph, mat, delay, parent)

	return telegraph


## Create a line telegraph (directional attack indicator).
## Returns the CSG node.
static func create_line(
	start: Vector3,
	end: Vector3,
	width: float,
	delay: float,
	color: Color = Color(1.0, 0.3, 0.1, 0.3),
	parent: Node3D = null
) -> CSGBox3D:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	var midpoint: Vector3 = start + direction * 0.5

	var telegraph: CSGBox3D = CSGBox3D.new()
	telegraph.size = Vector3(width, 0.05, length)
	telegraph.global_position = midpoint + Vector3(0, 0.05, 0)

	# Rotate to face direction
	if direction.length() > 0.01:
		var flat_dir: Vector3 = Vector3(direction.x, 0, direction.z).normalized()
		if flat_dir.length() > 0.01:
			telegraph.rotation.y = atan2(-flat_dir.x, -flat_dir.z)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	telegraph.material = mat

	if parent:
		parent.add_child(telegraph)
		_animate_and_remove(telegraph, mat, delay, parent)

	return telegraph


## Create a cone telegraph (cleave/breath attack indicator).
## Returns the CSG node.
static func create_cone(
	origin: Vector3,
	direction: Vector3,
	length: float,
	angle_degrees: float,
	delay: float,
	color: Color = Color(1.0, 0.5, 0.1, 0.3),
	parent: Node3D = null
) -> CSGCylinder3D:
	# Use a cylinder rotated to represent a cone shape
	var telegraph: CSGCylinder3D = CSGCylinder3D.new()
	telegraph.radius = length * tan(deg_to_rad(angle_degrees / 2.0))
	telegraph.height = 0.05
	telegraph.sides = 16
	telegraph.global_position = origin + direction.normalized() * (length * 0.5) + Vector3(0, 0.05, 0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	telegraph.material = mat

	if parent:
		parent.add_child(telegraph)
		_animate_and_remove(telegraph, mat, delay, parent)

	return telegraph


## Animate telegraph: pulse alpha up, then remove after delay
static func _animate_and_remove(telegraph: Node3D, mat: StandardMaterial3D, delay: float, parent: Node3D) -> void:
	var tween: Tween = parent.create_tween()
	var start_alpha: float = mat.albedo_color.a
	var pulse_count: int = maxi(1, int(delay / 0.4))

	# Pulse the alpha: low → high → low pattern
	for i in range(pulse_count):
		tween.tween_property(mat, "albedo_color:a", start_alpha * 2.5, 0.2)
		tween.tween_property(mat, "albedo_color:a", start_alpha, 0.2)

	# Final bright flash before attack lands
	tween.tween_property(mat, "albedo_color:a", 0.8, 0.1)
	tween.tween_callback(telegraph.queue_free)
