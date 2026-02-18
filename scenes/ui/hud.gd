## HUD — Top-level UI overlay showing area name, player info, panels, and minimap placeholder
##
## Listens to EventBus signals to update display.
## Hosts inventory, equipment, skills, dialogue, shop, crafting panels and tooltip.
## Keybinds: I = inventory, E = equipment, K = skills
extends CanvasLayer

# ── Stat bars & labels (built in code, absolute positioned) ──
var hp_bar: ProgressBar = null
var energy_bar: ProgressBar = null
var level_label: Label = null
var credits_label: Label = null
var fps_label: Label = null
var pos_label: Label = null

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
var _achievement_panel: PanelContainer = null
var _multiplayer_panel: PanelContainer = null
var _tooltip_panel: PanelContainer = null
var _tutorial_panel: PanelContainer = null
var _world_map_panel: PanelContainer = null
var _combat_log_panel: PanelContainer = null
var _dps_meter: PanelContainer = null
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
var achievement_script: GDScript = preload("res://scripts/ui/achievement_panel.gd")
var tooltip_script: GDScript = preload("res://scripts/ui/tooltip_panel.gd")
var tutorial_script: GDScript = preload("res://scripts/ui/tutorial_panel.gd")
var world_map_script: GDScript = preload("res://scripts/ui/world_map_panel.gd")
var combat_log_script: GDScript = preload("res://scripts/ui/combat_log_panel.gd")
var dps_meter_script: GDScript = preload("res://scripts/ui/dps_meter.gd")
# context_menu is built inline in _build_context_menu()

# ── Chat log ──
var _chat_bg: PanelContainer = null
var _chat_container: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_messages: Array[Label] = []
var _max_chat_lines: int = 50
var _chat_input: LineEdit = null
var _chat_typing: bool = false  # True when chat input is focused
var _chat_drag_header: DraggableHeader = null
var _chat_resize_handle: Control = null
var _chat_resizing: bool = false
var _chat_resize_start: Vector2 = Vector2.ZERO
var _chat_size_start: Vector2 = Vector2.ZERO

## Overlaid HP/Energy text labels (drawn on top of progress bars)
var _hp_text: Label = null
var _energy_text: Label = null

## Buff display — shows active food/consumable buffs above stat bars
var _buff_container: HBoxContainer = null
var _buff_labels: Dictionary = {}  # { buff_type: { "panel": PanelContainer, "icon": Label, "text": Label } }

## Chat filter state — which categories are visible
var _chat_filters: Dictionary = {
	"all": true, "combat": true, "loot": true, "xp": true,
	"quest": true, "system": true,
}
var _chat_filter_buttons: Dictionary = {}  # { category: Button }
const CHAT_FILTER_CATEGORIES: Array = [
	{ "id": "all", "label": "All", "color": Color(0.7, 0.7, 0.7) },
	{ "id": "combat", "label": "Combat", "color": Color(0.9, 0.35, 0.25) },
	{ "id": "loot", "label": "Loot", "color": Color(0.3, 0.8, 0.9) },
	{ "id": "xp", "label": "XP", "color": Color(0.3, 0.8, 0.35) },
	{ "id": "quest", "label": "Quest", "color": Color(0.8, 0.55, 0.9) },
	{ "id": "system", "label": "Sys", "color": Color(0.55, 0.6, 0.6) },
]
## Maps chat channels to filter categories
const CHAT_CHANNEL_TO_FILTER: Dictionary = {
	"combat": "combat", "loot": "loot", "xp": "xp", "levelup": "xp",
	"quest": "quest", "slayer": "quest",
	"system": "system", "equipment": "system", "prestige": "system",
	"achievement": "system", "dungeon": "system", "pet": "system",
	"multiplayer": "all",
}

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
	EventBus.game_saved.connect(_on_game_saved)

	# Panel layout persistence
	EventBus.panel_closed.connect(_on_panel_state_changed)
	EventBus.panel_opened.connect(_on_panel_state_changed)

	# Context menu signal
	EventBus.context_menu_requested.connect(_on_context_menu_requested)
	EventBus.context_menu_hidden.connect(_hide_context_menu)

	# Window resize — reposition minimap and action bar
	get_tree().root.size_changed.connect(_on_window_resized)

	# Build combat style indicator (must be before stat bars so label can be inserted)
	_build_combat_style_indicator()

	# Build stat bars (HP, EN, ADR) — absolute positioned
	_build_stat_bars()

	# Initial display (level + credits now shown in skills/inventory panels)

	# Build panels (hidden by default)
	_build_panels()

	# Wire drag-end callbacks for panel position saving
	_wire_panel_drag_callbacks()

	# Restore saved panel positions/visibility/lock state (deferred so layout pass is done)
	call_deferred("_restore_panel_layout")

	# Build tutorial panel (auto-shows for new players)
	_build_tutorial_panel()

	# Build chat log
	_build_chat_log()

	# Build action buttons bar
	_build_action_bar()

	# Build gathering progress bar
	_build_gather_progress()

	# Build adrenaline bar + ability buttons
	_build_adrenaline_bar()

	# Build buff display (active food/consumable buffs)
	_build_buff_display()
	_build_ability_bar()

	# Build minimap
	_build_minimap()

	# Build QoL overlays
	_build_low_hp_vignette()
	_build_area_toast()
	_build_levelup_flash()
	_build_combat_indicator()
	_build_loot_toast()
	_build_target_info_panel()
	_build_gather_label()
	_build_save_toast()
	_build_hover_label()

## Build stat bars + info labels with absolute positioning (no TopBar/BottomBar containers)
var _stat_bars_container: VBoxContainer = null

func _build_stat_bars() -> void:
	# ── Stat bars container — centered above ability bar at bottom of screen ──
	_stat_bars_container = VBoxContainer.new()
	_stat_bars_container.name = "StatBarsContainer"
	_stat_bars_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_bars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_stat_bars_container.add_theme_constant_override("separation", 2)
	add_child(_stat_bars_container)

	# ── Style indicator label — centered above HP bar ──
	if _style_indicator_label:
		_stat_bars_container.add_child(_style_indicator_label)

	# ── HP Bar ──
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.custom_minimum_size = Vector2(280, 18)
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false

	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.08, 0.02, 0.02, 0.7)
	hp_bg.set_corner_radius_all(4)
	hp_bg.border_color = Color(0.3, 0.08, 0.08, 0.4)
	hp_bg.set_border_width_all(1)
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.65, 0.12, 0.08, 0.9)
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	_stat_bars_container.add_child(hp_bar)

	_hp_text = Label.new()
	_hp_text.name = "HPText"
	_hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 12)
	_hp_text.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95, 0.95))
	_hp_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_hp_text.add_theme_constant_override("shadow_offset_x", 1)
	_hp_text.add_theme_constant_override("shadow_offset_y", 1)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.add_child(_hp_text)

	# ── Energy Bar ──
	energy_bar = ProgressBar.new()
	energy_bar.name = "EnergyBar"
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.custom_minimum_size = Vector2(220, 14)
	energy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	energy_bar.max_value = 100.0
	energy_bar.value = 100.0
	energy_bar.show_percentage = false

	var en_bg: StyleBoxFlat = StyleBoxFlat.new()
	en_bg.bg_color = Color(0.02, 0.04, 0.1, 0.7)
	en_bg.set_corner_radius_all(4)
	en_bg.border_color = Color(0.06, 0.1, 0.3, 0.4)
	en_bg.set_border_width_all(1)
	energy_bar.add_theme_stylebox_override("background", en_bg)

	var en_fill: StyleBoxFlat = StyleBoxFlat.new()
	en_fill.bg_color = Color(0.12, 0.35, 0.75, 0.9)
	en_fill.set_corner_radius_all(4)
	energy_bar.add_theme_stylebox_override("fill", en_fill)
	_stat_bars_container.add_child(energy_bar)

	_energy_text = Label.new()
	_energy_text.name = "EnergyText"
	_energy_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_text.add_theme_font_size_override("font_size", 11)
	_energy_text.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 0.95))
	_energy_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_energy_text.add_theme_constant_override("shadow_offset_x", 1)
	_energy_text.add_theme_constant_override("shadow_offset_y", 1)
	_energy_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	energy_bar.add_child(_energy_text)

	# Level + credits now shown in Skills and Inventory panels respectively

	# ── FPS label — bottom-right ──
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp_size: Vector2 = _get_viewport_size()
	fps_label.position = Vector2(vp_size.x - 100, vp_size.y - 26)
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.3, 0.5))
	fps_label.text = "60 FPS"
	add_child(fps_label)

	# ── Position label — bottom-right (left of FPS) ──
	pos_label = Label.new()
	pos_label.name = "PosLabel"
	pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_label.position = Vector2(vp_size.x - 200, vp_size.y - 26)
	pos_label.add_theme_font_size_override("font_size", 13)
	pos_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4, 0.5))
	pos_label.text = "0, 0"
	add_child(pos_label)

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

	# Update adrenaline bar + text (show burst mode timer when active)
	if _adrenaline_bar:
		var adr_val: float = float(GameState.player["adrenaline"])
		_adrenaline_bar.value = adr_val
		_adrenaline_bar.max_value = 100.0
		if _adrenaline_text:
			var combat: Node = _player.get_node_or_null("CombatController") if _player else null
			if combat and "._burst_mode_active" != "" and combat.get("_burst_mode_active"):
				var burst_t: float = float(combat.get("_burst_mode_timer"))
				_adrenaline_text.text = "BURST %.1fs" % burst_t
				_adrenaline_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 0.95))
			elif combat and combat.get("_overcharge_active"):
				_adrenaline_text.text = "%d%% [OC]" % int(adr_val)
				_adrenaline_text.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 0.95))
			else:
				_adrenaline_text.text = "%d%%" % int(adr_val)
				_adrenaline_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75, 0.9))

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

	# ── Gathering bar: follow 3D node position ──
	if _gather_progress and _gather_progress.visible:
		_update_gather_bar_position()

	# ── Distance check: close interaction panels if player walks away ──
	_check_interaction_distance()

	# ── Ability queue indicator — highlight queued ability button ──
	_update_ability_queue_highlight(delta)

	# ── Ability cooldown overlays ──
	_update_ability_cooldowns()

	# ── Active buff display (food/consumable timers) ──
	_update_buff_display()

	# ── Keep chat resize handle pinned to chat panel corner ──
	if _chat_resize_handle and _chat_bg:
		_update_chat_resize_handle_pos()

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
		# Shift+1..5 → defense abilities
		if event.shift_pressed:
			match event.keycode:
				KEY_1:
					_use_defensive_ability(1)
					get_viewport().set_input_as_handled()
					return
				KEY_2:
					_use_defensive_ability(2)
					get_viewport().set_input_as_handled()
					return
				KEY_3:
					_use_defensive_ability(3)
					get_viewport().set_input_as_handled()
					return
				KEY_4:
					_use_defensive_ability(4)
					get_viewport().set_input_as_handled()
					return
				KEY_5:
					_use_defensive_ability(5)
					get_viewport().set_input_as_handled()
					return

		match event.keycode:
			# Ability keybinds (1-6)
			KEY_1:
				_use_ability(1)
				get_viewport().set_input_as_handled()
			KEY_2:
				_use_ability(2)
				get_viewport().set_input_as_handled()
			KEY_3:
				_use_ability(3)
				get_viewport().set_input_as_handled()
			KEY_4:
				_use_ability(4)
				get_viewport().set_input_as_handled()
			KEY_5:
				_use_ability(5)
				get_viewport().set_input_as_handled()
			KEY_6:
				_use_ability(6)
				get_viewport().set_input_as_handled()
			# Eat food (F)
			KEY_F:
				_eat_food()
				get_viewport().set_input_as_handled()
			# Weapon special attack (S)
			KEY_S:
				_use_weapon_special()
				get_viewport().set_input_as_handled()
			# Toggle run/walk (R)
			KEY_R:
				_toggle_run()
				get_viewport().set_input_as_handled()
			# Target nearest enemy (Tab)
			KEY_TAB:
				_target_nearest_enemy()
				get_viewport().set_input_as_handled()
			# Escape: cancel swap mode, close all panels, deselect target, close context menu
			KEY_ESCAPE:
				if _swap_mode:
					_cancel_swap_mode()
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
			# Achievements (J)
			KEY_J:
				_toggle_panel(_achievement_panel, "achievements")
				get_viewport().set_input_as_handled()
			# World Map (M)
			KEY_M:
				_toggle_world_map_panel()
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

	# Inventory panel (far right) — open by default
	var vp_sz: Vector2 = _get_viewport_size()
	_inventory_panel = PanelContainer.new()
	_inventory_panel.set_script(inventory_script)
	_inventory_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_inventory_panel.visible = true
	_inventory_panel.position = Vector2(vp_sz.x - 260, 80)
	add_child(_inventory_panel)

	# Equipment panel (left of inventory) — open by default
	_equipment_panel = PanelContainer.new()
	_equipment_panel.set_script(equipment_script)
	_equipment_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_equipment_panel.visible = true
	_equipment_panel.position = Vector2(vp_sz.x - 520, 80)
	add_child(_equipment_panel)

	# Skills panel (left side, below stat bars) — open by default
	_skills_panel = PanelContainer.new()
	_skills_panel.set_script(skills_script)
	_skills_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_skills_panel.visible = true
	_skills_panel.position = Vector2(14, 170)
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

	# Crafting panel (center — wider for split-panel layout)
	_crafting_panel = PanelContainer.new()
	_crafting_panel.set_script(crafting_script)
	_crafting_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_crafting_panel.visible = false
	_crafting_panel.position = Vector2(vp_sz.x / 2.0 - 320, 80)
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

	# Achievement panel (left-center)
	_achievement_panel = PanelContainer.new()
	_achievement_panel.set_script(achievement_script)
	_achievement_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_achievement_panel.visible = false
	_achievement_panel.position = Vector2(200, 60)
	add_child(_achievement_panel)

	# Multiplayer panel (bottom-right, always accessible)
	_multiplayer_panel = PanelContainer.new()
	_multiplayer_panel.name = "MultiplayerPanel"
	_multiplayer_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_multiplayer_panel.visible = false
	_multiplayer_panel.position = Vector2(680, 400)
	_multiplayer_panel.custom_minimum_size = Vector2(300, 220)
	add_child(_multiplayer_panel)
	_build_multiplayer_panel_contents()

	# Combat log panel
	_combat_log_panel = PanelContainer.new()
	_combat_log_panel.set_script(combat_log_script)
	_combat_log_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_combat_log_panel.visible = false
	_combat_log_panel.position = Vector2(10, 350)
	add_child(_combat_log_panel)

	# DPS meter
	_dps_meter = PanelContainer.new()
	_dps_meter.set_script(dps_meter_script)
	_dps_meter.add_theme_stylebox_override("panel", panel_style.duplicate())
	_dps_meter.visible = false
	_dps_meter.position = Vector2(10, 280)
	add_child(_dps_meter)

	# Tooltip (always exists, but hidden — added last so it renders on top)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.set_script(tooltip_script)
	add_child(_tooltip_panel)

	# Context menu (right-click popup — built inline, no external script)
	_build_context_menu()


