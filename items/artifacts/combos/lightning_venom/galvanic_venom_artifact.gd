## galvanic_venom_artifact.gd -- combo synergy (Lightning + Venom): sparks have a chance to
## inject a venom stack. The chain does the poisoning for you.
extends ArtifactBase

const POISON := preload("res://systems/status_effects/poison/poison_status_effect.tres")

@export var venom_chance: float = 0.5

func on_equipped() -> void:
	if not Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.connect(_on_spark_hit)

func on_unequipped() -> void:
	if Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.disconnect(_on_spark_hit)

func _on_spark_hit(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > venom_chance:
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr:
		mgr.apply_status(POISON, user, "Galvanic Venom")
