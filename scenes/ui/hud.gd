## HUD — Top-level UI overlay showing area name, player info, panels, and minimap placeholder
##
## Listens to EventBus signals to update display.
## Hosts inventory, equipment, skills, dialogue, shop, crafting panels and tooltip.
## Keybinds: I = inventory, E = equipment, K = skills
extends CanvasLayer

@onready var area_label: Label = $TopBar/AreaLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var hp_bar: ProgressBar = $TopBar/HPBar
@onready var energy_bar: ProgressBar = $TopBar/EnergyBar
@onready var credits_label: Label = $TopBar/CreditsLabel
@onready var fps_label: Label = $BottomBar/FPSLabel
@onready var pos_label: Label = $BottomBar/PosLabel

var _player: Node3D = null

# ── Distance-close tracking for interaction panels ──
const PANEL_CLOSE_DISTANCE: float = 8.0  # Close panels when player walks this far
var _interaction_source_pos: Vector3 = Vector3.ZERO  # Where the interaction started
var _interaction_panels_open: bool = false  # Whether any interaction panel is open

# ── Design resolution (reliable fallback for viewport size at _ready time) ──
var _design_size: Vector2 = Vector2(
	ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
	ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
)

## Get the actual viewport size (responds to window resizes)
func _get_viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return _design_size

# ── UI panel instances ──
var _inventory_panel: PanelContainer = null
var _equipment_panel: PanelContainer = null
var _skills_panel: PanelContainer = null
var _dialogue_panel: PanelContainer = null
var _shop_panel: PanelContainer = null
var _crafting_panel: PanelContainer = null
var _quest_panel: PanelContainer = null
var _bank_panel: PanelContainer = null
var _bestiary_panel: PanelContainer = null
var _prestige_panel: PanelContainer = null
var _dungeon_panel: PanelContainer = null
var _pet_panel: PanelContainer = null
var _settings_panel: PanelContainer = null
var _multiplayer_panel: PanelContainer = null
var _tooltip_panel: PanelContainer = null
var _context_menu: PanelContainer = null
var _context_menu_vbox: VBoxContainer = null
var _context_menu_title: Label = null

# Panel scripts
var inventory_script: GDScript = preload("res://scripts/ui/inventory_panel.gd")
var equipment_script: GDScript = preload("res://scripts/ui/equipment_panel.gd")
var skills_script: GDScript = preload("res://scripts/ui/skills_panel.gd")
var dialogue_script: GDScript = preload("res://scripts/ui/dialogue_panel.gd")
var shop_script: GDScript = preload("res://scripts/ui/shop_panel.gd")
var crafting_script: GDScript = preload("res://scripts/ui/crafting_panel.gd")
var quest_script: GDScript = preload("res://scripts/ui/quest_panel.gd")
var bank_script: GDScript = preload("res://scripts/ui/bank_panel.gd")
var bestiary_script: GDScript = preload("res://scripts/ui/bestiary_panel.gd")
var prestige_script: GDScript = preload("res://scripts/ui/prestige_panel.gd")
var dungeon_script: GDScript = preload("res://scripts/ui/dungeon_panel.gd")
var pet_script: GDScript = preload("res://scripts/ui/pet_panel.gd")
var settings_script: GDScript = preload("res://scripts/ui/settings_panel.gd")
var tooltip_script: GDScript = preload("res://scripts/ui/tooltip_panel.gd")
# context_menu is built inline in _build_context_menu()

# ── Chat log ──
var _chat_bg: PanelContainer = null
var _chat_container: VBoxContainer = null
var _chat_messages: Array[Label] = []
var _max_chat_lines: int = 10
var _chat_input: LineEdit = null
var _chat_typing: bool = false  # True when chat input is focused

## Overlaid HP/Energy text labels (drawn on top of progress bars)
var _hp_text: Label = null
var _energy_text: Label = null

## Hover text — shows entity names when mouse hovers in 3D world
var _hover_label: Label = null
var _hover_target: Node = null  # Currently hovered entity
var _hover_raycast_timer: float = 0.0  # Throttle raycasts to every ~0.05s

func _ready() -> void:
	# Connect to EventBus signals
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.player_credits_changed.connect(_on_credits_changed)
	EventBus.player_level_up.connect(_on_level_up)
	EventBus.chat_message.connect(_on_chat_message)
	EventBus.inventory_full.connect(_on_inventory_full)

	# QoL signals
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.item_added.connect(_on_item_added)
	EventBus.gathering_started.connect(_on_gathering_started)
	EventBus.gathering_complete.connect(_on_gathering_complete)
	EventBus.quest_accepted.connect(_on_quest_tracker_update)
	EventBus.quest_progress.connect(_on_quest_progress_update)
	EventBus.quest_completed.connect(_on_quest_tracker_update)
	EventBus.game_saved.connect(_on_game_saved)

	# Panel layout persistence
	EventBus.panel_closed.connect(_on_panel_state_changed)
	EventBus.panel_opened.connect(_on_panel_state_changed)

	# Context menu signal
	EventBus.context_menu_requested.connect(_on_context_menu_requested)
	EventBus.context_menu_hidden.connect(_hide_context_menu)

	# Window resize — reposition minimap and action bar
	get_tree().root.size_changed.connect(_on_window_resized)

	# Style the top and bottom bars
	_style_top_bar()
	_style_bottom_bar()

	# Initial display
	_update_area_display(GameState.current_area)
	_update_credits_display(GameState.player["credits"])
	_update_level_display()

	# Build panels (hidden by default)
	_build_panels()

	# Wire drag-end callbacks for panel position saving
	_wire_panel_drag_callbacks()

	# Restore saved panel positions/visibility/lock state (deferred so layout pass is done)
	call_deferred("_restore_panel_layout")

	# Build chat log
	_build_chat_log()

	# Build action buttons bar
	_build_action_bar()

	# Build gathering progress bar
	_build_gather_progress()

	# Build adrenaline bar + ability buttons
	_build_adrenaline_bar()
	_build_ability_bar()

	# Build minimap
	_build_minimap()

	# Build QoL overlays
	_build_low_hp_vignette()
	_build_area_toast()
	_build_levelup_flash()
	_build_combat_indicator()
	_build_slayer_display()
	_build_loot_toast()
	_build_target_info_panel()
	_build_gather_label()
	_build_quest_tracker()
	_build_save_toast()
	_build_combat_style_indicator()
	_build_hover_label()

## Style the TopBar: dark background, colored HP/energy bars with text overlays
func _style_top_bar() -> void:
	var top_bar: HBoxContainer = $TopBar
	if top_bar == null:
		return
	# Let mouse events pass through the top bar to the 3D world
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# (top bar background removed — cleaner look)

	# (accent line removed — cleaner look)

	# Let all TopBar children pass through mouse events
	if hp_bar:
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if energy_bar:
		energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if area_label:
		area_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level_label:
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if credits_label:
		credits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ── Style HP Bar ──
	if hp_bar:
		var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.08, 0.02, 0.02, 0.7)
		hp_bg.set_corner_radius_all(3)
		hp_bg.border_color = Color(0.3, 0.08, 0.08, 0.4)
		hp_bg.set_border_width_all(1)
		hp_bar.add_theme_stylebox_override("background", hp_bg)

		var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.65, 0.12, 0.08, 0.9)
		hp_fill.set_corner_radius_all(3)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)

		_hp_text = Label.new()
		_hp_text.name = "HPText"
		_hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_text.add_theme_font_size_override("font_size", 10)
		_hp_text.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95, 0.95))
		_hp_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		_hp_text.add_theme_constant_override("shadow_offset_x", 1)
		_hp_text.add_theme_constant_override("shadow_offset_y", 1)
		_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_bar.add_child(_hp_text)

	# ── Style Energy Bar ──
	if energy_bar:
		var en_bg: StyleBoxFlat = StyleBoxFlat.new()
		en_bg.bg_color = Color(0.02, 0.04, 0.1, 0.7)
		en_bg.set_corner_radius_all(3)
		en_bg.border_color = Color(0.06, 0.1, 0.3, 0.4)
		en_bg.set_border_width_all(1)
		energy_bar.add_theme_stylebox_override("background", en_bg)

		var en_fill: StyleBoxFlat = StyleBoxFlat.new()
		en_fill.bg_color = Color(0.12, 0.35, 0.75, 0.9)
		en_fill.set_corner_radius_all(3)
		energy_bar.add_theme_stylebox_override("fill", en_fill)

		_energy_text = Label.new()
		_energy_text.name = "EnergyText"
		_energy_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_energy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_energy_text.add_theme_font_size_override("font_size", 10)
		_energy_text.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 0.95))
		_energy_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		_energy_text.add_theme_constant_override("shadow_offset_x", 1)
		_energy_text.add_theme_constant_override("shadow_offset_y", 1)
		_energy_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		energy_bar.add_child(_energy_text)

	# Style area label — subtle with shadow
	if area_label:
		area_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
		area_label.add_theme_constant_override("shadow_offset_x", 1)
		area_label.add_theme_constant_override("shadow_offset_y", 1)

	# Style credits label — muted gold
	if credits_label:
		credits_label.add_theme_font_size_override("font_size", 13)
		credits_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3, 0.9))
		credits_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
		credits_label.add_theme_constant_override("shadow_offset_x", 1)
		credits_label.add_theme_constant_override("shadow_offset_y", 1)

## Style the BottomBar: add subtle dark background
func _style_bottom_bar() -> void:
	var bottom_bar: HBoxContainer = $BottomBar
	if bottom_bar == null:
		return
	# Let mouse events pass through the bottom bar to the 3D world
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fps_label:
		fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pos_label:
		pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# (bottom bar background removed — cleaner look)

func _process(delta: float) -> void:
	# Update FPS counter
	if fps_label:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	# Update player position display
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player and pos_label:
		var p: Vector3 = _player.global_position
		pos_label.text = "%.0f, %.0f" % [p.x, p.z]

	# Update HP/Energy bars + overlay text
	if hp_bar:
		hp_bar.value = GameState.player["hp"]
		hp_bar.max_value = GameState.player["max_hp"]
		if _hp_text:
			_hp_text.text = "HP: %d / %d" % [GameState.player["hp"], GameState.player["max_hp"]]
	if energy_bar:
		energy_bar.value = GameState.player["energy"]
		energy_bar.max_value = GameState.player["max_energy"]
		if _energy_text:
			_energy_text.text = "EN: %d / %d" % [GameState.player["energy"], GameState.player["max_energy"]]

	# Update adrenaline bar + text
	if _adrenaline_bar:
		var adr_val: float = float(GameState.player["adrenaline"])
		_adrenaline_bar.value = adr_val
		_adrenaline_bar.max_value = 100.0
		if _adrenaline_text:
			_adrenaline_text.text = "%d%%" % int(adr_val)

	# ── QoL: Low HP vignette pulse ──
	_update_low_hp_vignette(delta)

	# ── QoL: Combat indicator ──
	_update_combat_indicator()

	# ── QoL: Target info panel (live HP update) ──
	_update_target_info()

	# ── Hover text for 3D entities ──
	_update_hover_label()

	# ── Minimap camera follow ──
	_update_minimap()

	# ── Distance check: close interaction panels if player walks away ──
	_check_interaction_distance()

func _unhandled_input(event: InputEvent) -> void:
	# ── Chat input: Enter to open, Escape to close ──
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not _chat_typing:
				# Enter while not typing → focus the chat input
				_focus_chat_input()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_ESCAPE:
			if _chat_typing:
				# Escape while typing → unfocus chat input
				_unfocus_chat_input()
				get_viewport().set_input_as_handled()
				return

	# ── Block all game keybinds while typing in chat ──
	if _chat_typing:
		return

	# Panel toggle keybinds
	if event.is_action_pressed("toggle_inventory"):
		_toggle_panel(_inventory_panel, "inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_equipment"):
		_toggle_panel(_equipment_panel, "equipment")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_skills"):
		_toggle_panel(_skills_panel, "skills")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_quests"):
		_toggle_panel(_quest_panel, "quests")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_bestiary"):
		_toggle_panel(_bestiary_panel, "bestiary")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# Ability keybinds (1, 2, 3)
			KEY_1:
				_use_ability(1)
				get_viewport().set_input_as_handled()
			KEY_2:
				_use_ability(2)
				get_viewport().set_input_as_handled()
			KEY_3:
				_use_ability(3)
				get_viewport().set_input_as_handled()
			# Eat food (F)
			KEY_F:
				_eat_food()
				get_viewport().set_input_as_handled()
			# Combat style cycle (C)
			KEY_C:
				_cycle_combat_style()
				get_viewport().set_input_as_handled()
			# Toggle run/walk (R)
			KEY_R:
				_toggle_run()
				get_viewport().set_input_as_handled()
			# Target nearest enemy (Tab)
			KEY_TAB:
				_target_nearest_enemy()
				get_viewport().set_input_as_handled()
			# Escape: close all panels, deselect target, close context menu
			KEY_ESCAPE:
				_close_all_panels()
				EventBus.context_menu_hidden.emit()
				get_viewport().set_input_as_handled()
			# Space: deselect target
			KEY_SPACE:
				_deselect_target()
				get_viewport().set_input_as_handled()
			# Dungeon (N)
			KEY_N:
				_toggle_panel(_dungeon_panel, "dungeon")
				get_viewport().set_input_as_handled()
			# Minimap zoom toggle (M)
			KEY_M:
				_cycle_minimap_zoom()
				get_viewport().set_input_as_handled()