## Build the tutorial panel — auto-shows on first game
func _build_tutorial_panel() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.06, 0.92)
	panel_style.border_color = Color(0.2, 0.55, 0.75, 0.45)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(8)

	var vp_sz: Vector2 = _get_viewport_size()
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_script(tutorial_script)
	_tutorial_panel.add_theme_stylebox_override("panel", panel_style)
	_tutorial_panel.visible = false
	_tutorial_panel.position = Vector2(vp_sz.x / 2.0 - 180, 16)
	add_child(_tutorial_panel)

	# Wire drag-end callback (since _wire_panel_drag_callbacks runs before this)
	_tutorial_panel.ready.connect(_bind_drag_callback.bind(_tutorial_panel, "tutorial"), CONNECT_ONE_SHOT)

	# Auto-show for new players (deferred so everything is initialized)
	if not GameState.tutorial.get("completed", false) and not GameState.tutorial.get("skipped", false):
		call_deferred("_start_tutorial")


func _start_tutorial() -> void:
	if _tutorial_panel and _tutorial_panel.has_method("start_tutorial"):
		_tutorial_panel.start_tutorial()


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
	_chat_bg.position = Vector2(10, vp_size.y - 290)
	_chat_bg.custom_minimum_size = Vector2(300, 180)
	_chat_bg.size = Vector2(400, 250)
	_chat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chat_bg)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_bg.add_child(outer_vbox)

	# Draggable header — always interactive so player can drag even when chat is unfocused
	var drag_header: DraggableHeader = DraggableHeader.attach(_chat_bg, "Chat", Callable())
	drag_header.name = "ChatDragHeader"
	drag_header.mouse_filter = Control.MOUSE_FILTER_STOP
	outer_vbox.add_child(drag_header)
	_chat_drag_header = drag_header
	# Update resize handle position whenever drag ends
	drag_header._on_drag_end = _update_chat_resize_handle_pos

	# Resize handle at the bottom-right corner
	_chat_resize_handle = _build_chat_resize_handle()

	# ── Chat filter tabs ──
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.name = "ChatFilterRow"
	filter_row.add_theme_constant_override("separation", 2)
	filter_row.mouse_filter = Control.MOUSE_FILTER_STOP
	var filter_margin: MarginContainer = MarginContainer.new()
	filter_margin.add_theme_constant_override("margin_left", 6)
	filter_margin.add_theme_constant_override("margin_right", 6)
	filter_margin.add_theme_constant_override("margin_top", 1)
	filter_margin.add_theme_constant_override("margin_bottom", 1)
	filter_margin.add_child(filter_row)
	outer_vbox.add_child(filter_margin)
	for cat in CHAT_FILTER_CATEGORIES:
		var cat_id: String = str(cat["id"])
		var cat_color: Color = cat["color"]
		var fbtn: Button = Button.new()
		fbtn.text = str(cat["label"])
		fbtn.add_theme_font_size_override("font_size", 10)
		fbtn.custom_minimum_size = Vector2(0, 18)
		fbtn.focus_mode = Control.FOCUS_NONE
		var fbtn_style: StyleBoxFlat = StyleBoxFlat.new()
		fbtn_style.bg_color = Color(cat_color.r * 0.15, cat_color.g * 0.15, cat_color.b * 0.15, 0.6)
		fbtn_style.border_color = cat_color.darkened(0.3)
		fbtn_style.border_color.a = 0.5
		fbtn_style.set_border_width_all(1)
		fbtn_style.set_corner_radius_all(3)
		fbtn_style.content_margin_left = 4
		fbtn_style.content_margin_right = 4
		fbtn_style.content_margin_top = 0
		fbtn_style.content_margin_bottom = 0
		fbtn.add_theme_stylebox_override("normal", fbtn_style)
		fbtn.add_theme_stylebox_override("hover", fbtn_style)
		fbtn.add_theme_stylebox_override("pressed", fbtn_style)
		fbtn.add_theme_color_override("font_color", cat_color)
		fbtn.pressed.connect(_on_chat_filter_toggle.bind(cat_id))
		filter_row.add_child(fbtn)
		_chat_filter_buttons[cat_id] = fbtn

	# Message area with padding
	var msg_margin: MarginContainer = MarginContainer.new()
	msg_margin.add_theme_constant_override("margin_left", 8)
	msg_margin.add_theme_constant_override("margin_right", 8)
	msg_margin.add_theme_constant_override("margin_top", 5)
	msg_margin.add_theme_constant_override("margin_bottom", 3)
	msg_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(msg_margin)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.name = "ChatScroll"
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_chat_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_margin.add_child(_chat_scroll)

	_chat_container = VBoxContainer.new()
	_chat_container.name = "ChatContainer"
	_chat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_container.add_theme_constant_override("separation", 3)
	_chat_scroll.add_child(_chat_container)

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
	_chat_input.add_theme_font_size_override("font_size", 14)
	_chat_input.custom_minimum_size = Vector2(0, 30)

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
	btn.custom_minimum_size = Vector2(width * 1.2, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", accent.lightened(0.1))
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.4))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	# Normal — near-invisible background, subtle bottom accent
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.04, 0.08, 0.6)
	normal.border_color = Color(0.1, 0.15, 0.2, 0.3)
	normal.set_border_width_all(0)
	normal.border_width_bottom = 2
	normal.border_color = accent.darkened(0.4)
	normal.border_color.a = 0.35
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — slight lift effect
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.05, 0.07, 0.14, 0.75)
	hover.border_color = accent.darkened(0.15)
	hover.border_color.a = 0.6
	hover.border_width_bottom = 3
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed — inset feel
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.7
	pressed.border_width_bottom = 0
	pressed.border_width_top = 2
	pressed.border_color = accent.darkened(0.2)
	pressed.border_color.a = 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

## Action bar background reference (for repositioning on window resize)
var _action_bar_bg: PanelContainer = null

## Create a compact icon button for the action bar (36x36 with 16x16 pixel art icon)
func _make_icon_btn(icon_id: String, tooltip: String, accent: Color = Color(0.2, 0.6, 0.8)) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(36, 36)
	btn.tooltip_text = tooltip
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Set pixel art icon
	var tex: ImageTexture = ItemIconGenerator.get_misc_texture(icon_id)
	if tex:
		btn.icon = tex
		btn.expand_icon = true

	# Normal — near-invisible background, subtle bottom accent
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.04, 0.08, 0.6)
	normal.border_color = accent.darkened(0.4)
	normal.border_color.a = 0.35
	normal.set_border_width_all(0)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — slight lift effect
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.05, 0.07, 0.14, 0.75)
	hover.border_color = accent.darkened(0.15)
	hover.border_color.a = 0.6
	hover.border_width_bottom = 3
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed — inset feel
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.7
	pressed.border_width_bottom = 0
	pressed.border_width_top = 2
	pressed.border_color = accent.darkened(0.2)
	pressed.border_color.a = 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

## Build compact 2x6 icon grid action bar at the bottom
func _build_action_bar() -> void:
	_action_bar_bg = PanelContainer.new()
	var bar_bg: PanelContainer = _action_bar_bg
	bar_bg.name = "ActionBarBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.015, 0.02, 0.04, 0.7)
	bg_style.border_color = Color(0.08, 0.15, 0.25, 0.3)
	bg_style.border_width_top = 1
	bg_style.set_corner_radius_all(6)
	bg_style.set_content_margin_all(3)
	bg_style.content_margin_left = 5
	bg_style.content_margin_right = 5
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bar_bg)

	# 2-row grid layout (7 columns to fit 14 buttons in 2 rows)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	bar_bg.add_child(grid)

	var cyan: Color = Color(0.2, 0.7, 0.9)
	var gold: Color = Color(0.9, 0.75, 0.3)
	var green: Color = Color(0.3, 0.8, 0.4)
	var purple: Color = Color(0.7, 0.4, 0.9)
	var orange: Color = Color(0.9, 0.5, 0.2)
	var red: Color = Color(0.8, 0.4, 0.3)

	# ── Row 1: Bag, Equip, Skills, Quests, Bestiary, Prestige ──
	var inv_btn: Button = _make_icon_btn("ui_bag", "Inventory (I)", cyan)
	inv_btn.pressed.connect(func(): _toggle_panel(_inventory_panel, "inventory"))
	grid.add_child(inv_btn)

	var eq_btn: Button = _make_icon_btn("ui_equip", "Equipment (E)", cyan)
	eq_btn.pressed.connect(func(): _toggle_panel(_equipment_panel, "equipment"))
	grid.add_child(eq_btn)

	var sk_btn: Button = _make_icon_btn("ui_skills", "Skills (K)", green)
	sk_btn.pressed.connect(func(): _toggle_panel(_skills_panel, "skills"))
	grid.add_child(sk_btn)

	var quest_btn: Button = _make_icon_btn("ui_quests", "Quests (Q)", purple)
	quest_btn.pressed.connect(func(): _toggle_panel(_quest_panel, "quests"))
	grid.add_child(quest_btn)

	var best_btn: Button = _make_icon_btn("ui_bestiary", "Bestiary (L)", red)
	best_btn.pressed.connect(func(): _toggle_panel(_bestiary_panel, "bestiary"))
	grid.add_child(best_btn)

	var pres_btn: Button = _make_icon_btn("ui_prestige", "Prestige", gold)
	pres_btn.pressed.connect(func(): _toggle_panel(_prestige_panel, "prestige"))
	grid.add_child(pres_btn)

	# ── Row 2: Dungeon, Pets, Achieve, Settings, Help, Map ──
	var dung_btn: Button = _make_icon_btn("ui_dungeon", "Dungeon (N)", orange)
	dung_btn.pressed.connect(func(): _toggle_panel(_dungeon_panel, "dungeon"))
	grid.add_child(dung_btn)

	var pet_btn: Button = _make_icon_btn("ui_pets", "Pets", Color(0.8, 0.4, 0.9))
	pet_btn.pressed.connect(func(): _toggle_panel(_pet_panel, "pets"))
	grid.add_child(pet_btn)

	var ach_btn: Button = _make_icon_btn("ui_achieve", "Achievements (J)", gold)
	ach_btn.pressed.connect(func(): _toggle_panel(_achievement_panel, "achievements"))
	grid.add_child(ach_btn)

	var clog_btn: Button = _make_icon_btn("ui_clog", "Combat Log", Color(0.8, 0.4, 0.3))
	clog_btn.pressed.connect(func(): _toggle_panel(_combat_log_panel, "combat_log"))
	grid.add_child(clog_btn)

	var dps_btn: Button = _make_icon_btn("ui_dps", "DPS Meter", Color(1.0, 0.7, 0.2))
	dps_btn.pressed.connect(func(): _toggle_panel(_dps_meter, "dps_meter"))
	grid.add_child(dps_btn)

	var set_btn: Button = _make_icon_btn("ui_settings", "Settings", Color(0.5, 0.5, 0.6))
	set_btn.pressed.connect(func(): _toggle_panel(_settings_panel, "settings"))
	grid.add_child(set_btn)

	var help_btn: Button = _make_icon_btn("ui_help", "Tutorial / Help", cyan)
	help_btn.pressed.connect(func():
		if _tutorial_panel:
			_tutorial_panel.visible = true
			EventBus.panel_opened.emit("tutorial")
			if _tutorial_panel.has_method("start_tutorial"):
				if GameState.tutorial.get("completed", false) or GameState.tutorial.get("skipped", false):
					GameState.tutorial["completed"] = false
					GameState.tutorial["skipped"] = false
					GameState.tutorial["current_step"] = 0
					GameState.tutorial["steps_done"] = []
				_tutorial_panel.start_tutorial()
	)
	grid.add_child(help_btn)

	var map_btn: Button = _make_icon_btn("ui_map", "World Map (M)", Color(0.3, 0.5, 0.85))
	map_btn.pressed.connect(func(): _toggle_world_map_panel())
	grid.add_child(map_btn)

	# Position centered at bottom
	_reposition_action_bar()

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
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	# Store channel as metadata for filtering
	label.set_meta("channel", channel)

	# Check if this message passes the current filter
	var filter_cat: String = CHAT_CHANNEL_TO_FILTER.get(channel, "system")
	var is_visible: bool = _chat_filters.get("all", true) or _chat_filters.get(filter_cat, true)
	label.visible = is_visible

	_chat_container.add_child(label)
	_chat_messages.append(label)

	# Remove old messages beyond limit
	while _chat_messages.size() > _max_chat_lines:
		var old: Label = _chat_messages[0]
		_chat_messages.remove_at(0)
		old.queue_free()

	# Auto-scroll to bottom so newest messages are visible
	if _chat_scroll:
		await get_tree().process_frame
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)

