## BattleUI — Mobile-friendly touch battle interface
##
## Displays creature HP bars, move buttons, action menu, and battle messages.
## Designed for portrait/landscape mobile with large touch targets.
extends CanvasLayer

# ── References ──
var _battle_system: BattleSystem = null
var _message_label: RichTextLabel = null
var _player_hp_bar: ProgressBar = null
var _player_hp_label: Label = null
var _player_name_label: Label = null
var _player_level_label: Label = null
var _player_status_label: Label = null
var _wild_hp_bar: ProgressBar = null
var _wild_hp_label: Label = null
var _wild_name_label: Label = null
var _wild_level_label: Label = null
var _wild_status_label: Label = null
var _move_container: GridContainer = null
var _action_container: HBoxContainer = null
var _ball_container: VBoxContainer = null
var _switch_container: VBoxContainer = null
var _item_container: VBoxContainer = null
var _main_panel: PanelContainer = null
var _sub_panel: PanelContainer = null
var _player_sprite: ColorRect = null
var _wild_sprite: ColorRect = null
var _message_queue: Array[String] = []
var _message_timer: float = 0.0
var _showing_message: bool = false
var _battle_arena: ColorRect = null

const MSG_DISPLAY_TIME: float = 1.2
const BUTTON_MIN_SIZE: Vector2 = Vector2(140, 56)

func setup(battle_system: BattleSystem) -> void:
	_battle_system = battle_system
	_battle_system.message_posted.connect(_on_message_posted)
	_battle_system.hp_updated.connect(_on_hp_updated)
	_battle_system.status_changed.connect(_on_status_changed)
	_battle_system.battle_ended.connect(_on_battle_ended)
	_battle_system.battle_state_changed.connect(_on_state_changed)
	_build_ui()
	visible = true

