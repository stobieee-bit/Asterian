## DungeonPanel — UI for entering and managing dungeon runs
##
## When no dungeon is active, shows a modifier-selection screen with an
## "Enter Dungeon" button.  Once inside, switches to a status view with
## current floor info, active modifiers, room progress, and buttons to
## advance floors or exit the dungeon.
##
## Reads modifier definitions from DataManager.dungeon_modifiers and current
## run state from GameState (dungeon_active, dungeon_floor).
## Communicates with dungeon_system via the "dungeon_system" group.
extends PanelContainer


# ──────────────────────────────────────────────
#  Node references
# ──────────────────────────────────────────────

var _title_label: Label = null
var _close_btn: Button = null

## Container shown when a dungeon run IS active
var _status_section: VBoxContainer = null
var _floor_label: Label = null
var _theme_label: Label = null
var _modifiers_container: VBoxContainer = null
var _rooms_label: Label = null
var _next_floor_btn: Button = null
var _exit_btn: Button = null

## Container shown when a dungeon run is NOT active
var _entry_section: VBoxContainer = null
var _modifier_list: VBoxContainer = null
var _enter_btn: Button = null

## Scroll wrapper for the modifier checklist
var _mod_scroll: ScrollContainer = null

## Stores references to the modifier CheckBox nodes keyed by modifier ID
var _modifier_checks: Dictionary = {}


# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	custom_minimum_size = Vector2(340, 380)
	visible = false
	z_index = 50

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Dungeon", _on_close)
	root_vbox.add_child(drag_header)

	# ── Status section (visible when dungeon IS active) ──
	_status_section = VBoxContainer.new()
	_status_section.add_theme_constant_override("separation", 4)
	root_vbox.add_child(_status_section)

	_floor_label = Label.new()
	_floor_label.add_theme_font_size_override("font_size", 18)
	_floor_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	_status_section.add_child(_floor_label)

	_theme_label = Label.new()
	_theme_label.add_theme_font_size_override("font_size", 14)
	_theme_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_section.add_child(_theme_label)

	# Sub-header for active modifiers
	var mod_title: Label = Label.new()
	mod_title.text = "Active Modifiers:"
	mod_title.add_theme_font_size_override("font_size", 14)
	mod_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_section.add_child(mod_title)

	_modifiers_container = VBoxContainer.new()
	_modifiers_container.add_theme_constant_override("separation", 2)
	_status_section.add_child(_modifiers_container)

	_rooms_label = Label.new()
	_rooms_label.add_theme_font_size_override("font_size", 14)
	_rooms_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_status_section.add_child(_rooms_label)

	_next_floor_btn = Button.new()
	_next_floor_btn.text = "Next Floor"
	_next_floor_btn.custom_minimum_size = Vector2(120, 32)
	_next_floor_btn.add_theme_font_size_override("font_size", 15)
	_next_floor_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_next_floor_btn.pressed.connect(_on_next_floor)
	_status_section.add_child(_next_floor_btn)

	_exit_btn = Button.new()
	_exit_btn.text = "Exit Dungeon"
	_exit_btn.custom_minimum_size = Vector2(120, 30)
	_exit_btn.add_theme_font_size_override("font_size", 14)
	_exit_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_exit_btn.pressed.connect(_on_exit_dungeon)
	_status_section.add_child(_exit_btn)

	# ── Entry section (visible when dungeon is NOT active) ──
	_entry_section = VBoxContainer.new()
	_entry_section.add_theme_constant_override("separation", 4)
	root_vbox.add_child(_entry_section)

	var select_label: Label = Label.new()
	select_label.text = "Select Modifiers:"
	select_label.add_theme_font_size_override("font_size", 15)
	select_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_entry_section.add_child(select_label)

	_mod_scroll = ScrollContainer.new()
	_mod_scroll.custom_minimum_size = Vector2(320, 200)
	_mod_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mod_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_section.add_child(_mod_scroll)

	_modifier_list = VBoxContainer.new()
	_modifier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modifier_list.add_theme_constant_override("separation", 4)
	_mod_scroll.add_child(_modifier_list)

	_enter_btn = Button.new()
	_enter_btn.text = "Enter Dungeon"
	_enter_btn.custom_minimum_size = Vector2(160, 36)
	_enter_btn.add_theme_font_size_override("font_size", 16)
	_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	_enter_btn.pressed.connect(_on_enter_dungeon)
	_entry_section.add_child(_enter_btn)

	# ── Connect EventBus signals for auto-refresh ──
	EventBus.dungeon_started.connect(_on_dungeon_started)
	EventBus.dungeon_floor_advanced.connect(_on_dungeon_floor_advanced)
	EventBus.dungeon_room_cleared.connect(_on_dungeon_room_cleared)
	EventBus.dungeon_exited.connect(_on_dungeon_exited)

	# Initial build
	refresh()


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Rebuild the entire panel based on whether a dungeon is active.
func refresh() -> void:
	var is_active: bool = bool(GameState.dungeon_active)

	_status_section.visible = is_active
	_entry_section.visible = not is_active

	if is_active:
		_refresh_status()
	else:
		_refresh_entry()