# ── Chat filter handlers ──

## Toggle a chat filter category on/off
func _on_chat_filter_toggle(category: String) -> void:
	if category == "all":
		# "All" toggles everything on and resets other filters
		for key in _chat_filters:
			_chat_filters[key] = true
	else:
		# Toggle this specific category; turn off "all" if it was on
		_chat_filters[category] = not _chat_filters[category]
		# Check if all individual categories are on → auto-enable "all"
		var all_on: bool = true
		for key in _chat_filters:
			if key != "all" and not _chat_filters[key]:
				all_on = false
				break
		_chat_filters["all"] = all_on

	# Update button visuals
	for cat_id in _chat_filter_buttons:
		var fbtn: Button = _chat_filter_buttons[cat_id]
		var enabled: bool = _chat_filters.get(cat_id, true)
		fbtn.modulate.a = 1.0 if enabled else 0.35

	# Re-filter all existing messages
	_apply_chat_filters()

## Re-filter all existing chat messages based on current filter state
func _apply_chat_filters() -> void:
	var show_all: bool = _chat_filters.get("all", true)
	for msg in _chat_messages:
		if not is_instance_valid(msg):
			continue
		var ch: String = str(msg.get_meta("channel", "system"))
		var filter_cat: String = CHAT_CHANNEL_TO_FILTER.get(ch, "system")
		msg.visible = show_all or _chat_filters.get(filter_cat, true)

# ── Chat input handlers ──

## Called when Enter is pressed while the chat input is focused
func _on_chat_input_submitted(text: String) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.length() > 0:
		# ── Slash commands (local only) ──
		if trimmed.begins_with("/"):
			_handle_slash_command(trimmed)
		else:
			# Send via multiplayer
			var client: Node = get_tree().get_first_node_in_group("multiplayer_client")
			if client and client.has_method("send_chat") and client.is_mp_connected():
				client.send_chat(trimmed)
			else:
				EventBus.chat_message.emit(trimmed, "system")
				# Still show chat bubble above local player when offline
				if client and client.has_method("_show_local_chat_bubble"):
					client._show_local_chat_bubble(trimmed)
	# Clear input and release focus
	_chat_input.text = ""
	_chat_input.release_focus()


func _handle_slash_command(cmd: String) -> void:
	var parts: PackedStringArray = cmd.split(" ", false)
	var command: String = parts[0].to_lower()
	match command:
		"/unstick":
			EventBus.chat_message.emit("Unsticking... You will respawn at Station Hub with death penalties.", "system")
			EventBus.player_unstick_requested.emit()
		_:
			EventBus.chat_message.emit("Unknown command: %s" % command, "system")

## Called when the chat input gains focus
func _on_chat_focus_entered() -> void:
	_chat_typing = true
	_chat_input.placeholder_text = "Type a message..."
	# Make the chat panel stop ignoring mouse so scrolling/clicking works
	if _chat_bg:
		_chat_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	if _chat_scroll:
		_chat_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

## Called when the chat input loses focus
func _on_chat_focus_exited() -> void:
	_chat_typing = false
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.text = ""
	# Return to mouse-transparent so clicks pass through to the game world
	if _chat_bg:
		_chat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _chat_scroll:
		_chat_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

## Build a small resize handle for the chat window (bottom-right corner)
## Added as sibling of _chat_bg on the HUD layer so PanelContainer layout isn't affected.
func _build_chat_resize_handle() -> Control:
	var handle: Control = Control.new()
	handle.name = "ChatResizeHandle"
	handle.custom_minimum_size = Vector2(18, 18)
	handle.size = Vector2(18, 18)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	add_child(handle)

	# Draw a small diagonal grip icon
	var grip_label: Label = Label.new()
	grip_label.text = "..."
	grip_label.add_theme_font_size_override("font_size", 12)
	grip_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.6, 0.5))
	grip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_child(grip_label)

	handle.gui_input.connect(_on_chat_resize_input)
	_update_chat_resize_handle_pos()
	return handle

## Keep the resize handle in the bottom-right corner of the chat panel (global coords)
func _update_chat_resize_handle_pos() -> void:
	if _chat_resize_handle == null or _chat_bg == null:
		return
	var panel_pos: Vector2 = _chat_bg.position
	var panel_size: Vector2 = _chat_bg.size
	_chat_resize_handle.position = Vector2(panel_pos.x + panel_size.x - 18, panel_pos.y + panel_size.y - 18)

## Handle mouse drag on the chat resize handle
func _on_chat_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_chat_resizing = true
				_chat_resize_start = event.global_position
				_chat_size_start = _chat_bg.size
			else:
				_chat_resizing = false
	elif event is InputEventMouseMotion and _chat_resizing:
		var delta: Vector2 = event.global_position - _chat_resize_start
		var new_size: Vector2 = _chat_size_start + delta
		# Clamp to minimum size
		new_size.x = maxf(new_size.x, _chat_bg.custom_minimum_size.x)
		new_size.y = maxf(new_size.y, _chat_bg.custom_minimum_size.y)
		# Clamp to viewport bounds
		var vp_size: Vector2 = _get_viewport_size()
		new_size.x = minf(new_size.x, vp_size.x - _chat_bg.position.x)
		new_size.y = minf(new_size.y, vp_size.y - _chat_bg.position.y)
		_chat_bg.size = new_size
		_update_chat_resize_handle_pos()

## Reposition the chat panel to bottom-left of current viewport
func _reposition_chat() -> void:
	if _chat_bg == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	_chat_bg.position = Vector2(10, vp_size.y - 310)
	_update_chat_resize_handle_pos()

func _update_area_display(_area_id: String) -> void:
	# Area name is shown in minimap only now — no separate label
	pass

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
# Floats above the 3D gathering node being harvested

var _gather_progress: ProgressBar = null
var _gather_target_node: Node3D = null  # The 3D node we're gathering from

## Build the gathering progress bar (floats above the resource node)
func _build_gather_progress() -> void:
	_gather_progress = ProgressBar.new()
	_gather_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gather_progress.custom_minimum_size = Vector2(120, 10)
	_gather_progress.show_percentage = false
	_gather_progress.visible = false

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.1, 0.7)
	bg_style.set_corner_radius_all(3)
	_gather_progress.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.65, 0.85, 0.9)
	fill_style.set_corner_radius_all(3)
	_gather_progress.add_theme_stylebox_override("fill", fill_style)

	add_child(_gather_progress)

## Show/update gathering progress (0.0 to 1.0), optionally track a 3D node
func show_gather_progress(progress: float, target_node: Node3D = null) -> void:
	if target_node and is_instance_valid(target_node):
		_gather_target_node = target_node
	if _gather_progress:
		_gather_progress.value = progress * 100.0
		_gather_progress.visible = true
		_update_gather_bar_position()

## Hide gathering progress bar
func hide_gather_progress() -> void:
	if _gather_progress:
		_gather_progress.visible = false
	if _gather_label:
		_gather_label.visible = false
	_gather_target_node = null

## Project the gather node's 3D position to screen and position the bar + label above it
func _update_gather_bar_position() -> void:
	if _gather_target_node == null or not is_instance_valid(_gather_target_node):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	# Position above the node (offset Y upward in world space)
	var world_pos: Vector3 = _gather_target_node.global_position + Vector3(0, 1.8, 0)
	if camera.is_position_behind(world_pos):
		if _gather_progress:
			_gather_progress.visible = false
		if _gather_label:
			_gather_label.visible = false
		return
	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	# Center the bar on the screen position
	if _gather_progress:
		_gather_progress.position = Vector2(screen_pos.x - 60, screen_pos.y)
		_gather_progress.visible = true
	if _gather_label and _gather_label.visible:
		_gather_label.position = Vector2(screen_pos.x - 80, screen_pos.y - 22)
		_gather_label.size = Vector2(160, 20)

# ── Adrenaline bar ──

var _adrenaline_bar: ProgressBar = null
var _adrenaline_text: Label = null

## Build the adrenaline bar inside the stat bars container
func _build_adrenaline_bar() -> void:
	var adr_row: HBoxContainer = HBoxContainer.new()
	adr_row.name = "AdrenalineRow"
	adr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	adr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	adr_row.add_theme_constant_override("separation", 4)
	if _stat_bars_container:
		_stat_bars_container.add_child(adr_row)
	else:
		add_child(adr_row)

	var lbl: Label = Label.new()
	lbl.text = "ADR"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.3, 0.8))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	adr_row.add_child(lbl)

	_adrenaline_bar = ProgressBar.new()
	_adrenaline_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adrenaline_bar.custom_minimum_size = Vector2(200, 12)
	_adrenaline_bar.show_percentage = false
	_adrenaline_bar.max_value = 100.0
	_adrenaline_bar.value = 0.0

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.06, 0.03, 0.6)
	bg_style.set_corner_radius_all(3)
	bg_style.border_color = Color(0.12, 0.25, 0.08, 0.3)
	bg_style.set_border_width_all(1)
	_adrenaline_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.7, 0.18, 0.85)
	fill_style.set_corner_radius_all(3)
	_adrenaline_bar.add_theme_stylebox_override("fill", fill_style)

	adr_row.add_child(_adrenaline_bar)

	_adrenaline_text = Label.new()
	_adrenaline_text.name = "AdrText"
	_adrenaline_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adrenaline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adrenaline_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_adrenaline_text.add_theme_font_size_override("font_size", 11)
	_adrenaline_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75, 0.9))
	_adrenaline_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_adrenaline_text.add_theme_constant_override("shadow_offset_x", 1)
	_adrenaline_text.add_theme_constant_override("shadow_offset_y", 1)
	_adrenaline_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_adrenaline_bar.add_child(_adrenaline_text)

	# ── Adrenaline spender buttons ──
	_build_adrenaline_spender_buttons(adr_row)

var _burst_btn: Button = null
var _overcharge_btn: Button = null
var _rush_btn: Button = null

## Build 3 small adrenaline spender buttons next to the adrenaline bar
func _build_adrenaline_spender_buttons(parent: HBoxContainer) -> void:
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.12, 0.06, 0.7)
	btn_style.set_corner_radius_all(3)
	btn_style.border_color = Color(0.25, 0.5, 0.15, 0.4)
	btn_style.set_border_width_all(1)
	btn_style.content_margin_left = 3
	btn_style.content_margin_right = 3
	btn_style.content_margin_top = 1
	btn_style.content_margin_bottom = 1

	# Burst Mode (100 ADR)
	_burst_btn = Button.new()
	_burst_btn.text = "B"
	_burst_btn.tooltip_text = "Burst Mode (100 ADR): Free abilities for 5s"
	_burst_btn.custom_minimum_size = Vector2(22, 16)
	_burst_btn.add_theme_font_size_override("font_size", 9)
	_burst_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_burst_btn.add_theme_stylebox_override("normal", btn_style)
	_burst_btn.add_theme_stylebox_override("hover", btn_style)
	_burst_btn.add_theme_stylebox_override("pressed", btn_style)
	_burst_btn.pressed.connect(_on_burst_pressed)
	parent.add_child(_burst_btn)

	# Overcharge (50 ADR)
	_overcharge_btn = Button.new()
	_overcharge_btn.text = "O"
	_overcharge_btn.tooltip_text = "Overcharge (50 ADR): Next ability deals 2x damage"
	_overcharge_btn.custom_minimum_size = Vector2(22, 16)
	_overcharge_btn.add_theme_font_size_override("font_size", 9)
	_overcharge_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	_overcharge_btn.add_theme_stylebox_override("normal", btn_style)
	_overcharge_btn.add_theme_stylebox_override("hover", btn_style)
	_overcharge_btn.add_theme_stylebox_override("pressed", btn_style)
	_overcharge_btn.pressed.connect(_on_overcharge_pressed)
	parent.add_child(_overcharge_btn)

	# Adrenaline Rush (25 ADR)
	_rush_btn = Button.new()
	_rush_btn.text = "R"
	_rush_btn.tooltip_text = "Adrenaline Rush (25 ADR): Instant +50 energy"
	_rush_btn.custom_minimum_size = Vector2(22, 16)
	_rush_btn.add_theme_font_size_override("font_size", 9)
	_rush_btn.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	_rush_btn.add_theme_stylebox_override("normal", btn_style)
	_rush_btn.add_theme_stylebox_override("hover", btn_style)
	_rush_btn.add_theme_stylebox_override("pressed", btn_style)
	_rush_btn.pressed.connect(_on_rush_pressed)
	parent.add_child(_rush_btn)

func _on_burst_pressed() -> void:
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat and combat.has_method("activate_burst_mode"):
		combat.activate_burst_mode()

func _on_overcharge_pressed() -> void:
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat and combat.has_method("activate_overcharge"):
		combat.activate_overcharge()

func _on_rush_pressed() -> void:
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat and combat.has_method("activate_adrenaline_rush"):
		combat.activate_adrenaline_rush()

# ── Buff display ──

