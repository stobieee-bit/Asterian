## QuestPanel — Shows active quests, their step-by-step progress, and slayer tasks
##
## Lists every active quest from GameState.active_quests. Each quest displays its
## name, per-step progress (done/remaining), and a "Turn In" button when all
## objectives are met. Also shows the active slayer task with kill progress and
## streak info. Auto-refreshes on quest/slayer signals.
extends PanelContainer

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _scroll: ScrollContainer = null
var _quests_container: VBoxContainer = null
var _empty_label: Label = null

# ── Slayer section refs ──
var _slayer_separator: HSeparator = null
var _slayer_title: Label = null
var _slayer_target: Label = null
var _slayer_progress: Label = null
var _slayer_streak: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(320, 340)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Quests", _on_close)
	vbox.add_child(drag_header)

	# ── Scrollable quest list ──
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(300, 280)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var scroll_vbox: VBoxContainer = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(scroll_vbox)

	# Quest entries container
	_quests_container = VBoxContainer.new()
	_quests_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_container.add_theme_constant_override("separation", 6)
	scroll_vbox.add_child(_quests_container)

	# ── Empty state label (hidden when quests exist) ──
	_empty_label = Label.new()
	_empty_label.text = "No active quests."
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quests_container.add_child(_empty_label)

	# ── Slayer task section (below quests) ──
	_slayer_separator = HSeparator.new()
	_slayer_separator.add_theme_constant_override("separation", 6)
	_slayer_separator.visible = false
	scroll_vbox.add_child(_slayer_separator)

	_slayer_title = Label.new()
	_slayer_title.text = "Slayer Task"
	_slayer_title.add_theme_font_size_override("font_size", 15)
	_slayer_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_slayer_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_slayer_title.add_theme_constant_override("shadow_offset_x", 1)
	_slayer_title.add_theme_constant_override("shadow_offset_y", 1)
	_slayer_title.visible = false
	scroll_vbox.add_child(_slayer_title)

	_slayer_target = Label.new()
	_slayer_target.add_theme_font_size_override("font_size", 14)
	_slayer_target.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_slayer_target.visible = false
	scroll_vbox.add_child(_slayer_target)

	_slayer_progress = Label.new()
	_slayer_progress.add_theme_font_size_override("font_size", 14)
	_slayer_progress.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_slayer_progress.visible = false
	scroll_vbox.add_child(_slayer_progress)

	_slayer_streak = Label.new()
	_slayer_streak.add_theme_font_size_override("font_size", 12)
	_slayer_streak.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_slayer_streak.visible = false
	scroll_vbox.add_child(_slayer_streak)

	# ── Connect EventBus signals for live refresh ──
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_progress.connect(_on_quest_progress)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.chat_message.connect(_on_chat_message)

	# Initial build
	refresh()


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Rebuild the entire quest list and slayer section.
func refresh() -> void:
	# Clear previous quest entries
	for child in _quests_container.get_children():
		child.queue_free()

	var quest_ids: Array = GameState.active_quests.keys()

	# Show the empty-state label when there are no active quests
	if quest_ids.is_empty():
		_empty_label = Label.new()
		_empty_label.text = "No active quests."
		_empty_label.add_theme_font_size_override("font_size", 14)
		_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quests_container.add_child(_empty_label)
	else:
		# Build a card for each active quest
		for quest_id in quest_ids:
			var qid: String = str(quest_id)
			_build_quest_entry(qid)

	# Refresh the slayer section
	_refresh_slayer()


# ──────────────────────────────────────────────
#  Quest entry builder
# ──────────────────────────────────────────────