func _build_ui() -> void:
	layer = 20

	# ── Full screen background ──
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# ── Battle arena (top half) ──
	_battle_arena = ColorRect.new()
	_battle_arena.color = Color(0.18, 0.35, 0.18, 1.0)
	_battle_arena.custom_minimum_size = Vector2(0, 280)
	_battle_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_battle_arena)

	# Wild creature info (top-left of arena)
	var wild_info: VBoxContainer = VBoxContainer.new()
	wild_info.position = Vector2(16, 16)
	wild_info.custom_minimum_size = Vector2(260, 0)
	_battle_arena.add_child(wild_info)

	var wild_header: HBoxContainer = HBoxContainer.new()
	wild_info.add_child(wild_header)

	_wild_name_label = Label.new()
	_wild_name_label.text = "Wild Creature"
	_wild_name_label.add_theme_font_size_override("font_size", 18)
	_wild_name_label.add_theme_color_override("font_color", Color.WHITE)
	wild_header.add_child(_wild_name_label)

	_wild_level_label = Label.new()
	_wild_level_label.text = " Lv.5"
	_wild_level_label.add_theme_font_size_override("font_size", 16)
	_wild_level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	wild_header.add_child(_wild_level_label)

	_wild_status_label = Label.new()
	_wild_status_label.text = ""
	_wild_status_label.add_theme_font_size_override("font_size", 14)
	_wild_status_label.add_theme_color_override("font_color", Color.YELLOW)
	wild_info.add_child(_wild_status_label)

	_wild_hp_bar = ProgressBar.new()
	_wild_hp_bar.custom_minimum_size = Vector2(220, 12)
	_wild_hp_bar.max_value = 100
	_wild_hp_bar.value = 100
	_wild_hp_bar.show_percentage = false
	var wild_sb: StyleBoxFlat = StyleBoxFlat.new()
	wild_sb.bg_color = Color(0.2, 0.2, 0.2)
	wild_sb.corner_radius_top_left = 3
	wild_sb.corner_radius_top_right = 3
	wild_sb.corner_radius_bottom_left = 3
	wild_sb.corner_radius_bottom_right = 3
	_wild_hp_bar.add_theme_stylebox_override("background", wild_sb)
	var wild_fill: StyleBoxFlat = StyleBoxFlat.new()
	wild_fill.bg_color = Color(0.2, 0.85, 0.3)
	wild_fill.corner_radius_top_left = 3
	wild_fill.corner_radius_top_right = 3
	wild_fill.corner_radius_bottom_left = 3
	wild_fill.corner_radius_bottom_right = 3
	_wild_hp_bar.add_theme_stylebox_override("fill", wild_fill)
	wild_info.add_child(_wild_hp_bar)

	# Wild sprite (right side of arena)
	_wild_sprite = ColorRect.new()
	_wild_sprite.custom_minimum_size = Vector2(96, 96)
	_wild_sprite.size = Vector2(96, 96)
	_wild_sprite.position = Vector2(480, 30)
	_wild_sprite.color = Color.WHITE
	_battle_arena.add_child(_wild_sprite)

	# Player sprite (left-bottom of arena)
	_player_sprite = ColorRect.new()
	_player_sprite.custom_minimum_size = Vector2(96, 96)
	_player_sprite.size = Vector2(96, 96)
	_player_sprite.position = Vector2(60, 160)
	_player_sprite.color = Color.WHITE
	_battle_arena.add_child(_player_sprite)

	# Player creature info (bottom-right of arena)
	var player_info: VBoxContainer = VBoxContainer.new()
	player_info.position = Vector2(360, 160)
	player_info.custom_minimum_size = Vector2(280, 0)
	_battle_arena.add_child(player_info)

	var player_header: HBoxContainer = HBoxContainer.new()
	player_info.add_child(player_header)

	_player_name_label = Label.new()
	_player_name_label.text = "Your Creature"
	_player_name_label.add_theme_font_size_override("font_size", 18)
	_player_name_label.add_theme_color_override("font_color", Color.WHITE)
	player_header.add_child(_player_name_label)

	_player_level_label = Label.new()
	_player_level_label.text = " Lv.5"
	_player_level_label.add_theme_font_size_override("font_size", 16)
	_player_level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	player_header.add_child(_player_level_label)

	_player_status_label = Label.new()
	_player_status_label.text = ""
	_player_status_label.add_theme_font_size_override("font_size", 14)
	_player_status_label.add_theme_color_override("font_color", Color.YELLOW)
	player_info.add_child(_player_status_label)

	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.custom_minimum_size = Vector2(220, 12)
	_player_hp_bar.max_value = 100
	_player_hp_bar.value = 100
	_player_hp_bar.show_percentage = false
	var player_sb: StyleBoxFlat = StyleBoxFlat.new()
	player_sb.bg_color = Color(0.2, 0.2, 0.2)
	player_sb.corner_radius_top_left = 3
	player_sb.corner_radius_top_right = 3
	player_sb.corner_radius_bottom_left = 3
	player_sb.corner_radius_bottom_right = 3
	_player_hp_bar.add_theme_stylebox_override("background", player_sb)
	var player_fill: StyleBoxFlat = StyleBoxFlat.new()
	player_fill.bg_color = Color(0.2, 0.85, 0.3)
	player_fill.corner_radius_top_left = 3
	player_fill.corner_radius_top_right = 3
	player_fill.corner_radius_bottom_left = 3
	player_fill.corner_radius_bottom_right = 3
	_player_hp_bar.add_theme_stylebox_override("fill", player_fill)
	player_info.add_child(_player_hp_bar)

	_player_hp_label = Label.new()
	_player_hp_label.text = "100 / 100"
	_player_hp_label.add_theme_font_size_override("font_size", 14)
	_player_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_player_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_info.add_child(_player_hp_label)

	# ── Message box ──
	var msg_panel: PanelContainer = PanelContainer.new()
	msg_panel.custom_minimum_size = Vector2(0, 64)
	var msg_sb: StyleBoxFlat = StyleBoxFlat.new()
	msg_sb.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	msg_sb.border_color = Color(0.4, 0.4, 0.5)
	msg_sb.set_border_width_all(2)
	msg_sb.content_margin_left = 12
	msg_sb.content_margin_right = 12
	msg_sb.content_margin_top = 8
	msg_sb.content_margin_bottom = 8
	msg_panel.add_theme_stylebox_override("panel", msg_sb)
	root.add_child(msg_panel)

	_message_label = RichTextLabel.new()
	_message_label.bbcode_enabled = true
	_message_label.text = "What will you do?"
	_message_label.fit_content = true
	_message_label.add_theme_font_size_override("normal_font_size", 18)
	_message_label.add_theme_color_override("default_color", Color.WHITE)
	msg_panel.add_child(_message_label)

	# ── Action buttons panel ──
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(0, 160)
	var main_sb: StyleBoxFlat = StyleBoxFlat.new()
	main_sb.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	main_sb.content_margin_left = 8
	main_sb.content_margin_right = 8
	main_sb.content_margin_top = 8
	main_sb.content_margin_bottom = 8
	_main_panel.add_theme_stylebox_override("panel", main_sb)
	root.add_child(_main_panel)

	_action_container = HBoxContainer.new()
	_action_container.add_theme_constant_override("separation", 8)
	_action_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_child(_action_container)

	_add_action_button("FIGHT", Color(0.85, 0.3, 0.3), _on_fight_pressed)
	_add_action_button("BAG", Color(0.3, 0.7, 0.3), _on_bag_pressed)
	_add_action_button("PARTY", Color(0.3, 0.5, 0.85), _on_party_pressed)
	_add_action_button("RUN", Color(0.7, 0.7, 0.3), _on_run_pressed)

	# ── Move selection panel (hidden) ──
	_move_container = GridContainer.new()
	_move_container.columns = 2
	_move_container.add_theme_constant_override("h_separation", 8)
	_move_container.add_theme_constant_override("v_separation", 8)
	_move_container.visible = false
	_main_panel.add_child(_move_container)

	# ── Sub panels (balls, items, switch — hidden) ──
	_sub_panel = PanelContainer.new()
	_sub_panel.custom_minimum_size = Vector2(0, 160)
	var sub_sb: StyleBoxFlat = StyleBoxFlat.new()
	sub_sb.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	sub_sb.content_margin_left = 8
	sub_sb.content_margin_right = 8
	sub_sb.content_margin_top = 8
	sub_sb.content_margin_bottom = 8
	_sub_panel.add_theme_stylebox_override("panel", sub_sb)
	_sub_panel.visible = false
	root.add_child(_sub_panel)

	_ball_container = VBoxContainer.new()
	_ball_container.add_theme_constant_override("separation", 4)
	_sub_panel.add_child(_ball_container)

	_item_container = VBoxContainer.new()
	_item_container.add_theme_constant_override("separation", 4)
	_item_container.visible = false
	_sub_panel.add_child(_item_container)

	_switch_container = VBoxContainer.new()
	_switch_container.add_theme_constant_override("separation", 4)
	_switch_container.visible = false
	_sub_panel.add_child(_switch_container)

	# Initial creature data display
	_refresh_creature_display()

