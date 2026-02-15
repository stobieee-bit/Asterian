## CraftingPanel — Shows available recipes at a processing station
##
## Opens when player interacts with a processing station (smelter, bioforge, etc.)
## Lists recipes filtered by the station's skill type.
extends PanelContainer

# ── State ──
var _skill_id: String = ""
var _station_name: String = ""
var _crafting_sys: Node = null

# ── Node refs ──
var _title_label: Label = null
var _close_btn: Button = null
var _recipes_container: VBoxContainer = null
var _scroll: ScrollContainer = null

func _ready() -> void:
	custom_minimum_size = Vector2(360, 340)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Draggable header
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Crafting", _on_close)
	drag_header.name = "DragHeader"
	vbox.add_child(drag_header)
	_title_label = drag_header._title_label

	# Scrollable recipe list
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(340, 270)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_recipes_container = VBoxContainer.new()
	_recipes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes_container.add_theme_constant_override("separation", 3)
	_scroll.add_child(_recipes_container)

	visible = false
	z_index = 55

## Open crafting for a specific skill
func open_crafting(skill_id: String, station_name: String) -> void:
	_skill_id = skill_id
	_station_name = station_name
	_title_label.text = station_name

	# Find crafting system
	_crafting_sys = get_tree().get_first_node_in_group("crafting_system")

	visible = true
	refresh()

func refresh() -> void:
	for child in _recipes_container.get_children():
		child.queue_free()

	if _crafting_sys == null:
		_crafting_sys = get_tree().get_first_node_in_group("crafting_system")

	var recipes: Array = DataManager.get_recipes_for_skill(_skill_id)

	for recipe in recipes:
		var recipe_id: String = str(recipe.get("id", ""))
		if recipe_id == "":
			# Try finding the key from recipe data
			for key in DataManager.recipes:
				if DataManager.recipes[key] == recipe:
					recipe_id = key
					break

		var recipe_name: String = str(recipe.get("name", recipe_id))
		var req_level: int = int(recipe.get("level", 1))
		var xp: int = int(recipe.get("xp", 0))
		var inputs: Dictionary = recipe.get("input", {})
		var outputs: Dictionary = recipe.get("output", {})

		# Recipe container
		var recipe_box: VBoxContainer = VBoxContainer.new()
		recipe_box.add_theme_constant_override("separation", 1)
		_recipes_container.add_child(recipe_box)

		# Name + Level row
		var name_row: HBoxContainer = HBoxContainer.new()
		recipe_box.add_child(name_row)

		var name_lbl: Label = Label.new()
		name_lbl.text = recipe_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)

		# Color based on whether player meets level req
		var player_level: int = int(GameState.skills.get(_skill_id, {}).get("level", 1))
		if player_level >= req_level:
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		name_row.add_child(name_lbl)

		var level_lbl: Label = Label.new()
		level_lbl.text = "Lv %d" % req_level
		level_lbl.add_theme_font_size_override("font_size", 10)
		level_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
		name_row.add_child(level_lbl)

		var xp_lbl: Label = Label.new()
		xp_lbl.text = "%d XP" % xp
		xp_lbl.add_theme_font_size_override("font_size", 10)
		xp_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		name_row.add_child(xp_lbl)

		# Ingredients row
		var ing_text: String = ""
		for item_id in inputs:
			var qty: int = int(inputs[item_id])
			var item_data: Dictionary = DataManager.get_item(item_id)
			var item_name: String = str(item_data.get("name", item_id))
			var have: int = GameState.count_item(item_id)
			if ing_text != "":
				ing_text += ", "
			ing_text += "%dx %s (%d)" % [qty, item_name, have]

		var ing_lbl: Label = Label.new()
		ing_lbl.text = "  Needs: %s" % ing_text
		ing_lbl.add_theme_font_size_override("font_size", 9)
		ing_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.5))
		recipe_box.add_child(ing_lbl)

		# Craft button
		var craft_btn: Button = Button.new()
		craft_btn.text = "Craft"
		craft_btn.add_theme_font_size_override("font_size", 10)
		craft_btn.custom_minimum_size = Vector2(50, 22)

		var can_do: bool = false
		if _crafting_sys and _crafting_sys.has_method("can_craft"):
			can_do = _crafting_sys.can_craft(recipe_id)
		craft_btn.disabled = not can_do
		craft_btn.pressed.connect(_on_craft.bind(recipe_id))
		name_row.add_child(craft_btn)

		# Separator
		var sep: HSeparator = HSeparator.new()
		_recipes_container.add_child(sep)

func _on_craft(recipe_id: String) -> void:
	if _crafting_sys and _crafting_sys.has_method("craft"):
		_crafting_sys.craft(recipe_id)
		# Small delay then refresh to show updated counts
		await get_tree().create_timer(0.1).timeout
		refresh()

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("crafting")
