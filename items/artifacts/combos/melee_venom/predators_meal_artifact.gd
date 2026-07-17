## predators_meal_artifact.gd -- combo synergy (Melee + Venom): killing a POISONED enemy heals
## you 1 HP. The venom tenderizes; the predator feeds.
extends ArtifactBase

@export var heal_per_kill: int = 1

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or not is_instance_valid(user):
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	if user.has_method("heal"):
		user.heal(heal_per_kill)