## Buff type → { icon emoji, color }
const BUFF_DISPLAY_INFO: Dictionary = {
	"damage": { "icon": "ATK", "color": Color(1.0, 0.45, 0.2) },
	"defense": { "icon": "DEF", "color": Color(0.3, 0.7, 1.0) },
	"accuracy": { "icon": "ACC", "color": Color(0.9, 0.85, 0.3) },
	"speed": { "icon": "SPD", "color": Color(0.4, 0.95, 0.5) },
	"all": { "icon": "ALL", "color": Color(0.95, 0.75, 0.2) },
	"healOverTime": { "icon": "HOT", "color": Color(0.3, 0.95, 0.4) },
}

func _build_buff_display() -> void:
	_buff_container = HBoxContainer.new()
	_buff_container.name = "BuffDisplay"
	_buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buff_container.add_theme_constant_override("separation", 6)
	_buff_container.visible = false  # Hidden when no buffs active
	add_child(_buff_container)

func _reposition_buff_display() -> void:
	if _buff_container == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	# Position centered above stat bars
	var container_width: float = _buff_container.size.x
	if container_width < 10:
		container_width = 200.0
	# Stat bars top is ~vp.y - 88 - 97 - 67 = ~vp.y - 252
	var stat_top: float = vp_size.y - 252.0
	_buff_container.position = Vector2(
		vp_size.x / 2.0 - container_width / 2.0,
		stat_top - 22
	)

func _update_buff_display() -> void:
	if _buff_container == null:
		return

	var buffs: Array[Dictionary] = GameState.active_buffs

	# Remove labels for expired buffs
	var active_types: Array[String] = []
	for b in buffs:
		active_types.append(str(b["type"]))

	var to_remove: Array[String] = []
	for buff_type in _buff_labels:
		if not active_types.has(buff_type):
			to_remove.append(buff_type)
	for buff_type in to_remove:
		var info: Dictionary = _buff_labels[buff_type]
		if info.has("panel") and info["panel"] is Node:
			info["panel"].queue_free()
		_buff_labels.erase(buff_type)

	# Update or create labels for active buffs
	for b in buffs:
		var btype: String = str(b["type"])
		var remaining: float = float(b["remaining"])
		var value: float = float(b["value"])
		var source: String = str(b.get("source", ""))

		if not _buff_labels.has(btype):
			# Create new buff chip
			var chip: PanelContainer = PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chip_style: StyleBoxFlat = StyleBoxFlat.new()
			var info: Dictionary = BUFF_DISPLAY_INFO.get(btype, { "icon": "BUF", "color": Color(0.7, 0.7, 0.7) })
			var col: Color = info["color"]
			chip_style.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.75)
			chip_style.border_color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.5)
			chip_style.set_border_width_all(1)
			chip_style.set_corner_radius_all(4)
			chip_style.content_margin_left = 4
			chip_style.content_margin_right = 4
			chip_style.content_margin_top = 1
			chip_style.content_margin_bottom = 1
			chip.add_theme_stylebox_override("panel", chip_style)

			var hbox: HBoxContainer = HBoxContainer.new()
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_theme_constant_override("separation", 3)
			chip.add_child(hbox)

			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(12, 12)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.texture = ItemIcons.get_buff_texture(btype)
			hbox.add_child(icon_rect)

			var text_lbl: Label = Label.new()
			text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_lbl.add_theme_font_size_override("font_size", 10)
			text_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
			text_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
			text_lbl.add_theme_constant_override("shadow_offset_x", 1)
			text_lbl.add_theme_constant_override("shadow_offset_y", 1)
			hbox.add_child(text_lbl)

			_buff_container.add_child(chip)
			_buff_labels[btype] = { "panel": chip, "icon": icon_rect, "text": text_lbl }

		# Update timer text
		var label_info: Dictionary = _buff_labels[btype]
		var text_lbl: Label = label_info["text"] as Label
		if text_lbl:
			var time_str: String
			if remaining >= 60.0:
				time_str = "%dm%02ds" % [int(remaining) / 60, int(remaining) % 60]
			else:
				time_str = "%ds" % int(ceilf(remaining))
			# Show buff value context
			var val_str: String = ""
			if btype == "damage" or btype == "defense":
				val_str = "+%d " % int(value)
			elif btype == "speed" or btype == "accuracy":
				val_str = "+%d%% " % int(value * 100.0)
			elif btype == "all":
				val_str = "+%d%% " % int(value * 100.0)
			elif btype == "healOverTime":
				val_str = "%d/s " % int(value)
			text_lbl.text = "%s%s" % [val_str, time_str]

		# Flash warning when buff is about to expire (< 5 seconds)
		var icon_node: TextureRect = label_info["icon"] as TextureRect
		if icon_node:
			if remaining < 5.0:
				# Blink effect — alternate alpha
				var blink: float = 0.5 + 0.5 * sin(remaining * 6.0)
				icon_node.modulate.a = blink
				if text_lbl:
					text_lbl.modulate.a = blink
			else:
				icon_node.modulate.a = 1.0
				if text_lbl:
					text_lbl.modulate.a = 1.0

	# Show/hide container
	_buff_container.visible = not buffs.is_empty()

	# Re-center after adding/removing chips
	if _buff_container.visible:
		_reposition_buff_display()

# ── Ability bar ──
var _ability_bar: HBoxContainer = null
var _ability_bar_bg: PanelContainer = null
var _ability_buttons: Array[Button] = []
var _ability_cd_overlays: Array[ColorRect] = []  # Dark cooldown overlay per button
var _ability_cd_labels: Array[Label] = []  # Timer text per button
var _queue_pulse_time: float = 0.0
var _last_queued_slot: int = -1  # Track to restore buttons when queue clears
var _revolution_btn: Button = null  # Revolution toggle button
var _special_btn: Button = null  # Weapon special attack button
var _special_cd_overlay: ColorRect = null
var _special_cd_label: Label = null

# ── Ability bar swap mode (right-click to reorder) ──
var _swap_mode: bool = false
var _swap_source_idx: int = -1  # Index in _ability_buttons being swapped

# ── Defense bar (shared abilities row above main bar) ──
var _defense_bar: HBoxContainer = null
var _defense_buttons: Array[Button] = []
var _defense_cd_overlays: Array[ColorRect] = []
var _defense_cd_labels: Array[Label] = []

## Build ability bars (defense row + main row), centered above action bar
func _build_ability_bar() -> void:
	_ability_bar_bg = PanelContainer.new()
	_ability_bar_bg.name = "AbilityBarBG"
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.015, 0.02, 0.04, 0.7)
	bg_style.border_color = Color(0.08, 0.15, 0.25, 0.3)
	bg_style.border_width_top = 1
	bg_style.set_corner_radius_all(6)
	bg_style.set_content_margin_all(5)
	bg_style.content_margin_left = 8
	bg_style.content_margin_right = 8
	_ability_bar_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_ability_bar_bg)

	# Two-row layout: defense bar on top, main ability bar on bottom
	var bar_vbox: VBoxContainer = VBoxContainer.new()
	bar_vbox.add_theme_constant_override("separation", 3)
	_ability_bar_bg.add_child(bar_vbox)

	# Defense bar (compact shared abilities)
	_defense_bar = HBoxContainer.new()
	_defense_bar.add_theme_constant_override("separation", 3)
	_defense_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_vbox.add_child(_defense_bar)

	# Main ability bar
	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 5)
	bar_vbox.add_child(_ability_bar)

	# Build buttons from data
	_refresh_ability_buttons()
	_refresh_defense_buttons()

	# Position centered above action bar
	_reposition_ability_bar()

## Refresh ability buttons based on current combat style
func _refresh_ability_buttons() -> void:
	if _ability_bar == null:
		return

	# Reset swap mode when rebuilding
	_swap_mode = false
	_swap_source_idx = -1

	# Clear old buttons
	for child in _ability_bar.get_children():
		child.queue_free()
	_ability_buttons.clear()
	_ability_cd_overlays.clear()
	_ability_cd_labels.clear()

	# Use combat controller's active abilities (already in custom display order)
	var abilities: Array = []
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and "_active_abilities" in combat:
			abilities = combat._active_abilities
	# Fallback: load from DataManager if combat controller isn't ready
	if abilities.is_empty():
		abilities = DataManager.get_abilities_for_style(str(GameState.player.get("combat_style", "nano"))) if DataManager.has_method("get_abilities_for_style") else []
		abilities.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))

	# Accent colors by tier
	var tier_colors: Dictionary = {
		"basic": Color(0.3, 0.9, 1.0),
		"threshold": Color(1.0, 0.6, 0.1),
		"ultimate": Color(1.0, 0.2, 0.9),
	}

	if abilities.size() > 0:
		for i in range(abilities.size()):
			var ab: Dictionary = abilities[i]
			var tier: String = str(ab.get("tier", "basic"))
			var accent: Color = tier_colors.get(tier, Color(0.3, 0.9, 1.0))
			var adr_cost: int = int(ab.get("adr_cost", 0))
			var adr_gain: int = int(ab.get("adr_gain", 0))
			var cost_text: String = "+%d ADR" % adr_gain if adr_gain > 0 else ("%d ADR" % adr_cost if adr_cost > 0 else "")
			var slot_num: int = i + 1
			var ab_name: String = str(ab.get("name", "Ability"))
			var ab_id: String = str(ab.get("id", ""))
			var ab_tex: ImageTexture = ItemIcons.get_ability_texture(ab_id) if ab_id != "" else null

			var btn: Button = _make_ability_btn(str(slot_num), ab_name, accent, adr_cost, cost_text, false, ab_tex)
			var cd_val: float = float(ab.get("cooldown", 0))
			var cd_text: String = " | CD: %ds" % int(cd_val) if cd_val > 0 else ""
			var dmg_min: float = float(ab.get("damage_min", 0))
			var dmg_max: float = float(ab.get("damage_max", 0))
			var dmg_text: String
			if dmg_min > 0 and dmg_max > 0:
				dmg_text = "%.1f-%.1fx damage" % [dmg_min, dmg_max]
			else:
				dmg_text = "%.1fx damage" % float(ab.get("damage_mult", 1.0))
			btn.tooltip_text = "%s — %s%s\n%s" % [ab_name, dmg_text, cd_text, str(ab.get("description", ""))]
			var slot_idx: int = slot_num
			btn.pressed.connect(func(): _on_ability_btn_left_click(slot_idx))
			var btn_idx: int = i
			btn.gui_input.connect(func(event: InputEvent): _on_ability_btn_input(event, btn_idx))
			_ability_bar.add_child(btn)
			_ability_buttons.append(btn)
	else:
		# Fallback: generic 5 buttons if DataManager doesn't have abilities yet
		var fb_tex: ImageTexture = ItemIcons.get_ability_texture("_default")
		var fallback_data: Array = [
			{"key": "1", "name": "Attack", "color": Color(0.3, 0.9, 1.0), "cost": 0, "cost_text": "+8 ADR"},
			{"key": "2", "name": "Attack", "color": Color(0.3, 0.9, 1.0), "cost": 0, "cost_text": "+8 ADR"},
			{"key": "3", "name": "Threshold", "color": Color(1.0, 0.6, 0.1), "cost": 50, "cost_text": "50 ADR"},
			{"key": "4", "name": "Threshold", "color": Color(1.0, 0.6, 0.1), "cost": 50, "cost_text": "50 ADR"},
			{"key": "5", "name": "Ultimate", "color": Color(1.0, 0.2, 0.9), "cost": 100, "cost_text": "100 ADR"},
		]
		for i in range(fallback_data.size()):
			var fb: Dictionary = fallback_data[i]
			var btn: Button = _make_ability_btn(fb["key"], fb["name"], fb["color"], fb["cost"], fb["cost_text"], false, fb_tex)
			var slot_idx: int = i + 1
			btn.pressed.connect(func(): _use_ability(slot_idx))
			_ability_bar.add_child(btn)
			_ability_buttons.append(btn)

	# Eat food button — green
	var food_tex: ImageTexture = ItemIcons.get_misc_texture("food")
	var food_btn: Button = _make_ability_btn("F", "Food", Color(0.3, 1.0, 0.3), 0, "", false, food_tex)
	food_btn.tooltip_text = "Eat Food — Heals HP\nUses best food in inventory"
	food_btn.pressed.connect(func(): _eat_food())
	_ability_bar.add_child(food_btn)

	# Revolution toggle button — compact "R" button
	var rev_active: bool = GameState.settings.get("revolution", false)
	var rev_color: Color = Color(0.2, 0.9, 0.3) if rev_active else Color(0.4, 0.4, 0.4)
	_revolution_btn = Button.new()
	_revolution_btn.custom_minimum_size = Vector2(36, 44)
	_revolution_btn.focus_mode = Control.FOCUS_NONE
	_revolution_btn.text = "R"
	_revolution_btn.tooltip_text = "Revolution — Auto-fire basic abilities\nClick or press R to toggle"
	_revolution_btn.add_theme_font_size_override("font_size", 16)
	var rev_normal: StyleBoxFlat = StyleBoxFlat.new()
	rev_normal.bg_color = Color(0.02, 0.03, 0.06, 0.7)
	rev_normal.border_color = rev_color
	rev_normal.set_border_width_all(2)
	rev_normal.set_corner_radius_all(4)
	rev_normal.set_content_margin_all(3)
	_revolution_btn.add_theme_stylebox_override("normal", rev_normal)
	var rev_hover: StyleBoxFlat = rev_normal.duplicate()
	rev_hover.bg_color = Color(0.04, 0.06, 0.12, 0.8)
	_revolution_btn.add_theme_stylebox_override("hover", rev_hover)
	var rev_pressed: StyleBoxFlat = rev_normal.duplicate()
	rev_pressed.bg_color = rev_color.darkened(0.65)
	rev_pressed.bg_color.a = 0.6
	_revolution_btn.add_theme_stylebox_override("pressed", rev_pressed)
	_revolution_btn.add_theme_color_override("font_color", rev_color)
	_revolution_btn.pressed.connect(_toggle_revolution)
	_ability_bar.add_child(_revolution_btn)

	# Weapon Special attack button — gold accent
	_special_btn = Button.new()
	_special_btn.custom_minimum_size = Vector2(44, 44)
	_special_btn.focus_mode = Control.FOCUS_NONE
	_special_btn.text = ""
	_special_btn.add_theme_font_size_override("font_size", 14)
	var sp_accent: Color = Color(1.0, 0.85, 0.1)
	var sp_normal: StyleBoxFlat = StyleBoxFlat.new()
	sp_normal.bg_color = Color(0.04, 0.03, 0.01, 0.7)
	sp_normal.border_color = sp_accent.darkened(0.35)
	sp_normal.border_color.a = 0.5
	sp_normal.set_border_width_all(0)
	sp_normal.border_width_bottom = 2
	sp_normal.set_corner_radius_all(4)
	sp_normal.set_content_margin_all(3)
	_special_btn.add_theme_stylebox_override("normal", sp_normal)
	var sp_hover: StyleBoxFlat = sp_normal.duplicate()
	sp_hover.bg_color = Color(0.08, 0.06, 0.02, 0.8)
	sp_hover.border_color = sp_accent.darkened(0.1)
	sp_hover.border_color.a = 0.7
	sp_hover.border_width_bottom = 3
	_special_btn.add_theme_stylebox_override("hover", sp_hover)
	var sp_pressed: StyleBoxFlat = sp_normal.duplicate()
	sp_pressed.bg_color = sp_accent.darkened(0.65)
	sp_pressed.bg_color.a = 0.6
	_special_btn.add_theme_stylebox_override("pressed", sp_pressed)
	# Keybind label
	var sp_key_lbl: Label = Label.new()
	sp_key_lbl.text = "S"
	sp_key_lbl.add_theme_font_size_override("font_size", 9)
	sp_key_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	sp_key_lbl.position = Vector2(2, 0)
	sp_key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_btn.add_child(sp_key_lbl)
	# Icon label
	var sp_icon_lbl: Label = Label.new()
	sp_icon_lbl.text = "SP"
	sp_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sp_icon_lbl.add_theme_font_size_override("font_size", 16)
	sp_icon_lbl.add_theme_color_override("font_color", sp_accent)
	sp_icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sp_icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_btn.add_child(sp_icon_lbl)
	# CD overlay
	_special_cd_overlay = ColorRect.new()
	_special_cd_overlay.color = Color(0, 0, 0, 0.55)
	_special_cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_cd_overlay.visible = false
	_special_cd_overlay.size = Vector2(44, 44)
	_special_btn.add_child(_special_cd_overlay)
	# CD label
	_special_cd_label = Label.new()
	_special_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_special_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_special_cd_label.add_theme_font_size_override("font_size", 11)
	_special_cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_special_cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_special_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_cd_label.visible = false
	_special_btn.add_child(_special_cd_label)
	# Update tooltip based on weapon
	_update_special_btn_tooltip()
	_special_btn.pressed.connect(_use_weapon_special)
	_ability_bar.add_child(_special_btn)

