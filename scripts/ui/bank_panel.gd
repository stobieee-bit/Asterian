## BankPanel — 48-slot bank storage with deposit/withdraw functionality
##
## Two tabs: "Bank" (8x6 grid, 48 slots) and "Inventory" (7x4 grid, 28 slots).
## Click a bank slot to withdraw to inventory; click an inventory slot to deposit
## to bank.
## Quantity selector: 1 / 5 / 10 / X (custom amount) — applies to each click.
## "Deposit All" dumps entire inventory into the bank.
## "Deposit Equip" unequips all gear and deposits it into the bank.
extends PanelContainer

# ── Constants ──
const BANK_COLS: int = 8
const BANK_ROWS: int = 6
const INV_COLS: int = 7
const INV_ROWS: int = 4
const SLOT_SIZE: int = 44
const SLOT_PADDING: int = 4

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _bank_tab_btn: Button = null
var _inv_tab_btn: Button = null
var _deposit_all_btn: Button = null
var _deposit_equip_btn: Button = null
var _grid: GridContainer = null
var _slots: Array[PanelContainer] = []

# Quantity selector
var _qty_buttons: Array[Button] = []
var _qty_custom_input: LineEdit = null
var _qty_row: HBoxContainer = null

# ── State ──
var _mode: String = "bank"  # "bank" or "inventory"
var _transfer_qty: int = 1  # How many items per click (1, 5, 10, or custom)

# ── Lifecycle ──

func _ready() -> void:
	custom_minimum_size = Vector2(400, 460)
	visible = false
	z_index = 55

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Bank", _on_close)
	vbox.add_child(drag_header)

	# ── Tab buttons + Deposit buttons ──
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vbox.add_child(tabs)

	_bank_tab_btn = Button.new()
	_bank_tab_btn.text = "Bank"
	_bank_tab_btn.add_theme_font_size_override("font_size", 12)
	_bank_tab_btn.pressed.connect(func(): _set_mode("bank"))
	tabs.add_child(_bank_tab_btn)

	_inv_tab_btn = Button.new()
	_inv_tab_btn.text = "Inventory"
	_inv_tab_btn.add_theme_font_size_override("font_size", 12)
	_inv_tab_btn.pressed.connect(func(): _set_mode("inventory"))
	tabs.add_child(_inv_tab_btn)

	# Spacer to push action buttons right
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)

	_deposit_equip_btn = Button.new()
	_deposit_equip_btn.text = "Deposit Equip"
	_deposit_equip_btn.add_theme_font_size_override("font_size", 11)
	_deposit_equip_btn.custom_minimum_size = Vector2(96, 24)
	_deposit_equip_btn.pressed.connect(_on_deposit_equipment)
	tabs.add_child(_deposit_equip_btn)

	_deposit_all_btn = Button.new()
	_deposit_all_btn.text = "Deposit All"
	_deposit_all_btn.add_theme_font_size_override("font_size", 11)
	_deposit_all_btn.custom_minimum_size = Vector2(80, 24)
	_deposit_all_btn.pressed.connect(_on_deposit_all)
	tabs.add_child(_deposit_all_btn)

	# ── Quantity selector row ──
	_qty_row = HBoxContainer.new()
	_qty_row.add_theme_constant_override("separation", 3)
	vbox.add_child(_qty_row)

	var qty_label: Label = Label.new()
	qty_label.text = "Qty:"
	qty_label.add_theme_font_size_override("font_size", 11)
	qty_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_qty_row.add_child(qty_label)

	var qty_values: Array[int] = [1, 5, 10, -1]  # -1 = custom (X)
	for val in qty_values:
		var btn: Button = Button.new()
		btn.text = "X" if val == -1 else str(val)
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(32, 22)
		btn.pressed.connect(_on_qty_selected.bind(val))
		_qty_row.add_child(btn)
		_qty_buttons.append(btn)

	# Custom amount input (hidden until X is pressed)
	_qty_custom_input = LineEdit.new()
	_qty_custom_input.placeholder_text = "amt"
	_qty_custom_input.add_theme_font_size_override("font_size", 11)
	_qty_custom_input.custom_minimum_size = Vector2(50, 22)
	_qty_custom_input.max_length = 6
	_qty_custom_input.visible = false
	_qty_custom_input.text_submitted.connect(_on_custom_qty_submitted)
	_qty_row.add_child(_qty_custom_input)

	# All button (withdraw/deposit all of a single item stack)
	var all_btn: Button = Button.new()
	all_btn.text = "All"
	all_btn.add_theme_font_size_override("font_size", 11)
	all_btn.custom_minimum_size = Vector2(36, 22)
	all_btn.pressed.connect(_on_qty_selected.bind(0))  # 0 = "All"
	_qty_row.add_child(all_btn)
	_qty_buttons.append(all_btn)

	_update_qty_buttons()

	# ── Grid container (slots rebuilt on mode switch) ──
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", SLOT_PADDING)
	_grid.add_theme_constant_override("v_separation", SLOT_PADDING)
	vbox.add_child(_grid)

	# Connect inventory change signals so the panel stays in sync
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)

	# Build initial grid (bank mode)
	_rebuild_grid()

