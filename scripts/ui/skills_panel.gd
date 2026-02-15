## SkillsPanel — Shows all player skills with XP bars, levels, and descriptions
##
## Skills are grouped by category (Combat, Gathering, Production).
## Each skill shows: [Icon] Skill Name  Lv XX  [XP bar]
## Click a skill to see its guide (unlock milestones + description).
extends PanelContainer

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _skill_rows: Dictionary = {}  # { skill_id: { "level": Label, "xp_bar": ProgressBar, "xp_label": Label, "row": PanelContainer } }

# ── Guide view ──
var _main_vbox: VBoxContainer = null      # The main skill list container
var _guide_container: VBoxContainer = null # The guide view (shown on click)
var _active_guide_skill: String = ""       # Which skill guide is open

# Skill display order grouped by category
var _skill_groups: Array[Dictionary] = [
	{"label": "Combat", "color": Color(0.8, 0.3, 0.3), "skills": ["nano", "tesla", "void"]},
	{"label": "Gathering", "color": Color(0.8, 0.6, 0.3), "skills": ["astromining"]},
	{"label": "Production", "color": Color(0.3, 0.7, 0.5), "skills": ["bioforge", "circuitry", "xenocook"]},
]

func _ready() -> void:
	custom_minimum_size = Vector2(280, 340)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 3)
	add_child(_main_vbox)

	# Draggable header
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Skills", _on_close_pressed)
	_main_vbox.add_child(drag_header)

	var total_label: Label = Label.new()
	total_label.name = "TotalLevel"
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	_main_vbox.add_child(total_label)

	# Build grouped skill rows
	for group in _skill_groups:
		_add_group_header(_main_vbox, group["label"], group["color"])
		for skill_id in group["skills"]:
			if GameState.skills.has(skill_id):
				var row: Dictionary = _create_skill_row(_main_vbox, skill_id)
				_skill_rows[skill_id] = row

	# Connect signals
	EventBus.player_xp_gained.connect(_on_xp_gained)
	EventBus.player_level_up.connect(_on_level_up)

	refresh()

## Add a category header label (Combat, Gathering, Production)
func _add_group_header(parent: VBoxContainer, label_text: String, color: Color) -> void:
	var header: Label = Label.new()
	header.text = label_text
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", color.darkened(0.1))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_child(header)
	parent.add_child(margin)

## Create a single skill row (clickable)
func _create_skill_row(parent: VBoxContainer, skill_id: String) -> Dictionary:
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id.capitalize()))
	var skill_color: Color = _skill_color(skill_id)

	# Clickable button-like container
	var click_panel: PanelContainer = PanelContainer.new()
	var click_style: StyleBoxFlat = StyleBoxFlat.new()
	click_style.bg_color = Color(0.08, 0.1, 0.16, 0.6)
	click_style.set_corner_radius_all(3)
	click_style.set_content_margin_all(3)
	click_panel.add_theme_stylebox_override("panel", click_style)
	click_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(click_panel)

	# Hover effect
	var hover_style: StyleBoxFlat = click_style.duplicate()
	hover_style.bg_color = Color(0.12, 0.16, 0.24, 0.8)
	hover_style.border_color = skill_color.darkened(0.4)
	hover_style.set_border_width_all(1)

	click_panel.mouse_entered.connect(func():
		click_panel.add_theme_stylebox_override("panel", hover_style)
	)
	click_panel.mouse_exited.connect(func():
		click_panel.add_theme_stylebox_override("panel", click_style)
	)
	click_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_skill_guide(skill_id)
	)

	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	click_panel.add_child(row)

	# Name + Level row
	var name_row: HBoxContainer = HBoxContainer.new()
	row.add_child(name_row)

	var icon_label: Label = Label.new()
	icon_label.text = _skill_icon(skill_id)
	icon_label.add_theme_font_size_override("font_size", 13)
	name_row.add_child(icon_label)

	var name_label: Label = Label.new()
	name_label.text = " " + skill_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", skill_color)
	name_row.add_child(name_label)

	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_row.add_child(level_label)

	# Arrow hint
	var arrow: Label = Label.new()
	arrow.text = " >"
	arrow.add_theme_font_size_override("font_size", 11)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	name_row.add_child(arrow)

	# XP progress bar
	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.show_percentage = false

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	bg_style.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = skill_color.darkened(0.3)
	fill_style.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("fill", fill_style)

	row.add_child(xp_bar)

	# XP text
	var xp_label: Label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	row.add_child(xp_label)

	return {
		"level": level_label,
		"xp_bar": xp_bar,
		"xp_label": xp_label,
		"row": click_panel,
	}

