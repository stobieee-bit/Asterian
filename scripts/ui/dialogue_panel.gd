## DialoguePanel — Shows NPC dialogue with clickable response options
##
## Opens when player talks to an NPC. Shows NPC name, dialogue text,
## and a list of response buttons. Supports dialogue tree navigation.
extends PanelContainer

const NPC_ACTION_RANGE: float = 5.0

# ── State ──
var _current_npc: Node = null
var _current_node_key: String = "greeting"

# ── Node refs ──
var _npc_name_label: Label = null
var _portrait_rect: ColorRect = null
var _portrait_label: Label = null
var _text_label: RichTextLabel = null
var _options_container: VBoxContainer = null
var _close_btn: Button = null

func _ready() -> void:
	custom_minimum_size = Vector2(420, 220)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Draggable header (NPC name updates dynamically)
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "", _on_close)
	drag_header.name = "DragHeader"
	vbox.add_child(drag_header)
	_npc_name_label = drag_header._title_label

	# Content row: portrait + dialogue text
	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 8)
	vbox.add_child(content_row)

	# NPC portrait (colored box with initial)
	var portrait_container: PanelContainer = PanelContainer.new()
	portrait_container.custom_minimum_size = Vector2(56, 56)
	var port_style: StyleBoxFlat = StyleBoxFlat.new()
	port_style.bg_color = Color(0.08, 0.12, 0.2, 0.9)
	port_style.border_color = Color(0.2, 0.5, 0.7, 0.6)
	port_style.set_border_width_all(1)
	port_style.set_corner_radius_all(4)
	portrait_container.add_theme_stylebox_override("panel", port_style)
	content_row.add_child(portrait_container)

	_portrait_rect = ColorRect.new()
	_portrait_rect.color = Color(0.15, 0.3, 0.5, 0.5)
	_portrait_rect.custom_minimum_size = Vector2(56, 56)
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.add_child(_portrait_rect)

	_portrait_label = Label.new()
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 28)
	_portrait_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	_portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.add_child(_portrait_label)

	# Dialogue text
	_text_label = RichTextLabel.new()
	_text_label.custom_minimum_size = Vector2(340, 80)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.add_theme_color_override("default_color", Color(0.8, 0.85, 0.8))
	_text_label.add_theme_font_size_override("normal_font_size", 13)
	content_row.add_child(_text_label)

	# Options
	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 3)
	vbox.add_child(_options_container)

	visible = false
	z_index = 50

## Open dialogue with an NPC
func open_dialogue(npc: Node) -> void:
	_current_npc = npc
	_current_node_key = "greeting"
	_npc_name_label.text = npc.npc_name

	# Set portrait initial
	if _portrait_label:
		var npc_name: String = str(npc.npc_name)
		_portrait_label.text = npc_name[0] if npc_name.length() > 0 else "?"

	# Set portrait color based on NPC role (subtle hint)
	if _portrait_rect:
		var npc_id: String = str(npc.npc_id) if "npc_id" in npc else ""
		_portrait_rect.color = _npc_portrait_color(npc_id)

	_show_dialogue_node("greeting")
	visible = true
	EventBus.panel_opened.emit("dialogue")

## Display a dialogue node
func _show_dialogue_node(key: String) -> void:
	if _current_npc == null:
		return

	var node: Dictionary = _current_npc.get_dialogue_node(key)
	if node.is_empty():
		_on_close()
		return

	var text: String = str(node.get("text", "..."))

	# Handle dynamic text placeholders
	if text.begins_with("__") and text.ends_with("__"):
		text = _resolve_dynamic_text(text)

	_text_label.text = text

	# Clear old options
	for child in _options_container.get_children():
		child.queue_free()

	# Create option buttons
	var options: Array = node.get("options", [])

	# If no options provided (dynamic text), add dynamic options or default close
	if options.is_empty():
		var dynamic_options: Array = _get_dynamic_options(key)
		if dynamic_options.is_empty():
			var btn: Button = Button.new()
			btn.text = "Continue"
			btn.add_theme_font_size_override("font_size", 12)
			btn.pressed.connect(_on_close)
			_options_container.add_child(btn)
		else:
			for dopt in dynamic_options:
				var dlabel: String = str(dopt.get("label", "..."))
				var daction: String = str(dopt.get("action", ""))
				var dbtn: Button = Button.new()
				dbtn.text = dlabel
				dbtn.add_theme_font_size_override("font_size", 12)
				dbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				if daction != "":
					dbtn.pressed.connect(_on_action.bind(daction))
				else:
					dbtn.pressed.connect(_on_close)
				_options_container.add_child(dbtn)
		return

	for opt in options:
		var label_text: String = str(opt.get("label", "..."))
		var next_key: Variant = opt.get("next", null)
		var action: String = str(opt.get("action", ""))

		var btn: Button = Button.new()
		btn.text = label_text
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if action != "":
			btn.pressed.connect(_on_action.bind(action))
		elif next_key == null or str(next_key) == "null" or str(next_key) == "":
			btn.pressed.connect(_on_close)
		else:
			btn.pressed.connect(_on_navigate.bind(str(next_key)))

		_options_container.add_child(btn)