## Toggle a panel's visibility
func _toggle_panel(panel: PanelContainer, panel_name: String) -> void:
	if panel == null:
		return
	panel.visible = not panel.visible
	if panel.visible:
		EventBus.panel_opened.emit(panel_name)
		# Refresh panel data
		if panel.has_method("refresh"):
			panel.refresh()
	else:
		EventBus.panel_closed.emit(panel_name)

## Build all UI panels (hidden by default)
func _build_panels() -> void:
	# Panel style base — clean, dark, minimal border
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.06, 0.88)
	panel_style.border_color = Color(0.1, 0.2, 0.3, 0.4)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)

	# Inventory panel (right side) — open by default
	_inventory_panel = PanelContainer.new()
	_inventory_panel.set_script(inventory_script)
	_inventory_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_inventory_panel.visible = true
	_inventory_panel.anchors_preset = Control.PRESET_CENTER_RIGHT
	_inventory_panel.position = Vector2(800, 80)
	add_child(_inventory_panel)

	# Equipment panel (left of inventory) — open by default
	_equipment_panel = PanelContainer.new()
	_equipment_panel.set_script(equipment_script)
	_equipment_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_equipment_panel.visible = true
	_equipment_panel.position = Vector2(560, 80)
	add_child(_equipment_panel)

	# Skills panel (left side) — open by default
	_skills_panel = PanelContainer.new()
	_skills_panel.set_script(skills_script)
	_skills_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_skills_panel.visible = true
	_skills_panel.position = Vector2(20, 80)
	add_child(_skills_panel)

	# Dialogue panel (center of screen)
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_script(dialogue_script)
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_dialogue_panel.visible = false
	_dialogue_panel.position = Vector2(300, 300)
	add_child(_dialogue_panel)

	# Shop panel (center-right)
	_shop_panel = PanelContainer.new()
	_shop_panel.set_script(shop_script)
	_shop_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_shop_panel.visible = false
	_shop_panel.position = Vector2(500, 100)
	add_child(_shop_panel)

	# Crafting panel (center)
	_crafting_panel = PanelContainer.new()
	_crafting_panel.set_script(crafting_script)
	_crafting_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_crafting_panel.visible = false
	_crafting_panel.position = Vector2(350, 100)
	add_child(_crafting_panel)

	# Quest panel (left-center)
	_quest_panel = PanelContainer.new()
	_quest_panel.set_script(quest_script)
	_quest_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_quest_panel.visible = false
	_quest_panel.position = Vector2(20, 80)
	add_child(_quest_panel)

	# Bank panel (center)
	_bank_panel = PanelContainer.new()
	_bank_panel.set_script(bank_script)
	_bank_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_bank_panel.visible = false
	_bank_panel.position = Vector2(300, 60)
	add_child(_bank_panel)

	# Bestiary panel (left)
	_bestiary_panel = PanelContainer.new()
	_bestiary_panel.set_script(bestiary_script)
	_bestiary_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_bestiary_panel.visible = false
	_bestiary_panel.position = Vector2(20, 80)
	add_child(_bestiary_panel)

	# Prestige panel (center-left)
	_prestige_panel = PanelContainer.new()
	_prestige_panel.set_script(prestige_script)
	_prestige_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_prestige_panel.visible = false
	_prestige_panel.position = Vector2(200, 60)
	add_child(_prestige_panel)

	# Dungeon panel (center)
	_dungeon_panel = PanelContainer.new()
	_dungeon_panel.set_script(dungeon_script)
	_dungeon_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_dungeon_panel.visible = false
	_dungeon_panel.position = Vector2(400, 60)
	add_child(_dungeon_panel)

	# Pet panel (right-center)
	_pet_panel = PanelContainer.new()
	_pet_panel.set_script(pet_script)
	_pet_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_pet_panel.visible = false
	_pet_panel.position = Vector2(600, 60)
	add_child(_pet_panel)

	# Settings panel (center)
	_settings_panel = PanelContainer.new()
	_settings_panel.set_script(settings_script)
	_settings_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_settings_panel.visible = false
	_settings_panel.position = Vector2(350, 100)
	add_child(_settings_panel)

	# Multiplayer panel (bottom-right, always accessible)
	_multiplayer_panel = PanelContainer.new()
	_multiplayer_panel.name = "MultiplayerPanel"
	_multiplayer_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_multiplayer_panel.visible = false
	_multiplayer_panel.position = Vector2(680, 400)
	_multiplayer_panel.custom_minimum_size = Vector2(300, 220)
	add_child(_multiplayer_panel)
	_build_multiplayer_panel_contents()

	# Tooltip (always exists, but hidden — added last so it renders on top)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.set_script(tooltip_script)
	add_child(_tooltip_panel)

	# Context menu (right-click popup — built inline, no external script)
	_build_context_menu()

## Build the chat log in the bottom-left
func _build_chat_log() -> void:
	_chat_bg = PanelContainer.new()
	_chat_bg.name = "ChatBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.015, 0.02, 0.04, 0.6)
	bg_style.border_color = Color(0.08, 0.15, 0.25, 0.25)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(4)
	bg_style.set_content_margin_all(0)
	_chat_bg.add_theme_stylebox_override("panel", bg_style)
	var vp_size: Vector2 = _get_viewport_size()
	_chat_bg.position = Vector2(8, vp_size.y - 240)
	_chat_bg.custom_minimum_size = Vector2(360, 180)
	_chat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chat_bg)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_bg.add_child(outer_vbox)

	# Minimal header
	var header: PanelContainer = PanelContainer.new()
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = Color(0.02, 0.04, 0.08, 0.5)
	header_style.corner_radius_top_left = 4
	header_style.corner_radius_top_right = 4
	header_style.set_content_margin_all(2)
	header_style.content_margin_left = 6
	header.add_theme_stylebox_override("panel", header_style)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(header)

	var header_label: Label = Label.new()
	header_label.text = "Chat"
	header_label.add_theme_font_size_override("font_size", 9)
	header_label.add_theme_color_override("font_color", Color(0.35, 0.55, 0.65, 0.6))
	header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_label)

	# Message area with padding
	var msg_margin: MarginContainer = MarginContainer.new()
	msg_margin.add_theme_constant_override("margin_left", 6)
	msg_margin.add_theme_constant_override("margin_right", 6)
	msg_margin.add_theme_constant_override("margin_top", 4)
	msg_margin.add_theme_constant_override("margin_bottom", 2)
	msg_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(msg_margin)

	_chat_container = VBoxContainer.new()
	_chat_container.name = "ChatContainer"
	_chat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_container.custom_minimum_size = Vector2(360, 0)
	_chat_container.add_theme_constant_override("separation", 2)
	msg_margin.add_child(_chat_container)

	# ── Chat input field at the bottom ──
	var input_margin: MarginContainer = MarginContainer.new()
	input_margin.add_theme_constant_override("margin_left", 4)
	input_margin.add_theme_constant_override("margin_right", 4)
	input_margin.add_theme_constant_override("margin_bottom", 4)
	input_margin.add_theme_constant_override("margin_top", 0)
	outer_vbox.add_child(input_margin)

	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.max_length = 200
	_chat_input.add_theme_font_size_override("font_size", 11)
	_chat_input.custom_minimum_size = Vector2(0, 24)

	var input_style: StyleBoxFlat = StyleBoxFlat.new()
	input_style.bg_color = Color(0.025, 0.035, 0.06, 0.7)
	input_style.border_color = Color(0.08, 0.15, 0.25, 0.35)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(3)
	input_style.content_margin_left = 6
	input_style.content_margin_right = 6
	input_style.content_margin_top = 2
	input_style.content_margin_bottom = 2
	_chat_input.add_theme_stylebox_override("normal", input_style)

	var focus_style: StyleBoxFlat = input_style.duplicate()
	focus_style.border_color = Color(0.15, 0.35, 0.55, 0.6)
	_chat_input.add_theme_stylebox_override("focus", focus_style)

	_chat_input.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.9))
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.3, 0.4, 0.5, 0.5))

	# Connect signals
	_chat_input.text_submitted.connect(_on_chat_input_submitted)
	_chat_input.focus_entered.connect(_on_chat_focus_entered)
	_chat_input.focus_exited.connect(_on_chat_focus_exited)

	input_margin.add_child(_chat_input)

## Create a styled, clean button with subtle accent coloring
func _make_sci_btn(text: String, width: float = 70, accent: Color = Color(0.2, 0.6, 0.8)) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 28)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", accent.lightened(0.1))
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.4))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	# Normal — near-invisible background, subtle bottom accent
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.04, 0.08, 0.6)
	normal.border_color = Color(0.1, 0.15, 0.2, 0.3)
	normal.set_border_width_all(0)
	normal.border_width_bottom = 1
	normal.border_color = accent.darkened(0.4)
	normal.border_color.a = 0.35
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(3)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — slight lift effect
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.05, 0.07, 0.14, 0.75)
	hover.border_color = accent.darkened(0.15)
	hover.border_color.a = 0.6
	hover.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed — inset feel
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.7
	pressed.border_width_bottom = 0
	pressed.border_width_top = 1
	pressed.border_color = accent.darkened(0.2)
	pressed.border_color.a = 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

## Action bar background reference (for repositioning on window resize)
var _action_bar_bg: PanelContainer = null

## Build action button bar at the bottom
func _build_action_bar() -> void:
	_action_bar_bg = PanelContainer.new()
	var bar_bg: PanelContainer = _action_bar_bg
	bar_bg.name = "ActionBarBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.015, 0.02, 0.04, 0.65)
	bg_style.border_color = Color(0.08, 0.15, 0.25, 0.25)
	bg_style.border_width_top = 1
	bg_style.set_corner_radius_all(4)
	bg_style.set_content_margin_all(3)
	bg_style.content_margin_left = 6
	bg_style.content_margin_right = 6
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	var vp_init: Vector2 = _get_viewport_size()
	bar_bg.position = Vector2(vp_init.x / 2.0 - 440, vp_init.y - 44)
	add_child(bar_bg)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar_bg.add_child(bar)

	var cyan: Color = Color(0.2, 0.7, 0.9)
	var gold: Color = Color(0.9, 0.75, 0.3)
	var green: Color = Color(0.3, 0.8, 0.4)
	var purple: Color = Color(0.7, 0.4, 0.9)

	# Inventory button
	var inv_btn: Button = _make_sci_btn("Bag [I]", 65, cyan)
	inv_btn.tooltip_text = "Inventory (I)"
	inv_btn.pressed.connect(func(): _toggle_panel(_inventory_panel, "inventory"))
	bar.add_child(inv_btn)

	# Equipment button
	var eq_btn: Button = _make_sci_btn("Equip [E]", 72, cyan)
	eq_btn.tooltip_text = "Equipment (E)"
	eq_btn.pressed.connect(func(): _toggle_panel(_equipment_panel, "equipment"))
	bar.add_child(eq_btn)

	# Skills button
	var sk_btn: Button = _make_sci_btn("Skills [K]", 72, green)
	sk_btn.tooltip_text = "Skills (K)"
	sk_btn.pressed.connect(func(): _toggle_panel(_skills_panel, "skills"))
	bar.add_child(sk_btn)

	# Quests button
	var quest_btn: Button = _make_sci_btn("Quests [Q]", 78, purple)
	quest_btn.tooltip_text = "Quests (Q)"
	quest_btn.pressed.connect(func(): _toggle_panel(_quest_panel, "quests"))
	bar.add_child(quest_btn)

	# Bestiary button
	var best_btn: Button = _make_sci_btn("Bestiary [L]", 82, Color(0.8, 0.4, 0.3))
	best_btn.tooltip_text = "Bestiary (L)"
	best_btn.pressed.connect(func(): _toggle_panel(_bestiary_panel, "bestiary"))
	bar.add_child(best_btn)

	# Prestige button
	var pres_btn: Button = _make_sci_btn("Prestige", 72, gold)
	pres_btn.tooltip_text = "Prestige System"
	pres_btn.pressed.connect(func(): _toggle_panel(_prestige_panel, "prestige"))
	bar.add_child(pres_btn)

	# Dungeon button
	var dung_btn: Button = _make_sci_btn("Dungeon", 72, Color(0.9, 0.5, 0.2))
	dung_btn.tooltip_text = "Dungeon Explorer"
	dung_btn.pressed.connect(func(): _toggle_panel(_dungeon_panel, "dungeon"))
	bar.add_child(dung_btn)

	# Pets button
	var pet_btn: Button = _make_sci_btn("Pets", 52, Color(0.8, 0.4, 0.9))
	pet_btn.tooltip_text = "Pet Companions"
	pet_btn.pressed.connect(func(): _toggle_panel(_pet_panel, "pets"))
	bar.add_child(pet_btn)

	# Settings button
	var set_btn: Button = _make_sci_btn("Settings", 68, Color(0.5, 0.5, 0.6))
	set_btn.tooltip_text = "Settings"
	set_btn.pressed.connect(func(): _toggle_panel(_settings_panel, "settings"))
	bar.add_child(set_btn)

# ── Signal handlers ──

