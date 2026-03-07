## TypeChart — Static type effectiveness lookup for creature battles
##
## Contains the full 18-type effectiveness chart. Returns multipliers
## for attack type vs. defender type(s).
class_name TypeChart
extends RefCounted

# ── Type effectiveness multipliers ──
# 2.0 = super effective, 0.5 = not very effective, 0.0 = immune

const CHART: Dictionary = {
	"normal":   { "rock": 0.5, "ghost": 0.0, "steel": 0.5 },
	"fire":     { "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 2.0, "bug": 2.0, "rock": 0.5, "dragon": 0.5, "steel": 2.0 },
	"water":    { "fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0, "rock": 2.0, "dragon": 0.5 },
	"electric": { "water": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0, "flying": 2.0, "dragon": 0.5 },
	"grass":    { "fire": 0.5, "water": 2.0, "grass": 0.5, "poison": 0.5, "ground": 2.0, "flying": 0.5, "bug": 0.5, "rock": 2.0, "dragon": 0.5, "steel": 0.5 },
	"ice":      { "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 0.5, "ground": 2.0, "flying": 2.0, "dragon": 2.0, "steel": 0.5 },
	"fighting": { "normal": 2.0, "ice": 2.0, "poison": 0.5, "flying": 0.5, "psychic": 0.5, "bug": 0.5, "rock": 2.0, "ghost": 0.0, "dark": 2.0, "steel": 2.0, "fairy": 0.5 },
	"poison":   { "grass": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5, "steel": 0.0, "fairy": 2.0 },
	"ground":   { "fire": 2.0, "electric": 2.0, "grass": 0.5, "poison": 2.0, "flying": 0.0, "bug": 0.5, "rock": 2.0, "steel": 2.0 },
	"flying":   { "electric": 0.5, "grass": 2.0, "fighting": 2.0, "bug": 2.0, "rock": 0.5, "steel": 0.5 },
	"psychic":  { "fighting": 2.0, "poison": 2.0, "psychic": 0.5, "dark": 0.0, "steel": 0.5 },
	"bug":      { "fire": 0.5, "grass": 2.0, "fighting": 0.5, "poison": 0.5, "flying": 0.5, "psychic": 2.0, "ghost": 0.5, "dark": 2.0, "steel": 0.5, "fairy": 0.5 },
	"rock":     { "fire": 2.0, "ice": 2.0, "fighting": 0.5, "ground": 0.5, "flying": 2.0, "bug": 2.0, "steel": 0.5 },
	"ghost":    { "normal": 0.0, "psychic": 2.0, "ghost": 2.0, "dark": 0.5 },
	"dragon":   { "dragon": 2.0, "steel": 0.5, "fairy": 0.0 },
	"dark":     { "fighting": 0.5, "psychic": 2.0, "ghost": 2.0, "dark": 0.5, "fairy": 0.5 },
	"steel":    { "fire": 0.5, "water": 0.5, "electric": 0.5, "ice": 2.0, "rock": 2.0, "steel": 0.5, "fairy": 2.0 },
	"fairy":    { "fire": 0.5, "fighting": 2.0, "poison": 0.5, "dragon": 2.0, "dark": 2.0, "steel": 0.5 },
}

# ── Type colors for UI ──
const TYPE_COLORS: Dictionary = {
	"normal":   Color(0.66, 0.66, 0.47),
	"fire":     Color(0.93, 0.51, 0.19),
	"water":    Color(0.39, 0.56, 0.94),
	"electric": Color(0.97, 0.82, 0.17),
	"grass":    Color(0.47, 0.78, 0.30),
	"ice":      Color(0.59, 0.85, 0.84),
	"fighting": Color(0.76, 0.18, 0.16),
	"poison":   Color(0.63, 0.24, 0.63),
	"ground":   Color(0.88, 0.75, 0.40),
	"flying":   Color(0.66, 0.56, 0.95),
	"psychic":  Color(0.98, 0.33, 0.53),
	"bug":      Color(0.65, 0.73, 0.10),
	"rock":     Color(0.71, 0.63, 0.21),
	"ghost":    Color(0.44, 0.34, 0.58),
	"dragon":   Color(0.44, 0.21, 0.99),
	"dark":     Color(0.44, 0.34, 0.27),
	"steel":    Color(0.72, 0.72, 0.82),
	"fairy":    Color(0.84, 0.52, 0.68),
}

## Get type effectiveness multiplier for move_type vs. defender types
static func get_effectiveness(move_type: String, defender_types: Array) -> float:
	var multiplier: float = 1.0
	if not CHART.has(move_type):
		return multiplier
	var chart_entry: Dictionary = CHART[move_type]
	for def_type in defender_types:
		var dt: String = str(def_type)
		if chart_entry.has(dt):
			multiplier *= float(chart_entry[dt])
	return multiplier

## Get color for a type
static func get_type_color(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color.WHITE)

## Get effectiveness text description
static func get_effectiveness_text(multiplier: float) -> String:
	if multiplier == 0.0:
		return "It has no effect..."
	elif multiplier < 1.0:
		return "It's not very effective..."
	elif multiplier > 1.0:
		return "It's super effective!"
	return ""