## Refresh defense (shared ability) buttons
func _refresh_defense_buttons() -> void:
	if _defense_bar == null:
		return

	# Clear old buttons
	for child in _defense_bar.get_children():
		child.queue_free()
	_defense_buttons.clear()
	_defense_cd_overlays.clear()
	_defense_cd_labels.clear()

	var shared: Array = DataManager.get_shared_abilities() if DataManager.has_method("get_shared_abilities") else []
	if shared.is_empty():
		_defense_bar.visible = false
		return
	_defense_bar.visible = true

	var keybinds: Array[String] = ["S1", "S2", "S3", "S4", "S5"]
	var tier_colors: Dictionary = {
		"basic": Color(0.3, 0.9, 1.0),
		"threshold": Color(1.0, 0.6, 0.1),
		"ultimate": Color(1.0, 0.2, 0.9),
	}

	for i in range(shared.size()):
		var ab: Dictionary = shared[i]
		var tier: String = str(ab.get("tier", "basic"))
		var accent: Color = tier_colors.get(tier, Color(0.5, 0.5, 0.5))
		var ab_id: String = str(ab.get("id", ""))
		var ab_name: String = str(ab.get("name", ""))
		var keybind: String = keybinds[i] if i < keybinds.size() else ""
		var ab_tex: ImageTexture = ItemIcons.get_ability_texture(ab_id) if ab_id != "" else null

		var btn: Button = _make_defense_btn(keybind, ab_name, accent, ab, ab_tex)
		var slot_idx: int = i + 1
		btn.pressed.connect(func(): _use_defensive_ability(slot_idx))
		_defense_bar.add_child(btn)
		_defense_buttons.append(btn)

## Create a compact defense ability button (90×36)
func _make_defense_btn(keybind: String, label_text: String, accent: Color, ab: Dictionary, icon_texture: ImageTexture = null) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(56, 36)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.06, 0.6)
	normal.border_color = accent.darkened(0.4)
	normal.border_color.a = 0.4
	normal.set_border_width_all(0)
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.04, 0.06, 0.12, 0.7)
	hover.border_color = accent.darkened(0.1)
	hover.border_color.a = 0.5
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.5
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.text = ""

	# Icon — pixel art TextureRect or text fallback
	if icon_texture != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
	else:
		var icon_lbl: Label = Label.new()
		icon_lbl.text = label_text
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 11)
		icon_lbl.clip_text = true
		icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_lbl)

	# CD overlay
	var cd_overlay: ColorRect = ColorRect.new()
	cd_overlay.color = Color(0, 0, 0, 0.55)
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.visible = false
	cd_overlay.size = Vector2(56, 36)
	btn.add_child(cd_overlay)
	_defense_cd_overlays.append(cd_overlay)

	# CD label
	var cd_label: Label = Label.new()
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.add_theme_font_size_override("font_size", 11)
	cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	btn.add_child(cd_label)
	_defense_cd_labels.append(cd_label)

	# Tooltip
	var ab_name: String = str(ab.get("name", ""))
	var cd_val: float = float(ab.get("cooldown", 0))
	var cd_text: String = " | CD: %ds" % int(cd_val) if cd_val > 0 else ""
	var cost: int = int(ab.get("adr_cost", 0))
	var cost_text: String = "%d ADR" % cost if cost > 0 else "+%d ADR" % int(ab.get("adr_gain", 0))
	btn.tooltip_text = "%s — %s%s\n%s" % [ab_name, cost_text, cd_text, str(ab.get("description", ""))]

	return btn

## Use a defensive ability from the defense bar
func _use_defensive_ability(slot: int) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and combat.has_method("use_defensive_ability"):
			combat.use_defensive_ability(slot)

## Position the ability bar centered above the compact action bar
func _reposition_ability_bar() -> void:
	if _ability_bar_bg == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	# Wait a frame for size to update
	await get_tree().process_frame
	var bar_width: float = _ability_bar_bg.size.x
	if bar_width < 10:
		bar_width = 830.0  # Estimate for 6 buttons * 120px + gaps + margins
	# Position above compact action bar (~88px from bottom)
	var action_top: float = vp_size.y - 88.0
	var ability_h: float = _ability_bar_bg.size.y
	if ability_h < 10:
		ability_h = 95.0  # Two-row ability bar estimate
	_ability_bar_bg.position = Vector2(vp_size.x / 2.0 - bar_width / 2.0, action_top - ability_h - 2)
	# Also reposition stat bars above ability bar
	_reposition_stat_bars()

func _reposition_stat_bars() -> void:
	if _stat_bars_container == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	# Stat bars sit centered above the ability bar
	var container_width: float = 280.0  # Width of widest bar (HP)
	var ability_top: float = vp_size.y - 88.0 - 97.0  # action bar top - ability bar height
	var stat_h: float = _stat_bars_container.size.y
	if stat_h < 10:
		stat_h = 65.0  # HP + EN + ADR + style + spacing
	_stat_bars_container.position = Vector2(
		vp_size.x / 2.0 - container_width / 2.0,
		ability_top - stat_h - 2
	)

## Highlight the queued ability button with a pulsing glow border
func _update_ability_queue_highlight(delta: float) -> void:
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat == null:
		return

	var queued_slot: int = int(combat.get("_queued_ability_slot")) if "_queued_ability_slot" in combat else -1

	# If queue cleared, restore the previously highlighted button
	if queued_slot <= 0 and _last_queued_slot > 0:
		var prev_idx: int = _last_queued_slot - 1
		if prev_idx >= 0 and prev_idx < _ability_buttons.size():
			var btn: Button = _ability_buttons[prev_idx]
			var normal_style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if normal_style:
				normal_style.border_color.a = 0.4
				normal_style.set_border_width_all(0)
				normal_style.border_width_bottom = 2
		_last_queued_slot = -1
		_queue_pulse_time = 0.0
		return

	if queued_slot <= 0:
		return

	# Pulse animation
	_queue_pulse_time += delta * 5.0
	var pulse: float = 0.5 + sin(_queue_pulse_time) * 0.5  # 0.0 to 1.0

	var btn_idx: int = queued_slot - 1
	if btn_idx >= 0 and btn_idx < _ability_buttons.size():
		var btn: Button = _ability_buttons[btn_idx]
		var normal_style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if normal_style:
			# Pulsing bright border on all sides
			normal_style.border_color = Color(1.0, 1.0, 1.0, 0.4 + pulse * 0.5)
			normal_style.set_border_width_all(2)

	_last_queued_slot = queued_slot

## Update ability cooldown overlays based on GCD timer, per-ability CD, and food cooldown
func _update_ability_cooldowns() -> void:
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat == null:
		return

	var gcd_timer: float = float(combat.get("_gcd_timer")) if "_gcd_timer" in combat else 0.0
	var gcd_max: float = float(combat.get("GCD_TIME")) if "GCD_TIME" in combat else 1.8
	var food_cd: float = float(combat.get("_food_cooldown_timer")) if "_food_cooldown_timer" in combat else 0.0

	# Get current style abilities in display order (matches button order, respects custom reorder)
	var abilities: Array = combat._active_abilities if "_active_abilities" in combat else []

	var btn_count: int = _ability_cd_overlays.size()
	for i in range(btn_count):
		var overlay: ColorRect = _ability_cd_overlays[i]
		var cd_label: Label = _ability_cd_labels[i]
		if not is_instance_valid(overlay) or not is_instance_valid(cd_label):
			continue

		# Last button is always food — use food cooldown
		var is_food: bool = (i == btn_count - 1)

		if is_food:
			var cd_remaining: float = food_cd
			var cd_total: float = gcd_max
			if cd_remaining > 0.01:
				var frac: float = clampf(cd_remaining / cd_total, 0.0, 1.0)
				overlay.size.y = 44.0 * frac
				overlay.position.y = 0.0
				overlay.visible = true
				cd_label.text = "%.1f" % cd_remaining
				cd_label.visible = true
			else:
				overlay.visible = false
				cd_label.visible = false
		else:
			# Ability button — check both GCD and per-ability cooldown
			var per_ab_cd: float = 0.0
			var per_ab_cd_max: float = 0.0
			if i < abilities.size() and combat.has_method("get_ability_cooldown"):
				var ab: Dictionary = abilities[i]
				var ab_id: String = str(ab.get("id", ""))
				per_ab_cd = combat.get_ability_cooldown(ab_id)
				per_ab_cd_max = float(ab.get("cooldown", 0))

			# Use whichever cooldown is longer
			var cd_remaining: float
			var cd_total: float
			if per_ab_cd > gcd_timer:
				cd_remaining = per_ab_cd
				cd_total = maxf(per_ab_cd_max, 1.0)  # Use ability's max CD for sweep
			else:
				cd_remaining = gcd_timer
				cd_total = gcd_max

			if cd_remaining > 0.01:
				var frac: float = clampf(cd_remaining / cd_total, 0.0, 1.0)
				overlay.size.y = 44.0 * frac
				overlay.position.y = 0.0
				overlay.visible = true
				cd_label.text = "%.1f" % cd_remaining
				cd_label.visible = true
			else:
				overlay.visible = false
				cd_label.visible = false

	# ── Defense bar cooldowns ──
	var shared: Array = DataManager.get_shared_abilities() if DataManager.has_method("get_shared_abilities") else []
	for i in range(_defense_cd_overlays.size()):
		var def_overlay: ColorRect = _defense_cd_overlays[i]
		var def_label: Label = _defense_cd_labels[i]
		if not is_instance_valid(def_overlay) or not is_instance_valid(def_label):
			continue

		var def_cd: float = 0.0
		var def_cd_max: float = 1.0
		if i < shared.size() and combat.has_method("get_ability_cooldown"):
			var def_ab: Dictionary = shared[i]
			var def_id: String = str(def_ab.get("id", ""))
			def_cd = maxf(combat.get_ability_cooldown(def_id), gcd_timer)
			def_cd_max = maxf(float(def_ab.get("cooldown", 0)), gcd_max)

		if def_cd > 0.01:
			var frac: float = clampf(def_cd / def_cd_max, 0.0, 1.0)
			def_overlay.size.y = 36.0 * frac
			def_overlay.position.y = 0.0
			def_overlay.visible = true
			def_label.text = "%.0f" % def_cd if def_cd > 1.0 else "%.1f" % def_cd
			def_label.visible = true
		else:
			def_overlay.visible = false
			def_label.visible = false

	# ── Weapon special cooldown ──
	if _special_cd_overlay and is_instance_valid(_special_cd_overlay) and combat.has_method("get_weapon_special_cooldown"):
		var ws_cd: float = combat.get_weapon_special_cooldown()
		var ws_cd_max: float = 30.0  # Default, will use actual
		var spec_data: Dictionary = combat.get_weapon_special_data() if combat.has_method("get_weapon_special_data") else {}
		if not spec_data.is_empty():
			ws_cd_max = maxf(float(spec_data.get("cooldown", 30)), 1.0)
		# Also factor in GCD
		ws_cd = maxf(ws_cd, gcd_timer)
		ws_cd_max = maxf(ws_cd_max, gcd_max)
		if ws_cd > 0.01:
			var frac: float = clampf(ws_cd / ws_cd_max, 0.0, 1.0)
			_special_cd_overlay.size.y = 44.0 * frac
			_special_cd_overlay.position.y = 0.0
			_special_cd_overlay.visible = true
			_special_cd_label.text = "%.0f" % ws_cd if ws_cd > 1.0 else "%.1f" % ws_cd
			_special_cd_label.visible = true
		else:
			_special_cd_overlay.visible = false
			_special_cd_label.visible = false

