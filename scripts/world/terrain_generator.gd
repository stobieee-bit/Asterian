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

## Pre-register an area's noise and geometry data without building a mesh.
## Must be called for ALL areas before generate_area_terrain() so the generator
## knows the full world layout and can suppress overlapping vertices.
func register_area(area_id: String, cx: float, cz: float, radius: float,
		floor_y: float, terrain_params: Dictionary) -> void:
	if _area_data.has(area_id):
		return  # Already registered
	var amplitude: float = float(terrain_params.get("amplitude", 1.0))
	var frequency: float = float(terrain_params.get("frequency", 0.02))
	var seed_val: int = int(terrain_params.get("seed", hash(area_id) % 99999))
	var octaves: int = int(terrain_params.get("octaves", 3))
	var lacunarity: float = float(terrain_params.get("lacunarity", 2.0))
	var gain: float = float(terrain_params.get("gain", 0.5))
	var falloff_start: float = float(terrain_params.get("edgeFalloffStart", 0.7))

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_val
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain
	_noise_map[area_id] = noise

	_area_data[area_id] = {
		"cx": cx, "cz": cz, "radius": radius,
		"amplitude": amplitude, "floor_y": floor_y,
		"falloff_start": falloff_start
	}


## Generate terrain mesh + collision for one area.
## Returns { "mesh_instance": MeshInstance3D, "static_body": StaticBody3D }
## All areas must be registered via register_area() first for overlap awareness.
func generate_area_terrain(area_id: String, cx: float, cz: float, radius: float,
		floor_y: float, base_color: Color, terrain_params: Dictionary) -> Dictionary:

	# Register if not already done (backward compatibility)
	register_area(area_id, cx, cz, radius, floor_y, terrain_params)

	var amplitude: float = _area_data[area_id]["amplitude"]
	var falloff_start: float = _area_data[area_id]["falloff_start"]
	var noise: FastNoiseLite = _noise_map[area_id]

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
#  OVERLAP SUPPRESSION
# ═══════════════════════════════════════════════════════════════════════════════

## For a vertex at (wx, wz) belonging to area_id, returns:
## - 0.0 = inside a smaller (higher-priority) area → suppress vertex entirely
## - 1.0 = outside all smaller areas → keep vertex as-is
## Binary suppression: no partial blending. The smaller area's own edge falloff
## handles smooth visual transitions naturally.
## Uses "smaller radius wins" rule (same as get_height). Ties broken by area_id.
func _get_overlap_factor(area_id: String, wx: float, wz: float) -> float:
	var my_data: Dictionary = _area_data[area_id]
	var my_radius: float = my_data["radius"]

	for other_id in _area_data:
		if other_id == area_id:
			continue
		var other: Dictionary = _area_data[other_id]
		var other_radius: float = other["radius"]

		# Only suppress if the OTHER area is smaller (higher priority)
		# Tie-break: smaller area_id string wins priority
		if other_radius > my_radius:
			continue
		if other_radius == my_radius and other_id >= area_id:
			continue

		# Distance from this vertex to the other area's center
		var dx: float = wx - other["cx"]
		var dz: float = wz - other["cz"]
		var dist: float = sqrt(dx * dx + dz * dz)

		# Inside the other area — fully suppress (binary: no blend margin)
		if dist <= other_radius:
			return 0.0

	return 1.0


## Get the terrain height of the highest-priority (smallest) area at (wx, wz),
## EXCLUDING the given area_id. Used to snap suppressed vertices flush with
## the area that's taking priority over them.
func _get_priority_height(excluded_area_id: String, wx: float, wz: float) -> float:
	var best_area: String = ""
	var best_radius: float = INF

	for area_id in _area_data:
		if area_id == excluded_area_id:
			continue
		var data: Dictionary = _area_data[area_id]
		var dx: float = wx - data["cx"]
		var dz: float = wz - data["cz"]
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist <= data["radius"] and data["radius"] < best_radius:
			best_radius = data["radius"]
			best_area = area_id

	if best_area == "":
		return 0.0  # Shouldn't happen — only called when inside another area

	return get_height_in_area(best_area, wx, wz)