func _refresh_creature_display() -> void:
	if _battle_system == null:
		return
	var pc: CreatureInstance = _battle_system.get_player_creature()
	var wc: CreatureInstance = _battle_system.get_wild_creature()
	if pc:
		_player_name_label.text = pc.nickname
		_player_level_label.text = " Lv.%d" % pc.level
		var base: Dictionary = pc.get_base_data()
		var sc: Array = base.get("sprite_color", [0.5, 0.5, 0.5])
		_player_sprite.color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
	if wc:
		_wild_name_label.text = wc.nickname
		_wild_level_label.text = " Lv.%d" % wc.level
		var base: Dictionary = wc.get_base_data()
		var sc: Array = base.get("sprite_color", [0.5, 0.5, 0.5])
		_wild_sprite.color = Color(float(sc[0]), float(sc[1]), float(sc[2]))

func _add_action_button(text: String, color: Color, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(callback)
	_action_container.add_child(btn)

func _show_moves() -> void:
	# Clear old move buttons
	for child in _move_container.get_children():
		child.queue_free()

	var pc: CreatureInstance = _battle_system.get_player_creature()
	if pc == null:
		return

	for i in range(pc.known_moves.size()):
		var m: Dictionary = pc.known_moves[i]
		var move_data: Dictionary = DataManager.get_creature_move(m["id"])
		var move_type: String = str(move_data.get("type", "normal"))
		var type_color: Color = TypeChart.get_type_color(move_type)

		var btn: Button = Button.new()
		btn.text = "%s\n%s  PP: %d/%d" % [
			str(move_data.get("name", m["id"])),
			move_type.to_upper(),
			int(m["current_pp"]),
			int(m["max_pp"]),
		]
		btn.custom_minimum_size = Vector2(200, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = type_color.darkened(0.3)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h: StyleBoxFlat = sb.duplicate()
		sb_h.bg_color = type_color
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var idx: int = i
		btn.pressed.connect(func(): _on_move_selected(idx))
		_move_container.add_child(btn)

	# Back button
	var back_btn: Button = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(200, 56)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_sb: StyleBoxFlat = StyleBoxFlat.new()
	back_sb.bg_color = Color(0.4, 0.4, 0.4)
	back_sb.corner_radius_top_left = 6
	back_sb.corner_radius_top_right = 6
	back_sb.corner_radius_bottom_left = 6
	back_sb.corner_radius_bottom_right = 6
	back_sb.content_margin_top = 6
	back_sb.content_margin_bottom = 6
	back_btn.add_theme_stylebox_override("normal", back_sb)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.pressed.connect(_on_back_pressed)
	_move_container.add_child(back_btn)

func _show_bag_options() -> void:
	_sub_panel.visible = true
	_main_panel.visible = false
	_ball_container.visible = true
	_item_container.visible = false
	_switch_container.visible = false

	for child in _ball_container.get_children():
		child.queue_free()

	var label: Label = Label.new()
	label.text = "Choose an item:"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	_ball_container.add_child(label)

	# Balls
	var balls: Array[String] = ["pokeball", "greatball", "ultraball", "masterball"]
	var ball_names: Array[String] = ["Poké Ball", "Great Ball", "Ultra Ball", "Master Ball"]
	var ball_colors: Array[Color] = [
		Color(0.85, 0.25, 0.25), Color(0.3, 0.5, 0.85),
		Color(0.8, 0.75, 0.15), Color(0.6, 0.2, 0.7),
	]
	for i in range(balls.size()):
		var count: int = int(GameState.creature_bag.get(balls[i], 0))
		if count > 0:
			var btn: Button = Button.new()
			btn.text = "%s x%d" % [ball_names[i], count]
			btn.custom_minimum_size = Vector2(0, 44)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = ball_colors[i].darkened(0.3)
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_color_override("font_color", Color.WHITE)
			var ball_id: String = balls[i]
			btn.pressed.connect(func(): _on_ball_selected(ball_id))
			_ball_container.add_child(btn)

	# Healing items
	var items: Array[String] = ["potion", "super_potion", "hyper_potion", "revive"]
	var item_names: Array[String] = ["Potion", "Super Potion", "Hyper Potion", "Revive"]
	for i in range(items.size()):
		var count: int = int(GameState.creature_bag.get(items[i], 0))
		if count > 0:
			var btn: Button = Button.new()
			btn.text = "%s x%d" % [item_names[i], count]
			btn.custom_minimum_size = Vector2(0, 44)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0.2, 0.5, 0.3)
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_color_override("font_color", Color.WHITE)
			var item_id: String = items[i]
			btn.pressed.connect(func(): _on_item_used(item_id))
			_ball_container.add_child(btn)

	# Back button
	var back: Button = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 44)
	var back_sb: StyleBoxFlat = StyleBoxFlat.new()
	back_sb.bg_color = Color(0.4, 0.4, 0.4)
	back_sb.corner_radius_top_left = 6
	back_sb.corner_radius_top_right = 6
	back_sb.corner_radius_bottom_left = 6
	back_sb.corner_radius_bottom_right = 6
	back.add_theme_stylebox_override("normal", back_sb)
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.pressed.connect(_on_back_pressed)
	_ball_container.add_child(back)

