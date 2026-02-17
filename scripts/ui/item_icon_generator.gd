class_name ItemIconGenerator
## Procedural 16x16 pixel art icon generator for sci-fi RPG items.
## Icons are drawn at 16x16, cached as ImageTexture, displayed via TextureRect
## with NEAREST filtering (set globally in project.godot).
extends RefCounted

# ── Caches ──
static var _cache: Dictionary = {}
static var _slot_cache: Dictionary = {}
static var _type_cache: Dictionary = {}
static var _ability_cache: Dictionary = {}
static var _skill_cache: Dictionary = {}
static var _buff_cache: Dictionary = {}

const S: int = 16  # Icon size

# ── Sci-Fi Color Palette ──
const C_CYAN: Color      = Color(0.0, 0.85, 0.95)
const C_TEAL: Color      = Color(0.0, 0.7, 0.65)
const C_BLUE: Color      = Color(0.3, 0.5, 0.85)
const C_NAVY: Color      = Color(0.15, 0.25, 0.55)
const C_RED: Color       = Color(0.85, 0.15, 0.15)
const C_CRIMSON: Color   = Color(0.6, 0.08, 0.12)
const C_ORANGE: Color    = Color(0.9, 0.55, 0.1)
const C_AMBER: Color     = Color(0.75, 0.45, 0.05)
const C_GREEN: Color     = Color(0.2, 0.8, 0.3)
const C_DGREEN: Color    = Color(0.1, 0.5, 0.15)
const C_PURPLE: Color    = Color(0.6, 0.2, 0.85)
const C_DPURPLE: Color   = Color(0.35, 0.1, 0.5)
const C_GOLD: Color      = Color(0.95, 0.8, 0.2)
const C_DGOLD: Color     = Color(0.65, 0.5, 0.1)
const C_PINK: Color      = Color(0.9, 0.4, 0.6)
const C_WHITE: Color     = Color(0.95, 0.95, 0.97)
const C_LGRAY: Color     = Color(0.65, 0.68, 0.72)
const C_GRAY: Color      = Color(0.4, 0.42, 0.48)
const C_DGRAY: Color     = Color(0.2, 0.22, 0.28)
const C_BLACK: Color     = Color(0.05, 0.06, 0.08)
const C_BROWN: Color     = Color(0.5, 0.35, 0.2)
const C_DBROWN: Color    = Color(0.3, 0.2, 0.1)
const C_NCYAN: Color     = Color(0.3, 1.0, 1.0)
const C_NGREEN: Color    = Color(0.3, 1.0, 0.4)

# ═══════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════

static func get_texture(icon_name: String, item_type: String = "") -> ImageTexture:
	if icon_name != "" and _cache.has(icon_name):
		return _cache[icon_name]
	if icon_name != "":
		var img: Image = _generate(icon_name)
		if img != null:
			var tex: ImageTexture = _to_texture(img)
			_cache[icon_name] = tex
			return tex
	return get_type_texture(item_type)

static func get_slot_texture(slot_name: String) -> ImageTexture:
	if _slot_cache.has(slot_name):
		return _slot_cache[slot_name]
	var img: Image = _generate_slot(slot_name)
	var tex: ImageTexture = _to_texture(img)
	_slot_cache[slot_name] = tex
	return tex

static func get_type_texture(item_type: String) -> ImageTexture:
	if item_type == "":
		item_type = "_default"
	if _type_cache.has(item_type):
		return _type_cache[item_type]
	var img: Image = _generate_type(item_type)
	var tex: ImageTexture = _to_texture(img)
	_type_cache[item_type] = tex
	return tex

static func get_ability_texture(ability_id: String) -> ImageTexture:
	if _ability_cache.has(ability_id):
		return _ability_cache[ability_id]
	var img: Image = _generate_ability(ability_id)
	if img == null:
		img = _generate_ability("_default")
	var tex: ImageTexture = _to_texture(img)
	_ability_cache[ability_id] = tex
	return tex

static func get_skill_texture(skill_id: String) -> ImageTexture:
	if _skill_cache.has(skill_id):
		return _skill_cache[skill_id]
	var img: Image = _generate_skill(skill_id)
	if img == null:
		img = _generate_skill("_default")
	var tex: ImageTexture = _to_texture(img)
	_skill_cache[skill_id] = tex
	return tex

static func get_buff_texture(buff_type: String) -> ImageTexture:
	if _buff_cache.has(buff_type):
		return _buff_cache[buff_type]
	var img: Image = _generate_buff(buff_type)
	if img == null:
		img = _generate_buff("_default")
	var tex: ImageTexture = _to_texture(img)
	_buff_cache[buff_type] = tex
	return tex

static func get_misc_texture(icon_id: String) -> ImageTexture:
	var key: String = "misc_" + icon_id
	if _cache.has(key):
		return _cache[key]
	var img: Image = _generate_misc(icon_id)
	if img == null:
		return get_type_texture("")
	var tex: ImageTexture = _to_texture(img)
	_cache[key] = tex
	return tex

static func clear_cache() -> void:
	_cache.clear()
	_slot_cache.clear()
	_type_cache.clear()
	_ability_cache.clear()
	_skill_cache.clear()
	_buff_cache.clear()

# ═══════════════════════════════════════════
#  DRAWING PRIMITIVES
# ═══════════════════════════════════════════

static func _img() -> Image:
	return Image.create(S, S, false, Image.FORMAT_RGBA8)

