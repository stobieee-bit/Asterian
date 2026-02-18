## TutorialPanel — Step-by-step onboarding guide for new players
##
## Shows tutorial steps that advance when the player performs each action.
## Persists progress via GameState.tutorial dictionary.
## Can be closed and reopened without skipping; "Skip Tutorial" ends it.
extends PanelContainer

# ── Step definitions ──────────────────────────────────────────────────
# Each step: id, title, text (BBCode), hint_key, detect_mode, completion_signal, completion_args
const STEPS: Array[Dictionary] = [
	{
		"id": "move",
		"title": "Movement",
		"text": "Welcome to [color=#66cccc]Asterian[/color]!\n\n[color=#66cccc]Left-click[/color] on the ground to move your character.\nTry walking around the Station Hub.",
		"hint_key": "Left-click on ground",
		"detect_mode": "poll",
	},
	{
		"id": "camera",
		"title": "Camera Controls",
		"text": "Use the [color=#66cccc]scroll wheel[/color] to zoom in and out.\n\n[color=#66cccc]Hold middle mouse button and drag[/color] to rotate the camera around your character.",
		"hint_key": "Scroll = Zoom  |  Middle-click drag = Rotate",
		"detect_mode": "poll",
	},
	{
		"id": "combat",
		"title": "Combat",
		"text": "Find a nearby enemy and [color=#66cccc]left-click[/color] it to start attacking.\n\nYour character will auto-attack once in range. Defeat it to continue!",
		"hint_key": "Left-click an enemy",
		"detect_mode": "signal",
		"completion_signal": "enemy_killed",
	},
	{
		"id": "loot",
		"title": "Picking Up Loot",
		"text": "Enemies drop items on the ground when defeated.\n\n[color=#66cccc]Left-click[/color] a glowing ground item to pick it up.",
		"hint_key": "Left-click ground item",
		"detect_mode": "signal",
		"completion_signal": "item_added",
	},
	{
		"id": "inventory",
		"title": "Inventory",
		"text": "Press [color=#66cccc]I[/color] to open your inventory.\n\nHere you can see all items you're carrying. Right-click items for options.",
		"hint_key": "Press  I",
		"detect_mode": "signal",
		"completion_signal": "panel_opened",
		"completion_args": { "0": "inventory" },
	},
	{
		"id": "equipment",
		"title": "Equipment",
		"text": "Press [color=#66cccc]E[/color] to open your equipment panel.\n\nRight-click a weapon or armor in your inventory to equip it and boost your stats.",
		"hint_key": "Press  E  →  Right-click item to equip",
		"detect_mode": "signal",
		"completion_signal": "item_equipped",
	},
	{
		"id": "skills",
		"title": "Skills & Leveling",
		"text": "Press [color=#66cccc]K[/color] to view your skills.\n\nYou have 8 skills that level up as you fight, gather, and craft. Higher levels unlock new content.",
		"hint_key": "Press  K",
		"detect_mode": "signal",
		"completion_signal": "panel_opened",
		"completion_args": { "0": "skills" },
	},
	{
		"id": "abilities",
		"title": "Abilities",
		"text": "During combat, press [color=#66cccc]1-5[/color] to use special abilities.\n\nAbilities cost energy and deal extra damage. They queue up automatically!",
		"hint_key": "Press  1 - 5  during combat",
		"detect_mode": "signal",
		"completion_signal": "player_attacked",
	},
	{
		"id": "food",
		"title": "Healing",
		"text": "Press [color=#66cccc]F[/color] to eat food and restore HP.\n\nYou start with Lichen Wraps in your inventory. Keep food handy for tough fights!",
		"hint_key": "Press  F",
		"detect_mode": "signal",
		"completion_signal": "player_healed",
	},
	{
		"id": "gathering",
		"title": "Gathering Resources",
		"text": "Find a glowing [color=#66cccc]resource node[/color] in the world and left-click it to gather materials.\n\nOre, plants, and other resources are scattered around each area.",
		"hint_key": "Left-click a resource node",
		"detect_mode": "signal",
		"completion_signal": "gathering_complete",
	},
	{
		"id": "npc_talk",
		"title": "NPC Interaction",
		"text": "[color=#66cccc]Right-click[/color] an NPC to see interaction options.\n\nNPCs offer quests, shops, banking, and useful information.",
		"hint_key": "Right-click an NPC",
		"detect_mode": "signal",
		"completion_signal": "panel_opened",
		"completion_args": { "0": "dialogue" },
	},
	{
		"id": "quest",
		"title": "Quests",
		"text": "Talk to NPCs to accept quests. Press [color=#66cccc]Q[/color] to view the quest log.\n\nQuests reward XP, credits, and items. Follow the quest steps to complete them.",
		"hint_key": "Press  Q",
		"detect_mode": "signal",
		"completion_signal": "panel_opened",
		"completion_args": { "0": "quests" },
	},
	{
		"id": "complete",
		"title": "Tutorial Complete!",
		"text": "You've learned the basics of Asterian!\n\nThere's much more to discover:\n• [color=#66cccc]Slayer tasks[/color] — talk to the Slayer Master\n• [color=#66cccc]Dungeons[/color] — press N\n• [color=#66cccc]Crafting[/color] — use processing stations\n• [color=#66cccc]Pets[/color], [color=#66cccc]Prestige[/color], and more!",
		"hint_key": "",
		"detect_mode": "manual",
	},
]