## Show skill guide — replaces skill list with unlock milestones and description
func _show_skill_guide(skill_id: String) -> void:
	_active_guide_skill = skill_id
	_main_vbox.visible = false

	# Remove old guide if present
	if _guide_container and is_instance_valid(_guide_container):
		_guide_container.queue_free()

	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id.capitalize()))
	var skill_color: Color = _skill_color(skill_id)
	var skill_desc: String = str(skill_data.get("desc", ""))
	var skill_trains: String = str(skill_data.get("trains", ""))
	var skill_category: String = str(skill_data.get("category", ""))
	var skill_state: Dictionary = GameState.skills.get(skill_id, {})
	var current_level: int = int(skill_state.get("level", 1))

	_guide_container = VBoxContainer.new()
	_guide_container.add_theme_constant_override("separation", 4)
	add_child(_guide_container)

	# ── Header with back button ──
	var header: HBoxContainer = HBoxContainer.new()
	_guide_container.add_child(header)

	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.add_theme_font_size_override("font_size", 11)

	var back_style: StyleBoxFlat = StyleBoxFlat.new()
	back_style.bg_color = Color(0.12, 0.15, 0.22)
	back_style.set_corner_radius_all(3)
	back_style.set_content_margin_all(4)
	back_btn.add_theme_stylebox_override("normal", back_style)

	var back_hover: StyleBoxFlat = back_style.duplicate()
	back_hover.bg_color = Color(0.18, 0.22, 0.32)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	back_btn.pressed.connect(_close_skill_guide)
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  %s %s" % [_skill_icon(skill_id), skill_name]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", skill_color)
	header.add_child(title)

	# ── Category badge ──
	if skill_category != "":
		var cat_label: Label = Label.new()
		cat_label.text = skill_category
		cat_label.add_theme_font_size_override("font_size", 10)
		cat_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
		_guide_container.add_child(cat_label)

	# ── Skill description ──
	if skill_desc != "":
		var desc_label: Label = Label.new()
		desc_label.text = skill_desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_guide_container.add_child(desc_label)

	# ── How to train ──
	if skill_trains != "":
		var train_label: Label = Label.new()
		train_label.text = "Train: %s" % skill_trains
		train_label.add_theme_font_size_override("font_size", 10)
		train_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		train_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_guide_container.add_child(train_label)

	# ── Current level / XP summary ──
	var current_xp: int = int(skill_state.get("xp", 0))
	var next_xp: int = DataManager.xp_for_level(current_level + 1)
	var is_max: bool = current_level >= DataManager.MAX_SKILL_LEVEL

	var summary: Label = Label.new()
	if is_max:
		summary.text = "Level %d (MAX)  |  %s XP" % [current_level, _format_number(current_xp)]
	else:
		summary.text = "Level %d  |  %s / %s XP" % [current_level, _format_number(current_xp), _format_number(next_xp)]
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	_guide_container.add_child(summary)

	# ── Separator ──
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_guide_container.add_child(sep)

	# ── Unlock header ──
	var unlock_header: Label = Label.new()
	unlock_header.text = "Unlocks"
	unlock_header.add_theme_font_size_override("font_size", 12)
	unlock_header.add_theme_color_override("font_color", skill_color.lightened(0.1))
	_guide_container.add_child(unlock_header)

	# ── Scrollable unlock list ──
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_guide_container.add_child(scroll)

	var unlock_list: VBoxContainer = VBoxContainer.new()
	unlock_list.add_theme_constant_override("separation", 2)
	unlock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(unlock_list)

	# Get unlocks for this skill (filtered to max level cap)
	var all_unlocks: Array = DataManager.skill_unlocks.get(skill_id, [])
	var unlocks: Array = []
	for u in all_unlocks:
		if int(u.get("level", 1)) <= DataManager.MAX_SKILL_LEVEL:
			unlocks.append(u)

	if unlocks.is_empty():
		var no_data: Label = Label.new()
		no_data.text = "No unlock data available."
		no_data.add_theme_font_size_override("font_size", 11)
		no_data.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		unlock_list.add_child(no_data)
	else:
		for unlock in unlocks:
			var req_level: int = int(unlock.get("level", 1))
			var desc: String = str(unlock.get("desc", "???"))
			var is_unlocked: bool = current_level >= req_level

			var entry: HBoxContainer = HBoxContainer.new()
			unlock_list.add_child(entry)

			# Check/lock icon
			var status_icon: Label = Label.new()
			if is_unlocked:
				status_icon.text = "+"
				status_icon.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			else:
				status_icon.text = "-"
				status_icon.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
			status_icon.add_theme_font_size_override("font_size", 12)
			status_icon.custom_minimum_size.x = 16
			entry.add_child(status_icon)

			# Level badge
			var lvl_badge: Label = Label.new()
			lvl_badge.text = "Lv %d" % req_level
			lvl_badge.custom_minimum_size.x = 40
			lvl_badge.add_theme_font_size_override("font_size", 10)
			if is_unlocked:
				lvl_badge.add_theme_color_override("font_color", skill_color.darkened(0.1))
			else:
				lvl_badge.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			entry.add_child(lvl_badge)

			# Description
			var desc_label: Label = Label.new()
			desc_label.text = desc
			desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if is_unlocked:
				desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			else:
				desc_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
			entry.add_child(desc_label)

