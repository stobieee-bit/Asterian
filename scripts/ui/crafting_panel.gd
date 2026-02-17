## CraftingPanel — Modern crafting interface for processing stations
##
## Split-panel design: recipe list (left) + detail view (right).
## Features search/filter, have/need color-coding, bulk craft buttons,
## skill progress bar, and styled recipe cards.
extends PanelContainer

# ── State ──
var _skill_id: String = ""
var _station_name: String = ""
var _crafting_sys: Node = null
var _all_recipes: Array = []
var _filtered_recipes: Array = []
var _selected_recipe_id: String = ""
var _search_text: String = ""
var _filter_mode: int = 0  # 0 = All, 1 = Craftable, 2 = Locked

# ── Constants ──
const PANEL_WIDTH: int = 620
const PANEL_HEIGHT: int = 440
const LIST_WIDTH: int = 240
const DETAIL_WIDTH: int = 340

# ── Colors ──
const COL_BG_CARD: Color = Color(0.035, 0.05, 0.08, 0.7)
const COL_BG_CARD_HOVER: Color = Color(0.06, 0.08, 0.14, 0.85)
const COL_BG_CARD_SELECTED: Color = Color(0.06, 0.1, 0.2, 0.9)
const COL_ACCENT: Color = Color(0.2, 0.6, 0.9)
const COL_CRAFTABLE: Color = Color(0.35, 0.85, 0.4)
const COL_LOCKED: Color = Color(0.55, 0.35, 0.35)
const COL_HAVE_ENOUGH: Color = Color(0.3, 0.85, 0.35)
const COL_NEED_MORE: Color = Color(0.9, 0.3, 0.25)
const COL_TEXT_DIM: Color = Color(0.45, 0.5, 0.55)
const COL_TEXT_BRIGHT: Color = Color(0.85, 0.9, 0.92)
const COL_XP: Color = Color(0.3, 0.85, 0.3)
const COL_SEPARATOR: Color = Color(0.1, 0.15, 0.25, 0.35)

# ── Node refs (left panel) ──
var _title_label: Label = null
var _search_input: LineEdit = null
var _filter_buttons: Array[Button] = []
var _skill_bar: ProgressBar = null
var _skill_level_label: Label = null
var _recipe_scroll: ScrollContainer = null
var _recipe_list: VBoxContainer = null
var _recipe_cards: Array[PanelContainer] = []

