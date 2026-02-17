## TerrainGenerator — Procedural noise-based mesh terrain for circular areas
##
## Generates terrain meshes using SurfaceTool + FastNoiseLite with:
## - Polar grid geometry (concentric rings + angular segments)
## - Per-area noise params (seed, frequency, amplitude, octaves)
## - Edge falloff so terrain tapers to flat at area boundaries
## - Vertex colors derived from groundColor + height variation
## - ConcavePolygonShape3D collision matching the visual mesh
## - get_height(x, z) API for any system to query terrain Y at a world position
class_name TerrainGenerator
extends RefCounted

# ── Cached data for height queries ──
var _noise_map: Dictionary = {}    # area_id -> FastNoiseLite
var _area_data: Dictionary = {}    # area_id -> { cx, cz, radius, amplitude, floor_y, falloff_start }

# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Generate terrain mesh + collision for one area.
## Returns { "mesh_instance": MeshInstance3D, "static_body": StaticBody3D }
func generate_area_terrain(area_id: String, cx: float, cz: float, radius: float,
		floor_y: float, base_color: Color, terrain_params: Dictionary) -> Dictionary:

	var amplitude: float = float(terrain_params.get("amplitude", 1.0))
	var frequency: float = float(terrain_params.get("frequency", 0.02))
	var seed_val: int = int(terrain_params.get("seed", hash(area_id) % 99999))
	var octaves: int = int(terrain_params.get("octaves", 3))
	var lacunarity: float = float(terrain_params.get("lacunarity", 2.0))
	var gain: float = float(terrain_params.get("gain", 0.5))
	var falloff_start: float = float(terrain_params.get("edgeFalloffStart", 0.7))

	# Create and cache noise instance
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_val
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain
	_noise_map[area_id] = noise

	# Cache area data for height queries
	_area_data[area_id] = {
		"cx": cx, "cz": cz, "radius": radius,
		"amplitude": amplitude, "floor_y": floor_y,
		"falloff_start": falloff_start
	}

	# Determine mesh resolution based on area size
	var ring_count: int
	var segment_count: int
	if radius < 60.0:
		ring_count = 20
		segment_count = 32
	elif radius < 200.0:
		ring_count = 40
		segment_count = 48
	else:
		ring_count = 60
		segment_count = 64

	# Build the mesh
	var mesh_data: Dictionary = _build_circular_mesh(
		area_id, cx, cz, radius, floor_y, base_color,
		noise, amplitude, falloff_start, ring_count, segment_count)

	# Visual mesh
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Terrain_%s" % area_id
	mesh_inst.mesh = mesh_data["mesh"]
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Material
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	mat.metallic = 0.35
	mat.emission_enabled = true
	mat.emission = base_color.lightened(0.3)
	mat.emission_energy_multiplier = 0.2
	mesh_inst.material_override = mat

	# Collision
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCol_%s" % area_id
	static_body.collision_layer = 1
	var col_shape := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh_data["faces"])
	col_shape.shape = shape
	static_body.add_child(col_shape)

	return { "mesh_instance": mesh_inst, "static_body": static_body }


## Query terrain height at any world XZ position.
## Returns the Y coordinate on the terrain surface.
func get_height(world_x: float, world_z: float) -> float:
	# Find the smallest containing area (most specific)
	var best_area: String = ""
	var best_radius: float = INF

	for area_id in _area_data:
		var data: Dictionary = _area_data[area_id]
		var dx: float = world_x - data["cx"]
		var dz: float = world_z - data["cz"]
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist <= data["radius"] and data["radius"] < best_radius:
			best_radius = data["radius"]
			best_area = area_id

	if best_area == "":
		return 0.0  # Outside all areas

	return get_height_in_area(best_area, world_x, world_z)


## Check if a world XZ position is inside any registered terrain area.
func is_inside_area(world_x: float, world_z: float) -> bool:
	for area_id in _area_data:
		var data: Dictionary = _area_data[area_id]
		var dx: float = world_x - data["cx"]
		var dz: float = world_z - data["cz"]
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist <= data["radius"]:
			return true
	return false


## Query height for a specific known area (faster — skips area lookup).
func get_height_in_area(area_id: String, world_x: float, world_z: float) -> float:
	if not _area_data.has(area_id) or not _noise_map.has(area_id):
		return 0.0
	var data: Dictionary = _area_data[area_id]
	var noise: FastNoiseLite = _noise_map[area_id]
	return data["floor_y"] + _sample_height(
		world_x, world_z, noise, data["amplitude"],
		data["cx"], data["cz"], data["radius"], data["falloff_start"])