## Create a styled ability button with keybind + name + cost badge
func _make_ability_btn(keybind: String, label_text: String, accent: Color, cost: int, cost_text_override: String = "", is_icon: bool = false, icon_texture: ImageTexture = null) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(120, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.06, 0.7)
	normal.border_color = accent.darkened(0.35)
	normal.border_color.a = 0.4
	normal.set_border_width_all(0)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.04, 0.06, 0.12, 0.8)
	hover.border_color = accent.darkened(0.1)
	hover.border_color.a = 0.6
	hover.border_width_bottom = 3
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.65)
	pressed.bg_color.a = 0.6
	pressed.border_width_bottom = 0
	pressed.border_width_top = 2
	pressed.border_color = accent.darkened(0.2)
	pressed.border_color.a = 0.4
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.text = ""

	var inner: Control = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(inner)

	# Keybind — top-left
	var key_lbl: Label = Label.new()
	key_lbl.text = keybind
	key_lbl.position = Vector2(4, 1)
	key_lbl.size = Vector2(18, 18)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", accent.lightened(0.15))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(key_lbl)

	# Ability display — pixel art TextureRect, or clipped text fallback
	if icon_texture != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.position = Vector2(48, 6)
		icon_rect.size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_rect)
	else:
		# Text name fallback — clipped with ellipsis
		var name_lbl: Label = Label.new()
		name_lbl.text = label_text
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.position = Vector2(20, 2)
		name_lbl.size = Vector2(96, 20)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", accent)
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
		name_lbl.add_theme_constant_override("shadow_offset_x", 1)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		inner.add_child(name_lbl)

	# Cost badge
	var badge_text: String = cost_text_override if cost_text_override != "" else ("%d ADR" % cost if cost > 0 else "")
	if badge_text != "":
		var cost_lbl: Label = Label.new()
		cost_lbl.text = badge_text
		cost_lbl.position = Vector2(0, 24)
		cost_lbl.size = Vector2(120, 16)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		var badge_color: Color = Color(0.3, 0.75, 0.4, 0.7) if badge_text.begins_with("+") else Color(0.45, 0.55, 0.45, 0.6)
		cost_lbl.add_theme_color_override("font_color", badge_color)
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cost_lbl)

	# ── Cooldown overlay (dark sweep from top, covers button during GCD) ──
	var cd_overlay: ColorRect = ColorRect.new()
	cd_overlay.name = "CooldownOverlay"
	cd_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	cd_overlay.position = Vector2(0, 0)
	cd_overlay.size = Vector2(120, 44)
	cd_overlay.visible = false
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cd_overlay)
	_ability_cd_overlays.append(cd_overlay)

	# Timer text centered over the overlay
	var cd_lbl: Label = Label.new()
	cd_lbl.name = "CooldownLabel"
	cd_lbl.position = Vector2(0, 12)
	cd_lbl.size = Vector2(120, 20)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_lbl.add_theme_font_size_override("font_size", 14)
	cd_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	cd_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	cd_lbl.add_theme_constant_override("shadow_offset_x", 1)
	cd_lbl.add_theme_constant_override("shadow_offset_y", 1)
	cd_lbl.visible = false
	cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cd_lbl)
	_ability_cd_labels.append(cd_lbl)

	return btn

# ── Ability bar swap mode (right-click reorder) ──

## Handle left-click on an ability button (fires ability or completes swap)
func _on_ability_btn_left_click(slot: int) -> void:
	if _swap_mode:
		# In swap mode: left-click on a different button completes the swap
		var target_idx: int = slot - 1
		if target_idx != _swap_source_idx and target_idx >= 0 and target_idx < _ability_buttons.size():
			_perform_ability_swap(_swap_source_idx, target_idx)
		_cancel_swap_mode()
		return
	_use_ability(slot)

## Handle gui_input on ability buttons (right-click to start/complete swap)
func _on_ability_btn_input(event: InputEvent, btn_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _swap_mode:
			if btn_idx == _swap_source_idx:
				# Right-click same button → cancel
				_cancel_swap_mode()
			else:
				# Right-click different button → swap
				_perform_ability_swap(_swap_source_idx, btn_idx)
				_cancel_swap_mode()
		else:
			# Enter swap mode
			_swap_mode = true
			_swap_source_idx = btn_idx
			_update_swap_highlights()
			EventBus.chat_message.emit("Click another ability to swap positions.", "system")
		get_viewport().set_input_as_handled()

## Perform the swap between two ability bar positions
func _perform_ability_swap(from_idx: int, to_idx: int) -> void:
	var style: String = str(GameState.player.get("combat_style", "nano"))

	# Build current order as array of ability IDs
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var combat: Node = _player.get_node_or_null("CombatController")
	if combat == null:
		return
	var active: Array = combat._active_abilities
	if from_idx < 0 or from_idx >= active.size() or to_idx < 0 or to_idx >= active.size():
		return

	# Get names for chat feedback
	var name_a: String = str(active[from_idx].get("name", "?"))
	var name_b: String = str(active[to_idx].get("name", "?"))

	# Build ID order and swap
	var order: Array = []
	for ab in active:
		order.append(str(ab.get("id", "")))
	var tmp: String = order[from_idx]
	order[from_idx] = order[to_idx]
	order[to_idx] = tmp

	# Save to GameState
	var bar_orders: Dictionary = GameState.settings.get("ability_bar_order", {})
	if not bar_orders is Dictionary:
		bar_orders = {}
	bar_orders[style] = order
	GameState.settings["ability_bar_order"] = bar_orders

	# Refresh combat controller and HUD
	combat.refresh_abilities()
	_refresh_ability_buttons()

	EventBus.chat_message.emit("Swapped %s and %s." % [name_a, name_b], "system")

## Cancel swap mode and clear highlights
func _cancel_swap_mode() -> void:
	_swap_mode = false
	_swap_source_idx = -1
	_update_swap_highlights()

## Update visual highlights for swap mode
func _update_swap_highlights() -> void:
	for i in range(_ability_buttons.size()):
		if not is_instance_valid(_ability_buttons[i]):
			continue
		var btn: Button = _ability_buttons[i]
		var style_box: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style_box == null:
			continue
		if _swap_mode and i == _swap_source_idx:
			# Highlight the source button with white pulsing border
			style_box.border_width_top = 2
			style_box.border_width_left = 2
			style_box.border_width_right = 2
			style_box.border_color = Color(1.0, 1.0, 1.0, 0.9)
		else:
			# Reset to normal
			style_box.border_width_top = 0
			style_box.border_width_left = 0
			style_box.border_width_right = 0

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

## Toggle Revolution (auto-fire basic abilities)
func _toggle_revolution() -> void:
	var current: bool = GameState.settings.get("revolution", false)
	GameState.settings["revolution"] = not current
	var active: bool = not current
	# Update button appearance
	if _revolution_btn:
		var rev_color: Color = Color(0.2, 0.9, 0.3) if active else Color(0.4, 0.4, 0.4)
		var style_box: StyleBoxFlat = _revolution_btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style_box:
			style_box.border_color = rev_color
		_revolution_btn.add_theme_color_override("font_color", rev_color)
	var status: String = "ON" if active else "OFF"
	EventBus.chat_message.emit("Revolution %s." % status, "system")

## Use the equipped weapon's special attack
func _use_weapon_special() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var combat: Node = _player.get_node_or_null("CombatController")
		if combat and combat.has_method("use_weapon_special"):
			combat.use_weapon_special()

## Update the special button tooltip based on equipped weapon
func _update_special_btn_tooltip() -> void:
	if _special_btn == null:
		return
	var weapon_id: String = str(GameState.equipment.get("weapon", ""))
	if weapon_id == "":
		_special_btn.tooltip_text = "Weapon Special (S)\nNo weapon equipped"
		return
	var weapon_data: Dictionary = DataManager.get_item(weapon_id)
	var special: Variant = weapon_data.get("special", {})
	if special is Dictionary and not special.is_empty():
		var spec_name: String = str(special.get("name", "Special"))
		var spec_icon: String = str(special.get("icon", ""))
		var spec_desc: String = str(special.get("description", ""))
		var spec_cost: int = int(special.get("adr_cost", 0))
		var spec_cd: int = int(special.get("cooldown", 0))
		_special_btn.tooltip_text = "%s %s — %d ADR | CD: %ds\n%s" % [spec_icon, spec_name, spec_cost, spec_cd, spec_desc]
		# Update icon label to show weapon special icon
		for child in _special_btn.get_children():
			if child is Label and child.text == "SP":
				child.text = spec_icon if spec_icon != "" else "SP"
				break
	else:
		_special_btn.tooltip_text = "Weapon Special (S)\nNo special attack on this weapon"

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
	elif area_id in ["spore-marshes", "hive-tunnels"]:
		_area_toast_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.3, 1.0))
	elif area_id in ["fungal-wastes", "stalker-reaches"]:
		_area_toast_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1.0))
	elif area_id == "void-citadel":
		_area_toast_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.9, 1.0))
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

var _combat_indicator: HBoxContainer = null
var _in_combat_state: bool = false
## Panels hidden by combat mode (to restore when combat ends)
var _combat_hidden_panels: Array[String] = []
var _pre_combat_chat_alpha: float = 1.0

func _build_combat_indicator() -> void:
	_combat_indicator = HBoxContainer.new()
	_combat_indicator.name = "CombatIndicator"
	_combat_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_indicator.position = Vector2(14, 126)
	_combat_indicator.size = Vector2(160, 22)
	_combat_indicator.visible = false
	_combat_indicator.add_theme_constant_override("separation", 4)

	var swords_icon: TextureRect = TextureRect.new()
	swords_icon.custom_minimum_size = Vector2(14, 14)
	swords_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swords_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swords_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	swords_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swords_icon.texture = ItemIcons.get_misc_texture("combat_swords")
	_combat_indicator.add_child(swords_icon)

	var combat_text: Label = Label.new()
	combat_text.text = "IN COMBAT"
	combat_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_text.add_theme_font_size_override("font_size", 14)
	combat_text.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.9))
	combat_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	combat_text.add_theme_constant_override("shadow_offset_x", 1)
	combat_text.add_theme_constant_override("shadow_offset_y", 1)
	_combat_indicator.add_child(combat_text)

	add_child(_combat_indicator)

	# ── Kill streak & combo overlay ──
	_build_streak_combo_overlay()

var _streak_label: Label = null
var _combo_label: Label = null

func _build_streak_combo_overlay() -> void:
	# Kill streak counter
	_streak_label = Label.new()
	_streak_label.name = "KillStreakLabel"
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_label.position = Vector2(14, 148)
	_streak_label.add_theme_font_size_override("font_size", 12)
	_streak_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 0.9))
	_streak_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_streak_label.add_theme_constant_override("shadow_offset_x", 1)
	_streak_label.add_theme_constant_override("shadow_offset_y", 1)
	_streak_label.visible = false
	add_child(_streak_label)

	# Combo progress
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.position = Vector2(14, 164)
	_combo_label.add_theme_font_size_override("font_size", 11)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	_combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_combo_label.add_theme_constant_override("shadow_offset_x", 1)
	_combo_label.add_theme_constant_override("shadow_offset_y", 1)
	_combo_label.visible = false
	add_child(_combo_label)

	# Connect signals
	EventBus.kill_streak_updated.connect(_on_kill_streak_updated)
	EventBus.combo_completed.connect(_on_combo_completed)

func _on_kill_streak_updated(streak: int) -> void:
	if _streak_label == null:
		return
	if streak >= 3:
		_streak_label.text = "Streak: %d" % streak
		_streak_label.visible = true
	else:
		_streak_label.visible = false

func _on_combo_completed(_combo_id: String, combo_name: String) -> void:
	if _combo_label == null:
		return
	_combo_label.text = combo_name + "!"
	_combo_label.visible = true
	# Auto-hide after 3 seconds
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): _combo_label.visible = false)


func _on_combat_started(_enemy_id: String) -> void:
	_in_combat_state = true
	# ── Combat mode: auto-hide non-essential panels ──
	_combat_hidden_panels.clear()
	var hide_map: Dictionary = {
		"skills": _skills_panel,
		"quests": _quest_panel,
		"bestiary": _bestiary_panel,
		"prestige": _prestige_panel,
		"dungeon": _dungeon_panel,
		"pet": _pet_panel,
		"achievement": _achievement_panel,
		"settings": _settings_panel,
	}
	for panel_name in hide_map:
		var panel: PanelContainer = hide_map[panel_name]
		if panel and panel.visible:
			panel.visible = false
			_combat_hidden_panels.append(panel_name)
	# Chat stays fully visible during combat for readability