func _on_area_entered(area_id: String) -> void:
	_update_area_display(area_id)
	_show_area_toast(area_id)

func _on_credits_changed(new_total: int) -> void:
	_update_credits_display(new_total)

func _on_level_up(skill: String, new_level: int) -> void:
	_update_level_display()
	_show_levelup_flash(skill, new_level)

func _on_inventory_full() -> void:
	_on_chat_message("Inventory is full!", "system")

func _on_chat_message(text: String, channel: String) -> void:
	if _chat_container == null:
		return

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)

	# Color by channel — slightly muted for a cleaner look
	var color: Color
	match channel:
		"loot":
			color = Color(0.3, 0.8, 0.9, 0.95)
		"combat":
			color = Color(0.9, 0.35, 0.25, 0.95)
		"equipment":
			color = Color(0.8, 0.65, 0.3, 0.95)
		"system":
			color = Color(0.55, 0.6, 0.6, 0.85)
		"xp":
			color = Color(0.3, 0.8, 0.35, 0.95)
		"quest":
			color = Color(0.8, 0.55, 0.9, 0.95)
		"levelup":
			color = Color(0.95, 0.9, 0.3, 1.0)
		"slayer":
			color = Color(0.9, 0.45, 0.2, 0.95)
		"achievement":
			color = Color(0.9, 0.75, 0.1, 0.95)
		"prestige":
			color = Color(0.9, 0.75, 0.1, 0.95)
		"dungeon":
			color = Color(0.9, 0.45, 0.2, 0.95)
		"pet":
			color = Color(0.7, 0.3, 0.9, 0.95)
		"multiplayer":
			color = Color(0.3, 0.6, 0.9, 0.95)
		_:
			color = Color(0.5, 0.5, 0.5, 0.8)

	label.add_theme_color_override("font_color", color)
	label.text = text

	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	_chat_container.add_child(label)
	_chat_messages.append(label)

	# Remove old messages
	while _chat_messages.size() > _max_chat_lines:
		var old: Label = _chat_messages[0]
		_chat_messages.remove_at(0)
		old.queue_free()

	# Auto-fade after 8 seconds
	var tween: Tween = create_tween()
	tween.tween_interval(8.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)

# ── Chat input handlers ──

## Called when Enter is pressed while the chat input is focused
func _on_chat_input_submitted(text: String) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.length() > 0:
		# Send via multiplayer
		var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
		if client and client.has_method("send_chat") and client.is_mp_connected():
			client.send_chat(trimmed)
			# Don't emit locally — server echoes our message back via _handle_chat()
		else:
			# Not connected — show locally as system message
			EventBus.chat_message.emit(trimmed, "system")
	# Clear input and release focus
	_chat_input.text = ""
	_chat_input.release_focus()

## Called when the chat input gains focus
func _on_chat_focus_entered() -> void:
	_chat_typing = true
	_chat_input.placeholder_text = "Type a message..."
	# Make the chat panel stop ignoring mouse so scrolling/clicking works
	if _chat_bg:
		_chat_bg.mouse_filter = Control.MOUSE_FILTER_STOP

## Called when the chat input loses focus
func _on_chat_focus_exited() -> void:
	_chat_typing = false
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.text = ""
	# Return to mouse-transparent so clicks pass through to the game world
	if _chat_bg:
		_chat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Focus the chat input (called from Enter key)
func _focus_chat_input() -> void:
	if _chat_input == null:
		return
	_chat_input.grab_focus()

## Unfocus the chat input (called from Escape key)
func _unfocus_chat_input() -> void:
	if _chat_input == null:
		return
	_chat_input.release_focus()

## Reposition the chat panel to bottom-left of current viewport
func _reposition_chat() -> void:
	if _chat_bg == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	_chat_bg.position = Vector2(8, vp_size.y - 260)

func _update_area_display(area_id: String) -> void:
	if area_label == null:
		return
	var area_data: Dictionary = DataManager.get_area(area_id)
	if not area_data.is_empty():
		area_label.text = str(area_data.get("name", area_id))
	else:
		area_label.text = area_id

func _update_credits_display(amount: int) -> void:
	if credits_label:
		# Format large numbers with commas
		var s: String = str(amount)
		if amount >= 1000:
			var parts: Array[String] = []
			while s.length() > 3:
				parts.push_front(s.right(3))
				s = s.left(s.length() - 3)
			parts.push_front(s)
			s = ",".join(parts)
		credits_label.text = "$%s" % s

func _update_level_display() -> void:
	if level_label:
		level_label.text = "Combat Lv %d | Total Lv %d" % [
			GameState.get_combat_level(),
			GameState.get_total_level()
		]

# ── Public API for opening panels from other systems ──

## Open NPC dialogue panel — called by InteractionController
func open_dialogue(npc: Node) -> void:
	if _dialogue_panel and _dialogue_panel.has_method("open_dialogue"):
		_dialogue_panel.open_dialogue(npc)
		_mark_interaction_source()

## Open shop panel — called by DialoguePanel when player selects "Shop"
func open_shop(npc: Node) -> void:
	if _shop_panel and _shop_panel.has_method("open_shop"):
		_shop_panel.open_shop(npc)
		_mark_interaction_source()

## Open crafting panel — called when player interacts with a processing station
func open_crafting(skill_id: String, station_name: String) -> void:
	if _crafting_panel and _crafting_panel.has_method("open_crafting"):
		_crafting_panel.open_crafting(skill_id, station_name)
		_mark_interaction_source()

## Open bank panel
func open_bank() -> void:
	_toggle_panel(_bank_panel, "bank")
	_mark_interaction_source()

## Open prestige panel
func open_prestige() -> void:
	_toggle_panel(_prestige_panel, "prestige")

## Open dungeon panel
func open_dungeon() -> void:
	_toggle_panel(_dungeon_panel, "dungeon")

# ── Distance-based panel closing ──

## Record the player's position when an interaction panel opens
func _mark_interaction_source() -> void:
	if _player:
		_interaction_source_pos = _player.global_position
		_interaction_panels_open = true

## Close interaction panels (bank, shop, crafting, dialogue) if the player walks too far
func _check_interaction_distance() -> void:
	if not _interaction_panels_open or _player == null:
		return

	var dist: float = _player.global_position.distance_to(_interaction_source_pos)
	if dist < PANEL_CLOSE_DISTANCE:
		return

	# Close all interaction panels
	var closed_any: bool = false
	var interaction_panels: Array = [_dialogue_panel, _shop_panel, _crafting_panel, _bank_panel]
	for panel in interaction_panels:
		if panel and panel.visible:
			panel.visible = false
			closed_any = true

	if closed_any:
		EventBus.chat_message.emit("Moved too far away.", "system")

	_interaction_panels_open = false

# ── Gathering progress bar ──
# Managed by InteractionController but displayed by HUD

var _gather_progress: ProgressBar = null

## Build the gathering progress bar (shown above the action bar when gathering)
func _build_gather_progress() -> void:
	_gather_progress = ProgressBar.new()
	_gather_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gather_progress.custom_minimum_size = Vector2(110, 8)
	_gather_progress.show_percentage = false
	_gather_progress.visible = false
	_gather_progress.position = Vector2(340, _design_size.y - 60)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.1, 0.6)
	bg_style.set_corner_radius_all(2)
	_gather_progress.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.65, 0.85, 0.8)
	fill_style.set_corner_radius_all(2)
	_gather_progress.add_theme_stylebox_override("fill", fill_style)

	add_child(_gather_progress)

## Show/update gathering progress (0.0 to 1.0)
func show_gather_progress(progress: float) -> void:
	if _gather_progress:
		_gather_progress.value = progress * 100.0
		_gather_progress.visible = true

## Hide gathering progress bar
func hide_gather_progress() -> void:
	if _gather_progress:
		_gather_progress.visible = false
	if _gather_label:
		_gather_label.visible = false

# ── Adrenaline bar ──

var _adrenaline_bar: ProgressBar = null
var _adrenaline_text: Label = null

## Build the adrenaline bar under the HP/Energy bars
func _build_adrenaline_bar() -> void:
	var adr_container: Control = Control.new()
	adr_container.name = "AdrenalineContainer"
	adr_container.position = Vector2(12, 36)
	adr_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(adr_container)

	var lbl: Label = Label.new()
	lbl.text = "ADR"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.3, 0.7))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = Vector2(0, 0)
	adr_container.add_child(lbl)

	_adrenaline_bar = ProgressBar.new()
	_adrenaline_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adrenaline_bar.custom_minimum_size = Vector2(150, 10)
	_adrenaline_bar.show_percentage = false
	_adrenaline_bar.max_value = 100.0
	_adrenaline_bar.value = 0.0
	_adrenaline_bar.position = Vector2(30, 2)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.06, 0.03, 0.6)
	bg_style.set_corner_radius_all(2)
	bg_style.border_color = Color(0.12, 0.25, 0.08, 0.3)
	bg_style.set_border_width_all(1)
	_adrenaline_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.7, 0.18, 0.85)
	fill_style.set_corner_radius_all(2)
	_adrenaline_bar.add_theme_stylebox_override("fill", fill_style)

	adr_container.add_child(_adrenaline_bar)

	_adrenaline_text = Label.new()
	_adrenaline_text.name = "AdrText"
	_adrenaline_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adrenaline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adrenaline_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_adrenaline_text.add_theme_font_size_override("font_size", 8)
	_adrenaline_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75, 0.8))
	_adrenaline_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_adrenaline_text.add_theme_constant_override("shadow_offset_x", 1)
	_adrenaline_text.add_theme_constant_override("shadow_offset_y", 1)
	_adrenaline_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_adrenaline_bar.add_child(_adrenaline_text)

# ── Ability bar ──

## Build 3 ability buttons + eat food button below the adrenaline bar
func _build_ability_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.position = Vector2(12, 50)
	bar.add_theme_constant_override("separation", 3)
	add_child(bar)

	# Basic ability (BUILDS +8% adrenaline) — cyan
	var btn1: Button = _make_ability_btn("1", "Basic", Color(0.3, 0.9, 1.0), 0, "+8 ADR")
	btn1.tooltip_text = "Basic Ability — 1.5x damage\nBuilds 8% Adrenaline"
	btn1.pressed.connect(func(): _use_ability(1))
	bar.add_child(btn1)

	# Threshold ability (COSTS 50% adrenaline) — orange
	var btn2: Button = _make_ability_btn("2", "Thresh", Color(1.0, 0.6, 0.1), 50)
	btn2.tooltip_text = "Threshold Ability — 2.88x damage\nCosts 50% Adrenaline"
	btn2.pressed.connect(func(): _use_ability(2))
	bar.add_child(btn2)

	# Ultimate ability (COSTS 100% adrenaline) — magenta
	var btn3: Button = _make_ability_btn("3", "Ulti", Color(1.0, 0.2, 0.9), 100)
	btn3.tooltip_text = "Ultimate Ability — 5.0x damage\nCosts 100% Adrenaline"
	btn3.pressed.connect(func(): _use_ability(3))
	bar.add_child(btn3)

	# Eat food button — green
	var food_btn: Button = _make_ability_btn("F", "Eat", Color(0.3, 1.0, 0.3), 0)
	food_btn.tooltip_text = "Eat Food — Heals HP\nUses best food in inventory"
	food_btn.pressed.connect(func(): _eat_food())
	bar.add_child(food_btn)

## Create a styled ability button with keybind + name + cost badge
func _make_ability_btn(keybind: String, label_text: String, accent: Color, cost: int, cost_text_override: String = "") -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(72, 32)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.06, 0.7)
	normal.border_color = accent.darkened(0.35)
	normal.border_color.a = 0.4
	normal.set_border_width_all(0)
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.04, 0.06, 0.12, 0.8)
	hover.border_color = accent.darkened(0.1)
	hover.border_color.a = 0.6
	hover.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.6
	pressed.border_width_bottom = 0
	pressed.border_width_top = 1
	pressed.border_color = accent.darkened(0.2)
	pressed.border_color.a = 0.4
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.text = ""

	var inner: Control = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(inner)

	# Keybind — small, top-left
	var key_lbl: Label = Label.new()
	key_lbl.text = keybind
	key_lbl.position = Vector2(3, 0)
	key_lbl.size = Vector2(14, 14)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.add_theme_color_override("font_color", accent.darkened(0.1))
	key_lbl.add_theme_color_override("font_color", accent.lightened(0.15))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(key_lbl)

	# Ability name
	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.position = Vector2(18, 1)
	name_lbl.size = Vector2(52, 14)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", accent)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	# Cost badge
	var badge_text: String = cost_text_override if cost_text_override != "" else ("%d ADR" % cost if cost > 0 else "")
	if badge_text != "":
		var cost_lbl: Label = Label.new()
		cost_lbl.text = badge_text
		cost_lbl.position = Vector2(0, 16)
		cost_lbl.size = Vector2(72, 12)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 7)
		var badge_color: Color = Color(0.3, 0.75, 0.4, 0.6) if badge_text.begins_with("+") else Color(0.45, 0.55, 0.45, 0.55)
		cost_lbl.add_theme_color_override("font_color", badge_color)
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cost_lbl)

	return btn

# ── Combat helpers (called from keybinds and buttons) ──

