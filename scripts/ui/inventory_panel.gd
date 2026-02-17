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
var _slot_inner: Array[Control] = []
var _slot_icon_rect: Array[ColorRect] = []
var _slot_icon_tex: Array[TextureRect] = []
var _slot_item_label: Array[Label] = []
var _slot_qty_label: Array[Label] = []
var _title_label: Label = null
var _close_btn: Button = null
var _credits_label: Label = null

# ── Drag state ──
var _is_dragging: bool = false
var _drag_index: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_pending: bool = false          # Left-click held, waiting for threshold
var _drag_preview: PanelContainer = null  # Floating icon following cursor
const DRAG_THRESHOLD: float = 6.0        # Pixels before drag starts

func _ready() -> void:
	# Panel style
	custom_minimum_size = Vector2(
		COLS * (SLOT_SIZE + SLOT_PADDING) + 24,
		ROWS * (SLOT_SIZE + SLOT_PADDING) + 80
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

	# ── Credits row below grid ──
	_credits_label = Label.new()
	_credits_label.name = "CreditsLabel"
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits_label.add_theme_font_size_override("font_size", 15)
	_credits_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3, 0.95))
	_credits_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_credits_label.add_theme_constant_override("shadow_offset_x", 1)
	_credits_label.add_theme_constant_override("shadow_offset_y", 1)
	_credits_label.text = "$0"
	vbox.add_child(_credits_label)

	# Connect to signals for live updates
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)
	EventBus.player_credits_changed.connect(_on_credits_changed)

	# Initial refresh
	refresh()
	_update_credits_display(int(GameState.player.get("credits", 0)))

## Create a single inventory slot
func _create_slot(index: int) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.7)
	style.border_color = Color(0.1, 0.15, 0.22, 0.35)
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

	# Icon texture (pixel art, centered)
	var icon_tex: TextureRect = TextureRect.new()
	icon_tex.name = "IconTexture"
	icon_tex.position = Vector2(4, 4)
	icon_tex.size = Vector2(40, 40)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_tex)

	# Hidden item label (kept for data reference, not displayed)
	var label: Label = Label.new()
	label.name = "ItemLabel"
	label.visible = false
	label.position = Vector2(0, 0)
	label.size = Vector2(0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(label)

	# Quantity label (bottom-right corner, separated from icon symbol)
	var qty_label: Label = Label.new()
	qty_label.name = "QtyLabel"
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	qty_label.add_theme_font_size_override("font_size", 12)
	qty_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	qty_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	qty_label.add_theme_constant_override("shadow_offset_x", 1)
	qty_label.add_theme_constant_override("shadow_offset_y", 1)
	qty_label.position = Vector2(0, SLOT_SIZE - 16)
	qty_label.size = Vector2(SLOT_SIZE, 16)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(qty_label)

	# Cache child refs for fast refresh lookups
	_slot_inner.append(inner)
	_slot_icon_rect.append(icon_rect)
	_slot_icon_tex.append(icon_tex)
	_slot_item_label.append(label)
	_slot_qty_label.append(qty_label)

	# Connect click
	slot.gui_input.connect(_on_slot_input.bind(index))
	slot.mouse_entered.connect(_on_slot_hover.bind(index))
	slot.mouse_exited.connect(_on_slot_exit)

	return slot

## Refresh all slots from GameState.inventory
func refresh() -> void:
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		var item_label: Label = _slot_item_label[i]
		var qty_label: Label = _slot_qty_label[i]
		var icon_rect: ColorRect = _slot_icon_rect[i]
		var icon_tex: TextureRect = _slot_icon_tex[i]
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

			# Show icon background colored by item type (strong opacity for clear icon block)
			icon_rect.color = _type_icon_color(item_type)
			icon_rect.color.a = 0.85

			# Show pixel art icon from item's icon field (or fallback to type)
			var icon_id: String = str(item_data.get("icon", ""))
			icon_tex.texture = ItemIcons.get_icon_texture(icon_id, item_type)
			icon_tex.modulate = Color.WHITE

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
			icon_tex.texture = null
			if style:
				style.border_color = Color(0.2, 0.3, 0.4, 0.6)

## Handle slot click input
func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if index >= GameState.inventory.size():
				return

			var entry: Dictionary = GameState.inventory[index]
			var item_id: String = str(entry.get("item_id", ""))
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_type: String = str(item_data.get("type", ""))

			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				# Double-click to equip — cancel any pending drag
				_drag_pending = false
				if item_type in ["weapon", "armor", "offhand"]:
					_equip_from_slot(item_id)

			elif event.button_index == MOUSE_BUTTON_LEFT:
				# Single left-click — start tracking for potential drag
				_drag_pending = true
				_drag_index = index
				_drag_start_pos = get_global_mouse_position()

			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Right-click context menu
				_show_item_context_menu(item_id, item_data, item_type, index, get_global_mouse_position())

		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Release inside a slot while dragging — swap
			if _is_dragging:
				_finish_drag(index)


## Global input to track mouse movement and release during drag
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		if _drag_pending and not _is_dragging:
			# Check if we've moved far enough to start dragging
			var dist: float = get_global_mouse_position().distance_to(_drag_start_pos)
			if dist >= DRAG_THRESHOLD:
				_start_drag()
		elif _is_dragging and _drag_preview:
			# Move preview with cursor
			_drag_preview.global_position = get_global_mouse_position() - Vector2(SLOT_SIZE * 0.5, SLOT_SIZE * 0.5)

	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging:
			# Released — check if over a slot or outside panel
			var drop_slot: int = _get_slot_under_mouse()
			if drop_slot >= 0:
				_finish_drag(drop_slot)
			else:
				# Dropped outside inventory — drop item to ground
				_drop_to_ground()
		# Always reset drag state on release
		_drag_pending = false


## Begin dragging: create floating preview, dim source slot
func _start_drag() -> void:
	_drag_pending = false
	if _drag_index < 0 or _drag_index >= GameState.inventory.size():
		return

	_is_dragging = true
	EventBus.tooltip_hidden.emit()

	var entry: Dictionary = GameState.inventory[_drag_index]
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_type: String = str(item_data.get("type", ""))

	# Create floating preview
	_drag_preview = PanelContainer.new()
	_drag_preview.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_drag_preview.z_index = 200
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	preview_style.border_color = Color(0.4, 0.6, 0.9, 0.8)
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(3)
	_drag_preview.add_theme_stylebox_override("panel", preview_style)

	var inner: Control = Control.new()
	inner.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.add_child(inner)

	var icon_rect: ColorRect = ColorRect.new()
	icon_rect.position = Vector2(4, 4)
	icon_rect.size = Vector2(40, 40)
	icon_rect.color = _type_icon_color(item_type)
	icon_rect.color.a = 0.85
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_rect)

	var icon_tex: TextureRect = TextureRect.new()
	icon_tex.position = Vector2(4, 4)
	icon_tex.size = Vector2(40, 40)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_id: String = str(item_data.get("icon", ""))
	icon_tex.texture = ItemIcons.get_icon_texture(icon_id, item_type)
	inner.add_child(icon_tex)

	# Add preview as top-level so it draws above everything
	_drag_preview.top_level = true
	add_child(_drag_preview)
	_drag_preview.global_position = get_global_mouse_position() - Vector2(SLOT_SIZE * 0.5, SLOT_SIZE * 0.5)

	# Dim the source slot
	_dim_slot(_drag_index, true)


