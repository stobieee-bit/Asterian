## FloatText — Manages floating damage numbers, XP text, and hit splats
##
## Listens to EventBus.float_text_requested and spawns pooled Label3D nodes
## that float upward with jitter and fade out.
## Features:
##   - Random horizontal jitter to avoid text overlap
##   - Hit splat styling: damage (red), heal (green), miss (gray), crit (orange)
##   - Scale pulse for crits and level-ups
##   - Staggered Y offset when multiple texts spawn at same position
extends Node3D

# ── Pool ──
var _pool: Array[Label3D] = []
var _pool_size: int = 30
var _next_index: int = 0

# ── Active texts ──
var _active: Array[Dictionary] = []

# ── Jitter/collision avoidance ──
## Track recent spawn positions to stagger overlapping texts
var _recent_spawns: Array[Dictionary] = []  # {pos, time}
const OVERLAP_RADIUS: float = 1.5    # How close counts as "same spot"
const OVERLAP_WINDOW: float = 0.4    # Seconds to check for overlap
const JITTER_RANGE: float = 0.6      # Random horizontal offset

func _ready() -> void:
	# Build pool of Label3D nodes
	for i in range(_pool_size):
		var label: Label3D = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 28
		label.outline_size = 6
		label.visible = false
		label.top_level = true
		add_child(label)
		_pool.append(label)

	# Connect to signal
	EventBus.float_text_requested.connect(_on_float_text_requested)

func _process(delta: float) -> void:
	# Clean old recent spawns
	var now: float = Time.get_ticks_msec() / 1000.0
	var j: int = _recent_spawns.size() - 1
	while j >= 0:
		if now - float(_recent_spawns[j]["time"]) > OVERLAP_WINDOW:
			_recent_spawns.remove_at(j)
		j -= 1

	# Update active float texts
	var i: int = _active.size() - 1
	while i >= 0:
		var entry: Dictionary = _active[i]
		var label: Label3D = entry["label"]
		entry["time"] += delta

		var t: float = entry["time"]
		var duration: float = entry["duration"]
		var progress: float = t / duration

		if progress >= 1.0:
			# Done — hide and recycle
			label.visible = false
			_active.remove_at(i)
		else:
			# Float upward with slight arc from jitter
			var start_pos: Vector3 = entry["start_pos"]
			var jitter_x: float = entry.get("jitter_x", 0.0)
			var jitter_z: float = entry.get("jitter_z", 0.0)

			# Parabolic horizontal drift (starts from jitter, drifts further)
			var drift: float = t * 0.3
			var y_offset: float = t * 2.0 + entry.get("y_boost", 0.0)

			label.global_position = start_pos + Vector3(
				jitter_x + jitter_x * drift,
				y_offset,
				jitter_z + jitter_z * drift
			)

			# Fade out in last 35%
			if progress > 0.65:
				var fade: float = 1.0 - (progress - 0.65) / 0.35
				label.modulate.a = fade
			else:
				label.modulate.a = 1.0

			# Scale animation for crits and level-ups
			if entry.get("is_crit", false):
				# Crits: punchy scale-up then settle
				var scale_val: float
				if progress < 0.15:
					# Quick scale up
					scale_val = 1.0 + (progress / 0.15) * 0.5
				elif progress < 0.3:
					# Settle back
					scale_val = 1.5 - ((progress - 0.15) / 0.15) * 0.3
				else:
					scale_val = 1.2
				label.font_size = int(entry.get("base_font_size", 36) * scale_val)
			elif entry.get("is_large", false):
				# Level-ups: gentle pulse
				var scale_val: float = 1.0 + sin(progress * PI) * 0.3
				label.font_size = int(entry.get("base_font_size", 36) * scale_val)

		i -= 1

func _on_float_text_requested(text: String, world_pos: Vector3, color: Color) -> void:
	var label: Label3D = _pool[_next_index]
	_next_index = (_next_index + 1) % _pool_size

	# Categorize the text type for styling
	var is_damage: bool = text.begins_with("-") or (text.length() > 0 and text[0].is_valid_int() and not text.contains("+"))
	var is_heal: bool = text.begins_with("+") and (text.contains("HP") or color.g > 0.7)
	var is_miss: bool = text.to_lower().contains("miss") or text.to_lower().contains("block")
	var is_crit: bool = text.ends_with("!") and not text.contains("Level")
	var is_large: bool = text.ends_with("!") or text.contains("Level")
	var is_xp: bool = text.contains("XP")

	# ── Jitter: offset horizontally to avoid overlap ──
	var jitter_x: float = randf_range(-JITTER_RANGE, JITTER_RANGE)
	var jitter_z: float = randf_range(-JITTER_RANGE * 0.3, JITTER_RANGE * 0.3)

	# Check how many recent texts spawned at roughly the same position
	var now: float = Time.get_ticks_msec() / 1000.0
	var overlap_count: int = 0
	for recent in _recent_spawns:
		var rpos: Vector3 = recent["pos"]
		var rtime: float = float(recent["time"])
		if now - rtime < OVERLAP_WINDOW and world_pos.distance_to(rpos) < OVERLAP_RADIUS:
			overlap_count += 1

	# Stagger Y based on overlap count (prevents stacking)
	var y_boost: float = overlap_count * 0.6

	# Record this spawn
	_recent_spawns.append({"pos": world_pos, "time": now})

	# ── Font size and style ──
	var base_font_size: int = 28
	var outline_size: int = 6

	if is_crit:
		base_font_size = 38
		outline_size = 8
	elif is_large:
		base_font_size = 36
		outline_size = 7
	elif is_miss:
		base_font_size = 22
		outline_size = 4
	elif is_xp:
		base_font_size = 22
		outline_size = 4

	# ── Configure label ──
	label.text = text
	label.modulate = color
	label.global_position = world_pos + Vector3(jitter_x, y_boost, jitter_z)
	label.visible = true
	label.font_size = base_font_size
	label.outline_size = outline_size

	# Outline color: darker version of main color for readability
	label.outline_modulate = Color(0, 0, 0, 0.8)

	# ── Duration ──
	var duration: float = 1.0
	if is_crit:
		duration = 1.6
	elif is_large:
		duration = 1.5
	elif is_miss:
		duration = 0.7
	elif is_xp:
		duration = 1.3

	_active.append({
		"label": label,
		"start_pos": world_pos + Vector3(jitter_x, y_boost, jitter_z),
		"time": 0.0,
		"duration": duration,
		"is_large": is_large,
		"is_crit": is_crit,
		"jitter_x": jitter_x,
		"jitter_z": jitter_z,
		"y_boost": y_boost,
		"base_font_size": base_font_size,
	})