## Navigate to another dialogue node
func _on_navigate(key: String) -> void:
	_current_node_key = key
	_show_dialogue_node(key)

## Handle an action option
func _on_action(action: String) -> void:
	# All NPC-dependent actions require proximity
	if not _is_npc_in_range():
		EventBus.chat_message.emit("You need to move closer.", "system")
		_on_close()
		return

	# Handle parameterized actions (e.g., "acceptQuest:first_blood")
	if action.begins_with("acceptQuest:"):
		var quest_id: String = action.substr(12)
		var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
		if quest_sys and quest_sys.has_method("accept_quest"):
			quest_sys.accept_quest(quest_id)
		_on_close()
		return

	if action.begins_with("completeQuest:"):
		var quest_id: String = action.substr(14)
		var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
		if quest_sys and quest_sys.has_method("complete_quest"):
			quest_sys.complete_quest(quest_id)
		_on_close()
		return

	if action == "assignSlayer":
		var slayer_sys: Node = get_tree().get_first_node_in_group("slayer_system")
		if slayer_sys and slayer_sys.has_method("assign_task"):
			slayer_sys.assign_task()
		_on_close()
		return

	match action:
		"openShop":
			# Save NPC ref BEFORE closing (close nulls _current_npc)
			var shop_npc: Node = _current_npc
			_on_close()
			if shop_npc and is_instance_valid(shop_npc) and shop_npc.has_method("has_shop") and shop_npc.has_shop():
				EventBus.panel_opened.emit("shop")
				_open_shop_for(shop_npc)
		"openBank":
			_on_close()
			var hud_node: Node = get_parent()
			if hud_node and hud_node.has_method("open_bank"):
				hud_node.open_bank()
		"openAppearanceEditor":
			EventBus.chat_message.emit("Appearance editor coming soon!", "system")
		_:
			EventBus.chat_message.emit("Action not implemented: %s" % action, "system")

## Check if the player is still close enough to the current NPC for actions
func _is_npc_in_range() -> bool:
	if _current_npc == null or not is_instance_valid(_current_npc):
		return false
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	return player.global_position.distance_to(_current_npc.global_position) <= NPC_ACTION_RANGE

func _open_shop_for(npc: Node) -> void:
	var hud_node: Node = get_parent()
	if hud_node and hud_node.has_method("open_shop"):
		hud_node.open_shop(npc)

func _on_close() -> void:
	visible = false
	_current_npc = null
	EventBus.panel_closed.emit("dialogue")

## Resolve dynamic dialogue text
func _resolve_dynamic_text(placeholder: String) -> String:
	match placeholder:
		"__QUEST_DYNAMIC__":
			return _build_quest_dynamic_text()
		"__SLAYER_DYNAMIC__":
			return _build_slayer_dynamic_text()
		"__PRESTIGE_DYNAMIC__":
			var total_level: int = GameState.get_total_level()
			if total_level < 50:
				return "You are not yet ready. Return when your total level reaches 50 to discuss... transcendence."
			else:
				return "Ah, you've grown strong. I can reset your skills and grant permanent bonuses. This is Prestige — total rebirth for greater power. Tier %d awaits." % (GameState.prestige_tier + 1)
		"__PSIONICS_DYNAMIC__":
			return "I study the neural patterns of deep-space organisms. The tissue from creatures like Neuroworms contains remarkable bio-electric properties."
		"__KRIOS_DYNAMIC__":
			return "The corruption grows stronger each day. I need capable soldiers to push back the corrupted creatures. Are you ready for the front lines?"
		"__MIRA_DYNAMIC__":
			return "The signals from the deep abyss are getting stronger. I need help decoding them. Are you willing to venture into the darkness?"
		_:
			return "..."

## Build quest dynamic text — finds available quests from this NPC
func _build_quest_dynamic_text() -> String:
	if _current_npc == null:
		return "I have nothing for you right now."

	var npc_id: String = str(_current_npc.npc_id) if "npc_id" in _current_npc else ""

	# Check for completable active quests
	for quest_id in GameState.active_quests:
		var quest_data: Dictionary = DataManager.get_quest(str(quest_id))
		if quest_data.get("giver", "") == npc_id:
			var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
			if quest_sys and quest_sys.has_method("is_quest_complete") and quest_sys.is_quest_complete(str(quest_id)):
				return "Excellent work! You've completed %s. Here's your reward." % str(quest_data.get("name", quest_id))

	# Check for available new quests from this NPC
	for quest_id in DataManager.quests:
		var quest_data: Dictionary = DataManager.quests[quest_id]
		if quest_data.get("giver", "") == npc_id:
			var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
			if quest_sys and quest_sys.has_method("can_accept_quest") and quest_sys.can_accept_quest(quest_id):
				return "%s\n\nRewards: %s" % [str(quest_data.get("desc", "")), _format_rewards(quest_data.get("rewards", {}))]

	return "You've completed all my missions. Well done, recruit!"