# ── Quantity selector ──

## Called when user clicks a qty button (1/5/10/X/All)
func _on_qty_selected(value: int) -> void:
	if value == -1:
		# Show custom input
		_qty_custom_input.visible = true
		_qty_custom_input.grab_focus()
		_transfer_qty = -1
	elif value == 0:
		# "All" mode
		_transfer_qty = 0
		_qty_custom_input.visible = false
	else:
		_transfer_qty = value
		_qty_custom_input.visible = false
	_update_qty_buttons()

## Called when user types a custom amount and presses Enter
func _on_custom_qty_submitted(text: String) -> void:
	var val: int = int(text.strip_edges())
	if val < 1:
		val = 1
	_transfer_qty = val
	_qty_custom_input.visible = false
	_update_qty_buttons()

## Highlight the active quantity button
func _update_qty_buttons() -> void:
	var preset_values: Array[int] = [1, 5, 10, -1, 0]  # matches button order
	for i in range(_qty_buttons.size()):
		var btn: Button = _qty_buttons[i]
		var val: int = preset_values[i] if i < preset_values.size() else -99
		var is_active: bool = false

		if val == -1:
			# X button — active when transfer_qty is a custom (non-preset) value
			is_active = _transfer_qty not in [0, 1, 5, 10] and _transfer_qty != -1
			if _transfer_qty == -1:
				is_active = true
			if is_active and _transfer_qty > 0:
				btn.text = "X:%d" % _transfer_qty
			else:
				btn.text = "X"
		elif val == 0:
			is_active = (_transfer_qty == 0)
		else:
			is_active = (_transfer_qty == val)

		if is_active:
			btn.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		else:
			btn.remove_theme_color_override("font_color")

## Get effective quantity for a transfer, clamped to available
func _get_effective_qty(available: int) -> int:
	if _transfer_qty == 0:
		return available  # "All"
	if _transfer_qty == -1:
		return 1  # X not yet set, treat as 1
	return mini(_transfer_qty, available)

# ── Mode switching ──

## Switch between "bank" and "inventory" tabs and rebuild the grid
func _set_mode(mode: String) -> void:
	if _mode == mode:
		return
	_mode = mode
	_rebuild_grid()

# ── Grid building ──

## Tear down and recreate all slot nodes for the current mode
func _rebuild_grid() -> void:
	# Clear existing slots
	_slots.clear()
	for child in _grid.get_children():
		child.queue_free()

	var cols: int = BANK_COLS if _mode == "bank" else INV_COLS
	var rows: int = BANK_ROWS if _mode == "bank" else INV_ROWS
	_grid.columns = cols

	var total_slots: int = cols * rows
	for i in range(total_slots):
		var slot: PanelContainer = _create_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)

	# Update tab button styling to indicate active tab
	_bank_tab_btn.disabled = (_mode == "bank")
	_inv_tab_btn.disabled = (_mode == "inventory")

	# Deposit buttons only visible on bank tab
	_deposit_all_btn.visible = (_mode == "bank")
	_deposit_equip_btn.visible = (_mode == "bank")

	refresh()

