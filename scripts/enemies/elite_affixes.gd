## EliteAffixes — Defines and applies elite enemy modifiers
##
## 4 affixes that modify enemy behavior:
## - Vampiric: heals 10% of damage dealt
## - Shielded: caps incoming damage at 50 per hit
## - Explosive: AoE damage on death
## - Regenerating: slow HP regen over time
##
## Used by enemy_controller.gd when an enemy is flagged as elite.
class_name EliteAffixes
extends RefCounted

const AFFIX_LIST: Array[String] = ["vampiric", "shielded", "explosive", "regenerating"]

const AFFIX_COLORS: Dictionary = {
	"vampiric": Color(0.8, 0.2, 0.3),
	"shielded": Color(0.3, 0.6, 1.0),
	"explosive": Color(1.0, 0.5, 0.1),
	"regenerating": Color(0.2, 0.9, 0.3),
}

const AFFIX_DESCRIPTIONS: Dictionary = {
	"vampiric": "Heals 10% of damage dealt",
	"shielded": "Damage capped at 50 per hit",
	"explosive": "Explodes on death",
	"regenerating": "Slowly regenerates HP",
}


## Pick a random affix
static func random_affix() -> String:
	return AFFIX_LIST[randi() % AFFIX_LIST.size()]


## Get the display color for an affix
static func get_color(affix: String) -> Color:
	return AFFIX_COLORS.get(affix, Color(1.0, 0.85, 0.1))


## Get the description for an affix
static func get_description(affix: String) -> String:
	return AFFIX_DESCRIPTIONS.get(affix, "")


## Apply vampiric healing — call after enemy deals damage.
## Returns the heal amount applied.
static func apply_vampiric(enemy: Node, damage_dealt: int) -> int:
	if damage_dealt <= 0:
		return 0
	var heal: int = maxi(1, int(float(damage_dealt) * 0.10))
	if "hp" in enemy and "max_hp" in enemy:
		enemy.hp = mini(int(enemy.max_hp), int(enemy.hp) + heal)
	return heal


## Apply shielded cap — call before applying damage to the enemy.
## Returns the capped damage value.
static func apply_shielded(damage: int) -> int:
	return mini(damage, 50)


## Apply explosive on death — deals AoE damage to the player.
## Call in _die() when the enemy has the explosive affix.
static func apply_explosive(enemy_pos: Vector3, enemy_level: int, tree: SceneTree) -> void:
	var explosion_damage: int = enemy_level * 3
	var explosion_radius: float = 5.0
	var player: Node = tree.get_first_node_in_group("player")
	if player == null:
		return

	# Show telegraph briefly, then damage
	EnemyTelegraph.create_circle(
		enemy_pos, explosion_radius, 0.5,
		Color(1.0, 0.4, 0.1, 0.4),
		player.get_parent() if player.get_parent() else player
	)

	# Check if player is in range
	if player.global_position.distance_to(enemy_pos) <= explosion_radius:
		# Emit damage through EventBus — combat controller handles defense/etc
		EventBus.float_text_requested.emit(
			"Explosion! %d" % explosion_damage,
			player.global_position + Vector3(0, 3.0, 0),
			Color(1.0, 0.4, 0.1)
		)
		# Direct HP loss (bypasses combat controller for simplicity)
		var actual: int = maxi(1, explosion_damage)
		GameState.player["hp"] = maxi(0, int(GameState.player["hp"]) - actual)
		EventBus.player_damaged.emit(actual, "explosion")


## Apply regenerating — call each physics tick.
## Returns true if healing occurred.
static func apply_regenerating(enemy: Node, delta: float) -> bool:
	if "hp" in enemy and "max_hp" in enemy:
		var regen_rate: float = float(enemy.max_hp) * 0.005 * delta  # 0.5% per second
		enemy.hp = mini(int(enemy.max_hp), int(enemy.hp) + int(regen_rate + 0.5))
		return regen_rate >= 1.0
	return false
