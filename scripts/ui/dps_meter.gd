## DPSMeter — Small overlay showing damage per second, total damage, and duration
##
## Resets when combat starts (combat_started signal), freezes when combat ends
## (combat_ended signal). Accumulates damage from hit_landed when player is attacker.
extends PanelContainer

var _dps_label: Label = null
var _total_label: Label = null
var _time_label: Label = null

var _total_damage: int = 0
var _combat_duration: float = 0.0
var _is_active: bool = false
var _is_frozen: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(140, 65)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "DPS Meter", _on_close)
	vbox.add_child(drag_header)

	# ── DPS display ──
	_dps_label = Label.new()
	_dps_label.text = "DPS: 0"
	_dps_label.add_theme_font_size_override("font_size", 14)
	_dps_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_dps_label)

	# ── Total damage ──
	_total_label = Label.new()
	_total_label.text = "Total: 0"
	_total_label.add_theme_font_size_override("font_size", 11)
	_total_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_total_label)

	# ── Duration ──
	_time_label = Label.new()
	_time_label.text = "0.0s"
	_time_label.add_theme_font_size_override("font_size", 10)
	_time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_time_label)

	# ── Connect signals ──
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.hit_landed.connect(_on_hit_landed)


func _process(delta: float) -> void:
	if not visible:
		return
	if _is_active and not _is_frozen:
		_combat_duration += delta
		_update_display()


func _update_display() -> void:
	var dps: float = 0.0
	if _combat_duration > 0.5:
		dps = float(_total_damage) / _combat_duration
	_dps_label.text = "DPS: %s" % _format_number(int(dps))
	_total_label.text = "Total: %s" % _format_number(_total_damage)
	_time_label.text = "%.1fs" % _combat_duration


func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)


# ──────────────────────────────────────────────
#  Signal handlers
# ──────────────────────────────────────────────

func _on_combat_started(_enemy_id: String) -> void:
	_total_damage = 0
	_combat_duration = 0.0
	_is_active = true
	_is_frozen = false
	_update_display()

func _on_combat_ended() -> void:
	_is_frozen = true
	_update_display()

func _on_hit_landed(_target: Node, damage: int, _is_crit: bool, attacker: Node) -> void:
	if attacker and attacker.is_in_group("player"):
		_total_damage += damage
		if not _is_active:
			_is_active = true
			_is_frozen = false

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("dps_meter")
