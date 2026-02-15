## TooltipPanel — Follows mouse, shows item stats on hover
##
## Listens to EventBus.tooltip_requested and tooltip_hidden signals.
## Positions itself near the mouse and shows item name, type, tier, stats, desc.
## When hovering inventory gear, shows stat comparison vs currently equipped item.
extends PanelContainer

# ── Node refs ──
var _name_label: Label = null
var _type_label: Label = null
var _stats_label: Label = null
var _compare_label: Label = null  # Stat comparison vs equipped
var _desc_label: Label = null
var _vbox: VBoxContainer = null

# ── State ──
var _is_showing: bool = false
var _follow_mouse: bool = true

func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.06, 0.92)
	style.border_color = Color(0.1, 0.25, 0.35, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_vbox.add_child(_name_label)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 13)
	_type_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65, 0.8))
	_vbox.add_child(_type_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6, 0.9))
	_vbox.add_child(_stats_label)

	_compare_label = Label.new()
	_compare_label.add_theme_font_size_override("font_size", 13)
	_compare_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.85))
	_compare_label.visible = false
	_vbox.add_child(_compare_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.75))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = 190
	_vbox.add_child(_desc_label)

	# Start hidden
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	# Connect signals
	EventBus.tooltip_requested.connect(_on_tooltip_requested)
	EventBus.tooltip_hidden.connect(_on_tooltip_hidden)

func _process(_delta: float) -> void:
	if _is_showing and _follow_mouse:
		_position_near_mouse()

## Show tooltip with item data or generic data (stations, NPCs, etc.)
func _on_tooltip_requested(data: Dictionary, _global_pos: Vector2) -> void:
	# ── Generic tooltip (stations, NPCs, world objects) ──
	if data.has("title") and data.has("lines"):
		_show_generic_tooltip(data)
		return

	var item_data: Dictionary = data.get("item_data", {})
	if item_data.is_empty():
		_on_tooltip_hidden()
		return

	var item_name: String = str(item_data.get("name", "Unknown"))
	var item_type: String = str(item_data.get("type", "misc"))
	var tier: int = int(item_data.get("tier", 0))
	var desc: String = str(item_data.get("desc", ""))
	var quantity: int = int(data.get("quantity", 1))
	var source: String = str(data.get("source", ""))

	# Name (colored by tier)
	_name_label.text = item_name
	_name_label.add_theme_color_override("font_color", _tier_color(tier))

	# Reset fields that generic tooltips may have changed
	_type_label.visible = true
	_stats_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))

	# Type line
	var tier_name: String = _tier_name(tier)
	var type_text: String = item_type.capitalize()
	if tier > 0:
		type_text = "%s %s" % [tier_name, type_text]
	if quantity > 1:
		type_text += " (x%d)" % quantity
	_type_label.text = type_text

	# Stats
	var stats_lines: Array[String] = []

	# Weapon stats
	var damage: int = int(item_data.get("damage", 0))
	if damage > 0:
		stats_lines.append("Damage: +%d" % damage)
	var accuracy: int = int(item_data.get("accuracy", 0))
	if accuracy > 0:
		stats_lines.append("Accuracy: %d%%" % accuracy)

	# Armor stats
	var armor: int = int(item_data.get("armor", 0))
	if armor > 0:
		stats_lines.append("Armor: +%d" % armor)

	# Style
	var style: String = str(item_data.get("style", ""))
	if style != "":
		stats_lines.append("Style: %s" % style.capitalize())

	# Combat style
	var combat_style: String = str(item_data.get("combatStyle", ""))
	if combat_style != "":
		stats_lines.append("Combat: %s" % combat_style.capitalize())

	# Heal amount for food
	var heal: int = int(item_data.get("heals", int(item_data.get("heal", 0))))
	if heal > 0:
		stats_lines.append("Heals: %d HP" % heal)

	# Value
	var value: int = int(item_data.get("value", 0))
	if value > 0:
		stats_lines.append("Value: %d credits" % value)

	# Level requirement
	var level_req: int = int(item_data.get("levelReq", 0))
	if level_req > 0:
		stats_lines.append("Requires: Combat Lv %d" % level_req)

	# Skill requirements
	var equip_req: Variant = item_data.get("equipReq", {})
	if equip_req is Dictionary:
		for skill_id in equip_req:
			var req_level: int = int(equip_req[skill_id])
			var skill_data: Dictionary = DataManager.get_skill(skill_id)
			var skill_name: String = str(skill_data.get("name", skill_id))
			stats_lines.append("Requires: %s Lv %d" % [skill_name, req_level])

	# Special effects
	var special: String = str(item_data.get("special", ""))
	if special != "":
		stats_lines.append("Special: %s" % special.capitalize())

	_stats_label.text = "\n".join(stats_lines) if stats_lines.size() > 0 else ""
	_stats_label.visible = stats_lines.size() > 0

	# ── Stat comparison vs equipped gear ──
	_compare_label.visible = false
	if source == "inventory" and item_type in ["weapon", "armor", "offhand"]:
		var compare_text: String = _build_comparison(item_data, item_type)
		if compare_text != "":
			_compare_label.text = compare_text
			_compare_label.visible = true

	# Description
	_desc_label.text = desc
	_desc_label.visible = desc != ""

	# Show
	visible = true
	_is_showing = true
	_position_near_mouse()