# ── Node refs (right panel) ──
var _detail_container: VBoxContainer = null
var _detail_name_label: Label = null
var _detail_level_label: Label = null
var _detail_xp_label: Label = null
var _detail_desc_label: Label = null
var _input_grid: GridContainer = null
var _output_grid: GridContainer = null
var _craft_buttons_row: HBoxContainer = null
var _craft_1_btn: Button = null
var _craft_5_btn: Button = null
var _craft_all_btn: Button = null
var _craft_x_btn: Button = null
var _craft_x_input: SpinBox = null
var _empty_detail_label: Label = null
var _status_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# ── Header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Crafting", _on_close)
	drag_header.name = "DragHeader"
	root_vbox.add_child(drag_header)
	_title_label = drag_header._title_label

	# Skill progress bar under header
	var skill_row: HBoxContainer = HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 6)
	skill_row.custom_minimum_size = Vector2(0, 20)
	root_vbox.add_child(skill_row)

	_skill_level_label = Label.new()
	_skill_level_label.add_theme_font_size_override("font_size", 11)
	_skill_level_label.add_theme_color_override("font_color", COL_ACCENT)
	_skill_level_label.custom_minimum_size = Vector2(60, 0)
	skill_row.add_child(_skill_level_label)

	_skill_bar = ProgressBar.new()
	_skill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_bar.custom_minimum_size = Vector2(0, 14)
	_skill_bar.show_percentage = false
	_skill_bar.min_value = 0.0
	_skill_bar.max_value = 1.0
	skill_row.add_child(_skill_bar)

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.06, 0.1, 0.7)
	bar_bg.set_corner_radius_all(3)
	_skill_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = COL_ACCENT.darkened(0.15)
	bar_fill.set_corner_radius_all(3)
	_skill_bar.add_theme_stylebox_override("fill", bar_fill)

	# Thin separator
	var header_sep: HSeparator = HSeparator.new()
	header_sep.add_theme_constant_override("separation", 4)
	header_sep.add_theme_stylebox_override("separator", _make_separator_style())
	root_vbox.add_child(header_sep)

	# ── Main split: left list + right detail ──
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(split)

	# ── LEFT PANEL — Recipe List ──
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	left_panel.add_theme_constant_override("separation", 4)
	split.add_child(left_panel)

	# Search bar
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search recipes..."
	_search_input.add_theme_font_size_override("font_size", 12)
	_search_input.custom_minimum_size = Vector2(0, 26)
	_search_input.clear_button_enabled = true
	left_panel.add_child(_search_input)

	var search_style: StyleBoxFlat = StyleBoxFlat.new()
	search_style.bg_color = Color(0.03, 0.04, 0.07, 0.8)
	search_style.border_color = Color(0.1, 0.18, 0.3, 0.5)
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(3)
	search_style.set_content_margin_all(4)
	_search_input.add_theme_stylebox_override("normal", search_style)

	var search_focus: StyleBoxFlat = search_style.duplicate()
	search_focus.border_color = COL_ACCENT.darkened(0.2)
	_search_input.add_theme_stylebox_override("focus", search_focus)
	_search_input.text_changed.connect(_on_search_changed)

	# Filter buttons row
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 2)
	left_panel.add_child(filter_row)

	var filter_labels: Array[String] = ["All", "Craftable", "Locked"]
	for i in range(filter_labels.size()):
		var fbtn: Button = Button.new()
		fbtn.text = filter_labels[i]
		fbtn.add_theme_font_size_override("font_size", 10)
		fbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fbtn.custom_minimum_size = Vector2(0, 20)
		fbtn.focus_mode = Control.FOCUS_NONE
		fbtn.pressed.connect(_on_filter_changed.bind(i))
		_apply_filter_button_style(fbtn, i == 0)
		filter_row.add_child(fbtn)
		_filter_buttons.append(fbtn)

	# Recipe scrollable list
	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(_recipe_scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 3)
	_recipe_scroll.add_child(_recipe_list)

	# Vertical separator between panels
	var vsep: VSeparator = VSeparator.new()
	vsep.add_theme_constant_override("separation", 6)
	vsep.add_theme_stylebox_override("separator", _make_vseparator_style())
	split.add_child(vsep)

	# ── RIGHT PANEL — Detail View ──
	# Use a MarginContainer to hold the right panel content with proper sizing
	var right_wrapper: MarginContainer = MarginContainer.new()
	right_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_wrapper.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	split.add_child(right_wrapper)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_wrapper.add_child(right_scroll)

	# Single child inside scroll — a VBox that holds both empty label and detail
	var right_content: VBoxContainer = VBoxContainer.new()
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_content.add_theme_constant_override("separation", 0)
	right_scroll.add_child(right_content)

	# Empty state label
	_empty_detail_label = Label.new()
	_empty_detail_label.text = "Select a recipe to\nview details"
	_empty_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_detail_label.add_theme_font_size_override("font_size", 13)
	_empty_detail_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_empty_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_detail_label.custom_minimum_size = Vector2(0, 300)
	right_content.add_child(_empty_detail_label)

	_detail_container = VBoxContainer.new()
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_container.add_theme_constant_override("separation", 6)
	_detail_container.visible = false
	right_content.add_child(_detail_container)

	# ── Detail: Recipe name ──
	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 16)
	_detail_name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	_detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_container.add_child(_detail_name_label)

	# Level + XP row
	var level_xp_row: HBoxContainer = HBoxContainer.new()
	level_xp_row.add_theme_constant_override("separation", 12)
	_detail_container.add_child(level_xp_row)

	_detail_level_label = Label.new()
	_detail_level_label.add_theme_font_size_override("font_size", 12)
	level_xp_row.add_child(_detail_level_label)

	_detail_xp_label = Label.new()
	_detail_xp_label.add_theme_font_size_override("font_size", 12)
	_detail_xp_label.add_theme_color_override("font_color", COL_XP)
	level_xp_row.add_child(_detail_xp_label)

	# Detail separator
	var det_sep1: HSeparator = HSeparator.new()
	det_sep1.add_theme_constant_override("separation", 4)
	det_sep1.add_theme_stylebox_override("separator", _make_separator_style())
	_detail_container.add_child(det_sep1)

	# ── Ingredients section ──
	var ing_header: Label = Label.new()
	ing_header.text = "INGREDIENTS"
	ing_header.add_theme_font_size_override("font_size", 10)
	ing_header.add_theme_color_override("font_color", COL_TEXT_DIM)
	_detail_container.add_child(ing_header)

	_input_grid = GridContainer.new()
	_input_grid.columns = 1
	_input_grid.add_theme_constant_override("v_separation", 4)
	_detail_container.add_child(_input_grid)

	# ── Output section ──
	var det_sep2: HSeparator = HSeparator.new()
	det_sep2.add_theme_constant_override("separation", 4)
	det_sep2.add_theme_stylebox_override("separator", _make_separator_style())
	_detail_container.add_child(det_sep2)

	var out_header: Label = Label.new()
	out_header.text = "OUTPUT"
	out_header.add_theme_font_size_override("font_size", 10)
	out_header.add_theme_color_override("font_color", COL_TEXT_DIM)
	_detail_container.add_child(out_header)

	_output_grid = GridContainer.new()
	_output_grid.columns = 1
	_output_grid.add_theme_constant_override("v_separation", 4)
	_detail_container.add_child(_output_grid)

	# Another separator
	var det_sep3: HSeparator = HSeparator.new()
	det_sep3.add_theme_constant_override("separation", 6)
	det_sep3.add_theme_stylebox_override("separator", _make_separator_style())
	_detail_container.add_child(det_sep3)

	# ── Craft buttons ──
	_craft_buttons_row = HBoxContainer.new()
	_craft_buttons_row.add_theme_constant_override("separation", 4)
	_detail_container.add_child(_craft_buttons_row)

	_craft_1_btn = _make_craft_button("Craft 1", COL_ACCENT)
	_craft_1_btn.pressed.connect(_on_craft_amount.bind(1))
	_craft_buttons_row.add_child(_craft_1_btn)

	_craft_5_btn = _make_craft_button("Craft 5", COL_ACCENT)
	_craft_5_btn.pressed.connect(_on_craft_amount.bind(5))
	_craft_buttons_row.add_child(_craft_5_btn)

	_craft_all_btn = _make_craft_button("All", COL_CRAFTABLE)
	_craft_all_btn.pressed.connect(_on_craft_all)
	_craft_buttons_row.add_child(_craft_all_btn)

	# Custom amount row
	var custom_row: HBoxContainer = HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 4)
	_detail_container.add_child(custom_row)

	_craft_x_input = SpinBox.new()
	_craft_x_input.min_value = 1
	_craft_x_input.max_value = 999
	_craft_x_input.value = 1
	_craft_x_input.step = 1
	_craft_x_input.custom_minimum_size = Vector2(80, 28)
	_craft_x_input.add_theme_font_size_override("font_size", 12)
	_craft_x_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(_craft_x_input)

	_craft_x_btn = _make_craft_button("Craft X", COL_ACCENT)
	_craft_x_btn.pressed.connect(_on_craft_x)
	custom_row.add_child(_craft_x_btn)

	# Status message
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_container.add_child(_status_label)

	visible = false
	z_index = 55

