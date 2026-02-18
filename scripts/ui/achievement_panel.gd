## AchievementPanel — Displays all achievements grouped by category
##
## Shows unlocked/total count, total points, and each achievement with its
## name, description, point value, and unlock status. Grouped by category
## (Combat, Skilling, Quests, Exploration, Prestige, Economy, Collection).
## Auto-refreshes when achievements are unlocked.
extends PanelContainer

# ── Category display order and colors ──
const CATEGORY_ORDER: Array[String] = [
	"combat", "skilling", "quests", "explore", "prestige", "economy", "collection"
]
const CATEGORY_NAMES: Dictionary = {
	"combat": "Combat",
	"skilling": "Skilling",
	"quests": "Quests",
	"explore": "Exploration",
	"prestige": "Prestige",
	"economy": "Economy",
	"collection": "Collection",
}
const CATEGORY_COLORS: Dictionary = {
	"combat": Color(0.9, 0.3, 0.3),
	"skilling": Color(0.3, 0.85, 0.4),
	"quests": Color(1.0, 0.85, 0.2),
	"explore": Color(0.3, 0.7, 1.0),
	"prestige": Color(0.8, 0.5, 1.0),
	"economy": Color(1.0, 0.7, 0.2),
	"collection": Color(0.5, 0.9, 0.9),
}

# ── Node refs ──
var _scroll: ScrollContainer = null
var _entries_container: VBoxContainer = null
var _summary_label: Label = null
var _points_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(360, 420)
	visible = false
	z_index = 50

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Draggable header ──
	var drag_header: DraggableHeader = DraggableHeader.attach(self, "Achievements", _on_close)
	vbox.add_child(drag_header)

	# ── Summary row ──
	var summary_row: HBoxContainer = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	vbox.add_child(summary_row)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 13)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	summary_row.add_child(_summary_label)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 13)
	_points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	summary_row.add_child(_points_label)

	# ── Separator ──
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# ── Scrollable achievement list ──
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(340, 350)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_entries_container = VBoxContainer.new()
	_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_container.add_theme_constant_override("separation", 2)
	_scroll.add_child(_entries_container)

	# ── Connect signals ──
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

	# Initial build
	refresh()


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Rebuild the entire achievement list from DataManager.
func refresh() -> void:
	# Clear previous entries
	for child in _entries_container.get_children():
		child.queue_free()

	# Update summary
	var ach_sys: Node = get_tree().get_first_node_in_group("achievement_system")
	var summary: Dictionary = {}
	if ach_sys and ach_sys.has_method("get_progress_summary"):
		summary = ach_sys.get_progress_summary()

	var unlocked: int = int(summary.get("unlocked", 0))
	var total: int = int(summary.get("total", 0))
	var points: int = int(summary.get("points", 0))
	var max_points: int = int(summary.get("max_points", 0))

	_summary_label.text = "%d / %d Unlocked" % [unlocked, total]
	_points_label.text = "%d / %d pts" % [points, max_points]

	# Group achievements by category
	var by_category: Dictionary = {}
	for cat in CATEGORY_ORDER:
		by_category[cat] = []

	for entry in DataManager.achievements:
		var cat: String = str(entry.get("category", "combat"))
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(entry)

	# Build each category section
	for cat in CATEGORY_ORDER:
		var entries: Array = by_category.get(cat, [])
		if entries.is_empty():
			continue
		_build_category_section(cat, entries)


# ──────────────────────────────────────────────
#  UI building
# ──────────────────────────────────────────────

## Build a category header + all achievement entries for one category.
func _build_category_section(cat: String, entries: Array) -> void:
	var cat_name: String = CATEGORY_NAMES.get(cat, cat.capitalize())
	var cat_color: Color = CATEGORY_COLORS.get(cat, Color(0.7, 0.7, 0.7))

	# Count unlocked in this category
	var cat_unlocked: int = 0
	for entry in entries:
		if GameState.unlocked_achievements.has(str(entry.get("id", ""))):
			cat_unlocked += 1

	# ── Category header ──
	var header: Label = Label.new()
	header.text = "%s  (%d/%d)" % [cat_name, cat_unlocked, entries.size()]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", cat_color)
	_entries_container.add_child(header)

	# ── Achievement rows ──
	for entry in entries:
		_build_achievement_row(entry, cat_color)

	# ── Separator after category ──
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_entries_container.add_child(sep)


## Build a single achievement row: icon + name + description + points.
func _build_achievement_row(entry: Dictionary, cat_color: Color) -> void:
	var ach_id: String = str(entry.get("id", ""))
	var ach_name: String = str(entry.get("name", ach_id))
	var ach_desc: String = str(entry.get("desc", ""))
	var ach_points: int = int(entry.get("points", 0))
	var ach_title: String = str(entry.get("title", ""))
	var is_unlocked: bool = GameState.unlocked_achievements.has(ach_id)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_entries_container.add_child(row)

	# ── Status icon ──
	var icon_label: Label = Label.new()
	icon_label.add_theme_font_size_override("font_size", 14)
	if is_unlocked:
		icon_label.text = "[*]"
		icon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		icon_label.text = "[ ]"
		icon_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	row.add_child(icon_label)

	# ── Name + description column ──
	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 0)
	row.add_child(info_col)

	var name_label: Label = Label.new()
	name_label.text = ach_name
	name_label.add_theme_font_size_override("font_size", 13)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	else:
		name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	info_col.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = ach_desc
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	info_col.add_child(desc_label)

	# Show title reward if present
	if ach_title != "" and is_unlocked:
		var title_label: Label = Label.new()
		title_label.text = "Title: %s" % ach_title
		title_label.add_theme_font_size_override("font_size", 11)
		title_label.add_theme_color_override("font_color", cat_color.lightened(0.2))
		info_col.add_child(title_label)

	# ── Points badge ──
	var pts_label: Label = Label.new()
	pts_label.text = "%d pts" % ach_points
	pts_label.add_theme_font_size_override("font_size", 12)
	pts_label.custom_minimum_size = Vector2(45, 0)
	pts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_unlocked:
		pts_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		pts_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	row.add_child(pts_label)


# ──────────────────────────────────────────────
#  Callbacks
# ──────────────────────────────────────────────

func _on_close() -> void:
	visible = false
	EventBus.panel_closed.emit("achievements")

func _on_achievement_unlocked(_ach_id: String) -> void:
	if visible:
		refresh()