# ── Node refs ─────────────────────────────────────────────────────────
var _vbox: VBoxContainer = null
var _step_number_label: Label = null
var _title_label: Label = null
var _text_label: RichTextLabel = null
var _hint_label: Label = null
var _progress_label: Label = null
var _progress_bar: ProgressBar = null
var _skip_btn: Button = null
var _next_btn: Button = null
var _drag_header: DraggableHeader = null

# ── State ─────────────────────────────────────────────────────────────
var _current_step: int = 0
var _step_completed: bool = false
var _poll_active: bool = false
var _pulse_phase: float = 0.0
var _spawn_pos: Vector3 = Vector3(0, 1, 0)
var _initial_cam_distance: float = -1.0
var _initial_cam_angle: float = 0.0
var _current_signal_name: String = ""
var _current_signal_callable: Callable = Callable()

# ── Guideline step count (excludes the "complete" final screen) ──
var _guided_step_count: int = STEPS.size() - 1


func _ready() -> void:
	custom_minimum_size = Vector2(360, 200)
	z_index = 80
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	# ── Draggable header ──
	_drag_header = DraggableHeader.attach(self, "Tutorial", _on_close)
	_drag_header.name = "DragHeader"
	_vbox.add_child(_drag_header)

	# ── Step number + title row ──
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(title_row)

	_step_number_label = Label.new()
	_step_number_label.add_theme_font_size_override("font_size", 14)
	_step_number_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9, 0.9))
	title_row.add_child(_step_number_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	title_row.add_child(_title_label)

	# ── Instruction text ──
	_text_label = RichTextLabel.new()
	_text_label.custom_minimum_size = Vector2(340, 60)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_color_override("default_color", Color(0.78, 0.82, 0.78))
	_text_label.add_theme_font_size_override("normal_font_size", 14)
	_vbox.add_child(_text_label)

	# ── Hint label ──
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.6, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vbox.add_child(_hint_label)

	# ── Separator ──
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	_vbox.add_child(sep)

	# ── Progress row ──
	var progress_row: HBoxContainer = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(progress_row)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.6, 0.7))
	progress_row.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(140, 10)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.show_percentage = false
	_progress_bar.max_value = _guided_step_count
	_progress_bar.value = 0
	# Style the progress bar
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.08, 0.12, 0.8)
	bar_bg.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.6, 0.8, 0.9)
	bar_fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	progress_row.add_child(_progress_bar)

	# ── Button row ──
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row)

	_skip_btn = _make_button("Skip Tutorial", Color(0.5, 0.4, 0.4, 0.6), _on_skip_pressed)
	btn_row.add_child(_skip_btn)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	_next_btn = _make_button("Next  ->", Color(0.3, 0.7, 0.9, 0.9), _on_next_pressed)
	btn_row.add_child(_next_btn)


## Start or resume the tutorial
func start_tutorial() -> void:
	_current_step = int(GameState.tutorial.get("current_step", 0))

	# Skip any already-completed steps
	while _current_step < STEPS.size():
		var step_id: String = STEPS[_current_step]["id"]
		var steps_done: Array = GameState.tutorial.get("steps_done", [])
		if step_id in steps_done:
			_current_step += 1
		else:
			break

	if _current_step >= STEPS.size():
		_finish_tutorial()
		return

	visible = true
	_show_step(_current_step)


## Refresh (convention for panels — called by toggle)
func refresh() -> void:
	if visible and _current_step < STEPS.size():
		_show_step(_current_step)