# ── PUBLIC API ──

## Open crafting for a specific skill
func open_crafting(skill_id: String, station_name: String) -> void:
	_skill_id = skill_id
	_station_name = station_name
	_title_label.text = station_name

	_crafting_sys = get_tree().get_first_node_in_group("crafting_system")
	_selected_recipe_id = ""
	_search_text = ""
	_filter_mode = 0
	_search_input.text = ""

	# Reset filter button styles
	for i in range(_filter_buttons.size()):
		_apply_filter_button_style(_filter_buttons[i], i == 0)

	visible = true
	refresh()

## Full refresh — reloads recipes and rebuilds both panels
func refresh() -> void:
	if _crafting_sys == null:
		_crafting_sys = get_tree().get_first_node_in_group("crafting_system")

	_all_recipes = DataManager.get_recipes_for_skill(_skill_id)

	# Sort by level
	_all_recipes.sort_custom(func(a, b): return int(a.get("level", 0)) < int(b.get("level", 0)))

	_apply_filters()
	_rebuild_recipe_list()
	_update_skill_bar()
	_refresh_detail()

# ── FILTERING ──

func _apply_filters() -> void:
	_filtered_recipes = []
	var player_level: int = int(GameState.skills.get(_skill_id, {}).get("level", 1))

	for recipe in _all_recipes:
		var recipe_name: String = str(recipe.get("name", "")).to_lower()
		var recipe_id: String = str(recipe.get("id", "")).to_lower()
		var req_level: int = int(recipe.get("level", 1))

		# Search filter
		if _search_text != "":
			var search_lower: String = _search_text.to_lower()
			if search_lower not in recipe_name and search_lower not in recipe_id:
				# Also search ingredient/output names
				var found_in_items: bool = false
				for item_id in recipe.get("input", {}):
					var item_data: Dictionary = DataManager.get_item(item_id)
					if search_lower in str(item_data.get("name", item_id)).to_lower():
						found_in_items = true
						break
				if not found_in_items:
					for item_id in recipe.get("output", {}):
						var item_data: Dictionary = DataManager.get_item(item_id)
						if search_lower in str(item_data.get("name", item_id)).to_lower():
							found_in_items = true
							break
				if not found_in_items:
					continue

		# Tab filter
		match _filter_mode:
			1:  # Craftable only
				if player_level < req_level:
					continue
				var can_do: bool = _crafting_sys != null and _crafting_sys.has_method("can_craft") and _crafting_sys.can_craft(str(recipe.get("id", "")))
				if not can_do:
					continue
			2:  # Locked only
				if player_level >= req_level:
					continue

		_filtered_recipes.append(recipe)

