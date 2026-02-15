class_name ItemIcons
## Shared emoji icon lookup for all UI panels (inventory, equipment, bank, ability bar).
## Uses Unicode emoji — zero texture files needed, works on all modern browsers.

## Master icon lookup: returns emoji for an item's icon_name field, with type fallback
static func get_icon(icon_name: String, item_type: String = "") -> String:
	match icon_name:
		# ── Ores, bars & crafting ──
		"icon_ore":       return "🪨"
		"icon_bar":       return "🧱"
		"icon_alloy":     return "⚙️"
		"icon_essence":   return "✨"
		"icon_gem":       return "💎"
		"icon_dust":      return "🌫️"
		# ── Bio resources ──
		"icon_bio_bone":     return "🦴"
		"icon_bio_membrane": return "🔬"
		"icon_bio_mushroom": return "🍄"
		"icon_bio_swirl":    return "🌀"
		"icon_bio_brain":    return "🧠"
		"icon_bio_galaxy":   return "🌌"
		"icon_bio_sparkle":  return "🔆"
		"icon_bio_crystal":  return "🔷"
		"icon_bio_fiber":    return "🧵"
		"icon_bio_conduit":  return "🔌"
		"icon_neural":       return "🧬"
		"icon_chrono":       return "⏳"
		"icon_stinger":      return "🐝"
		"icon_dark_orb":     return "🌑"
		# ── Raw food ingredients ──
		"icon_food_lichen":   return "🌿"
		"icon_food_fruit":    return "🍇"
		"icon_food_meat":     return "🥩"
		"icon_food_pepper":   return "🌶️"
		"icon_food_truffle":  return "🫒"
		"icon_food_kelp":     return "🥬"
		"icon_food_grain":    return "🌾"
		"icon_food_mushroom": return "🍄"
		"icon_food_honey":    return "🍯"
		"icon_food_yeast":    return "🧫"
		# ── Cooked food ──
		"icon_wrap":       return "🌯"
		"icon_soup":       return "🍲"
		"icon_smoothie":   return "🧃"
		"icon_grain_bowl": return "🍚"
		"icon_burger":     return "🍔"
		"icon_stew":       return "🥘"
		"icon_curry":      return "🍛"
		"icon_steak":      return "🥩"
		"icon_feast":      return "🍱"
		"icon_pasta":      return "🍝"
		"icon_cake":       return "🎂"
		"icon_drumstick":  return "🍗"
		"icon_elixir":     return "🧪"
		"icon_serum":      return "💉"
		"icon_syringe":    return "💉"
		# ── Consumables & utility ──
		"icon_repair_kit": return "🔧"
		"icon_beacon":     return "📡"
		"icon_battery":    return "🔋"
		"icon_flare":      return "🎇"
		"icon_chip":       return "🖥️"
		"icon_bomb":       return "💣"
		# ── Trophy & special ──
		"icon_crown":     return "👑"
		"icon_heart":     return "❤️"
		"icon_star":      return "⭐"
		"icon_shield":    return "🛡️"
		"icon_medal":     return "🏅"
		"icon_speaker":   return "📢"
		"icon_telescope": return "🔭"
		"icon_sigil":     return "🔯"
		"icon_skull":     return "💀"
		"icon_relic":     return "🏺"
		# ── Weapons ──
		"icon_nanoblade":  return "🗡️"
		"icon_coilgun":    return "🔫"
		"icon_voidstaff":  return "🪄"
		"icon_capacitor":  return "⚡"
		# ── Armor pieces ──
		"icon_helmet":  return "🪖"
		"icon_vest":    return "🦺"
		"icon_greaves": return "🦿"
		"icon_boots":   return "🥾"
		"icon_gloves":  return "🧤"
		# ── Tools ──
		"icon_pickaxe": return "⛏️"
		"icon_scanner": return "📡"
		"icon_welder":  return "🔩"
		"icon_stove":   return "🍳"
		# ── Other ──
		"icon_credits": return "💰"
		"icon_pet":     return "🐾"
	# Fallback to type-based emoji
	return get_type_icon(item_type)

## Fallback emoji by item type
static func get_type_icon(item_type: String) -> String:
	match item_type:
		"weapon":      return "⚔️"
		"armor":       return "🛡️"
		"offhand":     return "🛡️"
		"food":        return "🍖"
		"consumable":  return "🧪"
		"resource":    return "🪨"
		"material":    return "⚙️"
		"tool":        return "🛠️"
		"pet":         return "🐾"
		_:             return "📦"

## Empty equipment slot placeholder emoji
static func get_equip_slot_icon(slot_name: String) -> String:
	match slot_name:
		"head":    return "🪖"
		"body":    return "🦺"
		"weapon":  return "⚔️"
		"offhand": return "🛡️"
		"legs":    return "🦿"
		"boots":   return "🥾"
		"gloves":  return "🧤"
		_:         return "📦"
