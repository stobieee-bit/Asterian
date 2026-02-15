## ContextMenu — Right-click popup with action options
##
## Shows a dark sci-fi styled list of clickable options near the cursor.
## Each option has a label, optional icon letter, and a callback.
## Closes when an option is clicked or when clicking elsewhere.
##
## Usage:
##   EventBus.context_menu_requested.emit([
##       {"label": "Attack", "icon": "W", "color": Color.RED, "callback": some_func},
##       {"label": "Examine", "icon": "?", "color": Color.GRAY, "callback": some_func},
##   ], get_global_mouse_position())
extends PanelContainer

# ── State ──
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _is_showing: bool = false

func _ready() -> void:
	# Panel style: dark with cyan border, slightly brighter than tooltip
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	style.border_color = Color(0.15, 0.4, 0.6, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

	# Build content container
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 1)
	add_child(_vbox)

	# Title label (e.g. item/enemy name) — hidden until set
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.visible = false
	_vbox.add_child(_title_label)

	# Start hidden
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110  # Above tooltip

	# Connect signals
	EventBus.context_menu_requested.connect(_on_context_menu_requested)
	EventBus.context_menu_hidden.connect(hide_menu)

func _input(event: InputEvent) -> void:
	if not _is_showing:
		return

	# Close on any mouse click outside the menu
	if event is InputEventMouseButton and event.pressed:
		var mouse: Vector2 = event.position
		var rect: Rect2 = Rect2(global_position, size)
		if not rect.has_point(mouse):
			hide_menu()
			# Don't consume — let the click pass through to the world

	# Close on Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()
		get_viewport().set_input_as_handled()

## Show context menu with options
func _on_context_menu_requested(options: Array, global_pos: Vector2) -> void:
	# Clear old options (keep title label)
	while _vbox.get_child_count() > 1:
		var child: Node = _vbox.get_child(_vbox.get_child_count() - 1)
		_vbox.remove_child(child)
		child.queue_free()

	# Check if a title was provided in first option
	_title_label.visible = false
	for opt in options:
		if opt.has("title"):
			_title_label.text = str(opt["title"])
			if opt.has("title_color"):
				_title_label.add_theme_color_override("font_color", opt["title_color"])
			else:
				_title_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
			_title_label.visible = true
			break

	# Add separator after title
	if _title_label.visible:
		var sep: HSeparator = HSeparator.new()
		sep.add_theme_constant_override("separation", 2)
		sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
		var sep_style: StyleBoxLine = sep.get_theme_stylebox("separator") as StyleBoxLine
		if sep_style:
			sep_style.color = Color(0.15, 0.3, 0.45, 0.4)
			sep_style.thickness = 1
		_vbox.add_child(sep)

	# Build option buttons
	for opt in options:
		if opt.has("title"):
			continue  # Skip the title entry

		var btn: Button = Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(140, 26)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Style
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = Color(0.04, 0.06, 0.1, 0.0)  # Transparent
		normal.set_corner_radius_all(3)
		normal.set_content_margin_all(2)
		normal.content_margin_left = 6
		btn.add_theme_stylebox_override("normal", normal)

		var hover: StyleBoxFlat = StyleBoxFlat.new()
		hover.bg_color = Color(0.08, 0.15, 0.25, 0.9)
		hover.set_corner_radius_all(3)
		hover.set_content_margin_all(2)
		hover.content_margin_left = 6
		hover.border_color = Color(0.2, 0.5, 0.7, 0.3)
		hover.set_border_width_all(1)
		btn.add_theme_stylebox_override("hover", hover)

		var pressed: StyleBoxFlat = StyleBoxFlat.new()
		pressed.bg_color = Color(0.1, 0.2, 0.35, 0.9)
		pressed.set_corner_radius_all(3)
		pressed.set_content_margin_all(2)
		pressed.content_margin_left = 6
		btn.add_theme_stylebox_override("pressed", pressed)

		# Inner layout with icon + label
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 6)
		btn.add_child(hbox)

		# Icon letter (optional)
		var icon_text: String = str(opt.get("icon", ""))
		if icon_text != "":
			var icon_color: Color = opt.get("color", Color(0.4, 0.7, 0.9))
			var icon_lbl: Label = Label.new()
			icon_lbl.text = icon_text
			icon_lbl.add_theme_font_size_override("font_size", 11)
			icon_lbl.add_theme_color_override("font_color", icon_color)
			icon_lbl.custom_minimum_size = Vector2(14, 0)
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(icon_lbl)

		# Label
		var label_text: String = str(opt.get("label", "Action"))
		var label_color: Color = opt.get("color", Color(0.8, 0.85, 0.9))
		var lbl: Label = Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", label_color)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)

		# Keybind hint (optional, right-aligned)
		var keybind: String = str(opt.get("keybind", ""))
		if keybind != "":
			var spacer: Control = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(spacer)

			var kb_lbl: Label = Label.new()
			kb_lbl.text = keybind
			kb_lbl.add_theme_font_size_override("font_size", 9)
			kb_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
			kb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(kb_lbl)

		# Connect callback
		var callback: Callable = opt.get("callback", Callable())
		if callback.is_valid():
			btn.pressed.connect(func():
				callback.call()
				hide_menu()
			)
		else:
			btn.pressed.connect(hide_menu)

		_vbox.add_child(btn)

	# Position near mouse, clamped to viewport
	visible = true
	_is_showing = true

	# Wait a frame for size to be calculated
	await get_tree().process_frame
	_position_near(global_pos)

## Hide the context menu
func hide_menu() -> void:
	visible = false
	_is_showing = false

## Position near a point, clamped to viewport bounds
func _position_near(pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var menu_size: Vector2 = size

	# Try to place below-right of cursor
	var final_pos: Vector2 = pos + Vector2(2, 2)

	# Clamp to viewport
	if final_pos.x + menu_size.x > viewport_size.x:
		final_pos.x = pos.x - menu_size.x - 2
	if final_pos.y + menu_size.y > viewport_size.y:
		final_pos.y = pos.y - menu_size.y - 2

	final_pos.x = maxf(0, final_pos.x)
	final_pos.y = maxf(0, final_pos.y)

	global_position = final_pos