func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_apply_filters()
	_rebuild_recipe_list()

func _on_filter_changed(mode: int) -> void:
	_filter_mode = mode
	for i in range(_filter_buttons.size()):
		_apply_filter_button_style(_filter_buttons[i], i == mode)
	_apply_filters()
	_rebuild_recipe_list()

# ── RECIPE LIST ──

func _rebuild_recipe_list() -> void:
	# Clear old cards
	for child in _recipe_list.get_children():
		child.queue_free()
	_recipe_cards.clear()

	var player_level: int = int(GameState.skills.get(_skill_id, {}).get("level", 1))

	if _filtered_recipes.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No recipes found"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_recipe_list.add_child(empty_lbl)
		return

	for recipe in _filtered_recipes:
		var recipe_id: String = str(recipe.get("id", ""))
		var recipe_name: String = str(recipe.get("name", recipe_id))
		var req_level: int = int(recipe.get("level", 1))
		var is_selected: bool = recipe_id == _selected_recipe_id
		var meets_level: bool = player_level >= req_level
		var can_craft: bool = _crafting_sys != null and _crafting_sys.has_method("can_craft") and _crafting_sys.can_craft(recipe_id)

		var card: PanelContainer = _make_recipe_card(recipe_id, recipe_name, req_level, meets_level, can_craft, is_selected)
		_recipe_list.add_child(card)
		_recipe_cards.append(card)