## Show a generic tooltip with title + colored lines (for stations, NPCs, etc.)
func _show_generic_tooltip(data: Dictionary) -> void:
	var title: String = str(data.get("title", ""))
	var title_color: Color = data.get("title_color", Color.WHITE)
	var lines: Array = data.get("lines", [])

	# Title
	_name_label.text = title
	_name_label.add_theme_color_override("font_color", title_color)

	# Build lines into stats area
	var line_texts: Array[String] = []
	for line in lines:
		if line is Dictionary:
			line_texts.append(str(line.get("text", "")))
		else:
			line_texts.append(str(line))

	_type_label.text = ""
	_type_label.visible = false
	_stats_label.text = "\n".join(line_texts) if line_texts.size() > 0 else ""
	_stats_label.visible = line_texts.size() > 0
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.65))
	_compare_label.visible = false
	_desc_label.text = ""
	_desc_label.visible = false

	visible = true
	_is_showing = true
	_position_near_mouse()

func _on_tooltip_hidden() -> void:
	visible = false
	_is_showing = false

## Build stat comparison text between hovered item and currently equipped item
func _build_comparison(item_data: Dictionary, item_type: String) -> String:
	# Determine which equipment slot(s) this item would fill
	var target_slot: String = _get_equip_slot(item_data, item_type)
	if target_slot == "":
		return ""

	# Get currently equipped item in that slot
	var equipped_id: String = str(GameState.equipment.get(target_slot, ""))
	if equipped_id == "":
		return "-- vs: (empty slot) --"

	var equipped_data: Dictionary = DataManager.get_item(equipped_id)
	if equipped_data.is_empty():
		return ""

	var lines: Array[String] = []
	var equipped_name: String = str(equipped_data.get("name", equipped_id))
	lines.append("-- vs %s --" % equipped_name)

	# Compare key stats
	var stats_to_compare: Array[Array] = [
		["damage", "Damage"],
		["accuracy", "Accuracy"],
		["armor", "Armor"],
	]

	for stat_pair in stats_to_compare:
		var key: String = stat_pair[0]
		var label: String = stat_pair[1]
		var new_val: int = int(item_data.get(key, 0))
		var old_val: int = int(equipped_data.get(key, 0))

		if new_val == 0 and old_val == 0:
			continue

		var diff: int = new_val - old_val
		if diff > 0:
			lines.append("  %s: +%d (better)" % [label, diff])
		elif diff < 0:
			lines.append("  %s: %d (worse)" % [label, diff])
		else:
			lines.append("  %s: same" % label)

	if lines.size() <= 1:
		return ""

	return "\n".join(lines)

## Determine which equipment slot an item would go into
func _get_equip_slot(item_data: Dictionary, item_type: String) -> String:
	var slot: String = str(item_data.get("slot", ""))
	if slot != "":
		return slot

	# Infer from type
	match item_type:
		"weapon":
			return "weapon"
		"offhand":
			return "offhand"
		"armor":
			# Check sub-slot from style field
			var equip_slot: String = str(item_data.get("equipSlot", ""))
			if equip_slot != "":
				return equip_slot
			# Default to body for armor
			return "body"
		_:
			return ""

## Position tooltip near mouse but within viewport
func _position_near_mouse() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = get_viewport_rect().size
	var tt_size: Vector2 = size

	# Offset from cursor
	var pos: Vector2 = mouse + Vector2(16, 16)

	# Clamp to viewport
	if pos.x + tt_size.x > viewport_size.x:
		pos.x = mouse.x - tt_size.x - 8
	if pos.y + tt_size.y > viewport_size.y:
		pos.y = mouse.y - tt_size.y - 8

	global_position = pos

## Tier color from equipment data
func _tier_color(tier: int) -> Color:
	if tier <= 0:
		return Color(0.8, 0.8, 0.8)
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)

## Tier name from equipment data
func _tier_name(tier: int) -> String:
	if tier <= 0:
		return ""
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return str(tiers[tier_str].get("name", "Tier %d" % tier))
	return "Tier %d" % tier
