## BestiaryPanel — Enemy log showing all discovered and undiscovered enemies
##
## Displays a scrollable list of enemies sorted by combat level. Discovered
## enemies (present in GameState.collection_log) show full stats colored by
## combat style; undiscovered enemies display "???" in dark gray. Automatically
## updates when an enemy is killed.
extends PanelContainer

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _summary_label: Label = null
var _scroll: ScrollContainer = null
var _list_container: VBoxContainer = null

func _ready() -> void:
	custom_minimum_size = Vector2(340, 400)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Bestiary", _on_close_pressed)
	vbox.add_child(drag_header)

	# ── Stats summary: "X / Y Enemies Discovered" ──
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(_summary_label)

	# ── Scrollable enemy list ──
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list_container)

	# ── Connect signals ──
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Initial draw
	refresh()

# ── Public API ──────────────────────────────────────────────────────────────

## Rebuild the entire enemy list from DataManager + GameState
func refresh() -> void:
	# Clear existing rows
	for child in _list_container.get_children():
		child.queue_free()

	# Gather all enemy type IDs and sort by combat level ascending
	var all_enemies: Array[Dictionary] = _get_sorted_enemies()
	var total_count: int = all_enemies.size()
	var discovered_count: int = GameState.collection_log.size()

	# Bestiary loot bonus: +1% per 10 entries, max +10%
	var loot_bonus: float = minf(10.0, float(discovered_count) * 0.1)
	var next_milestone: int = (int(discovered_count / 10) + 1) * 10

	# Update summary
	_summary_label.text = "%d / %d Discovered  |  Loot Bonus: +%.1f%%\nNext bonus at %d entries" % [
		discovered_count, total_count, loot_bonus, next_milestone
	]

	# Build a row for each enemy
	for enemy_entry in all_enemies:
		var type_id: String = str(enemy_entry["type_id"])
		var is_discovered: bool = GameState.collection_log.has(type_id)

		if is_discovered:
			_add_discovered_row(type_id, enemy_entry)
		else:
			_add_undiscovered_row()

# ── Signal callbacks ────────────────────────────────────────────────────────

## Called when any enemy is killed — add to collection_log if new, then refresh
func _on_enemy_killed(_enemy_id: String, enemy_type: String) -> void:
	if not GameState.collection_log.has(enemy_type):
		GameState.collection_log.append(enemy_type)
	refresh()

## Close button handler
func _on_close_pressed() -> void:
	visible = false
	EventBus.panel_closed.emit("bestiary")

# ── Private helpers ─────────────────────────────────────────────────────────

## Collect all enemies from DataManager and return sorted by level asc
func _get_sorted_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for type_id in DataManager.enemies:
		var data: Dictionary = DataManager.enemies[type_id]
		result.append({
			"type_id": type_id,
			"level": int(data.get("level", 0)),
		})

	# Sort ascending by level
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["level"] < b["level"]
	)
	return result

