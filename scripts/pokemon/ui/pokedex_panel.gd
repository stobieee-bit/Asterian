## PokedexPanel — Creature encyclopedia tracking seen/caught creatures
##
## Shows a grid of all creatures with icons indicating seen vs. caught.
extends CanvasLayer

var _root: PanelContainer = null
var _grid: GridContainer = null

func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)
	EventBus.pokedex_updated.connect(func(_id: String): _refresh())

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.08, 0.97)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_root.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "POKÉDEX"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

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

	# Stats
	var stats: Label = Label.new()
	stats.name = "StatsLabel"
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(stats)

	# Scroll
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var all_ids: Array[String] = DataManager.get_all_creature_ids()
	var seen_count: int = 0
	var caught_count: int = 0

	for creature_id in all_ids:
		var dex_entry: Dictionary = GameState.pokedex.get(creature_id, {})
		var is_seen: bool = dex_entry.get("seen", false)
		var is_caught: bool = dex_entry.get("caught", false)
		if is_seen:
			seen_count += 1
		if is_caught:
			caught_count += 1

		var creature_data: Dictionary = DataManager.get_creature(creature_id)

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 80)
		var card_sb: StyleBoxFlat = StyleBoxFlat.new()
		card_sb.bg_color = Color(0.2, 0.15, 0.15) if is_seen else Color(0.15, 0.12, 0.12)
		card_sb.corner_radius_top_left = 6
		card_sb.corner_radius_top_right = 6
		card_sb.corner_radius_bottom_left = 6
		card_sb.corner_radius_bottom_right = 6
		card_sb.content_margin_left = 8
		card_sb.content_margin_right = 8
		card_sb.content_margin_top = 6
		card_sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", card_sb)
		_grid.add_child(card)

		var vb: VBoxContainer = VBoxContainer.new()
		card.add_child(vb)

		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		vb.add_child(hb)

		# Color icon
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		if is_seen:
			var sc: Array = creature_data.get("sprite_color", [0.3, 0.3, 0.3])
			icon.color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
		else:
			icon.color = Color(0.2, 0.2, 0.2)
		hb.add_child(icon)

		# Status icon
		var status_lbl: Label = Label.new()
		if is_caught:
			status_lbl.text = "*"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		elif is_seen:
			status_lbl.text = "o"
			status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))
		else:
			status_lbl.text = "-"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		status_lbl.add_theme_font_size_override("font_size", 16)
		hb.add_child(status_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = str(creature_data.get("name", "???")) if is_seen else "???"
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color.WHITE if is_seen else Color(0.4, 0.4, 0.4))
		vb.add_child(name_lbl)

		if is_seen:
			var types_str: String = ""
			for t in creature_data.get("types", []):
				types_str += str(t).to_upper() + " "
			var type_lbl: Label = Label.new()
			type_lbl.text = types_str.strip_edges()
			type_lbl.add_theme_font_size_override("font_size", 10)
			type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			vb.add_child(type_lbl)

	# Update stats
	var stats_label: Label = _root.find_child("StatsLabel", true, false)
	if stats_label:
		stats_label.text = "Seen: %d / %d    Caught: %d / %d" % [seen_count, all_ids.size(), caught_count, all_ids.size()]

func _close() -> void:
	visible = false
	EventBus.panel_closed.emit("PokedexPanel")

func _on_panel_opened(panel_name: String) -> void:
	if panel_name == "PokedexPanel":
		_refresh()
		visible = true

func _on_panel_closed(panel_name: String) -> void:
	if panel_name == "PokedexPanel":
		visible = false
