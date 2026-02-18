## CombatLogPanel — Scrollable combat log showing recent combat events
##
## Listens to combat signals (hit_landed, hit_missed, player_damaged, enemy_killed,
## status_effect_applied, combo_completed) and displays timestamped entries.
## 200-entry cap with auto-scroll. Toggle via keybind or button.
extends PanelContainer

const MAX_ENTRIES: int = 200
const LOG_FONT_SIZE: int = 11

var _scroll: ScrollContainer = null
var _log_label: RichTextLabel = null
var _entry_count: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 250)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Combat Log", _on_close)
	vbox.add_child(drag_header)

	# ── Scrollable log ──
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(280, 210)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false  # We handle scrolling via ScrollContainer
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", LOG_FONT_SIZE)
	_log_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.75))
	_scroll.add_child(_log_label)

	# ── Clear button ──
	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(50, 20)
	clear_btn.add_theme_font_size_override("font_size", 10)
	clear_btn.pressed.connect(_on_clear)
	vbox.add_child(clear_btn)

	# ── Connect combat signals ──
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.hit_missed.connect(_on_hit_missed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.status_effect_applied.connect(_on_status_effect)
	EventBus.combo_completed.connect(_on_combo)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.buff_applied.connect(_on_buff_applied)


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

func add_entry(bbcode_text: String) -> void:
	var timestamp: String = _get_timestamp()
	_log_label.append_text("[color=#666666]%s[/color] %s\n" % [timestamp, bbcode_text])
	_entry_count += 1

	# Cap entries — clear oldest if over limit
	if _entry_count > MAX_ENTRIES:
		# Simplest approach: clear and note
		_log_label.clear()
		_log_label.append_text("[color=#555555]--- Log trimmed ---[/color]\n")
		_entry_count = 1

	# Auto-scroll to bottom
	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


# ──────────────────────────────────────────────
#  Signal handlers
# ──────────────────────────────────────────────

func _on_hit_landed(hit_target: Node, damage: int, is_crit: bool, attacker: Node) -> void:
	# Player hitting enemy
	if attacker and attacker.is_in_group("player"):
		var target_name: String = _get_name(hit_target)
		var crit_str: String = " [color=#ffdd22](CRIT!)[/color]" if is_crit else ""
		add_entry("[color=#ff6644]You hit %s for %d%s[/color]" % [target_name, damage, crit_str])
	# Enemy hitting player (handled by player_damaged instead)

func _on_hit_missed(hit_target: Node) -> void:
	var target_name: String = _get_name(hit_target)
	add_entry("[color=#888888]Miss on %s[/color]" % target_name)

func _on_player_damaged(amount: int, source: String) -> void:
	add_entry("[color=#ff4444]You took %d damage from %s[/color]" % [amount, source])

func _on_enemy_killed(enemy_id: String, _enemy_type: String) -> void:
	add_entry("[color=#44ff44]Killed: %s[/color]" % enemy_id)

func _on_status_effect(effect_target: Node, effect_type: String, stacks: int) -> void:
	var target_name: String = _get_name(effect_target)
	var colors: Dictionary = {
		"poison": "#44ff44",
		"bleed": "#ff3333",
		"burn": "#ff8800",
		"slow": "#8888ff",
		"stun": "#ffff44",
	}
	var c: String = colors.get(effect_type, "#aaaaaa")
	add_entry("[color=%s]%s applied to %s (x%d)[/color]" % [c, effect_type.capitalize(), target_name, stacks])

func _on_combo(combo_id: String, combo_name: String) -> void:
	add_entry("[color=#ffdd11][b]COMBO: %s![/b][/color]" % combo_name)

func _on_player_healed(amount: int) -> void:
	add_entry("[color=#33ff88]Healed for %d[/color]" % amount)

func _on_buff_applied(buff_type: String, value: float, duration: float) -> void:
	add_entry("[color=#88ccff]Buff: %s (%.0f%% for %.0fs)[/color]" % [buff_type, value * 100, duration])


# ──────────────────────────────────────────────
#  Helpers
# ──────────────────────────────────────────────

func _get_timestamp() -> String:
	var dict: Dictionary = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [dict["hour"], dict["minute"], dict["second"]]

func _get_name(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "???"
	if "enemy_name" in node and str(node.enemy_name) != "":
		return str(node.enemy_name)
	if "enemy_id" in node:
		return str(node.enemy_id)
	return node.name

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("combat_log")

func _on_clear() -> void:
	_log_label.clear()
	_entry_count = 0
