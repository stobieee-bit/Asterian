## WeatherSystem -- Per-area atmospheric particle effects
##
## Spawns CPUParticles3D nodes that follow the player and change based on the
## current area. Each area has a unique particle configuration: dust motes for
## the Station Hub, spores for Gathering Grounds, sandstorms for Alien Wastes,
## void particles for The Abyss, rock dust for Asteroid Mines, sterile lights
## for Bio-Research Lab, and corruption particles for corrupted areas.
##
## Listens to EventBus.area_entered and smoothly transitions between effects
## using tweens. The particle emitters are children of this Node3D, which
## tracks the player position every frame.
##
## Structure:
##   WeatherSystem (Node3D)
##     +-- PrimaryParticles (CPUParticles3D) -- main ambient effect
##     +-- SecondaryParticles (CPUParticles3D) -- accent sparks/wisps
extends Node3D

# ── Constants ──

## Duration (seconds) for the cross-fade between area particle effects.
const TRANSITION_FADE_TIME: float = 0.5

## Default emission box half-extents that surround the player.
const DEFAULT_BOX_EXTENTS: Vector3 = Vector3(25.0, 12.0, 25.0)

# ── Node references ──

## Primary ambient particle emitter (dust, spores, sand, etc.)
var _primary: CPUParticles3D = null

## Secondary accent particle emitter (sparks, wisps, embers)
var _secondary: CPUParticles3D = null

## Cached reference to the player CharacterBody3D
var _player: CharacterBody3D = null

## The area_id whose weather is currently active
var _current_weather_area: String = ""

## Active transition tween (killed on re-entry to prevent overlap)
var _transition_tween: Tween = null

# ── Per-area weather configuration ──

