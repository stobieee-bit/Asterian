## PokemonMain — Main entry point for the mobile Pokémon creature game
##
## Manages game flow: starter selection → overworld → encounters → battles.
## Wires all systems together and handles transitions.
extends Node2D

# ── Systems ──
var _overworld: Node2D = null
var _battle_system: BattleSystem = null
var _battle_ui: CanvasLayer = null
var _party_panel: CanvasLayer = null
var _pokedex_panel: CanvasLayer = null
var _bag_panel: CanvasLayer = null
var _starter_ui: CanvasLayer = null
var _menu_panel: CanvasLayer = null
var _game_started: bool = false

func _ready() -> void:
	# Check if player already has a party (loaded save)
	if GameState.creature_party.size() > 0:
		_game_started = true
		_start_game()
	else:
		_show_starter_selection()

# ── Starter Selection ──

func _show_starter_selection() -> void:
	_starter_ui = CanvasLayer.new()
	_starter_ui.layer = 30
	add_child(_starter_ui)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_starter_ui.add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(500, 500)
	root.position = Vector2(-250, -250)
	root.add_theme_constant_override("separation", 20)
	_starter_ui.add_child(root)

	var title: Label = Label.new()
	title.text = "Choose Your Starter!"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Pick your first creature companion."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	var starters: Array = [
		{ "id": "bulbascion", "name": "Bulbascion", "type": "GRASS/POISON", "color": Color(0.3, 0.8, 0.4), "desc": "A sturdy plant creature.\nStrong against Water types." },
		{ "id": "charmeleon", "name": "Flamander", "type": "FIRE", "color": Color(0.95, 0.45, 0.15), "desc": "A fierce fire lizard.\nStrong against Grass types." },
		{ "id": "aqualung", "name": "Aqualung", "type": "WATER", "color": Color(0.3, 0.55, 0.95), "desc": "A resilient water creature.\nStrong against Fire types." },
	]

	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(grid)

	for starter in starters:
		var card: VBoxContainer = VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		grid.add_child(card)

		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.color = Color(starter["color"])
		card.add_child(icon)

		var name_lbl: Label = Label.new()
		name_lbl.text = str(starter["name"])
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_lbl)

		var type_lbl: Label = Label.new()
		type_lbl.text = str(starter["type"])
		type_lbl.add_theme_font_size_override("font_size", 12)
		type_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(type_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = str(starter["desc"])
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(desc_lbl)

		var btn: Button = Button.new()
		btn.text = "CHOOSE"
		btn.custom_minimum_size = Vector2(100, 44)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(starter["color"]).darkened(0.3)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h: StyleBoxFlat = sb.duplicate()
		sb_h.bg_color = Color(starter["color"])
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var starter_id: String = str(starter["id"])
		btn.pressed.connect(func(): _select_starter(starter_id))
		card.add_child(btn)

func _select_starter(creature_id: String) -> void:
	# Create starter creature at level 5
	var starter: CreatureInstance = CreatureInstance.create(creature_id, 5)
	GameState.creature_party.append(starter.to_dict())

	# Mark in Pokédex
	GameState.pokedex[creature_id] = { "seen": true, "caught": true }

	# Remove starter UI
	if _starter_ui:
		_starter_ui.queue_free()
		_starter_ui = null

	_game_started = true
	_start_game()

# ── Game initialization ──

func _start_game() -> void:
	# Create overworld
	_overworld = preload("res://scripts/pokemon/overworld.gd").new()
	add_child(_overworld)
	_overworld.encounter_triggered.connect(_on_encounter_triggered)
	_overworld.heal_pad_entered.connect(_on_heal_pad)

	# Create UI panels
	_party_panel = preload("res://scripts/pokemon/ui/party_panel.gd").new()
	add_child(_party_panel)

	_pokedex_panel = preload("res://scripts/pokemon/ui/pokedex_panel.gd").new()
	add_child(_pokedex_panel)

	_bag_panel = preload("res://scripts/pokemon/ui/bag_panel.gd").new()
	add_child(_bag_panel)

	# Create game menu
	_create_menu()

# ── Menu ──

func _create_menu() -> void:
	_menu_panel = CanvasLayer.new()
	_menu_panel.layer = 25
	_menu_panel.visible = false
	add_child(_menu_panel)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_menu_panel.add_child(bg)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(250, 380)
	panel.position = Vector2(-125, -190)
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	panel_sb.corner_radius_top_left = 12
	panel_sb.corner_radius_top_right = 12
	panel_sb.corner_radius_bottom_left = 12
	panel_sb.corner_radius_bottom_right = 12
	panel_sb.content_margin_left = 16
	panel_sb.content_margin_right = 16
	panel_sb.content_margin_top = 16
	panel_sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_sb)
	_menu_panel.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var menu_items: Array = [
		{ "text": "PARTY", "color": Color(0.3, 0.5, 0.85), "action": "party" },
		{ "text": "BAG", "color": Color(0.3, 0.7, 0.3), "action": "bag" },
		{ "text": "POKÉDEX", "color": Color(0.85, 0.3, 0.3), "action": "pokedex" },
		{ "text": "SAVE", "color": Color(0.6, 0.6, 0.3), "action": "save" },
		{ "text": "CLOSE", "color": Color(0.4, 0.4, 0.4), "action": "close" },
	]

	for item in menu_items:
		var btn: Button = Button.new()
		btn.text = str(item["text"])
		btn.custom_minimum_size = Vector2(0, 52)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(item["color"]).darkened(0.2)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h: StyleBoxFlat = sb.duplicate()
		sb_h.bg_color = Color(item["color"])
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var action: String = str(item["action"])
		btn.pressed.connect(func(): _on_menu_action(action))
		vbox.add_child(btn)

	# Connect menu button from overworld
	EventBus.panel_opened.connect(func(name: String):
		if name == "CreaturePartyPanel" and _menu_panel:
			_menu_panel.visible = true
	)

