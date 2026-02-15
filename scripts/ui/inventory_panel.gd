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

## Get symbol character for item type icon (fallback if no specific icon)
func _type_icon_symbol(item_type: String) -> String:
	match item_type:
		"weapon":      return "\u2694"  # Crossed swords
		"armor":       return "\u229B"  # Circled asterisk
		"offhand":     return "\u25D7"  # Half circle (shield)
		"food":        return "\u2663"  # Club (organic)
		"consumable":  return "\u2606"  # Star outline
		"resource":    return "\u25C6"  # Diamond
		"material":    return "\u25A0"  # Filled square
		"tool":        return "\u2692"  # Hammer/pick
		"pet":         return "\u2740"  # Flower
		_:             return "\u25CB"  # Circle

## Get icon from item data's icon field — maps to Unicode symbols
func _item_icon_symbol(icon_name: String, item_type: String) -> String:
	match icon_name:
		# Ores & bars & crafting
		"icon_ore":       return "\u25C6"  # Diamond
		"icon_bar":       return "\u25AC"  # Rectangle
		"icon_alloy":     return "\u25A3"  # Nested square
		"icon_essence":   return "\u2727"  # 4-point star
		"icon_gem":       return "\u2666"  # Diamond suit
		"icon_dust":      return "\u2729"  # Stress star
		# Bio resources
		"icon_bio_bone":     return "\u2620"  # Skull
		"icon_bio_membrane": return "\u25CE"  # Bullseye
		"icon_bio_mushroom": return "\u2660"  # Spade
		"icon_bio_swirl":    return "\u263C"  # Sun face
		"icon_bio_brain":    return "\u2609"  # Sun
		"icon_bio_galaxy":   return "\u2738"  # 8-point star
		"icon_bio_sparkle":  return "\u2726"  # 4-star
		"icon_bio_crystal":  return "\u2662"  # Diamond outline
		"icon_bio_fiber":    return "\u2248"  # Approx
		"icon_bio_conduit":  return "\u2261"  # Identical
		"icon_neural":       return "\u2318"  # POI
		"icon_chrono":       return "\u231A"  # Watch
		"icon_stinger":      return "\u2191"  # Up arrow
		"icon_dark_orb":     return "\u25CF"  # Filled circle
		# Raw food ingredients
		"icon_food_lichen":   return "\u2618"  # Shamrock
		"icon_food_fruit":    return "\u2663"  # Club
		"icon_food_meat":     return "\u2665"  # Heart
		"icon_food_pepper":   return "\u2740"  # Flower
		"icon_food_truffle":  return "\u2660"  # Spade
		"icon_food_kelp":     return "\u223F"  # Sine wave
		"icon_food_grain":    return "\u2637"  # Trigram
		"icon_food_mushroom": return "\u2660"  # Spade
		"icon_food_honey":    return "\u2736"  # 6-point star
		"icon_food_yeast":    return "\u25CB"  # Circle
		# Cooked food
		"icon_wrap":       return "\u25AD"  # Rect
		"icon_soup":       return "\u2615"  # Hot beverage
		"icon_smoothie":   return "\u2661"  # Heart outline
		"icon_grain_bowl": return "\u2312"  # Arc
		"icon_burger":     return "\u25A0"  # Square
		"icon_stew":       return "\u2615"  # Hot beverage
		"icon_curry":      return "\u263C"  # Sun
		"icon_steak":      return "\u2665"  # Heart
		"icon_feast":      return "\u2605"  # Star
		"icon_pasta":      return "\u223F"  # Sine
		"icon_cake":       return "\u25B3"  # Triangle
		"icon_drumstick":  return "\u2742"  # Florette
		"icon_elixir":     return "\u2606"  # Star outline
		"icon_serum":      return "\u2721"  # 6-point star
		"icon_syringe":    return "\u2191"  # Arrow up
		# Consumables & utility
		"icon_repair_kit": return "\u2692"  # Hammer pick
		"icon_beacon":     return "\u2604"  # Comet
		"icon_battery":    return "\u26A1"  # Lightning
		"icon_flare":      return "\u2600"  # Sun
		"icon_chip":       return "\u25A3"  # Nested square
		"icon_bomb":       return "\u25C9"  # Fisheye
		# Trophy & special
		"icon_crown":     return "\u265B"  # Queen
		"icon_heart":     return "\u2665"  # Heart
		"icon_star":      return "\u2605"  # Star
		"icon_shield":    return "\u25D7"  # Half circle
		"icon_medal":     return "\u2742"  # Florette
		"icon_speaker":   return "\u266B"  # Music notes
		"icon_telescope": return "\u25CE"  # Bullseye
		"icon_sigil":     return "\u2721"  # 6-point star
		"icon_skull":     return "\u2620"  # Skull
		"icon_relic":     return "\u2756"  # Diamond mark
		# Weapons
		"icon_nanoblade":  return "\u2694"  # Swords
		"icon_coilgun":    return "\u27B5"  # Arrow
		"icon_voidstaff":  return "\u2742"  # Florette
		"icon_capacitor":  return "\u26A1"  # Lightning
		# Armor pieces
		"icon_helmet":  return "\u2299"  # Circled dot
		"icon_vest":    return "\u229B"  # Circled asterisk
		"icon_greaves": return "\u2296"  # Circled minus
		"icon_boots":   return "\u22A5"  # Perpendicular
		"icon_gloves":  return "\u270B"  # Hand
		# Tools
		"icon_pickaxe": return "\u2692"  # Hammer pick
		"icon_scanner": return "\u25CE"  # Bullseye
		"icon_welder":  return "\u2604"  # Comet
		"icon_stove":   return "\u2302"  # House
		# Other
		"icon_credits": return "\u20B5"  # Cedi sign
		"icon_pet":     return "\u2740"  # Flower
	# Fallback to type-based symbol
	return _type_icon_symbol(item_type)