## Close skill guide, return to skill list
func _close_skill_guide() -> void:
	_active_guide_skill = ""
	if _guide_container and is_instance_valid(_guide_container):
		_guide_container.queue_free()
		_guide_container = null
	_main_vbox.visible = true
	refresh()

## Refresh all skill displays
func refresh() -> void:
	for skill_id in _skill_rows:
		var row: Dictionary = _skill_rows[skill_id]
		var skill_state: Dictionary = GameState.skills.get(skill_id, {})
		var level: int = int(skill_state.get("level", 1))
		var xp: int = int(skill_state.get("xp", 0))

		# Level text
		var is_max: bool = level >= DataManager.MAX_SKILL_LEVEL
		(row["level"] as Label).text = "Lv %d" % level

		# XP bar
		var current_xp: int = xp
		var next_level_xp: int = DataManager.xp_for_level(level + 1)
		var prev_level_xp: int = DataManager.xp_for_level(level) if level > 1 else 0

		var xp_bar: ProgressBar = row["xp_bar"] as ProgressBar
		if is_max or next_level_xp <= 0:
			xp_bar.min_value = 0
			xp_bar.max_value = 1
			xp_bar.value = 1  # Max level — full bar
		elif next_level_xp > prev_level_xp:
			xp_bar.min_value = 0
			xp_bar.max_value = next_level_xp - prev_level_xp
			xp_bar.value = current_xp - prev_level_xp
		else:
			xp_bar.min_value = 0
			xp_bar.max_value = 1
			xp_bar.value = 1

		# XP text
		if is_max:
			(row["xp_label"] as Label).text = "%s XP (MAX)" % _format_number(current_xp)
		else:
			(row["xp_label"] as Label).text = "%s / %s XP" % [
				_format_number(current_xp),
				_format_number(next_level_xp)
			]

	# Total level
	var total_lbl: Label = _main_vbox.get_node_or_null("TotalLevel") as Label
	if total_lbl:
		total_lbl.text = "Total Level: %d" % GameState.get_total_level()

func _on_xp_gained(_skill: String, _amount: int) -> void:
	refresh()

func _on_level_up(_skill: String, _new_level: int) -> void:
	refresh()

func _on_close_pressed() -> void:
	# If guide is open, close it first
	if _active_guide_skill != "":
		_close_skill_guide()
	visible = false
	EventBus.panel_closed.emit("skills")

## Color for each skill type
func _skill_color(skill_id: String) -> Color:
	match skill_id:
		"nano": return Color(0.2, 0.9, 0.4)     # Green
		"tesla": return Color(0.3, 0.6, 1.0)     # Blue
		"void": return Color(0.6, 0.2, 0.9)      # Purple
		"astromining": return Color(0.8, 0.6, 0.3) # Orange
		"bioforge": return Color(0.2, 0.8, 0.6)   # Teal
		"circuitry": return Color(0.2, 0.8, 0.8)  # Cyan
		"xenocook": return Color(0.9, 0.8, 0.2)   # Yellow
		_: return Color(0.6, 0.6, 0.6)

## Unicode icon for each skill
func _skill_icon(skill_id: String) -> String:
	match skill_id:
		"nano": return "N"
		"tesla": return "T"
		"void": return "V"
		"astromining": return "A"
		"bioforge": return "B"
		"circuitry": return "C"
		"xenocook": return "X"
		_: return "?"

## Format large numbers: 1000 → "1.0K", 1000000 → "1.0M"
func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