## Find the combat controller and use an ability
func _use_ability(slot: int) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and combat.has_method("use_ability"):
			combat.use_ability(slot)

## Find the combat controller and eat food
func _eat_food() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and combat.has_method("eat_food"):
			combat.eat_food()

# ══════════════════════════════════════════════════════════════════
# QoL: LOW HP WARNING — Red vignette that pulses when below 25% HP
# ══════════════════════════════════════════════════════════════════

var _low_hp_vignette: ColorRect = null
var _low_hp_time: float = 0.0
var _damage_flash: ColorRect = null

func _build_low_hp_vignette() -> void:
	_low_hp_vignette = ColorRect.new()
	_low_hp_vignette.name = "LowHPVignette"
	_low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-screen overlay — use explicit size since parent is CanvasLayer
	var vp_size: Vector2 = _get_viewport_size()
	_low_hp_vignette.position = Vector2.ZERO
	_low_hp_vignette.size = vp_size
	_low_hp_vignette.color = Color(0.8, 0.0, 0.0, 0.0)  # Start invisible
	_low_hp_vignette.visible = false
	add_child(_low_hp_vignette)

	# Damage flash overlay — brief red flash on taking damage
	_damage_flash = ColorRect.new()
	_damage_flash.name = "DamageFlash"
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.position = Vector2.ZERO
	_damage_flash.size = vp_size
	_damage_flash.color = Color(1.0, 0.1, 0.0, 0.0)
	_damage_flash.visible = false
	_damage_flash.z_index = 90
	add_child(_damage_flash)

func _update_low_hp_vignette(delta: float) -> void:
	if _low_hp_vignette == null:
		return
	var hp: float = float(GameState.player["hp"])
	var max_hp: float = float(GameState.player["max_hp"])
	if max_hp <= 0:
		return
	var pct: float = hp / max_hp

	if pct <= 0.25 and hp > 0:
		_low_hp_vignette.visible = true
		_low_hp_time += delta * 4.0  # Pulse speed
		# Pulse between alpha 0.05 and 0.2 — more urgent at lower HP
		var intensity: float = (1.0 - pct / 0.25) * 0.15 + 0.05
		var alpha: float = intensity * (0.5 + 0.5 * sin(_low_hp_time))
		_low_hp_vignette.color = Color(0.8, 0.0, 0.0, alpha)
	else:
		_low_hp_vignette.visible = false
		_low_hp_time = 0.0

# ══════════════════════════════════════════════════════════════════
# QoL: AREA TRANSITION TOAST — Big area name fades in center screen
# ══════════════════════════════════════════════════════════════════

var _area_toast_label: Label = null

func _build_area_toast() -> void:
	_area_toast_label = Label.new()
	_area_toast_label.name = "AreaToast"
	_area_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_area_toast_label.add_theme_font_size_override("font_size", 36)
	_area_toast_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.8, 1.0))
	_area_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_area_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_area_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	# Position in upper-center of screen
	var vp_size: Vector2 = _get_viewport_size()
	_area_toast_label.position = Vector2(0, vp_size.y * 0.18)
	_area_toast_label.size = Vector2(vp_size.x, 50)
	_area_toast_label.modulate = Color(1, 1, 1, 0)  # Start invisible
	add_child(_area_toast_label)

func _show_area_toast(area_id: String) -> void:
	if _area_toast_label == null:
		return
	var area_data: Dictionary = DataManager.get_area(area_id)
	var area_name: String = str(area_data.get("name", area_id)) if not area_data.is_empty() else area_id
	_area_toast_label.text = area_name

	# Color based on area danger level
	var danger_level: int = int(area_data.get("dangerLevel", 0))
	if "corrupted" in area_id:
		_area_toast_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	elif area_id == "the-abyss":
		_area_toast_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.9, 1.0))
	elif area_id == "alien-wastes":
		_area_toast_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1.0))
	else:
		_area_toast_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.8, 1.0))

	# Fade in, hold, fade out
	var tween: Tween = create_tween()
	_area_toast_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(_area_toast_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(_area_toast_label, "modulate:a", 0.0, 1.0)

# ══════════════════════════════════════════════════════════════════
# QoL: LEVEL-UP CELEBRATION — Gold flash + big text
# ══════════════════════════════════════════════════════════════════

var _levelup_flash: ColorRect = null
var _levelup_label: Label = null

func _build_levelup_flash() -> void:
	# Full-screen gold flash overlay
	_levelup_flash = ColorRect.new()
	_levelup_flash.name = "LevelUpFlash"
	_levelup_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-screen overlay — use explicit size since parent is CanvasLayer
	var flash_vp_size: Vector2 = _design_size
	_levelup_flash.position = Vector2.ZERO
	_levelup_flash.size = flash_vp_size
	_levelup_flash.color = Color(1.0, 0.85, 0.2, 0.0)
	_levelup_flash.visible = false
	add_child(_levelup_flash)

	# Big center text
	_levelup_label = Label.new()
	_levelup_label.name = "LevelUpLabel"
	_levelup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_levelup_label.add_theme_font_size_override("font_size", 44)
	_levelup_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	_levelup_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.8))
	_levelup_label.add_theme_constant_override("shadow_offset_x", 3)
	_levelup_label.add_theme_constant_override("shadow_offset_y", 3)
	var vp_size: Vector2 = _get_viewport_size()
	_levelup_label.position = Vector2(0, vp_size.y * 0.3)
	_levelup_label.size = Vector2(vp_size.x, 60)
	_levelup_label.modulate = Color(1, 1, 1, 0)
	add_child(_levelup_label)

func _show_levelup_flash(skill_id: String, new_level: int) -> void:
	if _levelup_flash == null or _levelup_label == null:
		return
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	var skill_name: String = str(skill_data.get("name", skill_id))

	# Flash overlay
	_levelup_flash.visible = true
	var flash_tween: Tween = create_tween()
	_levelup_flash.color = Color(1.0, 0.85, 0.2, 0.25)
	flash_tween.tween_property(_levelup_flash, "color:a", 0.0, 0.8)
	flash_tween.tween_callback(func(): _levelup_flash.visible = false)

	# Big text
	_levelup_label.text = "%s Level %d!" % [skill_name, new_level]
	var label_tween: Tween = create_tween()
	_levelup_label.modulate = Color(1, 1, 1, 0)
	# Scale punch effect via position offset
	label_tween.tween_property(_levelup_label, "modulate:a", 1.0, 0.2)
	label_tween.tween_interval(2.0)
	label_tween.tween_property(_levelup_label, "modulate:a", 0.0, 0.8)

# ══════════════════════════════════════════════════════════════════
# QoL: COMBAT STATE INDICATOR — "IN COMBAT" label + red tint
# ══════════════════════════════════════════════════════════════════

var _combat_label: Label = null
var _in_combat_state: bool = false

func _build_combat_indicator() -> void:
	_combat_label = Label.new()
	_combat_label.name = "CombatIndicator"
	_combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_label.text = "IN COMBAT"
	_combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combat_label.add_theme_font_size_override("font_size", 11)
	_combat_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.8))
	_combat_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_combat_label.add_theme_constant_override("shadow_offset_x", 1)
	_combat_label.add_theme_constant_override("shadow_offset_y", 1)
	_combat_label.position = Vector2(12, 88)
	_combat_label.size = Vector2(100, 16)
	_combat_label.visible = false
	add_child(_combat_label)

# ── Slayer task display ──
var _slayer_label: Label = null

func _build_slayer_display() -> void:
	_slayer_label = Label.new()
	_slayer_label.name = "SlayerTask"
	_slayer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slayer_label.add_theme_font_size_override("font_size", 11)
	_slayer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	_slayer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_slayer_label.add_theme_constant_override("shadow_offset_x", 1)
	_slayer_label.add_theme_constant_override("shadow_offset_y", 1)
	_slayer_label.position = Vector2(12, 108)
	_slayer_label.size = Vector2(250, 16)
	_slayer_label.visible = false
	add_child(_slayer_label)
	# Connect to enemy killed to update
	EventBus.enemy_killed.connect(_on_slayer_enemy_killed)
	# Show initial state (if save had an active task)
	call_deferred("_update_slayer_display")

func _on_slayer_enemy_killed(_eid: String, _etype: String) -> void:
	_update_slayer_display()

func _update_slayer_display() -> void:
	if _slayer_label == null:
		return
	var task: Dictionary = GameState.slayer_task
	if task.is_empty() or not task.has("remaining"):
		_slayer_label.visible = false
		return
	var remaining: int = int(task.get("remaining", 0))
	if remaining <= 0:
		_slayer_label.visible = false
		return
	var enemy_type: String = str(task.get("enemy_type", ""))
	var enemy_data: Dictionary = DataManager.get_enemy(enemy_type)
	var enemy_name: String = str(enemy_data.get("name", enemy_type))
	_slayer_label.text = "Slayer: %s (%d left)" % [enemy_name, remaining]
	_slayer_label.visible = true

func _on_combat_started(_enemy_id: String) -> void:
	_in_combat_state = true

func _on_combat_ended() -> void:
	_in_combat_state = false

func _update_combat_indicator() -> void:
	if _combat_label == null:
		return
	_combat_label.visible = _in_combat_state

# ══════════════════════════════════════════════════════════════════
# QoL: RARE LOOT TOAST — Center-screen notification for notable drops
# ══════════════════════════════════════════════════════════════════

var _loot_toast_label: Label = null
var _loot_toast_queue: Array[Dictionary] = []  # { text, color }
var _loot_toast_active: bool = false

func _build_loot_toast() -> void:
	_loot_toast_label = Label.new()
	_loot_toast_label.name = "LootToast"
	_loot_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loot_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loot_toast_label.add_theme_font_size_override("font_size", 22)
	_loot_toast_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	_loot_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_loot_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_loot_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	var vp_size: Vector2 = _get_viewport_size()
	_loot_toast_label.position = Vector2(0, vp_size.y * 0.4)
	_loot_toast_label.size = Vector2(vp_size.x, 40)
	_loot_toast_label.modulate = Color(1, 1, 1, 0)
	add_child(_loot_toast_label)

## Called when any item is added to inventory — show toast for notable items
func _on_item_added(item_id: String, quantity: int) -> void:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	# Determine rarity/tier to decide if this deserves a toast
	var tier: int = int(item_data.get("tier", 0))
	var item_name: String = str(item_data.get("name", item_id))
	var toast_color: Color
	var show_toast: bool = false

	# Tier 3+ equipment or special items get a toast
	if tier >= 4:
		toast_color = Color(1.0, 0.5, 0.1)   # Orange for high tier
		show_toast = true
	elif tier == 3:
		toast_color = Color(0.3, 0.9, 1.0)   # Cyan for mid tier
		show_toast = true

	# Check if it's a quest item or special category
	var category: String = str(item_data.get("category", ""))
	if category == "quest" or category == "unique":
		toast_color = Color(0.9, 0.6, 1.0)  # Purple for quest/unique
		show_toast = true

	if not show_toast:
		return

	var qty_text: String = " x%d" % quantity if quantity > 1 else ""
	_queue_loot_toast("+ %s%s" % [item_name, qty_text], toast_color)

## Queue a loot toast (so multiple drops don't overlap)
func _queue_loot_toast(text: String, color: Color) -> void:
	_loot_toast_queue.append({ "text": text, "color": color })
	if not _loot_toast_active:
		_show_next_loot_toast()

func _show_next_loot_toast() -> void:
	if _loot_toast_label == null or _loot_toast_queue.is_empty():
		_loot_toast_active = false
		return
	_loot_toast_active = true
	var toast: Dictionary = _loot_toast_queue.pop_front()
	_loot_toast_label.text = str(toast["text"])
	_loot_toast_label.add_theme_color_override("font_color", toast["color"] as Color)

	var tween: Tween = create_tween()
	_loot_toast_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(_loot_toast_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.5)
	tween.tween_property(_loot_toast_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_show_next_loot_toast)

# ══════════════════════════════════════════════════════════════════
# QoL: DAMAGE TAKEN / HEAL FEEDBACK — HP bar flash
# ══════════════════════════════════════════════════════════════════

func _on_player_damaged(_amount: int, _source: String) -> void:
	# Flash HP bar red briefly
	if hp_bar:
		var tween: Tween = create_tween()
		hp_bar.modulate = Color(2.0, 0.3, 0.3, 1.0)
		tween.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), 0.3)
	# Screen-edge damage flash
	if _damage_flash:
		_damage_flash.visible = true
		_damage_flash.color = Color(1.0, 0.1, 0.0, 0.15)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.25)
		flash_tween.tween_callback(func(): _damage_flash.visible = false)

func _on_player_healed(_amount: int) -> void:
	# Flash HP bar green briefly
	if hp_bar:
		var tween: Tween = create_tween()
		hp_bar.modulate = Color(0.3, 2.0, 0.3, 1.0)
		tween.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), 0.4)

# ══════════════════════════════════════════════════════════════════
# MULTIPLAYER PANEL
# ══════════════════════════════════════════════════════════════════

var _mp_action_btn: Button = null
var _mp_name_input: LineEdit = null
var _mp_server_input: LineEdit = null
var _mp_connect_btn: Button = null
var _mp_disconnect_btn: Button = null
var _mp_status_label: Label = null
var _mp_chat_input: LineEdit = null
var _mp_online_label: Label = null