static func _px(i: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < S and y >= 0 and y < S:
		i.set_pixel(x, y, c)

static func _rect(i: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			_px(i, x + dx, y + dy, c)

static func _orect(i: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_hline(i, x, y, w, c)
	_hline(i, x, y + h - 1, w, c)
	_vline(i, x, y, h, c)
	_vline(i, x + w - 1, y, h, c)

static func _hline(i: Image, x: int, y: int, l: int, c: Color) -> void:
	for dx in range(l):
		_px(i, x + dx, y, c)

static func _vline(i: Image, x: int, y: int, l: int, c: Color) -> void:
	for dy in range(l):
		_px(i, x, y + dy, c)

static func _circle(i: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_px(i, cx + dx, cy + dy, c)

static func _circle_outline(i: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			var d: int = dx * dx + dy * dy
			if d >= (r - 1) * (r - 1) and d <= (r + 1) * (r + 1):
				_px(i, cx + dx, cy + dy, c)

static func _to_texture(i: Image) -> ImageTexture:
	return ImageTexture.create_from_image(i)

# ═══════════════════════════════════════════
#  MASTER DISPATCHER
# ═══════════════════════════════════════════

static func _generate(icon_name: String) -> Image:
	var i: Image = _img()
	match icon_name:
		# Ores/Bars/Crafting
		"icon_ore":       _draw_ore(i)
		"icon_bar":       _draw_bar(i)
		"icon_alloy":     _draw_alloy(i)
		"icon_essence":   _draw_essence(i)
		"icon_gem":       _draw_gem(i)
		"icon_dust":      _draw_dust(i)
		# Bio Resources
		"icon_bio_bone":     _draw_bio_bone(i)
		"icon_bio_membrane": _draw_bio_membrane(i)
		"icon_bio_mushroom": _draw_bio_mushroom(i)
		"icon_bio_swirl":    _draw_bio_swirl(i)
		"icon_bio_brain":    _draw_bio_brain(i)
		"icon_bio_galaxy":   _draw_bio_galaxy(i)
		"icon_bio_sparkle":  _draw_bio_sparkle(i)
		"icon_bio_crystal":  _draw_bio_crystal(i)
		"icon_bio_fiber":    _draw_bio_fiber(i)
		"icon_bio_conduit":  _draw_bio_conduit(i)
		"icon_neural":       _draw_neural(i)
		"icon_chrono":       _draw_chrono(i)
		"icon_stinger":      _draw_stinger(i)
		"icon_dark_orb":     _draw_dark_orb(i)
		# Raw Food
		"icon_food_lichen":   _draw_food_lichen(i)
		"icon_food_fruit":    _draw_food_fruit(i)
		"icon_food_meat":     _draw_food_meat(i)
		"icon_food_pepper":   _draw_food_pepper(i)
		"icon_food_truffle":  _draw_food_truffle(i)
		"icon_food_kelp":     _draw_food_kelp(i)
		"icon_food_grain":    _draw_food_grain(i)
		"icon_food_mushroom": _draw_food_mushroom(i)
		"icon_food_honey":    _draw_food_honey(i)
		"icon_food_yeast":    _draw_food_yeast(i)
		# Cooked Food
		"icon_wrap":       _draw_wrap(i)
		"icon_soup":       _draw_soup(i)
		"icon_smoothie":   _draw_smoothie(i)
		"icon_grain_bowl": _draw_grain_bowl(i)
		"icon_burger":     _draw_burger(i)
		"icon_stew":       _draw_stew(i)
		"icon_curry":      _draw_curry(i)
		"icon_steak":      _draw_steak(i)
		"icon_feast":      _draw_feast(i)
		"icon_pasta":      _draw_pasta(i)
		"icon_cake":       _draw_cake(i)
		"icon_drumstick":  _draw_drumstick(i)
		"icon_elixir":     _draw_elixir(i)
		"icon_serum":      _draw_serum(i)
		"icon_syringe":    _draw_syringe(i)
		# Utility
		"icon_repair_kit": _draw_repair_kit(i)
		"icon_beacon":     _draw_beacon(i)
		"icon_battery":    _draw_battery(i)
		"icon_flare":      _draw_flare(i)
		"icon_chip":       _draw_chip(i)
		"icon_bomb":       _draw_bomb(i)
		# Trophy/Special
		"icon_crown":     _draw_crown(i)
		"icon_heart":     _draw_heart(i)
		"icon_star":      _draw_star(i)
		"icon_shield":    _draw_shield(i)
		"icon_medal":     _draw_medal(i)
		"icon_speaker":   _draw_speaker(i)
		"icon_telescope": _draw_telescope(i)
		"icon_sigil":     _draw_sigil(i)
		"icon_skull":     _draw_skull(i)
		"icon_relic":     _draw_relic(i)
		# Weapons
		"icon_nanoblade":  _draw_nanoblade(i)
		"icon_coilgun":    _draw_coilgun(i)
		"icon_voidstaff":  _draw_voidstaff(i)
		"icon_capacitor":  _draw_capacitor(i)
		# Armor
		"icon_helmet":  _draw_helmet(i)
		"icon_vest":    _draw_vest(i)
		"icon_greaves": _draw_greaves(i)
		"icon_boots":   _draw_boots(i)
		"icon_gloves":  _draw_gloves(i)
		# Tools
		"icon_pickaxe": _draw_pickaxe(i)
		"icon_scanner": _draw_scanner(i)
		"icon_welder":  _draw_welder(i)
		"icon_stove":   _draw_stove(i)
		# Other
		"icon_credits": _draw_credits(i)
		"icon_pet":     _draw_pet(i)
		"icon_plant":   _draw_plant(i)
		_:
			return null
	return i

# ═══════════════════════════════════════════
#  ORES / BARS / CRAFTING (6)
# ═══════════════════════════════════════════

static func _draw_ore(i: Image) -> void:
	# Irregular rock chunk with mineral vein
	_rect(i, 4, 9, 8, 4, C_DGRAY)
	_rect(i, 3, 6, 10, 4, C_AMBER)
	_rect(i, 5, 4, 6, 2, C_ORANGE)
	_vline(i, 3, 6, 4, C_DGRAY)
	_vline(i, 12, 6, 4, C_DGRAY)
	_hline(i, 5, 4, 6, C_DGRAY)
	_hline(i, 4, 12, 8, C_DGRAY)
	# Facet crack
	_px(i, 7, 7, C_DGRAY)
	_px(i, 8, 8, C_DGRAY)
	_px(i, 9, 9, C_DGRAY)
	# Mineral vein glow
	_px(i, 6, 7, C_NCYAN)
	_px(i, 6, 8, C_NCYAN)
	_px(i, 5, 8, C_NCYAN)

static func _draw_bar(i: Image) -> void:
	# Horizontal ingot with 3D perspective
	_rect(i, 3, 8, 10, 4, C_GRAY)
	_rect(i, 4, 6, 10, 2, C_LGRAY)
	# Top face (lighter)
	_hline(i, 4, 6, 10, C_WHITE)
	# Edges
	_hline(i, 3, 11, 10, C_DGRAY)
	_vline(i, 3, 8, 4, C_DGRAY)
	_vline(i, 13, 6, 2, C_DGRAY)
	# 3D edge
	_px(i, 3, 7, C_LGRAY)
	_px(i, 13, 8, C_GRAY)

static func _draw_alloy(i: Image) -> void:
	# Gear-toothed bar
	_rect(i, 3, 7, 10, 4, C_TEAL)
	_rect(i, 4, 5, 10, 2, C_CYAN)
	_hline(i, 4, 5, 10, C_DGRAY)
	_hline(i, 3, 10, 10, C_DGRAY)
	# Gear teeth
	_px(i, 2, 8, C_TEAL)
	_px(i, 2, 9, C_TEAL)
	_px(i, 13, 7, C_TEAL)
	_px(i, 13, 8, C_TEAL)
	# Neon accent
	_px(i, 8, 7, C_NCYAN)

static func _draw_essence(i: Image) -> void:
	# Diamond with radiating sparkle lines
	_px(i, 7, 4, C_PURPLE)
	_px(i, 6, 5, C_PURPLE)
	_px(i, 8, 5, C_PURPLE)
	_px(i, 5, 6, C_PURPLE)
	_px(i, 9, 6, C_PURPLE)
	_rect(i, 6, 6, 3, 3, C_PURPLE)
	_px(i, 7, 7, C_NCYAN)
	_px(i, 5, 9, C_PURPLE)
	_px(i, 9, 9, C_PURPLE)
	_px(i, 6, 10, C_PURPLE)
	_px(i, 8, 10, C_PURPLE)
	_px(i, 7, 11, C_PURPLE)
	# Sparkle rays
	_px(i, 7, 2, C_NCYAN)
	_px(i, 7, 13, C_NCYAN)
	_px(i, 3, 7, C_NCYAN)
	_px(i, 11, 7, C_NCYAN)

static func _draw_gem(i: Image) -> void:
	# Hexagonal gem with facets
	_hline(i, 6, 3, 4, C_DGRAY)
	_px(i, 5, 4, C_DGRAY)
	_rect(i, 6, 4, 4, 2, C_CYAN)
	_px(i, 10, 4, C_DGRAY)
	_px(i, 4, 5, C_DGRAY)
	_rect(i, 5, 5, 6, 3, C_BLUE)
	_px(i, 11, 5, C_DGRAY)
	_rect(i, 5, 8, 6, 2, C_NAVY)
	_px(i, 4, 8, C_DGRAY)
	_px(i, 11, 8, C_DGRAY)
	_px(i, 5, 10, C_DGRAY)
	_px(i, 10, 10, C_DGRAY)
	_hline(i, 6, 11, 4, C_DGRAY)
	# Highlight
	_px(i, 6, 4, C_WHITE)
	_px(i, 7, 5, C_WHITE)
	# Facet line
	_px(i, 7, 7, C_DGRAY)
	_px(i, 8, 8, C_DGRAY)

static func _draw_dust(i: Image) -> void:
	# Scattered particle cloud
	_px(i, 5, 5, C_LGRAY)
	_px(i, 8, 4, C_GRAY)
	_px(i, 10, 6, C_LGRAY)
	_px(i, 4, 8, C_GRAY)
	_rect(i, 7, 7, 2, 2, C_LGRAY)
	_px(i, 6, 9, C_GRAY)
	_px(i, 11, 8, C_LGRAY)
	_px(i, 9, 10, C_GRAY)
	_px(i, 3, 6, C_GRAY)
	_px(i, 12, 10, C_LGRAY)

# ═══════════════════════════════════════════
#  BIO RESOURCES (14)
# ═══════════════════════════════════════════

static func _draw_bio_bone(i: Image) -> void:
	# L-shaped bone with knob ends
	_rect(i, 4, 4, 3, 3, C_WHITE)
	_rect(i, 6, 6, 2, 6, C_LGRAY)
	_rect(i, 5, 5, 2, 2, C_WHITE)
	_rect(i, 8, 10, 3, 3, C_WHITE)
	_rect(i, 7, 11, 2, 2, C_LGRAY)
	_px(i, 6, 4, C_DGRAY)
	_px(i, 10, 12, C_DGRAY)

static func _draw_bio_membrane(i: Image) -> void:
	# Circular cell with nucleus
	_circle_outline(i, 7, 7, 5, C_PINK)
	_circle(i, 7, 7, 3, Color(0.6, 0.2, 0.4, 0.5))
	_circle(i, 7, 7, 1, C_DPURPLE)
	_px(i, 7, 7, C_PINK)

static func _draw_bio_mushroom(i: Image) -> void:
	# Mushroom cap and stem
	_rect(i, 4, 5, 8, 4, C_PINK)
	_rect(i, 5, 4, 6, 1, C_PINK)
	_hline(i, 4, 5, 8, C_DPURPLE)
	_rect(i, 7, 9, 2, 4, C_LGRAY)
	_px(i, 6, 6, C_NCYAN)
	_px(i, 9, 7, C_NCYAN)
	_hline(i, 4, 8, 8, C_DPURPLE)

static func _draw_bio_swirl(i: Image) -> void:
	# Spiral from center outward
	_px(i, 8, 7, C_CYAN)
	_px(i, 9, 7, C_TEAL)
	_px(i, 9, 8, C_TEAL)
	_px(i, 8, 9, C_TEAL)
	_px(i, 7, 9, C_TEAL)
	_px(i, 6, 8, C_CYAN)
	_px(i, 6, 7, C_CYAN)
	_px(i, 6, 6, C_CYAN)
	_px(i, 7, 5, C_TEAL)
	_px(i, 8, 5, C_TEAL)
	_px(i, 9, 5, C_TEAL)
	_px(i, 10, 6, C_CYAN)
	_px(i, 10, 7, C_CYAN)
	_px(i, 10, 8, C_CYAN)
	_px(i, 10, 9, C_TEAL)
	_px(i, 9, 10, C_TEAL)
	_px(i, 8, 10, C_TEAL)
	_px(i, 7, 7, C_NCYAN)

static func _draw_bio_brain(i: Image) -> void:
	# Two-lobed brain shape
	_rect(i, 3, 5, 4, 6, C_PINK)
	_rect(i, 9, 5, 4, 6, C_PINK)
	_rect(i, 4, 4, 3, 1, C_PINK)
	_rect(i, 9, 4, 3, 1, C_PINK)
	_vline(i, 7, 4, 8, C_DPURPLE)
	_vline(i, 8, 4, 8, C_DPURPLE)
	# Fold lines
	_px(i, 4, 7, C_DPURPLE)
	_px(i, 5, 8, C_DPURPLE)
	_px(i, 10, 7, C_DPURPLE)
	_px(i, 11, 8, C_DPURPLE)

static func _draw_bio_galaxy(i: Image) -> void:
	# Spiral galaxy with arms
	_px(i, 7, 7, C_WHITE)
	_px(i, 8, 7, C_WHITE)
	# Arms
	_px(i, 6, 6, C_PURPLE)
	_px(i, 5, 5, C_PURPLE)
	_px(i, 4, 5, C_DPURPLE)
	_px(i, 9, 6, C_PURPLE)
	_px(i, 10, 5, C_DPURPLE)
	_px(i, 9, 8, C_PURPLE)
	_px(i, 10, 9, C_PURPLE)
	_px(i, 11, 10, C_DPURPLE)
	_px(i, 6, 8, C_PURPLE)
	_px(i, 5, 9, C_DPURPLE)
	_px(i, 5, 10, C_DPURPLE)
	# Stars
	_px(i, 3, 8, C_LGRAY)
	_px(i, 11, 4, C_LGRAY)
	_px(i, 12, 7, C_LGRAY)

static func _draw_bio_sparkle(i: Image) -> void:
	# 4-pointed star
	_px(i, 7, 3, C_GOLD)
	_px(i, 7, 4, C_GOLD)
	_px(i, 7, 5, C_GOLD)
	_hline(i, 3, 7, 10, C_GOLD)
	_px(i, 7, 9, C_GOLD)
	_px(i, 7, 10, C_GOLD)
	_px(i, 7, 11, C_GOLD)
	_px(i, 7, 6, C_GOLD)
	_px(i, 7, 8, C_GOLD)
	# Center glow
	_px(i, 7, 7, C_NCYAN)
	_px(i, 6, 7, C_GOLD)
	_px(i, 8, 7, C_GOLD)

static func _draw_bio_crystal(i: Image) -> void:
	# Vertical hexagonal crystal shard
	_px(i, 7, 2, C_DGRAY)
	_rect(i, 6, 3, 3, 2, C_CYAN)
	_rect(i, 5, 5, 5, 5, C_BLUE)
	_rect(i, 6, 10, 3, 2, C_NAVY)
	_px(i, 7, 12, C_DGRAY)
	# Highlight edge
	_vline(i, 6, 3, 7, C_CYAN)
	_px(i, 7, 3, C_WHITE)
	# Outline
	_vline(i, 5, 5, 5, C_DGRAY)
	_vline(i, 9, 5, 5, C_DGRAY)

static func _draw_bio_fiber(i: Image) -> void:
	# Crossing fiber strands
	# Strand 1: top-left to bottom-right
	_px(i, 3, 3, C_GREEN)
	_px(i, 4, 4, C_GREEN)
	_px(i, 5, 5, C_GREEN)
	_px(i, 6, 6, C_GREEN)
	_px(i, 7, 7, C_GREEN)
	_px(i, 8, 8, C_GREEN)
	_px(i, 9, 9, C_DGREEN)
	_px(i, 10, 10, C_DGREEN)
	_px(i, 11, 11, C_DGREEN)
	# Strand 2: top-right to bottom-left
	_px(i, 11, 4, C_DGREEN)
	_px(i, 10, 5, C_DGREEN)
	_px(i, 9, 6, C_DGREEN)
	_px(i, 8, 7, C_GREEN)
	_px(i, 6, 9, C_GREEN)
	_px(i, 5, 10, C_GREEN)
	_px(i, 4, 11, C_DGREEN)
	# Nodes at crossings
	_px(i, 7, 7, C_NGREEN)
	_px(i, 5, 5, C_NGREEN)
	_px(i, 10, 10, C_NGREEN)

static func _draw_bio_conduit(i: Image) -> void:
	# Vertical tube with ring segments
	_rect(i, 6, 3, 4, 10, C_TEAL)
	_vline(i, 5, 3, 10, C_DGRAY)
	_vline(i, 10, 3, 10, C_DGRAY)
	# Ring segments
	_hline(i, 5, 5, 6, C_DGRAY)
	_hline(i, 5, 8, 6, C_DGRAY)
	_hline(i, 5, 11, 6, C_DGRAY)
	# Glow dot at top
	_px(i, 7, 3, C_NCYAN)
	_px(i, 8, 3, C_NCYAN)

static func _draw_neural(i: Image) -> void:
	# DNA double helix
	_px(i, 5, 3, C_CYAN)
	_px(i, 10, 3, C_PURPLE)
	_px(i, 4, 4, C_CYAN)
	_px(i, 11, 4, C_PURPLE)
	_hline(i, 5, 5, 6, C_LGRAY)
	_px(i, 4, 6, C_PURPLE)
	_px(i, 11, 6, C_CYAN)
	_px(i, 5, 7, C_PURPLE)
	_px(i, 10, 7, C_CYAN)
	_hline(i, 5, 8, 6, C_LGRAY)
	_px(i, 5, 9, C_CYAN)
	_px(i, 10, 9, C_PURPLE)
	_px(i, 4, 10, C_CYAN)
	_px(i, 11, 10, C_PURPLE)
	_hline(i, 5, 11, 6, C_LGRAY)
	_px(i, 5, 12, C_PURPLE)
	_px(i, 10, 12, C_CYAN)

static func _draw_chrono(i: Image) -> void:
	# Hourglass shape
	_hline(i, 4, 3, 8, C_GOLD)
	_hline(i, 4, 12, 8, C_GOLD)
	_px(i, 5, 4, C_DGOLD)
	_px(i, 10, 4, C_DGOLD)
	_px(i, 6, 5, C_AMBER)
	_px(i, 9, 5, C_AMBER)
	_px(i, 7, 6, C_AMBER)
	_px(i, 8, 6, C_AMBER)
	_px(i, 7, 7, C_GOLD)
	_px(i, 8, 7, C_GOLD)
	_px(i, 7, 8, C_AMBER)
	_px(i, 8, 8, C_AMBER)
	_px(i, 6, 9, C_AMBER)
	_px(i, 9, 9, C_AMBER)
	_px(i, 5, 10, C_DGOLD)
	_px(i, 10, 10, C_DGOLD)
	_px(i, 6, 11, C_DGOLD)
	_px(i, 9, 11, C_DGOLD)
	# Sand inside
	_px(i, 7, 9, C_GOLD)
	_px(i, 8, 10, C_GOLD)

static func _draw_stinger(i: Image) -> void:
	# Downward-pointing barb
	_rect(i, 6, 3, 4, 3, C_ORANGE)
	_rect(i, 7, 6, 2, 3, C_ORANGE)
	_px(i, 7, 9, C_AMBER)
	_px(i, 8, 10, C_RED)
	_px(i, 7, 10, C_RED)
	_px(i, 7, 11, C_RED)
	# Barb edges
	_px(i, 5, 5, C_AMBER)
	_px(i, 10, 5, C_AMBER)
	_px(i, 6, 4, C_DGRAY)
	_px(i, 9, 4, C_DGRAY)

static func _draw_dark_orb(i: Image) -> void:
	# Dark sphere with purple crescent
	_circle(i, 7, 7, 4, C_DGRAY)
	_circle(i, 7, 7, 3, C_BLACK)
	# Purple crescent (right edge)
	_px(i, 10, 6, C_PURPLE)
	_px(i, 10, 7, C_PURPLE)
	_px(i, 10, 8, C_PURPLE)
	_px(i, 11, 7, C_PURPLE)
	_px(i, 9, 5, C_DPURPLE)
	_px(i, 9, 9, C_DPURPLE)

# ═══════════════════════════════════════════
#  RAW FOOD (10)
# ═══════════════════════════════════════════

static func _draw_food_lichen(i: Image) -> void:
	# Low wavy ground lichen
	_hline(i, 3, 10, 10, C_DGREEN)
	_hline(i, 4, 9, 8, C_GREEN)
	_px(i, 5, 8, C_GREEN)
	_px(i, 8, 8, C_GREEN)
	_px(i, 10, 8, C_DGREEN)
	_px(i, 6, 7, C_DGREEN)
	_px(i, 9, 7, C_GREEN)
	_hline(i, 3, 11, 10, C_DGRAY)

static func _draw_food_fruit(i: Image) -> void:
	# Round fruit with stem/leaf
	_circle(i, 7, 8, 3, C_PURPLE)
	_circle(i, 7, 8, 2, C_DPURPLE)
	_px(i, 6, 7, C_PURPLE)
	_px(i, 7, 5, C_BROWN)
	_px(i, 7, 4, C_BROWN)
	_px(i, 8, 4, C_GREEN)
	_px(i, 9, 3, C_GREEN)
	_px(i, 6, 6, C_WHITE)

static func _draw_food_meat(i: Image) -> void:
	# Meat slab with marbling
	_rect(i, 3, 6, 10, 5, C_RED)
	_rect(i, 4, 5, 8, 1, C_CRIMSON)
	_hline(i, 3, 10, 10, C_CRIMSON)
	# Marbling
	_px(i, 6, 7, C_PINK)
	_px(i, 8, 8, C_PINK)
	_px(i, 10, 7, C_PINK)
	# Bone edge
	_rect(i, 3, 6, 1, 5, C_WHITE)

static func _draw_food_pepper(i: Image) -> void:
	# Curved chili pepper
	_px(i, 7, 3, C_DGREEN)
	_px(i, 7, 4, C_GREEN)
	_px(i, 6, 5, C_RED)
	_px(i, 7, 5, C_RED)
	_rect(i, 5, 6, 3, 2, C_RED)
	_rect(i, 5, 8, 3, 2, C_ORANGE)
	_px(i, 6, 10, C_ORANGE)
	_px(i, 7, 11, C_RED)
	_px(i, 8, 12, C_CRIMSON)
	_px(i, 5, 7, C_CRIMSON)

static func _draw_food_truffle(i: Image) -> void:
	# Round lumpy ball
	_circle(i, 7, 8, 3, C_BROWN)
	_px(i, 5, 7, C_DBROWN)
	_px(i, 8, 6, C_DBROWN)
	_px(i, 9, 9, C_DBROWN)
	_px(i, 6, 10, C_DBROWN)
	_px(i, 7, 7, C_BROWN)
	_px(i, 6, 6, C_AMBER)

static func _draw_food_kelp(i: Image) -> void:
	# Wavy vertical strand
	_px(i, 7, 3, C_GREEN)
	_px(i, 6, 4, C_GREEN)
	_px(i, 7, 5, C_GREEN)
	_px(i, 8, 6, C_DGREEN)
	_px(i, 7, 7, C_GREEN)
	_px(i, 6, 8, C_GREEN)
	_px(i, 7, 9, C_DGREEN)
	_px(i, 8, 10, C_GREEN)
	_px(i, 7, 11, C_GREEN)
	_px(i, 6, 12, C_DGREEN)
	# Small leaf
	_px(i, 9, 6, C_GREEN)
	_px(i, 5, 8, C_DGREEN)

static func _draw_food_grain(i: Image) -> void:
	# Wheat sheaf
	_vline(i, 7, 7, 5, C_AMBER)
	_vline(i, 8, 8, 4, C_AMBER)
	# Grain heads
	_px(i, 6, 4, C_GOLD)
	_px(i, 7, 3, C_GOLD)
	_px(i, 7, 4, C_GOLD)
	_px(i, 8, 4, C_GOLD)
	_px(i, 8, 5, C_GOLD)
	_px(i, 9, 5, C_GOLD)
	_px(i, 5, 5, C_DGOLD)
	_px(i, 6, 6, C_DGOLD)

static func _draw_food_mushroom(i: Image) -> void:
	# Mushroom in food green palette
	_rect(i, 4, 5, 8, 4, C_GREEN)
	_rect(i, 5, 4, 6, 1, C_GREEN)
	_hline(i, 4, 5, 8, C_DGREEN)
	_rect(i, 7, 9, 2, 4, C_LGRAY)
	_px(i, 6, 6, C_NGREEN)
	_px(i, 9, 7, C_NGREEN)
	_hline(i, 4, 8, 8, C_DGREEN)

static func _draw_food_honey(i: Image) -> void:
	# Hexagonal jar with drip
	_rect(i, 5, 4, 6, 7, C_GOLD)
	_rect(i, 6, 3, 4, 1, C_AMBER)
	_hline(i, 6, 3, 4, C_DGRAY)
	_vline(i, 5, 4, 7, C_DGRAY)
	_vline(i, 10, 4, 7, C_DGRAY)
	_hline(i, 5, 10, 6, C_DGRAY)
	# Drip
	_px(i, 7, 11, C_GOLD)
	_px(i, 7, 12, C_AMBER)
	# Highlight
	_px(i, 6, 5, C_WHITE)

static func _draw_food_yeast(i: Image) -> void:
	# Petri dish with culture dots
	_circle_outline(i, 7, 8, 4, C_LGRAY)
	_circle(i, 7, 8, 3, Color(0.85, 0.88, 0.9, 0.3))
	_px(i, 6, 7, C_GREEN)
	_px(i, 8, 9, C_GREEN)
	_px(i, 9, 7, C_DGREEN)

# ═══════════════════════════════════════════
#  COOKED FOOD (15)
# ═══════════════════════════════════════════

static func _draw_bowl(i: Image, c: Color) -> void:
	_rect(i, 3, 8, 10, 3, c)
	_rect(i, 4, 7, 8, 1, c)
	_hline(i, 3, 11, 10, C_DGRAY)
	_px(i, 3, 10, C_DGRAY)
	_px(i, 12, 10, C_DGRAY)

static func _draw_wrap(i: Image) -> void:
	# Horizontal burrito/wrap
	_rect(i, 3, 6, 10, 4, C_AMBER)
	_hline(i, 3, 5, 10, C_DGOLD)
	_hline(i, 3, 10, 10, C_DGRAY)
	# Rounded ends
	_px(i, 2, 7, C_AMBER)
	_px(i, 2, 8, C_AMBER)
	_px(i, 13, 7, C_DGOLD)
	# Filling visible
	_px(i, 12, 7, C_GREEN)
	_px(i, 12, 8, C_RED)
	_px(i, 11, 7, C_DGREEN)

static func _draw_soup(i: Image) -> void:
	# Bowl with steam
	_draw_bowl(i, C_BROWN)
	_rect(i, 4, 7, 8, 2, C_ORANGE)
	# Steam
	_px(i, 6, 5, C_LGRAY)
	_px(i, 6, 4, C_LGRAY)
	_px(i, 9, 5, C_LGRAY)
	_px(i, 9, 3, C_LGRAY)

static func _draw_smoothie(i: Image) -> void:
	# Tall glass with straw
	_rect(i, 5, 4, 5, 8, C_GREEN)
	_rect(i, 6, 3, 3, 1, C_GREEN)
	_vline(i, 5, 4, 8, C_DGRAY)
	_vline(i, 9, 4, 8, C_DGRAY)
	_hline(i, 5, 11, 5, C_DGRAY)
	# Straw
	_vline(i, 10, 2, 5, C_NGREEN)
	_px(i, 9, 6, C_NGREEN)
	# Highlight
	_px(i, 6, 5, C_WHITE)

static func _draw_grain_bowl(i: Image) -> void:
	_draw_bowl(i, C_BROWN)
	# Grain dots
	_px(i, 5, 8, C_WHITE)
	_px(i, 7, 8, C_WHITE)
	_px(i, 9, 8, C_WHITE)
	_px(i, 6, 9, C_WHITE)
	_px(i, 8, 9, C_WHITE)
	_px(i, 10, 9, C_WHITE)

static func _draw_burger(i: Image) -> void:
	# Stacked layers: bun/lettuce/patty/bun
	_rect(i, 4, 4, 8, 2, C_AMBER)
	_hline(i, 5, 3, 6, C_AMBER)
	_hline(i, 4, 6, 8, C_GREEN)
	_rect(i, 4, 7, 8, 2, C_BROWN)
	_rect(i, 4, 9, 8, 2, C_DGOLD)
	_hline(i, 4, 11, 8, C_DGRAY)
	# Sesame
	_px(i, 6, 4, C_WHITE)
	_px(i, 9, 4, C_WHITE)

static func _draw_stew(i: Image) -> void:
	_draw_bowl(i, C_BROWN)
	# Chunky contents
	_rect(i, 5, 7, 2, 2, C_ORANGE)
	_rect(i, 8, 8, 2, 2, C_AMBER)
	_px(i, 7, 7, C_RED)
	_px(i, 10, 7, C_GREEN)

static func _draw_curry(i: Image) -> void:
	_draw_bowl(i, C_BROWN)
	# Golden curry
	_rect(i, 4, 7, 5, 2, C_GOLD)
	# Rice mound
	_rect(i, 9, 7, 3, 2, C_WHITE)
	_px(i, 10, 6, C_WHITE)

static func _draw_steak(i: Image) -> void:
	# Flat slab with grill lines
	_rect(i, 3, 6, 10, 5, C_BROWN)
	_rect(i, 4, 5, 8, 1, C_CRIMSON)
	_hline(i, 3, 10, 10, C_DGRAY)
	# Grill lines
	_hline(i, 4, 7, 8, C_DGRAY)
	_hline(i, 4, 9, 8, C_DGRAY)
	# Sear highlight
	_px(i, 5, 6, C_AMBER)
	_px(i, 9, 6, C_AMBER)

static func _draw_feast(i: Image) -> void:
	# Plate with multiple food items
	_circle_outline(i, 7, 8, 5, C_LGRAY)
	_px(i, 5, 7, C_RED)
	_px(i, 7, 7, C_GREEN)
	_px(i, 9, 7, C_GOLD)
	_px(i, 6, 9, C_BROWN)
	_px(i, 8, 9, C_ORANGE)

static func _draw_pasta(i: Image) -> void:
	# Wavy noodle lines
	_px(i, 4, 5, C_GOLD)
	_px(i, 5, 6, C_GOLD)
	_px(i, 6, 5, C_GOLD)
	_px(i, 7, 6, C_GOLD)
	_px(i, 8, 5, C_AMBER)
	_px(i, 9, 6, C_AMBER)
	_px(i, 10, 5, C_AMBER)
	_px(i, 4, 8, C_GOLD)
	_px(i, 5, 9, C_GOLD)
	_px(i, 6, 8, C_GOLD)
	_px(i, 7, 9, C_GOLD)
	_px(i, 8, 8, C_AMBER)
	_px(i, 9, 9, C_AMBER)
	_px(i, 10, 8, C_AMBER)
	# Sauce
	_px(i, 6, 10, C_RED)
	_px(i, 7, 10, C_RED)
	_px(i, 7, 11, C_CRIMSON)

static func _draw_cake(i: Image) -> void:
	# Layered cake with frosting and cherry
	_rect(i, 4, 7, 8, 2, C_BROWN)
	_rect(i, 4, 9, 8, 2, C_AMBER)
	_hline(i, 4, 6, 8, C_PINK)
	_hline(i, 4, 11, 8, C_DGRAY)
	# Cherry on top
	_px(i, 7, 4, C_RED)
	_px(i, 8, 4, C_RED)
	_px(i, 7, 5, C_CRIMSON)
	_px(i, 8, 5, C_RED)
	# Frosting drip
	_px(i, 5, 7, C_PINK)
	_px(i, 10, 7, C_PINK)

static func _draw_drumstick(i: Image) -> void:
	# Classic game drumstick
	_circle(i, 5, 7, 3, C_AMBER)
	_circle(i, 5, 7, 2, C_BROWN)
	# Bone handle
	_hline(i, 8, 7, 4, C_WHITE)
	_hline(i, 8, 8, 4, C_LGRAY)
	_px(i, 12, 6, C_WHITE)
	_px(i, 12, 9, C_WHITE)

static func _draw_elixir(i: Image) -> void:
	# Flask/bottle with glowing liquid
	_rect(i, 6, 3, 4, 2, C_GRAY)
	_hline(i, 6, 3, 4, C_DGRAY)
	_rect(i, 5, 5, 6, 2, C_GRAY)
	_rect(i, 4, 7, 8, 4, C_DPURPLE)
	_hline(i, 4, 11, 8, C_DGRAY)
	_vline(i, 4, 7, 4, C_DGRAY)
	_vline(i, 11, 7, 4, C_DGRAY)
	# Liquid
	_rect(i, 5, 8, 6, 3, C_PURPLE)
	_px(i, 7, 9, C_NCYAN)
	# Cork
	_rect(i, 7, 2, 2, 1, C_BROWN)

static func _draw_serum(i: Image) -> void:
	# Small vial with bright liquid
	_rect(i, 6, 3, 4, 2, C_LGRAY)
	_rect(i, 5, 5, 6, 6, C_GRAY)
	_vline(i, 5, 5, 6, C_DGRAY)
	_vline(i, 10, 5, 6, C_DGRAY)
	_hline(i, 5, 10, 6, C_DGRAY)
	# Liquid
	_rect(i, 6, 6, 4, 4, C_GREEN)
	_px(i, 7, 7, C_NGREEN)
	# Cap
	_hline(i, 6, 3, 4, C_DGRAY)

static func _draw_syringe(i: Image) -> void:
	# Medical syringe
	# Barrel
	_rect(i, 4, 6, 7, 3, C_LGRAY)
	_vline(i, 4, 6, 3, C_DGRAY)
	# Plunger
	_rect(i, 2, 7, 2, 1, C_GRAY)
	# Needle
	_hline(i, 11, 7, 3, C_LGRAY)
	_px(i, 14, 7, C_WHITE)
	# Fluid inside
	_rect(i, 6, 7, 3, 1, C_GREEN)
	# Markings
	_px(i, 5, 6, C_DGRAY)
	_px(i, 7, 6, C_DGRAY)
	_px(i, 9, 6, C_DGRAY)

# ═══════════════════════════════════════════
#  UTILITY (6)
# ═══════════════════════════════════════════

static func _draw_repair_kit(i: Image) -> void:
	# Wrench
	_px(i, 5, 3, C_LGRAY)
	_px(i, 4, 4, C_LGRAY)
	_px(i, 6, 4, C_LGRAY)
	_px(i, 5, 4, C_GRAY)
	_px(i, 6, 5, C_GRAY)
	_px(i, 7, 6, C_GRAY)
	_px(i, 8, 7, C_LGRAY)
	_px(i, 9, 8, C_LGRAY)
	_px(i, 10, 9, C_LGRAY)
	_px(i, 11, 10, C_LGRAY)
	_px(i, 10, 11, C_LGRAY)
	_px(i, 12, 11, C_LGRAY)
	_px(i, 11, 12, C_GRAY)

static func _draw_beacon(i: Image) -> void:
	# Antenna tower with pulse
	_vline(i, 7, 5, 8, C_GRAY)
	_hline(i, 5, 8, 5, C_LGRAY)
	_hline(i, 6, 12, 3, C_GRAY)
	# Antenna top
	_px(i, 7, 4, C_LGRAY)
	_px(i, 7, 3, C_NCYAN)
	# Pulse arcs
	_px(i, 5, 4, C_CYAN)
	_px(i, 9, 4, C_CYAN)
	_px(i, 4, 3, C_TEAL)
	_px(i, 10, 3, C_TEAL)

static func _draw_battery(i: Image) -> void:
	# Rectangle with charge lines
	_rect(i, 4, 4, 8, 9, C_DGREEN)
	_orect(i, 4, 4, 8, 9, C_DGRAY)
	# Terminal
	_rect(i, 6, 3, 4, 1, C_LGRAY)
	# Charge bars
	_hline(i, 5, 6, 6, C_GREEN)
	_hline(i, 5, 8, 6, C_GREEN)
	_hline(i, 5, 10, 6, C_GREEN)
	# Glow
	_px(i, 8, 6, C_NGREEN)

static func _draw_flare(i: Image) -> void:
	# Bright starburst
	_px(i, 7, 7, C_WHITE)
	# Cardinal rays
	_vline(i, 7, 3, 3, C_RED)
	_vline(i, 7, 11, 3, C_RED)
	_hline(i, 3, 7, 3, C_RED)
	_hline(i, 11, 7, 3, C_RED)
	# Diagonal rays
	_px(i, 5, 5, C_ORANGE)
	_px(i, 9, 5, C_ORANGE)
	_px(i, 5, 9, C_ORANGE)
	_px(i, 9, 9, C_ORANGE)
	_px(i, 4, 4, C_AMBER)
	_px(i, 10, 4, C_AMBER)
	_px(i, 4, 10, C_AMBER)
	_px(i, 10, 10, C_AMBER)

static func _draw_chip(i: Image) -> void:
	# IC chip with pin legs
	_rect(i, 5, 5, 6, 6, C_DGRAY)
	_orect(i, 5, 5, 6, 6, C_GRAY)
	# Pins
	_px(i, 6, 4, C_LGRAY)
	_px(i, 8, 4, C_LGRAY)
	_px(i, 6, 11, C_LGRAY)
	_px(i, 8, 11, C_LGRAY)
	_px(i, 4, 6, C_LGRAY)
	_px(i, 4, 8, C_LGRAY)
	_px(i, 11, 6, C_LGRAY)
	_px(i, 11, 8, C_LGRAY)
	# Center dot
	_px(i, 7, 7, C_NCYAN)
	_px(i, 8, 7, C_NCYAN)

static func _draw_bomb(i: Image) -> void:
	# Round bomb with fuse
	_circle(i, 7, 8, 3, C_DGRAY)
	_circle(i, 7, 8, 2, C_GRAY)
	# Fuse
	_px(i, 9, 5, C_BROWN)
	_px(i, 10, 4, C_BROWN)
	_px(i, 11, 3, C_BROWN)
	# Spark
	_px(i, 12, 2, C_RED)
	_px(i, 11, 2, C_ORANGE)
	_px(i, 12, 3, C_GOLD)
	# Highlight
	_px(i, 6, 7, C_LGRAY)

# ═══════════════════════════════════════════
#  TROPHY / SPECIAL (10)
# ═══════════════════════════════════════════

static func _draw_crown(i: Image) -> void:
	# Crown with 3 points
	_rect(i, 3, 8, 10, 3, C_GOLD)
	_hline(i, 3, 11, 10, C_DGOLD)
	# Points
	_px(i, 4, 5, C_GOLD)
	_px(i, 4, 6, C_GOLD)
	_px(i, 4, 7, C_GOLD)
	_px(i, 7, 4, C_GOLD)
	_px(i, 8, 4, C_GOLD)
	_px(i, 7, 5, C_GOLD)
	_px(i, 8, 5, C_GOLD)
	_rect(i, 7, 6, 2, 2, C_GOLD)
	_px(i, 11, 5, C_GOLD)
	_px(i, 11, 6, C_GOLD)
	_px(i, 11, 7, C_GOLD)
	# Gem accents
	_px(i, 6, 9, C_RED)
	_px(i, 9, 9, C_CYAN)
	_px(i, 7, 9, C_DGOLD)

static func _draw_heart(i: Image) -> void:
	# Heart shape
	_rect(i, 3, 5, 3, 3, C_RED)
	_rect(i, 9, 5, 3, 3, C_RED)
	_rect(i, 5, 5, 5, 3, C_RED)
	_rect(i, 4, 8, 7, 2, C_RED)
	_rect(i, 5, 10, 5, 1, C_CRIMSON)
	_rect(i, 6, 11, 3, 1, C_CRIMSON)
	_px(i, 7, 12, C_CRIMSON)
	# Highlight
	_px(i, 4, 5, C_WHITE)
	_px(i, 5, 5, C_PINK)

static func _draw_star(i: Image) -> void:
	# 5-pointed star
	_px(i, 7, 2, C_GOLD)
	_px(i, 7, 3, C_GOLD)
	_rect(i, 6, 4, 3, 2, C_GOLD)
	_hline(i, 3, 6, 10, C_GOLD)
	_hline(i, 4, 7, 8, C_DGOLD)
	_rect(i, 5, 8, 5, 1, C_GOLD)
	_px(i, 5, 9, C_DGOLD)
	_px(i, 9, 9, C_DGOLD)
	_px(i, 4, 10, C_DGOLD)
	_px(i, 10, 10, C_DGOLD)
	# Center highlight
	_px(i, 7, 6, C_WHITE)

static func _draw_shield(i: Image) -> void:
	# Shield shape
	_rect(i, 4, 3, 8, 6, C_BLUE)
	_rect(i, 5, 9, 6, 2, C_NAVY)
	_rect(i, 6, 11, 4, 1, C_NAVY)
	_px(i, 7, 12, C_NAVY)
	_px(i, 8, 12, C_NAVY)
	# Emblem line
	_vline(i, 7, 4, 7, C_CYAN)
	_vline(i, 8, 4, 7, C_CYAN)
	_hline(i, 5, 6, 6, C_CYAN)
	# Border
	_vline(i, 4, 3, 6, C_DGRAY)
	_vline(i, 11, 3, 6, C_DGRAY)

static func _draw_medal(i: Image) -> void:
	# Medal on ribbon
	# Ribbon (inverted V)
	_px(i, 6, 3, C_RED)
	_px(i, 5, 4, C_RED)
	_px(i, 9, 3, C_RED)
	_px(i, 10, 4, C_RED)
	_px(i, 7, 4, C_CRIMSON)
	_px(i, 8, 4, C_CRIMSON)
	# Medal circle
	_circle(i, 7, 8, 3, C_GOLD)
	_circle(i, 7, 8, 2, C_DGOLD)
	_px(i, 7, 8, C_GOLD)
	# Star on medal
	_px(i, 7, 7, C_WHITE)

static func _draw_speaker(i: Image) -> void:
	# Speaker cone with waves
	_rect(i, 3, 6, 3, 4, C_GRAY)
	_rect(i, 6, 5, 2, 6, C_LGRAY)
	_px(i, 6, 4, C_GRAY)
	_px(i, 6, 11, C_GRAY)
	# Sound waves
	_px(i, 9, 6, C_CYAN)
	_px(i, 9, 9, C_CYAN)
	_px(i, 10, 7, C_CYAN)
	_px(i, 10, 8, C_CYAN)
	_px(i, 11, 6, C_TEAL)
	_px(i, 11, 9, C_TEAL)
	_px(i, 12, 7, C_TEAL)

static func _draw_telescope(i: Image) -> void:
	# Diagonal telescope tube
	_px(i, 10, 3, C_LGRAY)
	_px(i, 11, 3, C_LGRAY)
	_px(i, 9, 4, C_GRAY)
	_px(i, 10, 4, C_GRAY)
	_px(i, 8, 5, C_GRAY)
	_px(i, 9, 5, C_GRAY)
	_px(i, 7, 6, C_GRAY)
	_px(i, 8, 6, C_GRAY)
	_px(i, 6, 7, C_LGRAY)
	_px(i, 7, 7, C_LGRAY)
	_px(i, 5, 8, C_LGRAY)
	_px(i, 4, 8, C_LGRAY)
	# Lens
	_px(i, 12, 2, C_CYAN)
	_px(i, 11, 2, C_CYAN)
	# Tripod
	_px(i, 5, 9, C_GRAY)
	_px(i, 4, 10, C_DGRAY)
	_px(i, 6, 10, C_DGRAY)
	_px(i, 3, 11, C_DGRAY)
	_px(i, 7, 11, C_DGRAY)

static func _draw_sigil(i: Image) -> void:
	# Hexagon with inner geometric pattern
	_hline(i, 5, 3, 5, C_PURPLE)
	_px(i, 4, 4, C_PURPLE)
	_px(i, 10, 4, C_PURPLE)
	_px(i, 3, 5, C_PURPLE)
	_px(i, 11, 5, C_PURPLE)
	_px(i, 3, 7, C_PURPLE)
	_px(i, 11, 7, C_PURPLE)
	_px(i, 3, 8, C_PURPLE)
	_px(i, 11, 8, C_PURPLE)
	_px(i, 4, 9, C_PURPLE)
	_px(i, 10, 9, C_PURPLE)
	_hline(i, 5, 10, 5, C_PURPLE)
	# Inner triangle
	_px(i, 7, 4, C_NCYAN)
	_px(i, 6, 6, C_NCYAN)
	_px(i, 8, 6, C_NCYAN)
	_hline(i, 5, 8, 5, C_NCYAN)
	_px(i, 7, 5, C_NCYAN)

static func _draw_skull(i: Image) -> void:
	# Pixel skull
	_rect(i, 4, 3, 7, 5, C_WHITE)
	_rect(i, 5, 2, 5, 1, C_WHITE)
	_rect(i, 5, 8, 5, 2, C_LGRAY)
	# Eye sockets
	_rect(i, 5, 4, 2, 2, C_DGRAY)
	_rect(i, 8, 4, 2, 2, C_DGRAY)
	# Nose
	_px(i, 7, 6, C_GRAY)
	# Jaw
	_px(i, 5, 10, C_LGRAY)
	_px(i, 7, 10, C_LGRAY)
	_px(i, 9, 10, C_LGRAY)
	_hline(i, 5, 9, 5, C_DGRAY)

static func _draw_relic(i: Image) -> void:
	# Amphora/urn
	_rect(i, 6, 3, 4, 2, C_AMBER)
	_rect(i, 5, 5, 6, 5, C_BROWN)
	_rect(i, 6, 10, 4, 2, C_DBROWN)
	_hline(i, 6, 12, 4, C_DGRAY)
	# Handles
	_px(i, 4, 5, C_BROWN)
	_px(i, 4, 6, C_BROWN)
	_px(i, 11, 5, C_BROWN)
	_px(i, 11, 6, C_BROWN)
	# Decorative line
	_hline(i, 5, 7, 6, C_GOLD)
	# Neck
	_vline(i, 6, 3, 2, C_DGRAY)
	_vline(i, 9, 3, 2, C_DGRAY)

# ═══════════════════════════════════════════
#  WEAPONS (4)
# ═══════════════════════════════════════════

static func _draw_nanoblade(i: Image) -> void:
	# Diagonal blade bottom-left to top-right
	# Handle (bottom-left)
	_px(i, 3, 12, C_DBROWN)
	_px(i, 4, 11, C_BROWN)
	_px(i, 5, 10, C_BROWN)
	# Guard
	_px(i, 5, 9, C_GRAY)
	_px(i, 6, 10, C_GRAY)
	# Blade
	_px(i, 6, 9, C_TEAL)
	_px(i, 7, 8, C_TEAL)
	_px(i, 8, 7, C_CYAN)
	_px(i, 9, 6, C_CYAN)
	_px(i, 10, 5, C_CYAN)
	_px(i, 11, 4, C_CYAN)
	_px(i, 12, 3, C_NCYAN)
	# Blade edge (parallel)
	_px(i, 7, 9, C_TEAL)
	_px(i, 8, 8, C_TEAL)
	_px(i, 9, 7, C_CYAN)
	_px(i, 10, 6, C_CYAN)
	_px(i, 11, 5, C_CYAN)

static func _draw_coilgun(i: Image) -> void:
	# Horizontal gun profile
	# Barrel
	_rect(i, 6, 6, 7, 2, C_GRAY)
	_rect(i, 6, 8, 4, 1, C_DGRAY)
	# Grip
	_rect(i, 4, 6, 3, 2, C_DGRAY)
	_rect(i, 4, 8, 2, 3, C_BROWN)
	_px(i, 3, 7, C_DGRAY)
	# Coil rings
	_px(i, 8, 5, C_NCYAN)
	_px(i, 10, 5, C_NCYAN)
	_px(i, 8, 8, C_NCYAN)
	_px(i, 10, 8, C_NCYAN)
	# Muzzle
	_px(i, 13, 6, C_LGRAY)
	_px(i, 13, 7, C_LGRAY)
	# Trigger
	_px(i, 5, 9, C_LGRAY)

static func _draw_voidstaff(i: Image) -> void:
	# Vertical staff with orb at top
	# Staff shaft
	_vline(i, 7, 6, 7, C_BROWN)
	_vline(i, 8, 6, 7, C_DBROWN)
	# Orb at top
	_circle(i, 7, 4, 2, C_PURPLE)
	_px(i, 7, 4, C_NCYAN)
	_px(i, 8, 3, C_DPURPLE)
	# Bottom cap
	_px(i, 7, 13, C_GRAY)
	_px(i, 8, 13, C_GRAY)

static func _draw_capacitor(i: Image) -> void:
	# Lightning bolt Z-pattern
	_px(i, 8, 2, C_GOLD)
	_px(i, 9, 2, C_GOLD)
	_px(i, 7, 3, C_GOLD)
	_px(i, 8, 3, C_GOLD)
	_px(i, 6, 4, C_GOLD)
	_px(i, 7, 4, C_GOLD)
	_hline(i, 5, 5, 5, C_GOLD)
	_hline(i, 6, 6, 5, C_GOLD)
	_hline(i, 6, 7, 5, C_NCYAN)
	_px(i, 8, 8, C_GOLD)
	_px(i, 9, 8, C_GOLD)
	_px(i, 7, 9, C_GOLD)
	_px(i, 8, 9, C_GOLD)
	_px(i, 6, 10, C_DGOLD)
	_px(i, 7, 10, C_DGOLD)
	_px(i, 5, 11, C_DGOLD)
	_px(i, 6, 11, C_DGOLD)

# ═══════════════════════════════════════════
#  ARMOR (5)
# ═══════════════════════════════════════════

static func _draw_helmet(i: Image) -> void:
	# Dome with visor slit
	_rect(i, 4, 4, 8, 7, C_BLUE)
	_rect(i, 5, 3, 6, 1, C_BLUE)
	_hline(i, 6, 2, 4, C_BLUE)
	# Visor
	_hline(i, 4, 7, 8, C_CYAN)
	_hline(i, 4, 8, 8, C_NCYAN)
	# Outline
	_vline(i, 4, 4, 7, C_NAVY)
	_vline(i, 11, 4, 7, C_NAVY)
	_hline(i, 4, 10, 8, C_NAVY)
	# Highlight
	_px(i, 6, 4, C_WHITE)
	_px(i, 7, 3, C_WHITE)

static func _draw_vest(i: Image) -> void:
	# T-shaped torso armor
	_rect(i, 3, 4, 10, 2, C_BLUE)
	_rect(i, 5, 6, 6, 5, C_BLUE)
	_rect(i, 6, 11, 4, 1, C_NAVY)
	# Shoulders (bright)
	_rect(i, 3, 4, 2, 2, C_CYAN)
	_rect(i, 11, 4, 2, 2, C_CYAN)
	# Center seam
	_vline(i, 7, 5, 6, C_NAVY)
	# Outline
	_hline(i, 3, 3, 10, C_NAVY)
	_vline(i, 5, 6, 5, C_NAVY)
	_vline(i, 10, 6, 5, C_NAVY)

static func _draw_greaves(i: Image) -> void:
	# Two vertical leg guards
	_rect(i, 3, 3, 4, 9, C_BLUE)
	_rect(i, 9, 3, 4, 9, C_BLUE)
	# Knee joint lines
	_hline(i, 3, 7, 4, C_NAVY)
	_hline(i, 9, 7, 4, C_NAVY)
	# Outlines
	_vline(i, 3, 3, 9, C_NAVY)
	_vline(i, 6, 3, 9, C_NAVY)
	_vline(i, 9, 3, 9, C_NAVY)
	_vline(i, 12, 3, 9, C_NAVY)
	# Highlights
	_px(i, 4, 4, C_CYAN)
	_px(i, 10, 4, C_CYAN)

static func _draw_boots(i: Image) -> void:
	# Boot profile (L-shape)
	_rect(i, 5, 4, 4, 6, C_BLUE)
	_rect(i, 3, 10, 8, 2, C_BLUE)
	# Sole
	_hline(i, 3, 12, 8, C_GRAY)
	_hline(i, 3, 11, 1, C_GRAY)
	# Outline
	_vline(i, 5, 4, 6, C_NAVY)
	_vline(i, 8, 4, 6, C_NAVY)
	_vline(i, 10, 10, 2, C_NAVY)
	_hline(i, 5, 4, 4, C_NAVY)
	# Highlight
	_px(i, 6, 5, C_CYAN)

static func _draw_gloves(i: Image) -> void:
	# Gauntlet with fingers
	_rect(i, 4, 7, 7, 4, C_BLUE)
	_rect(i, 5, 5, 5, 2, C_BLUE)
	# Fingers
	_px(i, 4, 6, C_BLUE)
	_px(i, 4, 5, C_NAVY)
	_px(i, 10, 6, C_BLUE)
	_px(i, 10, 5, C_NAVY)
	# Cuff
	_hline(i, 4, 11, 7, C_NAVY)
	_hline(i, 4, 10, 7, C_NAVY)
	# Knuckle accent
	_px(i, 6, 7, C_NCYAN)
	_px(i, 8, 7, C_NCYAN)
	# Outline
	_vline(i, 4, 7, 4, C_NAVY)
	_vline(i, 10, 7, 4, C_NAVY)

# ═══════════════════════════════════════════
#  TOOLS (4)
# ═══════════════════════════════════════════

static func _draw_pickaxe(i: Image) -> void:
	# Classic pickaxe at ~45 degrees
	# Handle
	_px(i, 4, 11, C_BROWN)
	_px(i, 5, 10, C_BROWN)
	_px(i, 6, 9, C_BROWN)
	_px(i, 7, 8, C_BROWN)
	_px(i, 8, 7, C_BROWN)
	# Head
	_px(i, 9, 6, C_GRAY)
	_px(i, 10, 5, C_GRAY)
	_px(i, 11, 4, C_LGRAY)
	_px(i, 12, 3, C_LGRAY)
	# Other side
	_px(i, 7, 6, C_GRAY)
	_px(i, 6, 5, C_GRAY)
	_px(i, 5, 4, C_LGRAY)
	# Edge highlight
	_px(i, 12, 3, C_WHITE)
	_px(i, 5, 4, C_WHITE)

static func _draw_scanner(i: Image) -> void:
	# Handheld device with screen
	_rect(i, 4, 4, 7, 8, C_DGRAY)
	_orect(i, 4, 4, 7, 8, C_GRAY)
	# Screen
	_rect(i, 5, 5, 5, 4, C_NCYAN)
	_rect(i, 6, 6, 3, 2, Color(0.0, 0.4, 0.5))
	# Antenna
	_vline(i, 10, 2, 3, C_LGRAY)
	_px(i, 10, 1, C_NCYAN)
	# Button
	_px(i, 7, 10, C_LGRAY)

static func _draw_welder(i: Image) -> void:
	# Welding torch
	# Handle
	_rect(i, 3, 7, 5, 3, C_GRAY)
	_hline(i, 3, 10, 5, C_DGRAY)
	# Nozzle
	_rect(i, 8, 8, 4, 1, C_LGRAY)
	_px(i, 12, 8, C_LGRAY)
	# Sparks
	_px(i, 13, 7, C_ORANGE)
	_px(i, 12, 6, C_GOLD)
	_px(i, 13, 9, C_ORANGE)
	_px(i, 14, 8, C_RED)

static func _draw_stove(i: Image) -> void:
	# Hotplate with burner glow
	_rect(i, 3, 7, 10, 4, C_DGRAY)
	_orect(i, 3, 7, 10, 4, C_GRAY)
	_hline(i, 3, 11, 10, C_DGRAY)
	# Burners
	_circle_outline(i, 5, 6, 1, C_RED)
	_circle_outline(i, 10, 6, 1, C_RED)
	_px(i, 5, 6, C_ORANGE)
	_px(i, 10, 6, C_ORANGE)
	# Heat waves
	_px(i, 5, 4, C_LGRAY)
	_px(i, 10, 3, C_LGRAY)

# ═══════════════════════════════════════════
#  OTHER (3)
# ═══════════════════════════════════════════

static func _draw_credits(i: Image) -> void:
	# Coin with C marking
	_circle(i, 7, 7, 4, C_GOLD)
	_circle(i, 7, 7, 3, C_DGOLD)
	# C letter
	_px(i, 6, 6, C_GOLD)
	_px(i, 6, 7, C_GOLD)
	_px(i, 6, 8, C_GOLD)
	_px(i, 7, 5, C_GOLD)
	_px(i, 8, 5, C_GOLD)
	_px(i, 7, 9, C_GOLD)
	_px(i, 8, 9, C_GOLD)
	# Highlight
	_px(i, 5, 5, C_WHITE)

static func _draw_pet(i: Image) -> void:
	# Paw print
	# Main pad
	_rect(i, 5, 8, 5, 3, C_PINK)
	_rect(i, 6, 7, 3, 1, C_PINK)
	# Toe pads
	_px(i, 4, 5, C_PINK)
	_px(i, 5, 5, C_PINK)
	_px(i, 7, 4, C_PINK)
	_px(i, 8, 4, C_PINK)
	_px(i, 10, 5, C_PINK)
	_px(i, 11, 5, C_PINK)
	_px(i, 6, 6, C_PINK)
	_px(i, 9, 6, C_PINK)

static func _draw_plant(i: Image) -> void:
	# Potted plant
	# Pot
	_rect(i, 5, 9, 6, 3, C_BROWN)
	_hline(i, 4, 9, 8, C_DBROWN)
	_hline(i, 5, 12, 6, C_DGRAY)
	# Stem
	_vline(i, 7, 5, 4, C_DGREEN)
	# Leaves
	_px(i, 6, 5, C_GREEN)
	_px(i, 5, 4, C_GREEN)
	_px(i, 8, 5, C_GREEN)
	_px(i, 9, 4, C_GREEN)
	_px(i, 7, 3, C_GREEN)
	_px(i, 7, 4, C_NGREEN)

# ═══════════════════════════════════════════
#  TYPE FALLBACK ICONS (10)
# ═══════════════════════════════════════════

static func _generate_type(item_type: String) -> Image:
	var i: Image = _img()
	match item_type:
		"weapon":
			# Crossed blades
			_px(i, 4, 4, C_LGRAY)
			_px(i, 5, 5, C_LGRAY)
			_px(i, 6, 6, C_GRAY)
			_px(i, 7, 7, C_GRAY)
			_px(i, 8, 8, C_GRAY)
			_px(i, 9, 9, C_LGRAY)
			_px(i, 10, 10, C_LGRAY)
			_px(i, 10, 4, C_LGRAY)
			_px(i, 9, 5, C_LGRAY)
			_px(i, 8, 6, C_GRAY)
			_px(i, 6, 8, C_GRAY)
			_px(i, 5, 9, C_LGRAY)
			_px(i, 4, 10, C_LGRAY)
		"armor":
			# Simple shield
			_rect(i, 5, 4, 6, 5, C_BLUE)
			_rect(i, 6, 9, 4, 2, C_NAVY)
			_px(i, 7, 11, C_NAVY)
			_px(i, 8, 11, C_NAVY)
			_vline(i, 7, 5, 5, C_CYAN)
		"offhand":
			# Small shield variant
			_rect(i, 5, 5, 6, 4, C_NAVY)
			_rect(i, 6, 9, 4, 1, C_NAVY)
			_orect(i, 5, 5, 6, 4, C_BLUE)
			_px(i, 7, 7, C_CYAN)
		"food":
			# Plate with steam
			_hline(i, 4, 9, 8, C_LGRAY)
			_rect(i, 5, 7, 6, 2, C_AMBER)
			_px(i, 6, 5, C_LGRAY)
			_px(i, 9, 4, C_LGRAY)
		"consumable":
			# Flask/potion
			_rect(i, 6, 3, 3, 2, C_GRAY)
			_rect(i, 5, 5, 5, 5, C_DPURPLE)
			_rect(i, 6, 6, 3, 3, C_PURPLE)
			_px(i, 7, 7, C_NCYAN)
			_vline(i, 5, 5, 5, C_DGRAY)
			_vline(i, 9, 5, 5, C_DGRAY)
		"resource":
			# Rock chunk
			_rect(i, 4, 7, 8, 4, C_GRAY)
			_rect(i, 5, 5, 6, 2, C_LGRAY)
			_hline(i, 4, 10, 8, C_DGRAY)
			_px(i, 6, 7, C_AMBER)
		"material":
			# Gear
			_circle(i, 7, 7, 3, C_GRAY)
			_circle(i, 7, 7, 1, C_DGRAY)
			_px(i, 7, 3, C_LGRAY)
			_px(i, 7, 11, C_LGRAY)
			_px(i, 3, 7, C_LGRAY)
			_px(i, 11, 7, C_LGRAY)
			_px(i, 5, 5, C_LGRAY)
			_px(i, 9, 5, C_LGRAY)
			_px(i, 5, 9, C_LGRAY)
			_px(i, 9, 9, C_LGRAY)
		"tool":
			# Wrench
			_px(i, 6, 4, C_LGRAY)
			_px(i, 5, 5, C_LGRAY)
			_px(i, 7, 5, C_LGRAY)
			_px(i, 6, 5, C_GRAY)
			_px(i, 7, 6, C_GRAY)
			_px(i, 8, 7, C_LGRAY)
			_px(i, 9, 8, C_LGRAY)
			_px(i, 10, 9, C_LGRAY)
			_px(i, 11, 10, C_LGRAY)
		"pet":
			_draw_pet(i)
		_:
			# Crate/box
			_rect(i, 4, 5, 8, 7, C_GRAY)
			_orect(i, 4, 5, 8, 7, C_DGRAY)
			_hline(i, 4, 8, 8, C_DGRAY)
			_vline(i, 7, 5, 7, C_DGRAY)
	return i

# ═══════════════════════════════════════════
#  EQUIPMENT SLOT PLACEHOLDERS (7)
# ═══════════════════════════════════════════

static func _generate_slot(slot_name: String) -> Image:
	var i: Image = _img()
	var c: Color = Color(0.3, 0.4, 0.5, 0.4)
	match slot_name:
		"head":
			# Helmet outline
			_hline(i, 5, 3, 6, c)
			_vline(i, 4, 4, 6, c)
			_vline(i, 11, 4, 6, c)
			_hline(i, 4, 10, 8, c)
			_hline(i, 4, 7, 8, c)
		"body":
			# Vest outline
			_hline(i, 3, 4, 10, c)
			_vline(i, 3, 4, 2, c)
			_vline(i, 12, 4, 2, c)
			_vline(i, 5, 6, 5, c)
			_vline(i, 10, 6, 5, c)
			_hline(i, 5, 11, 6, c)
		"weapon":
			# Crossed swords X
			_px(i, 4, 4, c)
			_px(i, 5, 5, c)
			_px(i, 6, 6, c)
			_px(i, 7, 7, c)
			_px(i, 8, 8, c)
			_px(i, 9, 9, c)
			_px(i, 10, 10, c)
			_px(i, 10, 4, c)
			_px(i, 9, 5, c)
			_px(i, 8, 6, c)
			_px(i, 6, 8, c)
			_px(i, 5, 9, c)
			_px(i, 4, 10, c)
		"offhand":
			# Shield outline
			_hline(i, 5, 4, 6, c)
			_vline(i, 4, 5, 4, c)
			_vline(i, 11, 5, 4, c)
			_hline(i, 5, 9, 2, c)
			_hline(i, 9, 9, 2, c)
			_px(i, 7, 10, c)
			_px(i, 8, 10, c)
		"legs":
			# Greaves outline
			_orect(i, 3, 3, 4, 9, c)
			_orect(i, 9, 3, 4, 9, c)
		"boots":
			# Boot outline
			_vline(i, 5, 4, 6, c)
			_vline(i, 8, 4, 6, c)
			_hline(i, 5, 4, 4, c)
			_hline(i, 3, 10, 8, c)
			_hline(i, 3, 12, 8, c)
			_vline(i, 3, 10, 2, c)
			_vline(i, 10, 10, 2, c)
		"gloves":
			# Glove outline
			_orect(i, 4, 7, 7, 4, c)
			_hline(i, 5, 5, 5, c)
			_px(i, 4, 6, c)
			_px(i, 10, 6, c)
		_:
			# Generic box
			_orect(i, 4, 4, 8, 8, c)
	return i

# ═══════════════════════════════════════════
#  ABILITY ICONS
# ═══════════════════════════════════════════

static func _generate_ability(ability_id: String) -> Image:
	var i: Image = _img()
	match ability_id:
		"nano_strike": _draw_ab_nano_strike(i)
		"swarm_lash": _draw_ab_swarm_lash(i)
		"molecular_storm": _draw_ab_molecular_storm(i)
		"nano_drain": _draw_ab_nano_drain(i)
		"swarm_apocalypse": _draw_ab_swarm_apocalypse(i)
		"nano_frenzy": _draw_ab_nano_frenzy(i)
		"arc_bolt": _draw_ab_arc_bolt(i)
		"chain_lightning": _draw_ab_chain_lightning(i)
		"overcharge": _draw_ab_overcharge(i)
		"tesla_cage": _draw_ab_tesla_cage(i)
		"thunderstrike": _draw_ab_thunderstrike(i)
		"rapid_discharge": _draw_ab_rapid_discharge(i)
		"void_bolt": _draw_ab_void_bolt(i)
		"gravity_well": _draw_ab_gravity_well(i)
		"void_rend": _draw_ab_void_rend(i)
		"dark_singularity": _draw_ab_dark_singularity(i)
		"oblivion": _draw_ab_oblivion(i)
		"void_channel": _draw_ab_void_channel(i)
		"natural_instinct": _draw_ab_natural_instinct(i)
		"resonance": _draw_ab_resonance(i)
		"debilitate": _draw_ab_debilitate(i)
		"reflect": _draw_ab_reflect(i)
		"freedom": _draw_ab_freedom(i)
		"_default": _draw_ab_default(i)
		_: _draw_ab_default(i)
	return i

static func _draw_ab_nano_strike(i: Image) -> void:
	# Diagonal cyan blade top-right to bottom-left with motion lines
	# Blade body
	_px(i, 12, 2, C_WHITE)
	_px(i, 11, 3, C_CYAN)
	_px(i, 10, 4, C_CYAN)
	_px(i, 9, 5, C_CYAN)
	_px(i, 8, 6, C_CYAN)
	_px(i, 7, 7, C_TEAL)
	_px(i, 6, 8, C_TEAL)
	_px(i, 5, 9, C_TEAL)
	_px(i, 4, 10, C_TEAL)
	# Blade edge highlight (parallel offset)
	_px(i, 11, 2, C_WHITE)
	_px(i, 10, 3, C_WHITE)
	_px(i, 9, 4, C_WHITE)
	# Shadow side
	_px(i, 12, 3, C_TEAL)
	_px(i, 11, 4, C_TEAL)
	_px(i, 10, 5, C_TEAL)
	# Motion lines
	_px(i, 2, 6, C_CYAN)
	_px(i, 3, 7, C_CYAN)
	_px(i, 2, 8, C_TEAL)
	_px(i, 3, 9, C_TEAL)
	_px(i, 2, 10, C_TEAL)
	# Tip glow
	_px(i, 13, 1, C_WHITE)
	_px(i, 12, 1, C_CYAN)

static func _draw_ab_swarm_lash(i: Image) -> void:
	# Wavy vertical worm/tentacle with segments
	_px(i, 7, 1, C_NGREEN)
	_px(i, 8, 2, C_NGREEN)
	_px(i, 7, 3, C_GREEN)
	_px(i, 6, 4, C_NGREEN)
	_px(i, 7, 5, C_GREEN)
	_px(i, 8, 6, C_NGREEN)
	_px(i, 7, 7, C_GREEN)
	_px(i, 6, 8, C_NGREEN)
	_px(i, 7, 9, C_GREEN)
	_px(i, 8, 10, C_NGREEN)
	_px(i, 7, 11, C_GREEN)
	_px(i, 7, 12, C_DGREEN)
	_px(i, 7, 13, C_DGREEN)
	# Segment marks (darker lines across wave)
	_px(i, 6, 3, C_DGREEN)
	_px(i, 8, 5, C_DGREEN)
	_px(i, 6, 7, C_DGREEN)
	_px(i, 8, 9, C_DGREEN)
	_px(i, 6, 11, C_DGREEN)
	# Body width
	_px(i, 9, 3, C_GREEN)
	_px(i, 5, 5, C_GREEN)
	_px(i, 9, 7, C_GREEN)
	_px(i, 5, 9, C_GREEN)
	# Head
	_circle(i, 7, 1, 1, C_NGREEN)
	_px(i, 7, 0, C_WHITE)

static func _draw_ab_molecular_storm(i: Image) -> void:
	# Cyan spiral vortex with scattered particles
	# Center
	_circle(i, 7, 7, 1, C_TEAL)
	# Spiral arms (manual pixel placement)
	_px(i, 8, 6, C_CYAN)
	_px(i, 9, 6, C_CYAN)
	_px(i, 9, 7, C_CYAN)
	_px(i, 9, 8, C_CYAN)
	_px(i, 8, 9, C_CYAN)
	_px(i, 7, 9, C_CYAN)
	_px(i, 6, 9, C_CYAN)
	_px(i, 5, 8, C_CYAN)
	_px(i, 5, 7, C_CYAN)
	_px(i, 5, 6, C_CYAN)
	_px(i, 6, 5, C_CYAN)
	_px(i, 7, 5, C_CYAN)
	_px(i, 8, 5, C_TEAL)
	_px(i, 10, 6, C_TEAL)
	_px(i, 10, 9, C_TEAL)
	_px(i, 4, 8, C_TEAL)
	_px(i, 4, 5, C_TEAL)
	# Scattered particles
	_px(i, 12, 2, C_WHITE)
	_px(i, 2, 3, C_WHITE)
	_px(i, 13, 10, C_WHITE)
	_px(i, 3, 13, C_WHITE)
	_px(i, 12, 12, C_WHITE)
	_px(i, 1, 8, C_CYAN)
	_px(i, 11, 1, C_CYAN)

static func _draw_ab_nano_drain(i: Image) -> void:
	# Blood drop teardrop: wider at top, pointed at bottom
	# Top wide portion
	_hline(i, 5, 3, 6, C_RED)
	_hline(i, 4, 4, 8, C_RED)
	_hline(i, 4, 5, 8, C_RED)
	_hline(i, 4, 6, 8, C_RED)
	_hline(i, 5, 7, 6, C_RED)
	_hline(i, 6, 8, 4, C_RED)
	# Taper to point
	_hline(i, 6, 9, 4, C_CRIMSON)
	_hline(i, 7, 10, 2, C_CRIMSON)
	_px(i, 7, 11, C_CRIMSON)
	_px(i, 8, 11, C_CRIMSON)
	_px(i, 7, 12, C_CRIMSON)
	# Shadow side
	_vline(i, 11, 4, 5, C_CRIMSON)
	_px(i, 10, 8, C_CRIMSON)
	# Highlight
	_px(i, 5, 4, C_PINK)
	_px(i, 6, 3, C_PINK)

static func _draw_ab_swarm_apocalypse(i: Image) -> void:
	# Biohazard symbol: 3 circles in triangular arrangement + center ring
	# Top circle
	_circle_outline(i, 7, 3, 2, C_NGREEN)
	_px(i, 7, 3, C_DGREEN)
	# Bottom-left circle
	_circle_outline(i, 4, 9, 2, C_NGREEN)
	_px(i, 4, 9, C_DGREEN)
	# Bottom-right circle
	_circle_outline(i, 11, 9, 2, C_NGREEN)
	_px(i, 11, 9, C_DGREEN)
	# Center ring
	_circle_outline(i, 7, 7, 2, C_NGREEN)
	_circle(i, 7, 7, 1, C_DGREEN)
	# Connecting lines
	_px(i, 7, 5, C_GREEN)
	_px(i, 5, 7, C_GREEN)
	_px(i, 9, 7, C_GREEN)
	_px(i, 6, 6, C_GREEN)
	_px(i, 8, 6, C_GREEN)
	_px(i, 5, 8, C_GREEN)
	_px(i, 9, 8, C_GREEN)

static func _draw_ab_nano_frenzy(i: Image) -> void:
	# Circular arrows forming a loop/recycling symbol
	# Outer circle arc (top-right)
	_px(i, 9, 2, C_CYAN)
	_px(i, 10, 3, C_CYAN)
	_px(i, 11, 4, C_CYAN)
	_px(i, 11, 5, C_CYAN)
	_px(i, 11, 6, C_CYAN)
	# Arrow head top-right
	_px(i, 12, 4, C_WHITE)
	_px(i, 11, 3, C_WHITE)
	# Outer circle arc (bottom)
	_px(i, 10, 8, C_CYAN)
	_px(i, 9, 9, C_CYAN)
	_px(i, 8, 10, C_CYAN)
	_px(i, 7, 11, C_CYAN)
	_px(i, 6, 10, C_CYAN)
	_px(i, 5, 9, C_CYAN)
	# Arrow head bottom-left
	_px(i, 4, 10, C_WHITE)
	_px(i, 5, 11, C_WHITE)
	# Outer circle arc (left-top)
	_px(i, 4, 8, C_CYAN)
	_px(i, 3, 7, C_CYAN)
	_px(i, 3, 6, C_CYAN)
	_px(i, 3, 5, C_CYAN)
	_px(i, 4, 4, C_CYAN)
	_px(i, 5, 3, C_CYAN)
	_px(i, 6, 2, C_CYAN)
	_px(i, 7, 2, C_CYAN)
	_px(i, 8, 2, C_CYAN)
	# Arrow head left
	_px(i, 2, 6, C_WHITE)
	_px(i, 3, 4, C_WHITE)
	# Inner fill hint
	_circle(i, 7, 7, 2, C_TEAL)

static func _draw_ab_arc_bolt(i: Image) -> void:
	# Z-shaped lightning bolt, thick 2px
	# Top horizontal bar
	_hline(i, 4, 2, 8, C_WHITE)
	_hline(i, 4, 3, 8, C_BLUE)
	# Diagonal stroke
	_px(i, 10, 4, C_WHITE)
	_px(i, 9, 5, C_WHITE)
	_px(i, 9, 4, C_CYAN)
	_px(i, 8, 5, C_CYAN)
	_px(i, 7, 6, C_WHITE)
	_px(i, 6, 7, C_WHITE)
	_px(i, 6, 6, C_CYAN)
	_px(i, 5, 7, C_CYAN)
	# Bottom horizontal bar
	_hline(i, 3, 8, 8, C_WHITE)
	_hline(i, 3, 9, 8, C_BLUE)
	# Glow pixels
	_px(i, 4, 1, C_CYAN)
	_px(i, 11, 1, C_CYAN)
	_px(i, 3, 10, C_CYAN)
	_px(i, 10, 10, C_CYAN)

static func _draw_ab_chain_lightning(i: Image) -> void:
	# 2-3 interlocking chain link ovals
	# Top link (horizontal oval)
	_hline(i, 4, 2, 7, C_CYAN)
	_hline(i, 4, 5, 7, C_CYAN)
	_vline(i, 3, 3, 2, C_CYAN)
	_vline(i, 11, 3, 2, C_CYAN)
	_px(i, 4, 3, C_BLUE)
	_px(i, 10, 3, C_BLUE)
	_hline(i, 5, 3, 5, C_BLUE)
	_hline(i, 5, 4, 5, C_BLUE)
	# Bottom link (horizontal oval, offset right)
	_hline(i, 5, 7, 7, C_CYAN)
	_hline(i, 5, 10, 7, C_CYAN)
	_vline(i, 4, 8, 2, C_CYAN)
	_vline(i, 12, 8, 2, C_CYAN)
	_px(i, 5, 8, C_BLUE)
	_px(i, 11, 8, C_BLUE)
	_hline(i, 6, 8, 5, C_BLUE)
	_hline(i, 6, 9, 5, C_BLUE)
	# Link connection
	_px(i, 7, 5, C_WHITE)
	_px(i, 8, 5, C_WHITE)
	_px(i, 7, 6, C_CYAN)
	_px(i, 8, 6, C_CYAN)
	_px(i, 7, 7, C_WHITE)
	_px(i, 8, 7, C_WHITE)
	# Glow
	_px(i, 12, 2, C_CYAN)
	_px(i, 3, 11, C_CYAN)

static func _draw_ab_overcharge(i: Image) -> void:
	# Starburst: center dot + 8 rays
	_circle(i, 7, 7, 1, C_GOLD)
	_px(i, 7, 7, C_WHITE)
	# Cardinal rays
	_hline(i, 8, 7, 4, C_ORANGE)
	_hline(i, 3, 7, 4, C_ORANGE)
	_vline(i, 7, 8, 4, C_ORANGE)
	_vline(i, 7, 3, 4, C_ORANGE)
	# Diagonal rays
	_px(i, 9, 5, C_ORANGE)
	_px(i, 10, 4, C_AMBER)
	_px(i, 5, 5, C_ORANGE)
	_px(i, 4, 4, C_AMBER)
	_px(i, 9, 9, C_ORANGE)
	_px(i, 10, 10, C_AMBER)
	_px(i, 5, 9, C_ORANGE)
	_px(i, 4, 10, C_AMBER)
	# Ray tips
	_px(i, 12, 7, C_AMBER)
	_px(i, 2, 7, C_AMBER)
	_px(i, 7, 12, C_AMBER)
	_px(i, 7, 2, C_AMBER)
	# Inner ring
	_px(i, 8, 6, C_GOLD)
	_px(i, 9, 7, C_GOLD)
	_px(i, 8, 8, C_GOLD)
	_px(i, 7, 9, C_GOLD)
	_px(i, 6, 8, C_GOLD)
	_px(i, 5, 7, C_GOLD)
	_px(i, 6, 6, C_GOLD)
	_px(i, 7, 5, C_GOLD)

static func _draw_ab_tesla_cage(i: Image) -> void:
	# Blue outlined square with inner cross-hatch spark lines
	_orect(i, 2, 2, 12, 12, C_BLUE)
	_orect(i, 3, 3, 10, 10, C_NAVY)
	# Cross-hatch sparks inside
	_px(i, 5, 5, C_CYAN)
	_px(i, 7, 5, C_CYAN)
	_px(i, 9, 5, C_CYAN)
	_px(i, 4, 6, C_CYAN)
	_px(i, 6, 6, C_CYAN)
	_px(i, 8, 6, C_CYAN)
	_px(i, 10, 6, C_CYAN)
	_px(i, 5, 7, C_WHITE)
	_px(i, 9, 7, C_WHITE)
	_px(i, 7, 7, C_CYAN)
	_px(i, 4, 8, C_CYAN)
	_px(i, 6, 8, C_CYAN)
	_px(i, 8, 8, C_CYAN)
	_px(i, 10, 8, C_CYAN)
	_px(i, 5, 9, C_CYAN)
	_px(i, 7, 9, C_CYAN)
	_px(i, 9, 9, C_CYAN)
	# Corner spark accents
	_px(i, 2, 2, C_WHITE)
	_px(i, 13, 2, C_WHITE)
	_px(i, 2, 13, C_WHITE)
	_px(i, 13, 13, C_WHITE)

static func _draw_ab_thunderstrike(i: Image) -> void:
	# Small cloud at top + forked lightning bolt descending
	# Cloud
	_hline(i, 4, 2, 8, C_LGRAY)
	_hline(i, 3, 3, 10, C_LGRAY)
	_hline(i, 3, 4, 10, C_LGRAY)
	_hline(i, 4, 5, 8, C_LGRAY)
	_px(i, 3, 2, C_LGRAY)
	_px(i, 11, 2, C_LGRAY)
	# Lightning bolt main
	_px(i, 8, 5, C_WHITE)
	_px(i, 8, 6, C_WHITE)
	_px(i, 7, 6, C_CYAN)
	_px(i, 7, 7, C_WHITE)
	_px(i, 6, 7, C_CYAN)
	_px(i, 6, 8, C_WHITE)
	_px(i, 7, 8, C_CYAN)
	_px(i, 7, 9, C_WHITE)
	# Fork left
	_px(i, 6, 10, C_CYAN)
	_px(i, 5, 11, C_CYAN)
	_px(i, 5, 12, C_BLUE)
	# Fork right
	_px(i, 8, 10, C_CYAN)
	_px(i, 9, 11, C_CYAN)
	_px(i, 9, 12, C_BLUE)
	# Bolt glow
	_px(i, 8, 9, C_WHITE)

static func _draw_ab_rapid_discharge(i: Image) -> void:
	# 3 parallel short vertical lightning bolts side by side
	# Left bolt
	_px(i, 3, 3, C_CYAN)
	_px(i, 4, 4, C_CYAN)
	_px(i, 3, 5, C_WHITE)
	_px(i, 4, 5, C_CYAN)
	_px(i, 3, 6, C_CYAN)
	_px(i, 4, 7, C_BLUE)
	_px(i, 3, 8, C_BLUE)
	# Center bolt (brighter)
	_px(i, 7, 2, C_WHITE)
	_px(i, 8, 3, C_WHITE)
	_px(i, 7, 4, C_CYAN)
	_px(i, 8, 4, C_CYAN)
	_px(i, 7, 5, C_WHITE)
	_px(i, 8, 6, C_WHITE)
	_px(i, 7, 7, C_CYAN)
	_px(i, 8, 8, C_CYAN)
	_px(i, 7, 9, C_BLUE)
	_px(i, 8, 10, C_BLUE)
	# Right bolt
	_px(i, 11, 4, C_CYAN)
	_px(i, 12, 5, C_CYAN)
	_px(i, 11, 6, C_WHITE)
	_px(i, 12, 6, C_CYAN)
	_px(i, 11, 7, C_CYAN)
	_px(i, 12, 8, C_BLUE)
	_px(i, 11, 9, C_BLUE)

static func _draw_ab_void_bolt(i: Image) -> void:
	# Purple crystal/orb with facet highlight
	# Main orb body
	_circle(i, 7, 7, 5, C_DPURPLE)
	_circle(i, 7, 7, 4, C_PURPLE)
	# Facet lines
	_vline(i, 7, 2, 10, C_DPURPLE)
	_hline(i, 2, 7, 10, C_DPURPLE)
	_px(i, 5, 4, C_DPURPLE)
	_px(i, 9, 4, C_DPURPLE)
	_px(i, 4, 9, C_DPURPLE)
	_px(i, 10, 9, C_DPURPLE)
	# Highlight
	_px(i, 5, 4, C_PINK)
	_px(i, 6, 3, C_PINK)
	_px(i, 5, 5, C_PINK)
	# Core glow
	_circle(i, 8, 6, 1, C_PINK)

static func _draw_ab_gravity_well(i: Image) -> void:
	# Purple inward spiral (tighter toward center)
	# Outer ring fragment
	_px(i, 7, 1, C_PINK)
	_px(i, 10, 2, C_PINK)
	_px(i, 12, 5, C_PINK)
	_px(i, 12, 8, C_PURPLE)
	_px(i, 10, 11, C_PURPLE)
	_px(i, 7, 12, C_PURPLE)
	_px(i, 4, 11, C_PURPLE)
	_px(i, 2, 8, C_PURPLE)
	_px(i, 2, 5, C_PURPLE)
	_px(i, 4, 2, C_PURPLE)
	# Mid ring fragment
	_px(i, 7, 3, C_PURPLE)
	_px(i, 10, 4, C_PURPLE)
	_px(i, 11, 7, C_PURPLE)
	_px(i, 9, 10, C_DPURPLE)
	_px(i, 6, 10, C_DPURPLE)
	_px(i, 4, 8, C_DPURPLE)
	_px(i, 3, 6, C_DPURPLE)
	_px(i, 5, 4, C_DPURPLE)
	# Inner ring
	_px(i, 7, 5, C_DPURPLE)
	_px(i, 9, 6, C_DPURPLE)
	_px(i, 9, 8, C_DPURPLE)
	_px(i, 7, 9, C_DPURPLE)
	_px(i, 5, 8, C_DPURPLE)
	_px(i, 5, 6, C_DPURPLE)
	# Center
	_circle(i, 7, 7, 1, C_DPURPLE)
	_px(i, 7, 7, C_BLACK)

static func _draw_ab_void_rend(i: Image) -> void:
	# Purple skull with crack/fracture line down center
	# Skull body
	_rect(i, 4, 3, 8, 6, C_PURPLE)
	_rect(i, 5, 2, 6, 1, C_PURPLE)
	_rect(i, 5, 9, 6, 2, C_DPURPLE)
	# Eye sockets
	_rect(i, 5, 4, 2, 2, C_BLACK)
	_rect(i, 9, 4, 2, 2, C_BLACK)
	_px(i, 5, 4, C_WHITE)
	_px(i, 9, 4, C_WHITE)
	# Nose
	_px(i, 7, 6, C_DPURPLE)
	_px(i, 8, 6, C_DPURPLE)
	# Jaw
	_hline(i, 5, 10, 6, C_DPURPLE)
	_px(i, 5, 11, C_DPURPLE)
	_px(i, 7, 11, C_DPURPLE)
	_px(i, 9, 11, C_DPURPLE)
	# Fracture crack down center
	_px(i, 7, 2, C_DPURPLE)
	_px(i, 8, 3, C_DPURPLE)
	_px(i, 7, 4, C_DPURPLE)
	_px(i, 8, 5, C_DPURPLE)
	_px(i, 7, 6, C_DPURPLE)
	_px(i, 8, 7, C_DPURPLE)
	_px(i, 7, 8, C_DPURPLE)

static func _draw_ab_dark_singularity(i: Image) -> void:
	# Black center circle with bright purple accretion ring
	# Outer glow
	_circle(i, 7, 7, 6, C_PINK)
	# Accretion ring
	_circle(i, 7, 7, 5, C_PURPLE)
	_circle_outline(i, 7, 7, 4, C_PURPLE)
	# Transition
	_circle(i, 7, 7, 3, C_DPURPLE)
	# Black hole center
	_circle(i, 7, 7, 2, C_BLACK)
	# Ring highlight accents
	_px(i, 7, 2, C_PINK)
	_px(i, 11, 5, C_PINK)
	_px(i, 11, 9, C_PINK)
	_px(i, 3, 7, C_PINK)

static func _draw_ab_oblivion(i: Image) -> void:
	# Skull and crossbones in purple/white
	# Skull
	_rect(i, 5, 1, 6, 5, C_WHITE)
	_rect(i, 6, 0, 4, 1, C_WHITE)
	_rect(i, 6, 6, 4, 2, C_LGRAY)
	# Eye sockets
	_rect(i, 6, 2, 1, 2, C_DPURPLE)
	_rect(i, 9, 2, 1, 2, C_DPURPLE)
	# Jaw dividers
	_px(i, 6, 7, C_DPURPLE)
	_px(i, 8, 7, C_DPURPLE)
	_px(i, 10, 7, C_DPURPLE)
	# Crossbones (left bone)
	_px(i, 2, 10, C_PURPLE)
	_px(i, 3, 11, C_PURPLE)
	_px(i, 4, 10, C_PURPLE)
	_hline(i, 4, 11, 4, C_PURPLE)
	_hline(i, 4, 12, 4, C_PURPLE)
	_px(i, 3, 12, C_DPURPLE)
	_px(i, 2, 13, C_PURPLE)
	_px(i, 3, 13, C_DPURPLE)
	_px(i, 4, 13, C_PURPLE)
	# Crossbones (right bone)
	_px(i, 13, 10, C_PURPLE)
	_px(i, 12, 11, C_PURPLE)
	_px(i, 11, 10, C_PURPLE)
	_hline(i, 8, 11, 4, C_PURPLE)
	_hline(i, 8, 12, 4, C_PURPLE)
	_px(i, 12, 12, C_DPURPLE)
	_px(i, 13, 13, C_PURPLE)
	_px(i, 12, 13, C_DPURPLE)
	_px(i, 11, 13, C_PURPLE)

static func _draw_ab_void_channel(i: Image) -> void:
	# Dark eclipse: black circle with purple crescent on right side
	# Full black disc
	_circle(i, 7, 7, 6, C_DPURPLE)
	_circle(i, 7, 7, 5, C_BLACK)
	# Purple crescent on right
	_px(i, 11, 5, C_PURPLE)
	_px(i, 12, 6, C_PURPLE)
	_px(i, 12, 7, C_PURPLE)
	_px(i, 12, 8, C_PURPLE)
	_px(i, 11, 9, C_PURPLE)
	_px(i, 10, 4, C_PURPLE)
	_px(i, 10, 10, C_PURPLE)
	_px(i, 13, 7, C_PINK)
	_px(i, 11, 4, C_PINK)
	_px(i, 11, 10, C_PINK)
	# Crescent inner edge highlight
	_px(i, 10, 5, C_PINK)
	_px(i, 11, 7, C_PINK)
	_px(i, 10, 9, C_PINK)

static func _draw_ab_natural_instinct(i: Image) -> void:
	# Green DNA double helix (two intertwining strands)
	# Strand 1 (S-curve left-right)
	_px(i, 6, 1, C_NGREEN)
	_px(i, 7, 2, C_NGREEN)
	_px(i, 8, 3, C_NGREEN)
	_px(i, 9, 4, C_NGREEN)
	_px(i, 8, 5, C_NGREEN)
	_px(i, 7, 6, C_NGREEN)
	_px(i, 6, 7, C_NGREEN)
	_px(i, 5, 8, C_NGREEN)
	_px(i, 6, 9, C_NGREEN)
	_px(i, 7, 10, C_NGREEN)
	_px(i, 8, 11, C_NGREEN)
	_px(i, 9, 12, C_NGREEN)
	# Strand 2 (opposite S-curve)
	_px(i, 9, 1, C_GREEN)
	_px(i, 8, 2, C_GREEN)
	_px(i, 7, 3, C_GREEN)
	_px(i, 6, 4, C_GREEN)
	_px(i, 7, 5, C_GREEN)
	_px(i, 8, 6, C_GREEN)
	_px(i, 9, 7, C_GREEN)
	_px(i, 10, 8, C_GREEN)
	_px(i, 9, 9, C_GREEN)
	_px(i, 8, 10, C_GREEN)
	_px(i, 7, 11, C_GREEN)
	_px(i, 6, 12, C_GREEN)
	# Rungs connecting the strands
	_px(i, 7, 1, C_DGREEN)
	_px(i, 8, 4, C_DGREEN)
	_px(i, 6, 6, C_DGREEN)
	_px(i, 9, 6, C_DGREEN)
	_px(i, 7, 9, C_DGREEN)
	_px(i, 8, 9, C_DGREEN)
	_px(i, 7, 12, C_DGREEN)

static func _draw_ab_resonance(i: Image) -> void:
	# Green heart with white plus inside
	# Heart top-left bump
	_hline(i, 4, 4, 3, C_GREEN)
	_hline(i, 3, 5, 5, C_GREEN)
	_hline(i, 3, 6, 5, C_GREEN)
	# Heart top-right bump
	_hline(i, 9, 4, 3, C_GREEN)
	_hline(i, 8, 5, 5, C_GREEN)
	_hline(i, 8, 6, 5, C_GREEN)
	# Heart body
	_hline(i, 3, 7, 10, C_GREEN)
	_hline(i, 4, 8, 8, C_GREEN)
	_hline(i, 5, 9, 6, C_GREEN)
	_hline(i, 6, 10, 4, C_GREEN)
	_hline(i, 7, 11, 2, C_GREEN)
	_px(i, 7, 12, C_GREEN)
	# Plus symbol inside
	_hline(i, 5, 7, 6, C_WHITE)
	_vline(i, 7, 5, 5, C_WHITE)

static func _draw_ab_debilitate(i: Image) -> void:
	# Red downward double chevrons
	# Upper chevron (pointing down)
	_px(i, 3, 3, C_RED)
	_px(i, 4, 4, C_RED)
	_px(i, 5, 5, C_RED)
	_px(i, 6, 6, C_RED)
	_px(i, 7, 7, C_RED)
	_px(i, 8, 6, C_RED)
	_px(i, 9, 5, C_RED)
	_px(i, 10, 4, C_RED)
	_px(i, 11, 3, C_RED)
	_px(i, 4, 3, C_CRIMSON)
	_px(i, 5, 4, C_CRIMSON)
	_px(i, 6, 5, C_CRIMSON)
	_px(i, 7, 6, C_CRIMSON)
	_px(i, 8, 5, C_CRIMSON)
	_px(i, 9, 4, C_CRIMSON)
	_px(i, 10, 3, C_CRIMSON)
	# Lower chevron (pointing down)
	_px(i, 3, 7, C_RED)
	_px(i, 4, 8, C_RED)
	_px(i, 5, 9, C_RED)
	_px(i, 6, 10, C_RED)
	_px(i, 7, 11, C_RED)
	_px(i, 8, 10, C_RED)
	_px(i, 9, 9, C_RED)
	_px(i, 10, 8, C_RED)
	_px(i, 11, 7, C_RED)
	_px(i, 4, 7, C_CRIMSON)
	_px(i, 5, 8, C_CRIMSON)
	_px(i, 6, 9, C_CRIMSON)
	_px(i, 7, 10, C_CRIMSON)
	_px(i, 8, 9, C_CRIMSON)
	_px(i, 9, 8, C_CRIMSON)
	_px(i, 10, 7, C_CRIMSON)

static func _draw_ab_reflect(i: Image) -> void:
	# Two opposing horizontal arrows with vertical divider line
	# Vertical divider
	_vline(i, 7, 3, 10, C_WHITE)
	_vline(i, 8, 3, 10, C_WHITE)
	# Left arrow (pointing left)
	_hline(i, 3, 7, 4, C_CYAN)
	_hline(i, 3, 8, 4, C_CYAN)
	_px(i, 4, 6, C_CYAN)
	_px(i, 4, 9, C_CYAN)
	_px(i, 3, 5, C_CYAN)
	_px(i, 3, 10, C_CYAN)
	_px(i, 2, 7, C_WHITE)
	_px(i, 2, 8, C_WHITE)
	# Right arrow (pointing right)
	_hline(i, 9, 7, 4, C_CYAN)
	_hline(i, 9, 8, 4, C_CYAN)
	_px(i, 11, 6, C_CYAN)
	_px(i, 11, 9, C_CYAN)
	_px(i, 12, 5, C_CYAN)
	_px(i, 12, 10, C_CYAN)
	_px(i, 13, 7, C_WHITE)
	_px(i, 13, 8, C_WHITE)

static func _draw_ab_freedom(i: Image) -> void:
	# Open padlock: rectangle body + open shackle arc
	# Lock body
	_rect(i, 4, 8, 8, 6, C_GREEN)
	_orect(i, 4, 8, 8, 6, C_DGREEN)
	# Keyhole
	_circle(i, 8, 10, 1, C_DGREEN)
	_rect(i, 8, 11, 1, 2, C_DGREEN)
	# Shackle (open, swung to right)
	_vline(i, 5, 4, 5, C_GOLD)
	_vline(i, 6, 4, 5, C_GOLD)
	_hline(i, 5, 4, 4, C_GOLD)
	_px(i, 8, 4, C_GOLD)
	_px(i, 9, 4, C_GOLD)
	_px(i, 10, 5, C_GOLD)
	_px(i, 10, 6, C_GOLD)
	_px(i, 10, 7, C_GOLD)
	# Shackle shadow
	_px(i, 7, 4, C_DGOLD)
	_px(i, 11, 5, C_DGOLD)
	_px(i, 11, 6, C_DGOLD)
	_px(i, 11, 7, C_DGOLD)

static func _draw_ab_default(i: Image) -> void:
	# Gray crossed swords (generic fallback)
	# Sword 1: top-left to bottom-right
	_px(i, 2, 2, C_WHITE)
	_px(i, 3, 3, C_LGRAY)
	_px(i, 4, 4, C_LGRAY)
	_px(i, 5, 5, C_LGRAY)
	# Guard 1
	_px(i, 5, 4, C_GRAY)
	_px(i, 6, 5, C_GRAY)
	_px(i, 4, 6, C_GRAY)
	# Blade 1 continues
	_px(i, 6, 6, C_LGRAY)
	_px(i, 7, 7, C_LGRAY)
	_px(i, 8, 8, C_LGRAY)
	_px(i, 9, 9, C_LGRAY)
	_px(i, 10, 10, C_LGRAY)
	_px(i, 11, 11, C_GRAY)
	_px(i, 12, 12, C_GRAY)
	# Sword 2: top-right to bottom-left
	_px(i, 13, 2, C_WHITE)
	_px(i, 12, 3, C_LGRAY)
	_px(i, 11, 4, C_LGRAY)
	_px(i, 10, 5, C_LGRAY)
	# Guard 2
	_px(i, 11, 5, C_GRAY)
	_px(i, 10, 6, C_GRAY)
	_px(i, 9, 5, C_GRAY)
	# Blade 2 continues
	_px(i, 9, 6, C_LGRAY)
	_px(i, 8, 7, C_LGRAY)
	_px(i, 7, 8, C_LGRAY)
	_px(i, 6, 9, C_LGRAY)
	_px(i, 5, 10, C_LGRAY)
	_px(i, 4, 11, C_GRAY)
	_px(i, 3, 12, C_GRAY)
	# Highlight on blades
	_px(i, 3, 2, C_WHITE)
	_px(i, 12, 2, C_WHITE)

# ═══════════════════════════════════════════
#  SKILL ICONS
# ═══════════════════════════════════════════

static func _generate_skill(skill_id: String) -> Image:
	var i: Image = _img()
	match skill_id:
		"nano": _draw_sk_nano(i)
		"tesla": _draw_sk_tesla(i)
		"void": _draw_sk_void(i)
		"astromining": _draw_sk_astromining(i)
		"xenobotany": _draw_sk_xenobotany(i)
		"bioforge": _draw_sk_bioforge(i)
		"circuitry": _draw_sk_circuitry(i)
		"xenocook": _draw_sk_xenocook(i)
		"psionics": _draw_sk_psionics(i)
		"chronomancy": _draw_sk_chronomancy(i)
		_: _draw_sk_nano(i)
	return i

static func _draw_sk_nano(i: Image) -> void:
	# Green microscope — tube + eyepiece + base
	# Base
	_hline(i, 4, 13, 8, C_DGREEN)
	_hline(i, 5, 12, 6, C_GREEN)
	# Stand
	_vline(i, 8, 6, 6, C_GREEN)
	_vline(i, 7, 6, 6, C_GREEN)
	# Tube (angled)
	_px(i, 6, 5, C_NGREEN)
	_px(i, 5, 4, C_NGREEN)
	_px(i, 4, 3, C_NGREEN)
	_px(i, 3, 2, C_GREEN)
	# Eyepiece
	_px(i, 2, 1, C_GREEN)
	_px(i, 3, 1, C_NGREEN)
	# Lens circle
	_circle(i, 6, 9, 1, C_CYAN)
	_px(i, 6, 9, C_WHITE)
	# Stage
	_hline(i, 5, 10, 4, C_DGREEN)

static func _draw_sk_tesla(i: Image) -> void:
	# Blue lightning bolt — Z shape
	_hline(i, 5, 2, 5, C_CYAN)
	_hline(i, 5, 3, 5, C_BLUE)
	_px(i, 9, 4, C_CYAN)
	_px(i, 8, 5, C_CYAN)
	_px(i, 7, 6, C_WHITE)
	_px(i, 8, 5, C_BLUE)
	_hline(i, 5, 7, 5, C_CYAN)
	_hline(i, 5, 8, 5, C_BLUE)
	_px(i, 5, 9, C_CYAN)
	_px(i, 6, 10, C_CYAN)
	_px(i, 7, 11, C_WHITE)
	_hline(i, 5, 12, 5, C_CYAN)
	_hline(i, 5, 13, 5, C_BLUE)

static func _draw_sk_void(i: Image) -> void:
	# Purple spiral vortex
	_circle_outline(i, 7, 7, 5, C_PURPLE)
	_circle_outline(i, 7, 7, 3, C_DPURPLE)
	_circle(i, 7, 7, 1, C_BLACK)
	# Spiral arm fragments
	_px(i, 10, 3, C_PINK)
	_px(i, 11, 4, C_PINK)
	_px(i, 3, 10, C_PINK)
	_px(i, 4, 11, C_PINK)
	_px(i, 12, 7, C_PURPLE)
	_px(i, 2, 7, C_PURPLE)

static func _draw_sk_astromining(i: Image) -> void:
	# Pickaxe — handle + head
	# Handle (diagonal)
	_px(i, 4, 12, C_BROWN)
	_px(i, 5, 11, C_BROWN)
	_px(i, 6, 10, C_BROWN)
	_px(i, 7, 9, C_BROWN)
	_px(i, 8, 8, C_DBROWN)
	# Pick head (angled right)
	_px(i, 9, 7, C_LGRAY)
	_px(i, 10, 6, C_LGRAY)
	_px(i, 11, 5, C_WHITE)
	_px(i, 12, 4, C_LGRAY)
	# Pick head (angled left)
	_px(i, 7, 7, C_LGRAY)
	_px(i, 6, 6, C_LGRAY)
	_px(i, 5, 5, C_WHITE)
	_px(i, 4, 4, C_LGRAY)
	# Ore sparkle
	_px(i, 12, 2, C_GOLD)
	_px(i, 13, 3, C_AMBER)

static func _draw_sk_xenobotany(i: Image) -> void:
	# Green leaf/sprout with stem
	# Stem
	_vline(i, 7, 8, 5, C_DGREEN)
	_vline(i, 8, 9, 4, C_DGREEN)
	# Left leaf
	_px(i, 5, 5, C_GREEN)
	_px(i, 4, 4, C_GREEN)
	_px(i, 5, 4, C_NGREEN)
	_px(i, 6, 4, C_NGREEN)
	_px(i, 6, 5, C_GREEN)
	_px(i, 6, 6, C_GREEN)
	_px(i, 7, 5, C_GREEN)
	_px(i, 7, 6, C_NGREEN)
	_px(i, 7, 7, C_GREEN)
	# Right leaf
	_px(i, 9, 5, C_GREEN)
	_px(i, 10, 4, C_GREEN)
	_px(i, 9, 4, C_NGREEN)
	_px(i, 10, 5, C_NGREEN)
	_px(i, 8, 5, C_GREEN)
	_px(i, 8, 6, C_GREEN)
	_px(i, 11, 4, C_GREEN)
	# Vein highlight
	_px(i, 6, 5, C_WHITE)
	_px(i, 9, 5, C_WHITE)

static func _draw_sk_bioforge(i: Image) -> void:
	# Teal DNA double helix
	# Strand 1 (left wave)
	_px(i, 5, 2, C_TEAL)
	_px(i, 4, 3, C_TEAL)
	_px(i, 4, 4, C_TEAL)
	_px(i, 5, 5, C_TEAL)
	_px(i, 7, 6, C_TEAL)
	_px(i, 9, 7, C_TEAL)
	_px(i, 10, 8, C_TEAL)
	_px(i, 10, 9, C_TEAL)
	_px(i, 9, 10, C_TEAL)
	_px(i, 7, 11, C_TEAL)
	_px(i, 5, 12, C_TEAL)
	_px(i, 4, 13, C_TEAL)
	# Strand 2 (right wave)
	_px(i, 10, 2, C_CYAN)
	_px(i, 11, 3, C_CYAN)
	_px(i, 11, 4, C_CYAN)
	_px(i, 10, 5, C_CYAN)
	_px(i, 8, 6, C_CYAN)
	_px(i, 6, 7, C_CYAN)
	_px(i, 5, 8, C_CYAN)
	_px(i, 5, 9, C_CYAN)
	_px(i, 6, 10, C_CYAN)
	_px(i, 8, 11, C_CYAN)
	_px(i, 10, 12, C_CYAN)
	_px(i, 11, 13, C_CYAN)
	# Rungs connecting strands
	_hline(i, 5, 5, 5, C_DGREEN)
	_hline(i, 6, 7, 3, C_DGREEN)
	_hline(i, 5, 9, 5, C_DGREEN)
	_hline(i, 6, 11, 3, C_DGREEN)

static func _draw_sk_circuitry(i: Image) -> void:
	# Orange wrench + gear
	# Wrench handle
	_vline(i, 4, 6, 7, C_ORANGE)
	_vline(i, 5, 6, 7, C_AMBER)
	# Wrench head (open jaw)
	_px(i, 3, 4, C_ORANGE)
	_px(i, 3, 5, C_ORANGE)
	_px(i, 6, 4, C_ORANGE)
	_px(i, 6, 5, C_ORANGE)
	_hline(i, 3, 3, 4, C_ORANGE)
	# Gear (right side)
	_circle_outline(i, 11, 7, 2, C_AMBER)
	_px(i, 11, 7, C_ORANGE)
	# Gear teeth
	_px(i, 11, 4, C_AMBER)
	_px(i, 11, 10, C_AMBER)
	_px(i, 8, 7, C_AMBER)
	_px(i, 14, 7, C_AMBER)

static func _draw_sk_xenocook(i: Image) -> void:
	# Amber frying pan — round pan + handle
	# Pan body
	_circle(i, 6, 7, 3, C_AMBER)
	_circle_outline(i, 6, 7, 3, C_BROWN)
	# Pan highlight
	_px(i, 5, 6, C_ORANGE)
	_px(i, 6, 6, C_ORANGE)
	# Handle
	_hline(i, 10, 7, 4, C_BROWN)
	_hline(i, 10, 8, 4, C_DBROWN)
	# Steam wisps
	_px(i, 5, 3, C_LGRAY)
	_px(i, 7, 2, C_LGRAY)
	_px(i, 6, 1, C_GRAY)

static func _draw_sk_psionics(i: Image) -> void:
	# Pink/magenta brain shape
	# Brain left hemisphere
	_circle(i, 5, 7, 3, C_PINK)
	# Brain right hemisphere
	_circle(i, 10, 7, 3, C_PINK)
	# Center divide
	_vline(i, 7, 4, 7, C_DPURPLE)
	_vline(i, 8, 4, 7, C_DPURPLE)
	# Brain folds (squiggly lines)
	_px(i, 4, 6, C_PURPLE)
	_px(i, 5, 5, C_PURPLE)
	_px(i, 6, 6, C_PURPLE)
	_px(i, 9, 6, C_PURPLE)
	_px(i, 10, 5, C_PURPLE)
	_px(i, 11, 6, C_PURPLE)
	# Glow
	_px(i, 7, 3, C_WHITE)
	_px(i, 8, 3, C_WHITE)

static func _draw_sk_chronomancy(i: Image) -> void:
	# Cyan hourglass
	# Top triangle
	_hline(i, 3, 2, 10, C_CYAN)
	_hline(i, 4, 3, 8, C_TEAL)
	_hline(i, 5, 4, 6, C_TEAL)
	_hline(i, 6, 5, 4, C_TEAL)
	# Neck
	_px(i, 7, 6, C_CYAN)
	_px(i, 8, 6, C_CYAN)
	_px(i, 7, 7, C_WHITE)
	_px(i, 8, 7, C_WHITE)
	_px(i, 7, 8, C_CYAN)
	_px(i, 8, 8, C_CYAN)
	# Bottom triangle
	_hline(i, 6, 9, 4, C_TEAL)
	_hline(i, 5, 10, 6, C_TEAL)
	_hline(i, 4, 11, 8, C_TEAL)
	_hline(i, 3, 12, 10, C_CYAN)
	# Sand particles
	_px(i, 7, 10, C_GOLD)
	_px(i, 8, 11, C_GOLD)
	_px(i, 7, 11, C_AMBER)

# ═══════════════════════════════════════════
#  BUFF ICONS
# ═══════════════════════════════════════════

static func _generate_buff(buff_type: String) -> Image:
	var i: Image = _img()
	match buff_type:
		"damage": _draw_bf_damage(i)
		"defense": _draw_bf_defense(i)
		"accuracy": _draw_bf_accuracy(i)
		"speed": _draw_bf_speed(i)
		"all": _draw_bf_all(i)
		"healOverTime": _draw_bf_heal(i)
		_: _draw_bf_all(i)
	return i

static func _draw_bf_damage(i: Image) -> void:
	# Orange crossed swords
	# Sword 1: top-left to bottom-right
	_px(i, 3, 3, C_WHITE)
	_px(i, 4, 4, C_ORANGE)
	_px(i, 5, 5, C_ORANGE)
	_px(i, 6, 6, C_ORANGE)
	_px(i, 7, 7, C_AMBER)
	_px(i, 8, 8, C_ORANGE)
	_px(i, 9, 9, C_ORANGE)
	_px(i, 10, 10, C_ORANGE)
	_px(i, 11, 11, C_AMBER)
	_px(i, 12, 12, C_WHITE)
	# Sword 2: top-right to bottom-left
	_px(i, 12, 3, C_WHITE)
	_px(i, 11, 4, C_ORANGE)
	_px(i, 10, 5, C_ORANGE)
	_px(i, 9, 6, C_ORANGE)
	_px(i, 6, 9, C_ORANGE)
	_px(i, 5, 10, C_ORANGE)
	_px(i, 4, 11, C_ORANGE)
	_px(i, 3, 12, C_WHITE)
	# Guards
	_px(i, 5, 6, C_AMBER)
	_px(i, 6, 5, C_AMBER)
	_px(i, 10, 9, C_AMBER)
	_px(i, 9, 10, C_AMBER)

static func _draw_bf_defense(i: Image) -> void:
	# Blue shield
	_hline(i, 4, 2, 8, C_BLUE)
	_hline(i, 3, 3, 10, C_BLUE)
	_hline(i, 3, 4, 10, C_NAVY)
	_hline(i, 3, 5, 10, C_NAVY)
	_hline(i, 3, 6, 10, C_BLUE)
	_hline(i, 4, 7, 8, C_BLUE)
	_hline(i, 4, 8, 8, C_NAVY)
	_hline(i, 5, 9, 6, C_NAVY)
	_hline(i, 5, 10, 6, C_BLUE)
	_hline(i, 6, 11, 4, C_BLUE)
	_hline(i, 7, 12, 2, C_NAVY)
	# Shield emblem — cross
	_vline(i, 7, 4, 5, C_WHITE)
	_vline(i, 8, 4, 5, C_WHITE)
	_hline(i, 5, 6, 6, C_WHITE)

static func _draw_bf_accuracy(i: Image) -> void:
	# Yellow crosshair / target circles
	_circle_outline(i, 7, 7, 5, C_GOLD)
	_circle_outline(i, 7, 7, 2, C_GOLD)
	_px(i, 7, 7, C_AMBER)
	# Crosshair lines
	_vline(i, 7, 1, 3, C_GOLD)
	_vline(i, 7, 11, 3, C_GOLD)
	_hline(i, 1, 7, 3, C_GOLD)
	_hline(i, 11, 7, 3, C_GOLD)

static func _draw_bf_speed(i: Image) -> void:
	# Green lightning bolt
	_hline(i, 6, 2, 4, C_NGREEN)
	_px(i, 9, 3, C_NGREEN)
	_px(i, 8, 4, C_NGREEN)
	_px(i, 7, 5, C_GREEN)
	_hline(i, 5, 6, 5, C_NGREEN)
	_hline(i, 5, 7, 5, C_GREEN)
	_px(i, 6, 8, C_NGREEN)
	_px(i, 7, 9, C_GREEN)
	_px(i, 8, 10, C_NGREEN)
	_hline(i, 5, 11, 4, C_NGREEN)
	_hline(i, 5, 12, 4, C_GREEN)
	# Glow
	_px(i, 7, 6, C_WHITE)

static func _draw_bf_all(i: Image) -> void:
	# Gold star
	# Center
	_rect(i, 6, 5, 4, 6, C_GOLD)
	# Top point
	_px(i, 7, 2, C_GOLD)
	_px(i, 8, 2, C_GOLD)
	_hline(i, 6, 3, 4, C_GOLD)
	_hline(i, 6, 4, 4, C_GOLD)
	# Left point
	_px(i, 2, 6, C_GOLD)
	_px(i, 3, 6, C_GOLD)
	_hline(i, 3, 7, 3, C_GOLD)
	_px(i, 4, 8, C_AMBER)
	# Right point
	_px(i, 13, 6, C_GOLD)
	_px(i, 12, 6, C_GOLD)
	_hline(i, 10, 7, 3, C_GOLD)
	_px(i, 11, 8, C_AMBER)
	# Bottom-left point
	_px(i, 4, 11, C_AMBER)
	_px(i, 5, 10, C_GOLD)
	_px(i, 4, 12, C_GOLD)
	# Bottom-right point
	_px(i, 11, 11, C_AMBER)
	_px(i, 10, 10, C_GOLD)
	_px(i, 11, 12, C_GOLD)
	# Center highlight
	_px(i, 7, 6, C_WHITE)
	_px(i, 8, 6, C_WHITE)

static func _draw_bf_heal(i: Image) -> void:
	# Green heart with + symbol
	# Heart top bumps
	_circle(i, 5, 5, 2, C_GREEN)
	_circle(i, 10, 5, 2, C_GREEN)
	# Heart body
	_hline(i, 3, 6, 10, C_GREEN)
	_hline(i, 4, 7, 8, C_GREEN)
	_hline(i, 4, 8, 8, C_GREEN)
	_hline(i, 5, 9, 6, C_DGREEN)
	_hline(i, 6, 10, 4, C_DGREEN)
	_hline(i, 7, 11, 2, C_DGREEN)
	# Plus symbol
	_vline(i, 7, 5, 4, C_WHITE)
	_hline(i, 6, 6, 3, C_WHITE)

# ═══════════════════════════════════════════
#  MISC ICONS
# ═══════════════════════════════════════════

static func _generate_misc(icon_id: String) -> Image:
	var i: Image = _img()
	match icon_id:
		"combat_swords": _draw_misc_combat_swords(i)
		"location_pin": _draw_misc_location_pin(i)
		"food": _draw_drumstick(i)
		"special_attack": _draw_misc_special_attack(i)
		_: return null
	return i

static func _draw_misc_combat_swords(i: Image) -> void:
	# Red/crimson crossed swords for IN COMBAT label
	# Sword 1: top-left to bottom-right
	_px(i, 2, 2, C_WHITE)
	_px(i, 3, 3, C_RED)
	_px(i, 4, 4, C_RED)
	_px(i, 5, 5, C_RED)
	_px(i, 6, 6, C_CRIMSON)
	_px(i, 7, 7, C_RED)
	_px(i, 8, 8, C_RED)
	_px(i, 9, 9, C_RED)
	_px(i, 10, 10, C_CRIMSON)
	_px(i, 11, 11, C_RED)
	_px(i, 12, 12, C_WHITE)
	# Sword 2: top-right to bottom-left
	_px(i, 12, 2, C_WHITE)
	_px(i, 11, 3, C_RED)
	_px(i, 10, 4, C_RED)
	_px(i, 9, 5, C_RED)
	_px(i, 8, 6, C_CRIMSON)
	_px(i, 6, 8, C_RED)
	_px(i, 5, 9, C_RED)
	_px(i, 4, 10, C_RED)
	_px(i, 3, 11, C_CRIMSON)
	_px(i, 2, 12, C_WHITE)
	# Guards
	_px(i, 4, 6, C_CRIMSON)
	_px(i, 6, 4, C_CRIMSON)
	_px(i, 10, 8, C_CRIMSON)
	_px(i, 8, 10, C_CRIMSON)

static func _draw_misc_location_pin(i: Image) -> void:
	# Red teardrop map pin with white center dot
	# Pin head (circle)
	_circle(i, 7, 5, 3, C_RED)
	_circle_outline(i, 7, 5, 4, C_CRIMSON)
	# Pin point (tapering down)
	_hline(i, 6, 9, 3, C_RED)
	_px(i, 7, 10, C_RED)
	_px(i, 7, 11, C_CRIMSON)
	# White center dot
	_px(i, 7, 5, C_WHITE)
	_px(i, 7, 4, C_WHITE)
	_px(i, 8, 5, C_WHITE)

static func _draw_misc_special_attack(i: Image) -> void:
	# Gold 4-pointed star burst
	# Vertical beam
	_vline(i, 7, 1, 14, C_GOLD)
	_vline(i, 8, 1, 14, C_GOLD)
	# Horizontal beam
	_hline(i, 1, 7, 14, C_GOLD)
	_hline(i, 1, 8, 14, C_GOLD)
	# Diagonal accents
	_px(i, 4, 4, C_AMBER)
	_px(i, 11, 4, C_AMBER)
	_px(i, 4, 11, C_AMBER)
	_px(i, 11, 11, C_AMBER)
	_px(i, 5, 5, C_GOLD)
	_px(i, 10, 5, C_GOLD)
	_px(i, 5, 10, C_GOLD)
	_px(i, 10, 10, C_GOLD)
	# Center glow
	_rect(i, 6, 6, 4, 4, C_GOLD)
	_px(i, 7, 7, C_WHITE)
	_px(i, 8, 7, C_WHITE)
	_px(i, 7, 8, C_WHITE)
	_px(i, 8, 8, C_WHITE)