## Create a single grid slot with item label and quantity label
func _create_slot(index: int) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# Dark background style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	style.border_color = Color(0.2, 0.3, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", style)

	# Item name label (centered)
	var item_label: Label = Label.new()
	item_label.name = "ItemLabel"
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 9)
	item_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	item_label.clip_text = true
	slot.add_child(item_label)

	# Quantity label (bottom-right)
	var qty_lbl: Label = Label.new()
	qty_lbl.name = "QtyLabel"
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	qty_lbl.add_theme_font_size_override("font_size", 9)
	qty_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	qty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(qty_lbl)

	# Input / hover signals
	slot.gui_input.connect(_on_slot_input.bind(index))
	slot.mouse_entered.connect(_on_slot_hover.bind(index))
	slot.mouse_exited.connect(_on_slot_exit)

	return slot

# ── Refresh ──

## Refresh all visible slots from GameState data
func refresh() -> void:
	var source: Array[Dictionary] = GameState.bank if _mode == "bank" else GameState.inventory

	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		var item_label: Label = slot.get_node("ItemLabel") as Label
		var qty_lbl: Label = slot.get_node("QtyLabel") as Label
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat

		if i < source.size():
			var entry: Dictionary = source[i]
			var item_id: String = str(entry.get("item_id", ""))
			var quantity: int = int(entry.get("quantity", 1))
			var item_data: Dictionary = DataManager.get_item(item_id)

			var item_name: String = str(item_data.get("name", item_id))
			var tier: int = int(item_data.get("tier", 1))

			# Truncate long names to fit in the 44px slot
			if item_name.length() > 7:
				item_label.text = item_name.left(6) + "."
			else:
				item_label.text = item_name

			item_label.add_theme_color_override("font_color", _tier_color(tier))
			qty_lbl.text = str(quantity) if quantity > 1 else ""

			# Tier-colored border
			if style:
				style.border_color = _tier_color(tier).darkened(0.3)
				style.border_color.a = 0.8
		else:
			# Empty slot
			item_label.text = ""
			qty_lbl.text = ""
			if style:
				style.border_color = Color(0.2, 0.3, 0.4, 0.6)

# ── Slot interaction ──

## Handle click on a slot: withdraw (bank tab) or deposit (inventory tab)
func _on_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _mode == "bank":
		_withdraw_item(index)
	else:
		_deposit_item(index)

# ── Bank operations ──

## Withdraw item(s) from the bank into the player's inventory
func _withdraw_item(bank_index: int) -> void:
	if bank_index >= GameState.bank.size():
		return

	var entry: Dictionary = GameState.bank[bank_index]
	var item_id: String = str(entry.get("item_id", ""))
	var available: int = int(entry.get("quantity", 1))
	var item_data: Dictionary = DataManager.get_item(item_id)

	if item_data.is_empty():
		return

	var amount: int = _get_effective_qty(available)
	if amount <= 0:
		return

	# Each withdrawn item takes its own inventory slot (no stacking)
	var actually_withdrawn: int = 0
	for _i in range(amount):
		if not GameState.has_inventory_space():
			if actually_withdrawn == 0:
				EventBus.chat_message.emit("Inventory full!", "system")
				return
			break
		actually_withdrawn += 1

	# Remove from bank
	GameState.bank[bank_index]["quantity"] -= actually_withdrawn
	if GameState.bank[bank_index]["quantity"] <= 0:
		GameState.bank.remove_at(bank_index)

	# Add to inventory (each item gets its own slot)
	GameState.add_item(item_id, actually_withdrawn)

	var item_name: String = str(item_data.get("name", item_id))
	if actually_withdrawn > 1:
		EventBus.chat_message.emit("Withdrew %d x %s from bank." % [actually_withdrawn, item_name], "system")
	else:
		EventBus.chat_message.emit("Withdrew %s from bank." % item_name, "system")
	refresh()

## Deposit item(s) from inventory into the bank
func _deposit_item(inv_index: int) -> void:
	if inv_index >= GameState.inventory.size():
		return

	var entry: Dictionary = GameState.inventory[inv_index]
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = DataManager.get_item(item_id)

	if item_data.is_empty():
		return

	# Count how many of this item exist across all inventory slots
	var total_owned: int = GameState.count_item(item_id)
	var amount: int = _get_effective_qty(total_owned)
	if amount <= 0:
		return

	# Try to deposit into bank (bank always stacks)
	if not _bank_add(item_id, amount, item_data):
		EventBus.chat_message.emit("Bank is full!", "system")
		return

	# Remove from inventory (removes individual slots)
	GameState.remove_item(item_id, amount)

	var item_name: String = str(item_data.get("name", item_id))
	if amount > 1:
		EventBus.chat_message.emit("Deposited %d x %s in bank." % [amount, item_name], "system")
	else:
		EventBus.chat_message.emit("Deposited %s in bank." % item_name, "system")
	refresh()

