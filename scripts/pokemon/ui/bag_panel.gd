## BagPanel — Mobile bag/inventory for items and balls
##
## Shows categories of items (Balls, Medicine, Key Items) with counts.
extends CanvasLayer

var _root: PanelContainer = null
var _item_list: VBoxContainer = null

func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.18, 0.97)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_root.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "BAG"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var money_label: Label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.add_theme_font_size_override("font_size", 16)
	money_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	header.add_child(money_label)

	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	var close_sb: StyleBoxFlat = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.7, 0.2, 0.2)
	close_sb.corner_radius_top_left = 6
	close_sb.corner_radius_top_right = 6
	close_sb.corner_radius_bottom_left = 6
	close_sb.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Scroll
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 6)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)

func _refresh() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	# Money
	var money_label: Label = _root.find_child("MoneyLabel", true, false)
	if money_label:
		money_label.text = "$%d" % GameState.creature_money

	# Balls section
	_add_section_header("POKÉ BALLS")
	var balls: Dictionary = {
		"pokeball": { "name": "Poké Ball", "desc": "Standard ball", "color": Color(0.85, 0.25, 0.25) },
		"greatball": { "name": "Great Ball", "desc": "Better catch rate", "color": Color(0.3, 0.5, 0.85) },
		"ultraball": { "name": "Ultra Ball", "desc": "High catch rate", "color": Color(0.8, 0.75, 0.15) },
		"masterball": { "name": "Master Ball", "desc": "Never fails!", "color": Color(0.6, 0.2, 0.7) },
	}
	for ball_id in balls:
		var count: int = int(GameState.creature_bag.get(ball_id, 0))
		if count > 0:
			_add_item_row(balls[ball_id]["name"], count, str(balls[ball_id]["desc"]), Color(balls[ball_id]["color"]))

	# Medicine section
	_add_section_header("MEDICINE")
	var medicine: Dictionary = {
		"potion": { "name": "Potion", "desc": "Heals 20 HP" },
		"super_potion": { "name": "Super Potion", "desc": "Heals 50 HP" },
		"hyper_potion": { "name": "Hyper Potion", "desc": "Heals 200 HP" },
		"revive": { "name": "Revive", "desc": "Revives fainted creature" },
	}
	for item_id in medicine:
		var count: int = int(GameState.creature_bag.get(item_id, 0))
		if count > 0:
			_add_item_row(medicine[item_id]["name"], count, str(medicine[item_id]["desc"]), Color(0.2, 0.6, 0.3))

func _add_section_header(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_item_list.add_child(label)

	var sep: HSeparator = HSeparator.new()
	_item_list.add_child(sep)

func _add_item_row(item_name: String, count: int, desc: String, color: Color) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	var card_sb: StyleBoxFlat = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.18, 0.2, 0.28)
	card_sb.corner_radius_top_left = 6
	card_sb.corner_radius_top_right = 6
	card_sb.corner_radius_bottom_left = 6
	card_sb.corner_radius_bottom_right = 6
	card_sb.content_margin_left = 10
	card_sb.content_margin_right = 10
	card_sb.content_margin_top = 6
	card_sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_sb)
	_item_list.add_child(card)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.color = color
	hbox.add_child(icon)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl: Label = Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc_lbl)

	var count_lbl: Label = Label.new()
	count_lbl.text = "x%d" % count
	count_lbl.add_theme_font_size_override("font_size", 18)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(count_lbl)

func _close() -> void:
	visible = false
	EventBus.panel_closed.emit("BagPanel")

func _on_panel_opened(panel_name: String) -> void:
	if panel_name == "BagPanel":
		_refresh()
		visible = true

func _on_panel_closed(panel_name: String) -> void:
	if panel_name == "BagPanel":
		visible = false