# ═══════════════════════════════════════════════════════════════════════════════
#  MESH GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_circular_mesh(area_id: String, cx: float, cz: float, radius: float,
		floor_y: float, base_color: Color, noise: FastNoiseLite,
		amplitude: float, falloff_start: float,
		ring_count: int, segment_count: int) -> Dictionary:

	# ── Generate all vertices + colors ──
	var vertices: Array[Vector3] = []
	var colors: Array[Color] = []

	# Center vertex
	var center_h: float = _sample_height(cx, cz, noise, amplitude, cx, cz, radius, falloff_start)
	vertices.append(Vector3(cx, floor_y + center_h, cz))
	colors.append(_height_color(base_color, center_h, amplitude))

	# Ring vertices (ring 1 .. ring_count)
	for ring in range(1, ring_count + 1):
		var ring_frac: float = float(ring) / float(ring_count)
		var ring_radius: float = radius * ring_frac
		for seg in range(segment_count):
			var angle: float = float(seg) / float(segment_count) * TAU
			var vx: float = cx + cos(angle) * ring_radius
			var vz: float = cz + sin(angle) * ring_radius
			var h: float = _sample_height(vx, vz, noise, amplitude, cx, cz, radius, falloff_start)
			vertices.append(Vector3(vx, floor_y + h, vz))
			colors.append(_height_color(base_color, h, amplitude))

	# ── Build triangles using SurfaceTool ──
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Center fan: center vertex -> first ring
	for seg in range(segment_count):
		var next_seg: int = (seg + 1) % segment_count
		var i0: int = 0              # center
		var i1: int = 1 + seg        # ring 1, current segment
		var i2: int = 1 + next_seg   # ring 1, next segment

		st.set_color(colors[i0])
		st.set_normal(Vector3.UP)
		st.add_vertex(vertices[i0])

		st.set_color(colors[i1])
		st.set_normal(Vector3.UP)
		st.add_vertex(vertices[i1])

		st.set_color(colors[i2])
		st.set_normal(Vector3.UP)
		st.add_vertex(vertices[i2])

	# Ring quads: ring r -> ring r+1
	for ring in range(1, ring_count):
		var base_idx: int = 1 + (ring - 1) * segment_count
		var next_base: int = 1 + ring * segment_count
		for seg in range(segment_count):
			var next_seg: int = (seg + 1) % segment_count
			var i0: int = base_idx + seg
			var i1: int = base_idx + next_seg
			var i2: int = next_base + seg
			var i3: int = next_base + next_seg

			# Triangle 1
			st.set_color(colors[i0])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i0])

			st.set_color(colors[i2])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i2])

			st.set_color(colors[i1])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i1])

			# Triangle 2
			st.set_color(colors[i1])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i1])

			st.set_color(colors[i2])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i2])

			st.set_color(colors[i3])
			st.set_normal(Vector3.UP)
			st.add_vertex(vertices[i3])

	# Generate proper normals from geometry
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	# ── Build collision face array from the same vertices ──
	var faces := PackedVector3Array()

	# Center fan faces
	for seg in range(segment_count):
		var next_seg: int = (seg + 1) % segment_count
		faces.append(vertices[0])
		faces.append(vertices[1 + seg])
		faces.append(vertices[1 + next_seg])

	# Ring quad faces
	for ring in range(1, ring_count):
		var base_idx: int = 1 + (ring - 1) * segment_count
		var next_base: int = 1 + ring * segment_count
		for seg in range(segment_count):
			var next_seg: int = (seg + 1) % segment_count
			var i0: int = base_idx + seg
			var i1: int = base_idx + next_seg
			var i2: int = next_base + seg
			var i3: int = next_base + next_seg
			# Tri 1
			faces.append(vertices[i0])
			faces.append(vertices[i2])
			faces.append(vertices[i1])
			# Tri 2
			faces.append(vertices[i1])
			faces.append(vertices[i2])
			faces.append(vertices[i3])

	return { "mesh": mesh, "faces": faces }


# ═══════════════════════════════════════════════════════════════════════════════
#  HEIGHT SAMPLING
# ═══════════════════════════════════════════════════════════════════════════════

## Sample terrain height at a world XZ position with edge falloff.
func _sample_height(world_x: float, world_z: float, noise: FastNoiseLite,
		amplitude: float, cx: float, cz: float, radius: float,
		falloff_start: float) -> float:
	# Distance fraction from area center (0 at center, 1 at edge)
	var dx: float = world_x - cx
	var dz: float = world_z - cz
	var dist_frac: float = sqrt(dx * dx + dz * dz) / radius

	# Smooth falloff: full height inside falloff_start, tapers to 0 at edge
	var falloff: float = 1.0 - smoothstep(falloff_start, 1.0, dist_frac)

	# Sample noise (-1 to 1 range)
	var raw: float = noise.get_noise_2d(world_x, world_z)

	return raw * amplitude * falloff


## Derive vertex color from base color + height (lighter = higher, darker = lower).
func _height_color(base_color: Color, height: float, amplitude: float) -> Color:
	if amplitude < 0.01:
		return base_color
	var t: float = clampf(height / amplitude, -1.0, 1.0) * 0.5 + 0.5  # 0..1
	# Darken valleys slightly, lighten hills
	return base_color.lerp(base_color.lightened(0.15), t)
