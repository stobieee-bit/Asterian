## QuestPanel — Shows active quests and their step-by-step progress
##
## Lists every active quest from GameState.active_quests. Each quest displays its
## name, per-step progress (done/remaining), and a "Turn In" button when all
## objectives are met. Auto-refreshes on quest_accepted / quest_progress /
## quest_completed signals.
extends PanelContainer

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _scroll: ScrollContainer = null
var _quests_container: VBoxContainer = null
var _empty_label: Label = null


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

	_quests_container = VBoxContainer.new()
	_quests_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_container.add_theme_constant_override("separation", 6)
	_scroll.add_child(_quests_container)

	# ── Empty state label (hidden when quests exist) ──
	_empty_label = Label.new()
	_empty_label.text = "No active quests."
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quests_container.add_child(_empty_label)

	# ── Connect EventBus signals for live refresh ──
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_progress.connect(_on_quest_progress)
	EventBus.quest_completed.connect(_on_quest_completed)

	# Initial build
	refresh()


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Rebuild the entire quest list from GameState.active_quests.
func refresh() -> void:
	# Clear previous entries (keep _empty_label — we re-add it below)
	for child in _quests_container.get_children():
		child.queue_free()

	var quest_ids: Array = GameState.active_quests.keys()

	# Show the empty-state label when there are no active quests
	if quest_ids.is_empty():
		_empty_label = Label.new()
		_empty_label.text = "No active quests."
		_empty_label.add_theme_font_size_override("font_size", 12)
		_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quests_container.add_child(_empty_label)
		return

	# Build a card for each active quest
	for quest_id in quest_ids:
		var qid: String = str(quest_id)
		_build_quest_entry(qid)


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
	name_label.add_theme_font_size_override("font_size", 13)
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
		step_label.add_theme_font_size_override("font_size", 11)

		if done:
			# Completed step — green with checkmark
			step_label.text = "  ✓ %s (%d/%d)" % [desc, required, required]
			step_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			# Incomplete step — gray with circle
			step_label.text = "  ○ %s (%d/%d)" % [desc, current, required]
			step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		quest_box.add_child(step_label)

	# ── Turn In button (only when all steps are done) ──
	if completable:
		var turn_in_btn: Button = Button.new()
		turn_in_btn.text = "Turn In"
		turn_in_btn.add_theme_font_size_override("font_size", 11)
		turn_in_btn.custom_minimum_size = Vector2(70, 26)
		turn_in_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		turn_in_btn.pressed.connect(_on_turn_in.bind(quest_id))
		quest_box.add_child(turn_in_btn)

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


func _on_quest_accepted(_quest_id: String) -> void:
	refresh()


func _on_quest_progress(_quest_id: String, _step: int) -> void:
	refresh()


func _on_quest_completed(_quest_id: String) -> void:
	refresh()


func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("quests")