## Finish drag by swapping items between source and target slots
func _finish_drag(target_index: int) -> void:
	if _drag_index < 0:
		_cancel_drag()
		return

	var src: int = _drag_index
	var dst: int = target_index

	if src != dst:
		# Swap items in GameState.inventory
		var inv: Array = GameState.inventory
		if src < inv.size() and dst < inv.size():
			# Both slots have items — swap
			var tmp: Dictionary = inv[src]
			inv[src] = inv[dst]
			inv[dst] = tmp
		elif src < inv.size() and dst >= inv.size():
			# Moving to an empty slot — append + remove
			var entry: Dictionary = inv[src]
			inv.remove_at(src)
			# Pad with empty slots if needed (shouldn't happen with 28 fixed slots,
			# but the inventory array only contains occupied slots up to the last item)
			while inv.size() < dst:
				inv.append({"item_id": "", "quantity": 0})
			inv.insert(dst, entry)
			# Clean trailing empty entries
			while inv.size() > 0 and str(inv[inv.size() - 1].get("item_id", "")) == "":
				inv.remove_at(inv.size() - 1)

	_cancel_drag()
	refresh()


## Drop item to ground at the player's position
func _drop_to_ground() -> void:
	if _drag_index < 0 or _drag_index >= GameState.inventory.size():
		_cancel_drag()
		return

	var entry: Dictionary = GameState.inventory[_drag_index]
	var item_id: String = str(entry.get("item_id", ""))
	var quantity: int = int(entry.get("quantity", 1))
	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_name: String = str(item_data.get("name", item_id))

	# Remove from inventory by index (direct removal, not by item_id search)
	GameState.inventory.remove_at(_drag_index)
	EventBus.item_removed.emit(item_id, quantity)

	# Spawn ground item at player position
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		var forward: Vector3 = -player.global_transform.basis.z.normalized()
		var drop_pos: Vector3 = player.global_position + forward * 2.0
		EventBus.item_dropped_to_ground.emit(item_id, quantity, drop_pos)

	EventBus.chat_message.emit("Dropped %s." % item_name, "system")
	_cancel_drag()
	refresh()