# ──────────────────────────────────────────────
#  Status section (dungeon active)
# ──────────────────────────────────────────────

## Update floor number, theme, modifiers, and room progress.
func _refresh_status() -> void:
	var floor_num: int = int(GameState.dungeon_floor)
	_floor_label.text = "Floor %d" % floor_num

	# Theme name from dungeon_system
	var dungeon_sys: Node = _get_dungeon_system()
	var theme_name: String = "Unknown"
	if dungeon_sys != null and dungeon_sys.has_method("get_current_theme"):
		var theme: Dictionary = dungeon_sys.get_current_theme()
		theme_name = str(theme.get("name", "Unknown"))
	_theme_label.text = "Theme: %s" % theme_name

	# Rebuild active modifiers list
	_refresh_active_modifiers(dungeon_sys)

	# Rooms cleared count
	_refresh_rooms_label(dungeon_sys)

	# Next floor button: only enabled when the current floor is complete
	var floor_complete: bool = false
	if dungeon_sys != null and dungeon_sys.has_method("is_floor_complete"):
		floor_complete = bool(dungeon_sys.is_floor_complete())
	_next_floor_btn.disabled = not floor_complete


## Rebuild the active modifiers list inside the status section.
func _refresh_active_modifiers(dungeon_sys: Node) -> void:
	# Clear old entries
	for child in _modifiers_container.get_children():
		child.queue_free()

	var active_mods: Array = []
	if dungeon_sys != null and dungeon_sys.has_method("get_active_modifiers"):
		active_mods = dungeon_sys.get_active_modifiers()

	if active_mods.is_empty():
		var none_label: Label = Label.new()
		none_label.text = "  None"
		none_label.add_theme_font_size_override("font_size", 14)
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_modifiers_container.add_child(none_label)
		return

	for mod in active_mods:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_modifiers_container.add_child(row)

		# Icon label (emoji/text stand-in)
		var icon_lbl: Label = Label.new()
		icon_lbl.text = str(mod.get("icon", "?"))
		icon_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(icon_lbl)

		# Modifier name
		var name_lbl: Label = Label.new()
		name_lbl.text = str(mod.get("name", "Unknown"))
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(name_lbl)


## Update the "Rooms Cleared: X / Y" label from current floor data.
func _refresh_rooms_label(dungeon_sys: Node) -> void:
	var total_rooms: int = 0
	var cleared_rooms: int = 0

	if dungeon_sys != null and "_current_floor_data" in dungeon_sys:
		var floor_data: Dictionary = dungeon_sys._current_floor_data
		var rooms: Array = floor_data.get("rooms", [])
		total_rooms = int(rooms.size())
		for room in rooms:
			if bool(room.get("cleared", false)):
				cleared_rooms += 1

	_rooms_label.text = "Rooms Cleared: %d / %d" % [cleared_rooms, total_rooms]


