## venom_blades_artifact.gd -- combo synergy (Melee + Venom): every melee strike has a chance to
## add a venom stack.
extends ArtifactBase

const POISON := preload("res://systems/status_effects/poison/poison_status_effect.tres")

@export var venom_chance: float = 0.6

func on_equipped() -> void:
	if not Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.connect(_on_enemy_hit)

func on_unequipped() -> void:
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)

func _on_enemy_hit(hit_details: Dictionary) -> void:
	if randf() > venom_chance:
		return
	var enemy = hit_details.get("enemy")
	if not is_instance_valid(enemy):
		return
	var mgr = enemy.get_node_or_null("StatusEffectManager")
	if mgr:
		mgr.apply_status(POISON, user, "Venom Blades")