func _on_menu_action(action: String) -> void:
	_menu_panel.visible = false
	match action:
		"party":
			EventBus.panel_opened.emit("CreaturePartyPanel")
		"bag":
			EventBus.panel_opened.emit("BagPanel")
		"pokedex":
			EventBus.panel_opened.emit("PokedexPanel")
		"save":
			SaveManager.save_game()
			EventBus.game_saved.emit()
		"close":
			pass

# ── Encounters ──

func _on_encounter_triggered(area_name: String) -> void:
	if _battle_system and _battle_system.is_active():
		return

	# Get first alive creature
	var player_creature: CreatureInstance = _get_first_alive_creature()
	if player_creature == null:
		return

	var encounter: Dictionary = _overworld.get_random_encounter(area_name)
	var wild_id: String = str(encounter["id"])
	var wild_level: int = int(encounter["level"])

	# Mark as seen in Pokédex
	if not GameState.pokedex.has(wild_id):
		GameState.pokedex[wild_id] = { "seen": true, "caught": false }
	elif not GameState.pokedex[wild_id].get("seen", false):
		GameState.pokedex[wild_id]["seen"] = true
	EventBus.pokedex_updated.emit(wild_id)

	# Start battle
	_overworld.set_in_battle(true)

	_battle_system = BattleSystem.new()
	add_child(_battle_system)
	_battle_system.battle_ended.connect(_on_battle_ended)

	_battle_ui = preload("res://scripts/pokemon/ui/battle_ui.gd").new()
	add_child(_battle_ui)
	_battle_ui.setup(_battle_system)

	_battle_system.start_wild_battle(player_creature, wild_id, wild_level)

func _on_battle_ended(result: String) -> void:
	# Clean up battle
	await get_tree().create_timer(1.0).timeout

	if _battle_system:
		_battle_system.queue_free()
		_battle_system = null

	_overworld.set_in_battle(false)

	match result:
		"lose":
			# Heal party and return to heal pad
			for i in range(GameState.creature_party.size()):
				var inst: CreatureInstance = CreatureInstance.from_dict(GameState.creature_party[i])
				inst.full_heal()
				GameState.creature_party[i] = inst.to_dict()
		"win", "caught", "run":
			pass

func _on_heal_pad() -> void:
	# Heal all creatures
	for i in range(GameState.creature_party.size()):
		var inst: CreatureInstance = CreatureInstance.from_dict(GameState.creature_party[i])
		inst.full_heal()
		GameState.creature_party[i] = inst.to_dict()
	EventBus.creature_party_changed.emit()

func _get_first_alive_creature() -> CreatureInstance:
	for c in GameState.creature_party:
		if int(c.get("current_hp", 0)) > 0:
			return CreatureInstance.from_dict(c)
	return null