## Build the contents of the multiplayer panel (connect form + chat input)
func _build_multiplayer_panel_contents() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_multiplayer_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "Multiplayer"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Status label
	_mp_status_label = Label.new()
	_mp_status_label.text = "Disconnected"
	_mp_status_label.add_theme_font_size_override("font_size", 11)
	_mp_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_mp_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mp_status_label)

	# Online count
	_mp_online_label = Label.new()
	_mp_online_label.text = ""
	_mp_online_label.add_theme_font_size_override("font_size", 10)
	_mp_online_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_mp_online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mp_online_label)

	# Name input
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Name:"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_row.add_child(name_lbl)

	_mp_name_input = LineEdit.new()
	_mp_name_input.custom_minimum_size = Vector2(180, 0)
	_mp_name_input.placeholder_text = "Your name..."
	_mp_name_input.max_length = 16
	_mp_name_input.text = str(GameState.settings.get("mp_name", ""))
	name_row.add_child(_mp_name_input)

	# Server input
	var server_row: HBoxContainer = HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 4)
	vbox.add_child(server_row)

	var server_lbl: Label = Label.new()
	server_lbl.text = "Server:"
	server_lbl.add_theme_font_size_override("font_size", 11)
	server_row.add_child(server_lbl)

	_mp_server_input = LineEdit.new()
	_mp_server_input.custom_minimum_size = Vector2(180, 0)
	_mp_server_input.text = str(GameState.settings.get("mp_server", "wss://asterian-server.onrender.com"))
	server_row.add_child(_mp_server_input)

	# Connect / Disconnect buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_mp_connect_btn = Button.new()
	_mp_connect_btn.text = "Connect"
	_mp_connect_btn.custom_minimum_size = Vector2(100, 28)
	_mp_connect_btn.pressed.connect(_on_mp_connect_pressed)
	btn_row.add_child(_mp_connect_btn)

	_mp_disconnect_btn = Button.new()
	_mp_disconnect_btn.text = "Disconnect"
	_mp_disconnect_btn.custom_minimum_size = Vector2(100, 28)
	_mp_disconnect_btn.visible = false
	_mp_disconnect_btn.pressed.connect(_on_mp_disconnect_pressed)
	btn_row.add_child(_mp_disconnect_btn)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Chat input
	var chat_row: HBoxContainer = HBoxContainer.new()
	chat_row.add_theme_constant_override("separation", 4)
	vbox.add_child(chat_row)

	_mp_chat_input = LineEdit.new()
	_mp_chat_input.custom_minimum_size = Vector2(220, 0)
	_mp_chat_input.placeholder_text = "Chat message..."
	_mp_chat_input.max_length = 200
	_mp_chat_input.text_submitted.connect(_on_mp_chat_submitted)
	chat_row.add_child(_mp_chat_input)

	var send_btn: Button = Button.new()
	send_btn.text = "Send"
	send_btn.custom_minimum_size = Vector2(50, 0)
	send_btn.pressed.connect(func(): _on_mp_chat_submitted(_mp_chat_input.text))
	chat_row.add_child(send_btn)

	# Connect EventBus signals for status updates
	EventBus.multiplayer_connected.connect(_on_mp_connected)
	EventBus.multiplayer_disconnected.connect(_on_mp_disconnected)
	EventBus.multiplayer_player_joined.connect(_on_mp_player_changed)
	EventBus.multiplayer_player_left.connect(_on_mp_player_changed)

## Connect button pressed
func _on_mp_connect_pressed() -> void:
	var mp_name: String = _mp_name_input.text.strip_edges()
	if mp_name == "":
		mp_name = "Player"
		_mp_name_input.text = mp_name
	var url: String = _mp_server_input.text.strip_edges()
	if url == "":
		url = "wss://asterian-server.onrender.com"
		_mp_server_input.text = url

	var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
	if client and client.has_method("connect_to_server"):
		client.connect_to_server(url, mp_name)
		_mp_status_label.text = "Connecting..."
		_mp_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

## Disconnect button pressed
func _on_mp_disconnect_pressed() -> void:
	var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
	if client and client.has_method("disconnect_from_server"):
		client.disconnect_from_server()

## Chat text submitted (Enter key or Send button)
func _on_mp_chat_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return
	var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
	if client and client.has_method("send_chat"):
		client.send_chat(text.strip_edges())
		# Show own message in chat
		var own_name: String = _mp_name_input.text.strip_edges()
		if own_name == "":
			own_name = "You"
		EventBus.chat_message.emit("%s: %s" % [own_name, text.strip_edges()], "multiplayer")
	_mp_chat_input.text = ""

## Called when multiplayer connects successfully
func _on_mp_connected(player_count: int) -> void:
	_mp_status_label.text = "Connected"
	_mp_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_mp_online_label.text = "%d player(s) online" % player_count
	_mp_connect_btn.visible = false
	_mp_disconnect_btn.visible = true
	if _mp_action_btn:
		_mp_action_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

## Called when multiplayer disconnects
func _on_mp_disconnected() -> void:
	_mp_status_label.text = "Disconnected"
	_mp_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_mp_online_label.text = ""
	_mp_connect_btn.visible = true
	_mp_disconnect_btn.visible = false
	if _mp_action_btn:
		_mp_action_btn.remove_theme_color_override("font_color")

## Called when a player joins or leaves — update the online count
func _on_mp_player_changed(_player_name: String) -> void:
	var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
	if client and client.has_method("is_mp_connected") and client.is_mp_connected():
		# Count remote players + self
		var remote_count: int = client.get("_remote_players").size() if client.get("_remote_players") != null else 0
		_mp_online_label.text = "%d player(s) online" % (remote_count + 1)

# ══════════════════════════════════════════════════════════════════
# QoL: TARGET INFO PANEL — Shows targeted enemy name, level, HP, style
# ══════════════════════════════════════════════════════════════════

var _target_panel: PanelContainer = null
var _target_name_label: Label = null
var _target_level_label: Label = null
var _target_hp_bar: ProgressBar = null
var _target_hp_label: Label = null
var _target_style_label: Label = null
var _target_weakness_label: Label = null

func _build_target_info_panel() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.8)
	style.border_color = Color(0.5, 0.12, 0.08, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(5)

	_target_panel = PanelContainer.new()
	_target_panel.name = "TargetInfoPanel"
	_target_panel.add_theme_stylebox_override("panel", style)
	_target_panel.visible = false
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp_w: float = _design_size.x
	_target_panel.position = Vector2(vp_w / 2.0 - 110, 38)
	_target_panel.custom_minimum_size = Vector2(220, 0)
	add_child(_target_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_target_panel.add_child(vbox)

	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	_target_name_label = Label.new()
	_target_name_label.add_theme_font_size_override("font_size", 11)
	_target_name_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.3, 0.95))
	_target_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_target_name_label)

	_target_level_label = Label.new()
	_target_level_label.add_theme_font_size_override("font_size", 10)
	_target_level_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.8))
	row1.add_child(_target_level_label)

	var hp_container: Control = Control.new()
	hp_container.custom_minimum_size = Vector2(210, 10)
	vbox.add_child(hp_container)

	_target_hp_bar = ProgressBar.new()
	_target_hp_bar.custom_minimum_size = Vector2(210, 10)
	_target_hp_bar.position = Vector2.ZERO
	_target_hp_bar.show_percentage = false
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.08, 0.03, 0.03, 0.7)
	hp_bg.set_corner_radius_all(2)
	_target_hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.65, 0.12, 0.08, 0.85)
	hp_fill.set_corner_radius_all(2)
	_target_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_container.add_child(_target_hp_bar)

	_target_hp_label = Label.new()
	_target_hp_label.add_theme_font_size_override("font_size", 9)
	_target_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	_target_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hp_label.position = Vector2(0, -1)
	_target_hp_label.size = Vector2(210, 10)
	hp_container.add_child(_target_hp_label)

	# Row 3: Style + Weakness
	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 12)
	vbox.add_child(row3)

	_target_style_label = Label.new()
	_target_style_label.add_theme_font_size_override("font_size", 10)
	_target_style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(_target_style_label)

	_target_weakness_label = Label.new()
	_target_weakness_label.add_theme_font_size_override("font_size", 10)
	row3.add_child(_target_weakness_label)

func _update_target_info() -> void:
	if _target_panel == null:
		return

	# Find the combat controller's target
	if _player == null:
		_target_panel.visible = false
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat == null:
		_target_panel.visible = false
		return

	var tgt: Node = combat.get("target")
	if tgt == null or not is_instance_valid(tgt):
		_target_panel.visible = false
		return
	# Check DEAD state (enum value 5)
	if "state" in tgt and int(tgt.state) == 5:
		_target_panel.visible = false
		return

	_target_panel.visible = true

	# Name
	var ename: String = str(tgt.enemy_name) if "enemy_name" in tgt else str(tgt.enemy_id)
	_target_name_label.text = ename

	# Level
	var elevel: int = int(tgt.level) if "level" in tgt else 1
	_target_level_label.text = "Lv %d" % elevel

	# HP (enemy uses hp / max_hp, not current_hp)
	var ehp: int = int(tgt.hp) if "hp" in tgt else 0
	var emhp: int = int(tgt.max_hp) if "max_hp" in tgt else 1
	_target_hp_bar.max_value = emhp
	_target_hp_bar.value = ehp
	_target_hp_label.text = "%d / %d" % [ehp, emhp]

	# Combat style color + text
	var estyle: String = str(tgt.combat_style) if "combat_style" in tgt else ""
	var style_color: Color
	match estyle:
		"nano":
			style_color = Color(0.3, 0.9, 1.0)
		"tesla":
			style_color = Color(1.0, 0.9, 0.2)
		"void":
			style_color = Color(0.6, 0.2, 0.9)
		_:
			style_color = Color(0.6, 0.6, 0.6)
	_target_style_label.text = estyle.capitalize() if estyle != "" else "Unknown"
	_target_style_label.add_theme_color_override("font_color", style_color)

	# Weakness (combat triangle: nano < void, tesla < nano, void < tesla)
	var weakness: String = ""
	var weak_color: Color = Color(0.3, 1.0, 0.3)
	match estyle:
		"nano":
			weakness = "Weak: Void"
			weak_color = Color(0.6, 0.2, 0.9)
		"tesla":
			weakness = "Weak: Nano"
			weak_color = Color(0.3, 0.9, 1.0)
		"void":
			weakness = "Weak: Tesla"
			weak_color = Color(1.0, 0.9, 0.2)
	_target_weakness_label.text = weakness
	_target_weakness_label.add_theme_color_override("font_color", weak_color)

# ══════════════════════════════════════════════════════════════════
# QoL: GATHERING PROGRESS LABEL — "Mining Stellarite Ore..." above bar
# ══════════════════════════════════════════════════════════════════

var _gather_label: Label = null
var _gather_skill_id: String = ""
var _gather_node_id: String = ""

func _build_gather_label() -> void:
	_gather_label = Label.new()
	_gather_label.name = "GatherLabel"
	_gather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gather_label.add_theme_font_size_override("font_size", 12)
	_gather_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
	_gather_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_gather_label.add_theme_constant_override("shadow_offset_x", 1)
	_gather_label.add_theme_constant_override("shadow_offset_y", 1)
	# Position just above the gather progress bar
	var gp_vp_h: float = _design_size.y
	_gather_label.position = Vector2(290, gp_vp_h - 88)
	_gather_label.size = Vector2(220, 20)
	_gather_label.visible = false
	add_child(_gather_label)

func _on_gathering_started(skill: String, node_id: String) -> void:
	_gather_skill_id = skill
	_gather_node_id = node_id
	if _gather_label:
		# Build a descriptive label: "Mining Stellarite Ore..."
		var skill_data: Dictionary = DataManager.get_skill(skill)
		var skill_name: String = str(skill_data.get("name", skill)).capitalize()
		# Try to get the resource name from the gathering node
		var resource_name: String = ""
		for gnode in get_tree().get_nodes_in_group("gathering_nodes"):
			if is_instance_valid(gnode) and "node_id" in gnode and str(gnode.node_id) == node_id:
				if "resource_id" in gnode:
					var item_data: Dictionary = DataManager.get_item(str(gnode.resource_id))
					resource_name = str(item_data.get("name", ""))
				break
		if resource_name != "":
			_gather_label.text = "%s %s..." % [skill_name, resource_name]
		else:
			_gather_label.text = "%s..." % skill_name
		_gather_label.visible = true

func _on_gathering_complete(_skill: String, _item_id: String) -> void:
	if _gather_label:
		# Brief flash to green on completion
		_gather_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
		_gather_label.text = "Complete!"
		var tween: Tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_callback(func():
			if _gather_label:
				_gather_label.visible = false
				_gather_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
		)

# ══════════════════════════════════════════════════════════════════
# QoL: QUEST STEP TRACKER — Persistent corner widget showing active quest
# ══════════════════════════════════════════════════════════════════

var _quest_tracker_panel: PanelContainer = null
var _quest_tracker_title: Label = null
var _quest_tracker_step: Label = null
var _quest_tracker_progress: Label = null