func _process(delta: float) -> void:
	if not visible:
		return

	# Pulse border
	_pulse_phase += delta * 2.5
	var panel_style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		var alpha: float = 0.35 + sin(_pulse_phase) * 0.2
		panel_style.border_color = Color(0.2, 0.55, 0.75, alpha)

	# Poll-based detection
	if _poll_active and not _step_completed and _current_step < STEPS.size():
		var step: Dictionary = STEPS[_current_step]
		var step_id: String = step["id"]
		var completed: bool = false

		if step_id == "move":
			completed = _check_player_moved()
		elif step_id == "camera":
			completed = _check_camera_changed()

		if completed:
			_on_step_completed()


# ── Step display ──────────────────────────────────────────────────────

func _show_step(index: int) -> void:
	if index < 0 or index >= STEPS.size():
		return

	_current_step = index
	_step_completed = false
	_poll_active = false

	# Disconnect any previous signal
	_disconnect_signal()

	var step: Dictionary = STEPS[index]
	var is_final: bool = step["id"] == "complete"

	# Update UI
	if is_final:
		_step_number_label.text = "[*]"
	else:
		_step_number_label.text = "(%d)" % (index + 1)
	_title_label.text = step["title"]
	_text_label.text = step["text"]
	_hint_label.text = step.get("hint_key", "")
	_hint_label.visible = step.get("hint_key", "") != ""

	# Progress
	var done_count: int = mini(index, _guided_step_count)
	_progress_label.text = "Step %d of %d" % [mini(index + 1, _guided_step_count), _guided_step_count]
	_progress_bar.value = done_count

	# Buttons
	if is_final:
		_skip_btn.visible = false
		_next_btn.text = "Finish"
		_next_btn.disabled = false
		_set_btn_color(_next_btn, Color(0.3, 0.8, 0.5, 0.9))
		_step_completed = true
	else:
		_skip_btn.visible = true
		_next_btn.text = "Next  ->"
		_next_btn.disabled = true
		_set_btn_color(_next_btn, Color(0.3, 0.4, 0.5, 0.4))

	# Set up completion detection
	var detect: String = step.get("detect_mode", "manual")
	if detect == "poll":
		_poll_active = true
		# Capture initial state for camera detection
		if step["id"] == "camera":
			_capture_camera_initial()
	elif detect == "signal":
		_connect_step_signal(step)

	# Save current step
	GameState.tutorial["current_step"] = _current_step


# ── Completion handling ───────────────────────────────────────────────

func _on_step_completed() -> void:
	if _step_completed:
		return
	_step_completed = true
	_poll_active = false

	# Record in GameState
	var step_id: String = STEPS[_current_step]["id"]
	var steps_done: Array = GameState.tutorial.get("steps_done", [])
	if step_id not in steps_done:
		steps_done.append(step_id)
		GameState.tutorial["steps_done"] = steps_done

	# Disconnect signal listener
	_disconnect_signal()

	# Enable Next button with cyan highlight
	_next_btn.disabled = false
	_set_btn_color(_next_btn, Color(0.3, 0.75, 0.95, 0.95))
	_next_btn.text = "Next  ->  [x]"

	# Emit for other systems
	EventBus.tutorial_step_completed.emit(step_id)

	# Chat feedback
	EventBus.chat_message.emit("Tutorial: %s — complete!" % STEPS[_current_step]["title"], "system")


func _on_next_pressed() -> void:
	if not _step_completed:
		return

	var step: Dictionary = STEPS[_current_step]
	if step["id"] == "complete":
		_finish_tutorial()
		return

	# Advance to next step, skipping any already-done steps
	_current_step += 1
	while _current_step < STEPS.size():
		var sid: String = STEPS[_current_step]["id"]
		var steps_done: Array = GameState.tutorial.get("steps_done", [])
		if sid in steps_done and sid != "complete":
			_current_step += 1
		else:
			break

	if _current_step >= STEPS.size():
		_finish_tutorial()
	else:
		# If the next step is the "complete" screen, just finish directly
		if STEPS[_current_step]["id"] == "complete":
			_finish_tutorial()
		else:
			_show_step(_current_step)


func _on_skip_pressed() -> void:
	GameState.tutorial["completed"] = true
	GameState.tutorial["skipped"] = true
	visible = false
	_disconnect_signal()
	_poll_active = false
	EventBus.tutorial_skipped.emit()
	EventBus.chat_message.emit("Tutorial skipped. Click the ? button to reopen anytime.", "system")


