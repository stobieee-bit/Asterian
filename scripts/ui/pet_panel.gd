## PetPanel — Pet management panel for summoning, dismissing, and viewing pets
##
## Displays the currently active pet (with XP bar, buff info, evolution stage),
## and a scrollable list of all owned pets with summon buttons. Built entirely
## in code via _ready(). Find the pet system at runtime through the
## "pet_system" group.
extends PanelContainer

# ── Rarity color lookup ──
const RARITY_COLORS: Dictionary = {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.9, 0.3),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.8, 0.3, 1.0),
}

# ── Buff type display format strings ──
const BUFF_FORMATS: Dictionary = {
	"hp": "+%s HP",
	"damage": "+%s Damage",
	"defense": "+%s Defense",
	"speed": "+%s%% Speed",
	"xp": "+%s%% XP",
	"gathering": "+%s%% Gathering",
	"all": "+%s All Stats",
}

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _active_section: VBoxContainer = null
var _no_pet_label: Label = null
var _scroll: ScrollContainer = null
var _list_container: VBoxContainer = null
var _root_vbox: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(320, 380)
	visible = false
	z_index = 50

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 6)
	add_child(_root_vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Pets", _on_close)
	_root_vbox.add_child(drag_header)

	# ── Active pet section (rebuilt dynamically) ──
	_active_section = VBoxContainer.new()
	_active_section.add_theme_constant_override("separation", 3)
	_root_vbox.add_child(_active_section)

	# ── Placeholder when no pet is active ──
	_no_pet_label = Label.new()
	_no_pet_label.text = "No pet summoned"
	_no_pet_label.add_theme_font_size_override("font_size", 14)
	_no_pet_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_root_vbox.add_child(_no_pet_label)

	# ── Separator between active pet and owned list ──
	_root_vbox.add_child(HSeparator.new())

	# ── Owned pets header ──
	var list_title: Label = Label.new()
	list_title.text = "Owned Pets"
	list_title.add_theme_font_size_override("font_size", 15)
	list_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_root_vbox.add_child(list_title)

	# ── Scrollable owned pets list ──
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root_vbox.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list_container)

	# Initial draw
	refresh()


# ── Public API ─────────────────────────────────────────────────────────────

## Rebuild the entire panel: active pet section and owned pets list.
func refresh() -> void:
	_refresh_active_section()
	_refresh_owned_list()


# ── Active pet section ─────────────────────────────────────────────────────

## Rebuild the active pet details area. Shows pet name, XP bar, buff, evolution
## stage, and a dismiss button when a pet is summoned. Shows a placeholder label
## when no pet is active.
func _refresh_active_section() -> void:
	# Clear previous active section content
	for child in _active_section.get_children():
		child.queue_free()

	var active_id: String = str(GameState.active_pet)

	if active_id == "":
		_active_section.visible = false
		_no_pet_label.visible = true
		return

	# We have an active pet — hide the placeholder
	_active_section.visible = true
	_no_pet_label.visible = false

	# Look up pet definition from DataManager
	var pet_def: Dictionary = _find_pet_def(active_id)
	if pet_def.is_empty():
		_active_section.visible = false
		_no_pet_label.visible = true
		return

	var pet_state: Dictionary = GameState.owned_pets.get(active_id, {}) as Dictionary
	var pet_level: int = int(pet_state.get("level", 1))
	var pet_xp: int = int(pet_state.get("xp", 0))
	var pet_name: String = str(pet_def.get("name", active_id))
	var pet_rarity: String = str(pet_def.get("rarity", "common"))
	var max_level: int = int(pet_def.get("maxLevel", 20))
	var rarity_color: Color = RARITY_COLORS.get(pet_rarity, Color(0.6, 0.6, 0.6))

	# ── Name + Level ──
	var name_label: Label = Label.new()
	name_label.text = "%s  (Lv %d)" % [pet_name, pet_level]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", rarity_color)
	_active_section.add_child(name_label)

	# ── XP progress bar ──
	var xp_needed: int = _xp_for_pet_level(pet_level + 1)
	var xp_current_level: int = _xp_for_pet_level(pet_level)
	var xp_into_level: int = int(max(0, pet_xp - xp_current_level))
	var xp_range: int = int(max(1, xp_needed - xp_current_level))

	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(280, 16)
	xp_bar.max_value = float(xp_range)
	xp_bar.value = float(min(xp_into_level, xp_range))
	xp_bar.show_percentage = false
	_active_section.add_child(xp_bar)

	# XP text below bar
	var xp_label: Label = Label.new()
	if pet_level >= max_level:
		xp_label.text = "XP: MAX"
	else:
		xp_label.text = "XP: %d / %d" % [xp_into_level, xp_range]
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_active_section.add_child(xp_label)

	# ── Buff description ──
	var buff_label: Label = Label.new()
	buff_label.text = _format_buff(pet_def, pet_level)
	buff_label.add_theme_font_size_override("font_size", 14)
	buff_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_active_section.add_child(buff_label)

	# ── Evolution stage indicator ──
	var evo_levels: Array = pet_def.get("evolutionLevels", []) as Array
	var current_stage: int = _get_evolution_stage(pet_level, evo_levels)
	var total_stages: int = int(evo_levels.size()) + 1

	var evo_label: Label = Label.new()
	evo_label.text = "Stage %d/%d" % [current_stage, total_stages]
	evo_label.add_theme_font_size_override("font_size", 14)
	evo_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_active_section.add_child(evo_label)

	# ── Dismiss button ──
	var dismiss_btn: Button = Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.custom_minimum_size = Vector2(80, 26)
	dismiss_btn.add_theme_font_size_override("font_size", 14)
	dismiss_btn.pressed.connect(_on_dismiss)
	_active_section.add_child(dismiss_btn)