func _on_combat_ended() -> void:
	_in_combat_state = false
	# ── Combat mode: restore panels after 2s delay ──
	await get_tree().create_timer(2.0).timeout
	if _in_combat_state:
		return  # Re-entered combat, don't restore
	var restore_map: Dictionary = {
		"skills": _skills_panel,
		"quests": _quest_panel,
		"bestiary": _bestiary_panel,
		"prestige": _prestige_panel,
		"dungeon": _dungeon_panel,
		"pet": _pet_panel,
		"achievement": _achievement_panel,
		"settings": _settings_panel,
	}
	for panel_name in _combat_hidden_panels:
		if restore_map.has(panel_name):
			var panel: PanelContainer = restore_map[panel_name]
			if panel:
				panel.visible = true
	_combat_hidden_panels.clear()
	# Chat opacity no longer changes during combat

func _update_combat_indicator() -> void:
	if _combat_indicator == null:
		return
	_combat_indicator.visible = _in_combat_state

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
	_loot_toast_label.add_theme_font_size_override("font_size", 26)
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
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Status label
	_mp_status_label = Label.new()
	_mp_status_label.text = "Disconnected"
	_mp_status_label.add_theme_font_size_override("font_size", 14)
	_mp_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_mp_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mp_status_label)

	# Online count
	_mp_online_label = Label.new()
	_mp_online_label.text = ""
	_mp_online_label.add_theme_font_size_override("font_size", 13)
	_mp_online_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_mp_online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mp_online_label)

	# Name input
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Name:"
	name_lbl.add_theme_font_size_override("font_size", 14)
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
	server_lbl.add_theme_font_size_override("font_size", 14)
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
	_target_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_target_panel)
	# Position above stat bars (bottom-center) instead of top-center
	_reposition_target_panel()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_target_panel.add_child(vbox)

	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vbox.add_child(row1)

	_target_name_label = Label.new()
	_target_name_label.add_theme_font_size_override("font_size", 15)
	_target_name_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.3, 0.95))
	_target_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_target_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_target_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_target_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_target_name_label)

	_target_level_label = Label.new()
	_target_level_label.add_theme_font_size_override("font_size", 14)
	_target_level_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.8))
	row1.add_child(_target_level_label)

	var hp_container: Control = Control.new()
	hp_container.custom_minimum_size = Vector2(288, 16)
	vbox.add_child(hp_container)

	_target_hp_bar = ProgressBar.new()
	_target_hp_bar.custom_minimum_size = Vector2(288, 16)
	_target_hp_bar.position = Vector2.ZERO
	_target_hp_bar.show_percentage = false
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.08, 0.03, 0.03, 0.7)
	hp_bg.set_corner_radius_all(3)
	_target_hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.65, 0.12, 0.08, 0.85)
	hp_fill.set_corner_radius_all(3)
	_target_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_container.add_child(_target_hp_bar)

	_target_hp_label = Label.new()
	_target_hp_label.add_theme_font_size_override("font_size", 12)
	_target_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_target_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_target_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_target_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_target_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_container.add_child(_target_hp_label)

	# Row 3: Style + Weakness
	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	vbox.add_child(row3)

	_target_style_label = Label.new()
	_target_style_label.add_theme_font_size_override("font_size", 13)
	_target_style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(_target_style_label)

	_target_weakness_label = Label.new()
	_target_weakness_label.add_theme_font_size_override("font_size", 13)
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

	# Weakness & resistance — prefer enemy-specific data, fall back to combat triangle
	var weak_str: String = str(tgt.get("weakness")) if "weakness" in tgt else ""
	var resist_str: String = str(tgt.get("resistance")) if "resistance" in tgt else ""
	var weakness_text: String = ""
	var weak_color: Color = Color(0.3, 1.0, 0.3)
	if weak_str != "" or resist_str != "":
		# Enemy has explicit weakness/resistance data
		var parts: Array[String] = []
		if weak_str != "":
			parts.append("Weak: %s" % weak_str.capitalize())
		if resist_str != "":
			parts.append("Resist: %s" % resist_str.capitalize())
		weakness_text = " | ".join(parts)
		# Color based on weakness style
		match weak_str:
			"nano": weak_color = Color(0.3, 0.9, 1.0)
			"tesla": weak_color = Color(1.0, 0.9, 0.2)
			"void": weak_color = Color(0.6, 0.2, 0.9)
			_: weak_color = Color(0.3, 1.0, 0.3)
	else:
		# Fall back to combat triangle
		match estyle:
			"nano":
				weakness_text = "Weak: Void"
				weak_color = Color(0.6, 0.2, 0.9)
			"tesla":
				weakness_text = "Weak: Nano"
				weak_color = Color(0.3, 0.9, 1.0)
			"void":
				weakness_text = "Weak: Tesla"
				weak_color = Color(1.0, 0.9, 0.2)
	_target_weakness_label.text = weakness_text
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
	_gather_label.add_theme_font_size_override("font_size", 13)
	_gather_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
	_gather_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_gather_label.add_theme_constant_override("shadow_offset_x", 1)
	_gather_label.add_theme_constant_override("shadow_offset_y", 1)
	# Position will be updated dynamically by _update_gather_bar_position()
	_gather_label.position = Vector2(0, 0)
	_gather_label.size = Vector2(160, 20)
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
# QoL: AUTO-SAVE INDICATOR — Brief "Game Saved" toast
# ══════════════════════════════════════════════════════════════════

var _save_toast_label: Label = null

func _build_save_toast() -> void:
	_save_toast_label = Label.new()
	_save_toast_label.name = "SaveToast"
	_save_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_toast_label.text = "Game Saved"
	_save_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_toast_label.add_theme_font_size_override("font_size", 14)
	_save_toast_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.85))
	_save_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_save_toast_label.add_theme_constant_override("shadow_offset_x", 1)
	_save_toast_label.add_theme_constant_override("shadow_offset_y", 1)
	var vp_size: Vector2 = _get_viewport_size()
	_save_toast_label.position = Vector2(vp_size.x - 180, vp_size.y - 48)
	_save_toast_label.size = Vector2(170, 24)
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
# QoL: COMBAT STYLE INDICATOR — Shows current style (determined by weapon)
# ══════════════════════════════════════════════════════════════════

var _style_indicator_label: Label = null

func _build_combat_style_indicator() -> void:
	_style_indicator_label = Label.new()
	_style_indicator_label.name = "CombatStyleIndicator"
	_style_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_indicator_label.add_theme_font_size_override("font_size", 13)
	_style_indicator_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_style_indicator_label.add_theme_constant_override("shadow_offset_x", 1)
	_style_indicator_label.add_theme_constant_override("shadow_offset_y", 1)
	_style_indicator_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Added to stat bars container as first child (above HP bar) in _build_stat_bars
	_update_style_indicator()

	# Listen for weapon equip to update style indicator + abilities
	EventBus.item_equipped.connect(_on_item_equipped_for_style)

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
	_style_indicator_label.text = style.capitalize()
	_style_indicator_label.add_theme_color_override("font_color", color)

func _on_item_equipped_for_style(slot: String, _item_id: String) -> void:
	if slot != "weapon":
		return
	# Style is set by equipment_system — just refresh UI
	_update_style_indicator()
	_refresh_ability_buttons()
	_update_special_btn_tooltip()
	_reposition_ability_bar()
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
	_context_menu_title.add_theme_font_size_override("font_size", 14)
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
		btn.custom_minimum_size = Vector2(160, 30)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_normal: StyleBoxFlat = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		btn_normal.set_corner_radius_all(3)
		btn_normal.set_content_margin_all(3)
		btn_normal.content_margin_left = 6
		btn.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.06, 0.1, 0.18, 0.7)
		btn_hover.set_corner_radius_all(3)
		btn_hover.set_content_margin_all(3)
		btn_hover.content_margin_left = 6
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed: StyleBoxFlat = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.08, 0.15, 0.25, 0.7)
		btn_pressed.set_corner_radius_all(3)
		btn_pressed.set_content_margin_all(3)
		btn_pressed.content_margin_left = 6
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
		btn.add_theme_font_size_override("font_size", 14)
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
		"tutorial": _tutorial_panel,
	}

## Save one panel's current state to GameState.panel_layout
func _save_panel_state(panel: PanelContainer, panel_name: String) -> void:
	if panel == null:
		return
	var header: DraggableHeader = panel.find_child("DragHeader", true, false) as DraggableHeader
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
		var header: DraggableHeader = panel.find_child("DragHeader", true, false) as DraggableHeader
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
	var header: DraggableHeader = panel.find_child("DragHeader", true, false) as DraggableHeader
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
	_hover_label.add_theme_font_size_override("font_size", 15)
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
	# Simple check: if mouse is in top 42px or bottom ~90px (compact action bar + ability bar)
	var vp_size: Vector2 = _get_viewport_size()
	if mouse_pos.y < 60 or mouse_pos.y > vp_size.y - 100:
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
		_achievement_panel, _multiplayer_panel, _dialogue_panel,
		_shop_panel, _crafting_panel, _bank_panel, _tutorial_panel
	]
	for panel in panels:
		if panel and panel.visible:
			var header: DraggableHeader = panel.find_child("DragHeader", true, false) as DraggableHeader
			if header and header._is_locked:
				continue
			panel.visible = false

## Handle window resize — reposition anchored elements
func _on_window_resized() -> void:
	var vp: Vector2 = _get_viewport_size()
	# Reposition minimap to top-right corner
	_resize_minimap()
	# Reposition action bar to bottom-center
	_reposition_action_bar()
	# Reposition ability bar to centered above action bar
	_reposition_ability_bar()
	# Reposition stat bars above ability bar
	_reposition_stat_bars()
	# Reposition buff display above stat bars
	_reposition_buff_display()
	# Reposition chat to bottom-left
	_reposition_chat()
	# Reposition FPS/Pos labels to bottom-right
	_reposition_bottom_labels()
	# Reposition tutorial panel to top-center
	_reposition_tutorial_panel()
	# Reposition target info above stat bars
	_reposition_target_panel()
	# Reposition right-anchored panels (inventory, equipment)
	if _inventory_panel:
		_inventory_panel.position.x = vp.x - 260
	if _equipment_panel:
		_equipment_panel.position.x = vp.x - 520
	# Reposition center-anchored panels
	if _crafting_panel and _crafting_panel.visible:
		_crafting_panel.position.x = vp.x / 2.0 - 320
	if _bank_panel and _bank_panel.visible:
		_bank_panel.position = Vector2(vp.x / 2.0 - 200, 60)
	# Reposition world map to screen center
	if _world_map_panel and _world_map_panel.visible:
		_world_map_panel.position = Vector2(vp.x / 2.0 - 310, vp.y / 2.0 - 270)

## Reposition the bottom action bar (compact 2x6 grid) to horizontal center
func _reposition_action_bar() -> void:
	if _action_bar_bg == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	await get_tree().process_frame
	var bar_w: float = _action_bar_bg.size.x
	if bar_w < 10:
		bar_w = 282.0  # 7 buttons * 36px + 6 gaps * 3px + padding ~282px
	var bar_h: float = _action_bar_bg.size.y
	if bar_h < 10:
		bar_h = 84.0  # 2 rows * 36px + gap + padding
	_action_bar_bg.position = Vector2(vp_size.x / 2.0 - bar_w / 2.0, vp_size.y - bar_h - 4)

## Reposition target info panel above stat bars (bottom-center)
func _reposition_target_panel() -> void:
	if _target_panel == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	# Place near top-center of screen for easy visibility
	_target_panel.position = Vector2(vp_size.x / 2.0 - 150, 10)

## Reposition FPS and Position labels to bottom-right
func _reposition_bottom_labels() -> void:
	var vp_size: Vector2 = _get_viewport_size()
	# Place above the action bar to avoid overlap
	if fps_label:
		fps_label.position = Vector2(vp_size.x - 100, vp_size.y - 100)
	if pos_label:
		pos_label.position = Vector2(vp_size.x - 200, vp_size.y - 100)

func _reposition_tutorial_panel() -> void:
	if _tutorial_panel == null:
		return
	var vp_size: Vector2 = _get_viewport_size()
	_tutorial_panel.position = Vector2(vp_size.x / 2.0 - 180, 16)


## Minimap camera zoom — scroll wheel or +/- buttons
var _minimap_zoom_level: int = 0  # 0=small, 1=medium, 2=large (panel size)
var _minimap_cam_zoom: float = 80.0  # Camera ortho size (smaller = zoomed in)
const MINIMAP_CAM_ZOOM_MIN: float = 20.0  # Closest zoom
const MINIMAP_CAM_ZOOM_MAX: float = 250.0  # Farthest zoom
const MINIMAP_CAM_ZOOM_STEP: float = 15.0  # Per scroll tick
var _minimap_zoom_label: Label = null

func _minimap_zoom_in() -> void:
	_minimap_cam_zoom = maxf(_minimap_cam_zoom - MINIMAP_CAM_ZOOM_STEP, MINIMAP_CAM_ZOOM_MIN)
	if _minimap_camera:
		_minimap_camera.size = _minimap_cam_zoom
	_update_minimap_zoom_label()

func _minimap_zoom_out() -> void:
	_minimap_cam_zoom = minf(_minimap_cam_zoom + MINIMAP_CAM_ZOOM_STEP, MINIMAP_CAM_ZOOM_MAX)
	if _minimap_camera:
		_minimap_camera.size = _minimap_cam_zoom
	_update_minimap_zoom_label()

func _update_minimap_zoom_label() -> void:
	if _minimap_zoom_label:
		var pct: int = int(100.0 * (MINIMAP_CAM_ZOOM_MAX - _minimap_cam_zoom) / (MINIMAP_CAM_ZOOM_MAX - MINIMAP_CAM_ZOOM_MIN))
		_minimap_zoom_label.text = "%d%%" % pct