func _show_party_options() -> void:
	_sub_panel.visible = true
	_main_panel.visible = false
	_ball_container.visible = false
	_item_container.visible = false
	_switch_container.visible = true

	for child in _switch_container.get_children():
		child.queue_free()

	var label: Label = Label.new()
	label.text = "Switch to:"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	_switch_container.add_child(label)

	for i in range(GameState.creature_party.size()):
		var c: Dictionary = GameState.creature_party[i]
		var creature_data: Dictionary = DataManager.get_creature(str(c.get("creature_id", "")))
		var name: String = str(c.get("nickname", creature_data.get("name", "???")))
		var hp: int = int(c.get("current_hp", 0))
		var is_active: bool = (str(c.get("creature_id", "")) == _battle_system.get_player_creature().creature_id)
		var is_fainted: bool = hp <= 0

		var btn: Button = Button.new()
		btn.text = "%s  Lv.%d  HP: %d" % [name, int(c.get("level", 1)), hp]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = is_active or is_fainted
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.5, 0.7) if not is_fainted else Color(0.4, 0.2, 0.2)
		if is_active:
			sb.bg_color = Color(0.2, 0.4, 0.2)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var idx: int = i
		btn.pressed.connect(func(): _on_switch_selected(idx))
		_switch_container.add_child(btn)

	var back: Button = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 44)
	var back_sb: StyleBoxFlat = StyleBoxFlat.new()
	back_sb.bg_color = Color(0.4, 0.4, 0.4)
	back_sb.corner_radius_top_left = 6
	back_sb.corner_radius_top_right = 6
	back_sb.corner_radius_bottom_left = 6
	back_sb.corner_radius_bottom_right = 6
	back.add_theme_stylebox_override("normal", back_sb)
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.pressed.connect(_on_back_pressed)
	_switch_container.add_child(back)