func _make_recipe_card(recipe_id: String, recipe_name: String, req_level: int, meets_level: bool, can_craft: bool, is_selected: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 38)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Card style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = COL_BG_CARD_SELECTED
		style.border_color = COL_ACCENT.darkened(0.15)
		style.set_border_width_all(1)
		style.border_width_left = 3
	else:
		style.bg_color = COL_BG_CARD
		style.border_color = Color(0.08, 0.12, 0.2, 0.3)
		style.set_border_width_all(1)
		style.border_width_left = 3
		if can_craft:
			style.border_color = COL_CRAFTABLE.darkened(0.4)
		elif not meets_level:
			style.border_color = COL_LOCKED.darkened(0.3)

	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	# Card content
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Status indicator dot
	var dot: Label = Label.new()
	if can_craft:
		dot.text = "●"
		dot.add_theme_color_override("font_color", COL_CRAFTABLE)
	elif meets_level:
		dot.text = "○"
		dot.add_theme_color_override("font_color", COL_TEXT_DIM)
	else:
		dot.text = "✕"
		dot.add_theme_color_override("font_color", COL_LOCKED)
	dot.add_theme_font_size_override("font_size", 10)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(dot)

	# Name + level column
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 0)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = recipe_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if meets_level:
		name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	else:
		name_lbl.add_theme_color_override("font_color", COL_LOCKED)
	info_vbox.add_child(name_lbl)

	var level_lbl: Label = Label.new()
	level_lbl.text = "Lv %d" % req_level
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if meets_level:
		level_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	else:
		level_lbl.add_theme_color_override("font_color", COL_LOCKED.darkened(0.2))
	info_vbox.add_child(level_lbl)

	# Click handler — use gui_input for proper handling
	card.gui_input.connect(_on_card_input.bind(recipe_id))

	# Hover effects
	card.mouse_entered.connect(_on_card_hover.bind(card, true, is_selected))
	card.mouse_exited.connect(_on_card_hover.bind(card, false, is_selected))

	return card

func _on_card_input(event: InputEvent, recipe_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_recipe_id = recipe_id
		_rebuild_recipe_list()
		_refresh_detail()

func _on_card_hover(card: PanelContainer, entering: bool, is_selected: bool) -> void:
	if is_selected:
		return
	var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if entering:
			style.bg_color = COL_BG_CARD_HOVER
		else:
			style.bg_color = COL_BG_CARD

# ── DETAIL PANEL ──

func _refresh_detail() -> void:
	if _selected_recipe_id == "":
		_detail_container.visible = false
		_empty_detail_label.visible = true
		return

	_detail_container.visible = true
	_empty_detail_label.visible = false

	var recipe: Dictionary = DataManager.get_recipe(_selected_recipe_id)
	if recipe.is_empty():
		_detail_container.visible = false
		_empty_detail_label.visible = true
		return

	var recipe_name: String = str(recipe.get("name", _selected_recipe_id))
	var req_level: int = int(recipe.get("level", 1))
	var xp: int = int(recipe.get("xp", 0))
	var inputs: Dictionary = recipe.get("input", {})
	var outputs: Dictionary = recipe.get("output", {})
	var player_level: int = int(GameState.skills.get(_skill_id, {}).get("level", 1))
	var meets_level: bool = player_level >= req_level

	# Name
	_detail_name_label.text = recipe_name
	if meets_level:
		_detail_name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	else:
		_detail_name_label.add_theme_color_override("font_color", COL_LOCKED)

	# Level
	if meets_level:
		_detail_level_label.text = "Level %d" % req_level
		_detail_level_label.add_theme_color_override("font_color", COL_ACCENT)
	else:
		_detail_level_label.text = "Requires Level %d" % req_level
		_detail_level_label.add_theme_color_override("font_color", COL_NEED_MORE)

	# XP
	var skill_data: Dictionary = DataManager.get_skill(_skill_id)
	var skill_name: String = str(skill_data.get("name", _skill_id)).capitalize()
	_detail_xp_label.text = "+%d %s XP" % [xp, skill_name]

	# ── Ingredients ──
	for child in _input_grid.get_children():
		child.queue_free()

	for item_id in inputs:
		var qty_needed: int = int(inputs[item_id])
		var have: int = GameState.count_item(item_id)
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_name: String = str(item_data.get("name", item_id))
		var enough: bool = have >= qty_needed

		var row: HBoxContainer = _make_ingredient_row(item_name, qty_needed, have, enough)
		_input_grid.add_child(row)

	# ── Outputs ──
	for child in _output_grid.get_children():
		child.queue_free()

	for item_id in outputs:
		var qty: int = int(outputs[item_id])
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_name: String = str(item_data.get("name", item_id))

		var row: HBoxContainer = _make_output_row(item_name, qty)
		_output_grid.add_child(row)

	# ── Craft buttons state ──
	var can_do: bool = _crafting_sys != null and _crafting_sys.has_method("can_craft") and _crafting_sys.can_craft(_selected_recipe_id)
	var max_amount: int = _calculate_max_crafts(_selected_recipe_id) if can_do else 0

	_craft_1_btn.disabled = not can_do
	_craft_5_btn.disabled = not can_do or max_amount < 5
	_craft_all_btn.disabled = not can_do
	_craft_x_btn.disabled = not can_do

	if can_do and max_amount > 0:
		_craft_all_btn.text = "All (%d)" % max_amount
	else:
		_craft_all_btn.text = "All"

	# Status message
	if not meets_level:
		_status_label.text = "You need level %d to craft this" % req_level
		_status_label.add_theme_color_override("font_color", COL_NEED_MORE)
	elif not can_do:
		_status_label.text = "Missing ingredients or inventory full"
		_status_label.add_theme_color_override("font_color", COL_NEED_MORE)
	else:
		_status_label.text = "Ready to craft"
		_status_label.add_theme_color_override("font_color", COL_CRAFTABLE)

func _make_ingredient_row(item_name: String, needed: int, have: int, enough: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Colored item dot
	var dot: Label = Label.new()
	dot.text = "◆"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", COL_HAVE_ENOUGH if enough else COL_NEED_MORE)
	dot.custom_minimum_size = Vector2(14, 0)
	row.add_child(dot)

	# Item name — quantity integrated into the name text for clarity
	var name_lbl: Label = Label.new()
	name_lbl.text = "%dx %s" % [needed, item_name]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT if enough else COL_TEXT_DIM)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_lbl)

	# Have count (shows current stock)
	var count_lbl: Label = Label.new()
	count_lbl.text = "(%d)" % have
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", COL_HAVE_ENOUGH if enough else COL_NEED_MORE)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count_lbl)

	return row

