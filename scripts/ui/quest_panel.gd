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
var _slayer_location: HBoxContainer = null
var _slayer_location_label: Label = null
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

	_slayer_location = HBoxContainer.new()
	_slayer_location.add_theme_constant_override("separation", 3)
	_slayer_location.visible = false
	scroll_vbox.add_child(_slayer_location)

	var _loc_spacer: Control = Control.new()
	_loc_spacer.custom_minimum_size = Vector2(8, 0)
	_slayer_location.add_child(_loc_spacer)

	var _loc_pin: TextureRect = TextureRect.new()
	_loc_pin.custom_minimum_size = Vector2(12, 12)
	_loc_pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loc_pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_loc_pin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_loc_pin.texture = ItemIcons.get_misc_texture("location_pin")
	_slayer_location.add_child(_loc_pin)

	_slayer_location_label = Label.new()
	_slayer_location_label.add_theme_font_size_override("font_size", 12)
	_slayer_location_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_slayer_location.add_child(_slayer_location_label)

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

	# Refresh when panel becomes visible (updates turn-in proximity check)
	visibility_changed.connect(_on_visibility_changed)

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
			step_label.text = "  [x] %s (%d/%d)" % [desc, required, required]
			step_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			# Incomplete step — gray
			step_label.text = "  [ ] %s (%d/%d)" % [desc, current, required]
			step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		quest_box.add_child(step_label)

	# ── Button row ──
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	quest_box.add_child(btn_row)

	# Turn In button (only when all steps are done AND player is near the quest giver)
	if completable:
		var turn_in_btn: Button = Button.new()
		turn_in_btn.add_theme_font_size_override("font_size", 14)
		turn_in_btn.custom_minimum_size = Vector2(70, 26)

		var near_giver: bool = _is_player_near_quest_giver(quest_id)
		if near_giver:
			turn_in_btn.text = "Turn In"
			turn_in_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			turn_in_btn.pressed.connect(_on_turn_in.bind(quest_id))
		else:
			var giver_name: String = _get_quest_giver_name(quest_id)
			turn_in_btn.text = "Turn In"
			turn_in_btn.disabled = true
			turn_in_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			turn_in_btn.tooltip_text = "Return to %s to turn in" % giver_name
		btn_row.add_child(turn_in_btn)

	# Hint: tell player to return to the quest giver when quest is completable but far away
	if completable and not _is_player_near_quest_giver(quest_id):
		var hint_label: Label = Label.new()
		hint_label.text = "  ↩ Return to %s" % _get_quest_giver_name(quest_id)
		hint_label.add_theme_font_size_override("font_size", 12)
		hint_label.add_theme_color_override("font_color", Color(0.8, 0.65, 0.3, 0.8))
		quest_box.add_child(hint_label)

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
#  Quest giver proximity check
# ──────────────────────────────────────────────

## How close the player must be to the quest giver NPC to turn in (world units).
const TURN_IN_DISTANCE: float = 12.0

## Check if the player is within turn-in range of the quest's giver NPC.
func _is_player_near_quest_giver(quest_id: String) -> bool:
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	var giver_id: String = str(quest_data.get("giver", ""))
	if giver_id.is_empty():
		return true  # No giver defined — allow turn-in anywhere

	var npc_data: Dictionary = DataManager.npcs.get(giver_id, {})
	if npc_data.is_empty():
		return true  # NPC data missing — fallback to allowing

	var npc_pos_data: Dictionary = npc_data.get("position", {})
	var npc_x: float = float(npc_pos_data.get("x", 0))
	var npc_z: float = float(npc_pos_data.get("z", 0))

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false

	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	var dist_sq: float = (px - npc_x) * (px - npc_x) + (pz - npc_z) * (pz - npc_z)
	return dist_sq <= TURN_IN_DISTANCE * TURN_IN_DISTANCE


## Get the display name of the quest giver NPC.
func _get_quest_giver_name(quest_id: String) -> String:
	var quest_data: Dictionary = DataManager.get_quest(quest_id)
	var giver_id: String = str(quest_data.get("giver", ""))
	if giver_id.is_empty():
		return "the quest giver"
	var npc_data: Dictionary = DataManager.npcs.get(giver_id, {})
	return str(npc_data.get("name", giver_id.replace("_", " ").capitalize()))


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


func _on_visibility_changed() -> void:
	if visible:
		refresh()


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

			# Build location: zone + area
			var enemy_level: int = int(enemy_data.get("level", 0))
			var enemy_area: String = str(task.get("area", ""))
			var zone_name: String = _find_zone_name(enemy_area, enemy_level)
			var location_text: String
			if zone_name != "":
				location_text = "%s, %s" % [zone_name, area_name]
			else:
				location_text = area_name
			if _slayer_location_label:
				_slayer_location_label.text = location_text

			if _slayer_streak:
				_slayer_streak.text = "  Streak: %d" % GameState.slayer_streak

	var has_quests: bool = not GameState.active_quests.is_empty()

	if _slayer_separator:
		_slayer_separator.visible = has_slayer and has_quests
	if _slayer_title:
		_slayer_title.visible = has_slayer
	if _slayer_target:
		_slayer_target.visible = has_slayer
	if _slayer_progress:
		_slayer_progress.visible = has_slayer
	if _slayer_location:
		_slayer_location.visible = has_slayer
	if _slayer_streak:
		_slayer_streak.visible = has_slayer

## Find the sub-zone name for an enemy based on its area and level
func _find_zone_name(enemy_area: String, enemy_level: int) -> String:
	var best_name: String = ""
	var best_range: int = 9999
	for zone in DataManager.enemy_sub_zones:
		var z_area: String = str(zone.get("area", ""))
		if z_area != enemy_area:
			continue
		var z_min: int = int(zone.get("levelMin", 0))
		var z_max: int = int(zone.get("levelMax", 0))
		if enemy_level >= z_min and enemy_level <= z_max:
			var range_span: int = z_max - z_min
			if range_span < best_range:
				best_range = range_span
				best_name = str(zone.get("name", ""))
	return best_name