## Configuration dictionary for each area's primary and secondary particles.
## Keys match area_id values from DataManager / GameState.
##
## Each entry is a Dictionary with two sub-keys: "primary" and "secondary".
## "secondary" may be null if the area has no accent effect.
##
## Sub-dictionary keys:
##   amount         : int    -- particle count
##   lifetime       : float  -- seconds each particle lives
##   direction      : Vector3 -- emission direction
##   velocity_min   : float  -- initial_velocity_min
##   velocity_max   : float  -- initial_velocity_max
##   gravity        : Vector3 -- per-particle gravity override
##   scale_min      : float  -- particle scale range low
##   scale_max      : float  -- particle scale range high
##   color_start    : Color  -- gradient start
##   color_end      : Color  -- gradient end (faded out alpha)
##   box_extents    : Vector3 -- emission box half-size (optional, defaults to DEFAULT_BOX_EXTENTS)
const WEATHER_CONFIGS: Dictionary = {
	# ── Station Hub: gentle floating dust motes, dim cyan ambient ──
	"station-hub": {
		"primary": {
			"amount": 80,
			"lifetime": 7.0,
			"direction": Vector3(0.2, 0.5, 0.1),
			"velocity_min": 0.1,
			"velocity_max": 0.5,
			"gravity": Vector3(0.0, 0.02, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.15,
			"color_start": Color(0.4, 0.8, 0.85, 0.4),
			"color_end": Color(0.3, 0.7, 0.8, 0.0),
		},
		"secondary": {
			"amount": 30,
			"lifetime": 5.0,
			"direction": Vector3(0.0, 0.3, 0.0),
			"velocity_min": 0.05,
			"velocity_max": 0.2,
			"gravity": Vector3(0.0, 0.01, 0.0),
			"scale_min": 0.06,
			"scale_max": 0.18,
			"color_start": Color(0.2, 0.6, 0.9, 0.25),
			"color_end": Color(0.15, 0.5, 0.8, 0.0),
		},
	},

	# ── Gathering Grounds: spore particles drifting upward, green-tinted ──
	"gathering-grounds": {
		"primary": {
			"amount": 100,
			"lifetime": 6.0,
			"direction": Vector3(0.0, 1.0, 0.0),
			"velocity_min": 0.3,
			"velocity_max": 1.0,
			"gravity": Vector3(0.0, -0.05, 0.0),
			"scale_min": 0.05,
			"scale_max": 0.18,
			"color_start": Color(0.3, 0.85, 0.25, 0.45),
			"color_end": Color(0.2, 0.7, 0.15, 0.0),
		},
		"secondary": {
			"amount": 50,
			"lifetime": 5.0,
			"direction": Vector3(0.3, 0.6, 0.2),
			"velocity_min": 0.1,
			"velocity_max": 0.4,
			"gravity": Vector3(0.0, 0.01, 0.0),
			"scale_min": 0.08,
			"scale_max": 0.25,
			"color_start": Color(0.7, 0.9, 0.7, 0.25),
			"color_end": Color(0.5, 0.8, 0.5, 0.0),
		},
	},

	# ── Alien Wastes: horizontal sand/dust storm, orange-tinted ──
	"alien-wastes": {
		"primary": {
			"amount": 150,
			"lifetime": 3.5,
			"direction": Vector3(1.0, 0.1, 0.3),
			"velocity_min": 2.0,
			"velocity_max": 5.0,
			"gravity": Vector3(0.0, -0.3, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.2,
			"color_start": Color(0.9, 0.6, 0.2, 0.5),
			"color_end": Color(0.8, 0.5, 0.15, 0.0),
			"box_extents": Vector3(30.0, 12.0, 30.0),
		},
		"secondary": {
			"amount": 60,
			"lifetime": 2.5,
			"direction": Vector3(1.2, 0.3, 0.5),
			"velocity_min": 3.0,
			"velocity_max": 6.0,
			"gravity": Vector3(0.0, -0.5, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.1,
			"color_start": Color(1.0, 0.75, 0.35, 0.35),
			"color_end": Color(0.9, 0.6, 0.25, 0.0),
			"box_extents": Vector3(30.0, 10.0, 30.0),
		},
	},

	# ── The Abyss: dark void particles drifting down, purple energy sparks ──
	"the-abyss": {
		"primary": {
			"amount": 120,
			"lifetime": 8.0,
			"direction": Vector3(0.0, -1.0, 0.0),
			"velocity_min": 0.15,
			"velocity_max": 0.6,
			"gravity": Vector3(0.0, -0.08, 0.0),
			"scale_min": 0.05,
			"scale_max": 0.22,
			"color_start": Color(0.15, 0.05, 0.2, 0.45),
			"color_end": Color(0.1, 0.02, 0.15, 0.0),
		},
		"secondary": {
			"amount": 40,
			"lifetime": 3.0,
			"direction": Vector3(0.0, 0.3, 0.0),
			"velocity_min": 0.5,
			"velocity_max": 2.0,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.1,
			"color_start": Color(0.6, 0.2, 0.9, 0.65),
			"color_end": Color(0.4, 0.1, 0.7, 0.0),
		},
	},

	# ── Asteroid Mines: rock dust falling, small ember particles ──
	"asteroid-mines": {
		"primary": {
			"amount": 120,
			"lifetime": 4.5,
			"direction": Vector3(0.1, -1.0, 0.05),
			"velocity_min": 0.5,
			"velocity_max": 1.5,
			"gravity": Vector3(0.0, -0.6, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.15,
			"color_start": Color(0.55, 0.45, 0.35, 0.5),
			"color_end": Color(0.4, 0.3, 0.2, 0.0),
		},
		"secondary": {
			"amount": 35,
			"lifetime": 3.5,
			"direction": Vector3(0.0, 0.5, 0.0),
			"velocity_min": 0.2,
			"velocity_max": 0.8,
			"gravity": Vector3(0.0, -0.1, 0.0),
			"scale_min": 0.02,
			"scale_max": 0.08,
			"color_start": Color(1.0, 0.5, 0.15, 0.55),
			"color_end": Color(0.9, 0.3, 0.05, 0.0),
		},
	},

	# ── Bio-Research Lab: sterile floating light particles, white/blue ──
	"bio-research-lab": {
		"primary": {
			"amount": 60,
			"lifetime": 9.0,
			"direction": Vector3(0.0, 0.2, 0.0),
			"velocity_min": 0.05,
			"velocity_max": 0.25,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.1,
			"color_start": Color(0.85, 0.9, 1.0, 0.3),
			"color_end": Color(0.7, 0.8, 1.0, 0.0),
		},
		"secondary": {
			"amount": 25,
			"lifetime": 6.0,
			"direction": Vector3(0.0, 0.1, 0.0),
			"velocity_min": 0.02,
			"velocity_max": 0.1,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.12,
			"color_start": Color(0.2, 0.8, 0.6, 0.2),
			"color_end": Color(0.15, 0.6, 0.4, 0.0),
		},
	},

	# ── Bio-Lab (alternate key) ──
	"bio-lab": {
		"primary": {
			"amount": 60,
			"lifetime": 9.0,
			"direction": Vector3(0.0, 0.2, 0.0),
			"velocity_min": 0.05,
			"velocity_max": 0.25,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.1,
			"color_start": Color(0.85, 0.9, 1.0, 0.3),
			"color_end": Color(0.7, 0.8, 1.0, 0.0),
		},
		"secondary": {
			"amount": 25,
			"lifetime": 6.0,
			"direction": Vector3(0.0, 0.1, 0.0),
			"velocity_min": 0.02,
			"velocity_max": 0.1,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.12,
			"color_start": Color(0.2, 0.8, 0.6, 0.2),
			"color_end": Color(0.15, 0.6, 0.4, 0.0),
		},
	},

	# ── Corrupted Hub: red/black corruption, glitchy flickering ──
	"corrupted-hub": {
		"primary": {
			"amount": 100,
			"lifetime": 4.5,
			"direction": Vector3(0.1, 0.6, -0.1),
			"velocity_min": 0.3,
			"velocity_max": 1.2,
			"gravity": Vector3(0.0, 0.05, 0.0),
			"scale_min": 0.05,
			"scale_max": 0.25,
			"color_start": Color(0.85, 0.1, 0.1, 0.55),
			"color_end": Color(0.2, 0.0, 0.0, 0.0),
		},
		"secondary": {
			"amount": 50,
			"lifetime": 2.0,
			"direction": Vector3(0.0, 0.0, 0.0),
			"velocity_min": 0.8,
			"velocity_max": 2.5,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.02,
			"scale_max": 0.09,
			"color_start": Color(0.1, 0.0, 0.0, 0.65),
			"color_end": Color(0.9, 0.05, 0.05, 0.0),
		},
	},

	# ── Corrupted Wastes: intense red/orange storm, more violent ──
	"corrupted-wastes": {
		"primary": {
			"amount": 180,
			"lifetime": 3.0,
			"direction": Vector3(1.0, 0.2, 0.4),
			"velocity_min": 3.0,
			"velocity_max": 7.0,
			"gravity": Vector3(0.0, -0.4, 0.0),
			"scale_min": 0.05,
			"scale_max": 0.22,
			"color_start": Color(0.9, 0.2, 0.05, 0.55),
			"color_end": Color(0.3, 0.0, 0.0, 0.0),
			"box_extents": Vector3(30.0, 12.0, 30.0),
		},
		"secondary": {
			"amount": 70,
			"lifetime": 2.0,
			"direction": Vector3(1.3, 0.5, 0.6),
			"velocity_min": 4.0,
			"velocity_max": 8.0,
			"gravity": Vector3(0.0, -0.6, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.12,
			"color_start": Color(0.15, 0.0, 0.0, 0.45),
			"color_end": Color(1.0, 0.15, 0.0, 0.0),
			"box_extents": Vector3(30.0, 10.0, 30.0),
		},
	},

	# ── Corrupted Abyss: intense void corruption, red-purple chaos ──
	"corrupted-abyss": {
		"primary": {
			"amount": 140,
			"lifetime": 5.5,
			"direction": Vector3(0.0, -1.0, 0.0),
			"velocity_min": 0.3,
			"velocity_max": 1.2,
			"gravity": Vector3(0.0, -0.15, 0.0),
			"scale_min": 0.06,
			"scale_max": 0.3,
			"color_start": Color(0.5, 0.0, 0.15, 0.55),
			"color_end": Color(0.15, 0.0, 0.05, 0.0),
		},
		"secondary": {
			"amount": 55,
			"lifetime": 2.5,
			"direction": Vector3(0.0, 0.5, 0.0),
			"velocity_min": 1.0,
			"velocity_max": 3.0,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.12,
			"color_start": Color(0.9, 0.05, 0.3, 0.75),
			"color_end": Color(0.5, 0.0, 0.6, 0.0),
		},
	},

	# ── Corrupted Lab: toxic green-red corruption ──
	"corrupted-lab": {
		"primary": {
			"amount": 80,
			"lifetime": 5.0,
			"direction": Vector3(0.0, 0.4, 0.0),
			"velocity_min": 0.2,
			"velocity_max": 0.7,
			"gravity": Vector3(0.0, 0.02, 0.0),
			"scale_min": 0.04,
			"scale_max": 0.15,
			"color_start": Color(0.6, 0.15, 0.1, 0.4),
			"color_end": Color(0.2, 0.05, 0.0, 0.0),
		},
		"secondary": {
			"amount": 25,
			"lifetime": 3.0,
			"direction": Vector3(0.0, 0.2, 0.0),
			"velocity_min": 0.1,
			"velocity_max": 0.4,
			"gravity": Vector3(0.0, 0.0, 0.0),
			"scale_min": 0.03,
			"scale_max": 0.1,
			"color_start": Color(0.3, 0.7, 0.2, 0.3),
			"color_end": Color(0.1, 0.3, 0.05, 0.0),
		},
	},
}

# ── Lifecycle ──

func _ready() -> void:
	_create_particle_nodes()
	EventBus.area_entered.connect(_on_area_entered)

	# Wait one frame for the player to be spawned, then apply initial weather
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if GameState.current_area != "":
		_apply_weather(GameState.current_area)


func _process(_delta: float) -> void:
	# Keep particles centered on the player
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return
	global_position = _player.global_position


# ── Node setup ──

## Create the two CPUParticles3D children used for all area effects.
## They start with emitting = false until the first area transition.
func _create_particle_nodes() -> void:
	_primary = CPUParticles3D.new()
	_primary.name = "PrimaryParticles"
	_primary.emitting = false
	_primary.one_shot = false
	_primary.local_coords = false
	add_child(_primary)

	_secondary = CPUParticles3D.new()
	_secondary.name = "SecondaryParticles"
	_secondary.emitting = false
	_secondary.one_shot = false
	_secondary.local_coords = false
	add_child(_secondary)


# ── Signal handlers ──

## Called when the player enters a new area. Triggers a smooth transition
## from the current weather to the new area's weather.
func _on_area_entered(area_id: String) -> void:
	if area_id == _current_weather_area:
		return
	_transition_to_weather(area_id)


# ── Weather transitions ──

## Smoothly transitions from current particles to the target area's weather.
## Stops current emitters, waits, then configures and starts the new effect.
func _transition_to_weather(area_id: String) -> void:
	# Kill any in-progress transition to prevent overlapping tweens
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_LINEAR)

	# Phase 1: Fade out -- stop emitting and wait for particles to dissipate
	_primary.emitting = false
	_secondary.emitting = false

	_transition_tween.tween_interval(TRANSITION_FADE_TIME)

	# Phase 2: Configure and enable the new weather
	_transition_tween.tween_callback(_apply_weather.bind(area_id))


## Immediately configures both particle emitters for the given area and
## starts emission. Called directly for the initial area and as a tween
## callback during transitions.
func _apply_weather(area_id: String) -> void:
	_current_weather_area = area_id

	if not WEATHER_CONFIGS.has(area_id):
		# Unknown area -- disable particles silently
		_primary.emitting = false
		_secondary.emitting = false
		return

	var config: Dictionary = WEATHER_CONFIGS[area_id]

	# Configure primary emitter
	var primary_cfg: Variant = config.get("primary", null)
	if primary_cfg != null and primary_cfg is Dictionary:
		_configure_emitter(_primary, primary_cfg as Dictionary)
		_primary.emitting = true
	else:
		_primary.emitting = false

	# Configure secondary emitter
	var secondary_cfg: Variant = config.get("secondary", null)
	if secondary_cfg != null and secondary_cfg is Dictionary:
		_configure_emitter(_secondary, secondary_cfg as Dictionary)
		_secondary.emitting = true
	else:
		_secondary.emitting = false

	print("WeatherSystem: Applied weather for '%s'" % area_id)


## Applies a configuration dictionary to a CPUParticles3D node.
## Sets emission shape, direction, velocity, gravity, scale, and color ramp.
func _configure_emitter(emitter: CPUParticles3D, cfg: Dictionary) -> void:
	# Particle count and lifetime
	emitter.amount = int(cfg.get("amount", 30))
	emitter.lifetime = float(cfg.get("lifetime", 4.0))
	emitter.explosiveness = 0.0
	emitter.randomness = 0.5

	# Emission shape -- box surrounding the player
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var extents: Vector3 = cfg.get("box_extents", DEFAULT_BOX_EXTENTS) as Vector3
	emitter.emission_box_extents = extents

	# Direction and spread
	var dir: Vector3 = cfg.get("direction", Vector3.UP) as Vector3
	emitter.direction = dir
	emitter.spread = 25.0

	# Velocity
	emitter.initial_velocity_min = float(cfg.get("velocity_min", 0.2))
	emitter.initial_velocity_max = float(cfg.get("velocity_max", 0.8))

	# Gravity
	var grav: Vector3 = cfg.get("gravity", Vector3.ZERO) as Vector3
	emitter.gravity = grav

	# Scale
	emitter.scale_amount_min = float(cfg.get("scale_min", 0.05))
	emitter.scale_amount_max = float(cfg.get("scale_max", 0.15))

	# Mesh — CPUParticles3D uses the `mesh` property (not draw_pass_1)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	# Material — unshaded billboard with alpha transparency
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mat.render_priority = -1
	quad.surface_set_material(0, mat)

	emitter.mesh = quad

	# Color ramp gradient (start color -> faded end color)
	var color_start: Color = cfg.get("color_start", Color(1.0, 1.0, 1.0, 0.4)) as Color
	var color_end: Color = cfg.get("color_end", Color(1.0, 1.0, 1.0, 0.0)) as Color

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	emitter.color_ramp = gradient

	# Also set the base color to the start color for a consistent look
	emitter.color = Color(1.0, 1.0, 1.0, 1.0)
