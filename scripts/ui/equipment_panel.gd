## EquipmentPanel — Paper doll view with 7 equipment slots
##
## Shows the player's equipped items arranged in a humanoid layout:
##   [Head]
##   [Body]   [Weapon] [Offhand]
##   [Legs]
##   [Boots]  [Gloves]
## Plus total stats at the bottom.
extends PanelContainer

# ── Slot layout positions (relative grid) ──
const SLOT_SIZE: int = 56
const SLOT_GAP: int = 6

# ── Node refs ──
var _slot_nodes: Dictionary = {}  # { slot_name: PanelContainer }
var _stats_label: Label = null
var _title_label: Label = null
var _close_btn: Button = null
var _style_btn: Button = null

# Slot order for layout
var _slot_names: Array[String] = ["head", "body", "weapon", "offhand", "legs", "boots", "gloves"]

func _ready() -> void:
	custom_minimum_size = Vector2(240, 380)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Draggable header
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Equipment", _on_close_pressed)
	vbox.add_child(drag_header)

	# Combat style toggle
	var style_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(style_row)

	var style_label: Label = Label.new()
	style_label.text = "Style: "
	style_label.add_theme_font_size_override("font_size", 14)
	style_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	style_row.add_child(style_label)

	_style_btn = Button.new()
	_style_btn.text = _style_display_name(GameState.player["combat_style"])
	_style_btn.add_theme_font_size_override("font_size", 14)
	_style_btn.pressed.connect(_on_style_toggle)
	style_row.add_child(_style_btn)

	# Paper doll layout
	var doll: VBoxContainer = VBoxContainer.new()
	doll.add_theme_constant_override("separation", SLOT_GAP)
	doll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(doll)

	# Row 1: Head (centered)
	var row1: HBoxContainer = _centered_row()
	row1.add_child(_create_slot("head", "Head"))
	doll.add_child(row1)

	# Row 2: Weapon | Body | Offhand
	var row2: HBoxContainer = _centered_row()
	row2.add_child(_create_slot("weapon", "Weapon"))
	row2.add_child(_create_slot("body", "Body"))
	row2.add_child(_create_slot("offhand", "Offhand"))
	doll.add_child(row2)

	# Row 3: Legs (centered)
	var row3: HBoxContainer = _centered_row()
	row3.add_child(_create_slot("legs", "Legs"))
	doll.add_child(row3)

	# Row 4: Gloves | Boots
	var row4: HBoxContainer = _centered_row()
	row4.add_child(_create_slot("gloves", "Gloves"))
	row4.add_child(_create_slot("boots", "Boots"))
	doll.add_child(row4)

	# Stats summary
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.7))
	vbox.add_child(_stats_label)

	# Connect signals
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)

	refresh()

## Create a centered HBoxContainer for layout rows
func _centered_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SLOT_GAP)
	return row

## Get icon symbol for a slot type (empty state) — ASCII-safe
func _slot_icon(slot_name: String) -> String:
	match slot_name:
		"head":    return "He"
		"body":    return "Bd"
		"weapon":  return "Wp"
		"offhand": return "Oh"
		"legs":    return "Lg"
		"boots":   return "Bt"
		"gloves":  return "Gl"
		_: return "?"

## Create a single equipment slot
func _create_slot(slot_name: String, display_name: String) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.7)
	style.border_color = Color(0.1, 0.18, 0.25, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", style)

	# Inner control for absolute positioning
	var inner: Control = Control.new()
	inner.name = "Inner"
	inner.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)

	# Slot icon (large, centered — shows slot type when empty, item icon when equipped)
	var icon_label: Label = Label.new()
	icon_label.name = "SlotIcon"
	icon_label.text = _slot_icon(slot_name)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.position = Vector2(0, 0)
	icon_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.add_theme_color_override("font_color", Color(0.15, 0.22, 0.3, 0.3))
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_label)

	# Hidden item label (kept for data reference, not displayed)
	var item_label: Label = Label.new()
	item_label.name = "ItemLabel"
	item_label.visible = false
	item_label.position = Vector2(0, 0)
	item_label.size = Vector2(0, 0)
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(item_label)

	# Click handler
	slot.gui_input.connect(_on_slot_input.bind(slot_name))
	slot.mouse_entered.connect(_on_slot_hover.bind(slot_name))
	slot.mouse_exited.connect(_on_slot_exit)

	_slot_nodes[slot_name] = slot
	return slot

