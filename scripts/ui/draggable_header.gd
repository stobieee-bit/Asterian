## DraggableHeader — A drag handle you can attach to any PanelContainer
##
## Creates a styled header bar with a title, lock toggle, and close button.
## Dragging the header moves the parent PanelContainer around the viewport.
## Lock button prevents accidental dragging.
## Usage: Call DraggableHeader.attach(panel, "Title", close_callback) to add.
class_name DraggableHeader
extends HBoxContainer

# ── Drag state ──
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _panel_start: Vector2 = Vector2.ZERO
var _target_panel: PanelContainer = null
var _is_locked: bool = false

# ── Callbacks ──
var _on_drag_end: Callable = Callable()  # Called when drag ends (for saving position)

# ── Refs ──
var _title_label: Label = null
var _lock_btn: Button = null
var _drag_hint: Label = null
var _close_btn: Button = null

## Static factory — attach a draggable header to a panel
## Returns the DraggableHeader so you can customize it further.
static func attach(panel: PanelContainer, title: String, close_callback: Callable = Callable()) -> DraggableHeader:
	var header: DraggableHeader = DraggableHeader.new()
	header._target_panel = panel
	header._setup(title, close_callback)
	return header

func _setup(title: String, close_callback: Callable) -> void:
	name = "DragHeader"
	custom_minimum_size = Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Catch mouse events for dragging

	# Title label
	_title_label = Label.new()
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let drag through
	add_child(_title_label)

	# Drag hint (subtle dots icon — hidden when locked)
	_drag_hint = Label.new()
	_drag_hint.text = ":::"
	_drag_hint.add_theme_color_override("font_color", Color(0.3, 0.5, 0.6, 0.5))
	_drag_hint.add_theme_font_size_override("font_size", 12)
	_drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_hint)

	# Lock button
	_lock_btn = Button.new()
	_lock_btn.text = "O"  # O = open/unlocked
	_lock_btn.custom_minimum_size = Vector2(24, 24)
	_lock_btn.add_theme_font_size_override("font_size", 10)
	_lock_btn.tooltip_text = "Lock panel position"

	var lock_style: StyleBoxFlat = StyleBoxFlat.new()
	lock_style.bg_color = Color(0.08, 0.1, 0.15, 0.5)
	lock_style.set_corner_radius_all(3)
	lock_style.set_content_margin_all(2)
	_lock_btn.add_theme_stylebox_override("normal", lock_style)

	var lock_hover: StyleBoxFlat = lock_style.duplicate()
	lock_hover.bg_color = Color(0.1, 0.15, 0.25, 0.8)
	lock_hover.border_color = Color(0.3, 0.6, 0.8, 0.5)
	lock_hover.set_border_width_all(1)
	_lock_btn.add_theme_stylebox_override("hover", lock_hover)

	_lock_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 0.7))
	_lock_btn.add_theme_color_override("font_hover_color", Color(0.5, 0.8, 0.9))
	_lock_btn.pressed.connect(_on_lock_toggle)
	add_child(_lock_btn)

	# Close button
	if close_callback.is_valid():
		_close_btn = Button.new()
		_close_btn.text = "X"
		_close_btn.custom_minimum_size = Vector2(24, 24)
		_close_btn.add_theme_font_size_override("font_size", 11)

		# Style close button
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.1, 0.15, 0.5)
		btn_style.set_corner_radius_all(3)
		btn_style.set_content_margin_all(2)
		_close_btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover: StyleBoxFlat = btn_style.duplicate()
		btn_hover.bg_color = Color(0.5, 0.15, 0.1, 0.8)
		btn_hover.border_color = Color(0.8, 0.2, 0.1, 0.5)
		btn_hover.set_border_width_all(1)
		_close_btn.add_theme_stylebox_override("hover", btn_hover)

		_close_btn.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
		_close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.3))

		_close_btn.pressed.connect(close_callback)
		add_child(_close_btn)

func _gui_input(event: InputEvent) -> void:
	if _target_panel == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_locked:
					return  # Don't start dragging when locked
				_is_dragging = true
				_drag_start = event.global_position
				_panel_start = _target_panel.position
				accept_event()
			else:
				if _is_dragging and _on_drag_end.is_valid():
					_on_drag_end.call()
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.global_position - _drag_start
		var new_pos: Vector2 = _panel_start + delta

		# Clamp to viewport
		var viewport_size: Vector2 = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
			ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
		)
		var panel_size: Vector2 = _target_panel.size
		new_pos.x = clampf(new_pos.x, 0, viewport_size.x - panel_size.x)
		new_pos.y = clampf(new_pos.y, 0, viewport_size.y - panel_size.y)

		_target_panel.position = new_pos
		accept_event()

## Toggle lock state
func _on_lock_toggle() -> void:
	_is_locked = not _is_locked
	_update_lock_visuals()
	if _on_drag_end.is_valid():
		_on_drag_end.call()  # Save state when lock changes

## Update visuals to reflect lock state
func _update_lock_visuals() -> void:
	if _lock_btn:
		if _is_locked:
			_lock_btn.text = "L"  # L = locked
			_lock_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			_lock_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
			_lock_btn.tooltip_text = "Unlock panel position"
		else:
			_lock_btn.text = "O"  # O = open/unlocked
			_lock_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 0.7))
			_lock_btn.add_theme_color_override("font_hover_color", Color(0.5, 0.8, 0.9))
			_lock_btn.tooltip_text = "Lock panel position"
	if _drag_hint:
		_drag_hint.visible = not _is_locked

## Set lock state programmatically (used when restoring from save)
func set_locked(locked: bool) -> void:
	_is_locked = locked
	_update_lock_visuals()

## Update the title text
func set_title(new_title: String) -> void:
	if _title_label:
		_title_label.text = new_title