func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("tutorial")


func _finish_tutorial() -> void:
	GameState.tutorial["completed"] = true
	visible = false
	_disconnect_signal()
	_poll_active = false
	EventBus.tutorial_completed.emit()
	EventBus.chat_message.emit("Tutorial complete! Enjoy exploring Asterian.", "system")


# ── Signal-based completion ───────────────────────────────────────────

func _connect_step_signal(step: Dictionary) -> void:
	var sig_name: String = step.get("completion_signal", "")
	if sig_name == "":
		return

	var args_filter: Dictionary = step.get("completion_args", {})

	# Build a callable that checks signal args
	if args_filter.is_empty():
		# No filter — any emission completes the step
		_current_signal_callable = func(_a1 = null, _a2 = null, _a3 = null) -> void:
			_on_step_completed()
	else:
		# Filter on first argument (e.g., panel_name)
		var expected: String = str(args_filter.get("0", ""))
		_current_signal_callable = func(arg1 = null, _a2 = null, _a3 = null) -> void:
			if str(arg1) == expected:
				_on_step_completed()

	_current_signal_name = sig_name

	# Connect to the matching EventBus signal
	if EventBus.has_signal(sig_name):
		EventBus.connect(sig_name, _current_signal_callable)


func _disconnect_signal() -> void:
	if _current_signal_name != "" and _current_signal_callable.is_valid():
		if EventBus.has_signal(_current_signal_name):
			if EventBus.is_connected(_current_signal_name, _current_signal_callable):
				EventBus.disconnect(_current_signal_name, _current_signal_callable)
	_current_signal_name = ""
	_current_signal_callable = Callable()


# ── Poll-based completion ─────────────────────────────────────────────

func _check_player_moved() -> bool:
	var player: Node3D = _find_player()
	if player and player.global_position.distance_to(_spawn_pos) > 3.0:
		return true
	return false


func _check_camera_changed() -> bool:
	var player: Node3D = _find_player()
	if player == null:
		return false
	var camera_rig: Node = player.get_node_or_null("CameraRig")
	if camera_rig == null:
		return false
	# Check if orbit angle or distance changed from initial
	var cur_dist: float = camera_rig.get("_distance") if camera_rig.get("_distance") != null else 0.0
	var cur_angle: float = camera_rig.get("_orbit_angle") if camera_rig.get("_orbit_angle") != null else 0.0
	if _initial_cam_distance < 0:
		_capture_camera_initial()
		return false
	if absf(cur_dist - _initial_cam_distance) > 1.0 or absf(cur_angle - _initial_cam_angle) > 0.15:
		return true
	return false


func _capture_camera_initial() -> void:
	var player: Node3D = _find_player()
	if player:
		var camera_rig: Node = player.get_node_or_null("CameraRig")
		if camera_rig:
			_initial_cam_distance = camera_rig.get("_distance") if camera_rig.get("_distance") != null else 15.0
			_initial_cam_angle = camera_rig.get("_orbit_angle") if camera_rig.get("_orbit_angle") != null else 0.0


func _find_player() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null


# ── UI helpers ────────────────────────────────────────────────────────

func _make_button(text: String, color: Color, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", color)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.06, 0.09, 0.14, 0.8)
	btn_style.border_color = Color(color.r, color.g, color.b, 0.3)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style: StyleBoxFlat = btn_style.duplicate()
	hover_style.bg_color = Color(0.1, 0.15, 0.22, 0.9)
	hover_style.border_color = Color(color.r, color.g, color.b, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)

	var disabled_style: StyleBoxFlat = btn_style.duplicate()
	disabled_style.bg_color = Color(0.04, 0.06, 0.1, 0.5)
	disabled_style.border_color = Color(0.15, 0.2, 0.25, 0.2)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.35, 0.4, 0.4))

	btn.pressed.connect(callback)
	return btn


func _set_btn_color(btn: Button, color: Color) -> void:
	btn.add_theme_color_override("font_color", color)
	var normal_style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
	if normal_style:
		normal_style.border_color = Color(color.r, color.g, color.b, 0.4)
	var hover_style: StyleBoxFlat = btn.get_theme_stylebox("hover") as StyleBoxFlat
	if hover_style:
		hover_style.border_color = Color(color.r, color.g, color.b, 0.7)