## Build the UI block for a single quest: name, step lines, optional Turn In button.
func _build_quest_entry(quest_id: String) -> void:
	# Use QuestSystem's helper for a clean progress snapshot
	var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
	if quest_sys == null:
		return

	var progress: Dictionary = quest_sys.get_quest_progress(quest_id)
	if progress.is_empty():
		return

	var quest_name: String = str(progress.get("name", quest_id))
	var steps: Array = progress.get("steps", [])
	var completable: bool = bool(progress.get("completable", false))

	# Container for this quest
	var quest_box: VBoxContainer = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 2)
	_quests_container.add_child(quest_box)

	# ── Quest name ──
	var name_label: Label = Label.new()
	name_label.text = quest_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	quest_box.add_child(name_label)

	# ── Step lines ──
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var desc: String = str(step.get("desc", ""))
		var current: int = int(step.get("current", 0))
		var required: int = int(step.get("required", 1))
		var done: bool = bool(step.get("done", false))

		# Strip existing "(x/y)" from JSON desc to avoid duplication
		var paren_idx: int = desc.rfind(" (")
		if paren_idx >= 0 and desc.ends_with(")"):
			desc = desc.substr(0, paren_idx)

		var step_label: Label = Label.new()
		step_label.add_theme_font_size_override("font_size", 14)

		if done:
			# Completed step — green with checkmark
			step_label.text = "  ✓ %s (%d/%d)" % [desc, required, required]
			step_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			# Incomplete step — gray with circle
			step_label.text = "  ○ %s (%d/%d)" % [desc, current, required]
			step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		quest_box.add_child(step_label)

	# ── Button row ──
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	quest_box.add_child(btn_row)

	# Turn In button (only when all steps are done)
	if completable:
		var turn_in_btn: Button = Button.new()
		turn_in_btn.text = "Turn In"
		turn_in_btn.add_theme_font_size_override("font_size", 14)
		turn_in_btn.custom_minimum_size = Vector2(70, 26)
		turn_in_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		turn_in_btn.pressed.connect(_on_turn_in.bind(quest_id))
		btn_row.add_child(turn_in_btn)

	# Abandon button — always available for active quests
	var abandon_btn: Button = Button.new()
	abandon_btn.text = "Abandon"
	abandon_btn.add_theme_font_size_override("font_size", 13)
	abandon_btn.custom_minimum_size = Vector2(70, 26)
	abandon_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	abandon_btn.pressed.connect(_on_abandon.bind(quest_id))
	btn_row.add_child(abandon_btn)

	# Separator between quests
	var sep: HSeparator = HSeparator.new()
	_quests_container.add_child(sep)


# ──────────────────────────────────────────────
#  Callbacks
# ──────────────────────────────────────────────

## Turn in a completed quest via the QuestSystem.
func _on_turn_in(quest_id: String) -> void:
	var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
	if quest_sys == null:
		push_warning("QuestPanel: No quest_system node found in scene tree.")
		return

	if quest_sys.has_method("complete_quest"):
		quest_sys.complete_quest(quest_id)

	# Rebuild after completion (quest will have moved to completed_quests)
	refresh()


## Abandon an active quest via the QuestSystem.
func _on_abandon(quest_id: String) -> void:
	var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
	if quest_sys == null:
		push_warning("QuestPanel: No quest_system node found in scene tree.")
		return

	if quest_sys.has_method("abandon_quest"):
		quest_sys.abandon_quest(quest_id)

	# Rebuild after abandonment
	refresh()


func _on_quest_accepted(_quest_id: String) -> void:
	refresh()


func _on_quest_progress(_quest_id: String, _step: int) -> void:
	refresh()


func _on_quest_completed(_quest_id: String) -> void:
	refresh()


func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("quests")


func _on_enemy_killed(_eid: String, _etype: String) -> void:
	_refresh_slayer()


func _on_chat_message(_text: String, channel: String) -> void:
	if channel == "slayer":
		_refresh_slayer()


# ──────────────────────────────────────────────
#  Slayer task display
# ──────────────────────────────────────────────

## Update the slayer section visibility and content.
func _refresh_slayer() -> void:
	var has_slayer: bool = false
	var task: Dictionary = GameState.slayer_task
	if not task.is_empty() and task.has("remaining"):
		var remaining: int = int(task.get("remaining", 0))
		if remaining > 0:
			has_slayer = true
			var count: int = int(task.get("count", 0))
			var enemy_type: String = str(task.get("enemy_type", ""))
			var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
			var enemy_name: String = str(enemy_data.get("name", enemy_type))
			var area_name: String = str(task.get("area", "")).replace("-", " ").capitalize()

			if _slayer_target:
				_slayer_target.text = "  Kill %s" % enemy_name
			if _slayer_progress:
				_slayer_progress.text = "  %d / %d" % [count - remaining, count]
			if _slayer_streak:
				_slayer_streak.text = "  Streak: %d  |  %s" % [GameState.slayer_streak, area_name]

	var has_quests: bool = not GameState.active_quests.is_empty()

	if _slayer_separator:
		_slayer_separator.visible = has_slayer and has_quests
	if _slayer_title:
		_slayer_title.visible = has_slayer
	if _slayer_target:
		_slayer_target.visible = has_slayer
	if _slayer_progress:
		_slayer_progress.visible = has_slayer
	if _slayer_streak:
		_slayer_streak.visible = has_slayer