func _build_quest_tracker() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.75)
	style.border_color = Color(0.5, 0.3, 0.7, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)

	_quest_tracker_panel = PanelContainer.new()
	_quest_tracker_panel.name = "QuestTracker"
	_quest_tracker_panel.add_theme_stylebox_override("panel", style)
	_quest_tracker_panel.visible = false
	_quest_tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position below the minimap in top-right corner
	var vp_size: Vector2 = _get_viewport_size()
	_quest_tracker_panel.position = Vector2(vp_size.x - 250, 172)
	_quest_tracker_panel.custom_minimum_size = Vector2(230, 0)
	add_child(_quest_tracker_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_quest_tracker_panel.add_child(vbox)

	_quest_tracker_title = Label.new()
	_quest_tracker_title.add_theme_font_size_override("font_size", 11)
	_quest_tracker_title.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	_quest_tracker_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_quest_tracker_title.add_theme_constant_override("shadow_offset_x", 1)
	_quest_tracker_title.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_quest_tracker_title)

	_quest_tracker_step = Label.new()
	_quest_tracker_step.add_theme_font_size_override("font_size", 10)
	_quest_tracker_step.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	_quest_tracker_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_tracker_step.custom_minimum_size = Vector2(218, 0)
	vbox.add_child(_quest_tracker_step)

	_quest_tracker_progress = Label.new()
	_quest_tracker_progress.add_theme_font_size_override("font_size", 10)
	_quest_tracker_progress.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	vbox.add_child(_quest_tracker_progress)

	# Initial update
	_refresh_quest_tracker()

func _on_quest_tracker_update(_arg: String = "") -> void:
	_refresh_quest_tracker()

func _on_quest_progress_update(_qid: String, _step: int) -> void:
	_refresh_quest_tracker()

func _refresh_quest_tracker() -> void:
	if _quest_tracker_panel == null:
		return

	# Find the first active quest with progress info
	if GameState.active_quests.is_empty():
		_quest_tracker_panel.visible = false
		return

	var quest_sys: Node = get_tree().get_first_node_in_group("quest_system")
	if quest_sys == null:
		_quest_tracker_panel.visible = false
		return

	# Show the first active quest
	var quest_id: String = str(GameState.active_quests.keys()[0])
	var progress: Dictionary = quest_sys.get_quest_progress(quest_id) if quest_sys.has_method("get_quest_progress") else {}
	if progress.is_empty():
		_quest_tracker_panel.visible = false
		return

	_quest_tracker_panel.visible = true
	_quest_tracker_title.text = str(progress.get("name", quest_id))

	var steps: Array = progress.get("steps", [])
	var current_step: int = int(progress.get("step", 0))

	if current_step < steps.size():
		var step: Dictionary = steps[current_step]
		var desc: String = str(step.get("desc", ""))
		# Strip trailing (x/y) from desc if present
		var paren_idx: int = desc.rfind(" (")
		if paren_idx >= 0 and desc.ends_with(")"):
			desc = desc.substr(0, paren_idx)
		_quest_tracker_step.text = desc
		var current_count: int = int(step.get("current", 0))
		var required: int = int(step.get("required", 1))
		_quest_tracker_progress.text = "%d / %d" % [current_count, required]
		if step.get("done", false):
			_quest_tracker_progress.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			_quest_tracker_progress.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	elif progress.get("completable", false):
		_quest_tracker_step.text = "All objectives complete!"
		_quest_tracker_progress.text = "Return to turn in"
		_quest_tracker_progress.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		_quest_tracker_panel.visible = false

# ══════════════════════════════════════════════════════════════════
# QoL: AUTO-SAVE INDICATOR — Brief "Game Saved" toast
# ══════════════════════════════════════════════════════════════════

var _save_toast_label: Label = null

func _build_save_toast() -> void:
	_save_toast_label = Label.new()
	_save_toast_label.name = "SaveToast"
	_save_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_toast_label.text = "Game Saved"
	_save_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_toast_label.add_theme_font_size_override("font_size", 11)
	_save_toast_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.8))
	_save_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_save_toast_label.add_theme_constant_override("shadow_offset_x", 1)
	_save_toast_label.add_theme_constant_override("shadow_offset_y", 1)
	var vp_size: Vector2 = _get_viewport_size()
	_save_toast_label.position = Vector2(vp_size.x - 160, vp_size.y - 30)
	_save_toast_label.size = Vector2(150, 20)
	_save_toast_label.modulate = Color(1, 1, 1, 0)
	add_child(_save_toast_label)

func _on_game_saved() -> void:
	if _save_toast_label == null:
		return
	var tween: Tween = create_tween()
	_save_toast_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(_save_toast_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(_save_toast_label, "modulate:a", 0.0, 0.8)

# ══════════════════════════════════════════════════════════════════
# QoL: COMBAT STYLE INDICATOR + KEYBIND — Show current style, [C] to swap
# ══════════════════════════════════════════════════════════════════

var _style_indicator_label: Label = null

func _build_combat_style_indicator() -> void:
	_style_indicator_label = Label.new()
	_style_indicator_label.name = "CombatStyleIndicator"
	_style_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_indicator_label.add_theme_font_size_override("font_size", 11)
	_style_indicator_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_style_indicator_label.add_theme_constant_override("shadow_offset_x", 1)
	_style_indicator_label.add_theme_constant_override("shadow_offset_y", 1)
	# Position next to adrenaline bar
	_style_indicator_label.position = Vector2(200, 44)
	_style_indicator_label.size = Vector2(120, 16)
	add_child(_style_indicator_label)
	_update_style_indicator()

func _update_style_indicator() -> void:
	if _style_indicator_label == null:
		return
	var style: String = str(GameState.player.get("combat_style", "nano"))
	var color: Color
	match style:
		"nano":
			color = Color(0.3, 0.9, 1.0)
		"tesla":
			color = Color(1.0, 0.9, 0.2)
		"void":
			color = Color(0.6, 0.2, 0.9)
		_:
			color = Color(0.6, 0.6, 0.6)
	_style_indicator_label.text = "%s [C]" % style.capitalize()
	_style_indicator_label.add_theme_color_override("font_color", color)

func _cycle_combat_style() -> void:
	var current: String = str(GameState.player.get("combat_style", "nano"))
	var styles: Array[String] = ["nano", "tesla", "void"]
	var idx: int = styles.find(current)
	var next_idx: int = (idx + 1) % styles.size()
	GameState.player["combat_style"] = styles[next_idx]
	_update_style_indicator()
	EventBus.chat_message.emit("Combat style: %s" % styles[next_idx].capitalize(), "combat")
	# Flash the label for feedback
	if _style_indicator_label:
		var tween: Tween = create_tween()
		_style_indicator_label.modulate = Color(2.0, 2.0, 2.0, 1.0)
		tween.tween_property(_style_indicator_label, "modulate", Color(1, 1, 1, 1), 0.3)

# ══════════════════════════════════════════════════════════════════
# CONTEXT MENU — Right-click popup with action options
# ══════════════════════════════════════════════════════════════════

## Build the context menu panel (hidden until right-click triggers it)
func _build_context_menu() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.06, 0.92)
	style.border_color = Color(0.08, 0.2, 0.3, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(3)
	style.content_margin_top = 2
	style.content_margin_bottom = 3

	_context_menu = PanelContainer.new()
	_context_menu.name = "ContextMenu"
	_context_menu.add_theme_stylebox_override("panel", style)
	_context_menu.visible = false
	_context_menu.z_index = 110
	add_child(_context_menu)

	_context_menu_vbox = VBoxContainer.new()
	_context_menu_vbox.add_theme_constant_override("separation", 1)
	_context_menu.add_child(_context_menu_vbox)

	_context_menu_title = Label.new()
	_context_menu_title.add_theme_font_size_override("font_size", 11)
	_context_menu_title.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85, 0.9))
	_context_menu_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_context_menu_title.add_theme_constant_override("shadow_offset_x", 1)
	_context_menu_title.add_theme_constant_override("shadow_offset_y", 1)
	_context_menu_title.visible = false
	_context_menu_vbox.add_child(_context_menu_title)

## Handle context menu request from EventBus
func _on_context_menu_requested(options: Array, global_pos: Vector2) -> void:
	if _context_menu == null or _context_menu_vbox == null:
		return

	# Clear old options (keep title label at index 0)
	while _context_menu_vbox.get_child_count() > 1:
		var child: Node = _context_menu_vbox.get_child(_context_menu_vbox.get_child_count() - 1)
		_context_menu_vbox.remove_child(child)
		child.queue_free()

	# Check for title entry
	_context_menu_title.visible = false
	for opt in options:
		if opt is Dictionary and opt.has("title"):
			_context_menu_title.text = str(opt["title"])
			if opt.has("title_color"):
				_context_menu_title.add_theme_color_override("font_color", opt["title_color"])
			else:
				_context_menu_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
			_context_menu_title.visible = true
			break

	# Separator after title
	if _context_menu_title.visible:
		var sep: ColorRect = ColorRect.new()
		sep.color = Color(0.1, 0.2, 0.3, 0.25)
		sep.custom_minimum_size = Vector2(130, 1)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_context_menu_vbox.add_child(sep)

	for opt in options:
		if not opt is Dictionary:
			continue
		if opt.has("title"):
			continue

		var label_text: String = str(opt.get("label", "Action"))
		var icon_text: String = str(opt.get("icon", ""))
		var label_color: Color = Color(0.7, 0.75, 0.8, 0.9)
		if opt.has("color"):
			label_color = opt["color"]
			label_color.a = minf(label_color.a, 0.9)
		var keybind: String = str(opt.get("keybind", ""))

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(140, 24)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_normal: StyleBoxFlat = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		btn_normal.set_corner_radius_all(2)
		btn_normal.set_content_margin_all(2)
		btn_normal.content_margin_left = 5
		btn.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.06, 0.1, 0.18, 0.7)
		btn_hover.set_corner_radius_all(2)
		btn_hover.set_content_margin_all(2)
		btn_hover.content_margin_left = 5
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed: StyleBoxFlat = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.08, 0.15, 0.25, 0.7)
		btn_pressed.set_corner_radius_all(2)
		btn_pressed.set_content_margin_all(2)
		btn_pressed.content_margin_left = 5
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		# Build text: "[icon] label   keybind"
		var display_text: String = ""
		if icon_text != "":
			display_text = "%s  %s" % [icon_text, label_text]
		else:
			display_text = label_text
		if keybind != "":
			display_text += "  [%s]" % keybind

		btn.text = display_text
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", label_color)
		btn.add_theme_color_override("font_hover_color", label_color.lightened(0.25))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Connect callback
		if opt.has("callback") and opt["callback"] is Callable:
			var cb: Callable = opt["callback"]
			btn.pressed.connect(func():
				_hide_context_menu()
				cb.call()
			)
		else:
			btn.pressed.connect(_hide_context_menu)

		_context_menu_vbox.add_child(btn)

	# Show and position
	_context_menu.visible = true

	# Position near cursor (wait a frame for size calc)
	await get_tree().process_frame
	var viewport_size: Vector2 = _design_size
	var menu_size: Vector2 = _context_menu.size
	var pos: Vector2 = global_pos + Vector2(2, 2)

	if pos.x + menu_size.x > viewport_size.x:
		pos.x = global_pos.x - menu_size.x - 2
	if pos.y + menu_size.y > viewport_size.y:
		pos.y = global_pos.y - menu_size.y - 2
	pos.x = maxf(0, pos.x)
	pos.y = maxf(0, pos.y)

	_context_menu.position = pos

## Hide the context menu
func _hide_context_menu() -> void:
	if _context_menu:
		_context_menu.visible = false

## Close context menu when clicking outside it
func _input(event: InputEvent) -> void:
	if _context_menu == null or not _context_menu.visible:
		return

	# Close on any mouse click outside the menu
	if event is InputEventMouseButton and event.pressed:
		var mouse: Vector2 = event.position
		var rect: Rect2 = Rect2(_context_menu.global_position, _context_menu.size)
		if not rect.has_point(mouse):
			_hide_context_menu()

	# Close on Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_context_menu()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════
# PANEL LAYOUT — Save/restore panel positions, visibility, and lock state
# ══════════════════════════════════════════════════════════════════

## Get mapping of panel names to panel instances
func _get_panel_map() -> Dictionary:
	return {
		"inventory": _inventory_panel,
		"equipment": _equipment_panel,
		"skills": _skills_panel,
		"quests": _quest_panel,
		"bestiary": _bestiary_panel,
		"prestige": _prestige_panel,
		"dungeon": _dungeon_panel,
		"pets": _pet_panel,
		"settings": _settings_panel,
	}

## Save one panel's current state to GameState.panel_layout
func _save_panel_state(panel: PanelContainer, panel_name: String) -> void:
	if panel == null:
		return
	var header: DraggableHeader = panel.get_node_or_null("DragHeader") as DraggableHeader
	var locked: bool = false
	if header:
		locked = header._is_locked
	GameState.panel_layout[panel_name] = {
		"x": panel.position.x,
		"y": panel.position.y,
		"visible": panel.visible,
		"locked": locked,
	}

## Save ALL panel states at once
func _save_all_panel_states() -> void:
	var panel_map: Dictionary = _get_panel_map()
	for panel_name in panel_map:
		_save_panel_state(panel_map[panel_name], panel_name)