# ── Owned pets list ────────────────────────────────────────────────────────

## Rebuild the scrollable list of all owned pets with summon buttons.
func _refresh_owned_list() -> void:
	# Clear previous entries
	for child in _list_container.get_children():
		child.queue_free()

	var active_id: String = str(GameState.active_pet)
	var owned: Dictionary = GameState.owned_pets

	if owned.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No pets owned yet."
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_list_container.add_child(empty_label)
		return

	# Iterate all owned pet IDs
	for pet_id in owned:
		var pet_id_str: String = str(pet_id)
		var pet_def: Dictionary = _find_pet_def(pet_id_str)
		if pet_def.is_empty():
			continue

		var pet_state: Dictionary = owned[pet_id] as Dictionary
		var pet_level: int = int(pet_state.get("level", 1))
		var pet_name: String = str(pet_def.get("name", pet_id_str))
		var pet_rarity: String = str(pet_def.get("rarity", "common"))
		var rarity_color: Color = RARITY_COLORS.get(pet_rarity, Color(0.6, 0.6, 0.6))
		var is_active: bool = pet_id_str == active_id

		# Row container
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list_container.add_child(row)

		# ── Pet name (colored by rarity) ──
		var name_label: Label = Label.new()
		name_label.text = pet_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 100
		if is_active:
			# Highlight active pet with a brighter version of its rarity color
			name_label.add_theme_color_override("font_color", rarity_color.lightened(0.3))
		else:
			name_label.add_theme_color_override("font_color", rarity_color)
		row.add_child(name_label)

		# ── Level label ──
		var level_label: Label = Label.new()
		level_label.text = "Lv %d" % pet_level
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row.add_child(level_label)

		# ── Buff summary ──
		var buff_label: Label = Label.new()
		buff_label.text = _format_buff(pet_def, pet_level)
		buff_label.add_theme_font_size_override("font_size", 13)
		buff_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		row.add_child(buff_label)

		# ── Summon / Active indicator ──
		if is_active:
			var active_label: Label = Label.new()
			active_label.text = "Active"
			active_label.add_theme_font_size_override("font_size", 13)
			active_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			active_label.custom_minimum_size = Vector2(50, 22)
			row.add_child(active_label)
		else:
			var summon_btn: Button = Button.new()
			summon_btn.text = "Summon"
			summon_btn.add_theme_font_size_override("font_size", 13)
			summon_btn.custom_minimum_size = Vector2(60, 22)
			summon_btn.pressed.connect(_on_summon.bind(pet_id_str))
			row.add_child(summon_btn)

		# Subtle separator
		var sep: HSeparator = HSeparator.new()
		sep.add_theme_constant_override("separation", 2)
		_list_container.add_child(sep)


# ── Signal callbacks ───────────────────────────────────────────────────────

## Close the panel and notify the event bus.
func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("pets")


## Summon a pet via the pet system, then refresh the panel.
func _on_summon(pet_id: String) -> void:
	var pet_system: Node = get_tree().get_first_node_in_group("pet_system")
	if pet_system == null:
		push_warning("PetPanel: No pet_system node found in scene tree.")
		return

	if pet_system.has_method("summon_pet"):
		pet_system.summon_pet(pet_id)

	refresh()


## Dismiss the current active pet via the pet system, then refresh.
func _on_dismiss() -> void:
	var pet_system: Node = get_tree().get_first_node_in_group("pet_system")
	if pet_system == null:
		push_warning("PetPanel: No pet_system node found in scene tree.")
		return

	if pet_system.has_method("dismiss_pet"):
		pet_system.dismiss_pet()

	refresh()


# ── Private helpers ────────────────────────────────────────────────────────

## Find a pet definition Dictionary from DataManager.pets by id.
## Returns an empty Dictionary if not found.
func _find_pet_def(pet_id: String) -> Dictionary:
	for pet in DataManager.pets:
		var entry: Dictionary = pet as Dictionary
		if str(entry.get("id", "")) == pet_id:
			return entry
	return {}


## Format the buff description for display, e.g. "+15 HP" or "+5% XP".
## Computes the total buff value based on base + (perLevel * (level - 1)).
func _format_buff(pet_def: Dictionary, pet_level: int) -> String:
	var buff: Dictionary = pet_def.get("buff", {}) as Dictionary
	var buff_type: String = str(buff.get("type", ""))
	var base_value: float = float(buff.get("baseValue", 0))
	var per_level: float = float(buff.get("perLevel", 0))
	var total_value: float = base_value + per_level * float(max(0, pet_level - 1))

	var format_str: String = BUFF_FORMATS.get(buff_type, "+%s ???")

	# Use percentage formatting for types that display as percentages
	if buff_type in ["speed", "xp", "gathering"]:
		var display_value: int = int(roundf(total_value * 100.0))
		return format_str % [str(display_value)]
	else:
		var display_value: int = int(roundf(total_value))
		return format_str % [str(display_value)]


## Calculate XP required to reach a given pet level. Simple quadratic curve:
## XP = 50 * level^2. Level 1 requires 0 XP.
func _xp_for_pet_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(50 * level * level)


## Determine the current evolution stage (1-based) based on pet level and
## the evolution thresholds array. Stage 1 is base form; each threshold
## crossed advances the stage by one.
func _get_evolution_stage(pet_level: int, evolution_levels: Array) -> int:
	var stage: int = 1
	for i in range(evolution_levels.size()):
		var threshold: int = int(evolution_levels[i])
		if pet_level >= threshold:
			stage = i + 2
	return stage
