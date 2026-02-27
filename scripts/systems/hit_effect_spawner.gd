## HitEffectSpawner — Spawns style-colored particle bursts at hit impact points
##
## Pools CPUParticles3D nodes for reuse. Connects to EventBus.hit_landed
## and spawns a brief spark burst at the target's position.
extends Node3D

# ── Pool settings ──
const POOL_SIZE: int = 16
const PARTICLE_LIFETIME: float = 0.35

# ── Style colors ──
const STYLE_COLORS: Dictionary = {
	"nano": Color(0.2, 0.8, 1.0),
	"tesla": Color(1.0, 0.8, 0.2),
	"void": Color(0.6, 0.2, 1.0),
}
const DEFAULT_COLOR: Color = Color(1.0, 0.4, 0.2)

# ── Pool ──
var _pool: Array[CPUParticles3D] = []
var _pool_index: int = 0

func _ready() -> void:
	_build_pool()
	EventBus.hit_landed.connect(_on_hit_landed)

func _build_pool() -> void:
	for i: int in range(POOL_SIZE):
		var particles: CPUParticles3D = CPUParticles3D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 8
		particles.lifetime = PARTICLE_LIFETIME
		particles.speed_scale = 1.8
		# Spread outward in hemisphere
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 60.0
		particles.initial_velocity_min = 2.5
		particles.initial_velocity_max = 5.0
		particles.gravity = Vector3(0, -6.0, 0)
		particles.damping_min = 3.0
		particles.damping_max = 5.0
		# Small bright sparks
		particles.scale_amount_min = 0.04
		particles.scale_amount_max = 0.08
		# Mesh
		var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.emission_enabled = true
		spark_mat.emission_energy_multiplier = 3.0
		spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.08
		sphere.material = spark_mat
		particles.mesh = sphere
		particles.top_level = true
		add_child(particles)
		_pool.append(particles)

func _on_hit_landed(target: Node, damage: int, is_crit: bool, _attacker: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	# Only spawn sparks for enemy targets (not player taking damage)
	if target.is_in_group("player"):
		return

	var pos: Vector3 = Vector3.ZERO
	if target is Node3D:
		pos = (target as Node3D).global_position + Vector3(0, 1.0, 0)
	else:
		return

	# Determine style color from target's combat_style
	var style_color: Color = DEFAULT_COLOR
	if "combat_style" in target:
		var s: String = str(target.combat_style)
		if s in STYLE_COLORS:
			style_color = STYLE_COLORS[s]

	# Scale particle count with damage / crits
	var count: int = 8
	if is_crit:
		count = 14
	elif damage > 30:
		count = 11

	_spawn_sparks(pos, style_color, count)

func _spawn_sparks(pos: Vector3, color: Color, count: int) -> void:
	var particles: CPUParticles3D = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE

	# Stop any current emission and reconfigure
	particles.emitting = false
	particles.amount = count
	particles.global_position = pos

	# Update color on the mesh material
	var mesh: SphereMesh = particles.mesh as SphereMesh
	if mesh and mesh.material:
		var mat: StandardMaterial3D = mesh.material as StandardMaterial3D
		mat.albedo_color = color
		mat.emission = color

	particles.emitting = true