## Restore panel positions, visibility, and lock state from GameState
func _restore_panel_layout() -> void:
	var panel_map: Dictionary = _get_panel_map()
	for panel_name in panel_map:
		var panel: PanelContainer = panel_map[panel_name]
		if panel == null:
			continue
		if not GameState.panel_layout.has(panel_name):
			continue
		var layout: Dictionary = GameState.panel_layout[panel_name]

		# Clear any anchors/presets so position is respected
		panel.anchors_preset = Control.PRESET_TOP_LEFT
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 0.0
		panel.anchor_bottom = 0.0

		# Restore position
		var x: float = float(layout.get("x", panel.position.x))
		var y: float = float(layout.get("y", panel.position.y))
		panel.position = Vector2(x, y)

		# Restore visibility
		var vis: bool = bool(layout.get("visible", false))
		panel.visible = vis
		if vis and panel.has_method("refresh"):
			panel.refresh()

		# Restore lock state
		var locked: bool = bool(layout.get("locked", false))
		var header: DraggableHeader = panel.get_node_or_null("DragHeader") as DraggableHeader
		if header:
			header.set_locked(locked)

## Wire drag-end callbacks so panel positions save after dragging
func _wire_panel_drag_callbacks() -> void:
	var panel_map: Dictionary = _get_panel_map()
	for panel_name in panel_map:
		var panel: PanelContainer = panel_map[panel_name]
		if panel == null:
			continue
		# Deferred call — headers are created inside _ready, which runs after add_child
		panel.ready.connect(_bind_drag_callback.bind(panel, panel_name), CONNECT_ONE_SHOT)

## Bind the drag-end callback to a panel's header (called after panel._ready)
func _bind_drag_callback(panel: PanelContainer, panel_name: String) -> void:
	var header: DraggableHeader = panel.get_node_or_null("DragHeader") as DraggableHeader
	if header:
		header._on_drag_end = func(): _save_panel_state(panel, panel_name)

## When a panel opens or closes, save its state
func _on_panel_state_changed(panel_name: String) -> void:
	var panel_map: Dictionary = _get_panel_map()
	if panel_map.has(panel_name):
		_save_panel_state(panel_map[panel_name], panel_name)

# ══════════════════════════════════════════════════════════════════
# HOVER TEXT — Shows entity name/info when mouse hovers in 3D world
# ══════════════════════════════════════════════════════════════════

## Build the hover text label (follows mouse, shows entity name)
func _build_hover_label() -> void:
	_hover_label = Label.new()
	_hover_label.name = "HoverLabel"
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.add_theme_font_size_override("font_size", 13)
	_hover_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 0.95))
	_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	_hover_label.visible = false
	_hover_label.z_index = 90
	add_child(_hover_label)

## Update hover label by raycasting from mouse position
func _update_hover_label() -> void:
	if _hover_label == null:
		return

	# Throttle raycasts to ~20 per second
	_hover_raycast_timer -= get_process_delta_time()
	if _hover_raycast_timer > 0 and _hover_label.visible:
		# Just update position, skip raycast
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		_hover_label.position = mouse_pos + Vector2(16, -24)
		return
	_hover_raycast_timer = 0.05

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_hover_label.visible = false
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# Don't hover when over UI panels
	# Simple check: if mouse is in top 42px (top bar) or bottom 55px (bottom bar + action bar)
	var vp_size: Vector2 = _get_viewport_size()
	if mouse_pos.y < 42 or mouse_pos.y > vp_size.y - 55:
		_hover_label.visible = false
		_hover_target = null
		return

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state

	# Check enemies (mask 4), NPCs (mask 8), ground items (mask 16)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	query.collision_mask = 4 | 8 | 16  # Enemies + NPCs + ground items
	if _player:
		query.exclude = [_player.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		_hover_label.visible = false
		_hover_target = null
		return

	var hit_node: Node = result.collider

	# Walk up to find entity root
	var entity: Node = null
	var hover_text: String = ""
	var hover_color: Color = Color(1.0, 0.95, 0.8)

	# Check enemies
	var check_node: Node = hit_node
	while check_node and not check_node.is_in_group("enemies"):
		check_node = check_node.get_parent()
	if check_node and check_node.is_in_group("enemies"):
		entity = check_node
		var edata: Dictionary = DataManager.get_enemy(check_node.enemy_id)
		var ename: String = str(edata.get("name", check_node.enemy_id))
		var elevel: int = int(edata.get("level", 1))
		var estyle: String = str(edata.get("combatStyle", ""))
		hover_text = "%s (Lv %d)" % [ename, elevel]
		# Color by combat style
		match estyle:
			"nano":  hover_color = Color(0.3, 0.9, 1.0)
			"tesla": hover_color = Color(1.0, 0.8, 0.2)
			"void":  hover_color = Color(0.8, 0.3, 1.0)
			_:       hover_color = Color(1.0, 0.4, 0.3)

	# Check NPCs
	if entity == null:
		check_node = hit_node
		while check_node and not check_node.is_in_group("npcs"):
			check_node = check_node.get_parent()
		if check_node and check_node.is_in_group("npcs"):
			entity = check_node
			var npc_name: String = str(check_node.npc_name) if "npc_name" in check_node else "NPC"
			hover_text = npc_name
			hover_color = Color(0.3, 0.95, 0.7)

	# Check ground items
	if entity == null:
		check_node = hit_node
		while check_node and not check_node.is_in_group("ground_items"):
			check_node = check_node.get_parent()
		if check_node:
			entity = check_node
			var gitem_id: String = str(check_node.get_meta("item_id", ""))
			var gitem_data: Dictionary = DataManager.get_item(gitem_id)
			var gitem_name: String = str(gitem_data.get("name", gitem_id))
			var gitem_qty: int = int(check_node.get_meta("quantity", 1))
			var qty_text: String = " x%d" % gitem_qty if gitem_qty > 1 else ""
			hover_text = "%s%s" % [gitem_name, qty_text]
			# Color by tier
			var tier: int = int(gitem_data.get("tier", 1))
			var tiers: Dictionary = DataManager.equipment_data.get("tiers", {})
			if tiers.has(str(tier)):
				hover_color = Color.html(str(tiers[str(tier)].get("color", "#cccccc")))
			else:
				hover_color = Color(0.7, 0.85, 0.7)

	# Check gathering nodes
	if entity == null:
		check_node = hit_node
		while check_node and not check_node.is_in_group("gathering_nodes"):
			check_node = check_node.get_parent()
		if check_node and check_node.is_in_group("gathering_nodes"):
			entity = check_node
			var gres_id: String = str(check_node.resource_id) if "resource_id" in check_node else ""
			var gres_data: Dictionary = DataManager.get_item(gres_id)
			var gres_name: String = str(gres_data.get("name", gres_id))
			var gskill_id: String = str(check_node.skill_id) if "skill_id" in check_node else ""
			var gskill_data: Dictionary = DataManager.get_skill(gskill_id)
			var gskill_name: String = str(gskill_data.get("name", gskill_id))
			var glevel: int = int(check_node.skill_level) if "skill_level" in check_node else 1
			var is_depleted: bool = check_node._is_depleted if "_is_depleted" in check_node else false
			if is_depleted:
				hover_text = "%s (Depleted)" % gres_name
				hover_color = Color(0.5, 0.5, 0.5)
			elif check_node.has_method("can_gather") and check_node.can_gather():
				hover_text = "%s — Lv %d %s" % [gres_name, glevel, gskill_name]
				hover_color = Color(0.9, 0.8, 0.4)
			else:
				hover_text = "%s — Lv %d %s (Req)" % [gres_name, glevel, gskill_name]
				hover_color = Color(0.7, 0.3, 0.3)

	if entity == null or hover_text == "":
		_hover_label.visible = false
		_hover_target = null
		return

	_hover_target = entity
	_hover_label.text = hover_text
	_hover_label.add_theme_color_override("font_color", hover_color)

	# Position the label above the mouse cursor
	_hover_label.position = mouse_pos + Vector2(16, -24)

	# Clamp to viewport
	var label_size: Vector2 = _hover_label.size
	if _hover_label.position.x + label_size.x > vp_size.x:
		_hover_label.position.x = mouse_pos.x - label_size.x - 8
	if _hover_label.position.y < 0:
		_hover_label.position.y = mouse_pos.y + 16

	_hover_label.visible = true

# ── Additional keybind helpers ──

## Toggle run/walk mode
func _toggle_run() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.is_running = not _player.is_running
		var mode: String = "Running" if _player.is_running else "Walking"
		EventBus.chat_message.emit(mode, "system")

## Target nearest enemy within aggro range
func _target_nearest_enemy() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return

	var combat: Node = _player.get_node_or_null("CombatController")
	if combat == null:
		return

	var nearest: Node = null
	var nearest_dist: float = 20.0  # Max tab-targeting range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.state == enemy.State.DEAD:
			continue
		var dist: float = _player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest and combat.has_method("_set_target"):
		combat._set_target(nearest)
		# Walk toward it
		_player.move_target = nearest.global_position
		_player.is_moving = true
		EventBus.chat_message.emit("Targeting: %s" % str(nearest.enemy_id), "combat")
	else:
		EventBus.chat_message.emit("No enemies nearby.", "system")

## Deselect current target
func _deselect_target() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and combat.has_method("_clear_target"):
			combat._clear_target()
		_player.is_moving = false

## Close all open panels
func _close_all_panels() -> void:
	var panels: Array = [
		_inventory_panel, _equipment_panel, _skills_panel,
		_quest_panel, _bestiary_panel, _prestige_panel,
		_dungeon_panel, _pet_panel, _settings_panel,
		_multiplayer_panel, _dialogue_panel, _shop_panel,
		_crafting_panel, _bank_panel
	]
	for panel in panels:
		if panel and panel.visible:
			panel.visible = false

## Handle window resize — reposition anchored elements
func _on_window_resized() -> void:
	# Reposition minimap to top-right corner
	_resize_minimap()
	# Reposition action bar to bottom-center
	_reposition_action_bar()
	# Reposition chat to bottom-left
	_reposition_chat()

## Reposition the bottom action bar to horizontal center
func _reposition_action_bar() -> void:
	if _action_bar_bg == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	_action_bar_bg.position = Vector2(vp_size.x / 2.0 - 380, vp_size.y - 52)

## Cycle minimap zoom level (small → medium → large)
var _minimap_zoom_level: int = 0  # 0=small (160), 1=medium (220), 2=large (300)

func _cycle_minimap_zoom() -> void:
	_minimap_zoom_level = (_minimap_zoom_level + 1) % 3
	_resize_minimap()

func _resize_minimap() -> void:
	if _minimap_container == null or _minimap_viewport == null:
		return

	var sizes: Array[int] = [160, 220, 300]
	var cam_sizes: Array[float] = [40.0, 60.0, 90.0]
	var map_size: int = sizes[_minimap_zoom_level]
	var cam_size: float = cam_sizes[_minimap_zoom_level]

	# Update container position and size (use actual viewport, not design size)
	var vp_size: Vector2 = _get_viewport_size()
	_minimap_container.position = Vector2(vp_size.x - map_size - 16, 4)
	_minimap_container.custom_minimum_size = Vector2(map_size, map_size)

	# Update viewport size
	_minimap_viewport.size = Vector2i(map_size - 6, map_size - 22)

	# Update camera orthographic size
	if _minimap_camera:
		_minimap_camera.size = cam_size

	# Update TextureRect size directly
	if _minimap_tex_rect:
		_minimap_tex_rect.custom_minimum_size = Vector2(map_size - 6, map_size - 22)

	# Update player dot position (centered)
	if _minimap_player_dot:
		_minimap_player_dot.position = Vector2(
			(map_size - 6) / 2.0 - 3,
			-((map_size - 22) / 2.0) - 3
		)

	# Move quest tracker below minimap
	if _quest_tracker_panel:
		_quest_tracker_panel.position.y = map_size + 12

	EventBus.chat_message.emit("Minimap: %s" % ["Small", "Medium", "Large"][_minimap_zoom_level], "system")

# ══════════════════════════════════════════════════════════════════
# MINIMAP — Top-right corner with SubViewport showing top-down view
# ══════════════════════════════════════════════════════════════════

var _minimap_container: PanelContainer = null
var _minimap_viewport: SubViewport = null
var _minimap_camera: Camera3D = null
var _minimap_player_dot: ColorRect = null
var _minimap_area_label: Label = null
var _minimap_tex_rect: TextureRect = null
var _minimap_enemy_dots: Array[ColorRect] = []
var _minimap_npc_dots: Array[ColorRect] = []
var _minimap_dot_container: Control = null
const MINIMAP_DOT_POOL_SIZE: int = 30

# ── Full map panel ──
var _full_map_panel: PanelContainer = null
var _full_map_viewport: SubViewport = null
var _full_map_camera: Camera3D = null

func _build_minimap() -> void:
	var map_size: int = 150

	# Outer panel — clean, minimal
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.04, 0.75)
	style.border_color = Color(0.08, 0.15, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)

	_minimap_container = PanelContainer.new()
	_minimap_container.name = "MinimapPanel"
	_minimap_container.add_theme_stylebox_override("panel", style)
	_minimap_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through
	var vp_size: Vector2 = _get_viewport_size()
	_minimap_container.position = Vector2(vp_size.x - map_size - 16, 4)
	_minimap_container.custom_minimum_size = Vector2(map_size, map_size)
	add_child(_minimap_container)

	# Handle minimap click-to-walk
	_minimap_container.gui_input.connect(_on_minimap_click)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_container.add_child(inner)

	# Minimap viewport rendered in a TextureRect
	_minimap_viewport = SubViewport.new()
	_minimap_viewport.name = "MinimapViewport"
	_minimap_viewport.size = Vector2i(map_size - 6, map_size - 22)
	_minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_minimap_viewport.transparent_bg = false
	var main_world: World3D = get_viewport().find_world_3d()
	if main_world:
		_minimap_viewport.world_3d = main_world
	add_child(_minimap_viewport)

	# Camera looking straight down — will auto-rotate with main camera
	_minimap_camera = Camera3D.new()
	_minimap_camera.name = "MinimapCam"
	_minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_minimap_camera.size = 40.0
	_minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
	_minimap_camera.position = Vector3(0, 50, 0)
	_minimap_camera.near = 0.1
	_minimap_camera.far = 200.0
	_minimap_viewport.add_child(_minimap_camera)

	# TextureRect to display the viewport
	_minimap_tex_rect = TextureRect.new()
	_minimap_tex_rect.name = "MinimapTex"
	_minimap_tex_rect.custom_minimum_size = Vector2(map_size - 6, map_size - 22)
	_minimap_tex_rect.texture = _minimap_viewport.get_texture()
	_minimap_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_minimap_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_minimap_tex_rect)

	# Centered player dot overlay (triangle pointing forward)
	var dot_container: Control = Control.new()
	dot_container.custom_minimum_size = Vector2(map_size - 6, 0)
	dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(dot_container)

	_minimap_player_dot = ColorRect.new()
	_minimap_player_dot.color = Color(0.1, 1.0, 0.3, 0.9)
	_minimap_player_dot.size = Vector2(6, 6)
	_minimap_player_dot.position = Vector2((map_size - 6) / 2.0 - 3, -((map_size - 22) / 2.0) - 3)
	_minimap_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_container.add_child(_minimap_player_dot)

	# Entity dot overlay container (for enemies and NPCs)
	_minimap_dot_container = Control.new()
	_minimap_dot_container.name = "DotOverlay"
	_minimap_dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_dot_container.custom_minimum_size = Vector2(map_size - 6, 0)
	dot_container.add_child(_minimap_dot_container)

	# Pre-create enemy dots (red)
	for _i in range(MINIMAP_DOT_POOL_SIZE):
		var edot: ColorRect = ColorRect.new()
		edot.color = Color(1.0, 0.2, 0.1, 0.9)
		edot.size = Vector2(4, 4)
		edot.visible = false
		edot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_dot_container.add_child(edot)
		_minimap_enemy_dots.append(edot)

	# Pre-create NPC dots (cyan)
	for _i in range(8):
		var ndot: ColorRect = ColorRect.new()
		ndot.color = Color(0.2, 0.9, 1.0, 0.9)
		ndot.size = Vector2(5, 5)
		ndot.visible = false
		ndot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_dot_container.add_child(ndot)
		_minimap_npc_dots.append(ndot)

	# Bottom row: area label + legend + map button
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bottom_row)

	_minimap_area_label = Label.new()
	_minimap_area_label.name = "MinimapArea"
	_minimap_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_area_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap_area_label.add_theme_font_size_override("font_size", 8)
	_minimap_area_label.add_theme_color_override("font_color", Color(0.35, 0.55, 0.65, 0.6))
	_minimap_area_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(_minimap_area_label)

	var map_btn: Button = Button.new()
	map_btn.text = "M"
	map_btn.add_theme_font_size_override("font_size", 9)
	map_btn.tooltip_text = "Open Map"
	map_btn.custom_minimum_size = Vector2(18, 12)
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.05, 0.08, 0.15, 0.5)
	btn_style.set_corner_radius_all(2)
	btn_style.set_content_margin_all(1)
	map_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.1, 0.18, 0.3, 0.7)
	map_btn.add_theme_stylebox_override("hover", btn_hover)
	map_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8, 0.7))
	map_btn.add_theme_color_override("font_hover_color", Color(0.5, 0.75, 0.95))
	map_btn.pressed.connect(_toggle_full_map)
	bottom_row.add_child(map_btn)

	# Legend row — minimal
	var legend: HBoxContainer = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 3)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(legend)

	var legend_items: Array = [
		{"color": Color(0.1, 0.85, 0.3, 0.8), "label": "You"},
		{"color": Color(0.9, 0.2, 0.1, 0.8), "label": "Foe"},
		{"color": Color(0.2, 0.8, 0.9, 0.8), "label": "NPC"},
	]
	for item in legend_items:
		var ldot: ColorRect = ColorRect.new()
		ldot.custom_minimum_size = Vector2(4, 4)
		ldot.color = item["color"]
		ldot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(ldot)
		var lbl: Label = Label.new()
		lbl.text = item["label"]
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 0.6))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(lbl)