## Refresh all equipment slots and stats
func refresh() -> void:
	for slot_name in _slot_nodes:
		var slot: PanelContainer = _slot_nodes[slot_name]
		var inner: Control = slot.get_node("Inner") as Control
		var item_label: Label = inner.get_node("ItemLabel") as Label
		var slot_icon: Label = inner.get_node("SlotIcon") as Label
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat

		var item_id: String = str(GameState.equipment.get(slot_name, ""))
		if item_id != "":
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_name: String = str(item_data.get("name", item_id))
			var tier: int = int(item_data.get("tier", 1))

			# Store name for tooltip reference (hidden label)
			item_label.text = item_name

			var tc: Color = _tier_color(tier)

			# Show item-specific icon when equipped (icon-only, no text)
			if slot_icon:
				var icon_id: String = str(item_data.get("icon", ""))
				slot_icon.text = _item_icon(icon_id, slot_name)
				slot_icon.add_theme_color_override("font_color", tc.lightened(0.2))

			if style:
				style.border_color = tc.darkened(0.2)
				style.border_color.a = 0.9
		else:
			if item_label:
				item_label.text = ""
			# Show slot icon prominently when empty
			if slot_icon:
				slot_icon.text = _slot_icon(slot_name)
				slot_icon.add_theme_color_override("font_color", Color(0.2, 0.3, 0.4, 0.4))
			if style:
				style.border_color = Color(0.2, 0.4, 0.5, 0.7)

	# Update stats
	_update_stats()

	# Update style button
	if _style_btn:
		_style_btn.text = _style_display_name(GameState.player["combat_style"])

## Update the stats summary
func _update_stats() -> void:
	if _stats_label == null:
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	var equip_sys: Node = null
	if player:
		equip_sys = player.get_node_or_null("EquipmentSystem")

	var armor: int = 0
	var weapon_dmg: int = 0
	if equip_sys:
		armor = equip_sys.get_total_armor()
		weapon_dmg = equip_sys.get_weapon_damage()

	_stats_label.text = "Armor: %d  |  Weapon: +%d dmg\nHP: %d/%d  |  Combat Lv: %d" % [
		armor, weapon_dmg,
		GameState.player["hp"], GameState.player["max_hp"],
		GameState.get_combat_level()
	]

## Handle click on equipment slot
func _on_slot_input(event: InputEvent, slot_name: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var item_id: String = str(GameState.equipment.get(slot_name, ""))
		if item_id == "":
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click: show context menu with unequip option
			_show_equip_context_menu(item_id, slot_name, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			# Double-click: quick unequip
			_unequip_slot(slot_name)

## Unequip a slot
func _unequip_slot(slot_name: String) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var equip_sys: Node = player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("unequip_slot"):
		equip_sys.unequip_slot(slot_name)
	refresh()

## Show context menu for an equipped item
func _show_equip_context_menu(item_id: String, slot_name: String, screen_pos: Vector2) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_name: String = str(item_data.get("name", item_id))
	var tier: int = int(item_data.get("tier", 0))
	var tier_col: Color = _tier_color(tier)

	var options: Array = []
	options.append({"title": item_name, "title_color": tier_col})

	options.append({
		"label": "Unequip",
		"icon": "U",
		"color": Color(0.8, 0.6, 0.3),
		"callback": func(): _unequip_slot(slot_name)
	})

	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = str(item_data.get("desc", ""))
			if desc == "":
				desc = "Equipped %s." % slot_name
			EventBus.chat_message.emit(
				"Examine: %s — %s" % [item_name, desc], "system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Show tooltip on hover
func _on_slot_hover(slot_name: String) -> void:
	var item_id: String = str(GameState.equipment.get(slot_name, ""))
	if item_id == "":
		EventBus.tooltip_hidden.emit()
		return

	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	var tooltip_data: Dictionary = {
		"item_id": item_id,
		"item_data": item_data,
		"quantity": 1,
		"source": "equipment",
		"slot": slot_name,
	}
	EventBus.tooltip_requested.emit(tooltip_data, get_global_mouse_position())

func _on_slot_exit() -> void:
	EventBus.tooltip_hidden.emit()

## Toggle combat style: nano → tesla → void → nano
func _on_style_toggle() -> void:
	var current: String = str(GameState.player["combat_style"])
	match current:
		"nano":
			GameState.player["combat_style"] = "tesla"
		"tesla":
			GameState.player["combat_style"] = "void"
		_:
			GameState.player["combat_style"] = "nano"
	refresh()
	EventBus.chat_message.emit(
		"Combat style: %s" % _style_display_name(GameState.player["combat_style"]),
		"system"
	)

func _on_close_pressed() -> void:
	visible = false
	EventBus.panel_closed.emit("equipment")

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	refresh()

## Style name with color hint
func _style_display_name(style: String) -> String:
	match style:
		"nano": return "Nano"
		"tesla": return "Tesla"
		"void": return "Void"
		_: return style.capitalize()

## Tier color lookup
func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)

## Get icon symbol for equipped item (from item data icon field) — ASCII-safe
func _item_icon(icon_name: String, slot_name: String) -> String:
	match icon_name:
		"icon_nanoblade":  return "Nb"
		"icon_coilgun":    return "Cg"
		"icon_voidstaff":  return "Vs"
		"icon_capacitor":  return "Zp"
		"icon_helmet":     return "He"
		"icon_vest":       return "Ve"
		"icon_greaves":    return "Lg"
		"icon_boots":      return "Bo"
		"icon_gloves":     return "Gl"
		"icon_shield":     return "Sh"
		"icon_crown":      return "Cw"
	# Fallback to slot default
	return _slot_icon(slot_name)
