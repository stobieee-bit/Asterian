## CreaturePartyPanel — Mobile party management screen
##
## Displays the player's party of up to 6 creatures with HP bars,
## types, and status. Allows rearranging and viewing details.
extends CanvasLayer

var _root: PanelContainer = null
var _party_list: VBoxContainer = null
var _visible: bool = false

func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)
	EventBus.creature_party_changed.connect(_refresh)

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.18, 0.97)
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
	title.text = "PARTY"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
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

	# Scroll container for party list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 6)
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_party_list)

	# Heal All button (bottom)
	var heal_btn: Button = Button.new()
	heal_btn.text = "HEAL ALL (at Heal Pad)"
	heal_btn.custom_minimum_size = Vector2(0, 48)
	var heal_sb: StyleBoxFlat = StyleBoxFlat.new()
	heal_sb.bg_color = Color(0.7, 0.2, 0.3)
	heal_sb.corner_radius_top_left = 8
	heal_sb.corner_radius_top_right = 8
	heal_sb.corner_radius_bottom_left = 8
	heal_sb.corner_radius_bottom_right = 8
	heal_btn.add_theme_stylebox_override("normal", heal_sb)
	heal_btn.add_theme_font_size_override("font_size", 16)
	heal_btn.add_theme_color_override("font_color", Color.WHITE)
	heal_btn.pressed.connect(_heal_all)
	vbox.add_child(heal_btn)

func _refresh() -> void:
	for child in _party_list.get_children():
		child.queue_free()

	for i in range(GameState.creature_party.size()):
		var c: Dictionary = GameState.creature_party[i]
		var creature_data: Dictionary = DataManager.get_creature(str(c.get("creature_id", "")))
		if creature_data.is_empty():
			continue

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 72)
		var card_sb: StyleBoxFlat = StyleBoxFlat.new()
		var hp: int = int(c.get("current_hp", 0))
		card_sb.bg_color = Color(0.2, 0.25, 0.35) if hp > 0 else Color(0.3, 0.15, 0.15)
		card_sb.corner_radius_top_left = 8
		card_sb.corner_radius_top_right = 8
		card_sb.corner_radius_bottom_left = 8
		card_sb.corner_radius_bottom_right = 8
		card_sb.content_margin_left = 12
		card_sb.content_margin_right = 12
		card_sb.content_margin_top = 8
		card_sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_sb)
		_party_list.add_child(card)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		# Creature color icon
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		var sc: Array = creature_data.get("sprite_color", [0.5, 0.5, 0.5])
		icon.color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
		hbox.add_child(icon)

		# Info
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_label: Label = Label.new()
		name_label.text = "%s  Lv.%d" % [str(c.get("nickname", creature_data.get("name", "???"))), int(c.get("level", 1))]
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		info.add_child(name_label)

		# Type badges
		var types_hbox: HBoxContainer = HBoxContainer.new()
		types_hbox.add_theme_constant_override("separation", 4)
		info.add_child(types_hbox)
		var types: Array = creature_data.get("types", [])
		for t in types:
			var type_label: Label = Label.new()
			type_label.text = " %s " % str(t).to_upper()
			type_label.add_theme_font_size_override("font_size", 11)
			type_label.add_theme_color_override("font_color", Color.WHITE)
			types_hbox.add_child(type_label)

		# HP bar
		var inst: CreatureInstance = CreatureInstance.from_dict(c)
		var hp_bar: ProgressBar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 8)
		hp_bar.max_value = inst.max_hp
		hp_bar.value = hp
		hp_bar.show_percentage = false
		var bg_sb: StyleBoxFlat = StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.2, 0.2, 0.2)
		bg_sb.corner_radius_top_left = 2
		bg_sb.corner_radius_top_right = 2
		bg_sb.corner_radius_bottom_left = 2
		bg_sb.corner_radius_bottom_right = 2
		hp_bar.add_theme_stylebox_override("background", bg_sb)
		var fill_sb: StyleBoxFlat = StyleBoxFlat.new()
		var pct: float = float(hp) / float(inst.max_hp) if inst.max_hp > 0 else 0.0
		if pct > 0.5:
			fill_sb.bg_color = Color(0.2, 0.85, 0.3)
		elif pct > 0.2:
			fill_sb.bg_color = Color(0.9, 0.8, 0.2)
		else:
			fill_sb.bg_color = Color(0.9, 0.2, 0.2)
		fill_sb.corner_radius_top_left = 2
		fill_sb.corner_radius_top_right = 2
		fill_sb.corner_radius_bottom_left = 2
		fill_sb.corner_radius_bottom_right = 2
		hp_bar.add_theme_stylebox_override("fill", fill_sb)
		info.add_child(hp_bar)

		var hp_label: Label = Label.new()
		hp_label.text = "HP: %d / %d" % [hp, inst.max_hp]
		hp_label.add_theme_font_size_override("font_size", 12)
		hp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info.add_child(hp_label)

func _heal_all() -> void:
	for i in range(GameState.creature_party.size()):
		var c: Dictionary = GameState.creature_party[i]
		var inst: CreatureInstance = CreatureInstance.from_dict(c)
		inst.full_heal()
		GameState.creature_party[i] = inst.to_dict()
	_refresh()

func _close() -> void:
	visible = false
	_visible = false
	EventBus.panel_closed.emit("CreaturePartyPanel")

func _on_panel_opened(panel_name: String) -> void:
	if panel_name == "CreaturePartyPanel":
		_refresh()
		visible = true
		_visible = true

func _on_panel_closed(panel_name: String) -> void:
	if panel_name == "CreaturePartyPanel":
		visible = false
		_visible = false