# ═══════════════════════════════════════════════════════════════════════════════
#  MESH GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_circular_mesh(area_id: String, cx: float, cz: float, radius: float,
		floor_y: float, base_color: Color, noise: FastNoiseLite,
		amplitude: float, falloff_start: float,
		ring_count: int, segment_count: int) -> Dictionary:

	# ── Generate all vertices + colors + overlap factors ──
	var vertices: Array[Vector3] = []
	var colors: Array[Color] = []
	var overlaps: Array[float] = []  # Track per-vertex overlap for collision/visual filtering

	# Center vertex — apply overlap suppression
	var center_h: float = _sample_height(cx, cz, noise, amplitude, cx, cz, radius, falloff_start)
	var center_overlap: float = _get_overlap_factor(area_id, cx, cz)
	overlaps.append(center_overlap)
	if center_overlap < 1.0:
		# Inside a priority area — snap to its height (vertex won't be rendered)
		var priority_y: float = _get_priority_height(area_id, cx, cz)
		vertices.append(Vector3(cx, priority_y, cz))
		colors.append(Color(base_color, 0.0))
	else:
		vertices.append(Vector3(cx, floor_y + center_h, cz))
		colors.append(_height_color(base_color, center_h, amplitude))

	# Ring vertices (ring 1 .. ring_count) — with overlap suppression
	for ring in range(1, ring_count + 1):
		var ring_frac: float = float(ring) / float(ring_count)
		var ring_radius: float = radius * ring_frac
		for seg in range(segment_count):
			var angle: float = float(seg) / float(segment_count) * TAU
			var vx: float = cx + cos(angle) * ring_radius
			var vz: float = cz + sin(angle) * ring_radius
			var h: float = _sample_height(vx, vz, noise, amplitude, cx, cz, radius, falloff_start)
			var overlap: float = _get_overlap_factor(area_id, vx, vz)
			overlaps.append(overlap)
			if overlap < 1.0:
				# Inside a priority area — snap to its height (vertex won't be rendered)
				var priority_y: float = _get_priority_height(area_id, vx, vz)
				vertices.append(Vector3(vx, priority_y, vz))
				colors.append(Color(base_color, 0.0))
			else:
				# Outside all priority areas — full height
				vertices.append(Vector3(vx, floor_y + h, vz))
				colors.append(_height_color(base_color, h, amplitude))

	# ── Build triangles using SurfaceTool (skip fully-suppressed triangles) ──
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Center fan: center vertex -> first ring
	for seg in range(segment_count):
		var next_seg: int = (seg + 1) % segment_count
		var i0: int = 0              # center
		var i1: int = 1 + seg        # ring 1, current segment
		var i2: int = 1 + next_seg   # ring 1, next segment

		# Skip triangle if ANY vertex is suppressed (inside a priority area)
		if overlaps[i0] < 1.0 or overlaps[i1] < 1.0 or overlaps[i2] < 1.0:
			continue

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

			# Triangle 1 — skip if any vertex is inside a priority area
			if overlaps[i0] >= 1.0 and overlaps[i2] >= 1.0 and overlaps[i1] >= 1.0:
				st.set_color(colors[i0])
				st.set_normal(Vector3.UP)
				st.add_vertex(vertices[i0])

				st.set_color(colors[i2])
				st.set_normal(Vector3.UP)
				st.add_vertex(vertices[i2])

				st.set_color(colors[i1])
				st.set_normal(Vector3.UP)
				st.add_vertex(vertices[i1])

			# Triangle 2 — skip if any vertex is inside a priority area
			if overlaps[i1] >= 1.0 and overlaps[i2] >= 1.0 and overlaps[i3] >= 1.0:
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

	# ── Build collision face array, SKIPPING suppressed triangles ──
	# Triangles with any suppressed vertex (overlap < 1.0) are omitted from
	# collision. The smaller (priority) area's collision mesh covers that zone.
	var faces := PackedVector3Array()

	# Center fan faces — skip if any vertex is suppressed
	for seg in range(segment_count):
		var next_seg: int = (seg + 1) % segment_count
		var i0: int = 0
		var i1: int = 1 + seg
		var i2: int = 1 + next_seg
		if overlaps[i0] < 1.0 or overlaps[i1] < 1.0 or overlaps[i2] < 1.0:
			continue
		faces.append(vertices[i0])
		faces.append(vertices[i1])
		faces.append(vertices[i2])

	# Ring quad faces — skip triangles with any suppressed vertex
	for ring in range(1, ring_count):
		var base_idx: int = 1 + (ring - 1) * segment_count
		var next_base: int = 1 + ring * segment_count
		for seg in range(segment_count):
			var next_seg: int = (seg + 1) % segment_count
			var i0: int = base_idx + seg
			var i1: int = base_idx + next_seg
			var i2: int = next_base + seg
			var i3: int = next_base + next_seg
			# Tri 1 — only if all vertices are outside priority areas
			if overlaps[i0] >= 1.0 and overlaps[i2] >= 1.0 and overlaps[i1] >= 1.0:
				faces.append(vertices[i0])
				faces.append(vertices[i2])
				faces.append(vertices[i1])
			# Tri 2 — only if all vertices are outside priority areas
			if overlaps[i1] >= 1.0 and overlaps[i2] >= 1.0 and overlaps[i3] >= 1.0:
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