## Build slayer dynamic text
func _build_slayer_dynamic_text() -> String:
	if GameState.slayer_task.is_empty():
		return "I assign dangerous hunting tasks. Want a slayer assignment? Complete them for streak bonuses and slayer points."
	else:
		var remaining: int = int(GameState.slayer_task.get("remaining", 0))
		var enemy_type: String = str(GameState.slayer_task.get("enemy_type", "unknown"))
		var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
		var enemy_name: String = str(enemy_data.get("name", enemy_type))
		return "Your current assignment: Slay %d more %s. Streak: %d." % [remaining, enemy_name, GameState.slayer_streak]

## Get dynamic options for quest/slayer nodes
func _get_dynamic_options(key: String) -> Array:
	if _current_npc == null:
		return []

	var npc_id: String = str(_current_npc.npc_id) if "npc_id" in _current_npc else ""

	if key == "quest_check":
		var options: Array = []
		# Check for completable quests first
		for quest_id in GameState.active_quests:
			var quest_data: Dictionary = DataManager.get_quest(str(quest_id))
			if quest_data.get("giver", "") == npc_id:
				var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
				if quest_sys and quest_sys.has_method("is_quest_complete") and quest_sys.is_quest_complete(str(quest_id)):
					options.append({ "label": "Claim reward!", "action": "completeQuest:%s" % str(quest_id) })
					options.append({ "label": "Not yet.", "action": "" })
					return options

		# Check for available quests
		for quest_id in DataManager.quests:
			var quest_data: Dictionary = DataManager.quests[quest_id]
			if quest_data.get("giver", "") == npc_id:
				var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
				if quest_sys and quest_sys.has_method("can_accept_quest") and quest_sys.can_accept_quest(quest_id):
					options.append({ "label": "Accept: %s" % str(quest_data.get("name", quest_id)), "action": "acceptQuest:%s" % quest_id })

		if options.is_empty():
			options.append({ "label": "Nothing available right now.", "action": "" })
		else:
			options.append({ "label": "Maybe later.", "action": "" })
		return options

	# Check if the current dialogue text was __SLAYER_DYNAMIC__
	if _current_npc and "npc_id" in _current_npc:
		var npc_data: Dictionary = DataManager.get_npc(str(_current_npc.npc_id))
		var dialogue: Dictionary = npc_data.get("dialogue", {})
		var node_data: Dictionary = dialogue.get(key, {})
		var text_val: String = str(node_data.get("text", ""))
		if text_val == "__SLAYER_DYNAMIC__":
			var slayer_options: Array = []
			if GameState.slayer_task.is_empty():
				slayer_options.append({ "label": "Give me a task.", "action": "assignSlayer" })
			else:
				slayer_options.append({ "label": "I'll get it done.", "action": "" })
			slayer_options.append({ "label": "Goodbye.", "action": "" })
			return slayer_options

	return []

## Format reward text for quest descriptions
func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	var credits: int = int(rewards.get("credits", 0))
	if credits > 0:
		parts.append("%d credits" % credits)
	var xp_rewards: Dictionary = rewards.get("xp", {})
	for skill_id in xp_rewards:
		parts.append("%d %s XP" % [int(xp_rewards[skill_id]), str(skill_id)])
	var item_rewards: Array = rewards.get("items", [])
	for item_entry in item_rewards:
		var item_id: String = str(item_entry) if item_entry is String else str(item_entry.get("item", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		if not item_data.is_empty():
			parts.append(str(item_data.get("name", item_id)))
	return ", ".join(parts) if parts.size() > 0 else "Experience"

## Get portrait background color based on NPC role
func _npc_portrait_color(npc_id: String) -> Color:
	var npc_data: Dictionary = DataManager.get_npc(npc_id)
	var role: String = str(npc_data.get("role", ""))
	match role:
		"shopkeeper":
			return Color(0.2, 0.35, 0.15, 0.6)
		"quest_giver":
			return Color(0.3, 0.2, 0.45, 0.6)
		"slayer_master":
			return Color(0.4, 0.15, 0.1, 0.6)
		"banker":
			return Color(0.2, 0.3, 0.1, 0.6)
		"prestige":
			return Color(0.4, 0.35, 0.1, 0.6)
		_:
			return Color(0.15, 0.25, 0.4, 0.5)
