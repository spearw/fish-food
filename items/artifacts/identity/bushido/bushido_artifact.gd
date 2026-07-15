## bushido_artifact.gd
## Samurai's identity artifact: every kill hones the edge. Crit chance and crit damage grow with
## kills, up to a cap -- a duel that sharpens as the run goes.
extends ArtifactBase

@export var crit_chance_per_kill: float = 0.002   # +0.2% of base per kill
@export var crit_damage_per_kill: float = 0.005   # +0.5% of base per kill
@export var max_kills: int = 150                  # cap: x1.3 crit chance, x1.75 crit damage

var _kills := 0

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(_enemy_node: Node) -> void:
	if _kills >= max_kills:
		return
	_kills += 1
	if is_instance_valid(user) and user.has_method("notify_stats_changed"):
		user.notify_stats_changed()

func get_crit_chance_modifier() -> float:
	return 1.0 + crit_chance_per_kill * _kills

func get_crit_damage_modifier() -> float:
	return 1.0 + crit_damage_per_kill * _kills
