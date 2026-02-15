## PrestigePanel — Prestige status, unlocked passives, and prestige shop
##
## Displays the player's current prestige tier and points, a list of tier 1-10
## passives (locked ones hidden behind "???"), and a scrollable shop where
## prestige points can be spent on permanent upgrades.
extends PanelContainer

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _tier_label: Label = null
var _points_label: Label = null
var _prestige_btn: Button = null
var _requirement_label: Label = null
var _passives_container: VBoxContainer = null
var _shop_container: VBoxContainer = null
var _scroll: ScrollContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(360, 420)
	visible = false
	z_index = 50

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Prestige", _on_close)
	root_vbox.add_child(drag_header)

	# ── Status section ──
	var status_box: VBoxContainer = VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 2)
	root_vbox.add_child(status_box)

	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 14)
	_tier_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	status_box.add_child(_tier_label)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 12)
	_points_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	status_box.add_child(_points_label)

	_prestige_btn = Button.new()
	_prestige_btn.text = "Prestige"
	_prestige_btn.custom_minimum_size = Vector2(100, 30)
	_prestige_btn.add_theme_font_size_override("font_size", 12)
	_prestige_btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_prestige_btn.pressed.connect(_on_prestige)
	status_box.add_child(_prestige_btn)

	_requirement_label = Label.new()
	_requirement_label.text = "Requires Total Level 500+"
	_requirement_label.add_theme_font_size_override("font_size", 10)
	_requirement_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_box.add_child(_requirement_label)

	# ── Separator before passives ──
	root_vbox.add_child(HSeparator.new())

	# ── Passives section ──
	var passives_title: Label = Label.new()
	passives_title.text = "Unlocked Passives"
	passives_title.add_theme_font_size_override("font_size", 13)
	passives_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	root_vbox.add_child(passives_title)

	_passives_container = VBoxContainer.new()
	_passives_container.add_theme_constant_override("separation", 2)
	root_vbox.add_child(_passives_container)

	# ── Separator before shop ──
	root_vbox.add_child(HSeparator.new())

	# ── Shop section ──
	var shop_title: Label = Label.new()
	shop_title.text = "Prestige Shop"
	shop_title.add_theme_font_size_override("font_size", 13)
	shop_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	root_vbox.add_child(shop_title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(340, 120)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll)

	_shop_container = VBoxContainer.new()
	_shop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_container.add_theme_constant_override("separation", 4)
	_scroll.add_child(_shop_container)

	# ── Connect EventBus for auto-refresh ──
	EventBus.prestige_triggered.connect(_on_prestige_triggered)

	# Initial build
	refresh()


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Rebuild every section of the panel from current game state.
func refresh() -> void:
	_refresh_status()
	_refresh_passives()
	_refresh_shop()


# ──────────────────────────────────────────────
#  Status section
# ──────────────────────────────────────────────

## Update the tier, points, and prestige button state.
func _refresh_status() -> void:
	var tier: int = int(GameState.prestige_tier)
	var points: int = int(GameState.prestige_points)

	_tier_label.text = "Tier %d / 10" % tier
	_points_label.text = "Prestige Points: %d" % points

	# Enable the prestige button only when the system says we can prestige
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys != null and prestige_sys.has_method("can_prestige"):
		_prestige_btn.disabled = not bool(prestige_sys.can_prestige())
	else:
		_prestige_btn.disabled = true


# ──────────────────────────────────────────────
#  Passives section
# ──────────────────────────────────────────────

## Rebuild the tier 1-10 passive list.  Unlocked passives show their name and
## description in their designated color; locked ones show "Tier X: ???" in gray.
func _refresh_passives() -> void:
	# Clear old entries
	for child in _passives_container.get_children():
		child.queue_free()

	var passives: Dictionary = DataManager.prestige_passives
	var current_tier: int = int(GameState.prestige_tier)

	# Iterate tiers 1 through 10
	for tier_num in range(1, 11):
		var tier_key: String = str(tier_num)
		if not passives.has(tier_key):
			continue
		var passive: Dictionary = passives[tier_key]
		var unlocked: bool = current_tier >= tier_num

		var passive_label: Label = Label.new()
		passive_label.add_theme_font_size_override("font_size", 11)

		if unlocked:
			var passive_name: String = str(passive.get("name", "Unknown"))
			var passive_desc: String = str(passive.get("desc", ""))
			var color_hex: String = str(passive.get("color", "#88ccff"))
			var passive_color: Color = Color.html(color_hex)

			passive_label.text = "Tier %d: %s — %s" % [tier_num, passive_name, passive_desc]
			passive_label.add_theme_color_override("font_color", passive_color)
		else:
			passive_label.text = "Tier %d: ???" % tier_num
			passive_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_passives_container.add_child(passive_label)


# ──────────────────────────────────────────────
#  Shop section
# ──────────────────────────────────────────────

## Rebuild the prestige shop item list.  Each item shows its name, PP cost, and
## a Buy button (or "Owned" label if already purchased and non-repeatable).
func _refresh_shop() -> void:
	# Clear old entries
	for child in _shop_container.get_children():
		child.queue_free()

	var shop_items: Array = DataManager.prestige_shop_items
	var current_points: int = int(GameState.prestige_points)
	var purchases: Array = GameState.prestige_purchases

	for i in range(shop_items.size()):
		var item: Dictionary = shop_items[i] as Dictionary
		var item_id: String = str(item.get("id", ""))
		var item_name: String = str(item.get("name", "Unknown"))
		var item_cost: int = int(item.get("cost", 0))
		var repeatable: bool = bool(item.get("repeatable", false))
		var already_owned: bool = purchases.has(item_id)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_shop_container.add_child(row)

		# Item name
		var name_label: Label = Label.new()
		name_label.text = item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 140
		row.add_child(name_label)

		# Cost label
		var cost_label: Label = Label.new()
		cost_label.text = "%d PP" % item_cost
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		row.add_child(cost_label)

		# Buy button or Owned label
		if already_owned and not repeatable:
			var owned_label: Label = Label.new()
			owned_label.text = "Owned"
			owned_label.add_theme_font_size_override("font_size", 10)
			owned_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			owned_label.custom_minimum_size = Vector2(50, 22)
			row.add_child(owned_label)
		else:
			var buy_btn: Button = Button.new()
			buy_btn.text = "Buy"
			buy_btn.add_theme_font_size_override("font_size", 10)
			buy_btn.custom_minimum_size = Vector2(50, 22)
			buy_btn.pressed.connect(_on_buy.bind(item_id))

			# Disable if the player cannot afford the item
			if current_points < item_cost:
				buy_btn.disabled = true

			row.add_child(buy_btn)


# ──────────────────────────────────────────────
#  Callbacks
# ──────────────────────────────────────────────

## Close the panel and notify the event bus.
func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("prestige")


## Attempt to prestige via the prestige system, then rebuild the panel.
func _on_prestige() -> void:
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys == null:
		push_warning("PrestigePanel: No prestige_system node found in scene tree.")
		return

	if prestige_sys.has_method("prestige"):
		prestige_sys.prestige()

	refresh()


## Purchase a shop item via the prestige system, then rebuild the panel.
func _on_buy(item_id: String) -> void:
	var prestige_sys: Node = get_tree().get_first_node_in_group("prestige_system")
	if prestige_sys == null:
		push_warning("PrestigePanel: No prestige_system node found in scene tree.")
		return

	if prestige_sys.has_method("purchase_shop_item"):
		prestige_sys.purchase_shop_item(item_id)

	refresh()


## Auto-refresh when a prestige event fires.
func _on_prestige_triggered(_new_tier: int) -> void:
	refresh()