## Handle click on minimap — convert to world position and walk there
func _on_minimap_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player == null or _minimap_camera == null or _minimap_tex_rect == null:
			return

		# Get click position relative to the minimap texture
		var local_pos: Vector2 = _minimap_tex_rect.get_local_mouse_position()
		var tex_size: Vector2 = _minimap_tex_rect.size

		# Normalize to -0.5..+0.5
		var norm_x: float = (local_pos.x / tex_size.x) - 0.5
		var norm_y: float = (local_pos.y / tex_size.y) - 0.5

		# Convert to world offset.
		# Godot orthographic camera.size = vertical extent in world units.
		# Horizontal extent = size * aspect_ratio.
		var cam_size: float = _minimap_camera.size
		var aspect: float = tex_size.x / tex_size.y if tex_size.y > 0 else 1.0
		var offset_x: float = norm_x * cam_size * aspect
		var offset_z: float = norm_y * cam_size

		# The minimap camera is rotated to match the main camera.
		# Screen-space offsets are in the camera's local frame, so we
		# need the INVERSE rotation (negate the angle) to get world offsets.
		var cam_rot_y: float = _minimap_camera.global_rotation.y
		var cos_r: float = cos(-cam_rot_y)
		var sin_r: float = sin(-cam_rot_y)
		var world_x: float = _player.global_position.x + offset_x * cos_r - offset_z * sin_r
		var world_z: float = _player.global_position.z + offset_x * sin_r + offset_z * cos_r

		# Set player walk target
		_player.move_target = Vector3(world_x, 0.0, world_z)
		_player.is_moving = true

		# Consume the event
		get_viewport().set_input_as_handled()

## Toggle the full world map overlay
func _toggle_full_map() -> void:
	if _full_map_panel and is_instance_valid(_full_map_panel):
		_full_map_panel.visible = not _full_map_panel.visible
		if _full_map_panel.visible and _full_map_camera:
			_full_map_camera.global_position = Vector3(_player.global_position.x if _player else 0.0, 200.0, _player.global_position.z if _player else 0.0)
		# Save visibility state
		_save_full_map_state()
		return

	# Build full map panel
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	panel_style.border_color = Color(0.15, 0.35, 0.5, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(8)

	_full_map_panel = PanelContainer.new()
	_full_map_panel.name = "FullMapPanel"
	_full_map_panel.add_theme_stylebox_override("panel", panel_style)
	_full_map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_full_map_panel.custom_minimum_size = Vector2(600, 500)
	add_child(_full_map_panel)

	# Restore saved position or use default
	var saved: Dictionary = GameState.panel_layout.get("world_map", {}) as Dictionary
	var default_x: float = 200.0
	var default_y: float = 60.0
	_full_map_panel.position = Vector2(
		float(saved.get("x", default_x)),
		float(saved.get("y", default_y))
	)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_full_map_panel.add_child(vbox)

	# Draggable header with close button (replaces old title row)
	var header: DraggableHeader = DraggableHeader.attach(
		_full_map_panel, "World Map",
		func(): _full_map_panel.visible = false; _save_full_map_state()
	)
	header._on_drag_end = func(): _save_full_map_state()
	vbox.add_child(header)
	vbox.move_child(header, 0)

	# Restore lock state
	var locked: bool = bool(saved.get("locked", false))
	header.set_locked(locked)

	# Map viewport
	_full_map_viewport = SubViewport.new()
	_full_map_viewport.name = "FullMapViewport"
	_full_map_viewport.size = Vector2i(580, 440)
	_full_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_full_map_viewport.transparent_bg = false
	var main_world: World3D = get_viewport().find_world_3d()
	if main_world:
		_full_map_viewport.world_3d = main_world
	add_child(_full_map_viewport)

	_full_map_camera = Camera3D.new()
	_full_map_camera.name = "FullMapCam"
	_full_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_full_map_camera.size = 300.0
	_full_map_camera.rotation_degrees = Vector3(-90, 0, 0)
	_full_map_camera.position = Vector3(_player.global_position.x if _player else 0.0, 200.0, _player.global_position.z if _player else 0.0)
	_full_map_camera.near = 0.1
	_full_map_camera.far = 500.0
	_full_map_viewport.add_child(_full_map_camera)

	var map_tex: TextureRect = TextureRect.new()
	map_tex.custom_minimum_size = Vector2(580, 440)
	map_tex.texture = _full_map_viewport.get_texture()
	map_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(map_tex)

## Save the full world map panel's position and state
func _save_full_map_state() -> void:
	if _full_map_panel == null:
		return
	var header: DraggableHeader = _full_map_panel.get_node_or_null("DragHeader") as DraggableHeader
	var locked: bool = false
	if header:
		locked = header._is_locked
	GameState.panel_layout["world_map"] = {
		"x": _full_map_panel.position.x,
		"y": _full_map_panel.position.y,
		"visible": _full_map_panel.visible,
		"locked": locked,
	}

func _update_minimap() -> void:
	if _minimap_camera == null or _player == null:
		return

	# Ensure the viewport shares the 3D world
	if _minimap_viewport and _minimap_viewport.world_3d == null:
		var main_world: World3D = get_viewport().find_world_3d()
		if main_world:
			_minimap_viewport.world_3d = main_world

	# Follow player position (camera looks straight down)
	_minimap_camera.global_position = Vector3(_player.global_position.x, 50.0, _player.global_position.z)

	# Auto-rotate minimap with main camera
	var main_cam: Camera3D = _player.get_viewport().get_camera_3d()
	if main_cam:
		_minimap_camera.global_rotation.y = main_cam.global_rotation.y

	# Update area label on minimap
	if _minimap_area_label:
		var area_data: Dictionary = DataManager.get_area(GameState.current_area)
		_minimap_area_label.text = str(area_data.get("name", GameState.current_area)) if not area_data.is_empty() else GameState.current_area

	# Update entity dots on minimap
	_update_minimap_dots()

	# Update full map camera if visible
	if _full_map_panel and _full_map_panel.visible and _full_map_camera:
		_full_map_camera.global_position = Vector3(_player.global_position.x, 200.0, _player.global_position.z)

## Update enemy/NPC dot positions on minimap overlay
func _update_minimap_dots() -> void:
	if _minimap_camera == null or _minimap_tex_rect == null or _player == null:
		return
	if _minimap_dot_container == null:
		return

	var cam_size: float = _minimap_camera.size
	var tex_size: Vector2 = _minimap_tex_rect.size
	var player_pos: Vector3 = _player.global_position
	var cam_rot_y: float = _minimap_camera.global_rotation.y
	var cos_r: float = cos(-cam_rot_y)
	var sin_r: float = sin(-cam_rot_y)

	# Hide all dots first
	for dot in _minimap_enemy_dots:
		dot.visible = false
	for dot in _minimap_npc_dots:
		dot.visible = false

	# Plot enemies (red dots)
	var idx: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if idx >= _minimap_enemy_dots.size():
			break
		if not is_instance_valid(enemy):
			continue
		if "state" in enemy and enemy.state == enemy.State.DEAD:
			continue
		var dx: float = enemy.global_position.x - player_pos.x
		var dz: float = enemy.global_position.z - player_pos.z
		var rx: float = dx * cos_r - dz * sin_r
		var rz: float = dx * sin_r + dz * cos_r
		var px: float = (rx / cam_size) * tex_size.x + tex_size.x * 0.5
		var py: float = (rz / cam_size) * tex_size.y + tex_size.y * 0.5
		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			_minimap_enemy_dots[idx].position = Vector2(px - 2, -(tex_size.y) + py - 2)
			_minimap_enemy_dots[idx].visible = true
			idx += 1

	# Plot NPCs (cyan dots)
	idx = 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if idx >= _minimap_npc_dots.size():
			break
		if not is_instance_valid(npc):
			continue
		var dx: float = npc.global_position.x - player_pos.x
		var dz: float = npc.global_position.z - player_pos.z
		var rx: float = dx * cos_r - dz * sin_r
		var rz: float = dx * sin_r + dz * cos_r
		var px: float = (rx / cam_size) * tex_size.x + tex_size.x * 0.5
		var py: float = (rz / cam_size) * tex_size.y + tex_size.y * 0.5
		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			_minimap_npc_dots[idx].position = Vector2(px - 2, -(tex_size.y) + py - 2)
			_minimap_npc_dots[idx].visible = true
			idx += 1