func _make_output_row(item_name: String, qty: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var arrow: Label = Label.new()
	arrow.text = "►"
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", COL_ACCENT)
	arrow.custom_minimum_size = Vector2(14, 0)
	row.add_child(arrow)

	var name_lbl: Label = Label.new()
	if qty > 1:
		name_lbl.text = "%dx %s" % [qty, item_name]
	else:
		name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_lbl)

	return row

# ── SKILL BAR ──

func _update_skill_bar() -> void:
	var skill_info: Dictionary = GameState.skills.get(_skill_id, {})
	var level: int = int(skill_info.get("level", 1))
	var current_xp: int = int(skill_info.get("xp", 0))
	var xp_this_level: int = DataManager.xp_for_level(level)
	var xp_next_level: int = DataManager.xp_for_level(level + 1)

	var skill_data: Dictionary = DataManager.get_skill(_skill_id)
	var skill_name: String = str(skill_data.get("name", _skill_id)).capitalize()
	_skill_level_label.text = "%s Lv %d" % [skill_name, level]

	if xp_next_level > 0 and xp_next_level > xp_this_level:
		var progress: float = float(current_xp - xp_this_level) / float(xp_next_level - xp_this_level)
		_skill_bar.value = clampf(progress, 0.0, 1.0)
	else:
		_skill_bar.value = 1.0  # Max level

# ── CRAFTING ACTIONS ──

func _on_craft_amount(amount: int) -> void:
	if _selected_recipe_id == "" or _crafting_sys == null:
		return
	_do_craft_batch(amount)

func _on_craft_all() -> void:
	if _selected_recipe_id == "" or _crafting_sys == null:
		return
	var max_crafts: int = _calculate_max_crafts(_selected_recipe_id)
	if max_crafts > 0:
		_do_craft_batch(max_crafts)

