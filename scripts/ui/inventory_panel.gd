## InventoryPanel — 28-slot inventory grid with drag/drop and right-click equip
##
## Shows items as colored slots in a 7x4 grid. Right-click to equip weapons/armor.
## Double-click to equip. Inventory data lives in GameState.inventory.
extends PanelContainer

# ── Constants ──
const COLS: int = 7
const ROWS: int = 4
const SLOT_SIZE: int = 48
const SLOT_PADDING: int = 4

# ── Node refs ──
var _grid: GridContainer = null
var _slots: Array[PanelContainer] = []
var _title_label: Label = null
var _close_btn: Button = null

# ── State ──
var _is_dragging: bool = false
var _drag_index: int = -1

func _ready() -> void:
	# Panel style
	custom_minimum_size = Vector2(
		COLS * (SLOT_SIZE + SLOT_PADDING) + 24,
		ROWS * (SLOT_SIZE + SLOT_PADDING) + 60
	)

	# Build UI tree
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Draggable header (replaces old static header)
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Inventory", _on_close_pressed)
	vbox.add_child(drag_header)

	# Grid
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", SLOT_PADDING)
	_grid.add_theme_constant_override("v_separation", SLOT_PADDING)
	vbox.add_child(_grid)

	# Create 28 slots
	for i in range(COLS * ROWS):
		var slot: PanelContainer = _create_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)

	# Connect to signals for live updates
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)

	# Initial refresh
	refresh()