## Deposit all inventory items into the bank
func _on_deposit_all() -> void:
	if GameState.inventory.is_empty():
		EventBus.chat_message.emit("Inventory is empty.", "system")
		return

	var deposited_count: int = 0

	# Iterate backwards so remove_at doesn't shift indices we haven't visited
	for i in range(GameState.inventory.size() - 1, -1, -1):
		var entry: Dictionary = GameState.inventory[i]
		var item_id: String = str(entry.get("item_id", ""))
		var quantity: int = int(entry.get("quantity", 1))
		var item_data: Dictionary = DataManager.get_item(item_id)

		if item_data.is_empty():
			continue

		# Deposit the full stack
		if _bank_add(item_id, quantity, item_data):
			GameState.inventory.remove_at(i)
			deposited_count += quantity
		else:
			# Bank full
			break

	if deposited_count > 0:
		EventBus.item_removed.emit("", deposited_count)
		EventBus.chat_message.emit("Deposited %d item(s) into bank." % deposited_count, "system")
	else:
		EventBus.chat_message.emit("Bank is full!", "system")

	refresh()

## Deposit all equipped gear into the bank
func _on_deposit_equipment() -> void:
	var deposited_count: int = 0
	var slots: Array[String] = ["head", "body", "legs", "boots", "gloves", "weapon", "offhand"]

	for slot_name in slots:
		var item_id: String = str(GameState.equipment.get(slot_name, ""))
		if item_id == "":
			continue

		var item_data: Dictionary = DataManager.get_item(item_id)
		if item_data.is_empty():
			continue

		# Try to bank the equipped item
		if _bank_add(item_id, 1, item_data):
			GameState.equipment[slot_name] = ""
			EventBus.item_unequipped.emit(slot_name, item_id)
			deposited_count += 1
		else:
			EventBus.chat_message.emit("Bank full! Some equipment not deposited.", "system")
			break

	if deposited_count > 0:
		EventBus.chat_message.emit("Deposited %d equipped item(s) into bank." % deposited_count, "system")
	else:
		EventBus.chat_message.emit("No equipment to deposit.", "system")

	refresh()

## Internal helper: add an item + quantity into the bank array.
## Bank ALWAYS stacks — if the item is already present, increases quantity.
## Otherwise appends a new entry if bank has room.
## Returns true on success, false if the bank is full.
func _bank_add(item_id: String, quantity: int, _item_data: Dictionary) -> bool:
	# Always look for an existing stack in the bank
	for entry in GameState.bank:
		if entry.get("item_id", "") == item_id:
			entry["quantity"] += quantity
			return true

	# Need a new bank slot
	if GameState.bank.size() >= GameState.bank_size:
		return false

	GameState.bank.append({ "item_id": item_id, "quantity": quantity })
	return true

# ── Tooltips ──

## Show tooltip when hovering over a filled slot
func _on_slot_hover(index: int) -> void:
	var source: Array[Dictionary] = GameState.bank if _mode == "bank" else GameState.inventory

	if index >= source.size():
		EventBus.tooltip_hidden.emit()
		return

	var entry: Dictionary = source[index]
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	var tooltip_data: Dictionary = {
		"item_id": item_id,
		"item_data": item_data,
		"quantity": int(entry.get("quantity", 1)),
		"source": "bank" if _mode == "bank" else "inventory",
	}
	EventBus.tooltip_requested.emit(tooltip_data, get_global_mouse_position())

func _on_slot_exit() -> void:
	EventBus.tooltip_hidden.emit()

# ── Panel open / close ──

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("bank")

func _on_inventory_changed(_item_id: String, _qty: int) -> void:
	if visible:
		refresh()

# ── Tier color utility ──

## Look up tier color from DataManager.equipment_data.tiers
func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)
