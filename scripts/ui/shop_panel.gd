## ShopPanel — Buy/sell interface for NPC shops
##
## Shows available items with prices. Click to buy (deducts credits).
## Also shows a "Sell" tab for selling inventory items.
extends PanelContainer

# ── State ──
var _shop_data: Dictionary = {}
var _shop_items: Array = []
var _npc_name: String = ""
var _mode: String = "buy"  # "buy" or "sell"

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _buy_btn: Button = null
var _sell_btn: Button = null
var _items_container: VBoxContainer = null
var _credits_label: Label = null
var _scroll: ScrollContainer = null

func _ready() -> void:
	custom_minimum_size = Vector2(340, 380)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Draggable header
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Shop", _on_close)
	drag_header.name = "DragHeader"
	vbox.add_child(drag_header)
	_title_label = drag_header._title_label

	# Tab buttons
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vbox.add_child(tabs)

	_buy_btn = Button.new()
	_buy_btn.text = "Buy"
	_buy_btn.add_theme_font_size_override("font_size", 12)
	_buy_btn.pressed.connect(func(): _set_mode("buy"))
	tabs.add_child(_buy_btn)

	_sell_btn = Button.new()
	_sell_btn.text = "Sell"
	_sell_btn.add_theme_font_size_override("font_size", 12)
	_sell_btn.pressed.connect(func(): _set_mode("sell"))
	tabs.add_child(_sell_btn)

	_credits_label = Label.new()
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits_label.add_theme_font_size_override("font_size", 12)
	_credits_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	tabs.add_child(_credits_label)

	# Scrollable items list
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(320, 280)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 2)
	_scroll.add_child(_items_container)

	visible = false
	z_index = 55

## Open the shop with data from an NPC
func open_shop(npc: Node) -> void:
	if npc == null or not npc.has_method("get_shop_data"):
		return
	_shop_data = npc.get_shop_data()
	_npc_name = str(npc.npc_name)
	_shop_items = _shop_data.get("items", [])
	_title_label.text = str(_shop_data.get("name", "Shop"))
	_mode = "buy"
	visible = true
	refresh()

## Refresh the items list
func refresh() -> void:
	# Update credits display
	_credits_label.text = "%d credits" % int(GameState.player["credits"])

	# Clear old items
	for child in _items_container.get_children():
		child.queue_free()

	if _mode == "buy":
		_refresh_buy()
	else:
		_refresh_sell()

func _refresh_buy() -> void:
	for entry in _shop_items:
		var item_id: String = str(entry.get("itemId", ""))
		var price: int = int(entry.get("price", 0))
		var stock: int = int(entry.get("stock", 0))

		var item_data: Dictionary = DataManager.get_item(item_id)
		if item_data.is_empty():
			continue

		var item_name: String = str(item_data.get("name", item_id))
		var tier: int = int(item_data.get("tier", 0))

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_items_container.add_child(row)

		# Item name
		var name_lbl: Label = Label.new()
		name_lbl.text = item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", _tier_color(tier))
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 140
		row.add_child(name_lbl)

		# Price
		var price_lbl: Label = Label.new()
		price_lbl.text = "%d cr" % price
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		row.add_child(price_lbl)

		# Buy button
		var buy_button: Button = Button.new()
		buy_button.text = "Buy"
		buy_button.add_theme_font_size_override("font_size", 10)
		buy_button.custom_minimum_size = Vector2(40, 22)
		buy_button.pressed.connect(_on_buy.bind(item_id, price))

		# Disable if can't afford or inventory full
		if int(GameState.player["credits"]) < price:
			buy_button.disabled = true
		if not GameState.has_inventory_space():
			buy_button.disabled = true

		row.add_child(buy_button)

		# Hover tooltip
		row.mouse_entered.connect(_on_item_hover.bind(item_id))
		row.mouse_exited.connect(_on_item_exit)

func _refresh_sell() -> void:
	for i in range(GameState.inventory.size()):
		var entry: Dictionary = GameState.inventory[i]
		var item_id: String = str(entry.get("item_id", ""))
		var quantity: int = int(entry.get("quantity", 1))

		var item_data: Dictionary = DataManager.get_item(item_id)
		if item_data.is_empty():
			continue

		var item_name: String = str(item_data.get("name", item_id))
		var tier: int = int(item_data.get("tier", 0))
		var sell_price: int = int(int(item_data.get("value", 0)) * 0.6)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_items_container.add_child(row)

		# Item name + quantity
		var name_lbl: Label = Label.new()
		var qty_text: String = " x%d" % quantity if quantity > 1 else ""
		name_lbl.text = "%s%s" % [item_name, qty_text]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", _tier_color(tier))
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 140
		row.add_child(name_lbl)

		# Sell price
		var price_lbl: Label = Label.new()
		price_lbl.text = "%d cr" % sell_price
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))
		row.add_child(price_lbl)

		# Sell button
		var sell_button: Button = Button.new()
		sell_button.text = "Sell"
		sell_button.add_theme_font_size_override("font_size", 10)
		sell_button.custom_minimum_size = Vector2(40, 22)
		sell_button.pressed.connect(_on_sell.bind(item_id, sell_price))
		row.add_child(sell_button)

		row.mouse_entered.connect(_on_item_hover.bind(item_id))
		row.mouse_exited.connect(_on_item_exit)

## Buy an item
func _on_buy(item_id: String, price: int) -> void:
	if int(GameState.player["credits"]) < price:
		EventBus.chat_message.emit("Not enough credits!", "system")
		return
	if not GameState.has_inventory_space():
		EventBus.chat_message.emit("Inventory full!", "system")
		return

	GameState.add_credits(-price)
	GameState.add_item(item_id, 1)
	var item_data: Dictionary = DataManager.get_item(item_id)
	EventBus.chat_message.emit("Bought %s for %d credits." % [str(item_data.get("name", item_id)), price], "loot")
	refresh()

## Sell an item
func _on_sell(item_id: String, sell_price: int) -> void:
	if not GameState.remove_item(item_id):
		return
	GameState.add_credits(sell_price)
	var item_data: Dictionary = DataManager.get_item(item_id)
	EventBus.chat_message.emit("Sold %s for %d credits." % [str(item_data.get("name", item_id)), sell_price], "loot")
	refresh()

func _set_mode(mode: String) -> void:
	_mode = mode
	refresh()

func _on_item_hover(item_id: String) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if not item_data.is_empty():
		var tooltip_data: Dictionary = {"item_id": item_id, "item_data": item_data, "quantity": 1, "source": "shop"}
		EventBus.tooltip_requested.emit(tooltip_data, get_global_mouse_position())

func _on_item_exit() -> void:
	EventBus.tooltip_hidden.emit()

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("shop")

func _tier_color(tier: int) -> Color:
	var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
	var tier_str: String = str(tier)
	if tiers.has(tier_str):
		return Color.html(str(tiers[tier_str].get("color", "#888888")))
	return Color(0.55, 0.55, 0.55)