## Show a confirmation context menu before dropping an item
func _confirm_drop(item_id: String, item_name: String) -> void:
	var confirm_options: Array = []
	confirm_options.append({"title": "Drop %s?" % item_name, "title_color": Color(1.0, 0.5, 0.3)})
	confirm_options.append({
		"label": "Confirm", "icon": "!", "color": Color(0.9, 0.3, 0.3),
		"callback": func():
			_execute_drop(item_id, item_name)
	})
	EventBus.context_menu_requested.emit(confirm_options, get_global_mouse_position())


## Actually remove the item and spawn it on the ground
func _execute_drop(item_id: String, item_name: String) -> void:
	GameState.remove_item(item_id, 1)
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		var fwd: Vector3 = -player_node.global_transform.basis.z.normalized()
		EventBus.item_dropped_to_ground.emit(item_id, 1, player_node.global_position + fwd * 2.0)
	EventBus.chat_message.emit("Dropped %s." % item_name, "system")
	refresh()


## Cancel drag, remove preview, restore slot appearance
func _cancel_drag() -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
		_drag_preview = null

	if _drag_index >= 0 and _drag_index < _slots.size():
		_dim_slot(_drag_index, false)

	_is_dragging = false
	_drag_pending = false
	_drag_index = -1


## Dim or restore a slot's visual to indicate it's being dragged
func _dim_slot(index: int, dimmed: bool) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: PanelContainer = _slots[index]
	slot.modulate.a = 0.3 if dimmed else 1.0


## Get the inventory slot index under the current mouse position, or -1 if none
func _get_slot_under_mouse() -> int:
	var mouse_pos: Vector2 = get_global_mouse_position()
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		var rect: Rect2 = slot.get_global_rect()
		if rect.has_point(mouse_pos):
			return i
	return -1

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

## Eat food to heal and apply buff
func _eat_food(item_id: String, _index: int) -> void:
	# Prefer combat_controller's eat_food() which handles cooldowns and buffs
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node:
		var combat: Node = player_node.get_node_or_null("CombatController")
		if combat and combat.has_method("eat_food"):
			combat.eat_food(item_id)
			refresh()
			return
	# Fallback: manual heal
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
	refresh()

## Use a consumable item (apply buff and/or heal, then consume)
func _use_consumable(item_id: String) -> void:
	if GameState.count_item(item_id) <= 0:
		return
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return
	var item_name: String = str(item_data.get("name", item_id))

	# Heal if item has a heal field
	var heal: int = int(item_data.get("heals", item_data.get("healAmount", item_data.get("heal", 0))))
	if heal > 0:
		var max_hp: int = int(GameState.player["max_hp"])
		var old_hp: int = int(GameState.player["hp"])
		GameState.player["hp"] = mini(max_hp, old_hp + heal)
		var actual_heal: int = int(GameState.player["hp"]) - old_hp
		if actual_heal > 0:
			EventBus.player_healed.emit(actual_heal)

	# Apply buff if defined
	var buff_data: Dictionary = item_data.get("buff", {})
	var buff_msg: String = ""
	if not buff_data.is_empty():
		var buff_type: String = str(buff_data.get("type", ""))
		var buff_value: float = float(buff_data.get("value", 0))
		var buff_duration: float = float(buff_data.get("duration", 60))
		if buff_type != "" and buff_value > 0:
			GameState.apply_buff(buff_type, buff_value, buff_duration, item_name)
			var dur_text: String = "%ds" % int(buff_duration) if buff_duration < 120 else "%dm" % int(buff_duration / 60.0)
			buff_msg = " +%.0f %s for %s" % [buff_value, buff_type, dur_text]

	# Consume the item
	GameState.remove_item(item_id, 1)
	EventBus.chat_message.emit("Used %s.%s" % [item_name, buff_msg], "system")
	refresh()

## Show tooltip on hover
func _on_slot_hover(index: int) -> void:
	if _is_dragging:
		return
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

func _on_credits_changed(new_total: int) -> void:
	_update_credits_display(new_total)

func _update_credits_display(amount: int) -> void:
	if _credits_label == null:
		return
	var s: String = str(amount)
	if amount >= 1000:
		var parts: Array[String] = []
		while s.length() > 3:
			parts.push_front(s.right(3))
			s = s.left(s.length() - 3)
		parts.push_front(s)
		s = ",".join(parts)
	_credits_label.text = "$%s" % s

func _on_close_pressed() -> void:
	_cancel_drag()
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

	# Use option for consumables (applies buff and/or heal)
	if item_type == "consumable":
		options.append({
			"label": "Use",
			"icon": "U",
			"color": Color(0.9, 0.8, 0.2),
			"callback": func():
				_use_consumable(item_id)
		})

	# Drop option for all items — shows confirmation before destroying
	options.append({
		"label": "Drop",
		"icon": "D",
		"color": Color(0.8, 0.4, 0.3),
		"callback": func():
			_confirm_drop(item_id, item_name)
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

## Get pixel art texture from item data — delegates to shared ItemIcons utility
func _item_icon_texture(icon_name: String, item_type: String) -> ImageTexture:
	return ItemIcons.get_icon_texture(icon_name, item_type)