## Create a single inventory slot
func _create_slot(index: int) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# Style: dark background
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	style.border_color = Color(0.2, 0.3, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", style)

	# Inner container for free positioning of children
	var inner: Control = Control.new()
	inner.name = "Inner"
	inner.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)

	# Icon background (colored square, fills most of slot)
	var icon_rect: ColorRect = ColorRect.new()
	icon_rect.name = "IconRect"
	icon_rect.position = Vector2(4, 4)
	icon_rect.size = Vector2(40, 40)
	icon_rect.color = Color(0.15, 0.2, 0.3, 0.0)  # Hidden by default
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_rect)

	# Icon symbol (centered, larger for icon-only display)
	var icon_sym: Label = Label.new()
	icon_sym.name = "IconSymbol"
	icon_sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_sym.add_theme_font_size_override("font_size", 22)
	icon_sym.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	icon_sym.position = Vector2(4, 2)
	icon_sym.size = Vector2(40, 40)
	icon_sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_sym)

	# Hidden item label (kept for data reference, not displayed)
	var label: Label = Label.new()
	label.name = "ItemLabel"
	label.visible = false
	label.position = Vector2(0, 0)
	label.size = Vector2(0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(label)

	# Quantity label (top-right corner)
	var qty_label: Label = Label.new()
	qty_label.name = "QtyLabel"
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	qty_label.add_theme_font_size_override("font_size", 9)
	qty_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	qty_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	qty_label.add_theme_constant_override("shadow_offset_x", 1)
	qty_label.add_theme_constant_override("shadow_offset_y", 1)
	qty_label.position = Vector2(0, 0)
	qty_label.size = Vector2(SLOT_SIZE, 16)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(qty_label)

	# Connect click
	slot.gui_input.connect(_on_slot_input.bind(index))
	slot.mouse_entered.connect(_on_slot_hover.bind(index))
	slot.mouse_exited.connect(_on_slot_exit)

	return slot

## Refresh all slots from GameState.inventory
func refresh() -> void:
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		var inner: Control = slot.get_node("Inner") as Control
		var item_label: Label = inner.get_node("ItemLabel") as Label
		var qty_label: Label = inner.get_node("QtyLabel") as Label
		var icon_rect: ColorRect = inner.get_node("IconRect") as ColorRect
		var icon_sym: Label = inner.get_node("IconSymbol") as Label
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat

		if i < GameState.inventory.size():
			var entry: Dictionary = GameState.inventory[i]
			var item_id: String = str(entry.get("item_id", ""))
			var quantity: int = int(entry.get("quantity", 1))
			var item_data: Dictionary = DataManager.get_item(item_id)

			var item_name: String = str(item_data.get("name", item_id))
			var item_type: String = str(item_data.get("type", ""))
			var tier: int = int(item_data.get("tier", 1))
			var tier_col: Color = _tier_color(tier)

			# Show icon background colored by item type
			icon_rect.color = _type_icon_color(item_type)
			icon_rect.color.a = 0.7

			# Show icon symbol from item's icon field (or fallback to type)
			var icon_id: String = str(item_data.get("icon", ""))
			icon_sym.text = _item_icon_symbol(icon_id, item_type)
			icon_sym.add_theme_color_override("font_color", tier_col.lightened(0.3))

			# Store name for tooltip reference (not displayed)
			item_label.text = item_name

			qty_label.text = str(quantity) if quantity > 1 else ""

			# Colored border for higher tiers
			if style:
				style.border_color = tier_col.darkened(0.3)
				style.border_color.a = 0.8
		else:
			item_label.text = ""
			qty_label.text = ""
			icon_rect.color = Color(0.15, 0.2, 0.3, 0.0)
			icon_sym.text = ""
			if style:
				style.border_color = Color(0.2, 0.3, 0.4, 0.6)

## Handle slot click input
func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if index >= GameState.inventory.size():
			return

		var entry: Dictionary = GameState.inventory[index]
		var item_id: String = str(entry.get("item_id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_type: String = str(item_data.get("type", ""))

		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			# Double-click to equip
			if item_type in ["weapon", "armor", "offhand"]:
				_equip_from_slot(item_id)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click context menu
			_show_item_context_menu(item_id, item_data, item_type, index, get_global_mouse_position())

## Try to equip item
func _equip_from_slot(item_id: String) -> void:
	# Find equipment system on player
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var equip_sys: Node = player.get_node_or_null("EquipmentSystem")
	if equip_sys and equip_sys.has_method("equip_item"):
		equip_sys.equip_item(item_id)
	refresh()

## Eat food to heal
func _eat_food(item_id: String, _index: int) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	var heal: int = int(item_data.get("heals", int(item_data.get("heal", 10))))
	if GameState.player["hp"] >= GameState.player["max_hp"]:
		EventBus.chat_message.emit("Already at full HP.", "system")
		return
	GameState.remove_item(item_id)
	GameState.player["hp"] = mini(GameState.player["hp"] + heal, GameState.player["max_hp"])
	EventBus.player_healed.emit(heal)
	var item_name: String = str(item_data.get("name", item_id))
	EventBus.chat_message.emit("Ate %s, healed %d HP." % [item_name, heal], "system")

	# Float text
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		EventBus.float_text_requested.emit(
			"+%d" % heal,
			player.global_position + Vector3(0, 2.8, 0),
			Color(0.2, 1.0, 0.3)
		)
	refresh()

## Show tooltip on hover
func _on_slot_hover(index: int) -> void:
	if index >= GameState.inventory.size():
		EventBus.tooltip_hidden.emit()
		return

	var entry: Dictionary = GameState.inventory[index]
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	var tooltip_data: Dictionary = {
		"item_id": item_id,
		"item_data": item_data,
		"quantity": int(entry.get("quantity", 1)),
		"source": "inventory",
	}
	EventBus.tooltip_requested.emit(tooltip_data, get_global_mouse_position())

func _on_slot_exit() -> void:
	EventBus.tooltip_hidden.emit()

func _on_close_pressed() -> void:
	visible = false
	EventBus.panel_closed.emit("inventory")

func _on_inventory_changed(_item_id: String, _qty: int) -> void:
	refresh()

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	refresh()

## Show right-click context menu for an inventory item
func _show_item_context_menu(item_id: String, item_data: Dictionary, item_type: String, index: int, screen_pos: Vector2) -> void:
	var item_name: String = str(item_data.get("name", item_id))
	var tier: int = int(item_data.get("tier", 0))
	var tier_col: Color = _tier_color(tier)
	var quantity: int = int(GameState.inventory[index].get("quantity", 1))
	var qty_text: String = " x%d" % quantity if quantity > 1 else ""

	var options: Array = []
	options.append({
		"title": "%s%s" % [item_name, qty_text],
		"title_color": tier_col,
	})

	# Equip option for gear
	if item_type in ["weapon", "armor", "offhand"]:
		options.append({
			"label": "Equip",
			"icon": "E",
			"color": Color(0.3, 0.85, 1.0),
			"callback": func(): _equip_from_slot(item_id)
		})

	# Eat option for food
	if item_type == "food":
		options.append({
			"label": "Eat",
			"icon": "F",
			"color": Color(0.3, 1.0, 0.3),
			"keybind": "F",
			"callback": func(): _eat_food(item_id, index)
		})

	# Use option for consumables
	if item_type == "consumable":
		options.append({
			"label": "Use",
			"icon": "U",
			"color": Color(0.9, 0.8, 0.2),
			"callback": func():
				EventBus.chat_message.emit("Used %s." % item_name, "system")
		})

	# Drop option for all items
	options.append({
		"label": "Drop",
		"icon": "D",
		"color": Color(0.8, 0.4, 0.3),
		"callback": func():
			GameState.remove_item(item_id, 1)
			EventBus.chat_message.emit("Dropped %s." % item_name, "system")
			refresh()
	})

	# Examine option for all items
	options.append({
		"label": "Examine",
		"icon": "?",
		"color": Color(0.6, 0.7, 0.8),
		"callback": func():
			var desc: String = str(item_data.get("desc", ""))
			if desc == "":
				desc = "A %s item." % item_type
			var value: int = int(item_data.get("value", 0))
			var value_text: String = " (Value: %d cr)" % value if value > 0 else ""
			EventBus.chat_message.emit(
				"Examine: %s — %s%s" % [item_name, desc, value_text],
				"system"
			)
	})

	EventBus.context_menu_requested.emit(options, screen_pos)

## Get tier color
func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)

## Get background color for item type icon
func _type_icon_color(item_type: String) -> Color:
	match item_type:
		"weapon":      return Color(0.7, 0.2, 0.2)   # Red
		"armor":       return Color(0.25, 0.35, 0.6)  # Steel blue
		"offhand":     return Color(0.5, 0.25, 0.6)   # Purple
		"food":        return Color(0.2, 0.55, 0.2)   # Green
		"consumable":  return Color(0.6, 0.5, 0.15)   # Gold
		"resource":    return Color(0.35, 0.3, 0.2)   # Brown
		"material":    return Color(0.3, 0.4, 0.35)   # Teal-gray
		"tool":        return Color(0.45, 0.4, 0.3)   # Bronze
		"pet":         return Color(0.55, 0.3, 0.5)   # Magenta
		_:             return Color(0.25, 0.25, 0.3)   # Default gray

## Get short letter symbol for item type (ASCII-safe, works in all fonts)
func _type_icon_symbol(item_type: String) -> String:
	match item_type:
		"weapon":      return "W"
		"armor":       return "A"
		"offhand":     return "S"
		"food":        return "F"
		"consumable":  return "C"
		"resource":    return "R"
		"material":    return "M"
		"tool":        return "T"
		"pet":         return "P"
		_:             return "?"

## Get icon symbol from item data's icon field — ASCII-safe abbreviations
func _item_icon_symbol(icon_name: String, item_type: String) -> String:
	match icon_name:
		# Ores & bars & crafting
		"icon_ore":       return "Or"
		"icon_bar":       return "Br"
		"icon_alloy":     return "Al"
		"icon_essence":   return "Es"
		"icon_gem":       return "Gm"
		"icon_dust":      return "Du"
		# Bio resources
		"icon_bio_bone":     return "Bn"
		"icon_bio_membrane": return "Mb"
		"icon_bio_mushroom": return "Ms"
		"icon_bio_swirl":    return "Sw"
		"icon_bio_brain":    return "Br"
		"icon_bio_galaxy":   return "Gx"
		"icon_bio_sparkle":  return "Sp"
		"icon_bio_crystal":  return "Cr"
		"icon_bio_fiber":    return "Fb"
		"icon_bio_conduit":  return "Cd"
		"icon_neural":       return "Nr"
		"icon_chrono":       return "Ch"
		"icon_stinger":      return "St"
		"icon_dark_orb":     return "Ob"
		# Raw food ingredients
		"icon_food_lichen":   return "Li"
		"icon_food_fruit":    return "Fr"
		"icon_food_meat":     return "Mt"
		"icon_food_pepper":   return "Pp"
		"icon_food_truffle":  return "Tr"
		"icon_food_kelp":     return "Kp"
		"icon_food_grain":    return "Gr"
		"icon_food_mushroom": return "Ms"
		"icon_food_honey":    return "Hn"
		"icon_food_yeast":    return "Ys"
		# Cooked food
		"icon_wrap":       return "Wr"
		"icon_soup":       return "Sp"
		"icon_smoothie":   return "Sm"
		"icon_grain_bowl": return "Bw"
		"icon_burger":     return "Bg"
		"icon_stew":       return "Sw"
		"icon_curry":      return "Cu"
		"icon_steak":      return "Sk"
		"icon_feast":      return "Ft"
		"icon_pasta":      return "Pa"
		"icon_cake":       return "Ck"
		"icon_drumstick":  return "Dm"
		"icon_elixir":     return "Ex"
		"icon_serum":      return "Sr"
		"icon_syringe":    return "Sy"
		# Consumables & utility
		"icon_repair_kit": return "Rk"
		"icon_beacon":     return "Bc"
		"icon_battery":    return "Bt"
		"icon_flare":      return "Fl"
		"icon_chip":       return "Cp"
		"icon_bomb":       return "Bm"
		# Trophy & special
		"icon_crown":     return "Cw"
		"icon_heart":     return "Ht"
		"icon_star":      return "*"
		"icon_shield":    return "Sh"
		"icon_medal":     return "Md"
		"icon_speaker":   return "Sp"
		"icon_telescope": return "Te"
		"icon_sigil":     return "Si"
		"icon_skull":     return "Sk"
		"icon_relic":     return "Rl"
		# Weapons
		"icon_nanoblade":  return "Nb"
		"icon_coilgun":    return "Cg"
		"icon_voidstaff":  return "Vs"
		"icon_capacitor":  return "Zp"
		# Armor pieces
		"icon_helmet":  return "He"
		"icon_vest":    return "Ve"
		"icon_greaves": return "Lg"
		"icon_boots":   return "Bo"
		"icon_gloves":  return "Gl"
		# Tools
		"icon_pickaxe": return "Pk"
		"icon_scanner": return "Sc"
		"icon_welder":  return "We"
		"icon_stove":   return "Sv"
		# Other
		"icon_credits": return "Cr"
		"icon_pet":     return "Pt"
	# Fallback to type-based symbol
	return _type_icon_symbol(item_type)
