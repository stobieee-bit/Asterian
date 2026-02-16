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
var _condition_bars: Dictionary = {}  # { slot_name: ProgressBar }
var _stats_label: Label = null
var _repair_btn: Button = null
var _title_label: Label = null
var _close_btn: Button = null

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

	# Repair All button
	_repair_btn = Button.new()
	_repair_btn.text = "Repair All"
	_repair_btn.add_theme_font_size_override("font_size", 13)
	_repair_btn.custom_minimum_size = Vector2(0, 28)
	_repair_btn.visible = false  # Only shown when gear is degraded
	_repair_btn.pressed.connect(_on_repair_all)
	vbox.add_child(_repair_btn)

	# Connect signals
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)
	visibility_changed.connect(_on_visibility_changed)

	refresh()

## Create a centered HBoxContainer for layout rows
func _centered_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SLOT_GAP)
	return row

## Get pixel art texture for a slot type (empty state) — delegates to shared ItemIcons
func _slot_icon_texture(slot_name: String) -> ImageTexture:
	return ItemIcons.get_equip_slot_texture(slot_name)

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

	# Slot icon texture (pixel art — shows slot type when empty, item icon when equipped)
	var icon_tex: TextureRect = TextureRect.new()
	icon_tex.name = "SlotIconTex"
	icon_tex.position = Vector2(3, 3)
	icon_tex.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.texture = ItemIcons.get_equip_slot_texture(slot_name)
	icon_tex.modulate = Color(0.15, 0.22, 0.3, 0.3)
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_tex)

	# Hidden item label (kept for data reference, not displayed)
	var item_label: Label = Label.new()
	item_label.name = "ItemLabel"
	item_label.visible = false
	item_label.position = Vector2(0, 0)
	item_label.size = Vector2(0, 0)
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(item_label)

	# Condition bar overlay (small bar at bottom of slot, hidden by default)
	var cond_bar: ProgressBar = ProgressBar.new()
	cond_bar.name = "CondBar"
	cond_bar.position = Vector2(2, SLOT_SIZE - 7)
	cond_bar.size = Vector2(SLOT_SIZE - 4, 5)
	cond_bar.max_value = 100.0
	cond_bar.value = 100.0
	cond_bar.show_percentage = false
	cond_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cond_bar.visible = false
	var cond_bg: StyleBoxFlat = StyleBoxFlat.new()
	cond_bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	cond_bg.set_corner_radius_all(2)
	cond_bar.add_theme_stylebox_override("background", cond_bg)
	var cond_fill: StyleBoxFlat = StyleBoxFlat.new()
	cond_fill.bg_color = Color(0.2, 0.8, 0.3, 0.9)
	cond_fill.set_corner_radius_all(2)
	cond_bar.add_theme_stylebox_override("fill", cond_fill)
	inner.add_child(cond_bar)
	_condition_bars[slot_name] = cond_bar

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
		var slot_icon_tex: TextureRect = inner.get_node("SlotIconTex") as TextureRect
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat

		var item_id: String = str(GameState.equipment.get(slot_name, ""))
		if item_id != "":
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_name: String = str(item_data.get("name", item_id))
			var tier: int = int(item_data.get("tier", 1))

			# Store name for tooltip reference (hidden label)
			item_label.text = item_name

			var tc: Color = _tier_color(tier)

			# Show item-specific pixel art icon when equipped
			if slot_icon_tex:
				var icon_id: String = str(item_data.get("icon", ""))
				var tex: ImageTexture = ItemIcons.get_icon_texture(icon_id, "")
				if tex == null:
					tex = ItemIcons.get_equip_slot_texture(slot_name)
				slot_icon_tex.texture = tex
				slot_icon_tex.modulate = tc.lightened(0.2)

			if style:
				style.border_color = tc.darkened(0.2)
				style.border_color.a = 0.9
		else:
			if item_label:
				item_label.text = ""
			# Show slot placeholder icon when empty
			if slot_icon_tex:
				slot_icon_tex.texture = ItemIcons.get_equip_slot_texture(slot_name)
				slot_icon_tex.modulate = Color(0.2, 0.3, 0.4, 0.4)
			if style:
				style.border_color = Color(0.2, 0.4, 0.5, 0.7)

	# Update condition bars
	_update_condition_bars()

	# Update stats
	_update_stats()

	# Update repair button
	_update_repair_button()


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
	var set_bonus_text: String = ""
	if equip_sys:
		armor = equip_sys.get_total_armor()
		weapon_dmg = equip_sys.get_weapon_damage()

		# Check for set bonus
		if equip_sys.has_method("get_current_set_bonus"):
			var bonus: Dictionary = equip_sys.get_current_set_bonus()
			var pieces: int = int(bonus.get("pieces", 0))
			var style: String = str(bonus.get("style", ""))
			if pieces >= 3 and style != "":
				var desc: String = str(bonus.get("desc", ""))
				set_bonus_text = "\nSet (%s %d/5): %s" % [style.capitalize(), pieces, desc]

	_stats_label.text = "Armor: %d  |  Weapon: +%d dmg\nHP: %d/%d  |  Combat Lv: %d%s" % [
		armor, weapon_dmg,
		GameState.player["hp"], GameState.player["max_hp"],
		GameState.get_combat_level(),
		set_bonus_text,
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

	# Show Repair option if item is degraded (tier 5+)
	if tier >= 5:
		var cond: float = float(GameState.equipment_condition.get(slot_name, 1.0))
		if cond < 1.0:
			var player: Node = get_tree().get_first_node_in_group("player")
			var equip_sys: Node = null
			if player:
				equip_sys = player.get_node_or_null("EquipmentSystem")
			var cost: int = 0
			if equip_sys and equip_sys.has_method("get_repair_cost"):
				cost = equip_sys.get_repair_cost(slot_name)
			options.append({
				"label": "Repair (%d cr)" % cost,
				"icon": "R",
				"color": Color(0.3, 0.8, 0.5),
				"callback": func():
					if equip_sys and equip_sys.has_method("repair_slot"):
						equip_sys.repair_slot(slot_name)
					refresh()
			})

	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = str(item_data.get("desc", ""))
			if desc == "":
				desc = "Equipped %s." % slot_name
			# Add condition info for degradable items
			var cond_str: String = ""
			if tier >= 5:
				var cond2: float = float(GameState.equipment_condition.get(slot_name, 1.0))
				cond_str = " | Condition: %d%%" % int(cond2 * 100.0)
			EventBus.chat_message.emit(
				"Examine: %s — %s%s" % [item_name, desc, cond_str], "system"
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

func _on_close_pressed() -> void:
	visible = false
	EventBus.panel_closed.emit("equipment")

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	refresh()

func _on_visibility_changed() -> void:
	if visible:
		refresh()

## Update condition bars on each equipment slot
func _update_condition_bars() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var equip_sys: Node = null
	if player:
		equip_sys = player.get_node_or_null("EquipmentSystem")

	for slot_name in _condition_bars:
		var cond_bar: ProgressBar = _condition_bars[slot_name]
		var item_id: String = str(GameState.equipment.get(slot_name, ""))
		if item_id == "":
			cond_bar.visible = false
			continue

		var item_data: Dictionary = DataManager.get_item(item_id)
		var tier: int = int(item_data.get("tier", 1))
		if tier < 5:
			cond_bar.visible = false
			continue

		var cond: float = float(GameState.equipment_condition.get(slot_name, 1.0))
		cond_bar.value = cond * 100.0
		cond_bar.visible = true

		# Color the fill based on condition
		var fill_style: StyleBoxFlat = cond_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if cond > 0.5:
				fill_style.bg_color = Color(0.2, 0.8, 0.3, 0.9)  # Green
			elif cond > 0.25:
				fill_style.bg_color = Color(0.9, 0.7, 0.1, 0.9)  # Yellow
			else:
				fill_style.bg_color = Color(0.9, 0.2, 0.15, 0.9)  # Red

## Update the Repair All button visibility and text
func _update_repair_button() -> void:
	if _repair_btn == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		_repair_btn.visible = false
		return
	var equip_sys: Node = player.get_node_or_null("EquipmentSystem")
	if equip_sys == null or not equip_sys.has_method("has_degraded_equipment"):
		_repair_btn.visible = false
		return

	if equip_sys.has_degraded_equipment():
		var cost: int = equip_sys.get_total_repair_cost()
		_repair_btn.text = "Repair All (%d cr)" % cost
		_repair_btn.visible = true
		# Dim if can't afford
		if GameState.has_credits(cost):
			_repair_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			_repair_btn.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	else:
		_repair_btn.visible = false

## Handle Repair All button press
func _on_repair_all() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var equip_sys: Node = player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("repair_all"):
		equip_sys.repair_all()
	refresh()

## Tier color lookup
func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)

## Get pixel art texture for equipped item — delegates to shared ItemIcons
func _item_icon_texture(icon_name: String, slot_name: String) -> ImageTexture:
	var tex: ImageTexture = ItemIcons.get_icon_texture(icon_name, "")
	if tex == null:
		return _slot_icon_texture(slot_name)
	return tex