# ── Callbacks ──

func _on_fight_pressed() -> void:
	_action_container.visible = false
	_move_container.visible = true
	_show_moves()

func _on_bag_pressed() -> void:
	_show_bag_options()

func _on_party_pressed() -> void:
	_show_party_options()

func _on_run_pressed() -> void:
	_battle_system.attempt_run()

func _on_move_selected(index: int) -> void:
	_move_container.visible = false
	_action_container.visible = true
	_battle_system.select_move(index)

func _on_ball_selected(ball_type: String) -> void:
	_sub_panel.visible = false
	_main_panel.visible = true
	_battle_system.attempt_catch(ball_type)

func _on_item_used(item_type: String) -> void:
	_sub_panel.visible = false
	_main_panel.visible = true
	_battle_system.use_item(item_type)

func _on_switch_selected(index: int) -> void:
	_sub_panel.visible = false
	_main_panel.visible = true
	_battle_system.switch_creature(index)

func _on_back_pressed() -> void:
	_move_container.visible = false
	_action_container.visible = true
	_sub_panel.visible = false
	_main_panel.visible = true

func _on_message_posted(text: String) -> void:
	_message_label.text = text

func _on_hp_updated(is_player: bool, current: int, max_hp: int) -> void:
	if is_player:
		_player_hp_bar.max_value = max_hp
		_player_hp_bar.value = current
		_player_hp_label.text = "%d / %d" % [current, max_hp]
		# Color based on HP %
		var pct: float = float(current) / float(max_hp)
		var fill: StyleBoxFlat = _player_hp_bar.get_theme_stylebox("fill").duplicate()
		if pct > 0.5:
			fill.bg_color = Color(0.2, 0.85, 0.3)
		elif pct > 0.2:
			fill.bg_color = Color(0.9, 0.8, 0.2)
		else:
			fill.bg_color = Color(0.9, 0.2, 0.2)
		_player_hp_bar.add_theme_stylebox_override("fill", fill)
	else:
		_wild_hp_bar.max_value = max_hp
		_wild_hp_bar.value = current
		var pct: float = float(current) / float(max_hp)
		var fill: StyleBoxFlat = _wild_hp_bar.get_theme_stylebox("fill").duplicate()
		if pct > 0.5:
			fill.bg_color = Color(0.2, 0.85, 0.3)
		elif pct > 0.2:
			fill.bg_color = Color(0.9, 0.8, 0.2)
		else:
			fill.bg_color = Color(0.9, 0.2, 0.2)
		_wild_hp_bar.add_theme_stylebox_override("fill", fill)

func _on_status_changed(is_player: bool, status: String) -> void:
	var label: Label = _player_status_label if is_player else _wild_status_label
	match status:
		"burn": label.text = "[BRN]"
		"paralyze": label.text = "[PAR]"
		"poison": label.text = "[PSN]"
		"sleep": label.text = "[SLP]"
		"freeze": label.text = "[FRZ]"
		_: label.text = ""

func _on_state_changed(new_state: BattleSystem.BattleState) -> void:
	match new_state:
		BattleSystem.BattleState.PLAYER_TURN:
			_message_label.text = "What will you do?"
			_action_container.visible = true
			_move_container.visible = false
			_main_panel.visible = true
			_sub_panel.visible = false
			_refresh_creature_display()

func _on_battle_ended(_result: String) -> void:
	# Disable all buttons, show end message
	await get_tree().create_timer(1.5).timeout
	queue_free()
