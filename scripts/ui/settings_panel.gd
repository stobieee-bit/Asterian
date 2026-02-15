## SettingsPanel — Game settings with audio, display, combat, and save/load controls
##
## Extends PanelContainer. All UI built programmatically in _ready().
## Reads and writes GameState.settings dictionary. Emits EventBus.settings_changed
## on every slider/checkbox change. Save/Load use SaveManager singleton.
extends PanelContainer

# ── Node refs (audio) ──
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null

# ── Node refs (display) ──
var _damage_numbers_check: CheckBox = null
var _hp_bars_check: CheckBox = null

# ── Node refs (combat) ──
var _auto_retaliate_check: CheckBox = null

# ── Node refs (game) ──
var _play_time_label: Label = null

# ── Node refs (header) ──
var _title_label: Label = null
var _close_btn: Button = null

func _ready() -> void:
	custom_minimum_size = Vector2(300, 360)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Settings", _on_close)
	vbox.add_child(drag_header)

	# ── Audio section ──
	vbox.add_child(_create_section_header("Audio"))

	_music_slider = _create_slider_row(vbox, "Music Volume", 0.0, 1.0, 0.05)
	_music_slider.value_changed.connect(_on_music_volume_changed)

	_sfx_slider = _create_slider_row(vbox, "SFX Volume", 0.0, 1.0, 0.05)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# ── Display section ──
	vbox.add_child(_create_section_header("Display"))

	_damage_numbers_check = _create_checkbox_row(vbox, "Show Damage Numbers")
	_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)

	_hp_bars_check = _create_checkbox_row(vbox, "Show HP Bars")
	_hp_bars_check.toggled.connect(_on_hp_bars_toggled)

	# ── Combat section ──
	vbox.add_child(_create_section_header("Combat"))

	_auto_retaliate_check = _create_checkbox_row(vbox, "Auto Retaliate")
	_auto_retaliate_check.toggled.connect(_on_auto_retaliate_toggled)

	# ── Game section ──
	vbox.add_child(_create_section_header("Game"))

	var save_load_row: HBoxContainer = HBoxContainer.new()
	save_load_row.add_theme_constant_override("separation", 8)
	vbox.add_child(save_load_row)

	var save_btn: Button = Button.new()
	save_btn.text = "Save Game"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_save_pressed)
	save_load_row.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.text = "Load Game"
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(_on_load_pressed)
	save_load_row.add_child(load_btn)

	# Play time display
	_play_time_label = Label.new()
	_play_time_label.add_theme_font_size_override("font_size", 11)
	_play_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_play_time_label)

	# Set initial values from GameState
	refresh()

# ── Section header factory ──

## Create a section header label with slightly brighter color
func _create_section_header(title: String) -> Label:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	return label

# ── Row factories ──

## Create an HBoxContainer with a label and HSlider, returns the slider
func _create_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step_val: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.custom_minimum_size = Vector2(120, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	return slider

## Create an HBoxContainer with a label and CheckBox, returns the checkbox
func _create_checkbox_row(parent: VBoxContainer, label_text: String) -> CheckBox:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(label)

	var checkbox: CheckBox = CheckBox.new()
	row.add_child(checkbox)

	return checkbox

# ── Public API ──

## Refresh all UI elements from GameState.settings
func refresh() -> void:
	var s: Dictionary = GameState.settings

	# Audio
	if _music_slider != null:
		_music_slider.set_value_no_signal(float(s.get("music_volume", 0.5)))
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(float(s.get("sfx_volume", 0.7)))

	# Display
	if _damage_numbers_check != null:
		_damage_numbers_check.set_pressed_no_signal(bool(s.get("show_damage_numbers", true)))
	if _hp_bars_check != null:
		_hp_bars_check.set_pressed_no_signal(bool(s.get("show_hp_bars", true)))

	# Combat
	if _auto_retaliate_check != null:
		_auto_retaliate_check.set_pressed_no_signal(bool(s.get("auto_retaliate", true)))

	# Play time
	_update_play_time()

# ── Signal handlers (audio) ──

## Called when the music volume slider changes
func _on_music_volume_changed(value: float) -> void:
	GameState.settings["music_volume"] = value
	EventBus.settings_changed.emit("music_volume", value)

## Called when the SFX volume slider changes
func _on_sfx_volume_changed(value: float) -> void:
	GameState.settings["sfx_volume"] = value
	EventBus.settings_changed.emit("sfx_volume", value)

# ── Signal handlers (display) ──

## Called when the "Show Damage Numbers" checkbox is toggled
func _on_damage_numbers_toggled(pressed: bool) -> void:
	GameState.settings["show_damage_numbers"] = pressed
	EventBus.settings_changed.emit("show_damage_numbers", pressed)

## Called when the "Show HP Bars" checkbox is toggled
func _on_hp_bars_toggled(pressed: bool) -> void:
	GameState.settings["show_hp_bars"] = pressed
	EventBus.settings_changed.emit("show_hp_bars", pressed)

# ── Signal handlers (combat) ──

## Called when the "Auto Retaliate" checkbox is toggled
func _on_auto_retaliate_toggled(pressed: bool) -> void:
	GameState.settings["auto_retaliate"] = pressed
	EventBus.settings_changed.emit("auto_retaliate", pressed)

# ── Signal handlers (game) ──

## Save game and emit feedback via chat
func _on_save_pressed() -> void:
	var success: bool = SaveManager.save_game()
	if success:
		EventBus.chat_message.emit("Game saved!", "system")
	else:
		EventBus.chat_message.emit("Error: Could not save game.", "system")

## Load game and emit feedback via chat
func _on_load_pressed() -> void:
	var success: bool = SaveManager.load_game()
	if success:
		EventBus.chat_message.emit("Game loaded!", "system")
		refresh()
	else:
		EventBus.chat_message.emit("No save file found.", "system")

# ── Close handler ──

## Hide the panel and notify the UI system
func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("settings")

# ── Play time ──

## Update the play time display label from GameState.total_play_time
func _update_play_time() -> void:
	if _play_time_label == null:
		return

	var total_seconds: int = int(GameState.total_play_time)
	var hours: int = int(total_seconds / 3600)
	var minutes: int = int((total_seconds % 3600) / 60)
	_play_time_label.text = "Total Play Time: %dh %dm" % [hours, minutes]