func _on_craft_x() -> void:
	if _selected_recipe_id == "" or _crafting_sys == null:
		return
	var amount: int = int(_craft_x_input.value)
	if amount > 0:
		_do_craft_batch(amount)

func _do_craft_batch(amount: int) -> void:
	if _crafting_sys == null:
		return

	if amount == 1 and _crafting_sys.has_method("craft"):
		# Single craft — use normal method with messages
		_crafting_sys.craft(_selected_recipe_id)
	elif _crafting_sys.has_method("craft_batch"):
		# Batch craft — single combined message
		_crafting_sys.craft_batch(_selected_recipe_id, amount)
	else:
		return

	# Refresh after short delay so signals propagate
	await get_tree().create_timer(0.05).timeout
	refresh()

func _calculate_max_crafts(recipe_id: String) -> int:
	var recipe: Dictionary = DataManager.get_recipe(recipe_id)
	if recipe.is_empty():
		return 0

	# Check level requirement
	var skill_id: String = str(recipe.get("skill", ""))
	var req_level: int = int(recipe.get("level", 1))
	if skill_id != "":
		var current_level: int = int(GameState.skills.get(skill_id, {}).get("level", 1))
		if current_level < req_level:
			return 0

	var inputs: Dictionary = recipe.get("input", {})
	var outputs: Dictionary = recipe.get("output", {})

	if inputs.is_empty():
		return 0

	# Max based on ingredients
	var max_by_ingredients: int = 999
	for item_id in inputs:
		var needed: int = int(inputs[item_id])
		if needed <= 0:
			continue
		var have: int = GameState.count_item(item_id)
		var possible: int = int(have / needed)
		max_by_ingredients = mini(max_by_ingredients, possible)

	if max_by_ingredients <= 0:
		return 0

	# Max based on inventory space (conservative estimate)
	var output_slots_per_craft: int = 0
	for item_id in outputs:
		output_slots_per_craft += int(outputs[item_id])

	var input_slots_per_craft: int = 0
	for item_id in inputs:
		input_slots_per_craft += int(inputs[item_id])

	# Net slots needed per craft (outputs minus freed inputs)
	var net_slots: int = output_slots_per_craft - input_slots_per_craft
	if net_slots > 0:
		var free_slots: int = GameState.inventory_size - GameState.inventory.size()
		var max_by_space: int = int(free_slots / net_slots) if net_slots > 0 else max_by_ingredients
		max_by_ingredients = mini(max_by_ingredients, max_by_space)

	return maxi(0, max_by_ingredients)

# ── CLOSE ──

func _on_close() -> void:
	visible = false
	_selected_recipe_id = ""
	EventBus.panel_closed.emit("crafting")

# ── STYLE HELPERS ──

func _make_separator_style() -> StyleBoxFlat:
	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = COL_SEPARATOR
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	return sep_style

func _make_vseparator_style() -> StyleBoxFlat:
	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = COL_SEPARATOR
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_left = 1
	sep_style.content_margin_right = 1
	return sep_style

func _make_craft_button(text: String, accent: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(60, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.7)
	normal.bg_color.a = 0.6
	normal.border_color = accent.darkened(0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = accent.darkened(0.55)
	hover.bg_color.a = 0.75
	hover.border_color = accent.darkened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.4)
	pressed.bg_color.a = 0.8
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.05, 0.06, 0.08, 0.4)
	disabled.border_color = Color(0.1, 0.12, 0.15, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))

	return btn

func _apply_filter_button_style(btn: Button, active: bool) -> void:
	var accent: Color = COL_ACCENT if active else Color(0.3, 0.35, 0.4)

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	if active:
		normal.bg_color = accent.darkened(0.65)
		normal.bg_color.a = 0.7
	else:
		normal.bg_color = Color(0.03, 0.04, 0.07, 0.5)
	normal.border_color = accent.darkened(0.3) if active else Color(0.1, 0.12, 0.18, 0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color.a = 0.8 if active else 0.6
	hover.border_color = accent.darkened(0.1) if active else Color(0.15, 0.2, 0.3, 0.5)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.5)
	pressed.bg_color.a = 0.7
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT if active else COL_TEXT_DIM)