func _cycle_minimap_zoom() -> void:
	_minimap_zoom_level = (_minimap_zoom_level + 1) % 3
	_resize_minimap()

func _resize_minimap() -> void:
	if _minimap_container == null or _minimap_viewport == null:
		return

	var sizes: Array[int] = [360, 500, 680]
	var cam_defaults: Array[float] = [80.0, 120.0, 180.0]
	var map_size: int = sizes[_minimap_zoom_level]
	# Keep current camera zoom unless panel size changes
	_minimap_cam_zoom = cam_defaults[_minimap_zoom_level]

	# Update container position and size (use actual viewport, not design size)
	var vp_size: Vector2 = _get_viewport_size()
	_minimap_container.position = Vector2(vp_size.x - map_size - 16, 4)
	_minimap_container.custom_minimum_size = Vector2(map_size, map_size)

	# Update viewport size
	_minimap_viewport.size = Vector2i(map_size - 6, map_size - 22)

	# Update camera orthographic size
	if _minimap_camera:
		_minimap_camera.size = _minimap_cam_zoom

	# Update TextureRect size directly
	if _minimap_tex_rect:
		_minimap_tex_rect.custom_minimum_size = Vector2(map_size - 6, map_size - 22)

	# Update player dot/arrow position (centered)
	var center_pos: Vector2 = Vector2((map_size - 6) / 2.0, -((map_size - 22) / 2.0))
	if _minimap_player_dot:
		_minimap_player_dot.position = center_pos
	if _minimap_player_arrow:
		_minimap_player_arrow.position = center_pos

	_update_minimap_zoom_label()
	EventBus.chat_message.emit("Minimap: %s" % ["Small", "Medium", "Large"][_minimap_zoom_level], "system")

# ══════════════════════════════════════════════════════════════════
# MINIMAP — Top-right corner with SubViewport showing top-down view
# ══════════════════════════════════════════════════════════════════

var _minimap_container: PanelContainer = null
var _minimap_viewport: SubViewport = null
var _minimap_camera: Camera3D = null
var _minimap_player_dot: ColorRect = null
var _minimap_area_label: Label = null
var _minimap_level_label: Label = null
var _minimap_tex_rect: TextureRect = null
var _minimap_enemy_dots: Array[ColorRect] = []
var _minimap_npc_dots: Array[ColorRect] = []
var _minimap_gather_dots: Array[ColorRect] = []
var _minimap_dot_container: Control = null
var _minimap_dot_timer: float = 0.0  # Throttle dot updates to 5 FPS
var _minimap_player_arrow: Polygon2D = null
const MINIMAP_DOT_POOL_SIZE: int = 30
const MINIMAP_GATHER_POOL_SIZE: int = 20

# ── Full map panel ──
var _full_map_panel: PanelContainer = null
var _full_map_viewport: SubViewport = null
var _full_map_camera: Camera3D = null

func _build_minimap() -> void:
	var map_size: int = 360

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

	# Centered player arrow overlay (triangle pointing up = forward)
	var dot_container: Control = Control.new()
	dot_container.custom_minimum_size = Vector2(map_size - 6, 0)
	dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(dot_container)

	# Keep the old ColorRect hidden as a position anchor
	_minimap_player_dot = ColorRect.new()
	_minimap_player_dot.color = Color(0, 0, 0, 0)  # Invisible anchor
	_minimap_player_dot.size = Vector2(1, 1)
	_minimap_player_dot.position = Vector2((map_size - 6) / 2.0, -((map_size - 22) / 2.0))
	_minimap_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_container.add_child(_minimap_player_dot)

	# Directional arrow using Polygon2D — points upward by default
	_minimap_player_arrow = Polygon2D.new()
	_minimap_player_arrow.polygon = PackedVector2Array([
		Vector2(0, -10),   # Tip (forward/up)
		Vector2(-8, 8),    # Bottom-left
		Vector2(0, 4),     # Notch
		Vector2(8, 8),     # Bottom-right
	])
	_minimap_player_arrow.color = Color(0.1, 1.0, 0.3, 0.95)
	_minimap_player_arrow.position = _minimap_player_dot.position
	dot_container.add_child(_minimap_player_arrow)

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
		edot.size = Vector2(7, 7)
		edot.visible = false
		edot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_dot_container.add_child(edot)
		_minimap_enemy_dots.append(edot)

	# Pre-create NPC dots (cyan)
	for _i in range(8):
		var ndot: ColorRect = ColorRect.new()
		ndot.color = Color(0.2, 0.9, 1.0, 0.9)
		ndot.size = Vector2(8, 8)
		ndot.visible = false
		ndot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_dot_container.add_child(ndot)
		_minimap_npc_dots.append(ndot)

	# Pre-create gathering node dots (yellow)
	for _i in range(MINIMAP_GATHER_POOL_SIZE):
		var gdot: ColorRect = ColorRect.new()
		gdot.color = Color(1.0, 0.85, 0.15, 0.85)
		gdot.size = Vector2(7, 7)
		gdot.visible = false
		gdot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_dot_container.add_child(gdot)
		_minimap_gather_dots.append(gdot)

	# Bottom row: area label + legend + map button
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bottom_row)

	# Area name + level range in a vertical stack
	var area_info_vbox: VBoxContainer = VBoxContainer.new()
	area_info_vbox.add_theme_constant_override("separation", 0)
	area_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(area_info_vbox)

	_minimap_area_label = Label.new()
	_minimap_area_label.name = "MinimapArea"
	_minimap_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_area_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap_area_label.add_theme_font_size_override("font_size", 11)
	_minimap_area_label.add_theme_color_override("font_color", Color(0.35, 0.55, 0.65, 0.7))
	_minimap_area_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_info_vbox.add_child(_minimap_area_label)

	_minimap_level_label = Label.new()
	_minimap_level_label.name = "MinimapLevel"
	_minimap_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap_level_label.add_theme_font_size_override("font_size", 9)
	_minimap_level_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.35, 0.6))
	_minimap_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_info_vbox.add_child(_minimap_level_label)

	var map_btn: Button = Button.new()
	map_btn.text = "M"
	map_btn.add_theme_font_size_override("font_size", 12)
	map_btn.tooltip_text = "Open Map"
	map_btn.custom_minimum_size = Vector2(22, 16)
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

	# Zoom controls row: [-] [zoom %] [+]
	var zoom_row: HBoxContainer = HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 2)
	zoom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(zoom_row)

	var zoom_btn_style: StyleBoxFlat = StyleBoxFlat.new()
	zoom_btn_style.bg_color = Color(0.05, 0.08, 0.15, 0.5)
	zoom_btn_style.set_corner_radius_all(2)
	zoom_btn_style.set_content_margin_all(0)
	var zoom_btn_hover: StyleBoxFlat = zoom_btn_style.duplicate()
	zoom_btn_hover.bg_color = Color(0.1, 0.18, 0.3, 0.7)

	var zoom_out_btn: Button = Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.add_theme_font_size_override("font_size", 14)
	zoom_out_btn.custom_minimum_size = Vector2(22, 16)
	zoom_out_btn.add_theme_stylebox_override("normal", zoom_btn_style)
	zoom_out_btn.add_theme_stylebox_override("hover", zoom_btn_hover)
	zoom_out_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8, 0.7))
	zoom_out_btn.add_theme_color_override("font_hover_color", Color(0.5, 0.75, 0.95))
	zoom_out_btn.tooltip_text = "Zoom Out"
	zoom_out_btn.pressed.connect(_minimap_zoom_out)
	zoom_row.add_child(zoom_out_btn)

	_minimap_zoom_label = Label.new()
	_minimap_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_zoom_label.custom_minimum_size = Vector2(40, 0)
	_minimap_zoom_label.add_theme_font_size_override("font_size", 10)
	_minimap_zoom_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65, 0.7))
	_minimap_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_row.add_child(_minimap_zoom_label)
	_update_minimap_zoom_label()

	var zoom_in_btn: Button = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.add_theme_font_size_override("font_size", 14)
	zoom_in_btn.custom_minimum_size = Vector2(22, 16)
	zoom_in_btn.add_theme_stylebox_override("normal", zoom_btn_style.duplicate())
	zoom_in_btn.add_theme_stylebox_override("hover", zoom_btn_hover.duplicate())
	zoom_in_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8, 0.7))
	zoom_in_btn.add_theme_color_override("font_hover_color", Color(0.5, 0.75, 0.95))
	zoom_in_btn.tooltip_text = "Zoom In"
	zoom_in_btn.pressed.connect(_minimap_zoom_in)
	zoom_row.add_child(zoom_in_btn)

	# Legend row — minimal
	var legend: HBoxContainer = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 3)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(legend)

	var legend_items: Array = [
		{"color": Color(0.1, 0.85, 0.3, 0.8), "label": "You"},
		{"color": Color(0.9, 0.2, 0.1, 0.8), "label": "Foe"},
		{"color": Color(0.2, 0.8, 0.9, 0.8), "label": "NPC"},
		{"color": Color(1.0, 0.85, 0.15, 0.8), "label": "Node"},
	]
	for item in legend_items:
		var ldot: ColorRect = ColorRect.new()
		ldot.custom_minimum_size = Vector2(8, 8)
		ldot.color = item["color"]
		ldot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(ldot)
		var lbl: Label = Label.new()
		lbl.text = item["label"]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 0.65))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(lbl)

## Handle click/scroll on minimap — click to walk, scroll to zoom
func _on_minimap_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Scroll wheel zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_minimap_zoom_in()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_minimap_zoom_out()
			get_viewport().set_input_as_handled()
			return
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
## Toggle world map — opens the 2D node graph world map panel
func _toggle_world_map_panel() -> void:
	if _world_map_panel and is_instance_valid(_world_map_panel):
		_world_map_panel.visible = not _world_map_panel.visible
		if _world_map_panel.visible:
			EventBus.panel_opened.emit("world_map")
			if _world_map_panel.has_method("refresh"):
				_world_map_panel.refresh()
		else:
			EventBus.panel_closed.emit("world_map")
		return

	# Build world map panel on first open
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	panel_style.border_color = Color(0.15, 0.35, 0.5, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(8)

	_world_map_panel = PanelContainer.new()
	_world_map_panel.set_script(world_map_script)
	_world_map_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_world_map_panel)

	# Center on screen
	var vp_size: Vector2 = _get_viewport_size()
	_world_map_panel.position = Vector2(
		vp_size.x / 2.0 - 310,
		vp_size.y / 2.0 - 270
	)
	EventBus.panel_opened.emit("world_map")

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
	var header: DraggableHeader = _full_map_panel.find_child("DragHeader", true, false) as DraggableHeader
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

	# Update level range label on minimap
	if _minimap_level_label:
		var level_range: Dictionary = DataManager.area_level_ranges.get(GameState.current_area, {})
		if not level_range.is_empty():
			var min_lv: int = int(level_range.get("min", 0))
			var max_lv: int = int(level_range.get("max", 0))
			_minimap_level_label.text = "Lv %d-%d" % [min_lv, max_lv]
			_minimap_level_label.visible = true
		else:
			_minimap_level_label.text = ""
			_minimap_level_label.visible = false

	# Update entity dots on minimap (throttled — 5 FPS is plenty for dots)
	_minimap_dot_timer += get_process_delta_time()
	if _minimap_dot_timer >= 0.2:
		_minimap_dot_timer = 0.0
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
	# Forward rotation (world → screen): use +cam_rot_y
	# (inverse -cam_rot_y is for screen → world, e.g. click-to-walk)
	var cos_r: float = cos(cam_rot_y)
	var sin_r: float = sin(cam_rot_y)

	# Hide all dots first
	for dot in _minimap_enemy_dots:
		dot.visible = false
	for dot in _minimap_npc_dots:
		dot.visible = false
	for dot in _minimap_gather_dots:
		dot.visible = false

	# Aspect ratio correction — orthographic cam.size is vertical extent
	var aspect: float = tex_size.x / tex_size.y if tex_size.y > 0 else 1.0
	var cam_h: float = cam_size           # vertical world units
	var cam_w: float = cam_size * aspect   # horizontal world units

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
		var px: float = (rx / cam_w) * tex_size.x + tex_size.x * 0.5
		var py: float = (rz / cam_h) * tex_size.y + tex_size.y * 0.5
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
		var px: float = (rx / cam_w) * tex_size.x + tex_size.x * 0.5
		var py: float = (rz / cam_h) * tex_size.y + tex_size.y * 0.5
		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			_minimap_npc_dots[idx].position = Vector2(px - 2, -(tex_size.y) + py - 2)
			_minimap_npc_dots[idx].visible = true
			idx += 1

	# Plot gathering nodes (yellow dots) — skip depleted ones
	idx = 0
	for gnode in get_tree().get_nodes_in_group("gathering_nodes"):
		if idx >= _minimap_gather_dots.size():
			break
		if not is_instance_valid(gnode):
			continue
		if "_is_depleted" in gnode and gnode._is_depleted:
			continue
		var dx: float = gnode.global_position.x - player_pos.x
		var dz: float = gnode.global_position.z - player_pos.z
		var rx: float = dx * cos_r - dz * sin_r
		var rz: float = dx * sin_r + dz * cos_r
		var px: float = (rx / cam_w) * tex_size.x + tex_size.x * 0.5
		var py: float = (rz / cam_h) * tex_size.y + tex_size.y * 0.5
		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			_minimap_gather_dots[idx].position = Vector2(px - 2, -(tex_size.y) + py - 2)
			_minimap_gather_dots[idx].visible = true
			idx += 1