## Build a row for a discovered (known) enemy with full stats
func _add_discovered_row(type_id: String, _entry: Dictionary) -> void:
	var data: Dictionary = DataManager.get_enemy(type_id)
	if data.is_empty():
		return

	var enemy_name: String = str(data.get("name", type_id))
	var combat_level: int = int(data.get("level", 0))
	var hp: int = int(data.get("hp", 0))
	var combat_style: String = str(data.get("combatStyle", ""))
	var area: String = str(data.get("area", "unknown"))
	var atk_damage: int = int(data.get("damage", 0))

	# Container for this enemy entry
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	_list_container.add_child(row)

	# ── Line 1: Name (colored by style) + combat level ──
	var line1: HBoxContainer = HBoxContainer.new()
	row.add_child(line1)

	var name_label: Label = Label.new()
	name_label.text = enemy_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", _style_color(combat_style))
	line1.add_child(name_label)

	var level_label: Label = Label.new()
	level_label.text = "Lv %d" % combat_level
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	line1.add_child(level_label)

	# ── Line 2: HP, Attack, Area ──
	var line2: HBoxContainer = HBoxContainer.new()
	row.add_child(line2)

	# Determine zone name from enemy level + area
	var enemy_level: int = int(data.get("level", 0))
	var zone_name: String = _find_zone_name(area, enemy_level)
	var location_text: String
	if zone_name != "":
		location_text = "%s, %s" % [zone_name, _format_area(area)]
	else:
		location_text = _format_area(area)

	var stats_label: Label = Label.new()
	stats_label.text = "HP: %d  |  Atk: %d" % [hp, atk_damage]
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.6))
	line2.add_child(stats_label)

	# ── Location line: zone + area ──
	var loc_hbox: HBoxContainer = HBoxContainer.new()
	loc_hbox.add_theme_constant_override("separation", 3)
	row.add_child(loc_hbox)

	var pin_icon: TextureRect = TextureRect.new()
	pin_icon.custom_minimum_size = Vector2(12, 12)
	pin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pin_icon.texture = ItemIcons.get_misc_texture("location_pin")
	loc_hbox.add_child(pin_icon)

	var loc_label: Label = Label.new()
	loc_label.text = location_text
	loc_label.add_theme_font_size_override("font_size", 12)
	loc_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	loc_hbox.add_child(loc_label)

	# ── Line 3: Weakness + Defense info (unlocked at 10+ bestiary entries) ──
	var entry_count: int = GameState.collection_log.size()
	if entry_count >= 10:
		var weakness: String = _get_weakness(combat_style)
		var defense_val: int = int(data.get("defense", 0))
		var weak_label: Label = Label.new()
		weak_label.text = "Weak to: %s  |  Def: %d" % [weakness, defense_val]
		weak_label.add_theme_font_size_override("font_size", 12)
		weak_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		row.add_child(weak_label)

	# ── Line 4: Drop table (unlocked at 25+ bestiary entries) ──
	if entry_count >= 25:
		var loot_table: Array = data.get("lootTable", [])
		if loot_table.size() > 0:
			var drop_parts: Array[String] = []
			for drop in loot_table:
				var did: String = str(drop.get("itemId", ""))
				var dchance: float = float(drop.get("chance", 0.0)) * 100.0
				if did == "credits":
					drop_parts.append("Credits (%d%%)" % int(dchance))
				else:
					var ditem: Dictionary = DataManager.get_item(did)
					var dname: String = str(ditem.get("name", did))
					drop_parts.append("%s (%d%%)" % [dname, int(dchance)])
			var drops_label: Label = Label.new()
			drops_label.text = "Drops: %s" % ", ".join(drop_parts)
			drops_label.add_theme_font_size_override("font_size", 11)
			drops_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			drops_label.clip_text = true
			drops_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			drops_label.custom_minimum_size.x = 310
			row.add_child(drops_label)

	# ── Kill count from boss_kills ──
	var kill_count: int = int(GameState.boss_kills.get(type_id, 0))
	if kill_count > 0:
		var kill_label: Label = Label.new()
		kill_label.text = "Kills: %d" % kill_count
		kill_label.add_theme_font_size_override("font_size", 13)
		kill_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		row.add_child(kill_label)

	# Subtle separator line
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	_list_container.add_child(sep)

## Build a placeholder row for an undiscovered enemy
func _add_undiscovered_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_list_container.add_child(row)

	var unknown_label: Label = Label.new()
	unknown_label.text = "???"
	unknown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unknown_label.add_theme_font_size_override("font_size", 15)
	unknown_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	row.add_child(unknown_label)

	# Subtle separator line
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	_list_container.add_child(sep)

## Return color for a combat style: nano=cyan, tesla=yellow, void=purple
func _style_color(combat_style: String) -> Color:
	match combat_style:
		"nano":  return Color(0.3, 0.9, 1.0)   # Cyan
		"tesla": return Color(1.0, 0.9, 0.3)   # Yellow
		"void":  return Color(0.7, 0.4, 1.0)   # Purple
		_:       return Color(0.7, 0.7, 0.7)   # Fallback gray

## Get the weakness of an enemy based on combat style triangle:
## nano → weak to tesla, tesla → weak to void, void → weak to nano
func _get_weakness(combat_style: String) -> String:
	match combat_style:
		"nano":  return "Tesla ⚡"
		"tesla": return "Void 🌀"
		"void":  return "Nano 🔬"
		_:       return "None"

## Find the sub-zone name for an enemy based on its area and level
func _find_zone_name(enemy_area: String, enemy_level: int) -> String:
	var best_name: String = ""
	var best_range: int = 9999  # Tightest level range wins
	for zone in DataManager.enemy_sub_zones:
		var z_area: String = str(zone.get("area", ""))
		if z_area != enemy_area:
			continue
		var z_min: int = int(zone.get("levelMin", 0))
		var z_max: int = int(zone.get("levelMax", 0))
		if enemy_level >= z_min and enemy_level <= z_max:
			var range_span: int = z_max - z_min
			if range_span < best_range:
				best_range = range_span
				best_name = str(zone.get("name", ""))
	return best_name

## Format area slug to display name: "alien-wastes" → "Alien Wastes"
func _format_area(area: String) -> String:
	return area.replace("-", " ").capitalize()