# ──────────────────────────────────────────────
#  Entry section (dungeon not active)
# ──────────────────────────────────────────────

## Rebuild the modifier checkbox list from DataManager.dungeon_modifiers.
func _refresh_entry() -> void:
	# Clear old entries
	for child in _modifier_list.get_children():
		child.queue_free()
	_modifier_checks.clear()

	var modifiers: Dictionary = DataManager.dungeon_modifiers

	for mod_id in modifiers:
		var mod: Dictionary = modifiers[mod_id]
		var mod_name: String = str(mod.get("name", mod_id))
		var mod_icon: String = str(mod.get("icon", "?"))
		var mod_desc: String = str(mod.get("desc", ""))

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_modifier_list.add_child(row)

		# CheckBox
		var check: CheckBox = CheckBox.new()
		check.custom_minimum_size = Vector2(22, 22)
		row.add_child(check)
		_modifier_checks[str(mod_id)] = check

		# Icon label
		var icon_lbl: Label = Label.new()
		icon_lbl.text = mod_icon
		icon_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(icon_lbl)

		# Name + description label
		var info_lbl: Label = Label.new()
		info_lbl.text = "%s — %s" % [mod_name, mod_desc]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_font_size_override("font_size", 14)
		info_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info_lbl)


# ──────────────────────────────────────────────
#  Callbacks
# ──────────────────────────────────────────────

## Close the panel and notify the event bus.
func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("dungeon")


## Collect selected modifier IDs and start a dungeon run.
func _on_enter_dungeon() -> void:
	var dungeon_sys: Node = _get_dungeon_system()
	if dungeon_sys == null:
		push_warning("DungeonPanel: No dungeon_system node found in scene tree.")
		return

	# Gather selected modifier IDs
	var selected_mods: Array = []
	for mod_id in _modifier_checks:
		var check: CheckBox = _modifier_checks[mod_id] as CheckBox
		if check != null and bool(check.button_pressed):
			selected_mods.append(str(mod_id))

	if dungeon_sys.has_method("start_dungeon"):
		dungeon_sys.start_dungeon(str(GameState.current_area), selected_mods)

	refresh()


## Advance to the next dungeon floor.
func _on_next_floor() -> void:
	var dungeon_sys: Node = _get_dungeon_system()
	if dungeon_sys == null:
		push_warning("DungeonPanel: No dungeon_system node found in scene tree.")
		return

	if dungeon_sys.has_method("advance_floor"):
		dungeon_sys.advance_floor()

	refresh()


## Exit the current dungeon run.
func _on_exit_dungeon() -> void:
	var dungeon_sys: Node = _get_dungeon_system()
	if dungeon_sys == null:
		push_warning("DungeonPanel: No dungeon_system node found in scene tree.")
		return

	if dungeon_sys.has_method("exit_dungeon"):
		dungeon_sys.exit_dungeon()

	refresh()


# ── EventBus auto-refresh handlers ──

## Auto-refresh when a dungeon starts.
func _on_dungeon_started(_floor_data: Dictionary) -> void:
	refresh()


## Auto-refresh when a new floor begins.
func _on_dungeon_floor_advanced(_floor_data: Dictionary) -> void:
	refresh()


## Auto-refresh when a room is cleared.
func _on_dungeon_room_cleared(_grid_x: int, _grid_z: int) -> void:
	refresh()


## Auto-refresh when the dungeon run ends.
func _on_dungeon_exited() -> void:
	refresh()


# ──────────────────────────────────────────────
#  Helpers
# ──────────────────────────────────────────────

## Look up the dungeon_system node via the scene tree group.
func _get_dungeon_system() -> Node:
	return get_tree().get_first_node_in_group("dungeon_system")
